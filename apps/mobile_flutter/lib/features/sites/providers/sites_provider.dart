import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/database/database.dart' hide Site;
import 'package:greyeye_mobile/core/database/database_provider.dart';
import 'package:greyeye_mobile/core/database/daos/sites_dao.dart';
import 'package:greyeye_mobile/features/sites/models/site_model.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class SitesNotifier extends StateNotifier<AsyncValue<List<SiteView>>> {
  SitesNotifier(this._sitesDao)
      : super(const AsyncValue.loading()) {
    load();
  }

  final SitesDao _sitesDao;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final rows = await _sitesDao.allSites();
      final views = <SiteView>[];
      for (final row in rows) {
        final camCount = await _sitesDao.cameraCountForSite(row.id);
        final activeCamCount =
            await _sitesDao.activeCameraCountForSite(row.id);
        views.add(SiteView.fromDbRow(
          row,
          cameraCount: camCount,
          activeCameraCount: activeCamCount,
        ));
      }
      state = AsyncValue.data(views);
    } on Exception catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<SiteView> create({
    required String name,
    String? address,
    double? latitude,
    double? longitude,
    String timezone = 'Asia/Seoul',
  }) async {
    final id = _uuid.v4();
    await _sitesDao.insertSite(SitesCompanion.insert(
      id: id,
      name: name,
      address: Value(address),
      latitude: Value(latitude),
      longitude: Value(longitude),
      timezone: Value(timezone),
    ));
    final row = await _sitesDao.siteById(id);
    final view = SiteView.fromDbRow(row!);
    state.whenData((sites) {
      state = AsyncValue.data([view, ...sites]);
    });
    return view;
  }

  Future<void> update(
    String siteId, {
    required String name,
    String? address,
    String? timezone,
  }) async {
    await _sitesDao.updateSite(SitesCompanion(
      id: Value(siteId),
      name: Value(name),
      address: Value(address),
      timezone: timezone != null ? Value(timezone) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    ));
    await load();
  }

  Future<void> delete(String siteId) async {
    await _sitesDao.deleteSite(siteId);
    state.whenData((sites) {
      state = AsyncValue.data(sites.where((s) => s.id != siteId).toList());
    });
  }
}

final sitesProvider =
    StateNotifierProvider<SitesNotifier, AsyncValue<List<SiteView>>>((ref) {
  return SitesNotifier(ref.watch(sitesDaoProvider));
});

final siteProvider = Provider.family<SiteView?, String>((ref, siteId) {
  return ref.watch(sitesProvider).valueOrNull?.firstWhere(
        (s) => s.id == siteId,
        orElse: () => SiteView(id: siteId, name: '...'),
      );
});
