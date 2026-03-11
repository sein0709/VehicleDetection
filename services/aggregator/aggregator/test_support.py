"""Test-only helpers for the aggregator package."""

from __future__ import annotations

from datetime import UTC, datetime

from shared_contracts.enums import VehicleClass12
from shared_contracts.events import VehicleCrossingEvent


def make_crossing_event(
    *,
    camera_id: str = "cam_001",
    line_id: str = "line_A",
    class12: VehicleClass12 = VehicleClass12.C01_PASSENGER_MINITRUCK,
    direction: str = "inbound",
    confidence: float = 0.95,
    speed_estimate_kmh: float | None = 60.0,
    timestamp_utc: datetime | None = None,
    org_id: str = "org_1",
    site_id: str = "site_1",
    track_id: str = "track_001",
    crossing_seq: int = 1,
) -> VehicleCrossingEvent:
    if timestamp_utc is None:
        timestamp_utc = datetime(2025, 6, 15, 10, 7, 30, tzinfo=UTC)
    return VehicleCrossingEvent(
        camera_id=camera_id,
        line_id=line_id,
        track_id=track_id,
        crossing_seq=crossing_seq,
        class12=class12,
        confidence=confidence,
        direction=direction,
        model_version="v1.0",
        frame_index=100,
        speed_estimate_kmh=speed_estimate_kmh,
        org_id=org_id,
        site_id=site_id,
        timestamp_utc=timestamp_utc,
    )
