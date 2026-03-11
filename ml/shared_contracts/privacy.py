"""Privacy controls and media security settings (SEC-14, SEC-15, SEC-16, DM-4).

Defines the organization-level privacy settings model and provides helpers
for the redaction pipeline and media encryption decisions.

Audio capture is hard-disabled (SEC-14) — no setting exists to enable it.
Raw media storage defaults to OFF (SEC-15). When enabled, optional
face/plate redaction (SEC-16) can be activated.
"""

from __future__ import annotations

from enum import StrEnum
from typing import Any

from pydantic import BaseModel, Field


class RedactionMode(StrEnum):
    """How to handle detected faces/plates in stored frames."""
    DISABLED = "disabled"
    GAUSSIAN_BLUR = "gaussian_blur"
    SOLID_FILL = "solid_fill"


class PrivacySettings(BaseModel):
    """Organization-level privacy configuration.

    These settings control what data is collected and retained beyond
    the aggregated traffic counts. Defaults follow the privacy-by-design
    principle: collect the minimum necessary for traffic analysis.
    """

    # SEC-15: Raw media storage (default OFF)
    store_frames: bool = Field(
        default=False,
        description="Store raw video frames in object storage",
    )
    store_clips: bool = Field(
        default=False,
        description="Store video clips in object storage",
    )

    # Event-level data (no PII, default ON)
    store_bbox: bool = Field(
        default=True,
        description="Include bounding box coordinates in crossing events",
    )
    store_speed: bool = Field(
        default=True,
        description="Include speed estimates in crossing events",
    )

    # SEC-16: Redaction (only relevant when store_frames=True)
    redact_faces: RedactionMode = Field(
        default=RedactionMode.DISABLED,
        description="Face redaction mode for stored frames",
    )
    redact_plates: RedactionMode = Field(
        default=RedactionMode.DISABLED,
        description="License plate redaction mode for stored frames",
    )

    # Aggregate-only mode: discard raw events after aggregation
    aggregate_only: bool = Field(
        default=False,
        description="Only retain 15-min aggregates; discard raw crossing events after aggregation",
    )

    # DM-4: Media encryption
    encrypt_media: bool = Field(
        default=True,
        description="Encrypt media files (frames/clips) before upload to object storage",
    )

    @property
    def requires_redaction(self) -> bool:
        """Whether any redaction pipeline step is needed."""
        return (
            self.store_frames
            and (
                self.redact_faces != RedactionMode.DISABLED
                or self.redact_plates != RedactionMode.DISABLED
            )
        )

    @property
    def media_storage_enabled(self) -> bool:
        """Whether any raw media storage is enabled."""
        return self.store_frames or self.store_clips


class DataRetentionPolicy(BaseModel):
    """Per-organization data retention configuration."""

    raw_events_days: int = Field(
        default=90,
        ge=1,
        le=3650,
        description="Days to retain raw vehicle crossing events",
    )
    aggregates_days: int = Field(
        default=730,
        ge=90,
        le=3650,
        description="Days to retain 15-minute aggregates (min 90)",
    )
    media_days: int = Field(
        default=30,
        ge=1,
        le=365,
        description="Days to retain stored frames/clips",
    )
    audit_log_days: int = Field(
        default=1095,
        ge=1095,
        description="Days to retain audit logs (minimum 3 years per compliance)",
    )
    hard_examples_days: int = Field(
        default=365,
        ge=30,
        le=3650,
        description="Days to retain hard-example frames for ML retraining",
    )


AUDIO_CAPTURE_ENABLED: bool = False
"""SEC-14: Audio capture is permanently disabled. No configuration can enable it."""


def should_store_frame(settings: PrivacySettings) -> bool:
    """Determine whether a frame should be persisted after inference."""
    return settings.store_frames


def should_redact_frame(settings: PrivacySettings) -> bool:
    """Determine whether a frame needs redaction before storage."""
    return settings.requires_redaction


def strip_pii_from_event(event: dict[str, Any], settings: PrivacySettings) -> dict[str, Any]:
    """Remove optional fields from a crossing event based on privacy settings."""
    result = dict(event)
    if not settings.store_bbox:
        result.pop("bbox", None)
    if not settings.store_speed:
        result.pop("speed_kmh", None)
        result.pop("speed_estimate", None)
    return result
