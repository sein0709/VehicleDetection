"""Tests for analytics endpoints."""

from __future__ import annotations

from typing import Any
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from tests.conftest import TEST_CAMERA_ID, TEST_SITE_ID


class TestGet15mBuckets:
    def test_returns_paginated_buckets(
        self,
        client: TestClient,
        operator_headers: dict,
        sample_bucket_rows: list[dict[str, Any]],
    ) -> None:
        with patch("reporting_api.routes.analytics.db") as mock_db:
            mock_db.query_15m_buckets = AsyncMock(
                return_value=(sample_bucket_rows, None)
            )

            resp = client.get(
                "/v1/analytics/15m",
                params={
                    "camera_id": str(TEST_CAMERA_ID),
                    "start": "2026-03-09T10:00:00Z",
                    "end": "2026-03-09T11:00:00Z",
                },
                headers=operator_headers,
            )

        assert resp.status_code == 200
        data = resp.json()
        assert "buckets" in data
        assert "pagination" in data
        assert len(data["buckets"]) == 2
        assert data["buckets"][0]["total_count"] == 42
        assert "bucket_start" in data["buckets"][0]
        assert "bucket_end" in data["buckets"][0]
        assert data["pagination"]["has_more"] is False

    def test_returns_with_pagination_cursor(
        self,
        client: TestClient,
        operator_headers: dict,
        sample_bucket_rows: list[dict[str, Any]],
    ) -> None:
        next_cursor = "dGVzdC1jdXJzb3I="
        with patch("reporting_api.routes.analytics.db") as mock_db:
            mock_db.query_15m_buckets = AsyncMock(
                return_value=(sample_bucket_rows, next_cursor)
            )

            resp = client.get(
                "/v1/analytics/15m",
                params={
                    "camera_id": str(TEST_CAMERA_ID),
                    "start": "2026-03-09T10:00:00Z",
                    "end": "2026-03-09T11:00:00Z",
                    "limit": "2",
                },
                headers=operator_headers,
            )

        assert resp.status_code == 200
        data = resp.json()
        assert data["pagination"]["has_more"] is True
        assert data["pagination"]["cursor"] == next_cursor

    def test_group_by_class(
        self,
        client: TestClient,
        operator_headers: dict,
        sample_bucket_rows_with_class: list[dict[str, Any]],
    ) -> None:
        with patch("reporting_api.routes.analytics.db") as mock_db:
            mock_db.query_15m_buckets = AsyncMock(
                return_value=(sample_bucket_rows_with_class, None)
            )

            resp = client.get(
                "/v1/analytics/15m",
                params={
                    "camera_id": str(TEST_CAMERA_ID),
                    "start": "2026-03-09T10:00:00Z",
                    "end": "2026-03-09T11:00:00Z",
                    "group_by": "class",
                },
                headers=operator_headers,
            )

        assert resp.status_code == 200
        data = resp.json()
        assert len(data["buckets"]) == 2
        assert "1" in data["buckets"][0]["by_class"]

    def test_site_level_query(
        self,
        client: TestClient,
        operator_headers: dict,
        sample_bucket_rows: list[dict[str, Any]],
    ) -> None:
        with patch("reporting_api.routes.analytics.db") as mock_db:
            mock_db.query_15m_buckets = AsyncMock(
                return_value=(sample_bucket_rows, None)
            )

            resp = client.get(
                "/v1/analytics/15m",
                params={
                    "site_id": str(TEST_SITE_ID),
                    "start": "2026-03-09T10:00:00Z",
                    "end": "2026-03-09T11:00:00Z",
                },
                headers=operator_headers,
            )

        assert resp.status_code == 200
        call_kwargs = mock_db.query_15m_buckets.call_args
        assert call_kwargs.kwargs.get("site_id") == TEST_SITE_ID

    def test_class_filter(
        self,
        client: TestClient,
        operator_headers: dict,
        sample_bucket_rows: list[dict[str, Any]],
    ) -> None:
        with patch("reporting_api.routes.analytics.db") as mock_db:
            mock_db.query_15m_buckets = AsyncMock(
                return_value=(sample_bucket_rows, None)
            )

            resp = client.get(
                "/v1/analytics/15m",
                params={
                    "camera_id": str(TEST_CAMERA_ID),
                    "start": "2026-03-09T10:00:00Z",
                    "end": "2026-03-09T11:00:00Z",
                    "class_filter": "1,2,5",
                },
                headers=operator_headers,
            )

        assert resp.status_code == 200
        call_kwargs = mock_db.query_15m_buckets.call_args
        assert call_kwargs.kwargs.get("class_filter") == [1, 2, 5]

    def test_requires_auth(self, client: TestClient) -> None:
        resp = client.get(
            "/v1/analytics/15m",
            params={
                "camera_id": str(TEST_CAMERA_ID),
                "start": "2026-03-09T10:00:00Z",
                "end": "2026-03-09T11:00:00Z",
            },
        )
        assert resp.status_code == 401

    def test_avg_speed_in_response(
        self,
        client: TestClient,
        operator_headers: dict,
        sample_bucket_rows: list[dict[str, Any]],
    ) -> None:
        with patch("reporting_api.routes.analytics.db") as mock_db:
            mock_db.query_15m_buckets = AsyncMock(
                return_value=(sample_bucket_rows, None)
            )

            resp = client.get(
                "/v1/analytics/15m",
                params={
                    "camera_id": str(TEST_CAMERA_ID),
                    "start": "2026-03-09T10:00:00Z",
                    "end": "2026-03-09T11:00:00Z",
                },
                headers=operator_headers,
            )

        data = resp.json()
        assert data["buckets"][0]["avg_speed_kmh"] == 50.0


class TestGetKPI:
    def test_returns_kpi(
        self,
        client: TestClient,
        operator_headers: dict,
        sample_kpi: dict[str, Any],
    ) -> None:
        with patch("reporting_api.routes.analytics.db") as mock_db:
            mock_db.query_kpi = AsyncMock(return_value=sample_kpi)

            resp = client.get(
                "/v1/analytics/kpi",
                params={
                    "camera_id": str(TEST_CAMERA_ID),
                    "start": "2026-03-09T10:00:00Z",
                    "end": "2026-03-09T14:00:00Z",
                },
                headers=operator_headers,
            )

        assert resp.status_code == 200
        data = resp.json()
        assert data["total_count"] == 1250
        assert data["flow_rate_per_hour"] == 312.5
        assert data["heavy_vehicle_ratio"] == 0.16
        assert data["avg_speed_kmh"] == 52.3

    def test_kpi_with_site_id(
        self,
        client: TestClient,
        operator_headers: dict,
        sample_kpi: dict[str, Any],
    ) -> None:
        with patch("reporting_api.routes.analytics.db") as mock_db:
            mock_db.query_kpi = AsyncMock(return_value=sample_kpi)

            resp = client.get(
                "/v1/analytics/kpi",
                params={
                    "site_id": str(TEST_SITE_ID),
                    "start": "2026-03-09T10:00:00Z",
                    "end": "2026-03-09T14:00:00Z",
                },
                headers=operator_headers,
            )

        assert resp.status_code == 200
        data = resp.json()
        assert data["site_id"] == str(TEST_SITE_ID)
        assert data["camera_id"] is None

    def test_requires_auth(self, client: TestClient) -> None:
        resp = client.get(
            "/v1/analytics/kpi",
            params={
                "camera_id": str(TEST_CAMERA_ID),
                "start": "2026-03-09T10:00:00Z",
                "end": "2026-03-09T14:00:00Z",
            },
        )
        assert resp.status_code == 401


class TestGetLiveKPI:
    def test_returns_live_data(
        self, client: TestClient, operator_headers: dict
    ) -> None:
        live_data = {
            "bucket_start": "2026-03-09T10:00:00",
            "elapsed_seconds": 450,
            "total_count": 15,
            "class_counts": {1: 12, 2: 3},
            "direction_counts": {"inbound": 8, "outbound": 7},
            "active_tracks": 5,
            "flow_rate_per_hour": 120.0,
        }
        with patch("reporting_api.routes.analytics.redis_client") as mock_redis:
            mock_redis.get_live_bucket = AsyncMock(return_value=live_data)

            resp = client.get(
                "/v1/analytics/live",
                params={"camera_id": str(TEST_CAMERA_ID)},
                headers=operator_headers,
            )

        assert resp.status_code == 200
        data = resp.json()
        assert data["camera_id"] == str(TEST_CAMERA_ID)
        assert data["active_tracks"] == 5
        assert data["counts"]["total"] == 15
        assert data["counts"]["by_class"] == {"1": 12, "2": 3}

    def test_returns_empty_when_no_data(
        self, client: TestClient, operator_headers: dict
    ) -> None:
        with patch("reporting_api.routes.analytics.redis_client") as mock_redis:
            mock_redis.get_live_bucket = AsyncMock(return_value=None)

            resp = client.get(
                "/v1/analytics/live",
                params={"camera_id": str(TEST_CAMERA_ID)},
                headers=operator_headers,
            )

        assert resp.status_code == 200
        data = resp.json()
        assert data["active_tracks"] == 0
        assert data["flow_rate_per_hour"] == 0.0


class TestCompareRanges:
    def test_compare_success(
        self, client: TestClient, operator_headers: dict
    ) -> None:
        comparison = {
            "range1": {"total_count": 100, "avg_speed_kmh": 55.0},
            "range2": {"total_count": 130, "avg_speed_kmh": 52.0},
            "count_delta": 30,
            "count_change_pct": 30.0,
        }
        with patch("reporting_api.routes.analytics.db") as mock_db:
            mock_db.query_comparison = AsyncMock(return_value=comparison)

            resp = client.get(
                "/v1/analytics/compare",
                params={
                    "camera_id": str(TEST_CAMERA_ID),
                    "range1_start": "2026-03-08T08:00:00Z",
                    "range1_end": "2026-03-08T12:00:00Z",
                    "range2_start": "2026-03-09T08:00:00Z",
                    "range2_end": "2026-03-09T12:00:00Z",
                },
                headers=operator_headers,
            )

        assert resp.status_code == 200
        data = resp.json()
        assert data["count_delta"] == 30
        assert data["count_change_pct"] == 30.0

    def test_compare_with_site_id(
        self, client: TestClient, operator_headers: dict
    ) -> None:
        comparison = {
            "range1": {"total_count": 200, "avg_speed_kmh": 50.0},
            "range2": {"total_count": 180, "avg_speed_kmh": 48.0},
            "count_delta": -20,
            "count_change_pct": -10.0,
        }
        with patch("reporting_api.routes.analytics.db") as mock_db:
            mock_db.query_comparison = AsyncMock(return_value=comparison)

            resp = client.get(
                "/v1/analytics/compare",
                params={
                    "site_id": str(TEST_SITE_ID),
                    "range1_start": "2026-03-08T08:00:00Z",
                    "range1_end": "2026-03-08T12:00:00Z",
                    "range2_start": "2026-03-09T08:00:00Z",
                    "range2_end": "2026-03-09T12:00:00Z",
                },
                headers=operator_headers,
            )

        assert resp.status_code == 200
        data = resp.json()
        assert data["site_id"] == str(TEST_SITE_ID)
        assert data["count_delta"] == -20

    def test_requires_auth(self, client: TestClient) -> None:
        resp = client.get(
            "/v1/analytics/compare",
            params={
                "camera_id": str(TEST_CAMERA_ID),
                "range1_start": "2026-03-08T08:00:00Z",
                "range1_end": "2026-03-08T12:00:00Z",
                "range2_start": "2026-03-09T08:00:00Z",
                "range2_end": "2026-03-09T12:00:00Z",
            },
        )
        assert resp.status_code == 401
