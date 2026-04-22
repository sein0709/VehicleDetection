import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:greyeye_mobile/core/theme/app_colors.dart';
import 'package:greyeye_mobile/features/sites/services/roi_normalizer.dart';
import 'package:greyeye_mobile/features/sites/widgets/calibration_canvas.dart';
import 'package:greyeye_mobile/features/sites/widgets/help_card.dart';

/// Result returned by [TrafficLightRoiEditorScreen].
///
/// All coordinates are normalized image-space ratios in [0..1] — the
/// server's `Calibration.resolve_ratio_coords` scales them to pixels.
class TrafficLightRoi {
  const TrafficLightRoi({required this.label, required this.roi});
  final String label;
  /// `[x, y, w, h]` in normalized image space.
  final List<double> roi;
}

/// Per-light ROI editor for F7 (신호등 시간계산).
///
/// Workflow:
///  1. Frame loads (extracted from the user's picked video, or picked
///     manually if extraction failed)
///  2. Tap once = top-left corner; tap again = bottom-right
///  3. Subsequent taps refine alternating corners — saves the user
///     from "Reset and start over" when only one corner is wrong
///  4. "Save" returns the ROI; "Cancel" pops with null
class TrafficLightRoiEditorScreen extends StatefulWidget {
  const TrafficLightRoiEditorScreen({
    super.key,
    required this.videoPath,
    this.initialLabel = 'main',
    this.initialRoi,
  });

  final String videoPath;
  final String initialLabel;
  /// Pre-existing ROI to seed the editor with (`[x, y, w, h]` in [0..1]).
  final List<double>? initialRoi;

  @override
  State<TrafficLightRoiEditorScreen> createState() =>
      _TrafficLightRoiEditorScreenState();
}

class _TrafficLightRoiEditorScreenState
    extends State<TrafficLightRoiEditorScreen> {
  late final TextEditingController _labelCtrl;
  Offset? _cornerA;
  Offset? _cornerB;
  // Tracks which corner the next tap will overwrite. Toggles A↔B so the
  // user can refine either corner without resetting the whole ROI.
  bool _nextIsA = true;

  // Lets the AppBar "pick backdrop" action drive the canvas's
  // private file-picker without duplicating the picker logic here.
  final GlobalKey<CalibrationCanvasState> _canvasKey =
      GlobalKey<CalibrationCanvasState>();

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.initialLabel);
    final r = widget.initialRoi;
    if (r != null && r.length == 4) {
      _cornerA = Offset(r[0], r[1]);
      _cornerB = Offset(r[0] + r[2], r[1] + r[3]);
      _nextIsA = false;
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  void _handleTap(Offset ratio) {
    setState(() {
      if (_nextIsA) {
        _cornerA = ratio;
      } else {
        _cornerB = ratio;
      }
      if (_cornerA != null && _cornerB != null) {
        _nextIsA = !_nextIsA;
      } else {
        _nextIsA = false;
      }
    });
  }

  void _reset() {
    setState(() {
      _cornerA = null;
      _cornerB = null;
      _nextIsA = true;
    });
  }

  void _save() {
    final a = _cornerA;
    final b = _cornerB;
    if (a == null || b == null) return;
    final roi = RoiNormalizer.roiFromCorners(a, b);
    if (roi[2] < 0.01 || roi[3] < 0.01) {
      // Reject degenerate boxes — typically a double-tap on the same
      // pixel. Better to ask the user than to send `[0.5, 0.5, 0, 0]`
      // which the HSV state machine will read as "always unknown".
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).roiEditorRoiTooSmall),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      TrafficLightRoi(
        label: _labelCtrl.text.trim().isEmpty
            ? 'main'
            : _labelCtrl.text.trim(),
        roi: roi,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canSave = _cornerA != null && _cornerB != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.roiEditorTitle),
        actions: [
          IconButton(
            tooltip: l10n.roiEditorPickBackdrop,
            icon: const Icon(Icons.folder_open),
            onPressed: () => _canvasKey.currentState?.pickBackdrop(),
          ),
          if (_cornerA != null || _cornerB != null)
            IconButton(
              tooltip: l10n.roiEditorReset,
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            HelpCard(
              title: l10n.lightWhatIsThisTitle,
              body: l10n.lightWhatIsThisBody,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _labelCtrl,
                decoration: InputDecoration(
                  labelText: l10n.roiEditorLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: CalibrationCanvas(
                key: _canvasKey,
                videoPath: widget.videoPath,
                onTap: _handleTap,
                overlayBuilder: (rect) => _RoiPainter(
                  cornerA: _cornerA,
                  cornerB: _cornerB,
                  imageRect: rect,
                  color: AppColors.success,
                ),
              ),
            ),
            _buildHintBar(theme, l10n),
            Padding(
              padding: const EdgeInsets.all(12),
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
    final String hint;
    if (_cornerA == null) {
      hint = l10n.roiEditorHintTopLeft;
    } else if (_cornerB == null) {
      hint = l10n.roiEditorHintBottomRight;
    } else {
      hint = l10n.roiEditorHintRefine;
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

class _RoiPainter extends CustomPainter {
  _RoiPainter({
    required this.cornerA,
    required this.cornerB,
    required this.imageRect,
    required this.color,
  });

  final Offset? cornerA;
  final Offset? cornerB;
  final Rect imageRect;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (cornerA != null && cornerB != null) {
      final aw = RoiNormalizer.imageRatioToWidget(
        ratio: cornerA!,
        imageRect: imageRect,
      );
      final bw = RoiNormalizer.imageRatioToWidget(
        ratio: cornerB!,
        imageRect: imageRect,
      );
      final rect = Rect.fromPoints(aw, bw);
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);
      canvas.drawCircle(aw, 6, dot);
      canvas.drawCircle(bw, 6, dot);
    } else if (cornerA != null) {
      final aw = RoiNormalizer.imageRatioToWidget(
        ratio: cornerA!,
        imageRect: imageRect,
      );
      canvas.drawCircle(aw, 6, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _RoiPainter old) =>
      old.cornerA != cornerA ||
      old.cornerB != cornerB ||
      old.imageRect != imageRect;
}
