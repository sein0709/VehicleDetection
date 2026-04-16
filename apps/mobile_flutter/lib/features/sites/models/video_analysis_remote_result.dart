/// Normalized remote video analysis counts (RunPod / similar JSON).
class VideoAnalysisBreakdownEntry {
  const VideoAnalysisBreakdownEntry({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;
}

class VideoAnalysisRemoteResult {
  const VideoAnalysisRemoteResult({
    required this.totalVehiclesCounted,
    required this.breakdown,
  });

  /// Prefer server-provided `total_vehicles_counted` when numeric; otherwise
  /// the sum of [breakdown] counts (or flat class rows when building breakdown).
  final int totalVehiclesCounted;

  /// Sorted by count descending; ties broken by [label] ascending.
  final List<VideoAnalysisBreakdownEntry> breakdown;

  factory VideoAnalysisRemoteResult.fromJson(Map<String, dynamic> json) {
    final breakdown = _parseBreakdown(json);
    final total = _resolveTotal(json, breakdown);
    return VideoAnalysisRemoteResult(
      totalVehiclesCounted: total,
      breakdown: _sortBreakdown(breakdown),
    );
  }
}

/// Keys that are not per-class counts when reading a flat map.
const Set<String> _videoAnalysisMetadataKeys = {
  'total_vehicles_counted',
  'breakdown',
  'status',
  'message',
  'error',
  'errors',
  'detail',
  'details',
  'request_id',
  'job_id',
  'id',
  'timestamp',
};

List<VideoAnalysisBreakdownEntry> _parseBreakdown(Map<String, dynamic> json) {
  final raw = json['breakdown'];
  if (raw != null) {
    return _breakdownFromStructured(raw);
  }
  return _breakdownFromFlatMap(json);
}

List<VideoAnalysisBreakdownEntry> _breakdownFromStructured(dynamic raw) {
  if (raw is Map) {
    final out = <VideoAnalysisBreakdownEntry>[];
    for (final e in raw.entries) {
      final label = e.key.toString().trim();
      if (label.isEmpty) continue;
      final n = _coerceNonNegativeInt(e.value);
      if (n != null) {
        out.add(VideoAnalysisBreakdownEntry(label: label, count: n));
      }
    }
    return out;
  }
  if (raw is List) {
    final out = <VideoAnalysisBreakdownEntry>[];
    for (final item in raw) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(
          item.map((k, v) => MapEntry(k.toString(), v)),
        );
        final label = _readLabel(map);
        final count = _readCount(map);
        if (label != null && count != null) {
          out.add(VideoAnalysisBreakdownEntry(label: label, count: count));
        }
      }
    }
    return out;
  }
  return const [];
}

List<VideoAnalysisBreakdownEntry> _breakdownFromFlatMap(
  Map<String, dynamic> json,
) {
  final out = <VideoAnalysisBreakdownEntry>[];
  for (final e in json.entries) {
    final key = e.key;
    if (_videoAnalysisMetadataKeys.contains(key)) continue;
    final n = _coerceNonNegativeInt(e.value);
    if (n == null) continue;
    out.add(VideoAnalysisBreakdownEntry(label: key, count: n));
  }
  return out;
}

int _resolveTotal(
  Map<String, dynamic> json,
  List<VideoAnalysisBreakdownEntry> breakdown,
) {
  final explicit = _coerceNonNegativeInt(json['total_vehicles_counted']);
  if (explicit != null) return explicit;

  var sum = 0;
  for (final e in breakdown) {
    sum += e.count;
  }
  return sum;
}

List<VideoAnalysisBreakdownEntry> _sortBreakdown(
  List<VideoAnalysisBreakdownEntry> entries,
) {
  final copy = List<VideoAnalysisBreakdownEntry>.from(entries);
  copy.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    return a.label.compareTo(b.label);
  });
  return copy;
}

String? _readLabel(Map<String, dynamic> map) {
  for (final k in const ['label', 'name', 'class', 'category', 'type']) {
    final v = map[k];
    if (v != null) {
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
  }
  return null;
}

int? _readCount(Map<String, dynamic> map) {
  for (final k in const ['count', 'value', 'total', 'n']) {
    final n = _coerceNonNegativeInt(map[k]);
    if (n != null) return n;
  }
  return null;
}

int? _coerceNonNegativeInt(dynamic value) {
  if (value is int) return value < 0 ? null : value;
  if (value is double) {
    if (value.isNaN || value.isInfinite) return null;
    final i = value.round();
    return i < 0 ? null : i;
  }
  if (value is num) {
    final i = value.round();
    return i < 0 ? null : i;
  }
  return null;
}
