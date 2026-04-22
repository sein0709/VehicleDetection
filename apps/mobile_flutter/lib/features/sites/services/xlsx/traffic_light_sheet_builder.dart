import 'package:excel/excel.dart' as xl;

import '../../models/video_analysis_remote_result.dart';
import 'sheet_builder.dart';

/// Traffic light timing (신호등). One block per configured light, three
/// rows per block (red / green / yellow) with cycle counts and
/// avg/total durations.
class TrafficLightSheetBuilder extends XlsxSheetBuilder {
  TrafficLightSheetBuilder({required this.result});

  final VideoAnalysisRemoteResult result;

  @override
  String get sheetName => '신호등';

  @override
  void build(xl.Sheet sheet) {
    if (result.trafficLights.isEmpty) {
      appendRow(sheet, ['Traffic-light task was not enabled.']);
      return;
    }

    appendRow(sheet, [
      'Light label',
      'State',
      'Cycles',
      'Average duration (s)',
      'Total duration (s)',
    ]);
    for (final light in result.trafficLights) {
      _writeStateRow(sheet, light.label, 'red', light.red);
      _writeStateRow(sheet, light.label, 'green', light.green);
      _writeStateRow(sheet, light.label, 'yellow', light.yellow);
    }
  }

  void _writeStateRow(
    xl.Sheet sheet,
    String label,
    String state,
    VideoAnalysisTrafficLightCycle cycle,
  ) {
    appendRow(sheet, [
      label,
      state,
      cycle.cycles,
      double.parse(cycle.avgDurationS.toStringAsFixed(2)),
      double.parse(cycle.totalDurationS.toStringAsFixed(2)),
    ]);
  }
}
