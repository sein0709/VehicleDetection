"""Tests for upload session endpoints (create, get, resume)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import TYPE_CHECKING
from unittest.mock import AsyncMock, MagicMock

from ingest_service.models import SessionState

if TYPE_CHECKING:
    from fastapi.testclient import TestClient


class TestCreateSession:
    def test_create_session_success(
        self,
        client: TestClient,
        mock_session_store: MagicMock,
        operator_headers: dict[str, str],
    ) -> None:
        now = datetime.now(tz=UTC)
        resp = client.post(
            "/v1/ingest/sessions",
            json={
                "camera_id": "cam_001",
                "frame_count": 100,
                "start_ts": (now - timedelta(hours=1)).isoformat(),
                "end_ts": now.isoformat(),
            },
            headers=operator_headers,
        )

        assert resp.status_code == 201
        data = resp.json()
        assert data["camera_id"] == "cam_001"
        assert data["status"] == "created"
        assert data["frame_count"] == 100
        assert data["frames_uploaded"] == 0
        assert data["resume_from_index"] == 0
        assert len(data["session_id"]) == 32
        mock_session_store.create.assert_called_once()

    def test_create_session_persists_state(
        self,
        client: TestClient,
        mock_session_store: MagicMock,
        operator_headers: dict[str, str],
    ) -> None:
        now = datetime.now(tz=UTC)
        client.post(
            "/v1/ingest/sessions",
            json={
                "camera_id": "cam_002",
                "frame_count": 500,
                "start_ts": (now - timedelta(hours=2)).isoformat(),
                "end_ts": now.isoformat(),
                "offline_upload": True,
            },
            headers=operator_headers,
        )

        call_args = mock_session_store.create.call_args[0][0]
        assert isinstance(call_args, SessionState)
        assert call_args.camera_id == "cam_002"
        assert call_args.frame_count == 500
        assert call_args.offline_upload is True

    def test_create_session_requires_operator(
        self,
        client: TestClient,
        viewer_headers: dict[str, str],
    ) -> None:
        now = datetime.now(tz=UTC)
        resp = client.post(
            "/v1/ingest/sessions",
            json={
                "camera_id": "cam_001",
                "frame_count": 100,
                "start_ts": (now - timedelta(hours=1)).isoformat(),
                "end_ts": now.isoformat(),
            },
            headers=viewer_headers,
        )

        assert resp.status_code == 403

    def test_create_session_requires_auth(self, client: TestClient) -> None:
        now = datetime.now(tz=UTC)
        resp = client.post(
            "/v1/ingest/sessions",
            json={
                "camera_id": "cam_001",
                "frame_count": 100,
                "start_ts": (now - timedelta(hours=1)).isoformat(),
                "end_ts": now.isoformat(),
            },
        )

        assert resp.status_code == 401

    def test_create_session_invalid_frame_count(
        self,
        client: TestClient,
        operator_headers: dict[str, str],
    ) -> None:
        now = datetime.now(tz=UTC)
        resp = client.post(
            "/v1/ingest/sessions",
            json={
                "camera_id": "cam_001",
                "frame_count": 0,
                "start_ts": (now - timedelta(hours=1)).isoformat(),
                "end_ts": now.isoformat(),
            },
            headers=operator_headers,
        )

        assert resp.status_code == 422 or resp.status_code == 400


class TestGetSession:
    def test_get_session_success(
        self,
        client: TestClient,
        mock_session_store: MagicMock,
        operator_headers: dict[str, str],
        sample_session_state: SessionState,
    ) -> None:
        mock_session_store.get = AsyncMock(return_value=sample_session_state)

        resp = client.get(
            f"/v1/ingest/sessions/{sample_session_state.session_id}",
            headers=operator_headers,
        )

        assert resp.status_code == 200
        data = resp.json()
        assert data["session_id"] == sample_session_state.session_id
        assert data["camera_id"] == "cam_001"
        assert data["status"] == "created"
        assert data["frame_count"] == 100

    def test_get_session_not_found(
        self,
        client: TestClient,
        mock_session_store: MagicMock,
        operator_headers: dict[str, str],
    ) -> None:
        mock_session_store.get = AsyncMock(return_value=None)

        resp = client.get(
            "/v1/ingest/sessions/nonexistent",
            headers=operator_headers,
        )

        assert resp.status_code == 404

    def test_get_session_requires_auth(self, client: TestClient) -> None:
        resp = client.get("/v1/ingest/sessions/some_id")
        assert resp.status_code == 401


class TestResumeSession:
    def test_resume_session_success(
        self,
        client: TestClient,
        mock_session_store: MagicMock,
        operator_headers: dict[str, str],
        sample_session_state: SessionState,
    ) -> None:
        sample_session_state.frames_uploaded = 50
        mock_session_store.get = AsyncMock(return_value=sample_session_state)

        resp = client.patch(
            f"/v1/ingest/sessions/{sample_session_state.session_id}",
            json={"last_frame_index": 49},
            headers=operator_headers,
        )

        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "uploading"
        assert data["resume_from_index"] == 50
        mock_session_store.update.assert_called_once()

    def test_resume_session_not_found(
        self,
        client: TestClient,
        mock_session_store: MagicMock,
        operator_headers: dict[str, str],
    ) -> None:
        mock_session_store.get = AsyncMock(return_value=None)

        resp = client.patch(
            "/v1/ingest/sessions/nonexistent",
            json={"last_frame_index": 10},
            headers=operator_headers,
        )

        assert resp.status_code == 404

    def test_resume_completed_session_conflict(
        self,
        client: TestClient,
        mock_session_store: MagicMock,
        operator_headers: dict[str, str],
        sample_session_state: SessionState,
    ) -> None:
        sample_session_state.status = "completed"
        mock_session_store.get = AsyncMock(return_value=sample_session_state)

        resp = client.patch(
            f"/v1/ingest/sessions/{sample_session_state.session_id}",
            json={"last_frame_index": 99},
            headers=operator_headers,
        )

        assert resp.status_code == 409

    def test_resume_session_requires_operator(
        self,
        client: TestClient,
        viewer_headers: dict[str, str],
    ) -> None:
        resp = client.patch(
            "/v1/ingest/sessions/some_id",
            json={"last_frame_index": 10},
            headers=viewer_headers,
        )

        assert resp.status_code == 403

    def test_resume_session_requires_auth(self, client: TestClient) -> None:
        resp = client.patch(
            "/v1/ingest/sessions/some_id",
            json={"last_frame_index": 10},
        )

        assert resp.status_code == 401
