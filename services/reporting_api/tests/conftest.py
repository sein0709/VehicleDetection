"""Shared fixtures for Reporting API tests."""

from __future__ import annotations

import secrets
from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import AsyncMock, patch
from uuid import UUID, uuid4

import jwt
import pytest
from fastapi.testclient import TestClient
from reporting_api.app import create_app
from reporting_api.settings import Settings

TEST_ORG_ID = uuid4()
TEST_USER_ID = uuid4()
TEST_CAMERA_ID = uuid4()
TEST_SITE_ID = uuid4()
TEST_LINE_ID = uuid4()

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
        database_url="postgresql://test:test@localhost:5432/test",
        redis_url="redis://localhost:6379/0",
        jwt_secret=JWT_SECRET,
        jwt_algorithm="HS256",
        s3_endpoint="http://localhost:9000",
        s3_bucket="test-exports",
        s3_access_key="minioadmin",
        s3_secret_key="minioadmin",
    )


@pytest.fixture()
def client(settings: Settings) -> TestClient:
    with (
        patch("reporting_api.app.db") as mock_db_mod,
        patch("reporting_api.app.redis_client") as mock_redis_mod,
    ):
        mock_db_mod.connect = AsyncMock()
        mock_db_mod.close = AsyncMock()
        mock_db_mod._get_pool = AsyncMock()
        mock_redis_mod.connect = AsyncMock()
        mock_redis_mod.close = AsyncMock()
        mock_redis_mod._get_redis = AsyncMock()

        app = create_app(settings)
        yield TestClient(app, raise_server_exceptions=False)


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
def analyst_headers() -> dict[str, str]:
    return {"Authorization": f"Bearer {_make_token('analyst')}"}


@pytest.fixture()
def sample_bucket_rows() -> list[dict[str, Any]]:
    base = datetime(2026, 3, 9, 10, 0, tzinfo=UTC)
    return [
        {
            "bucket_start": base,
            "count": 42,
            "sum_confidence": 38.5,
            "sum_speed_kmh": 2100.0,
            "min_speed_kmh": 20.0,
            "max_speed_kmh": 80.0,
        },
        {
            "bucket_start": base + timedelta(minutes=15),
            "count": 37,
            "sum_confidence": 33.2,
            "sum_speed_kmh": 1850.0,
            "min_speed_kmh": 15.0,
            "max_speed_kmh": 75.0,
        },
    ]


@pytest.fixture()
def sample_bucket_rows_with_class() -> list[dict[str, Any]]:
    base = datetime(2026, 3, 9, 10, 0, tzinfo=UTC)
    return [
        {
            "bucket_start": base,
            "class12": 1,
            "count": 30,
            "sum_confidence": 27.0,
            "sum_speed_kmh": 1500.0,
            "min_speed_kmh": 25.0,
            "max_speed_kmh": 75.0,
        },
        {
            "bucket_start": base,
            "class12": 5,
            "count": 12,
            "sum_confidence": 11.5,
            "sum_speed_kmh": 600.0,
            "min_speed_kmh": 20.0,
            "max_speed_kmh": 80.0,
        },
    ]


@pytest.fixture()
def sample_kpi() -> dict[str, Any]:
    return {
        "total_count": 1250,
        "flow_rate_per_hour": 312.5,
        "class_distribution": {1: 800, 2: 150, 3: 100, 5: 100, 8: 100},
        "heavy_vehicle_ratio": 0.16,
        "avg_speed_kmh": 52.3,
    }


@pytest.fixture()
def sample_export_rows() -> list[dict[str, Any]]:
    base = datetime(2026, 3, 9, 10, 0, tzinfo=UTC)
    return [
        {
            "camera_id": TEST_CAMERA_ID,
            "line_id": TEST_LINE_ID,
            "bucket_start": base,
            "class12": 1,
            "direction": "inbound",
            "count": 25,
            "sum_confidence": 22.5,
            "sum_speed_kmh": 1250.0,
            "min_speed_kmh": 30.0,
            "max_speed_kmh": 70.0,
        },
        {
            "camera_id": TEST_CAMERA_ID,
            "line_id": TEST_LINE_ID,
            "bucket_start": base,
            "class12": 2,
            "direction": "outbound",
            "count": 10,
            "sum_confidence": 9.0,
            "sum_speed_kmh": 500.0,
            "min_speed_kmh": 25.0,
            "max_speed_kmh": 65.0,
        },
    ]
