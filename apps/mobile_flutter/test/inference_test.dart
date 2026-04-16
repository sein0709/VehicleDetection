import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:greyeye_mobile/core/inference/detector.dart';
import 'package:greyeye_mobile/core/inference/pipeline_settings.dart';

void main() {
  test('Load model and check output shape', () async {
    final modelPath = 'assets/models/stage1_detector.tflite';
    final modelFile = File(modelPath);
    expect(modelFile.existsSync(), isTrue);

    final interpreter = Interpreter.fromFile(modelFile);
    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;
    
    print('Input shape: $inputShape');
    print('Output shape: $outputShape');

    // Also check detector initialization
    final detector = VehicleDetector(PipelineSettings().detector);
    detector.loadFromBuffer(modelFile.readAsBytesSync());
    print('Detector numClasses: ${detector.numClasses}');
  });
}
