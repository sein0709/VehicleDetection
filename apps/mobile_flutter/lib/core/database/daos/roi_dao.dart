import 'package:drift/drift.dart';
import 'package:greyeye_mobile/core/database/database.dart';
import 'package:greyeye_mobile/core/database/tables.dart';

part 'roi_dao.g.dart';

@DriftAccessor(tables: [RoiPresets, CountingLines])
class RoiDao extends DatabaseAccessor<AppDatabase> with _$RoiDaoMixin {
  RoiDao(super.db);

  // --- ROI Presets ---

  Future<List<RoiPreset>> presetsForCamera(String cameraId) =>
      (select(roiPresets)
            ..where((t) => t.cameraId.equals(cameraId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Stream<List<RoiPreset>> watchPresetsForCamera(String cameraId) =>
      (select(roiPresets)
            ..where((t) => t.cameraId.equals(cameraId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<RoiPreset?> activePresetForCamera(String cameraId) =>
      (select(roiPresets)
            ..where(
                (t) => t.cameraId.equals(cameraId) & t.isActive.equals(true),
          ))
          .getSingleOrNull();

  Future<int> insertPreset(RoiPresetsCompanion entry) =>
      into(roiPresets).insert(entry);

  Future<bool> updatePreset(RoiPresetsCompanion entry) =>
      update(roiPresets).replace(entry);

  Future<int> deletePreset(String id) =>
      (delete(roiPresets)..where((t) => t.id.equals(id))).go();

  /// Deactivate all presets for a camera, then activate the given one.
  Future<void> activatePreset(String cameraId, String presetId) =>
      transaction(() async {
        await (update(roiPresets)
              ..where((t) => t.cameraId.equals(cameraId)))
            .write(const RoiPresetsCompanion(isActive: Value(false)));
        await (update(roiPresets)
              ..where((t) => t.id.equals(presetId)))
            .write(const RoiPresetsCompanion(isActive: Value(true)));
      });

  // --- Counting Lines ---

  Future<List<CountingLine>> linesForPreset(String presetId) =>
      (select(countingLines)
            ..where((t) => t.presetId.equals(presetId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Stream<List<CountingLine>> watchLinesForPreset(String presetId) =>
      (select(countingLines)
            ..where((t) => t.presetId.equals(presetId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<List<CountingLine>> linesForCamera(String cameraId) =>
      (select(countingLines)
            ..where((t) => t.cameraId.equals(cameraId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<int> insertLine(CountingLinesCompanion entry) =>
      into(countingLines).insert(entry);

  Future<bool> updateLine(CountingLinesCompanion entry) =>
      update(countingLines).replace(entry);

  Future<int> deleteLine(String id) =>
      (delete(countingLines)..where((t) => t.id.equals(id))).go();

  Future<int> deleteLinesForPreset(String presetId) =>
      (delete(countingLines)..where((t) => t.presetId.equals(presetId))).go();
}
