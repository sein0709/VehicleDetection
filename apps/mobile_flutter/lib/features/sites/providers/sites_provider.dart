import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/constants/api_constants.dart';
import 'package:greyeye_mobile/core/network/api_client.dart';
import 'package:greyeye_mobile/features/sites/models/site_model.dart';

class SitesNotifier extends StateNotifier<AsyncValue<List<Site>>> {
  SitesNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  final ApiClient _api;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final response = await _api.get<Map<String, dynamic>>(ApiConstants.sites);
      final data = response.data;
      final items = (data?['data'] as List<dynamic>?)
              ?.map((e) => Site.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      state = AsyncValue.data(items);
    } on Exception catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Site> create(Map<String, dynamic> body) async {
    final response =
        await _api.post<Map<String, dynamic>>(ApiConstants.sites, data: body);
    final site = Site.fromJson(response.data!);
    state.whenData((sites) {
      state = AsyncValue.data([...sites, site]);
    });
    return site;
  }

  Future<void> update(String siteId, Map<String, dynamic> body) async {
    await _api.patch<Map<String, dynamic>>(
      ApiConstants.site(siteId),
      data: body,
    );
    await load();
  }

  Future<void> delete(String siteId) async {
    await _api.delete<void>(ApiConstants.site(siteId));
    state.whenData((sites) {
      state = AsyncValue.data(sites.where((s) => s.id != siteId).toList());
    });
  }
}

final sitesProvider =
    StateNotifierProvider<SitesNotifier, AsyncValue<List<Site>>>((ref) {
  return SitesNotifier(ref.watch(apiClientProvider));
});

final siteProvider = Provider.family<Site?, String>((ref, siteId) {
  return ref.watch(sitesProvider).valueOrNull?.firstWhere(
        (s) => s.id == siteId,
        orElse: () => Site(
          id: siteId,
          name: '...',
          orgId: '',
        ),
      );
});
