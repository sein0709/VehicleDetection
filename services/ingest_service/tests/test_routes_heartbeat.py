"""Tests for heartbeat endpoint."""

from __future__ import annotations

from typing import TYPE_CHECKING
from unittest.mock import AsyncMock, MagicMock

if TYPE_CHECKING:
    from fastapi.testclient import TestClient


class TestHeartbeat:
    def test_heartbeat_success(
        self,
        client: TestClient,
        mock_health_cache: MagicMock,
        mock_nats: MagicMock,
        operator_headers: dict[str, str],
    ) -> None:
        resp = client.post(
            "/v1/ingest/heartbeat",
            json={"camera_id": "cam_001", "fps_actual": 9.5},
            headers=operator_headers,
        )

        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "ok"
        assert "cam_001" in data["message"]
        assert data["expected_interval_seconds"] is not None
        mock_health_cache.record_heartbeat.assert_called_once()

    def test_heartbeat_records_all_fields(
        self,
        client: TestClient,
        mock_health_cache: MagicMock,
        mock_nats: MagicMock,
        operator_headers: dict[str, str],
    ) -> None:
        client.post(
            "/v1/ingest/heartbeat",
            json={
                "camera_id": "cam_002",
                "fps_actual": 10.0,
                "frame_width": 1920,
                "frame_height": 1080,
                "last_frame_index": 500,
            },
            headers=operator_headers,
        )

        call_args = mock_health_cache.record_heartbeat.call_args
        # camera_id is positional, rest are keyword
        assert call_args[0][0] == "cam_002"
        assert call_args[1]["fps_actual"] == 10.0
        assert call_args[1]["frame_width"] == 1920
        assert call_args[1]["frame_height"] == 1080
        assert call_args[1]["last_frame_index"] == 500

    def test_heartbeat_publishes_health_event(
        self,
        client: TestClient,
        mock_health_cache: MagicMock,
        mock_nats: MagicMock,
        operator_headers: dict[str, str],
    ) -> None:
        client.post(
            "/v1/ingest/heartbeat",
            json={"camera_id": "cam_003", "fps_actual": 8.0, "status": "degraded"},
            headers=operator_headers,
        )

        mock_nats.publish_health_event.assert_called_once()
        call_args = mock_nats.publish_health_event.call_args
        assert call_args[0][0] == "cam_003"
        event_data = call_args[0][1]
        assert event_data["camera_id"] == "cam_003"
        assert event_data["status"] == "degraded"
        assert event_data["fps_actual"] == 8.0

    def test_heartbeat_continues_on_nats_failure(
        self,
        client: TestClient,
        mock_health_cache: MagicMock,
        mock_nats: MagicMock,
        operator_headers: dict[str, str],
    ) -> None:
        mock_nats.publish_health_event = AsyncMock(side_effect=RuntimeError("NATS down"))

        resp = client.post(
            "/v1/ingest/heartbeat",
            json={"camera_id": "cam_001", "fps_actual": 10.0},
            headers=operator_headers,
        )

        assert resp.status_code == 200
        mock_health_cache.record_heartbeat.assert_called_once()

    def test_heartbeat_minimal_payload(
        self,
        client: TestClient,
        mock_health_cache: MagicMock,
        mock_nats: MagicMock,
        operator_headers: dict[str, str],
    ) -> None:
        resp = client.post(
            "/v1/ingest/heartbeat",
            json={"camera_id": "cam_001"},
            headers=operator_headers,
        )

        assert resp.status_code == 200

    def test_heartbeat_requires_auth(self, client: TestClient) -> None:
        resp = client.post(
            "/v1/ingest/heartbeat",
            json={"camera_id": "cam_001"},
        )

        assert resp.status_code == 401

    def test_heartbeat_allows_viewer(
        self,
        client: TestClient,
        mock_health_cache: MagicMock,
        mock_nats: MagicMock,
        viewer_headers: dict[str, str],
    ) -> None:
        resp = client.post(
            "/v1/ingest/heartbeat",
            json={"camera_id": "cam_001"},
            headers=viewer_headers,
        )

        assert resp.status_code == 200

    def test_heartbeat_missing_camera_id(
        self,
        client: TestClient,
        operator_headers: dict[str, str],
    ) -> None:
        resp = client.post(
            "/v1/ingest/heartbeat",
            json={},
            headers=operator_headers,
        )

        assert resp.status_code == 422 or resp.status_code == 400

    def test_heartbeat_expected_interval(
        self,
        client: TestClient,
        mock_health_cache: MagicMock,
        mock_nats: MagicMock,
        operator_headers: dict[str, str],
    ) -> None:
        resp = client.post(
            "/v1/ingest/heartbeat",
            json={"camera_id": "cam_001", "fps_actual": 10.0},
            headers=operator_headers,
        )

        data = resp.json()
        assert data["expected_interval_seconds"] == 0.2
