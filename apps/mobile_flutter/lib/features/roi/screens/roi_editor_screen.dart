import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:greyeye_mobile/features/roi/models/roi_model.dart';
import 'package:greyeye_mobile/features/roi/providers/roi_provider.dart';

enum _DrawMode { polygon, line, lane }

class RoiEditorScreen extends ConsumerStatefulWidget {
  const RoiEditorScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  ConsumerState<RoiEditorScreen> createState() => _RoiEditorScreenState();
}

class _RoiEditorScreenState extends ConsumerState<RoiEditorScreen> {
  _DrawMode _mode = _DrawMode.line;
  final _nameController = TextEditingController(text: 'Default Preset');
  List<Offset> _tempPoints = [];
  int _lineCounter = 1;
  int _laneCounter = 1;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onTapCanvas(Offset normalizedPoint) {
    final notifier = ref.read(roiEditorProvider(widget.cameraId).notifier);

    switch (_mode) {
      case _DrawMode.polygon:
        setState(() => _tempPoints = [..._tempPoints, normalizedPoint]);
      case _DrawMode.line:
        setState(() => _tempPoints = [..._tempPoints, normalizedPoint]);
        if (_tempPoints.length == 2) {
          notifier.addCountingLine(
            CountingLine(
              name: 'Line $_lineCounter',
              start: Point2D(x: _tempPoints[0].dx, y: _tempPoints[0].dy),
              end: Point2D(x: _tempPoints[1].dx, y: _tempPoints[1].dy),
              direction: 'inbound',
            ),
          );
          _lineCounter++;
          setState(() => _tempPoints = []);
        }
      case _DrawMode.lane:
        setState(() => _tempPoints = [..._tempPoints, normalizedPoint]);
    }
  }

  void _finishCurrentDrawing() {
    final notifier = ref.read(roiEditorProvider(widget.cameraId).notifier);
    if (_tempPoints.length < 2) {
      setState(() => _tempPoints = []);
      return;
    }

    switch (_mode) {
      case _DrawMode.polygon:
        notifier.setRoiPolygon(
          _tempPoints.map((p) => Point2D(x: p.dx, y: p.dy)).toList(),
        );
      case _DrawMode.lane:
        notifier.addLanePolyline(
          LanePolyline(
            name: 'Lane $_laneCounter',
            points:
                _tempPoints.map((p) => Point2D(x: p.dx, y: p.dy)).toList(),
          ),
        );
        _laneCounter++;
      case _DrawMode.line:
        break;
    }
    setState(() => _tempPoints = []);
  }

  Future<void> _save() async {
    final notifier = ref.read(roiEditorProvider(widget.cameraId).notifier);
    notifier.setPresetName(_nameController.text.trim());
    try {
      await notifier.save();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).roiPresetSaved)),
        );
        context.pop();
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editorState = ref.watch(roiEditorProvider(widget.cameraId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.roiTitle),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(roiEditorProvider(widget.cameraId).notifier).reset();
              setState(() {
                _tempPoints = [];
                _lineCounter = 1;
                _laneCounter = 1;
              });
            },
            child: Text(l10n.roiReset),
          ),
          TextButton(
            onPressed: editorState.isSaving ? null : _save,
            child: Text(l10n.roiSave),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.roiPresetName,
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<_DrawMode>(
              segments: [
                ButtonSegment(
                  value: _DrawMode.polygon,
                  label: Text(l10n.roiSegmentRoi),
                  icon: const Icon(Icons.pentagon_outlined),
                ),
                ButtonSegment(
                  value: _DrawMode.line,
                  label: Text(l10n.roiSegmentLine),
                  icon: const Icon(Icons.horizontal_rule),
                ),
                ButtonSegment(
                  value: _DrawMode.lane,
                  label: Text(l10n.roiSegmentLane),
                  icon: const Icon(Icons.straighten),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (modes) {
                _finishCurrentDrawing();
                setState(() => _mode = modes.first);
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.roiInstructions,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onTapUp: (details) {
                      final normalized = Offset(
                        details.localPosition.dx / constraints.maxWidth,
                        details.localPosition.dy / constraints.maxHeight,
                      );
                      _onTapCanvas(normalized);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CustomPaint(
                          size: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          painter: _RoiPainter(
                            roiPolygon: editorState.roiPolygon,
                            countingLines: editorState.countingLines,
                            lanePolylines: editorState.lanePolylines,
                            tempPoints: _tempPoints,
                            currentMode: _mode,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_mode != _DrawMode.line && _tempPoints.length >= 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FilledButton.icon(
                onPressed: _finishCurrentDrawing,
                icon: const Icon(Icons.check),
                label: Text(l10n.roiFinishDrawing),
              ),
            ),
          _buildSummary(editorState, theme, l10n),
        ],
      ),
    );
  }

  Widget _buildSummary(RoiEditorState state, ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(
            label: l10n.roiSegmentRoi,
            value: state.roiPolygon.isEmpty ? l10n.roiSummaryNone : l10n.roiSummarySet,
            color: state.roiPolygon.isEmpty ? Colors.grey : Colors.green,
          ),
          _SummaryItem(
            label: l10n.roiSummaryLines,
            value: '${state.countingLines.length}',
            color: theme.colorScheme.primary,
          ),
          _SummaryItem(
            label: l10n.roiSummaryLanes,
            value: '${state.lanePolylines.length}',
            color: theme.colorScheme.tertiary,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _RoiPainter extends CustomPainter {
  _RoiPainter({
    required this.roiPolygon,
    required this.countingLines,
    required this.lanePolylines,
    required this.tempPoints,
    required this.currentMode,
  });

  final List<Point2D> roiPolygon;
  final List<CountingLine> countingLines;
  final List<LanePolyline> lanePolylines;
  final List<Offset> tempPoints;
  final _DrawMode currentMode;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);

    if (roiPolygon.isNotEmpty) {
      _drawPolygon(canvas, size, roiPolygon, const Color(0x3300BCD4),
          const Color(0xFF00BCD4));
    }

    for (final line in countingLines) {
      _drawCountingLine(canvas, size, line);
    }

    for (final lane in lanePolylines) {
      _drawLanePolyline(canvas, size, lane);
    }

    if (tempPoints.isNotEmpty) {
      _drawTempPoints(canvas, size);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 0.5;
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawPolygon(
    Canvas canvas,
    Size size,
    List<Point2D> points,
    Color fill,
    Color stroke,
  ) {
    if (points.length < 3) return;
    final path = Path();
    path.moveTo(points[0].x * size.width, points[0].y * size.height);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].x * size.width, points[i].y * size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final p in points) {
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        5,
        Paint()..color = stroke,
      );
    }
  }

  void _drawCountingLine(Canvas canvas, Size size, CountingLine line) {
    final start = Offset(line.start.x * size.width, line.start.y * size.height);
    final end = Offset(line.end.x * size.width, line.end.y * size.height);
    final paint = Paint()
      ..color = Colors.yellowAccent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, paint);

    canvas.drawCircle(start, 6, Paint()..color = Colors.yellowAccent);
    canvas.drawCircle(end, 6, Paint()..color = Colors.yellowAccent);

    final midX = (start.dx + end.dx) / 2;
    final midY = (start.dy + end.dy) / 2;
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final arrowLen = 15.0;
    final arrowPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final perpAngle = angle + math.pi / 2;
    final tipX = midX + arrowLen * math.cos(perpAngle);
    final tipY = midY + arrowLen * math.sin(perpAngle);
    canvas.drawLine(Offset(midX, midY), Offset(tipX, tipY), arrowPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: line.name,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(midX - textPainter.width / 2, midY - 18));
  }

  void _drawLanePolyline(Canvas canvas, Size size, LanePolyline lane) {
    if (lane.points.length < 2) return;
    final paint = Paint()
      ..color = Colors.lightGreenAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(
      lane.points[0].x * size.width,
      lane.points[0].y * size.height,
    );
    for (var i = 1; i < lane.points.length; i++) {
      path.lineTo(
        lane.points[i].x * size.width,
        lane.points[i].y * size.height,
      );
    }
    canvas.drawPath(path, paint);
    for (final p in lane.points) {
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        4,
        Paint()..color = Colors.lightGreenAccent,
      );
    }
  }

  void _drawTempPoints(Canvas canvas, Size size) {
    final color = switch (currentMode) {
      _DrawMode.polygon => Colors.cyanAccent,
      _DrawMode.line => Colors.yellowAccent,
      _DrawMode.lane => Colors.lightGreenAccent,
    };
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (tempPoints.length > 1) {
      final path = Path();
      path.moveTo(
        tempPoints[0].dx * size.width,
        tempPoints[0].dy * size.height,
      );
      for (var i = 1; i < tempPoints.length; i++) {
        path.lineTo(
          tempPoints[i].dx * size.width,
          tempPoints[i].dy * size.height,
        );
      }
      canvas.drawPath(path, paint);
    }

    for (final p in tempPoints) {
      canvas.drawCircle(
        Offset(p.dx * size.width, p.dy * size.height),
        6,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoiPainter oldDelegate) => true;
}
