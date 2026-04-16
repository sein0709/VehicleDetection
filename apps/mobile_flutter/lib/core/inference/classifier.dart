/// Stage 3 — 12-class vehicle classification via TFLite.
///
/// Crops detected vehicle regions, resizes to 224×224, applies ImageNet
/// normalisation, and runs through an EfficientNet-B0 classifier to produce
/// a probability distribution over the 12 KICT/MOLIT vehicle classes.
///
/// Ported from `services/inference_worker/inference_worker/stages/classifier.py`.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:greyeye_mobile/core/inference/models.dart';
import 'package:greyeye_mobile/core/inference/pipeline_settings.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

const int _numClasses = 12;

const _imagenetMean = [0.485, 0.456, 0.406];
const _imagenetStd = [0.229, 0.224, 0.225];

/// Coarse fallback groups: when fine-grained confidence is low, collapse
/// to the representative class of the coarse group with highest aggregate
/// probability.
const _coarseGroups = <String, List<int>>{
  'car': [1],
  'bus': [2],
  'truck': [3, 4, 5, 6, 7],
  'trailer': [8, 9, 10, 11, 12],
};

class VehicleClassifier {
  VehicleClassifier(this._settings);

  final ClassifierSettings _settings;
  Interpreter? _interpreter;

  Future<void> load() async {
    if (_settings.mode == ClassificationMode.disabled) return;
    _interpreter = await Interpreter.fromAsset(_settings.modelPath);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  /// Classify a batch of vehicle crops from a single frame.
  List<ClassPrediction> classifyCrops(
    img.Image frame,
    List<BoundingBox> bboxes,
  ) {
    if (_settings.mode == ClassificationMode.disabled) {
      return bboxes
          .map(
            (bbox) => ClassPrediction(
              classCode: 1,
              probabilities: List<double>.filled(_numClasses, 1.0 / _numClasses),
              confidence: 0.0,
              cropBbox: bbox,
            ),
          )
          .toList();
    }

    if (bboxes.isEmpty) return [];

    final interpreter = _interpreter;
    if (interpreter == null) {
      return bboxes
          .map(
            (bbox) => ClassPrediction(
              classCode: 1,
              probabilities: List<double>.filled(_numClasses, 1.0 / _numClasses),
              confidence: 0.0,
              cropBbox: bbox,
            ),
          )
          .toList();
    }

    final crops = _extractCrops(frame, bboxes);
    final results = <ClassPrediction>[];

    for (var i = 0; i < crops.length; i++) {
      final preprocessed = _preprocess(crops[i]);
      final output = [List<double>.filled(_numClasses, 0.0)];

      interpreter.run(preprocessed, output);

      final probs = _softmax(
        Float32List.fromList(
          output[0].map((v) => v.toDouble()).toList(),
        ),
      );
      var bestIdx = 0;
      var bestConf = probs[0];
      for (var c = 1; c < _numClasses; c++) {
        if (probs[c] > bestConf) {
          bestConf = probs[c];
          bestIdx = c;
        }
      }

      var pred = ClassPrediction(
        classCode: bestIdx + 1,
        probabilities: probs,
        confidence: bestConf,
        cropBbox: bboxes[i],
      );

      if (_settings.mode == ClassificationMode.coarseOnly ||
          bestConf < _settings.fallbackThreshold) {
        pred = _applyCoarseFallback(pred);
      }

      results.add(pred);
    }

    return results;
  }

  List<img.Image> _extractCrops(img.Image frame, List<BoundingBox> bboxes) {
    final h = frame.height;
    final w = frame.width;
    final target = _settings.inputSize;

    return bboxes.map((bbox) {
      final x1 = math.max(0, (bbox.x * w).round());
      final y1 = math.max(0, (bbox.y * h).round());
      final x2 = math.min(w, ((bbox.x + bbox.w) * w).round());
      final y2 = math.min(h, ((bbox.y + bbox.h) * h).round());

      final cropW = x2 - x1;
      final cropH = y2 - y1;

      if (cropW <= 0 || cropH <= 0) {
        return img.Image(width: target, height: target);
      }

      final cropped = img.copyCrop(
        frame,
        x: x1,
        y: y1,
        width: cropW,
        height: cropH,
      );
      return img.copyResize(cropped, width: target, height: target);
    }).toList();
  }

  /// Normalise a crop to [1, inputSize, inputSize, 3] nested List with
  /// ImageNet mean/std.
  List<List<List<List<double>>>> _preprocess(img.Image crop) {
    final target = _settings.inputSize;
    return [
      List.generate(
        target,
        (y) => List.generate(target, (x) {
          final pixel = crop.getPixel(x, y);
          return [
            ((pixel.r / 255.0) - _imagenetMean[0]) / _imagenetStd[0],
            ((pixel.g / 255.0) - _imagenetMean[1]) / _imagenetStd[1],
            ((pixel.b / 255.0) - _imagenetMean[2]) / _imagenetStd[2],
          ];
        }),
      ),
    ];
  }
}

List<double> _softmax(Float32List logits) {
  var maxVal = logits[0];
  for (var i = 1; i < logits.length; i++) {
    if (logits[i] > maxVal) maxVal = logits[i];
  }

  final exps = List<double>.filled(logits.length, 0.0);
  var sum = 0.0;
  for (var i = 0; i < logits.length; i++) {
    exps[i] = math.exp(logits[i] - maxVal);
    sum += exps[i];
  }

  for (var i = 0; i < exps.length; i++) {
    exps[i] /= sum + 1e-9;
  }
  return exps;
}

ClassPrediction _applyCoarseFallback(ClassPrediction pred) {
  final probs = pred.probabilities;
  var bestGroup = '';
  var bestGroupProb = -1.0;

  for (final entry in _coarseGroups.entries) {
    var groupProb = 0.0;
    for (final classCode in entry.value) {
      groupProb += probs[classCode - 1];
    }
    if (groupProb > bestGroupProb) {
      bestGroupProb = groupProb;
      bestGroup = entry.key;
    }
  }

  final representative = _coarseGroups[bestGroup]!.first;
  return ClassPrediction(
    classCode: representative,
    probabilities: probs,
    confidence: bestGroupProb,
    cropBbox: pred.cropBbox,
  );
}
