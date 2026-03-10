"""Redis client for camera health status caching.

Stores last-seen timestamps, FPS, and computed camera status for fast
lookups by the Live Monitor and Ingest Service heartbeat flow.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime

import redis.asyncio as aioredis

from config_service.settings import Settings

logger = logging.getLogger(__name__)

CAMERA_HEALTH_PREFIX = "camera:health:"
CAMERA_HEALTH_TTL = 300  # 5 minutes


class CameraHealthCache:
    """Redis-backed cache for camera online/offline status."""

    def __init__(self, settings: Settings) -> None:
        self._redis = aioredis.from_url(
            settings.redis_url,
            decode_responses=True,
        )
        self._offline_threshold = settings.camera_offline_threshold_seconds

    async def close(self) -> None:
        await self._redis.aclose()

    async def record_heartbeat(
        self,
        camera_id: str,
        *,
        fps: float | None = None,
        frame_width: int | None = None,
        frame_height: int | None = None,
    ) -> None:
        key = f"{CAMERA_HEALTH_PREFIX}{camera_id}"
        now = datetime.now(tz=UTC).isoformat()
        mapping: dict[str, str] = {"last_seen": now, "status": "online"}
        if fps is not None:
            mapping["fps"] = str(fps)
        if frame_width is not None:
            mapping["frame_width"] = str(frame_width)
        if frame_height is not None:
            mapping["frame_height"] = str(frame_height)
        await self._redis.hset(key, mapping=mapping)
        await self._redis.expire(key, CAMERA_HEALTH_TTL)

    async def get_camera_health(self, camera_id: str) -> dict[str, str] | None:
        key = f"{CAMERA_HEALTH_PREFIX}{camera_id}"
        data = await self._redis.hgetall(key)
        if not data:
            return None

        last_seen_str = data.get("last_seen")
        if last_seen_str:
            last_seen = datetime.fromisoformat(last_seen_str)
            elapsed = (datetime.now(tz=UTC) - last_seen).total_seconds()
            if elapsed > self._offline_threshold:
                data["status"] = "offline"

        return data

    async def set_camera_offline(self, camera_id: str) -> None:
        key = f"{CAMERA_HEALTH_PREFIX}{camera_id}"
        await self._redis.hset(key, "status", "offline")
