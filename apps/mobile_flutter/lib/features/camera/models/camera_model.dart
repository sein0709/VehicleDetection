import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:greyeye_mobile/core/database/database.dart' as db;

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
class CameraView {
  const CameraView({
    required this.id,
    required this.siteId,
    required this.name,
    this.sourceType = 'smartphone',
    this.settings = const CameraSettings(),
    this.status = 'offline',
    this.createdAt,
    this.lastSeenAt,
  });

  final String id;
  final String siteId;
  final String name;
  final String sourceType;
  final CameraSettings settings;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;

  bool get isOnline => status == 'online';
  bool get isDegraded => status == 'degraded';

  factory CameraView.fromDbRow(db.Camera row) {
    CameraSettings settings;
    try {
      settings = CameraSettings.fromJson(
        jsonDecode(row.settingsJson) as Map<String, dynamic>,
      );
    } catch (_) {
      settings = const CameraSettings();
    }
    return CameraView(
      id: row.id,
      siteId: row.siteId,
      name: row.name,
      sourceType: row.sourceType,
      settings: settings,
      status: row.status,
      createdAt: row.createdAt,
      lastSeenAt: row.lastSeenAt,
    );
  }

  CameraView copyWith({
    String? name,
    String? sourceType,
    CameraSettings? settings,
    String? status,
  }) =>
      CameraView(
        id: id,
        siteId: siteId,
        name: name ?? this.name,
        sourceType: sourceType ?? this.sourceType,
        settings: settings ?? this.settings,
        status: status ?? this.status,
        createdAt: createdAt,
        lastSeenAt: lastSeenAt,
      );
}
