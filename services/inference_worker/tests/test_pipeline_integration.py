"""Integration test: synthetic frame sequence through the full 5-stage pipeline."""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import numpy as np
import pytest

from inference_worker.event_publisher import EventPublisher
from inference_worker.models import Detection, FrameMetadata
from inference_worker.pipeline import InferencePipeline
from inference_worker.redis_state import RedisLiveState
from inference_worker.settings import Settings
from inference_worker.stages.classifier import StubClassifierBackend, VehicleClassifier
from inference_worker.stages.detector import VehicleDetector
from shared_contracts.enums import VehicleClass12
from shared_contracts.events import VehicleCrossingEvent
from shared_contracts.geometry import (
    BoundingBox,
    CountingLine,
    DirectionVector,
    Point2D,
)


class MovingVehicleDetectorBackend:
    """Simulates a vehicle moving downward across the frame over multiple frames.

    Moves slowly enough that IoU-based tracking can associate detections
    across consecutive frames (large bbox, small displacement).
    """

    def __init__(self):
        self._frame_count = 0

    def detect(self, preprocessed):
        y = 150 + self._frame_count * 15
        self._frame_count += 1
        return np.array([[[320, y, 120, 120, 0.92]]], dtype=np.float32)


class DeterministicClassifierBackend:
    """Always classifies as C02_BUS with high confidence."""

    def classify_batch(self, crops):
        n = crops.shape[0]
        logits = np.zeros((n, 12), dtype=np.float32)
        logits[:, 1] = 10.0
        return logits


@pytest.fixture
def mock_publisher():
    pub = AsyncMock(spec=EventPublisher)
    pub.publish_crossing = AsyncMock()
    pub.publish_track_event = AsyncMock()
    pub.upload_hard_example = AsyncMock()
    return pub


@pytest.fixture
def mock_redis():
    redis = AsyncMock(spec=RedisLiveState)
    redis.push_tracks = AsyncMock()
    redis.increment_crossing_count = AsyncMock()
    return redis


@pytest.fixture
def pipeline_settings():
    settings = Settings()
    settings.smoother.min_track_age = 2
    settings.tracker.min_hits = 2
    settings.tracker.max_age = 10
    settings.crossing.cooldown_frames = 0
    settings.crossing.min_displacement = 0.0
    settings.hard_example.enabled = False
    return settings


@pytest.mark.asyncio
async def test_full_pipeline_crossing_event(
    pipeline_settings, mock_publisher, mock_redis
):
    """Simulate a vehicle moving across a counting line and verify event emission."""
    detector = VehicleDetector(
        pipeline_settings.detector,
        backend=MovingVehicleDetectorBackend(),
    )
    classifier = VehicleClassifier(
        pipeline_settings.classifier,
        backend=DeterministicClassifierBackend(),
    )

    pipeline = InferencePipeline(
        settings=pipeline_settings,
        publisher=mock_publisher,
        redis_state=mock_redis,
        detector=detector,
        classifier=classifier,
    )

    counting_line = CountingLine(
        name="test_line",
        start=Point2D(x=0.0, y=0.5),
        end=Point2D(x=1.0, y=0.5),
        direction="bidirectional",
        direction_vector=DirectionVector(dx=0.0, dy=1.0),
    )
    pipeline.update_counting_lines("cam_001", [counting_line])

    frame = np.zeros((640, 640, 3), dtype=np.uint8)
    all_events: list[VehicleCrossingEvent] = []

    for i in range(10):
        metadata = FrameMetadata(
            camera_id="cam_001",
            frame_index=i,
            timestamp_utc=datetime.now(timezone.utc),
            org_id="org_1",
            site_id="site_1",
        )
        events = await pipeline.process_frame(
            frame=frame,
            frame_data=b"fake_jpeg",
            metadata=metadata,
        )
        all_events.extend(events)

    mock_redis.push_tracks.assert_called()

    cam_state = pipeline.get_camera_state("cam_001")
    assert cam_state is not None
    assert cam_state.last_frame_index == 9
    assert "cam_001" in pipeline.active_cameras


@pytest.mark.asyncio
async def test_pipeline_no_detections(pipeline_settings, mock_publisher, mock_redis):
    """Pipeline handles frames with no detections gracefully."""
    from inference_worker.stages.detector import StubDetectorBackend

    detector = VehicleDetector(
        pipeline_settings.detector,
        backend=StubDetectorBackend(),
    )

    pipeline = InferencePipeline(
        settings=pipeline_settings,
        publisher=mock_publisher,
        redis_state=mock_redis,
        detector=detector,
    )

    frame = np.zeros((480, 640, 3), dtype=np.uint8)
    metadata = FrameMetadata(
        camera_id="cam_empty",
        frame_index=0,
        timestamp_utc=datetime.now(timezone.utc),
    )

    events = await pipeline.process_frame(frame, b"fake", metadata)
    assert events == []
    mock_publisher.publish_crossing.assert_not_called()


@pytest.mark.asyncio
async def test_pipeline_multiple_cameras(
    pipeline_settings, mock_publisher, mock_redis
):
    """Pipeline maintains independent state per camera."""
    from inference_worker.stages.detector import StubDetectorBackend

    detector = VehicleDetector(
        pipeline_settings.detector,
        backend=StubDetectorBackend(),
    )

    pipeline = InferencePipeline(
        settings=pipeline_settings,
        publisher=mock_publisher,
        redis_state=mock_redis,
        detector=detector,
    )

    for cam_id in ["cam_a", "cam_b", "cam_c"]:
        metadata = FrameMetadata(
            camera_id=cam_id,
            frame_index=0,
            timestamp_utc=datetime.now(timezone.utc),
        )
        frame = np.zeros((480, 640, 3), dtype=np.uint8)
        await pipeline.process_frame(frame, b"fake", metadata)

    assert len(pipeline.active_cameras) == 3
    assert "cam_a" in pipeline.active_cameras
    assert "cam_b" in pipeline.active_cameras
    assert "cam_c" in pipeline.active_cameras


@pytest.mark.asyncio
async def test_track_events_emitted(pipeline_settings, mock_publisher, mock_redis):
    """Verify TrackStarted and TrackUpdated events are published."""
    detector = VehicleDetector(
        pipeline_settings.detector,
        backend=MovingVehicleDetectorBackend(),
    )
    classifier = VehicleClassifier(
        pipeline_settings.classifier,
        backend=DeterministicClassifierBackend(),
    )

    pipeline = InferencePipeline(
        settings=pipeline_settings,
        publisher=mock_publisher,
        redis_state=mock_redis,
        detector=detector,
        classifier=classifier,
    )

    frame = np.zeros((640, 640, 3), dtype=np.uint8)

    for i in range(5):
        metadata = FrameMetadata(
            camera_id="cam_track",
            frame_index=i,
            timestamp_utc=datetime.now(timezone.utc),
        )
        await pipeline.process_frame(frame, b"fake", metadata)

    assert mock_publisher.publish_track_event.call_count > 0
