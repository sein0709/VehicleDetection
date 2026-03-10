"""Tests for Stage 1: Vehicle Detection."""

from __future__ import annotations

import numpy as np
import pytest

from inference_worker.stages.detector import (
    StubDetectorBackend,
    VehicleDetector,
    _letterbox,
    _nms,
)


class TestLetterbox:
    def test_square_image(self):
        img = np.zeros((640, 640, 3), dtype=np.uint8)
        padded, scale, (pw, ph) = _letterbox(img, 640)
        assert padded.shape == (640, 640, 3)
        assert scale == 1.0
        assert pw == 0
        assert ph == 0

    def test_landscape_image(self):
        img = np.zeros((540, 960, 3), dtype=np.uint8)
        padded, scale, (pw, ph) = _letterbox(img, 640)
        assert padded.shape == (640, 640, 3)
        assert abs(scale - 640 / 960) < 1e-5

    def test_portrait_image(self):
        img = np.zeros((1080, 720, 3), dtype=np.uint8)
        padded, scale, (pw, ph) = _letterbox(img, 640)
        assert padded.shape == (640, 640, 3)
        assert abs(scale - 640 / 1080) < 1e-5


class TestNMS:
    def test_empty_input(self):
        boxes = np.empty((0, 4), dtype=np.float32)
        scores = np.empty(0, dtype=np.float32)
        assert _nms(boxes, scores, 0.5) == []

    def test_single_box(self):
        boxes = np.array([[10, 10, 50, 50]], dtype=np.float32)
        scores = np.array([0.9], dtype=np.float32)
        assert _nms(boxes, scores, 0.5) == [0]

    def test_overlapping_boxes(self):
        boxes = np.array(
            [[10, 10, 50, 50], [12, 12, 52, 52], [100, 100, 150, 150]],
            dtype=np.float32,
        )
        scores = np.array([0.9, 0.8, 0.7], dtype=np.float32)
        keep = _nms(boxes, scores, 0.5)
        assert 0 in keep
        assert 2 in keep
        assert len(keep) == 2

    def test_non_overlapping_boxes(self):
        boxes = np.array(
            [[0, 0, 10, 10], [100, 100, 110, 110]],
            dtype=np.float32,
        )
        scores = np.array([0.9, 0.8], dtype=np.float32)
        keep = _nms(boxes, scores, 0.5)
        assert len(keep) == 2


class TestVehicleDetector:
    def test_stub_backend_returns_empty(self, detector_settings):
        detector = VehicleDetector(detector_settings, backend=StubDetectorBackend())
        frame = np.zeros((480, 640, 3), dtype=np.uint8)
        detections = detector.detect_frame(frame, frame_index=0)
        assert detections == []

    def test_custom_backend(self, detector_settings):
        class FakeBackend:
            def detect(self, preprocessed):
                return np.array([[[320, 320, 100, 100, 0.95]]], dtype=np.float32)

        detector = VehicleDetector(detector_settings, backend=FakeBackend())
        frame = np.zeros((640, 640, 3), dtype=np.uint8)
        detections = detector.detect_frame(frame, frame_index=5)

        assert len(detections) == 1
        d = detections[0]
        assert d.confidence == pytest.approx(0.95)
        assert d.frame_index == 5
        assert 0.0 <= d.bbox.x <= 1.0
        assert 0.0 <= d.bbox.y <= 1.0
        assert d.bbox.w > 0
        assert d.bbox.h > 0

    def test_confidence_filtering(self, detector_settings):
        detector_settings.confidence_threshold = 0.5

        class LowConfBackend:
            def detect(self, preprocessed):
                return np.array(
                    [[[320, 320, 50, 50, 0.3], [100, 100, 50, 50, 0.8]]],
                    dtype=np.float32,
                )

        detector = VehicleDetector(detector_settings, backend=LowConfBackend())
        frame = np.zeros((640, 640, 3), dtype=np.uint8)
        detections = detector.detect_frame(frame, frame_index=0)
        assert len(detections) == 1
        assert detections[0].confidence == pytest.approx(0.8)

    def test_max_detections_limit(self, detector_settings):
        detector_settings.max_detections = 2

        class ManyDetBackend:
            def detect(self, preprocessed):
                dets = [[100 * i, 100 * i, 50, 50, 0.9] for i in range(1, 6)]
                return np.array([dets], dtype=np.float32)

        detector = VehicleDetector(detector_settings, backend=ManyDetBackend())
        frame = np.zeros((640, 640, 3), dtype=np.uint8)
        detections = detector.detect_frame(frame, frame_index=0)
        assert len(detections) <= 2
