"""Redis publisher for live KPI updates after each accumulator flush.

After each flush the aggregator:
1. Publishes per-camera bucket updates to a Redis pub/sub channel so the
   Reporting API WebSocket can push ≤2s live refreshes (NFR-1).
2. Stores the current bucket state in a Redis hash so the dashboard can
   read the latest snapshot without hitting Postgres.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta
from typing import Any

import redis.asyncio as aioredis

logger = logging.getLogger(__name__)

CHANNEL_PREFIX = "live:kpi:"
HASH_PREFIX = "bucket:current:"
BUCKET_TTL = timedelta(minutes=20)


class RedisKPIPublisher:
    """Publishes aggregated bucket updates to Redis pub/sub and stores current state."""

    def __init__(self, redis_url: str) -> None:
        self._redis = aioredis.from_url(redis_url, decode_responses=True)

    async def publish_bucket_update(
        self,
        camera_id: str,
        bucket_start: datetime,
        totals: dict[str, Any],
    ) -> int:
        """Publish a single bucket update to the live KPI channel.

        Returns the number of subscribers that received the message.
        """
        channel = f"{CHANNEL_PREFIX}{camera_id}"
        message = json.dumps(
            {
                "camera_id": camera_id,
                "bucket_start": bucket_start.isoformat(),
                **totals,
            },
            default=str,
        )
        receivers = await self._redis.publish(channel, message)
        logger.debug("Published KPI update to %s (%d receivers)", channel, receivers)
        return receivers

    async def publish_flush_summary(
        self,
        rows: list[dict[str, Any]],
    ) -> None:
        """Publish a batch of flushed rows: one pub/sub message per camera
        and a hash update for each row's bucket.

        Only updates the live hash for buckets less than 1 hour old
        (per Section 5.5 late-event rules).
        """
        camera_buckets: dict[str, list[dict[str, Any]]] = {}
        for row in rows:
            cam = row["camera_id"]
            camera_buckets.setdefault(cam, []).append(row)

        for camera_id, cam_rows in camera_buckets.items():
            summary = _build_camera_summary(camera_id, cam_rows)
            channel = f"{CHANNEL_PREFIX}{camera_id}"
            await self._redis.publish(channel, json.dumps(summary, default=str))

            for row in cam_rows:
                await self.set_current_bucket(camera_id, row)

    async def set_current_bucket(
        self,
        camera_id: str,
        bucket_data: dict[str, Any],
    ) -> None:
        """Store a bucket snapshot in a Redis hash with a TTL.

        The key is scoped to camera + bucket_start so multiple buckets
        (current + recent late arrivals) can coexist.
        """
        bucket_start = bucket_data.get("bucket_start", "unknown")
        key = f"{HASH_PREFIX}{camera_id}:{bucket_start}"
        serialised = {
            k: json.dumps(v, default=str) if isinstance(v, (dict, list, datetime)) else str(v)
            for k, v in bucket_data.items()
        }
        await self._redis.hset(key, mapping=serialised)
        await self._redis.expire(key, int(BUCKET_TTL.total_seconds()))

        latest_key = f"{HASH_PREFIX}{camera_id}:latest"
        await self._redis.hset(latest_key, mapping=serialised)
        await self._redis.expire(latest_key, int(BUCKET_TTL.total_seconds()))

    async def close(self) -> None:
        await self._redis.aclose()
        logger.info("Redis publisher closed")


def _build_camera_summary(camera_id: str, rows: list[dict[str, Any]]) -> dict[str, Any]:
    """Aggregate flushed rows into a per-camera KPI summary for the pub/sub message."""
    total_count = 0
    class_counts: dict[int, int] = {}
    direction_counts: dict[str, int] = {"inbound": 0, "outbound": 0}
    bucket_starts: set[str] = set()

    for row in rows:
        total_count += row["count"]
        cls = row["class12"]
        class_counts[cls] = class_counts.get(cls, 0) + row["count"]
        direction_counts[row["direction"]] = (
            direction_counts.get(row["direction"], 0) + row["count"]
        )
        bs = row["bucket_start"]
        bucket_starts.add(bs.isoformat() if isinstance(bs, datetime) else str(bs))

    flow_rate_per_hour = total_count * 4 if len(bucket_starts) == 1 else total_count

    return {
        "camera_id": camera_id,
        "bucket_starts": sorted(bucket_starts),
        "total_count": total_count,
        "flow_rate_per_hour": flow_rate_per_hour,
        "class_counts": class_counts,
        "direction_counts": direction_counts,
    }
