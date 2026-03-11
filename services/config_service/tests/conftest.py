"""Shared fixtures for Config Service tests."""

from __future__ import annotations

import secrets
from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import AsyncMock, MagicMock
from uuid import UUID, uuid4

import jwt
import pytest
from config_service.app import create_app
from config_service.db import ConfigDB
from config_service.redis_client import CameraHealthCache
from config_service.settings import Settings
from fastapi.testclient import TestClient
from config_service.test_support import TEST_ORG_ID, TEST_SITE_ID, TEST_USER_ID

TEST_CAMERA_ID = uuid4()
TEST_PRESET_ID = uuid4()

JWT_SECRET = "test-secret"


def _make_token(
    role: str = "operator",
    user_id: UUID | None = None,
    org_id: UUID | None = None,
) -> str:
    now = datetime.now(tz=UTC)
    payload = {
        "sub": str(user_id or TEST_USER_ID),
        "org_id": str(org_id or TEST_ORG_ID),
        "role": role,
        "email": f"{role}@test.com",
        "name": f"Test {role.title()}",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(hours=1)).timestamp()),
        "jti": secrets.token_hex(16),
        "iss": "greyeye-auth",
        "aud": "greyeye-api",
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


@pytest.fixture()
def settings() -> Settings:
    return Settings(
        supabase_url="http://localhost:54321",
        supabase_anon_key="test-anon-key",
        supabase_service_role_key="test-service-key",
        database_url="postgresql://test:test@localhost:5432/test",
        redis_url="redis://localhost:6379/0",
        jwt_secret=JWT_SECRET,
        jwt_algorithm="HS256",
    )


@pytest.fixture()
def mock_db() -> MagicMock:
    db = MagicMock(spec=ConfigDB)
    db.write_audit_log = AsyncMock()
    return db


@pytest.fixture()
def mock_health_cache() -> MagicMock:
    cache = MagicMock(spec=CameraHealthCache)
    cache._redis = AsyncMock()
    cache._redis.ping = AsyncMock()
    cache.get_camera_health = AsyncMock(return_value=None)
    cache.close = AsyncMock()
    return cache


@pytest.fixture()
def client(settings: Settings, mock_db: MagicMock, mock_health_cache: MagicMock) -> TestClient:
    app = create_app(settings)
    app.state.config_db = mock_db
    app.state.health_cache = mock_health_cache
    return TestClient(app, raise_server_exceptions=False)


@pytest.fixture()
def operator_headers() -> dict[str, str]:
    return {"Authorization": f"Bearer {_make_token('operator')}"}


@pytest.fixture()
def admin_headers() -> dict[str, str]:
    return {"Authorization": f"Bearer {_make_token('admin')}"}


@pytest.fixture()
def viewer_headers() -> dict[str, str]:
    return {"Authorization": f"Bearer {_make_token('viewer')}"}


@pytest.fixture()
def sample_site() -> dict[str, Any]:
    return {
        "id": str(TEST_SITE_ID),
        "org_id": str(TEST_ORG_ID),
        "name": "강남역 교차로",
        "address": "서울특별시 강남구",
        "location": None,
        "geofence": None,
        "timezone": "Asia/Seoul",
        "status": "active",
        "active_config_version": 1,
        "created_at": datetime.now(tz=UTC).isoformat(),
        "updated_at": datetime.now(tz=UTC).isoformat(),
        "created_by": str(TEST_USER_ID),
    }


@pytest.fixture()
def sample_camera() -> dict[str, Any]:
    return {
        "id": str(TEST_CAMERA_ID),
        "site_id": str(TEST_SITE_ID),
        "org_id": str(TEST_ORG_ID),
        "name": "남측 카메라",
        "source_type": "smartphone",
        "rtsp_url": None,
        "settings": {
            "target_fps": 10,
            "resolution": "1920x1080",
            "night_mode": False,
            "classification_mode": "full_12class",
        },
        "status": "offline",
        "active_config_version": 1,
        "last_seen_at": None,
        "created_at": datetime.now(tz=UTC).isoformat(),
        "updated_at": datetime.now(tz=UTC).isoformat(),
    }


@pytest.fixture()
def sample_preset() -> dict[str, Any]:
    return {
        "id": str(TEST_PRESET_ID),
        "camera_id": str(TEST_CAMERA_ID),
        "org_id": str(TEST_ORG_ID),
        "name": "평일 기본",
        "roi_polygon": {
            "type": "Polygon",
            "coordinates": [[[0.1, 0.2], [0.9, 0.2], [0.9, 0.95], [0.1, 0.95], [0.1, 0.2]]],
        },
        "counting_lines": [],
        "lane_polylines": [],
        "is_active": False,
        "version": 1,
        "created_at": datetime.now(tz=UTC).isoformat(),
        "created_by": str(TEST_USER_ID),
    }
