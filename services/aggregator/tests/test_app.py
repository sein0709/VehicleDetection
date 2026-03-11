"""Tests for the FastAPI application: health endpoints, metrics, and error handling."""

from __future__ import annotations

from typing import TYPE_CHECKING
from unittest.mock import MagicMock, PropertyMock

if TYPE_CHECKING:
    from fastapi.testclient import TestClient


class TestHealthEndpoints:
    """Verify /healthz and /readyz."""

    def test_healthz_returns_ok(self, client: TestClient) -> None:
        resp = client.get("/healthz")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "ok"
        assert data["service"] == "aggregator"

    def test_readyz_returns_ready(self, client: TestClient) -> None:
        resp = client.get("/readyz")
        assert resp.status_code == 200
        assert resp.json()["status"] == "ready"

    def test_readyz_returns_503_when_nats_disconnected(
        self, client: TestClient, mock_consumer: MagicMock
    ) -> None:
        type(mock_consumer).is_connected = PropertyMock(return_value=False)
        client.app.state.consumer = mock_consumer

        resp = client.get("/readyz")
        assert resp.status_code == 503
        data = resp.json()
        assert "nats_disconnected" in data["reasons"]


class TestMetricsEndpoint:
    """Verify /metrics exposes Prometheus metrics."""

    def test_metrics_returns_prometheus_payload(self, client: TestClient) -> None:
        resp = client.get("/metrics")
        assert resp.status_code == 200
        assert "text/plain" in resp.headers["content-type"]
        assert "greyeye_service_info" in resp.text

    def test_metrics_includes_http_series(self, client: TestClient) -> None:
        resp = client.get("/metrics")
        assert "http_request_duration_seconds" in resp.text


class TestRequestIdMiddleware:
    """Verify X-Request-ID is set on responses."""

    def test_response_has_request_id(self, client: TestClient) -> None:
        resp = client.get("/healthz")
        assert "X-Request-ID" in resp.headers

    def test_custom_request_id_echoed(self, client: TestClient) -> None:
        resp = client.get("/healthz", headers={"X-Request-ID": "test-123"})
        assert resp.headers["X-Request-ID"] == "test-123"


class TestErrorHandling:
    """Verify error response format."""

    def test_404_returns_json(self, client: TestClient) -> None:
        resp = client.get("/nonexistent")
        assert resp.status_code == 404
