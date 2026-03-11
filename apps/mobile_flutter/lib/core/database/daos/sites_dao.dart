import 'package:drift/drift.dart';
import 'package:greyeye_mobile/core/database/database.dart';
import 'package:greyeye_mobile/core/database/tables.dart';

part 'sites_dao.g.dart';

@DriftAccessor(tables: [Sites, Cameras])
class SitesDao extends DatabaseAccessor<AppDatabase> with _$SitesDaoMixin {
  SitesDao(super.db);

  Future<List<Site>> allSites() =>
      (select(sites)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Stream<List<Site>> watchAllSites() =>
      (select(sites)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Future<Site?> siteById(String id) =>
      (select(sites)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<Site?> watchSiteById(String id) =>
      (select(sites)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<int> insertSite(SitesCompanion entry) => into(sites).insert(entry);

  Future<bool> updateSite(SitesCompanion entry) =>
      update(sites).replace(entry);

  Future<int> deleteSite(String id) =>
      (delete(sites)..where((t) => t.id.equals(id))).go();

  Future<int> cameraCountForSite(String siteId) async {
    final count = cameras.id.count();
    final query = selectOnly(cameras)
      ..addColumns([count])
      ..where(cameras.siteId.equals(siteId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> activeCameraCountForSite(String siteId) async {
    final count = cameras.id.count();
    final query = selectOnly(cameras)
      ..addColumns([count])
      ..where(
          cameras.siteId.equals(siteId) & cameras.status.equals('online'),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}
