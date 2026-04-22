import 'dart:io';

import 'package:dio/dio.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:greyeye_mobile/core/theme/app_colors.dart';
import 'package:greyeye_mobile/features/sites/models/site_calibration.dart';
import 'package:greyeye_mobile/features/sites/models/video_analysis_remote_result.dart';
import 'package:greyeye_mobile/features/sites/providers/site_calibration_provider.dart';
import 'package:greyeye_mobile/features/sites/screens/count_line_editor_screen.dart';
import 'package:greyeye_mobile/features/sites/screens/plate_allowlist_editor_screen.dart';
import 'package:greyeye_mobile/features/sites/screens/speed_config_editor_screen.dart';
import 'package:greyeye_mobile/features/sites/screens/traffic_light_roi_editor_screen.dart';
import 'package:greyeye_mobile/features/sites/screens/transit_config_editor_screen.dart';
import 'package:greyeye_mobile/features/sites/services/task_calibration_builder.dart';
import 'package:greyeye_mobile/features/sites/services/video_analysis_remote_service.dart';
import 'package:greyeye_mobile/features/sites/services/video_frame_extractor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class VideoAnalysisScreen extends ConsumerStatefulWidget {
  const VideoAnalysisScreen({super.key, required this.siteId});

  final String siteId;

  @override
  ConsumerState<VideoAnalysisScreen> createState() =>
      _VideoAnalysisScreenState();
}

enum _ScreenPhase { idle, staged, uploading, processing, done, error }

class _VideoAnalysisScreenState extends ConsumerState<VideoAnalysisScreen> {
  String? _selectedVideoPath;
  _ScreenPhase _phase = _ScreenPhase.idle;
  String _errorMessage = '';
  VideoAnalysisRemoteResult? _result;
  DateTime? _analysisStartedAt;
  DateTime? _analysisCompletedAt;
  // Cached first-frame thumbnail of the staged video; null while
  // extraction is pending or if extraction failed (we still let the
  // operator start analysis without one).
  Uint8List? _stagedThumbnail;

  // All operator-editable calibration choices live in
  // `siteCalibrationProvider(siteId)`, hydrated from disk on first
  // build and persisted on every change. The screen reads through
  // [_cal] / [_calNotifier] helpers below — never holds duplicate
  // state. This means the operator's task picks, allowlist, and
  // editor overrides survive both screen rebuilds AND app restarts,
  // which was the biggest UX gap left by the previous iteration.

  // Active video download state. We track these in the State (not in a
  // local async function) so we can render a progress indicator and
  // cancel the request if the user navigates away.
  bool _isDownloadingVideo = false;
  double? _downloadProgress; // null = unknown total (no Content-Length)
  CancelToken? _downloadCancelToken;

  @override
  void dispose() {
    _downloadCancelToken?.cancel();
    super.dispose();
  }

  // Calibration accessors. Reading via watch() in build() drives
  // rebuilds when the persisted state changes (e.g. after an editor
  // returns); reading via read() in callbacks gets the latest value
  // without subscribing the callback to rebuilds.
  SiteCalibration get _calRead =>
      ref.read(siteCalibrationProvider(widget.siteId)).calibration;
  SiteCalibrationNotifier get _calNotifier =>
      ref.read(siteCalibrationProvider(widget.siteId).notifier);

  static const _maxDuration = Duration(seconds: 300);

  Future<void> _pickFromGallery() async {
    // file_picker so the operator can choose .dav (CCTV) files —
    // ImagePicker.pickVideo only exposes the system gallery, which
    // hides anything outside its known video MIME types.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'mov', 'm4v', 'dav'],
      dialogTitle: AppLocalizations.of(context).videoAnalysisPickFileTitle,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    await _consumePickedVideo(path);
  }

  Future<void> _recordFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: _maxDuration,
    );
    if (picked == null) return;
    await _consumePickedVideo(picked.path);
  }

  Future<void> _consumePickedVideo(String path) async {
    // Stage-only: previously this kicked off the upload immediately,
    // which removed the operator's chance to opt out of vehicle
    // counting (e.g. bus-stop scenario) or edit calibration before the
    // server got the file. Now we stash the path, fetch a thumbnail,
    // and wait for an explicit Start tap.
    setState(() {
      _selectedVideoPath = path;
      _result = null;
      _errorMessage = '';
      _analysisCompletedAt = null;
      _stagedThumbnail = null;
      _phase = _ScreenPhase.staged;
    });

    // Block .dav uploads up-front: the server's OpenCV pipeline cannot
    // demux Dahua containers reliably, and the operator can still use
    // the file as a calibration backdrop in the per-task editors.
    if (looksLikeDavPath(path)) {
      setState(() {
        _phase = _ScreenPhase.error;
        _errorMessage =
            AppLocalizations.of(context).videoAnalysisDavNotSupported;
      });
      return;
    }

    // Best-effort thumbnail — the staged card still works without one
    // (we just show the filename).
    final thumb = await const VideoFrameExtractor().extractFrame(path);
    if (!mounted) return;
    setState(() => _stagedThumbnail = thumb);
  }

  Future<void> _startAnalysis() async {
    final path = _selectedVideoPath;
    if (path == null) return;
    if (looksLikeDavPath(path)) {
      setState(() {
        _phase = _ScreenPhase.error;
        _errorMessage =
            AppLocalizations.of(context).videoAnalysisDavNotSupported;
      });
      return;
    }
    setState(() {
      _phase = _ScreenPhase.uploading;
      _errorMessage = '';
      _analysisStartedAt = DateTime.now();
    });
    await _uploadAndPoll(path);
  }

  void _clearStagedFile() {
    setState(() {
      _selectedVideoPath = null;
      _stagedThumbnail = null;
      _phase = _ScreenPhase.idle;
      _errorMessage = '';
    });
  }

  Future<void> _applyBusStopPreset() async {
    // One-tap shortcut for the most common pedestrian-only scenario:
    // disables vehicle counting and enables transit + pedestrians.
    // Keeps the rest of the operator's calibration intact.
    final l10n = AppLocalizations.of(context);
    await _calNotifier.setEnabledTasks(<String>{
      AnalysisTask.transit,
      AnalysisTask.pedestrians,
    });
    if (!mounted) return;
    _toast(l10n.videoAnalysisBusStopApplied);
  }

  Future<void> _openCountLineEditor() async {
    final videoPath = _selectedVideoPath ?? '';
    CountLineConfig? seed;
    final ov = _calRead.countLineOverride;
    if (ov != null) {
      seed = CountLineConfig(
        inLine: ov.inLineXY.map((p) => Offset(p[0], p[1])).toList(),
        outLine: ov.outLineXY.map((p) => Offset(p[0], p[1])).toList(),
      );
    }
    final result = await Navigator.of(context).push<CountLineConfig>(
      MaterialPageRoute(
        builder: (_) => CountLineEditorScreen(
          videoPath: videoPath,
          initial: seed,
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _calNotifier.setCountLineOverride(CountLineOverride(
      inLineXY:
          result.inLine.map((p) => <double>[p.dx, p.dy]).toList(),
      outLineXY:
          result.outLine.map((p) => <double>[p.dx, p.dy]).toList(),
    ),);
  }

  Future<void> _uploadAndPoll(String path) async {
    final service = ref.read(videoAnalysisRemoteServiceProvider);

    // Phase 1: Upload the video and get a job ID.
    final String jobId;
    try {
      jobId = await service.submitVideo(
        path,
        // The server defaults `output_video` to false and only runs
        // {vehicles, pedestrians} unless calibration says otherwise.
        // Always send the JSON so per-task overrides + the video toggle
        // both apply.
        calibrationJson: toCalibrationJson(_calRead),
      );
    } on VideoAnalysisException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _ScreenPhase.error;
        _errorMessage = e.message;
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _ScreenPhase.error;
        _errorMessage = e.toString();
      });
      return;
    }

    if (!mounted) return;
    setState(() => _phase = _ScreenPhase.processing);

    // Phase 2: Poll until the server returns the final result.
    try {
      final result = await service.pollUntilComplete(jobId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _ScreenPhase.done;
        _analysisCompletedAt = DateTime.now();
      });
    } on VideoAnalysisException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _ScreenPhase.error;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _ScreenPhase.error;
        _errorMessage = e.toString();
      });
    }
  }

  void _retry() {
    // Retry now goes through the normal start path so it's a single
    // entry point — no risk of skipping the .dav guard or the start
    // timestamp reset.
    _startAnalysis();
  }

  Future<void> _exportXlsx() async {
    final result = _result;
    if (result == null) return;

    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['결과값'];
      excel.delete('Sheet1');

      _ResultsTemplateBuilder(
        sheet: sheet,
        siteId: widget.siteId,
        breakdown: result.breakdown,
        analysisStartedAt: _analysisStartedAt,
      ).build();

      final bytes = excel.encode();
      if (bytes == null) return;

      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir.path}/video_analysis_$timestamp.xlsx';
      await File(filePath).writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 완료: $filePath')),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _openTrafficLightEditor() async {
    // Editors handle a missing main video via their own per-screen file
    // picker — pass an empty string and let CalibrationCanvas prompt
    // the operator to choose a backdrop.
    final videoPath = _selectedVideoPath ?? '';
    final existing = _calRead.trafficLightOverrides.isEmpty
        ? null
        : _calRead.trafficLightOverrides.first;
    final result = await Navigator.of(context).push<TrafficLightRoi>(
      MaterialPageRoute(
        builder: (_) => TrafficLightRoiEditorScreen(
          videoPath: videoPath,
          initialLabel: existing?.label ?? 'main',
          initialRoi: existing?.roi,
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _calNotifier.setTrafficLightOverrides([
      TrafficLightOverride(label: result.label, roi: result.roi),
    ]);
  }

  Future<void> _openSpeedEditor() async {
    final videoPath = _selectedVideoPath ?? '';
    SpeedConfig? seed;
    final ov = _calRead.speedOverride;
    if (ov != null) {
      seed = SpeedConfig(
        sourceQuad: ov.sourceQuadXY
            .map((p) => Offset(p[0], p[1]))
            .toList(),
        linesYRatio: ov.linesYRatio,
        realWorldWidthM: ov.realWorldWidthM,
        realWorldLengthM: ov.realWorldLengthM,
        line1XY: ov.linesXY != null && ov.linesXY!.length == 2
            ? ov.linesXY![0].map((p) => Offset(p[0], p[1])).toList()
            : const [],
        line2XY: ov.linesXY != null && ov.linesXY!.length == 2
            ? ov.linesXY![1].map((p) => Offset(p[0], p[1])).toList()
            : const [],
      );
    }
    final result = await Navigator.of(context).push<SpeedConfig>(
      MaterialPageRoute(
        builder: (_) =>
            SpeedConfigEditorScreen(videoPath: videoPath, initial: seed),
      ),
    );
    if (!mounted || result == null) return;
    final hasArbitraryLines =
        result.line1XY.length == 2 && result.line2XY.length == 2;
    await _calNotifier.setSpeedOverride(SpeedOverride(
      sourceQuadXY:
          result.sourceQuad.map((p) => <double>[p.dx, p.dy]).toList(),
      linesYRatio: result.linesYRatio,
      realWorldWidthM: result.realWorldWidthM,
      realWorldLengthM: result.realWorldLengthM,
      linesXY: hasArbitraryLines
          ? <List<List<double>>>[
              result.line1XY.map((p) => <double>[p.dx, p.dy]).toList(),
              result.line2XY.map((p) => <double>[p.dx, p.dy]).toList(),
            ]
          : null,
    ),);
  }

  Future<void> _openTransitEditor() async {
    final videoPath = _selectedVideoPath ?? '';
    TransitConfig? seed;
    final ov = _calRead.transitOverride;
    if (ov != null) {
      seed = TransitConfig(
        stopPolygon: ov.stopPolygonXY
            .map((p) => Offset(p[0], p[1]))
            .toList(),
        doorLine:
            ov.doorLineXY.map((p) => Offset(p[0], p[1])).toList(),
        busZonePolygon: ov.busZonePolygonXY
            ?.map((p) => Offset(p[0], p[1]))
            .toList(),
        maxCapacity: ov.maxCapacity,
      );
    }
    final result = await Navigator.of(context).push<TransitConfig>(
      MaterialPageRoute(
        builder: (_) => TransitConfigEditorScreen(
          videoPath: videoPath,
          initial: seed,
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _calNotifier.setTransitOverride(TransitOverride(
      stopPolygonXY: result.stopPolygon
          .map((p) => <double>[p.dx, p.dy])
          .toList(),
      doorLineXY:
          result.doorLine.map((p) => <double>[p.dx, p.dy]).toList(),
      busZonePolygonXY: result.busZonePolygon
          ?.map((p) => <double>[p.dx, p.dy])
          .toList(),
      maxCapacity: result.maxCapacity,
    ),);
  }

  Future<void> _openAllowlistEditor() async {
    final updated = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => PlateAllowlistEditorScreen(
          initial: _calRead.lprAllowlist,
        ),
      ),
    );
    if (!mounted || updated == null) return;
    await _calNotifier.setLprAllowlist(updated);
  }

  Future<void> _resetCalibration() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.calibrationResetTitle),
        content: Text(l10n.calibrationResetMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.roiEditorCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.calibrationResetConfirm),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _calNotifier.reset();
    if (mounted) _toast(l10n.calibrationResetDone);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _downloadAnnotatedVideo({String kind = 'classified'}) async {
    final result = _result;
    if (result == null || result.jobId.isEmpty) return;
    if (_isDownloadingVideo) return;

    final service = ref.read(videoAnalysisRemoteServiceProvider);
    final cancelToken = CancelToken();

    setState(() {
      _isDownloadingVideo = true;
      _downloadProgress = null;
      _downloadCancelToken = cancelToken;
    });

    try {
      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'video_analysis_${kind}_$timestamp.mp4';
      final destPath = '${dir.path}/$filename';

      await service.downloadAnnotatedVideo(
        jobId: result.jobId,
        kind: kind,
        destPath: destPath,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = total > 0 ? received / total : null;
          });
        },
      );

      if (!mounted) return;
      // Hand off to the platform share sheet so the user can save to Files,
      // send via messenger, etc — same UX as the report exporter.
      await Share.shareXFiles([XFile(destPath)]);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).videoAnalysisDownloadSaved(destPath),
          ),
        ),
      );
    } on VideoAnalysisException catch (e) {
      if (cancelToken.isCancelled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).videoAnalysisDownloadCanceled,
              ),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingVideo = false;
          _downloadProgress = null;
          _downloadCancelToken = null;
        });
      } else {
        _isDownloadingVideo = false;
        _downloadCancelToken = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final calState = ref.watch(siteCalibrationProvider(widget.siteId));
    final cal = calState.calibration;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.videoAnalysisTitle),
        actions: [
          IconButton(
            tooltip: l10n.calibrationResetTooltip,
            icon: const Icon(Icons.restart_alt),
            onPressed: _resetCalibration,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PickerCard(
                  isUploading: _phase == _ScreenPhase.uploading ||
                      _phase == _ScreenPhase.processing,
                  onPickGallery: _pickFromGallery,
                  onRecordCamera: _recordFromCamera,
                  onApplyBusStopPreset: _applyBusStopPreset,
                  includeAnnotatedVideo: cal.includeAnnotatedVideo,
                  onIncludeAnnotatedVideoChanged:
                      _calNotifier.setIncludeAnnotatedVideo,
                  enabledTasks: cal.enabledTasks,
                  onTaskToggled: (task, enabled) {
                    final next = {...cal.enabledTasks};
                    if (enabled) {
                      next.add(task);
                    } else {
                      next.remove(task);
                    }
                    _calNotifier.setEnabledTasks(next);
                  },
                  trafficLightConfigured:
                      cal.trafficLightOverrides.isNotEmpty,
                  onConfigureTrafficLight: _openTrafficLightEditor,
                  speedConfigured: cal.speedOverride != null,
                  onConfigureSpeed: _openSpeedEditor,
                  transitConfigured: cal.transitOverride != null,
                  onConfigureTransit: _openTransitEditor,
                  countLineConfigured: cal.countLineOverride != null,
                  onConfigureCountLine: _openCountLineEditor,
                  lprAllowlistCount: cal.lprAllowlist.length,
                  onConfigureLprAllowlist: _openAllowlistEditor,
                  transitAutoMode: cal.transitAutoMode,
                  onTransitAutoModeChanged:
                      _calNotifier.setTransitAutoMode,
                  transitMaxCapacity: cal.transitMaxCapacity,
                  onTransitMaxCapacityChanged:
                      _calNotifier.setTransitMaxCapacity,
                  lightAutoMode: cal.lightAutoMode,
                  onLightAutoModeChanged: _calNotifier.setLightAutoMode,
                  lightAutoLabel: cal.lightAutoLabel,
                  onLightAutoLabelChanged: _calNotifier.setLightAutoLabel,
                ),
                if (_phase == _ScreenPhase.staged &&
                    _selectedVideoPath != null) ...[
                  const SizedBox(height: 24),
                  _StagedVideoCard(
                    filename: p.basename(_selectedVideoPath!),
                    thumbnail: _stagedThumbnail,
                    onStart: _startAnalysis,
                    onChooseDifferent: _clearStagedFile,
                    theme: theme,
                  ),
                ],
                if (_phase == _ScreenPhase.uploading) ...[
                  const SizedBox(height: 24),
                  _UploadingCard(theme: theme),
                ],
                if (_phase == _ScreenPhase.processing) ...[
                  const SizedBox(height: 24),
                  _ProcessingCard(theme: theme),
                ],
                if (_phase == _ScreenPhase.error) ...[
                  const SizedBox(height: 24),
                  _ErrorCard(
                    message: _errorMessage,
                    onRetry: _retry,
                    theme: theme,
                  ),
                ],
                if (_phase == _ScreenPhase.done && _result != null) ...[
                  const SizedBox(height: 24),
                  _TotalHero(
                    total: _result!.totalVehiclesCounted,
                    theme: theme,
                  ),
                  if (_result!.breakdown.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _BreakdownBarChart(
                      breakdown: _result!.breakdown,
                      theme: theme,
                    ),
                    const SizedBox(height: 16),
                    _BreakdownList(
                      breakdown: _result!.breakdown,
                      theme: theme,
                    ),
                  ],
                  if (_result!.twoWheelerBreakdown.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _TwoWheelerBreakdownList(
                      breakdown: _result!.twoWheelerBreakdown,
                      theme: theme,
                    ),
                  ],
                  if (cal.enabledTasks.contains(AnalysisTask.pedestrians)) ...[
                    const SizedBox(height: 16),
                    _PedestrianCard(
                      count: _result!.pedestriansCount,
                      theme: theme,
                    ),
                  ],
                  if (_result!.speed != null) ...[
                    const SizedBox(height: 16),
                    _SpeedCard(speed: _result!.speed!, theme: theme),
                  ],
                  if (_result!.transit != null) ...[
                    const SizedBox(height: 16),
                    _TransitCard(transit: _result!.transit!, theme: theme),
                  ],
                  if (_result!.trafficLights.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _TrafficLightCard(
                      lights: _result!.trafficLights,
                      theme: theme,
                    ),
                  ],
                  if (_result!.plateSummary != null ||
                      _result!.plates.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _PlatesCard(
                      summary: _result!.plateSummary,
                      plates: _result!.plates,
                      theme: theme,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _exportXlsx,
                    icon: const Icon(Icons.file_download),
                    label: Text(l10n.videoAnalysisExportCsv),
                  ),
                  if (_result!.hasClassifiedVideo) ...[
                    const SizedBox(height: 12),
                    _DownloadVideoButton(
                      isDownloading: _isDownloadingVideo,
                      progress: _downloadProgress,
                      label: l10n.videoAnalysisDownloadVideo,
                      onPressed: _downloadAnnotatedVideo,
                      onCancel: () => _downloadCancelToken?.cancel(),
                    ),
                  ],
                  if (_result!.hasTransitVideo) ...[
                    const SizedBox(height: 12),
                    _DownloadVideoButton(
                      isDownloading: _isDownloadingVideo,
                      progress: _downloadProgress,
                      label: l10n.videoAnalysisDownloadTransitVideo,
                      onPressed: () =>
                          _downloadAnnotatedVideo(kind: 'transit'),
                      onCancel: () => _downloadCancelToken?.cancel(),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Picker card
// ---------------------------------------------------------------------------

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.isUploading,
    required this.onPickGallery,
    required this.onRecordCamera,
    required this.onApplyBusStopPreset,
    required this.includeAnnotatedVideo,
    required this.onIncludeAnnotatedVideoChanged,
    required this.enabledTasks,
    required this.onTaskToggled,
    required this.trafficLightConfigured,
    required this.onConfigureTrafficLight,
    required this.speedConfigured,
    required this.onConfigureSpeed,
    required this.transitConfigured,
    required this.onConfigureTransit,
    required this.countLineConfigured,
    required this.onConfigureCountLine,
    required this.lprAllowlistCount,
    required this.onConfigureLprAllowlist,
    required this.transitAutoMode,
    required this.onTransitAutoModeChanged,
    required this.transitMaxCapacity,
    required this.onTransitMaxCapacityChanged,
    required this.lightAutoMode,
    required this.onLightAutoModeChanged,
    required this.lightAutoLabel,
    required this.onLightAutoLabelChanged,
  });

  final bool isUploading;
  final VoidCallback onPickGallery;
  final VoidCallback onRecordCamera;
  final VoidCallback onApplyBusStopPreset;
  final bool includeAnnotatedVideo;
  final ValueChanged<bool> onIncludeAnnotatedVideoChanged;
  final Set<String> enabledTasks;
  /// Fires for every selectable task (`AnalysisTask.selectable`),
  /// including `vehicles` which is now operator-controllable.
  final void Function(String task, bool enabled) onTaskToggled;
  final bool trafficLightConfigured;
  final VoidCallback onConfigureTrafficLight;
  final bool speedConfigured;
  final VoidCallback onConfigureSpeed;
  final bool transitConfigured;
  final VoidCallback onConfigureTransit;
  final bool countLineConfigured;
  final VoidCallback onConfigureCountLine;
  final int lprAllowlistCount;
  final VoidCallback onConfigureLprAllowlist;
  final bool transitAutoMode;
  final ValueChanged<bool> onTransitAutoModeChanged;
  final int transitMaxCapacity;
  final ValueChanged<int> onTransitMaxCapacityChanged;
  final bool lightAutoMode;
  final ValueChanged<bool> onLightAutoModeChanged;
  final String lightAutoLabel;
  final ValueChanged<String> onLightAutoLabelChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.videoAnalysisCloud,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.videoAnalysisDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: includeAnnotatedVideo,
              onChanged:
                  isUploading ? null : onIncludeAnnotatedVideoChanged,
              title: Text(l10n.videoAnalysisIncludeAnnotatedVideo),
              subtitle: Text(
                l10n.videoAnalysisIncludeAnnotatedVideoHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 8),
            // One-tap "this clip is a bus stop" shortcut. Disables vehicle
            // counting and enables transit + pedestrians so the most common
            // pedestrian-only scenario is reachable without 3-4 toggles.
            OutlinedButton.icon(
              onPressed: isUploading ? null : onApplyBusStopPreset,
              icon: const Icon(Icons.directions_bus_filled_outlined),
              label: Text(l10n.videoAnalysisBusStopPreset),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.videoAnalysisBusStopPresetHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _TasksToRunPanel(
              isUploading: isUploading,
              enabledTasks: enabledTasks,
              onTaskToggled: onTaskToggled,
              theme: theme,
              trafficLightConfigured: trafficLightConfigured,
              onConfigureTrafficLight: onConfigureTrafficLight,
              speedConfigured: speedConfigured,
              onConfigureSpeed: onConfigureSpeed,
              transitConfigured: transitConfigured,
              onConfigureTransit: onConfigureTransit,
              countLineConfigured: countLineConfigured,
              onConfigureCountLine: onConfigureCountLine,
              lprAllowlistCount: lprAllowlistCount,
              onConfigureLprAllowlist: onConfigureLprAllowlist,
              transitAutoMode: transitAutoMode,
              onTransitAutoModeChanged: onTransitAutoModeChanged,
              transitMaxCapacity: transitMaxCapacity,
              onTransitMaxCapacityChanged: onTransitMaxCapacityChanged,
              lightAutoMode: lightAutoMode,
              onLightAutoModeChanged: onLightAutoModeChanged,
              lightAutoLabel: lightAutoLabel,
              onLightAutoLabelChanged: onLightAutoLabelChanged,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isUploading ? null : onPickGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l10n.videoAnalysisGallery),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isUploading ? null : onRecordCamera,
                    icon: const Icon(Icons.videocam_outlined),
                    label: Text(l10n.videoAnalysisRecord),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Staged-file card — shown after the operator picks a video, BEFORE
// upload starts. Surfaces a thumbnail + filename + start/cancel buttons
// so calibration and task toggles can be reviewed first.
// ---------------------------------------------------------------------------

class _StagedVideoCard extends StatelessWidget {
  const _StagedVideoCard({
    required this.filename,
    required this.thumbnail,
    required this.onStart,
    required this.onChooseDifferent,
    required this.theme,
  });

  final String filename;
  final Uint8List? thumbnail;
  final VoidCallback onStart;
  final VoidCallback onChooseDifferent;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (thumbnail != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.memory(
                    thumbnail!,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.movie_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              l10n.videoAnalysisStagedFile(filename),
              style: theme.textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.videoAnalysisStagedHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.videoAnalysisStartAnalysis),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onChooseDifferent,
              icon: const Icon(Icons.swap_horiz),
              label: Text(l10n.videoAnalysisChooseDifferentFile),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Annotated-video download button (with progress + cancel)
// ---------------------------------------------------------------------------

class _DownloadVideoButton extends StatelessWidget {
  const _DownloadVideoButton({
    required this.isDownloading,
    required this.progress,
    required this.label,
    required this.onPressed,
    required this.onCancel,
  });

  final bool isDownloading;
  // null when total is unknown (no Content-Length) — we show an
  // indeterminate progress bar in that case.
  final double? progress;
  final String label;
  final VoidCallback onPressed;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!isDownloading) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.movie_filter_outlined),
        label: Text(label),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.videoAnalysisDownloadingVideo)),
            TextButton(
              onPressed: onCancel,
              child: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Uploading / processing indicator
// ---------------------------------------------------------------------------

class _UploadingCard extends StatelessWidget {
  const _UploadingCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).videoAnalysisUploading,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).videoAnalysisUploadingHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Server-side processing indicator (polling phase)
// ---------------------------------------------------------------------------

class _ProcessingCard extends StatelessWidget {
  const _ProcessingCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).videoAnalysisProcessing,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).videoAnalysisProcessingHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error card with retry
// ---------------------------------------------------------------------------

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
    required this.theme,
  });

  final String message;
  final VoidCallback onRetry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context).videoAnalysisRetry),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Total hero
// ---------------------------------------------------------------------------

class _TotalHero extends StatelessWidget {
  const _TotalHero({required this.total, required this.theme});

  final int total;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            Icon(
              Icons.directions_car,
              size: 36,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              '$total',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).videoAnalysisTotalCounted,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Horizontal bar chart (fl_chart)
// ---------------------------------------------------------------------------

const _chartPalette = AppColors.chartPalette;

class _BreakdownBarChart extends StatelessWidget {
  const _BreakdownBarChart({required this.breakdown, required this.theme});

  final List<VideoAnalysisBreakdownEntry> breakdown;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final maxCount = breakdown.fold<int>(
      0,
      (m, e) => e.count > m ? e.count : m,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).videoAnalysisBreakdown, style: theme.textTheme.titleSmall),
            const SizedBox(height: 20),
            ...List.generate(breakdown.length, (i) {
              final entry = breakdown[i];
              final fraction = maxCount > 0 ? entry.count / maxCount : 0.0;
              final color = _chartPalette[i % _chartPalette.length];

              return Padding(
                padding: EdgeInsets.only(
                  bottom: i < breakdown.length - 1 ? 12 : 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.label,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.count}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 14,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact breakdown list
// ---------------------------------------------------------------------------

class _BreakdownList extends StatelessWidget {
  const _BreakdownList({required this.breakdown, required this.theme});

  final List<VideoAnalysisBreakdownEntry> breakdown;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: List.generate(breakdown.length, (i) {
            final entry = breakdown[i];
            final color = _chartPalette[i % _chartPalette.length];
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 6,
                backgroundColor: color,
              ),
              title: Text(
                entry.label,
                style: theme.textTheme.bodyMedium,
              ),
              trailing: Text(
                '${entry.count}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2-wheeler breakdown list
// ---------------------------------------------------------------------------

class _TwoWheelerBreakdownList extends StatelessWidget {
  const _TwoWheelerBreakdownList({
    required this.breakdown,
    required this.theme,
  });

  final List<VideoAnalysisBreakdownEntry> breakdown;
  final ThemeData theme;

  IconData _iconFor(String label) {
    switch (label) {
      case 'Bicycle':
        return Icons.pedal_bike;
      case 'Motorcycle':
        return Icons.two_wheeler;
      case 'Personal Mobility':
        return Icons.electric_scooter;
      default:
        return Icons.directions_bike;
    }
  }

  String _koreanFor(String label) {
    switch (label) {
      case 'Bicycle':
        return '자전거';
      case 'Motorcycle':
        return '오토바이';
      case 'Personal Mobility':
        return 'PM / 킥보드';
      default:
        return label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = breakdown.fold<int>(0, (s, e) => s + e.count);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.two_wheeler, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '2륜차',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '$total',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...breakdown.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _iconFor(entry.label),
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _koreanFor(entry.label),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${entry.count}',
                      style: theme.textTheme.bodyMedium?.copyWith(
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
    );
  }
}

// ---------------------------------------------------------------------------
// XLSX export — results template builder
// ---------------------------------------------------------------------------

/// 6종 + 이륜 categories used in the Korean traffic count results template.
enum _TemplateCategory {
  passenger,
  busSmall,
  busLarge,
  truckSmall,
  truckMid,
  truckTrailer,
  motorcycle,
}

double _pcuFactor(_TemplateCategory c) {
  switch (c) {
    case _TemplateCategory.passenger:
      return 1.0;
    case _TemplateCategory.busSmall:
      return 1.5;
    case _TemplateCategory.busLarge:
      return 2.0;
    case _TemplateCategory.truckSmall:
      return 1.0;
    case _TemplateCategory.truckMid:
      return 1.5;
    case _TemplateCategory.truckTrailer:
      return 2.5;
    case _TemplateCategory.motorcycle:
      return 0.5;
  }
}

/// Maps a server-provided breakdown label (e.g. `Class 1 (Passenger/Van)`,
/// `Motorcycle`) to a template category. Returns `null` if no rule matches.
_TemplateCategory? _categorize(String label) {
  final l = label.toLowerCase();

  if (l.contains('motorcycle') || l.contains('이륜')) {
    return _TemplateCategory.motorcycle;
  }
  if (l.contains('passenger') || l.startsWith('class 1')) {
    return _TemplateCategory.passenger;
  }
  if (l.contains('bus') || l.startsWith('class 2')) {
    return _TemplateCategory.busLarge;
  }
  if (l.contains('<2.5t') ||
      l.contains('< 2.5t') ||
      l.startsWith('class 3')) {
    return _TemplateCategory.truckSmall;
  }
  if (l.contains('>=2.5t') ||
      l.contains('>= 2.5t') ||
      l.contains('2.5-8.5t') ||
      l.startsWith('class 4')) {
    return _TemplateCategory.truckMid;
  }
  // Class 5..12 are multi-axle / trailer / semi categories.
  final m = RegExp(r'^class\s+(\d+)').firstMatch(l);
  if (m != null) {
    final n = int.tryParse(m.group(1)!);
    if (n != null && n >= 5) return _TemplateCategory.truckTrailer;
  }
  return null;
}

/// Rounds [t] down to the nearest 15-minute boundary.
DateTime _floorTo15Min(DateTime t) {
  final minute = (t.minute ~/ 15) * 15;
  return DateTime(t.year, t.month, t.day, t.hour, minute);
}

String _formatBucket(DateTime start) {
  final end = start.add(const Duration(minutes: 15));
  final fmt = DateFormat('HH:mm');
  return ' ${fmt.format(start)}-${fmt.format(end)}';
}

class _ResultsTemplateBuilder {
  _ResultsTemplateBuilder({
    required this.sheet,
    required this.siteId,
    required this.breakdown,
    required this.analysisStartedAt,
  });

  final xl.Sheet sheet;
  final String siteId;
  final List<VideoAnalysisBreakdownEntry> breakdown;
  final DateTime? analysisStartedAt;

  /// Number of direction blocks (only direction 1 carries data; 2-4 are zeros).
  static const int _directionCount = 4;

  /// Columns per direction block: 승용 | 버스 소형 | 버스 대형 | 화물 소형 |
  /// 화물 중.대 | 화물 트레일 | 소계 대 | 소계 PCU | 이륜
  static const int _colsPerDirection = 9;

  static const List<_TemplateCategory> _classCols = [
    _TemplateCategory.passenger,
    _TemplateCategory.busSmall,
    _TemplateCategory.busLarge,
    _TemplateCategory.truckSmall,
    _TemplateCategory.truckMid,
    _TemplateCategory.truckTrailer,
  ];

  void build() {
    final counts = _aggregateCounts();
    final bucketStart = _floorTo15Min(analysisStartedAt ?? DateTime.now());
    final hourStart = DateTime(
      bucketStart.year,
      bucketStart.month,
      bucketStart.day,
      bucketStart.hour,
    );

    _writeTitleRow();
    _writeDirectionMarkerRow();
    _writeCategoryHeaderRow();
    _writeSubcategoryHeaderRow();
    _writeHourBlock(hourStart, bucketStart, counts);
  }

  Map<_TemplateCategory, int> _aggregateCounts() {
    final out = <_TemplateCategory, int>{};
    for (final entry in breakdown) {
      final cat = _categorize(entry.label);
      if (cat == null) continue;
      out[cat] = (out[cat] ?? 0) + entry.count;
    }
    return out;
  }

  void _writeTitleRow() {
    final row = <xl.CellValue?>[xl.TextCellValue(siteId)];
    _padRow(row);
    sheet.appendRow(row);
  }

  void _writeDirectionMarkerRow() {
    final row = <xl.CellValue?>[null];
    for (var d = 1; d <= _directionCount; d++) {
      // Direction marker sits on the first count column of each block;
      // the time-bucket column (col 0) is shared, so each block starts at
      // 1 + (d-1) * _colsPerDirection.
      for (var c = 0; c < _colsPerDirection; c++) {
        if (c == 0) {
          row.add(xl.IntCellValue(d));
        } else {
          row.add(null);
        }
      }
    }
    sheet.appendRow(row);
  }

  void _writeCategoryHeaderRow() {
    final headers = <xl.CellValue?>[xl.TextCellValue('  시 간 대')];
    for (var d = 0; d < _directionCount; d++) {
      headers.addAll(const <xl.CellValue?>[]);
      headers.add(xl.TextCellValue('소형'));
      headers.add(xl.TextCellValue('버스'));
      headers.add(null); // 버스 대형 spans w/ 소형 visually; keep blank
      headers.add(xl.TextCellValue('화물'));
      headers.add(null); // 중.대
      headers.add(null); // 트레일
      headers.add(xl.TextCellValue('소  계'));
      headers.add(null); // PCU
      headers.add(xl.TextCellValue('이륜'));
    }
    sheet.appendRow(headers);
  }

  void _writeSubcategoryHeaderRow() {
    final row = <xl.CellValue?>[null];
    for (var d = 0; d < _directionCount; d++) {
      row.add(xl.TextCellValue('승용'));
      row.add(xl.TextCellValue('소형'));
      row.add(xl.TextCellValue('대형'));
      row.add(xl.TextCellValue('소형'));
      row.add(xl.TextCellValue('중.대'));
      row.add(xl.TextCellValue('트레일'));
      row.add(xl.TextCellValue('대'));
      row.add(xl.TextCellValue('PCU'));
      row.add(null);
    }
    sheet.appendRow(row);
  }

  /// Writes 4 bucket rows + 계(대) row + 보정교통량 row for one hour.
  void _writeHourBlock(
    DateTime hourStart,
    DateTime dataBucketStart,
    Map<_TemplateCategory, int> counts,
  ) {
    final bucketTotals = <int>[]; // total 대 per 15-min bucket (direction 1)

    for (var i = 0; i < 4; i++) {
      final bucket = hourStart.add(Duration(minutes: 15 * i));
      final isDataBucket = bucket == dataBucketStart;
      final bucketCounts = isDataBucket
          ? counts
          : const <_TemplateCategory, int>{};
      final row = _buildBucketRow(bucket, bucketCounts);
      sheet.appendRow(row);
      bucketTotals.add(_subtotalCount(bucketCounts));
    }

    // 계(대) row — summed across the four 15-min buckets.
    final summed = Map<_TemplateCategory, int>.from(counts);
    sheet.appendRow(_buildSumRow(summed));

    // 보정교통량 row — PHF = hour total / (4 * peak 15-min).
    final hourTotal = _subtotalCount(summed);
    final peakBucketTotal = bucketTotals.fold<int>(
      0,
      (m, v) => v > m ? v : m,
    );
    final phf = peakBucketTotal == 0
        ? 0.0
        : hourTotal / (4 * peakBucketTotal);
    final hourPcu = _subtotalPcu(summed);
    sheet.appendRow(_buildPhfRow(phf, hourTotal, hourPcu));
  }

  List<xl.CellValue?> _buildBucketRow(
    DateTime bucketStart,
    Map<_TemplateCategory, int> counts,
  ) {
    final row = <xl.CellValue?>[xl.TextCellValue(_formatBucket(bucketStart))];
    for (var d = 0; d < _directionCount; d++) {
      // Only direction 1 carries data; others are zeros.
      final blockCounts =
          d == 0 ? counts : const <_TemplateCategory, int>{};
      _appendDirectionBlock(row, blockCounts);
    }
    return row;
  }

  List<xl.CellValue?> _buildSumRow(Map<_TemplateCategory, int> counts) {
    final row = <xl.CellValue?>[xl.TextCellValue('    계(대)')];
    for (var d = 0; d < _directionCount; d++) {
      final blockCounts =
          d == 0 ? counts : const <_TemplateCategory, int>{};
      _appendDirectionBlock(row, blockCounts);
    }
    return row;
  }

  /// 보정교통량 row mimics the template: most cells empty, PHF=, then hour
  /// totals in the 소계 columns.
  List<xl.CellValue?> _buildPhfRow(double phf, int hourTotal, double hourPcu) {
    final row = <xl.CellValue?>[xl.TextCellValue(' 보정교통량')];
    for (var d = 0; d < _directionCount; d++) {
      // Direction 1 holds the PHF/totals; others stay blank.
      if (d == 0) {
        row.add(null); // 승용
        row.add(null); // 버스 소형
        row.add(null); // 버스 대형
        row.add(xl.TextCellValue(' PHF='));
        row.add(xl.DoubleCellValue(double.parse(phf.toStringAsFixed(2))));
        row.add(null); // 트레일
        row.add(xl.IntCellValue(hourTotal));
        row.add(xl.DoubleCellValue(double.parse(hourPcu.toStringAsFixed(1))));
        row.add(null); // 이륜
      } else {
        for (var c = 0; c < _colsPerDirection; c++) {
          row.add(null);
        }
      }
    }
    return row;
  }

  void _appendDirectionBlock(
    List<xl.CellValue?> row,
    Map<_TemplateCategory, int> counts,
  ) {
    for (final cat in _classCols) {
      row.add(xl.IntCellValue(counts[cat] ?? 0));
    }
    row.add(xl.IntCellValue(_subtotalCount(counts)));
    row.add(xl.DoubleCellValue(
      double.parse(_subtotalPcu(counts).toStringAsFixed(1)),
    ));
    row.add(xl.IntCellValue(counts[_TemplateCategory.motorcycle] ?? 0));
  }

  int _subtotalCount(Map<_TemplateCategory, int> counts) {
    var sum = 0;
    for (final cat in _TemplateCategory.values) {
      sum += counts[cat] ?? 0;
    }
    return sum;
  }

  double _subtotalPcu(Map<_TemplateCategory, int> counts) {
    var sum = 0.0;
    for (final cat in _TemplateCategory.values) {
      sum += (counts[cat] ?? 0) * _pcuFactor(cat);
    }
    return sum;
  }

  /// Pads a row with `null` cells so the title row spans the full sheet width.
  void _padRow(List<xl.CellValue?> row) {
    final totalCols = 1 + _directionCount * _colsPerDirection;
    while (row.length < totalCols) {
      row.add(null);
    }
  }
}

// ===========================================================================
// Tasks-to-run panel — checkboxes building the calibration JSON
// ===========================================================================

class _TasksToRunPanel extends StatelessWidget {
  const _TasksToRunPanel({
    required this.isUploading,
    required this.enabledTasks,
    required this.onTaskToggled,
    required this.theme,
    required this.trafficLightConfigured,
    required this.onConfigureTrafficLight,
    required this.speedConfigured,
    required this.onConfigureSpeed,
    required this.transitConfigured,
    required this.onConfigureTransit,
    required this.countLineConfigured,
    required this.onConfigureCountLine,
    required this.lprAllowlistCount,
    required this.onConfigureLprAllowlist,
    required this.transitAutoMode,
    required this.onTransitAutoModeChanged,
    required this.transitMaxCapacity,
    required this.onTransitMaxCapacityChanged,
    required this.lightAutoMode,
    required this.onLightAutoModeChanged,
    required this.lightAutoLabel,
    required this.onLightAutoLabelChanged,
  });

  final bool isUploading;
  final Set<String> enabledTasks;
  final void Function(String task, bool enabled) onTaskToggled;
  final ThemeData theme;
  final bool trafficLightConfigured;
  final VoidCallback onConfigureTrafficLight;
  final bool speedConfigured;
  final VoidCallback onConfigureSpeed;
  final bool transitConfigured;
  final VoidCallback onConfigureTransit;
  final bool countLineConfigured;
  final VoidCallback onConfigureCountLine;
  final int lprAllowlistCount;
  final VoidCallback onConfigureLprAllowlist;
  final bool transitAutoMode;
  final ValueChanged<bool> onTransitAutoModeChanged;
  final int transitMaxCapacity;
  final ValueChanged<int> onTransitMaxCapacityChanged;
  final bool lightAutoMode;
  final ValueChanged<bool> onLightAutoModeChanged;
  final String lightAutoLabel;
  final ValueChanged<String> onLightAutoLabelChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      initiallyExpanded: false,
      title: Text(l10n.videoAnalysisTasksTitle),
      subtitle: Text(
        l10n.videoAnalysisTasksHint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      children: [
        _taskTile(
          l10n.videoAnalysisTaskVehicles,
          task: AnalysisTask.vehicles,
          trailing: enabledTasks.contains(AnalysisTask.vehicles)
              ? _ConfigureChip(
                  label: l10n.videoAnalysisCountLineConfigure,
                  configured: countLineConfigured,
                  onTap: isUploading ? null : onConfigureCountLine,
                )
              : null,
        ),
        _taskTile(
          l10n.videoAnalysisTaskPedestrians,
          task: AnalysisTask.pedestrians,
        ),
        _taskTile(
          l10n.videoAnalysisTaskSpeed,
          task: AnalysisTask.speed,
          trailing: enabledTasks.contains(AnalysisTask.speed)
              ? _ConfigureChip(
                  label: l10n.videoAnalysisConfigure,
                  configured: speedConfigured,
                  onTap: isUploading ? null : onConfigureSpeed,
                )
              : null,
        ),
        _taskTile(
          l10n.videoAnalysisTaskTransit,
          task: AnalysisTask.transit,
          trailing: enabledTasks.contains(AnalysisTask.transit)
              ? _AutoManualToggle(
                  isAuto: transitAutoMode,
                  onChanged:
                      isUploading ? null : onTransitAutoModeChanged,
                  manualLabel: l10n.videoAnalysisConfigure,
                  configured: transitConfigured,
                  onConfigureManual:
                      isUploading ? null : onConfigureTransit,
                )
              : null,
        ),
        if (enabledTasks.contains(AnalysisTask.transit) && transitAutoMode)
          _AutoTransitRow(
            theme: theme,
            maxCapacity: transitMaxCapacity,
            onMaxCapacityChanged: onTransitMaxCapacityChanged,
            isUploading: isUploading,
          ),
        _taskTile(
          l10n.videoAnalysisTaskTrafficLight,
          task: AnalysisTask.trafficLight,
          trailing: enabledTasks.contains(AnalysisTask.trafficLight)
              ? _AutoManualToggle(
                  isAuto: lightAutoMode,
                  onChanged:
                      isUploading ? null : onLightAutoModeChanged,
                  manualLabel: l10n.videoAnalysisConfigure,
                  configured: trafficLightConfigured,
                  onConfigureManual:
                      isUploading ? null : onConfigureTrafficLight,
                )
              : null,
        ),
        if (enabledTasks.contains(AnalysisTask.trafficLight) && lightAutoMode)
          _AutoLightRow(
            theme: theme,
            label: lightAutoLabel,
            onLabelChanged: onLightAutoLabelChanged,
            isUploading: isUploading,
          ),
        _taskTile(
          l10n.videoAnalysisTaskLpr,
          task: AnalysisTask.lpr,
          trailing: enabledTasks.contains(AnalysisTask.lpr)
              ? _ConfigureChip(
                  label: l10n.lprAllowlistConfigure,
                  configured: lprAllowlistCount > 0,
                  badge: lprAllowlistCount > 0 ? '$lprAllowlistCount' : null,
                  onTap: isUploading ? null : onConfigureLprAllowlist,
                )
              : null,
        ),
      ],
    );
  }

  Widget _taskTile(
    String label, {
    String? task,
    Widget? trailing,
  }) {
    final isOn = task != null && enabledTasks.contains(task);
    return CheckboxListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: isOn,
      onChanged: (isUploading || task == null)
          ? null
          : (v) => onTaskToggled(task, v ?? false),
      title: Text(label),
      secondary: trailing,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

/// Auto / Manual selector shown next to the transit and traffic-light
/// checkboxes. Auto mode hides the geometry editor and lets the server
/// VLM auto-detect ROIs from a keyframe; manual mode reveals a Configure
/// chip that opens the existing per-task editor.
class _AutoManualToggle extends StatelessWidget {
  const _AutoManualToggle({
    required this.isAuto,
    required this.onChanged,
    required this.manualLabel,
    required this.configured,
    required this.onConfigureManual,
  });

  final bool isAuto;
  final ValueChanged<bool>? onChanged;
  final String manualLabel;
  final bool configured;
  final VoidCallback? onConfigureManual;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Compact toggle: tap "자동" or "수동" to switch. Visual emphasis on
        // current selection mirrors a SegmentedButton without taking up
        // its full width inside the task tile.
        _ModeChip(
          label: l10n.calibrationModeAuto,
          icon: Icons.auto_awesome,
          selected: isAuto,
          onTap: onChanged == null ? null : () => onChanged!(true),
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 4),
        _ModeChip(
          label: l10n.calibrationModeManual,
          icon: Icons.tune,
          selected: !isAuto,
          onTap: onChanged == null ? null : () => onChanged!(false),
          color: theme.colorScheme.primary,
        ),
        if (!isAuto) ...[
          const SizedBox(width: 4),
          _ConfigureChip(
            label: manualLabel,
            configured: configured,
            onTap: onConfigureManual,
          ),
        ],
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? color.withValues(alpha: 0.15) : null,
          border: Border.all(
            color: selected
                ? color
                : theme.colorScheme.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? color : null),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? color : null,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline panel shown under the Transit task tile when auto mode is on.
/// Collects the only piece of info the AI can't infer (max capacity) and
/// surfaces a help card explaining what the AI is going to do.
class _AutoTransitRow extends StatefulWidget {
  const _AutoTransitRow({
    required this.theme,
    required this.maxCapacity,
    required this.onMaxCapacityChanged,
    required this.isUploading,
  });

  final ThemeData theme;
  final int maxCapacity;
  final ValueChanged<int> onMaxCapacityChanged;
  final bool isUploading;

  @override
  State<_AutoTransitRow> createState() => _AutoTransitRowState();
}

class _AutoTransitRowState extends State<_AutoTransitRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.maxCapacity.toString());
  }

  @override
  void didUpdateWidget(covariant _AutoTransitRow old) {
    super.didUpdateWidget(old);
    // Keep the field in sync when the parent reset the calibration
    // (e.g. via the "Reset site calibration" action).
    if (widget.maxCapacity.toString() != _ctrl.text) {
      _ctrl.text = widget.maxCapacity.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.transitAutoModeBody,
            style: widget.theme.textTheme.bodySmall?.copyWith(
              color: widget.theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.number,
                  enabled: !widget.isUploading,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.transitEditorCapacity,
                    helperText: l10n.transitEditorCapacityHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) {
                      widget.onMaxCapacityChanged(n);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Inline panel shown under the Traffic-light task tile when auto mode
/// is on. Collects only the label (used to disambiguate when there are
/// multiple lights in the report).
class _AutoLightRow extends StatefulWidget {
  const _AutoLightRow({
    required this.theme,
    required this.label,
    required this.onLabelChanged,
    required this.isUploading,
  });

  final ThemeData theme;
  final String label;
  final ValueChanged<String> onLabelChanged;
  final bool isUploading;

  @override
  State<_AutoLightRow> createState() => _AutoLightRowState();
}

class _AutoLightRowState extends State<_AutoLightRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.label);
  }

  @override
  void didUpdateWidget(covariant _AutoLightRow old) {
    super.didUpdateWidget(old);
    if (widget.label != _ctrl.text) {
      _ctrl.text = widget.label;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.lightAutoModeBody,
            style: widget.theme.textTheme.bodySmall?.copyWith(
              color: widget.theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            enabled: !widget.isUploading,
            decoration: InputDecoration(
              labelText: l10n.lightAutoLabelField,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) {
              final trimmed = v.trim();
              if (trimmed.isNotEmpty) {
                widget.onLabelChanged(trimmed);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Configure / Manage button shown next to a task checkbox once it's
/// enabled. Renders a check-icon prefix when an override is set, so the
/// operator sees at a glance whether they've customised that task.
class _ConfigureChip extends StatelessWidget {
  const _ConfigureChip({
    required this.label,
    required this.configured,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool configured;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(
        configured ? Icons.check_circle : Icons.tune,
        size: 18,
        color:
            configured ? AppColors.success : theme.colorScheme.primary,
      ),
      label: Text(badge != null ? '$label · $badge' : label),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// ===========================================================================
// F2 — Pedestrian count card
// ===========================================================================

class _PedestrianCard extends StatelessWidget {
  const _PedestrianCard({required this.count, required this.theme});

  final int count;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_walk, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.videoAnalysisPedestrianTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.videoAnalysisPedestrianCount(count),
              style: theme.textTheme.headlineSmall,
            ),
            if (count == 0) ...[
              const SizedBox(height: 4),
              Text(
                l10n.videoAnalysisPedestrianDetectorOff,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// F4 — Speed card
// ===========================================================================

class _SpeedCard extends StatelessWidget {
  const _SpeedCard({required this.speed, required this.theme});

  final VideoAnalysisSpeed speed;
  final ThemeData theme;

  String _kmh(BuildContext context, double? v) {
    final l10n = AppLocalizations.of(context);
    if (v == null) return '—';
    return l10n.videoAnalysisSpeedKmh(v.toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasMeasurements = speed.vehiclesMeasured > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.videoAnalysisSpeedTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasMeasurements)
              Text(
                l10n.videoAnalysisSpeedNoMeasurements,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              Text(
                l10n.videoAnalysisSpeedMeasured(speed.vehiclesMeasured),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SpeedStat(
                    label: l10n.videoAnalysisSpeedAvg,
                    value: _kmh(context, speed.avgKmh),
                    theme: theme,
                    emphasized: true,
                  ),
                  _SpeedStat(
                    label: l10n.videoAnalysisSpeedMin,
                    value: _kmh(context, speed.minKmh),
                    theme: theme,
                  ),
                  _SpeedStat(
                    label: l10n.videoAnalysisSpeedMax,
                    value: _kmh(context, speed.maxKmh),
                    theme: theme,
                  ),
                ],
              ),
              if (speed.perTrack.isNotEmpty) ...[
                const Divider(height: 32),
                Text(
                  l10n.videoAnalysisSpeedPerTrack,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ..._sortedPerTrack(speed.perTrack).map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.videoAnalysisSpeedTrackRow(e.key),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          _kmh(context, e.value),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Sort by km/h descending so the fastest vehicles surface first —
  /// typical speed-enforcement workflow looks for the top-N.
  List<MapEntry<String, double>> _sortedPerTrack(Map<String, double> m) {
    final entries = m.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}

class _SpeedStat extends StatelessWidget {
  const _SpeedStat({
    required this.label,
    required this.value,
    required this.theme,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final ThemeData theme;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: emphasized
              ? theme.textTheme.titleLarge
              : theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}

// ===========================================================================
// F6 — Transit card (boarding / alighting / density)
// ===========================================================================

class _TransitCard extends StatelessWidget {
  const _TransitCard({required this.transit, required this.theme});

  final VideoAnalysisTransit transit;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Use semantically-distinct colours for boarding (positive / inflow)
    // vs alighting (departure / outflow). Matches transit-domain
    // convention (green=ON, red=OFF) and the planned video overlay.
    const boardingColor = AppColors.success;
    const alightingColor = AppColors.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.videoAnalysisTransitTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TransitMetric(
                    label: l10n.videoAnalysisTransitBoarding,
                    value: transit.boarding.toString(),
                    color: boardingColor,
                    icon: Icons.arrow_circle_up,
                    theme: theme,
                  ),
                ),
                Expanded(
                  child: _TransitMetric(
                    label: l10n.videoAnalysisTransitAlighting,
                    value: transit.alighting.toString(),
                    color: alightingColor,
                    icon: Icons.arrow_circle_down,
                    theme: theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TransitMetric(
                    label: l10n.videoAnalysisTransitPeak,
                    value: transit.peakCount.toString(),
                    color: theme.colorScheme.primary,
                    icon: Icons.groups,
                    theme: theme,
                  ),
                ),
                Expanded(
                  child: _TransitMetric(
                    label: l10n.videoAnalysisTransitDensity,
                    value: l10n.videoAnalysisTransitDensityValue(
                      transit.avgDensityPct.toStringAsFixed(1),
                    ),
                    color: theme.colorScheme.tertiary,
                    icon: Icons.density_medium,
                    theme: theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              transit.busGated
                  ? l10n.videoAnalysisTransitBusGated
                  : l10n.videoAnalysisTransitNotGated,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransitMetric extends StatelessWidget {
  const _TransitMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.theme,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(value, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// F7 — Traffic-light timing card (one block per signal head)
// ===========================================================================

class _TrafficLightCard extends StatelessWidget {
  const _TrafficLightCard({required this.lights, required this.theme});

  final List<VideoAnalysisTrafficLight> lights;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.traffic, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.videoAnalysisTrafficLightTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            for (final light in lights) ...[
              const SizedBox(height: 16),
              Text(
                l10n.videoAnalysisTrafficLightLabel(light.label),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _TrafficLightTable(light: light, theme: theme),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrafficLightTable extends StatelessWidget {
  const _TrafficLightTable({required this.light, required this.theme});

  final VideoAnalysisTrafficLight light;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final headerStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    String secs(double v) =>
        l10n.videoAnalysisTrafficLightSeconds(v.toStringAsFixed(1));

    final rows = <_TrafficLightRow>[
      _TrafficLightRow(
        label: l10n.videoAnalysisTrafficLightRed,
        color: AppColors.error,
        cycle: light.red,
      ),
      _TrafficLightRow(
        label: l10n.videoAnalysisTrafficLightYellow,
        color: AppColors.warning,
        cycle: light.yellow,
      ),
      _TrafficLightRow(
        label: l10n.videoAnalysisTrafficLightGreen,
        color: AppColors.success,
        cycle: light.green,
      ),
    ];

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1.4),
        3: FlexColumnWidth(1.4),
      },
      children: [
        TableRow(
          children: [
            const SizedBox.shrink(),
            Text(
              l10n.videoAnalysisTrafficLightCycles,
              style: headerStyle,
              textAlign: TextAlign.right,
            ),
            Text(
              l10n.videoAnalysisTrafficLightAvgDuration,
              style: headerStyle,
              textAlign: TextAlign.right,
            ),
            Text(
              l10n.videoAnalysisTrafficLightTotalDuration,
              style: headerStyle,
              textAlign: TextAlign.right,
            ),
          ],
        ),
        for (final r in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: r.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(r.label, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  r.cycle.cycles.toString(),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  secs(r.cycle.avgDurationS),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  secs(r.cycle.totalDurationS),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _TrafficLightRow {
  const _TrafficLightRow({
    required this.label,
    required this.color,
    required this.cycle,
  });
  final String label;
  final Color color;
  final VideoAnalysisTrafficLightCycle cycle;
}

// ===========================================================================
// F5 — License plates card (resident vs visitor)
// ===========================================================================

class _PlatesCard extends StatelessWidget {
  const _PlatesCard({
    required this.summary,
    required this.plates,
    required this.theme,
  });

  final VideoAnalysisPlateSummary? summary;
  final List<VideoAnalysisPlate> plates;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const residentColor = AppColors.success;
    final visitorColor = theme.colorScheme.tertiary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.no_crash, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.videoAnalysisLprTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            if (summary != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TransitMetric(
                      label: l10n.videoAnalysisLprResident,
                      value: summary!.resident.toString(),
                      color: residentColor,
                      icon: Icons.home,
                      theme: theme,
                    ),
                  ),
                  Expanded(
                    child: _TransitMetric(
                      label: l10n.videoAnalysisLprVisitor,
                      value: summary!.visitor.toString(),
                      color: visitorColor,
                      icon: Icons.person_outline,
                      theme: theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.videoAnalysisLprAllowlistSize(summary!.allowlistSize),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (summary!.privacyHashed) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.videoAnalysisLprPrivacyHashed,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
            if (plates.isNotEmpty) ...[
              const Divider(height: 32),
              for (final p in plates)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: p.category == 'resident'
                              ? residentColor.withValues(alpha: 0.15)
                              : visitorColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          p.category == 'resident'
                              ? l10n.videoAnalysisLprResident
                              : l10n.videoAnalysisLprVisitor,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: p.category == 'resident'
                                ? residentColor
                                : visitorColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          // Plate text when present, otherwise the hash
                          // prefix. Privacy mode keeps PII out of the UI.
                          p.text != null
                              ? '${l10n.videoAnalysisLprPlatePrefix}: ${p.text}'
                              : p.textHash != null
                                  ? '${l10n.videoAnalysisLprHashPrefix}: ${p.textHash}'
                                  : '—',
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
