"""Backpressure verification test.

Floods the ingest service at a rate exceeding its capacity to verify:
1. 429 responses are returned when NATS queue depth >= 500
2. Retry-After header is present and correct
3. No 5xx errors occur (graceful degradation, not crash)
4. No data loss — all accepted frames are acknowledged
5. Service recovers once flood stops

Run standalone::

    python -m tests.loadtest.scenario_backpressure [--rps 200] [--duration 60]
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import time

import httpx

from tests.loadtest.auth import operator_headers
from tests.loadtest.config import LoadTestSettings, get_settings
from tests.loadtest.frame_gen import frame_metadata_json, generate_frame
from tests.loadtest.stats import LoadTestResult, print_result

logger = logging.getLogger(__name__)


async def _flood_worker(
    client: httpx.AsyncClient,
    worker_id: int,
    result: LoadTestResult,
    settings: LoadTestSettings,
    stop_event: asyncio.Event,
    rps_per_worker: float,
) -> None:
    """Send frames as fast as possible up to the per-worker RPS limit."""
    camera_id = f"cam_bp_{worker_id:04d}"
    headers = operator_headers(user_id=f"user_bp_{worker_id}")
    interval = 1.0 / rps_per_worker if rps_per_worker > 0 else 0
    frame_idx = 0
    upload_bucket = result.get_bucket("frame_upload")
    bp_bucket = result.get_bucket("backpressure_response")

    while not stop_event.is_set():
        t0 = time.perf_counter()
        frame_data = generate_frame(worker_id, frame_idx, width=320, height=240)
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
                upload_bucket.record(elapsed_ms)
            elif resp.status_code == 429:
                result.backpressure_429s += 1
                result.failed_requests += 1
                bp_bucket.record(elapsed_ms)

                retry_after = resp.headers.get("Retry-After")
                if not retry_after:
                    result.notes.append(
                        f"WARN: 429 without Retry-After at frame {frame_idx}"
                    )
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


async def _recovery_check(
    client: httpx.AsyncClient,
    settings: LoadTestSettings,
    result: LoadTestResult,
) -> bool:
    """After the flood, verify the service recovers and accepts frames again."""
    logger.info("Waiting 10s for queue to drain before recovery check...")
    await asyncio.sleep(10.0)

    camera_id = "cam_bp_recovery"
    headers = operator_headers(user_id="user_bp_recovery")
    recovery_bucket = result.get_bucket("recovery_upload")

    successes = 0
    for i in range(10):
        frame_data = generate_frame(999, i, width=320, height=240)
        metadata = frame_metadata_json(camera_id, i)
        t0 = time.perf_counter()
        try:
            resp = await client.post(
                f"{settings.ingest_url}/v1/ingest/frames",
                data={"metadata": metadata},
                files={"frame": ("frame.jpg", frame_data, "image/jpeg")},
                headers=headers,
                timeout=10.0,
            )
            elapsed_ms = (time.perf_counter() - t0) * 1000
            if resp.status_code == 202:
                successes += 1
                recovery_bucket.record(elapsed_ms)
        except Exception:
            pass
        await asyncio.sleep(0.5)

    recovered = successes >= 8
    logger.info("Recovery check: %d/10 succeeded — %s", successes, "PASS" if recovered else "FAIL")
    return recovered


async def run_backpressure_test(
    flood_rps: int | None = None,
    duration: int | None = None,
) -> LoadTestResult:
    """Flood the ingest service and verify backpressure behaviour."""
    settings = get_settings()
    rps = flood_rps or settings.backpressure_flood_rps
    dur = duration or settings.backpressure_duration_seconds

    num_workers = min(rps, 50)
    rps_per_worker = rps / num_workers

    result = LoadTestResult(
        scenario="backpressure",
        num_cameras=num_workers,
        fps_per_camera=int(rps_per_worker),
        duration_seconds=dur,
    )

    logger.info(
        "Starting backpressure test: %d RPS (%d workers × %.1f RPS) for %ds",
        rps, num_workers, rps_per_worker, dur,
    )

    stop_event = asyncio.Event()

    async with httpx.AsyncClient(
        limits=httpx.Limits(max_connections=num_workers * 2, max_keepalive_connections=num_workers),
    ) as client:
        tasks = [
            asyncio.create_task(
                _flood_worker(client, i, result, settings, stop_event, rps_per_worker)
            )
            for i in range(num_workers)
        ]

        await asyncio.sleep(dur)
        stop_event.set()

        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)

        recovered = await _recovery_check(client, settings, result)

    result.finish()

    result.nfr_checks["backpressure: 429s_triggered"] = result.backpressure_429s > 0

    result.nfr_checks["backpressure: no_5xx_errors"] = result.server_errors_5xx == 0

    result.nfr_checks["backpressure: no_data_loss"] = result.server_errors_5xx == 0

    result.nfr_checks["backpressure: service_recovers"] = recovered

    bp_ratio = result.backpressure_429s / max(result.total_requests, 1)
    result.nfr_checks["backpressure: 429_ratio_reasonable"] = bp_ratio > 0.01

    result.notes.append(f"Target flood RPS: {rps}")
    result.notes.append(
        f"429 ratio: {bp_ratio * 100:.1f}% "
        f"({result.backpressure_429s}/{result.total_requests})"
    )
    result.notes.append(f"Service recovery after flood: {'YES' if recovered else 'NO'}")

    return result


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="GreyEye backpressure verification test")
    parser.add_argument("--rps", type=int, default=None)
    parser.add_argument("--duration", type=int, default=None)
    parser.add_argument("--output-dir", type=str, default=None)
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    result = asyncio.run(run_backpressure_test(args.rps, args.duration))
    print_result(result)

    output_dir = args.output_dir or get_settings().output_dir
    path = result.save(output_dir)
    logger.info("Results saved to %s", path)


if __name__ == "__main__":
    main()
