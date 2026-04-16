import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/inference/axle_classifier.dart';
import 'package:greyeye_mobile/core/inference/detector.dart';
import 'package:greyeye_mobile/core/inference/models.dart';
import 'package:greyeye_mobile/core/inference/pipeline_settings.dart';
import 'package:greyeye_mobile/features/classify/models/classify_result.dart';
import 'package:image/image.dart' as img;

enum ClassifyStatus { idle, loading, classifying, done, error }

class ClassifyState {
  const ClassifyState({
    this.status = ClassifyStatus.idle,
    this.imagePath,
    this.result,
    this.errorMessage,
  });

  final ClassifyStatus status;
  final String? imagePath;
  final ClassifyResult? result;
  final String? errorMessage;

  ClassifyState copyWith({
    ClassifyStatus? status,
    String? imagePath,
    ClassifyResult? result,
    String? errorMessage,
  }) =>
      ClassifyState(
        status: status ?? this.status,
        imagePath: imagePath ?? this.imagePath,
        result: result ?? this.result,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class ClassifyNotifier extends StateNotifier<ClassifyState> {
  ClassifyNotifier() : super(const ClassifyState());

  VehicleDetector? _detector;
  AxleClassifier? _axleClassifier;
  bool _modelsLoaded = false;

  Future<void> _ensureModelsLoaded() async {
    if (_modelsLoaded) return;

    state = state.copyWith(status: ClassifyStatus.loading);

    _detector = VehicleDetector(const DetectorSettings());
    _axleClassifier = AxleClassifier(const Stage2DetectorSettings());

    await Future.wait([
      _detector!.load(),
      _axleClassifier!.load(),
    ]);

    _modelsLoaded = true;
  }

  Future<void> classifyImage(String imagePath) async {
    try {
      state = ClassifyState(
        status: ClassifyStatus.loading,
        imagePath: imagePath,
      );

      await _ensureModelsLoaded();

      state = state.copyWith(status: ClassifyStatus.classifying);

      final bytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        state = state.copyWith(
          status: ClassifyStatus.error,
          errorMessage: 'Failed to decode image',
        );
        return;
      }

      final detections = _detector!.detectFrame(decoded, 0);

      final vehicleResults = <VehicleClassifyResult>[];

      for (final det in detections) {
        final coarseClass = det.classCode ?? 1;
        final stage1Conf = det.confidence;

        if (coarseClass == 3) {
          final crop = _extractCrop(decoded, det.bbox);
          final analysis = _axleClassifier!.analyseCrop(crop, coarseClass);

          vehicleResults.add(
            VehicleClassifyResult(
              bbox: det.bbox,
              stage1ClassCode: coarseClass,
              stage1Confidence: stage1Conf,
              wheelCount: analysis.wheelCount,
              jointCount: analysis.jointCount,
              axleCount: analysis.axleCount,
              hasTrailer: analysis.hasTrailer,
              finalClassCode: analysis.kictClassCode,
              finalConfidence: analysis.confidence > 0
                  ? analysis.confidence
                  : stage1Conf,
            ),
          );
        } else {
          vehicleResults.add(
            VehicleClassifyResult(
              bbox: det.bbox,
              stage1ClassCode: coarseClass,
              stage1Confidence: stage1Conf,
              wheelCount: 0,
              jointCount: 0,
              axleCount: 2,
              hasTrailer: false,
              finalClassCode: coarseClass,
              finalConfidence: stage1Conf,
            ),
          );
        }
      }

      state = ClassifyState(
        status: ClassifyStatus.done,
        imagePath: imagePath,
        result: ClassifyResult(
          detections: detections,
          vehicleResults: vehicleResults,
        ),
      );
    } catch (e) {
      state = ClassifyState(
        status: ClassifyStatus.error,
        imagePath: imagePath,
        errorMessage: e.toString(),
      );
    }
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

  void reset() {
    state = const ClassifyState();
  }

  @override
  void dispose() {
    _detector?.dispose();
    _axleClassifier?.dispose();
    super.dispose();
  }
}

final classifyProvider =
    StateNotifierProvider.autoDispose<ClassifyNotifier, ClassifyState>(
  (ref) => ClassifyNotifier(),
);
