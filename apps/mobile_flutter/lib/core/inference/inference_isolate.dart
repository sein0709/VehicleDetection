/// Background isolate runner for the on-device inference pipeline.
///
/// Runs TFLite inference on a separate isolate to avoid blocking the UI
/// thread. Communicates via message passing with typed request/response
/// envelopes.
library;

import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:greyeye_mobile/core/inference/inference_pipeline.dart';
import 'package:greyeye_mobile/core/inference/models.dart';
import 'package:greyeye_mobile/core/inference/pipeline_settings.dart';
import 'package:image/image.dart' as img;

// ---------------------------------------------------------------------------
// Message types exchanged between the main isolate and the worker isolate.
// ---------------------------------------------------------------------------

sealed class _IsolateRequest {}

class _InitRequest extends _IsolateRequest {
  _InitRequest(this.settings, this.detectorBytes, this.axleClassifierBytes);
  final PipelineSettings settings;
  final Uint8List detectorBytes;
  final Uint8List? axleClassifierBytes;
}

class _ProcessFrameRequest extends _IsolateRequest {
  _ProcessFrameRequest({
    required this.jpegBytes,
    required this.cameraId,
    required this.frameIndex,
    required this.timestampUtc,
  });

  final Uint8List jpegBytes;
  final String cameraId;
  final int frameIndex;
  final DateTime timestampUtc;
}

class _UpdateLinesRequest extends _IsolateRequest {
  _UpdateLinesRequest(this.cameraId, this.lines);
  final String cameraId;
  final List<CountingLine> lines;
}

class _ResetCameraRequest extends _IsolateRequest {
  _ResetCameraRequest(this.cameraId);
  final String cameraId;
}

class _DisposeRequest extends _IsolateRequest {}

sealed class _IsolateResponse {}

class _InitDone extends _IsolateResponse {}

class _FrameResult extends _IsolateResponse {
  _FrameResult(this.result);
  final PipelineFrameResult result;
}

class _ErrorResponse extends _IsolateResponse {
  _ErrorResponse(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Manages a background isolate running the [InferencePipeline].
///
/// Usage:
/// ```dart
/// final runner = InferenceIsolateRunner();
/// await runner.start(PipelineSettings());
/// final result = await runner.processFrame(...);
/// runner.dispose();
/// ```
class InferenceIsolateRunner {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;

  final _responseController =
      StreamController<_IsolateResponse>.broadcast();
  StreamSubscription<Object?>? _subscription;

  bool get isRunning => _isolate != null;

  /// Spawn the worker isolate and load TFLite models.
  ///
  /// Model bytes are loaded from Flutter assets on the main isolate (where
  /// bindings are available) and then sent to the background isolate which
  /// creates interpreters via [Interpreter.fromBuffer].
  Future<void> start(PipelineSettings settings) async {
    if (_isolate != null) return;

    // Pre-load model bytes on the main isolate (rootBundle requires bindings).
    final detectorBytes = await _loadAssetBytes(settings.detector.modelPath);
    Uint8List? axleBytes;
    if (settings.classifier.mode == ClassificationMode.full12class ||
        settings.classifier.mode == ClassificationMode.hybridCloud) {
      axleBytes = await _loadAssetBytes(settings.stage2Detector.modelPath);
    }

    _receivePort = ReceivePort();
    final completer = Completer<SendPort>();

    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _receivePort!.sendPort,
    );

    _subscription = _receivePort!.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is _IsolateResponse) {
        _responseController.add(message);
      }
    });

    _sendPort = await completer.future;

    // Send init request and wait for acknowledgement.
    final initCompleter = Completer<void>();
    late final StreamSubscription<_IsolateResponse> sub;
    sub = _responseController.stream.listen((resp) {
      if (resp is _InitDone) {
        initCompleter.complete();
        sub.cancel();
      } else if (resp is _ErrorResponse) {
        initCompleter.completeError(Exception(resp.message));
        sub.cancel();
      }
    });

    _sendPort!.send(_InitRequest(settings, detectorBytes, axleBytes));
    await initCompleter.future;
  }

  static Future<Uint8List> _loadAssetBytes(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }

  /// Submit a frame for processing. Returns the pipeline result.
  Future<PipelineFrameResult> processFrame({
    required Uint8List jpegBytes,
    required String cameraId,
    required int frameIndex,
    DateTime? timestampUtc,
  }) {
    final completer = Completer<PipelineFrameResult>();
    late final StreamSubscription<_IsolateResponse> sub;
    sub = _responseController.stream.listen((resp) {
      if (resp is _FrameResult) {
        completer.complete(resp.result);
        sub.cancel();
      } else if (resp is _ErrorResponse) {
        completer.completeError(Exception(resp.message));
        sub.cancel();
      }
    });

    _sendPort!.send(
      _ProcessFrameRequest(
        jpegBytes: jpegBytes,
        cameraId: cameraId,
        frameIndex: frameIndex,
        timestampUtc: timestampUtc ?? DateTime.now().toUtc(),
      ),
    );

    return completer.future;
  }

  /// Update counting lines for a camera (forwarded to the isolate).
  void updateCountingLines(String cameraId, List<CountingLine> lines) {
    _sendPort?.send(_UpdateLinesRequest(cameraId, lines));
  }

  /// Reset all pipeline state for a camera.
  void resetCamera(String cameraId) {
    _sendPort?.send(_ResetCameraRequest(cameraId));
  }

  /// Shut down the worker isolate and release resources.
  void dispose() {
    _sendPort?.send(_DisposeRequest());
    _subscription?.cancel();
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _receivePort = null;
    _responseController.close();
  }
}

// ---------------------------------------------------------------------------
// Isolate entry point
// ---------------------------------------------------------------------------

void _isolateEntryPoint(SendPort mainSendPort) {
  final workerReceivePort = ReceivePort();
  mainSendPort.send(workerReceivePort.sendPort);

  InferencePipeline? pipeline;

  workerReceivePort.listen((message) async {
    if (message is _InitRequest) {
      try {
        pipeline = InferencePipeline(message.settings);
        pipeline!.loadFromBuffers(
          detectorBytes: message.detectorBytes,
          axleClassifierBytes: message.axleClassifierBytes,
        );
        mainSendPort.send(_InitDone());
      } catch (e) {
        mainSendPort.send(_ErrorResponse('Init failed: $e'));
      }
    } else if (message is _ProcessFrameRequest) {
      try {
        if (pipeline == null) {
          mainSendPort.send(_ErrorResponse('Pipeline not initialised'));
          return;
        }

        final frame = img.decodeJpg(message.jpegBytes);
        if (frame == null) {
          mainSendPort.send(_ErrorResponse('Failed to decode JPEG'));
          return;
        }

        final result = pipeline!.processFrame(
          frame: frame,
          cameraId: message.cameraId,
          frameIndex: message.frameIndex,
          timestampUtc: message.timestampUtc,
        );

        mainSendPort.send(_FrameResult(result));
      } catch (e) {
        mainSendPort.send(_ErrorResponse('Frame processing failed: $e'));
      }
    } else if (message is _UpdateLinesRequest) {
      pipeline?.updateCountingLines(message.cameraId, message.lines);
    } else if (message is _ResetCameraRequest) {
      pipeline?.resetCamera(message.cameraId);
    } else if (message is _DisposeRequest) {
      pipeline?.dispose();
      workerReceivePort.close();
    }
  });
}
