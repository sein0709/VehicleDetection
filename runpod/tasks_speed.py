"""Task 4: speed analysis via a 4-point perspective warp + two LineZones.

For each tracked vehicle, record the frame index when it crosses the upper
entry line and the lower exit line. Convert image → world via a user-supplied
4-point perspective quad. Speed km/h = (world_distance_m / elapsed_s) × 3.6.

Note: supervision 0.27 does not expose a ViewTransformer class, so the
perspective warp uses cv2.getPerspectiveTransform directly. The homography is
kept on the engine so we could warp centers if we ever want per-sample world
velocity instead of the current entry/exit-line method.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any

import cv2
import numpy as np
import supervision as sv

from calibration import SpeedCfg

logger = logging.getLogger("speed")


@dataclass
class SpeedEngine:
    cfg: SpeedCfg
    fps: float
    frame_w: int
    frame_h: int

    # derived
    homography: np.ndarray = field(init=False)          # 3x3 image→world
    line_upper: sv.LineZone = field(init=False)
    line_lower: sv.LineZone = field(init=False)

    # per-track state
    entry_frames: dict[int, int] = field(default_factory=dict)
    speeds_kmh: dict[int, float] = field(default_factory=dict)

    def __post_init__(self) -> None:
        source = np.array(self.cfg.source_quad, dtype=np.float32)
        w_m = self.cfg.real_world_m["width"]
        l_m = self.cfg.real_world_m["length"]
        # Destination: a rectangle where 1 unit = 1 meter.
        target = np.array(
            [[0, 0], [w_m, 0], [w_m, l_m], [0, l_m]], dtype=np.float32
        )
        self.homography = cv2.getPerspectiveTransform(source, target)

        y1 = int(self.frame_h * self.cfg.lines_y_ratio[0])
        y2 = int(self.frame_h * self.cfg.lines_y_ratio[1])
        self.line_upper = sv.LineZone(
            start=sv.Point(0, y1), end=sv.Point(self.frame_w, y1)
        )
        self.line_lower = sv.LineZone(
            start=sv.Point(0, y2), end=sv.Point(self.frame_w, y2)
        )
        # Real-world Y distance between the two lines, in meters:
        # linear interpolation along the length axis of the target rectangle.
        self._distance_m = abs(
            self.cfg.lines_y_ratio[1] - self.cfg.lines_y_ratio[0]
        ) * l_m

    def update(self, detections: sv.Detections, frame_idx: int) -> None:
        """Call once per pipeline frame. Emits km/h into self.speeds_kmh as
        vehicles cross both lines."""
        if detections.tracker_id is None or len(detections) == 0:
            return

        # Trigger LineZone crossings — supervision mutates internal state.
        self.line_upper.trigger(detections)
        self.line_lower.trigger(detections)

        # Build {tid: center_y} to decide who just entered vs exited.
        xy = detections.get_anchors_coordinates(anchor=sv.Position.CENTER)
        for tid, (_, cy) in zip(detections.tracker_id, xy):
            tid_int = int(tid)
            y_top = self.line_upper.vector.start.y
            y_bot = self.line_lower.vector.start.y

            # First time we see tid above/below the upper line, record entry.
            if tid_int not in self.entry_frames and abs(cy - y_top) < 5:
                self.entry_frames[tid_int] = frame_idx

            # When tid reaches the lower line, compute speed.
            if tid_int in self.entry_frames and tid_int not in self.speeds_kmh \
               and abs(cy - y_bot) < 5:
                elapsed_s = (frame_idx - self.entry_frames[tid_int]) / self.fps
                if elapsed_s > 0:
                    kmh = (self._distance_m / elapsed_s) * 3.6
                    self.speeds_kmh[tid_int] = round(kmh, 1)

    def report(self) -> dict[str, Any]:
        if not self.speeds_kmh:
            return {"vehicles_measured": 0, "avg_kmh": None, "per_track": {}}
        values = list(self.speeds_kmh.values())
        return {
            "vehicles_measured": len(values),
            "avg_kmh": round(sum(values) / len(values), 1),
            "min_kmh": min(values),
            "max_kmh": max(values),
            "per_track": {str(k): v for k, v in self.speeds_kmh.items()},
        }
