"""Tests for the DLQ handler (dead-letter queue routing).

Covers:
- Successful message processing (ack)
- Transient failure (nak for retry)
- Terminal failure (route to DLQ after max_deliver)
- DLQ publish failure fallback
- Stats tracking
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock

import pytest

from shared_contracts.nats_dlq import DLQHandler


def _make_msg(
    subject: str = "events.crossings.cam_001",
    data: bytes = b'{"event": "test"}',
    headers: dict[str, str] | None = None,
    num_delivered: int = 1,
) -> MagicMock:
    """Create a mock NATS JetStream message."""
    msg = MagicMock()
    msg.subject = subject
    msg.data = data
    msg.headers = headers or {"Content-Type": "application/json"}
    msg.ack = AsyncMock()
    msg.nak = AsyncMock()

    metadata = MagicMock()
    metadata.num_delivered = num_delivered
    msg.metadata = metadata

    return msg


class TestDLQHandlerSuccess:
    @pytest.mark.asyncio
    async def test_successful_processing_acks(self) -> None:
        js = MagicMock()
        handler = DLQHandler(js, max_deliver=3)
        msg = _make_msg(num_delivered=1)
        callback = AsyncMock()

        result = await handler.process(msg, callback)

        assert result is True
        callback.assert_awaited_once_with(msg)
        msg.ack.assert_awaited_once()
        msg.nak.assert_not_awaited()

    @pytest.mark.asyncio
    async def test_stats_increment_on_success(self) -> None:
        js = MagicMock()
        handler = DLQHandler(js, max_deliver=3)

        for i in range(5):
            msg = _make_msg(num_delivered=1)
            await handler.process(msg, AsyncMock())

        assert handler.stats == {"processed": 5, "errors": 0, "dlq_routed": 0}


class TestDLQHandlerTransientFailure:
    @pytest.mark.asyncio
    async def test_failure_before_max_deliver_naks(self) -> None:
        js = MagicMock()
        handler = DLQHandler(js, max_deliver=3)
        msg = _make_msg(num_delivered=1)
        callback = AsyncMock(side_effect=ValueError("transient error"))

        result = await handler.process(msg, callback)

        assert result is False
        msg.nak.assert_awaited_once()
        msg.ack.assert_not_awaited()

    @pytest.mark.asyncio
    async def test_second_attempt_still_naks(self) -> None:
        js = MagicMock()
        handler = DLQHandler(js, max_deliver=3)
        msg = _make_msg(num_delivered=2)
        callback = AsyncMock(side_effect=RuntimeError("still failing"))

        result = await handler.process(msg, callback)

        assert result is False
        msg.nak.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_stats_track_errors(self) -> None:
        js = MagicMock()
        handler = DLQHandler(js, max_deliver=3)
        msg = _make_msg(num_delivered=1)
        callback = AsyncMock(side_effect=ValueError("oops"))

        await handler.process(msg, callback)

        assert handler.stats["errors"] == 1
        assert handler.stats["dlq_routed"] == 0


class TestDLQHandlerTerminalFailure:
    @pytest.mark.asyncio
    async def test_max_deliver_routes_to_dlq(self) -> None:
        js = MagicMock()
        js.publish = AsyncMock()
        handler = DLQHandler(js, max_deliver=3)
        msg = _make_msg(
            subject="events.crossings.cam_001",
            num_delivered=3,
        )
        callback = AsyncMock(side_effect=ValueError("permanent error"))

        result = await handler.process(msg, callback)

        assert result is False
        js.publish.assert_awaited_once()
        dlq_call = js.publish.call_args
        assert dlq_call[0][0] == "events.dlq.crossings.cam_001"
        assert dlq_call[0][1] == msg.data

        dlq_headers = dlq_call[1]["headers"]
        assert dlq_headers["X-DLQ-Original-Subject"] == "events.crossings.cam_001"
        assert "ValueError" in dlq_headers["X-DLQ-Error-Reason"]
        assert dlq_headers["X-DLQ-Attempts"] == "3"

        msg.ack.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_max_deliver_exceeded_routes_to_dlq(self) -> None:
        js = MagicMock()
        js.publish = AsyncMock()
        handler = DLQHandler(js, max_deliver=3)
        msg = _make_msg(num_delivered=5)
        callback = AsyncMock(side_effect=RuntimeError("dead"))

        await handler.process(msg, callback)

        js.publish.assert_awaited_once()
        msg.ack.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_dlq_stats_increment(self) -> None:
        js = MagicMock()
        js.publish = AsyncMock()
        handler = DLQHandler(js, max_deliver=2)

        msg = _make_msg(num_delivered=2)
        await handler.process(msg, AsyncMock(side_effect=ValueError("fail")))

        assert handler.stats["dlq_routed"] == 1
        assert handler.stats["errors"] == 1

    @pytest.mark.asyncio
    async def test_frames_subject_dlq_routing(self) -> None:
        js = MagicMock()
        js.publish = AsyncMock()
        handler = DLQHandler(js, max_deliver=1)
        msg = _make_msg(subject="frames.cam_005", num_delivered=1)
        callback = AsyncMock(side_effect=RuntimeError("decode error"))

        await handler.process(msg, callback)

        dlq_subject = js.publish.call_args[0][0]
        assert dlq_subject == "events.dlq.frames.cam_005"

    @pytest.mark.asyncio
    async def test_preserves_original_headers(self) -> None:
        js = MagicMock()
        js.publish = AsyncMock()
        handler = DLQHandler(js, max_deliver=1)
        msg = _make_msg(
            num_delivered=1,
            headers={"Camera-Id": "cam_001", "Content-Type": "application/json"},
        )
        callback = AsyncMock(side_effect=ValueError("fail"))

        await handler.process(msg, callback)

        dlq_headers = js.publish.call_args[1]["headers"]
        assert dlq_headers["Camera-Id"] == "cam_001"
        assert dlq_headers["Content-Type"] == "application/json"
        assert "X-DLQ-Original-Subject" in dlq_headers


class TestDLQPublishFailure:
    @pytest.mark.asyncio
    async def test_dlq_publish_failure_naks_original(self) -> None:
        js = MagicMock()
        js.publish = AsyncMock(side_effect=RuntimeError("DLQ stream down"))
        handler = DLQHandler(js, max_deliver=1)
        msg = _make_msg(num_delivered=1)
        callback = AsyncMock(side_effect=ValueError("processing failed"))

        result = await handler.process(msg, callback)

        assert result is False
        msg.nak.assert_awaited_once()
        msg.ack.assert_not_awaited()


class TestDLQHandlerEdgeCases:
    @pytest.mark.asyncio
    async def test_max_deliver_one(self) -> None:
        """With max_deliver=1, first failure goes straight to DLQ."""
        js = MagicMock()
        js.publish = AsyncMock()
        handler = DLQHandler(js, max_deliver=1)
        msg = _make_msg(num_delivered=1)
        callback = AsyncMock(side_effect=ValueError("immediate fail"))

        await handler.process(msg, callback)

        js.publish.assert_awaited_once()
        assert handler.stats["dlq_routed"] == 1

    @pytest.mark.asyncio
    async def test_mixed_success_and_failure(self) -> None:
        js = MagicMock()
        js.publish = AsyncMock()
        handler = DLQHandler(js, max_deliver=2)

        ok_msg = _make_msg(num_delivered=1)
        await handler.process(ok_msg, AsyncMock())

        retry_msg = _make_msg(num_delivered=1)
        await handler.process(retry_msg, AsyncMock(side_effect=ValueError("retry")))

        dlq_msg = _make_msg(num_delivered=2)
        await handler.process(dlq_msg, AsyncMock(side_effect=ValueError("dead")))

        assert handler.stats == {"processed": 1, "errors": 2, "dlq_routed": 1}

    @pytest.mark.asyncio
    async def test_message_without_metadata_defaults_to_one(self) -> None:
        """Messages without .metadata attribute are treated as first delivery."""
        js = MagicMock()
        handler = DLQHandler(js, max_deliver=3)
        msg = _make_msg(num_delivered=1)
        del msg.metadata

        callback = AsyncMock(side_effect=ValueError("fail"))
        await handler.process(msg, callback)

        msg.nak.assert_awaited_once()
