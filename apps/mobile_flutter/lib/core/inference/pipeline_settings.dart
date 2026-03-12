/// Configurable parameters for each stage of the on-device inference pipeline.
///
/// Mirrors the Python `Settings` hierarchy from
/// `services/inference_worker/inference_worker/settings.py`, keeping only
/// the parameters relevant to on-device execution.
class DetectorSettings {
  const DetectorSettings({
    this.inputSize = 640,
    this.confidenceThreshold = 0.25,
    this.nmsIouThreshold = 0.45,
    this.maxDetections = 100,
    this.modelPath = 'assets/models/detector.tflite',
    this.filterVehiclesOnly = true,
    this.cocoClassMap = const {
      2: 1, // COCO car       -> KICT 1 (Passenger car)
      5: 2, // COCO bus       -> KICT 2 (Bus)
      7: 3, // COCO truck     -> KICT 3 (Truck)
    },
  });

  final int inputSize;
  final double confidenceThreshold;
  final double nmsIouThreshold;
  final int maxDetections;
  final String modelPath;

  /// When true, only detections whose COCO class index appears in
  /// [cocoClassMap] are kept. Set to false when using a custom model that
  /// already outputs only vehicle classes.
  final bool filterVehiclesOnly;

  /// Maps COCO 80-class indices to the project's 12-class KICT codes.
  /// Only used when [filterVehiclesOnly] is true.
  final Map<int, int> cocoClassMap;
}

class TrackerSettings {
  const TrackerSettings({
    this.minHits = 3,
    this.maxAge = 30,
    this.iouThreshold = 0.3,
    this.centroidHistoryLength = 50,
  });

  final int minHits;
  final int maxAge;
  final double iouThreshold;
  final int centroidHistoryLength;
}

class ClassifierSettings {
  const ClassifierSettings({
    this.inputSize = 224,
    this.fallbackThreshold = 0.4,
    this.modelPath = 'assets/models/classifier.tflite',
    this.mode = ClassificationMode.disabled,
  });

  final int inputSize;
  final double fallbackThreshold;
  final String modelPath;
  final ClassificationMode mode;
}

enum ClassificationMode { full12class, coarseOnly, disabled }

class SmootherSettings {
  const SmootherSettings({
    this.strategy = SmoothingStrategy.majority,
    this.window = 5,
    this.emaAlpha = 0.3,
    this.minTrackAge = 3,
  });

  final SmoothingStrategy strategy;
  final int window;
  final double emaAlpha;
  final int minTrackAge;
}

enum SmoothingStrategy { majority, ema }

class CrossingSettings {
  const CrossingSettings({
    this.cooldownFrames = 10,
    this.minDisplacement = 0.01,
  });

  final int cooldownFrames;
  final double minDisplacement;
}

class PipelineSettings {
  const PipelineSettings({
    this.detector = const DetectorSettings(),
    this.tracker = const TrackerSettings(),
    this.classifier = const ClassifierSettings(),
    this.smoother = const SmootherSettings(),
    this.crossing = const CrossingSettings(),
    this.cameraFps = 10.0,
  });

  final DetectorSettings detector;
  final TrackerSettings tracker;
  final ClassifierSettings classifier;
  final SmootherSettings smoother;
  final CrossingSettings crossing;
  final double cameraFps;
}
