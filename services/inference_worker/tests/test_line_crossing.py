"""Tests for Stage 5: Line Crossing Detection."""

from __future__ import annotations

import pytest

from inference_worker.models import TrackState
from inference_worker.stages.line_crossing import (
    LineCrossingDetector,
    _segments_intersect,
    check_single_crossing,
)
from shared_contracts.geometry import (
    BoundingBox,
    CountingLine,
    DirectionVector,
    Point2D,
)


class TestSegmentIntersection:
    def test_crossing_segments(self):
        assert _segments_intersect(
            (0.0, 0.0), (1.0, 1.0),
            (0.0, 1.0), (1.0, 0.0),
        )

    def test_parallel_segments(self):
        assert not _segments_intersect(
            (0.0, 0.0), (1.0, 0.0),
            (0.0, 1.0), (1.0, 1.0),
        )

    def test_non_crossing_segments(self):
        assert not _segments_intersect(
            (0.0, 0.0), (0.5, 0.0),
            (0.6, 0.0), (1.0, 0.0),
        )

    def test_t_shaped_no_cross(self):
        assert not _segments_intersect(
            (0.0, 0.5), (0.4, 0.5),
            (0.5, 0.0), (0.5, 1.0),
        )


class TestCheckSingleCrossing:
    def test_crossing_detected(self, horizontal_counting_line):
        prev = Point2D(x=0.5, y=0.3)
        curr = Point2D(x=0.5, y=0.7)
        result = check_single_crossing(prev, curr, horizontal_counting_line)
        assert result is not None
        assert result.direction == "inbound"

    def test_no_crossing(self, horizontal_counting_line):
        prev = Point2D(x=0.5, y=0.3)
        curr = Point2D(x=0.5, y=0.4)
        result = check_single_crossing(prev, curr, horizontal_counting_line)
        assert result is None

    def test_outbound_crossing(self, horizontal_counting_line):
        prev = Point2D(x=0.5, y=0.7)
        curr = Point2D(x=0.5, y=0.3)
        result = check_single_crossing(prev, curr, horizontal_counting_line)
        assert result is not None
        assert result.direction == "outbound"

    def test_inbound_only_line_blocks_outbound(self, inbound_only_line):
        prev = Point2D(x=0.5, y=0.8)
        curr = Point2D(x=0.5, y=0.4)
        result = check_single_crossing(prev, curr, inbound_only_line)
        assert result is None

    def test_inbound_only_line_allows_inbound(self, inbound_only_line):
        prev = Point2D(x=0.5, y=0.4)
        curr = Point2D(x=0.5, y=0.8)
        result = check_single_crossing(prev, curr, inbound_only_line)
        assert result is not None
        assert result.direction == "inbound"


class TestLineCrossingDetector:
    def test_cooldown_suppresses_rapid_crossings(
        self, crossing_settings, horizontal_counting_line
    ):
        crossing_settings.cooldown_frames = 5
        crossing_settings.min_displacement = 0.0
        detector = LineCrossingDetector(crossing_settings)

        track = TrackState(
            track_id="trk_00001",
            bbox=BoundingBox(x=0.4, y=0.3, w=0.2, h=0.2),
            centroid=Point2D(x=0.5, y=0.7),
            centroid_history=[Point2D(x=0.5, y=0.3), Point2D(x=0.5, y=0.7)],
            first_seen_frame=0,
            last_seen_frame=1,
            age=2,
            hits=2,
            is_confirmed=True,
        )

        results = detector.check_crossings(
            track, [horizontal_counting_line], frame_index=1
        )
        assert len(results) == 1

        track.centroid_history.append(Point2D(x=0.5, y=0.3))
        results = detector.check_crossings(
            track, [horizontal_counting_line], frame_index=2
        )
        assert len(results) == 0

    def test_min_displacement_filter(
        self, crossing_settings, horizontal_counting_line
    ):
        crossing_settings.min_displacement = 0.5
        detector = LineCrossingDetector(crossing_settings)

        track = TrackState(
            track_id="trk_00002",
            bbox=BoundingBox(x=0.4, y=0.49, w=0.2, h=0.02),
            centroid=Point2D(x=0.5, y=0.51),
            centroid_history=[Point2D(x=0.5, y=0.49), Point2D(x=0.5, y=0.51)],
            first_seen_frame=0,
            last_seen_frame=1,
            age=2,
            hits=2,
            is_confirmed=True,
        )

        results = detector.check_crossings(
            track, [horizontal_counting_line], frame_index=1
        )
        assert len(results) == 0

    def test_crossing_increments_sequence(
        self, crossing_settings, horizontal_counting_line
    ):
        crossing_settings.cooldown_frames = 0
        crossing_settings.min_displacement = 0.0
        detector = LineCrossingDetector(crossing_settings)

        track = TrackState(
            track_id="trk_00003",
            bbox=BoundingBox(x=0.4, y=0.3, w=0.2, h=0.2),
            centroid=Point2D(x=0.5, y=0.7),
            centroid_history=[Point2D(x=0.5, y=0.3), Point2D(x=0.5, y=0.7)],
            first_seen_frame=0,
            last_seen_frame=1,
            age=2,
            hits=2,
            is_confirmed=True,
        )

        detector.check_crossings(track, [horizontal_counting_line], frame_index=1)
        assert track.crossing_sequences.get("line_1") == 1

        track.centroid_history.append(Point2D(x=0.5, y=0.3))
        detector.check_crossings(track, [horizontal_counting_line], frame_index=2)
        assert track.crossing_sequences.get("line_1") == 2
