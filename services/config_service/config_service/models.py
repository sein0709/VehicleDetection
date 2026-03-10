"""Request and response Pydantic models for the Config Service API."""

from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field

from shared_contracts.enums import CameraSourceType, CameraStatus, ClassificationMode, SiteStatus
from shared_contracts.geometry import LanePolyline, ROIPolygon

# ── Site Models ──────────────────────────────────────────────────────────────


class LocationInput(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)


class GeoFenceInput(BaseModel):
    type: str = "Polygon"
    coordinates: list[list[list[float]]]


class CreateSiteRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    address: str | None = None
    location: LocationInput | None = None
    geofence: GeoFenceInput | None = None
    timezone: str = "Asia/Seoul"


class UpdateSiteRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    address: str | None = None
    location: LocationInput | None = None
    geofence: GeoFenceInput | None = None
    timezone: str | None = None


class SiteResponse(BaseModel):
    id: UUID
    org_id: UUID
    name: str
    address: str | None = None
    location: dict[str, Any] | None = None
    geofence: dict[str, Any] | None = None
    timezone: str
    status: SiteStatus
    active_config_version: int
    created_at: datetime
    updated_at: datetime
    created_by: UUID | None = None


# ── Camera Models ────────────────────────────────────────────────────────────


class CameraSettingsInput(BaseModel):
    target_fps: int = Field(default=10, ge=1, le=30)
    resolution: str = "1920x1080"
    night_mode: bool = False
    classification_mode: ClassificationMode = ClassificationMode.FULL_12CLASS


class CreateCameraRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    source_type: CameraSourceType
    rtsp_url: str | None = None
    settings: CameraSettingsInput = Field(default_factory=CameraSettingsInput)


class UpdateCameraRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    rtsp_url: str | None = None
    settings: CameraSettingsInput | None = None


class CameraResponse(BaseModel):
    id: UUID
    site_id: UUID
    org_id: UUID
    name: str
    source_type: CameraSourceType
    rtsp_url: str | None = None
    settings: dict[str, Any]
    status: CameraStatus
    active_config_version: int
    last_seen_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class CameraStatusResponse(BaseModel):
    camera_id: UUID
    status: CameraStatus
    last_seen_at: datetime | None = None
    fps_actual: float | None = None
    frame_width: int | None = None
    frame_height: int | None = None


class CameraHeartbeatRequest(BaseModel):
    fps: float | None = Field(default=None, ge=0, le=120)
    frame_width: int | None = Field(default=None, ge=1)
    frame_height: int | None = Field(default=None, ge=1)


# ── ROI Preset Models ────────────────────────────────────────────────────────


class CountingLineInput(BaseModel):
    name: str
    start: dict[str, float]
    end: dict[str, float]
    direction: str = Field(description="inbound | outbound | bidirectional")
    direction_vector: dict[str, float]


class CreateROIPresetRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    roi_polygon: ROIPolygon
    counting_lines: list[CountingLineInput] = Field(default_factory=list)
    lane_polylines: list[LanePolyline] = Field(default_factory=list)


class UpdateROIPresetRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    roi_polygon: ROIPolygon | None = None
    counting_lines: list[CountingLineInput] | None = None
    lane_polylines: list[LanePolyline] | None = None


class ROIPresetResponse(BaseModel):
    id: UUID
    camera_id: UUID
    org_id: UUID
    name: str
    roi_polygon: dict[str, Any]
    counting_lines: list[dict[str, Any]] = Field(default_factory=list)
    lane_polylines: list[dict[str, Any]] = Field(default_factory=list)
    is_active: bool
    version: int
    created_at: datetime
    created_by: UUID | None = None


# ── Config Version Models ────────────────────────────────────────────────────


class ConfigVersionResponse(BaseModel):
    id: UUID
    org_id: UUID
    entity_type: str
    entity_id: UUID
    version_number: int
    config_snapshot: dict[str, Any]
    is_active: bool
    created_by: UUID | None = None
    rollback_from: UUID | None = None
    created_at: datetime


# ── Common ───────────────────────────────────────────────────────────────────


class MessageResponse(BaseModel):
    message: str
