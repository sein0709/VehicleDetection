"""Task 6: public transit analytics.

* Density: supervision.PolygonZone counts persons inside the bus-stop footprint
  every sampled frame. density_pct = count / max_capacity × 100.
* Boarding/alighting: one supervision.LineZone per bus door. Counts only advance
  while a bus is physically at the stop (optional ``bus_zone_polygon``) — this
  keeps passers-by from inflating transit counts between bus arrivals.
* Annotated video output (optional): circles drawn on each person's head (top-
  centre of bbox), colour-shaded by density. Tracks that recently crossed a
  door line flash green (boarding) or red (alighting) for a short fade window.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any

import cv2
import numpy as np
import supervision as sv

from calibration import TransitCfg
from config import PEDESTRIAN_CLASS_ID

logger = logging.getLogger("transit")

# BUS class id in the RT-DETR output = MOLIT Class 2. Kept local to this
# module because transit semantics attach specifically to buses, not all
# vehicles.
BUS_CLASS_ID = 6

# How many sampled frames to keep a boarding/alighting colour tag on a
# tracker_id after it crosses a door line.
CROSSING_TAG_TTL = 8


@dataclass
class TransitEngine:
    cfg: TransitCfg
    frame_w: int
    frame_h: int

    zone: sv.PolygonZone = field(init=False)
    bus_zone: sv.PolygonZone | None = field(init=False, default=None)
    doors: list[sv.LineZone] = field(default_factory=list)

    density_samples: list[dict[str, float]] = field(default_factory=list)
    peak_count: int = 0

    # tracker_id -> frames_remaining (positive = tag still visible)
    _boarded_ttl: dict[int, int] = field(default_factory=dict)
    _alighted_ttl: dict[int, int] = field(default_factory=dict)
    # per-door previous in/out counts so we can detect which tids just crossed
    _door_counts: list[tuple[int, int]] = field(default_factory=list)
    # Cumulative, bus-gated boarding/alighting totals
    boarding_total: int = 0
    alighting_total: int = 0
    # Per-tid direction bookkeeping so a tid is only counted once per door.
    _tid_direction: dict[int, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        poly = np.array(self.cfg.stop_polygon, dtype=np.int32)
        self.zone = sv.PolygonZone(
            polygon=poly,
            triggering_anchors=(sv.Position.BOTTOM_CENTER,),
        )
        if self.cfg.bus_zone_polygon is not None:
            self.bus_zone = sv.PolygonZone(
                polygon=np.array(self.cfg.bus_zone_polygon, dtype=np.int32),
                triggering_anchors=(sv.Position.CENTER,),
            )
        for door in self.cfg.doors:
            line = door.get("line")
            if not line or len(line) != 2:
                logger.warning("Skipping invalid door definition: %s", door)
                continue
            (x1, y1), (x2, y2) = line
            self.doors.append(
                sv.LineZone(start=sv.Point(x1, y1), end=sv.Point(x2, y2))
            )
        self._door_counts = [(0, 0)] * len(self.doors)

    # ----------------------------------------------------------- updates
    def update(
        self,
        detections: sv.Detections,
        timestamp_s: float,
    ) -> None:
        if detections.class_id is None or len(detections) == 0:
            self._decay_tags()
            return

        person_mask = detections.class_id == PEDESTRIAN_CLASS_ID
        persons = detections[person_mask]

        # Density from persons inside the stop polygon.
        if len(persons) > 0:
            inside_mask = self.zone.trigger(detections=persons)
            count_inside = int(inside_mask.sum())
            self.peak_count = max(self.peak_count, count_inside)
            pct = (
                (count_inside / self.cfg.max_capacity) * 100
                if self.cfg.max_capacity else 0.0
            )
            self.density_samples.append(
                {"t": round(timestamp_s, 2), "count": count_inside,
                 "density_pct": round(pct, 1)}
            )

        # Bus-presence gate. Counts only advance when a bus detection overlaps
        # the bus_zone_polygon (or any bus exists in frame, if no zone given).
        bus_present = self._any_bus_present(detections)

        # Door crossings — always call trigger() to keep supervision's internal
        # state consistent (tracker ids it has already seen), but only credit
        # the count when a bus is at the stop.
        if len(persons) > 0:
            for i, door in enumerate(self.doors):
                door.trigger(persons)
                if bus_present:
                    self._harvest_door_crossings(i, door, persons)

        self._decay_tags()

    # ---------------------------------------------------- reporting APIs
    def near_capacity(self) -> bool:
        if not self.density_samples:
            return False
        return self.density_samples[-1]["density_pct"] >= 80.0

    def apply_vlm_density_correction(
        self, timestamp_s: float, vlm_count: int,
    ) -> None:
        """Override the closest density sample with a VLM-confirmed headcount.

        The CV path counts BOTTOM_CENTER anchors inside the stop polygon —
        when the polygon gets crowded, occlusion makes the count an
        under-estimate. The VLM gets the same crop and is more reliable on
        a packed scene, so we replace the matching sample's count and
        clamp ``peak_count`` upward (we never let the VLM lower a value
        we've already observed at the pixel level).
        """
        if not self.density_samples or vlm_count < 0:
            return

        idx = min(
            range(len(self.density_samples)),
            key=lambda i: abs(self.density_samples[i]["t"] - timestamp_s),
        )
        sample = self.density_samples[idx]
        sample["count"] = max(int(sample["count"]), vlm_count)
        sample["density_pct"] = round(
            (sample["count"] / self.cfg.max_capacity) * 100
            if self.cfg.max_capacity else 0.0,
            1,
        )
        sample["vlm_corrected"] = True
        self.peak_count = max(self.peak_count, sample["count"])

    def report(self, annotated_video_path: str | None = None) -> dict[str, Any]:
        avg_pct = 0.0
        if self.density_samples:
            avg_pct = sum(s["density_pct"] for s in self.density_samples) / len(self.density_samples)
        out: dict[str, Any] = {
            "peak_count": self.peak_count,
            "avg_density_pct": round(avg_pct, 1),
            "boarding": self.boarding_total,
            "alighting": self.alighting_total,
            "samples": self.density_samples[-200:],
            "bus_gated": self.bus_zone is not None,
        }
        if annotated_video_path:
            out["annotated_video"] = annotated_video_path
        return out

    # ---------------------------------------------------- internals
    def _any_bus_present(self, detections: sv.Detections) -> bool:
        if detections.class_id is None or len(detections) == 0:
            return False
        buses = detections[detections.class_id == BUS_CLASS_ID]
        if len(buses) == 0:
            return False
        if self.bus_zone is None:
            # Conservative fallback — any bus anywhere counts as "at the stop".
            return True
        mask = self.bus_zone.trigger(detections=buses)
        return bool(mask.any())

    def _harvest_door_crossings(
        self,
        door_idx: int,
        door: sv.LineZone,
        persons: sv.Detections,
    ) -> None:
        """Detect newly-crossed tids since last call and tag them.

        supervision.LineZone tracks which tids have crossed IN vs OUT but its
        public API exposes only the running in_count/out_count. We derive new
        crossings by comparing against the previous snapshot and by watching
        which tids have flipped sides against the line between frames.
        """
        prev_in, prev_out = self._door_counts[door_idx]
        new_in = door.in_count - prev_in
        new_out = door.out_count - prev_out
        self._door_counts[door_idx] = (door.in_count, door.out_count)

        if new_in <= 0 and new_out <= 0:
            return

        # Best-effort: whichever tids in `persons` are closest to the line and
        # haven't already been recorded get tagged. supervision doesn't expose
        # per-crossing tids directly in 0.27 so this is approximate — good
        # enough for visualization; the counts themselves come from LineZone.
        if persons.tracker_id is None:
            self.boarding_total += new_in
            self.alighting_total += new_out
            return

        unseen = [
            int(tid) for tid in persons.tracker_id
            if int(tid) not in self._tid_direction
        ]
        # Tag the first N unseen as the direction of their crossing.
        for _ in range(new_in):
            if not unseen:
                break
            tid = unseen.pop(0)
            self._tid_direction[tid] = "in"
            self._boarded_ttl[tid] = CROSSING_TAG_TTL
        for _ in range(new_out):
            if not unseen:
                break
            tid = unseen.pop(0)
            self._tid_direction[tid] = "out"
            self._alighted_ttl[tid] = CROSSING_TAG_TTL

        self.boarding_total += new_in
        self.alighting_total += new_out

    def _decay_tags(self) -> None:
        for ttl_map in (self._boarded_ttl, self._alighted_ttl):
            for tid in list(ttl_map):
                ttl_map[tid] -= 1
                if ttl_map[tid] <= 0:
                    del ttl_map[tid]

    # ---------------------------------------------------- annotation
    def annotate_frame(
        self,
        frame: np.ndarray,
        detections: sv.Detections,
    ) -> np.ndarray:
        """Return a copy of ``frame`` with transit overlays drawn on it."""
        out = frame.copy()
        h, w = out.shape[:2]

        # Density-driven colour scale: green < 50%, yellow 50-80%, red >=80%.
        pct = self.density_samples[-1]["density_pct"] if self.density_samples else 0.0
        if pct >= 80:
            density_color = (0, 0, 255)        # BGR red
        elif pct >= 50:
            density_color = (0, 255, 255)      # yellow
        else:
            density_color = (0, 255, 0)        # green

        # Stop polygon with translucent fill.
        poly = np.array(self.cfg.stop_polygon, dtype=np.int32)
        overlay = out.copy()
        cv2.fillPoly(overlay, [poly], density_color)
        cv2.addWeighted(overlay, 0.15, out, 0.85, 0, out)
        cv2.polylines(out, [poly], True, density_color, 2, cv2.LINE_AA)

        # Bus zone, if calibrated.
        if self.cfg.bus_zone_polygon is not None:
            bz = np.array(self.cfg.bus_zone_polygon, dtype=np.int32)
            cv2.polylines(out, [bz], True, (255, 200, 0), 2, cv2.LINE_AA)

        # Door lines.
        for i, door in enumerate(self.doors):
            s, e = door.vector.start, door.vector.end
            cv2.line(out, (int(s.x), int(s.y)), (int(e.x), int(e.y)),
                     (255, 128, 0), 2, cv2.LINE_AA)
            cv2.putText(out, f"door_{i}", (int(s.x), int(s.y) - 6),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 128, 0), 1)

        # Head circles on persons inside the stop polygon.
        if detections.class_id is not None and len(detections) > 0:
            persons = detections[detections.class_id == PEDESTRIAN_CLASS_ID]
            if len(persons) > 0:
                inside_mask = self.zone.trigger(detections=persons)
                for j in range(len(persons)):
                    if not inside_mask[j]:
                        continue
                    x1, y1, x2, y2 = [int(v) for v in persons.xyxy[j]]
                    hx = (x1 + x2) // 2
                    hy = y1 + int(0.10 * (y2 - y1))
                    tid = int(persons.tracker_id[j]) if persons.tracker_id is not None else -1

                    # Priority: recently-tagged boarder/alighter overrides density colour.
                    if tid in self._boarded_ttl:
                        circle_color = (0, 255, 0)
                        ring_thickness = 3
                    elif tid in self._alighted_ttl:
                        circle_color = (0, 0, 255)
                        ring_thickness = 3
                    else:
                        circle_color = density_color
                        ring_thickness = 2
                    cv2.circle(out, (hx, hy), 18, circle_color, ring_thickness)

        # Header HUD — density bar + boarding / alighting totals.
        hud_h = 46
        cv2.rectangle(out, (0, 0), (w, hud_h), (0, 0, 0), -1)
        pct_clamped = min(100.0, pct)
        bar_w = int((w * 0.35) * (pct_clamped / 100.0))
        cv2.rectangle(out, (10, 8), (10 + bar_w, 28), density_color, -1)
        cv2.rectangle(out, (10, 8), (10 + int(w * 0.35), 28), (200, 200, 200), 1)
        cv2.putText(out, f"density {pct:.0f}% / cap {self.cfg.max_capacity}",
                    (10, 42), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
        cv2.putText(out,
                    f"board(in) {self.boarding_total}   alight(out) {self.alighting_total}",
                    (int(w * 0.40), 28),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)

        return out
