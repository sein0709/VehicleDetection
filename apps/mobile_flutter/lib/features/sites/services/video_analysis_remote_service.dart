import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../models/video_analysis_remote_result.dart';

/// Dedicated [Dio] instance for the initial video upload.
final videoAnalysisDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 5),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
});

final videoAnalysisRemoteServiceProvider =
    Provider<VideoAnalysisRemoteService>((ref) {
  return VideoAnalysisRemoteService(ref.watch(videoAnalysisDioProvider));
});

class VideoAnalysisRemoteService {
  VideoAnalysisRemoteService(this._dio);

  final Dio _dio;

  static const _pollInterval = Duration(seconds: 3);

  /// Uploads [filePath] and returns the job ID assigned by the server.
  ///
  /// The server responds quickly with `{ "job_id": "...", "status": "processing" }`.
  /// Use [pollUntilComplete] to wait for the final result.
  ///
  /// [calibrationJson], when supplied, is forwarded as the multipart
  /// `calibration` field. This is how the client opts into the annotated
  /// MP4 output (e.g. `'{"output_video": true}'`); the server's
  /// `parse_calibration` reads it and gates `pipeline.py`'s annotator.
  Future<String> submitVideo(
    String filePath, {
    String? calibrationJson,
  }) async {
    // TODO(debug): remove after confirming uploads work end-to-end
    final fileSize = await File(filePath).length();
    debugPrint(
      '[VideoAnalysis] Uploading "$filePath" — ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB ($fileSize bytes)',
    );

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      if (calibrationJson != null && calibrationJson.isNotEmpty)
        'calibration': calibrationJson,
    });

    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.analyzeVideoUrl,
        data: formData,
      );
    } on DioException catch (e) {
      throw VideoAnalysisException(_messageFromDioException(e));
    }

    final data = response.data;
    final jobId = data?['job_id'] as String?;
    if (jobId == null || jobId.isEmpty) {
      throw const VideoAnalysisException(
        'Server did not return a job_id. Is the backend updated?',
      );
    }
    return jobId;
  }

  /// Streams the annotated MP4 for [jobId] to [destPath].
  ///
  /// Returns [destPath] on success. Throws [VideoAnalysisException] with a
  /// human-readable message on failure (404 if `output_video` wasn't enabled,
  /// timeouts, network errors, etc).
  ///
  /// [kind] is `classified` (default) for the per-class bbox overlay or
  /// `transit` for the head-circle / boarding overlay. Use [onProgress] to
  /// drive a progress bar; `total` is `-1` when the server doesn't send a
  /// Content-Length header (the FastAPI `FileResponse` does, so this is rare).
  Future<String> downloadAnnotatedVideo({
    required String jobId,
    required String destPath,
    String kind = 'classified',
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      await _dio.download(
        ApiConstants.videoUrl(jobId, kind: kind),
        destPath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        // Annotated MP4 transfer can be many MB over a slow link — give the
        // socket up to 10 minutes of receive idle before bailing.
        options: Options(receiveTimeout: const Duration(minutes: 10)),
      );
      return destPath;
    } on DioException catch (e) {
      // Best-effort cleanup of the partially-written file. existsSync()
      // is the analyzer-preferred form (avoid_slow_async_io); a stat
      // hop is fine here since we've already errored out.
      try {
        final f = File(destPath);
        if (f.existsSync()) await f.delete();
      } on Exception {
        /* ignore */
      }
      throw VideoAnalysisException(_messageFromDioException(e));
    }
  }

  /// Polls `GET /status/<jobId>` every 3 seconds until the server returns a
  /// terminal status (`success` or an error).
  ///
  /// Returns the parsed [VideoAnalysisRemoteResult] on success.
  Future<VideoAnalysisRemoteResult> pollUntilComplete(String jobId) async {
    while (true) {
      final status = await _checkJobStatus(jobId);
      final state = status['status'] as String? ?? '';

      if (state == 'success') {
        return VideoAnalysisRemoteResult.fromJson(status);
      }

      if (state == 'error' || state == 'failed') {
        final msg =
            status['message'] as String? ?? 'Analysis failed on the server.';
        throw VideoAnalysisException(msg);
      }

      await Future<void>.delayed(_pollInterval);
    }
  }

  /// Pre-flight traffic-light ROI preview.
  ///
  /// Uploads [frameBytes] (a JPEG/PNG-encoded keyframe extracted on-device)
  /// and returns the list of proposed light bboxes. Throws
  /// [VideoAnalysisException] when the VLM is unavailable on the server (HTTP
  /// 503) so the UI can drop the operator straight into the manual editor.
  Future<List<TrafficLightRoiProposal>> previewTrafficLightRoi(
    Uint8List frameBytes, {
    String filename = 'frame.jpg',
  }) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        frameBytes,
        filename: filename,
      ),
    });

    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.trafficLightPreviewUrl,
        data: formData,
        options: Options(
          // VLM round-trip can take a few seconds even on a cached crop;
          // give it more headroom than the default 30s receive timeout.
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
    } on DioException catch (e) {
      throw VideoAnalysisException(_messageFromDioException(e));
    }

    final data = response.data;
    if (data == null) {
      throw const VideoAnalysisException(
        'Server returned an empty preview response.',
      );
    }
    final raw = data['lights'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) TrafficLightRoiProposal.fromJson(item),
    ];
  }

  /// Single GET to the job status endpoint.
  Future<Map<String, dynamic>> _checkJobStatus(String jobId) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.jobStatusUrl(jobId),
      );
    } on DioException catch (e) {
      throw VideoAnalysisException(_messageFromDioException(e));
    }

    final data = response.data;
    if (data == null) {
      throw const VideoAnalysisException(
        'Server returned an empty status response.',
      );
    }
    return data;
  }
}

class VideoAnalysisException implements Exception {
  const VideoAnalysisException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// One traffic-light bbox proposal returned by the preview endpoint.
/// Coordinates are normalized 0..1 (caller scales by the displayed image
/// dimensions for overlay rendering).
class TrafficLightRoiProposal {
  const TrafficLightRoiProposal({
    required this.label,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    required this.aboveThreshold,
  });

  final String label;
  final double x;
  final double y;
  final double width;
  final double height;
  final double confidence;
  final bool aboveThreshold;

  factory TrafficLightRoiProposal.fromJson(Map<dynamic, dynamic> json) {
    final roiRaw = json['roi'];
    final roi = roiRaw is List && roiRaw.length == 4
        ? roiRaw.map((v) => (v as num).toDouble()).toList()
        : <double>[0, 0, 0, 0];
    return TrafficLightRoiProposal(
      label: (json['label'] ?? 'main').toString(),
      x: roi[0],
      y: roi[1],
      width: roi[2],
      height: roi[3],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      aboveThreshold: json['above_threshold'] == true,
    );
  }
}

String _messageFromDioException(DioException e) {
  return switch (e.type) {
    DioExceptionType.connectionTimeout =>
      'Connection timed out. Check your network and try again.',
    DioExceptionType.sendTimeout =>
      'Upload timed out. The video may be too large or your connection too slow.',
    DioExceptionType.receiveTimeout =>
      'The server took too long to respond. Please try again.',
    DioExceptionType.connectionError =>
      'Could not reach the analysis server. Check your internet connection.',
    DioExceptionType.badResponse => _messageFromBadResponse(e),
    _ => e.message ?? 'An unexpected network error occurred.',
  };
}

String _messageFromBadResponse(DioException e) {
  final code = e.response?.statusCode;
  final reason = e.response?.statusMessage;
  final reasonText =
      (reason != null && reason.isNotEmpty) ? reason : 'no details';

  if (code == 524) {
    return 'Request timed out at the network edge (HTTP 524). '
        'Please try again shortly.';
  }
  if (code == 504 || code == 502) {
    return 'Gateway error (HTTP $code). '
        'The analysis server may be overloaded. Please try again.';
  }

  return 'Server error (HTTP $code: $reasonText).';
}
