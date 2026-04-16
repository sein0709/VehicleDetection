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
    this.modelPath = 'assets/models/stage1_detector.tflite',
    this.filterVehiclesOnly = false,
    this.cocoClassMap = const {
      0: 1, // car   -> KICT 1 (Passenger car)
      1: 2, // bus   -> KICT 2 (Bus)
      2: 3, // truck -> KICT 3 (Truck <2.5t, coarse placeholder)
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

  /// Maps raw model class indices to the project's KICT codes.
  /// For the Stage 1 model: {0: car, 1: bus, 2: truck}.
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

/// Stage 2 detector settings for wheel/joint detection on vehicle crops.
/// Used to infer axle count and trailer articulation for KICT 12-class mapping.
class Stage2DetectorSettings {
  const Stage2DetectorSettings({
    this.inputSize = 640,
    this.confidenceThreshold = 0.25,
    this.nmsIouThreshold = 0.45,
    this.maxDetections = 50,
    this.modelPath = 'assets/models/stage2_detector.tflite',
  });

  final int inputSize;
  final double confidenceThreshold;
  final double nmsIouThreshold;
  final int maxDetections;
  final String modelPath;

  static const int wheelClassIdx = 0;
  static const int jointClassIdx = 1;
  static const int numClasses = 2;
}

class ClassifierSettings {
  const ClassifierSettings({
    this.inputSize = 224,
    this.fallbackThreshold = 0.4,
    this.modelPath = 'assets/models/classifier.tflite',
    this.mode = ClassificationMode.full12class,
  });

  final int inputSize;
  final double fallbackThreshold;
  final String modelPath;
  final ClassificationMode mode;
}

enum ClassificationMode { full12class, coarseOnly, hybridCloud, disabled }

enum VlmProvider { gemini, openai }

class VlmSettings {
  const VlmSettings({
    this.provider = VlmProvider.gemini,
    this.apiKey = '',
    this.model = 'gemini-2.0-flash',
    this.confidenceThreshold = 0.7,
    this.batchSize = 5,
    this.batchTimeoutMs = 2000,
    this.requestTimeoutMs = 10000,
    this.maxRetries = 2,
    this.systemPrompt = defaultPrompt,
  });

  final VlmProvider provider;
  final String apiKey;
  final String model;

  /// Skip the VLM call when the local AxleClassifier confidence exceeds this.
  final double confidenceThreshold;

  /// Max crops to accumulate before flushing a batch request.
  final int batchSize;

  /// Max milliseconds to wait before flushing an incomplete batch.
  final int batchTimeoutMs;

  /// Per-request timeout for the HTTP call to the VLM provider.
  final int requestTimeoutMs;

  /// Number of retries on transient failures before falling back to local.
  final int maxRetries;

  final String systemPrompt;

  static const String defaultPrompt =
      '당신은 한국 도로교통 차량 분류 전문가입니다. '
      '이미지에 보이는 차량을 KICT/국토교통부 12종 분류 기준에 따라 분류하세요.\n\n'
      '분류 코드:\n'
      '1: 승용차/미니트럭\n'
      '2: 버스\n'
      '3: 1~2.5톤 미만 화물차\n'
      '4: 2.5~8.5톤 미만 화물차\n'
      '5: 1단위 3축\n'
      '6: 1단위 4축\n'
      '7: 1단위 5축\n'
      '8: 2단위 4축 세미트레일러\n'
      '9: 2단위 4축 풀트레일러\n'
      '10: 2단위 5축 세미트레일러\n'
      '11: 2단위 5축 풀트레일러\n'
      '12: 2단위 6축 세미트레일러\n\n'
      '바퀴 수, 축 수, 연결 장치(관절) 유무를 주의 깊게 관찰하세요. '
      'JSON 형식으로 응답하세요: {"class": <1-12>, "confidence": <0.0-1.0>}';

  VlmSettings copyWith({
    VlmProvider? provider,
    String? apiKey,
    String? model,
    double? confidenceThreshold,
    int? batchSize,
    int? batchTimeoutMs,
    int? requestTimeoutMs,
    int? maxRetries,
    String? systemPrompt,
  }) {
    return VlmSettings(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      batchSize: batchSize ?? this.batchSize,
      batchTimeoutMs: batchTimeoutMs ?? this.batchTimeoutMs,
      requestTimeoutMs: requestTimeoutMs ?? this.requestTimeoutMs,
      maxRetries: maxRetries ?? this.maxRetries,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }
}

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
    this.stage2Detector = const Stage2DetectorSettings(),
    this.tracker = const TrackerSettings(),
    this.classifier = const ClassifierSettings(),
    this.smoother = const SmootherSettings(),
    this.crossing = const CrossingSettings(),
    this.vlm = const VlmSettings(),
    this.cameraFps = 10.0,
  });

  final DetectorSettings detector;
  final Stage2DetectorSettings stage2Detector;
  final TrackerSettings tracker;
  final ClassifierSettings classifier;
  final SmootherSettings smoother;
  final CrossingSettings crossing;
  final VlmSettings vlm;
  final double cameraFps;
}
