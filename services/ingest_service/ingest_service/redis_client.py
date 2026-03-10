"""Redis client for camera heartbeat tracking and upload session storage.

Stores last-seen timestamps and camera health status for fast lookups
by the Live Monitor and dashboard. Also manages resumable upload sessions.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import TYPE_CHECKING

import redis.asyncio as aioredis

from ingest_service.models import SessionState

if TYPE_CHECKING:
    from ingest_service.settings import Settings

logger = logging.getLogger(__name__)

CAMERA_HEALTH_PREFIX = "camera:health:"
SESSION_PREFIX = "ingest:session:"


class CameraHealthCache:
    """Redis-backed cache for camera online/offline status."""

    def __init__(self, settings: Settings) -> None:
        self._redis = aioredis.from_url(
            settings.redis_url,
            decode_responses=True,
        )
        self._health_ttl = settings.health_ttl_seconds
        self._offline_multiplier = settings.offline_threshold_multiplier

    async def close(self) -> None:
        await self._redis.aclose()

    async def record_heartbeat(
        self,
        camera_id: str,
        fps_actual: float | None = None,
        frame_width: int | None = None,
        frame_height: int | None = None,
        last_frame_index: int | None = None,
    ) -> None:
        key = f"{CAMERA_HEALTH_PREFIX}{camera_id}"
        now = datetime.now(tz=UTC).isoformat()
        mapping: dict[str, str] = {"last_seen": now, "status": "online"}
        if fps_actual is not None:
            mapping["fps_actual"] = str(fps_actual)
        if frame_width is not None:
            mapping["frame_width"] = str(frame_width)
        if frame_height is not None:
            mapping["frame_height"] = str(frame_height)
        if last_frame_index is not None:
            mapping["last_frame_index"] = str(last_frame_index)
        await self._redis.hset(key, mapping=mapping)
        await self._redis.expire(key, self._health_ttl)

    async def get_camera_health(self, camera_id: str) -> dict[str, str] | None:
        key = f"{CAMERA_HEALTH_PREFIX}{camera_id}"
        data = await self._redis.hgetall(key)
        if not data:
            return None
        return data


class SessionStore:
    """Redis-backed store for resumable upload sessions."""

    def __init__(self, settings: Settings) -> None:
        self._redis = aioredis.from_url(
            settings.redis_url,
            decode_responses=True,
        )
        self._session_ttl = settings.session_ttl_seconds

    async def close(self) -> None:
        await self._redis.aclose()

    def _key(self, session_id: str) -> str:
        return f"{SESSION_PREFIX}{session_id}"

    async def create(self, state: SessionState) -> None:
        key = self._key(state.session_id)
        await self._redis.set(
            key,
            state.model_dump_json(),
            ex=self._session_ttl,
        )

    async def get(self, session_id: str) -> SessionState | None:
        key = self._key(session_id)
        raw = await self._redis.get(key)
        if raw is None:
            return None
        return SessionState.model_validate_json(raw)

    async def update(self, state: SessionState) -> None:
        key = self._key(state.session_id)
        ttl = await self._redis.ttl(key)
        if ttl < 0:
            ttl = self._session_ttl
        await self._redis.set(
            key,
            state.model_dump_json(),
            ex=ttl,
        )

    async def increment_frames(self, session_id: str) -> SessionState | None:
        """Atomically increment frames_uploaded and refresh last_activity_at."""
        state = await self.get(session_id)
        if state is None:
            return None
        state.frames_uploaded += 1
        state.last_activity_at = datetime.now(tz=UTC)
        if state.status == "created":
            state.status = "uploading"
        if state.frames_uploaded >= state.frame_count:
            state.status = "completed"
        await self.update(state)
        return state

    async def delete(self, session_id: str) -> None:
        key = self._key(session_id)
        await self._redis.delete(key)
