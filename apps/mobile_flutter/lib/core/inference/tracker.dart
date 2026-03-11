/// Stage 2 — ByteTrack-style multi-object tracker.
///
/// Assigns persistent track IDs across frames using IoU-based association.
/// Two-stage matching: first high-confidence detections against confirmed
/// tracks, then low-confidence detections to recover unmatched tracks.
///
/// Ported from `services/inference_worker/inference_worker/stages/tracker.py`.
library;

import 'dart:math' as math;

import 'package:greyeye_mobile/core/inference/models.dart';
import 'package:greyeye_mobile/core/inference/pipeline_settings.dart';

class ByteTracker {
  ByteTracker(this._settings);

  final TrackerSettings _settings;
  int _nextId = 0;

  String _newTrackId() {
    final tid = 'trk_${_nextId.toString().padLeft(5, '0')}';
    _nextId++;
    return tid;
  }

  /// Run one tracking step, returning the updated track-state map.
  Map<String, TrackState> update(
    List<Detection> detections,
    Map<String, TrackState> existingTracks,
    int frameIndex, {
    double fps = 10.0,
  }) {
    final highConf = detections.where((d) => d.confidence >= 0.5).toList();
    final lowConf = detections.where((d) => d.confidence < 0.5).toList();

    final confirmed = <String, TrackState>{};
    final tentative = <String, TrackState>{};
    for (final e in existingTracks.entries) {
      if (e.value.isConfirmed) {
        confirmed[e.key] = e.value;
      } else {
        tentative[e.key] = e.value;
      }
    }

    final updated = <String, TrackState>{};

    // First association: confirmed tracks ↔ high-confidence detections.
    final (matchedTids1, remainingHigh) =
        _associate(confirmed, highConf, frameIndex, fps, updated);

    // Second association: unmatched confirmed ↔ low-confidence detections.
    final unmatchedConfirmed = <String, TrackState>{
      for (final e in confirmed.entries)
        if (!matchedTids1.contains(e.key)) e.key: e.value,
    };
    _associate(unmatchedConfirmed, lowConf, frameIndex, fps, updated);

    // Age out still-unmatched confirmed tracks.
    for (final e in unmatchedConfirmed.entries) {
      if (updated.containsKey(e.key)) continue;
      final ts = e.value;
      ts.timeSinceUpdate += 1;
      ts.occlusionFlag = true;
      if (ts.timeSinceUpdate <= _settings.maxAge) {
        updated[e.key] = ts;
      }
    }

    // Third association: tentative tracks ↔ remaining high-confidence.
    final (tentMatched, _) =
        _associate(tentative, remainingHigh, frameIndex, fps, updated);

    // Age out unmatched tentative tracks.
    for (final e in tentative.entries) {
      if (tentMatched.contains(e.key) || updated.containsKey(e.key)) continue;
      final ts = e.value;
      ts.timeSinceUpdate += 1;
      if (ts.timeSinceUpdate <= _settings.maxAge) {
        updated[e.key] = ts;
      }
    }

    // Create new tentative tracks from unmatched high-confidence detections.
    final usedDetIndices = <int>{};
    for (var i = 0; i < remainingHigh.length; i++) {
      final det = remainingHigh[i];
      for (final ts in updated.values) {
        if (ts.lastSeenFrame == frameIndex &&
            ts.bbox.x == det.bbox.x &&
            ts.bbox.y == det.bbox.y) {
          usedDetIndices.add(i);
          break;
        }
      }
    }

    for (var i = 0; i < remainingHigh.length; i++) {
      if (usedDetIndices.contains(i)) continue;
      final det = remainingHigh[i];
      final newId = _newTrackId();
      final centroid = bboxCenter(det.bbox);
      updated[newId] = TrackState(
        trackId: newId,
        bbox: det.bbox,
        centroid: centroid,
        centroidHistory: [centroid],
        firstSeenFrame: frameIndex,
        lastSeenFrame: frameIndex,
        age: 1,
        hits: 1,
      );
    }

    // Promote tentative → confirmed.
    for (final ts in updated.values) {
      if (!ts.isConfirmed && ts.hits >= _settings.minHits) {
        ts.isConfirmed = true;
      }
    }

    return updated;
  }

  /// Associate detections to tracks via IoU.
  ///
  /// Returns (matched track IDs, unmatched detections).
  (Set<String>, List<Detection>) _associate(
    Map<String, TrackState> tracks,
    List<Detection> detections,
    int frameIndex,
    double fps,
    Map<String, TrackState> output,
  ) {
    if (tracks.isEmpty || detections.isEmpty) {
      return ({}, List<Detection>.of(detections));
    }

    final trackIds = tracks.keys.toList();
    final trackBoxes = trackIds.map((id) => bboxToXyxy(tracks[id]!.bbox)).toList();
    final detBoxes = detections.map((d) => bboxToXyxy(d.bbox)).toList();

    final iou = _iouMatrix(trackBoxes, detBoxes);
    final (matches, _, _) = _greedyAssignment(iou, _settings.iouThreshold);

    final matchedTids = <String>{};
    final matchedDetIdx = <int>{};

    for (final (tIdx, dIdx) in matches) {
      final tid = trackIds[tIdx];
      final det = detections[dIdx];
      final ts = tracks[tid]!;

      final centroid = bboxCenter(det.bbox);
      ts.bbox = det.bbox;
      ts.centroid = centroid;
      ts.centroidHistory.add(centroid);
      if (ts.centroidHistory.length > _settings.centroidHistoryLength) {
        ts.centroidHistory = ts.centroidHistory.sublist(
          ts.centroidHistory.length - _settings.centroidHistoryLength,
        );
      }
      ts.lastSeenFrame = frameIndex;
      ts.age += 1;
      ts.hits += 1;
      ts.timeSinceUpdate = 0;
      ts.occlusionFlag = false;

      if (ts.centroidHistory.length >= 2 && fps > 0) {
        final prev = ts.centroidHistory[ts.centroidHistory.length - 2];
        final disp = math.sqrt(
          math.pow(centroid.x - prev.x, 2) + math.pow(centroid.y - prev.y, 2),
        );
        ts.speedEstimateKmh = disp * fps * 3.6;
      }

      output[tid] = ts;
      matchedTids.add(tid);
      matchedDetIdx.add(dIdx);
    }

    final remaining = <Detection>[
      for (var i = 0; i < detections.length; i++)
        if (!matchedDetIdx.contains(i)) detections[i],
    ];

    return (matchedTids, remaining);
  }
}

/// Compute IoU between two sets of xyxy boxes → (M × N) matrix.
List<List<double>> _iouMatrix(
  List<List<double>> boxesA,
  List<List<double>> boxesB,
) {
  final m = boxesA.length;
  final n = boxesB.length;
  final result = List.generate(m, (_) => List<double>.filled(n, 0.0));

  for (var i = 0; i < m; i++) {
    final a = boxesA[i];
    final areaA = (a[2] - a[0]) * (a[3] - a[1]);
    for (var j = 0; j < n; j++) {
      final b = boxesB[j];
      final xx1 = math.max(a[0], b[0]);
      final yy1 = math.max(a[1], b[1]);
      final xx2 = math.min(a[2], b[2]);
      final yy2 = math.min(a[3], b[3]);
      final inter = math.max(0.0, xx2 - xx1) * math.max(0.0, yy2 - yy1);
      final areaB = (b[2] - b[0]) * (b[3] - b[1]);
      result[i][j] = inter / (areaA + areaB - inter + 1e-6);
    }
  }

  return result;
}

/// Greedy assignment on an IoU cost matrix (higher = better).
(List<(int, int)>, List<int>, List<int>) _greedyAssignment(
  List<List<double>> costMatrix,
  double threshold,
) {
  final m = costMatrix.length;
  if (m == 0) return ([], [], []);
  final n = costMatrix[0].length;
  if (n == 0) return ([], List<int>.generate(m, (i) => i), []);

  final entries = <(int, int, double)>[];
  for (var i = 0; i < m; i++) {
    for (var j = 0; j < n; j++) {
      entries.add((i, j, costMatrix[i][j]));
    }
  }
  entries.sort((a, b) => b.$3.compareTo(a.$3));

  final matchedRows = <int>{};
  final matchedCols = <int>{};
  final matches = <(int, int)>[];

  for (final (r, c, cost) in entries) {
    if (matchedRows.contains(r) || matchedCols.contains(c)) continue;
    if (cost < threshold) break;
    matches.add((r, c));
    matchedRows.add(r);
    matchedCols.add(c);
  }

  final unmatchedRows = [
    for (var i = 0; i < m; i++)
      if (!matchedRows.contains(i)) i,
  ];
  final unmatchedCols = [
    for (var j = 0; j < n; j++)
      if (!matchedCols.contains(j)) j,
  ];

  return (matches, unmatchedRows, unmatchedCols);
}
