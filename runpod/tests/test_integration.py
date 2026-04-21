"""Full integration: real RT-DETR weights + real video decode.

These tests skip entirely unless ``ultralytics``, ``supervision``, ``cv2`` and
``numpy`` are all installed. Vertex AI is intentionally disabled (VLM circuit
forced open in conftest) so the tests verify the pipeline's CV-only graceful-
degradation path. A separate ``test_vlm_circuit_breaker`` confirms that
triggers don't fire when VLM is unavailable.

CPU runs are slow: the ``short_video`` fixture trims the 5-minute clip to
``MAX_TEST_SECONDS`` (default 30). Set ``FULL_VIDEO=1`` to run the complete clip.
"""
from __future__ import annotations

import json
import os
from pathlib import Path

import pytest

from conftest import (
    requires_fastapi,
    requires_integration_stack,
)

pytestmark = [pytest.mark.integration, requires_integration_stack]


# ---------------------------------------------------------------------------
# Shared: warm the RT-DETR model once per session so we don't reload per test.
# ---------------------------------------------------------------------------
@pytest.fixture(scope="module")
def warmed_pipeline(rtdetr_weights_path: Path, monkeypatch_module):
    """Loads the RT-DETR model once and leaves it cached in pipeline._model."""
    monkeypatch_module.setenv("RTDETR_WEIGHTS", str(rtdetr_weights_path))
    # Re-import config so the new env var wins
    import importlib

    import config as _config

    importlib.reload(_config)
    import pipeline as _pipeline

    importlib.reload(_pipeline)
    _pipeline.get_model()
    return _pipeline


@pytest.fixture(scope="module")
def monkeypatch_module():
    """Module-scoped monkeypatch — pytest's default is function-scoped."""
    from _pytest.monkeypatch import MonkeyPatch

    mp = MonkeyPatch()
    yield mp
    mp.undo()


# ===========================================================================
# End-to-end pipeline
# ===========================================================================
class TestPipelineOnRealVideo:
    def test_vehicles_only_default_calibration(self, warmed_pipeline, short_video):
        """The baseline: no calibration JSON, just Tasks 1/2/3 counting."""
        from calibration import parse_calibration

        cal = parse_calibration(None)
        report = warmed_pipeline.run_pipeline(str(short_video), cal)

        # Schema sanity — new structured shape
        assert "totals" in report
        assert "vehicle_breakdown" in report
        assert "counting" in report
        assert "meta" in report

        # New counting block shape (2026-04 refactor)
        counting = report["counting"]
        assert counting["method"] in ("tripwire", "intersection_polygon")
        assert isinstance(counting["unique_tracks_counted"], int)
        # unique_tracks_counted spans all categories (vehicles + non-vehicles);
        # totals breaks it down. Sum should match.
        assert counting["unique_tracks_counted"] == sum(report["totals"].values())
        assert "tripwire_crossings_in" in counting
        assert "tripwire_crossings_out" in counting

        # Legacy-compat aliases for the Flutter mobile app — REGRESSION GUARD
        # for the "1.7 billion vehicles" bug where finished_at leaked into the
        # flat-map breakdown fallback.
        assert "total_vehicles_counted" in report
        assert "breakdown" in report
        assert report["total_vehicles_counted"] == report["totals"]["vehicles"]
        assert report["breakdown"] == report["vehicle_breakdown"]
        assert isinstance(report["total_vehicles_counted"], int)
        assert report["total_vehicles_counted"] < 1_000_000, \
            f"Total {report['total_vehicles_counted']} suspiciously large — " \
            "likely a Unix-timestamp leak into vehicle counts"

        assert set(report["totals"].keys()) == {
            "vehicles", "pedestrians", "bicycles", "motorcycles", "personal_mobility"
        }
        for v in report["totals"].values():
            assert isinstance(v, int) and v >= 0

        # 2-wheeler breakdown is present (may be empty on clips without 2-wheelers).
        assert "two_wheeler_breakdown" in report
        assert isinstance(report["two_wheeler_breakdown"], dict)
        # All keys should map to known 2-wheeler class names.
        for k, v in report["two_wheeler_breakdown"].items():
            assert k in {"Bicycle", "Motorcycle", "Personal Mobility"}
            assert isinstance(v, int) and v > 0

        meta = report["meta"]
        assert meta["frames_sampled"] > 0
        assert meta["fps"] > 0
        assert meta["elapsed_s"] > 0

        # With VLM circuit open, no VLM-only sections should appear
        assert "speed" not in report
        assert "transit" not in report
        assert "traffic_light" not in report
        assert "plates" not in report
        assert "plate_summary" not in report

    def test_with_speed_calibration_emits_speed_block(
        self, warmed_pipeline, short_video
    ):
        import cv2

        from calibration import parse_calibration

        cap = cv2.VideoCapture(str(short_video))
        w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        cap.release()

        raw = json.dumps({
            "tasks_enabled": ["vehicles", "speed"],
            "speed": {
                # A believable trapezoid over the lower half of the frame.
                "source_quad": [
                    [w * 0.35, h * 0.45],
                    [w * 0.65, h * 0.45],
                    [w * 0.95, h * 0.95],
                    [w * 0.05, h * 0.95],
                ],
                "real_world_m": {"width": 3.5, "length": 20.0},
                "lines_y_ratio": [0.50, 0.85],
            },
        })
        cal = parse_calibration(raw)
        assert cal.speed is not None

        report = warmed_pipeline.run_pipeline(str(short_video), cal)
        assert "speed" in report
        speed = report["speed"]
        # Schema always present; measured count may be 0 on a short clip.
        assert "vehicles_measured" in speed
        assert "avg_kmh" in speed
        assert "per_track" in speed

    def test_with_traffic_light_roi_emits_timeline(
        self, warmed_pipeline, short_video
    ):
        import cv2

        from calibration import parse_calibration

        cap = cv2.VideoCapture(str(short_video))
        w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        cap.release()

        raw = json.dumps({
            "tasks_enabled": ["vehicles", "traffic_light"],
            # A small ROI in the upper-right — wherever the user's actual light
            # is doesn't matter for schema; HSV sampling just needs pixels.
            "traffic_light": {"roi": [int(w * 0.80), 0, 80, 80]},
        })
        cal = parse_calibration(raw)

        report = warmed_pipeline.run_pipeline(str(short_video), cal)
        assert "traffic_light" in report
        tl = report["traffic_light"]
        assert "cycles" in tl and set(tl["cycles"].keys()) == {"red", "green", "yellow"}
        assert "timeline" in tl
        # Timeline must have at least one span since we sampled frames.
        assert len(tl["timeline"]) >= 1

    def test_transit_block_schema(self, warmed_pipeline, short_video):
        import cv2

        from calibration import parse_calibration

        cap = cv2.VideoCapture(str(short_video))
        w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        cap.release()

        raw = json.dumps({
            "tasks_enabled": ["pedestrians", "transit"],
            "transit": {
                "stop_polygon": [
                    [w * 0.10, h * 0.60],
                    [w * 0.40, h * 0.60],
                    [w * 0.40, h * 0.95],
                    [w * 0.10, h * 0.95],
                ],
                "max_capacity": 30,
                "doors": [],
            },
        })
        cal = parse_calibration(raw)

        report = warmed_pipeline.run_pipeline(str(short_video), cal)
        assert "transit" in report
        t = report["transit"]
        for k in ("peak_count", "avg_density_pct", "boarding", "alighting", "samples"):
            assert k in t


# ===========================================================================
# Graceful degradation without Vertex
# ===========================================================================
class TestVlmCircuitBreaker:
    def test_circuit_open_still_produces_counts(
        self, warmed_pipeline, short_video
    ):
        """With the VLM pool unavailable (default in tests), the pipeline must
        still finish, produce counts, and include no VLM-only sections. This
        is the key safety property: a Vertex outage must not break the pod."""
        from calibration import parse_calibration
        from vlm import pool

        assert not pool.is_available(), "autouse fixture should keep circuit open"

        report = warmed_pipeline.run_pipeline(
            str(short_video), parse_calibration(None)
        )
        assert report["totals"]["vehicles"] >= 0
        assert report["meta"]["frames_sampled"] > 0


# ===========================================================================
# FastAPI upload / status lifecycle
# ===========================================================================
@requires_fastapi
class TestFastAPI:
    def test_upload_and_poll(self, warmed_pipeline, short_video, tmp_path):
        """Full HTTP round trip: POST /analyze_video → poll /status until done.

        TestClient's context-manager form drives the FastAPI lifespan for us,
        so the VLM pool gets started/stopped cleanly around the request.
        """
        import time

        from fastapi.testclient import TestClient

        import server as _server

        with TestClient(_server.app) as client:
            with open(short_video, "rb") as fh:
                resp = client.post(
                    "/analyze_video",
                    files={"file": ("clip.mp4", fh, "video/mp4")},
                    data={"calibration": json.dumps({"tasks_enabled": ["vehicles"]})},
                )
            assert resp.status_code == 200
            body = resp.json()
            assert body["status"] == "processing"
            job_id = body["job_id"]

            # Poll — generous timeout for CPU-only integration runs
            deadline = time.time() + 600
            final = None
            while time.time() < deadline:
                status_resp = client.get(f"/status/{job_id}")
                assert status_resp.status_code == 200
                final = status_resp.json()
                if final.get("status") in ("success", "error"):
                    break
                time.sleep(2)

            assert final is not None
            assert final["status"] == "success", final
            assert "totals" in final
            assert "meta" in final

            # Legacy keys present for mobile-app compatibility.
            assert "total_vehicles_counted" in final
            assert "breakdown" in final
            assert isinstance(final["total_vehicles_counted"], int)
            assert final["total_vehicles_counted"] < 1_000_000

            # finished_at lives in meta only — never at top level — so the
            # mobile app's flat-map fallback can never grab it as a count.
            assert "finished_at" not in final
            assert "_finished_at" not in final
            assert isinstance(final["meta"].get("finished_at"), (int, float))

    def test_status_404_for_unknown_job(self):
        from fastapi.testclient import TestClient

        import server as _server

        client = TestClient(_server.app)
        resp = client.get("/status/does-not-exist")
        assert resp.status_code == 404

    def test_healthz(self):
        from fastapi.testclient import TestClient

        import server as _server

        client = TestClient(_server.app)
        resp = client.get("/healthz")
        assert resp.status_code == 200
        assert resp.json() == {"status": "ok"}
