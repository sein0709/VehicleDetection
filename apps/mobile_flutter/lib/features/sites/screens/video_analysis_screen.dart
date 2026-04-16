import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:greyeye_mobile/core/constants/vehicle_classes.dart';
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
      final detectedCounts = <String, int>{
        for (final e in result.breakdown) e.label: e.count,
      };
      final timeFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

      final excel = xl.Excel.createExcel();
      final sheet = excel['Analysis'];
      excel.delete('Sheet1');

      sheet.appendRow([
        xl.TextCellValue('Analysis Start'),
        xl.TextCellValue(
          _analysisStartedAt != null
              ? timeFmt.format(_analysisStartedAt!)
              : '',
        ),
      ]);
      sheet.appendRow([
        xl.TextCellValue('Analysis End'),
        xl.TextCellValue(
          _analysisCompletedAt != null
              ? timeFmt.format(_analysisCompletedAt!)
              : '',
        ),
      ]);
      sheet.appendRow([xl.TextCellValue(''), xl.TextCellValue('')]);

      sheet.appendRow([
        xl.TextCellValue('class_name'),
        xl.TextCellValue('count'),
      ]);

      for (final vc in VehicleClass.values) {
        final count = detectedCounts[vc.labelEn] ?? 0;
        sheet.appendRow([
          xl.TextCellValue(vc.labelEn),
          xl.IntCellValue(count),
        ]);
      }

      sheet.appendRow([
        xl.TextCellValue('TOTAL'),
        xl.IntCellValue(result.totalVehiclesCounted),
      ]);

      final bytes = excel.encode();
      if (bytes == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir.path}/video_analysis_$timestamp.xlsx';
      await File(filePath).writeAsBytes(bytes);

      await Share.shareXFiles([XFile(filePath)]);
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
