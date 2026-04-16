"""RunPod video-analysis server.

Accepts video uploads via ``POST /analyze_video``, processes them in a
background thread (YOLO detection + counting), and exposes job status via
``GET /status/{job_id}``.

**Key design note:** the uploaded file is read and persisted to disk
*before* the HTTP response is returned.  ``UploadFile``'s underlying
temporary file is cleaned up by Starlette as soon as the response is sent,
so deferring the read to a ``BackgroundTask`` would result in an empty or
closed file handle — yielding 0 vehicles every time.
"""

from __future__ import annotations

import logging
import os
import tempfile
from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager
from typing import Any
from uuid import uuid4

import cv2
import numpy as np
from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("video_analysis")

UPLOAD_DIR = os.environ.get("UPLOAD_DIR", tempfile.gettempdir())
MODEL_PATH = os.environ.get("MODEL_PATH", "yolo11n.onnx")
CONFIDENCE_THRESHOLD = float(os.environ.get("CONFIDENCE_THRESHOLD", "0.25"))
NMS_IOU_THRESHOLD = float(os.environ.get("NMS_IOU_THRESHOLD", "0.45"))
INPUT_SIZE = int(os.environ.get("INPUT_SIZE", "640"))
FRAME_SAMPLE_INTERVAL = int(os.environ.get("FRAME_SAMPLE_INTERVAL", "10"))

NUM_CLASSES = 12
CLASS_NAMES = [
    "C01_PASSENGER_MINITRUCK",
    "C02_BUS",
    "C03_TRUCK_LT_2_5T",
    "C04_TRUCK_2_5_TO_8_5T",
    "C05_SINGLE_3_AXLE",
    "C06_SINGLE_4_AXLE",
    "C07_SINGLE_5_AXLE",
    "C08_SEMI_4_AXLE",
    "C09_FULL_4_AXLE",
    "C10_SEMI_5_AXLE",
    "C11_FULL_5_AXLE",
    "C12_SEMI_6_AXLE",
]

jobs: dict[str, dict[str, Any]] = {}
_executor = ThreadPoolExecutor(max_workers=2)
_ort_session = None


def _load_model():
    """Load the ONNX model lazily (once)."""
    global _ort_session
    if _ort_session is not None:
        return _ort_session
    try:
        import onnxruntime as ort

        providers = ["CUDAExecutionProvider", "CPUExecutionProvider"]
        _ort_session = ort.InferenceSession(MODEL_PATH, providers=providers)
        logger.info("Loaded ONNX model from %s", MODEL_PATH)
    except Exception:
        logger.warning("Could not load ONNX model at %s — stub mode", MODEL_PATH)
        _ort_session = None
    return _ort_session


def _letterbox(image: np.ndarray, target_size: int):
    h, w = image.shape[:2]
    scale = target_size / max(h, w)
    new_w, new_h = int(w * scale), int(h * scale)
    resized_img = cv2.resize(image, (new_w, new_h), interpolation=cv2.INTER_LINEAR)
    canvas = np.full((target_size, target_size, 3), 114, dtype=np.uint8)
    pad_w = (target_size - new_w) // 2
    pad_h = (target_size - new_h) // 2
    canvas[pad_h : pad_h + new_h, pad_w : pad_w + new_w] = resized_img
    return canvas, scale, (pad_w, pad_h)


def _nms(boxes: np.ndarray, scores: np.ndarray, iou_threshold: float) -> list[int]:
    if len(boxes) == 0:
        return []
    x1, y1, x2, y2 = boxes[:, 0], boxes[:, 1], boxes[:, 2], boxes[:, 3]
    areas = (x2 - x1) * (y2 - y1)
    order = scores.argsort()[::-1]
    keep: list[int] = []
    while order.size > 0:
        i = order[0]
        keep.append(int(i))
        if order.size == 1:
            break
        xx1 = np.maximum(x1[i], x1[order[1:]])
        yy1 = np.maximum(y1[i], y1[order[1:]])
        xx2 = np.minimum(x2[i], x2[order[1:]])
        yy2 = np.minimum(y2[i], y2[order[1:]])
        inter = np.maximum(0.0, xx2 - xx1) * np.maximum(0.0, yy2 - yy1)
        iou = inter / (areas[i] + areas[order[1:]] - inter + 1e-6)
        remaining = np.where(iou <= iou_threshold)[0]
        order = order[remaining + 1]
    return keep


def _detect_frame(session, frame: np.ndarray) -> dict[int, int]:
    """Run detection on a single frame and return per-class counts (class_id -> count)."""
    padded, scale, (pad_w, pad_h) = _letterbox(frame, INPUT_SIZE)
    blob = padded.astype(np.float32) / 255.0
    blob = blob.transpose(2, 0, 1)[np.newaxis]

    input_name = session.get_inputs()[0].name
    raw = session.run(None, {input_name: blob})[0]

    if raw.size == 0:
        return {}

    preds = raw[0] if raw.ndim == 3 else raw
    if preds.ndim == 2 and preds.shape[0] < preds.shape[1]:
        preds = preds.T
    if preds.shape[1] < 5:
        return {}

    if preds.shape[1] == 4 + NUM_CLASSES:
        scores = preds[:, 4:].max(axis=1)
        class_ids = preds[:, 4:].argmax(axis=1)
    elif preds.shape[1] == 5 + NUM_CLASSES:
        scores = preds[:, 4] * preds[:, 5:].max(axis=1)
        class_ids = preds[:, 5:].argmax(axis=1)
    else:
        scores = preds[:, 4]
        class_ids = np.zeros(len(scores), dtype=int)

    mask = scores >= CONFIDENCE_THRESHOLD
    preds = preds[mask]
    scores = scores[mask]
    class_ids = class_ids[mask]

    if len(preds) == 0:
        return {}

    cx, cy, bw, bh = preds[:, 0], preds[:, 1], preds[:, 2], preds[:, 3]
    boxes_xyxy = np.stack([cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2], axis=1)
    keep = _nms(boxes_xyxy, scores, NMS_IOU_THRESHOLD)

    counts: dict[int, int] = {}
    for idx in keep:
        cls_id = int(class_ids[idx])
        counts[cls_id] = counts.get(cls_id, 0) + 1
    return counts


def _process_video(job_id: str, video_path: str) -> None:
    """Background job: decode video, run detection on sampled frames, tally."""
    try:
        logger.info("Processing job %s — %s", job_id, video_path)
        jobs[job_id]["status"] = "processing"

        session = _load_model()

        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            jobs[job_id].update(status="error", message="Failed to open video file")
            return

        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        logger.info("Job %s: %d frames, %.1f fps", job_id, total_frames, fps)

        class_counts: dict[str, int] = {}
        total_vehicles = 0
        frame_idx = 0

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            if frame_idx % FRAME_SAMPLE_INTERVAL == 0 and session is not None:
                frame_counts = _detect_frame(session, frame)
                for cls_id, cnt in frame_counts.items():
                    name = CLASS_NAMES[cls_id] if cls_id < NUM_CLASSES else f"UNKNOWN_{cls_id}"
                    class_counts[name] = class_counts.get(name, 0) + cnt
                    total_vehicles += cnt

            frame_idx += 1

        cap.release()

        jobs[job_id].update(
            status="success",
            total_vehicles_counted=total_vehicles,
            breakdown=class_counts,
            message="Analysis complete",
        )
        logger.info("Job %s complete: %d vehicles", job_id, total_vehicles)

    except Exception as exc:
        logger.exception("Job %s failed", job_id)
        jobs[job_id].update(status="error", message=str(exc))

    finally:
        try:
            os.unlink(video_path)
            logger.info("Cleaned up %s", video_path)
        except OSError:
            pass


@asynccontextmanager
async def lifespan(app: FastAPI):
    _load_model()
    yield
    _executor.shutdown(wait=False)


app = FastAPI(title="GreyEye Video Analysis", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.post("/analyze_video")
async def analyze_video(file: UploadFile = File(...)):
    job_id = str(uuid4())

    # ---- FIX: read and persist the upload BEFORE returning ----
    # Starlette cleans up the UploadFile temp file when the response is sent.
    # If we only pass the UploadFile to a background task, its underlying
    # SpooledTemporaryFile will already be closed/empty by the time the
    # background task runs.  We therefore read the entire payload into a
    # persistent temp file *now*, and hand the path to the worker.
    safe_filename = (file.filename or "upload").replace("/", "_").replace("..", "_")
    dest_path = os.path.join(UPLOAD_DIR, f"{job_id}_{safe_filename}")

    contents = await file.read()
    file_size = len(contents)
    with open(dest_path, "wb") as f:
        f.write(contents)
    logger.info(
        "Saved upload for job %s: %s (%d bytes)", job_id, dest_path, file_size
    )

    jobs[job_id] = {"status": "processing", "job_id": job_id}
    _executor.submit(_process_video, job_id, dest_path)

    return JSONResponse(
        content={
            "job_id": job_id,
            "status": "processing",
            "message": f"Video received ({file_size} bytes)",
        }
    )


@app.get("/status/{job_id}")
async def get_status(job_id: str):
    job = jobs.get(job_id)
    if job is None:
        return JSONResponse(status_code=404, content={"error": "Job not found"})
    return JSONResponse(content=job)


@app.get("/healthz")
async def healthz():
    return {"status": "ok"}
