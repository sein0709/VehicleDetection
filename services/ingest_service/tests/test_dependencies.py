"""Tests for authentication and authorization dependencies."""

from __future__ import annotations

import json
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from fastapi.testclient import TestClient

FRAME_META = json.dumps({
    "camera_id": "cam_001",
    "frame_index": 0,
    "timestamp_utc": "2026-03-10T10:00:00Z",
})
FRAME_FILE = ("frame.jpg", b"\xff\xd8" + b"\x00" * 50, "image/jpeg")


class TestAuth:
    def test_no_auth_header(self, client: TestClient) -> None:
        resp = client.post(
            "/v1/ingest/heartbeat",
            json={"camera_id": "cam_001"},
        )
        assert resp.status_code == 401

    def test_invalid_bearer_format(self, client: TestClient) -> None:
        resp = client.post(
            "/v1/ingest/heartbeat",
            json={"camera_id": "cam_001"},
            headers={"Authorization": "Basic abc123"},
        )
        assert resp.status_code == 401

    def test_invalid_jwt(self, client: TestClient) -> None:
        resp = client.post(
            "/v1/ingest/heartbeat",
            json={"camera_id": "cam_001"},
            headers={"Authorization": "Bearer invalid.token.here"},
        )
        assert resp.status_code == 401

    def test_viewer_cannot_upload_frames(
        self,
        client: TestClient,
        viewer_headers: dict[str, str],
    ) -> None:
        resp = client.post(
            "/v1/ingest/frames",
            data={"metadata": FRAME_META},
            files={"frame": FRAME_FILE},
            headers=viewer_headers,
        )
        assert resp.status_code == 403

    def test_analyst_cannot_upload_frames(
        self,
        client: TestClient,
        analyst_headers: dict[str, str],
    ) -> None:
        resp = client.post(
            "/v1/ingest/frames",
            data={"metadata": FRAME_META},
            files={"frame": FRAME_FILE},
            headers=analyst_headers,
        )
        assert resp.status_code == 403

    def test_admin_can_upload_frames(
        self,
        client: TestClient,
        admin_headers: dict[str, str],
    ) -> None:
        resp = client.post(
            "/v1/ingest/frames",
            data={"metadata": FRAME_META},
            files={"frame": FRAME_FILE},
            headers=admin_headers,
        )
        assert resp.status_code == 202

    def test_operator_can_upload_frames(
        self,
        client: TestClient,
        operator_headers: dict[str, str],
    ) -> None:
        resp = client.post(
            "/v1/ingest/frames",
            data={"metadata": FRAME_META},
            files={"frame": FRAME_FILE},
            headers=operator_headers,
        )
        assert resp.status_code == 202
