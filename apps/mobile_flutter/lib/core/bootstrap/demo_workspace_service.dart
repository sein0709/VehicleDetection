import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/database/database.dart';
import 'package:greyeye_mobile/core/database/database_provider.dart';

final demoWorkspaceServiceProvider = Provider<DemoWorkspaceService>(
  (ref) => DemoWorkspaceService(ref.watch(databaseProvider)),
);

class DemoWorkspaceSummary {
  const DemoWorkspaceSummary({
    required this.siteId,
    this.cameraId,
    this.created = true,
  });

  final String siteId;
  final String? cameraId;
  final bool created;
}

class DemoWorkspaceService {
  DemoWorkspaceService(this._db);

  final AppDatabase _db;

  Future<DemoWorkspaceSummary> seedDemoWorkspace() async {
    final existingSites = await _db.sitesDao.allSites();
    if (existingSites.isNotEmpty) {
      final site = existingSites.first;
      final cameras = await _db.camerasDao.camerasForSite(site.id);
      return DemoWorkspaceSummary(
        siteId: site.id,
        cameraId: cameras.isNotEmpty ? cameras.first.id : null,
        created: false,
      );
    }

    final now = DateTime.now().toUtc();
    const siteId = 'demo-site-seoul';
    const cameraId = 'demo-camera-northbound';
    const presetId = 'demo-preset-default';
    const lineId = 'demo-line-main';
    final windowStart = now.subtract(const Duration(hours: 24));

    await _db.transaction(() async {
      await _db.sitesDao.insertSite(
        SitesCompanion.insert(
          id: siteId,
          name: 'Demo Junction',
          address: const Value('Bundang-gu, Seongnam-si'),
          latitude: const Value(37.3781),
          longitude: const Value(127.1112),
          timezone: const Value('Asia/Seoul'),
        ),
      );

      await _db.camerasDao.insertCamera(
        CamerasCompanion.insert(
          id: cameraId,
          siteId: siteId,
          name: 'Northbound Pole Cam',
          sourceType: const Value('smartphone'),
          settingsJson: Value(
            jsonEncode(const {
              'target_fps': 10,
              'resolution': '1920x1080',
              'night_mode': false,
              'classification_mode': 'full_12class',
            }),
          ),
          status: const Value('online'),
          lastSeenAt: Value(now),
        ),
      );

      await _db.roiDao.insertPreset(
        RoiPresetsCompanion.insert(
          id: presetId,
          cameraId: cameraId,
          name: 'Default Count Line',
          roiPolygonJson: const Value(
            '[{"x":0.08,"y":0.12},{"x":0.92,"y":0.12},'
            '{"x":0.92,"y":0.9},{"x":0.08,"y":0.9}]',
          ),
          isActive: const Value(true),
        ),
      );

      await _db.roiDao.insertLine(
        CountingLinesCompanion.insert(
          id: lineId,
          presetId: presetId,
          cameraId: cameraId,
          name: 'Main Count Line',
          startX: 0.18,
          startY: 0.52,
          endX: 0.82,
          endY: 0.52,
          direction: const Value('inbound'),
        ),
      );

      await _db.crossingsDao.insertCrossingsBatch(
        _buildDemoCrossings(
          cameraId: cameraId,
          lineId: lineId,
          start: windowStart,
          end: now,
        ),
      );
    });

    await _db.crossingsDao.reaggregate(
      cameraId,
      from: windowStart,
      to: now.add(const Duration(minutes: 15)),
    );

    return const DemoWorkspaceSummary(
      siteId: siteId,
      cameraId: cameraId,
    );
  }

  List<VehicleCrossingsCompanion> _buildDemoCrossings({
    required String cameraId,
    required String lineId,
    required DateTime start,
    required DateTime end,
  }) {
    final entries = <VehicleCrossingsCompanion>[];
    final classPattern = <int>[1, 1, 3, 2, 4, 1, 8, 2, 5, 1, 12, 3];
    final bboxPattern = <Map<String, double>>[
      {'x': 0.18, 'y': 0.24, 'w': 0.18, 'h': 0.12},
      {'x': 0.28, 'y': 0.3, 'w': 0.16, 'h': 0.11},
      {'x': 0.42, 'y': 0.34, 'w': 0.2, 'h': 0.12},
    ];

    var timestamp = start;
    var index = 0;
    while (timestamp.isBefore(end)) {
      final classCode = classPattern[index % classPattern.length];
      final direction = index.isEven ? 'inbound' : 'outbound';
      final bbox = bboxPattern[index % bboxPattern.length];
      final minuteStep = 7 + (index % 5) * 3;

      entries.add(
        VehicleCrossingsCompanion.insert(
          id: 'demo-crossing-$index',
          cameraId: cameraId,
          lineId: lineId,
          trackId: 'demo-track-$index',
          crossingSeq: const Value(1),
          class12: classCode,
          confidence: 0.78 + ((index % 4) * 0.04),
          direction: direction,
          frameIndex: index * 12,
          speedEstimateKmh: Value(28 + ((index * 7) % 25).toDouble()),
          bboxJson: Value(jsonEncode(bbox)),
          timestampUtc: timestamp,
        ),
      );

      timestamp = timestamp.add(Duration(minutes: minuteStep));
      index += 1;
    }

    return entries;
  }
}
