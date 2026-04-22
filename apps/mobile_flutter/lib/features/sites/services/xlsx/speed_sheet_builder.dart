import 'package:excel/excel.dart' as xl;

import '../../models/video_analysis_remote_result.dart';
import 'sheet_builder.dart';

/// Speed analytics (속도). Header summary at the top, then one row per
/// measured track sorted by km/h descending so the fastest vehicles
/// surface first — matches the typical speed-enforcement workflow.
class SpeedSheetBuilder extends XlsxSheetBuilder {
  SpeedSheetBuilder({required this.result});

  final VideoAnalysisRemoteResult result;

  @override
  String get sheetName => '속도';

  @override
  void build(xl.Sheet sheet) {
    final speed = result.speed;
    if (speed == null) {
      appendRow(sheet, ['Speed task was not enabled for this analysis.']);
      return;
    }

    appendRow(sheet, ['Vehicles measured', speed.vehiclesMeasured]);
    appendRow(sheet, ['Average km/h', speed.avgKmh ?? 0]);
    appendRow(sheet, ['Min km/h', speed.minKmh ?? 0]);
    appendRow(sheet, ['Max km/h', speed.maxKmh ?? 0]);
    appendRow(sheet, [
      'Tracks dropped (no exit-line crossing)',
      speed.droppedTracks,
    ]);
    appendRow(sheet, [null]);

    appendRow(sheet, ['Track ID', 'Speed (km/h)']);
    final entries = speed.perTrack.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in entries) {
      appendRow(sheet, [e.key, e.value]);
    }
  }
}
