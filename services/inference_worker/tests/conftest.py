"""Shared test fixtures for the inference worker."""

from __future__ import annotations

import numpy as np
import pytest

from inference_worker.settings import (
    ClassifierSettings,
    CrossingSettings,
    DetectorSettings,
    HardExampleSettings,
    Settings,
    SmootherSettings,
    TrackerSettings,
)
from shared_contracts.geometry import CountingLine, DirectionVector, Point2D


@pytest.fixture
def default_settings() -> Settings:
    return Settings()


@pytest.fixture
def detector_settings() -> DetectorSettings:
    return DetectorSettings()


@pytest.fixture
def tracker_settings() -> TrackerSettings:
    return TrackerSettings()


@pytest.fixture
def classifier_settings() -> ClassifierSettings:
    return ClassifierSettings()


@pytest.fixture
def smoother_settings() -> SmootherSettings:
    return SmootherSettings()


@pytest.fixture
def crossing_settings() -> CrossingSettings:
    return CrossingSettings()


@pytest.fixture
def hard_example_settings() -> HardExampleSettings:
    return HardExampleSettings()


@pytest.fixture
def sample_frame() -> np.ndarray:
    """A 1080x1920 synthetic frame with some structure."""
    frame = np.zeros((1080, 1920, 3), dtype=np.uint8)
    frame[200:400, 300:600] = [128, 128, 128]
    frame[500:700, 800:1200] = [64, 64, 200]
    return frame


@pytest.fixture
def small_frame() -> np.ndarray:
    """A 480x640 synthetic frame."""
    return np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)


@pytest.fixture
def horizontal_counting_line() -> CountingLine:
    """A horizontal counting line across the middle of the frame."""
    return CountingLine(
        name="line_1",
        start=Point2D(x=0.1, y=0.5),
        end=Point2D(x=0.9, y=0.5),
        direction="bidirectional",
        direction_vector=DirectionVector(dx=0.0, dy=1.0),
    )


@pytest.fixture
def inbound_only_line() -> CountingLine:
    """A counting line that only registers inbound crossings."""
    return CountingLine(
        name="line_inbound",
        start=Point2D(x=0.0, y=0.6),
        end=Point2D(x=1.0, y=0.6),
        direction="inbound",
        direction_vector=DirectionVector(dx=0.0, dy=1.0),
    )
