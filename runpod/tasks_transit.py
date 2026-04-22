"""Task 6: public transit analytics.

* Density: supervision.PolygonZone counts persons inside the bus-stop footprint
  every sampled frame. density_pct = count / max_capacity × 100.
* Boarding/alighting (PRIMARY): VLM-per-arrival. The engine watches for
  bus-presence transitions; each true→false transition closes a "bus arrival
  event" with up to 3 sampled crops covering the door-open window. The
  pipeline submits each arrival to ``VLMTask.BUS_BOARDING`` and the response
  fills boarding/alighting for that arrival. Totals in the report are the
  sum across all VLM-applied arrivals — far more reliable than the old
  per-frame LineZone direction-tagging on supervision 0.27, which couldn't
  expose per-crossing track ids.
* Boarding/alighting (FALLBACK): if the VLM circuit is open or no arrivals
  were observed, the legacy ``sv.LineZone`` per-door totals are reported and
  flagged with ``source: "linezone_fallback"`` so the operator can tell
  which path produced the number.
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

# Cap on stored crops per arrival so a long bus dwell (e.g. terminal layover)
# doesn't balloon memory. The VLM only needs a representative sample.
MAX_ARRIVAL_CROPS = 12

# Padding around the door-region bounding rect so the VLM sees a bit of
# context around the bus / curb instead of a pixel-tight crop.
ARRIVAL_CROP_PAD_PX = 24


@dataclass
class BusArrival:
    """One bus-stop event: from arrival_t to departure_t.

    ``door_crops`` accumulates while the bus is present; on departure the
    pipeline harvests a small representative subset (first / mid / last) and
    submits them as a single multi-image VLM request. ``boarding`` and
    ``alighting`` are 0 until the VLM result is applied via
    ``TransitEngine.apply_vlm_boarding``.
    """
    arrival_t: float
    departure_t: float = 0.0
    door_crops: list = field(default_factory=list)
    boarding: int = 0
    alighting: int = 0
    vlm_applied: bool = False
    vlm_confidence: float = 0.0


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
    # FALLBACK boarding/alighting totals from the LineZone heuristic. Only
    # surfaced when no VLM arrivals were observed (circuit open or no bus).
    boarding_total: int = 0
    alighting_total: int = 0
    # Per-tid direction bookkeeping so a tid is only counted once per door.
    _tid_direction: dict[int, str] = field(default_factory=dict)

    # Bus-arrival event detector state.
    arrivals: list[BusArrival] = field(default_factory=list)
    _bus_present_prev: bool = False
    _current_arrival: BusArrival | None = None
    # Indices of arrivals finalized in the most-recent update() call.
    # The pipeline polls this via pop_finalized_arrivals() to know which
    # arrivals to send to the VLM right now.
    _just_departed_idx: list[int] = field(default_factory=list)
    # Cached door-region bbox (computed lazily once we know the polygons
    # have been resolved to pixel coords).
    _door_bbox: tuple[int, int, int, int] | None = None

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
        frame: np.ndarray | None = None,
    ) -> None:
        # Bus-presence gate is computed first so it's always available for
        # arrival-event detection even when there are no person detections
        # (a bus pulling in with nobody at the stop is still an arrival).
        bus_present = (
            False
            if detections.class_id is None or len(detections) == 0
            else self._any_bus_present(detections)
        )

        # Arrival / departure transitions drive the BusArrival queue. The
        # pipeline polls pop_finalized_arrivals() after each update to ship
        # the closed events to the VLM.
        self._update_bus_arrival(bus_present, timestamp_s, frame)

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

        # Door crossings — always call trigger() to keep supervision's internal
        # state consistent (tracker ids it has already seen), but only credit
        # the FALLBACK count when a bus is at the stop.
        if len(persons) > 0:
            for i, door in enumerate(self.doors):
                door.trigger(persons)
                if bus_present:
                    self._harvest_door_crossings(i, door, persons)

        self._decay_tags()

    def _update_bus_arrival(
        self,
        bus_present: bool,
        timestamp_s: float,
        frame: np.ndarray | None,
    ) -> None:
        """State machine on bus presence.

        false→true: open a new BusArrival; capture first crop.
        true→true:  append crop (capped) so we have a sequence to send.
        true→false: close the arrival and queue it for VLM dispatch.
        """
        if bus_present and not self._bus_present_prev:
            self._current_arrival = BusArrival(arrival_t=round(timestamp_s, 2))
            self._maybe_capture_crop(frame)
        elif bus_present and self._current_arrival is not None:
            self._maybe_capture_crop(frame)
        elif not bus_present and self._bus_present_prev \
                and self._current_arrival is not None:
            self._current_arrival.departure_t = round(timestamp_s, 2)
            self.arrivals.append(self._current_arrival)
            self._just_departed_idx.append(len(self.arrivals) - 1)
            self._current_arrival = None
        self._bus_present_prev = bus_present

    def _maybe_capture_crop(self, frame: np.ndarray | None) -> None:
        if frame is None or self._current_arrival is None:
            return
        if len(self._current_arrival.door_crops) >= MAX_ARRIVAL_CROPS:
            # Replace the middle crop so we always keep first + last as
            # context anchors but still pull in something representative
            # from the long middle.
            mid = len(self._current_arrival.door_crops) // 2
            crop = self._extract_door_region(frame)
            if crop is not None:
                self._current_arrival.door_crops[mid] = crop
            return
        crop = self._extract_door_region(frame)
        if crop is not None:
            self._current_arrival.door_crops.append(crop)

    def _extract_door_region(self, frame: np.ndarray) -> np.ndarray | None:
        if self._door_bbox is None:
            polys = []
            if len(self.cfg.stop_polygon) >= 3:
                polys.append(np.array(self.cfg.stop_polygon, dtype=np.int32))
            if self.cfg.bus_zone_polygon is not None \
               and len(self.cfg.bus_zone_polygon) >= 3:
                polys.append(np.array(
                    self.cfg.bus_zone_polygon, dtype=np.int32,
                ))
            if not polys:
                return None
            stacked = np.concatenate(polys, axis=0)
            x, y, w, h = cv2.boundingRect(stacked)
            x = max(0, x - ARRIVAL_CROP_PAD_PX)
            y = max(0, y - ARRIVAL_CROP_PAD_PX)
            w = min(self.frame_w - x, w + 2 * ARRIVAL_CROP_PAD_PX)
            h = min(self.frame_h - y, h + 2 * ARRIVAL_CROP_PAD_PX)
            self._door_bbox = (x, y, w, h)
        x, y, w, h = self._door_bbox
        if w <= 0 or h <= 0:
            return None
        crop = frame[y:y + h, x:x + w]
        return crop.copy() if crop.size > 0 else None

    # ---------------------------------------------------- reporting APIs
    def pop_finalized_arrivals(self) -> list[tuple[int, BusArrival]]:
        """Return arrivals finalized in the most recent update() call.

        Returned indices remain stable for the lifetime of the engine, so
        the pipeline can stash ``(arrival_idx, future)`` and route the VLM
        verdict back via ``apply_vlm_boarding`` once the future resolves.
        """
        out = [(i, self.arrivals[i]) for i in self._just_departed_idx]
        self._just_departed_idx = []
        return out

    def finalize_open_arrival(self, timestamp_s: float) -> None:
        """Close out any in-progress arrival when the video ends mid-event.

        Without this, a clip that ends while the bus is still at the stop
        would silently drop the arrival from the report. The pipeline calls
        this once after the decode loop, before draining VLM futures.
        """
        if self._current_arrival is None:
            return
        self._current_arrival.departure_t = round(timestamp_s, 2)
        self.arrivals.append(self._current_arrival)
        self._just_departed_idx.append(len(self.arrivals) - 1)
        self._current_arrival = None
        self._bus_present_prev = False

    def apply_vlm_boarding(
        self,
        arrival_idx: int,
        boarding: int,
        alighting: int,
        confidence: float = 0.0,
    ) -> None:
        """Stamp the VLM verdict onto a previously-queued arrival event."""
        if not (0 <= arrival_idx < len(self.arrivals)):
            return
        a = self.arrivals[arrival_idx]
        a.boarding = max(0, int(boarding))
        a.alighting = max(0, int(alighting))
        a.vlm_confidence = float(confidence)
        a.vlm_applied = True

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

        # Boarding/alighting source resolution. The VLM totals are the
        # primary number; if no arrival had a successful VLM result we fall
        # back to the LineZone heuristic so the operator still gets *some*
        # number when the VLM is unavailable.
        vlm_arrivals = [a for a in self.arrivals if a.vlm_applied]
        if vlm_arrivals:
            boarding = sum(a.boarding for a in vlm_arrivals)
            alighting = sum(a.alighting for a in vlm_arrivals)
            source = "vlm"
        else:
            boarding = self.boarding_total
            alighting = self.alighting_total
            source = "linezone_fallback"

        per_arrival = [
            {
                "arrival_t": a.arrival_t,
                "departure_t": a.departure_t,
                "boarding": a.boarding,
                "alighting": a.alighting,
                "vlm_applied": a.vlm_applied,
                "vlm_confidence": round(a.vlm_confidence, 2),
            }
            for a in self.arrivals
        ]

        out: dict[str, Any] = {
            "peak_count": self.peak_count,
            "avg_density_pct": round(avg_pct, 1),
            "boarding": boarding,
            "alighting": alighting,
            "source": source,
            "arrivals": len(self.arrivals),
            "per_arrival": per_arrival,
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
