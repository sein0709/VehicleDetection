import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/constants/vehicle_classes.dart';
import 'package:greyeye_mobile/core/database/database.dart';
import 'package:greyeye_mobile/core/database/database_provider.dart';
import 'package:greyeye_mobile/core/inference/inference_isolate.dart';
import 'package:greyeye_mobile/core/inference/models.dart';
import 'package:greyeye_mobile/core/inference/pipeline_settings.dart';
import 'package:greyeye_mobile/core/theme/app_colors.dart';
import 'package:greyeye_mobile/features/analytics/models/analytics_model.dart';
import 'package:greyeye_mobile/features/analytics/providers/analytics_provider.dart';
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
  int _frameIndex = 0;
  int _crossingCount = 0;
  Timer? _frameTimer;

  @override
  void initState() {
    super.initState();
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
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      await _inferenceRunner.start(PipelineSettings());

      final roiDao = ref.read(roiDaoProvider);
      final activePreset =
          await roiDao.activePresetForCamera(widget.cameraId);
      if (activePreset != null) {
        final dbLines = await roiDao.linesForPreset(activePreset.id);
        final countingLines = dbLines
            .map((l) => roi.CountingLine(
                  name: l.id,
                  start: roi.Point2D(x: l.startX, y: l.startY),
                  end: roi.Point2D(x: l.endX, y: l.endY),
                  direction: l.direction,
                ))
            .toList();
        _inferenceRunner.updateCountingLines(widget.cameraId, countingLines);
      }

      if (mounted) {
        setState(() => _initializing = false);
        _startProcessing();
      }
    } catch (e) {
      if (mounted) setState(() => _initializing = false);
    }
  }

  void _startProcessing() {
    if (_isRunning) return;
    setState(() => _isRunning = true);

    _frameTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _captureAndProcess();
    });
  }

  void _stopProcessing() {
    _frameTimer?.cancel();
    _frameTimer = null;
    setState(() => _isRunning = false);
  }

  Future<void> _captureAndProcess() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final xFile = await _cameraController!.takePicture();
      final bytes = await xFile.readAsBytes();

      final result = await _inferenceRunner.processFrame(
        jpegBytes: bytes,
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
    } catch (_) {}
  }

  Future<void> _persistCrossings(List<VehicleCrossingEvent> crossings) async {
    final dao = ref.read(crossingsDaoProvider);
    final entries = crossings.map((c) {
      return VehicleCrossingsCompanion.insert(
        id: _uuid.v4(),
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

    if (mounted) {
      setState(() {
        _crossingCount += crossings.length;
      });
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _cameraController?.dispose();
    _inferenceRunner.resetCamera(widget.cameraId);
    _inferenceRunner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final liveKpi = ref.watch(liveKpiProvider(widget.cameraId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.monitorTitle),
        actions: [
          Icon(
            Icons.circle,
            size: 12,
            color: _isRunning ? AppColors.cameraOnline : AppColors.cameraOffline,
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
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
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
                              'Initializing camera & ML models...',
                              style: TextStyle(color: Colors.white54),
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
                      painter: _TrackOverlayPainter(tracks: _tracks),
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
                          '${_tracks.length} tracks · $_crossingCount crossings',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _LiveKpiPanel(liveKpi: liveKpi, theme: theme, l10n: l10n),
          ),
        ],
      ),
    );
  }
}

class _LiveKpiPanel extends StatelessWidget {
  const _LiveKpiPanel({
    required this.liveKpi,
    required this.theme,
    required this.l10n,
  });

  final LiveKpiUpdate? liveKpi;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final kpi = liveKpi;
    if (kpi == null) {
      return const Center(child: Text('Waiting for data...'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: l10n.monitorVehicleCount,
                value: '${kpi.totalCount}',
                icon: Icons.directions_car,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiCard(
                label: 'Flow Rate/h',
                value: '${kpi.flowRatePerHour.round()}',
                icon: Icons.speed,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Bucket',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: kpi.elapsedSeconds / 900.0,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(kpi.elapsedSeconds / 60).toStringAsFixed(1)} / 15.0 min',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('By Direction', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DirectionBar(
                        label: 'Inbound',
                        count: kpi.byDirection['inbound'] ?? 0,
                        total: kpi.totalCount,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DirectionBar(
                        label: 'Outbound',
                        count: kpi.byDirection['outbound'] ?? 0,
                        total: kpi.totalCount,
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('By Class', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ...kpi.byClass.entries.map<Widget>((entry) {
                  final vc = VehicleClass.fromCode(entry.key);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: vc?.color ?? Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vc?.labelEn ?? 'Class ${entry.key}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionBar extends StatelessWidget {
  const _DirectionBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? count / total : 0.0;
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: fraction,
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 2),
        Text('$count', style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _TrackOverlayPainter extends CustomPainter {
  _TrackOverlayPainter({required this.tracks});

  final List<TrackSnapshot> tracks;

  @override
  void paint(Canvas canvas, Size size) {
    for (final track in tracks) {
      final vc = VehicleClass.fromCode(track.classCode ?? 0);
      final color = vc?.color ?? Colors.white;

      final rect = Rect.fromLTWH(
        track.bbox.x * size.width,
        track.bbox.y * size.height,
        track.bbox.w * size.width,
        track.bbox.h * size.height,
      );

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(rect, paint);

      final label = vc?.labelEn ?? 'C${track.classCode}';
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
      tracks != oldDelegate.tracks;
}
