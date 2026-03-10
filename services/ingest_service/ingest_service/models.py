"""Request and response models for the Ingest Service API."""

from __future__ import annotations

from datetime import datetime  # noqa: TC003
from typing import Literal

from pydantic import BaseModel, Field

# ---------------------------------------------------------------------------
# Frame upload
# ---------------------------------------------------------------------------

class FrameMetadata(BaseModel):
    """Metadata sent alongside each frame upload (as a JSON-encoded form field)."""

    camera_id: str
    frame_index: int = Field(ge=0)
    timestamp_utc: datetime
    offline_upload: bool = False
    session_id: str | None = None
    content_type: str = "image/jpeg"


class FrameUploadResponse(BaseModel):
    status: str = "queued"
    queue_position: int
    estimated_latency_ms: float


class BackpressureResponse(BaseModel):
    error: str = "queue_full"
    message: str
    retry_after_seconds: int


# ---------------------------------------------------------------------------
# Heartbeat
# ---------------------------------------------------------------------------

class HeartbeatRequest(BaseModel):
    camera_id: str
    fps_actual: float | None = None
    status: str = "online"
    frame_width: int | None = None
    frame_height: int | None = None
    last_frame_index: int | None = None


class HeartbeatResponse(BaseModel):
    status: str
    message: str
    expected_interval_seconds: float | None = None


# ---------------------------------------------------------------------------
# Upload sessions (offline / resumable upload)
# ---------------------------------------------------------------------------

class CreateSessionRequest(BaseModel):
    camera_id: str
    frame_count: int = Field(ge=1, description="Total frames expected in this session")
    start_ts: datetime
    end_ts: datetime
    offline_upload: bool = True


class ResumeSessionRequest(BaseModel):
    """Sent when resuming an interrupted upload session."""

    last_frame_index: int = Field(
        ge=0,
        description="Last frame_index the client successfully uploaded",
    )


SessionStatus = Literal["created", "uploading", "completed", "expired"]


class SessionState(BaseModel):
    """Internal session state persisted in Redis."""

    session_id: str
    camera_id: str
    status: SessionStatus = "created"
    frame_count: int
    frames_uploaded: int = 0
    start_ts: datetime
    end_ts: datetime
    offline_upload: bool = True
    created_by: str = ""
    created_at: datetime | None = None
    last_activity_at: datetime | None = None
    resume_from_index: int = 0


class SessionResponse(BaseModel):
    session_id: str
    camera_id: str
    status: SessionStatus
    frame_count: int = 0
    frames_uploaded: int = 0
    resume_from_index: int = 0


class MessageResponse(BaseModel):
    message: str
