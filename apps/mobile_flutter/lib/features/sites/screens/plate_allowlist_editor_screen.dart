import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:greyeye_mobile/features/sites/services/plate_normalizer.dart';
import 'package:greyeye_mobile/features/sites/widgets/help_card.dart';

/// Result of the allowlist editor: the canonical plate strings to send
/// in `calibration.lpr.allowlist`. Empty list = no allowlist (every
/// detected plate becomes a "visitor").
typedef PlateAllowlist = List<String>;

/// CRUD screen for the resident plate allowlist (F5 — 주거시설 상주/방문).
///
/// Currently stores in-memory only — persisted state will land when
/// the Supabase `residential_plates` table is wired in (see
/// `docs/09-features-roadmap-geonhwa.md` F5). Until then the operator
/// re-enters the list per session, which is OK for the demo flow but
/// not for a production deploy.
class PlateAllowlistEditorScreen extends StatefulWidget {
  const PlateAllowlistEditorScreen({super.key, this.initial = const []});

  final PlateAllowlist initial;

  @override
  State<PlateAllowlistEditorScreen> createState() =>
      _PlateAllowlistEditorScreenState();
}

class _PlateAllowlistEditorScreenState
    extends State<PlateAllowlistEditorScreen> {
  late final TextEditingController _addCtrl;
  late final List<String> _plates;
  String _addError = '';

  @override
  void initState() {
    super.initState();
    _addCtrl = TextEditingController();
    _plates = [...widget.initial];
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  void _addCurrent() {
    final raw = _addCtrl.text;
    final normalized = PlateNormalizer.normalize(raw);
    final l10n = AppLocalizations.of(context);
    if (normalized == null) {
      setState(() => _addError = l10n.lprAllowlistInvalid);
      return;
    }
    if (_plates.contains(normalized)) {
      setState(() => _addError = l10n.lprAllowlistDuplicate);
      return;
    }
    setState(() {
      _plates.add(normalized);
      _addCtrl.clear();
      _addError = '';
    });
  }

  void _remove(int index) {
    setState(() => _plates.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.lprAllowlistTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_plates),
            child: Text(l10n.roiEditorSave),
          ),
        ],
      ),
      body: Column(
        children: [
          HelpCard(
            title: l10n.lprWhatIsThisTitle,
            body: l10n.lprWhatIsThisBody,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.lprAllowlistHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.lprAllowlistAddHint,
                          border: const OutlineInputBorder(),
                          isDense: true,
                          errorText: _addError.isEmpty ? null : _addError,
                        ),
                        onSubmitted: (_) => _addCurrent(),
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _addCurrent,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.lprAllowlistAdd),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.lprAllowlistCount(_plates.length),
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _plates.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.lprAllowlistEmpty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _plates.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      return ListTile(
                        leading: const Icon(Icons.no_crash),
                        title: Text(_plates[i]),
                        trailing: IconButton(
                          tooltip: l10n.lprAllowlistRemove,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _remove(i),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
