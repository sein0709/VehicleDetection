"""Unified load test runner — executes all scenarios and produces a combined report.

Usage::

    # Run all scenarios
    python -m tests.loadtest.runner --all

    # Run specific scenarios
    python -m tests.loadtest.runner --mvp --backpressure

    # Quick smoke test (reduced durations)
    python -m tests.loadtest.runner --all --quick
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import sys
import time
from datetime import UTC, datetime
from pathlib import Path

from tests.loadtest.config import get_settings
from tests.loadtest.stats import LoadTestResult, print_result

logger = logging.getLogger(__name__)


async def _check_services() -> dict[str, bool]:
    """Verify that required services are reachable."""
    import httpx

    settings = get_settings()
    checks: dict[str, bool] = {}

    async with httpx.AsyncClient(timeout=5.0) as client:
        for name, url in [
            ("ingest", f"{settings.ingest_url}/healthz"),
            ("reporting", f"{settings.reporting_url}/healthz"),
        ]:
            try:
                resp = await client.get(url)
                checks[name] = resp.status_code == 200
            except Exception:
                checks[name] = False

    try:
        import nats

        nc = await nats.connect(settings.nats_url, connect_timeout=5)
        checks["nats"] = nc.is_connected
        await nc.close()
    except Exception:
        checks["nats"] = False

    return checks


def _print_service_status(checks: dict[str, bool]) -> bool:
    print("\nService Health Checks:")
    all_ok = True
    for name, ok in checks.items():
        status = "OK" if ok else "UNREACHABLE"
        symbol = "+" if ok else "!"
        print(f"  [{symbol}] {name}: {status}")
        if not ok:
            all_ok = False
    print()
    return all_ok


async def run_all(
    scenarios: list[str],
    quick: bool = False,
    output_dir: str | None = None,
) -> list[LoadTestResult]:
    """Run selected load test scenarios and return results."""
    settings = get_settings()
    out_dir = output_dir or settings.output_dir

    checks = await _check_services()
    all_ok = _print_service_status(checks)

    results: list[LoadTestResult] = []

    if "mvp" in scenarios:
        if not checks.get("ingest"):
            logger.warning("Skipping MVP test — ingest service unreachable")
        else:
            from tests.loadtest.scenario_mvp import run_mvp_test

            duration = 30 if quick else None
            cameras = 5 if quick else None
            result = await run_mvp_test(num_cameras=cameras, duration=duration)
            print_result(result)
            result.save(out_dir)
            results.append(result)

    if "scale" in scenarios:
        if not checks.get("ingest"):
            logger.warning("Skipping scale test — ingest service unreachable")
        else:
            from tests.loadtest.scenario_scale import run_scale_test

            duration = 60 if quick else None
            cameras = 20 if quick else None
            result = await run_scale_test(num_cameras=cameras, duration=duration)
            print_result(result)
            result.save(out_dir)
            results.append(result)

    if "backpressure" in scenarios:
        if not checks.get("ingest"):
            logger.warning("Skipping backpressure test — ingest service unreachable")
        else:
            from tests.loadtest.scenario_backpressure import run_backpressure_test

            duration = 20 if quick else None
            rps = 50 if quick else None
            result = await run_backpressure_test(flood_rps=rps, duration=duration)
            print_result(result)
            result.save(out_dir)
            results.append(result)

    if "latency" in scenarios:
        nats_ok = checks.get("nats", False)
        ingest_ok = checks.get("ingest", False)
        reporting_ok = checks.get("reporting", False)
        if not (ingest_ok or reporting_ok):
            logger.warning("Skipping latency test — services unreachable")
        else:
            from tests.loadtest.scenario_latency import run_latency_test

            duration = 30 if quick else None
            result = await run_latency_test(duration=duration)
            print_result(result)
            result.save(out_dir)
            results.append(result)

    if "pipeline" in scenarios:
        if not checks.get("nats"):
            logger.warning("Skipping pipeline test — NATS unreachable")
        else:
            from tests.loadtest.scenario_pipeline import run_pipeline_test

            events = 100 if quick else None
            cameras = 5 if quick else None
            result = await run_pipeline_test(num_cameras=cameras, events_per_camera=events)
            print_result(result)
            result.save(out_dir)
            results.append(result)

    return results


def _print_summary(results: list[LoadTestResult]) -> bool:
    """Print combined summary and return True if all NFR checks pass."""
    print(f"\n{'#'*72}")
    print(f"  COMBINED LOAD TEST SUMMARY")
    print(f"{'#'*72}")

    all_passed = True
    for result in results:
        d = result.to_dict()
        scenario_pass = all(d["nfr_checks"].values()) if d["nfr_checks"] else True
        status = "PASS" if scenario_pass else "FAIL"
        print(f"\n  [{status}] {d['scenario']}")
        print(f"         Requests: {d['total_requests']}  |  Success: {d['success_rate']*100:.1f}%"
              f"  |  RPS: {d['effective_rps']:.1f}")
        for check, passed in d["nfr_checks"].items():
            mark = "+" if passed else "!"
            print(f"         [{mark}] {check}")
        if not scenario_pass:
            all_passed = False

    overall = "ALL PASS" if all_passed else "SOME FAILURES"
    print(f"\n  Overall: {overall}")
    print(f"{'#'*72}\n")
    return all_passed


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="GreyEye unified load test runner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Scenarios:
  --mvp            10-camera MVP test (NFR-2, NFR-3)
  --scale          100-camera scale test (HPA, degradation)
  --backpressure   Flood test (429 verification, recovery)
  --latency        End-to-end latency measurement
  --pipeline       NATS event bus throughput
  --all            Run all scenarios
  --quick          Reduced durations for CI/smoke testing
""",
    )
    parser.add_argument("--mvp", action="store_true")
    parser.add_argument("--scale", action="store_true")
    parser.add_argument("--backpressure", action="store_true")
    parser.add_argument("--latency", action="store_true")
    parser.add_argument("--pipeline", action="store_true")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--quick", action="store_true", help="Reduced durations for CI")
    parser.add_argument("--output-dir", type=str, default=None)
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        datefmt="%H:%M:%S",
    )

    scenarios: list[str] = []
    if args.all:
        scenarios = ["mvp", "scale", "backpressure", "latency", "pipeline"]
    else:
        if args.mvp:
            scenarios.append("mvp")
        if args.scale:
            scenarios.append("scale")
        if args.backpressure:
            scenarios.append("backpressure")
        if args.latency:
            scenarios.append("latency")
        if args.pipeline:
            scenarios.append("pipeline")

    if not scenarios:
        parser.print_help()
        sys.exit(1)

    logger.info("Running scenarios: %s%s", ", ".join(scenarios), " (quick)" if args.quick else "")

    results = asyncio.run(run_all(scenarios, quick=args.quick, output_dir=args.output_dir))

    if not results:
        logger.warning("No tests were executed (services may be unreachable)")
        sys.exit(2)

    all_passed = _print_summary(results)

    combined = {
        "timestamp": datetime.now(tz=UTC).isoformat(),
        "scenarios": [r.to_dict() for r in results],
        "all_passed": all_passed,
    }
    out_dir = Path(args.output_dir or get_settings().output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    combined_path = out_dir / f"combined_{int(time.time())}.json"
    combined_path.write_text(json.dumps(combined, indent=2), encoding="utf-8")
    logger.info("Combined report: %s", combined_path)

    sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    main()
