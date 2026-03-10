import 'package:flutter/foundation.dart';

@immutable
class BoundingBox {
  const BoundingBox({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final double x;
  final double y;
  final double w;
  final double h;

  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        w: (json['w'] as num).toDouble(),
        h: (json['h'] as num).toDouble(),
      );
}

@immutable
class LiveTrack {
  const LiveTrack({
    required this.trackId,
    required this.classCode,
    required this.bbox,
    this.confidence = 0.0,
    this.speedEstimate,
  });

  final String trackId;
  final int classCode;
  final BoundingBox bbox;
  final double confidence;
  final double? speedEstimate;

  factory LiveTrack.fromJson(Map<String, dynamic> json) => LiveTrack(
        trackId: json['track_id'] as String,
        classCode: json['class12'] as int? ?? json['class_code'] as int? ?? 1,
        bbox: BoundingBox.fromJson(json['bbox'] as Map<String, dynamic>),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        speedEstimate: (json['speed_estimate_kmh'] as num?)?.toDouble(),
      );
}
