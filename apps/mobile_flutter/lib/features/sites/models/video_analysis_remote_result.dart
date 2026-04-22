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
    required this.jobId,
    required this.totalVehiclesCounted,
    required this.breakdown,
    this.twoWheelerBreakdown = const [],
    this.pedestriansCount = 0,
    this.speed,
    this.transit,
    this.trafficLights = const [],
    this.plateSummary,
    this.plates = const [],
    this.hasClassifiedVideo = false,
    this.hasTransitVideo = false,
  });

  /// Server-issued job identifier. Required to fetch the annotated MP4
  /// from `/video/{jobId}`. Empty when the response omitted it (older
  /// servers / mocked tests) — UI hides video download in that case.
  final String jobId;

  /// Prefer server-provided `total_vehicles_counted` when numeric; otherwise
  /// the sum of [breakdown] counts (or flat class rows when building breakdown).
  final int totalVehiclesCounted;

  /// Sorted by count descending; ties broken by [label] ascending.
  final List<VideoAnalysisBreakdownEntry> breakdown;

  /// 2-wheeler counts (bicycle, motorcycle, personal mobility). Empty when
  /// the server doesn't emit a `two_wheeler_breakdown` block, e.g. older
  /// pipeline versions.
  final List<VideoAnalysisBreakdownEntry> twoWheelerBreakdown;

  /// F2 — pedestrian count from `totals.pedestrians`. 0 when the server
  /// didn't run pedestrian detection (`ENABLE_PEDESTRIAN_DETECTOR=0`).
  final int pedestriansCount;

  /// F4 — speed analytics block, present only when calibration enabled
  /// the speed task and the source quad / line ratios were valid.
  final VideoAnalysisSpeed? speed;

  /// F6 — transit (boarding / alighting / density) analytics block,
  /// present only when calibration enabled the transit task.
  final VideoAnalysisTransit? transit;

  /// F7 — per-light state-machine summary. Empty unless the calibration
  /// included `traffic_light` / `traffic_lights`.
  final List<VideoAnalysisTrafficLight> trafficLights;

  /// F5 — high-level plate counts (resident vs visitor). Present only
  /// when calibration enabled the LPR task.
  final VideoAnalysisPlateSummary? plateSummary;

  /// F5 — per-track plate records. Empty unless LPR ran.
  final List<VideoAnalysisPlate> plates;

  /// True when the server wrote a class-annotated MP4 for this job
  /// (i.e. the request included `calibration.output_video=true`).
  /// Drives visibility of the "Download annotated video" action.
  final bool hasClassifiedVideo;

  /// True when the transit task wrote its own head-circle / boarding-colour
  /// overlay MP4 (`calibration.transit.output_video=true`).
  final bool hasTransitVideo;

  factory VideoAnalysisRemoteResult.fromJson(Map<String, dynamic> json) {
    final breakdown = _parseBreakdown(json);
    final total = _resolveTotal(json, breakdown);
    return VideoAnalysisRemoteResult(
      jobId: (json['job_id'] as Object?)?.toString() ?? '',
      totalVehiclesCounted: total,
      breakdown: _sortBreakdown(breakdown),
      twoWheelerBreakdown: _sortBreakdown(_parseTwoWheelerBreakdown(json)),
      pedestriansCount: _parsePedestriansCount(json),
      speed: VideoAnalysisSpeed.tryParse(json['speed']),
      transit: VideoAnalysisTransit.tryParse(json['transit']),
      trafficLights: VideoAnalysisTrafficLight.parseList(json['traffic_light']),
      plateSummary:
          VideoAnalysisPlateSummary.tryParse(json['plate_summary']),
      plates: VideoAnalysisPlate.parseMap(json['plates']),
      hasClassifiedVideo: _isNonEmptyString(json['annotated_video']),
      hasTransitVideo: _hasTransitAnnotatedVideo(json),
    );
  }
}

// ---------------------------------------------------------------------------
// F4 — Speed
// ---------------------------------------------------------------------------

class VideoAnalysisSpeed {
  const VideoAnalysisSpeed({
    required this.vehiclesMeasured,
    this.avgKmh,
    this.minKmh,
    this.maxKmh,
    this.perTrack = const {},
  });

  final int vehiclesMeasured;
  final double? avgKmh;
  final double? minKmh;
  final double? maxKmh;
  /// Map of `track_id` (string) → measured km/h.
  final Map<String, double> perTrack;

  static VideoAnalysisSpeed? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final perTrackRaw = raw['per_track'];
    final perTrack = <String, double>{};
    if (perTrackRaw is Map) {
      for (final e in perTrackRaw.entries) {
        final v = _coerceDouble(e.value);
        if (v != null) perTrack[e.key.toString()] = v;
      }
    }
    final measured = _coerceNonNegativeInt(raw['vehicles_measured']) ?? 0;
    return VideoAnalysisSpeed(
      vehiclesMeasured: measured,
      avgKmh: _coerceDouble(raw['avg_kmh']),
      minKmh: _coerceDouble(raw['min_kmh']),
      maxKmh: _coerceDouble(raw['max_kmh']),
      perTrack: perTrack,
    );
  }
}

// ---------------------------------------------------------------------------
// F6 — Transit
// ---------------------------------------------------------------------------

class VideoAnalysisTransit {
  const VideoAnalysisTransit({
    required this.peakCount,
    required this.avgDensityPct,
    required this.boarding,
    required this.alighting,
    required this.busGated,
  });

  final int peakCount;
  final double avgDensityPct;
  final int boarding;
  final int alighting;

  /// True when door-line counting was gated on bus presence (i.e. a
  /// `bus_zone_polygon` was configured). Surfaced so operators can spot
  /// the difference between "0 boarding" because no bus arrived vs
  /// because the gate was overly tight.
  final bool busGated;

  static VideoAnalysisTransit? tryParse(Object? raw) {
    if (raw is! Map) return null;
    return VideoAnalysisTransit(
      peakCount: _coerceNonNegativeInt(raw['peak_count']) ?? 0,
      avgDensityPct: _coerceDouble(raw['avg_density_pct']) ?? 0.0,
      boarding: _coerceNonNegativeInt(raw['boarding']) ?? 0,
      alighting: _coerceNonNegativeInt(raw['alighting']) ?? 0,
      busGated: raw['bus_gated'] == true,
    );
  }
}

// ---------------------------------------------------------------------------
// F7 — Traffic Light
// ---------------------------------------------------------------------------

class VideoAnalysisTrafficLightCycle {
  const VideoAnalysisTrafficLightCycle({
    required this.cycles,
    required this.avgDurationS,
    required this.totalDurationS,
  });

  final int cycles;
  final double avgDurationS;
  final double totalDurationS;

  static VideoAnalysisTrafficLightCycle parse(Object? raw) {
    if (raw is! Map) {
      return const VideoAnalysisTrafficLightCycle(
        cycles: 0,
        avgDurationS: 0,
        totalDurationS: 0,
      );
    }
    return VideoAnalysisTrafficLightCycle(
      cycles: _coerceNonNegativeInt(raw['cycles']) ?? 0,
      avgDurationS: _coerceDouble(raw['avg_duration_s']) ?? 0.0,
      totalDurationS: _coerceDouble(raw['total_duration_s']) ?? 0.0,
    );
  }
}

class VideoAnalysisTrafficLight {
  const VideoAnalysisTrafficLight({
    required this.label,
    required this.red,
    required this.green,
    required this.yellow,
  });

  final String label;
  final VideoAnalysisTrafficLightCycle red;
  final VideoAnalysisTrafficLightCycle green;
  final VideoAnalysisTrafficLightCycle yellow;

  /// Accepts the new `{traffic_lights: [...]}` shape AND the legacy
  /// `{cycles: {...}}` single-light fallback. Returns an empty list when
  /// neither is present.
  static List<VideoAnalysisTrafficLight> parseList(Object? raw) {
    if (raw is! Map) return const [];
    final lights = raw['traffic_lights'];
    if (lights is List) {
      return [
        for (final item in lights)
          if (item is Map) _parseSingle(Map<String, Object?>.from(item)),
      ];
    }
    final cycles = raw['cycles'];
    if (cycles is Map) {
      return [
        _parseSingle(<String, Object?>{
          'label': raw['label'] ?? 'main',
          'cycles': cycles,
        }),
      ];
    }
    return const [];
  }

  static VideoAnalysisTrafficLight _parseSingle(Map<String, Object?> raw) {
    final cycles = raw['cycles'];
    final cyclesMap = cycles is Map ? cycles : const <Object?, Object?>{};
    return VideoAnalysisTrafficLight(
      label: (raw['label'] ?? 'main').toString(),
      red: VideoAnalysisTrafficLightCycle.parse(cyclesMap['red']),
      green: VideoAnalysisTrafficLightCycle.parse(cyclesMap['green']),
      yellow: VideoAnalysisTrafficLightCycle.parse(cyclesMap['yellow']),
    );
  }
}

// ---------------------------------------------------------------------------
// F5 — Plates / LPR
// ---------------------------------------------------------------------------

class VideoAnalysisPlateSummary {
  const VideoAnalysisPlateSummary({
    required this.resident,
    required this.visitor,
    required this.total,
    required this.privacyHashed,
    required this.allowlistSize,
  });

  final int resident;
  final int visitor;
  final int total;
  final bool privacyHashed;
  final int allowlistSize;

  static VideoAnalysisPlateSummary? tryParse(Object? raw) {
    if (raw is! Map) return null;
    return VideoAnalysisPlateSummary(
      resident: _coerceNonNegativeInt(raw['resident']) ?? 0,
      visitor: _coerceNonNegativeInt(raw['visitor']) ?? 0,
      total: _coerceNonNegativeInt(raw['total']) ?? 0,
      privacyHashed: raw['privacy_hashed'] == true,
      allowlistSize: _coerceNonNegativeInt(raw['allowlist_size']) ?? 0,
    );
  }
}

class VideoAnalysisPlate {
  const VideoAnalysisPlate({
    required this.trackId,
    required this.category,
    this.text,
    this.textHash,
    this.source,
  });

  final String trackId;
  /// One of `resident`, `visitor`, `unknown`. Falls back to `unknown` when
  /// the server returned an unrecognised value.
  final String category;
  /// Raw normalized plate text. Null when the job ran with `hash_plates=true`.
  final String? text;
  /// SHA-256 prefix of the plate. Null when the job ran with `hash_plates=false`.
  final String? textHash;
  /// One of `gemma`, `easyocr`, `both`, or null if the server didn't tag.
  final String? source;

  static List<VideoAnalysisPlate> parseMap(Object? raw) {
    if (raw is! Map) return const [];
    final out = <VideoAnalysisPlate>[];
    for (final e in raw.entries) {
      final rec = e.value;
      if (rec is! Map) continue;
      final category = (rec['category'] ?? 'unknown').toString();
      out.add(VideoAnalysisPlate(
        trackId: e.key.toString(),
        category: const {'resident', 'visitor', 'unknown'}.contains(category)
            ? category
            : 'unknown',
        text: rec['text']?.toString(),
        textHash: rec['text_hash']?.toString(),
        source: rec['source']?.toString(),
      ),);
    }
    out.sort((a, b) {
      // Residents first (visitor allowlist is the alarm-worthy case for
      // typical deployments — but residents are usually the smaller list,
      // so showing them first reads as a more useful summary).
      final byCat = _categoryOrder(a.category).compareTo(
        _categoryOrder(b.category),
      );
      if (byCat != 0) return byCat;
      return a.trackId.compareTo(b.trackId);
    });
    return out;
  }
}

int _categoryOrder(String category) {
  switch (category) {
    case 'resident':
      return 0;
    case 'visitor':
      return 1;
    default:
      return 2;
  }
}

// ---------------------------------------------------------------------------
// F2 — Pedestrian
// ---------------------------------------------------------------------------

int _parsePedestriansCount(Map<String, dynamic> json) {
  final totals = json['totals'];
  if (totals is Map) {
    final n = _coerceNonNegativeInt(totals['pedestrians']);
    if (n != null) return n;
  }
  // Backwards compat: older pipelines may emit `pedestrians` at the top.
  final n = _coerceNonNegativeInt(json['pedestrians']);
  return n ?? 0;
}

bool _isNonEmptyString(Object? v) => v is String && v.trim().isNotEmpty;

bool _hasTransitAnnotatedVideo(Map<String, dynamic> json) {
  final transit = json['transit'];
  if (transit is Map) {
    return _isNonEmptyString(transit['annotated_video']);
  }
  return false;
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
  // Server-local file paths surfaced by `/status` for the annotated MP4
  // outputs. Never per-class counts — the values are absolute paths or
  // nested objects, but pin them as metadata for defence-in-depth.
  'annotated_video',
  'transit',
  'speed',
  'traffic_light',
  'traffic_lights',
  'plates',
  'plate_summary',
  'totals',
  'vehicle_breakdown',
  'counting',
  'meta',
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

/// Lossy double coercion that accepts int, double, and num. Returns null
/// for NaN, infinity, and non-numeric values so callers can default
/// without spreading null-coalescing through the parser.
double? _coerceDouble(dynamic value) {
  if (value is int) return value.toDouble();
  if (value is double) {
    if (value.isNaN || value.isInfinite) return null;
    return value;
  }
  if (value is num) return value.toDouble();
  return null;
}
