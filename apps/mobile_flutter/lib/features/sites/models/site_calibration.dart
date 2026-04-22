import 'package:greyeye_mobile/features/sites/services/task_calibration_builder.dart';

/// Bundle of every operator-editable calibration choice for one site.
/// This is the unit the persistence layer reads / writes — the screen
/// state is an in-memory mirror, the calibration JSON sent to the
/// server is derived from it via [toCalibrationJson].
///
/// Forward-compat: unknown JSON keys are ignored on parse; missing
/// fields fall back to defaults. Storage shouldn't break on schema
/// drift between mobile-app versions.
class SiteCalibration {
  const SiteCalibration({
    this.includeAnnotatedVideo = true,
    this.enabledTasks = const {AnalysisTask.vehicles, AnalysisTask.pedestrians},
    this.trafficLightOverrides = const [],
    this.speedOverride,
    this.transitOverride,
    this.countLineOverride,
    this.pedestrianZoneOverride,
    this.lprAllowlist = const [],
    this.transitAutoMode = true,
    this.lightAutoMode = true,
    this.transitMaxCapacity = 30,
    this.lightAutoLabel = 'main',
  });

  /// Default state for a site that's never been configured. Mirrors
  /// the screen's old hard-coded defaults so existing operators see
  /// the same starting point after the persistence migration.
  static const SiteCalibration empty = SiteCalibration();

  final bool includeAnnotatedVideo;
  final Set<String> enabledTasks;
  final List<TrafficLightOverride> trafficLightOverrides;
  final SpeedOverride? speedOverride;
  final TransitOverride? transitOverride;
  final CountLineOverride? countLineOverride;
  /// Optional pedestrian ROI polygon (F2). Restricts the pedestrian
  /// total to tracks whose anchor lay inside the polygon. Null means
  /// "count the whole frame" — the legacy default.
  final PedestrianZoneOverride? pedestrianZoneOverride;
  final List<String> lprAllowlist;
  /// When true, the transit task is sent to the server with only
  /// [transitMaxCapacity] — no polygons. The server's auto-calibration
  /// pre-pass asks the VLM to identify the bus stop / door / bus zone
  /// from a keyframe. Falls back to legacy defaults if the VLM is
  /// unavailable. Default ON because it produces a usable result with
  /// zero operator drawing.
  final bool transitAutoMode;
  /// Same idea for the traffic-light ROI. Auto mode ships only the
  /// label; the server VLM proposes the bbox.
  final bool lightAutoMode;
  /// Bus-stop max capacity used in auto mode (no polygon editor).
  /// Density % = persons inside detected stop polygon ÷ this.
  final int transitMaxCapacity;
  /// Default label for the auto-mode traffic light (operators rarely
  /// need to change this; only matters when there are multiple lights
  /// and we want the report to label them differently).
  final String lightAutoLabel;

  SiteCalibration copyWith({
    bool? includeAnnotatedVideo,
    Set<String>? enabledTasks,
    List<TrafficLightOverride>? trafficLightOverrides,
    SpeedOverride? speedOverride,
    TransitOverride? transitOverride,
    CountLineOverride? countLineOverride,
    PedestrianZoneOverride? pedestrianZoneOverride,
    List<String>? lprAllowlist,
    bool? transitAutoMode,
    bool? lightAutoMode,
    int? transitMaxCapacity,
    String? lightAutoLabel,
  }) {
    return SiteCalibration(
      includeAnnotatedVideo:
          includeAnnotatedVideo ?? this.includeAnnotatedVideo,
      enabledTasks: enabledTasks ?? this.enabledTasks,
      trafficLightOverrides:
          trafficLightOverrides ?? this.trafficLightOverrides,
      speedOverride: speedOverride ?? this.speedOverride,
      transitOverride: transitOverride ?? this.transitOverride,
      countLineOverride: countLineOverride ?? this.countLineOverride,
      pedestrianZoneOverride:
          pedestrianZoneOverride ?? this.pedestrianZoneOverride,
      lprAllowlist: lprAllowlist ?? this.lprAllowlist,
      transitAutoMode: transitAutoMode ?? this.transitAutoMode,
      lightAutoMode: lightAutoMode ?? this.lightAutoMode,
      transitMaxCapacity: transitMaxCapacity ?? this.transitMaxCapacity,
      lightAutoLabel: lightAutoLabel ?? this.lightAutoLabel,
    );
  }

  /// "Forget" a non-list override — copyWith can't express null because
  /// the param defaults already mean "keep". Used by the Reset action
  /// and by editors when the operator clears a configured task.
  SiteCalibration withoutSpeed() => SiteCalibration(
        includeAnnotatedVideo: includeAnnotatedVideo,
        enabledTasks: enabledTasks,
        trafficLightOverrides: trafficLightOverrides,
        speedOverride: null,
        transitOverride: transitOverride,
        countLineOverride: countLineOverride,
        pedestrianZoneOverride: pedestrianZoneOverride,
        lprAllowlist: lprAllowlist,
        transitAutoMode: transitAutoMode,
        lightAutoMode: lightAutoMode,
        transitMaxCapacity: transitMaxCapacity,
        lightAutoLabel: lightAutoLabel,
      );
  SiteCalibration withoutTransit() => SiteCalibration(
        includeAnnotatedVideo: includeAnnotatedVideo,
        enabledTasks: enabledTasks,
        trafficLightOverrides: trafficLightOverrides,
        speedOverride: speedOverride,
        transitOverride: null,
        countLineOverride: countLineOverride,
        pedestrianZoneOverride: pedestrianZoneOverride,
        lprAllowlist: lprAllowlist,
        transitAutoMode: transitAutoMode,
        lightAutoMode: lightAutoMode,
        transitMaxCapacity: transitMaxCapacity,
        lightAutoLabel: lightAutoLabel,
      );
  SiteCalibration withoutCountLines() => SiteCalibration(
        includeAnnotatedVideo: includeAnnotatedVideo,
        enabledTasks: enabledTasks,
        trafficLightOverrides: trafficLightOverrides,
        speedOverride: speedOverride,
        transitOverride: transitOverride,
        countLineOverride: null,
        pedestrianZoneOverride: pedestrianZoneOverride,
        lprAllowlist: lprAllowlist,
        transitAutoMode: transitAutoMode,
        lightAutoMode: lightAutoMode,
        transitMaxCapacity: transitMaxCapacity,
        lightAutoLabel: lightAutoLabel,
      );
  SiteCalibration withoutPedestrianZone() => SiteCalibration(
        includeAnnotatedVideo: includeAnnotatedVideo,
        enabledTasks: enabledTasks,
        trafficLightOverrides: trafficLightOverrides,
        speedOverride: speedOverride,
        transitOverride: transitOverride,
        countLineOverride: countLineOverride,
        pedestrianZoneOverride: null,
        lprAllowlist: lprAllowlist,
        transitAutoMode: transitAutoMode,
        lightAutoMode: lightAutoMode,
        transitMaxCapacity: transitMaxCapacity,
        lightAutoLabel: lightAutoLabel,
      );

  /// Snapshot for storage. Schema version is included so the loader
  /// can branch on future format changes without a migration table.
  Map<String, Object?> toJson() => <String, Object?>{
        'schema_version': 2,
        'include_annotated_video': includeAnnotatedVideo,
        'enabled_tasks': enabledTasks.toList()..sort(),
        'lpr_allowlist': lprAllowlist,
        'transit_auto_mode': transitAutoMode,
        'light_auto_mode': lightAutoMode,
        'transit_max_capacity': transitMaxCapacity,
        'light_auto_label': lightAutoLabel,
        'traffic_light_overrides': [
          for (final o in trafficLightOverrides)
            <String, Object?>{'label': o.label, 'roi': o.roi},
        ],
        if (speedOverride != null)
          'speed_override': <String, Object?>{
            'source_quad_xy': speedOverride!.sourceQuadXY,
            'lines_y_ratio': speedOverride!.linesYRatio,
            'real_world_width_m': speedOverride!.realWorldWidthM,
            'real_world_length_m': speedOverride!.realWorldLengthM,
            if (speedOverride!.linesXY != null)
              'lines_xy': speedOverride!.linesXY,
          },
        if (transitOverride != null)
          'transit_override': <String, Object?>{
            'stop_polygon_xy': transitOverride!.stopPolygonXY,
            'door_line_xy': transitOverride!.doorLineXY,
            if (transitOverride!.busZonePolygonXY != null)
              'bus_zone_polygon_xy': transitOverride!.busZonePolygonXY,
            'max_capacity': transitOverride!.maxCapacity,
          },
        if (countLineOverride != null)
          'count_line_override': <String, Object?>{
            'in_line_xy': countLineOverride!.inLineXY,
            'out_line_xy': countLineOverride!.outLineXY,
          },
        if (pedestrianZoneOverride != null)
          'pedestrian_zone_override': <String, Object?>{
            'polygon_xy': pedestrianZoneOverride!.polygonXY,
          },
      };

  static SiteCalibration fromJson(Map<String, Object?> json) {
    final tasks = (json['enabled_tasks'] as List?)
            ?.map((e) => e.toString())
            .toSet() ??
        const {AnalysisTask.vehicles, AnalysisTask.pedestrians};
    final allowlist = (json['lpr_allowlist'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final tlights = (json['traffic_light_overrides'] as List?)
            ?.whereType<Map<String, Object?>>()
            .map<TrafficLightOverride>(_parseTrafficLight)
            .toList() ??
        const <TrafficLightOverride>[];
    return SiteCalibration(
      includeAnnotatedVideo:
          (json['include_annotated_video'] as bool?) ?? true,
      enabledTasks: tasks,
      trafficLightOverrides: tlights,
      speedOverride: _parseSpeed(json['speed_override']),
      transitOverride: _parseTransit(json['transit_override']),
      countLineOverride: _parseCountLine(json['count_line_override']),
      pedestrianZoneOverride:
          _parsePedestrianZone(json['pedestrian_zone_override']),
      lprAllowlist: allowlist,
      // schema_version=1 records didn't include these fields; default
      // to ON so existing sites get the new VLM-driven UX automatically.
      transitAutoMode: (json['transit_auto_mode'] as bool?) ?? true,
      lightAutoMode: (json['light_auto_mode'] as bool?) ?? true,
      transitMaxCapacity:
          ((json['transit_max_capacity'] as num?) ?? 30).toInt(),
      lightAutoLabel: (json['light_auto_label'] as String?) ?? 'main',
    );
  }
}

TrafficLightOverride _parseTrafficLight(Map<String, Object?> raw) {
  final roi = (raw['roi'] as List<dynamic>?)
          ?.map((v) => (v as num).toDouble())
          .toList() ??
      const <double>[];
  return TrafficLightOverride(
    label: (raw['label'] ?? 'main').toString(),
    roi: roi,
  );
}

SpeedOverride? _parseSpeed(Object? raw) {
  if (raw is! Map) return null;
  final quad = (raw['source_quad_xy'] as List<dynamic>?)
          ?.whereType<List<dynamic>>()
          .map<List<double>>(
              (p) => p.map((v) => (v as num).toDouble()).toList(),)
          .toList() ??
      const <List<double>>[];
  if (quad.length != 4) return null;
  final lines = (raw['lines_y_ratio'] as List<dynamic>?)
          ?.map((v) => (v as num).toDouble())
          .toList() ??
      const <double>[];
  if (lines.length != 2) return null;

  List<List<List<double>>>? linesXY;
  final rawLinesXY = raw['lines_xy'];
  if (rawLinesXY is List && rawLinesXY.length == 2) {
    final parsed = <List<List<double>>>[];
    var ok = true;
    for (final line in rawLinesXY) {
      if (line is! List || line.length != 2) {
        ok = false;
        break;
      }
      parsed.add([
        for (final p in line)
          if (p is List && p.length == 2)
            [(p[0] as num).toDouble(), (p[1] as num).toDouble()]
          else
            <double>[0.0, 0.0],
      ]);
    }
    if (ok) linesXY = parsed;
  }

  return SpeedOverride(
    sourceQuadXY: quad,
    linesYRatio: lines,
    realWorldWidthM:
        ((raw['real_world_width_m'] as num?) ?? 3.5).toDouble(),
    realWorldLengthM:
        ((raw['real_world_length_m'] as num?) ?? 20.0).toDouble(),
    linesXY: linesXY,
  );
}

PedestrianZoneOverride? _parsePedestrianZone(Object? raw) {
  if (raw is! Map) return null;
  final polyRaw = raw['polygon_xy'];
  if (polyRaw is! List) return null;
  final polygon = polyRaw
      .whereType<List<dynamic>>()
      .map<List<double>>(
          (p) => p.map((v) => (v as num).toDouble()).toList(),)
      .toList();
  if (polygon.length < 3) return null;
  return PedestrianZoneOverride(polygonXY: polygon);
}

CountLineOverride? _parseCountLine(Object? raw) {
  if (raw is! Map) return null;
  List<List<double>> readLine(Object? v) {
    if (v is! List) return const [];
    return v
        .whereType<List<dynamic>>()
        .map<List<double>>(
            (p) => p.map((v) => (v as num).toDouble()).toList(),)
        .toList();
  }

  final inLine = readLine(raw['in_line_xy']);
  final outLine = readLine(raw['out_line_xy']);
  if (inLine.length != 2 || outLine.length != 2) return null;
  return CountLineOverride(inLineXY: inLine, outLineXY: outLine);
}

TransitOverride? _parseTransit(Object? raw) {
  if (raw is! Map) return null;
  List<List<double>> readPolygon(Object? v) {
    if (v is! List) return const [];
    return v
        .whereType<List<dynamic>>()
        .map<List<double>>(
            (p) => p.map((v) => (v as num).toDouble()).toList(),)
        .toList();
  }

  final poly = readPolygon(raw['stop_polygon_xy']);
  final door = readPolygon(raw['door_line_xy']);
  if (poly.length < 3 || door.length != 2) return null;
  final busRaw = readPolygon(raw['bus_zone_polygon_xy']);
  return TransitOverride(
    stopPolygonXY: poly,
    doorLineXY: door,
    busZonePolygonXY: busRaw.length >= 3 ? busRaw : null,
    maxCapacity: ((raw['max_capacity'] as num?) ?? 30).toInt(),
  );
}

/// Convenience: build the multipart calibration body the server expects
/// directly from a [SiteCalibration]. Pure function — no I/O.
String toCalibrationJson(SiteCalibration cal) {
  return buildCalibrationJson(
    enabledTasks: cal.enabledTasks,
    outputAnnotatedVideo: cal.includeAnnotatedVideo,
    trafficLightOverrides: cal.trafficLightOverrides,
    speedOverride: cal.speedOverride,
    transitOverride: cal.transitOverride,
    countLineOverride: cal.countLineOverride,
    pedestrianZoneOverride: cal.pedestrianZoneOverride,
    lprAllowlist: cal.lprAllowlist,
    transitAutoMode: cal.transitAutoMode,
    lightAutoMode: cal.lightAutoMode,
    transitMaxCapacity: cal.transitMaxCapacity,
    lightAutoLabel: cal.lightAutoLabel,
  );
}
