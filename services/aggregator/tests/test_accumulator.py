"""Tests for the in-memory bucket accumulator.

Covers: bucket assignment, accumulation, flush triggers, late-event handling,
future-timestamp rejection, and flush_late_only.
"""

from __future__ import annotations

import time
from datetime import UTC, datetime, timedelta

import pytest
from aggregator.accumulator import BucketAccumulator

from shared_contracts.enums import VehicleClass12
from shared_contracts.events import compute_bucket_start
from tests.conftest import make_crossing_event


# -----------------------------------------------------------------------
# Bucket assignment
# -----------------------------------------------------------------------
class TestBucketAssignment:
    """Verify events are assigned to the correct 15-minute bucket."""

    def test_event_at_hour_start(self) -> None:
        ts = datetime(2025, 6, 15, 10, 0, 0, tzinfo=UTC)
        event = make_crossing_event(timestamp_utc=ts)
        expected = datetime(2025, 6, 15, 10, 0, 0, tzinfo=UTC)
        assert compute_bucket_start(event.timestamp_utc) == expected

    def test_event_mid_bucket(self) -> None:
        ts = datetime(2025, 6, 15, 10, 7, 30, tzinfo=UTC)
        event = make_crossing_event(timestamp_utc=ts)
        expected = datetime(2025, 6, 15, 10, 0, 0, tzinfo=UTC)
        assert compute_bucket_start(event.timestamp_utc) == expected

    def test_event_at_bucket_boundary(self) -> None:
        ts = datetime(2025, 6, 15, 10, 15, 0, tzinfo=UTC)
        event = make_crossing_event(timestamp_utc=ts)
        expected = datetime(2025, 6, 15, 10, 15, 0, tzinfo=UTC)
        assert compute_bucket_start(event.timestamp_utc) == expected

    def test_event_at_45_minute_mark(self) -> None:
        ts = datetime(2025, 6, 15, 10, 47, 59, tzinfo=UTC)
        event = make_crossing_event(timestamp_utc=ts)
        expected = datetime(2025, 6, 15, 10, 45, 0, tzinfo=UTC)
        assert compute_bucket_start(event.timestamp_utc) == expected

    def test_event_at_end_of_day(self) -> None:
        ts = datetime(2025, 6, 15, 23, 59, 59, tzinfo=UTC)
        expected = datetime(2025, 6, 15, 23, 45, 0, tzinfo=UTC)
        assert compute_bucket_start(ts) == expected

    def test_event_at_midnight(self) -> None:
        ts = datetime(2025, 6, 16, 0, 0, 0, tzinfo=UTC)
        expected = datetime(2025, 6, 16, 0, 0, 0, tzinfo=UTC)
        assert compute_bucket_start(ts) == expected


# -----------------------------------------------------------------------
# Accumulation
# -----------------------------------------------------------------------
class TestAccumulation:
    """Verify event counters are accumulated correctly."""

    def test_single_event(self, accumulator: BucketAccumulator) -> None:
        event = make_crossing_event(confidence=0.9, speed_estimate_kmh=50.0)
        accumulator.add_event(event)

        assert accumulator.pending_count == 1
        rows = accumulator.flush()
        assert len(rows) == 1
        assert rows[0]["count"] == 1
        assert rows[0]["sum_confidence"] == 0.9
        assert rows[0]["min_speed_kmh"] == 50.0
        assert rows[0]["max_speed_kmh"] == 50.0

    def test_multiple_same_bucket(self, accumulator: BucketAccumulator) -> None:
        ts = datetime(2025, 6, 15, 10, 5, 0, tzinfo=UTC)
        for i in range(5):
            event = make_crossing_event(
                confidence=0.8 + i * 0.02,
                speed_estimate_kmh=40.0 + i * 10,
                timestamp_utc=ts,
            )
            accumulator.add_event(event)

        assert accumulator.pending_count == 5
        rows = accumulator.flush()
        assert len(rows) == 1
        assert rows[0]["count"] == 5
        assert rows[0]["min_speed_kmh"] == 40.0
        assert rows[0]["max_speed_kmh"] == 80.0

    def test_different_classes_separate_buckets(self, accumulator: BucketAccumulator) -> None:
        ts = datetime(2025, 6, 15, 10, 5, 0, tzinfo=UTC)
        accumulator.add_event(
            make_crossing_event(class12=VehicleClass12.C01_PASSENGER_MINITRUCK, timestamp_utc=ts)
        )
        accumulator.add_event(make_crossing_event(class12=VehicleClass12.C02_BUS, timestamp_utc=ts))

        rows = accumulator.flush()
        assert len(rows) == 2

    def test_different_directions_separate_buckets(self, accumulator: BucketAccumulator) -> None:
        ts = datetime(2025, 6, 15, 10, 5, 0, tzinfo=UTC)
        accumulator.add_event(make_crossing_event(direction="inbound", timestamp_utc=ts))
        accumulator.add_event(make_crossing_event(direction="outbound", timestamp_utc=ts))

        rows = accumulator.flush()
        assert len(rows) == 2

    def test_different_cameras_separate_buckets(self, accumulator: BucketAccumulator) -> None:
        ts = datetime(2025, 6, 15, 10, 5, 0, tzinfo=UTC)
        accumulator.add_event(make_crossing_event(camera_id="cam_A", timestamp_utc=ts))
        accumulator.add_event(make_crossing_event(camera_id="cam_B", timestamp_utc=ts))

        rows = accumulator.flush()
        assert len(rows) == 2
        camera_ids = {r["camera_id"] for r in rows}
        assert camera_ids == {"cam_A", "cam_B"}

    def test_different_lines_separate_buckets(self, accumulator: BucketAccumulator) -> None:
        ts = datetime(2025, 6, 15, 10, 5, 0, tzinfo=UTC)
        accumulator.add_event(make_crossing_event(line_id="line_1", timestamp_utc=ts))
        accumulator.add_event(make_crossing_event(line_id="line_2", timestamp_utc=ts))

        rows = accumulator.flush()
        assert len(rows) == 2

    def test_no_speed_events(self, accumulator: BucketAccumulator) -> None:
        event = make_crossing_event(speed_estimate_kmh=None)
        accumulator.add_event(event)

        rows = accumulator.flush()
        assert rows[0]["min_speed_kmh"] is None
        assert rows[0]["max_speed_kmh"] is None
        assert rows[0]["sum_speed_kmh"] is None

    def test_flush_clears_buffer(self, accumulator: BucketAccumulator) -> None:
        accumulator.add_event(make_crossing_event())
        assert accumulator.pending_count == 1

        accumulator.flush()
        assert accumulator.pending_count == 0

    def test_bucket_key_includes_org(self, accumulator: BucketAccumulator) -> None:
        event = make_crossing_event(org_id="org_42")
        accumulator.add_event(event)
        rows = accumulator.flush()
        assert rows[0]["org_id"] == "org_42"

    def test_confidence_accumulation(self, accumulator: BucketAccumulator) -> None:
        ts = datetime(2025, 6, 15, 10, 5, 0, tzinfo=UTC)
        accumulator.add_event(make_crossing_event(confidence=0.8, timestamp_utc=ts))
        accumulator.add_event(make_crossing_event(confidence=0.9, timestamp_utc=ts))
        accumulator.add_event(make_crossing_event(confidence=0.7, timestamp_utc=ts))

        rows = accumulator.flush()
        assert rows[0]["sum_confidence"] == pytest.approx(2.4)

    def test_speed_min_max_tracking(self, accumulator: BucketAccumulator) -> None:
        ts = datetime(2025, 6, 15, 10, 5, 0, tzinfo=UTC)
        accumulator.add_event(make_crossing_event(speed_estimate_kmh=30.0, timestamp_utc=ts))
        accumulator.add_event(make_crossing_event(speed_estimate_kmh=90.0, timestamp_utc=ts))
        accumulator.add_event(make_crossing_event(speed_estimate_kmh=60.0, timestamp_utc=ts))

        rows = accumulator.flush()
        assert rows[0]["min_speed_kmh"] == 30.0
        assert rows[0]["max_speed_kmh"] == 90.0
        assert rows[0]["sum_speed_kmh"] == pytest.approx(180.0)

    def test_mixed_speed_and_no_speed(self, accumulator: BucketAccumulator) -> None:
        ts = datetime(2025, 6, 15, 10, 5, 0, tzinfo=UTC)
        accumulator.add_event(make_crossing_event(speed_estimate_kmh=50.0, timestamp_utc=ts))
        accumulator.add_event(make_crossing_event(speed_estimate_kmh=None, timestamp_utc=ts))

        rows = accumulator.flush()
        assert rows[0]["min_speed_kmh"] == 50.0
        assert rows[0]["max_speed_kmh"] == 50.0
        assert rows[0]["sum_speed_kmh"] == pytest.approx(50.0)


# -----------------------------------------------------------------------
# Flush triggers
# -----------------------------------------------------------------------
class TestFlushTriggers:
    """Verify should_flush() triggers correctly."""

    def test_no_events_no_flush(self, accumulator: BucketAccumulator) -> None:
        assert not accumulator.should_flush()

    def test_buffer_size_trigger(self) -> None:
        acc = BucketAccumulator(flush_interval_seconds=9999, max_buffer_size=3)
        ts = datetime(2025, 6, 15, 10, 5, 0, tzinfo=UTC)
        for _ in range(3):
            acc.add_event(make_crossing_event(timestamp_utc=ts))
        assert acc.should_flush()

    def test_time_trigger(self) -> None:
        acc = BucketAccumulator(flush_interval_seconds=0.01, max_buffer_size=9999)
        acc.add_event(make_crossing_event())
        time.sleep(0.02)
        assert acc.should_flush()

    def test_bucket_boundary_trigger(self) -> None:
        acc = BucketAccumulator(flush_interval_seconds=9999, max_buffer_size=9999)
        ts1 = datetime(2025, 6, 15, 10, 14, 0, tzinfo=UTC)
        ts2 = datetime(2025, 6, 15, 10, 16, 0, tzinfo=UTC)
        acc.add_event(make_crossing_event(timestamp_utc=ts1))
        acc.add_event(make_crossing_event(timestamp_utc=ts2))
        assert acc.should_flush()

    def test_no_premature_flush(self) -> None:
        acc = BucketAccumulator(flush_interval_seconds=9999, max_buffer_size=9999)
        ts = datetime(2025, 6, 15, 10, 5, 0, tzinfo=UTC)
        acc.add_event(make_crossing_event(timestamp_utc=ts))
        assert not acc.should_flush()

    def test_flush_resets_timer(self) -> None:
        acc = BucketAccumulator(flush_interval_seconds=9999, max_buffer_size=9999)
        ts = datetime(2025, 6, 15, 10, 5, 0, tzinfo=UTC)
        acc.add_event(make_crossing_event(timestamp_utc=ts))
        acc.flush()

        acc.add_event(make_crossing_event(timestamp_utc=ts))
        assert not acc.should_flush()


# -----------------------------------------------------------------------
# Late-arriving events
# -----------------------------------------------------------------------
class TestLateEvents:
    """Verify handling of events arriving for past buckets."""

    def test_late_event_accepted(self, accumulator: BucketAccumulator) -> None:
        past_ts = datetime.now(UTC) - timedelta(minutes=30)
        event = make_crossing_event(timestamp_utc=past_ts)
        result = accumulator.add_event(event)

        assert result.status == "accepted"
        assert result.is_late is True

    def test_very_old_event_still_accepted(self, accumulator: BucketAccumulator) -> None:
        old_ts = datetime.now(UTC) - timedelta(hours=5)
        event = make_crossing_event(timestamp_utc=old_ts)
        result = accumulator.add_event(event)

        assert result.status == "accepted"
        assert result.is_late is True

    def test_current_bucket_event_not_late(self, accumulator: BucketAccumulator) -> None:
        now = datetime.now(UTC)
        event = make_crossing_event(timestamp_utc=now)
        result = accumulator.add_event(event)

        assert result.status == "accepted"
        assert result.is_late is False

    def test_late_event_count_tracked(self, accumulator: BucketAccumulator) -> None:
        past_ts = datetime.now(UTC) - timedelta(minutes=30)
        for _ in range(3):
            accumulator.add_event(make_crossing_event(timestamp_utc=past_ts))

        assert accumulator.stats["late_events"] == 3


# -----------------------------------------------------------------------
# Future-timestamp rejection
# -----------------------------------------------------------------------
class TestFutureRejection:
    """Verify events with future timestamps are rejected."""

    def test_future_event_rejected(self, accumulator: BucketAccumulator) -> None:
        future_ts = datetime.now(UTC) + timedelta(minutes=5)
        event = make_crossing_event(timestamp_utc=future_ts)
        result = accumulator.add_event(event)

        assert result.status == "rejected_future"
        assert result.bucket_start is None
        assert accumulator.pending_count == 0

    def test_slight_future_within_tolerance_accepted(self, accumulator: BucketAccumulator) -> None:
        near_future = datetime.now(UTC) + timedelta(seconds=10)
        event = make_crossing_event(timestamp_utc=near_future)
        result = accumulator.add_event(event)

        assert result.status == "accepted"

    def test_rejected_future_count_tracked(self, accumulator: BucketAccumulator) -> None:
        future_ts = datetime.now(UTC) + timedelta(minutes=10)
        accumulator.add_event(make_crossing_event(timestamp_utc=future_ts))
        accumulator.add_event(make_crossing_event(timestamp_utc=future_ts))

        assert accumulator.stats["rejected_future"] == 2
        assert accumulator.pending_count == 0


# -----------------------------------------------------------------------
# Stats
# -----------------------------------------------------------------------
class TestStats:
    """Verify the stats property."""

    def test_initial_stats(self, accumulator: BucketAccumulator) -> None:
        stats = accumulator.stats
        assert stats["pending_events"] == 0
        assert stats["distinct_buckets"] == 0
        assert stats["rejected_future"] == 0
        assert stats["late_events"] == 0

    def test_stats_after_events(self, accumulator: BucketAccumulator) -> None:
        ts = datetime(2025, 6, 15, 10, 5, 0, tzinfo=UTC)
        accumulator.add_event(make_crossing_event(timestamp_utc=ts))
        accumulator.add_event(make_crossing_event(timestamp_utc=ts, class12=VehicleClass12.C02_BUS))

        stats = accumulator.stats
        assert stats["pending_events"] == 2
        assert stats["distinct_buckets"] == 2

    def test_bucket_count_property(self, accumulator: BucketAccumulator) -> None:
        ts = datetime(2025, 6, 15, 10, 5, 0, tzinfo=UTC)
        accumulator.add_event(make_crossing_event(timestamp_utc=ts))
        assert accumulator.bucket_count == 1

        accumulator.add_event(make_crossing_event(timestamp_utc=ts, direction="outbound"))
        assert accumulator.bucket_count == 2
