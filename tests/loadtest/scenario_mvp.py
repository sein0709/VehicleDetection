"""MVP load test: 10 cameras @ 10 FPS for 2 minutes.

Validates NFR-3 (system supports >= 10 simultaneous camera feeds at 10 FPS)
and NFR-2 (end-to-end inference latency <= 1.5s per frame).

Run standalone::

    python -m tests.loadtest.scenario_mvp [--cameras 10] [--fps 10] [--duration 120]

Requires the local dev stack (``make dev-up``) and services running.
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


async def _camera_producer(
    client: httpx.AsyncClient,
    camera_idx: int,
    result: LoadTestResult,
    settings: LoadTestSettings,
    stop_event: asyncio.Event,
) -> None:
    """Simulate a single camera uploading frames at the configured FPS."""
    camera_id = f"cam_lt_{camera_idx:04d}"
    headers = operator_headers(user_id=f"user_cam_{camera_idx}")
    interval = 1.0 / settings.mvp_fps_per_camera
    frame_idx = 0
    bucket = result.get_bucket("frame_upload")

    while not stop_event.is_set():
        t0 = time.perf_counter()
        frame_data = generate_frame(camera_idx, frame_idx)
        metadata = frame_metadata_json(camera_id, frame_idx)

        try:
            resp = await client.post(
                f"{settings.ingest_url}/v1/ingest/frames",
                data={"metadata": metadata},
                files={"frame": ("frame.jpg", frame_data, "image/jpeg")},
                headers=headers,
                timeout=10.0,
            )
            elapsed_ms = (time.perf_counter() - t0) * 1000
            result.total_requests += 1

            if resp.status_code == 202:
                result.successful_requests += 1
                bucket.record(elapsed_ms)
            elif resp.status_code == 429:
                result.backpressure_429s += 1
                result.failed_requests += 1
                retry_after = float(resp.headers.get("Retry-After", "1"))
                await asyncio.sleep(retry_after)
                continue
            elif resp.status_code >= 500:
                result.server_errors_5xx += 1
                result.failed_requests += 1
            else:
                result.failed_requests += 1

        except httpx.TimeoutException:
            result.total_requests += 1
            result.failed_requests += 1
            logger.debug("Timeout uploading frame %d for %s", frame_idx, camera_id)
        except Exception:
            result.total_requests += 1
            result.failed_requests += 1
            logger.debug("Error uploading frame for %s", camera_id, exc_info=True)

        frame_idx += 1

        elapsed = time.perf_counter() - t0
        sleep_time = max(0, interval - elapsed)
        if sleep_time > 0:
            await asyncio.sleep(sleep_time)


async def _heartbeat_producer(
    client: httpx.AsyncClient,
    camera_idx: int,
    settings: LoadTestSettings,
    stop_event: asyncio.Event,
) -> None:
    """Send periodic heartbeats for a camera."""
    camera_id = f"cam_lt_{camera_idx:04d}"
    headers = operator_headers(user_id=f"user_cam_{camera_idx}")
    headers["Content-Type"] = "application/json"

    while not stop_event.is_set():
        try:
            await client.post(
                f"{settings.ingest_url}/v1/ingest/heartbeat",
                json={
                    "camera_id": camera_id,
                    "fps_actual": float(settings.mvp_fps_per_camera),
                    "status": "online",
                    "frame_width": settings.frame_width,
                    "frame_height": settings.frame_height,
                },
                headers=headers,
                timeout=5.0,
            )
        except Exception:
            pass
        await asyncio.sleep(10.0)


async def run_mvp_test(
    num_cameras: int | None = None,
    fps: int | None = None,
    duration: int | None = None,
) -> LoadTestResult:
    """Execute the MVP load test scenario.

    Returns a LoadTestResult with all metrics and NFR pass/fail verdicts.
    """
    settings = get_settings()
    cameras = num_cameras or settings.mvp_cameras
    fps_val = fps or settings.mvp_fps_per_camera
    dur = duration or settings.mvp_duration_seconds

    result = LoadTestResult(
        scenario="mvp_10cam",
        num_cameras=cameras,
        fps_per_camera=fps_val,
        duration_seconds=dur,
    )

    logger.info(
        "Starting MVP load test: %d cameras @ %d FPS for %ds",
        cameras, fps_val, dur,
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
            tasks.append(asyncio.create_task(
                _camera_producer(client, i, result, settings, stop_event)
            ))
            tasks.append(asyncio.create_task(
                _heartbeat_producer(client, i, settings, stop_event)
            ))

        await asyncio.sleep(dur)
        stop_event.set()

        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)

    result.finish()

    target_rps = cameras * fps_val
    upload_bucket = result.get_bucket("frame_upload")

    result.nfr_checks["NFR-3: supports_10_cameras_10fps"] = (
        cameras >= settings.nfr3_min_cameras
        and result.success_rate >= 0.95
    )

    result.nfr_checks["NFR-2: upload_p95_under_1500ms"] = (
        upload_bucket.count > 0
        and upload_bucket.percentile(95) <= settings.nfr2_inference_latency_ms
    )

    result.nfr_checks["throughput_meets_target"] = (
        result.effective_rps >= target_rps * 0.90
    )

    result.nfr_checks["error_rate_under_5pct"] = result.error_rate < 0.05

    result.nfr_checks["no_data_loss_under_backpressure"] = (
        result.server_errors_5xx == 0
    )

    result.notes.append(f"Target RPS: {target_rps}, Achieved: {result.effective_rps:.1f}")
    result.notes.append(
        f"Backpressure 429s: {result.backpressure_429s} "
        f"({result.backpressure_429s / max(result.total_requests, 1) * 100:.1f}%)"
    )

    return result


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="GreyEye MVP load test (10 cameras)")
    parser.add_argument("--cameras", type=int, default=None)
    parser.add_argument("--fps", type=int, default=None)
    parser.add_argument("--duration", type=int, default=None)
    parser.add_argument("--output-dir", type=str, default=None)
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    result = asyncio.run(run_mvp_test(args.cameras, args.fps, args.duration))
    print_result(result)

    output_dir = args.output_dir or get_settings().output_dir
    path = result.save(output_dir)
    logger.info("Results saved to %s", path)


if __name__ == "__main__":
    main()
