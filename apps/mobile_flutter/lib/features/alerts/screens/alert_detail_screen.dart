import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/features/alerts/models/alert_model.dart';
import 'package:greyeye_mobile/features/alerts/providers/alerts_provider.dart';

class AlertDetailScreen extends ConsumerWidget {
  const AlertDetailScreen({super.key, required this.alertId});

  final String alertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final alertsAsync = ref.watch(alertsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.alertDetailTitle)),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.commonError)),
        data: (alerts) {
          final alert = alerts.where((a) => a.id == alertId).firstOrNull;
          if (alert == null) {
            return Center(child: Text(l10n.errorNotFound));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: alert.severity.color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              alert.ruleName,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _DetailRow(
                        label: l10n.alertSeverity,
                        value: alert.severity.name.toUpperCase(),
                      ),
                      _DetailRow(
                        label: l10n.alertStatus,
                        value: alert.status.name,
                      ),
                      _DetailRow(
                        label: l10n.alertCondition,
                        value: alert.conditionType,
                      ),
                      if (alert.siteName != null)
                        _DetailRow(label: l10n.alertSite, value: alert.siteName!),
                      if (alert.cameraName != null)
                        _DetailRow(
                          label: l10n.alertCamera,
                          value: alert.cameraName!,
                        ),
                      if (alert.message.isNotEmpty)
                        _DetailRow(label: l10n.alertMessage, value: alert.message),
                      if (alert.triggeredAt != null)
                        _DetailRow(
                          label: l10n.alertTimestamp,
                          value: alert.triggeredAt!.toLocal().toString(),
                        ),
                      if (alert.assignedTo != null)
                        _DetailRow(
                          label: l10n.alertAssignedTo,
                          value: alert.assignedTo!,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (alert.status == AlertStatus.triggered)
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(alertsProvider.notifier).acknowledge(alertId),
                  icon: const Icon(Icons.check),
                  label: Text(l10n.alertsMarkRead),
                ),
              if (alert.status == AlertStatus.triggered ||
                  alert.status == AlertStatus.acknowledged) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(alertsProvider.notifier).resolve(alertId),
                  icon: const Icon(Icons.done_all),
                  label: Text(l10n.alertResolve),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
