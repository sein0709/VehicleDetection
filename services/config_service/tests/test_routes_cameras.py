"""Tests for camera management endpoints."""

from __future__ import annotations

from typing import Any
from unittest.mock import AsyncMock, MagicMock

from fastapi.testclient import TestClient


class TestCreateCamera:
    def test_create_camera_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_site: dict[str, Any],
        sample_camera: dict[str, Any],
    ) -> None:
        mock_db.get_site = AsyncMock(return_value=sample_site)
        mock_db.create_camera = AsyncMock(return_value=sample_camera)

        resp = client.post(
            f"/v1/sites/{sample_site['id']}/cameras",
            json={
                "name": "남측 카메라",
                "source_type": "smartphone",
                "settings": {
                    "target_fps": 10,
                    "resolution": "1920x1080",
                    "night_mode": False,
                    "classification_mode": "full_12class",
                },
            },
            headers=operator_headers,
        )

        assert resp.status_code == 201
        data = resp.json()
        assert data["name"] == "남측 카메라"
        assert data["source_type"] == "smartphone"

    def test_create_camera_passes_created_by(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_site: dict[str, Any],
        sample_camera: dict[str, Any],
    ) -> None:
        mock_db.get_site = AsyncMock(return_value=sample_site)
        mock_db.create_camera = AsyncMock(return_value=sample_camera)

        client.post(
            f"/v1/sites/{sample_site['id']}/cameras",
            json={"name": "Test", "source_type": "smartphone"},
            headers=operator_headers,
        )

        call_kwargs = mock_db.create_camera.call_args.kwargs
        assert "created_by" in call_kwargs
        assert call_kwargs["created_by"] is not None

    def test_create_camera_site_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
    ) -> None:
        mock_db.get_site = AsyncMock(return_value=None)

        resp = client.post(
            "/v1/sites/00000000-0000-0000-0000-000000000000/cameras",
            json={"name": "Test", "source_type": "smartphone"},
            headers=operator_headers,
        )
        assert resp.status_code == 404


class TestListCameras:
    def test_list_cameras_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_site: dict[str, Any],
        sample_camera: dict[str, Any],
    ) -> None:
        mock_db.list_cameras = AsyncMock(return_value=([sample_camera], 1))

        resp = client.get(
            f"/v1/sites/{sample_site['id']}/cameras",
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert len(resp.json()["data"]) == 1


class TestUpdateCamera:
    def test_update_camera_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_camera: dict[str, Any],
    ) -> None:
        updated = {**sample_camera, "name": "Updated Camera", "active_config_version": 2}
        mock_db.update_camera = AsyncMock(return_value=updated)

        resp = client.patch(
            f"/v1/cameras/{sample_camera['id']}",
            json={"name": "Updated Camera"},
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert resp.json()["name"] == "Updated Camera"

    def test_update_camera_empty_body(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_camera: dict[str, Any],
    ) -> None:
        resp = client.patch(
            f"/v1/cameras/{sample_camera['id']}",
            json={},
            headers=operator_headers,
        )
        assert resp.status_code == 422

    def test_update_camera_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_camera: dict[str, Any],
    ) -> None:
        mock_db.update_camera = AsyncMock(return_value=None)

        resp = client.patch(
            f"/v1/cameras/{sample_camera['id']}",
            json={"name": "New Name"},
            headers=operator_headers,
        )
        assert resp.status_code == 404


class TestArchiveCamera:
    def test_archive_camera_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_camera: dict[str, Any],
    ) -> None:
        mock_db.archive_camera = AsyncMock(return_value=True)

        resp = client.delete(
            f"/v1/cameras/{sample_camera['id']}",
            headers=operator_headers,
        )

        assert resp.status_code == 200

    def test_archive_camera_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_camera: dict[str, Any],
    ) -> None:
        mock_db.archive_camera = AsyncMock(return_value=False)

        resp = client.delete(
            f"/v1/cameras/{sample_camera['id']}",
            headers=operator_headers,
        )
        assert resp.status_code == 404


class TestCameraStatus:
    def test_camera_status_from_db(
        self,
        client: TestClient,
        mock_db: MagicMock,
        mock_health_cache: MagicMock,
        operator_headers: dict,
        sample_camera: dict[str, Any],
    ) -> None:
        mock_db.get_camera = AsyncMock(return_value=sample_camera)
        mock_health_cache.get_camera_health = AsyncMock(return_value=None)

        resp = client.get(
            f"/v1/cameras/{sample_camera['id']}/status",
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert resp.json()["status"] == "offline"

    def test_camera_status_from_cache(
        self,
        client: TestClient,
        mock_db: MagicMock,
        mock_health_cache: MagicMock,
        operator_headers: dict,
        sample_camera: dict[str, Any],
    ) -> None:
        mock_db.get_camera = AsyncMock(return_value=sample_camera)
        mock_health_cache.get_camera_health = AsyncMock(
            return_value={
                "status": "online",
                "last_seen": "2026-03-09T10:00:00+00:00",
                "fps": "9.8",
                "frame_width": "1920",
                "frame_height": "1080",
            }
        )

        resp = client.get(
            f"/v1/cameras/{sample_camera['id']}/status",
            headers=operator_headers,
        )

        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "online"
        assert data["fps_actual"] == 9.8
        assert data["frame_width"] == 1920
        assert data["frame_height"] == 1080

    def test_camera_status_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        mock_health_cache: MagicMock,
        operator_headers: dict,
    ) -> None:
        mock_db.get_camera = AsyncMock(return_value=None)

        resp = client.get(
            "/v1/cameras/00000000-0000-0000-0000-000000000000/status",
            headers=operator_headers,
        )
        assert resp.status_code == 404


class TestCameraHeartbeat:
    def test_heartbeat_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        mock_health_cache: MagicMock,
        operator_headers: dict,
        sample_camera: dict[str, Any],
    ) -> None:
        mock_db.get_camera = AsyncMock(return_value=sample_camera)
        mock_health_cache.record_heartbeat = AsyncMock()
        mock_db.update_camera_status = AsyncMock()

        resp = client.post(
            f"/v1/cameras/{sample_camera['id']}/heartbeat",
            json={"fps": 9.5, "frame_width": 1920, "frame_height": 1080},
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert "heartbeat" in resp.json()["message"].lower()
        mock_health_cache.record_heartbeat.assert_called_once()
        mock_db.update_camera_status.assert_called_once()

    def test_heartbeat_no_body(
        self,
        client: TestClient,
        mock_db: MagicMock,
        mock_health_cache: MagicMock,
        operator_headers: dict,
        sample_camera: dict[str, Any],
    ) -> None:
        mock_db.get_camera = AsyncMock(return_value=sample_camera)
        mock_health_cache.record_heartbeat = AsyncMock()
        mock_db.update_camera_status = AsyncMock()

        resp = client.post(
            f"/v1/cameras/{sample_camera['id']}/heartbeat",
            headers=operator_headers,
        )

        assert resp.status_code == 200

    def test_heartbeat_camera_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
    ) -> None:
        mock_db.get_camera = AsyncMock(return_value=None)

        resp = client.post(
            "/v1/cameras/00000000-0000-0000-0000-000000000000/heartbeat",
            headers=operator_headers,
        )
        assert resp.status_code == 404

    def test_heartbeat_requires_auth(self, client: TestClient) -> None:
        resp = client.post(
            "/v1/cameras/00000000-0000-0000-0000-000000000000/heartbeat",
        )
        assert resp.status_code == 401
