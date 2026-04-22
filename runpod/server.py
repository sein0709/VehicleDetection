"""FastAPI entry point — MOLIT Traffic Analytics Engine.

Thin surface: upload endpoint kicks work onto a ThreadPoolExecutor (so the
event loop stays responsive under load), status endpoint polls the in-process
job store. Heavy lifting lives in ``pipeline.py``.
"""
from __future__ import annotations

import logging
import os
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse

from auto_calibration import autofill_calibration
from calibration import parse_calibration
from config import JOB_TTL_SECONDS, TEMP_DIR
from pipeline import get_model, run_pipeline
from vlm import pool as vlm_pool

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("server")

os.makedirs(TEMP_DIR, exist_ok=True)

jobs_db: dict[str, dict[str, Any]] = {}
_executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="pipeline")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Warm the RT-DETR weights + spin up the VLM worker pool.
    try:
        get_model()
    except Exception as exc:
        logger.error("RT-DETR load failed at startup: %s", exc)
    vlm_pool.start()
    yield
    vlm_pool.stop()
    _executor.shutdown(wait=False)


app = FastAPI(title="MOLIT Traffic Analytics Engine", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def _job_finished_at(job: dict[str, Any]) -> float | None:
    """Read finished_at from meta.finished_at (success) or top-level _finished_at
    (error path, where there is no meta block). Returns None if missing."""
    meta = job.get("meta")
    if isinstance(meta, dict) and isinstance(meta.get("finished_at"), (int, float)):
        return float(meta["finished_at"])
    val = job.get("_finished_at")
    return float(val) if isinstance(val, (int, float)) else None


def _reap_stale_jobs() -> None:
    now = time.time()
    stale = [
        jid for jid, job in jobs_db.items()
        if job.get("status") in ("success", "error")
        and (_job_finished_at(job) or now) and now - (_job_finished_at(job) or now) > JOB_TTL_SECONDS
    ]
    for jid in stale:
        jobs_db.pop(jid, None)


def _process(job_id: str, video_path: str, calibration_raw: str | None) -> None:
    try:
        cal = parse_calibration(calibration_raw)
        # Auto-calibration pre-pass: fills missing transit / traffic-light
        # geometry by asking the VLM about a single keyframe. No-op when
        # the operator already supplied geometry or VLM_AUTOCALIBRATE=0.
        cal = autofill_calibration(video_path, cal)
        report = run_pipeline(video_path, cal)
        # Stamp the finish time INSIDE meta — never at the top level. A stray
        # top-level numeric (epoch seconds) confuses any client that does a
        # flat-map scan for "class counts" and would render 1.7B vehicles.
        report.setdefault("meta", {})["finished_at"] = time.time()
        jobs_db[job_id] = {
            "status": "success",
            "job_id": job_id,
            **report,
        }
        logger.info("Job %s complete", job_id)
    except Exception as exc:
        logger.exception("Job %s failed", job_id)
        # Errors have no meta block; use an underscore-prefixed key the client
        # never reads as a class breakdown.
        jobs_db[job_id] = {
            "status": "error",
            "job_id": job_id,
            "message": str(exc),
            "_finished_at": time.time(),
        }
    finally:
        try:
            os.remove(video_path)
        except OSError:
            pass
        _reap_stale_jobs()


@app.get("/")
async def root_ping() -> dict[str, Any]:
    return {
        "status": "ONLINE",
        "vlm_available": vlm_pool.is_available(),
        "jobs_in_flight": sum(1 for j in jobs_db.values() if j.get("status") == "processing"),
    }


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/analyze_video")
async def analyze_video(
    file: UploadFile = File(...),
    calibration: str | None = Form(None),
) -> JSONResponse:
    job_id = str(uuid.uuid4())
    safe_name = (file.filename or "upload.mp4").replace("/", "_").replace("..", "_")
    video_path = os.path.join(TEMP_DIR, f"{job_id}_{safe_name}")

    # Persist upload synchronously — UploadFile's temp file disappears once
    # the response is sent (see upstream bug fix notes in the original main.py).
    contents = await file.read()
    with open(video_path, "wb") as f:
        f.write(contents)

    jobs_db[job_id] = {"status": "processing", "job_id": job_id}
    _executor.submit(_process, job_id, video_path, calibration)

    return JSONResponse(
        content={
            "job_id": job_id,
            "status": "processing",
            "bytes_received": len(contents),
        }
    )


@app.get("/status/{job_id}")
async def check_status(job_id: str) -> JSONResponse:
    job = jobs_db.get(job_id)
    if job is None:
        return JSONResponse(status_code=404, content={"error": "Job not found"})
    return JSONResponse(content=job)


# Stream the annotated MP4 for a finished job. Which variant is returned
# depends on the query parameter:
#   ?kind=classified   → class-annotated (bboxes + MOLIT labels)  [default]
#   ?kind=transit      → transit overlay (head circles + boarding colours)
# 404 if the job is unknown, still processing, or didn't request that output.
@app.get("/video/{job_id}")
async def get_video(job_id: str, kind: str = "classified") -> FileResponse:
    job = jobs_db.get(job_id)
    if job is None or job.get("status") != "success":
        raise HTTPException(status_code=404, detail="Job not found or not finished")

    if kind == "classified":
        path = job.get("annotated_video")
    elif kind == "transit":
        path = (job.get("transit") or {}).get("annotated_video")
    else:
        raise HTTPException(status_code=400, detail="kind must be 'classified' or 'transit'")

    if not path or not os.path.exists(path):
        raise HTTPException(
            status_code=404,
            detail=f"No '{kind}' video produced for this job (was output_video enabled?)",
        )
    return FileResponse(
        path=path,
        media_type="video/mp4",
        filename=os.path.basename(path),
    )
