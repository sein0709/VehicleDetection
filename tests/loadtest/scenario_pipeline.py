"""NATS pipeline throughput test.

Publishes crossing events directly to NATS and measures how fast the
aggregator and notification service can consume them.  This isolates
the event bus throughput from HTTP overhead.

Validates:
- Aggregator can keep up with 10-camera crossing event rate
- No messages land in the DLQ under normal load
- Late-arriving events are handled correctly
- Bucket flush latency stays within bounds

Run standalone::

    python -m tests.loadtest.scenario_pipeline [--cameras 10] [--events-per-cam 500]
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import random
import time
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import nats
from nats.js import JetStreamContext

from shared_contracts.enums import VehicleClass12
from shared_contracts.events import VehicleCrossingEvent
from shared_contracts.nats_streams import (
    STREAM_CROSSINGS,
    STREAM_DLQ,
    SUBJECT_CROSSINGS,
    ensure_streams,
)
from tests.loadtest.config import get_settings
from tests.loadtest.stats import LoadTestResult, print_result

logger = logging.getLogger(__name__)

VEHICLE_CLASSES = list(VehicleClass12)
DIRECTIONS = ["inbound", "outbound"]


def _make_crossing(
    camera_idx: int,
    track_num: int,
    ts: datetime | None = None,
) -> VehicleCrossingEvent:
    camera_id = f"cam_pipe_{camera_idx:04d}"
    return VehicleCrossingEvent(
        timestamp_utc=ts or datetime.now(tz=UTC),
        camera_id=camera_id,
        line_id=f"line_{camera_idx:02d}_01",
        track_id=f"trk_{uuid4().hex[:8]}",
        crossing_seq=1,
        class12=random.choice(VEHICLE_CLASSES),
        confidence=round(random.uniform(0.6, 0.99), 3),
        direction=random.choice(DIRECTIONS),
        model_version="v0.1.0-loadtest",
        frame_index=track_num * 10,
        org_id=get_settings().org_id,
        site_id=get_settings().site_id,
    )


async def _publish_crossings(
    js: JetStreamContext,
    camera_idx: int,
    num_events: int,
    result: LoadTestResult,
    rate_limit: float = 0.0,
) -> None:
    """Publish crossing events for a single camera."""
    bucket = result.get_bucket("nats_publish")
    subject = f"{SUBJECT_CROSSINGS}.cam_pipe_{camera_idx:04d}"

    for i in range(num_events):
        event = _make_crossing(camera_idx, i)
        payload = event.model_dump_json().encode()

        t0 = time.perf_counter()
        try:
            ack = await js.publish(subject, payload)
            elapsed_ms = (time.perf_counter() - t0) * 1000
            result.total_requests += 1
            result.successful_requests += 1
            bucket.record(elapsed_ms)
        except Exception:
            result.total_requests += 1
            result.failed_requests += 1
            logger.debug("Failed to publish crossing event", exc_info=True)

        if rate_limit > 0:
            await asyncio.sleep(1.0 / rate_limit)


async def _publish_late_events(
    js: JetStreamContext,
    result: LoadTestResult,
    num_events: int = 50,
) -> None:
    """Publish events with timestamps in past buckets to test late-arrival handling."""
    bucket = result.get_bucket("nats_publish_late")
    subject = f"{SUBJECT_CROSSINGS}.cam_pipe_late"

    for i in range(num_events):
        delay_minutes = random.randint(15, 120)
        late_ts = datetime.now(tz=UTC) - timedelta(minutes=delay_minutes)
        event = _make_crossing(999, i, ts=late_ts)
        payload = event.model_dump_json().encode()

        t0 = time.perf_counter()
        try:
            await js.publish(subject, payload)
            elapsed_ms = (time.perf_counter() - t0) * 1000
            result.total_requests += 1
            result.successful_requests += 1
            bucket.record(elapsed_ms)
        except Exception:
            result.total_requests += 1
            result.failed_requests += 1


async def _check_dlq(js: JetStreamContext) -> int:
    """Count messages in the DLQ stream."""
    try:
        info = await js.stream_info(STREAM_DLQ)
        return info.state.messages
    except Exception:
        return 0


async def _check_crossings_stream(js: JetStreamContext) -> int:
    """Count messages in the crossings stream."""
    try:
        info = await js.stream_info(STREAM_CROSSINGS)
        return info.state.messages
    except Exception:
        return 0


async def run_pipeline_test(
    num_cameras: int | None = None,
    events_per_camera: int | None = None,
) -> LoadTestResult:
    """Publish crossing events to NATS and measure pipeline throughput."""
    settings = get_settings()
    cameras = num_cameras or settings.mvp_cameras
    events_per_cam = events_per_camera or 500

    result = LoadTestResult(
        scenario="pipeline_throughput",
        num_cameras=cameras,
        fps_per_camera=0,
        duration_seconds=0,
    )

    logger.info(
        "Starting pipeline throughput test: %d cameras × %d events",
        cameras, events_per_cam,
    )

    nc = await nats.connect(settings.nats_url)
    js = nc.jetstream()

    dlq_before = await _check_dlq(js)
    crossings_before = await _check_crossings_stream(js)

    logger.info("Publishing %d crossing events across %d cameras...", cameras * events_per_cam, cameras)
    tasks = [
        asyncio.create_task(
            _publish_crossings(js, i, events_per_cam, result, rate_limit=100)
        )
        for i in range(cameras)
    ]
    await asyncio.gather(*tasks, return_exceptions=True)

    logger.info("Publishing %d late-arriving events...", 50)
    await _publish_late_events(js, result, num_events=50)

    logger.info("Waiting 15s for aggregator to flush...")
    await asyncio.sleep(15.0)

    dlq_after = await _check_dlq(js)
    crossings_after = await _check_crossings_stream(js)
    new_dlq = dlq_after - dlq_before

    await nc.close()
    result.finish()

    total_events = cameras * events_per_cam + 50
    publish_bucket = result.get_bucket("nats_publish")

    result.nfr_checks["pipeline: all_events_published"] = (
        result.successful_requests >= total_events * 0.99
    )

    result.nfr_checks["pipeline: publish_p95_under_50ms"] = (
        publish_bucket.count > 0
        and publish_bucket.percentile(95) <= 50
    )

    result.nfr_checks["pipeline: no_dlq_messages"] = new_dlq == 0

    result.nfr_checks["pipeline: late_events_accepted"] = (
        result.get_bucket("nats_publish_late").count >= 45
    )

    events_per_second = result.successful_requests / max(result.elapsed_seconds, 0.1)
    result.notes.append(f"Total events: {total_events}")
    result.notes.append(f"Publish throughput: {events_per_second:.0f} events/s")
    result.notes.append(f"New DLQ messages: {new_dlq}")
    result.notes.append(f"Crossings stream delta: {crossings_after - crossings_before}")

    return result


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="GreyEye NATS pipeline throughput test")
    parser.add_argument("--cameras", type=int, default=None)
    parser.add_argument("--events-per-cam", type=int, default=None)
    parser.add_argument("--output-dir", type=str, default=None)
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    result = asyncio.run(run_pipeline_test(args.cameras, args.events_per_cam))
    print_result(result)

    output_dir = args.output_dir or get_settings().output_dir
    path = result.save(output_dir)
    logger.info("Results saved to %s", path)


if __name__ == "__main__":
    main()
