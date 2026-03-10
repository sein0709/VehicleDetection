"""Tests for FastAPI authentication and authorization dependencies."""

from __future__ import annotations

from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from auth_service.tokens import TokenService

from .conftest import TEST_ADMIN_ID, TEST_ORG_ID, TEST_USER_ID


class TestAuthDependency:
    def test_missing_header_returns_401(self, client: TestClient):
        resp = client.get("/v1/users/me")
        assert resp.status_code == 401

    def test_malformed_header_returns_401(self, client: TestClient):
        resp = client.get("/v1/users/me", headers={"Authorization": "NotBearer token"})
        assert resp.status_code == 401

    def test_empty_bearer_returns_401(self, client: TestClient):
        resp = client.get("/v1/users/me", headers={"Authorization": "Bearer "})
        assert resp.status_code == 401

    def test_invalid_jwt_returns_401(self, client: TestClient):
        resp = client.get("/v1/users/me", headers={"Authorization": "Bearer invalid.jwt.token"})
        assert resp.status_code == 401

    def test_denied_token_returns_401(
        self, client: TestClient, operator_headers: dict, mock_redis: AsyncMock,
    ):
        mock_redis.is_token_denied.return_value = True
        resp = client.get("/v1/users/me", headers=operator_headers)
        assert resp.status_code == 401
        assert "revoked" in resp.json()["detail"].lower()


class TestRequestIdMiddleware:
    def test_generates_request_id(self, client: TestClient):
        resp = client.get("/healthz")
        assert "x-request-id" in resp.headers

    def test_preserves_provided_request_id(self, client: TestClient):
        resp = client.get("/healthz", headers={"X-Request-ID": "custom-123"})
        assert resp.headers["x-request-id"] == "custom-123"
