import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/constants/api_constants.dart';
import 'package:greyeye_mobile/core/network/api_client.dart';
import 'package:greyeye_mobile/features/roi/models/roi_model.dart';

final roiPresetsProvider = FutureProvider.family<List<RoiPreset>, String>(
  (ref, cameraId) async {
    final api = ref.watch(apiClientProvider);
    final response = await api.get<Map<String, dynamic>>(
      ApiConstants.cameraRoiPresets(cameraId),
    );
    return (response.data?['items'] as List<dynamic>?)
            ?.map((e) => RoiPreset.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  },
);

class RoiEditorNotifier extends StateNotifier<RoiEditorState> {
  RoiEditorNotifier(this._api, this._cameraId)
      : super(const RoiEditorState());

  final ApiClient _api;
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
      final body = {
        'name': state.presetName,
        if (state.roiPolygon.isNotEmpty)
          'roi_polygon': {
            'type': 'Polygon',
            'coordinates': [
              state.roiPolygon.map((p) => [p.x, p.y]).toList(),
            ],
          },
        'counting_lines':
            state.countingLines.map((c) => c.toJson()).toList(),
        'lane_polylines':
            state.lanePolylines.map((l) => l.toJson()).toList(),
      };
      final response = await _api.post<Map<String, dynamic>>(
        ApiConstants.cameraRoiPresets(_cameraId),
        data: body,
      );
      state = state.copyWith(isSaving: false);
      return RoiPreset.fromJson(response.data!);
    } on Exception {
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }

  Future<void> activatePreset(String presetId) async {
    await _api.post<void>(ApiConstants.activateRoiPreset(presetId));
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
  return RoiEditorNotifier(ref.watch(apiClientProvider), cameraId);
});
