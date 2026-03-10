"""Tests for the CameraHealthCache Redis client."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock

import pytest
from config_service.redis_client import CAMERA_HEALTH_PREFIX, CAMERA_HEALTH_TTL, CameraHealthCache
from config_service.settings import Settings


@pytest.fixture()
def settings() -> Settings:
    return Settings(
        redis_url="redis://localhost:6379/0",
        camera_offline_threshold_seconds=60,
    )


@pytest.fixture()
def cache(settings: Settings) -> CameraHealthCache:
    c = CameraHealthCache(settings)
    c._redis = AsyncMock()
    return c


class TestRecordHeartbeat:
    async def test_records_basic_heartbeat(self, cache: CameraHealthCache) -> None:
        await cache.record_heartbeat("cam-123")

        cache._redis.hset.assert_called_once()
        call_kwargs = cache._redis.hset.call_args
        key = call_kwargs.args[0] if call_kwargs.args else call_kwargs.kwargs.get("name")
        assert key == f"{CAMERA_HEALTH_PREFIX}cam-123"

        mapping = call_kwargs.kwargs.get("mapping") or call_kwargs.args[1]
        assert mapping["status"] == "online"
        assert "last_seen" in mapping

        cache._redis.expire.assert_called_once_with(
            f"{CAMERA_HEALTH_PREFIX}cam-123", CAMERA_HEALTH_TTL
        )

    async def test_records_fps_and_resolution(self, cache: CameraHealthCache) -> None:
        await cache.record_heartbeat("cam-456", fps=9.5, frame_width=1920, frame_height=1080)

        mapping = cache._redis.hset.call_args.kwargs.get("mapping")
        assert mapping["fps"] == "9.5"
        assert mapping["frame_width"] == "1920"
        assert mapping["frame_height"] == "1080"

    async def test_omits_none_fields(self, cache: CameraHealthCache) -> None:
        await cache.record_heartbeat("cam-789", fps=None)

        mapping = cache._redis.hset.call_args.kwargs.get("mapping")
        assert "fps" not in mapping


class TestGetCameraHealth:
    async def test_returns_none_when_no_data(self, cache: CameraHealthCache) -> None:
        cache._redis.hgetall = AsyncMock(return_value={})
        result = await cache.get_camera_health("cam-missing")
        assert result is None

    async def test_returns_online_when_recent(self, cache: CameraHealthCache) -> None:
        now = datetime.now(tz=UTC)
        cache._redis.hgetall = AsyncMock(
            return_value={"status": "online", "last_seen": now.isoformat(), "fps": "10.0"}
        )

        result = await cache.get_camera_health("cam-ok")
        assert result is not None
        assert result["status"] == "online"
        assert result["fps"] == "10.0"

    async def test_marks_offline_when_stale(self, cache: CameraHealthCache) -> None:
        stale = datetime.now(tz=UTC) - timedelta(seconds=120)
        cache._redis.hgetall = AsyncMock(
            return_value={"status": "online", "last_seen": stale.isoformat()}
        )

        result = await cache.get_camera_health("cam-stale")
        assert result is not None
        assert result["status"] == "offline"


class TestSetCameraOffline:
    async def test_sets_offline_status(self, cache: CameraHealthCache) -> None:
        await cache.set_camera_offline("cam-down")
        cache._redis.hset.assert_called_once_with(
            f"{CAMERA_HEALTH_PREFIX}cam-down", "status", "offline"
        )
