"""Shared pytest fixtures and skip guards for runpod/ tests.

These tests are co-located with the service so they ship alongside it. The
runtime deps (ultralytics, supervision, easyocr, vertexai) are heavy and may
not be installed on every dev machine, so we skip intelligently instead of
erroring out on import.
"""
from __future__ import annotations

import importlib
import os
import sys
from pathlib import Path

import pytest

# ---------------------------------------------------------------------------
# Make the runpod/ package importable as top-level modules (config, pipeline…)
# ---------------------------------------------------------------------------
RUNPOD_DIR = Path(__file__).resolve().parent.parent
if str(RUNPOD_DIR) not in sys.path:
    sys.path.insert(0, str(RUNPOD_DIR))


# ---------------------------------------------------------------------------
# Skip guards — each heavy dep gets its own marker
# ---------------------------------------------------------------------------
def _has(module: str) -> bool:
    try:
        importlib.import_module(module)
        return True
    except Exception:
        return False


HAS_CV2 = _has("cv2")
HAS_NUMPY = _has("numpy")
HAS_ULTRALYTICS = _has("ultralytics")
HAS_SUPERVISION = _has("supervision")
HAS_FASTAPI = _has("fastapi")


requires_cv2 = pytest.mark.skipif(not HAS_CV2, reason="cv2 not installed")
requires_numpy = pytest.mark.skipif(not HAS_NUMPY, reason="numpy not installed")
requires_integration_stack = pytest.mark.skipif(
    not (HAS_ULTRALYTICS and HAS_SUPERVISION and HAS_CV2 and HAS_NUMPY),
    reason="integration stack (ultralytics + supervision + cv2) not installed",
)
requires_fastapi = pytest.mark.skipif(not HAS_FASTAPI, reason="fastapi not installed")


# ---------------------------------------------------------------------------
# Asset fixtures
# ---------------------------------------------------------------------------
VIDEO_DIR = Path("/Users/sein/Desktop/4-1서당사거리")
SAMPLE_VIDEO = VIDEO_DIR / "07.00.00-07.05.00[R][0@0][0].mp4"
MODEL_PATH = Path(__file__).resolve().parents[2] / "best.pt"


@pytest.fixture(scope="session")
def sample_video_path() -> Path:
    if not SAMPLE_VIDEO.exists():
        pytest.skip(f"Sample video not found at {SAMPLE_VIDEO}")
    return SAMPLE_VIDEO


@pytest.fixture(scope="session")
def rtdetr_weights_path() -> Path:
    if not MODEL_PATH.exists():
        pytest.skip(f"RT-DETR weights not found at {MODEL_PATH}")
    return MODEL_PATH


@pytest.fixture(scope="session")
def short_video(tmp_path_factory, sample_video_path: Path) -> Path:
    """Trim the sample video to ~MAX_TEST_SECONDS so CPU runs finish quickly.

    Set FULL_VIDEO=1 in the environment to skip trimming and run on the
    complete 5-min clip.
    """
    import cv2  # local import — session is skipped if cv2 missing via caller

    if os.environ.get("FULL_VIDEO") == "1":
        return sample_video_path

    max_seconds = float(os.environ.get("MAX_TEST_SECONDS", "30"))
    out_dir = tmp_path_factory.mktemp("clips")
    out_path = out_dir / "trimmed.mp4"

    cap = cv2.VideoCapture(str(sample_video_path))
    if not cap.isOpened():
        pytest.skip(f"Could not open {sample_video_path}")
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    max_frames = int(fps * max_seconds)

    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(str(out_path), fourcc, fps, (w, h))
    try:
        for _ in range(max_frames):
            ok, frame = cap.read()
            if not ok:
                break
            writer.write(frame)
    finally:
        writer.release()
        cap.release()

    if not out_path.exists() or out_path.stat().st_size == 0:
        pytest.skip("Failed to create trimmed test clip")
    return out_path


# ---------------------------------------------------------------------------
# Make sure the VLM pool never tries to hit Vertex during tests
# ---------------------------------------------------------------------------
@pytest.fixture(autouse=True)
def _no_live_vertex(monkeypatch):
    """Force the VLM circuit open for every test — the pipeline should
    degrade gracefully to pure CV. Individual tests that want to exercise
    VLM paths can re-patch `pool.is_available` themselves.
    """
    if not HAS_CV2:
        return
    try:
        from vlm import pool
    except Exception:
        return
    monkeypatch.setattr(pool, "_circuit_open", True, raising=False)
    monkeypatch.setattr(pool, "_model", None, raising=False)
