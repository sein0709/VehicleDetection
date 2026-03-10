import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/constants/api_constants.dart';
import 'package:greyeye_mobile/core/network/api_client.dart';
import 'package:greyeye_mobile/features/camera/models/camera_model.dart';

class CameraListNotifier extends StateNotifier<AsyncValue<List<Camera>>> {
  CameraListNotifier(this._api, this._siteId)
      : super(const AsyncValue.loading()) {
    load();
  }

  final ApiClient _api;
  final String _siteId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final response = await _api.get<Map<String, dynamic>>(
        ApiConstants.siteCameras(_siteId),
      );
      final items = (response.data?['items'] as List<dynamic>?)
              ?.map((e) => Camera.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      state = AsyncValue.data(items);
    } on Exception catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Camera> addCamera(Map<String, dynamic> body) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiConstants.siteCameras(_siteId),
      data: body,
    );
    final camera = Camera.fromJson(response.data!);
    state.whenData((cameras) {
      state = AsyncValue.data([...cameras, camera]);
    });
    return camera;
  }

  Future<void> updateCamera(
    String cameraId,
    Map<String, dynamic> body,
  ) async {
    await _api.patch<Map<String, dynamic>>(
      ApiConstants.camera(cameraId),
      data: body,
    );
    await load();
  }

  Future<void> deleteCamera(String cameraId) async {
    await _api.delete<void>(ApiConstants.camera(cameraId));
    state.whenData((cameras) {
      state =
          AsyncValue.data(cameras.where((c) => c.id != cameraId).toList());
    });
  }
}

final cameraListProvider = StateNotifierProvider.family<CameraListNotifier,
    AsyncValue<List<Camera>>, String>((ref, siteId) {
  return CameraListNotifier(ref.watch(apiClientProvider), siteId);
});

final cameraDetailProvider =
    FutureProvider.family<Camera, String>((ref, cameraId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>(
    ApiConstants.camera(cameraId),
  );
  return Camera.fromJson(response.data!);
});
