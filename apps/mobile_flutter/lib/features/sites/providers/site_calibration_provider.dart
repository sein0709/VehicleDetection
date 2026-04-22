import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/features/sites/models/site_calibration.dart';
import 'package:greyeye_mobile/features/sites/services/site_calibration_storage.dart';
import 'package:greyeye_mobile/features/sites/services/task_calibration_builder.dart';

/// Singleton storage instance. Test code overrides via
/// `siteCalibrationStorageProvider.overrideWith(...)` so the unit
/// tests don't need a real filesystem.
final siteCalibrationStorageProvider =
    Provider<SiteCalibrationStorage>((ref) => FileSiteCalibrationStorage());

/// State held by [SiteCalibrationNotifier].
///
/// We always expose a non-null [SiteCalibration] (defaulting to
/// [SiteCalibration.empty] for sites that have never been configured)
/// so the UI never has to handle a "no record yet" state separately
/// from an "empty calibration" state — they look identical.
class SiteCalibrationState {
  const SiteCalibrationState({
    required this.calibration,
    required this.loading,
  });

  final SiteCalibration calibration;
  /// True only on the very first load from disk. Subsequent edits
  /// don't trigger a loading state — we save in the background while
  /// keeping the UI responsive on the in-memory copy.
  final bool loading;
}

class SiteCalibrationNotifier extends StateNotifier<SiteCalibrationState> {
  SiteCalibrationNotifier(this._storage, this._siteId)
      : super(
          const SiteCalibrationState(
            calibration: SiteCalibration.empty,
            loading: true,
          ),
        ) {
    _hydrate();
  }

  final SiteCalibrationStorage _storage;
  final String _siteId;

  Future<void> _hydrate() async {
    final loaded = await _storage.load(_siteId);
    if (!mounted) return;
    state = SiteCalibrationState(
      calibration: loaded ?? SiteCalibration.empty,
      loading: false,
    );
  }

  /// Replace state and persist. The persist is fire-and-forget — the
  /// UI doesn't block on disk IO. Errors are swallowed in the storage
  /// impl (already logged), so we don't bubble them up here.
  Future<void> update(SiteCalibration updated) async {
    state = SiteCalibrationState(calibration: updated, loading: false);
    await _storage.save(_siteId, updated);
  }

  /// Convenience wrappers — saves the screen from rebuilding the full
  /// SiteCalibration each time it edits one field.
  Future<void> setIncludeAnnotatedVideo(bool v) =>
      update(state.calibration.copyWith(includeAnnotatedVideo: v));

  Future<void> setEnabledTasks(Set<String> tasks) =>
      update(state.calibration.copyWith(enabledTasks: tasks));

  Future<void> setTrafficLightOverrides(
    List<TrafficLightOverride> overrides,
  ) =>
      update(state.calibration
          .copyWith(trafficLightOverrides: overrides),);

  Future<void> setSpeedOverride(SpeedOverride? override) {
    final cur = state.calibration;
    final next = override == null
        ? cur.withoutSpeed()
        : cur.copyWith(speedOverride: override);
    return update(next);
  }

  Future<void> setTransitOverride(TransitOverride? override) {
    final cur = state.calibration;
    final next = override == null
        ? cur.withoutTransit()
        : cur.copyWith(transitOverride: override);
    return update(next);
  }

  Future<void> setCountLineOverride(CountLineOverride? override) {
    final cur = state.calibration;
    final next = override == null
        ? cur.withoutCountLines()
        : cur.copyWith(countLineOverride: override);
    return update(next);
  }

  Future<void> setPedestrianZoneOverride(
    PedestrianZoneOverride? override,
  ) {
    final cur = state.calibration;
    final next = override == null
        ? cur.withoutPedestrianZone()
        : cur.copyWith(pedestrianZoneOverride: override);
    return update(next);
  }

  Future<void> setLprAllowlist(List<String> plates) =>
      update(state.calibration.copyWith(lprAllowlist: plates));

  Future<void> setTransitAutoMode(bool v) =>
      update(state.calibration.copyWith(transitAutoMode: v));

  Future<void> setLightAutoMode(bool v) =>
      update(state.calibration.copyWith(lightAutoMode: v));

  Future<void> setTransitMaxCapacity(int n) =>
      update(state.calibration.copyWith(transitMaxCapacity: n));

  Future<void> setLightAutoLabel(String label) =>
      update(state.calibration.copyWith(lightAutoLabel: label));

  /// Delete the saved record entirely. Next [_hydrate] returns
  /// [SiteCalibration.empty].
  Future<void> reset() async {
    await _storage.clear(_siteId);
    state = const SiteCalibrationState(
      calibration: SiteCalibration.empty,
      loading: false,
    );
  }
}

/// Per-site provider, keyed by `siteId`.
///
/// The `family.autoDispose` combo means that navigating away from a
/// site frees the in-memory state, while subsequent visits re-hydrate
/// from disk — no stale state across sessions.
final siteCalibrationProvider = StateNotifierProvider.autoDispose
    .family<SiteCalibrationNotifier, SiteCalibrationState, String>(
  (ref, siteId) {
    final storage = ref.watch(siteCalibrationStorageProvider);
    return SiteCalibrationNotifier(storage, siteId);
  },
);
