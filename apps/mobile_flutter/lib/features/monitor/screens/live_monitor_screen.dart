import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:greyeye_mobile/core/constants/vehicle_classes.dart';
import 'package:greyeye_mobile/core/database/daos/cameras_dao.dart';
import 'package:greyeye_mobile/core/database/daos/crossings_dao.dart';
import 'package:greyeye_mobile/core/database/daos/roi_dao.dart';
import 'package:greyeye_mobile/core/database/database.dart';
import 'package:greyeye_mobile/core/database/database_provider.dart';
import 'package:greyeye_mobile/core/inference/inference_isolate.dart';
import 'package:greyeye_mobile/core/inference/models.dart';
import 'package:greyeye_mobile/core/inference/pipeline_settings.dart';
import 'package:greyeye_mobile/core/inference/vlm_client.dart';
import 'package:greyeye_mobile/core/inference/vlm_queue.dart';
import 'package:greyeye_mobile/core/inference/vlm_settings_provider.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:greyeye_mobile/core/theme/app_colors.dart';
import 'package:greyeye_mobile/features/analytics/models/analytics_model.dart';
import 'package:greyeye_mobile/features/analytics/providers/analytics_provider.dart';
import 'package:greyeye_mobile/features/camera/models/camera_model.dart';
import 'package:greyeye_mobile/features/roi/models/roi_model.dart' as roi;
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class LiveMonitorScreen extends ConsumerStatefulWidget {
  const LiveMonitorScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  ConsumerState<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends ConsumerState<LiveMonitorScreen> {
  CameraController? _cameraController;
  final InferenceIsolateRunner _inferenceRunner = InferenceIsolateRunner();
  List<TrackSnapshot> _tracks = [];
  bool _isRunning = false;
  bool _initializing = true;
  bool _demoMode = false;
  bool _processingFrame = false;
  int _frameIndex = 0;
  int _crossingCount = 0;
  int _demoStep = 0;
  String? _statusMessage;
  PipelineSettings? _pipelineSettingsForMessage;
  Object? _inferenceError;
  String? _activeLineId;
  Timer? _frameTimer;
  CamerasDao? _camerasDao;
  RoiDao? _roiDao;
  CrossingsDao? _crossingsDao;

  VlmClient? _vlmClient;
  VlmRequestQueue? _vlmQueue;
  ClassificationMode _classificationMode = ClassificationMode.full12class;

  /// Crossing IDs currently awaiting VLM refinement. Cleared when the VLM
  /// result (or fallback) arrives via the queue callback.
  final Set<String> _pendingVlmCrossingIds = {};

  /// Maps crossing ID -> refined class code, populated by VLM callback so the
  /// KPI panel can show which crossings were cloud-refined.
  final Map<String, int> _vlmRefinedClasses = {};

  int get _pendingVlmCount => _pendingVlmCrossingIds.length;

  @override
  void initState() {
    super.initState();
    _camerasDao = ref.read(camerasDaoProvider);
    _roiDao = ref.read(roiDaoProvider);
    _crossingsDao = ref.read(crossingsDaoProvider);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _initializing = false);
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      final cameraRow =
          await _camerasDao?.cameraById(widget.cameraId);
      final cameraSettings = cameraRow != null
          ? CameraView.fromDbRow(cameraRow).settings
          : const CameraSettings();
      final pipelineSettings = _pipelineSettingsFor(cameraSettings);
      _classificationMode = pipelineSettings.classifier.mode;

      _initVlmIfNeeded(pipelineSettings);

      final roiDao = _roiDao!;
      List<roi.CountingLine> countingLines = const [];
      final activePreset = await roiDao.activePresetForCamera(widget.cameraId);
      if (activePreset != null) {
        final dbLines = await roiDao.linesForPreset(activePreset.id);
        countingLines = dbLines
            .map((l) => roi.CountingLine(
                  name: l.id,
                  start: roi.Point2D(x: l.startX, y: l.startY),
                  end: roi.Point2D(x: l.endX, y: l.endY),
                  direction: l.direction,
                ))
            .toList();
        _activeLineId = dbLines.isNotEmpty ? dbLines.first.id : null;
      }

      final missingModels = await _missingModelAssetsFor(pipelineSettings);
      try {
        if (missingModels.isNotEmpty) {
          throw StateError(
            'Missing model assets: ${missingModels.join(', ')}. '
            'Run `make export-tflite` to install the detector and classifier.',
          );
        }

        await _inferenceRunner.start(pipelineSettings);
        if (countingLines.isNotEmpty) {
          _inferenceRunner.updateCountingLines(widget.cameraId, countingLines);
        }
        _pipelineSettingsForMessage = pipelineSettings;
      } catch (error) {
        _demoMode = true;
        _pipelineSettingsForMessage = pipelineSettings;
        _inferenceError = error;
      }

      await _camerasDao?.updateStatus(widget.cameraId, 'online');
      await _camerasDao?.markSeen(widget.cameraId);

      if (mounted) {
        setState(() => _initializing = false);
        _startProcessing();
      }
    } on CameraException catch (e) {
      _demoMode = true;
      _statusMessage = null;
      debugPrint('CameraException [${e.code}]: ${e.description}');
      if (mounted) {
        setState(() => _initializing = false);
        _startProcessing();
      }
    } catch (e) {
      _demoMode = true;
      _statusMessage = null;
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() => _initializing = false);
        _startProcessing();
      }
    }
  }

  void _initVlmIfNeeded(PipelineSettings pipelineSettings) {
    if (pipelineSettings.classifier.mode != ClassificationMode.hybridCloud) {
      return;
    }

    final vlmSettings = ref.read(vlmSettingsProvider);
    if (vlmSettings.apiKey.isEmpty) {
      debugPrint('VLM hybrid cloud mode enabled but no API key configured');
      return;
    }

    _vlmClient = VlmClient(settings: vlmSettings);
    _vlmQueue = VlmRequestQueue(
      client: _vlmClient!,
      crossingsDao: _crossingsDao!,
      settings: vlmSettings,
      onRefinement: _onVlmRefinement,
    );
  }

  void _onVlmRefinement(
    String crossingId,
    int classCode,
    double confidence,
    String source,
  ) {
    if (!mounted) return;
    setState(() {
      _pendingVlmCrossingIds.remove(crossingId);
      _vlmRefinedClasses[crossingId] = classCode;
    });
  }

  void _startProcessing() {
    if (_isRunning) return;
    setState(() => _isRunning = true);

    if (_demoMode) {
      _frameTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _simulateFrame();
      });
      return;
    }

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _cameraController!.startImageStream(_onCameraFrame);
    }
  }

  void _stopProcessing() {
    _frameTimer?.cancel();
    _frameTimer = null;
    if (!_demoMode &&
        _cameraController != null &&
        _cameraController!.value.isInitialized &&
        _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }
    setState(() => _isRunning = false);
  }

  void _onCameraFrame(CameraImage cameraImage) {
    if (_processingFrame) return;
    _processingFrame = true;
    _processStreamFrame(cameraImage);
  }

  Future<void> _processStreamFrame(CameraImage cameraImage) async {
    try {
      final jpegBytes = _cameraImageToJpeg(cameraImage);
      if (jpegBytes == null) return;

      final result = await _inferenceRunner.processFrame(
        jpegBytes: jpegBytes,
        cameraId: widget.cameraId,
        frameIndex: _frameIndex++,
      );

      if (mounted) {
        setState(() {
          _tracks = result.tracks;
        });
      }

      if (result.crossings.isNotEmpty) {
        _persistCrossings(result.crossings);
      }
    } catch (_) {
    } finally {
      _processingFrame = false;
    }
  }

  Uint8List? _cameraImageToJpeg(CameraImage cameraImage) {
    try {
      final plane = cameraImage.planes.first;
      final width = cameraImage.width;
      final height = cameraImage.height;
      final bytes = plane.bytes;
      final rowStride = plane.bytesPerRow;

      final image = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        final rowOffset = y * rowStride;
        for (int x = 0; x < width; x++) {
          final pixelOffset = rowOffset + x * 4;
          final b = bytes[pixelOffset];
          final g = bytes[pixelOffset + 1];
          final r = bytes[pixelOffset + 2];
          final a = bytes[pixelOffset + 3];
          image.setPixelRgba(x, y, r, g, b, a);
        }
      }

      return Uint8List.fromList(img.encodeJpg(image, quality: 85));
    } catch (_) {
      return null;
    }
  }

  Future<void> _simulateFrame() async {
    final frameIndex = _frameIndex++;
    final progress = (_demoStep % 120) / 120.0;
    _demoStep += 1;

    final tracks = <TrackSnapshot>[
      TrackSnapshot(
        trackId: 'demo-a',
        bbox: BoundingBox(
          x: 0.08 + progress * 0.65,
          y: 0.28,
          w: 0.16,
          h: 0.12,
        ),
        classCode: 1,
        confidence: 0.92,
        speedEstimateKmh: 34,
      ),
      TrackSnapshot(
        trackId: 'demo-b',
        bbox: BoundingBox(
          x: 0.62 - progress * 0.45,
          y: 0.52,
          w: 0.18,
          h: 0.13,
        ),
        classCode: 3,
        confidence: 0.88,
        speedEstimateKmh: 41,
      ),
    ];

    if (mounted) {
      setState(() {
        _tracks = tracks;
      });
    }

    if (_activeLineId == null || frameIndex % 12 != 0) {
      return;
    }

    final direction = (frameIndex ~/ 12).isEven ? 'inbound' : 'outbound';
    final demoClass = <int>[1, 3, 2, 4, 8, 1][(frameIndex ~/ 12) % 6];
    final crossing = VehicleCrossingEvent(
      timestampUtc: DateTime.now().toUtc(),
      cameraId: widget.cameraId,
      lineId: _activeLineId!,
      trackId: 'demo-crossing-$frameIndex',
      crossingSeq: 1,
      classCode: demoClass,
      confidence: 0.85,
      direction: direction,
      frameIndex: frameIndex,
      speedEstimateKmh: 32 + ((frameIndex ~/ 12) % 18).toDouble(),
      bbox: tracks.first.bbox,
    );

    await _persistCrossings([crossing]);
  }

  Future<void> _persistCrossings(List<VehicleCrossingEvent> crossings) async {
    final dao = _crossingsDao!;
    final ids = <String>[];
    final entries = crossings.map((c) {
      final id = _uuid.v4();
      ids.add(id);
      return VehicleCrossingsCompanion.insert(
        id: id,
        cameraId: c.cameraId,
        lineId: c.lineId,
        trackId: c.trackId,
        crossingSeq: Value(c.crossingSeq),
        class12: c.classCode,
        confidence: c.confidence,
        direction: c.direction,
        frameIndex: c.frameIndex,
        speedEstimateKmh: Value(c.speedEstimateKmh),
        bboxJson: Value(jsonEncode({
          'x': c.bbox.x,
          'y': c.bbox.y,
          'w': c.bbox.w,
          'h': c.bbox.h,
        })),
        timestampUtc: c.timestampUtc,
      );
    }).toList();

    await dao.insertCrossingsBatch(entries);

    if (_vlmQueue != null) {
      for (var i = 0; i < crossings.length; i++) {
        final c = crossings[i];
        if (c.pendingVlmRefinement && c.cropJpegBytes != null) {
          _pendingVlmCrossingIds.add(ids[i]);
          _vlmQueue!.enqueue(VlmRequest(
            crossingId: ids[i],
            jpegCrop: c.cropJpegBytes!,
            localFallbackClass: c.classCode,
            localFallbackConfidence: c.localFallbackConfidence ?? c.confidence,
          ));
        }
      }
    }

    if (mounted) {
      setState(() {
        _crossingCount += crossings.length;
      });
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    if (_cameraController != null &&
        _cameraController!.value.isInitialized &&
        _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }
    _cameraController?.dispose();
    _camerasDao?.updateStatus(widget.cameraId, 'offline');
    _inferenceRunner.resetCamera(widget.cameraId);
    _inferenceRunner.dispose();
    _vlmQueue?.dispose();
    _vlmClient?.dispose();
    super.dispose();
  }

  String? _resolvedStatusMessage(AppLocalizations l10n) {
    if (_pipelineSettingsForMessage != null && _inferenceError != null) {
      return _inferenceFailureMessage(_inferenceError!, _pipelineSettingsForMessage!, l10n);
    }
    if (_pipelineSettingsForMessage != null) {
      return _pipelineSummaryMessage(_pipelineSettingsForMessage!, l10n);
    }
    if (_demoMode && _statusMessage == null) {
      return l10n.monitorCameraUnavailable;
    }
    return _statusMessage;
  }

  Widget _buildCameraView(AppLocalizations l10n, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_initializing)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white54),
                    SizedBox(height: 12),
                    Text(
                      l10n.monitorInitializing,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              )
            else if (_cameraController != null &&
                _cameraController!.value.isInitialized)
              CameraPreview(_cameraController!)
            else
              Center(
                child: Text(
                  l10n.monitorNoFeed,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            CustomPaint(
              painter: _TrackOverlayPainter(
                tracks: _tracks,
                previewAspectRatio:
                    _cameraController?.value.isInitialized == true
                        ? _cameraController!.value.aspectRatio
                        : 16 / 9,
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: _StatusBadge(
                message: _resolvedStatusMessage(l10n) ??
                    (_demoMode ? l10n.monitorSimulated : l10n.monitorLive),
                color: _demoMode
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.primary,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.monitorTracksAndCrossings(_tracks.length, _crossingCount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            if (_pendingVlmCount > 0)
              Positioned(
                top: 32,
                right: 8,
                child: _VlmRefinementBadge(pendingCount: _pendingVlmCount),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final liveKpi = ref.watch(liveKpiProvider(widget.cameraId));
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 840;

    final cameraView = _buildCameraView(l10n, theme);
    final vlmStats = _vlmQueue?.stats;
    final kpiPanel = _LiveKpiPanel(
      liveKpi: liveKpi,
      theme: theme,
      l10n: l10n,
      isHybridCloud: _classificationMode == ClassificationMode.hybridCloud,
      pendingVlmCount: _pendingVlmCount,
      vlmStats: vlmStats,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.monitorTitle),
        actions: [
          Icon(
            Icons.circle,
            size: 12,
            color:
                _isRunning ? AppColors.cameraOnline : AppColors.cameraOffline,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
            onPressed: _initializing
                ? null
                : () {
                    if (_isRunning) {
                      _stopProcessing();
                    } else {
                      _startProcessing();
                    }
                  },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: wide
          ? Row(
              children: [
                Expanded(flex: 8, child: cameraView),
                Expanded(flex: 2, child: kpiPanel),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 3, child: cameraView),
                Expanded(flex: 2, child: kpiPanel),
              ],
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.message,
    required this.color,
  });

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LiveKpiPanel extends StatelessWidget {
  const _LiveKpiPanel({
    required this.liveKpi,
    required this.theme,
    required this.l10n,
    this.isHybridCloud = false,
    this.pendingVlmCount = 0,
    this.vlmStats,
  });

  final LiveKpiUpdate? liveKpi;
  final ThemeData theme;
  final AppLocalizations l10n;
  final bool isHybridCloud;
  final int pendingVlmCount;
  final VlmQueueStats? vlmStats;

  @override
  Widget build(BuildContext context) {
    final kpi = liveKpi;
    if (kpi == null) {
      return Center(child: Text(l10n.monitorWaitingForData));
    }

    final inbound = kpi.byDirection['inbound'] ?? 0;
    final outbound = kpi.byDirection['outbound'] ?? 0;
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final sectionStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w700,
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _CompactRow(
          label: l10n.monitorVehicleCount,
          labelStyle: sectionStyle,
          child: Text('${kpi.totalCount}', style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          )),
        ),
        const Divider(height: 16),

        _CompactRow(
          label: l10n.monitorFlowRate,
          labelStyle: sectionStyle,
          child: Text('${kpi.flowRatePerHour.round()} /h', style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.secondary,
          )),
        ),
        const Divider(height: 16),

        Text(l10n.monitorCurrentBucket, style: sectionStyle),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: kpi.elapsedSeconds / 900.0,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 2),
        Text(
          '${(kpi.elapsedSeconds / 60).toStringAsFixed(1)} / 15.0 min',
          style: theme.textTheme.labelSmall,
        ),
        const Divider(height: 16),

        Text(l10n.monitorByDirection, style: sectionStyle),
        const SizedBox(height: 6),
        _CompactRow(
          label: l10n.monitorInbound,
          labelStyle: labelStyle,
          child: Text('$inbound', style: valueStyle),
        ),
        const SizedBox(height: 2),
        _CompactRow(
          label: l10n.monitorOutbound,
          labelStyle: labelStyle,
          child: Text('$outbound', style: valueStyle),
        ),
        const Divider(height: 16),

        Text(l10n.monitorByClass, style: sectionStyle),
        const SizedBox(height: 6),
        ...kpi.byClass.entries.map<Widget>((entry) {
          final vc = VehicleClass.fromCode(entry.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: vc?.color ?? Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    vc?.labelKo ?? 'C${entry.key}',
                    style: labelStyle,
                  ),
                ),
                Text('${entry.value}', style: valueStyle),
              ],
            ),
          );
        }),

        if (isHybridCloud) ...[
          const Divider(height: 16),
          _VlmStatusSection(
            sectionStyle: sectionStyle,
            labelStyle: labelStyle,
            valueStyle: valueStyle,
            pendingCount: pendingVlmCount,
            stats: vlmStats,
          ),
        ],
      ],
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.label,
    this.labelStyle,
    required this.child,
  });

  final String label;
  final TextStyle? labelStyle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        child,
      ],
    );
  }
}

class _VlmRefinementBadge extends StatefulWidget {
  const _VlmRefinementBadge({required this.pendingCount});

  final int pendingCount;

  @override
  State<_VlmRefinementBadge> createState() => _VlmRefinementBadgeState();
}

class _VlmRefinementBadgeState extends State<_VlmRefinementBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.deepOrange.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              AppLocalizations.of(context).monitorRefiningCrossings(widget.pendingCount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VlmStatusSection extends StatelessWidget {
  const _VlmStatusSection({
    required this.sectionStyle,
    required this.labelStyle,
    required this.valueStyle,
    required this.pendingCount,
    this.stats,
  });

  final TextStyle? sectionStyle;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final int pendingCount;
  final VlmQueueStats? stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = stats;

    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.monitorCloudVlm, style: sectionStyle),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: pendingCount > 0
                    ? Colors.deepOrange.withValues(alpha: 0.15)
                    : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                pendingCount > 0 ? l10n.monitorRefining(pendingCount) : l10n.monitorIdle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: pendingCount > 0
                      ? Colors.deepOrange
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (s != null) ...[
          _CompactRow(
            label: l10n.monitorSentToVlm,
            labelStyle: labelStyle,
            child: Text('${s.totalEnqueued}', style: valueStyle),
          ),
          const SizedBox(height: 2),
          _CompactRow(
            label: l10n.monitorRefined,
            labelStyle: labelStyle,
            child: Text('${s.totalSucceeded}', style: valueStyle),
          ),
          const SizedBox(height: 2),
          _CompactRow(
            label: l10n.monitorFallbacks,
            labelStyle: labelStyle,
            child: Text('${s.totalFallbacks}', style: valueStyle),
          ),
          if (s.totalFlushed > 0) ...[
            const SizedBox(height: 2),
            _CompactRow(
              label: l10n.monitorAvgLatency,
              labelStyle: labelStyle,
              child: Text(
                '${s.averageLatencyMs.toStringAsFixed(0)} ms',
                style: valueStyle,
              ),
            ),
          ],
        ] else
          Text(
            l10n.monitorNoApiKey,
            style: labelStyle?.copyWith(fontStyle: FontStyle.italic),
          ),
      ],
    );
  }
}

class _TrackOverlayPainter extends CustomPainter {
  _TrackOverlayPainter({
    required this.tracks,
    required this.previewAspectRatio,
  });

  final List<TrackSnapshot> tracks;
  final double previewAspectRatio;

  @override
  void paint(Canvas canvas, Size size) {
    // Compute the fitted preview rect (mirrors AspectRatio / BoxFit.contain).
    final containerAR = size.width / size.height;
    double previewW, previewH;
    if (previewAspectRatio < containerAR) {
      previewH = size.height;
      previewW = previewH * previewAspectRatio;
    } else {
      previewW = size.width;
      previewH = previewW / previewAspectRatio;
    }
    final offsetX = (size.width - previewW) / 2;
    final offsetY = (size.height - previewH) / 2;

    for (final track in tracks) {
      final vc = VehicleClass.fromCode(track.classCode ?? 0);
      final color = vc?.color ?? Colors.white;

      final rect = Rect.fromLTWH(
        offsetX + track.bbox.x * previewW,
        offsetY + track.bbox.y * previewH,
        track.bbox.w * previewW,
        track.bbox.h * previewH,
      );

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(rect, paint);

      final label = vc?.labelKo ?? 'C${track.classCode}';
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$label #${track.trackId}',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black54,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(rect.left, rect.top - 14));
    }
  }

  @override
  bool shouldRepaint(covariant _TrackOverlayPainter oldDelegate) =>
      tracks != oldDelegate.tracks ||
      previewAspectRatio != oldDelegate.previewAspectRatio;
}

PipelineSettings _pipelineSettingsFor(CameraSettings cameraSettings) {
  final classificationMode = switch (cameraSettings.classificationMode) {
    'disabled' => ClassificationMode.disabled,
    'coarse_only' => ClassificationMode.coarseOnly,
    'hybrid_cloud' => ClassificationMode.hybridCloud,
    _ => ClassificationMode.full12class,
  };

  return PipelineSettings(
    cameraFps: cameraSettings.targetFps.toDouble(),
    classifier: ClassifierSettings(mode: classificationMode),
  );
}

Future<List<String>> _missingModelAssetsFor(PipelineSettings settings) async {
  final missingModels = <String>[];

  if (!await _assetExists(settings.detector.modelPath)) {
    missingModels.add(settings.detector.modelPath);
  }

  if ((settings.classifier.mode == ClassificationMode.full12class ||
          settings.classifier.mode == ClassificationMode.hybridCloud) &&
      !await _assetExists(settings.stage2Detector.modelPath)) {
    missingModels.add(settings.stage2Detector.modelPath);
  }

  return missingModels;
}

Future<bool> _assetExists(String assetPath) async {
  try {
    await rootBundle.load(assetPath);
    return true;
  } catch (_) {
    return false;
  }
}

String _pipelineSummaryMessage(PipelineSettings settings, AppLocalizations l10n) {
  return switch (settings.classifier.mode) {
    ClassificationMode.full12class => l10n.monitorPipelineFull12,
    ClassificationMode.coarseOnly => l10n.monitorPipelineCoarse,
    ClassificationMode.hybridCloud => l10n.monitorPipelineHybrid,
    ClassificationMode.disabled => l10n.monitorPipelineDetectionOnly,
  };
}

String _inferenceFailureMessage(
  Object error,
  PipelineSettings settings,
  AppLocalizations l10n,
) {
  final errorStr = '$error';
  return switch (settings.classifier.mode) {
    ClassificationMode.full12class =>
      l10n.monitorClassificationUnavailable12(errorStr),
    ClassificationMode.coarseOnly =>
      l10n.monitorClassificationUnavailableCoarse(errorStr),
    ClassificationMode.hybridCloud =>
      l10n.monitorClassificationUnavailableHybrid(errorStr),
    ClassificationMode.disabled =>
      l10n.monitorClassificationUnavailableDisabled(errorStr),
  };
}
