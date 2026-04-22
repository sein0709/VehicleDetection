import 'dart:convert';

/// Identifiers for the analytics tasks the server's `parse_calibration`
/// understands. Mirror of `runpod/calibration.py::ALL_TASKS`.
abstract final class AnalysisTask {
  static const vehicles = 'vehicles';
  static const pedestrians = 'pedestrians';
  static const speed = 'speed';
  static const transit = 'transit';
  static const trafficLight = 'traffic_light';
  static const lpr = 'lpr';

  /// Tasks that always run unless explicitly disabled. The server defaults
  /// to this set when no calibration is supplied.
  static const Set<String> defaults = {vehicles, pedestrians};

  /// Tasks that the operator can opt into from the picker card. `vehicles`
  /// is included so bus-stop or pedestrian-only deployments can disable
  /// vehicle counting outright (the server skips count-line/annotation
  /// work when this task is off, even though the vehicle detector still
  /// runs to support transit/speed/lpr).
  static const List<String> selectable = [
    vehicles,
    pedestrians,
    speed,
    transit,
    trafficLight,
    lpr,
  ];
}

/// Builds the multipart `calibration` JSON body the mobile UI sends with
/// each upload.
///
/// All coordinate fields use **normalized (0..1) ratios** so the client
/// doesn't need to know the video resolution. The server's
/// `Calibration.resolve_ratio_coords()` rescales them at video-load time.
///
/// Defaults assume a centered road in the lower half of the frame. They
/// are deliberately generic — accurate per-site calibration is a separate
/// editor that's not yet built. The roadmap calls these out as required
/// follow-ups (`docs/09-features-roadmap-geonhwa.md` C1).
/// Per-light ROI override for F7. The ROI is `[x, y, w, h]` in
/// normalized [0..1] image space. Operators populate this via
/// [TrafficLightRoiEditorScreen]; when null, the builder falls back to
/// a generic top-center default that produces an HSV signal but won't
/// be accurate for any specific intersection.
class TrafficLightOverride {
  const TrafficLightOverride({required this.label, required this.roi});
  final String label;
  final List<double> roi;
}

/// Speed-task override for F4. Coordinates are normalized image-space
/// `[x, y]` ratios; metres are physical lane width / segment length.
/// When null, the builder falls back to a generic lower-trapezoid
/// default — produces non-zero numbers but not site-accurate.
class SpeedOverride {
  const SpeedOverride({
    required this.sourceQuadXY,
    required this.linesYRatio,
    required this.realWorldWidthM,
    required this.realWorldLengthM,
    this.linesXY,
  });
  /// 4 entries of `[x, y]` ratios (TL, TR, BR, BL by convention, but
  /// any consistent order — the perspective transform on the server
  /// side maps to the same destination rectangle either way).
  final List<List<double>> sourceQuadXY;
  /// 2 entries; both in [0..1]. Legacy fallback used when [linesXY] is
  /// null. The server only consumes this when no `lines_xy` is sent.
  final List<double> linesYRatio;
  final double realWorldWidthM;
  final double realWorldLengthM;
  /// Optional operator-drawn 2-point speed lines. Each entry is
  /// `[[x,y],[x,y]]` in normalized [0..1] image-space. When set, the
  /// server uses these as arbitrary line vectors instead of synthesizing
  /// horizontal lines from [linesYRatio]. New editor pass-through.
  final List<List<List<double>>>? linesXY;
}

/// Operator-drawn IN/OUT line pair for segment-style vehicle counting
/// (replaces the fixed horizontal red tripwire). Each line is a 2-point
/// `[[x, y], [x, y]]` segment in normalized [0..1] image-space.
///
/// A vehicle counts as one only when its track crosses BOTH lines during
/// the clip (in either order) — see `SegmentCounter` in
/// `runpod/pipeline.py`. This rejects the overcount pattern produced by
/// vehicles that oscillate near a single tripwire and produces accurate
/// per-direction flow on oblique camera angles.
class CountLineOverride {
  const CountLineOverride({required this.inLineXY, required this.outLineXY});
  final List<List<double>> inLineXY;
  final List<List<double>> outLineXY;
}

/// Transit-task override for F6.
class TransitOverride {
  const TransitOverride({
    required this.stopPolygonXY,
    required this.doorLineXY,
    required this.maxCapacity,
    this.busZonePolygonXY,
  });
  /// 3+ vertices, each `[x, y]` in [0..1].
  final List<List<double>> stopPolygonXY;
  /// Exactly 2 endpoints, each `[x, y]` in [0..1].
  final List<List<double>> doorLineXY;
  final List<List<double>>? busZonePolygonXY;
  final int maxCapacity;
}

String buildCalibrationJson({
  required Set<String> enabledTasks,
  required bool outputAnnotatedVideo,
  List<TrafficLightOverride> trafficLightOverrides = const [],
  SpeedOverride? speedOverride,
  TransitOverride? transitOverride,
  CountLineOverride? countLineOverride,
  List<String> lprAllowlist = const [],
  // Auto-mode flags: when true the geometry is omitted and the server's
  // VLM auto-calibration pre-pass fills it from a video keyframe.
  bool transitAutoMode = false,
  bool lightAutoMode = false,
  int transitMaxCapacity = 30,
  String lightAutoLabel = 'main',
}) {
  // Honour the operator's exact selection — vehicles is no longer auto-
  // injected so a bus-stop scenario can run with only {transit, pedestrians}
  // enabled. The server defaults already match the legacy
  // {vehicles, pedestrians} behaviour when `tasks_enabled` is absent.
  final tasks = enabledTasks.toList()..sort();

  final body = <String, Object?>{
    'tasks_enabled': tasks,
    if (outputAnnotatedVideo) 'output_video': true,
  };

  if (countLineOverride != null) {
    body['count_lines'] = <String, Object?>{
      'in': countLineOverride.inLineXY,
      'out': countLineOverride.outLineXY,
    };
  }

  if (enabledTasks.contains(AnalysisTask.speed)) {
    if (speedOverride != null) {
      body['speed'] = <String, Object?>{
        'source_quad': speedOverride.sourceQuadXY,
        'real_world_m': <String, double>{
          'width': speedOverride.realWorldWidthM,
          'length': speedOverride.realWorldLengthM,
        },
        'lines_y_ratio': speedOverride.linesYRatio,
        if (speedOverride.linesXY != null) 'lines_xy': speedOverride.linesXY,
      };
    } else {
      body['speed'] = <String, Object?>{
        // Lower-half trapezoid (camera-on-pole assumption). Width:length
        // estimate of one lane × 20 m of asphalt — operator should
        // override for accurate km/h, but the default produces non-zero
        // numbers so the F4 section renders at all.
        'source_quad': <List<double>>[
          [0.30, 0.55], [0.70, 0.55], [0.85, 0.95], [0.15, 0.95],
        ],
        'real_world_m': <String, double>{'width': 3.5, 'length': 20.0},
        'lines_y_ratio': <double>[0.60, 0.90],
      };
    }
  }

  if (enabledTasks.contains(AnalysisTask.transit)) {
    if (transitAutoMode) {
      // Auto mode: ship only the scalar config. The server's
      // auto-calibration pre-pass asks the VLM for stop_polygon,
      // doors and bus_zone_polygon from one keyframe.
      body['transit'] = <String, Object?>{
        'max_capacity': transitMaxCapacity,
        'output_video': outputAnnotatedVideo,
      };
    } else if (transitOverride != null) {
      body['transit'] = <String, Object?>{
        'stop_polygon': transitOverride.stopPolygonXY,
        'max_capacity': transitOverride.maxCapacity,
        'doors': <Map<String, Object?>>[
          <String, Object?>{'line': transitOverride.doorLineXY},
        ],
        if (transitOverride.busZonePolygonXY != null)
          'bus_zone_polygon': transitOverride.busZonePolygonXY,
        'output_video': outputAnnotatedVideo,
      };
    } else {
      body['transit'] = <String, Object?>{
        // Bottom band of the frame. Door line one-third from the bottom —
        // typical for a curb-mounted camera framing a stop.
        'stop_polygon': <List<double>>[
          [0.10, 0.70], [0.90, 0.70], [0.90, 0.95], [0.10, 0.95],
        ],
        'max_capacity': transitMaxCapacity,
        'doors': <Map<String, Object?>>[
          <String, Object?>{
            'line': <List<double>>[[0.20, 0.85], [0.80, 0.85]],
          },
        ],
        // Default to writing the head-circle overlay MP4 too, so the
        // download flow has something to fetch when transit is on.
        'output_video': outputAnnotatedVideo,
      };
    }
  }

  if (enabledTasks.contains(AnalysisTask.trafficLight)) {
    if (lightAutoMode) {
      // Auto mode: ship only the label; the server's VLM auto-cal
      // pre-pass proposes the bbox.
      body['traffic_lights'] = <Map<String, Object?>>[
        <String, Object?>{'label': lightAutoLabel},
      ];
    } else {
      final lights = trafficLightOverrides.isNotEmpty
          ? trafficLightOverrides
              .map<Map<String, Object?>>(
                (o) => <String, Object?>{
                  'label': o.label,
                  'roi': o.roi,
                },
              )
              .toList()
          // No editor result — fall back to a generic top-center box so
          // the F7 section at least renders. Won't be accurate; operators
          // are expected to use the editor for any real deployment.
          : <Map<String, Object?>>[
              <String, Object?>{
                'label': 'main',
                'roi': <double>[0.45, 0.05, 0.10, 0.12],
              },
            ];
      body['traffic_lights'] = lights;
    }
  }

  if (enabledTasks.contains(AnalysisTask.lpr)) {
    body['lpr'] = <String, Object?>{
      'enabled': true,
      'residential_only': true,
      'allowlist': lprAllowlist,
      'hash_plates': false,
    };
  }

  return jsonEncode(body);
}
