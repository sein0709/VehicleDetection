"""Tests for hard-example collection."""

from __future__ import annotations

from datetime import datetime, timezone

import numpy as np
import pytest

from inference_worker.hard_examples import HardExampleCollector
from inference_worker.models import ClassPrediction, SmoothedPrediction, TrackState
from shared_contracts.enums import VehicleClass12
from shared_contracts.geometry import BoundingBox, Point2D


def _smoothed(cls: VehicleClass12, conf: float) -> SmoothedPrediction:
    probs = [0.0] * 12
    probs[cls.value - 1] = conf
    raw = ClassPrediction(
        class12=cls,
        probabilities=probs,
        confidence=conf,
        crop_bbox=BoundingBox(x=0.1, y=0.1, w=0.2, h=0.2),
    )
    return SmoothedPrediction(
        class12=cls,
        confidence=conf,
        probabilities=probs,
        raw_prediction=raw,
    )


def _track(track_id: str = "trk_00001") -> TrackState:
    return TrackState(
        track_id=track_id,
        bbox=BoundingBox(x=0.1, y=0.1, w=0.2, h=0.2),
        centroid=Point2D(x=0.2, y=0.2),
        first_seen_frame=0,
        last_seen_frame=5,
        age=5,
        hits=5,
        is_confirmed=True,
    )


class TestHardExampleCollector:
    def test_low_confidence_trigger(self, hard_example_settings):
        hard_example_settings.confidence_threshold = 0.5
        collector = HardExampleCollector(hard_example_settings)

        frame = np.zeros((100, 100, 3), dtype=np.uint8)
        smoothed = _smoothed(VehicleClass12.C01_PASSENGER_MINITRUCK, conf=0.3)

        he = collector.check_and_collect(
            track=_track(),
            smoothed=smoothed,
            previous_class=VehicleClass12.C01_PASSENGER_MINITRUCK,
            frame_data=b"fake_jpeg",
            frame=frame,
            camera_id="cam1",
            frame_index=5,
            timestamp_utc=datetime.now(timezone.utc),
            model_version="v0.1.0",
        )
        assert he is not None
        assert he.trigger_reason == "low_confidence"

    def test_class_flip_trigger(self, hard_example_settings):
        hard_example_settings.confidence_threshold = 0.1
        collector = HardExampleCollector(hard_example_settings)

        frame = np.zeros((100, 100, 3), dtype=np.uint8)
        smoothed = _smoothed(VehicleClass12.C02_BUS, conf=0.8)

        he = collector.check_and_collect(
            track=_track(),
            smoothed=smoothed,
            previous_class=VehicleClass12.C01_PASSENGER_MINITRUCK,
            frame_data=b"fake_jpeg",
            frame=frame,
            camera_id="cam1",
            frame_index=5,
            timestamp_utc=datetime.now(timezone.utc),
            model_version="v0.1.0",
        )
        assert he is not None
        assert he.trigger_reason == "class_flip"

    def test_rare_class_trigger(self, hard_example_settings):
        hard_example_settings.confidence_threshold = 0.1
        collector = HardExampleCollector(hard_example_settings)

        frame = np.zeros((100, 100, 3), dtype=np.uint8)
        smoothed = _smoothed(VehicleClass12.C08_SEMI_4_AXLE, conf=0.9)

        he = collector.check_and_collect(
            track=_track(),
            smoothed=smoothed,
            previous_class=VehicleClass12.C08_SEMI_4_AXLE,
            frame_data=b"fake_jpeg",
            frame=frame,
            camera_id="cam1",
            frame_index=5,
            timestamp_utc=datetime.now(timezone.utc),
            model_version="v0.1.0",
        )
        assert he is not None
        assert he.trigger_reason == "rare_class"

    def test_no_trigger_for_high_conf_common_class(self, hard_example_settings):
        collector = HardExampleCollector(hard_example_settings)

        frame = np.zeros((100, 100, 3), dtype=np.uint8)
        smoothed = _smoothed(VehicleClass12.C01_PASSENGER_MINITRUCK, conf=0.9)

        he = collector.check_and_collect(
            track=_track(),
            smoothed=smoothed,
            previous_class=VehicleClass12.C01_PASSENGER_MINITRUCK,
            frame_data=b"fake_jpeg",
            frame=frame,
            camera_id="cam1",
            frame_index=5,
            timestamp_utc=datetime.now(timezone.utc),
            model_version="v0.1.0",
        )
        assert he is None

    def test_disabled_returns_none(self, hard_example_settings):
        hard_example_settings.enabled = False
        collector = HardExampleCollector(hard_example_settings)

        frame = np.zeros((100, 100, 3), dtype=np.uint8)
        smoothed = _smoothed(VehicleClass12.C01_PASSENGER_MINITRUCK, conf=0.1)

        he = collector.check_and_collect(
            track=_track(),
            smoothed=smoothed,
            previous_class=None,
            frame_data=b"fake_jpeg",
            frame=frame,
            camera_id="cam1",
            frame_index=5,
            timestamp_utc=datetime.now(timezone.utc),
            model_version="v0.1.0",
        )
        assert he is None

    def test_rate_limiting(self, hard_example_settings):
        hard_example_settings.max_per_hour = 2
        hard_example_settings.confidence_threshold = 0.5
        collector = HardExampleCollector(hard_example_settings)

        frame = np.zeros((100, 100, 3), dtype=np.uint8)
        smoothed = _smoothed(VehicleClass12.C01_PASSENGER_MINITRUCK, conf=0.3)

        results = []
        for i in range(5):
            he = collector.check_and_collect(
                track=_track(f"trk_{i:05d}"),
                smoothed=smoothed,
                previous_class=VehicleClass12.C01_PASSENGER_MINITRUCK,
                frame_data=b"fake_jpeg",
                frame=frame,
                camera_id="cam1",
                frame_index=i,
                timestamp_utc=datetime.now(timezone.utc),
                model_version="v0.1.0",
            )
            results.append(he)

        collected = [r for r in results if r is not None]
        assert len(collected) == 2
