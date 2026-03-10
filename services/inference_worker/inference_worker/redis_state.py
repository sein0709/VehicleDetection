"""Redis live-state broadcaster for the Live Monitor WebSocket feed.

Pushes current bounding boxes, track IDs, class labels, and counting-line
state to Redis so the Reporting API can stream them to mobile clients.
"""

from __future__ import annotations

import json
import logging
from typing import TYPE_CHECKING

import redis.asyncio as aioredis

from inference_worker.models import TrackState

if TYPE_CHECKING:
    from inference_worker.settings import Settings

logger = logging.getLogger(__name__)

KEY_PREFIX_LIVE = "live:camera"
KEY_PREFIX_COUNTS = "live:counts"


class RedisLiveState:
    """Pushes per-camera live inference state to Redis."""

    def __init__(self) -> None:
        self._redis: aioredis.Redis | None = None
        self._ttl: int = 30

    async def connect(self, settings: Settings) -> None:
        self._redis = aioredis.from_url(
            settings.redis_url,
            decode_responses=False,
        )
        self._ttl = settings.redis_live_state_ttl
        logger.info("RedisLiveState connected to %s", settings.redis_url)

    async def push_tracks(
        self,
        camera_id: str,
        tracks: dict[str, TrackState],
        frame_index: int,
    ) -> None:
        """Push current track state for a camera to Redis.

        The data is consumed by the Live Monitor WebSocket endpoint.
        """
        if self._redis is None:
            return

        track_data = []
        for ts in tracks.values():
            if not ts.is_confirmed:
                continue
            entry = {
                "track_id": ts.track_id,
                "bbox": {
                    "x": ts.bbox.x,
                    "y": ts.bbox.y,
                    "w": ts.bbox.w,
                    "h": ts.bbox.h,
                },
                "centroid": {"x": ts.centroid.x, "y": ts.centroid.y},
                "class12": ts.smoothed_class.value if ts.smoothed_class else None,
                "confidence": ts.smoothed_confidence,
                "speed_kmh": ts.speed_estimate_kmh,
                "is_occluded": ts.occlusion_flag,
            }
            track_data.append(entry)

        payload = json.dumps({
            "camera_id": camera_id,
            "frame_index": frame_index,
            "track_count": len(track_data),
            "tracks": track_data,
        }).encode()

        key = f"{KEY_PREFIX_LIVE}:{camera_id}"
        await self._redis.set(key, payload, ex=self._ttl)

    async def increment_crossing_count(
        self,
        camera_id: str,
        line_id: str,
        direction: str,
        class_value: int,
    ) -> None:
        """Increment a live crossing counter in Redis (for real-time KPI display)."""
        if self._redis is None:
            return

        key = f"{KEY_PREFIX_COUNTS}:{camera_id}:{line_id}"
        field = f"{direction}:{class_value}"
        await self._redis.hincrby(key, field, 1)
        await self._redis.expire(key, 3600)

    async def close(self) -> None:
        if self._redis:
            await self._redis.close()
            logger.info("RedisLiveState connection closed")
