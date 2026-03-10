"""Integration tests for NATS JetStream infrastructure.

Requires a running NATS server with JetStream enabled (``make dev-up``).
These tests verify the full lifecycle: stream/consumer creation,
publish/subscribe, DLQ routing, and message replay.

Run with::

    uv run pytest -m integration libs/shared_contracts/tests/test_nats_integration.py
"""

from __future__ import annotations

import asyncio
import json
import os
from unittest.mock import AsyncMock, MagicMock

import nats
import pytest

from shared_contracts.events import VehicleCrossingEvent
from shared_contracts.nats_dlq import DLQHandler
from shared_contracts.nats_streams import (
    ALL_STREAM_NAMES,
    CONSUMER_AGGREGATOR_CROSSINGS,
    CONSUMER_DEFS,
    CONSUMER_INFERENCE_WORKER,
    CONSUMER_NOTIFICATION_CROSSINGS,
    CONSUMER_NOTIFICATION_HEALTH,
    STREAM_CROSSINGS,
    STREAM_DEFS,
    STREAM_DLQ,
    STREAM_FRAMES,
    SUBJECT_CROSSINGS,
    SUBJECT_DLQ,
    SUBJECT_FRAMES,
    dlq_subject_for,
    ensure_all,
    ensure_consumers,
    ensure_streams,
)

NATS_URL = os.environ.get("NATS_URL", "nats://localhost:4222")

pytestmark = [pytest.mark.integration]


@pytest.fixture()
async def nats_conn():
    """Connect to the local NATS server, yield, then close."""
    nc = await nats.connect(NATS_URL, connect_timeout=5)
    yield nc
    await nc.close()


@pytest.fixture()
async def js(nats_conn):
    """Return a JetStreamContext from the connection."""
    return nats_conn.jetstream()


@pytest.fixture(autouse=True)
async def _cleanup_streams(js):
    """Delete all GreyEye streams before each test for isolation."""
    for name in ALL_STREAM_NAMES:
        try:
            await js.delete_stream(name)
        except nats.js.errors.NotFoundError:
            pass
    yield
    for name in ALL_STREAM_NAMES:
        try:
            await js.delete_stream(name)
        except nats.js.errors.NotFoundError:
            pass


# ---------------------------------------------------------------------------
# Stream & consumer bootstrap
# ---------------------------------------------------------------------------
class TestStreamBootstrap:
    async def test_ensure_streams_creates_all(self, js) -> None:
        result = await ensure_streams(js)
        assert set(result) == set(ALL_STREAM_NAMES)

        for name in ALL_STREAM_NAMES:
            info = await js.stream_info(name)
            assert info.config.name == name

    async def test_ensure_streams_is_idempotent(self, js) -> None:
        await ensure_streams(js)
        result = await ensure_streams(js)
        assert len(result) == len(STREAM_DEFS)

    async def test_ensure_consumers_creates_all(self, js) -> None:
        await ensure_streams(js)
        result = await ensure_consumers(js)
        assert len(result) == len(CONSUMER_DEFS)

    async def test_ensure_all_creates_streams_and_consumers(self, js) -> None:
        streams, consumers = await ensure_all(js)
        assert len(streams) == len(STREAM_DEFS)
        assert len(consumers) == len(CONSUMER_DEFS)

    async def test_stream_subjects_match_definitions(self, js) -> None:
        await ensure_streams(js)
        for sdef in STREAM_DEFS:
            info = await js.stream_info(sdef.name)
            assert list(info.config.subjects) == sdef.subjects

    async def test_consumer_bindings_are_correct(self, js) -> None:
        await ensure_all(js)
        for cdef in CONSUMER_DEFS:
            info = await js.consumer_info(cdef.stream_name, cdef.durable_name)
            assert info.config.durable_name == cdef.durable_name
            assert info.config.filter_subject == cdef.filter_subject


# ---------------------------------------------------------------------------
# Publish / Subscribe
# ---------------------------------------------------------------------------
class TestPublishSubscribe:
    async def test_publish_and_pull_subscribe_crossing(self, js) -> None:
        await ensure_all(js)

        payload = json.dumps({"camera_id": "cam_test", "class12": "sedan"}).encode()
        await js.publish(f"{SUBJECT_CROSSINGS}.cam_test", payload)

        sub = await js.pull_subscribe(
            f"{SUBJECT_CROSSINGS}.>",
            durable=CONSUMER_AGGREGATOR_CROSSINGS,
            stream=STREAM_CROSSINGS,
        )
        messages = await sub.fetch(batch=1, timeout=5)
        assert len(messages) == 1
        assert json.loads(messages[0].data)["camera_id"] == "cam_test"
        await messages[0].ack()

    async def test_publish_and_pull_subscribe_frame(self, js) -> None:
        await ensure_all(js)

        frame_data = b"\xff\xd8synthetic_frame"
        headers = {"Camera-Id": "cam_001", "Content-Type": "image/jpeg"}
        await js.publish(f"{SUBJECT_FRAMES}.cam_001", frame_data, headers=headers)

        sub = await js.pull_subscribe(
            f"{SUBJECT_FRAMES}.>",
            durable=CONSUMER_INFERENCE_WORKER,
            stream=STREAM_FRAMES,
        )
        messages = await sub.fetch(batch=1, timeout=5)
        assert len(messages) == 1
        assert messages[0].data == frame_data
        assert messages[0].headers["Camera-Id"] == "cam_001"
        await messages[0].ack()

    async def test_multiple_consumers_on_same_stream(self, js) -> None:
        """Two consumers on CROSSINGS each get their own copy of the message."""
        await ensure_all(js)

        payload = json.dumps({"event": "crossing", "id": "evt_001"}).encode()
        await js.publish(f"{SUBJECT_CROSSINGS}.cam_test", payload)

        sub_agg = await js.pull_subscribe(
            f"{SUBJECT_CROSSINGS}.>",
            durable=CONSUMER_AGGREGATOR_CROSSINGS,
            stream=STREAM_CROSSINGS,
        )
        sub_notif = await js.pull_subscribe(
            f"{SUBJECT_CROSSINGS}.>",
            durable=CONSUMER_NOTIFICATION_CROSSINGS,
            stream=STREAM_CROSSINGS,
        )

        msgs_agg = await sub_agg.fetch(batch=1, timeout=5)
        msgs_notif = await sub_notif.fetch(batch=1, timeout=5)

        assert len(msgs_agg) == 1
        assert len(msgs_notif) == 1
        assert msgs_agg[0].data == msgs_notif[0].data

        await msgs_agg[0].ack()
        await msgs_notif[0].ack()

    async def test_subject_filtering(self, js) -> None:
        """Messages on different camera subjects are all captured by wildcard."""
        await ensure_all(js)

        for cam in ["cam_a", "cam_b", "cam_c"]:
            await js.publish(
                f"{SUBJECT_CROSSINGS}.{cam}",
                json.dumps({"camera_id": cam}).encode(),
            )

        sub = await js.pull_subscribe(
            f"{SUBJECT_CROSSINGS}.>",
            durable=CONSUMER_AGGREGATOR_CROSSINGS,
            stream=STREAM_CROSSINGS,
        )
        messages = await sub.fetch(batch=10, timeout=5)
        assert len(messages) == 3
        cameras = {json.loads(m.data)["camera_id"] for m in messages}
        assert cameras == {"cam_a", "cam_b", "cam_c"}
        for m in messages:
            await m.ack()


# ---------------------------------------------------------------------------
# DLQ routing (end-to-end with real NATS)
# ---------------------------------------------------------------------------
class TestDLQRouting:
    async def test_dlq_handler_routes_failed_message(self, js) -> None:
        """After max_deliver failures, message lands in the DLQ stream."""
        await ensure_all(js)

        payload = json.dumps({"event": "will_fail"}).encode()
        await js.publish(f"{SUBJECT_CROSSINGS}.cam_fail", payload)

        dlq = DLQHandler(js, max_deliver=1)
        sub = await js.pull_subscribe(
            f"{SUBJECT_CROSSINGS}.>",
            durable=CONSUMER_AGGREGATOR_CROSSINGS,
            stream=STREAM_CROSSINGS,
        )

        messages = await sub.fetch(batch=1, timeout=5)
        assert len(messages) == 1

        async def failing_callback(msg):
            raise ValueError("simulated processing failure")

        result = await dlq.process(messages[0], failing_callback)
        assert result is False

        dlq_sub = await js.pull_subscribe(
            f"{SUBJECT_DLQ}.>",
            durable="test-dlq-reader",
            stream=STREAM_DLQ,
        )
        dlq_msgs = await dlq_sub.fetch(batch=1, timeout=5)
        assert len(dlq_msgs) == 1

        expected_dlq_subject = dlq_subject_for("events.crossings.cam_fail")
        assert dlq_msgs[0].subject == expected_dlq_subject
        assert dlq_msgs[0].headers["X-DLQ-Original-Subject"] == "events.crossings.cam_fail"
        assert "ValueError" in dlq_msgs[0].headers["X-DLQ-Error-Reason"]
        assert json.loads(dlq_msgs[0].data) == {"event": "will_fail"}
        await dlq_msgs[0].ack()

    async def test_dlq_preserves_original_headers(self, js) -> None:
        await ensure_all(js)

        headers = {"Camera-Id": "cam_hdr", "Content-Type": "application/json"}
        await js.publish(
            f"{SUBJECT_CROSSINGS}.cam_hdr",
            b'{"test": true}',
            headers=headers,
        )

        dlq = DLQHandler(js, max_deliver=1)
        sub = await js.pull_subscribe(
            f"{SUBJECT_CROSSINGS}.>",
            durable=CONSUMER_AGGREGATOR_CROSSINGS,
            stream=STREAM_CROSSINGS,
        )
        messages = await sub.fetch(batch=1, timeout=5)

        await dlq.process(messages[0], AsyncMock(side_effect=RuntimeError("fail")))

        dlq_sub = await js.pull_subscribe(
            f"{SUBJECT_DLQ}.>",
            durable="test-dlq-headers",
            stream=STREAM_DLQ,
        )
        dlq_msgs = await dlq_sub.fetch(batch=1, timeout=5)
        assert dlq_msgs[0].headers["Camera-Id"] == "cam_hdr"
        await dlq_msgs[0].ack()

    async def test_transient_failure_naks_for_redelivery(self, js) -> None:
        """A failure before max_deliver NAKs so NATS redelivers."""
        await ensure_all(js)

        await js.publish(
            f"{SUBJECT_CROSSINGS}.cam_retry",
            json.dumps({"retry": True}).encode(),
        )

        dlq = DLQHandler(js, max_deliver=3)
        sub = await js.pull_subscribe(
            f"{SUBJECT_CROSSINGS}.>",
            durable=CONSUMER_AGGREGATOR_CROSSINGS,
            stream=STREAM_CROSSINGS,
        )

        messages = await sub.fetch(batch=1, timeout=5)
        result = await dlq.process(
            messages[0], AsyncMock(side_effect=ValueError("transient"))
        )
        assert result is False

        await asyncio.sleep(0.5)
        redelivered = await sub.fetch(batch=1, timeout=5)
        assert len(redelivered) == 1
        assert json.loads(redelivered[0].data)["retry"] is True
        await redelivered[0].ack()


# ---------------------------------------------------------------------------
# Message replay
# ---------------------------------------------------------------------------
class TestMessageReplay:
    async def test_replay_from_stream_beginning(self, js) -> None:
        """A new consumer with deliver_policy=all replays all messages."""
        await ensure_all(js)

        for i in range(5):
            await js.publish(
                f"{SUBJECT_CROSSINGS}.cam_replay",
                json.dumps({"seq": i}).encode(),
            )

        from nats.js.api import ConsumerConfig, DeliverPolicy

        await js.add_consumer(
            STREAM_CROSSINGS,
            ConsumerConfig(
                durable_name="replay-test-consumer",
                filter_subject=f"{SUBJECT_CROSSINGS}.>",
                deliver_policy=DeliverPolicy.ALL,
            ),
        )

        sub = await js.pull_subscribe(
            f"{SUBJECT_CROSSINGS}.>",
            durable="replay-test-consumer",
            stream=STREAM_CROSSINGS,
        )
        messages = await sub.fetch(batch=10, timeout=5)
        assert len(messages) == 5
        seqs = [json.loads(m.data)["seq"] for m in messages]
        assert seqs == [0, 1, 2, 3, 4]
        for m in messages:
            await m.ack()

    async def test_replay_does_not_affect_other_consumers(self, js) -> None:
        """Replaying via a new consumer doesn't disturb existing consumers."""
        await ensure_all(js)

        for i in range(3):
            await js.publish(
                f"{SUBJECT_CROSSINGS}.cam_iso",
                json.dumps({"idx": i}).encode(),
            )

        sub_agg = await js.pull_subscribe(
            f"{SUBJECT_CROSSINGS}.>",
            durable=CONSUMER_AGGREGATOR_CROSSINGS,
            stream=STREAM_CROSSINGS,
        )
        msgs = await sub_agg.fetch(batch=3, timeout=5)
        for m in msgs:
            await m.ack()

        from nats.js.api import ConsumerConfig, DeliverPolicy

        await js.add_consumer(
            STREAM_CROSSINGS,
            ConsumerConfig(
                durable_name="replay-isolation-consumer",
                filter_subject=f"{SUBJECT_CROSSINGS}.>",
                deliver_policy=DeliverPolicy.ALL,
            ),
        )
        sub_replay = await js.pull_subscribe(
            f"{SUBJECT_CROSSINGS}.>",
            durable="replay-isolation-consumer",
            stream=STREAM_CROSSINGS,
        )
        replay_msgs = await sub_replay.fetch(batch=10, timeout=5)
        assert len(replay_msgs) == 3

        try:
            extra = await sub_agg.fetch(batch=1, timeout=1)
        except nats.errors.TimeoutError:
            extra = []
        assert len(extra) == 0

        for m in replay_msgs:
            await m.ack()
