"""Tests for Stage 4: Temporal Smoothing."""

from __future__ import annotations

import pytest

from inference_worker.models import ClassPrediction
from inference_worker.stages.smoother import (
    TemporalSmoother,
    smooth_ema,
    smooth_majority,
)
from shared_contracts.enums import VehicleClass12
from shared_contracts.geometry import BoundingBox


def _pred(cls: VehicleClass12, conf: float = 0.9) -> ClassPrediction:
    probs = [0.0] * 12
    probs[cls.value - 1] = conf
    remaining = (1.0 - conf) / 11
    for i in range(12):
        if i != cls.value - 1:
            probs[i] = remaining
    return ClassPrediction(
        class12=cls,
        probabilities=probs,
        confidence=conf,
        crop_bbox=BoundingBox(x=0.1, y=0.1, w=0.2, h=0.2),
    )


class TestMajorityVoting:
    def test_unanimous_vote(self):
        history = [_pred(VehicleClass12.C01_PASSENGER_MINITRUCK)] * 5
        result = smooth_majority(history, window=5)
        assert result.class12 == VehicleClass12.C01_PASSENGER_MINITRUCK
        assert result.confidence == 1.0

    def test_majority_wins(self):
        history = [
            _pred(VehicleClass12.C01_PASSENGER_MINITRUCK),
            _pred(VehicleClass12.C02_BUS),
            _pred(VehicleClass12.C01_PASSENGER_MINITRUCK),
            _pred(VehicleClass12.C01_PASSENGER_MINITRUCK),
            _pred(VehicleClass12.C02_BUS),
        ]
        result = smooth_majority(history, window=5)
        assert result.class12 == VehicleClass12.C01_PASSENGER_MINITRUCK
        assert result.confidence == pytest.approx(3 / 5)

    def test_window_limits_history(self):
        old = [_pred(VehicleClass12.C02_BUS)] * 10
        recent = [_pred(VehicleClass12.C01_PASSENGER_MINITRUCK)] * 5
        history = old + recent
        result = smooth_majority(history, window=5)
        assert result.class12 == VehicleClass12.C01_PASSENGER_MINITRUCK


class TestEMA:
    def test_single_prediction(self):
        history = [_pred(VehicleClass12.C03_TRUCK_LT_2_5T, conf=0.9)]
        result = smooth_ema(history, alpha=0.3)
        assert result.class12 == VehicleClass12.C03_TRUCK_LT_2_5T

    def test_converges_to_dominant(self):
        history = [_pred(VehicleClass12.C01_PASSENGER_MINITRUCK)] * 20
        result = smooth_ema(history, alpha=0.3)
        assert result.class12 == VehicleClass12.C01_PASSENGER_MINITRUCK
        assert result.confidence > 0.5


class TestTemporalSmoother:
    def test_returns_none_below_min_age(self, smoother_settings):
        smoother_settings.min_track_age = 3
        smoother = TemporalSmoother(smoother_settings)
        history = [_pred(VehicleClass12.C01_PASSENGER_MINITRUCK)]
        assert smoother.smooth(history, track_age=1) is None

    def test_returns_result_at_min_age(self, smoother_settings):
        smoother_settings.min_track_age = 3
        smoother = TemporalSmoother(smoother_settings)
        history = [_pred(VehicleClass12.C01_PASSENGER_MINITRUCK)] * 3
        result = smoother.smooth(history, track_age=3)
        assert result is not None
        assert result.class12 == VehicleClass12.C01_PASSENGER_MINITRUCK

    def test_majority_strategy(self, smoother_settings):
        smoother_settings.strategy = "majority"
        smoother = TemporalSmoother(smoother_settings)
        history = [_pred(VehicleClass12.C02_BUS)] * 5
        result = smoother.smooth(history, track_age=5)
        assert result.class12 == VehicleClass12.C02_BUS

    def test_ema_strategy(self, smoother_settings):
        smoother_settings.strategy = "ema"
        smoother = TemporalSmoother(smoother_settings)
        history = [_pred(VehicleClass12.C04_TRUCK_2_5_TO_8_5T)] * 5
        result = smoother.smooth(history, track_age=5)
        assert result.class12 == VehicleClass12.C04_TRUCK_2_5_TO_8_5T

    def test_detect_class_flip(self, smoother_settings):
        smoother = TemporalSmoother(smoother_settings)
        history = [_pred(VehicleClass12.C01_PASSENGER_MINITRUCK)]
        assert smoother.detect_class_flip(
            history,
            VehicleClass12.C02_BUS,
            VehicleClass12.C01_PASSENGER_MINITRUCK,
        )
        assert not smoother.detect_class_flip(
            history,
            VehicleClass12.C01_PASSENGER_MINITRUCK,
            VehicleClass12.C01_PASSENGER_MINITRUCK,
        )
        assert not smoother.detect_class_flip(history, None, VehicleClass12.C01_PASSENGER_MINITRUCK)
