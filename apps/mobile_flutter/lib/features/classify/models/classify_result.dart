import 'package:greyeye_mobile/core/inference/models.dart';

/// Result of a two-stage classification on a single image.
class ClassifyResult {
  const ClassifyResult({
    required this.detections,
    required this.vehicleResults,
  });

  /// All bounding boxes detected by Stage 1.
  final List<Detection> detections;

  /// Per-vehicle classification results (one per detection).
  final List<VehicleClassifyResult> vehicleResults;
}

/// Classification result for a single detected vehicle.
class VehicleClassifyResult {
  const VehicleClassifyResult({
    required this.bbox,
    required this.stage1ClassCode,
    required this.stage1Confidence,
    required this.wheelCount,
    required this.jointCount,
    required this.axleCount,
    required this.hasTrailer,
    required this.finalClassCode,
    required this.finalConfidence,
  });

  final BoundingBox bbox;

  /// Coarse class from Stage 1: 1=car, 2=bus, 3=truck.
  final int stage1ClassCode;
  final double stage1Confidence;

  /// Stage 2 wheel/joint analysis (0 for car/bus).
  final int wheelCount;
  final int jointCount;
  final int axleCount;
  final bool hasTrailer;

  /// Final KICT 12-class code after two-stage refinement.
  final int finalClassCode;
  final double finalConfidence;

  String get stage1Label => switch (stage1ClassCode) {
        1 => 'Car',
        2 => 'Bus',
        3 => 'Truck',
        _ => 'Unknown',
      };
}
