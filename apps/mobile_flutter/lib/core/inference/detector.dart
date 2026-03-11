/// Stage 1 — YOLO-based vehicle detection via TFLite.
///
/// Runs a YOLOv8 model on full frames to produce bounding boxes with
/// confidence scores. The detector outputs a single "vehicle" class;
/// fine-grained 12-class discrimination is deferred to Stage 3.
///
/// Ported from `services/inference_worker/inference_worker/stages/detector.py`.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:greyeye_mobile/core/inference/models.dart';
import 'package:greyeye_mobile/core/inference/pipeline_settings.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

const int _numClasses = 12;

class VehicleDetector {
  VehicleDetector(this._settings);

  final DetectorSettings _settings;
  Interpreter? _interpreter;

  Future<void> load() async {
    _interpreter = await Interpreter.fromAsset(_settings.modelPath);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  /// Run detection on a single frame.
  ///
  /// [frame] is a decoded image. Returns normalised [Detection] objects.
  List<Detection> detectFrame(img.Image frame, int frameIndex) {
    final interpreter = _interpreter;
    if (interpreter == null) return [];

    final target = _settings.inputSize;
    final hOrig = frame.height;
    final wOrig = frame.width;

    // --- Letterbox ---
    final scale = target / math.max(hOrig, wOrig);
    final newW = (wOrig * scale).round();
    final newH = (hOrig * scale).round();
    final padW = (target - newW) ~/ 2;
    final padH = (target - newH) ~/ 2;

    final resized = img.copyResize(frame, width: newW, height: newH);

    // Build [1, target, target, 3] float32 input with 114/255 padding.
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
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            }
            return [114.0 / 255.0, 114.0 / 255.0, 114.0 / 255.0];
          },
        ),
      ),
    );

    // Allocate output buffer matching the model's output tensor shape.
    final outputShape = interpreter.getOutputTensor(0).shape;
    final output = _allocateOutput(outputShape);

    interpreter.run(inputList, output);

    // Flatten the output to a Float32List for postprocessing.
    final flatOutput = _flattenOutput(output);

    return _postprocess(
      flatOutput,
      outputShape,
      wOrig,
      hOrig,
      scale,
      padW,
      padH,
      frameIndex,
    );
  }

  List<Detection> _postprocess(
    Float32List raw,
    List<int> shape,
    int wOrig,
    int hOrig,
    double scale,
    int padW,
    int padH,
    int frameIndex,
  ) {
    if (raw.isEmpty) return [];

    // Determine prediction matrix dimensions.
    late int numPreds;
    late int predDim;
    late bool transposed;

    if (shape.length == 3) {
      final rows = shape[1];
      final cols = shape[2];
      if (rows < cols) {
        // (1, features, N) — transposed layout
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

    if (predDim < 5 && predDim != 4 + _numClasses) return [];

    // Extract predictions into a 2D view.
    final confThreshold = _settings.confidenceThreshold;
    final filteredBoxes = <List<double>>[];
    final filteredScores = <double>[];

    for (var n = 0; n < numPreds; n++) {
      // Read one prediction row.
      final p = Float64List(predDim);
      for (var f = 0; f < predDim; f++) {
        p[f] = transposed ? raw[f * numPreds + n] : raw[n * predDim + f];
      }

      double score;
      if (predDim == 5) {
        score = p[4];
      } else if (predDim == 5 + _numClasses) {
        var maxCls = p[5];
        for (var c = 6; c < predDim; c++) {
          if (p[c] > maxCls) maxCls = p[c];
        }
        score = p[4] * maxCls;
      } else if (predDim == 4 + _numClasses) {
        var maxCls = p[4];
        for (var c = 5; c < predDim; c++) {
          if (p[c] > maxCls) maxCls = p[c];
        }
        score = maxCls;
      } else {
        score = p[4];
      }

      if (score < confThreshold) continue;

      final cx = p[0], cy = p[1], bw = p[2], bh = p[3];
      filteredBoxes.add([cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2]);
      filteredScores.add(score);
    }

    if (filteredBoxes.isEmpty) return [];

    // NMS
    final keepIndices = _nms(
      filteredBoxes,
      filteredScores,
      _settings.nmsIouThreshold,
    );
    final maxDet = _settings.maxDetections;

    final detections = <Detection>[];
    for (var ki = 0; ki < keepIndices.length && ki < maxDet; ki++) {
      final idx = keepIndices[ki];
      final box = filteredBoxes[idx];

      final bx1 = (box[0] - padW) / scale;
      final by1 = (box[1] - padH) / scale;
      final bx2 = (box[2] - padW) / scale;
      final by2 = (box[3] - padH) / scale;

      final nx = (bx1 / wOrig).clamp(0.0, 1.0);
      final ny = (by1 / hOrig).clamp(0.0, 1.0);
      final nw = ((bx2 - bx1) / wOrig).clamp(0.0, 1.0);
      final nh = ((by2 - by1) / hOrig).clamp(0.0, 1.0);

      if (nw < 0.005 || nh < 0.005) continue;

      detections.add(
        Detection(
          bbox: BoundingBox(x: nx, y: ny, w: nw, h: nh),
          confidence: filteredScores[idx],
          frameIndex: frameIndex,
        ),
      );
    }

    return detections;
  }
}

/// Allocate a nested List matching [shape] for TFLite output.
Object _allocateOutput(List<int> shape) {
  if (shape.length == 1) {
    return List<double>.filled(shape[0], 0.0);
  }
  return List.generate(shape[0], (_) {
    return _allocateOutput(shape.sublist(1));
  });
}

/// Flatten a nested List output into a [Float32List].
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

/// Non-maximum suppression on xyxy boxes.
List<int> _nms(
  List<List<double>> boxes,
  List<double> scores,
  double iouThreshold,
) {
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

      if (iou > iouThreshold) {
        suppressed[j] = true;
      }
    }
  }

  return keep;
}
