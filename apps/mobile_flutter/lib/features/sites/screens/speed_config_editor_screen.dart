import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:greyeye_mobile/core/theme/app_colors.dart';
import 'package:greyeye_mobile/features/sites/services/roi_normalizer.dart';
import 'package:greyeye_mobile/features/sites/widgets/calibration_canvas.dart';
import 'package:greyeye_mobile/features/sites/widgets/help_card.dart';

/// Editor result for F4 (속도분석). All coordinates are normalized
/// image-space ratios in [0..1]. The server's `resolve_ratio_coords()`
/// scales them at video-load time. Real-world dimensions stay in
/// metres throughout — they're physical, not pixel-relative.
class SpeedConfig {
  const SpeedConfig({
    required this.sourceQuad,
    required this.linesYRatio,
    required this.realWorldWidthM,
    required this.realWorldLengthM,
    this.line1XY = const [],
    this.line2XY = const [],
  });

  /// 4 image-space corners of the perspective quad. Order is the order
  /// the user tapped — typically TL, TR, BR, BL — matching what
  /// `cv2.getPerspectiveTransform` expects.
  final List<Offset> sourceQuad;

  /// Two horizontal-line y-ratios in [0..1] (line 1 = "entry",
  /// line 2 = "exit"). Used by the server only when [line1XY] /
  /// [line2XY] are empty (legacy back-compat for sites configured before
  /// the arbitrary-line editor shipped).
  final List<double> linesYRatio;

  /// Operator-drawn 2-point speed lines (start, end). Empty when the
  /// editor was saved in "snap to horizontal" mode — server then falls
  /// back to [linesYRatio]. Both endpoints are image-space ratios.
  final List<Offset> line1XY;
  final List<Offset> line2XY;

  /// Real-world rectangle width in metres. Lateral lane width — used
  /// only by the perspective warp, not by the speed math directly.
  final double realWorldWidthM;
  /// Real-world rectangle length in metres along travel direction.
  /// This is the distance the perspective warp maps. Combined with the
  /// elapsed time between line-crossings → km/h.
  final double realWorldLengthM;
}

/// Speed-line / perspective-quad editor for F4.
///
/// Workflow:
///  1. Tap mode = "Quad corner" by default. Tap 4 corners of a known
///     real-world rectangle painted on the road (lane markings, a
///     known stretch of asphalt). Subsequent taps reset to corner 1.
///  2. Switch tap mode to "Line 1" / "Line 2" → tap anywhere → that
///     line's y-ratio becomes the tap's y position.
///  3. Enter real-world width / length in metres.
///  4. Save returns [SpeedConfig].
///
/// Constraints:
///  - All 4 corners must be set OR all 4 unset. Partially-set quads
///    are rejected with a snackbar.
///  - Lines must differ by ≥ 5% of frame height — otherwise the elapsed
///    time is too short to compute meaningful km/h.
///  - Both metre values must be > 0.
class SpeedConfigEditorScreen extends StatefulWidget {
  const SpeedConfigEditorScreen({
    super.key,
    required this.videoPath,
    this.initial,
  });

  final String videoPath;
  final SpeedConfig? initial;

  @override
  State<SpeedConfigEditorScreen> createState() =>
      _SpeedConfigEditorScreenState();
}

enum _SpeedTapMode { quad, line1, line2 }

class _SpeedConfigEditorScreenState extends State<SpeedConfigEditorScreen> {
  late final TextEditingController _widthCtrl;
  late final TextEditingController _lengthCtrl;

  final List<Offset> _quad = [];
  // Operator-drawn 2-point speed lines (image-space ratios). Empty
  // until both endpoints are tapped; reset on a third tap of the same
  // mode. When [_snapHorizontal] is on we ignore tap.dx and use the
  // line's y-ratio (legacy behavior) — see [_save].
  final List<Offset> _line1 = [];
  final List<Offset> _line2 = [];

  // Default y-ratios used when the operator picks "snap to horizontal"
  // and never tapped the canvas. Mirror the calibration builder defaults.
  double _line1YDefault = 0.60;
  double _line2YDefault = 0.90;

  bool _snapHorizontal = false;

  _SpeedTapMode _mode = _SpeedTapMode.quad;

  // Lets the AppBar "pick backdrop" action drive the canvas's
  // private file-picker without duplicating the picker logic here.
  final GlobalKey<CalibrationCanvasState> _canvasKey =
      GlobalKey<CalibrationCanvasState>();

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _widthCtrl = TextEditingController(
      text: (init?.realWorldWidthM ?? 3.5).toString(),
    );
    _lengthCtrl = TextEditingController(
      text: (init?.realWorldLengthM ?? 20.0).toString(),
    );
    if (init != null) {
      _quad.addAll(init.sourceQuad);
      if (init.line1XY.length == 2 && init.line2XY.length == 2) {
        _line1.addAll(init.line1XY);
        _line2.addAll(init.line2XY);
      } else if (init.linesYRatio.length == 2) {
        // Legacy y-only config: synthesise full-width horizontal lines so
        // the painter has something to draw, and leave snap-mode on.
        _line1YDefault = init.linesYRatio[0];
        _line2YDefault = init.linesYRatio[1];
        _snapHorizontal = true;
      }
    }
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _lengthCtrl.dispose();
    super.dispose();
  }

  void _handleTap(Offset ratio) {
    setState(() {
      switch (_mode) {
        case _SpeedTapMode.quad:
          if (_quad.length >= 4) {
            // Past the 4th tap, start a fresh quad — operator wants to
            // re-pick. This is friendlier than locking out further taps
            // and forcing them to hit a "Reset" button.
            _quad
              ..clear()
              ..add(ratio);
          } else {
            _quad.add(ratio);
          }
        case _SpeedTapMode.line1:
          _appendLineTap(_line1, ratio);
        case _SpeedTapMode.line2:
          _appendLineTap(_line2, ratio);
      }
    });
  }

  void _appendLineTap(List<Offset> line, Offset ratio) {
    final tap = _snapHorizontal
        // Snap-mode collapses the line to its y-coordinate; we still
        // need 2 endpoints (left/right of the frame) so the painter
        // can render and the saved JSON is consistent with the arbitrary
        // case. The server's lines_xy parser handles either shape.
        ? Offset(0.0, ratio.dy)
        : ratio;
    if (line.length >= 2) {
      // Restart on third tap of the same mode.
      line
        ..clear()
        ..add(tap);
    } else {
      line.add(tap);
      if (_snapHorizontal && line.length == 1) {
        // Auto-fill the second endpoint at x=1 so a single tap suffices
        // in snap mode.
        line.add(Offset(1.0, tap.dy));
      }
    }
  }

  void _resetQuad() {
    setState(_quad.clear);
  }

  /// Sensible default for first-time users: a centred 1-lane trapezoid in
  /// the lower-half of the frame, with two horizontal lines 30% apart in
  /// snap-mode. Matches the legacy mobile-default JSON so users who
  /// previously got "decent enough" output without touching the editor
  /// keep seeing the same numbers — and now they can see exactly what was
  /// being used.
  void _applyDefaultPreset() {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _quad
        ..clear()
        ..addAll(const [
          Offset(0.30, 0.55),
          Offset(0.70, 0.55),
          Offset(0.85, 0.95),
          Offset(0.15, 0.95),
        ]);
      _line1
        ..clear()
        ..addAll(const [Offset(0.0, 0.60), Offset(1.0, 0.60)]);
      _line2
        ..clear()
        ..addAll(const [Offset(0.0, 0.90), Offset(1.0, 0.90)]);
      _snapHorizontal = true;
      _line1YDefault = 0.60;
      _line2YDefault = 0.90;
      _widthCtrl.text = '3.5';
      _lengthCtrl.text = '10.0';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.speedDefaultPresetApplied)),
    );
  }

  void _resetActiveLine() {
    setState(() {
      switch (_mode) {
        case _SpeedTapMode.line1:
          _line1.clear();
        case _SpeedTapMode.line2:
          _line2.clear();
        case _SpeedTapMode.quad:
          break;
      }
    });
  }

  void _save() {
    final l10n = AppLocalizations.of(context);

    if (_quad.length != 4) {
      _toast(l10n.speedEditorQuadIncomplete);
      return;
    }
    if (!_snapHorizontal &&
        (_line1.length != 2 || _line2.length != 2)) {
      _toast(l10n.speedEditorLinesIncomplete);
      return;
    }
    // y-distance test still useful: catches operators picking two lines
    // that visually overlap regardless of orientation.
    final y1 = _line1.length == 2
        ? (_line1[0].dy + _line1[1].dy) / 2
        : _line1YDefault;
    final y2 = _line2.length == 2
        ? (_line2[0].dy + _line2[1].dy) / 2
        : _line2YDefault;
    if ((y2 - y1).abs() < 0.05) {
      _toast(l10n.speedEditorLinesTooClose);
      return;
    }
    final width = double.tryParse(_widthCtrl.text);
    final length = double.tryParse(_lengthCtrl.text);
    if (width == null || width <= 0 || length == null || length <= 0) {
      _toast(l10n.speedEditorBadMetres);
      return;
    }

    final hasArbitraryLines = _line1.length == 2 && _line2.length == 2;

    Navigator.of(context).pop(SpeedConfig(
      sourceQuad: List.of(_quad),
      // Always store as [smaller, larger] so legacy server consumers
      // don't care about tap order.
      linesYRatio: [
        y1 < y2 ? y1 : y2,
        y1 < y2 ? y2 : y1,
      ],
      line1XY: hasArbitraryLines ? List.of(_line1) : const [],
      line2XY: hasArbitraryLines ? List.of(_line2) : const [],
      realWorldWidthM: width,
      realWorldLengthM: length,
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

    final activeLineEmpty =
        (_mode == _SpeedTapMode.line1 && _line1.isEmpty) ||
            (_mode == _SpeedTapMode.line2 && _line2.isEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.speedEditorTitle),
        actions: [
          IconButton(
            tooltip: l10n.roiEditorPickBackdrop,
            icon: const Icon(Icons.folder_open),
            onPressed: () => _canvasKey.currentState?.pickBackdrop(),
          ),
          if (_mode == _SpeedTapMode.quad && _quad.isNotEmpty)
            IconButton(
              tooltip: l10n.speedEditorResetQuad,
              icon: const Icon(Icons.refresh),
              onPressed: _resetQuad,
            ),
          if (_mode != _SpeedTapMode.quad && !activeLineEmpty)
            IconButton(
              tooltip: l10n.countLineEditorReset,
              icon: const Icon(Icons.refresh),
              onPressed: _resetActiveLine,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            HelpCard(
              title: l10n.speedWhatIsThisTitle,
              body: l10n.speedWhatIsThisBody,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: OutlinedButton.icon(
                onPressed: _applyDefaultPreset,
                icon: const Icon(Icons.auto_fix_high),
                label: Text(l10n.speedDefaultPresetButton),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8,
              ),
              child: SegmentedButton<_SpeedTapMode>(
                segments: [
                  ButtonSegment(
                    value: _SpeedTapMode.quad,
                    label: Text(
                      l10n.speedEditorModeQuad(_quad.length),
                    ),
                    icon: const Icon(Icons.crop_din),
                  ),
                  ButtonSegment(
                    value: _SpeedTapMode.line1,
                    label: Text(l10n.speedEditorModeLine1),
                    icon: const Icon(Icons.horizontal_rule),
                  ),
                  ButtonSegment(
                    value: _SpeedTapMode.line2,
                    label: Text(l10n.speedEditorModeLine2),
                    icon: const Icon(Icons.horizontal_rule),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) =>
                    setState(() => _mode = s.first),
                showSelectedIcon: false,
              ),
            ),
            SwitchListTile.adaptive(
              value: _snapHorizontal,
              onChanged: (v) => setState(() => _snapHorizontal = v),
              title: Text(l10n.speedEditorSnapHorizontal),
              subtitle: Text(
                l10n.speedEditorSnapHorizontalHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12),
            ),
            Expanded(
              child: CalibrationCanvas(
                key: _canvasKey,
                videoPath: widget.videoPath,
                onTap: _handleTap,
                overlayBuilder: (rect) => _SpeedPainter(
                  quad: _quad,
                  line1Pts: _line1,
                  line2Pts: _line2,
                  imageRect: rect,
                ),
              ),
            ),
            _buildHintBar(theme, l10n),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _widthCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.speedEditorWidthM,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _lengthCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.speedEditorLengthM,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
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

  bool get _canSave {
    if (_quad.length != 4) return false;
    if (_snapHorizontal) return true;
    return _line1.length == 2 && _line2.length == 2;
  }

  Widget _buildHintBar(ThemeData theme, AppLocalizations l10n) {
    String hint;
    switch (_mode) {
      case _SpeedTapMode.quad:
        hint = _quad.length < 4
            ? l10n.speedEditorHintQuad(4 - _quad.length)
            : l10n.speedEditorHintQuadDone;
      case _SpeedTapMode.line1:
        hint = switch (_line1.length) {
          0 => l10n.speedEditorHintLine1Start,
          1 => l10n.speedEditorHintLine1End,
          _ => l10n.speedEditorHintLine1Done,
        };
      case _SpeedTapMode.line2:
        hint = switch (_line2.length) {
          0 => l10n.speedEditorHintLine2Start,
          1 => l10n.speedEditorHintLine2End,
          _ => l10n.speedEditorHintLine2Done,
        };
    }
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

class _SpeedPainter extends CustomPainter {
  _SpeedPainter({
    required this.quad,
    required this.line1Pts,
    required this.line2Pts,
    required this.imageRect,
  });

  final List<Offset> quad;
  final List<Offset> line1Pts;
  final List<Offset> line2Pts;
  final Rect imageRect;

  @override
  void paint(Canvas canvas, Size size) {
    final quadStroke = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final quadFill = Paint()
      ..color = AppColors.success.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final dot = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.fill;
    final lineStroke = Paint()
      ..color = AppColors.warning
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final lineDot = Paint()
      ..color = AppColors.warning
      ..style = PaintingStyle.fill;

    // Quad
    if (quad.isNotEmpty) {
      final widgetPts = quad
          .map((p) => RoiNormalizer.imageRatioToWidget(
                ratio: p,
                imageRect: imageRect,
              ),)
          .toList();
      if (widgetPts.length >= 2) {
        final path = Path()..moveTo(widgetPts.first.dx, widgetPts.first.dy);
        for (var i = 1; i < widgetPts.length; i++) {
          path.lineTo(widgetPts[i].dx, widgetPts[i].dy);
        }
        if (widgetPts.length == 4) {
          path.close();
          canvas.drawPath(path, quadFill);
        }
        canvas.drawPath(path, quadStroke);
      }
      for (var i = 0; i < widgetPts.length; i++) {
        canvas.drawCircle(widgetPts[i], 6, dot);
        // Number each tap so the operator can see the order — matters
        // for getPerspectiveTransform (must be consistent CW or CCW).
        final tp = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          widgetPts[i] - Offset(tp.width / 2, tp.height / 2),
        );
      }
    }

    void drawLineSegment(List<Offset> ratios, String label) {
      if (ratios.isEmpty) return;
      final widgetPts = ratios
          .map((p) => RoiNormalizer.imageRatioToWidget(
                ratio: p,
                imageRect: imageRect,
              ),)
          .toList();
      if (widgetPts.length == 2) {
        canvas.drawLine(widgetPts[0], widgetPts[1], lineStroke);
      }
      for (final p in widgetPts) {
        canvas.drawCircle(p, 5, lineDot);
      }
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: AppColors.warning,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black.withValues(alpha: 0.5),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, widgetPts.first + const Offset(8, -18));
    }

    drawLineSegment(line1Pts, 'L1');
    drawLineSegment(line2Pts, 'L2');
  }

  @override
  bool shouldRepaint(covariant _SpeedPainter old) =>
      old.quad != quad ||
      old.line1Pts != line1Pts ||
      old.line2Pts != line2Pts ||
      old.imageRect != imageRect;
}
