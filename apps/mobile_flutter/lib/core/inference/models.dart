/// Internal data models for the on-device inference pipeline.
///
/// Ported from `services/inference_worker/inference_worker/models.py`.
/// All bounding-box and point coordinates are normalised to 0.0–1.0
/// relative to the camera frame dimensions.
library;

import 'package:greyeye_mobile/features/monitor/models/live_track.dart';
import 'package:greyeye_mobile/features/roi/models/roi_model.dart';

// Re-export geometry types used throughout the pipeline.
export 'package:greyeye_mobile/features/monitor/models/live_track.dart'
    show BoundingBox;
export 'package:greyeye_mobile/features/roi/models/roi_model.dart'
    show CountingLine, Point2D;

/// Geometry helpers for [BoundingBox] needed by the pipeline.
Point2D bboxCenter(BoundingBox b) => Point2D(x: b.x + b.w / 2, y: b.y + b.h / 2);

/// Convert [BoundingBox] to [x1, y1, x2, y2] format.
List<double> bboxToXyxy(BoundingBox b) => [b.x, b.y, b.x + b.w, b.y + b.h];

/// Stage 1 output: a single detected vehicle bounding box.
class Detection {
  const Detection({
    required this.bbox,
    required this.confidence,
    required this.frameIndex,
    this.classCode,
  });

  final BoundingBox bbox;
  final double confidence;
  final int frameIndex;

  /// KICT class code assigned by the detector via COCO-to-KICT mapping.
  /// Null when using a custom model without the mapping enabled.
  final int? classCode;
}

/// Stage 3 output: classification result for a single vehicle crop.
class ClassPrediction {
  const ClassPrediction({
    required this.classCode,
    required this.probabilities,
    required this.confidence,
    required this.cropBbox,
  });

  final int classCode;

  /// 12-element probability vector (index 0 = class 1, ..., index 11 = class 12).
  final List<double> probabilities;
  final double confidence;
  final BoundingBox cropBbox;
}

/// Stage 4 output: temporally smoothed classification.
class SmoothedPrediction {
  const SmoothedPrediction({
    required this.classCode,
    required this.confidence,
    required this.probabilities,
    required this.rawPrediction,
  });

  final int classCode;
  final double confidence;
  final List<double> probabilities;
  final ClassPrediction rawPrediction;
}

/// Stage 5 output: a confirmed line-crossing event.
class CrossingResult {
  const CrossingResult({
    required this.lineId,
    required this.lineName,
    required this.direction,
  });

  final String lineId;
  final String lineName;

  /// `"inbound"` or `"outbound"`.
  final String direction;
}

/// Per-track mutable state maintained by the tracker across frames.
class TrackState {
  TrackState({
    required this.trackId,
    required this.bbox,
    required this.centroid,
    required this.firstSeenFrame,
    required this.lastSeenFrame,
    List<Point2D>? centroidHistory,
    List<ClassPrediction>? classHistory,
    this.smoothedClass,
    this.smoothedConfidence,
    this.age = 0,
    this.hits = 0,
    this.timeSinceUpdate = 0,
    this.isConfirmed = false,
    this.speedEstimateKmh,
    this.occlusionFlag = false,
    Map<String, int>? crossingSequences,
    Map<String, int>? lastCrossingFrame,
  })  : centroidHistory = centroidHistory ?? [centroid],
        classHistory = classHistory ?? [],
        crossingSequences = crossingSequences ?? {},
        lastCrossingFrame = lastCrossingFrame ?? {};

  final String trackId;
  BoundingBox bbox;
  Point2D centroid;
  List<Point2D> centroidHistory;
  List<ClassPrediction> classHistory;
  int? smoothedClass;
  double? smoothedConfidence;
  int firstSeenFrame;
  int lastSeenFrame;
  int age;
  int hits;
  int timeSinceUpdate;
  bool isConfirmed;
  double? speedEstimateKmh;
  bool occlusionFlag;
  Map<String, int> crossingSequences;
  Map<String, int> lastCrossingFrame;
}

/// Aggregate result emitted by the pipeline for each crossing event.
class VehicleCrossingEvent {
  const VehicleCrossingEvent({
    required this.timestampUtc,
    required this.cameraId,
    required this.lineId,
    required this.trackId,
    required this.crossingSeq,
    required this.classCode,
    required this.confidence,
    required this.direction,
    required this.frameIndex,
    this.speedEstimateKmh,
    required this.bbox,
  });

  final DateTime timestampUtc;
  final String cameraId;
  final String lineId;
  final String trackId;
  final int crossingSeq;
  final int classCode;
  final double confidence;
  final String direction;
  final int frameIndex;
  final double? speedEstimateKmh;
  final BoundingBox bbox;

  Map<String, dynamic> toJson() => {
        'timestamp_utc': timestampUtc.toIso8601String(),
        'camera_id': cameraId,
        'line_id': lineId,
        'track_id': trackId,
        'crossing_seq': crossingSeq,
        'class12': classCode,
        'confidence': confidence,
        'direction': direction,
        'frame_index': frameIndex,
        'speed_estimate_kmh': speedEstimateKmh,
        'bbox': {'x': bbox.x, 'y': bbox.y, 'w': bbox.w, 'h': bbox.h},
      };
}

/// Snapshot of all live tracks for a single frame, used for UI rendering.
class PipelineFrameResult {
  const PipelineFrameResult({
    required this.frameIndex,
    required this.tracks,
    required this.crossings,
  });

  final int frameIndex;
  final List<TrackSnapshot> tracks;
  final List<VehicleCrossingEvent> crossings;
}

/// Immutable snapshot of a single track for UI consumption.
class TrackSnapshot {
  const TrackSnapshot({
    required this.trackId,
    required this.bbox,
    this.classCode,
    this.confidence,
    this.speedEstimateKmh,
  });

  final String trackId;
  final BoundingBox bbox;
  final int? classCode;
  final double? confidence;
  final double? speedEstimateKmh;
}
