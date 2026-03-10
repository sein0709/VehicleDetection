"""Scale load test: 100 cameras @ 10 FPS for 5 minutes.

Validates HPA behaviour and system stability under 10x the MVP load.
Verifies graceful degradation, backpressure, and no data loss.

Run standalone::

    python -m tests.loadtest.scenario_scale [--cameras 100] [--fps 10] [--duration 300]
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import time
from datetime import UTC, datetime

import httpx

from tests.loadtest.auth import operator_headers
from tests.loadtest.config import LoadTestSettings, get_settings
from tests.loadtest.frame_gen import frame_metadata_json, generate_frame
from tests.loadtest.stats import LoadTestResult, print_result

logger = logging.getLogger(__name__)

_RAMP_UP_BATCH = 10
_RAMP_UP_INTERVAL = 5.0


async def _camera_producer(
    client: httpx.AsyncClient,
    camera_idx: int,
    result: LoadTestResult,
    settings: LoadTestSettings,
    stop_event: asyncio.Event,
    start_delay: float = 0.0,
) -> None:
    """Simulate a single camera with optional start delay for ramp-up."""
    if start_delay > 0:
        await asyncio.sleep(start_delay)

    camera_id = f"cam_scale_{camera_idx:04d}"
    headers = operator_headers(user_id=f"user_scale_{camera_idx}")
    interval = 1.0 / settings.scale_fps_per_camera
    frame_idx = 0
    upload_bucket = result.get_bucket("frame_upload")
    consecutive_429s = 0

    while not stop_event.is_set():
        t0 = time.perf_counter()
        frame_data = generate_frame(camera_idx, frame_idx, width=640, height=480)
        metadata = frame_metadata_json(camera_id, frame_idx)

        try:
            resp = await client.post(
                f"{settings.ingest_url}/v1/ingest/frames",
                data={"metadata": metadata},
                files={"frame": ("frame.jpg", frame_data, "image/jpeg")},
                headers=headers,
                timeout=15.0,
            )
            elapsed_ms = (time.perf_counter() - t0) * 1000
            result.total_requests += 1

            if resp.status_code == 202:
                result.successful_requests += 1
                upload_bucket.record(elapsed_ms)
                consecutive_429s = 0
            elif resp.status_code == 429:
                result.backpressure_429s += 1
                result.failed_requests += 1
                consecutive_429s += 1
                retry_after = float(resp.headers.get("Retry-After", "2"))
                backoff = min(retry_after * (1.5 ** min(consecutive_429s, 5)), 30.0)
                await asyncio.sleep(backoff)
                continue
            elif resp.status_code >= 500:
                result.server_errors_5xx += 1
                result.failed_requests += 1
            else:
                result.failed_requests += 1

        except httpx.TimeoutException:
            result.total_requests += 1
            result.failed_requests += 1
        except Exception:
            result.total_requests += 1
            result.failed_requests += 1

        frame_idx += 1
        elapsed = time.perf_counter() - t0
        sleep_time = max(0, interval - elapsed)
        if sleep_time > 0:
            await asyncio.sleep(sleep_time)


async def _monitor_throughput(
    result: LoadTestResult,
    stop_event: asyncio.Event,
) -> None:
    """Periodically log throughput during the test."""
    prev_count = 0
    while not stop_event.is_set():
        await asyncio.sleep(10.0)
        current = result.total_requests
        delta = current - prev_count
        rps = delta / 10.0
        logger.info(
            "Throughput: %.1f RPS | Total: %d | 429s: %d | 5xx: %d",
            rps, current, result.backpressure_429s, result.server_errors_5xx,
        )
        prev_count = current


async def run_scale_test(
    num_cameras: int | None = None,
    fps: int | None = None,
    duration: int | None = None,
) -> LoadTestResult:
    """Execute the 100-camera scale test with gradual ramp-up.

    Cameras are added in batches of 10 every 5 seconds to simulate
    realistic deployment scaling and observe HPA behaviour.
    """
    settings = get_settings()
    cameras = num_cameras or settings.scale_cameras
    fps_val = fps or settings.scale_fps_per_camera
    dur = duration or settings.scale_duration_seconds

    result = LoadTestResult(
        scenario="scale_100cam",
        num_cameras=cameras,
        fps_per_camera=fps_val,
        duration_seconds=dur,
    )

    logger.info(
        "Starting scale load test: %d cameras @ %d FPS for %ds (ramp-up: %d/batch)",
        cameras, fps_val, dur, _RAMP_UP_BATCH,
    )

    stop_event = asyncio.Event()

    async with httpx.AsyncClient(
        limits=httpx.Limits(
            max_connections=cameras * 2,
            max_keepalive_connections=cameras,
        ),
    ) as client:
        tasks: list[asyncio.Task] = []

        for i in range(cameras):
            batch_num = i // _RAMP_UP_BATCH
            delay = batch_num * _RAMP_UP_INTERVAL
            tasks.append(asyncio.create_task(
                _camera_producer(client, i, result, settings, stop_event, start_delay=delay)
            ))

        monitor = asyncio.create_task(_monitor_throughput(result, stop_event))
        tasks.append(monitor)

        ramp_up_time = (cameras // _RAMP_UP_BATCH) * _RAMP_UP_INTERVAL
        total_wait = ramp_up_time + dur
        logger.info("Ramp-up will take %.0fs, then sustaining for %ds", ramp_up_time, dur)

        await asyncio.sleep(total_wait)
        stop_event.set()

        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)

    result.finish()

    target_rps = cameras * fps_val
    upload_bucket = result.get_bucket("frame_upload")

    result.nfr_checks["scale: 100_cameras_sustained"] = (
        result.success_rate >= 0.80
    )

    result.nfr_checks["scale: upload_p95_under_3000ms"] = (
        upload_bucket.count > 0
        and upload_bucket.percentile(95) <= 3000
    )

    result.nfr_checks["scale: no_5xx_errors"] = result.server_errors_5xx == 0

    result.nfr_checks["scale: backpressure_under_20pct"] = (
        result.total_requests > 0
        and (result.backpressure_429s / result.total_requests) < 0.20
    )

    result.nfr_checks["scale: graceful_degradation"] = (
        result.server_errors_5xx == 0
        and result.success_rate >= 0.70
    )

    result.notes.append(f"Target RPS: {target_rps}, Achieved: {result.effective_rps:.1f}")
    result.notes.append(f"Ramp-up time: {ramp_up_time:.0f}s")
    result.notes.append(
        f"Backpressure ratio: "
        f"{result.backpressure_429s / max(result.total_requests, 1) * 100:.1f}%"
    )

    return result


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="GreyEye scale load test (100 cameras)")
    parser.add_argument("--cameras", type=int, default=None)
    parser.add_argument("--fps", type=int, default=None)
    parser.add_argument("--duration", type=int, default=None)
    parser.add_argument("--output-dir", type=str, default=None)
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    result = asyncio.run(run_scale_test(args.cameras, args.fps, args.duration))
    print_result(result)

    output_dir = args.output_dir or get_settings().output_dir
    path = result.save(output_dir)
    logger.info("Results saved to %s", path)


if __name__ == "__main__":
    main()
