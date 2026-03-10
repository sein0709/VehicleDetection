"""Tests for health and readiness endpoints."""

from __future__ import annotations

from typing import TYPE_CHECKING
from unittest.mock import AsyncMock, MagicMock, PropertyMock

if TYPE_CHECKING:
    from fastapi.testclient import TestClient


class TestHealthCheck:
    def test_healthz(self, client: TestClient) -> None:
        resp = client.get("/healthz")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "ok"
        assert data["service"] == "ingest-service"

    def test_readyz_all_healthy(
        self,
        client: TestClient,
        mock_health_cache: MagicMock,
        mock_nats: MagicMock,
    ) -> None:
        resp = client.get("/readyz")
        assert resp.status_code == 200
        assert resp.json()["status"] == "ready"

    def test_readyz_redis_down(
        self,
        client: TestClient,
        mock_health_cache: MagicMock,
        mock_nats: MagicMock,
    ) -> None:
        mock_health_cache._redis.ping = AsyncMock(side_effect=ConnectionError("Redis down"))

        resp = client.get("/readyz")
        assert resp.status_code == 503
        data = resp.json()
        assert "redis_unavailable" in data["reasons"]

    def test_readyz_nats_disconnected(
        self,
        client: TestClient,
        mock_health_cache: MagicMock,
        mock_nats: MagicMock,
    ) -> None:
        type(mock_nats).is_connected = PropertyMock(return_value=False)

        resp = client.get("/readyz")
        assert resp.status_code == 503
        data = resp.json()
        assert "nats_disconnected" in data["reasons"]

    def test_readyz_both_down(
        self,
        client: TestClient,
        mock_health_cache: MagicMock,
        mock_nats: MagicMock,
    ) -> None:
        mock_health_cache._redis.ping = AsyncMock(side_effect=ConnectionError("Redis down"))
        type(mock_nats).is_connected = PropertyMock(return_value=False)

        resp = client.get("/readyz")
        assert resp.status_code == 503
        data = resp.json()
        assert "redis_unavailable" in data["reasons"]
        assert "nats_disconnected" in data["reasons"]
