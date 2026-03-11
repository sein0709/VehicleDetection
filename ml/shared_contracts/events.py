"""Event schemas published to the NATS JetStream event bus.

These Pydantic models are the wire-format contracts shared between the
Inference Worker (publisher) and downstream consumers (Aggregation Service,
Notification Service, Live Monitor).
"""

from __future__ import annotations

from datetime import datetime  # noqa: TC003
from typing import Literal
from uuid import UUID, uuid4

from pydantic import BaseModel, Field

from .enums import AlertSeverity, VehicleClass12  # noqa: TC001
from .geometry import BoundingBox, Point2D  # noqa: TC001

BUCKET_DURATION_MINUTES = 15


class VehicleCrossingEvent(BaseModel):
    """Atomic unit of counting truth — emitted when a track crosses a counting line."""

    event_type: Literal["VehicleCrossingEvent"] = "VehicleCrossingEvent"
    version: str = "1.0"
    event_id: UUID = Field(default_factory=uuid4)
    timestamp_utc: datetime
    camera_id: str
    line_id: str
    track_id: str
    crossing_seq: int = Field(ge=1)
    class12: VehicleClass12
    confidence: float = Field(ge=0.0, le=1.0)
    direction: Literal["inbound", "outbound"]
    model_version: str
    frame_index: int
    speed_estimate_kmh: float | None = None
    bbox: BoundingBox | None = None
    org_id: str
    site_id: str

    @property
    def dedup_key(self) -> str:
        return f"{self.camera_id}:{self.line_id}:{self.track_id}:{self.crossing_seq}"

    @property
    def bucket_start(self) -> datetime:
        ts = self.timestamp_utc
        minute_floor = ts.minute - (ts.minute % BUCKET_DURATION_MINUTES)
        return ts.replace(minute=minute_floor, second=0, microsecond=0)


class TrackEvent(BaseModel):
    """Track lifecycle events pushed to Redis for the Live Monitor overlay."""

    event_type: Literal["TrackStarted", "TrackUpdated", "TrackEnded"]
    timestamp_utc: datetime
    camera_id: str
    track_id: str
    class12: VehicleClass12 | None = None
    confidence: float | None = None
    bbox: BoundingBox
    centroid: Point2D
    frame_index: int


class CameraHealthEvent(BaseModel):
    """Camera health status change published by the Ingest Service."""

    event_type: Literal["CameraHealthEvent"] = "CameraHealthEvent"
    timestamp_utc: datetime
    camera_id: str
    status: Literal["online", "degraded", "offline"]
    fps_actual: float | None = None
    last_frame_index: int | None = None
    reason: str | None = None


class AlertEvent(BaseModel):
    """Alert lifecycle events published to the mobile app via WebSocket."""

    event_type: Literal["AlertTriggered", "AlertAcknowledged", "AlertResolved"]
    timestamp_utc: datetime
    alert_id: UUID
    rule_id: UUID
    org_id: str
    severity: AlertSeverity
    message: str
    scope: dict[str, str]


def compute_bucket_start(timestamp_utc: datetime) -> datetime:
    """Assign a UTC timestamp to its 15-minute bucket.

    Buckets are aligned to the hour: :00, :15, :30, :45.
    The bucket_start is inclusive, bucket_end is exclusive.

    Examples:
        10:00:00 → bucket 10:00
        10:07:32 → bucket 10:00
        10:14:59 → bucket 10:00
        10:15:00 → bucket 10:15
        10:44:59 → bucket 10:30
        10:45:00 → bucket 10:45
        23:59:59 → bucket 23:45
    """
    minute_floor = timestamp_utc.minute - (timestamp_utc.minute % BUCKET_DURATION_MINUTES)
    return timestamp_utc.replace(minute=minute_floor, second=0, microsecond=0)
