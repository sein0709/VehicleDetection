import 'package:excel/excel.dart' as xl;

/// One builder per feature sheet. Each implementation owns its sheet's
/// layout (header rows + data rows). Builders are stateless aside from
/// the data they hold, so the orchestrator can run them in any order.
abstract class XlsxSheetBuilder {
  /// Localized sheet name (Korean by default — matches the existing
  /// `결과값` template convention).
  String get sheetName;

  /// Append rows into [sheet]. The orchestrator already created the
  /// sheet with [sheetName] before calling this.
  void build(xl.Sheet sheet);

  /// Convenience: append one row of mixed string/numeric/null cells.
  void appendRow(xl.Sheet sheet, List<dynamic> cells) {
    sheet.appendRow([for (final v in cells) toCell(v)]);
  }

  /// Coerce a Dart value into an `xl.CellValue?` so callers can pass
  /// `String`, `int`, `double`, `bool`, or `null` without ceremony.
  xl.CellValue? toCell(dynamic value) {
    if (value == null) return null;
    if (value is xl.CellValue) return value;
    if (value is String) return xl.TextCellValue(value);
    if (value is int) return xl.IntCellValue(value);
    if (value is double) return xl.DoubleCellValue(value);
    if (value is bool) return xl.TextCellValue(value ? 'YES' : 'NO');
    return xl.TextCellValue(value.toString());
  }
}
