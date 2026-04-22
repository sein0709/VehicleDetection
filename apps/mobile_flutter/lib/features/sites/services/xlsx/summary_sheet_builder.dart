import 'package:excel/excel.dart' as xl;

import '../../models/video_analysis_remote_result.dart';
import '../plate_repository.dart';
import 'sheet_builder.dart';

/// Single-glance summary: one row per metric. Always the first sheet so
/// stakeholders can answer "what did the analysis find?" without
/// hunting across tabs.
class SummarySheetBuilder extends XlsxSheetBuilder {
  SummarySheetBuilder({
    required this.result,
    required this.siteId,
    required this.analysisStartedAt,
    this.siteTotals,
  });

  final VideoAnalysisRemoteResult result;
  final String siteId;
  final DateTime? analysisStartedAt;
  final SitePlateTotals? siteTotals;

  @override
  String get sheetName => '요약';

  @override
  void build(xl.Sheet sheet) {
    appendRow(sheet, ['Site', siteId]);
    appendRow(sheet, [
      'Analysis started at',
      (analysisStartedAt ?? DateTime.now()).toIso8601String(),
    ]);
    appendRow(sheet, [null]);

    appendRow(sheet, ['Metric', 'Value', 'Notes']);
    appendRow(sheet, [
      'Total vehicles counted',
      result.totalVehiclesCounted,
      null,
    ]);
    appendRow(sheet, [
      'Pedestrians (보행자)',
      result.pedestriansCount,
      null,
    ]);

    final speed = result.speed;
    if (speed != null) {
      appendRow(sheet, [
        'Vehicles measured for speed',
        speed.vehiclesMeasured,
        speed.droppedTracks > 0
            ? 'Dropped (no exit-line crossing): ${speed.droppedTracks}'
            : null,
      ]);
      appendRow(sheet, [
        'Average speed (km/h)',
        speed.avgKmh ?? 0,
        speed.minKmh != null && speed.maxKmh != null
            ? 'min ${speed.minKmh} / max ${speed.maxKmh}'
            : null,
      ]);
    }

    final transit = result.transit;
    if (transit != null) {
      appendRow(sheet, [
        'Boarding (승차)',
        transit.boarding,
        'source=${transit.source}, arrivals=${transit.arrivals}',
      ]);
      appendRow(sheet, [
        'Alighting (하차)',
        transit.alighting,
        null,
      ]);
      appendRow(sheet, [
        'Peak headcount at stop',
        transit.peakCount,
        'Avg density ${transit.avgDensityPct.toStringAsFixed(1)}%',
      ]);
    }

    for (final light in result.trafficLights) {
      appendRow(sheet, [
        'Traffic light "${light.label}" — red cycles',
        light.red.cycles,
        'avg ${light.red.avgDurationS.toStringAsFixed(1)}s',
      ]);
      appendRow(sheet, [
        'Traffic light "${light.label}" — green cycles',
        light.green.cycles,
        'avg ${light.green.avgDurationS.toStringAsFixed(1)}s',
      ]);
      appendRow(sheet, [
        'Traffic light "${light.label}" — yellow cycles',
        light.yellow.cycles,
        'avg ${light.yellow.avgDurationS.toStringAsFixed(1)}s',
      ]);
    }

    final summary = result.plateSummary;
    if (summary != null) {
      appendRow(sheet, [
        'Plates — resident (this run)',
        summary.resident,
        summary.classificationPending
            ? 'Classification pending — site totals unavailable'
            : null,
      ]);
      appendRow(sheet, [
        'Plates — visitor (this run)',
        summary.visitor,
        null,
      ]);
      if (summary.unknown > 0) {
        appendRow(sheet, [
          'Plates — unclassified',
          summary.unknown,
          null,
        ]);
      }
    }
    if (siteTotals != null) {
      appendRow(sheet, [
        'Site total — resident (all-time)',
        siteTotals!.resident,
        null,
      ]);
      appendRow(sheet, [
        'Site total — visitor (all-time)',
        siteTotals!.visitor,
        null,
      ]);
    }
  }
}
