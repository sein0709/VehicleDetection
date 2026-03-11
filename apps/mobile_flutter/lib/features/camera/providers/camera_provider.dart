import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/database/database.dart';
import 'package:greyeye_mobile/core/database/database_provider.dart';
import 'package:greyeye_mobile/core/database/daos/cameras_dao.dart';
import 'package:greyeye_mobile/features/camera/models/camera_model.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class CameraListNotifier extends StateNotifier<AsyncValue<List<CameraView>>> {
  CameraListNotifier(this._camerasDao, this._siteId)
      : super(const AsyncValue.loading()) {
    load();
  }

  final CamerasDao _camerasDao;
  final String _siteId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final rows = await _camerasDao.camerasForSite(_siteId);
      state = AsyncValue.data(rows.map(CameraView.fromDbRow).toList());
    } on Exception catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<CameraView> addCamera({
    required String name,
    String sourceType = 'smartphone',
    CameraSettings settings = const CameraSettings(),
  }) async {
    final id = _uuid.v4();
    await _camerasDao.insertCamera(CamerasCompanion.insert(
      id: id,
      siteId: _siteId,
      name: name,
      sourceType: Value(sourceType),
      settingsJson: Value(jsonEncode(settings.toJson())),
    ));
    final row = await _camerasDao.cameraById(id);
    final view = CameraView.fromDbRow(row!);
    state.whenData((cameras) {
      state = AsyncValue.data([view, ...cameras]);
    });
    return view;
  }

  Future<void> updateCamera(
    String cameraId, {
    String? name,
    CameraSettings? settings,
  }) async {
    final row = await _camerasDao.cameraById(cameraId);
    if (row == null) return;
    await _camerasDao.updateCamera(CamerasCompanion(
      id: Value(cameraId),
      siteId: Value(row.siteId),
      name: Value(name ?? row.name),
      sourceType: Value(row.sourceType),
      settingsJson: Value(
        settings != null ? jsonEncode(settings.toJson()) : row.settingsJson,
      ),
      status: Value(row.status),
      updatedAt: Value(DateTime.now()),
    ));
    await load();
  }

  Future<void> deleteCamera(String cameraId) async {
    await _camerasDao.deleteCamera(cameraId);
    state.whenData((cameras) {
      state =
          AsyncValue.data(cameras.where((c) => c.id != cameraId).toList());
    });
  }
}

final cameraListProvider = StateNotifierProvider.family<CameraListNotifier,
    AsyncValue<List<CameraView>>, String>((ref, siteId) {
  return CameraListNotifier(ref.watch(camerasDaoProvider), siteId);
});

final cameraDetailProvider =
    FutureProvider.family<CameraView, String>((ref, cameraId) async {
  final dao = ref.watch(camerasDaoProvider);
  final row = await dao.cameraById(cameraId);
  if (row == null) throw Exception('Camera $cameraId not found');
  return CameraView.fromDbRow(row);
});
