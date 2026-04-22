import 'package:excel/excel.dart' as xl;

import '../../models/video_analysis_remote_result.dart';
import '../plate_repository.dart';
import 'sheet_builder.dart';

/// License plates (번호판). Per-plate row with track id, plate or hash,
/// dwell window, source (gemma / easyocr / both), and the recurrence-
/// based category. Site-wide totals row at the bottom mirrors the in-
/// app summary.
class PlatesSheetBuilder extends XlsxSheetBuilder {
  PlatesSheetBuilder({
    required this.result,
    this.siteTotals,
  });

  final VideoAnalysisRemoteResult result;
  final SitePlateTotals? siteTotals;

  @override
  String get sheetName => '번호판';

  @override
  void build(xl.Sheet sheet) {
    if (result.plates.isEmpty && result.plateSummary == null) {
      appendRow(sheet, ['LPR task was not enabled.']);
      return;
    }

    appendRow(sheet, [
      'Track ID',
      'Plate (or hash)',
      'Source',
      'First seen (s)',
      'Last seen (s)',
      'Dwell (s)',
      'Category',
    ]);
    for (final p in result.plates) {
      appendRow(sheet, [
        p.trackId,
        p.text ?? p.textHash ?? '',
        p.source ?? '',
        double.parse(p.firstSeenS.toStringAsFixed(2)),
        double.parse(p.lastSeenS.toStringAsFixed(2)),
        double.parse(p.dwellSeconds.toStringAsFixed(2)),
        p.category,
      ]);
    }
    appendRow(sheet, [null]);

    final summary = result.plateSummary;
    if (summary != null) {
      appendRow(sheet, ['This run']);
      appendRow(sheet, ['Resident', summary.resident]);
      appendRow(sheet, ['Visitor', summary.visitor]);
      appendRow(sheet, ['Unclassified', summary.unknown]);
      appendRow(sheet, ['Total plates', summary.total]);
      if (summary.privacyHashed) {
        appendRow(sheet, [
          'Note',
          'Privacy mode: plate text stored as SHA-256 prefix only.',
        ]);
      }
    }

    if (siteTotals != null) {
      appendRow(sheet, [null]);
      appendRow(sheet, ['This site (all-time)']);
      appendRow(sheet, ['Resident', siteTotals!.resident]);
      appendRow(sheet, ['Visitor', siteTotals!.visitor]);
    }
  }
}
