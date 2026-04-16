import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:greyeye_mobile/core/theme/app_colors.dart';

/// Breakpoints for responsive layout.
const double _compactBreakpoint = 600;
const double _mediumBreakpoint = 840;
const double _expandedBreakpoint = 1200;

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/classify')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int i) {
    switch (i) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/classify');
      case 2:
        context.go('/settings');
    }
  }

  List<_NavItem> _navItems(AppLocalizations l10n) => [
        _NavItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: l10n.navHome,
        ),
        _NavItem(
          icon: Icons.document_scanner_outlined,
          selectedIcon: Icons.document_scanner,
          label: l10n.navClassify,
        ),
        _NavItem(
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          label: l10n.navSettings,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final index = _currentIndex(context);
    final items = _navItems(l10n);
    final width = MediaQuery.sizeOf(context).width;

    if (width >= _expandedBreakpoint) {
      return _ExpandedLayout(
        index: index,
        items: items,
        onSelected: (i) => _onDestinationSelected(context, i),
        child: child,
      );
    }

    if (width >= _compactBreakpoint) {
      return _MediumLayout(
        index: index,
        items: items,
        extended: width >= _mediumBreakpoint,
        onSelected: (i) => _onDestinationSelected(context, i),
        child: child,
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => _onDestinationSelected(context, i),
        destinations: items
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}

/// Desktop expanded layout: persistent sidebar with labels and branding.
class _ExpandedLayout extends StatelessWidget {
  const _ExpandedLayout({
    required this.index,
    required this.items,
    required this.onSelected,
    required this.child,
  });

  final int index;
  final List<_NavItem> items;
  final ValueChanged<int> onSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 256,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              border: Border(
                right: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.remove_red_eye,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'GreyEye',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < items.length; i++)
                  _SidebarTile(
                    item: items[i],
                    selected: i == index,
                    onTap: () => onSelected(i),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'v0.1.0',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected
            ? colorScheme.secondaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: selected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Text(
                  item.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Medium layout: NavigationRail (optionally extended).
class _MediumLayout extends StatelessWidget {
  const _MediumLayout({
    required this.index,
    required this.items,
    required this.extended,
    required this.onSelected,
    required this.child,
  });

  final int index;
  final List<_NavItem> items;
  final bool extended;
  final ValueChanged<int> onSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            extended: extended,
            onDestinationSelected: onSelected,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: Padding(
              padding: EdgeInsets.symmetric(
                vertical: 12,
                horizontal: extended ? 16 : 0,
              ),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.remove_red_eye,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            destinations: items
                .map((item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: Text(item.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
