"""Tests for the NATS crossing consumer message handling."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest
from aggregator.accumulator import BucketAccumulator
from aggregator.nats_consumer import NatsCrossingConsumer

from aggregator.test_support import make_crossing_event


def _make_nats_msg(payload: dict) -> MagicMock:
    """Create a mock NATS message with the given JSON payload."""
    msg = MagicMock()
    msg.data = json.dumps(payload).encode()
    msg.subject = "events.crossings.cam_001"
    msg.ack = AsyncMock()
    msg.nak = AsyncMock()
    msg.headers = None
    metadata = MagicMock()
    metadata.num_delivered = 1
    msg.metadata = metadata
    return msg


class TestHandleCrossing:
    """Verify crossing event processing."""

    @pytest.mark.asyncio
    async def test_valid_event_added_to_accumulator(self) -> None:
        consumer = NatsCrossingConsumer()
        accumulator = BucketAccumulator()

        event = make_crossing_event(
            camera_id="cam_test",
            confidence=0.88,
            speed_estimate_kmh=55.0,
        )
        msg = _make_nats_msg(event.model_dump(mode="json"))

        await consumer._handle_crossing(msg, accumulator)

        assert accumulator.pending_count == 1
        rows = accumulator.flush()
        assert len(rows) == 1
        assert rows[0]["camera_id"] == "cam_test"
        assert rows[0]["count"] == 1

    @pytest.mark.asyncio
    async def test_multiple_events_accumulated(self) -> None:
        consumer = NatsCrossingConsumer()
        accumulator = BucketAccumulator()

        ts = datetime(2025, 6, 15, 10, 5, 0, tzinfo=UTC)
        for i in range(5):
            event = make_crossing_event(
                timestamp_utc=ts,
                track_id=f"track_{i}",
                crossing_seq=i + 1,
            )
            msg = _make_nats_msg(event.model_dump(mode="json"))
            await consumer._handle_crossing(msg, accumulator)

        assert accumulator.pending_count == 5

    @pytest.mark.asyncio
    async def test_processed_count_incremented(self) -> None:
        consumer = NatsCrossingConsumer()
        accumulator = BucketAccumulator()

        event = make_crossing_event()
        msg = _make_nats_msg(event.model_dump(mode="json"))
        await consumer._handle_crossing(msg, accumulator)

        assert consumer.stats["processed"] == 1


class TestHandleRecompute:
    """Verify recompute command processing."""

    @pytest.mark.asyncio
    async def test_recompute_calls_db(self) -> None:
        consumer = NatsCrossingConsumer()
        mock_db = MagicMock()
        mock_db.recompute = AsyncMock(return_value=5)
        mock_db.fetch_bucket_totals = AsyncMock(return_value=[])

        mock_redis = MagicMock()
        mock_redis.publish_flush_summary = AsyncMock()

        payload = {
            "camera_id": "cam_001",
            "start": "2025-06-15T10:00:00+00:00",
            "end": "2025-06-15T11:00:00+00:00",
        }
        msg = _make_nats_msg(payload)

        await consumer._handle_recompute(msg, mock_db, mock_redis)

        mock_db.recompute.assert_called_once_with(
            "cam_001",
            datetime(2025, 6, 15, 10, 0, 0, tzinfo=UTC),
            datetime(2025, 6, 15, 11, 0, 0, tzinfo=UTC),
        )

    @pytest.mark.asyncio
    async def test_recompute_publishes_kpi_when_rows_inserted(self) -> None:
        consumer = NatsCrossingConsumer()
        mock_db = MagicMock()
        mock_db.recompute = AsyncMock(return_value=3)
        mock_db.fetch_bucket_totals = AsyncMock(
            return_value=[
                {"camera_id": "cam_001", "count": 3, "class12": 1, "direction": "inbound"},
            ]
        )

        mock_redis = MagicMock()
        mock_redis.publish_flush_summary = AsyncMock()

        payload = {
            "camera_id": "cam_001",
            "start": "2025-06-15T10:00:00+00:00",
            "end": "2025-06-15T11:00:00+00:00",
        }
        msg = _make_nats_msg(payload)

        await consumer._handle_recompute(msg, mock_db, mock_redis)

        mock_redis.publish_flush_summary.assert_called_once()

    @pytest.mark.asyncio
    async def test_recompute_count_incremented(self) -> None:
        consumer = NatsCrossingConsumer()
        mock_db = MagicMock()
        mock_db.recompute = AsyncMock(return_value=0)
        mock_db.fetch_bucket_totals = AsyncMock(return_value=[])

        mock_redis = MagicMock()
        mock_redis.publish_flush_summary = AsyncMock()

        payload = {
            "camera_id": "cam_001",
            "start": "2025-06-15T10:00:00+00:00",
            "end": "2025-06-15T11:00:00+00:00",
        }
        msg = _make_nats_msg(payload)

        await consumer._handle_recompute(msg, mock_db, mock_redis)

        assert consumer.stats["recomputes"] == 1


class TestConsumerProperties:
    """Verify consumer state properties."""

    def test_is_connected_false_initially(self) -> None:
        consumer = NatsCrossingConsumer()
        assert not consumer.is_connected

    def test_initial_stats(self) -> None:
        consumer = NatsCrossingConsumer()
        assert consumer.stats == {"processed": 0, "recomputes": 0}
