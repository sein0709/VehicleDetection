import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:greyeye_mobile/core/theme/app_colors.dart';
import 'package:greyeye_mobile/features/camera/models/camera_model.dart';
import 'package:greyeye_mobile/features/camera/providers/camera_provider.dart';
import 'package:greyeye_mobile/shared/widgets/empty_state.dart';
import 'package:greyeye_mobile/shared/widgets/error_view.dart';

class CameraListScreen extends ConsumerWidget {
  const CameraListScreen({super.key, required this.siteId});

  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final camerasAsync = ref.watch(cameraListProvider(siteId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cameraListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.cameraAddTitle,
            onPressed: () =>
                context.go('/home/sites/$siteId/cameras/new'),
          ),
        ],
      ),
      body: camerasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: l10n.commonError,
          cause: e.toString(),
          onRetry: () => ref.invalidate(cameraListProvider(siteId)),
        ),
        data: (cameras) {
          if (cameras.isEmpty) {
            return EmptyState(
              icon: Icons.videocam_off_outlined,
              title: l10n.commonNoData,
              actionLabel: l10n.cameraAddTitle,
              onAction: () =>
                  context.go('/home/sites/$siteId/cameras/new'),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(cameraListProvider(siteId).notifier).load(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cameras.length,
              itemBuilder: (context, index) =>
                  _CameraCard(camera: cameras[index]),
            ),
          );
        },
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.camera});

  final Camera camera;

  Color get _statusColor {
    switch (camera.status) {
      case 'online':
        return AppColors.cameraOnline;
      case 'degraded':
        return AppColors.cameraWarning;
      default:
        return AppColors.cameraOffline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/cameras/${camera.id}/settings'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.videocam),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(camera.name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${camera.sourceType} · ${camera.settings.resolution}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'monitor':
                      context.push('/cameras/${camera.id}/monitor');
                    case 'roi':
                      context.push('/cameras/${camera.id}/roi');
                    case 'analytics':
                      context.push('/cameras/${camera.id}/analytics');
                    case 'settings':
                      context.push('/cameras/${camera.id}/settings');
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'monitor', child: Text('Live Monitor')),
                  PopupMenuItem(value: 'roi', child: Text('ROI Editor')),
                  PopupMenuItem(value: 'analytics', child: Text('Analytics')),
                  PopupMenuItem(value: 'settings', child: Text('Settings')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
