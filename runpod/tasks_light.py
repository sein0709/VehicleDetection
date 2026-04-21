"""Task 7: traffic-light state machine via static-ROI HSV mask.

No ML inference. Each sampled frame, every calibrated ROI is colour-classified
(red / yellow / green / unknown) by HSV fraction. A per-light state machine
records the dwell time per state; the union of lights is returned in the
pipeline report under ``traffic_lights``.

Multi-light support lets a scene declare separate ROIs for the main signal,
left-turn arrow, pedestrian signal, etc. — each runs an independent state
machine; arrow-signal direction recognition is a follow-up (handled via a VLM
call on state transitions when enabled, not in M7's scope).
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any

import cv2
import numpy as np

from calibration import TrafficLightCfg, TrafficLightEntry
from config import (
    HSV_GREEN_RANGE,
    HSV_RED_RANGES,
    HSV_YELLOW_RANGE,
    LIGHT_PIXEL_FRACTION,
)

logger = logging.getLogger("light")


@dataclass
class StateSpan:
    state: str
    start_s: float
    end_s: float

    @property
    def duration_s(self) -> float:
        return round(self.end_s - self.start_s, 2)


@dataclass
class SingleLightTracker:
    """HSV state machine for one traffic-light head."""
    entry: TrafficLightEntry

    spans: list[StateSpan] = field(default_factory=list)
    _current: StateSpan | None = None
    _unknown_streak: int = 0
    ambiguous_frames: list[tuple[float, np.ndarray]] = field(default_factory=list)

    def _classify(self, roi_bgr: np.ndarray) -> str:
        if roi_bgr.size == 0:
            return "unknown"
        hsv = cv2.cvtColor(roi_bgr, cv2.COLOR_BGR2HSV)
        total = hsv.shape[0] * hsv.shape[1]
        if total == 0:
            return "unknown"

        red_mask = np.zeros(hsv.shape[:2], dtype=np.uint8)
        for lo, hi in HSV_RED_RANGES:
            red_mask |= cv2.inRange(hsv, np.array(lo), np.array(hi))

        green_mask = cv2.inRange(
            hsv, np.array(HSV_GREEN_RANGE[0]), np.array(HSV_GREEN_RANGE[1])
        )
        yellow_mask = cv2.inRange(
            hsv, np.array(HSV_YELLOW_RANGE[0]), np.array(HSV_YELLOW_RANGE[1])
        )

        fracs = {
            "red":    red_mask.sum()    / (total * 255),
            "green":  green_mask.sum()  / (total * 255),
            "yellow": yellow_mask.sum() / (total * 255),
        }
        dominant, frac = max(fracs.items(), key=lambda kv: kv[1])
        return dominant if frac >= LIGHT_PIXEL_FRACTION else "unknown"

    def update(self, frame: np.ndarray, timestamp_s: float) -> tuple[str, np.ndarray | None]:
        x, y, w, h = self.entry.roi
        roi = frame[max(0, y):y + h, max(0, x):x + w]
        state = self._classify(roi)

        ambiguous_crop: np.ndarray | None = None
        if state == "unknown":
            self._unknown_streak += 1
            if self._unknown_streak in (1, 10, 30):
                ambiguous_crop = roi.copy()
        else:
            self._unknown_streak = 0

        if self._current is None:
            self._current = StateSpan(state=state, start_s=timestamp_s, end_s=timestamp_s)
        elif state != self._current.state:
            self._current.end_s = timestamp_s
            self.spans.append(self._current)
            self._current = StateSpan(state=state, start_s=timestamp_s, end_s=timestamp_s)
        else:
            self._current.end_s = timestamp_s

        return state, ambiguous_crop

    def apply_vlm_correction(self, corrected_state: str) -> None:
        if self._current and self._current.state == "unknown":
            self._current.state = corrected_state

    def report(self) -> dict[str, Any]:
        spans = list(self.spans)
        if self._current:
            spans.append(self._current)

        cycle_stats: dict[str, list[float]] = {"red": [], "green": [], "yellow": []}
        for s in spans:
            if s.state in cycle_stats:
                cycle_stats[s.state].append(s.duration_s)

        summary = {
            color: {
                "cycles": len(durs),
                "avg_duration_s": round(sum(durs) / len(durs), 2) if durs else 0.0,
                "total_duration_s": round(sum(durs), 2),
            }
            for color, durs in cycle_stats.items()
        }
        return {
            "label": self.entry.label,
            "roi": list(self.entry.roi),
            "cycles": summary,
            "timeline": [
                {"state": s.state, "start_s": round(s.start_s, 2),
                 "end_s": round(s.end_s, 2), "duration_s": s.duration_s}
                for s in spans
            ],
        }


@dataclass
class TrafficLightEngine:
    """Owns one SingleLightTracker per configured light. The pipeline interacts
    with this wrapper; per-light internals stay opaque."""
    cfg: TrafficLightCfg
    trackers: list[SingleLightTracker] = field(init=False)

    def __post_init__(self) -> None:
        self.trackers = [
            SingleLightTracker(entry=entry) for entry in self.cfg.lights
        ]
        if not self.trackers:
            logger.warning("TrafficLightEngine initialized with 0 lights — no-op")

    def update(self, frame: np.ndarray, timestamp_s: float) -> tuple[str, np.ndarray | None]:
        """Sample every configured light. Returns the (state, ambiguous_crop)
        of the FIRST light only — kept for backward compat with the single-
        light caller in pipeline.py; multi-light details live in self.report()."""
        first_state: str = "unknown"
        first_ambiguous: np.ndarray | None = None
        for i, tracker in enumerate(self.trackers):
            state, ambiguous = tracker.update(frame, timestamp_s)
            if i == 0:
                first_state, first_ambiguous = state, ambiguous
        return first_state, first_ambiguous

    def apply_vlm_correction(self, at_timestamp_s: float, corrected_state: str) -> None:
        # For now the VLM correction applies to the first light only (matches
        # prior single-light semantics). Multi-light VLM routing is a follow-up.
        if self.trackers:
            self.trackers[0].apply_vlm_correction(corrected_state)

    def report(self) -> dict[str, Any]:
        lights = [t.report() for t in self.trackers]
        out: dict[str, Any] = {"traffic_lights": lights}
        if len(lights) == 1:
            # Back-compat: preserve the singular `cycles` + `timeline` keys so
            # existing clients that read the old shape keep working.
            out["cycles"] = lights[0]["cycles"]
            out["timeline"] = lights[0]["timeline"]
        return out
