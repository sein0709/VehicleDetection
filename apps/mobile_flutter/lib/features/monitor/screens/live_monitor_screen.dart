import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/constants/api_constants.dart';
import 'package:greyeye_mobile/core/constants/vehicle_classes.dart';
import 'package:greyeye_mobile/core/theme/app_colors.dart';
import 'package:greyeye_mobile/features/analytics/models/analytics_model.dart';
import 'package:greyeye_mobile/features/analytics/providers/analytics_provider.dart';
import 'package:greyeye_mobile/features/monitor/models/live_track.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class LiveMonitorScreen extends ConsumerStatefulWidget {
  const LiveMonitorScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  ConsumerState<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends ConsumerState<LiveMonitorScreen> {
  WebSocketChannel? _trackChannel;
  StreamSubscription<dynamic>? _trackSub;
  List<LiveTrack> _tracks = [];
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _connectTrackStream();
  }

  void _connectTrackStream() {
    final uri = Uri.parse(
      '${ApiConstants.wsBaseUrl}/v1/tracks/live/ws?camera_id=${widget.cameraId}',
    );
    _trackChannel = WebSocketChannel.connect(uri);
    _trackSub = _trackChannel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          final tracks = (json['tracks'] as List<dynamic>?)
                  ?.map((t) => LiveTrack.fromJson(t as Map<String, dynamic>))
                  .toList() ??
              [];
          setState(() {
            _tracks = tracks;
            _connected = true;
          });
        } on Exception {
          // ignore
        }
      },
      onError: (_) => _reconnect(),
      onDone: _reconnect,
    );
  }

  void _reconnect() {
    _trackSub?.cancel();
    _trackChannel?.sink.close();
    setState(() => _connected = false);
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) _connectTrackStream();
    });
  }

  @override
  void dispose() {
    _trackSub?.cancel();
    _trackChannel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final liveKpi = ref.watch(liveKpiProvider(widget.cameraId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.monitorTitle),
        actions: [
          Icon(
            Icons.circle,
            size: 12,
            color: _connected ? AppColors.cameraOnline : AppColors.cameraOffline,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!_connected)
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.monitorNoFeed,
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    CustomPaint(
                      painter: _TrackOverlayPainter(tracks: _tracks),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_tracks.length} tracks',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _LiveKpiPanel(liveKpi: liveKpi, theme: theme, l10n: l10n),
          ),
        ],
      ),
    );
  }
}

class _LiveKpiPanel extends StatelessWidget {
  const _LiveKpiPanel({
    required this.liveKpi,
    required this.theme,
    required this.l10n,
  });

  final LiveKpiUpdate? liveKpi;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final kpi = liveKpi;
    if (kpi == null) {
      return const Center(child: Text('Waiting for data...'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: l10n.monitorVehicleCount,
                value: '${kpi.totalCount}',
                icon: Icons.directions_car,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiCard(
                label: 'Flow Rate/h',
                value: '${kpi.flowRatePerHour}',
                icon: Icons.speed,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiCard(
                label: 'Active Tracks',
                value: '${kpi.activeTracks}',
                icon: Icons.track_changes,
                color: theme.colorScheme.tertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Bucket',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: kpi.elapsedSeconds / 900.0,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(kpi.elapsedSeconds / 60).toStringAsFixed(1)} / 15.0 min',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('By Direction', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DirectionBar(
                        label: 'Inbound',
                        count: kpi.byDirection['inbound'] ?? 0,
                        total: kpi.totalCount,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DirectionBar(
                        label: 'Outbound',
                        count: kpi.byDirection['outbound'] ?? 0,
                        total: kpi.totalCount,
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('By Class', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ...kpi.byClass.entries.map<Widget>((entry) {
                  final vc = VehicleClass.fromCode(entry.key);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: vc?.color ?? Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vc?.labelEn ?? 'Class ${entry.key}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionBar extends StatelessWidget {
  const _DirectionBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? count / total : 0.0;
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: fraction,
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 2),
        Text('$count', style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _TrackOverlayPainter extends CustomPainter {
  _TrackOverlayPainter({required this.tracks});

  final List<LiveTrack> tracks;

  @override
  void paint(Canvas canvas, Size size) {
    for (final track in tracks) {
      final vc = VehicleClass.fromCode(track.classCode);
      final color = vc?.color ?? Colors.white;

      final rect = Rect.fromLTWH(
        track.bbox.x * size.width,
        track.bbox.y * size.height,
        track.bbox.w * size.width,
        track.bbox.h * size.height,
      );

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(rect, paint);

      final label = vc?.labelEn ?? 'C${track.classCode}';
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$label #${track.trackId}',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black54,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(rect.left, rect.top - 14));
    }
  }

  @override
  bool shouldRepaint(covariant _TrackOverlayPainter oldDelegate) =>
      tracks != oldDelegate.tracks;
}
