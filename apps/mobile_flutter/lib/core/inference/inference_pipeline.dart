/// Five-stage on-device inference pipeline orchestrator.
///
/// Wires together: detect → track → classify → smooth → line-cross.
/// Designed to run synchronously within a background isolate on each frame.
///
/// Ported from `services/inference_worker/inference_worker/pipeline.py`.
library;

import 'package:greyeye_mobile/core/inference/classifier.dart';
import 'package:greyeye_mobile/core/inference/detector.dart';
import 'package:greyeye_mobile/core/inference/line_crossing.dart';
import 'package:greyeye_mobile/core/inference/models.dart';
import 'package:greyeye_mobile/core/inference/pipeline_settings.dart';
import 'package:greyeye_mobile/core/inference/temporal_smoother.dart';
import 'package:greyeye_mobile/core/inference/tracker.dart';
import 'package:image/image.dart' as img;

class InferencePipeline {
  InferencePipeline(this._settings)
      : _detector = VehicleDetector(_settings.detector),
        _classifier = VehicleClassifier(_settings.classifier),
        _smoother = TemporalSmoother(_settings.smoother),
        _crossingDetector = LineCrossingDetector(_settings.crossing);

  final PipelineSettings _settings;
  final VehicleDetector _detector;
  final VehicleClassifier _classifier;
  final TemporalSmoother _smoother;
  final LineCrossingDetector _crossingDetector;

  final Map<String, ByteTracker> _trackers = {};
  final Map<String, Map<String, TrackState>> _trackStates = {};
  final Map<String, List<CountingLine>> _countingLines = {};

  /// Load TFLite models. Must be called before [processFrame].
  Future<void> load() async {
    await Future.wait([
      _detector.load(),
      _classifier.load(),
    ]);
  }

  void dispose() {
    _detector.dispose();
    _classifier.dispose();
  }

  /// Hot-reload counting lines for a camera.
  void updateCountingLines(String cameraId, List<CountingLine> lines) {
    _countingLines[cameraId] = lines;
  }

  /// Run the full 5-stage pipeline on a single frame.
  PipelineFrameResult processFrame({
    required img.Image frame,
    required String cameraId,
    required int frameIndex,
    required DateTime timestampUtc,
  }) {
    _trackers.putIfAbsent(cameraId, () => ByteTracker(_settings.tracker));
    _trackStates.putIfAbsent(cameraId, () => {});

    final tracker = _trackers[cameraId]!;
    final existingTracks = _trackStates[cameraId]!;

    // --- Stage 1: Detection ---
    final detections = _detector.detectFrame(frame, frameIndex);

    // --- Stage 2: Tracking ---
    final updatedTracks = tracker.update(
      detections,
      existingTracks,
      frameIndex,
      fps: _settings.cameraFps,
    );
    _trackStates[cameraId] = updatedTracks;

    // --- Stage 3: Classification (confirmed tracks only) ---
    final confirmedTracks = <String, TrackState>{};
    for (final e in updatedTracks.entries) {
      if (e.value.isConfirmed) confirmedTracks[e.key] = e.value;
    }

    final bboxesToClassify =
        confirmedTracks.values.map((ts) => ts.bbox).toList();
    final trackIdsOrdered = confirmedTracks.keys.toList();
    final predictions = _classifier.classifyCrops(frame, bboxesToClassify);

    for (var i = 0; i < trackIdsOrdered.length; i++) {
      final ts = confirmedTracks[trackIdsOrdered[i]]!;
      if (i < predictions.length) {
        ts.classHistory.add(predictions[i]);
        final maxHistory = _settings.smoother.window * 3;
        if (ts.classHistory.length > maxHistory) {
          ts.classHistory =
              ts.classHistory.sublist(ts.classHistory.length - maxHistory);
        }
      }
    }

    // --- Stage 4 + 5: Smoothing and Line Crossing ---
    final crossingEvents = <VehicleCrossingEvent>[];
    final countingLines = _countingLines[cameraId] ?? [];

    for (final entry in confirmedTracks.entries) {
      final ts = entry.value;
      if (ts.classHistory.isEmpty) continue;

      final smoothed = _smoother.smooth(ts.classHistory, ts.age);
      if (smoothed == null) continue;

      ts.smoothedClass = smoothed.classCode;
      ts.smoothedConfidence = smoothed.confidence;

      final crossings =
          _crossingDetector.checkCrossings(ts, countingLines, frameIndex);

      for (final crossing in crossings) {
        final seq = ts.crossingSequences[crossing.lineId] ?? 1;
        crossingEvents.add(
          VehicleCrossingEvent(
            timestampUtc: timestampUtc,
            cameraId: cameraId,
            lineId: crossing.lineId,
            trackId: ts.trackId,
            crossingSeq: seq,
            classCode: smoothed.classCode,
            confidence: smoothed.confidence,
            direction: crossing.direction,
            frameIndex: frameIndex,
            speedEstimateKmh: ts.speedEstimateKmh,
            bbox: ts.bbox,
          ),
        );
      }
    }

    final trackSnapshots = updatedTracks.values
        .map(
          (ts) => TrackSnapshot(
            trackId: ts.trackId,
            bbox: ts.bbox,
            classCode: ts.smoothedClass,
            confidence: ts.smoothedConfidence,
            speedEstimateKmh: ts.speedEstimateKmh,
          ),
        )
        .toList();

    return PipelineFrameResult(
      frameIndex: frameIndex,
      tracks: trackSnapshots,
      crossings: crossingEvents,
    );
  }

  /// Reset all state for a camera (e.g. when stopping a session).
  void resetCamera(String cameraId) {
    _trackers.remove(cameraId);
    _trackStates.remove(cameraId);
    _countingLines.remove(cameraId);
  }
}
