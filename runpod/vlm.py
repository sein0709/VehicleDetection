"""Async Gemma / Vertex AI worker pool.

Replaces the inline ``ask_gemma_for_override()`` call that used to block the
detection loop. Five VLM triggers share one pool:

    AXLE_CHECK       heavy-truck tripwire crossing → axle count + class override
    CLASS_REVERIFY   mid-band detection score → class confirmation
    PLATE_OCR        vehicle crop → plate localization + Korean OCR
    DENSITY_CHECK    crowded PolygonZone → passenger count sanity check
    LIGHT_STATE      HSV-ambiguous ROI → traffic-light colour confirmation

Design:
- Each call yields a Future; callers can await concurrently while the decode
  loop advances to the next frame.
- Perceptual-hash cache dedupes repeat crops of the same vehicle.
- Circuit breaker trips after ``VLM_CIRCUIT_THRESHOLD`` consecutive failures
  → all downstream triggers degrade gracefully (caller keeps the RT-DETR
  classification / HSV verdict).
- Per-call timeout so a stalled Vertex region can't wedge the job forever.
"""
from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import threading
from concurrent.futures import Future
from dataclasses import dataclass
from enum import Enum
from typing import Any

import cv2
import numpy as np

from config import (
    VERTEX_LOCATION,
    VERTEX_PROJECT,
    VLM_CIRCUIT_THRESHOLD,
    VLM_CONCURRENCY,
    VLM_MODEL_ID,
    VLM_TEMPERATURE,
    VLM_TIMEOUT_S,
)

logger = logging.getLogger("vlm")


class VLMTask(str, Enum):
    AXLE_CHECK = "axle_check"
    CLASS_REVERIFY = "class_reverify"
    PLATE_OCR = "plate_ocr"
    DENSITY_CHECK = "density_check"
    LIGHT_STATE = "light_state"


# ---------------------------------------------------------------------------
# Prompts — one per task
# ---------------------------------------------------------------------------
_PROMPT_AXLE = """
You are an expert Korean MOLIT (국토교통부) traffic inspector.
Classify this vehicle per the 12-class MOLIT standard by counting GROUNDED axles only
(ignore lifted/가변 axles).

Chassis categories:
- Passenger/Van, Bus
- Rigid Truck (단일구조): single unbroken frame, no hinge
- Semi-Trailer (반연결차): tractor + trailer with fifth-wheel hinge
- Full-Trailer (전연결차): truck + second trailer behind it

MOLIT IDs (this is the OUTPUT id):
  2  = Class 1 Passenger/Van
  6  = Class 2 Bus
  7  = Class 3 Rigid 2-axle, <2.5t
  8  = Class 4 Rigid 2-axle, >=2.5t
  9  = Class 5 Rigid 3-axle
  10 = Class 6 Rigid 4-axle
  11 = Class 7 Rigid 5-axle
  12 = Class 8 Semi-trailer 4-axle
  13 = Class 9 Full-trailer 4-axle
  3  = Class 10 Semi-trailer 5-axle
  4  = Class 11 Full-trailer 5-axle
  5  = Class 12 Semi/Full-trailer 6+ axle

Return ONLY valid JSON:
{"reasoning": "<short analysis>", "molit_class_id": <int>, "confidence": <float 0-1>}
""".strip()

_PROMPT_REVERIFY = """
The vehicle detector returned class {detected_name} (id {detected_id}) with LOW confidence.
Confirm or correct using the same MOLIT 12-class standard. Count grounded axles when relevant.

Return ONLY JSON:
{{"reasoning": "<short>", "molit_class_id": <int>, "confidence": <float 0-1>, "agrees_with_detector": <bool>}}
""".strip()

_PROMPT_PLATE = """
Locate the Korean license plate on this vehicle and read the text EXACTLY as printed.
Korean plates look like: "12가 3456" or "123가 4567" (region/hiragana-like block + digits).

Return ONLY JSON:
{"plate_found": <bool>,
 "plate_text": "<exact text or empty>",
 "plate_bbox_xyxy": [x1,y1,x2,y2]  // in pixel coords of this image, or null if plate_found is false,
 "confidence": <float 0-1>}
""".strip()

_PROMPT_DENSITY = """
Count the visible PEOPLE in this crop of a bus stop / platform.
Do not count vehicles, bicycles, or reflections.

Return ONLY JSON:
{"person_count": <int>, "confidence": <float 0-1>, "notes": "<short>"}
""".strip()

_PROMPT_LIGHT = """
This is a crop of a traffic light. Identify the currently-lit lamp.
Allowed states: "red", "yellow", "green", "unknown".
Return ONLY JSON:
{"state": "<one of allowed>", "confidence": <float 0-1>}
""".strip()

_PROMPTS: dict[VLMTask, str] = {
    VLMTask.AXLE_CHECK: _PROMPT_AXLE,
    VLMTask.CLASS_REVERIFY: _PROMPT_REVERIFY,
    VLMTask.PLATE_OCR: _PROMPT_PLATE,
    VLMTask.DENSITY_CHECK: _PROMPT_DENSITY,
    VLMTask.LIGHT_STATE: _PROMPT_LIGHT,
}


# ---------------------------------------------------------------------------
# Worker pool
# ---------------------------------------------------------------------------
@dataclass
class VLMRequest:
    task: VLMTask
    image: np.ndarray
    context: dict[str, Any]           # e.g. {"detected_id": 9, "detected_name": "Class 5"}
    track_id: int | None = None       # for logging / pending-set bookkeeping


class VLMPool:
    """Thread-safe submission point; a background asyncio loop drains the queue."""

    def __init__(self) -> None:
        self._loop: asyncio.AbstractEventLoop | None = None
        self._thread: threading.Thread | None = None
        self._sem: asyncio.Semaphore | None = None
        self._model = None
        self._cache: dict[str, dict[str, Any]] = {}
        self._cache_lock = threading.Lock()
        self._consecutive_failures = 0
        self._circuit_open = False
        self._init_error: str | None = None

    # ------------------------------------------------------------------ lifecycle
    def start(self) -> None:
        if self._thread is not None:
            return
        ready = threading.Event()

        def _run() -> None:
            self._loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self._loop)
            self._sem = asyncio.Semaphore(VLM_CONCURRENCY)
            self._initialize_vertex()
            ready.set()
            self._loop.run_forever()

        self._thread = threading.Thread(target=_run, name="vlm-pool", daemon=True)
        self._thread.start()
        ready.wait(timeout=30)

    def stop(self) -> None:
        if self._loop is not None and self._loop.is_running():
            self._loop.call_soon_threadsafe(self._loop.stop)
        if self._thread is not None:
            self._thread.join(timeout=5)

    def _initialize_vertex(self) -> None:
        try:
            import vertexai
            from vertexai.generative_models import GenerativeModel

            vertexai.init(project=VERTEX_PROJECT, location=VERTEX_LOCATION)
            self._model = GenerativeModel(VLM_MODEL_ID)
            logger.info("VLM initialized: %s @ %s", VLM_MODEL_ID, VERTEX_LOCATION)
        except Exception as exc:
            # Don't crash the server — log loudly and operate in degraded mode
            # so CV-only tasks (counting, HSV light, EasyOCR) still work.
            self._init_error = str(exc)
            self._circuit_open = True
            logger.error(
                "VLM init FAILED (%s) — circuit open, all VLM triggers will fall "
                "back to CV defaults. Check VLM_MODEL_ID=%s in config.py.",
                exc, VLM_MODEL_ID,
            )

    # ------------------------------------------------------------------ public API
    def submit(self, req: VLMRequest) -> Future:
        """Thread-safe submit. Returns a concurrent.futures.Future."""
        if self._loop is None:
            fut: Future = Future()
            fut.set_result(None)
            return fut
        return asyncio.run_coroutine_threadsafe(self._handle(req), self._loop)

    def is_available(self) -> bool:
        return self._model is not None and not self._circuit_open

    # ------------------------------------------------------------------ internals
    def _crop_hash(self, img: np.ndarray) -> str:
        # 16x16 average-hash with brightness bucket prefix — the bucket
        # disambiguates uniform-colour crops (solid black vs solid white)
        # which would otherwise share a hash because gray > gray.mean()
        # collapses to all-zeros for any uniform image.
        small = cv2.resize(img, (16, 16), interpolation=cv2.INTER_AREA)
        gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)
        bucket = int(gray.mean()) // 16      # 0..15
        bits = (gray > gray.mean()).astype(np.uint8).tobytes()
        return f"{bucket:02x}" + hashlib.sha1(bits).hexdigest()

    async def _handle(self, req: VLMRequest) -> dict[str, Any] | None:
        if self._circuit_open or self._model is None:
            return None

        cache_key = f"{req.task.value}:{self._crop_hash(req.image)}"
        with self._cache_lock:
            cached = self._cache.get(cache_key)
        if cached is not None:
            return cached

        assert self._sem is not None
        async with self._sem:
            try:
                result = await asyncio.wait_for(
                    self._call_model(req), timeout=VLM_TIMEOUT_S
                )
                self._consecutive_failures = 0
                with self._cache_lock:
                    self._cache[cache_key] = result
                return result
            except asyncio.TimeoutError:
                logger.warning("VLM %s timeout (track %s)", req.task.value, req.track_id)
                return self._on_failure()
            except Exception as exc:
                logger.warning("VLM %s failed: %s (track %s)", req.task.value, exc, req.track_id)
                return self._on_failure()

    def _on_failure(self) -> None:
        self._consecutive_failures += 1
        if self._consecutive_failures >= VLM_CIRCUIT_THRESHOLD:
            if not self._circuit_open:
                logger.error(
                    "VLM circuit OPEN after %d consecutive failures — degrading gracefully",
                    self._consecutive_failures,
                )
            self._circuit_open = True
        return None

    async def _call_model(self, req: VLMRequest) -> dict[str, Any]:
        from vertexai.generative_models import Part

        prompt = _PROMPTS[req.task]
        if req.task is VLMTask.CLASS_REVERIFY:
            prompt = prompt.format(
                detected_id=req.context.get("detected_id", "?"),
                detected_name=req.context.get("detected_name", "?"),
            )

        success, buf = cv2.imencode(".jpg", req.image, [cv2.IMWRITE_JPEG_QUALITY, 85])
        if not success:
            raise RuntimeError("cv2.imencode failed")
        image_part = Part.from_data(data=buf.tobytes(), mime_type="image/jpeg")

        # Vertex SDK is sync; run in executor to avoid blocking the event loop.
        def _sync_call() -> str:
            resp = self._model.generate_content(  # type: ignore[union-attr]
                [prompt, image_part],
                generation_config={"temperature": VLM_TEMPERATURE},
            )
            return resp.text

        loop = asyncio.get_running_loop()
        raw = await loop.run_in_executor(None, _sync_call)
        cleaned = raw.replace("```json", "").replace("```", "").strip()
        return json.loads(cleaned)


# Singleton — started from server.py lifespan.
pool = VLMPool()
