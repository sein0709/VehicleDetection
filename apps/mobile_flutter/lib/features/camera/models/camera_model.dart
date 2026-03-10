import 'package:flutter/foundation.dart';

@immutable
class CameraSettings {
  const CameraSettings({
    this.targetFps = 10,
    this.resolution = '1920x1080',
    this.nightMode = false,
    this.classificationMode = 'full_12class',
  });

  final int targetFps;
  final String resolution;
  final bool nightMode;
  final String classificationMode;

  factory CameraSettings.fromJson(Map<String, dynamic> json) => CameraSettings(
        targetFps: json['target_fps'] as int? ?? 10,
        resolution: json['resolution'] as String? ?? '1920x1080',
        nightMode: json['night_mode'] as bool? ?? false,
        classificationMode:
            json['classification_mode'] as String? ?? 'full_12class',
      );

  Map<String, dynamic> toJson() => {
        'target_fps': targetFps,
        'resolution': resolution,
        'night_mode': nightMode,
        'classification_mode': classificationMode,
      };

  CameraSettings copyWith({
    int? targetFps,
    String? resolution,
    bool? nightMode,
    String? classificationMode,
  }) =>
      CameraSettings(
        targetFps: targetFps ?? this.targetFps,
        resolution: resolution ?? this.resolution,
        nightMode: nightMode ?? this.nightMode,
        classificationMode: classificationMode ?? this.classificationMode,
      );
}

@immutable
class Camera {
  const Camera({
    required this.id,
    required this.siteId,
    required this.name,
    this.sourceType = 'smartphone',
    this.settings = const CameraSettings(),
    this.status = 'offline',
    this.configVersion = 1,
    this.createdAt,
    this.lastHeartbeat,
  });

  final String id;
  final String siteId;
  final String name;
  final String sourceType;
  final CameraSettings settings;
  final String status;
  final int configVersion;
  final DateTime? createdAt;
  final DateTime? lastHeartbeat;

  bool get isOnline => status == 'online';
  bool get isDegraded => status == 'degraded';

  factory Camera.fromJson(Map<String, dynamic> json) => Camera(
        id: json['id'] as String,
        siteId: json['site_id'] as String,
        name: json['name'] as String,
        sourceType: json['source_type'] as String? ?? 'smartphone',
        settings: json['settings'] != null
            ? CameraSettings.fromJson(json['settings'] as Map<String, dynamic>)
            : const CameraSettings(),
        status: json['status'] as String? ?? 'offline',
        configVersion: json['config_version'] as int? ?? 1,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        lastHeartbeat: json['last_heartbeat'] != null
            ? DateTime.parse(json['last_heartbeat'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'source_type': sourceType,
        'settings': settings.toJson(),
      };

  Camera copyWith({
    String? name,
    String? sourceType,
    CameraSettings? settings,
    String? status,
  }) =>
      Camera(
        id: id,
        siteId: siteId,
        name: name ?? this.name,
        sourceType: sourceType ?? this.sourceType,
        settings: settings ?? this.settings,
        status: status ?? this.status,
        configVersion: configVersion,
        createdAt: createdAt,
        lastHeartbeat: lastHeartbeat,
      );
}
