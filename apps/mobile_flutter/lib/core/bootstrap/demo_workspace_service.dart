import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/database/database.dart';
import 'package:greyeye_mobile/core/database/database_provider.dart';

final demoWorkspaceServiceProvider = Provider<DemoWorkspaceService>(
  (ref) => DemoWorkspaceService(ref.watch(databaseProvider)),
);

/// Auto-seeds demo data into the first camera if it has no crossings.
/// Watch this provider from any screen that needs data to be present.
final autoSeedDemoDataProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(demoWorkspaceServiceProvider);
  await service.seedDemoWorkspace();
});

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
    final now = DateTime.now().toUtc();
    final windowStart = now.subtract(const Duration(hours: 24));

    final existingSites = await _db.sitesDao.allSites();
    if (existingSites.isNotEmpty) {
      // Seed every camera across all existing sites.
      for (final site in existingSites) {
        await _seedIntoExistingSite(site, windowStart, now);
      }
      final firstSite = existingSites.first;
      final cameras = await _db.camerasDao.camerasForSite(firstSite.id);
      return DemoWorkspaceSummary(
        siteId: firstSite.id,
        cameraId: cameras.isNotEmpty ? cameras.first.id : null,
      );
    }

    const siteId = 'demo-site-seoul';
    const cameraId = 'demo-camera-northbound';
    const presetId = 'demo-preset-default';
    const lineId = 'demo-line-main';

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

  /// Seed demo crossings into the first camera of an existing site.
  Future<DemoWorkspaceSummary> _seedIntoExistingSite(
    Site site,
    DateTime windowStart,
    DateTime now,
  ) async {
    final cameras = await _db.camerasDao.camerasForSite(site.id);
    if (cameras.isEmpty) {
      return DemoWorkspaceSummary(
        siteId: site.id,
        created: false,
      );
    }

    final camera = cameras.first;

    // Find (or create) a counting line for this camera.
    var lines = await _db.roiDao.linesForCamera(camera.id);
    if (lines.isEmpty) {
      var presets = await _db.roiDao.presetsForCamera(camera.id);
      final String presetId;
      if (presets.isEmpty) {
        presetId = 'demo-preset-${camera.id}';
        await _db.roiDao.insertPreset(
          RoiPresetsCompanion.insert(
            id: presetId,
            cameraId: camera.id,
            name: 'Default Count Line',
            isActive: const Value(true),
          ),
        );
      } else {
        presetId = presets.first.id;
      }

      const fallbackLineId = 'demo-line-fallback';
      await _db.roiDao.insertLine(
        CountingLinesCompanion.insert(
          id: fallbackLineId,
          presetId: presetId,
          cameraId: camera.id,
          name: 'Main Count Line',
          startX: 0.18,
          startY: 0.52,
          endX: 0.82,
          endY: 0.52,
          direction: const Value('inbound'),
        ),
      );
      lines = await _db.roiDao.linesForCamera(camera.id);
    }

    final lineId = lines.first.id;

    // Check if demo data already exists to avoid duplicates.
    final existingCount = await _db.crossingsDao.crossingCountForCamera(
      camera.id,
      after: windowStart,
      before: now,
    );
    if (existingCount >= 10) {
      return DemoWorkspaceSummary(
        siteId: site.id,
        cameraId: camera.id,
        created: false,
      );
    }

    await _db.crossingsDao.insertCrossingsBatch(
      _buildDemoCrossings(
        cameraId: camera.id,
        lineId: lineId,
        start: windowStart,
        end: now,
      ),
    );

    await _db.crossingsDao.reaggregate(
      camera.id,
      from: windowStart,
      to: now.add(const Duration(minutes: 15)),
    );

    return DemoWorkspaceSummary(
      siteId: site.id,
      cameraId: camera.id,
    );
  }

  List<VehicleCrossingsCompanion> _buildDemoCrossings({
    required String cameraId,
    required String lineId,
    required DateTime start,
    required DateTime end,
  }) {
    // 50 hand-tuned crossings that produce a realistic traffic profile:
    //   - Morning rush (07:00-09:00): dense, car-heavy
    //   - Midday (10:00-14:00): moderate, mixed trucks
    //   - Afternoon rush (16:00-18:30): dense again
    //   - Light overnight/early-morning gaps
    //
    // Each tuple: (hoursFromStart, classCode, direction, confidence, speedKmh)
    const data = <(double, int, String, double, double)>[
      // Early morning trickle
      (1.0, 3, 'inbound', 0.81, 42),
      (2.5, 1, 'outbound', 0.88, 55),
      // Morning rush 07:00-09:00
      (7.0, 1, 'inbound', 0.92, 48),
      (7.2, 1, 'inbound', 0.89, 51),
      (7.4, 2, 'inbound', 0.84, 38),
      (7.7, 1, 'outbound', 0.91, 46),
      (7.9, 1, 'inbound', 0.87, 50),
      (8.0, 3, 'inbound', 0.78, 35),
      (8.1, 1, 'outbound', 0.93, 52),
      (8.3, 1, 'inbound', 0.90, 49),
      (8.5, 4, 'inbound', 0.76, 32),
      (8.6, 1, 'outbound', 0.88, 54),
      (8.8, 1, 'inbound', 0.85, 47),
      (9.0, 2, 'outbound', 0.82, 40),
      // Mid-morning
      (9.5, 5, 'inbound', 0.79, 30),
      (10.0, 1, 'outbound', 0.91, 56),
      (10.3, 3, 'inbound', 0.83, 36),
      (10.8, 8, 'inbound', 0.74, 28),
      (11.0, 1, 'outbound', 0.90, 53),
      // Midday — trucks and mixed
      (11.5, 3, 'inbound', 0.80, 34),
      (12.0, 1, 'inbound', 0.92, 50),
      (12.2, 10, 'inbound', 0.72, 25),
      (12.5, 1, 'outbound', 0.89, 48),
      (12.8, 5, 'outbound', 0.77, 31),
      (13.0, 3, 'inbound', 0.81, 37),
      (13.3, 12, 'inbound', 0.70, 22),
      (13.5, 1, 'outbound', 0.88, 52),
      (13.8, 2, 'inbound', 0.85, 41),
      // Early afternoon lull
      (14.2, 1, 'outbound', 0.90, 55),
      (14.8, 3, 'inbound', 0.79, 33),
      (15.0, 1, 'inbound', 0.87, 49),
      (15.5, 4, 'outbound', 0.75, 29),
      // Afternoon rush 16:00-18:30
      (16.0, 1, 'outbound', 0.93, 44),
      (16.2, 1, 'outbound', 0.91, 47),
      (16.3, 2, 'outbound', 0.83, 39),
      (16.5, 1, 'inbound', 0.88, 51),
      (16.7, 1, 'outbound', 0.90, 46),
      (16.9, 3, 'outbound', 0.80, 35),
      (17.0, 1, 'outbound', 0.92, 50),
      (17.2, 1, 'inbound', 0.86, 48),
      (17.5, 5, 'outbound', 0.78, 30),
      (17.7, 1, 'outbound', 0.89, 53),
      (17.9, 1, 'outbound', 0.91, 45),
      (18.0, 8, 'inbound', 0.73, 27),
      (18.3, 1, 'outbound', 0.87, 52),
      // Evening wind-down
      (19.0, 1, 'outbound', 0.90, 56),
      (20.0, 3, 'inbound', 0.82, 38),
      (21.5, 1, 'outbound', 0.86, 54),
      (22.5, 1, 'inbound', 0.84, 50),
      (23.5, 3, 'outbound', 0.77, 33),
    ];

    final bboxes = <String>[
      jsonEncode({'x': 0.18, 'y': 0.24, 'w': 0.18, 'h': 0.12}),
      jsonEncode({'x': 0.28, 'y': 0.30, 'w': 0.16, 'h': 0.11}),
      jsonEncode({'x': 0.42, 'y': 0.34, 'w': 0.20, 'h': 0.12}),
      jsonEncode({'x': 0.55, 'y': 0.28, 'w': 0.15, 'h': 0.10}),
    ];

    final entries = <VehicleCrossingsCompanion>[];
    for (var i = 0; i < data.length; i++) {
      final (hours, cls, dir, conf, speed) = data[i];
      final ts = start.add(Duration(
        minutes: (hours * 60).round(),
      ));
      if (ts.isAfter(end)) break;

      final idSuffix = '${cameraId.hashCode.toRadixString(36)}-$i';
      entries.add(
        VehicleCrossingsCompanion.insert(
          id: 'demo-cx-$idSuffix',
          cameraId: cameraId,
          lineId: lineId,
          trackId: 'demo-tk-$idSuffix',
          crossingSeq: const Value(1),
          class12: cls,
          confidence: conf,
          direction: dir,
          frameIndex: i * 12,
          speedEstimateKmh: Value(speed),
          bboxJson: Value(bboxes[i % bboxes.length]),
          timestampUtc: ts,
        ),
      );
    }

    return entries;
  }
}
