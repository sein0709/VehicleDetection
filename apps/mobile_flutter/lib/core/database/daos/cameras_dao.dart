import 'package:drift/drift.dart';
import 'package:greyeye_mobile/core/database/database.dart';
import 'package:greyeye_mobile/core/database/tables.dart';

part 'cameras_dao.g.dart';

@DriftAccessor(tables: [Cameras])
class CamerasDao extends DatabaseAccessor<AppDatabase> with _$CamerasDaoMixin {
  CamerasDao(super.db);

  Future<List<Camera>> camerasForSite(String siteId) =>
      (select(cameras)
            ..where((t) => t.siteId.equals(siteId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Stream<List<Camera>> watchCamerasForSite(String siteId) =>
      (select(cameras)
            ..where((t) => t.siteId.equals(siteId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<Camera?> cameraById(String id) =>
      (select(cameras)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<Camera?> watchCameraById(String id) =>
      (select(cameras)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<int> insertCamera(CamerasCompanion entry) =>
      into(cameras).insert(entry);

  Future<bool> updateCamera(CamerasCompanion entry) =>
      update(cameras).replace(entry);

  Future<void> updateStatus(String id, String newStatus) =>
      (update(cameras)..where((t) => t.id.equals(id))).write(
        CamerasCompanion(
          status: Value(newStatus),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> markSeen(String id) =>
      (update(cameras)..where((t) => t.id.equals(id))).write(
        CamerasCompanion(
          lastSeenAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<int> deleteCamera(String id) =>
      (delete(cameras)..where((t) => t.id.equals(id))).go();
}
