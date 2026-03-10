import 'package:flutter/foundation.dart';

@immutable
class Location {
  const Location({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  factory Location.fromJson(Map<String, dynamic> json) => Location(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };
}

@immutable
class Site {
  const Site({
    required this.id,
    required this.name,
    this.address,
    this.location,
    this.timezone = 'Asia/Seoul',
    required this.orgId,
    this.configVersion = 1,
    this.status = 'active',
    this.cameraCount = 0,
    this.activeCameraCount = 0,
    this.todayVehicleCount = 0,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? address;
  final Location? location;
  final String timezone;
  final String orgId;
  final int configVersion;
  final String status;
  final int cameraCount;
  final int activeCameraCount;
  final int todayVehicleCount;
  final DateTime? createdAt;

  bool get isActive => status == 'active';

  factory Site.fromJson(Map<String, dynamic> json) => Site(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String?,
        location: json['location'] != null
            ? Location.fromJson(json['location'] as Map<String, dynamic>)
            : null,
        timezone: json['timezone'] as String? ?? 'Asia/Seoul',
        orgId: json['org_id'] as String,
        configVersion: json['config_version'] as int? ?? 1,
        status: json['status'] as String? ?? 'active',
        cameraCount: json['camera_count'] as int? ?? 0,
        activeCameraCount: json['active_camera_count'] as int? ?? 0,
        todayVehicleCount: json['today_vehicle_count'] as int? ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (address != null) 'address': address,
        if (location != null) 'location': location!.toJson(),
        'timezone': timezone,
      };

  Site copyWith({
    String? name,
    String? address,
    Location? location,
    String? status,
    int? cameraCount,
    int? activeCameraCount,
    int? todayVehicleCount,
  }) =>
      Site(
        id: id,
        name: name ?? this.name,
        address: address ?? this.address,
        location: location ?? this.location,
        timezone: timezone,
        orgId: orgId,
        configVersion: configVersion,
        status: status ?? this.status,
        cameraCount: cameraCount ?? this.cameraCount,
        activeCameraCount: activeCameraCount ?? this.activeCameraCount,
        todayVehicleCount: todayVehicleCount ?? this.todayVehicleCount,
        createdAt: createdAt,
      );
}
