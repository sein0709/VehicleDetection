import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/constants/vehicle_classes.dart';
import 'package:greyeye_mobile/core/database/database.dart';
import 'package:greyeye_mobile/core/database/database_provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class ReportExportScreen extends ConsumerStatefulWidget {
  const ReportExportScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  ConsumerState<ReportExportScreen> createState() =>
      _ReportExportScreenState();
}

class _ReportExportScreenState extends ConsumerState<ReportExportScreen> {
  String _format = 'csv';
  DateTimeRange? _range;
  bool _isExporting = false;

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _export() async {
    if (_range == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).exportSelectRange)),
      );
      return;
    }
    setState(() => _isExporting = true);
    try {
      final dao = ref.read(crossingsDaoProvider);
      final crossings = await dao.crossingsForCamera(
        widget.cameraId,
        after: _range!.start.toUtc(),
        before: _range!.end.add(const Duration(days: 1)).toUtc(),
      );

      final dir = await getApplicationDocumentsDirectory();
      final dateFmt = DateFormat('yyyyMMdd_HHmmss');
      final timestamp = dateFmt.format(DateTime.now());

      String filePath;

      if (_format == 'csv') {
        final rows = <List<dynamic>>[
          [
            'timestamp_utc',
            'camera_id',
            'line_id',
            'track_id',
            'crossing_seq',
            'class_code',
            'class_name',
            'confidence',
            'direction',
            'speed_kmh',
          ],
          ...crossings.map((c) {
            final vc = VehicleClass.fromCode(c.class12);
            return [
              c.timestampUtc.toIso8601String(),
              c.cameraId,
              c.lineId,
              c.trackId,
              c.crossingSeq,
              c.class12,
              vc?.labelKo ?? 'C${c.class12}',
              c.confidence.toStringAsFixed(3),
              c.direction,
              c.speedEstimateKmh?.toStringAsFixed(1) ?? '',
            ];
          }),
        ];
        final csvString = const ListToCsvConverter().convert(rows);
        filePath = '${dir.path}/greyeye_export_$timestamp.csv';
        await File(filePath).writeAsString(csvString);
      } else if (_format == 'json') {
        final jsonRows = crossings.map((c) {
          final vc = VehicleClass.fromCode(c.class12);
          return {
            'timestamp_utc': c.timestampUtc.toIso8601String(),
            'camera_id': c.cameraId,
            'line_id': c.lineId,
            'track_id': c.trackId,
            'crossing_seq': c.crossingSeq,
            'class12': c.class12,
            'class_name': vc?.labelKo ?? 'C${c.class12}',
            'confidence': c.confidence,
            'direction': c.direction,
            'speed_estimate_kmh': c.speedEstimateKmh,
          };
        }).toList();
        final jsonString =
            const JsonEncoder.withIndent('  ').convert(jsonRows);
        filePath = '${dir.path}/greyeye_export_$timestamp.json';
        await File(filePath).writeAsString(jsonString);
      } else {
        filePath = '${dir.path}/greyeye_export_$timestamp.pdf';
        await _generatePdf(filePath, crossings);
      }

      await Share.shareXFiles([XFile(filePath)]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).exportExported(crossings.length)),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _generatePdf(
    String filePath,
    List<VehicleCrossing> crossings,
  ) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    final classCounts = <int, int>{};
    final dirCounts = <String, int>{};
    for (final c in crossings) {
      classCounts[c.class12] = (classCounts[c.class12] ?? 0) + 1;
      dirCounts[c.direction] = (dirCounts[c.direction] ?? 0) + 1;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'GreyEye 교통 보고서',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Paragraph(
            text:
                '카메라: ${widget.cameraId}\n'
                '기간: ${_range != null ? "${dateFmt.format(_range!.start)} - ${dateFmt.format(_range!.end)}" : "해당 없음"}\n'
                '총 통과 건수: ${crossings.length}',
          ),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: '차종별'),
          pw.TableHelper.fromTextArray(
            headers: ['차종', '건수'],
            data: classCounts.entries.map((e) {
              final vc = VehicleClass.fromCode(e.key);
              return [vc?.labelKo ?? 'C${e.key}', '${e.value}'];
            }).toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: '방향별'),
          pw.TableHelper.fromTextArray(
            headers: ['방향', '건수'],
            data: dirCounts.entries
                .map((e) => [e.key, '${e.value}'])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: '원시 통과 데이터 (처음 200건)'),
          pw.TableHelper.fromTextArray(
            headers: ['시간', '차종', '방향', '신뢰도'],
            data: crossings.take(200).map((c) {
              final vc = VehicleClass.fromCode(c.class12);
              return [
                dateFmt.format(c.timestampUtc),
                vc?.labelKo ?? 'C${c.class12}',
                c.direction,
                c.confidence.toStringAsFixed(2),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final wide = MediaQuery.sizeOf(context).width >= 840;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.analyticsExport)),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 640 : double.infinity),
          child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.analyticsTimeRange,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _range != null
                          ? '${_range!.start.toString().substring(0, 10)} — ${_range!.end.toString().substring(0, 10)}'
                          : l10n.exportSelectDateRange,
                    ),
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
                    l10n.exportFormat,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'csv', label: Text('CSV')),
                      ButtonSegment(value: 'json', label: Text('JSON')),
                      ButtonSegment(value: 'pdf', label: Text('PDF')),
                    ],
                    selected: {_format},
                    onSelectionChanged: (s) =>
                        setState(() => _format = s.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _isExporting ? null : _export,
            icon: _isExporting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download),
            label: Text(l10n.analyticsExport),
          ),
        ],
      ),
        ),
      ),
    );
  }
}
