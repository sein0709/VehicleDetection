"""One-shot VLM pre-pass that fills missing transit / traffic-light geometry.

Mobile clients running in "auto" mode submit a calibration block with only the
scalar config (max_capacity for transit, label for traffic light) and omit the
ROIs. This module sees those placeholders, samples one keyframe from the
uploaded video, and asks the VLM to propose the geometry.

The pre-pass runs synchronously BEFORE the main decode loop in
``runpod.pipeline.run_pipeline`` so the rest of the pipeline can read the
filled-in calibration as if the operator had drawn it by hand. On any
failure (no Vertex creds, timeout, low-confidence response, malformed JSON)
we silently fall back to the today's defaults — behaviour never regresses
when the VLM is unavailable.

Coordinate convention: prompts ask the VLM for normalized 0..1 floats. We
pass them through unchanged into the Calibration dataclasses; the existing
``Calibration.resolve_ratio_coords`` step in the pipeline scales them to
pixel coords once it knows the video resolution.
"""
from __future__ import annotations

import logging
from typing import Any

import cv2
import numpy as np

from calibration import Calibration, TrafficLightEntry
from config import (
    VLM_AUTOCALIBRATE,
    VLM_AUTOCALIBRATE_KEYFRAME_S,
    VLM_AUTOCALIBRATE_MIN_CONFIDENCE,
)
from vlm import VLMRequest, VLMTask, pool as vlm_pool

logger = logging.getLogger("auto_calibration")


def autofill_calibration(video_path: str, calibration: Calibration) -> Calibration:
    """Fill missing transit / traffic-light geometry via a VLM keyframe pass.

    Returns the same ``Calibration`` instance (mutated in place) for caller
    convenience. Safe to call when nothing needs auto-fill — exits early.
    """
    if not VLM_AUTOCALIBRATE:
        return calibration

    needs_transit = calibration.transit_needs_autofill()
    needs_light = calibration.traffic_light_needs_autofill()
    if not (needs_transit or needs_light):
        return calibration

    if not vlm_pool.is_available():
        logger.warning(
            "Auto-calibration requested but VLM pool unavailable — "
            "transit/light task will run with default geometry",
        )
        _apply_fallback_defaults(calibration, needs_transit, needs_light)
        return calibration

    frame = _sample_keyframe(video_path, VLM_AUTOCALIBRATE_KEYFRAME_S)
    if frame is None:
        logger.warning(
            "Auto-calibration: failed to sample keyframe from %s — "
            "falling back to defaults",
            video_path,
        )
        _apply_fallback_defaults(calibration, needs_transit, needs_light)
        return calibration

    if needs_transit:
        _autofill_transit(frame, calibration)
    if needs_light:
        _autofill_light(frame, calibration)

    return calibration


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------
def _sample_keyframe(video_path: str, t_sec: float) -> np.ndarray | None:
    """Grab one frame ``t_sec`` seconds into the video.

    Falls back to the very first decodable frame if seeking fails (some
    container/codec combinations on RunPod don't support frame-accurate
    POS_MSEC seeks).
    """
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        return None
    try:
        cap.set(cv2.CAP_PROP_POS_MSEC, t_sec * 1000.0)
        ok, frame = cap.read()
        if not ok or frame is None or frame.size == 0:
            cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
            ok, frame = cap.read()
        return frame if ok else None
    finally:
        cap.release()


def _autofill_transit(frame: np.ndarray, calibration: Calibration) -> None:
    if calibration.transit is None:
        return
    result = _call_vlm(VLMTask.BUS_STOP_LAYOUT, frame)
    confidence = float(result.get("confidence", 0.0)) if result else 0.0
    if not result or confidence < VLM_AUTOCALIBRATE_MIN_CONFIDENCE:
        logger.warning(
            "Auto-calibration: BUS_STOP_LAYOUT confidence %.2f below threshold %.2f — "
            "falling back to default transit geometry",
            confidence, VLM_AUTOCALIBRATE_MIN_CONFIDENCE,
        )
        _apply_transit_defaults(calibration)
        return

    stop_polygon = _coerce_polygon(result.get("stop_polygon"))
    bus_zone_polygon = _coerce_polygon(result.get("bus_zone_polygon"))
    door_lines = _coerce_door_lines(result.get("door_lines"))

    transit = calibration.transit
    if not transit.stop_polygon and stop_polygon:
        transit.stop_polygon = stop_polygon
    if not transit.bus_zone_polygon and bus_zone_polygon:
        transit.bus_zone_polygon = bus_zone_polygon
    if not transit.doors and door_lines:
        transit.doors = [{"line": line} for line in door_lines]

    # Final safety net: anything still missing after the VLM pass falls back
    # to the previous default placement so the engine doesn't crash.
    if not transit.stop_polygon or not transit.doors:
        logger.warning(
            "Auto-calibration: VLM response missing required geometry "
            "(stop_polygon=%s, doors=%s) — patching with defaults",
            len(transit.stop_polygon), len(transit.doors),
        )
        _apply_transit_defaults(calibration)
        return

    logger.info(
        "Auto-calibration: transit geometry filled by VLM "
        "(stop=%dpts, doors=%d, bus_zone=%s, conf=%.2f) — %s",
        len(transit.stop_polygon), len(transit.doors),
        "yes" if transit.bus_zone_polygon else "no",
        confidence, result.get("notes", ""),
    )


def _autofill_light(frame: np.ndarray, calibration: Calibration) -> None:
    if calibration.traffic_light is None:
        return
    result = _call_vlm(VLMTask.LIGHT_LAYOUT, frame)
    lights = result.get("lights") if result else None
    if not result or not isinstance(lights, list) or not lights:
        logger.warning(
            "Auto-calibration: LIGHT_LAYOUT returned no usable bbox — "
            "falling back to default traffic-light ROI",
        )
        _apply_light_defaults(calibration)
        return

    entries: list[TrafficLightEntry] = []
    for i, item in enumerate(lights):
        if not isinstance(item, dict):
            continue
        bbox = item.get("bbox_xyxy")
        conf = float(item.get("confidence", 0.0))
        if conf < VLM_AUTOCALIBRATE_MIN_CONFIDENCE:
            continue
        if not isinstance(bbox, list) or len(bbox) != 4:
            continue
        try:
            x1, y1, x2, y2 = (float(v) for v in bbox)
        except (TypeError, ValueError):
            continue
        # Convert xyxy → [x, y, w, h] in the same coordinate system the prompt
        # promised (normalized 0..1). resolve_ratio_coords scales later.
        x = max(0.0, min(x1, x2))
        y = max(0.0, min(y1, y2))
        w = abs(x2 - x1)
        h = abs(y2 - y1)
        if w <= 0.0 or h <= 0.0:
            continue
        entries.append(TrafficLightEntry(
            roi=[x, y, w, h],
            label=str(item.get("label") or f"light_{i}"),
        ))

    if not entries:
        logger.warning(
            "Auto-calibration: LIGHT_LAYOUT entries all rejected "
            "(low confidence or malformed) — falling back to defaults",
        )
        _apply_light_defaults(calibration)
        return

    calibration.traffic_light.lights = entries
    logger.info(
        "Auto-calibration: traffic_light filled by VLM (%d lights)",
        len(entries),
    )


def _call_vlm(task: VLMTask, frame: np.ndarray) -> dict[str, Any] | None:
    """Submit one VLM request and block on the result. Returns None on error."""
    try:
        future = vlm_pool.submit(VLMRequest(
            task=task, image=frame, context={},
        ))
        # Auto-cal happens before the decode loop so a sync block here is
        # acceptable — a Gemma 31B response is ~5–15s, we cap at the
        # configured per-call timeout.
        result = future.result(timeout=60)
        if not isinstance(result, dict):
            return None
        return result
    except Exception as exc:
        logger.warning("Auto-calibration VLM call %s failed: %s", task.value, exc)
        return None


def _coerce_polygon(raw: Any) -> list[list[float]]:
    if not isinstance(raw, list):
        return []
    out: list[list[float]] = []
    for pt in raw:
        if not isinstance(pt, (list, tuple)) or len(pt) != 2:
            continue
        try:
            x, y = float(pt[0]), float(pt[1])
        except (TypeError, ValueError):
            continue
        # Clamp to [0, 1] — the prompt asks for normalized coords; clamping
        # protects against the occasional VLM overshoot.
        x = min(1.0, max(0.0, x))
        y = min(1.0, max(0.0, y))
        out.append([x, y])
    return out if len(out) >= 3 else []


def _coerce_door_lines(raw: Any) -> list[list[list[float]]]:
    if not isinstance(raw, list):
        return []
    out: list[list[list[float]]] = []
    for door in raw:
        if isinstance(door, dict):
            line = door.get("line")
        else:
            line = door
        if not isinstance(line, list) or len(line) != 2:
            continue
        pts: list[list[float]] = []
        valid = True
        for pt in line:
            if not isinstance(pt, (list, tuple)) or len(pt) != 2:
                valid = False
                break
            try:
                x, y = float(pt[0]), float(pt[1])
            except (TypeError, ValueError):
                valid = False
                break
            pts.append([min(1.0, max(0.0, x)), min(1.0, max(0.0, y))])
        if valid and len(pts) == 2:
            out.append(pts)
    return out


# ---------------------------------------------------------------------------
# Fallback defaults — match the legacy mobile-side defaults so behaviour
# under "auto mode + VLM unavailable" matches what the manual editor would
# have submitted with no operator changes.
# ---------------------------------------------------------------------------
def _apply_fallback_defaults(
    calibration: Calibration, needs_transit: bool, needs_light: bool,
) -> None:
    if needs_transit:
        _apply_transit_defaults(calibration)
    if needs_light:
        _apply_light_defaults(calibration)


def _apply_transit_defaults(calibration: Calibration) -> None:
    """Normalized 0..1 defaults that mirror the mobile builder's previous
    behaviour: a wide bottom band for the stop polygon and a horizontal
    door line across it."""
    transit = calibration.transit
    if transit is None:
        return
    if not transit.stop_polygon:
        transit.stop_polygon = [
            [0.10, 0.55], [0.90, 0.55], [0.90, 0.95], [0.10, 0.95],
        ]
    if not transit.doors:
        transit.doors = [{"line": [[0.30, 0.75], [0.70, 0.75]]}]
    # bus_zone left None on purpose — mobile defaults didn't set it; the
    # engine falls back to "any bus in frame" which is the most permissive
    # behaviour.


def _apply_light_defaults(calibration: Calibration) -> None:
    """Normalized 0..1 ROI roughly where a fixed signal would sit in a
    typical road-camera framing (top-centre)."""
    if calibration.traffic_light is None:
        return
    calibration.traffic_light.lights = [
        TrafficLightEntry(roi=[0.40, 0.05, 0.20, 0.15], label="main"),
    ]
