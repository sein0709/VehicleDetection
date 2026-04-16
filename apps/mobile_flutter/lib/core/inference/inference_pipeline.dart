/// Five-stage on-device inference pipeline orchestrator.
///
/// Wires together: detect → track → classify (two-stage) → smooth → line-cross.
///
/// Classification uses a two-stage approach:
///   Stage 1 detector: car/bus/truck (coarse class from detection model)
///   Stage 2 detector: wheel/joint on truck crops → axle count → KICT 12-class
///
/// In `hybridCloud` mode, trucks still get a local AxleClassifier result as an
/// immediate best-guess, but crossing events for trucks carry a JPEG crop so
/// the main isolate can enqueue them into [VlmRequestQueue] for async cloud
/// refinement.
///
/// Designed to run synchronously within a background isolate on each frame.
library;

import 'dart:typed_data';

import 'package:greyeye_mobile/core/inference/axle_classifier.dart';
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
        _axleClassifier = AxleClassifier(_settings.stage2Detector),
        _smoother = TemporalSmoother(_settings.smoother),
        _crossingDetector = LineCrossingDetector(_settings.crossing);

  final PipelineSettings _settings;
  final VehicleDetector _detector;
  final AxleClassifier _axleClassifier;
  final TemporalSmoother _smoother;
  final LineCrossingDetector _crossingDetector;

  final Map<String, ByteTracker> _trackers = {};
  final Map<String, Map<String, TrackState>> _trackStates = {};
  final Map<String, List<CountingLine>> _countingLines = {};

  /// Load TFLite models from Flutter assets. Must be called before
  /// [processFrame]. Only works on the main isolate (requires bindings).
  Future<void> load() async {
    final futures = <Future<void>>[_detector.load()];
    if (_settings.classifier.mode == ClassificationMode.full12class ||
        _settings.classifier.mode == ClassificationMode.hybridCloud) {
      futures.add(_axleClassifier.load());
    }
    await Future.wait(futures);
  }

  /// Load TFLite models from pre-loaded byte buffers. Use this in background
  /// isolates where Flutter asset bindings are unavailable.
  void loadFromBuffers({
    required Uint8List detectorBytes,
    Uint8List? axleClassifierBytes,
  }) {
    _detector.loadFromBuffer(detectorBytes);
    if ((_settings.classifier.mode == ClassificationMode.full12class ||
            _settings.classifier.mode == ClassificationMode.hybridCloud) &&
        axleClassifierBytes != null) {
      _axleClassifier.loadFromBuffer(axleClassifierBytes);
    }
  }

  void dispose() {
    _detector.dispose();
    _axleClassifier.dispose();
  }

  /// Hot-reload counting lines for a camera.
  void updateCountingLines(String cameraId, List<CountingLine> lines) {
    _countingLines[cameraId] = lines;
  }

  /// Run the full pipeline on a single frame.
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

    // --- Stage 1: Detection (car/bus/truck) ---
    final detections = _detector.detectFrame(frame, frameIndex);

    // --- Stage 2: Tracking ---
    final updatedTracks = tracker.update(
      detections,
      existingTracks,
      frameIndex,
      fps: _settings.cameraFps,
    );
    _trackStates[cameraId] = updatedTracks;

    // --- Stage 3: Two-stage classification (confirmed tracks only) ---
    final confirmedTracks = <String, TrackState>{};
    for (final e in updatedTracks.entries) {
      if (e.value.isConfirmed) confirmedTracks[e.key] = e.value;
    }

    final mode = _settings.classifier.mode;
    final isHybridCloud = mode == ClassificationMode.hybridCloud;

    for (final ts in confirmedTracks.values) {
      final coarseClass = _resolveDetectorClass(detections, ts);
      if (coarseClass == null) continue;

      int finalClass;
      double finalConfidence;

      if (mode == ClassificationMode.disabled || mode == ClassificationMode.coarseOnly) {
        finalClass = coarseClass;
        finalConfidence = 1.0;
      } else {
        // full12class and hybridCloud both run Stage 2 on truck crops.
        // In hybridCloud mode the local result serves as an immediate
        // best-guess that may be refined asynchronously by a cloud VLM.
        if (coarseClass == 3) {
          final analysis = _axleClassifier.analyseCrop(
            _extractCrop(frame, ts.bbox),
            coarseClass,
          );
          finalClass = analysis.kictClassCode;
          finalConfidence = analysis.confidence > 0 ? analysis.confidence : 0.8;
        } else {
          finalClass = coarseClass;
          finalConfidence = 1.0;
        }
      }

      // Build a ClassPrediction for the smoother's history
      final probs = List<double>.filled(12, 0.0);
      if (finalClass >= 1 && finalClass <= 12) {
        probs[finalClass - 1] = finalConfidence;
      }
      ts.classHistory.add(
        ClassPrediction(
          classCode: finalClass,
          probabilities: probs,
          confidence: finalConfidence,
          cropBbox: ts.bbox,
        ),
      );
      final maxHistory = _settings.smoother.window * 3;
      if (ts.classHistory.length > maxHistory) {
        ts.classHistory = ts.classHistory.sublist(ts.classHistory.length - maxHistory);
      }
    }

    // --- Stage 4 + 5: Smoothing and Line Crossing ---
    final crossingEvents = <VehicleCrossingEvent>[];
    final countingLines = _countingLines[cameraId] ?? [];
    final vlmConfThreshold = _settings.vlm.confidenceThreshold;

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

        // Determine whether this crossing needs async VLM refinement.
        // Conditions: hybridCloud mode, truck class (3–12), and local
        // confidence below the VLM confidence threshold.
        final isTruck = smoothed.classCode >= 3;
        final localConfidenceLow = smoothed.confidence < vlmConfThreshold;
        final needsVlm = isHybridCloud && isTruck && localConfidenceLow;

        Uint8List? cropBytes;
        if (needsVlm) {
          final crop = _extractCrop(frame, ts.bbox);
          cropBytes = Uint8List.fromList(img.encodeJpg(crop, quality: 85));
        }

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
            pendingVlmRefinement: needsVlm,
            cropJpegBytes: cropBytes,
            localFallbackConfidence: needsVlm ? smoothed.confidence : null,
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

  img.Image _extractCrop(img.Image frame, BoundingBox bbox) {
    final h = frame.height;
    final w = frame.width;
    final x1 = (bbox.x * w).round().clamp(0, w);
    final y1 = (bbox.y * h).round().clamp(0, h);
    final x2 = ((bbox.x + bbox.w) * w).round().clamp(0, w);
    final y2 = ((bbox.y + bbox.h) * h).round().clamp(0, h);
    final cropW = x2 - x1;
    final cropH = y2 - y1;

    if (cropW <= 0 || cropH <= 0) {
      return img.Image(width: 64, height: 64);
    }
    return img.copyCrop(frame, x: x1, y: y1, width: cropW, height: cropH);
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
