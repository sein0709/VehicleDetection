"""Request and response Pydantic models for the Reporting API."""

from __future__ import annotations

from datetime import datetime
from enum import StrEnum
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field


# ── Enums ─────────────────────────────────────────────────────────────────────


class ExportFormat(StrEnum):
    CSV = "csv"
    JSON = "json"
    PDF = "pdf"


class ExportStatus(StrEnum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


# ── Pagination ────────────────────────────────────────────────────────────────


class PaginationMeta(BaseModel):
    cursor: str | None = None
    has_more: bool = False


# ── Analytics Responses ───────────────────────────────────────────────────────


class BucketRow(BaseModel):
    bucket_start: datetime
    bucket_end: datetime
    total_count: int
    by_class: dict[int, int] = Field(default_factory=dict)
    by_direction: dict[str, int] = Field(default_factory=dict)
    avg_speed_kmh: float | None = None


class BucketResponse(BaseModel):
    """Paginated response wrapping a list of 15-minute bucket rows."""

    buckets: list[BucketRow]
    pagination: PaginationMeta


class KPIResponse(BaseModel):
    camera_id: UUID | None = None
    site_id: UUID | None = None
    start: datetime
    end: datetime
    total_count: int
    flow_rate_per_hour: float
    class_distribution: dict[int, int] = Field(default_factory=dict)
    heavy_vehicle_ratio: float
    avg_speed_kmh: float | None = None


class LiveKPIUpdate(BaseModel):
    type: str = "live_kpi_update"
    camera_id: str
    current_bucket: datetime | None = None
    elapsed_seconds: float = 0.0
    counts: dict[str, Any] = Field(default_factory=dict)
    active_tracks: int = 0
    flow_rate_per_hour: float = 0.0


class ComparisonResponse(BaseModel):
    camera_id: UUID | None = None
    site_id: UUID | None = None
    range1: dict[str, Any]
    range2: dict[str, Any]
    count_delta: int
    count_change_pct: float | None = None


# ── Report Export ─────────────────────────────────────────────────────────────


class ExportRequest(BaseModel):
    scope: str = Field(description="e.g. 'camera:<uuid>' or 'site:<uuid>'")
    start: datetime
    end: datetime
    format: ExportFormat = ExportFormat.CSV
    filters: dict[str, Any] = Field(default_factory=dict)


class ExportResponse(BaseModel):
    export_id: str
    status: ExportStatus = ExportStatus.PENDING
    format: ExportFormat | None = None
    download_url: str | None = None
    created_at: datetime | None = None


# ── Shared Links ──────────────────────────────────────────────────────────────


class ShareLinkRequest(BaseModel):
    scope: str = Field(description="e.g. 'camera:<uuid>' or 'site:<uuid>'")
    filters: dict[str, Any] = Field(default_factory=dict)
    ttl_days: int = Field(default=7, ge=1, le=90)


class ShareLinkResponse(BaseModel):
    token: str
    url: str
    expires_at: datetime


class SharedReportDataResponse(BaseModel):
    scope: Any
    filters: Any
    expires_at: datetime | str
    data: list[dict[str, Any]] = Field(default_factory=list)
