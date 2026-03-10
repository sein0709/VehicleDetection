"""Internal data models for the inference pipeline stages.

These are worker-internal types, distinct from the shared contract models
published on the event bus.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field

from shared_contracts.enums import VehicleClass12
from shared_contracts.geometry import BoundingBox, Point2D


class Detection(BaseModel):
    """Stage 1 output: a single detected vehicle bounding box."""

    bbox: BoundingBox
    confidence: float = Field(ge=0.0, le=1.0)
    coarse_class: str = "vehicle"
    frame_index: int


class ClassPrediction(BaseModel):
    """Stage 3 output: classification result for a single vehicle crop."""

    class12: VehicleClass12
    probabilities: list[float] = Field(min_length=12, max_length=12)
    confidence: float = Field(ge=0.0, le=1.0)
    crop_bbox: BoundingBox


class SmoothedPrediction(BaseModel):
    """Stage 4 output: temporally smoothed classification."""

    class12: VehicleClass12
    confidence: float = Field(ge=0.0, le=1.0)
    probabilities: list[float] = Field(min_length=12, max_length=12)
    raw_prediction: ClassPrediction


class CrossingResult(BaseModel):
    """Stage 5 output: a confirmed line crossing event."""

    line_id: str
    line_name: str
    direction: str  # "inbound" | "outbound"


class TrackState(BaseModel):
    """Per-track state maintained by the tracker across frames."""

    track_id: str
    bbox: BoundingBox
    centroid: Point2D
    centroid_history: list[Point2D] = Field(default_factory=list)
    class_history: list[ClassPrediction] = Field(default_factory=list)
    smoothed_class: Optional[VehicleClass12] = None
    smoothed_confidence: Optional[float] = None
    first_seen_frame: int
    last_seen_frame: int
    age: int = 0
    hits: int = 0
    time_since_update: int = 0
    is_confirmed: bool = False
    speed_estimate_kmh: Optional[float] = None
    occlusion_flag: bool = False
    crossing_sequences: dict[str, int] = Field(default_factory=dict)
    last_crossing_frame: dict[str, int] = Field(default_factory=dict)


class CameraInferenceState(BaseModel):
    """All inference state for a single camera stream."""

    camera_id: str
    org_id: str = ""
    site_id: str = ""
    track_states: dict[str, TrackState] = Field(default_factory=dict)
    counting_lines: list = Field(default_factory=list)
    last_frame_index: int = -1
    model_version: str = "v0.1.0"
    next_track_id: int = 0


class HardExample(BaseModel):
    """A frame flagged for human review and active learning."""

    frame_data: bytes = Field(exclude=True, repr=False)
    crop_data: Optional[bytes] = Field(default=None, exclude=True, repr=False)
    camera_id: str
    track_id: str
    frame_index: int
    timestamp_utc: datetime
    predicted_class12: VehicleClass12
    confidence: float
    probabilities: list[float]
    trigger_reason: str
    model_version: str


class FrameMetadata(BaseModel):
    """Metadata extracted from NATS message headers."""

    camera_id: str
    frame_index: int = 0
    timestamp_utc: datetime = Field(default_factory=datetime.utcnow)
    content_type: str = "image/jpeg"
    offline_upload: bool = False
    org_id: str = ""
    site_id: str = ""
