import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:greyeye_mobile/core/theme/app_colors.dart';
import 'package:greyeye_mobile/features/camera/providers/camera_provider.dart';
import 'package:greyeye_mobile/shared/widgets/error_view.dart';

class CameraSettingsScreen extends ConsumerWidget {
  const CameraSettingsScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cameraAsync = ref.watch(cameraDetailProvider(cameraId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cameraDetailTitle)),
      body: cameraAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: l10n.commonError,
          onRetry: () => ref.invalidate(cameraDetailProvider(cameraId)),
        ),
        data: (camera) {
          final statusColor = camera.isOnline
              ? AppColors.cameraOnline
              : camera.isDegraded
                  ? AppColors.cameraWarning
                  : AppColors.cameraOffline;

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
                          Icon(Icons.circle, size: 12, color: statusColor),
                          const SizedBox(width: 8),
                          Text(
                            camera.status.toUpperCase(),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(label: l10n.cameraName, value: camera.name),
                      _InfoRow(label: 'Source', value: camera.sourceType),
                      _InfoRow(
                        label: 'Resolution',
                        value: camera.settings.resolution,
                      ),
                      _InfoRow(
                        label: 'FPS',
                        value: '${camera.settings.targetFps}',
                      ),
                      _InfoRow(
                        label: 'Classification',
                        value: camera.settings.classificationMode,
                      ),
                      _InfoRow(
                        label: 'Night Mode',
                        value: camera.settings.nightMode ? 'On' : 'Off',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ActionButton(
                icon: Icons.play_circle_outline,
                label: l10n.monitorTitle,
                onTap: () => context.push('/cameras/$cameraId/monitor'),
              ),
              _ActionButton(
                icon: Icons.crop_free,
                label: l10n.roiTitle,
                onTap: () => context.push('/cameras/$cameraId/roi'),
              ),
              _ActionButton(
                icon: Icons.list_alt,
                label: 'ROI Presets',
                onTap: () =>
                    context.push('/cameras/$cameraId/roi-presets'),
              ),
              _ActionButton(
                icon: Icons.bar_chart,
                label: l10n.analyticsTitle,
                onTap: () =>
                    context.push('/cameras/$cameraId/analytics'),
              ),
              _ActionButton(
                icon: Icons.file_download_outlined,
                label: l10n.analyticsExport,
                onTap: () =>
                    context.push('/cameras/$cameraId/export'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          )),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
