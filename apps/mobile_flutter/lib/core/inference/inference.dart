/// On-device inference pipeline — barrel export.
///
/// Import this single file to access the full pipeline API:
///
/// ```dart
/// import 'package:greyeye_mobile/core/inference/inference.dart';
/// ```
library;

export 'classifier.dart' show VehicleClassifier;
export 'detector.dart' show VehicleDetector;
export 'inference_isolate.dart' show InferenceIsolateRunner;
export 'inference_pipeline.dart' show InferencePipeline;
export 'line_crossing.dart' show LineCrossingDetector;
export 'models.dart';
export 'pipeline_settings.dart';
export 'temporal_smoother.dart' show TemporalSmoother;
export 'tracker.dart' show ByteTracker;
