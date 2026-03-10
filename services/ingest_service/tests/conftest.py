"""Shared fixtures for Ingest Service tests."""

from __future__ import annotations

import secrets
from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import AsyncMock, MagicMock, PropertyMock
from uuid import UUID, uuid4

import jwt
import pytest
from fastapi.testclient import TestClient
from ingest_service.app import create_app
from ingest_service.models import SessionState
from ingest_service.nats_client import NatsFramePublisher
from ingest_service.redis_client import CameraHealthCache, SessionStore
from ingest_service.settings import Settings

TEST_ORG_ID = uuid4()
TEST_USER_ID = uuid4()
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
        jwt_secret=JWT_SECRET,
        jwt_algorithm="HS256",
        max_queue_depth=500,
        backpressure_retry_after=5,
        max_frame_size_bytes=10 * 1024 * 1024,
        session_ttl_seconds=3600,
        health_ttl_seconds=300,
    )


@pytest.fixture()
def mock_nats() -> MagicMock:
    publisher = MagicMock(spec=NatsFramePublisher)
    publisher.publish_frame = AsyncMock(return_value=42)
    publisher.publish_health_event = AsyncMock(return_value=1)
    publisher.get_queue_depth = AsyncMock(return_value=0)
    publisher.close = AsyncMock()
    type(publisher).is_connected = PropertyMock(return_value=True)
    return publisher


@pytest.fixture()
def mock_health_cache() -> MagicMock:
    cache = MagicMock(spec=CameraHealthCache)
    cache._redis = AsyncMock()
    cache._redis.ping = AsyncMock()
    cache.record_heartbeat = AsyncMock()
    cache.get_camera_health = AsyncMock(return_value=None)
    cache.close = AsyncMock()
    return cache


@pytest.fixture()
def mock_session_store() -> MagicMock:
    store = MagicMock(spec=SessionStore)
    store._redis = AsyncMock()
    store.create = AsyncMock()
    store.get = AsyncMock(return_value=None)
    store.update = AsyncMock()
    store.increment_frames = AsyncMock(return_value=None)
    store.delete = AsyncMock()
    store.close = AsyncMock()
    return store


@pytest.fixture()
def client(
    settings: Settings,
    mock_nats: MagicMock,
    mock_health_cache: MagicMock,
    mock_session_store: MagicMock,
) -> TestClient:
    app = create_app(settings)
    app.state.nats_publisher = mock_nats
    app.state.health_cache = mock_health_cache
    app.state.session_store = mock_session_store
    app.state.settings = settings
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
def analyst_headers() -> dict[str, str]:
    return {"Authorization": f"Bearer {_make_token('analyst')}"}


@pytest.fixture()
def sample_frame_metadata() -> dict[str, Any]:
    return {
        "camera_id": "cam_001",
        "frame_index": 100,
        "timestamp_utc": datetime.now(tz=UTC).isoformat(),
        "offline_upload": False,
    }


@pytest.fixture()
def sample_session_state() -> SessionState:
    now = datetime.now(tz=UTC)
    return SessionState(
        session_id="sess_abc123",
        camera_id="cam_001",
        status="created",
        frame_count=100,
        frames_uploaded=0,
        start_ts=now - timedelta(hours=1),
        end_ts=now,
        offline_upload=True,
        created_by=str(TEST_USER_ID),
        created_at=now,
        last_activity_at=now,
        resume_from_index=0,
    )
