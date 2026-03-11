"""Tests for site management endpoints."""

from __future__ import annotations

from typing import Any
from unittest.mock import AsyncMock, MagicMock

from fastapi.testclient import TestClient


class TestCreateSite:
    def test_create_site_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_site: dict[str, Any],
    ) -> None:
        mock_db.create_site = AsyncMock(return_value=sample_site)

        resp = client.post(
            "/v1/sites",
            json={
                "name": "강남역 교차로",
                "address": "서울특별시 강남구",
                "timezone": "Asia/Seoul",
            },
            headers=operator_headers,
        )

        assert resp.status_code == 201
        data = resp.json()
        assert data["name"] == "강남역 교차로"
        assert data["status"] == "active"
        mock_db.create_site.assert_called_once()

    def test_create_site_requires_auth(self, client: TestClient) -> None:
        resp = client.post("/v1/sites", json={"name": "Test"})
        assert resp.status_code == 401

    def test_create_site_viewer_forbidden(self, client: TestClient, viewer_headers: dict) -> None:
        resp = client.post(
            "/v1/sites",
            json={"name": "Test"},
            headers=viewer_headers,
        )
        assert resp.status_code == 403

    def test_create_site_normalizes_postgis_location(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_site: dict[str, Any],
    ) -> None:
        site_with_postgis = {
            **sample_site,
            "location": "0101000020E6100000A857CA32C4C15F40D656EC2FBBBF4240",
        }
        mock_db.create_site = AsyncMock(return_value=site_with_postgis)

        resp = client.post(
            "/v1/sites",
            json={"name": "강남역 교차로"},
            headers=operator_headers,
        )

        assert resp.status_code == 201
        assert resp.json()["location"] == {
            "type": "Point",
            "coordinates": [127.0276, 37.4979],
        }


class TestListSites:
    def test_list_sites_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_site: dict[str, Any],
    ) -> None:
        mock_db.list_sites = AsyncMock(return_value=([sample_site], 1))

        resp = client.get("/v1/sites", headers=operator_headers)

        assert resp.status_code == 200
        data = resp.json()
        assert len(data["data"]) == 1
        assert data["pagination"]["total_count"] == 1


class TestGetSite:
    def test_get_site_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_site: dict[str, Any],
    ) -> None:
        mock_db.get_site = AsyncMock(return_value=sample_site)

        resp = client.get(f"/v1/sites/{sample_site['id']}", headers=operator_headers)

        assert resp.status_code == 200
        assert resp.json()["name"] == "강남역 교차로"

    def test_get_site_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
    ) -> None:
        mock_db.get_site = AsyncMock(return_value=None)

        resp = client.get(
            "/v1/sites/00000000-0000-0000-0000-000000000000", headers=operator_headers
        )
        assert resp.status_code == 404


class TestUpdateSite:
    def test_update_site_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_site: dict[str, Any],
    ) -> None:
        updated = {**sample_site, "name": "Updated Name", "active_config_version": 2}
        mock_db.update_site = AsyncMock(return_value=updated)

        resp = client.patch(
            f"/v1/sites/{sample_site['id']}",
            json={"name": "Updated Name"},
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert resp.json()["name"] == "Updated Name"

    def test_update_site_empty_body(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_site: dict[str, Any],
    ) -> None:
        resp = client.patch(
            f"/v1/sites/{sample_site['id']}",
            json={},
            headers=operator_headers,
        )
        assert resp.status_code == 422


class TestArchiveSite:
    def test_archive_site_success_admin(
        self,
        client: TestClient,
        mock_db: MagicMock,
        admin_headers: dict,
        sample_site: dict[str, Any],
    ) -> None:
        mock_db.archive_site = AsyncMock(return_value=True)

        resp = client.delete(
            f"/v1/sites/{sample_site['id']}",
            headers=admin_headers,
        )

        assert resp.status_code == 200
        assert "archived" in resp.json()["message"].lower()

    def test_archive_site_forbidden_for_operator(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_site: dict[str, Any],
    ) -> None:
        resp = client.delete(
            f"/v1/sites/{sample_site['id']}",
            headers=operator_headers,
        )
        assert resp.status_code == 403

    def test_archive_site_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        admin_headers: dict,
        sample_site: dict[str, Any],
    ) -> None:
        mock_db.archive_site = AsyncMock(return_value=False)

        resp = client.delete(
            f"/v1/sites/{sample_site['id']}",
            headers=admin_headers,
        )
        assert resp.status_code == 404
