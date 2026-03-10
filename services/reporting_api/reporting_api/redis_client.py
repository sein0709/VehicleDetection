"""Redis client for live KPI cache and real-time subscriptions.

The aggregator writes the current 15-minute bucket to a Redis hash
(``bucket:current:{camera_id}:latest``) and publishes updates to
``live:kpi:{camera_id}`` so the Reporting API WebSocket can push
≤2s live refreshes (NFR-1).
"""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import UTC, datetime
from typing import Any

import redis.asyncio as aioredis

logger = logging.getLogger(__name__)

LIVE_KPI_CHANNEL = "live:kpi:"
BUCKET_HASH_PREFIX = "bucket:current:"

_redis: aioredis.Redis | None = None


async def connect(redis_url: str) -> None:
    global _redis
    _redis = aioredis.from_url(redis_url, decode_responses=True)
    logger.info("Redis client connected")


async def close() -> None:
    global _redis
    if _redis is not None:
        await _redis.aclose()
        _redis = None
        logger.info("Redis client closed")


def _get_redis() -> aioredis.Redis:
    if _redis is None:
        raise RuntimeError("Redis client is not initialised — call connect() first")
    return _redis


async def get_live_bucket(camera_id: str) -> dict[str, Any] | None:
    """Fetch the current in-progress 15-minute bucket from Redis.

    Reads from the ``bucket:current:{camera_id}:latest`` hash set by the
    aggregator's ``RedisKPIPublisher``.
    """
    r = _get_redis()
    key = f"{BUCKET_HASH_PREFIX}{camera_id}:latest"
    data = await r.hgetall(key)
    if not data:
        return None

    result: dict[str, Any] = {}
    for k, v in data.items():
        try:
            result[k] = json.loads(v)
        except (json.JSONDecodeError, TypeError):
            result[k] = v
    return result


async def subscribe_live_kpi(camera_id: str):
    """Async generator that yields live KPI updates via Redis pub/sub.

    Each yielded value is a parsed JSON dict published by the aggregator
    after every flush cycle.
    """
    r = _get_redis()
    channel = f"{LIVE_KPI_CHANNEL}{camera_id}"
    pubsub = r.pubsub()
    await pubsub.subscribe(channel)
    try:
        async for message in pubsub.listen():
            if message["type"] == "message":
                try:
                    payload = json.loads(message["data"])
                except (json.JSONDecodeError, TypeError):
                    payload = {"raw": message["data"]}
                yield payload
    finally:
        await pubsub.unsubscribe(channel)
        await pubsub.aclose()


async def ping() -> bool:
    """Check Redis connectivity."""
    try:
        r = _get_redis()
        return await r.ping()
    except Exception:
        return False
