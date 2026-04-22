import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:greyeye_mobile/core/theme/app_colors.dart';
import 'package:greyeye_mobile/features/sites/services/roi_normalizer.dart';
import 'package:greyeye_mobile/features/sites/widgets/calibration_canvas.dart';
import 'package:greyeye_mobile/features/sites/widgets/help_card.dart';

/// Editor result for F6 (대중교통 승하차 + 밀집도). All polygon /
/// line coordinates are normalized image-space ratios in [0..1].
class TransitConfig {
  const TransitConfig({
    required this.stopPolygon,
    required this.doorLine,
    required this.maxCapacity,
    this.busZonePolygon,
  });

  /// 3+ vertices outlining the stop area. Density % = persons inside /
  /// [maxCapacity] × 100.
  final List<Offset> stopPolygon;

  /// 2 endpoints of the boarding/alighting door line. Crossing IN
  /// counts as boarding, OUT as alighting (signs flipped by
  /// supervision based on which side of the line a track started).
  final List<Offset> doorLine;

  /// Optional polygon limiting the door-line trigger to "while a bus
  /// is parked here". When null, every door-line crossing counts —
  /// inflates totals between bus arrivals.
  final List<Offset>? busZonePolygon;

  final int maxCapacity;
}

class TransitConfigEditorScreen extends StatefulWidget {
  const TransitConfigEditorScreen({
    super.key,
    required this.videoPath,
    this.initial,
  });

  final String videoPath;
  final TransitConfig? initial;

  @override
  State<TransitConfigEditorScreen> createState() =>
      _TransitConfigEditorScreenState();
}

enum _TransitTapMode { stopPolygon, doorLine, busZone }

class _TransitConfigEditorScreenState
    extends State<TransitConfigEditorScreen> {
  late final TextEditingController _capacityCtrl;

  final List<Offset> _stopPolygon = [];
  final List<Offset> _doorLine = [];
  final List<Offset> _busZone = [];
  bool _busZoneEnabled = false;

  _TransitTapMode _mode = _TransitTapMode.stopPolygon;

  // Lets the AppBar "pick backdrop" action drive the canvas's
  // private file-picker without duplicating the picker logic here.
  final GlobalKey<CalibrationCanvasState> _canvasKey =
      GlobalKey<CalibrationCanvasState>();

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _capacityCtrl =
        TextEditingController(text: (init?.maxCapacity ?? 30).toString());
    if (init != null) {
      _stopPolygon.addAll(init.stopPolygon);
      _doorLine.addAll(init.doorLine);
      if (init.busZonePolygon != null) {
        _busZone.addAll(init.busZonePolygon!);
        _busZoneEnabled = true;
      }
    }
  }

  @override
  void dispose() {
    _capacityCtrl.dispose();
    super.dispose();
  }

  void _handleTap(Offset ratio) {
    setState(() {
      switch (_mode) {
        case _TransitTapMode.stopPolygon:
          _stopPolygon.add(ratio);
        case _TransitTapMode.doorLine:
          if (_doorLine.length >= 2) {
            _doorLine
              ..clear()
              ..add(ratio);
          } else {
            _doorLine.add(ratio);
          }
        case _TransitTapMode.busZone:
          if (!_busZoneEnabled) return;
          _busZone.add(ratio);
      }
    });
  }

  void _undo() {
    setState(() {
      switch (_mode) {
        case _TransitTapMode.stopPolygon:
          if (_stopPolygon.isNotEmpty) _stopPolygon.removeLast();
        case _TransitTapMode.doorLine:
          if (_doorLine.isNotEmpty) _doorLine.removeLast();
        case _TransitTapMode.busZone:
          if (_busZone.isNotEmpty) _busZone.removeLast();
      }
    });
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    if (_stopPolygon.length < 3) {
      _toast(l10n.transitEditorStopPolygonTooSmall);
      return;
    }
    if (_doorLine.length != 2) {
      _toast(l10n.transitEditorDoorLineIncomplete);
      return;
    }
    if (_busZoneEnabled && _busZone.length < 3) {
      _toast(l10n.transitEditorBusZoneTooSmall);
      return;
    }
    final capacity = int.tryParse(_capacityCtrl.text);
    if (capacity == null || capacity <= 0) {
      _toast(l10n.transitEditorBadCapacity);
      return;
    }
    Navigator.of(context).pop(TransitConfig(
      stopPolygon: List.of(_stopPolygon),
      doorLine: List.of(_doorLine),
      busZonePolygon:
          _busZoneEnabled && _busZone.length >= 3 ? List.of(_busZone) : null,
      maxCapacity: capacity,
    ),);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canSave =
        _stopPolygon.length >= 3 && _doorLine.length == 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.transitEditorTitle),
        actions: [
          IconButton(
            tooltip: l10n.roiEditorPickBackdrop,
            icon: const Icon(Icons.folder_open),
            onPressed: () => _canvasKey.currentState?.pickBackdrop(),
          ),
          IconButton(
            tooltip: l10n.transitEditorUndo,
            icon: const Icon(Icons.undo),
            onPressed: _undo,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            HelpCard(
              title: l10n.transitWhatIsThisTitle,
              body: l10n.transitWhatIsThisBody,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8,
              ),
              child: SegmentedButton<_TransitTapMode>(
                segments: [
                  ButtonSegment(
                    value: _TransitTapMode.stopPolygon,
                    label: Text(l10n.transitEditorModeStopPolygon),
                    icon: const Icon(Icons.crop_free),
                  ),
                  ButtonSegment(
                    value: _TransitTapMode.doorLine,
                    label: Text(l10n.transitEditorModeDoorLine),
                    icon: const Icon(Icons.linear_scale),
                  ),
                  ButtonSegment(
                    value: _TransitTapMode.busZone,
                    label: Text(l10n.transitEditorModeBusZone),
                    icon: const Icon(Icons.directions_bus),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) =>
                    setState(() => _mode = s.first),
                showSelectedIcon: false,
              ),
            ),
            if (_mode == _TransitTapMode.busZone)
              SwitchListTile.adaptive(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16),
                dense: true,
                value: _busZoneEnabled,
                onChanged: (v) {
                  setState(() {
                    _busZoneEnabled = v;
                    if (!v) _busZone.clear();
                  });
                },
                title: Text(l10n.transitEditorBusZoneEnable),
                subtitle: Text(
                  l10n.transitEditorBusZoneHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Expanded(
              child: CalibrationCanvas(
                key: _canvasKey,
                videoPath: widget.videoPath,
                onTap: _handleTap,
                overlayBuilder: (rect) => _TransitPainter(
                  stopPolygon: _stopPolygon,
                  doorLine: _doorLine,
                  busZone: _busZoneEnabled ? _busZone : const [],
                  imageRect: rect,
                ),
              ),
            ),
            _buildHintBar(theme, l10n),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _capacityCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: l10n.transitEditorCapacity,
                  helperText: l10n.transitEditorCapacityHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.roiEditorCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: canSave ? _save : null,
                      child: Text(l10n.roiEditorSave),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintBar(ThemeData theme, AppLocalizations l10n) {
    final hint = switch (_mode) {
      _TransitTapMode.stopPolygon => _stopPolygon.length < 3
          ? l10n.transitEditorHintStopPolygon(3 - _stopPolygon.length)
          : l10n.transitEditorHintStopPolygonDone,
      _TransitTapMode.doorLine => _doorLine.length < 2
          ? l10n.transitEditorHintDoorLine(2 - _doorLine.length)
          : l10n.transitEditorHintDoorLineDone,
      _TransitTapMode.busZone => _busZoneEnabled
          ? (_busZone.length < 3
              ? l10n.transitEditorHintBusZone(3 - _busZone.length)
              : l10n.transitEditorHintBusZoneDone)
          : l10n.transitEditorBusZoneDisabled,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Text(
        hint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _TransitPainter extends CustomPainter {
  _TransitPainter({
    required this.stopPolygon,
    required this.doorLine,
    required this.busZone,
    required this.imageRect,
  });

  final List<Offset> stopPolygon;
  final List<Offset> doorLine;
  final List<Offset> busZone;
  final Rect imageRect;

  Path? _polygonPath(List<Offset> ratios) {
    if (ratios.isEmpty) return null;
    final widgetPts = ratios
        .map((p) => RoiNormalizer.imageRatioToWidget(
              ratio: p,
              imageRect: imageRect,
            ),)
        .toList();
    final path = Path()..moveTo(widgetPts.first.dx, widgetPts.first.dy);
    for (var i = 1; i < widgetPts.length; i++) {
      path.lineTo(widgetPts[i].dx, widgetPts[i].dy);
    }
    if (widgetPts.length >= 3) path.close();
    return path;
  }

  void _drawPolygon(
    Canvas canvas,
    List<Offset> ratios,
    Color color, {
    bool fill = true,
  }) {
    if (ratios.isEmpty) return;
    final path = _polygonPath(ratios);
    if (path == null) return;
    if (fill && ratios.length >= 3) {
      final fillPaint = Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(path, strokePaint);
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final p in ratios) {
      final wp = RoiNormalizer.imageRatioToWidget(
        ratio: p,
        imageRect: imageRect,
      );
      canvas.drawCircle(wp, 5, dot);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Stop polygon — primary; uses success colour to reinforce "this
    // is the area we measure density inside".
    _drawPolygon(canvas, stopPolygon, AppColors.success);

    // Door line — uses warning yellow so it stands out against the
    // green stop polygon when they overlap.
    if (doorLine.length == 2) {
      final a = RoiNormalizer.imageRatioToWidget(
        ratio: doorLine[0],
        imageRect: imageRect,
      );
      final b = RoiNormalizer.imageRatioToWidget(
        ratio: doorLine[1],
        imageRect: imageRect,
      );
      final stroke = Paint()
        ..color = AppColors.warning
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawLine(a, b, stroke);
      final dot = Paint()..color = AppColors.warning;
      canvas.drawCircle(a, 6, dot);
      canvas.drawCircle(b, 6, dot);
    } else if (doorLine.length == 1) {
      final a = RoiNormalizer.imageRatioToWidget(
        ratio: doorLine[0],
        imageRect: imageRect,
      );
      canvas.drawCircle(a, 6, Paint()..color = AppColors.warning);
    }

    // Bus zone — uses primary so all three overlays read distinctly.
    if (busZone.isNotEmpty) {
      _drawPolygon(canvas, busZone, AppColors.primary);
    }
  }

  @override
  bool shouldRepaint(covariant _TransitPainter old) =>
      old.stopPolygon != stopPolygon ||
      old.doorLine != doorLine ||
      old.busZone != busZone ||
      old.imageRect != imageRect;
}
