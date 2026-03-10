import 'package:flutter/foundation.dart';

@immutable
class Point2D {
  const Point2D({required this.x, required this.y});

  final double x;
  final double y;

  factory Point2D.fromJson(Map<String, dynamic> json) => Point2D(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

@immutable
class CountingLine {
  const CountingLine({
    required this.name,
    required this.start,
    required this.end,
    this.direction = 'inbound',
    this.directionVector,
  });

  final String name;
  final Point2D start;
  final Point2D end;
  final String direction;
  final Point2D? directionVector;

  factory CountingLine.fromJson(Map<String, dynamic> json) => CountingLine(
        name: json['name'] as String,
        start: Point2D.fromJson(json['start'] as Map<String, dynamic>),
        end: Point2D.fromJson(json['end'] as Map<String, dynamic>),
        direction: json['direction'] as String? ?? 'inbound',
        directionVector: json['direction_vector'] != null
            ? Point2D.fromJson(
                json['direction_vector'] as Map<String, dynamic>,
              )
            : null,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'start': start.toJson(),
        'end': end.toJson(),
        'direction': direction,
        if (directionVector != null)
          'direction_vector': directionVector!.toJson(),
      };
}

@immutable
class LanePolyline {
  const LanePolyline({required this.name, required this.points});

  final String name;
  final List<Point2D> points;

  factory LanePolyline.fromJson(Map<String, dynamic> json) => LanePolyline(
        name: json['name'] as String,
        points: (json['points'] as List<dynamic>)
            .map((p) => Point2D.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'points': points.map((p) => p.toJson()).toList(),
      };
}

@immutable
class RoiPreset {
  const RoiPreset({
    required this.id,
    required this.cameraId,
    required this.name,
    this.roiPolygon = const [],
    this.countingLines = const [],
    this.lanePolylines = const [],
    this.isActive = false,
    this.createdAt,
  });

  final String id;
  final String cameraId;
  final String name;
  final List<Point2D> roiPolygon;
  final List<CountingLine> countingLines;
  final List<LanePolyline> lanePolylines;
  final bool isActive;
  final DateTime? createdAt;

  factory RoiPreset.fromJson(Map<String, dynamic> json) {
    final polygon = json['roi_polygon'];
    List<Point2D> roiPoints = [];
    if (polygon is Map<String, dynamic>) {
      final coords = polygon['coordinates'];
      if (coords is List && coords.isNotEmpty) {
        final ring = coords[0] as List;
        roiPoints = ring
            .map((c) => Point2D(
                  x: (c[0] as num).toDouble(),
                  y: (c[1] as num).toDouble(),
                ))
            .toList();
      }
    }

    return RoiPreset(
      id: json['id'] as String,
      cameraId: json['camera_id'] as String,
      name: json['name'] as String,
      roiPolygon: roiPoints,
      countingLines: (json['counting_lines'] as List<dynamic>?)
              ?.map((c) => CountingLine.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      lanePolylines: (json['lane_polylines'] as List<dynamic>?)
              ?.map((l) => LanePolyline.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (roiPolygon.isNotEmpty)
          'roi_polygon': {
            'type': 'Polygon',
            'coordinates': [
              roiPolygon.map((p) => [p.x, p.y]).toList(),
            ],
          },
        'counting_lines': countingLines.map((c) => c.toJson()).toList(),
        'lane_polylines': lanePolylines.map((l) => l.toJson()).toList(),
      };

  RoiPreset copyWith({
    String? name,
    List<Point2D>? roiPolygon,
    List<CountingLine>? countingLines,
    List<LanePolyline>? lanePolylines,
    bool? isActive,
  }) =>
      RoiPreset(
        id: id,
        cameraId: cameraId,
        name: name ?? this.name,
        roiPolygon: roiPolygon ?? this.roiPolygon,
        countingLines: countingLines ?? this.countingLines,
        lanePolylines: lanePolylines ?? this.lanePolylines,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}
