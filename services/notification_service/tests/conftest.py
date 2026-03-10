"""Shared fixtures for Notification Service tests."""

from __future__ import annotations

import secrets
from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import UUID, uuid4

import jwt
import pytest
from fastapi.testclient import TestClient
from notification_service.app import create_app
from notification_service.db import NotificationDB
from notification_service.nats_consumer import EventConsumer
from notification_service.settings import Settings

TEST_ORG_ID = uuid4()
TEST_USER_ID = uuid4()
TEST_RULE_ID = uuid4()
TEST_ALERT_ID = uuid4()
TEST_CAMERA_ID = uuid4()
TEST_SITE_ID = uuid4()

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
        nats_url="nats://localhost:4222",
        redis_url="redis://localhost:6379/0",
        database_url="postgresql+asyncpg://test:test@localhost:5432/test",
        jwt_secret=JWT_SECRET,
        jwt_algorithm="HS256",
    )


@pytest.fixture()
def mock_db() -> MagicMock:
    return MagicMock(spec=NotificationDB)


@pytest.fixture()
def mock_consumer() -> MagicMock:
    consumer = MagicMock(spec=EventConsumer)
    consumer.start = AsyncMock()
    consumer.stop = AsyncMock()
    consumer.invalidate_rules_cache = AsyncMock()
    consumer.is_running = False
    return consumer


@pytest.fixture()
def client(settings: Settings, mock_db: MagicMock, mock_consumer: MagicMock) -> TestClient:
    with patch("notification_service.app.NotificationDB", return_value=mock_db), \
         patch("notification_service.app.EventConsumer", return_value=mock_consumer):
        app = create_app(settings)
        app.state.notification_db = mock_db
        app.state.consumer = mock_consumer
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
def sample_rule() -> dict[str, Any]:
    now = datetime.now(tz=UTC)
    return {
        "id": TEST_RULE_ID,
        "org_id": TEST_ORG_ID,
        "site_id": TEST_SITE_ID,
        "camera_id": TEST_CAMERA_ID,
        "name": "속도 저하 알림",
        "condition_type": "speed_drop",
        "condition_config": {"min_speed_kmh": 10.0},
        "severity": "warning",
        "channels": ["push", "email"],
        "recipients": [{"email": "ops@test.com"}],
        "cooldown_minutes": 15,
        "enabled": True,
        "created_at": now,
        "updated_at": now,
        "created_by": TEST_USER_ID,
    }


@pytest.fixture()
def sample_alert_event() -> dict[str, Any]:
    now = datetime.now(tz=UTC)
    return {
        "id": TEST_ALERT_ID,
        "org_id": TEST_ORG_ID,
        "rule_id": TEST_RULE_ID,
        "camera_id": str(TEST_CAMERA_ID),
        "site_id": str(TEST_SITE_ID),
        "severity": "warning",
        "status": "triggered",
        "message": "[WARNING] Rule '속도 저하 알림' triggered on camera test",
        "context": {"event_type": "VehicleCrossingEvent"},
        "triggered_at": now,
        "acknowledged_at": None,
        "acknowledged_by": None,
        "assigned_to": None,
        "resolved_at": None,
        "resolved_by": None,
    }
