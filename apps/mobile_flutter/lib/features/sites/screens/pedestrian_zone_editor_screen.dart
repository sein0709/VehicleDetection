import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:greyeye_mobile/core/theme/app_colors.dart';
import 'package:greyeye_mobile/features/sites/services/roi_normalizer.dart';
import 'package:greyeye_mobile/features/sites/widgets/calibration_canvas.dart';
import 'package:greyeye_mobile/features/sites/widgets/help_card.dart';

/// Editor result for the optional pedestrian ROI polygon (F2). The
/// vertices are normalized image-space `[x, y]` ratios in [0..1] — the
/// server's `Calibration.resolve_ratio_coords()` rescales them at
/// video-load time, same convention as `transit.stop_polygon`.
class PedestrianZoneConfig {
  const PedestrianZoneConfig({required this.polygon});

  /// 3+ vertices outlining the area in which pedestrians are counted.
  final List<Offset> polygon;
}

/// Free-form polygon editor for the pedestrian ROI. Mirrors the
/// stop-polygon mode of [TransitConfigEditorScreen] but trimmed down to
/// a single polygon — the only piece of state this feature needs.
///
/// Why a polygon and not a single rectangle? Because realistic
/// pedestrian zones don't align with the video's axes (e.g. a curved
/// crosswalk, a triangular plaza, an oblique sidewalk). The
/// PolygonZone trigger on the server already takes arbitrary vertex
/// counts so the editor exposes the same flexibility.
class PedestrianZoneEditorScreen extends StatefulWidget {
  const PedestrianZoneEditorScreen({
    super.key,
    required this.videoPath,
    this.initial,
  });

  final String videoPath;
  final PedestrianZoneConfig? initial;

  @override
  State<PedestrianZoneEditorScreen> createState() =>
      _PedestrianZoneEditorScreenState();
}

class _PedestrianZoneEditorScreenState
    extends State<PedestrianZoneEditorScreen> {
  final List<Offset> _polygon = [];

  // Lets the AppBar "pick backdrop" action drive the canvas's private
  // file-picker — same pattern as the other editors.
  final GlobalKey<CalibrationCanvasState> _canvasKey =
      GlobalKey<CalibrationCanvasState>();

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _polygon.addAll(init.polygon);
    }
  }

  void _handleTap(Offset ratio) {
    setState(() => _polygon.add(ratio));
  }

  void _undo() {
    if (_polygon.isEmpty) return;
    setState(_polygon.removeLast);
  }

  void _clear() {
    if (_polygon.isEmpty) return;
    setState(_polygon.clear);
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    if (_polygon.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pedestrianZoneEditorTooSmall)),
      );
      return;
    }
    Navigator.of(context).pop(
      PedestrianZoneConfig(polygon: List.of(_polygon)),
    );
  }

  bool get _canSave => _polygon.length >= 3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pedestrianZoneEditorTitle),
        actions: [
          IconButton(
            tooltip: l10n.roiEditorPickBackdrop,
            icon: const Icon(Icons.folder_open),
            onPressed: () => _canvasKey.currentState?.pickBackdrop(),
          ),
          IconButton(
            tooltip: l10n.transitEditorUndo,
            icon: const Icon(Icons.undo),
            onPressed: _polygon.isEmpty ? null : _undo,
          ),
          IconButton(
            tooltip: l10n.pedestrianZoneEditorClear,
            icon: const Icon(Icons.delete_outline),
            onPressed: _polygon.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            HelpCard(
              title: l10n.pedestrianZoneWhatIsThisTitle,
              body: l10n.pedestrianZoneWhatIsThisBody,
            ),
            Expanded(
              child: CalibrationCanvas(
                key: _canvasKey,
                videoPath: widget.videoPath,
                onTap: _handleTap,
                overlayBuilder: (rect) => _PedestrianZonePainter(
                  polygon: _polygon,
                  imageRect: rect,
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8,
              ),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Text(
                _polygon.length < 3
                    ? l10n.pedestrianZoneEditorHint(3 - _polygon.length)
                    : l10n.pedestrianZoneEditorHintDone(_polygon.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
                      onPressed: _canSave ? _save : null,
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
}

class _PedestrianZonePainter extends CustomPainter {
  _PedestrianZonePainter({
    required this.polygon,
    required this.imageRect,
  });

  final List<Offset> polygon;
  final Rect imageRect;

  @override
  void paint(Canvas canvas, Size size) {
    if (polygon.isEmpty) return;
    final widgetPts = polygon
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

    if (widgetPts.length >= 3) {
      final fill = Paint()
        ..color = AppColors.success.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fill);
    }
    final stroke = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(path, stroke);

    final dot = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.fill;
    for (final p in widgetPts) {
      canvas.drawCircle(p, 5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _PedestrianZonePainter old) =>
      old.polygon != polygon || old.imageRect != imageRect;
}
