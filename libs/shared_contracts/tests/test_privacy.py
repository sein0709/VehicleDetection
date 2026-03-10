"""Tests for privacy controls (SEC-14, SEC-15, SEC-16)."""

from __future__ import annotations

import pytest
import pydantic

from shared_contracts.privacy import (
    AUDIO_CAPTURE_ENABLED,
    DataRetentionPolicy,
    PrivacySettings,
    RedactionMode,
    should_redact_frame,
    should_store_frame,
    strip_pii_from_event,
)


class TestPrivacySettings:
    def test_defaults_are_privacy_preserving(self) -> None:
        settings = PrivacySettings()
        assert settings.store_frames is False
        assert settings.store_clips is False
        assert settings.redact_faces == RedactionMode.DISABLED
        assert settings.redact_plates == RedactionMode.DISABLED
        assert settings.aggregate_only is False
        assert settings.encrypt_media is True

    def test_audio_permanently_disabled(self) -> None:
        assert AUDIO_CAPTURE_ENABLED is False

    def test_requires_redaction_when_faces_enabled(self) -> None:
        settings = PrivacySettings(
            store_frames=True,
            redact_faces=RedactionMode.GAUSSIAN_BLUR,
        )
        assert settings.requires_redaction is True

    def test_no_redaction_when_frames_disabled(self) -> None:
        settings = PrivacySettings(
            store_frames=False,
            redact_faces=RedactionMode.GAUSSIAN_BLUR,
        )
        assert settings.requires_redaction is False

    def test_media_storage_enabled(self) -> None:
        assert PrivacySettings(store_frames=True).media_storage_enabled is True
        assert PrivacySettings(store_clips=True).media_storage_enabled is True
        assert PrivacySettings().media_storage_enabled is False


class TestPrivacyHelpers:
    def test_should_store_frame(self) -> None:
        assert should_store_frame(PrivacySettings()) is False
        assert should_store_frame(PrivacySettings(store_frames=True)) is True

    def test_should_redact_frame(self) -> None:
        assert should_redact_frame(PrivacySettings()) is False
        assert should_redact_frame(
            PrivacySettings(store_frames=True, redact_plates=RedactionMode.GAUSSIAN_BLUR)
        ) is True

    def test_strip_pii_removes_bbox(self) -> None:
        event = {"track_id": 1, "class": 3, "bbox": [0.1, 0.2, 0.3, 0.4], "speed_kmh": 60}
        settings = PrivacySettings(store_bbox=False)
        result = strip_pii_from_event(event, settings)
        assert "bbox" not in result
        assert "speed_kmh" in result

    def test_strip_pii_removes_speed(self) -> None:
        event = {"track_id": 1, "speed_kmh": 60, "speed_estimate": 58.5}
        settings = PrivacySettings(store_speed=False)
        result = strip_pii_from_event(event, settings)
        assert "speed_kmh" not in result
        assert "speed_estimate" not in result

    def test_strip_pii_preserves_all_when_enabled(self) -> None:
        event = {"track_id": 1, "bbox": [0.1, 0.2, 0.3, 0.4], "speed_kmh": 60}
        settings = PrivacySettings()
        result = strip_pii_from_event(event, settings)
        assert result == event


class TestDataRetentionPolicy:
    def test_defaults(self) -> None:
        policy = DataRetentionPolicy()
        assert policy.raw_events_days == 90
        assert policy.aggregates_days == 730
        assert policy.media_days == 30
        assert policy.audit_log_days == 1095  # 3 years minimum

    def test_audit_log_minimum_enforced(self) -> None:
        with pytest.raises(pydantic.ValidationError):
            DataRetentionPolicy(audit_log_days=365)  # Below 3-year minimum
