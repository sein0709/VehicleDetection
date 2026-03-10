import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:greyeye_mobile/features/sites/models/site_model.dart';
import 'package:greyeye_mobile/features/sites/providers/sites_provider.dart';
import 'package:greyeye_mobile/shared/widgets/empty_state.dart';
import 'package:greyeye_mobile/shared/widgets/error_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sitesAsync = ref.watch(sitesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.homeAddSite,
            onPressed: () => context.go('/home/sites/new'),
          ),
        ],
      ),
      body: sitesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: l10n.commonError,
          cause: e.toString(),
          onRetry: () => ref.invalidate(sitesProvider),
        ),
        data: (sites) {
          if (sites.isEmpty) {
            return EmptyState(
              icon: Icons.location_city_outlined,
              title: l10n.homeNoSites,
              actionLabel: l10n.homeAddSite,
              onAction: () => context.go('/home/sites/new'),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(sitesProvider.notifier).load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _KpiRow(sites: sites, l10n: l10n),
                const SizedBox(height: 16),
                Text(
                  l10n.homeSites,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...sites.map(
                  (site) => _SiteCard(site: site),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.sites, required this.l10n});

  final List<Site> sites;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalCameras =
        sites.fold(0, (sum, s) => sum + s.activeCameraCount);
    final totalVehicles =
        sites.fold(0, (sum, s) => sum + s.todayVehicleCount);

    return Row(
      children: [
        Expanded(
          child: _KpiTile(
            label: l10n.homeSites,
            value: '${sites.length}',
            icon: Icons.location_on,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiTile(
            label: l10n.homeActiveCameras,
            value: '$totalCameras',
            icon: Icons.videocam,
            color: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiTile(
            label: l10n.homeTotalVehicles,
            value: '$totalVehicles',
            icon: Icons.directions_car,
            color: theme.colorScheme.tertiary,
          ),
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteCard extends ConsumerWidget {
  const _SiteCard({required this.site});

  final Site site;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/home/sites/${site.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: site.isActive
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.location_on,
                  color: site.isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site.name,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (site.address != null)
                      Text(
                        site.address!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.siteCameraCount(site.cameraCount),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
