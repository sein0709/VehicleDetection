"""Stage 5 -- Line crossing detection.

Tests whether a track's centroid has crossed any configured counting line
between the current and previous frame using segment intersection (cross-product
method).  Handles deduplication via per-track crossing sequence numbers and
cooldown windows.
"""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING

from inference_worker.models import CrossingResult, TrackState
from shared_contracts.geometry import CountingLine, Point2D

if TYPE_CHECKING:
    from inference_worker.settings import CrossingSettings

logger = logging.getLogger(__name__)


def _cross_product(o: tuple[float, float], a: tuple[float, float], b: tuple[float, float]) -> float:
    """2D cross product of vectors (OA) x (OB)."""
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def _segments_intersect(
    p1: tuple[float, float],
    p2: tuple[float, float],
    q1: tuple[float, float],
    q2: tuple[float, float],
) -> bool:
    """Test whether line segments (p1-p2) and (q1-q2) intersect."""
    d1 = _cross_product(q1, q2, p1)
    d2 = _cross_product(q1, q2, p2)
    d3 = _cross_product(p1, p2, q1)
    d4 = _cross_product(p1, p2, q2)

    if ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and (
        (d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)
    ):
        return True

    return False


def _determine_direction(
    prev: Point2D,
    curr: Point2D,
    line: CountingLine,
) -> str:
    """Determine crossing direction relative to the counting line's direction vector."""
    dx = curr.x - prev.x
    dy = curr.y - prev.y
    dot = dx * line.direction_vector.dx + dy * line.direction_vector.dy
    return "inbound" if dot > 0 else "outbound"


def check_single_crossing(
    prev_centroid: Point2D,
    curr_centroid: Point2D,
    counting_line: CountingLine,
) -> CrossingResult | None:
    """Check if the centroid path crosses a single counting line.

    Returns a CrossingResult if a valid crossing occurred, None otherwise.
    """
    p1 = (prev_centroid.x, prev_centroid.y)
    p2 = (curr_centroid.x, curr_centroid.y)
    q1 = (counting_line.start.x, counting_line.start.y)
    q2 = (counting_line.end.x, counting_line.end.y)

    if not _segments_intersect(p1, p2, q1, q2):
        return None

    direction = _determine_direction(prev_centroid, curr_centroid, counting_line)

    line_dir = counting_line.direction.lower()
    if line_dir != "bidirectional" and line_dir != direction:
        return None

    return CrossingResult(
        line_id=counting_line.name,
        line_name=counting_line.name,
        direction=direction,
    )


class LineCrossingDetector:
    """Stage 5: detect counting-line crossings for all active tracks."""

    def __init__(self, settings: CrossingSettings) -> None:
        self._settings = settings

    def check_crossings(
        self,
        track: TrackState,
        counting_lines: list[CountingLine],
        frame_index: int,
    ) -> list[CrossingResult]:
        """Check a single track against all counting lines.

        Applies cooldown deduplication and minimum displacement filtering.
        Returns a list of confirmed crossings (usually 0 or 1).
        """
        if len(track.centroid_history) < 2:
            return []

        prev = track.centroid_history[-2]
        curr = track.centroid_history[-1]

        displacement = ((curr.x - prev.x) ** 2 + (curr.y - prev.y) ** 2) ** 0.5
        if displacement < self._settings.min_displacement:
            return []

        results: list[CrossingResult] = []

        for line in counting_lines:
            line_id = line.name

            last_frame = track.last_crossing_frame.get(line_id, -999)
            if (frame_index - last_frame) < self._settings.cooldown_frames:
                continue

            crossing = check_single_crossing(prev, curr, line)
            if crossing is not None:
                seq = track.crossing_sequences.get(line_id, 0) + 1
                track.crossing_sequences[line_id] = seq
                track.last_crossing_frame[line_id] = frame_index
                results.append(crossing)

        return results
