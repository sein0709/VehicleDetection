import 'package:excel/excel.dart' as xl;

import '../../models/video_analysis_remote_result.dart';
import '../plate_repository.dart';
import 'pedestrian_sheet_builder.dart';
import 'plates_sheet_builder.dart';
import 'sheet_builder.dart';
import 'speed_sheet_builder.dart';
import 'summary_sheet_builder.dart';
import 'traffic_light_sheet_builder.dart';
import 'transit_sheet_builder.dart';

/// Orchestrates the multi-sheet xlsx export. Builds:
///
/// 1. 요약 — single-glance summary across every feature
/// 2. 보행자 — pedestrian count
/// 3. 속도 — speed analytics + per-track table
/// 4. 대중교통 — boarding/alighting + density
/// 5. 신호등 — per-light cycle stats
/// 6. 번호판 — per-plate rows + recurrence-based totals
///
/// The historic Korean traffic-count template (`결과값`) is appended at
/// the end by the caller so this class doesn't depend on the existing
/// `_ResultsTemplateBuilder` (which lives in the screen file and uses a
/// private enum).
class ResultsWorkbook {
  ResultsWorkbook({
    required this.result,
    required this.siteId,
    this.analysisStartedAt,
    this.siteTotals,
  });

  final VideoAnalysisRemoteResult result;
  final String siteId;
  final DateTime? analysisStartedAt;
  final SitePlateTotals? siteTotals;

  /// Build the workbook. The caller is responsible for serializing it
  /// (typically via `excel.encode()`) and writing the bytes to disk.
  ///
  /// Pre-existing sheets in [excel] (e.g. the legacy 결과값 template)
  /// are kept as-is; this method only appends new sheets.
  void appendTo(xl.Excel excel) {
    final builders = <XlsxSheetBuilder>[
      SummarySheetBuilder(
        result: result,
        siteId: siteId,
        analysisStartedAt: analysisStartedAt,
        siteTotals: siteTotals,
      ),
      PedestrianSheetBuilder(result: result),
      SpeedSheetBuilder(result: result),
      TransitSheetBuilder(result: result),
      TrafficLightSheetBuilder(result: result),
      PlatesSheetBuilder(result: result, siteTotals: siteTotals),
    ];

    for (final builder in builders) {
      final sheet = excel[builder.sheetName];
      builder.build(sheet);
    }
  }
}
