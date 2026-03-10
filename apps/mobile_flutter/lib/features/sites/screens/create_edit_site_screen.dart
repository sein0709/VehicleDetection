import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:greyeye_mobile/features/sites/providers/sites_provider.dart';

class CreateEditSiteScreen extends ConsumerStatefulWidget {
  const CreateEditSiteScreen({super.key, this.siteId});

  final String? siteId;

  @override
  ConsumerState<CreateEditSiteScreen> createState() =>
      _CreateEditSiteScreenState();
}

class _CreateEditSiteScreenState extends ConsumerState<CreateEditSiteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSubmitting = false;

  bool get _isEditing => widget.siteId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final site = ref.read(siteProvider(widget.siteId!));
        if (site != null) {
          _nameController.text = site.name;
          _addressController.text = site.address ?? '';
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final body = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'timezone': 'Asia/Seoul',
      };
      if (_isEditing) {
        await ref.read(sitesProvider.notifier).update(widget.siteId!, body);
      } else {
        await ref.read(sitesProvider.notifier).create(body);
      }
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.siteEditTitle : l10n.siteAddTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.siteName,
                  prefixIcon: const Icon(Icons.location_city_outlined),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.loginFieldRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: l10n.siteAddress,
                  prefixIcon: const Icon(Icons.map_outlined),
                ),
                textInputAction: TextInputAction.done,
                maxLines: 2,
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
    );
  }
}
