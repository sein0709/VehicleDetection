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
    this.twoWheelerBreakdown = const [],
  });

  /// Prefer server-provided `total_vehicles_counted` when numeric; otherwise
  /// the sum of [breakdown] counts (or flat class rows when building breakdown).
  final int totalVehiclesCounted;

  /// Sorted by count descending; ties broken by [label] ascending.
  final List<VideoAnalysisBreakdownEntry> breakdown;

  /// 2-wheeler counts (bicycle, motorcycle, personal mobility). Empty when
  /// the server doesn't emit a `two_wheeler_breakdown` block, e.g. older
  /// pipeline versions.
  final List<VideoAnalysisBreakdownEntry> twoWheelerBreakdown;

  factory VideoAnalysisRemoteResult.fromJson(Map<String, dynamic> json) {
    final breakdown = _parseBreakdown(json);
    final total = _resolveTotal(json, breakdown);
    return VideoAnalysisRemoteResult(
      totalVehiclesCounted: total,
      breakdown: _sortBreakdown(breakdown),
      twoWheelerBreakdown: _sortBreakdown(_parseTwoWheelerBreakdown(json)),
    );
  }
}

/// Keys that are not per-class counts when reading a flat map.
///
/// Keep this list aligned with the server's response shape. When in doubt,
/// add a new metadata key here — false positives in the breakdown are far
/// worse than a missing class row.
const Set<String> _videoAnalysisMetadataKeys = {
  'total_vehicles_counted',
  'breakdown',
  'two_wheeler_breakdown',
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
  // Timestamp / lifecycle fields the server may stamp at the top level.
  // Triggered by the 2026-04-20 incident where a stray top-level
  // `finished_at: 1776681446.123` was rendered as "1.7B vehicles".
  'finished_at',
  'started_at',
  'created_at',
  'updated_at',
  'processed_at',
  'epoch',
  'unix_time',
};

/// Suffix-based metadata filter for keys we can't enumerate in advance.
/// Catches the family the explicit list misses: e.g. `*_at`, `*_time`,
/// `*_ms`, `*_ns`, `*_epoch`. Conservative — only patterns that are
/// unambiguously temporal.
const List<String> _videoAnalysisMetadataKeySuffixes = [
  '_at',
  '_time',
  '_timestamp',
  '_ms',
  '_ns',
  '_us',
  '_epoch',
];

/// Per-class count ceiling. Any value larger than this is implausible for a
/// short video clip (the server caps uploads at 5 minutes) and is almost
/// certainly a timestamp / epoch leak from the response. We drop such entries
/// rather than risk displaying 1.7-billion-vehicle nonsense.
const int _kMaxPerClassCount = 1000000;

bool _isMetadataKey(String key) {
  if (_videoAnalysisMetadataKeys.contains(key)) return true;
  for (final suffix in _videoAnalysisMetadataKeySuffixes) {
    if (key.endsWith(suffix)) return true;
  }
  return false;
}

List<VideoAnalysisBreakdownEntry> _parseBreakdown(Map<String, dynamic> json) {
  final raw = json['breakdown'];
  if (raw != null) {
    return _breakdownFromStructured(raw);
  }
  return _breakdownFromFlatMap(json);
}

List<VideoAnalysisBreakdownEntry> _parseTwoWheelerBreakdown(
  Map<String, dynamic> json,
) {
  final raw = json['two_wheeler_breakdown'];
  if (raw == null) return const [];
  return _breakdownFromStructured(raw);
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
    if (_isMetadataKey(key)) continue;
    final n = _coerceNonNegativeInt(e.value);
    if (n == null) continue;
    if (n > _kMaxPerClassCount) continue;
    out.add(VideoAnalysisBreakdownEntry(label: key, count: n));
  }
  return out;
}

int _resolveTotal(
  Map<String, dynamic> json,
  List<VideoAnalysisBreakdownEntry> breakdown,
) {
  final explicit = _coerceNonNegativeInt(json['total_vehicles_counted']);
  // Trust the explicit total only if it survives the same sanity ceiling
  // we apply to per-class entries — otherwise an absurd server response
  // would still leak through this path.
  if (explicit != null && explicit <= _kMaxPerClassCount) return explicit;

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
