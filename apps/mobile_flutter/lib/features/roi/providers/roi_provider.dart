import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/database/database.dart' as db;
import 'package:greyeye_mobile/core/database/database.dart'
    show RoiPresetsCompanion, CountingLinesCompanion;
import 'package:greyeye_mobile/core/database/database_provider.dart';
import 'package:greyeye_mobile/core/database/daos/roi_dao.dart';
import 'package:greyeye_mobile/features/roi/models/roi_model.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

RoiPreset _presetFromDb(db.RoiPreset row, List<db.CountingLine> lines) {
  List<Point2D> polygon = [];
  try {
    final decoded = jsonDecode(row.roiPolygonJson) as List<dynamic>;
    polygon = decoded
        .map((p) => Point2D(
              x: (p['x'] as num).toDouble(),
              y: (p['y'] as num).toDouble(),
            ))
        .toList();
  } catch (_) {}

  List<LanePolyline> lanePolylines = [];
  try {
    final decoded = jsonDecode(row.lanePolylinesJson) as List<dynamic>;
    lanePolylines = decoded
        .map((l) => LanePolyline.fromJson(l as Map<String, dynamic>))
        .toList();
  } catch (_) {}

  return RoiPreset(
    id: row.id,
    cameraId: row.cameraId,
    name: row.name,
    roiPolygon: polygon,
    countingLines: lines
        .map((l) => CountingLine(
              name: l.name,
              start: Point2D(x: l.startX, y: l.startY),
              end: Point2D(x: l.endX, y: l.endY),
              direction: l.direction,
              directionVector: l.directionVectorJson != null
                  ? () {
                      try {
                        final dv = jsonDecode(l.directionVectorJson!)
                            as Map<String, dynamic>;
                        return Point2D(
                          x: (dv['x'] as num).toDouble(),
                          y: (dv['y'] as num).toDouble(),
                        );
                      } catch (_) {
                        return null;
                      }
                    }()
                  : null,
            ))
        .toList(),
    lanePolylines: lanePolylines,
    isActive: row.isActive,
    createdAt: row.createdAt,
  );
}

final roiPresetsProvider = FutureProvider.family<List<RoiPreset>, String>(
  (ref, cameraId) async {
    final roiDao = ref.watch(roiDaoProvider);
    final presetRows = await roiDao.presetsForCamera(cameraId);
    final result = <RoiPreset>[];
    for (final row in presetRows) {
      final lines = await roiDao.linesForPreset(row.id);
      result.add(_presetFromDb(row, lines));
    }
    return result;
  },
);

class RoiEditorNotifier extends StateNotifier<RoiEditorState> {
  RoiEditorNotifier(this._roiDao, this._cameraId)
      : super(const RoiEditorState());

  final RoiDao _roiDao;
  final String _cameraId;

  void setRoiPolygon(List<Point2D> points) {
    state = state.copyWith(roiPolygon: points);
  }

  void addCountingLine(CountingLine line) {
    state = state.copyWith(
      countingLines: [...state.countingLines, line],
    );
  }

  void removeCountingLine(int index) {
    final lines = [...state.countingLines]..removeAt(index);
    state = state.copyWith(countingLines: lines);
  }

  void addLanePolyline(LanePolyline lane) {
    state = state.copyWith(
      lanePolylines: [...state.lanePolylines, lane],
    );
  }

  void setPresetName(String name) {
    state = state.copyWith(presetName: name);
  }

  Future<RoiPreset> save() async {
    state = state.copyWith(isSaving: true);
    try {
      final presetId = _uuid.v4();

      final polygonJson = jsonEncode(
        state.roiPolygon.map((p) => p.toJson()).toList(),
      );
      final laneJson = jsonEncode(
        state.lanePolylines.map((l) => l.toJson()).toList(),
      );

      await _roiDao.insertPreset(RoiPresetsCompanion.insert(
        id: presetId,
        cameraId: _cameraId,
        name: state.presetName.isEmpty ? 'Preset' : state.presetName,
        roiPolygonJson: Value(polygonJson),
        lanePolylinesJson: Value(laneJson),
      ));

      for (var i = 0; i < state.countingLines.length; i++) {
        final cl = state.countingLines[i];
        final lineId = _uuid.v4();
        await _roiDao.insertLine(CountingLinesCompanion.insert(
          id: lineId,
          presetId: presetId,
          cameraId: _cameraId,
          name: cl.name,
          startX: cl.start.x,
          startY: cl.start.y,
          endX: cl.end.x,
          endY: cl.end.y,
          direction: Value(cl.direction),
          directionVectorJson: cl.directionVector != null
              ? Value(jsonEncode(cl.directionVector!.toJson()))
              : const Value<String?>.absent(),
          sortOrder: Value(i),
        ));
      }

      final presetRow = await _roiDao
          .presetsForCamera(_cameraId)
          .then((rows) => rows.firstWhere((r) => r.id == presetId));
      final lineRows = await _roiDao.linesForPreset(presetId);
      final preset = _presetFromDb(presetRow, lineRows);

      state = state.copyWith(isSaving: false);
      return preset;
    } on Exception {
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }

  Future<void> activatePreset(String presetId) async {
    await _roiDao.activatePreset(_cameraId, presetId);
  }

  void reset() {
    state = const RoiEditorState();
  }
}

class RoiEditorState {
  const RoiEditorState({
    this.presetName = '',
    this.roiPolygon = const [],
    this.countingLines = const [],
    this.lanePolylines = const [],
    this.isSaving = false,
  });

  final String presetName;
  final List<Point2D> roiPolygon;
  final List<CountingLine> countingLines;
  final List<LanePolyline> lanePolylines;
  final bool isSaving;

  RoiEditorState copyWith({
    String? presetName,
    List<Point2D>? roiPolygon,
    List<CountingLine>? countingLines,
    List<LanePolyline>? lanePolylines,
    bool? isSaving,
  }) =>
      RoiEditorState(
        presetName: presetName ?? this.presetName,
        roiPolygon: roiPolygon ?? this.roiPolygon,
        countingLines: countingLines ?? this.countingLines,
        lanePolylines: lanePolylines ?? this.lanePolylines,
        isSaving: isSaving ?? this.isSaving,
      );
}

final roiEditorProvider = StateNotifierProvider.autoDispose
    .family<RoiEditorNotifier, RoiEditorState, String>((ref, cameraId) {
  return RoiEditorNotifier(ref.watch(roiDaoProvider), cameraId);
});
