import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:greyeye_mobile/features/alerts/models/alert_model.dart';
import 'package:greyeye_mobile/features/alerts/providers/alerts_provider.dart';
import 'package:greyeye_mobile/shared/widgets/empty_state.dart';
import 'package:greyeye_mobile/shared/widgets/error_view.dart';

class AlertsListScreen extends ConsumerWidget {
  const AlertsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final alertsAsync = ref.watch(alertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.alertsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.rule),
            tooltip: l10n.alertRulesTitle,
            onPressed: () => context.go('/alerts/rules'),
          ),
        ],
      ),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: l10n.commonError,
          cause: e.toString(),
          onRetry: () => ref.invalidate(alertsProvider),
        ),
        data: (alerts) {
          if (alerts.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_off_outlined,
              title: l10n.alertsEmpty,
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(alertsProvider.notifier).load(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              itemBuilder: (context, index) =>
                  _AlertCard(alert: alerts[index]),
            ),
          );
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final AlertEvent alert;

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/alerts/${alert.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: alert.severity.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _severityIcon(alert.severity),
                  color: alert.severity.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.ruleName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (alert.message.isNotEmpty)
                      Text(
                        alert.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _StatusBadge(status: alert.status),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(alert.triggeredAt),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  IconData _severityIcon(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Icons.error;
      case AlertSeverity.warning:
        return Icons.warning_amber;
      case AlertSeverity.info:
        return Icons.info_outline;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final AlertStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (color, label) = switch (status) {
      AlertStatus.triggered => (Colors.red, l10n.alertStatusTriggered),
      AlertStatus.acknowledged => (Colors.orange, l10n.alertStatusAcknowledged),
      AlertStatus.assigned => (Colors.blue, l10n.alertStatusAssigned),
      AlertStatus.resolved => (Colors.green, l10n.alertStatusResolved),
      AlertStatus.suppressed => (Colors.grey, l10n.alertStatusSuppressed),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
