"""Tests for frame upload endpoint."""

from __future__ import annotations

import json
from typing import TYPE_CHECKING, Any
from unittest.mock import AsyncMock, MagicMock

if TYPE_CHECKING:
    from fastapi.testclient import TestClient


class TestUploadFrame:
    def test_upload_success(
        self,
        client: TestClient,
        mock_nats: MagicMock,
        operator_headers: dict[str, str],
        sample_frame_metadata: dict[str, Any],
    ) -> None:
        mock_nats.get_queue_depth = AsyncMock(return_value=10)
        mock_nats.publish_frame = AsyncMock(return_value=42)

        resp = client.post(
            "/v1/ingest/frames",
            data={"metadata": json.dumps(sample_frame_metadata)},
            files={"frame": ("frame.jpg", b"\xff\xd8\xff\xe0" + b"\x00" * 100, "image/jpeg")},
            headers=operator_headers,
        )

        assert resp.status_code == 202
        data = resp.json()
        assert data["status"] == "queued"
        assert data["queue_position"] == 42
        assert data["estimated_latency_ms"] == 10 * 50.0
        mock_nats.publish_frame.assert_called_once()

    def test_upload_publishes_correct_metadata(
        self,
        client: TestClient,
        mock_nats: MagicMock,
        operator_headers: dict[str, str],
        sample_frame_metadata: dict[str, Any],
    ) -> None:
        mock_nats.publish_frame = AsyncMock(return_value=1)

        client.post(
            "/v1/ingest/frames",
            data={"metadata": json.dumps(sample_frame_metadata)},
            files={"frame": ("frame.jpg", b"\xff\xd8" + b"\x00" * 50, "image/jpeg")},
            headers=operator_headers,
        )

        call_args = mock_nats.publish_frame.call_args
        assert call_args[0][0] == "cam_001"
        meta = call_args[0][2]
        assert "uploaded_by" in meta
        assert "org_id" in meta

    def test_upload_backpressure_429(
        self,
        client: TestClient,
        mock_nats: MagicMock,
        operator_headers: dict[str, str],
        sample_frame_metadata: dict[str, Any],
    ) -> None:
        mock_nats.get_queue_depth = AsyncMock(return_value=600)

        resp = client.post(
            "/v1/ingest/frames",
            data={"metadata": json.dumps(sample_frame_metadata)},
            files={"frame": ("frame.jpg", b"\xff\xd8" + b"\x00" * 50, "image/jpeg")},
            headers=operator_headers,
        )

        assert resp.status_code == 429
        data = resp.json()
        assert data["error"] == "queue_full"
        assert data["retry_after_seconds"] == 5
        assert resp.headers["Retry-After"] == "5"
        mock_nats.publish_frame.assert_not_called()

    def test_upload_backpressure_at_exact_limit(
        self,
        client: TestClient,
        mock_nats: MagicMock,
        operator_headers: dict[str, str],
        sample_frame_metadata: dict[str, Any],
    ) -> None:
        mock_nats.get_queue_depth = AsyncMock(return_value=500)

        resp = client.post(
            "/v1/ingest/frames",
            data={"metadata": json.dumps(sample_frame_metadata)},
            files={"frame": ("frame.jpg", b"\xff\xd8" + b"\x00" * 50, "image/jpeg")},
            headers=operator_headers,
        )

        assert resp.status_code == 429

    def test_upload_just_below_limit_succeeds(
        self,
        client: TestClient,
        mock_nats: MagicMock,
        operator_headers: dict[str, str],
        sample_frame_metadata: dict[str, Any],
    ) -> None:
        mock_nats.get_queue_depth = AsyncMock(return_value=499)
        mock_nats.publish_frame = AsyncMock(return_value=500)

        resp = client.post(
            "/v1/ingest/frames",
            data={"metadata": json.dumps(sample_frame_metadata)},
            files={"frame": ("frame.jpg", b"\xff\xd8" + b"\x00" * 50, "image/jpeg")},
            headers=operator_headers,
        )

        assert resp.status_code == 202

    def test_upload_empty_frame_rejected(
        self,
        client: TestClient,
        mock_nats: MagicMock,
        operator_headers: dict[str, str],
        sample_frame_metadata: dict[str, Any],
    ) -> None:
        resp = client.post(
            "/v1/ingest/frames",
            data={"metadata": json.dumps(sample_frame_metadata)},
            files={"frame": ("frame.jpg", b"", "image/jpeg")},
            headers=operator_headers,
        )

        assert resp.status_code == 400
        assert resp.json()["error"] == "empty_frame"

    def test_upload_oversized_frame_rejected(
        self,
        client: TestClient,
        mock_nats: MagicMock,
        operator_headers: dict[str, str],
        sample_frame_metadata: dict[str, Any],
    ) -> None:
        huge_frame = b"\x00" * (11 * 1024 * 1024)

        resp = client.post(
            "/v1/ingest/frames",
            data={"metadata": json.dumps(sample_frame_metadata)},
            files={"frame": ("frame.jpg", huge_frame, "image/jpeg")},
            headers=operator_headers,
        )

        assert resp.status_code == 413
        assert resp.json()["error"] == "frame_too_large"

    def test_upload_requires_auth(
        self,
        client: TestClient,
        sample_frame_metadata: dict[str, Any],
    ) -> None:
        resp = client.post(
            "/v1/ingest/frames",
            data={"metadata": json.dumps(sample_frame_metadata)},
            files={"frame": ("frame.jpg", b"\xff\xd8" + b"\x00" * 50, "image/jpeg")},
        )

        assert resp.status_code == 401

    def test_upload_requires_operator_role(
        self,
        client: TestClient,
        viewer_headers: dict[str, str],
        sample_frame_metadata: dict[str, Any],
    ) -> None:
        resp = client.post(
            "/v1/ingest/frames",
            data={"metadata": json.dumps(sample_frame_metadata)},
            files={"frame": ("frame.jpg", b"\xff\xd8" + b"\x00" * 50, "image/jpeg")},
            headers=viewer_headers,
        )

        assert resp.status_code == 403

    def test_upload_invalid_metadata_json(
        self,
        client: TestClient,
        operator_headers: dict[str, str],
    ) -> None:
        resp = client.post(
            "/v1/ingest/frames",
            data={"metadata": "not-valid-json"},
            files={"frame": ("frame.jpg", b"\xff\xd8" + b"\x00" * 50, "image/jpeg")},
            headers=operator_headers,
        )

        assert resp.status_code == 500 or resp.status_code == 422

    def test_upload_with_session_id_increments_counter(
        self,
        client: TestClient,
        mock_nats: MagicMock,
        mock_session_store: MagicMock,
        operator_headers: dict[str, str],
        sample_frame_metadata: dict[str, Any],
    ) -> None:
        sample_frame_metadata["session_id"] = "sess_abc123"
        mock_nats.publish_frame = AsyncMock(return_value=42)

        resp = client.post(
            "/v1/ingest/frames",
            data={"metadata": json.dumps(sample_frame_metadata)},
            files={"frame": ("frame.jpg", b"\xff\xd8" + b"\x00" * 50, "image/jpeg")},
            headers=operator_headers,
        )

        assert resp.status_code == 202
        mock_session_store.increment_frames.assert_called_once_with("sess_abc123")

    def test_upload_without_session_id_skips_session(
        self,
        client: TestClient,
        mock_nats: MagicMock,
        mock_session_store: MagicMock,
        operator_headers: dict[str, str],
        sample_frame_metadata: dict[str, Any],
    ) -> None:
        mock_nats.publish_frame = AsyncMock(return_value=42)

        resp = client.post(
            "/v1/ingest/frames",
            data={"metadata": json.dumps(sample_frame_metadata)},
            files={"frame": ("frame.jpg", b"\xff\xd8" + b"\x00" * 50, "image/jpeg")},
            headers=operator_headers,
        )

        assert resp.status_code == 202
        mock_session_store.increment_frames.assert_not_called()

    def test_upload_offline_frame(
        self,
        client: TestClient,
        mock_nats: MagicMock,
        operator_headers: dict[str, str],
        sample_frame_metadata: dict[str, Any],
    ) -> None:
        sample_frame_metadata["offline_upload"] = True
        sample_frame_metadata["session_id"] = "sess_offline_001"
        mock_nats.publish_frame = AsyncMock(return_value=99)

        resp = client.post(
            "/v1/ingest/frames",
            data={"metadata": json.dumps(sample_frame_metadata)},
            files={"frame": ("frame.jpg", b"\xff\xd8" + b"\x00" * 50, "image/jpeg")},
            headers=operator_headers,
        )

        assert resp.status_code == 202
        call_meta = mock_nats.publish_frame.call_args[0][2]
        assert call_meta["offline_upload"] is True
