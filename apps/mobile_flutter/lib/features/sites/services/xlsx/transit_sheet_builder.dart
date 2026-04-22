import 'package:excel/excel.dart' as xl;

import '../../models/video_analysis_remote_result.dart';
import 'sheet_builder.dart';

/// Public transit (대중교통). Aggregate boarding/alighting + density at
/// the top, then a row per arrival event so the operator can see the
/// per-arrival breakdown the VLM produced.
class TransitSheetBuilder extends XlsxSheetBuilder {
  TransitSheetBuilder({required this.result});

  final VideoAnalysisRemoteResult result;

  @override
  String get sheetName => '대중교통';

  @override
  void build(xl.Sheet sheet) {
    final transit = result.transit;
    if (transit == null) {
      appendRow(sheet, ['Transit task was not enabled for this analysis.']);
      return;
    }

    appendRow(sheet, ['Boarding (승차)', transit.boarding]);
    appendRow(sheet, ['Alighting (하차)', transit.alighting]);
    appendRow(sheet, ['Bus arrivals observed', transit.arrivals]);
    appendRow(sheet, [
      'Boarding/alighting source',
      transit.source,
      transit.source == 'linezone_fallback'
          ? 'VLM unavailable — door-line totals shown (less accurate)'
          : null,
    ]);
    appendRow(sheet, ['Peak headcount at stop', transit.peakCount]);
    appendRow(sheet, [
      'Average density',
      '${transit.avgDensityPct.toStringAsFixed(1)}%',
    ]);
    appendRow(sheet, [
      'Bus-presence gating',
      transit.busGated ? 'enabled' : 'disabled',
    ]);
  }
}
