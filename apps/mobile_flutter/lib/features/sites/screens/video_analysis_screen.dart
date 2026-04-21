import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:greyeye_mobile/core/theme/app_colors.dart';
import 'package:greyeye_mobile/features/sites/models/video_analysis_remote_result.dart';
import 'package:greyeye_mobile/features/sites/services/video_analysis_remote_service.dart';

class VideoAnalysisScreen extends ConsumerStatefulWidget {
  const VideoAnalysisScreen({super.key, required this.siteId});

  final String siteId;

  @override
  ConsumerState<VideoAnalysisScreen> createState() =>
      _VideoAnalysisScreenState();
}

enum _ScreenPhase { idle, uploading, processing, done, error }

class _VideoAnalysisScreenState extends ConsumerState<VideoAnalysisScreen> {
  String? _selectedVideoPath;
  _ScreenPhase _phase = _ScreenPhase.idle;
  String _errorMessage = '';
  VideoAnalysisRemoteResult? _result;
  DateTime? _analysisStartedAt;
  DateTime? _analysisCompletedAt;

  @override
  void dispose() {
    super.dispose();
  }

  static const _maxDuration = Duration(seconds: 300);

  Future<void> _pickFromGallery() => _pickVideo(ImageSource.gallery);
  Future<void> _recordFromCamera() => _pickVideo(ImageSource.camera);

  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: source,
      maxDuration: _maxDuration,
    );
    if (picked == null) return;

    final path = picked.path;
    setState(() {
      _selectedVideoPath = path;
      _phase = _ScreenPhase.uploading;
      _result = null;
      _errorMessage = '';
      _analysisStartedAt = DateTime.now();
      _analysisCompletedAt = null;
    });

    await _uploadAndPoll(path);
  }

  Future<void> _uploadAndPoll(String path) async {
    final service = ref.read(videoAnalysisRemoteServiceProvider);

    // Phase 1: Upload the video and get a job ID.
    final String jobId;
    try {
      jobId = await service.submitVideo(path);
    } on VideoAnalysisException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _ScreenPhase.error;
        _errorMessage = e.message;
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _ScreenPhase.error;
        _errorMessage = e.toString();
      });
      return;
    }

    if (!mounted) return;
    setState(() => _phase = _ScreenPhase.processing);

    // Phase 2: Poll until the server returns the final result.
    try {
      final result = await service.pollUntilComplete(jobId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _ScreenPhase.done;
        _analysisCompletedAt = DateTime.now();
      });
    } on VideoAnalysisException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _ScreenPhase.error;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _ScreenPhase.error;
        _errorMessage = e.toString();
      });
    }
  }

  void _retry() {
    if (_selectedVideoPath != null) {
      setState(() {
        _phase = _ScreenPhase.uploading;
        _errorMessage = '';
      });
      _uploadAndPoll(_selectedVideoPath!);
    }
  }

  Future<void> _exportXlsx() async {
    final result = _result;
    if (result == null) return;

    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['결과값'];
      excel.delete('Sheet1');

      _ResultsTemplateBuilder(
        sheet: sheet,
        siteId: widget.siteId,
        breakdown: result.breakdown,
        analysisStartedAt: _analysisStartedAt,
      ).build();

      final bytes = excel.encode();
      if (bytes == null) return;

      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir.path}/video_analysis_$timestamp.xlsx';
      await File(filePath).writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 완료: $filePath')),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.videoAnalysisTitle)),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PickerCard(
                  isUploading: _phase == _ScreenPhase.uploading ||
                      _phase == _ScreenPhase.processing,
                  onPickGallery: _pickFromGallery,
                  onRecordCamera: _recordFromCamera,
                ),
                if (_phase == _ScreenPhase.uploading) ...[
                  const SizedBox(height: 24),
                  _UploadingCard(theme: theme),
                ],
                if (_phase == _ScreenPhase.processing) ...[
                  const SizedBox(height: 24),
                  _ProcessingCard(theme: theme),
                ],
                if (_phase == _ScreenPhase.error) ...[
                  const SizedBox(height: 24),
                  _ErrorCard(
                    message: _errorMessage,
                    onRetry: _retry,
                    theme: theme,
                  ),
                ],
                if (_phase == _ScreenPhase.done && _result != null) ...[
                  const SizedBox(height: 24),
                  _TotalHero(
                    total: _result!.totalVehiclesCounted,
                    theme: theme,
                  ),
                  if (_result!.breakdown.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _BreakdownBarChart(
                      breakdown: _result!.breakdown,
                      theme: theme,
                    ),
                    const SizedBox(height: 16),
                    _BreakdownList(
                      breakdown: _result!.breakdown,
                      theme: theme,
                    ),
                  ],
                  if (_result!.twoWheelerBreakdown.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _TwoWheelerBreakdownList(
                      breakdown: _result!.twoWheelerBreakdown,
                      theme: theme,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _exportXlsx,
                    icon: const Icon(Icons.file_download),
                    label: Text(l10n.videoAnalysisExportCsv),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Picker card
// ---------------------------------------------------------------------------

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.isUploading,
    required this.onPickGallery,
    required this.onRecordCamera,
  });

  final bool isUploading;
  final VoidCallback onPickGallery;
  final VoidCallback onRecordCamera;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).videoAnalysisCloud,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).videoAnalysisDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isUploading ? null : onPickGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(AppLocalizations.of(context).videoAnalysisGallery),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isUploading ? null : onRecordCamera,
                    icon: const Icon(Icons.videocam_outlined),
                    label: Text(AppLocalizations.of(context).videoAnalysisRecord),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Uploading / processing indicator
// ---------------------------------------------------------------------------

class _UploadingCard extends StatelessWidget {
  const _UploadingCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).videoAnalysisUploading,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).videoAnalysisUploadingHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Server-side processing indicator (polling phase)
// ---------------------------------------------------------------------------

class _ProcessingCard extends StatelessWidget {
  const _ProcessingCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).videoAnalysisProcessing,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).videoAnalysisProcessingHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error card with retry
// ---------------------------------------------------------------------------

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
    required this.theme,
  });

  final String message;
  final VoidCallback onRetry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context).videoAnalysisRetry),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Total hero
// ---------------------------------------------------------------------------

class _TotalHero extends StatelessWidget {
  const _TotalHero({required this.total, required this.theme});

  final int total;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            Icon(
              Icons.directions_car,
              size: 36,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              '$total',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).videoAnalysisTotalCounted,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Horizontal bar chart (fl_chart)
// ---------------------------------------------------------------------------

const _chartPalette = AppColors.chartPalette;

class _BreakdownBarChart extends StatelessWidget {
  const _BreakdownBarChart({required this.breakdown, required this.theme});

  final List<VideoAnalysisBreakdownEntry> breakdown;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final maxCount = breakdown.fold<int>(
      0,
      (m, e) => e.count > m ? e.count : m,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).videoAnalysisBreakdown, style: theme.textTheme.titleSmall),
            const SizedBox(height: 20),
            ...List.generate(breakdown.length, (i) {
              final entry = breakdown[i];
              final fraction = maxCount > 0 ? entry.count / maxCount : 0.0;
              final color = _chartPalette[i % _chartPalette.length];

              return Padding(
                padding: EdgeInsets.only(
                  bottom: i < breakdown.length - 1 ? 12 : 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.label,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.count}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 14,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact breakdown list
// ---------------------------------------------------------------------------

class _BreakdownList extends StatelessWidget {
  const _BreakdownList({required this.breakdown, required this.theme});

  final List<VideoAnalysisBreakdownEntry> breakdown;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: List.generate(breakdown.length, (i) {
            final entry = breakdown[i];
            final color = _chartPalette[i % _chartPalette.length];
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 6,
                backgroundColor: color,
              ),
              title: Text(
                entry.label,
                style: theme.textTheme.bodyMedium,
              ),
              trailing: Text(
                '${entry.count}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2-wheeler breakdown list
// ---------------------------------------------------------------------------

class _TwoWheelerBreakdownList extends StatelessWidget {
  const _TwoWheelerBreakdownList({
    required this.breakdown,
    required this.theme,
  });

  final List<VideoAnalysisBreakdownEntry> breakdown;
  final ThemeData theme;

  IconData _iconFor(String label) {
    switch (label) {
      case 'Bicycle':
        return Icons.pedal_bike;
      case 'Motorcycle':
        return Icons.two_wheeler;
      case 'Personal Mobility':
        return Icons.electric_scooter;
      default:
        return Icons.directions_bike;
    }
  }

  String _koreanFor(String label) {
    switch (label) {
      case 'Bicycle':
        return '자전거';
      case 'Motorcycle':
        return '오토바이';
      case 'Personal Mobility':
        return 'PM / 킥보드';
      default:
        return label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = breakdown.fold<int>(0, (s, e) => s + e.count);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.two_wheeler, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '2륜차',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '$total',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...breakdown.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _iconFor(entry.label),
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _koreanFor(entry.label),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${entry.count}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// XLSX export — results template builder
// ---------------------------------------------------------------------------

/// 6종 + 이륜 categories used in the Korean traffic count results template.
enum _TemplateCategory {
  passenger,
  busSmall,
  busLarge,
  truckSmall,
  truckMid,
  truckTrailer,
  motorcycle,
}

double _pcuFactor(_TemplateCategory c) {
  switch (c) {
    case _TemplateCategory.passenger:
      return 1.0;
    case _TemplateCategory.busSmall:
      return 1.5;
    case _TemplateCategory.busLarge:
      return 2.0;
    case _TemplateCategory.truckSmall:
      return 1.0;
    case _TemplateCategory.truckMid:
      return 1.5;
    case _TemplateCategory.truckTrailer:
      return 2.5;
    case _TemplateCategory.motorcycle:
      return 0.5;
  }
}

/// Maps a server-provided breakdown label (e.g. `Class 1 (Passenger/Van)`,
/// `Motorcycle`) to a template category. Returns `null` if no rule matches.
_TemplateCategory? _categorize(String label) {
  final l = label.toLowerCase();

  if (l.contains('motorcycle') || l.contains('이륜')) {
    return _TemplateCategory.motorcycle;
  }
  if (l.contains('passenger') || l.startsWith('class 1')) {
    return _TemplateCategory.passenger;
  }
  if (l.contains('bus') || l.startsWith('class 2')) {
    return _TemplateCategory.busLarge;
  }
  if (l.contains('<2.5t') ||
      l.contains('< 2.5t') ||
      l.startsWith('class 3')) {
    return _TemplateCategory.truckSmall;
  }
  if (l.contains('>=2.5t') ||
      l.contains('>= 2.5t') ||
      l.contains('2.5-8.5t') ||
      l.startsWith('class 4')) {
    return _TemplateCategory.truckMid;
  }
  // Class 5..12 are multi-axle / trailer / semi categories.
  final m = RegExp(r'^class\s+(\d+)').firstMatch(l);
  if (m != null) {
    final n = int.tryParse(m.group(1)!);
    if (n != null && n >= 5) return _TemplateCategory.truckTrailer;
  }
  return null;
}

/// Rounds [t] down to the nearest 15-minute boundary.
DateTime _floorTo15Min(DateTime t) {
  final minute = (t.minute ~/ 15) * 15;
  return DateTime(t.year, t.month, t.day, t.hour, minute);
}

String _formatBucket(DateTime start) {
  final end = start.add(const Duration(minutes: 15));
  final fmt = DateFormat('HH:mm');
  return ' ${fmt.format(start)}-${fmt.format(end)}';
}

class _ResultsTemplateBuilder {
  _ResultsTemplateBuilder({
    required this.sheet,
    required this.siteId,
    required this.breakdown,
    required this.analysisStartedAt,
  });

  final xl.Sheet sheet;
  final String siteId;
  final List<VideoAnalysisBreakdownEntry> breakdown;
  final DateTime? analysisStartedAt;

  /// Number of direction blocks (only direction 1 carries data; 2-4 are zeros).
  static const int _directionCount = 4;

  /// Columns per direction block: 승용 | 버스 소형 | 버스 대형 | 화물 소형 |
  /// 화물 중.대 | 화물 트레일 | 소계 대 | 소계 PCU | 이륜
  static const int _colsPerDirection = 9;

  static const List<_TemplateCategory> _classCols = [
    _TemplateCategory.passenger,
    _TemplateCategory.busSmall,
    _TemplateCategory.busLarge,
    _TemplateCategory.truckSmall,
    _TemplateCategory.truckMid,
    _TemplateCategory.truckTrailer,
  ];

  void build() {
    final counts = _aggregateCounts();
    final bucketStart = _floorTo15Min(analysisStartedAt ?? DateTime.now());
    final hourStart = DateTime(
      bucketStart.year,
      bucketStart.month,
      bucketStart.day,
      bucketStart.hour,
    );

    _writeTitleRow();
    _writeDirectionMarkerRow();
    _writeCategoryHeaderRow();
    _writeSubcategoryHeaderRow();
    _writeHourBlock(hourStart, bucketStart, counts);
  }

  Map<_TemplateCategory, int> _aggregateCounts() {
    final out = <_TemplateCategory, int>{};
    for (final entry in breakdown) {
      final cat = _categorize(entry.label);
      if (cat == null) continue;
      out[cat] = (out[cat] ?? 0) + entry.count;
    }
    return out;
  }

  void _writeTitleRow() {
    final row = <xl.CellValue?>[xl.TextCellValue(siteId)];
    _padRow(row);
    sheet.appendRow(row);
  }

  void _writeDirectionMarkerRow() {
    final row = <xl.CellValue?>[null];
    for (var d = 1; d <= _directionCount; d++) {
      // Direction marker sits on the first count column of each block;
      // the time-bucket column (col 0) is shared, so each block starts at
      // 1 + (d-1) * _colsPerDirection.
      for (var c = 0; c < _colsPerDirection; c++) {
        if (c == 0) {
          row.add(xl.IntCellValue(d));
        } else {
          row.add(null);
        }
      }
    }
    sheet.appendRow(row);
  }

  void _writeCategoryHeaderRow() {
    final headers = <xl.CellValue?>[xl.TextCellValue('  시 간 대')];
    for (var d = 0; d < _directionCount; d++) {
      headers.addAll(const <xl.CellValue?>[]);
      headers.add(xl.TextCellValue('소형'));
      headers.add(xl.TextCellValue('버스'));
      headers.add(null); // 버스 대형 spans w/ 소형 visually; keep blank
      headers.add(xl.TextCellValue('화물'));
      headers.add(null); // 중.대
      headers.add(null); // 트레일
      headers.add(xl.TextCellValue('소  계'));
      headers.add(null); // PCU
      headers.add(xl.TextCellValue('이륜'));
    }
    sheet.appendRow(headers);
  }

  void _writeSubcategoryHeaderRow() {
    final row = <xl.CellValue?>[null];
    for (var d = 0; d < _directionCount; d++) {
      row.add(xl.TextCellValue('승용'));
      row.add(xl.TextCellValue('소형'));
      row.add(xl.TextCellValue('대형'));
      row.add(xl.TextCellValue('소형'));
      row.add(xl.TextCellValue('중.대'));
      row.add(xl.TextCellValue('트레일'));
      row.add(xl.TextCellValue('대'));
      row.add(xl.TextCellValue('PCU'));
      row.add(null);
    }
    sheet.appendRow(row);
  }

  /// Writes 4 bucket rows + 계(대) row + 보정교통량 row for one hour.
  void _writeHourBlock(
    DateTime hourStart,
    DateTime dataBucketStart,
    Map<_TemplateCategory, int> counts,
  ) {
    final bucketTotals = <int>[]; // total 대 per 15-min bucket (direction 1)

    for (var i = 0; i < 4; i++) {
      final bucket = hourStart.add(Duration(minutes: 15 * i));
      final isDataBucket = bucket == dataBucketStart;
      final bucketCounts = isDataBucket
          ? counts
          : const <_TemplateCategory, int>{};
      final row = _buildBucketRow(bucket, bucketCounts);
      sheet.appendRow(row);
      bucketTotals.add(_subtotalCount(bucketCounts));
    }

    // 계(대) row — summed across the four 15-min buckets.
    final summed = Map<_TemplateCategory, int>.from(counts);
    sheet.appendRow(_buildSumRow(summed));

    // 보정교통량 row — PHF = hour total / (4 * peak 15-min).
    final hourTotal = _subtotalCount(summed);
    final peakBucketTotal = bucketTotals.fold<int>(
      0,
      (m, v) => v > m ? v : m,
    );
    final phf = peakBucketTotal == 0
        ? 0.0
        : hourTotal / (4 * peakBucketTotal);
    final hourPcu = _subtotalPcu(summed);
    sheet.appendRow(_buildPhfRow(phf, hourTotal, hourPcu));
  }

  List<xl.CellValue?> _buildBucketRow(
    DateTime bucketStart,
    Map<_TemplateCategory, int> counts,
  ) {
    final row = <xl.CellValue?>[xl.TextCellValue(_formatBucket(bucketStart))];
    for (var d = 0; d < _directionCount; d++) {
      // Only direction 1 carries data; others are zeros.
      final blockCounts =
          d == 0 ? counts : const <_TemplateCategory, int>{};
      _appendDirectionBlock(row, blockCounts);
    }
    return row;
  }

  List<xl.CellValue?> _buildSumRow(Map<_TemplateCategory, int> counts) {
    final row = <xl.CellValue?>[xl.TextCellValue('    계(대)')];
    for (var d = 0; d < _directionCount; d++) {
      final blockCounts =
          d == 0 ? counts : const <_TemplateCategory, int>{};
      _appendDirectionBlock(row, blockCounts);
    }
    return row;
  }

  /// 보정교통량 row mimics the template: most cells empty, PHF=, then hour
  /// totals in the 소계 columns.
  List<xl.CellValue?> _buildPhfRow(double phf, int hourTotal, double hourPcu) {
    final row = <xl.CellValue?>[xl.TextCellValue(' 보정교통량')];
    for (var d = 0; d < _directionCount; d++) {
      // Direction 1 holds the PHF/totals; others stay blank.
      if (d == 0) {
        row.add(null); // 승용
        row.add(null); // 버스 소형
        row.add(null); // 버스 대형
        row.add(xl.TextCellValue(' PHF='));
        row.add(xl.DoubleCellValue(double.parse(phf.toStringAsFixed(2))));
        row.add(null); // 트레일
        row.add(xl.IntCellValue(hourTotal));
        row.add(xl.DoubleCellValue(double.parse(hourPcu.toStringAsFixed(1))));
        row.add(null); // 이륜
      } else {
        for (var c = 0; c < _colsPerDirection; c++) {
          row.add(null);
        }
      }
    }
    return row;
  }

  void _appendDirectionBlock(
    List<xl.CellValue?> row,
    Map<_TemplateCategory, int> counts,
  ) {
    for (final cat in _classCols) {
      row.add(xl.IntCellValue(counts[cat] ?? 0));
    }
    row.add(xl.IntCellValue(_subtotalCount(counts)));
    row.add(xl.DoubleCellValue(
      double.parse(_subtotalPcu(counts).toStringAsFixed(1)),
    ));
    row.add(xl.IntCellValue(counts[_TemplateCategory.motorcycle] ?? 0));
  }

  int _subtotalCount(Map<_TemplateCategory, int> counts) {
    var sum = 0;
    for (final cat in _TemplateCategory.values) {
      sum += counts[cat] ?? 0;
    }
    return sum;
  }

  double _subtotalPcu(Map<_TemplateCategory, int> counts) {
    var sum = 0.0;
    for (final cat in _TemplateCategory.values) {
      sum += (counts[cat] ?? 0) * _pcuFactor(cat);
    }
    return sum;
  }

  /// Pads a row with `null` cells so the title row spans the full sheet width.
  void _padRow(List<xl.CellValue?> row) {
    final totalCols = 1 + _directionCount * _colsPerDirection;
    while (row.length < totalCols) {
      row.add(null);
    }
  }
}
