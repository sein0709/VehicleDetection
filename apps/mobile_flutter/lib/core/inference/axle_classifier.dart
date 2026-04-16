/// Stage 2 — Wheel/joint detection on vehicle crops via TFLite YOLO.
///
/// Runs a YOLOv8 model on cropped vehicle regions to detect wheels and
/// articulation joints. The counts are then mapped to the KICT 12-class
/// taxonomy based on axle count and trailer configuration.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:greyeye_mobile/core/inference/models.dart';
import 'package:greyeye_mobile/core/inference/pipeline_settings.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Result of Stage 2 wheel/joint analysis on a single vehicle crop.
class AxleAnalysis {
  const AxleAnalysis({
    required this.wheelCount,
    required this.jointCount,
    required this.axleCount,
    required this.hasTrailer,
    required this.kictClassCode,
    required this.confidence,
  });

  final int wheelCount;
  final int jointCount;

  /// Estimated axle count: ceil(wheelCount / 2), minimum 2.
  final int axleCount;

  /// True when at least one joint (articulation point) is detected.
  final bool hasTrailer;

  /// Final KICT 12-class code derived from coarse class + axle analysis.
  final int kictClassCode;

  /// Average detection confidence across all wheel/joint detections.
  final double confidence;
}

class AxleClassifier {
  AxleClassifier(this._settings);

  final Stage2DetectorSettings _settings;
  Interpreter? _interpreter;
  int _numClasses = 0;

  Future<void> load() async {
    final interpreter = await Interpreter.fromAsset(_settings.modelPath);
    _interpreter = interpreter;

    final outputShape = interpreter.getOutputTensor(0).shape;
    _numClasses = _inferNumClasses(outputShape);
  }

  /// Load from raw model bytes (for use in background isolates where
  /// Flutter asset bindings are unavailable).
  void loadFromBuffer(Uint8List bytes) {
    final interpreter = Interpreter.fromBuffer(bytes);
    _interpreter = interpreter;

    final outputShape = interpreter.getOutputTensor(0).shape;
    _numClasses = _inferNumClasses(outputShape);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  /// Analyse a single vehicle crop and return axle/joint information.
  ///
  /// [coarseClassCode] is the KICT code from Stage 1 (1=car, 2=bus, 3=truck).
  AxleAnalysis analyseCrop(img.Image crop, int coarseClassCode) {
    final interpreter = _interpreter;
    if (interpreter == null) {
      return _fallbackResult(coarseClassCode);
    }

    final target = _settings.inputSize;
    final hOrig = crop.height;
    final wOrig = crop.width;

    final scale = target / math.max(hOrig, wOrig);
    final newW = (wOrig * scale).round();
    final newH = (hOrig * scale).round();
    final padW = (target - newW) ~/ 2;
    final padH = (target - newH) ~/ 2;

    final resized = img.copyResize(crop, width: newW, height: newH);

    final inputList = List.generate(
      1,
      (_) => List.generate(
        target,
        (y) => List.generate(
          target,
          (x) {
            final srcY = y - padH;
            final srcX = x - padW;
            if (srcX >= 0 && srcX < newW && srcY >= 0 && srcY < newH) {
              final pixel = resized.getPixel(srcX, srcY);
              return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
            }
            return [114.0 / 255.0, 114.0 / 255.0, 114.0 / 255.0];
          },
        ),
      ),
    );

    final outputShape = interpreter.getOutputTensor(0).shape;
    final output = _allocateOutput(outputShape);
    interpreter.run(inputList, output);
    final flatOutput = _flattenOutput(output);

    final detections = _postprocess(flatOutput, outputShape);

    var wheelCount = 0;
    var jointCount = 0;
    var totalConf = 0.0;

    for (final det in detections) {
      if (det.classIdx == Stage2DetectorSettings.wheelClassIdx) {
        wheelCount++;
      } else if (det.classIdx == Stage2DetectorSettings.jointClassIdx) {
        jointCount++;
      }
      totalConf += det.confidence;
    }

    final avgConf = detections.isEmpty ? 0.0 : totalConf / detections.length;
    final axleCount = math.max(2, (wheelCount / 2).ceil());
    final hasTrailer = jointCount > 0;

    final kictCode = mapToKict(
      coarseClassCode: coarseClassCode,
      axleCount: axleCount,
      hasTrailer: hasTrailer,
    );

    return AxleAnalysis(
      wheelCount: wheelCount,
      jointCount: jointCount,
      axleCount: axleCount,
      hasTrailer: hasTrailer,
      kictClassCode: kictCode,
      confidence: avgConf,
    );
  }

  /// Analyse multiple crops in batch. Returns one [AxleAnalysis] per crop.
  List<AxleAnalysis> analyseCrops(
    img.Image frame,
    List<BoundingBox> bboxes,
    List<int> coarseClassCodes,
  ) {
    final results = <AxleAnalysis>[];
    final h = frame.height;
    final w = frame.width;

    for (var i = 0; i < bboxes.length; i++) {
      final bbox = bboxes[i];
      final coarse = coarseClassCodes[i];

      if (coarse == 1 || coarse == 2) {
        results.add(_fallbackResult(coarse));
        continue;
      }

      final x1 = math.max(0, (bbox.x * w).round());
      final y1 = math.max(0, (bbox.y * h).round());
      final x2 = math.min(w, ((bbox.x + bbox.w) * w).round());
      final y2 = math.min(h, ((bbox.y + bbox.h) * h).round());
      final cropW = x2 - x1;
      final cropH = y2 - y1;

      if (cropW <= 0 || cropH <= 0) {
        results.add(_fallbackResult(coarse));
        continue;
      }

      final cropped = img.copyCrop(frame, x: x1, y: y1, width: cropW, height: cropH);
      results.add(analyseCrop(cropped, coarse));
    }

    return results;
  }

  AxleAnalysis _fallbackResult(int coarseClassCode) {
    return AxleAnalysis(
      wheelCount: 0,
      jointCount: 0,
      axleCount: 2,
      hasTrailer: false,
      kictClassCode: coarseClassCode,
      confidence: 0.0,
    );
  }

  // -----------------------------------------------------------------------
  // KICT 12-class mapping from coarse class + axle analysis
  // -----------------------------------------------------------------------

  /// Map coarse vehicle class + axle/joint info to the KICT 12-class code.
  static int mapToKict({
    required int coarseClassCode,
    required int axleCount,
    required bool hasTrailer,
  }) {
    // Car and bus are always single-unit, no axle refinement needed.
    if (coarseClassCode == 1) return 1; // C01: Passenger/Mini
    if (coarseClassCode == 2) return 2; // C02: Bus

    // Truck / trailer classification based on axle count and joints.
    if (!hasTrailer) {
      // Single-unit vehicle
      return switch (axleCount) {
        <= 2 => 3,  // C03: Truck <2.5t (2 axles)
        3 => 5,     // C05: 3-Axle single unit
        4 => 6,     // C06: 4-Axle single unit
        _ => 7,     // C07: 5+-Axle single unit
      };
    }

    // Articulated vehicle (has trailer joint)
    // Semi-trailer = tractor + single trailer (one joint)
    // Full-trailer = truck + drawbar trailer (could also be one joint)
    // Default to semi-trailer since it's more common.
    return switch (axleCount) {
      <= 3 => 4,  // C04: Truck 2.5-8.5t (small articulated)
      4 => 8,     // C08: Semi 4-Axle
      5 => 10,    // C10: Semi 5-Axle
      _ => 12,    // C12: Semi 6+-Axle
    };
  }

  // -----------------------------------------------------------------------
  // YOLO postprocessing (reused from detector.dart pattern)
  // -----------------------------------------------------------------------

  static int _inferNumClasses(List<int> shape) {
    if (shape.length == 3) {
      final rows = shape[1];
      final cols = shape[2];
      if (rows < cols) return rows > 4 ? rows - 4 : 0;
      if (cols == 5) return 1;
      return cols > 4 ? cols - 4 : 0;
    } else if (shape.length == 2) {
      final predDim = shape[1];
      if (predDim == 5) return 1;
      return predDim > 4 ? predDim - 4 : 0;
    }
    return 0;
  }

  List<_RawDetection> _postprocess(Float32List raw, List<int> shape) {
    if (raw.isEmpty || _numClasses == 0) return [];

    late int numPreds;
    late int predDim;
    late bool transposed;

    if (shape.length == 3) {
      final rows = shape[1];
      final cols = shape[2];
      if (rows < cols) {
        numPreds = cols;
        predDim = rows;
        transposed = true;
      } else {
        numPreds = rows;
        predDim = cols;
        transposed = false;
      }
    } else if (shape.length == 2) {
      numPreds = shape[0];
      predDim = shape[1];
      transposed = false;
    } else {
      return [];
    }

    if (predDim != 5 &&
        predDim != 5 + _numClasses &&
        predDim != 4 + _numClasses) {
      return [];
    }

    final target = _settings.inputSize.toDouble();
    final isNormalized = _isNormalizedOutput(raw, numPreds, predDim, transposed);
    final coordScale = isNormalized ? target : 1.0;

    final confThreshold = _settings.confidenceThreshold;
    final boxes = <List<double>>[];
    final scores = <double>[];
    final classIndices = <int>[];

    for (var n = 0; n < numPreds; n++) {
      final p = Float64List(predDim);
      for (var f = 0; f < predDim; f++) {
        p[f] = transposed ? raw[f * numPreds + n] : raw[n * predDim + f];
      }

      double score;
      int bestClassIdx = 0;
      if (predDim == 5) {
        score = p[4];
      } else if (predDim == 5 + _numClasses) {
        var maxCls = p[5];
        for (var c = 6; c < predDim; c++) {
          if (p[c] > maxCls) {
            maxCls = p[c];
            bestClassIdx = c - 5;
          }
        }
        score = p[4] * maxCls;
      } else {
        var maxCls = p[4];
        for (var c = 5; c < predDim; c++) {
          if (p[c] > maxCls) {
            maxCls = p[c];
            bestClassIdx = c - 4;
          }
        }
        score = maxCls;
      }

      if (score < confThreshold) continue;

      final cx = p[0] * coordScale;
      final cy = p[1] * coordScale;
      final bw = p[2] * coordScale;
      final bh = p[3] * coordScale;
      boxes.add([cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2]);
      scores.add(score);
      classIndices.add(bestClassIdx);
    }

    if (boxes.isEmpty) return [];

    final keepIndices = _nms(boxes, scores, _settings.nmsIouThreshold);
    final maxDet = _settings.maxDetections;

    final results = <_RawDetection>[];
    for (var ki = 0; ki < keepIndices.length && ki < maxDet; ki++) {
      final idx = keepIndices[ki];
      results.add(
        _RawDetection(
          classIdx: classIndices[idx],
          confidence: scores[idx],
        ),
      );
    }
    return results;
  }

  static bool _isNormalizedOutput(
    Float32List raw,
    int numPreds,
    int predDim,
    bool transposed,
  ) {
    var maxCoord = 0.0;
    final samplesToCheck = math.min(numPreds, 100);
    for (var n = 0; n < samplesToCheck; n++) {
      for (var f = 0; f < 4; f++) {
        final val = transposed ? raw[f * numPreds + n] : raw[n * predDim + f];
        if (val.abs() > maxCoord) maxCoord = val.abs();
      }
    }
    return maxCoord <= 1.0;
  }
}

class _RawDetection {
  const _RawDetection({required this.classIdx, required this.confidence});
  final int classIdx;
  final double confidence;
}

Object _allocateOutput(List<int> shape) {
  if (shape.length == 1) return List<double>.filled(shape[0], 0.0);
  return List.generate(shape[0], (_) => _allocateOutput(shape.sublist(1)));
}

Float32List _flattenOutput(Object nested) {
  final flat = <double>[];
  _flattenRecursive(nested, flat);
  return Float32List.fromList(flat);
}

void _flattenRecursive(Object obj, List<double> out) {
  if (obj is List) {
    for (final item in obj) {
      _flattenRecursive(item as Object, out);
    }
  } else if (obj is double) {
    out.add(obj);
  } else if (obj is num) {
    out.add(obj.toDouble());
  }
}

List<int> _nms(List<List<double>> boxes, List<double> scores, double iouThreshold) {
  if (boxes.isEmpty) return [];

  final indices = List<int>.generate(boxes.length, (i) => i);
  indices.sort((a, b) => scores[b].compareTo(scores[a]));

  final keep = <int>[];
  final suppressed = List<bool>.filled(boxes.length, false);

  for (final i in indices) {
    if (suppressed[i]) continue;
    keep.add(i);

    final bi = boxes[i];
    final areaI = (bi[2] - bi[0]) * (bi[3] - bi[1]);

    for (final j in indices) {
      if (suppressed[j] || j == i) continue;

      final bj = boxes[j];
      final xx1 = math.max(bi[0], bj[0]);
      final yy1 = math.max(bi[1], bj[1]);
      final xx2 = math.min(bi[2], bj[2]);
      final yy2 = math.min(bi[3], bj[3]);

      final inter = math.max(0.0, xx2 - xx1) * math.max(0.0, yy2 - yy1);
      final areaJ = (bj[2] - bj[0]) * (bj[3] - bj[1]);
      final iou = inter / (areaI + areaJ - inter + 1e-6);

      if (iou > iouThreshold) suppressed[j] = true;
    }
  }

  return keep;
}
