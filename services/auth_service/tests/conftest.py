"""Shared fixtures for auth service tests.

Provides a fully-configured test client with mocked Supabase and Redis
backends, so tests run without external dependencies.
"""

from __future__ import annotations

import secrets
from collections.abc import AsyncGenerator
from datetime import UTC
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient

from auth_service.app import create_app
from auth_service.redis_client import RedisTokenStore
from auth_service.settings import Settings
from auth_service.supabase_client import SupabaseAuthClient
from auth_service.test_support import (
    TEST_ADMIN_ID,
    TEST_ORG_ID,
    TEST_USER_ID,
    make_user_record as _make_user_record,
)
from auth_service.tokens import TokenService


def _make_settings(**overrides: Any) -> Settings:
    defaults = {
        "supabase_url": "http://localhost:54321",
        "supabase_anon_key": "test-anon-key",
        "supabase_service_role_key": "test-service-key",
        "database_url": "postgresql://test:test@localhost:5432/test",
        "redis_url": "redis://localhost:6379/15",
        "jwt_secret": "test-secret-key-for-unit-tests-only",
        "jwt_algorithm": "HS256",
        "access_token_expire_minutes": 15,
        "refresh_token_expire_days": 7,
        "step_up_window_seconds": 300,
        "debug": True,
    }
    defaults.update(overrides)
    return Settings(**defaults)



@pytest.fixture
def settings() -> Settings:
    return _make_settings()


@pytest.fixture
def token_service(settings: Settings) -> TokenService:
    return TokenService(settings)


@pytest.fixture
def mock_supabase() -> AsyncMock:
    mock = AsyncMock(spec=SupabaseAuthClient)
    mock.close = AsyncMock()
    mock.write_audit_log = AsyncMock()
    return mock


@pytest.fixture
def mock_redis() -> AsyncMock:
    mock = AsyncMock(spec=RedisTokenStore)
    mock.close = AsyncMock()
    mock.is_token_denied = AsyncMock(return_value=False)
    mock.has_step_up = AsyncMock(return_value=False)
    mock.store_refresh_token = AsyncMock()
    mock.get_refresh_token = AsyncMock(return_value=None)
    mock.revoke_refresh_token = AsyncMock()
    mock.revoke_token_family = AsyncMock()
    mock.deny_access_token = AsyncMock()
    mock.set_step_up = AsyncMock()
    mock._redis = AsyncMock()
    mock._redis.ping = AsyncMock()
    return mock


@pytest.fixture
def app(settings: Settings, mock_supabase: AsyncMock, mock_redis: AsyncMock):
    application = create_app(settings)
    application.state.supabase_client = mock_supabase
    application.state.token_service = TokenService(settings)
    application.state.redis_store = mock_redis
    application.state.settings = settings
    return application


@pytest.fixture
def client(app) -> TestClient:
    return TestClient(app, raise_server_exceptions=False)


@pytest.fixture
def admin_token(token_service: TokenService) -> str:
    return token_service.create_access_token(
        user_id=TEST_ADMIN_ID,
        org_id=TEST_ORG_ID,
        role="admin",
        email="admin@example.com",
        name="Test Admin",
    )


@pytest.fixture
def operator_token(token_service: TokenService) -> str:
    return token_service.create_access_token(
        user_id=TEST_USER_ID,
        org_id=TEST_ORG_ID,
        role="operator",
        email="operator@example.com",
        name="Test Operator",
    )


@pytest.fixture
def viewer_token(token_service: TokenService) -> str:
    return token_service.create_access_token(
        user_id=UUID("00000000-0000-0000-0000-000000000030"),
        org_id=TEST_ORG_ID,
        role="viewer",
        email="viewer@example.com",
        name="Test Viewer",
    )


@pytest.fixture
def admin_headers(admin_token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {admin_token}"}


@pytest.fixture
def operator_headers(operator_token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {operator_token}"}


@pytest.fixture
def viewer_headers(viewer_token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {viewer_token}"}
