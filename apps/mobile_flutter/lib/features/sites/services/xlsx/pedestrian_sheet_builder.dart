import 'package:excel/excel.dart' as xl;

import '../../models/video_analysis_remote_result.dart';
import 'sheet_builder.dart';

/// Pedestrian counts (보행자). Trivial today — one row, one number — but
/// the dedicated sheet keeps the workbook layout symmetric and gives us
/// somewhere to land per-15-min ROI counts in a future iteration.
class PedestrianSheetBuilder extends XlsxSheetBuilder {
  PedestrianSheetBuilder({required this.result});

  final VideoAnalysisRemoteResult result;

  @override
  String get sheetName => '보행자';

  @override
  void build(xl.Sheet sheet) {
    appendRow(sheet, ['Metric', 'Value']);
    appendRow(sheet, ['Pedestrian count', result.pedestriansCount]);
  }
}
