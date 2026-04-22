import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:greyeye_mobile/core/theme/app_colors.dart';
import 'package:greyeye_mobile/features/sites/services/roi_normalizer.dart';
import 'package:greyeye_mobile/features/sites/widgets/calibration_canvas.dart';
import 'package:greyeye_mobile/features/sites/widgets/help_card.dart';

/// Editor result for the IN/OUT count-line pair. Coordinates are
/// normalized image-space `[x, y]` ratios in [0..1] — the server's
/// `resolve_ratio_coords()` rescales them at video-load time.
class CountLineConfig {
  const CountLineConfig({required this.inLine, required this.outLine});

  /// Two endpoints (start, end) in image-space ratios.
  final List<Offset> inLine;
  final List<Offset> outLine;
}

/// IN/OUT custom-line editor.
///
/// Workflow mirrors [SpeedConfigEditorScreen]: a [SegmentedButton] picks
/// which line you're drawing, two taps complete the line (start →
/// end), a third tap on the same mode resets that line. Save returns a
/// [CountLineConfig] only when both lines have 2 endpoints each.
///
/// Why segment-style and not single tripwire? See `SegmentCounter` in
/// `runpod/pipeline.py` — counting only after BOTH lines are crossed
/// rejects oscillating tracks (which inflate single-tripwire counts) and
/// scales to oblique camera angles where a horizontal line wouldn't fit.
class CountLineEditorScreen extends StatefulWidget {
  const CountLineEditorScreen({
    super.key,
    required this.videoPath,
    this.initial,
  });

  final String videoPath;
  final CountLineConfig? initial;

  @override
  State<CountLineEditorScreen> createState() => _CountLineEditorScreenState();
}

enum _CountLineMode { inLine, outLine }

class _CountLineEditorScreenState extends State<CountLineEditorScreen> {
  final List<Offset> _inLine = [];
  final List<Offset> _outLine = [];
  _CountLineMode _mode = _CountLineMode.inLine;

  // Lets the AppBar "pick backdrop" action drive the canvas's
  // private file-picker — same pattern as the speed editor.
  final GlobalKey<CalibrationCanvasState> _canvasKey =
      GlobalKey<CalibrationCanvasState>();

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _inLine.addAll(init.inLine);
      _outLine.addAll(init.outLine);
    }
  }

  void _handleTap(Offset ratio) {
    setState(() {
      final target = _mode == _CountLineMode.inLine ? _inLine : _outLine;
      if (target.length >= 2) {
        // Past the 2nd tap, restart the active line — friendlier than
        // forcing the operator to hit a "Reset" button.
        target
          ..clear()
          ..add(ratio);
      } else {
        target.add(ratio);
      }
    });
  }

  void _resetActive() {
    setState(() {
      (_mode == _CountLineMode.inLine ? _inLine : _outLine).clear();
    });
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    if (_inLine.length != 2 || _outLine.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.countLineEditorIncomplete)),
      );
      return;
    }
    Navigator.of(context).pop(CountLineConfig(
      inLine: List.of(_inLine),
      outLine: List.of(_outLine),
    ),);
  }

  bool get _canSave => _inLine.length == 2 && _outLine.length == 2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final activeIsEmpty =
        (_mode == _CountLineMode.inLine ? _inLine : _outLine).isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.countLineEditorTitle),
        actions: [
          IconButton(
            tooltip: l10n.roiEditorPickBackdrop,
            icon: const Icon(Icons.folder_open),
            onPressed: () => _canvasKey.currentState?.pickBackdrop(),
          ),
          if (!activeIsEmpty)
            IconButton(
              tooltip: l10n.countLineEditorReset,
              icon: const Icon(Icons.refresh),
              onPressed: _resetActive,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            HelpCard(
              title: l10n.countLineWhatIsThisTitle,
              body: l10n.countLineWhatIsThisBody,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8,
              ),
              child: SegmentedButton<_CountLineMode>(
                segments: [
                  ButtonSegment(
                    value: _CountLineMode.inLine,
                    label: Text(l10n.countLineEditorModeIn),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  ButtonSegment(
                    value: _CountLineMode.outLine,
                    label: Text(l10n.countLineEditorModeOut),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) =>
                    setState(() => _mode = s.first),
                showSelectedIcon: false,
              ),
            ),
            Expanded(
              child: CalibrationCanvas(
                key: _canvasKey,
                videoPath: widget.videoPath,
                onTap: _handleTap,
                overlayBuilder: (rect) => _CountLinePainter(
                  inLine: _inLine,
                  outLine: _outLine,
                  imageRect: rect,
                ),
              ),
            ),
            _buildHintBar(theme, l10n),
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

  Widget _buildHintBar(ThemeData theme, AppLocalizations l10n) {
    final activeLine =
        _mode == _CountLineMode.inLine ? _inLine : _outLine;
    final hint = switch (_mode) {
      _CountLineMode.inLine => switch (activeLine.length) {
          0 => l10n.countLineEditorHintInStart,
          1 => l10n.countLineEditorHintInEnd,
          _ => l10n.countLineEditorHintInDone,
        },
      _CountLineMode.outLine => switch (activeLine.length) {
          0 => l10n.countLineEditorHintOutStart,
          1 => l10n.countLineEditorHintOutEnd,
          _ => l10n.countLineEditorHintOutDone,
        },
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.countLineEditorDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountLinePainter extends CustomPainter {
  _CountLinePainter({
    required this.inLine,
    required this.outLine,
    required this.imageRect,
  });

  final List<Offset> inLine;
  final List<Offset> outLine;
  final Rect imageRect;

  @override
  void paint(Canvas canvas, Size size) {
    _paintLine(canvas, inLine, AppColors.success, 'IN');
    _paintLine(canvas, outLine, AppColors.error, 'OUT');
  }

  void _paintLine(
    Canvas canvas,
    List<Offset> line,
    Color color,
    String label,
  ) {
    if (line.isEmpty) return;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final widgetPts = line
        .map((p) => RoiNormalizer.imageRatioToWidget(
              ratio: p,
              imageRect: imageRect,
            ),)
        .toList();

    if (widgetPts.length == 2) {
      canvas.drawLine(widgetPts[0], widgetPts[1], stroke);
    }
    for (final p in widgetPts) {
      canvas.drawCircle(p, 6, dot);
    }
    // Label sits above the start point so it doesn't overlap the line.
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black.withValues(alpha: 0.5),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, widgetPts.first + const Offset(8, -18));
  }

  @override
  bool shouldRepaint(covariant _CountLinePainter old) =>
      old.inLine != inLine ||
      old.outLine != outLine ||
      old.imageRect != imageRect;
}
