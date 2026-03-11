import 'package:flutter/foundation.dart';
import 'package:greyeye_mobile/core/database/database.dart' as db;

@immutable
class Location {
  const Location({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

@immutable
class SiteView {
  const SiteView({
    required this.id,
    required this.name,
    this.address,
    this.location,
    this.timezone = 'Asia/Seoul',
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
  final String status;
  final int cameraCount;
  final int activeCameraCount;
  final int todayVehicleCount;
  final DateTime? createdAt;

  bool get isActive => status == 'active';

  factory SiteView.fromDbRow(
    db.Site row, {
    int cameraCount = 0,
    int activeCameraCount = 0,
    int todayVehicleCount = 0,
  }) {
    return SiteView(
      id: row.id,
      name: row.name,
      address: row.address,
      location: row.latitude != null && row.longitude != null
          ? Location(latitude: row.latitude!, longitude: row.longitude!)
          : null,
      timezone: row.timezone,
      status: row.status,
      cameraCount: cameraCount,
      activeCameraCount: activeCameraCount,
      todayVehicleCount: todayVehicleCount,
      createdAt: row.createdAt,
    );
  }

  SiteView copyWith({
    String? name,
    String? address,
    Location? location,
    String? status,
    int? cameraCount,
    int? activeCameraCount,
    int? todayVehicleCount,
  }) =>
      SiteView(
        id: id,
        name: name ?? this.name,
        address: address ?? this.address,
        location: location ?? this.location,
        timezone: timezone,
        status: status ?? this.status,
        cameraCount: cameraCount ?? this.cameraCount,
        activeCameraCount: activeCameraCount ?? this.activeCameraCount,
        todayVehicleCount: todayVehicleCount ?? this.todayVehicleCount,
        createdAt: createdAt,
      );
}
