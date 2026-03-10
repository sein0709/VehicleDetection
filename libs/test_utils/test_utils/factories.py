"""Test data factories for GreyEye event types.

These factories produce valid instances with sensible defaults, making it easy
to write concise tests that only override the fields they care about.
"""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import uuid4

from shared_contracts.enums import VehicleClass12
from shared_contracts.events import (
    CameraHealthEvent,
    TrackEvent,
    VehicleCrossingEvent,
)
from shared_contracts.geometry import BoundingBox, Point2D


def make_crossing_event(**overrides: object) -> VehicleCrossingEvent:
    defaults: dict[str, object] = {
        "timestamp_utc": datetime.now(tz=UTC),
        "camera_id": "cam_test_001",
        "line_id": "line_01",
        "track_id": f"trk_{uuid4().hex[:8]}",
        "crossing_seq": 1,
        "class12": VehicleClass12.C01_PASSENGER_MINITRUCK,
        "confidence": 0.92,
        "direction": "inbound",
        "model_version": "v0.1.0-test",
        "frame_index": 100,
        "org_id": "org_test",
        "site_id": "site_test",
    }
    defaults.update(overrides)
    return VehicleCrossingEvent(**defaults)  # type: ignore[arg-type]


def make_track_event(**overrides: object) -> TrackEvent:
    defaults: dict[str, object] = {
        "event_type": "TrackUpdated",
        "timestamp_utc": datetime.now(tz=UTC),
        "camera_id": "cam_test_001",
        "track_id": f"trk_{uuid4().hex[:8]}",
        "class12": VehicleClass12.C01_PASSENGER_MINITRUCK,
        "confidence": 0.88,
        "bbox": BoundingBox(x=0.3, y=0.4, w=0.1, h=0.08),
        "centroid": Point2D(x=0.35, y=0.44),
        "frame_index": 100,
    }
    defaults.update(overrides)
    return TrackEvent(**defaults)  # type: ignore[arg-type]


def make_camera_health_event(**overrides: object) -> CameraHealthEvent:
    defaults: dict[str, object] = {
        "timestamp_utc": datetime.now(tz=UTC),
        "camera_id": "cam_test_001",
        "status": "online",
        "fps_actual": 10.0,
    }
    defaults.update(overrides)
    return CameraHealthEvent(**defaults)  # type: ignore[arg-type]
