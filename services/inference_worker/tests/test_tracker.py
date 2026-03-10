"""Tests for Stage 2: Multi-Object Tracking (ByteTrack)."""

from __future__ import annotations

import pytest

from inference_worker.models import Detection, TrackState
from inference_worker.stages.tracker import ByteTracker, _iou_matrix

import numpy as np

from shared_contracts.geometry import BoundingBox, Point2D


@pytest.fixture
def tracker(tracker_settings):
    tracker_settings.min_hits = 2
    tracker_settings.max_age = 5
    tracker_settings.iou_threshold = 0.3
    return ByteTracker(tracker_settings, camera_id="cam_test")


def _det(x, y, w, h, conf=0.9, frame=0):
    return Detection(
        bbox=BoundingBox(x=x, y=y, w=w, h=h),
        confidence=conf,
        frame_index=frame,
    )


class TestIoUMatrix:
    def test_identical_boxes(self):
        boxes = np.array([[0.1, 0.1, 0.3, 0.3]], dtype=np.float32)
        iou = _iou_matrix(boxes, boxes)
        assert iou[0, 0] == pytest.approx(1.0, abs=1e-4)

    def test_non_overlapping(self):
        a = np.array([[0.0, 0.0, 0.1, 0.1]], dtype=np.float32)
        b = np.array([[0.5, 0.5, 0.6, 0.6]], dtype=np.float32)
        iou = _iou_matrix(a, b)
        assert iou[0, 0] == pytest.approx(0.0, abs=1e-4)

    def test_empty_inputs(self):
        a = np.empty((0, 4), dtype=np.float32)
        b = np.array([[0.1, 0.1, 0.3, 0.3]], dtype=np.float32)
        iou = _iou_matrix(a, b)
        assert iou.shape == (0, 1)


class TestByteTracker:
    def test_new_detection_creates_tentative_track(self, tracker):
        dets = [_det(0.1, 0.1, 0.2, 0.2)]
        tracks = tracker.update(dets, {}, frame_index=0)
        assert len(tracks) == 1
        t = list(tracks.values())[0]
        assert not t.is_confirmed
        assert t.hits == 1

    def test_track_confirmed_after_min_hits(self, tracker):
        tracks = {}
        for i in range(3):
            dets = [_det(0.1, 0.1, 0.2, 0.2, frame=i)]
            tracks = tracker.update(dets, tracks, frame_index=i)

        confirmed = [t for t in tracks.values() if t.is_confirmed]
        assert len(confirmed) >= 1

    def test_track_deleted_after_max_age(self, tracker):
        dets = [_det(0.1, 0.1, 0.2, 0.2)]
        tracks = tracker.update(dets, {}, frame_index=0)

        for i in range(1, 10):
            tracks = tracker.update([], tracks, frame_index=i)

        assert len(tracks) == 0

    def test_multiple_detections_create_multiple_tracks(self, tracker):
        dets = [
            _det(0.1, 0.1, 0.1, 0.1),
            _det(0.6, 0.6, 0.1, 0.1),
        ]
        tracks = tracker.update(dets, {}, frame_index=0)
        assert len(tracks) == 2

    def test_centroid_history_grows(self, tracker):
        tracks = {}
        for i in range(5):
            x = 0.1 + i * 0.02
            dets = [_det(x, 0.1, 0.2, 0.2, frame=i)]
            tracks = tracker.update(dets, tracks, frame_index=i)

        t = list(tracks.values())[0]
        assert len(t.centroid_history) >= 3

    def test_speed_estimate_computed(self, tracker):
        tracks = {}
        for i in range(5):
            x = 0.1 + i * 0.05
            dets = [_det(x, 0.1, 0.2, 0.2, frame=i)]
            tracks = tracker.update(dets, tracks, frame_index=i, fps=10.0)

        t = list(tracks.values())[0]
        assert t.speed_estimate_kmh is not None
        assert t.speed_estimate_kmh > 0

    def test_occlusion_flag_set_on_miss(self, tracker):
        dets = [_det(0.1, 0.1, 0.2, 0.2)]
        tracks = tracker.update(dets, {}, frame_index=0)
        tracks = tracker.update(dets, tracks, frame_index=1)
        tracks = tracker.update(dets, tracks, frame_index=2)

        tracks = tracker.update([], tracks, frame_index=3)
        occluded = [t for t in tracks.values() if t.occlusion_flag]
        assert len(occluded) >= 1
