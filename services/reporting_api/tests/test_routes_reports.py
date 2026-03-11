"""Tests for report export and share-link endpoints."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

from fastapi.testclient import TestClient

from reporting_api.test_support import TEST_CAMERA_ID, TEST_ORG_ID, TEST_USER_ID


class TestCreateExport:
    def test_create_export_accepted(
        self, client: TestClient, operator_headers: dict
    ) -> None:
        with patch("reporting_api.routes.reports.db") as mock_db:
            mock_db.query_export_data = AsyncMock(return_value=[])

            resp = client.post(
                "/v1/reports/export",
                json={
                    "scope": f"camera:{TEST_CAMERA_ID}",
                    "start": "2026-03-09T00:00:00Z",
                    "end": "2026-03-09T23:59:59Z",
                    "format": "csv",
                    "filters": {},
                },
                headers=operator_headers,
            )

        assert resp.status_code == 202
        data = resp.json()
        assert data["status"] == "pending"
        assert "export_id" in data
        assert data["format"] == "csv"

    def test_create_export_json_format(
        self, client: TestClient, operator_headers: dict
    ) -> None:
        with patch("reporting_api.routes.reports.db") as mock_db:
            mock_db.query_export_data = AsyncMock(return_value=[])

            resp = client.post(
                "/v1/reports/export",
                json={
                    "scope": f"camera:{TEST_CAMERA_ID}",
                    "start": "2026-03-09T00:00:00Z",
                    "end": "2026-03-09T23:59:59Z",
                    "format": "json",
                },
                headers=operator_headers,
            )

        assert resp.status_code == 202
        assert resp.json()["format"] == "json"

    def test_create_export_pdf_format(
        self, client: TestClient, operator_headers: dict
    ) -> None:
        with patch("reporting_api.routes.reports.db") as mock_db:
            mock_db.query_export_data = AsyncMock(return_value=[])

            resp = client.post(
                "/v1/reports/export",
                json={
                    "scope": f"camera:{TEST_CAMERA_ID}",
                    "start": "2026-03-09T00:00:00Z",
                    "end": "2026-03-09T23:59:59Z",
                    "format": "pdf",
                },
                headers=operator_headers,
            )

        assert resp.status_code == 202
        assert resp.json()["format"] == "pdf"

    def test_analyst_can_export(
        self, client: TestClient, analyst_headers: dict
    ) -> None:
        with patch("reporting_api.routes.reports.db") as mock_db:
            mock_db.query_export_data = AsyncMock(return_value=[])

            resp = client.post(
                "/v1/reports/export",
                json={
                    "scope": f"camera:{TEST_CAMERA_ID}",
                    "start": "2026-03-09T00:00:00Z",
                    "end": "2026-03-09T23:59:59Z",
                    "format": "csv",
                },
                headers=analyst_headers,
            )

        assert resp.status_code == 202

    def test_viewer_cannot_export(
        self, client: TestClient, viewer_headers: dict
    ) -> None:
        resp = client.post(
            "/v1/reports/export",
            json={
                "scope": f"camera:{TEST_CAMERA_ID}",
                "start": "2026-03-09T00:00:00Z",
                "end": "2026-03-09T23:59:59Z",
                "format": "csv",
            },
            headers=viewer_headers,
        )

        assert resp.status_code == 403

    def test_requires_auth(self, client: TestClient) -> None:
        resp = client.post(
            "/v1/reports/export",
            json={
                "scope": f"camera:{TEST_CAMERA_ID}",
                "start": "2026-03-09T00:00:00Z",
                "end": "2026-03-09T23:59:59Z",
                "format": "csv",
            },
        )
        assert resp.status_code == 401


class TestGetExportStatus:
    def test_get_existing_export(
        self, client: TestClient, operator_headers: dict
    ) -> None:
        with patch("reporting_api.routes.reports.db") as mock_db:
            mock_db.query_export_data = AsyncMock(return_value=[])

            create_resp = client.post(
                "/v1/reports/export",
                json={
                    "scope": f"camera:{TEST_CAMERA_ID}",
                    "start": "2026-03-09T00:00:00Z",
                    "end": "2026-03-09T23:59:59Z",
                    "format": "csv",
                },
                headers=operator_headers,
            )
        export_id = create_resp.json()["export_id"]

        resp = client.get(
            f"/v1/reports/export/{export_id}",
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert resp.json()["export_id"] == export_id
        assert resp.json()["format"] == "csv"

    def test_export_not_found(
        self, client: TestClient, operator_headers: dict
    ) -> None:
        resp = client.get(
            "/v1/reports/export/nonexistent-id",
            headers=operator_headers,
        )
        assert resp.status_code == 404


class TestStreamCSVExport:
    def test_stream_csv(
        self,
        client: TestClient,
        operator_headers: dict,
        sample_export_rows: list[dict[str, Any]],
    ) -> None:
        with patch("reporting_api.routes.reports.db") as mock_db:
            mock_db.query_export_data = AsyncMock(return_value=sample_export_rows)

            resp = client.post(
                "/v1/reports/export/stream",
                json={
                    "scope": f"camera:{TEST_CAMERA_ID}",
                    "start": "2026-03-09T00:00:00Z",
                    "end": "2026-03-09T23:59:59Z",
                    "format": "csv",
                },
                headers=operator_headers,
            )

        assert resp.status_code == 200
        assert "text/csv" in resp.headers["content-type"]
        assert "attachment" in resp.headers.get("content-disposition", "")
        content = resp.text
        lines = content.strip().split("\n")
        assert len(lines) == 3  # header + 2 data rows
        assert "bucket_start" in lines[0]
        assert "Sedan/Passenger" in lines[1]

    def test_viewer_cannot_stream(
        self, client: TestClient, viewer_headers: dict
    ) -> None:
        resp = client.post(
            "/v1/reports/export/stream",
            json={
                "scope": f"camera:{TEST_CAMERA_ID}",
                "start": "2026-03-09T00:00:00Z",
                "end": "2026-03-09T23:59:59Z",
                "format": "csv",
            },
            headers=viewer_headers,
        )
        assert resp.status_code == 403


class TestCreateShareLink:
    def test_create_share_link(
        self, client: TestClient, operator_headers: dict
    ) -> None:
        mock_record = {
            "token": "abc123token",
            "org_id": str(TEST_ORG_ID),
            "created_by": str(TEST_USER_ID),
            "scope": f"camera:{TEST_CAMERA_ID}",
            "filters": {},
            "expires_at": (datetime.now(tz=UTC) + timedelta(days=7)).isoformat(),
        }
        with patch("reporting_api.routes.reports.db") as mock_db:
            mock_db.create_shared_link = AsyncMock(return_value=mock_record)

            resp = client.post(
                "/v1/reports/share",
                json={
                    "scope": f"camera:{TEST_CAMERA_ID}",
                    "filters": {},
                    "ttl_days": 7,
                },
                headers=operator_headers,
            )

        assert resp.status_code == 201
        data = resp.json()
        assert data["token"] == "abc123token"
        assert "/v1/reports/shared/abc123token" in data["url"]

    def test_analyst_can_create_share(
        self, client: TestClient, analyst_headers: dict
    ) -> None:
        mock_record = {
            "token": "analyst-token",
            "org_id": str(TEST_ORG_ID),
            "created_by": str(TEST_USER_ID),
            "scope": f"camera:{TEST_CAMERA_ID}",
            "filters": {},
            "expires_at": (datetime.now(tz=UTC) + timedelta(days=7)).isoformat(),
        }
        with patch("reporting_api.routes.reports.db") as mock_db:
            mock_db.create_shared_link = AsyncMock(return_value=mock_record)

            resp = client.post(
                "/v1/reports/share",
                json={
                    "scope": f"camera:{TEST_CAMERA_ID}",
                    "filters": {},
                },
                headers=analyst_headers,
            )

        assert resp.status_code == 201

    def test_viewer_cannot_create_share(
        self, client: TestClient, viewer_headers: dict
    ) -> None:
        resp = client.post(
            "/v1/reports/share",
            json={
                "scope": f"camera:{TEST_CAMERA_ID}",
                "filters": {},
            },
            headers=viewer_headers,
        )
        assert resp.status_code == 403


class TestAccessSharedReport:
    def test_access_valid_link(self, client: TestClient) -> None:
        mock_record = {
            "id": str(uuid4()),
            "token": "valid-token",
            "org_id": str(TEST_ORG_ID),
            "created_by": str(TEST_USER_ID),
            "scope": f'"camera:{TEST_CAMERA_ID}"',
            "filters": '{"class": [1, 2]}',
            "expires_at": datetime.now(tz=UTC) + timedelta(days=3),
            "created_at": datetime.now(tz=UTC),
        }
        with patch("reporting_api.routes.reports.db") as mock_db:
            mock_db.get_shared_link = AsyncMock(return_value=mock_record)

            resp = client.get("/v1/reports/shared/valid-token")

        assert resp.status_code == 200
        data = resp.json()
        assert f"camera:{TEST_CAMERA_ID}" in str(data["scope"])

    def test_expired_link_returns_404(self, client: TestClient) -> None:
        with patch("reporting_api.routes.reports.db") as mock_db:
            mock_db.get_shared_link = AsyncMock(return_value=None)

            resp = client.get("/v1/reports/shared/expired-token")

        assert resp.status_code == 404


class TestAccessSharedReportData:
    def test_access_data_valid_link(
        self,
        client: TestClient,
        sample_export_rows: list[dict[str, Any]],
    ) -> None:
        mock_link = {
            "id": str(uuid4()),
            "token": "data-token",
            "org_id": TEST_ORG_ID,
            "created_by": TEST_USER_ID,
            "scope": f"camera:{TEST_CAMERA_ID}",
            "filters": '{"start": "2026-03-09T00:00:00Z", "end": "2026-03-09T23:59:59Z"}',
            "expires_at": datetime.now(tz=UTC) + timedelta(days=3),
            "created_at": datetime.now(tz=UTC),
        }
        with patch("reporting_api.routes.reports.db") as mock_db:
            mock_db.get_shared_link_data = AsyncMock(
                return_value=(mock_link, sample_export_rows)
            )

            resp = client.get("/v1/reports/shared/data-token/data")

        assert resp.status_code == 200
        data = resp.json()
        assert "data" in data
        assert len(data["data"]) == 2

    def test_expired_data_link_returns_404(self, client: TestClient) -> None:
        with patch("reporting_api.routes.reports.db") as mock_db:
            mock_db.get_shared_link_data = AsyncMock(return_value=(None, []))

            resp = client.get("/v1/reports/shared/expired-token/data")

        assert resp.status_code == 404


class TestHealthEndpoints:
    def test_healthz(self, client: TestClient) -> None:
        resp = client.get("/healthz")
        assert resp.status_code == 200
        assert resp.json()["status"] == "ok"
        assert resp.json()["service"] == "reporting-api"
