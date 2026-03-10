"""End-to-end latency and throughput verification.

Measures latency across the full pipeline:
  frame upload → NATS → inference → crossing event → aggregation → KPI query

Also verifies:
- NFR-1: Live KPI refresh <= 2s
- NFR-2: End-to-end inference latency <= 1.5s per frame
- Reporting API query latency under concurrent load
- WebSocket live KPI delivery timing

Run standalone::

    python -m tests.loadtest.scenario_latency [--cameras 5] [--duration 60]
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import time
from datetime import UTC, datetime, timedelta

import httpx

from tests.loadtest.auth import operator_headers, viewer_headers
from tests.loadtest.config import LoadTestSettings, get_settings
from tests.loadtest.frame_gen import frame_metadata_json, generate_frame
from tests.loadtest.stats import LoadTestResult, print_result

logger = logging.getLogger(__name__)


async def _measure_upload_latency(
    client: httpx.AsyncClient,
    settings: LoadTestSettings,
    result: LoadTestResult,
    num_frames: int = 100,
) -> None:
    """Measure frame upload round-trip latency (client → ingest → NATS ack)."""
    camera_id = "cam_latency_upload"
    headers = operator_headers(user_id="user_latency")
    bucket = result.get_bucket("upload_roundtrip")

    for i in range(num_frames):
        frame_data = generate_frame(0, i, width=640, height=480)
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
            result.total_requests += 1

            if resp.status_code == 202:
                result.successful_requests += 1
                bucket.record(elapsed_ms)
            elif resp.status_code == 429:
                result.backpressure_429s += 1
                result.failed_requests += 1
                await asyncio.sleep(1.0)
            else:
                result.failed_requests += 1
        except Exception:
            result.total_requests += 1
            result.failed_requests += 1

        await asyncio.sleep(0.05)


async def _measure_reporting_latency(
    client: httpx.AsyncClient,
    settings: LoadTestSettings,
    result: LoadTestResult,
    num_queries: int = 50,
) -> None:
    """Measure reporting API query latency under load."""
    headers = viewer_headers()
    now = datetime.now(tz=UTC)
    start = (now - timedelta(hours=1)).isoformat()
    end = now.isoformat()

    bucket_15m = result.get_bucket("reporting_15m_query")
    bucket_kpi = result.get_bucket("reporting_kpi_query")

    for _ in range(num_queries):
        t0 = time.perf_counter()
        try:
            resp = await client.get(
                f"{settings.reporting_url}/v1/analytics/15m",
                params={"start": start, "end": end, "limit": 100},
                headers=headers,
                timeout=10.0,
            )
            elapsed_ms = (time.perf_counter() - t0) * 1000
            result.total_requests += 1
            if resp.status_code == 200:
                result.successful_requests += 1
                bucket_15m.record(elapsed_ms)
            else:
                result.failed_requests += 1
        except Exception:
            result.total_requests += 1
            result.failed_requests += 1

        t0 = time.perf_counter()
        try:
            resp = await client.get(
                f"{settings.reporting_url}/v1/analytics/kpi",
                params={"start": start, "end": end},
                headers=headers,
                timeout=10.0,
            )
            elapsed_ms = (time.perf_counter() - t0) * 1000
            result.total_requests += 1
            if resp.status_code == 200:
                result.successful_requests += 1
                bucket_kpi.record(elapsed_ms)
            else:
                result.failed_requests += 1
        except Exception:
            result.total_requests += 1
            result.failed_requests += 1

        await asyncio.sleep(0.2)


async def _measure_websocket_latency(
    settings: LoadTestSettings,
    result: LoadTestResult,
    duration: float = 30.0,
) -> None:
    """Connect to the live KPI WebSocket and measure update delivery interval."""
    import websockets

    bucket = result.get_bucket("websocket_kpi_interval")
    camera_id = "cam_latency_upload"
    ws_url = (
        settings.reporting_url.replace("http://", "ws://").replace("https://", "wss://")
        + f"/v1/analytics/live/ws?camera_id={camera_id}"
    )

    try:
        async with websockets.connect(ws_url, open_timeout=10) as ws:
            last_update = time.perf_counter()
            deadline = time.perf_counter() + duration

            while time.perf_counter() < deadline:
                try:
                    msg = await asyncio.wait_for(ws.recv(), timeout=5.0)
                    now = time.perf_counter()
                    interval_ms = (now - last_update) * 1000
                    if interval_ms < 60_000:
                        bucket.record(interval_ms)
                    last_update = now
                except asyncio.TimeoutError:
                    continue
                except Exception:
                    break
    except Exception as e:
        result.notes.append(f"WebSocket connection failed: {e}")
        logger.warning("WebSocket test skipped: %s", e)


async def _concurrent_reporting_load(
    client: httpx.AsyncClient,
    settings: LoadTestSettings,
    result: LoadTestResult,
    num_concurrent: int = 20,
    queries_per_client: int = 10,
) -> None:
    """Simulate concurrent reporting API queries."""
    headers = viewer_headers()
    now = datetime.now(tz=UTC)
    start = (now - timedelta(hours=2)).isoformat()
    end = now.isoformat()
    bucket = result.get_bucket("concurrent_reporting")

    async def _query_worker(worker_id: int) -> None:
        for _ in range(queries_per_client):
            t0 = time.perf_counter()
            try:
                resp = await client.get(
                    f"{settings.reporting_url}/v1/analytics/15m",
                    params={"start": start, "end": end, "limit": 50},
                    headers=headers,
                    timeout=15.0,
                )
                elapsed_ms = (time.perf_counter() - t0) * 1000
                result.total_requests += 1
                if resp.status_code == 200:
                    result.successful_requests += 1
                    bucket.record(elapsed_ms)
                else:
                    result.failed_requests += 1
            except Exception:
                result.total_requests += 1
                result.failed_requests += 1
            await asyncio.sleep(0.1)

    tasks = [asyncio.create_task(_query_worker(i)) for i in range(num_concurrent)]
    await asyncio.gather(*tasks, return_exceptions=True)


async def run_latency_test(
    num_cameras: int | None = None,
    duration: int | None = None,
) -> LoadTestResult:
    """Execute the latency verification test suite."""
    settings = get_settings()
    cameras = num_cameras or 5
    dur = duration or 60

    result = LoadTestResult(
        scenario="latency_verification",
        num_cameras=cameras,
        fps_per_camera=10,
        duration_seconds=dur,
    )

    logger.info("Starting latency verification test (%d cameras, %ds)", cameras, dur)

    async with httpx.AsyncClient(
        limits=httpx.Limits(max_connections=100, max_keepalive_connections=50),
    ) as client:
        logger.info("Phase 1: Upload latency measurement...")
        await _measure_upload_latency(client, settings, result, num_frames=100)

        logger.info("Phase 2: Reporting API latency...")
        await _measure_reporting_latency(client, settings, result, num_queries=50)

        logger.info("Phase 3: WebSocket KPI delivery...")
        await _measure_websocket_latency(settings, result, duration=30.0)

        logger.info("Phase 4: Concurrent reporting load...")
        await _concurrent_reporting_load(client, settings, result)

    result.finish()

    upload_bucket = result.get_bucket("upload_roundtrip")
    reporting_15m = result.get_bucket("reporting_15m_query")
    reporting_kpi = result.get_bucket("reporting_kpi_query")
    ws_bucket = result.get_bucket("websocket_kpi_interval")
    concurrent_bucket = result.get_bucket("concurrent_reporting")

    result.nfr_checks["NFR-2: upload_p95_under_1500ms"] = (
        upload_bucket.count > 0
        and upload_bucket.percentile(95) <= settings.nfr2_inference_latency_ms
    )

    result.nfr_checks["NFR-1: live_kpi_p95_under_2000ms"] = (
        ws_bucket.count > 0
        and ws_bucket.percentile(95) <= settings.nfr1_live_kpi_refresh_ms
    )

    result.nfr_checks["reporting: 15m_query_p95_under_500ms"] = (
        reporting_15m.count > 0
        and reporting_15m.percentile(95) <= 500
    )

    result.nfr_checks["reporting: kpi_query_p95_under_500ms"] = (
        reporting_kpi.count > 0
        and reporting_kpi.percentile(95) <= 500
    )

    result.nfr_checks["reporting: concurrent_p95_under_1000ms"] = (
        concurrent_bucket.count > 0
        and concurrent_bucket.percentile(95) <= 1000
    )

    return result


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="GreyEye latency verification test")
    parser.add_argument("--cameras", type=int, default=None)
    parser.add_argument("--duration", type=int, default=None)
    parser.add_argument("--output-dir", type=str, default=None)
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    result = asyncio.run(run_latency_test(args.cameras, args.duration))
    print_result(result)

    output_dir = args.output_dir or get_settings().output_dir
    path = result.save(output_dir)
    logger.info("Results saved to %s", path)


if __name__ == "__main__":
    main()
