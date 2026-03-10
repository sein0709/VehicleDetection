"""Tests for NATS JetStream stream and consumer configuration.

Covers:
- Stream/consumer definition completeness and consistency
- Subject mapping and DLQ routing
- ensure_streams / ensure_consumers / ensure_all with mocked JetStream
- StreamDef and ConsumerDef dataclass behaviour
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, call

import pytest

from shared_contracts.nats_streams import (
    ALL_STREAM_NAMES,
    CONSUMER_AGGREGATOR_CROSSINGS,
    CONSUMER_AGGREGATOR_RECOMPUTE,
    CONSUMER_DEFS,
    CONSUMER_DEFS_BY_DURABLE,
    CONSUMER_INFERENCE_WORKER,
    CONSUMER_NOTIFICATION_CROSSINGS,
    CONSUMER_NOTIFICATION_HEALTH,
    MAX_AGE_24H_S,
    MAX_AGE_30D_S,
    MAX_AGE_7D_S,
    STREAM_ALERTS,
    STREAM_COMMANDS,
    STREAM_CROSSINGS,
    STREAM_DEFS,
    STREAM_DEFS_BY_NAME,
    STREAM_DLQ,
    STREAM_FRAMES,
    STREAM_HEALTH,
    STREAM_TRACKS,
    SUBJECT_ALERTS,
    SUBJECT_COMMANDS,
    SUBJECT_CROSSINGS,
    SUBJECT_DLQ,
    SUBJECT_FRAMES,
    SUBJECT_HEALTH,
    SUBJECT_RECOMPUTE,
    SUBJECT_TRACKS,
    ConsumerDef,
    StreamDef,
    dlq_subject_for,
    ensure_all,
    ensure_consumers,
    ensure_streams,
)


# ---------------------------------------------------------------------------
# Stream definitions
# ---------------------------------------------------------------------------
class TestStreamDefinitions:
    def test_seven_streams_defined(self) -> None:
        assert len(STREAM_DEFS) == 7

    def test_all_stream_names_match(self) -> None:
        expected = {
            STREAM_FRAMES,
            STREAM_CROSSINGS,
            STREAM_TRACKS,
            STREAM_HEALTH,
            STREAM_ALERTS,
            STREAM_COMMANDS,
            STREAM_DLQ,
        }
        assert set(ALL_STREAM_NAMES) == expected

    def test_stream_defs_by_name_lookup(self) -> None:
        for sdef in STREAM_DEFS:
            assert STREAM_DEFS_BY_NAME[sdef.name] is sdef

    def test_every_stream_has_subjects(self) -> None:
        for sdef in STREAM_DEFS:
            assert len(sdef.subjects) >= 1
            assert all(isinstance(s, str) for s in sdef.subjects)

    def test_every_stream_has_positive_max_age(self) -> None:
        for sdef in STREAM_DEFS:
            assert sdef.max_age_seconds > 0

    def test_frames_stream_config(self) -> None:
        s = STREAM_DEFS_BY_NAME[STREAM_FRAMES]
        assert s.subjects == [f"{SUBJECT_FRAMES}.>"]
        assert s.max_age_seconds == MAX_AGE_24H_S
        assert s.max_msgs == 100_000
        assert s.max_msg_size == 10 * 1024 * 1024

    def test_crossings_stream_config(self) -> None:
        s = STREAM_DEFS_BY_NAME[STREAM_CROSSINGS]
        assert s.subjects == [f"{SUBJECT_CROSSINGS}.>"]
        assert s.max_age_seconds == MAX_AGE_7D_S

    def test_dlq_stream_has_30d_retention(self) -> None:
        s = STREAM_DEFS_BY_NAME[STREAM_DLQ]
        assert s.subjects == [f"{SUBJECT_DLQ}.>"]
        assert s.max_age_seconds == MAX_AGE_30D_S

    def test_commands_stream_config(self) -> None:
        s = STREAM_DEFS_BY_NAME[STREAM_COMMANDS]
        assert s.subjects == [f"{SUBJECT_COMMANDS}.>"]

    def test_stream_names_are_uppercase(self) -> None:
        for sdef in STREAM_DEFS:
            assert sdef.name == sdef.name.upper()


class TestStreamDef:
    def test_subject_for_appends_token(self) -> None:
        sdef = StreamDef("TEST", ["events.crossings.>"], max_age_seconds=3600)
        assert sdef.subject_for("cam_001") == "events.crossings.cam_001"

    def test_subject_for_with_star_wildcard(self) -> None:
        sdef = StreamDef("TEST", ["frames.*"], max_age_seconds=3600)
        assert sdef.subject_for("cam_002") == "frames.cam_002"

    def test_subject_for_plain_prefix(self) -> None:
        sdef = StreamDef("TEST", ["commands.recompute"], max_age_seconds=3600)
        assert sdef.subject_for("org_001") == "commands.recompute.org_001"

    def test_frozen_dataclass(self) -> None:
        sdef = StreamDef("TEST", ["a.>"], max_age_seconds=100)
        with pytest.raises(AttributeError):
            sdef.name = "OTHER"  # type: ignore[misc]


# ---------------------------------------------------------------------------
# Consumer definitions
# ---------------------------------------------------------------------------
class TestConsumerDefinitions:
    def test_five_consumers_defined(self) -> None:
        assert len(CONSUMER_DEFS) == 5

    def test_consumer_defs_by_durable_lookup(self) -> None:
        for cdef in CONSUMER_DEFS:
            assert CONSUMER_DEFS_BY_DURABLE[cdef.durable_name] is cdef

    def test_inference_worker_consumer(self) -> None:
        c = CONSUMER_DEFS_BY_DURABLE[CONSUMER_INFERENCE_WORKER]
        assert c.stream_name == STREAM_FRAMES
        assert c.filter_subject == f"{SUBJECT_FRAMES}.>"
        assert c.deliver_policy == "last"

    def test_aggregator_crossings_consumer(self) -> None:
        c = CONSUMER_DEFS_BY_DURABLE[CONSUMER_AGGREGATOR_CROSSINGS]
        assert c.stream_name == STREAM_CROSSINGS
        assert c.filter_subject == f"{SUBJECT_CROSSINGS}.>"
        assert c.deliver_policy == "all"
        assert c.max_deliver == 5

    def test_notification_crossings_consumer(self) -> None:
        c = CONSUMER_DEFS_BY_DURABLE[CONSUMER_NOTIFICATION_CROSSINGS]
        assert c.stream_name == STREAM_CROSSINGS
        assert c.deliver_policy == "last"

    def test_notification_health_consumer(self) -> None:
        c = CONSUMER_DEFS_BY_DURABLE[CONSUMER_NOTIFICATION_HEALTH]
        assert c.stream_name == STREAM_HEALTH
        assert c.filter_subject == f"{SUBJECT_HEALTH}.>"

    def test_aggregator_recompute_consumer(self) -> None:
        c = CONSUMER_DEFS_BY_DURABLE[CONSUMER_AGGREGATOR_RECOMPUTE]
        assert c.stream_name == STREAM_COMMANDS
        assert c.filter_subject == SUBJECT_RECOMPUTE
        assert c.ack_wait_seconds == 60.0

    def test_all_consumers_reference_valid_streams(self) -> None:
        stream_names = {s.name for s in STREAM_DEFS}
        for cdef in CONSUMER_DEFS:
            assert cdef.stream_name in stream_names, (
                f"Consumer {cdef.durable_name} references unknown stream {cdef.stream_name}"
            )

    def test_all_consumers_have_positive_ack_wait(self) -> None:
        for cdef in CONSUMER_DEFS:
            assert cdef.ack_wait_seconds > 0

    def test_all_consumers_have_positive_max_deliver(self) -> None:
        for cdef in CONSUMER_DEFS:
            assert cdef.max_deliver >= 1

    def test_consumer_durable_names_are_unique(self) -> None:
        names = [c.durable_name for c in CONSUMER_DEFS]
        assert len(names) == len(set(names))


class TestConsumerDef:
    def test_frozen_dataclass(self) -> None:
        cdef = ConsumerDef("S", "d", "f.>")
        with pytest.raises(AttributeError):
            cdef.stream_name = "OTHER"  # type: ignore[misc]


# ---------------------------------------------------------------------------
# DLQ subject mapping
# ---------------------------------------------------------------------------
class TestDLQSubjectMapping:
    def test_crossing_event_subject(self) -> None:
        assert dlq_subject_for("events.crossings.cam_001") == "events.dlq.crossings.cam_001"

    def test_health_event_subject(self) -> None:
        assert dlq_subject_for("events.health.cam_002") == "events.dlq.health.cam_002"

    def test_track_event_subject(self) -> None:
        assert dlq_subject_for("events.tracks.cam_003") == "events.dlq.tracks.cam_003"

    def test_alert_event_subject(self) -> None:
        assert dlq_subject_for("events.alerts.org_001") == "events.dlq.alerts.org_001"

    def test_frames_subject(self) -> None:
        assert dlq_subject_for("frames.cam_004") == "events.dlq.frames.cam_004"

    def test_commands_subject(self) -> None:
        assert dlq_subject_for("commands.recompute") == "events.dlq.commands.recompute"

    def test_deeply_nested_subject(self) -> None:
        assert (
            dlq_subject_for("events.crossings.org.site.cam")
            == "events.dlq.crossings.org.site.cam"
        )


# ---------------------------------------------------------------------------
# ensure_streams (mocked JetStream)
# ---------------------------------------------------------------------------
class TestEnsureStreams:
    @pytest.mark.asyncio
    async def test_creates_all_streams(self) -> None:
        js = MagicMock()
        js.add_stream = AsyncMock()

        result = await ensure_streams(js)

        assert len(result) == 7
        assert js.add_stream.call_count == 7

    @pytest.mark.asyncio
    async def test_creates_subset_of_streams(self) -> None:
        js = MagicMock()
        js.add_stream = AsyncMock()

        subset = [STREAM_DEFS_BY_NAME[STREAM_FRAMES], STREAM_DEFS_BY_NAME[STREAM_HEALTH]]
        result = await ensure_streams(js, streams=subset)

        assert result == [STREAM_FRAMES, STREAM_HEALTH]
        assert js.add_stream.call_count == 2

    @pytest.mark.asyncio
    async def test_passes_replicas(self) -> None:
        js = MagicMock()
        js.add_stream = AsyncMock()

        await ensure_streams(js, replicas=3)

        for c in js.add_stream.call_args_list:
            config = c[0][0]
            assert config.num_replicas == 3

    @pytest.mark.asyncio
    async def test_passes_max_bytes_override(self) -> None:
        js = MagicMock()
        js.add_stream = AsyncMock()

        await ensure_streams(js, max_bytes=1_000_000)

        for c in js.add_stream.call_args_list:
            config = c[0][0]
            assert config.max_bytes == 1_000_000

    @pytest.mark.asyncio
    async def test_propagates_exception(self) -> None:
        js = MagicMock()
        js.add_stream = AsyncMock(side_effect=RuntimeError("NATS down"))

        with pytest.raises(RuntimeError, match="NATS down"):
            await ensure_streams(js)


# ---------------------------------------------------------------------------
# ensure_consumers (mocked JetStream)
# ---------------------------------------------------------------------------
class TestEnsureConsumers:
    @pytest.mark.asyncio
    async def test_creates_all_consumers(self) -> None:
        js = MagicMock()
        js.add_consumer = AsyncMock()

        result = await ensure_consumers(js)

        assert len(result) == 5
        assert js.add_consumer.call_count == 5

    @pytest.mark.asyncio
    async def test_creates_subset_of_consumers(self) -> None:
        js = MagicMock()
        js.add_consumer = AsyncMock()

        subset = [CONSUMER_DEFS_BY_DURABLE[CONSUMER_INFERENCE_WORKER]]
        result = await ensure_consumers(js, consumers=subset)

        assert result == [CONSUMER_INFERENCE_WORKER]
        assert js.add_consumer.call_count == 1

    @pytest.mark.asyncio
    async def test_consumer_bound_to_correct_stream(self) -> None:
        js = MagicMock()
        js.add_consumer = AsyncMock()

        await ensure_consumers(js)

        calls = js.add_consumer.call_args_list
        stream_consumer_pairs = [(c[0][0], c[0][1].durable_name) for c in calls]

        assert (STREAM_FRAMES, CONSUMER_INFERENCE_WORKER) in stream_consumer_pairs
        assert (STREAM_CROSSINGS, CONSUMER_AGGREGATOR_CROSSINGS) in stream_consumer_pairs
        assert (STREAM_CROSSINGS, CONSUMER_NOTIFICATION_CROSSINGS) in stream_consumer_pairs
        assert (STREAM_HEALTH, CONSUMER_NOTIFICATION_HEALTH) in stream_consumer_pairs
        assert (STREAM_COMMANDS, CONSUMER_AGGREGATOR_RECOMPUTE) in stream_consumer_pairs

    @pytest.mark.asyncio
    async def test_propagates_exception(self) -> None:
        js = MagicMock()
        js.add_consumer = AsyncMock(side_effect=RuntimeError("consumer error"))

        with pytest.raises(RuntimeError, match="consumer error"):
            await ensure_consumers(js)


# ---------------------------------------------------------------------------
# ensure_all (mocked JetStream)
# ---------------------------------------------------------------------------
class TestEnsureAll:
    @pytest.mark.asyncio
    async def test_creates_streams_then_consumers(self) -> None:
        js = MagicMock()
        js.add_stream = AsyncMock()
        js.add_consumer = AsyncMock()

        streams, consumers = await ensure_all(js)

        assert len(streams) == 7
        assert len(consumers) == 5
        assert js.add_stream.call_count == 7
        assert js.add_consumer.call_count == 5

    @pytest.mark.asyncio
    async def test_passes_replicas_and_max_bytes(self) -> None:
        js = MagicMock()
        js.add_stream = AsyncMock()
        js.add_consumer = AsyncMock()

        await ensure_all(js, replicas=3, max_bytes=500_000)

        for c in js.add_stream.call_args_list:
            config = c[0][0]
            assert config.num_replicas == 3
            assert config.max_bytes == 500_000


# ---------------------------------------------------------------------------
# Subject prefix constants
# ---------------------------------------------------------------------------
class TestSubjectPrefixes:
    def test_subject_prefixes_are_strings(self) -> None:
        for subj in [
            SUBJECT_FRAMES,
            SUBJECT_CROSSINGS,
            SUBJECT_TRACKS,
            SUBJECT_HEALTH,
            SUBJECT_ALERTS,
            SUBJECT_COMMANDS,
            SUBJECT_DLQ,
            SUBJECT_RECOMPUTE,
        ]:
            assert isinstance(subj, str)
            assert len(subj) > 0

    def test_recompute_is_under_commands(self) -> None:
        assert SUBJECT_RECOMPUTE.startswith(SUBJECT_COMMANDS)

    def test_dlq_is_under_events(self) -> None:
        assert SUBJECT_DLQ.startswith("events.")
