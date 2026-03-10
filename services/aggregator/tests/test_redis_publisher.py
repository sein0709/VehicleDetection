"""Tests for the Redis KPI publisher."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from unittest.mock import AsyncMock

import pytest
from aggregator.redis_publisher import (
    BUCKET_TTL,
    CHANNEL_PREFIX,
    RedisKPIPublisher,
    _build_camera_summary,
)


@pytest.fixture()
def mock_redis() -> AsyncMock:
    r = AsyncMock()
    r.publish = AsyncMock(return_value=1)
    r.hset = AsyncMock()
    r.expire = AsyncMock()
    r.aclose = AsyncMock()
    return r


@pytest.fixture()
def publisher(mock_redis: AsyncMock) -> RedisKPIPublisher:
    pub = RedisKPIPublisher.__new__(RedisKPIPublisher)
    pub._redis = mock_redis
    return pub


class TestPublishBucketUpdate:
    """Verify single bucket update publishing."""

    @pytest.mark.asyncio
    async def test_publishes_to_correct_channel(
        self, publisher: RedisKPIPublisher, mock_redis: AsyncMock
    ) -> None:
        bucket_start = datetime(2025, 6, 15, 10, 0, 0, tzinfo=UTC)
        await publisher.publish_bucket_update(
            camera_id="cam_001",
            bucket_start=bucket_start,
            totals={"count": 5, "class12": 1},
        )

        mock_redis.publish.assert_called_once()
        channel = mock_redis.publish.call_args[0][0]
        assert channel == f"{CHANNEL_PREFIX}cam_001"

    @pytest.mark.asyncio
    async def test_message_contains_camera_and_bucket(
        self, publisher: RedisKPIPublisher, mock_redis: AsyncMock
    ) -> None:
        bucket_start = datetime(2025, 6, 15, 10, 0, 0, tzinfo=UTC)
        await publisher.publish_bucket_update(
            camera_id="cam_001",
            bucket_start=bucket_start,
            totals={"count": 5},
        )

        raw = mock_redis.publish.call_args[0][1]
        msg = json.loads(raw)
        assert msg["camera_id"] == "cam_001"
        assert "2025-06-15" in msg["bucket_start"]
        assert msg["count"] == 5

    @pytest.mark.asyncio
    async def test_returns_receiver_count(
        self, publisher: RedisKPIPublisher, mock_redis: AsyncMock
    ) -> None:
        mock_redis.publish.return_value = 3
        result = await publisher.publish_bucket_update(
            camera_id="cam_001",
            bucket_start=datetime(2025, 6, 15, 10, 0, 0, tzinfo=UTC),
            totals={},
        )
        assert result == 3


class TestSetCurrentBucket:
    """Verify bucket hash storage with TTL."""

    @pytest.mark.asyncio
    async def test_sets_hash_with_ttl(
        self, publisher: RedisKPIPublisher, mock_redis: AsyncMock
    ) -> None:
        bucket_data = {
            "camera_id": "cam_001",
            "bucket_start": "2025-06-15T10:00:00+00:00",
            "count": 5,
        }
        await publisher.set_current_bucket("cam_001", bucket_data)

        assert mock_redis.hset.call_count == 2
        assert mock_redis.expire.call_count == 2

        expire_calls = mock_redis.expire.call_args_list
        for call in expire_calls:
            assert call[0][1] == int(BUCKET_TTL.total_seconds())

    @pytest.mark.asyncio
    async def test_sets_latest_key(
        self, publisher: RedisKPIPublisher, mock_redis: AsyncMock
    ) -> None:
        bucket_data = {"camera_id": "cam_001", "bucket_start": "2025-06-15T10:00:00+00:00"}
        await publisher.set_current_bucket("cam_001", bucket_data)

        hset_calls = mock_redis.hset.call_args_list
        keys = [call.kwargs.get("key") or call[0][0] for call in hset_calls]
        assert any("latest" in k for k in keys)


class TestPublishFlushSummary:
    """Verify batch flush summary publishing."""

    @pytest.mark.asyncio
    async def test_groups_by_camera(
        self, publisher: RedisKPIPublisher, mock_redis: AsyncMock
    ) -> None:
        rows = [
            {
                "camera_id": "cam_A",
                "line_id": "line_1",
                "bucket_start": datetime(2025, 6, 15, 10, 0, 0, tzinfo=UTC),
                "class12": 1,
                "direction": "inbound",
                "count": 3,
                "sum_confidence": 2.7,
                "sum_speed_kmh": 150.0,
                "min_speed_kmh": 40.0,
                "max_speed_kmh": 60.0,
            },
            {
                "camera_id": "cam_B",
                "line_id": "line_1",
                "bucket_start": datetime(2025, 6, 15, 10, 0, 0, tzinfo=UTC),
                "class12": 1,
                "direction": "inbound",
                "count": 2,
                "sum_confidence": 1.8,
                "sum_speed_kmh": 100.0,
                "min_speed_kmh": 45.0,
                "max_speed_kmh": 55.0,
            },
        ]
        await publisher.publish_flush_summary(rows)

        assert mock_redis.publish.call_count == 2

    @pytest.mark.asyncio
    async def test_empty_rows_no_publish(
        self, publisher: RedisKPIPublisher, mock_redis: AsyncMock
    ) -> None:
        await publisher.publish_flush_summary([])
        mock_redis.publish.assert_not_called()


class TestBuildCameraSummary:
    """Verify the KPI summary builder."""

    def test_single_row_summary(self) -> None:
        rows = [
            {
                "camera_id": "cam_001",
                "bucket_start": datetime(2025, 6, 15, 10, 0, 0, tzinfo=UTC),
                "class12": 1,
                "direction": "inbound",
                "count": 10,
            }
        ]
        summary = _build_camera_summary("cam_001", rows)

        assert summary["camera_id"] == "cam_001"
        assert summary["total_count"] == 10
        assert summary["flow_rate_per_hour"] == 40
        assert summary["class_counts"] == {1: 10}
        assert summary["direction_counts"]["inbound"] == 10

    def test_multi_class_summary(self) -> None:
        ts = datetime(2025, 6, 15, 10, 0, 0, tzinfo=UTC)
        base = {"camera_id": "cam_001", "bucket_start": ts}
        rows = [
            {**base, "class12": 1, "direction": "inbound", "count": 5},
            {**base, "class12": 2, "direction": "inbound", "count": 3},
            {**base, "class12": 1, "direction": "outbound", "count": 2},
        ]
        summary = _build_camera_summary("cam_001", rows)

        assert summary["total_count"] == 10
        assert summary["class_counts"] == {1: 7, 2: 3}
        assert summary["direction_counts"]["inbound"] == 8
        assert summary["direction_counts"]["outbound"] == 2
