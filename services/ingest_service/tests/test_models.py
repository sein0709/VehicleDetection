"""Tests for Pydantic request/response models."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest
from ingest_service.models import (
    BackpressureResponse,
    CreateSessionRequest,
    FrameMetadata,
    FrameUploadResponse,
    HeartbeatRequest,
    ResumeSessionRequest,
    SessionState,
)
from pydantic import ValidationError


class TestFrameMetadata:
    def test_valid_metadata(self) -> None:
        meta = FrameMetadata(
            camera_id="cam_001",
            frame_index=100,
            timestamp_utc=datetime.now(tz=UTC),
        )
        assert meta.camera_id == "cam_001"
        assert meta.offline_upload is False
        assert meta.session_id is None
        assert meta.content_type == "image/jpeg"

    def test_offline_upload_with_session(self) -> None:
        meta = FrameMetadata(
            camera_id="cam_001",
            frame_index=0,
            timestamp_utc=datetime.now(tz=UTC),
            offline_upload=True,
            session_id="sess_abc",
        )
        assert meta.offline_upload is True
        assert meta.session_id == "sess_abc"

    def test_negative_frame_index_rejected(self) -> None:
        with pytest.raises(ValidationError):
            FrameMetadata(
                camera_id="cam_001",
                frame_index=-1,
                timestamp_utc=datetime.now(tz=UTC),
            )

    def test_from_json(self) -> None:
        json_str = (
            '{"camera_id": "cam_001", "frame_index": 50,'
            ' "timestamp_utc": "2026-03-10T10:00:00Z"}'
        )
        meta = FrameMetadata.model_validate_json(json_str)
        assert meta.camera_id == "cam_001"
        assert meta.frame_index == 50


class TestHeartbeatRequest:
    def test_minimal(self) -> None:
        hb = HeartbeatRequest(camera_id="cam_001")
        assert hb.status == "online"
        assert hb.fps_actual is None

    def test_full(self) -> None:
        hb = HeartbeatRequest(
            camera_id="cam_001",
            fps_actual=9.5,
            status="degraded",
            frame_width=1920,
            frame_height=1080,
            last_frame_index=500,
        )
        assert hb.fps_actual == 9.5
        assert hb.frame_width == 1920


class TestCreateSessionRequest:
    def test_valid(self) -> None:
        now = datetime.now(tz=UTC)
        req = CreateSessionRequest(
            camera_id="cam_001",
            frame_count=100,
            start_ts=now - timedelta(hours=1),
            end_ts=now,
        )
        assert req.frame_count == 100
        assert req.offline_upload is True

    def test_zero_frame_count_rejected(self) -> None:
        now = datetime.now(tz=UTC)
        with pytest.raises(ValidationError):
            CreateSessionRequest(
                camera_id="cam_001",
                frame_count=0,
                start_ts=now - timedelta(hours=1),
                end_ts=now,
            )


class TestResumeSessionRequest:
    def test_valid(self) -> None:
        req = ResumeSessionRequest(last_frame_index=49)
        assert req.last_frame_index == 49

    def test_negative_rejected(self) -> None:
        with pytest.raises(ValidationError):
            ResumeSessionRequest(last_frame_index=-1)


class TestSessionState:
    def test_roundtrip_json(self) -> None:
        now = datetime.now(tz=UTC)
        state = SessionState(
            session_id="sess_001",
            camera_id="cam_001",
            status="uploading",
            frame_count=200,
            frames_uploaded=50,
            start_ts=now - timedelta(hours=2),
            end_ts=now,
            offline_upload=True,
            created_by="user_001",
            created_at=now,
            last_activity_at=now,
            resume_from_index=50,
        )
        json_str = state.model_dump_json()
        restored = SessionState.model_validate_json(json_str)
        assert restored.session_id == "sess_001"
        assert restored.frames_uploaded == 50
        assert restored.resume_from_index == 50


class TestBackpressureResponse:
    def test_defaults(self) -> None:
        resp = BackpressureResponse(
            message="Queue full",
            retry_after_seconds=5,
        )
        assert resp.error == "queue_full"


class TestFrameUploadResponse:
    def test_defaults(self) -> None:
        resp = FrameUploadResponse(
            queue_position=42,
            estimated_latency_ms=500.0,
        )
        assert resp.status == "queued"
