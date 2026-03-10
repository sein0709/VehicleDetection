import 'package:flutter/foundation.dart';

@immutable
class BucketData {
  const BucketData({
    required this.bucketStart,
    required this.bucketEnd,
    required this.totalCount,
    this.byClass = const {},
    this.byDirection = const {},
  });

  final DateTime bucketStart;
  final DateTime bucketEnd;
  final int totalCount;
  final Map<int, int> byClass;
  final Map<String, int> byDirection;

  int get inboundCount => byDirection['inbound'] ?? 0;
  int get outboundCount => byDirection['outbound'] ?? 0;

  factory BucketData.fromJson(Map<String, dynamic> json) => BucketData(
        bucketStart: DateTime.parse(json['bucket_start'] as String),
        bucketEnd: DateTime.parse(json['bucket_end'] as String),
        totalCount: json['total_count'] as int,
        byClass: (json['by_class'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(int.parse(k), v as int),
            ) ??
            {},
        byDirection: (json['by_direction'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v as int),
            ) ??
            {},
      );
}

@immutable
class AnalyticsResponse {
  const AnalyticsResponse({
    required this.cameraId,
    required this.start,
    required this.end,
    required this.buckets,
    this.hasMore = false,
    this.cursor,
  });

  final String cameraId;
  final DateTime start;
  final DateTime end;
  final List<BucketData> buckets;
  final bool hasMore;
  final String? cursor;

  int get totalVehicles =>
      buckets.fold(0, (sum, b) => sum + b.totalCount);

  Map<int, int> get aggregatedByClass {
    final result = <int, int>{};
    for (final bucket in buckets) {
      for (final entry in bucket.byClass.entries) {
        result[entry.key] = (result[entry.key] ?? 0) + entry.value;
      }
    }
    return result;
  }

  factory AnalyticsResponse.fromJson(Map<String, dynamic> json) =>
      AnalyticsResponse(
        cameraId: json['camera_id'] as String,
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        buckets: (json['buckets'] as List<dynamic>)
            .map((b) => BucketData.fromJson(b as Map<String, dynamic>))
            .toList(),
        hasMore: (json['pagination'] as Map<String, dynamic>?)?['has_more']
                as bool? ??
            false,
        cursor: (json['pagination'] as Map<String, dynamic>?)?['cursor']
            as String?,
      );
}

@immutable
class LiveKpiUpdate {
  const LiveKpiUpdate({
    required this.cameraId,
    required this.currentBucket,
    required this.elapsedSeconds,
    required this.totalCount,
    this.byClass = const {},
    this.byDirection = const {},
    this.activeTracks = 0,
    this.flowRatePerHour = 0,
  });

  final String cameraId;
  final DateTime currentBucket;
  final int elapsedSeconds;
  final int totalCount;
  final Map<int, int> byClass;
  final Map<String, int> byDirection;
  final int activeTracks;
  final int flowRatePerHour;

  factory LiveKpiUpdate.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'] as Map<String, dynamic>? ?? {};
    return LiveKpiUpdate(
      cameraId: json['camera_id'] as String,
      currentBucket: DateTime.parse(json['current_bucket'] as String),
      elapsedSeconds: json['elapsed_seconds'] as int? ?? 0,
      totalCount: counts['total'] as int? ?? 0,
      byClass: (counts['by_class'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(int.parse(k), v as int),
          ) ??
          {},
      byDirection: (counts['by_direction'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ??
          {},
      activeTracks: json['active_tracks'] as int? ?? 0,
      flowRatePerHour: json['flow_rate_per_hour'] as int? ?? 0,
    );
  }
}
