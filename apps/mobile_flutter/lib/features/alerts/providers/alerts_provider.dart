import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/constants/api_constants.dart';
import 'package:greyeye_mobile/core/network/api_client.dart';
import 'package:greyeye_mobile/features/alerts/models/alert_model.dart';

class AlertsNotifier extends StateNotifier<AsyncValue<List<AlertEvent>>> {
  AlertsNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  final ApiClient _api;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final response =
          await _api.get<Map<String, dynamic>>(ApiConstants.alerts);
      final items = (response.data?['data'] as List<dynamic>?)
              ?.map((e) => AlertEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      state = AsyncValue.data(items);
    } on Exception catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> acknowledge(String alertId) async {
    await _api.post<void>(ApiConstants.alertAcknowledge(alertId));
    await load();
  }

  Future<void> resolve(String alertId) async {
    await _api.post<void>(ApiConstants.alertResolve(alertId));
    await load();
  }
}

final alertsProvider =
    StateNotifierProvider<AlertsNotifier, AsyncValue<List<AlertEvent>>>(
  (ref) => AlertsNotifier(ref.watch(apiClientProvider)),
);

class AlertRulesNotifier extends StateNotifier<AsyncValue<List<AlertRule>>> {
  AlertRulesNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  final ApiClient _api;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final response =
          await _api.get<Map<String, dynamic>>(ApiConstants.alertRules);
      final items = (response.data?['data'] as List<dynamic>?)
              ?.map((e) => AlertRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      state = AsyncValue.data(items);
    } on Exception catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createRule(Map<String, dynamic> body) async {
    await _api.post<void>(ApiConstants.alertRules, data: body);
    await load();
  }

  Future<void> updateRule(String ruleId, Map<String, dynamic> body) async {
    await _api.patch<void>(ApiConstants.alertRule(ruleId), data: body);
    await load();
  }

  Future<void> deleteRule(String ruleId) async {
    await _api.delete<void>(ApiConstants.alertRule(ruleId));
    state.whenData((rules) {
      state = AsyncValue.data(rules.where((r) => r.id != ruleId).toList());
    });
  }
}

final alertRulesProvider =
    StateNotifierProvider<AlertRulesNotifier, AsyncValue<List<AlertRule>>>(
  (ref) => AlertRulesNotifier(ref.watch(apiClientProvider)),
);
