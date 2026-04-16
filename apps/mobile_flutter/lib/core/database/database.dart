import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:greyeye_mobile/core/database/daos/cameras_dao.dart';
import 'package:greyeye_mobile/core/database/daos/classifications_dao.dart';
import 'package:greyeye_mobile/core/database/daos/crossings_dao.dart';
import 'package:greyeye_mobile/core/database/daos/roi_dao.dart';
import 'package:greyeye_mobile/core/database/daos/sites_dao.dart';
import 'package:greyeye_mobile/core/database/tables.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Sites,
    Cameras,
    RoiPresets,
    CountingLines,
    VehicleCrossings,
    AggVehicleCounts15m,
    ManualClassifications,
  ],
  daos: [SitesDao, CamerasDao, RoiDao, CrossingsDao, ClassificationsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(manualClassifications);
          }
          if (from < 3) {
            await m.addColumn(
              vehicleCrossings,
              vehicleCrossings.vlmClassCode,
            );
            await m.addColumn(
              vehicleCrossings,
              vehicleCrossings.vlmConfidence,
            );
            await m.addColumn(
              vehicleCrossings,
              vehicleCrossings.classificationSource,
            );
          }
        },
      );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cameras_site_id ON cameras (site_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_roi_presets_camera_id '
      'ON roi_presets (camera_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_counting_lines_preset_id '
      'ON counting_lines (preset_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_counting_lines_camera_id '
      'ON counting_lines (camera_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_crossings_camera_ts '
      'ON vehicle_crossings (camera_id, timestamp_utc)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_crossings_line_ts '
      'ON vehicle_crossings (line_id, timestamp_utc)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_agg_camera_bucket '
      'ON agg_vehicle_counts15m (camera_id, bucket_start)',
    );
  }

  /// Delete all data (useful for logout / reset).
  Future<void> clearAllData() => transaction(() async {
        await delete(manualClassifications).go();
        await delete(aggVehicleCounts15m).go();
        await delete(vehicleCrossings).go();
        await delete(countingLines).go();
        await delete(roiPresets).go();
        await delete(cameras).go();
        await delete(sites).go();
      });
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'greyeye.sqlite'));
    if (kDebugMode) {
      debugPrint('Database path: ${file.path}');
    }
    return NativeDatabase.createInBackground(file, logStatements: kDebugMode);
  });
}
