import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/features/alerts/models/alert_model.dart';
import 'package:greyeye_mobile/features/alerts/providers/alerts_provider.dart';
import 'package:greyeye_mobile/shared/widgets/empty_state.dart';
import 'package:greyeye_mobile/shared/widgets/error_view.dart';

class AlertRulesScreen extends ConsumerWidget {
  const AlertRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rulesAsync = ref.watch(alertRulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.alertRulesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.alertRuleAdd,
            onPressed: () => _showAddRuleDialog(context, ref),
          ),
        ],
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: l10n.commonError,
          onRetry: () => ref.invalidate(alertRulesProvider),
        ),
        data: (rules) {
          if (rules.isEmpty) {
            return EmptyState(
              icon: Icons.rule,
              title: 'No alert rules configured',
              actionLabel: l10n.alertRuleAdd,
              onAction: () => _showAddRuleDialog(context, ref),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            itemBuilder: (context, index) =>
                _RuleCard(rule: rules[index]),
          );
        },
      ),
    );
  }

  void _showAddRuleDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final thresholdController = TextEditingController(text: '100');
    String conditionType = 'congestion';
    String severity = 'warning';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Alert Rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Rule Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: conditionType,
                  decoration: const InputDecoration(labelText: 'Condition'),
                  items: const [
                    DropdownMenuItem(
                      value: 'congestion',
                      child: Text('Congestion'),
                    ),
                    DropdownMenuItem(
                      value: 'speed_drop',
                      child: Text('Speed Drop'),
                    ),
                    DropdownMenuItem(
                      value: 'stopped_vehicle',
                      child: Text('Stopped Vehicle'),
                    ),
                    DropdownMenuItem(
                      value: 'heavy_vehicle_share',
                      child: Text('Heavy Vehicle Share'),
                    ),
                    DropdownMenuItem(
                      value: 'camera_offline',
                      child: Text('Camera Offline'),
                    ),
                    DropdownMenuItem(
                      value: 'count_anomaly',
                      child: Text('Count Anomaly'),
                    ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => conditionType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: thresholdController,
                  decoration: const InputDecoration(labelText: 'Threshold'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: severity,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: AlertSeverity.values
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.name,
                          child: Text(s.name.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => severity = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                ref.read(alertRulesProvider.notifier).createRule({
                  'name': nameController.text.trim(),
                  'condition_type': conditionType,
                  'threshold':
                      double.tryParse(thresholdController.text) ?? 100,
                  'severity': severity,
                  'enabled': true,
                  'cooldown_minutes': 15,
                });
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleCard extends ConsumerWidget {
  const _RuleCard({required this.rule});

  final AlertRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rule.severity.color.withValues(alpha: 0.15),
          child: Icon(
            Icons.rule,
            color: rule.severity.color,
          ),
        ),
        title: Text(rule.name),
        subtitle: Text(
          '${rule.conditionType} · threshold: ${rule.threshold}',
        ),
        trailing: Switch(
          value: rule.enabled,
          onChanged: (enabled) {
            ref.read(alertRulesProvider.notifier).updateRule(
              rule.id,
              {'enabled': enabled},
            );
          },
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
