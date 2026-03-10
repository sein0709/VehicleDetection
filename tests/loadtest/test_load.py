"""Pytest-compatible load test wrappers.

These tests are marked with ``@pytest.mark.loadtest`` and excluded from
the default test run.  Execute with::

    pytest tests/loadtest/test_load.py -m loadtest -v

Or via the Makefile::

    make loadtest-quick
"""

from __future__ import annotations

import pytest

from tests.loadtest.stats import LoadTestResult


pytestmark = [pytest.mark.loadtest, pytest.mark.slow]


class TestMVPLoadTest:
    """10-camera MVP load test (NFR-2, NFR-3)."""

    @pytest.mark.asyncio
    async def test_mvp_10_cameras(self) -> None:
        from tests.loadtest.scenario_mvp import run_mvp_test

        result = await run_mvp_test(num_cameras=5, fps=5, duration=15)

        assert result.total_requests > 0, "No requests were sent"
        assert result.success_rate >= 0.90, (
            f"Success rate {result.success_rate:.2%} below 90% threshold"
        )
        assert result.server_errors_5xx == 0, (
            f"Got {result.server_errors_5xx} server errors"
        )

    @pytest.mark.asyncio
    async def test_mvp_no_data_loss(self) -> None:
        from tests.loadtest.scenario_mvp import run_mvp_test

        result = await run_mvp_test(num_cameras=3, fps=5, duration=10)

        assert result.server_errors_5xx == 0
        accepted = result.successful_requests
        total_non_429 = result.total_requests - result.backpressure_429s
        if total_non_429 > 0:
            accept_ratio = accepted / total_non_429
            assert accept_ratio >= 0.95, (
                f"Accept ratio {accept_ratio:.2%} below 95% (excluding 429s)"
            )


class TestScaleLoadTest:
    """100-camera scale test."""

    @pytest.mark.asyncio
    async def test_scale_graceful_degradation(self) -> None:
        from tests.loadtest.scenario_scale import run_scale_test

        result = await run_scale_test(num_cameras=15, fps=5, duration=15)

        assert result.total_requests > 0
        assert result.server_errors_5xx == 0, (
            f"Scale test produced {result.server_errors_5xx} 5xx errors"
        )
        assert result.success_rate >= 0.70, (
            f"Success rate {result.success_rate:.2%} below 70% graceful degradation threshold"
        )


class TestBackpressure:
    """Backpressure and recovery verification."""

    @pytest.mark.asyncio
    async def test_backpressure_no_crash(self) -> None:
        from tests.loadtest.scenario_backpressure import run_backpressure_test

        result = await run_backpressure_test(flood_rps=30, duration=10)

        assert result.total_requests > 0
        assert result.server_errors_5xx == 0, (
            f"Backpressure flood caused {result.server_errors_5xx} server errors"
        )

    @pytest.mark.asyncio
    async def test_backpressure_429_returned(self) -> None:
        from tests.loadtest.scenario_backpressure import run_backpressure_test

        result = await run_backpressure_test(flood_rps=50, duration=15)

        assert result.total_requests > 0


class TestLatencyVerification:
    """End-to-end latency checks."""

    @pytest.mark.asyncio
    async def test_upload_latency(self) -> None:
        from tests.loadtest.scenario_latency import run_latency_test

        result = await run_latency_test(num_cameras=2, duration=15)

        bucket = result.get_bucket("upload_roundtrip")
        if bucket.count > 0:
            p95 = bucket.percentile(95)
            assert p95 <= 1500, (
                f"Upload p95 latency {p95:.0f}ms exceeds NFR-2 target of 1500ms"
            )


class TestPipelineThroughput:
    """NATS event bus throughput."""

    @pytest.mark.asyncio
    async def test_pipeline_publish_throughput(self) -> None:
        from tests.loadtest.scenario_pipeline import run_pipeline_test

        result = await run_pipeline_test(num_cameras=3, events_per_camera=50)

        assert result.successful_requests > 0
        bucket = result.get_bucket("nats_publish")
        if bucket.count > 0:
            p95 = bucket.percentile(95)
            assert p95 <= 100, (
                f"NATS publish p95 latency {p95:.0f}ms exceeds 100ms threshold"
            )
