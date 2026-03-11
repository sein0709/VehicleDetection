/// Stage 5 — Line crossing detection.
///
/// Tests whether a track's centroid has crossed any configured counting line
/// between the current and previous frame using segment intersection
/// (cross-product method). Handles deduplication via per-track crossing
/// sequence numbers and cooldown windows.
///
/// Ported from `services/inference_worker/inference_worker/stages/line_crossing.py`.
library;

import 'dart:math' as math;

import 'package:greyeye_mobile/core/inference/models.dart';
import 'package:greyeye_mobile/core/inference/pipeline_settings.dart';

class LineCrossingDetector {
  LineCrossingDetector(this._settings);

  final CrossingSettings _settings;

  /// Check a single track against all counting lines.
  ///
  /// Applies cooldown deduplication and minimum displacement filtering.
  /// Returns a list of confirmed crossings (usually 0 or 1).
  List<CrossingResult> checkCrossings(
    TrackState track,
    List<CountingLine> countingLines,
    int frameIndex,
  ) {
    if (track.centroidHistory.length < 2) return [];

    final prev = track.centroidHistory[track.centroidHistory.length - 2];
    final curr = track.centroidHistory.last;

    final displacement = math.sqrt(
      math.pow(curr.x - prev.x, 2) + math.pow(curr.y - prev.y, 2),
    );
    if (displacement < _settings.minDisplacement) return [];

    final results = <CrossingResult>[];

    for (final line in countingLines) {
      final lineId = line.name;

      final lastFrame = track.lastCrossingFrame[lineId] ?? -999;
      if ((frameIndex - lastFrame) < _settings.cooldownFrames) continue;

      final crossing = _checkSingleCrossing(prev, curr, line);
      if (crossing != null) {
        final seq = (track.crossingSequences[lineId] ?? 0) + 1;
        track.crossingSequences[lineId] = seq;
        track.lastCrossingFrame[lineId] = frameIndex;
        results.add(crossing);
      }
    }

    return results;
  }
}

CrossingResult? _checkSingleCrossing(
  Point2D prevCentroid,
  Point2D currCentroid,
  CountingLine countingLine,
) {
  final p1 = (prevCentroid.x, prevCentroid.y);
  final p2 = (currCentroid.x, currCentroid.y);
  final q1 = (countingLine.start.x, countingLine.start.y);
  final q2 = (countingLine.end.x, countingLine.end.y);

  if (!_segmentsIntersect(p1, p2, q1, q2)) return null;

  final direction =
      _determineDirection(prevCentroid, currCentroid, countingLine);

  final lineDir = countingLine.direction.toLowerCase();
  if (lineDir != 'bidirectional' && lineDir != direction) return null;

  return CrossingResult(
    lineId: countingLine.name,
    lineName: countingLine.name,
    direction: direction,
  );
}

/// 2D cross product of vectors (OA) × (OB).
double _crossProduct(
  (double, double) o,
  (double, double) a,
  (double, double) b,
) {
  return (a.$1 - o.$1) * (b.$2 - o.$2) - (a.$2 - o.$2) * (b.$1 - o.$1);
}

/// Test whether line segments (p1–p2) and (q1–q2) properly intersect.
bool _segmentsIntersect(
  (double, double) p1,
  (double, double) p2,
  (double, double) q1,
  (double, double) q2,
) {
  final d1 = _crossProduct(q1, q2, p1);
  final d2 = _crossProduct(q1, q2, p2);
  final d3 = _crossProduct(p1, p2, q1);
  final d4 = _crossProduct(p1, p2, q2);

  if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
    return true;
  }

  return false;
}

/// Determine crossing direction relative to the counting line's direction vector.
String _determineDirection(
  Point2D prev,
  Point2D curr,
  CountingLine line,
) {
  final dx = curr.x - prev.x;
  final dy = curr.y - prev.y;

  // Use explicit direction vector if available, otherwise derive a perpendicular
  // from the line endpoints (rotated 90° clockwise).
  final dirVec = line.directionVector;
  final dvx = dirVec?.x ?? (line.end.y - line.start.y);
  final dvy = dirVec?.y ?? -(line.end.x - line.start.x);

  final dot = dx * dvx + dy * dvy;
  return dot > 0 ? 'inbound' : 'outbound';
}
