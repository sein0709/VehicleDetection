"""Single-pass video pipeline.

One decode loop, every analytic runs off the same tracked-detection stream:

  RT-DETR + ByteTrack  →  sv.Detections
           │
           ├──────► bi-directional LineZone (Task 1/2/3 counting)
           ├──────► SpeedEngine   (Task 4)
           ├──────► TransitEngine (Task 6)
           └──────► per-track state (class history, VLM pending-set, plate store)

  Every Nth sampled frame (FRAME_SKIP):
    * tripwire crossings → per track_id, decide which VLM triggers to fire
    * traffic-light HSV sample (Task 7)

VLM calls are submitted to the async pool and collected at end-of-video so
the detection loop never blocks on Vertex AI round-trips.
"""
from __future__ import annotations

import logging
import os
import time
from collections import Counter, defaultdict
from concurrent.futures import Future
from dataclasses import dataclass, field
from typing import Any

import cv2
import numpy as np
import supervision as sv
from ultralytics import YOLO

from calibration import Calibration
from config import (
    ALL_CLASS_NAMES,
    CLAHE_CLIP_LIMIT,
    CLAHE_GRID_SIZE,
    DETECT_CONF,
    ENABLE_PEDESTRIAN_DETECTOR,
    FRAME_SKIP,
    HEAVY_TRUCK_IDS,
    IMGSZ,
    LOW_LIGHT_BOOST,
    MIN_TRACK_OBSERVATIONS,
    MIN_TRACK_TOTAL_CONF,
    NON_VEHICLE_IDS,
    PEDESTRIAN_CLASS_ID,
    PEDESTRIAN_DETECT_CONF,
    PEDESTRIAN_TRACK_ID_OFFSET,
    PEDESTRIAN_YOLO_MODEL,
    RTDETR_WEIGHTS,
    TRACKED_IDS,
    TRACKER_YAML,
    TWO_WHEELER_CLASS_IDS,
    VEHICLE_CLASS_NAMES,
    VEHICLE_IDS,
)
from ocr import normalize_plate, verifier as easyocr_verifier
from tasks_light import TrafficLightEngine
from tasks_speed import SpeedEngine
from tasks_transit import TransitEngine
from vlm import VLMRequest, VLMTask, pool as vlm_pool

logger = logging.getLogger("pipeline")


# ---------------------------------------------------------------------------
# Model singletons
# ---------------------------------------------------------------------------
_model: YOLO | None = None                 # vehicle detector (RT-DETR best.pt)
_pedestrian_model: YOLO | None = None      # secondary COCO detector (YOLO11n)
_clahe: Any = None


def get_model() -> YOLO:
    """RT-DETR vehicle detector. Kept as get_model() for backwards compat."""
    global _model
    if _model is None:
        logger.info("Loading RT-DETR weights: %s", RTDETR_WEIGHTS)
        _model = YOLO(RTDETR_WEIGHTS)
    return _model


def get_pedestrian_model() -> YOLO | None:
    """Optional YOLO11n for COCO person detection. best.pt has no person class
    so this runs in parallel to contribute pedestrian tracks. Returns None
    when ENABLE_PEDESTRIAN_DETECTOR=0 or the weights fail to load."""
    global _pedestrian_model
    if not ENABLE_PEDESTRIAN_DETECTOR:
        return None
    if _pedestrian_model is None:
        try:
            logger.info("Loading pedestrian YOLO weights: %s", PEDESTRIAN_YOLO_MODEL)
            _pedestrian_model = YOLO(PEDESTRIAN_YOLO_MODEL)
        except Exception as exc:
            logger.error(
                "Pedestrian detector load failed (%s) — pedestrian counts will be 0",
                exc,
            )
            _pedestrian_model = None
    return _pedestrian_model


def _get_clahe():
    global _clahe
    if _clahe is None:
        _clahe = cv2.createCLAHE(
            clipLimit=CLAHE_CLIP_LIMIT,
            tileGridSize=(CLAHE_GRID_SIZE, CLAHE_GRID_SIZE),
        )
    return _clahe


def _boost_low_light(frame: np.ndarray) -> np.ndarray:
    """Apply CLAHE to the L channel of LAB colour space. Lifts shadows
    without blowing out highlights. Enabled when LOW_LIGHT_BOOST=1.
    """
    lab = cv2.cvtColor(frame, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    l = _get_clahe().apply(l)
    return cv2.cvtColor(cv2.merge([l, a, b]), cv2.COLOR_LAB2BGR)


# ---------------------------------------------------------------------------
# Per-track bookkeeping
# ---------------------------------------------------------------------------
@dataclass
class TrackState:
    # class_id -> sum of detection confidences. Confidence-weighted so a single
    # high-confidence detection isn't drowned by many low-confidence ones.
    class_score: dict[int, float] = field(default_factory=dict)
    observation_count: int = 0               # number of sampled frames with a detection
    total_confidence: float = 0.0            # sum of all detection confidences
    best_crop: np.ndarray | None = None     # largest bbox seen for this track
    best_area: int = 0
    best_score: float = 0.0                  # area * conf — for VLM crop choice
    pending_vlm: list[Future] = field(default_factory=list)
    vlm_class_override: int | None = None   # from axle or reverify
    plate_text: str | None = None
    plate_source: str | None = None          # "gemma" / "easyocr" / "both"
    reverify_requested: bool = False
    axle_requested: bool = False
    plate_requested: bool = False
    # Tripwire crossing tracking (per-track Y history) — replaces module global.
    last_y: float | None = None
    # Polygon traversal: a track must be seen BOTH inside and outside the polygon
    # at some point to count as "crossed". Excludes cars waiting entirely inside
    # the polygon (e.g., at a red light). The legacy `polygon_seen` is True once
    # ever_inside_polygon fires — retained for VLM/trigger gating only.
    ever_inside_polygon: bool = False
    ever_outside_polygon: bool = False
    polygon_seen: bool = False

    def polygon_crossed(self) -> bool:
        return self.ever_inside_polygon and self.ever_outside_polygon

    def vote(self, class_id: int, confidence: float) -> None:
        self.class_score[class_id] = self.class_score.get(class_id, 0.0) + confidence
        self.observation_count += 1
        self.total_confidence += confidence

    def majority_class(self) -> int | None:
        if not self.class_score:
            return None
        return max(self.class_score.items(), key=lambda kv: kv[1])[0]

    def is_real_vehicle(self) -> bool:
        """Kill-filter for flash / phantom tracks that pollute the polygon-zone
        count. A real vehicle stays visible for at least a few sampled frames
        AND accumulates enough total confidence to justify a count."""
        return (
            self.observation_count >= MIN_TRACK_OBSERVATIONS
            and self.total_confidence >= MIN_TRACK_TOTAL_CONF
        )


# ---------------------------------------------------------------------------
# Operator-drawn IN/OUT segment counter
# ---------------------------------------------------------------------------
class SegmentCounter:
    """Two arbitrary line segments → segment-style vehicle counting.

    A track is counted exactly once when it crosses BOTH lines during the
    clip, regardless of order. Crossing order tags the direction
    (in→out vs out→in) so per-direction flow can still be reported. This
    rejects oscillating tracks near a single tripwire (which today inflate
    the count) and handles oblique camera angles where a horizontal
    tripwire would clip large swathes of the frame.

    Implementation note: we don't use `sv.LineZone` here because its API
    only exposes "did anyone cross this frame" by tracker_id and we need
    per-track BOTH-crossed bookkeeping. The geometric crossing test works
    on the per-detection bottom-center anchor, which is also what
    `sv.LineZone` uses by default.
    """

    def __init__(self, in_line: list[list[float]], out_line: list[list[float]]):
        self.in_p1 = (float(in_line[0][0]), float(in_line[0][1]))
        self.in_p2 = (float(in_line[1][0]), float(in_line[1][1]))
        self.out_p1 = (float(out_line[0][0]), float(out_line[0][1]))
        self.out_p2 = (float(out_line[1][0]), float(out_line[1][1]))

        # Per-track: last-seen anchor (used to detect crossings between samples)
        self._last_pt: dict[int, tuple[float, float]] = {}
        # Per-track sampled-frame index on first IN/OUT crossing (None until then)
        self.in_first_at: dict[int, int] = {}
        self.out_first_at: dict[int, int] = {}
        # Set of track_ids that have crossed BOTH lines (counted exactly once)
        self.crossed: set[int] = set()
        # Per-line raw crossing counters (any direction). Useful as a
        # diagnostic when the segment count seems low.
        self.in_crossings = 0
        self.out_crossings = 0

    @staticmethod
    def _segments_intersect(
        a1: tuple[float, float], a2: tuple[float, float],
        b1: tuple[float, float], b2: tuple[float, float],
    ) -> bool:
        """Standard 2-D segment intersection test using orientation signs.

        Returns True when segments [a1,a2] and [b1,b2] strictly cross or
        meet. Collinear-touching cases are accepted — for our use this
        only fires when an anchor lands exactly on the line, which is
        rare and harmless (the next sample disambiguates).
        """

        def orient(p, q, r) -> float:
            return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])

        o1 = orient(a1, a2, b1)
        o2 = orient(a1, a2, b2)
        o3 = orient(b1, b2, a1)
        o4 = orient(b1, b2, a2)
        if (o1 > 0) != (o2 > 0) and (o3 > 0) != (o4 > 0):
            return True
        # Collinear-on-segment: rare; accept to keep edge cases countable.
        if abs(o1) < 1e-9 and min(a1[0], a2[0]) <= b1[0] <= max(a1[0], a2[0]) \
           and min(a1[1], a2[1]) <= b1[1] <= max(a1[1], a2[1]):
            return True
        return False

    def update(self, tid: int, anchor: tuple[float, float], frame_idx: int) -> None:
        """Call once per detection per sampled frame with the bottom-center
        anchor. Records segment-line crossings transition-edge style — a
        crossing fires only when the segment from the previous anchor to
        the current anchor intersects the line."""
        prev = self._last_pt.get(tid)
        self._last_pt[tid] = anchor
        if prev is None:
            return

        if tid not in self.in_first_at and self._segments_intersect(
            prev, anchor, self.in_p1, self.in_p2,
        ):
            self.in_first_at[tid] = frame_idx
            self.in_crossings += 1
        if tid not in self.out_first_at and self._segments_intersect(
            prev, anchor, self.out_p1, self.out_p2,
        ):
            self.out_first_at[tid] = frame_idx
            self.out_crossings += 1

        if tid in self.in_first_at and tid in self.out_first_at:
            self.crossed.add(tid)

    def direction(self, tid: int) -> str | None:
        """'in_to_out' if the IN line was crossed first, 'out_to_in' otherwise.
        Returns None for tracks that haven't crossed both."""
        if tid not in self.crossed:
            return None
        in_at = self.in_first_at[tid]
        out_at = self.out_first_at[tid]
        return "in_to_out" if in_at <= out_at else "out_to_in"


# ---------------------------------------------------------------------------
# Main entry
# ---------------------------------------------------------------------------
def run_pipeline(video_path: str, calibration: Calibration) -> dict[str, Any]:
    t0 = time.time()
    model = get_model()
    pedestrian_model = get_pedestrian_model()

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"Failed to open video: {video_path}")

    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    # Mobile clients send normalized (0..1) coordinates because they don't
    # know the video resolution until upload completes. Convert in-place
    # before any engine reads pixel coords. No-op for pixel-space inputs.
    calibration.resolve_ratio_coords(w, h)
    logger.info(
        "Video: %dx%d @ %.1f fps, %d frames; tasks=%s",
        w, h, fps, total_frames, sorted(calibration.tasks_enabled),
    )

    # --- Counting: polygon zone is canonical when provided (handles turns);
    # the horizontal LineZone always runs as a directional signal (in vs out).
    # When the operator supplies an arbitrary IN/OUT line pair, the
    # SegmentCounter takes over from the horizontal tripwire — a track is
    # counted only when it crosses BOTH lines.
    tripwire_y = int(h * calibration.tripwire.y_ratio)
    count_line = sv.LineZone(
        start=sv.Point(0, tripwire_y), end=sv.Point(w, tripwire_y)
    )
    segment_counter: SegmentCounter | None = None
    if calibration.count_lines is not None:
        segment_counter = SegmentCounter(
            in_line=calibration.count_lines.in_line,
            out_line=calibration.count_lines.out_line,
        )
        logger.info(
            "Using operator-drawn IN/OUT segment counter (in=%s, out=%s)",
            calibration.count_lines.in_line, calibration.count_lines.out_line,
        )
    intersection_zone: sv.PolygonZone | None = None
    if calibration.intersection_polygon is not None:
        intersection_zone = sv.PolygonZone(
            polygon=np.array(calibration.intersection_polygon.polygon, dtype=np.int32),
            triggering_anchors=(sv.Position.BOTTOM_CENTER,),
        )

    # --- Optional engines ---
    speed_engine: SpeedEngine | None = None
    if calibration.wants("speed") and calibration.speed is not None:
        speed_engine = SpeedEngine(cfg=calibration.speed, fps=fps, frame_w=w, frame_h=h)

    # --- Class-annotated MP4 writer (independent of transit's own video) ---
    classified_writer: cv2.VideoWriter | None = None
    classified_output_path: str | None = None
    box_annotator: sv.BoxAnnotator | None = None
    label_annotator: sv.LabelAnnotator | None = None
    if calibration.output_video:
        src = os.fspath(video_path)
        base, _ext = os.path.splitext(src)
        classified_output_path = f"{base}_classified.mp4"
        sampled_fps = max(1.0, fps / FRAME_SKIP)
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        classified_writer = cv2.VideoWriter(
            classified_output_path, fourcc, sampled_fps, (w, h),
        )
        if not classified_writer.isOpened():
            logger.warning(
                "classified VideoWriter failed to open %s — output disabled",
                classified_output_path,
            )
            classified_writer = None
            classified_output_path = None
        else:
            box_annotator = sv.BoxAnnotator(
                color=sv.ColorPalette.DEFAULT, thickness=2,
            )
            label_annotator = sv.LabelAnnotator(
                color=sv.ColorPalette.DEFAULT, text_scale=0.5, text_thickness=1,
            )
            logger.info(
                "Writing class-annotated video to %s @ %.1f fps",
                classified_output_path, sampled_fps,
            )

    transit_engine: TransitEngine | None = None
    transit_writer: cv2.VideoWriter | None = None
    transit_output_path: str | None = None
    if calibration.wants("transit") and calibration.transit is not None:
        transit_engine = TransitEngine(cfg=calibration.transit, frame_w=w, frame_h=h)
        if calibration.transit.output_video:
            # Write annotated frames at the sampled-frame rate so the output
            # video stays in sync with the analytics cadence.
            src = os.fspath(video_path)
            base, _ext = os.path.splitext(src)
            transit_output_path = f"{base}_annotated.mp4"
            sampled_fps = max(1.0, fps / FRAME_SKIP)
            fourcc = cv2.VideoWriter_fourcc(*"mp4v")
            transit_writer = cv2.VideoWriter(
                transit_output_path, fourcc, sampled_fps, (w, h),
            )
            if not transit_writer.isOpened():
                logger.warning(
                    "Transit VideoWriter failed to open %s — output disabled",
                    transit_output_path,
                )
                transit_writer = None
                transit_output_path = None
            else:
                logger.info(
                    "Writing annotated transit video to %s @ %.1f fps",
                    transit_output_path, sampled_fps,
                )

    light_engine: TrafficLightEngine | None = None
    if calibration.wants("traffic_light") and calibration.traffic_light is not None:
        light_engine = TrafficLightEngine(cfg=calibration.traffic_light)

    # --- Per-track state ---
    tracks: dict[int, TrackState] = defaultdict(TrackState)
    crossings: dict[int, int] = {}  # track_id → majority class at crossing time
    # Side-channel for VLM calls that don't belong to any single track:
    # ambiguous LIGHT_STATE samples and bus-stop DENSITY_CHECK overrides.
    # Each entry is (kind, future, context). Drained alongside the per-track
    # futures after the decode loop so the VLM verdict actually reaches the
    # report (was previously dropped on the floor — see _apply_aux_vlm).
    pending_aux_vlm: list[tuple[str, Future, dict]] = []

    # When the operator turned off the `vehicles` task entirely (e.g.
    # bus-stop scenario with only pedestrians + transit enabled), skip
    # the count-line + classification + VLM-class-reverify work even
    # though the vehicle detector still runs (transit/speed/lpr need it
    # for bus / vehicle tracking).
    count_vehicles = calibration.wants("vehicles")

    # --- Loop ---
    frame_idx = 0
    sampled = 0
    while cap.isOpened():
        ok, frame = cap.read()
        if not ok:
            break
        frame_idx += 1
        if frame_idx % FRAME_SKIP != 0:
            continue
        sampled += 1
        timestamp_s = frame_idx / fps

        if LOW_LIGHT_BOOST:
            frame = _boost_low_light(frame)

        # Vehicle detector (RT-DETR): all classes in TRACKED_IDS.
        vehicle_results = model.track(
            source=frame,
            imgsz=IMGSZ,
            persist=True,
            conf=DETECT_CONF,
            tracker=TRACKER_YAML,
            verbose=False,
        )[0]

        # Pedestrian detector (YOLO11n): COCO class 0 only. Runs a separate
        # tracker state; we shift tracker_ids so they can't collide with the
        # vehicle tracker's tids in the merged Detections object.
        ped_results = None
        if pedestrian_model is not None:
            ped_results = pedestrian_model.track(
                source=frame,
                imgsz=IMGSZ,
                persist=True,
                conf=PEDESTRIAN_DETECT_CONF,
                classes=[0],                    # COCO person only
                tracker=TRACKER_YAML,
                verbose=False,
            )[0]

        parts: list[sv.Detections] = []
        if vehicle_results.boxes.id is not None:
            v = sv.Detections.from_ultralytics(vehicle_results)
            v = v[np.isin(v.class_id, list(TRACKED_IDS))]
            if len(v) > 0:
                parts.append(v)

        if ped_results is not None and ped_results.boxes.id is not None:
            p = sv.Detections.from_ultralytics(ped_results)
            if len(p) > 0:
                # Remap COCO class 0 (person) → our unified PEDESTRIAN_CLASS_ID.
                p.class_id = np.full_like(p.class_id, PEDESTRIAN_CLASS_ID)
                # Namespace-shift pedestrian tids away from vehicle tids.
                if p.tracker_id is not None:
                    p.tracker_id = p.tracker_id + PEDESTRIAN_TRACK_ID_OFFSET
                parts.append(p)

        if not parts:
            _maybe_light_sample(
                light_engine, frame, timestamp_s, pending_aux_vlm=pending_aux_vlm,
            )
            continue

        detections = sv.Detections.merge(parts) if len(parts) > 1 else parts[0]
        if len(detections) == 0:
            _maybe_light_sample(
                light_engine, frame, timestamp_s, pending_aux_vlm=pending_aux_vlm,
            )
            continue

        # --- Run engines that consume the full Detections set ---
        # Tripwire LineZone is the directional in/out signal kept for
        # diagnostic parity with previous reports; the segment counter
        # (when set) is the canonical source of vehicle counts.
        if count_vehicles:
            count_line.trigger(detections)
        polygon_mask = (
            intersection_zone.trigger(detections=detections)
            if intersection_zone is not None and count_vehicles
            else None
        )
        if speed_engine is not None:
            speed_engine.update(detections, frame_idx=frame_idx)
        if transit_engine is not None:
            transit_engine.update(detections, timestamp_s=timestamp_s)
            if transit_writer is not None:
                transit_writer.write(transit_engine.annotate_frame(frame, detections))
        _maybe_light_sample(
            light_engine, frame, timestamp_s,
            transit=transit_engine, pending_aux_vlm=pending_aux_vlm,
        )

        # --- Class-annotated video (tracked bboxes + MOLIT labels) ---
        # Skip when vehicles task is off — operator doesn't want a count,
        # so a frame full of vehicle bboxes is just visual noise.
        if count_vehicles and classified_writer is not None \
           and box_annotator is not None and label_annotator is not None:
            classified_writer.write(
                _annotate_classification_frame(
                    frame, detections, box_annotator, label_annotator,
                    frame_idx, total_frames, tripwire_y,
                    calibration.intersection_polygon,
                    segment_counter=segment_counter,
                )
            )

        # --- Per-detection bookkeeping + VLM triggers ---
        xyxy = detections.xyxy
        tracker_ids = detections.tracker_id
        class_ids = detections.class_id
        confidences = detections.confidence if detections.confidence is not None \
            else np.ones(len(detections))

        for i in range(len(detections)):
            tid = int(tracker_ids[i])
            cls = int(class_ids[i])
            conf = float(confidences[i])
            x1, y1, x2, y2 = [int(v) for v in xyxy[i]]
            area = max(0, x2 - x1) * max(0, y2 - y1)

            state = tracks[tid]
            state.vote(cls, conf)

            # Keep the highest area*confidence crop — sharper than "biggest".
            crop_score = area * conf
            if crop_score > state.best_score:
                pad = 20
                crop = frame[
                    max(0, y1 - pad):min(h, y2 + pad),
                    max(0, x1 - pad):min(w, x2 + pad),
                ]
                if crop.size > 0:
                    state.best_crop = crop.copy()
                    state.best_area = area
                    state.best_score = crop_score

            # --- Polygon boundary crossing → canonical count ---
            # A track must be observed both INSIDE and OUTSIDE the polygon to
            # count. This discards cars that are visible inside the polygon the
            # whole clip (waiting at a red light, parked, etc.) and keeps cars
            # that actually entered or exited the intersection during the video.
            if polygon_mask is not None:
                in_polygon = bool(polygon_mask[i])
                if in_polygon:
                    state.ever_inside_polygon = True
                    state.polygon_seen = True
                else:
                    state.ever_outside_polygon = True

            # --- Operator-drawn IN/OUT segment counter ---
            # Use the bottom-center anchor (matches sv.LineZone default).
            # Crossing both lines locks in the track's class vote — same
            # semantics as the legacy tripwire snapshot.
            if segment_counter is not None and count_vehicles:
                anchor = ((x1 + x2) / 2.0, float(y2))
                already_crossed = tid in segment_counter.crossed
                segment_counter.update(tid, anchor, frame_idx)
                just_crossed = (
                    not already_crossed and tid in segment_counter.crossed
                )
            else:
                # --- Legacy tripwire (horizontal line) — direction signal +
                # crossing-event trigger when no segment lines are configured.
                y_center = (y1 + y2) / 2
                just_crossed = (
                    count_vehicles
                    and _just_crossed_local(state, y_center, tripwire_y)
                )

            if just_crossed:
                # Freeze the vehicle's class vote at crossing time.
                maj = state.majority_class() or cls
                crossings[tid] = maj

                if maj in HEAVY_TRUCK_IDS and not state.axle_requested \
                   and state.best_crop is not None and vlm_pool.is_available():
                    state.axle_requested = True
                    fut = vlm_pool.submit(VLMRequest(
                        task=VLMTask.AXLE_CHECK,
                        image=state.best_crop,
                        context={},
                        track_id=tid,
                    ))
                    state.pending_vlm.append(fut)

                # --- Trigger C: plate OCR (Task 5, if enabled) ---
                if calibration.lpr.enabled and maj in VEHICLE_IDS \
                   and not state.plate_requested and state.best_crop is not None \
                   and vlm_pool.is_available():
                    state.plate_requested = True
                    fut = vlm_pool.submit(VLMRequest(
                        task=VLMTask.PLATE_OCR,
                        image=state.best_crop,
                        context={},
                        track_id=tid,
                    ))
                    state.pending_vlm.append(fut)

            # --- Trigger B: class re-verify for EVERY vehicle track ---
            # Was previously gated on mid-band confidence [0.35, 0.60]. That
            # missed the biggest classification error source: high-confidence
            # detections that are still wrong (e.g., small_bus detected as
            # small_truck). Now we give every tracked vehicle exactly ONE VLM
            # classification pass — gated by `reverify_requested` for dedup
            # and by `observation_count >= 3` so best_crop is actually the
            # best-seen crop (not the first noisy detection). Heavy trucks
            # still take the axle-check path (richer prompt). Skipped when
            # the operator turned off the vehicles task entirely.
            if count_vehicles \
               and cls in VEHICLE_IDS \
               and not state.reverify_requested \
               and not state.axle_requested \
               and state.observation_count >= 3 \
               and state.best_crop is not None \
               and vlm_pool.is_available():
                state.reverify_requested = True
                fut = vlm_pool.submit(VLMRequest(
                    task=VLMTask.CLASS_REVERIFY,
                    image=state.best_crop,
                    context={
                        "detected_id": cls,
                        "detected_name": ALL_CLASS_NAMES.get(cls, f"id_{cls}"),
                    },
                    track_id=tid,
                ))
                state.pending_vlm.append(fut)

            # --- Trigger D: bus-stop density near capacity → VLM headcount ---
            # (Handled in _maybe_light_sample helper where we have transit_engine.)

    cap.release()
    if transit_writer is not None:
        transit_writer.release()
    if classified_writer is not None:
        classified_writer.release()

    # --- Drain VLM futures ---
    logger.info("Draining VLM pending calls...")
    _apply_vlm_results(tracks, light_engine)
    _apply_aux_vlm(pending_aux_vlm, light_engine, transit_engine)

    # --- Build report ---
    elapsed = time.time() - t0
    report = _build_report(
        tracks=tracks,
        crossings=crossings,
        count_line=count_line,
        intersection_zone_used=intersection_zone is not None,
        segment_counter=segment_counter,
        count_vehicles=count_vehicles,
        speed_engine=speed_engine,
        transit_engine=transit_engine,
        transit_output_path=transit_output_path,
        light_engine=light_engine,
        calibration=calibration,
        classified_output_path=classified_output_path,
        elapsed_s=elapsed,
        frames_total=total_frames,
        frames_sampled=sampled,
        fps=fps,
    )
    logger.info(
        "Pipeline done in %.1fs (%.1fx realtime). Vehicles: %d",
        elapsed, (total_frames / fps) / elapsed if elapsed else 0,
        report["totals"]["vehicles"],
    )
    return report


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _annotate_classification_frame(
    frame: np.ndarray,
    detections: sv.Detections,
    box_ann: sv.BoxAnnotator,
    label_ann: sv.LabelAnnotator,
    frame_idx: int,
    total_frames: int,
    tripwire_y: int,
    intersection_polygon_cfg: Any,
    segment_counter: "SegmentCounter | None" = None,
) -> np.ndarray:
    """Draw bboxes + MOLIT class labels + HUD on the sampled frame.

    When `segment_counter` is provided, the operator's IN/OUT lines are
    drawn (green = IN, red = OUT) and the legacy horizontal tripwire is
    suppressed — drawing both would be visually confusing for a non-
    horizontal site setup.
    """
    h, w = frame.shape[:2]
    out = frame.copy()

    if len(detections) > 0:
        labels: list[str] = []
        for i in range(len(detections)):
            tid = int(detections.tracker_id[i]) if detections.tracker_id is not None else -1
            cls = int(detections.class_id[i]) if detections.class_id is not None else -1
            conf = float(detections.confidence[i]) if detections.confidence is not None else 0.0
            name = ALL_CLASS_NAMES.get(cls, f"id_{cls}")
            labels.append(f"#{tid} {name} {conf:.2f}")
        out = box_ann.annotate(scene=out, detections=detections)
        out = label_ann.annotate(scene=out, detections=detections, labels=labels)

    if segment_counter is not None:
        # Operator-drawn IN (green) + OUT (red) line vectors.
        in_p1 = (int(segment_counter.in_p1[0]), int(segment_counter.in_p1[1]))
        in_p2 = (int(segment_counter.in_p2[0]), int(segment_counter.in_p2[1]))
        out_p1 = (int(segment_counter.out_p1[0]), int(segment_counter.out_p1[1]))
        out_p2 = (int(segment_counter.out_p2[0]), int(segment_counter.out_p2[1]))
        cv2.line(out, in_p1, in_p2, (0, 200, 0), 2, cv2.LINE_AA)
        cv2.line(out, out_p1, out_p2, (0, 0, 200), 2, cv2.LINE_AA)
        cv2.putText(out, "IN", in_p1, cv2.FONT_HERSHEY_SIMPLEX,
                    0.6, (0, 200, 0), 2, cv2.LINE_AA)
        cv2.putText(out, "OUT", out_p1, cv2.FONT_HERSHEY_SIMPLEX,
                    0.6, (0, 0, 200), 2, cv2.LINE_AA)
    else:
        # Legacy horizontal tripwire (stays for sites with no editor pass).
        cv2.line(out, (0, tripwire_y), (w, tripwire_y), (0, 0, 255), 1, cv2.LINE_AA)

    # Intersection polygon outline
    if intersection_polygon_cfg is not None:
        poly = np.array(intersection_polygon_cfg.polygon, dtype=np.int32)
        cv2.polylines(out, [poly], True, (0, 255, 255), 2, cv2.LINE_AA)

    # HUD — frame count at the top
    hud_h = 32
    cv2.rectangle(out, (0, 0), (w, hud_h), (0, 0, 0), -1)
    cv2.putText(
        out,
        f"frame {frame_idx}/{total_frames}  detections={len(detections)}",
        (10, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2,
    )
    return out


def _observation_histogram(tracks: dict[int, "TrackState"], counted: list[int]) -> dict[str, int]:
    """Bucketed observation counts for the counted tracks — tells us whether
    overcount is coming from many short tracks (ID switching) or few long ones
    (over-detection). Buckets roughly in 1-second multiples at 12.5 Hz sample rate."""
    buckets = {"1-4": 0, "5-12": 0, "13-24": 0, "25-49": 0, "50+": 0}
    for tid in counted:
        n = tracks[tid].observation_count
        if n < 5:
            buckets["1-4"] += 1
        elif n < 13:
            buckets["5-12"] += 1
        elif n < 25:
            buckets["13-24"] += 1
        elif n < 50:
            buckets["25-49"] += 1
        else:
            buckets["50+"] += 1
    return buckets


def _just_crossed_local(state: TrackState, y_center: float, wire_y: int) -> bool:
    """Per-track tripwire crossing test.

    State lives on the TrackState (not a module global) — the previous version
    used a process-wide dict that leaked Y values across video uploads, causing
    phantom crossings on the very first frame of follow-up jobs.
    """
    old = state.last_y
    state.last_y = y_center
    if old is None:
        return False
    return (old < wire_y <= y_center) or (old > wire_y >= y_center)


def _maybe_light_sample(
    light: TrafficLightEngine | None,
    frame: np.ndarray,
    timestamp_s: float,
    transit: TransitEngine | None = None,
    pending_aux_vlm: list[tuple[str, Future, dict]] | None = None,
) -> None:
    if light is not None:
        state, ambiguous = light.update(frame, timestamp_s)
        if ambiguous is not None and vlm_pool.is_available():
            fut = vlm_pool.submit(VLMRequest(
                task=VLMTask.LIGHT_STATE,
                image=ambiguous,
                context={"timestamp_s": timestamp_s},
            ))
            if pending_aux_vlm is not None:
                pending_aux_vlm.append(("light", fut, {"t": timestamp_s}))
    if transit is not None and transit.near_capacity() and vlm_pool.is_available():
        # Density sanity check fires at most once per ~minute of video.
        # We piggyback on the polygon itself via a bounding-rect crop.
        poly = np.array(transit.cfg.stop_polygon)
        x, y, w, h = cv2.boundingRect(poly.astype(np.int32))
        crop = frame[max(0, y):y + h, max(0, x):x + w]
        if crop.size > 0:
            fut = vlm_pool.submit(VLMRequest(
                task=VLMTask.DENSITY_CHECK,
                image=crop,
                context={"timestamp_s": timestamp_s, "reported_count": transit.peak_count},
            ))
            if pending_aux_vlm is not None:
                pending_aux_vlm.append(("density", fut, {"t": timestamp_s}))


def _apply_vlm_results(
    tracks: dict[int, TrackState],
    light: TrafficLightEngine | None,
) -> None:
    for tid, state in tracks.items():
        for fut in state.pending_vlm:
            try:
                result = fut.result(timeout=30)
            except Exception as exc:
                logger.warning("VLM future failed for track %s: %s", tid, exc)
                continue
            if result is None:
                continue

            if "molit_class_id" in result:
                # Axle check or class reverify
                conf = float(result.get("confidence", 0.0))
                if conf > 0.80:
                    state.vlm_class_override = int(result["molit_class_id"])

            if result.get("plate_found") and result.get("plate_text"):
                state.plate_text = normalize_plate(result["plate_text"])
                state.plate_source = "gemma"
                # Secondary EasyOCR pass on the Gemma-returned plate region
                bbox = result.get("plate_bbox_xyxy")
                if bbox and state.best_crop is not None and len(bbox) == 4:
                    px1, py1, px2, py2 = [max(0, int(v)) for v in bbox]
                    px2 = min(state.best_crop.shape[1], px2)
                    py2 = min(state.best_crop.shape[0], py2)
                    if px2 > px1 and py2 > py1:
                        plate_crop = state.best_crop[py1:py2, px1:px2]
                        easy = easyocr_verifier.read(plate_crop)
                        if easy and easy.get("plate_text"):
                            if easy["plate_text"] == state.plate_text:
                                state.plate_source = "both"
                            elif easy.get("confidence", 0.0) > 0.75:
                                # Disagreement at high EasyOCR confidence — keep both.
                                state.plate_source = f"gemma:{state.plate_text}|easyocr:{easy['plate_text']}"


def _apply_aux_vlm(
    pending_aux_vlm: list[tuple[str, Future, dict]],
    light: TrafficLightEngine | None,
    transit: TransitEngine | None,
) -> None:
    """Drain side-channel VLM futures (LIGHT_STATE, DENSITY_CHECK).

    Per-track VLM futures are handled by ``_apply_vlm_results``; this
    function handles VLM calls that don't belong to a single track and
    were previously submitted-and-forgotten. Failures are logged and
    swallowed so a Vertex hiccup never tanks the whole job.
    """
    light_corrections = 0
    density_corrections = 0
    for kind, fut, ctx in pending_aux_vlm:
        try:
            result = fut.result(timeout=30)
        except Exception as exc:
            logger.warning("Aux VLM %s future failed: %s", kind, exc)
            continue
        if not result:
            continue

        if kind == "light" and light is not None:
            state = result.get("state")
            conf = float(result.get("confidence", 0.0))
            if state in ("red", "yellow", "green") and conf >= 0.6:
                light.apply_vlm_correction(float(ctx.get("t", 0.0)), state)
                light_corrections += 1

        elif kind == "density" and transit is not None:
            count = result.get("person_count")
            conf = float(result.get("confidence", 0.0))
            if isinstance(count, (int, float)) and conf >= 0.5:
                transit.apply_vlm_density_correction(
                    float(ctx.get("t", 0.0)), int(count),
                )
                density_corrections += 1

    if pending_aux_vlm:
        logger.info(
            "Aux VLM applied: %d light corrections, %d density corrections (of %d submitted)",
            light_corrections, density_corrections, len(pending_aux_vlm),
        )


def _build_report(
    *,
    tracks: dict[int, TrackState],
    crossings: dict[int, int],
    count_line: sv.LineZone,
    intersection_zone_used: bool,
    segment_counter: SegmentCounter | None,
    count_vehicles: bool,
    speed_engine: SpeedEngine | None,
    transit_engine: TransitEngine | None,
    transit_output_path: str | None,
    light_engine: TrafficLightEngine | None,
    calibration: Calibration,
    classified_output_path: str | None,
    elapsed_s: float,
    frames_total: int,
    frames_sampled: int,
    fps: float,
) -> dict[str, Any]:

    # ----- Decide which tracks to count and what class to assign each -----
    # Counting precedence:
    #   1. Operator-drawn IN/OUT segment counter (if configured) — canonical
    #      for sites with a per-camera-angle line setup.
    #   2. Intersection polygon (if calibrated) — handles 3G/4G turns.
    #   3. Legacy tripwire crossings.
    # When the operator turned the `vehicles` task off entirely (e.g.
    # bus-stop scenario), we skip vehicle counting altogether and the
    # report carries a zero count + an empty breakdown.
    if not count_vehicles:
        candidate_tids: list[int] = []
        inside_only = 0
        counting_method = "disabled"
    elif segment_counter is not None:
        candidate_tids = list(segment_counter.crossed)
        inside_only = 0
        counting_method = "segment_lines"
    elif intersection_zone_used:
        candidate_tids = [tid for tid, st in tracks.items() if st.polygon_crossed()]
        inside_only = sum(
            1 for st in tracks.values()
            if st.ever_inside_polygon and not st.ever_outside_polygon
        )
        logger.info(
            "Polygon traversal: %d crossed, %d inside-only excluded (likely waiting traffic)",
            len(candidate_tids), inside_only,
        )
        counting_method = "intersection_polygon"
    else:
        candidate_tids = list(crossings.keys())
        inside_only = 0
        counting_method = "tripwire"

    # Filter flash/phantom tracks (ByteTrack ID-switch noise, transient false
    # positives). Without this, the polygon-zone count inflates ~2× on noisy
    # or low-light footage because every track fragment is counted as a
    # separate vehicle.
    filtered_out = 0
    countable_tids: list[int] = []
    for tid in candidate_tids:
        if tracks[tid].is_real_vehicle():
            countable_tids.append(tid)
        else:
            filtered_out += 1
    if filtered_out:
        logger.info(
            "Filtered %d phantom/flash tracks (min_obs=%d, min_conf=%.2f); kept %d",
            filtered_out, MIN_TRACK_OBSERVATIONS, MIN_TRACK_TOTAL_CONF, len(countable_tids),
        )

    final_class: dict[int, int] = {}
    for tid in countable_tids:
        state = tracks[tid]
        # Prefer VLM override → confidence-weighted majority → tripwire snapshot
        if state.vlm_class_override is not None:
            final_class[tid] = state.vlm_class_override
        elif state.class_score:
            final_class[tid] = state.majority_class()  # type: ignore[assignment]
        elif tid in crossings:
            final_class[tid] = crossings[tid]

    vehicle_breakdown: Counter = Counter()
    pedestrians = 0
    bicycles = 0
    motorcycles = 0
    personal_mobility = 0
    for tid, cls in final_class.items():
        if cls in VEHICLE_CLASS_NAMES:
            vehicle_breakdown[VEHICLE_CLASS_NAMES[cls]] += 1
        elif cls == PEDESTRIAN_CLASS_ID:
            pedestrians += 1
        elif cls == 1:
            bicycles += 1
        elif cls == 15:
            motorcycles += 1
        elif cls == 16:
            personal_mobility += 1

    totals = {
        "vehicles": sum(1 for c in final_class.values() if c in VEHICLE_IDS),
        "pedestrians": pedestrians,
        "bicycles": bicycles,
        "motorcycles": motorcycles,
        "personal_mobility": personal_mobility,
    }

    # 2-wheeler breakdown — structured for the mobile UI. Keys mirror the
    # VEHICLE_BREAKDOWN style (class name → count) for consistent rendering.
    two_wheeler_breakdown: dict[str, int] = {}
    if bicycles:
        two_wheeler_breakdown["Bicycle"] = bicycles
    if motorcycles:
        two_wheeler_breakdown["Motorcycle"] = motorcycles
    if personal_mobility:
        two_wheeler_breakdown["Personal Mobility"] = personal_mobility

    breakdown_dict = dict(vehicle_breakdown)

    report: dict[str, Any] = {
        # Legacy keys — kept for the Flutter mobile parser, which falls back to
        # a flat-map scan if 'breakdown' is missing and would otherwise pick up
        # any stray top-level number (e.g. finished_at) as a "class count".
        # Do NOT remove without coordinating a mobile release.
        "total_vehicles_counted": totals["vehicles"],
        "breakdown": breakdown_dict,
        # New structured fields:
        "totals": totals,
        "vehicle_breakdown": breakdown_dict,
        "two_wheeler_breakdown": two_wheeler_breakdown,
        "counting": {
            "method": counting_method,
            "unique_tracks_counted": len(final_class),
            "candidate_tracks": len(tracks),
            "polygon_inside_only_excluded": inside_only,
            "observation_hist": _observation_histogram(tracks, countable_tids),
            "tripwire_crossings_in": count_line.in_count,
            "tripwire_crossings_out": count_line.out_count,
            **(
                {
                    "in_line_crossings": segment_counter.in_crossings,
                    "out_line_crossings": segment_counter.out_crossings,
                    "segment_counted": len(segment_counter.crossed),
                }
                if segment_counter is not None else {}
            ),
        },
        "meta": {
            "frames_total": frames_total,
            "frames_sampled": frames_sampled,
            "fps": round(fps, 2),
            "elapsed_s": round(elapsed_s, 2),
            "tasks_enabled": sorted(calibration.tasks_enabled),
        },
    }

    if classified_output_path:
        report["annotated_video"] = classified_output_path
    if speed_engine is not None:
        report["speed"] = speed_engine.report()
    if transit_engine is not None:
        report["transit"] = transit_engine.report(annotated_video_path=transit_output_path)
    if light_engine is not None:
        report["traffic_light"] = light_engine.report()
    if calibration.lpr.enabled:
        from ocr import classify_plate, hash_plate, normalize_plate

        plates: dict[str, dict[str, Any]] = {}
        resident_count = 0
        visitor_count = 0
        for tid, s in tracks.items():
            if not s.plate_text:
                continue
            norm = normalize_plate(s.plate_text)
            category = classify_plate(norm, calibration.lpr.allowlist)
            record: dict[str, Any] = {
                "source": s.plate_source,
                "category": category,
            }
            # Privacy toggle: store SHA-256 prefix instead of raw text.
            if calibration.lpr.hash_plates:
                record["text_hash"] = hash_plate(norm)
            else:
                record["text"] = norm
            plates[str(tid)] = record
            if category == "resident":
                resident_count += 1
            elif category == "visitor":
                visitor_count += 1
        report["plates"] = plates
        report["plate_summary"] = {
            "resident": resident_count,
            "visitor": visitor_count,
            "total": len(plates),
            "privacy_hashed": calibration.lpr.hash_plates,
            "allowlist_size": len(calibration.lpr.allowlist),
        }

    return report
