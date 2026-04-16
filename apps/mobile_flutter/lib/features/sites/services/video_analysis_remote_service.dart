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
  Future<String> submitVideo(String filePath) async {
    // TODO(debug): remove after confirming uploads work end-to-end
    final fileSize = await File(filePath).length();
    debugPrint(
      '[VideoAnalysis] Uploading "$filePath" — ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB ($fileSize bytes)',
    );

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
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
