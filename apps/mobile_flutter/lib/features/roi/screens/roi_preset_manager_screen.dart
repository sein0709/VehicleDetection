import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:greyeye_mobile/features/roi/models/roi_model.dart';
import 'package:greyeye_mobile/features/roi/providers/roi_provider.dart';
import 'package:greyeye_mobile/shared/widgets/error_view.dart';

class RoiPresetManagerScreen extends ConsumerWidget {
  const RoiPresetManagerScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(roiPresetsProvider(cameraId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ROI Presets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/cameras/$cameraId/roi'),
          ),
        ],
      ),
      body: presetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'Failed to load presets',
          onRetry: () => ref.invalidate(roiPresetsProvider(cameraId)),
        ),
        data: (presets) {
          if (presets.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.crop_free,
                    size: 64,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  const Text('No ROI presets configured'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () =>
                        context.push('/cameras/$cameraId/roi'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Preset'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: presets.length,
            itemBuilder: (context, index) => _PresetCard(
              preset: presets[index],
              cameraId: cameraId,
            ),
          );
        },
      ),
    );
  }
}

class _PresetCard extends ConsumerWidget {
  const _PresetCard({required this.preset, required this.cameraId});

  final RoiPreset preset;
  final String cameraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: preset.isActive
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            preset.isActive ? Icons.check_circle : Icons.crop_free,
            color: preset.isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ),
        title: Text(preset.name),
        subtitle: Text(
          '${preset.countingLines.length} lines · ${preset.lanePolylines.length} lanes',
        ),
        trailing: preset.isActive
            ? Chip(
                label: const Text('Active'),
                backgroundColor: theme.colorScheme.primaryContainer,
              )
            : TextButton(
                onPressed: () async {
                  await ref
                      .read(roiEditorProvider(cameraId).notifier)
                      .activatePreset(preset.id);
                  ref.invalidate(roiPresetsProvider(cameraId));
                },
                child: const Text('Activate'),
              ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
