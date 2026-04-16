import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/bootstrap/demo_workspace_service.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:greyeye_mobile/core/constants/vehicle_classes.dart';
import 'package:greyeye_mobile/features/analytics/models/analytics_model.dart';
import 'package:greyeye_mobile/features/analytics/providers/analytics_provider.dart';
import 'package:greyeye_mobile/shared/widgets/error_view.dart';

class AnalyticsDashboardScreen extends ConsumerStatefulWidget {
  const AnalyticsDashboardScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  ConsumerState<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState
    extends ConsumerState<AnalyticsDashboardScreen> {
  late DateTime _start;
  late DateTime _end;
  String _selectedRange = 'today';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day);
    _end = now;
  }

  void _setRange(String range) {
    final now = DateTime.now();
    setState(() {
      _selectedRange = range;
      switch (range) {
        case 'today':
          _start = DateTime(now.year, now.month, now.day);
          _end = now;
        case 'week':
          _start = now.subtract(const Duration(days: 7));
          _end = now;
        case 'month':
          _start = DateTime(now.year, now.month - 1, now.day);
          _end = now;
      }
    });
  }

  Future<void> _loadDemoData(WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final service = ref.read(demoWorkspaceServiceProvider);
      final summary = await service.seedDemoWorkspace();
      ref.invalidate(analyticsProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            summary.created
                ? l10n.analyticsDemoDataLoaded
                : l10n.analyticsDataAlreadyPresent,
          ),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _start, end: _end),
    );
    if (picked != null) {
      setState(() {
        _selectedRange = 'custom';
        _start = picked.start;
        _end = picked.end.add(const Duration(days: 1));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final params = AnalyticsParams(
      cameraId: widget.cameraId,
      start: _start,
      end: _end,
    );
    final analyticsAsync = ref.watch(analyticsProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.analyticsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.science_outlined),
            tooltip: l10n.analyticsLoadDemoData,
            onPressed: () => _loadDemoData(ref),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () =>
                context.push('/cameras/${widget.cameraId}/export'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 24 : 16,
              vertical: 8,
            ),
            child: Row(
              children: [
                _RangeChip(
                  label: l10n.analyticsToday,
                  selected: _selectedRange == 'today',
                  onTap: () => _setRange('today'),
                ),
                const SizedBox(width: 8),
                _RangeChip(
                  label: l10n.analyticsWeek,
                  selected: _selectedRange == 'week',
                  onTap: () => _setRange('week'),
                ),
                const SizedBox(width: 8),
                _RangeChip(
                  label: l10n.analyticsMonth,
                  selected: _selectedRange == 'month',
                  onTap: () => _setRange('month'),
                ),
                const SizedBox(width: 8),
                _RangeChip(
                  label: l10n.analyticsCustom,
                  selected: _selectedRange == 'custom',
                  onTap: _pickCustomRange,
                ),
              ],
            ),
          ),
          Expanded(
            child: analyticsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: l10n.commonError,
                onRetry: () => ref.invalidate(analyticsProvider(params)),
              ),
              data: (data) => wide
                  ? _DesktopAnalyticsContent(
                      data: data, theme: theme, l10n: l10n)
                  : _AnalyticsContent(
                      data: data, theme: theme, l10n: l10n),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _AnalyticsContent extends StatelessWidget {
  const _AnalyticsContent({
    required this.data,
    required this.theme,
    required this.l10n,
  });

  final AnalyticsResponse data;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final classDist = data.aggregatedByClass;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                label: l10n.homeTotalVehicles,
                value: '${data.totalVehicles}',
                icon: Icons.directions_car,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiTile(
                label: l10n.analyticsBuckets,
                value: '${data.buckets.length}',
                icon: Icons.access_time,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.analyticsVolumeChart,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: data.buckets.isEmpty
                      ? Center(child: Text(l10n.commonNoData))
                      : _VolumeBarChart(buckets: data.buckets),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.analyticsClassChart,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: classDist.isEmpty
                      ? Center(child: Text(l10n.commonNoData))
                      : _ClassPieChart(distribution: classDist),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: classDist.entries.map((e) {
                    final vc = VehicleClass.fromCode(e.key);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: vc?.color ?? Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${vc?.labelKo ?? "C${e.key}"}: ${e.value}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _VolumeBarChart extends StatelessWidget {
  const _VolumeBarChart({required this.buckets});

  final List<BucketData> buckets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = buckets.fold<int>(0, (m, b) => b.totalCount > m ? b.totalCount : m).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final bucket = buckets[groupIndex];
              final time =
                  '${bucket.bucketStart.hour}:${bucket.bucketStart.minute.toString().padLeft(2, '0')}';
              return BarTooltipItem(
                '$time\n${bucket.totalCount}',
                TextStyle(
                  color: theme.colorScheme.onInverseSurface,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < buckets.length && idx % 4 == 0) {
                  final b = buckets[idx];
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${b.bucketStart.hour}:${b.bucketStart.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: List.generate(
          buckets.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: buckets[i].totalCount.toDouble(),
                color: theme.colorScheme.primary,
                width: buckets.length > 20 ? 4 : 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassPieChart extends StatelessWidget {
  const _ClassPieChart({required this.distribution});

  final Map<int, int> distribution;

  @override
  Widget build(BuildContext context) {
    final total = distribution.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: distribution.entries.map((e) {
          final vc = VehicleClass.fromCode(e.key);
          final pct = (e.value / total * 100).toStringAsFixed(1);
          return PieChartSectionData(
            value: e.value.toDouble(),
            color: vc?.color ?? Colors.grey,
            title: '$pct%',
            titleStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            radius: 50,
          );
        }).toList(),
      ),
    );
  }
}

/// Desktop layout: KPIs across the top, charts side-by-side.
class _DesktopAnalyticsContent extends StatelessWidget {
  const _DesktopAnalyticsContent({
    required this.data,
    required this.theme,
    required this.l10n,
  });

  final AnalyticsResponse data;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final classDist = data.aggregatedByClass;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                label: l10n.homeTotalVehicles,
                value: '${data.totalVehicles}',
                icon: Icons.directions_car,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiTile(
                label: l10n.analyticsBuckets,
                value: '${data.buckets.length}',
                icon: Icons.access_time,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiTile(
                label: l10n.analyticsClasses,
                value: '${classDist.length}',
                icon: Icons.category,
                color: theme.colorScheme.tertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.analyticsVolumeChart,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 280,
                          child: data.buckets.isEmpty
                              ? Center(child: Text(l10n.commonNoData))
                              : _VolumeBarChart(buckets: data.buckets),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.analyticsClassChart,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: classDist.isEmpty
                              ? Center(child: Text(l10n.commonNoData))
                              : _ClassPieChart(distribution: classDist),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: classDist.entries.map((e) {
                            final vc = VehicleClass.fromCode(e.key);
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: vc?.color ?? Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${vc?.labelKo ?? "C${e.key}"}: ${e.value}',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
