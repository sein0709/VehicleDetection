/// Batching queue for asynchronous VLM vehicle classification requests.
///
/// Accumulates JPEG crops from crossing events and flushes them to the
/// [VlmClient] when the batch is full or a timeout expires. On success the
/// crossing record in SQLite is updated via [CrossingsDao]; on failure the
/// local fallback class is retained.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:greyeye_mobile/core/database/daos/crossings_dao.dart';
import 'package:greyeye_mobile/core/inference/pipeline_settings.dart';
import 'package:greyeye_mobile/core/inference/vlm_client.dart';

/// A single pending VLM classification request.
class VlmRequest {
  const VlmRequest({
    required this.crossingId,
    required this.jpegCrop,
    required this.localFallbackClass,
    required this.localFallbackConfidence,
  });

  /// Primary key of the [VehicleCrossings] row to update.
  final String crossingId;

  /// JPEG-encoded vehicle crop image.
  final Uint8List jpegCrop;

  /// Class code from the local AxleClassifier, used if the VLM call fails.
  final int localFallbackClass;

  /// Confidence from the local AxleClassifier.
  final double localFallbackConfidence;
}

/// Per-session statistics for VLM queue operations.
class VlmQueueStats {
  int totalEnqueued = 0;
  int totalFlushed = 0;
  int totalSucceeded = 0;
  int totalFailed = 0;
  int totalFallbacks = 0;
  Duration totalLatency = Duration.zero;

  double get averageLatencyMs =>
      totalFlushed == 0 ? 0 : totalLatency.inMilliseconds / totalFlushed;

  double get successRate =>
      totalFlushed == 0 ? 0 : totalSucceeded / totalFlushed;

  @override
  String toString() =>
      'VlmQueueStats(enqueued=$totalEnqueued, flushed=$totalFlushed, '
      'succeeded=$totalSucceeded, failed=$totalFailed, '
      'fallbacks=$totalFallbacks, avgLatency=${averageLatencyMs.toStringAsFixed(1)}ms)';
}

/// Callback signature for VLM refinement results.
///
/// Fired after each crossing is updated (or falls back), allowing the UI to
/// react without polling the database.
typedef VlmRefinementCallback = void Function(
  String crossingId,
  int classCode,
  double confidence,
  String source,
);

class VlmRequestQueue {
  VlmRequestQueue({
    required VlmClient client,
    required CrossingsDao crossingsDao,
    required VlmSettings settings,
    this.onRefinement,
  })  : _client = client,
        _crossingsDao = crossingsDao,
        _maxBatchSize = settings.batchSize,
        _batchTimeout = Duration(milliseconds: settings.batchTimeoutMs);

  final VlmClient _client;
  final CrossingsDao _crossingsDao;
  final int _maxBatchSize;
  final Duration _batchTimeout;

  /// Optional callback invoked after each crossing is refined or falls back.
  final VlmRefinementCallback? onRefinement;

  final List<VlmRequest> _pending = [];
  Timer? _timer;
  bool _disposed = false;
  bool _flushing = false;

  final VlmQueueStats stats = VlmQueueStats();

  /// Number of requests waiting to be flushed.
  int get pendingCount => _pending.length;

  /// Add a crossing crop to the queue.
  ///
  /// The batch is flushed immediately when [_maxBatchSize] is reached.
  /// Otherwise a timeout timer ensures the batch is sent within
  /// [_batchTimeout] even if the batch never fills up.
  void enqueue(VlmRequest request) {
    if (_disposed) {
      debugPrint('VlmRequestQueue: enqueue called after dispose, ignoring');
      return;
    }

    _pending.add(request);
    stats.totalEnqueued++;

    if (_pending.length >= _maxBatchSize) {
      _flush();
    } else {
      _ensureTimer();
    }
  }

  /// Flush any pending requests immediately, regardless of batch size.
  ///
  /// Safe to call even when the queue is empty.
  Future<void> flush() => _flush();

  /// Cancel pending timers, flush remaining requests, and release resources.
  ///
  /// After disposal, [enqueue] calls are silently ignored.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;

    if (_pending.isNotEmpty) {
      await _flush();
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _ensureTimer() {
    _timer ??= Timer(_batchTimeout, _flush);
  }

  Future<void> _flush() async {
    _timer?.cancel();
    _timer = null;

    if (_pending.isEmpty || _flushing) return;
    _flushing = true;

    final batch = List<VlmRequest>.of(_pending);
    _pending.clear();

    try {
      await _processBatch(batch);
    } finally {
      _flushing = false;

      // If new items arrived while we were flushing, restart the timer.
      if (_pending.isNotEmpty && !_disposed) {
        if (_pending.length >= _maxBatchSize) {
          unawaited(_flush());
        } else {
          _ensureTimer();
        }
      }
    }
  }

  Future<void> _processBatch(List<VlmRequest> batch) async {
    final stopwatch = Stopwatch()..start();

    try {
      final crops = batch.map((r) => r.jpegCrop).toList();
      final results = await _client.classifyBatch(crops);
      stopwatch.stop();
      stats.totalLatency += stopwatch.elapsed;
      stats.totalFlushed += batch.length;

      for (var i = 0; i < batch.length; i++) {
        final request = batch[i];
        if (i < results.length) {
          await _applyResult(request, results[i]);
        } else {
          await _applyFallback(request, 'VLM returned fewer results than crops');
        }
      }
    } on Exception catch (e) {
      stopwatch.stop();
      stats.totalLatency += stopwatch.elapsed;
      stats.totalFlushed += batch.length;
      stats.totalFailed += batch.length;
      stats.totalFallbacks += batch.length;

      debugPrint('VlmRequestQueue: batch failed, applying fallbacks: $e');

      for (final request in batch) {
        await _applyFallback(request, e.toString());
      }
    }
  }

  Future<void> _applyResult(
    VlmRequest request,
    VlmClassificationResult result,
  ) async {
    try {
      final updated = await _crossingsDao.updateCrossingClass(
        request.crossingId,
        classCode: result.classCode,
        confidence: result.confidence,
      );

      if (updated) {
        stats.totalSucceeded++;
        onRefinement?.call(
          request.crossingId,
          result.classCode,
          result.confidence,
          'vlm',
        );
      } else {
        stats.totalFailed++;
        debugPrint(
          'VlmRequestQueue: crossing ${request.crossingId} not found in DB',
        );
      }
    } on Exception catch (e) {
      stats.totalFailed++;
      stats.totalFallbacks++;
      debugPrint(
        'VlmRequestQueue: DB update failed for ${request.crossingId}: $e',
      );
      onRefinement?.call(
        request.crossingId,
        request.localFallbackClass,
        request.localFallbackConfidence,
        'fallback',
      );
    }
  }

  Future<void> _applyFallback(VlmRequest request, String reason) async {
    debugPrint(
      'VlmRequestQueue: fallback for ${request.crossingId}: $reason',
    );
    onRefinement?.call(
      request.crossingId,
      request.localFallbackClass,
      request.localFallbackConfidence,
      'fallback',
    );
  }
}
