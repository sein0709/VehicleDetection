"""Tests for ROI preset management endpoints."""

from __future__ import annotations

from typing import Any
from unittest.mock import AsyncMock, MagicMock

from fastapi.testclient import TestClient


class TestCreateROIPreset:
    def test_create_preset_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_camera: dict[str, Any],
        sample_preset: dict[str, Any],
    ) -> None:
        mock_db.get_camera = AsyncMock(return_value=sample_camera)
        mock_db.create_roi_preset = AsyncMock(return_value=sample_preset)

        resp = client.post(
            f"/v1/cameras/{sample_camera['id']}/roi-presets",
            json={
                "name": "평일 기본",
                "roi_polygon": {
                    "type": "Polygon",
                    "coordinates": [[[0.1, 0.2], [0.9, 0.2], [0.9, 0.95], [0.1, 0.95], [0.1, 0.2]]],
                },
                "counting_lines": [
                    {
                        "name": "남북 통행선",
                        "start": {"x": 0.2, "y": 0.5},
                        "end": {"x": 0.8, "y": 0.5},
                        "direction": "inbound",
                        "direction_vector": {"dx": 0.0, "dy": -1.0},
                    }
                ],
            },
            headers=operator_headers,
        )

        assert resp.status_code == 201
        assert resp.json()["name"] == "평일 기본"

    def test_create_preset_camera_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
    ) -> None:
        mock_db.get_camera = AsyncMock(return_value=None)

        resp = client.post(
            "/v1/cameras/00000000-0000-0000-0000-000000000000/roi-presets",
            json={
                "name": "Test",
                "roi_polygon": {
                    "type": "Polygon",
                    "coordinates": [[[0, 0], [1, 0], [1, 1], [0, 0]]],
                },
            },
            headers=operator_headers,
        )
        assert resp.status_code == 404


class TestListROIPresets:
    def test_list_presets_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_camera: dict[str, Any],
        sample_preset: dict[str, Any],
    ) -> None:
        mock_db.list_roi_presets = AsyncMock(return_value=[sample_preset])

        resp = client.get(
            f"/v1/cameras/{sample_camera['id']}/roi-presets",
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert len(resp.json()) == 1


class TestGetROIPreset:
    def test_get_preset_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_preset: dict[str, Any],
    ) -> None:
        mock_db.get_roi_preset = AsyncMock(return_value=sample_preset)

        resp = client.get(
            f"/v1/roi-presets/{sample_preset['id']}",
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert resp.json()["name"] == "평일 기본"


class TestActivateROIPreset:
    def test_activate_preset_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_preset: dict[str, Any],
    ) -> None:
        activated = {**sample_preset, "is_active": True}
        mock_db.activate_roi_preset = AsyncMock(return_value=activated)

        resp = client.post(
            f"/v1/roi-presets/{sample_preset['id']}/activate",
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert resp.json()["is_active"] is True


class TestUpdateROIPreset:
    def test_update_preset_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_preset: dict[str, Any],
    ) -> None:
        updated = {**sample_preset, "name": "주말 설정", "version": 2}
        mock_db.update_roi_preset = AsyncMock(return_value=updated)

        resp = client.put(
            f"/v1/roi-presets/{sample_preset['id']}",
            json={"name": "주말 설정"},
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert resp.json()["name"] == "주말 설정"

    def test_update_preset_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_preset: dict[str, Any],
    ) -> None:
        mock_db.update_roi_preset = AsyncMock(return_value=None)

        resp = client.put(
            f"/v1/roi-presets/{sample_preset['id']}",
            json={"name": "New Name"},
            headers=operator_headers,
        )
        assert resp.status_code == 404

    def test_update_preset_viewer_forbidden(
        self,
        client: TestClient,
        viewer_headers: dict,
        sample_preset: dict[str, Any],
    ) -> None:
        resp = client.put(
            f"/v1/roi-presets/{sample_preset['id']}",
            json={"name": "Nope"},
            headers=viewer_headers,
        )
        assert resp.status_code == 403


class TestDeleteROIPreset:
    def test_delete_preset_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_preset: dict[str, Any],
    ) -> None:
        mock_db.delete_roi_preset = AsyncMock(return_value=True)

        resp = client.delete(
            f"/v1/roi-presets/{sample_preset['id']}",
            headers=operator_headers,
        )

        assert resp.status_code == 200

    def test_delete_preset_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_preset: dict[str, Any],
    ) -> None:
        mock_db.delete_roi_preset = AsyncMock(return_value=False)

        resp = client.delete(
            f"/v1/roi-presets/{sample_preset['id']}",
            headers=operator_headers,
        )
        assert resp.status_code == 404
