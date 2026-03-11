import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/constants/api_constants.dart';
import 'package:greyeye_mobile/core/network/api_client.dart';
import 'package:greyeye_mobile/features/analytics/models/analytics_model.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class AnalyticsParams {
  const AnalyticsParams({
    required this.cameraId,
    required this.start,
    required this.end,
    this.groupBy = 'class',
  });

  final String cameraId;
  final DateTime start;
  final DateTime end;
  final String groupBy;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalyticsParams &&
          cameraId == other.cameraId &&
          start == other.start &&
          end == other.end &&
          groupBy == other.groupBy;

  @override
  int get hashCode => Object.hash(cameraId, start, end, groupBy);
}

final analyticsProvider =
    FutureProvider.family<AnalyticsResponse, AnalyticsParams>(
  (ref, params) async {
    final api = ref.watch(apiClientProvider);
    final response = await api.get<Map<String, dynamic>>(
      ApiConstants.analytics15m,
      queryParameters: {
        'camera_id': params.cameraId,
        'start': params.start.toUtc().toIso8601String(),
        'end': params.end.toUtc().toIso8601String(),
        'group_by': params.groupBy,
      },
    );
    return AnalyticsResponse.fromJson(response.data!);
  },
);

class LiveKpiNotifier extends StateNotifier<LiveKpiUpdate?> {
  LiveKpiNotifier(this._cameraId) : super(null) {
    _connect();
  }

  final String _cameraId;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  void _connect() {
    final uri = Uri.parse(
      '${ApiConstants.wsBaseUrl}${ApiConstants.analyticsLiveWs}?camera_id=$_cameraId',
    );
    _channel = WebSocketChannel.connect(uri);
    _subscription = _channel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (json['type'] == 'live_kpi_update') {
            state = LiveKpiUpdate.fromJson(json);
          }
        } on Exception {
          // ignore malformed messages
        }
      },
      onError: (_) => _reconnect(),
      onDone: _reconnect,
    );
  }

  void _reconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    Future<void>.delayed(const Duration(seconds: 3), _connect);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}

final liveKpiProvider = StateNotifierProvider.autoDispose
    .family<LiveKpiNotifier, LiveKpiUpdate?, String>((ref, cameraId) {
  return LiveKpiNotifier(cameraId);
});
