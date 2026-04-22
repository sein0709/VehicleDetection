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

        if self.cfg.lines_xy is not None and len(self.cfg.lines_xy) == 2:
            # Operator drew 2 arbitrary line segments — use them as the
            # entry/exit LineZones directly. World-distance is the
            # Euclidean distance between the two line midpoints after the
            # perspective warp, which collapses to the legacy
            # `|y2-y1|*length` formula for parallel horizontal lines but
            # also handles oblique lane configurations correctly.
            (l1_p1, l1_p2) = self.cfg.lines_xy[0]
            (l2_p1, l2_p2) = self.cfg.lines_xy[1]
            self.line_upper = sv.LineZone(
                start=sv.Point(int(l1_p1[0]), int(l1_p1[1])),
                end=sv.Point(int(l1_p2[0]), int(l1_p2[1])),
            )
            self.line_lower = sv.LineZone(
                start=sv.Point(int(l2_p1[0]), int(l2_p1[1])),
                end=sv.Point(int(l2_p2[0]), int(l2_p2[1])),
            )
            mid1 = np.array(
                [[(l1_p1[0] + l1_p2[0]) / 2, (l1_p1[1] + l1_p2[1]) / 2]],
                dtype=np.float32,
            ).reshape(-1, 1, 2)
            mid2 = np.array(
                [[(l2_p1[0] + l2_p2[0]) / 2, (l2_p1[1] + l2_p2[1]) / 2]],
                dtype=np.float32,
            ).reshape(-1, 1, 2)
            world1 = cv2.perspectiveTransform(mid1, self.homography)[0, 0]
            world2 = cv2.perspectiveTransform(mid2, self.homography)[0, 0]
            self._distance_m = float(np.linalg.norm(world1 - world2))
        else:
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
        vehicles cross both lines.

        Uses sv.LineZone's own crossing return value (per-detection masks
        of "crossed in / out this frame") rather than a y-coordinate
        proximity check. The proximity check only worked for horizontal
        lines; the mask-based approach handles operator-drawn oblique
        lines too.
        """
        if detections.tracker_id is None or len(detections) == 0:
            return

        upper_in, upper_out = self.line_upper.trigger(detections)
        lower_in, lower_out = self.line_lower.trigger(detections)
        upper_crossed = upper_in | upper_out
        lower_crossed = lower_in | lower_out

        for i, tid in enumerate(detections.tracker_id):
            tid_int = int(tid)
            # Entry = first crossing of either line.
            if tid_int not in self.entry_frames and (
                upper_crossed[i] or lower_crossed[i]
            ):
                self.entry_frames[tid_int] = frame_idx
                continue
            # Exit = first crossing of the OTHER line (not the same sample
            # as the entry — already short-circuited above).
            if tid_int in self.entry_frames and tid_int not in self.speeds_kmh \
               and (upper_crossed[i] or lower_crossed[i]):
                elapsed_s = (frame_idx - self.entry_frames[tid_int]) / self.fps
                if elapsed_s > 0:
                    kmh = (self._distance_m / elapsed_s) * 3.6
                    self.speeds_kmh[tid_int] = round(kmh, 1)

    def report(self) -> dict[str, Any]:
        # Tracks that crossed the first line but never the second are an
        # operator hint that the exit line is misplaced (too low / off the
        # vehicle path) or the clip ended mid-traversal. Surfaced as a
        # report field AND a debug log so it shows up both in the xlsx
        # output and in the pod logs.
        dropped = sorted(
            tid for tid in self.entry_frames if tid not in self.speeds_kmh
        )
        if dropped:
            logger.debug(
                "Speed: %d track(s) crossed line 1 but never line 2 (tids=%s) — "
                "check that line 2 sits on the vehicle path and the clip is long enough",
                len(dropped), dropped[:10],
            )

        if not self.speeds_kmh:
            return {
                "vehicles_measured": 0,
                "avg_kmh": None,
                "per_track": {},
                "dropped_tracks": len(dropped),
            }
        values = list(self.speeds_kmh.values())
        return {
            "vehicles_measured": len(values),
            "avg_kmh": round(sum(values) / len(values), 1),
            "min_kmh": min(values),
            "max_kmh": max(values),
            "per_track": {str(k): v for k, v in self.speeds_kmh.items()},
            "dropped_tracks": len(dropped),
        }
