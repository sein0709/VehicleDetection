"""Tests for the FastAPI observability middleware integration."""

from __future__ import annotations

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from observability.logging import reset_logging
from observability.middleware import setup_observability


@pytest.fixture()
def app() -> FastAPI:
    reset_logging()

    test_app = FastAPI(title="Test App")

    setup_observability(
        test_app,
        service_name="test-service",
        log_level="DEBUG",
        json_logs=True,
        tracing_enabled=False,
    )

    @test_app.get("/hello")
    async def hello():
        return {"message": "world"}

    @test_app.get("/healthz")
    async def healthz():
        return {"status": "ok"}

    return test_app


@pytest.fixture()
def client(app: FastAPI) -> TestClient:
    return TestClient(app)


class TestRequestContextMiddleware:
    def test_response_has_request_id(self, client: TestClient) -> None:
        resp = client.get("/hello")
        assert resp.status_code == 200
        assert "X-Request-ID" in resp.headers

    def test_custom_request_id_preserved(self, client: TestClient) -> None:
        resp = client.get("/hello", headers={"X-Request-ID": "my-custom-id"})
        assert resp.headers["X-Request-ID"] == "my-custom-id"

    def test_generated_request_id_is_hex(self, client: TestClient) -> None:
        resp = client.get("/hello")
        rid = resp.headers["X-Request-ID"]
        assert len(rid) == 32
        int(rid, 16)


class TestMetricsEndpoint:
    def test_metrics_endpoint_exists(self, client: TestClient) -> None:
        resp = client.get("/metrics")
        assert resp.status_code == 200
        body = resp.text
        assert "http_request_duration_seconds" in body or "greyeye_service_info" in body

    def test_metrics_content_type(self, client: TestClient) -> None:
        resp = client.get("/metrics")
        assert "text/plain" in resp.headers["content-type"]


class TestHealthEndpointsNotMetered:
    def test_healthz_not_counted_in_metrics(self, client: TestClient) -> None:
        client.get("/healthz")
        resp = client.get("/metrics")
        body = resp.text
        lines = [l for l in body.split("\n") if "/healthz" in l and "http_requests_total" in l]
        assert len(lines) == 0
