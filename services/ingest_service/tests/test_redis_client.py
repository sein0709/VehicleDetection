"""Tests for CameraHealthCache and SessionStore."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock

import pytest
from ingest_service.models import SessionState
from ingest_service.redis_client import (
    CAMERA_HEALTH_PREFIX,
    SESSION_PREFIX,
    CameraHealthCache,
    SessionStore,
)
from ingest_service.settings import Settings


@pytest.fixture()
def settings() -> Settings:
    return Settings(
        redis_url="redis://localhost:6379/0",
        health_ttl_seconds=300,
        session_ttl_seconds=3600,
    )


class TestCameraHealthCache:
    @pytest.fixture()
    def cache(self, settings: Settings) -> CameraHealthCache:
        c = CameraHealthCache.__new__(CameraHealthCache)
        c._redis = MagicMock()
        c._redis.hset = AsyncMock()
        c._redis.expire = AsyncMock()
        c._redis.hgetall = AsyncMock(return_value={})
        c._redis.aclose = AsyncMock()
        c._health_ttl = settings.health_ttl_seconds
        c._offline_multiplier = settings.offline_threshold_multiplier
        return c

    @pytest.mark.asyncio
    async def test_record_heartbeat_basic(self, cache: CameraHealthCache) -> None:
        await cache.record_heartbeat("cam_001", fps_actual=10.0)

        cache._redis.hset.assert_called_once()
        call_kwargs = cache._redis.hset.call_args.kwargs
        mapping = call_kwargs["mapping"]
        assert mapping["status"] == "online"
        assert mapping["fps_actual"] == "10.0"
        assert "last_seen" in mapping
        cache._redis.expire.assert_called_once_with(
            f"{CAMERA_HEALTH_PREFIX}cam_001", 300
        )

    @pytest.mark.asyncio
    async def test_record_heartbeat_all_fields(self, cache: CameraHealthCache) -> None:
        await cache.record_heartbeat(
            "cam_002",
            fps_actual=9.5,
            frame_width=1920,
            frame_height=1080,
            last_frame_index=500,
        )

        mapping = cache._redis.hset.call_args.kwargs["mapping"]
        assert mapping["fps_actual"] == "9.5"
        assert mapping["frame_width"] == "1920"
        assert mapping["frame_height"] == "1080"
        assert mapping["last_frame_index"] == "500"

    @pytest.mark.asyncio
    async def test_record_heartbeat_optional_fields(self, cache: CameraHealthCache) -> None:
        await cache.record_heartbeat("cam_003")

        mapping = cache._redis.hset.call_args.kwargs["mapping"]
        assert "fps_actual" not in mapping
        assert "frame_width" not in mapping

    @pytest.mark.asyncio
    async def test_get_camera_health_found(self, cache: CameraHealthCache) -> None:
        cache._redis.hgetall = AsyncMock(
            return_value={"status": "online", "last_seen": "2026-03-10T10:00:00+00:00"}
        )

        result = await cache.get_camera_health("cam_001")

        assert result is not None
        assert result["status"] == "online"

    @pytest.mark.asyncio
    async def test_get_camera_health_not_found(self, cache: CameraHealthCache) -> None:
        cache._redis.hgetall = AsyncMock(return_value={})

        result = await cache.get_camera_health("cam_nonexistent")

        assert result is None

    @pytest.mark.asyncio
    async def test_close(self, cache: CameraHealthCache) -> None:
        await cache.close()
        cache._redis.aclose.assert_called_once()


class TestSessionStore:
    @pytest.fixture()
    def store(self, settings: Settings) -> SessionStore:
        s = SessionStore.__new__(SessionStore)
        s._redis = MagicMock()
        s._redis.set = AsyncMock()
        s._redis.get = AsyncMock(return_value=None)
        s._redis.ttl = AsyncMock(return_value=3600)
        s._redis.delete = AsyncMock()
        s._redis.aclose = AsyncMock()
        s._session_ttl = settings.session_ttl_seconds
        return s

    @pytest.fixture()
    def sample_state(self) -> SessionState:
        now = datetime.now(tz=UTC)
        return SessionState(
            session_id="sess_test_001",
            camera_id="cam_001",
            status="created",
            frame_count=100,
            frames_uploaded=0,
            start_ts=now - timedelta(hours=1),
            end_ts=now,
            offline_upload=True,
            created_by="user_001",
            created_at=now,
            last_activity_at=now,
        )

    @pytest.mark.asyncio
    async def test_create_session(self, store: SessionStore, sample_state: SessionState) -> None:
        await store.create(sample_state)

        store._redis.set.assert_called_once()
        call_args = store._redis.set.call_args
        assert call_args[0][0] == f"{SESSION_PREFIX}sess_test_001"
        assert call_args[1]["ex"] == 3600

    @pytest.mark.asyncio
    async def test_get_session_found(self, store: SessionStore, sample_state: SessionState) -> None:
        store._redis.get = AsyncMock(return_value=sample_state.model_dump_json())

        result = await store.get("sess_test_001")

        assert result is not None
        assert result.session_id == "sess_test_001"
        assert result.camera_id == "cam_001"
        assert result.frame_count == 100

    @pytest.mark.asyncio
    async def test_get_session_not_found(self, store: SessionStore) -> None:
        store._redis.get = AsyncMock(return_value=None)

        result = await store.get("nonexistent")

        assert result is None

    @pytest.mark.asyncio
    async def test_update_session(self, store: SessionStore, sample_state: SessionState) -> None:
        await store.update(sample_state)

        store._redis.set.assert_called_once()

    @pytest.mark.asyncio
    async def test_increment_frames(self, store: SessionStore, sample_state: SessionState) -> None:
        store._redis.get = AsyncMock(return_value=sample_state.model_dump_json())

        result = await store.increment_frames("sess_test_001")

        assert result is not None
        assert result.frames_uploaded == 1
        assert result.status == "uploading"

    @pytest.mark.asyncio
    async def test_increment_frames_completes_session(
        self, store: SessionStore, sample_state: SessionState
    ) -> None:
        sample_state.frames_uploaded = 99
        sample_state.status = "uploading"
        store._redis.get = AsyncMock(return_value=sample_state.model_dump_json())

        result = await store.increment_frames("sess_test_001")

        assert result is not None
        assert result.frames_uploaded == 100
        assert result.status == "completed"

    @pytest.mark.asyncio
    async def test_increment_frames_not_found(self, store: SessionStore) -> None:
        store._redis.get = AsyncMock(return_value=None)

        result = await store.increment_frames("nonexistent")

        assert result is None

    @pytest.mark.asyncio
    async def test_delete_session(self, store: SessionStore) -> None:
        await store.delete("sess_test_001")

        store._redis.delete.assert_called_once_with(f"{SESSION_PREFIX}sess_test_001")

    @pytest.mark.asyncio
    async def test_close(self, store: SessionStore) -> None:
        await store.close()
        store._redis.aclose.assert_called_once()
