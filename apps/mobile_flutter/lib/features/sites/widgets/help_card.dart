import 'package:flutter/material.dart';

/// "이 설정은 무엇인가요?" expandable card used at the top of every
/// calibration editor.
///
/// Lives outside the editors themselves so each screen gets the same
/// layout, padding, and collapsed-by-default behaviour. When the operator
/// has never seen the screen before they can tap to expand and read the
/// plain-language explanation; on subsequent visits the card stays
/// collapsed and out of the way.
class HelpCard extends StatelessWidget {
  const HelpCard({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.help_outline,
    this.initiallyExpanded = false,
  });

  final String title;
  final String body;
  final IconData icon;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Theme(
        // Hide the default ExpansionTile divider lines; the card border
        // is enough visual separation.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          children: [
            Text(
              body,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
