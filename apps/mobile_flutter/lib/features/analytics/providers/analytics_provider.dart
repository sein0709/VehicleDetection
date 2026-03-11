import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/database/database.dart';
import 'package:greyeye_mobile/core/database/database_provider.dart';
import 'package:greyeye_mobile/core/database/daos/crossings_dao.dart';
import 'package:greyeye_mobile/features/analytics/models/analytics_model.dart';

class AnalyticsParams {
  const AnalyticsParams({
    required this.cameraId,
    required this.start,
    required this.end,
    this.groupBy = 'class',
  });

  final String cameraId;
  final DateTime start;
  final DateTime end;
  final String groupBy;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalyticsParams &&
          cameraId == other.cameraId &&
          start == other.start &&
          end == other.end &&
          groupBy == other.groupBy;

  @override
  int get hashCode => Object.hash(cameraId, start, end, groupBy);
}

AnalyticsResponse _buildResponse(List<AggVehicleCount15m> rows) {
  final bucketMap = <DateTime, BucketData>{};

  for (final row in rows) {
    final bs = row.bucketStart;
    final existing = bucketMap[bs];
    if (existing != null) {
      final byClass = Map<int, int>.from(existing.byClass);
      byClass[row.class12] = (byClass[row.class12] ?? 0) + row.count;
      final byDir = Map<String, int>.from(existing.byDirection);
      byDir[row.direction] = (byDir[row.direction] ?? 0) + row.count;
      bucketMap[bs] = BucketData(
        bucketStart: bs,
        bucketEnd: bs.add(const Duration(minutes: 15)),
        totalCount: existing.totalCount + row.count,
        byClass: byClass,
        byDirection: byDir,
      );
    } else {
      bucketMap[bs] = BucketData(
        bucketStart: bs,
        bucketEnd: bs.add(const Duration(minutes: 15)),
        totalCount: row.count,
        byClass: {row.class12: row.count},
        byDirection: {row.direction: row.count},
      );
    }
  }

  final buckets = bucketMap.values.toList()
    ..sort((a, b) => a.bucketStart.compareTo(b.bucketStart));

  return AnalyticsResponse(buckets: buckets);
}

final analyticsProvider =
    FutureProvider.family<AnalyticsResponse, AnalyticsParams>(
  (ref, params) async {
    final dao = ref.watch(crossingsDaoProvider);
    final rows = await dao.aggregatesForCamera(
      params.cameraId,
      from: params.start.toUtc(),
      to: params.end.toUtc(),
    );
    return _buildResponse(rows);
  },
);

/// Local live KPI computed from recent crossings, refreshed periodically.
class LiveKpiNotifier extends StateNotifier<LiveKpiUpdate?> {
  LiveKpiNotifier(this._crossingsDao, this._cameraId) : super(null) {
    _startPolling();
  }

  final CrossingsDao _crossingsDao;
  final String _cameraId;
  Timer? _timer;

  void _startPolling() {
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final now = DateTime.now().toUtc();
      final bucketMinute = (now.minute ~/ 15) * 15;
      final bucketStart =
          DateTime.utc(now.year, now.month, now.day, now.hour, bucketMinute);
      final elapsed = now.difference(bucketStart).inSeconds.toDouble();

      final crossings = await _crossingsDao.crossingsForCamera(
        _cameraId,
        after: bucketStart,
        before: now,
      );

      final byClass = <int, int>{};
      final byDirection = <String, int>{};
      for (final c in crossings) {
        byClass[c.class12] = (byClass[c.class12] ?? 0) + 1;
        byDirection[c.direction] = (byDirection[c.direction] ?? 0) + 1;
      }

      final total = crossings.length;
      final flowRate =
          elapsed > 0 ? (total / elapsed * 3600).roundToDouble() : 0.0;

      state = LiveKpiUpdate(
        cameraId: _cameraId,
        currentBucket: bucketStart,
        elapsedSeconds: elapsed,
        totalCount: total,
        byClass: byClass,
        byDirection: byDirection,
        activeTracks: 0,
        flowRatePerHour: flowRate,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final liveKpiProvider = StateNotifierProvider.autoDispose
    .family<LiveKpiNotifier, LiveKpiUpdate?, String>((ref, cameraId) {
  return LiveKpiNotifier(ref.watch(crossingsDaoProvider), cameraId);
});
