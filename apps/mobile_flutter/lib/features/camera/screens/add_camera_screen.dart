import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:greyeye_mobile/features/camera/models/camera_model.dart';
import 'package:greyeye_mobile/features/camera/providers/camera_provider.dart';

class AddCameraScreen extends ConsumerStatefulWidget {
  const AddCameraScreen({super.key, required this.siteId});

  final String siteId;

  @override
  ConsumerState<AddCameraScreen> createState() => _AddCameraScreenState();
}

class _AddCameraScreenState extends ConsumerState<AddCameraScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _sourceType = 'smartphone';
  int _targetFps = 10;
  String _resolution = '1920x1080';
  bool _nightMode = false;
  String _classificationMode = 'full_12class';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(cameraListProvider(widget.siteId).notifier)
          .addCamera(
            name: _nameController.text.trim(),
            sourceType: _sourceType,
            settings: CameraSettings(
              targetFps: _targetFps,
              resolution: _resolution,
              nightMode: _nightMode,
              classificationMode: _classificationMode,
            ),
          );
      if (mounted) context.pop();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final wide = MediaQuery.sizeOf(context).width >= 840;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cameraAddTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 600 : double.infinity),
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.cameraName,
                  prefixIcon: const Icon(Icons.videocam_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.loginFieldRequired : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _sourceType,
                decoration: InputDecoration(
                  labelText: l10n.cameraSourceType,
                  prefixIcon: const Icon(Icons.input),
                ),
                items: [
                  DropdownMenuItem(value: 'smartphone', child: Text(l10n.cameraSourceSmartphone)),
                  DropdownMenuItem(value: 'rtsp', child: Text(l10n.cameraSourceRtsp)),
                  DropdownMenuItem(value: 'onvif', child: Text(l10n.cameraSourceOnvif)),
                ],
                onChanged: (v) => setState(() => _sourceType = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _targetFps,
                decoration: InputDecoration(
                  labelText: l10n.cameraTargetFps,
                  prefixIcon: const Icon(Icons.speed),
                ),
                items: [1, 5, 10, 15, 30]
                    .map((fps) => DropdownMenuItem(
                          value: fps,
                          child: Text('$fps FPS'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _targetFps = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _resolution,
                decoration: InputDecoration(
                  labelText: l10n.cameraResolution,
                  prefixIcon: const Icon(Icons.aspect_ratio),
                ),
                items: const [
                  DropdownMenuItem(value: '1280x720', child: Text('720p')),
                  DropdownMenuItem(value: '1920x1080', child: Text('1080p')),
                ],
                onChanged: (v) => setState(() => _resolution = v!),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(l10n.cameraNightMode),
                value: _nightMode,
                onChanged: (v) => setState(() => _nightMode = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _classificationMode,
                decoration: InputDecoration(
                  labelText: l10n.cameraClassificationMode,
                  prefixIcon: const Icon(Icons.category),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'full_12class',
                    child: Text(l10n.classificationFull12),
                  ),
                  DropdownMenuItem(
                    value: 'coarse_only',
                    child: Text(l10n.classificationCoarse),
                  ),
                  DropdownMenuItem(
                    value: 'disabled',
                    child: Text(l10n.classificationDisabled),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _classificationMode = v!),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }
}
