"""In-memory accumulator that buffers crossing events into 15-minute buckets.

Implements the algorithm from Section 5.4 of the software design doc:
- Receive event → compute bucket_start → increment in-memory counter
- Flush triggers: 5s elapsed, bucket boundary crossed, buffer ≥ 1000 entries
- Late-arriving events are accepted (past buckets upserted); future timestamps rejected
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any, Literal, NamedTuple

from shared_contracts.events import VehicleCrossingEvent, compute_bucket_start

logger = logging.getLogger(__name__)

LATE_EVENT_LIVE_THRESHOLD = timedelta(hours=1)
FUTURE_TOLERANCE = timedelta(seconds=30)


class BucketKey(NamedTuple):
    camera_id: str
    line_id: str
    bucket_start: datetime
    class12: int
    direction: str


@dataclass
class _BucketState:
    org_id: str
    count: int = 0
    sum_confidence: float = 0.0
    sum_speed_kmh: float = 0.0
    min_speed_kmh: float | None = None
    max_speed_kmh: float | None = None


class AddEventResult(NamedTuple):
    status: Literal["accepted", "rejected_future"]
    bucket_start: datetime | None
    is_late: bool


@dataclass
class BucketAccumulator:
    """Collects crossing events and flushes aggregated rows periodically.

    Flush triggers (any one is sufficient):
    1. ``flush_interval_seconds`` elapsed since last flush
    2. A bucket boundary is crossed (events span multiple 15-min windows)
    3. Buffer exceeds ``max_buffer_size`` entries
    """

    flush_interval_seconds: float = 5.0
    max_buffer_size: int = 1000

    _buckets: dict[BucketKey, _BucketState] = field(default_factory=dict, init=False, repr=False)
    _event_count: int = field(default=0, init=False, repr=False)
    _last_flush_time: float = field(default_factory=time.monotonic, init=False, repr=False)
    _last_bucket_start: datetime | None = field(default=None, init=False, repr=False)
    _rejected_future_count: int = field(default=0, init=False, repr=False)
    _late_event_count: int = field(default=0, init=False, repr=False)

    def add_event(self, event: VehicleCrossingEvent) -> AddEventResult:
        """Add a crossing event to the accumulator.

        Returns an AddEventResult indicating whether the event was accepted
        and whether it was a late arrival.

        Future timestamps (beyond a small tolerance) are rejected per Section 5.5.
        """
        now_utc = datetime.now(UTC)
        if event.timestamp_utc > now_utc + FUTURE_TOLERANCE:
            self._rejected_future_count += 1
            logger.warning(
                "Rejected future event: camera=%s ts=%s (now=%s)",
                event.camera_id,
                event.timestamp_utc.isoformat(),
                now_utc.isoformat(),
            )
            return AddEventResult(status="rejected_future", bucket_start=None, is_late=False)

        bucket_start = compute_bucket_start(event.timestamp_utc)
        current_bucket = compute_bucket_start(now_utc)
        is_late = bucket_start < current_bucket

        if is_late:
            self._late_event_count += 1

        key = BucketKey(
            camera_id=event.camera_id,
            line_id=event.line_id,
            bucket_start=bucket_start,
            class12=int(event.class12),
            direction=event.direction,
        )

        state = self._buckets.get(key)
        if state is None:
            state = _BucketState(org_id=event.org_id)
            self._buckets[key] = state

        state.count += 1
        state.sum_confidence += event.confidence

        speed = event.speed_estimate_kmh
        if speed is not None:
            state.sum_speed_kmh += speed
            if state.min_speed_kmh is None or speed < state.min_speed_kmh:
                state.min_speed_kmh = speed
            if state.max_speed_kmh is None or speed > state.max_speed_kmh:
                state.max_speed_kmh = speed

        self._event_count += 1

        if self._last_bucket_start is not None and bucket_start != self._last_bucket_start:
            pass  # boundary crossed — should_flush will return True
        self._last_bucket_start = bucket_start

        return AddEventResult(status="accepted", bucket_start=bucket_start, is_late=is_late)

    def should_flush(self) -> bool:
        if self._event_count == 0:
            return False
        if self._event_count >= self.max_buffer_size:
            return True
        if (time.monotonic() - self._last_flush_time) >= self.flush_interval_seconds:
            return True
        bucket_starts = {k.bucket_start for k in self._buckets}
        return len(bucket_starts) > 1

    def flush(self) -> list[dict[str, Any]]:
        """Drain all accumulated buckets and return rows suitable for batch_upsert."""
        rows: list[dict[str, Any]] = []
        for key, state in self._buckets.items():
            has_speed = state.min_speed_kmh is not None
            rows.append(
                {
                    "org_id": state.org_id,
                    "camera_id": key.camera_id,
                    "line_id": key.line_id,
                    "bucket_start": key.bucket_start,
                    "class12": key.class12,
                    "direction": key.direction,
                    "count": state.count,
                    "sum_confidence": state.sum_confidence,
                    "sum_speed_kmh": state.sum_speed_kmh if has_speed else None,
                    "min_speed_kmh": state.min_speed_kmh,
                    "max_speed_kmh": state.max_speed_kmh,
                }
            )

        self._buckets.clear()
        self._event_count = 0
        self._last_flush_time = time.monotonic()
        self._last_bucket_start = None
        return rows

    def flush_late_only(self) -> list[dict[str, Any]]:
        """Flush only buckets for past 15-min windows, keeping the current bucket.

        Useful for ensuring completed buckets are persisted while the current
        bucket continues accumulating.
        """
        now_utc = datetime.now(UTC)
        current_bucket = compute_bucket_start(now_utc)

        late_rows: list[dict[str, Any]] = []
        late_keys: list[BucketKey] = []

        for key, state in self._buckets.items():
            if key.bucket_start < current_bucket:
                has_speed = state.min_speed_kmh is not None
                late_rows.append(
                    {
                        "org_id": state.org_id,
                        "camera_id": key.camera_id,
                        "line_id": key.line_id,
                        "bucket_start": key.bucket_start,
                        "class12": key.class12,
                        "direction": key.direction,
                        "count": state.count,
                        "sum_confidence": state.sum_confidence,
                        "sum_speed_kmh": state.sum_speed_kmh if has_speed else None,
                        "min_speed_kmh": state.min_speed_kmh,
                        "max_speed_kmh": state.max_speed_kmh,
                    }
                )
                late_keys.append(key)

        for key in late_keys:
            del self._buckets[key]
            self._event_count = max(0, self._event_count - 1)

        if late_rows:
            self._last_flush_time = time.monotonic()

        return late_rows

    @property
    def pending_count(self) -> int:
        return self._event_count

    @property
    def bucket_count(self) -> int:
        return len(self._buckets)

    @property
    def stats(self) -> dict[str, Any]:
        return {
            "pending_events": self._event_count,
            "distinct_buckets": len(self._buckets),
            "rejected_future": self._rejected_future_count,
            "late_events": self._late_event_count,
        }
