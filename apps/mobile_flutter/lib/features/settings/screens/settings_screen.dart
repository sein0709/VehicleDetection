import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:greyeye_mobile/core/database/database_provider.dart';
import 'package:greyeye_mobile/core/inference/pipeline_settings.dart';
import 'package:greyeye_mobile/core/inference/vlm_settings_provider.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:greyeye_mobile/features/auth/providers/auth_provider.dart';
import 'package:greyeye_mobile/features/settings/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);

    final wide = MediaQuery.sizeOf(context).width >= 840;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 640 : double.infinity),
          child: ListView(
        children: [
          if (auth.user != null) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      auth.user!.displayName.isNotEmpty
                          ? auth.user!.displayName[0].toUpperCase()
                          : '?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.user!.displayName,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          auth.user!.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
          ],
          _SectionHeader(title: l10n.settingsAppearance),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.settingsTheme),
            subtitle: Text(_themeName(settings.themeMode, l10n)),
            onTap: () => _showThemePicker(context, ref, settings, l10n),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.settingsLanguage),
            subtitle: Text(
              settings.locale?.languageCode == 'ko' ? '한국어' : 'English',
            ),
            onTap: () => _showLanguagePicker(context, ref, settings),
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsVersion),
            subtitle: const Text('0.1.0'),
          ),
          ListTile(
            leading: const Icon(Icons.rocket_launch_outlined),
            title: Text(l10n.settingsQuickSetup),
            subtitle: Text(l10n.settingsQuickSetupDesc),
            onTap: () => context.go('/setup'),
          ),
          const Divider(),
          const _CloudClassificationSection(),
          const Divider(),
          _SectionHeader(title: l10n.settingsData),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: Text(l10n.settingsClearData),
            subtitle: Text(l10n.settingsClearDataDesc),
            onTap: () => _confirmClearData(context, ref, l10n),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(
              l10n.settingsLogout,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => _confirmLogout(context, ref, l10n),
          ),
        ],
      ),
        ),
      ),
    );
  }

  String _themeName(ThemeMode mode, AppLocalizations l10n) {
    switch (mode) {
      case ThemeMode.light:
        return l10n.settingsThemeLight;
      case ThemeMode.dark:
        return l10n.settingsThemeDark;
      case ThemeMode.system:
        return l10n.settingsThemeSystem;
    }
  }

  void _showThemePicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    AppLocalizations l10n,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.settingsTheme),
        children: [
          for (final mode in ThemeMode.values)
            RadioListTile<ThemeMode>(
              value: mode,
              groupValue: settings.themeMode,
              title: Text(_themeName(mode, l10n)),
              onChanged: (v) {
                ref.read(settingsProvider.notifier).setThemeMode(v!);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(AppLocalizations.of(context).settingsLanguage),
        children: [
          RadioListTile<String>(
            value: 'en',
            groupValue: settings.locale?.languageCode ?? 'en',
            title: const Text('English'),
            onChanged: (v) {
              ref
                  .read(settingsProvider.notifier)
                  .setLocale(const Locale('en'));
              Navigator.pop(ctx);
            },
          ),
          RadioListTile<String>(
            value: 'ko',
            groupValue: settings.locale?.languageCode ?? 'en',
            title: const Text('한국어'),
            onChanged: (v) {
              ref
                  .read(settingsProvider.notifier)
                  .setLocale(const Locale('ko'));
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _confirmClearData(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsClearDataConfirmTitle),
        content: Text(l10n.settingsClearDataConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(databaseProvider).clearAllData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.settingsCleared)),
                );
              }
            },
            child: Text(l10n.settingsClearButton),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsLogout),
        content: Text(l10n.settingsLogoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: Text(l10n.settingsLogout),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _CloudClassificationSection extends ConsumerWidget {
  const _CloudClassificationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vlm = ref.watch(vlmSettingsProvider);
    final hasApiKey = vlm.apiKey.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: AppLocalizations.of(context).settingsCloudClassification),
        ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: Text(AppLocalizations.of(context).settingsVlmProvider),
          subtitle: Text(
            hasApiKey
                ? '${_providerLabel(vlm.provider)} · ${vlm.model}'
                : AppLocalizations.of(context).settingsNotConfigured,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const _CloudClassificationDetailScreen(),
            ),
          ),
        ),
      ],
    );
  }

  static String _providerLabel(VlmProvider provider) {
    switch (provider) {
      case VlmProvider.gemini:
        return 'Google Gemini';
      case VlmProvider.openai:
        return 'OpenAI';
    }
  }
}

class _CloudClassificationDetailScreen extends ConsumerStatefulWidget {
  const _CloudClassificationDetailScreen();

  @override
  ConsumerState<_CloudClassificationDetailScreen> createState() =>
      _CloudClassificationDetailScreenState();
}

class _CloudClassificationDetailScreenState
    extends ConsumerState<_CloudClassificationDetailScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    final vlm = ref.read(vlmSettingsProvider);
    _apiKeyController = TextEditingController(text: vlm.apiKey);
    _modelController = TextEditingController(text: vlm.model);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vlm = ref.watch(vlmSettingsProvider);
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsCloudClassification)),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 640 : double.infinity),
          child: ListView(
            padding: EdgeInsets.all(wide ? 24 : 16),
            children: [
              // --- Provider ---
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsProvider,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<VlmProvider>(
                        segments: [
                          ButtonSegment(
                            value: VlmProvider.gemini,
                            label: Text(l10n.settingsGemini),
                            icon: const Icon(Icons.auto_awesome),
                          ),
                          ButtonSegment(
                            value: VlmProvider.openai,
                            label: Text(l10n.settingsOpenai),
                            icon: const Icon(Icons.psychology),
                          ),
                        ],
                        selected: {vlm.provider},
                        onSelectionChanged: (selected) {
                          final provider = selected.first;
                          ref
                              .read(vlmSettingsProvider.notifier)
                              .setProvider(provider);
                          final defaultModel = provider == VlmProvider.gemini
                              ? 'gemini-2.0-flash'
                              : 'gpt-4o-mini';
                          _modelController.text = defaultModel;
                          ref
                              .read(vlmSettingsProvider.notifier)
                              .setModel(defaultModel);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // --- API Key & Model ---
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsAuth,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _apiKeyController,
                        obscureText: _obscureApiKey,
                        decoration: InputDecoration(
                          labelText: l10n.settingsApiKey,
                          hintText: vlm.provider == VlmProvider.gemini
                              ? 'AIza...'
                              : 'sk-...',
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _obscureApiKey
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(
                                  () => _obscureApiKey = !_obscureApiKey,
                                ),
                              ),
                              if (_apiKeyController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _apiKeyController.clear();
                                    ref
                                        .read(vlmSettingsProvider.notifier)
                                        .setApiKey('');
                                  },
                                ),
                            ],
                          ),
                        ),
                        onChanged: (value) => ref
                            .read(vlmSettingsProvider.notifier)
                            .setApiKey(value.trim()),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.settingsApiKeySecure,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _modelController,
                        decoration: InputDecoration(
                          labelText: l10n.settingsModelName,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) => ref
                            .read(vlmSettingsProvider.notifier)
                            .setModel(value.trim()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // --- Confidence Threshold ---
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsConfidenceThreshold,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.settingsConfidenceDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: vlm.confidenceThreshold,
                              min: 0.1,
                              max: 1.0,
                              divisions: 18,
                              label: vlm.confidenceThreshold.toStringAsFixed(2),
                              onChanged: (value) => ref
                                  .read(vlmSettingsProvider.notifier)
                                  .setConfidenceThreshold(
                                    double.parse(value.toStringAsFixed(2)),
                                  ),
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              vlm.confidenceThreshold.toStringAsFixed(2),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // --- Batch Controls ---
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsBatching,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.settingsBatchingDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _IntStepperTile(
                        label: l10n.settingsBatchSize,
                        value: vlm.batchSize,
                        min: 1,
                        max: 20,
                        onChanged: (v) => ref
                            .read(vlmSettingsProvider.notifier)
                            .setBatchSize(v),
                      ),
                      const Divider(height: 24),
                      _IntStepperTile(
                        label: l10n.settingsBatchTimeout,
                        value: vlm.batchTimeoutMs,
                        min: 500,
                        max: 10000,
                        step: 500,
                        suffix: 'ms',
                        onChanged: (v) => ref
                            .read(vlmSettingsProvider.notifier)
                            .setBatchTimeoutMs(v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // --- Advanced ---
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsAdvanced,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _IntStepperTile(
                        label: l10n.settingsRequestTimeout,
                        value: vlm.requestTimeoutMs,
                        min: 2000,
                        max: 30000,
                        step: 1000,
                        suffix: 'ms',
                        onChanged: (v) => ref
                            .read(vlmSettingsProvider.notifier)
                            .setRequestTimeoutMs(v),
                      ),
                      const Divider(height: 24),
                      _IntStepperTile(
                        label: l10n.settingsMaxRetries,
                        value: vlm.maxRetries,
                        min: 0,
                        max: 5,
                        onChanged: (v) => ref
                            .read(vlmSettingsProvider.notifier)
                            .setMaxRetries(v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // --- Reset ---
              OutlinedButton.icon(
                onPressed: () => _confirmReset(context, ref),
                icon: Icon(Icons.restore, color: theme.colorScheme.error),
                label: Text(
                  l10n.settingsResetDefaults,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).settingsResetConfirmTitle),
        content: Text(AppLocalizations.of(context).settingsResetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(vlmSettingsProvider.notifier).clearAll();
              const defaults = VlmSettings();
              _apiKeyController.text = defaults.apiKey;
              _modelController.text = defaults.model;
            },
            child: Text(AppLocalizations.of(context).settingsResetButton),
          ),
        ],
      ),
    );
  }
}

class _IntStepperTile extends StatelessWidget {
  const _IntStepperTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.suffix = '',
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = suffix.isEmpty ? '$value' : '$value $suffix';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              Text(
                displayValue,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton.outlined(
          icon: const Icon(Icons.remove, size: 18),
          onPressed: value > min ? () => onChanged(value - step) : null,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          icon: const Icon(Icons.add, size: 18),
          onPressed: value < max ? () => onChanged(value + step) : null,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
