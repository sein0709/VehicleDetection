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

    final classifierDisabled =
        _settings.classifier.mode == ClassificationMode.disabled;

    if (classifierDisabled) {
      // Use the detector's COCO-mapped class code directly on each track.
      // Pick the class from the detection that last matched this track.
      for (final ts in confirmedTracks.values) {
        final detectorClass = _resolveDetectorClass(detections, ts);
        if (detectorClass != null) {
          ts.smoothedClass = detectorClass;
          ts.smoothedConfidence = ts.smoothedConfidence ?? 1.0;
        }
      }
    } else {
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
    }

    // --- Stage 4 + 5: Smoothing and Line Crossing ---
    final crossingEvents = <VehicleCrossingEvent>[];
    final countingLines = _countingLines[cameraId] ?? [];

    for (final entry in confirmedTracks.entries) {
      final ts = entry.value;

      int? classCode;
      double? confidence;

      if (classifierDisabled) {
        classCode = ts.smoothedClass;
        confidence = ts.smoothedConfidence;
      } else {
        if (ts.classHistory.isEmpty) continue;
        final smoothed = _smoother.smooth(ts.classHistory, ts.age);
        if (smoothed == null) continue;
        ts.smoothedClass = smoothed.classCode;
        ts.smoothedConfidence = smoothed.confidence;
        classCode = smoothed.classCode;
        confidence = smoothed.confidence;
      }

      if (classCode == null) continue;

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
            classCode: classCode,
            confidence: confidence ?? 0.0,
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

  /// Find the best detector-assigned class code for a track by picking the
  /// detection whose bbox overlaps most with the track's current bbox.
  int? _resolveDetectorClass(List<Detection> detections, TrackState ts) {
    if (detections.isEmpty) return ts.smoothedClass;

    final tb = bboxToXyxy(ts.bbox);
    var bestIou = 0.0;
    int? bestClass;

    for (final det in detections) {
      if (det.classCode == null) continue;
      final db = bboxToXyxy(det.bbox);
      final ix1 = db[0] > tb[0] ? db[0] : tb[0];
      final iy1 = db[1] > tb[1] ? db[1] : tb[1];
      final ix2 = db[2] < tb[2] ? db[2] : tb[2];
      final iy2 = db[3] < tb[3] ? db[3] : tb[3];
      final inter = (ix2 - ix1).clamp(0.0, double.infinity) *
          (iy2 - iy1).clamp(0.0, double.infinity);
      final areaD = (db[2] - db[0]) * (db[3] - db[1]);
      final areaT = (tb[2] - tb[0]) * (tb[3] - tb[1]);
      final iou = inter / (areaD + areaT - inter + 1e-6);
      if (iou > bestIou) {
        bestIou = iou;
        bestClass = det.classCode;
      }
    }

    return bestClass ?? ts.smoothedClass;
  }

  /// Reset all state for a camera (e.g. when stopping a session).
  void resetCamera(String cameraId) {
    _trackers.remove(cameraId);
    _trackStates.remove(cameraId);
    _countingLines.remove(cameraId);
  }
}
