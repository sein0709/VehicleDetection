import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:greyeye_mobile/features/camera/providers/camera_provider.dart';
import 'package:greyeye_mobile/features/roi/models/roi_model.dart';
import 'package:greyeye_mobile/features/roi/providers/roi_provider.dart';
import 'package:greyeye_mobile/features/sites/providers/sites_provider.dart';

class QuickSetupScreen extends ConsumerStatefulWidget {
  const QuickSetupScreen({super.key});

  @override
  ConsumerState<QuickSetupScreen> createState() => _QuickSetupScreenState();
}

class _QuickSetupScreenState extends ConsumerState<QuickSetupScreen> {
  int _step = 0;
  final _siteNameController = TextEditingController();
  final _siteAddressController = TextEditingController();
  final _cameraNameController = TextEditingController();
  String? _siteId;
  String? _cameraId;
  bool _isLoading = false;

  static const _stepTitles = [
    'Create Site',
    'Add Camera',
    'Draw Counting Lines',
    'Verify Setup',
    'Start Monitoring',
  ];

  @override
  void dispose() {
    _siteNameController.dispose();
    _siteAddressController.dispose();
    _cameraNameController.dispose();
    super.dispose();
  }

  Future<void> _createSite() async {
    if (_siteNameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final site = await ref.read(sitesProvider.notifier).create(
            name: _siteNameController.text.trim(),
            address: _siteAddressController.text.trim().isEmpty
                ? null
                : _siteAddressController.text.trim(),
          );
      setState(() {
        _siteId = site.id;
        _step = 1;
        _isLoading = false;
      });
    } on Exception catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _addCamera() async {
    if (_cameraNameController.text.trim().isEmpty || _siteId == null) return;
    setState(() => _isLoading = true);
    try {
      final camera = await ref
          .read(cameraListProvider(_siteId!).notifier)
          .addCamera(name: _cameraNameController.text.trim());
      setState(() {
        _cameraId = camera.id;
        _step = 2;
        _isLoading = false;
      });
    } on Exception catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _saveDefaultRoi() async {
    if (_cameraId == null) return;
    setState(() => _isLoading = true);
    try {
      final notifier = ref.read(roiEditorProvider(_cameraId!).notifier);
      notifier.setPresetName('Default');
      notifier.addCountingLine(
        const CountingLine(
          name: 'Main Line',
          start: Point2D(x: 0.1, y: 0.5),
          end: Point2D(x: 0.9, y: 0.5),
          direction: 'inbound',
        ),
      );
      final preset = await notifier.save();
      await notifier.activatePreset(preset.id);
      setState(() {
        _step = 3;
        _isLoading = false;
      });
    } on Exception catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.setupTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_step + 1) / 5,
            minHeight: 4,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: List.generate(5, (i) {
                final isCompleted = i < _step;
                final isCurrent = i == _step;
                return Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isCompleted
                            ? theme.colorScheme.primary
                            : isCurrent
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                        child: isCompleted
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isCurrent
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                ),
                              ),
                      ),
                      if (i < 4)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: isCompleted
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _stepTitles[_step],
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildStepContent(l10n, theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(AppLocalizations l10n, ThemeData theme) {
    switch (_step) {
      case 0:
        return _buildCreateSiteStep(l10n);
      case 1:
        return _buildAddCameraStep(l10n);
      case 2:
        return _buildDrawLinesStep(l10n, theme);
      case 3:
        return _buildVerifyStep(l10n, theme);
      case 4:
        return _buildCompleteStep(l10n, theme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCreateSiteStep(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupAddSite),
        const SizedBox(height: 16),
        TextField(
          controller: _siteNameController,
          decoration: InputDecoration(
            labelText: l10n.siteName,
            prefixIcon: const Icon(Icons.location_city_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _siteAddressController,
          decoration: InputDecoration(
            labelText: l10n.siteAddress,
            prefixIcon: const Icon(Icons.map_outlined),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isLoading ? null : _createSite,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Next'),
        ),
      ],
    );
  }

  Widget _buildAddCameraStep(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Add your first camera to this site.'),
        const SizedBox(height: 16),
        TextField(
          controller: _cameraNameController,
          decoration: InputDecoration(
            labelText: l10n.cameraName,
            prefixIcon: const Icon(Icons.videocam_outlined),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isLoading ? null : _addCamera,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Next'),
        ),
      ],
    );
  }

  Widget _buildDrawLinesStep(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'A default counting line will be created. You can edit it later in the ROI editor.',
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.horizontal_rule,
                  size: 48,
                  color: Colors.yellowAccent.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Default counting line preview',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isLoading ? null : _saveDefaultRoi,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create & Continue'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _cameraId != null
              ? () => context.push('/cameras/$_cameraId/roi')
              : null,
          child: const Text('Open Full ROI Editor'),
        ),
      ],
    );
  }

  Widget _buildVerifyStep(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VerifyRow(
                  icon: Icons.check_circle,
                  label: 'Site',
                  value: _siteNameController.text,
                ),
                const SizedBox(height: 8),
                _VerifyRow(
                  icon: Icons.check_circle,
                  label: 'Camera',
                  value: _cameraNameController.text,
                ),
                const SizedBox(height: 8),
                const _VerifyRow(
                  icon: Icons.check_circle,
                  label: 'Counting Line',
                  value: 'Default (horizontal)',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => setState(() => _step = 4),
          child: const Text('Activate & Start'),
        ),
      ],
    );
  }

  Widget _buildCompleteStep(AppLocalizations l10n, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 80,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.setupComplete,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your monitoring site is ready. Start capturing traffic data.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.home),
          label: const Text('Go to Dashboard'),
        ),
        const SizedBox(height: 12),
        if (_cameraId != null)
          OutlinedButton.icon(
            onPressed: () =>
                context.push('/cameras/$_cameraId/monitor'),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Open Live Monitor'),
          ),
      ],
    );
  }
}

class _VerifyRow extends StatelessWidget {
  const _VerifyRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: Colors.green, size: 20),
        const SizedBox(width: 8),
        Text('$label: ', style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        )),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
