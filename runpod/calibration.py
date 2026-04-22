"""Per-site calibration loader.

Clients POST an optional multipart ``calibration`` field containing JSON with
the shape below. Missing sections → that analytic skips gracefully so Task 1
(counting) keeps working for callers who don't provide calibration.

{
  "tasks_enabled": ["vehicles","pedestrians","speed","lpr","transit","traffic_light"],
  "tripwire": {"y_ratio": 0.60},
  "speed": {
    "source_quad": [[x,y],[x,y],[x,y],[x,y]],
    "real_world_m": {"width": 3.5, "length": 20.0},
    "lines_y_ratio": [0.45, 0.75]
  },
  "transit": {
    "stop_polygon": [[x,y],...],
    "max_capacity": 30,
    "doors": [{"line": [[x,y],[x,y]]}]
  },
  "traffic_light": {"roi": [x, y, w, h]},
  "lpr": {"enabled": true, "residential_only": true}
}
"""
from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from typing import Any

logger = logging.getLogger("calibration")

DEFAULT_TASKS = ("vehicles", "pedestrians")
ALL_TASKS = (
    "vehicles", "pedestrians", "speed", "lpr", "transit", "traffic_light"
)


@dataclass
class TripwireCfg:
    y_ratio: float = 0.60


@dataclass
class CountLinesCfg:
    """Operator-drawn IN/OUT line pair for segment-style vehicle counting.

    Each line is a 2-point segment ``[[x, y], [x, y]]`` in image-space.
    Coordinates may be normalized (0..1) or pixel — `resolve_ratio_coords`
    detects and rescales the former at video-load time, same convention as
    the polygons.

    Semantics: a vehicle counts as one only if its track crosses BOTH lines
    during the clip (in either order). Crossing order tags the direction
    (in→out vs out→in). This avoids the overcount you get from a single
    tripwire when vehicles oscillate near the line, and gives more
    accurate per-direction flow on oblique camera angles than the legacy
    horizontal tripwire.
    """
    in_line: list[list[float]]
    out_line: list[list[float]]


@dataclass
class IntersectionPolygonCfg:
    """Counts each unique track that ever enters the polygon as one vehicle.

    For 3-/4-way intersections this captures vehicles that turn (and never
    cross a constant-Y tripwire). The horizontal tripwire stays as a fallback
    direction signal — both can coexist.
    """
    polygon: list[list[float]]


@dataclass
class SpeedCfg:
    source_quad: list[list[float]]           # 4 image-space points
    real_world_m: dict[str, float]           # {"width": m, "length": m}
    lines_y_ratio: list[float]               # 2 entries, both in [0,1]
    # Optional operator-drawn 2-point lines (each ``[[x, y], [x, y]]`` in
    # image-space ratio or pixel coords). When set, the SpeedEngine uses
    # these as arbitrary line vectors instead of synthesising horizontal
    # lines from `lines_y_ratio`. The y-ratio fallback is kept so legacy
    # calibration JSON keeps working without migration.
    lines_xy: list[list[list[float]]] | None = None


@dataclass
class TransitCfg:
    stop_polygon: list[list[float]]
    max_capacity: int
    doors: list[dict[str, Any]]
    # Optional polygon delimiting where a BUS parks at the stop. When set,
    # door-line boarding/alighting counts only advance while a bus detection
    # (vehicle class 6, MOLIT Class 2) overlaps this polygon — prevents
    # passers-by from inflating transit counts between bus arrivals.
    bus_zone_polygon: list[list[float]] | None = None
    # Opt-in annotated MP4 output (head circles + boarding/alighting tags).
    # Written alongside the input video with an `_annotated.mp4` suffix.
    output_video: bool = False


@dataclass
class TrafficLightEntry:
    """One traffic light head. A scene can have several (e.g. main + left-turn
    + pedestrian). Each is tracked by its own HSV state machine."""
    roi: list[int]                           # [x, y, w, h]
    label: str = "main"


@dataclass
class TrafficLightCfg:
    """Holds one or more TrafficLightEntry. Kept as a wrapper rather than a
    bare list so future per-site options (e.g. daylight HSV range override)
    have a natural home."""
    lights: list[TrafficLightEntry] = field(default_factory=list)

    @property
    def roi(self) -> list[int]:
        """Back-compat alias for code still reading the singular roi."""
        return self.lights[0].roi if self.lights else []


@dataclass
class LprCfg:
    enabled: bool = False
    residential_only: bool = True
    # Inline resident plate list. Each entry is a Korean plate string that will
    # be normalized (whitespace stripped, canonicalised to "NN가NNNN" shape) on
    # load, so variations like "12 가 3456" still match.
    allowlist: list[str] = field(default_factory=list)
    # Indirection for future Supabase / external storage. Only "inline" works
    # today — other values mean "fetch from source but fall back to `allowlist`
    # if the fetch isn't implemented yet".
    allowlist_source: str = "inline"
    # Privacy: when true, the emitted per-plate record stores a SHA-256 prefix
    # instead of the raw plate text. Category (resident/visitor) is still
    # computed from the normalized plate BEFORE hashing, so the allowlist
    # match is unaffected.
    hash_plates: bool = False


@dataclass
class Calibration:
    tasks_enabled: set[str] = field(default_factory=lambda: set(DEFAULT_TASKS))
    tripwire: TripwireCfg = field(default_factory=TripwireCfg)
    count_lines: CountLinesCfg | None = None
    intersection_polygon: IntersectionPolygonCfg | None = None
    speed: SpeedCfg | None = None
    transit: TransitCfg | None = None
    traffic_light: TrafficLightCfg | None = None
    lpr: LprCfg = field(default_factory=LprCfg)
    # Top-level class-annotated video output — independent of transit.output_video
    # (which has different overlays). When True, the pipeline writes
    # <input>_classified.mp4 with bboxes + MOLIT class labels on every detection.
    output_video: bool = False

    def wants(self, task: str) -> bool:
        return task in self.tasks_enabled

    # ------------------------------------------------------------------
    # Auto-calibration predicates — used by ``runpod.auto_calibration`` to
    # decide whether to ask the VLM for layout geometry. The mobile client's
    # "auto" mode submits a transit/traffic_light block with ONLY scalar
    # config (max_capacity, label) and omits geometry; that arrives here as
    # an instance with empty polygons / a placeholder ROI, which these
    # predicates flag as eligible for VLM auto-fill.
    # ------------------------------------------------------------------
    def transit_needs_autofill(self) -> bool:
        if not self.wants("transit") or self.transit is None:
            return False
        return (
            len(self.transit.stop_polygon) < 3
            or len(self.transit.doors) == 0
            or not self.transit.bus_zone_polygon
        )

    def traffic_light_needs_autofill(self) -> bool:
        if not self.wants("traffic_light") or self.traffic_light is None:
            return False
        if not self.traffic_light.lights:
            return True
        # Treat an all-zero placeholder ROI as "auto-detect please".
        return all(
            (len(e.roi) == 4 and all(float(v) == 0.0 for v in e.roi))
            for e in self.traffic_light.lights
        )

    def resolve_ratio_coords(self, width: int, height: int) -> None:
        """Convert any normalized (0..1) coordinates in this calibration to
        pixel coordinates using the supplied frame dimensions.

        Mobile clients can't know the video resolution before upload, so the
        UI builds default calibration JSON in normalized space (e.g. a
        speed quad covering the lower-half trapezoid is `[[0.3,0.6],…]`).
        Pixel-space inputs are passed through unchanged: a value is
        considered a ratio only if every coordinate in its container is in
        the closed interval [0.0, 1.0]. Any container with at least one
        value > 1.0 is assumed already in pixel space — this is true of
        every realistic ROI, since even a 1×1 ROI on a 2-pixel-wide frame
        would have width=1 = a valid ratio AND a valid pixel count, but
        such a degenerate ROI is implausible.

        ROIs are slightly trickier — `[x, y, w, h]` as ratios in [0,1]
        denote fractions of frame width / height. We treat a length-4 list
        with all values <= 1.0 as ratio-form.

        Idempotent: a second call after the values are pixels (>1.0) is a
        no-op since the >1.0 check short-circuits.
        """
        def _all_le_one(coords: list[Any]) -> bool:
            return all(
                isinstance(v, (int, float)) and 0.0 <= float(v) <= 1.0
                for v in coords
            )

        def _scale_polygon(points: list[list[float]]) -> list[list[float]]:
            flat = [v for pt in points for v in pt]
            if not _all_le_one(flat):
                return points
            return [[float(x) * width, float(y) * height] for x, y in points]

        if self.count_lines is not None:
            self.count_lines.in_line = _scale_polygon(self.count_lines.in_line)
            self.count_lines.out_line = _scale_polygon(self.count_lines.out_line)

        if self.intersection_polygon is not None:
            self.intersection_polygon.polygon = _scale_polygon(
                self.intersection_polygon.polygon,
            )

        if self.speed is not None:
            self.speed.source_quad = _scale_polygon(self.speed.source_quad)
            if self.speed.lines_xy is not None:
                self.speed.lines_xy = [
                    _scale_polygon(line) for line in self.speed.lines_xy
                ]

        if self.transit is not None:
            self.transit.stop_polygon = _scale_polygon(self.transit.stop_polygon)
            if self.transit.bus_zone_polygon is not None:
                self.transit.bus_zone_polygon = _scale_polygon(
                    self.transit.bus_zone_polygon,
                )
            for door in self.transit.doors:
                line = door.get("line")
                if isinstance(line, list) and len(line) == 2:
                    door["line"] = _scale_polygon(line)

        if self.traffic_light is not None:
            for entry in self.traffic_light.lights:
                roi = entry.roi
                if len(roi) == 4 and _all_le_one(list(roi)):
                    entry.roi = [
                        int(round(float(roi[0]) * width)),
                        int(round(float(roi[1]) * height)),
                        int(round(float(roi[2]) * width)),
                        int(round(float(roi[3]) * height)),
                    ]


def parse_calibration(raw: str | bytes | None) -> Calibration:
    """Parse the JSON string from the multipart field. Missing / invalid → defaults."""
    if not raw:
        logger.info("No calibration provided — running with defaults (vehicles + pedestrians)")
        return Calibration()

    try:
        data = json.loads(raw) if isinstance(raw, (str, bytes)) else raw
    except json.JSONDecodeError as exc:
        logger.warning("calibration JSON invalid (%s) — falling back to defaults", exc)
        return Calibration()

    cal = Calibration()

    tasks = data.get("tasks_enabled")
    if isinstance(tasks, list) and tasks:
        cal.tasks_enabled = {t for t in tasks if t in ALL_TASKS}

    # Top-level class-annotated MP4 toggle (read anywhere in the JSON).
    cal.output_video = bool(data.get("output_video", False))

    if "tripwire" in data and isinstance(data["tripwire"], dict):
        y = data["tripwire"].get("y_ratio", 0.60)
        cal.tripwire = TripwireCfg(y_ratio=float(y))

    if "count_lines" in data:
        try:
            cl = data["count_lines"]

            def _parse_line(raw: Any, name: str) -> list[list[float]]:
                if not isinstance(raw, list) or len(raw) != 2:
                    raise ValueError(f"{name} must be [[x,y],[x,y]]")
                return [[float(p[0]), float(p[1])] for p in raw]

            in_line = _parse_line(cl.get("in"), "count_lines.in")
            out_line = _parse_line(cl.get("out"), "count_lines.out")
            cal.count_lines = CountLinesCfg(in_line=in_line, out_line=out_line)
        except (KeyError, ValueError, TypeError, IndexError) as exc:
            logger.warning(
                "count_lines invalid (%s) — falling back to horizontal tripwire", exc,
            )
            cal.count_lines = None

    if "intersection_polygon" in data:
        try:
            ip = data["intersection_polygon"]
            poly = ip.get("polygon") if isinstance(ip, dict) else ip
            cal.intersection_polygon = IntersectionPolygonCfg(
                polygon=[[float(x), float(y)] for x, y in poly]
            )
            if len(cal.intersection_polygon.polygon) < 3:
                raise ValueError("intersection_polygon needs at least 3 points")
        except (KeyError, ValueError, TypeError) as exc:
            logger.warning("intersection_polygon invalid (%s) — falling back to tripwire", exc)
            cal.intersection_polygon = None

    if "speed" in data and cal.wants("speed"):
        try:
            s = data["speed"]
            lines_xy_raw = s.get("lines_xy")
            lines_xy: list[list[list[float]]] | None = None
            if lines_xy_raw is not None:
                if not isinstance(lines_xy_raw, list) or len(lines_xy_raw) != 2:
                    raise ValueError("speed.lines_xy must contain 2 line segments")
                lines_xy = []
                for i, line in enumerate(lines_xy_raw):
                    if not isinstance(line, list) or len(line) != 2:
                        raise ValueError(f"speed.lines_xy[{i}] must be [[x,y],[x,y]]")
                    lines_xy.append(
                        [[float(p[0]), float(p[1])] for p in line]
                    )
            cal.speed = SpeedCfg(
                source_quad=[[float(x), float(y)] for x, y in s["source_quad"]],
                real_world_m={
                    "width": float(s["real_world_m"]["width"]),
                    "length": float(s["real_world_m"]["length"]),
                },
                lines_y_ratio=[float(v) for v in s["lines_y_ratio"]],
                lines_xy=lines_xy,
            )
            if len(cal.speed.source_quad) != 4 or len(cal.speed.lines_y_ratio) != 2:
                raise ValueError("source_quad must have 4 points; lines_y_ratio must have 2")
        except (KeyError, ValueError, TypeError) as exc:
            logger.warning("speed calibration invalid (%s) — disabling speed task", exc)
            cal.speed = None
            cal.tasks_enabled.discard("speed")

    if "transit" in data and cal.wants("transit"):
        try:
            t = data["transit"]
            stop_poly_raw = t.get("stop_polygon") or []
            bus_zone_raw = t.get("bus_zone_polygon")
            doors_raw = t.get("doors") or []
            cal.transit = TransitCfg(
                stop_polygon=[[float(x), float(y)] for x, y in stop_poly_raw],
                max_capacity=int(t.get("max_capacity", 30)),
                doors=list(doors_raw),
                bus_zone_polygon=(
                    [[float(x), float(y)] for x, y in bus_zone_raw]
                    if bus_zone_raw else None
                ),
                output_video=bool(t.get("output_video", False)),
            )
            # Geometry is optional here — when the mobile client is in "auto"
            # mode it sends only max_capacity + output_video and the
            # auto-calibration pre-pass fills the polygons via the VLM.
            # See Calibration.transit_needs_autofill().
            if cal.transit.stop_polygon and len(cal.transit.stop_polygon) < 3:
                raise ValueError("stop_polygon needs at least 3 points")
            if cal.transit.bus_zone_polygon is not None \
               and len(cal.transit.bus_zone_polygon) < 3:
                raise ValueError("bus_zone_polygon needs at least 3 points")
        except (ValueError, TypeError) as exc:
            logger.warning("transit calibration invalid (%s) — disabling transit task", exc)
            cal.transit = None
            cal.tasks_enabled.discard("transit")

    # Accept both legacy singular "traffic_light" and new plural "traffic_lights"
    # shapes. Singular becomes a one-entry list with label "main".
    # Entries without an "roi" field are accepted as auto-calibration
    # placeholders — the auto-calibration pre-pass will fill them in via the
    # VLM. See Calibration.traffic_light_needs_autofill().
    if cal.wants("traffic_light"):
        try:
            entries: list[TrafficLightEntry] = []
            # Defer the int cast — ratio-form ROIs (all values <= 1.0) must
            # survive parsing so resolve_ratio_coords() can scale them later.
            # Pixel-form ROIs are stored as ints to match the historic type.
            def _coerce_roi(roi: list[Any]) -> list[Any]:
                if all(isinstance(v, (int, float)) and 0.0 <= float(v) <= 1.0
                       for v in roi):
                    return [float(v) for v in roi]
                return [int(v) for v in roi]

            def _placeholder_roi() -> list[int]:
                return [0, 0, 0, 0]

            if isinstance(data.get("traffic_lights"), list):
                for i, item in enumerate(data["traffic_lights"]):
                    roi_raw = item.get("roi")
                    if roi_raw is None:
                        roi = _placeholder_roi()
                    else:
                        if len(roi_raw) != 4:
                            raise ValueError(f"traffic_lights[{i}].roi must be [x, y, w, h]")
                        roi = _coerce_roi(roi_raw)
                    entries.append(TrafficLightEntry(
                        roi=roi,
                        label=str(item.get("label") or f"light_{i}"),
                    ))
            elif isinstance(data.get("traffic_light"), dict):
                tl = data["traffic_light"]
                roi_raw = tl.get("roi")
                if roi_raw is None:
                    roi = _placeholder_roi()
                else:
                    if len(roi_raw) != 4:
                        raise ValueError("traffic_light.roi must be [x, y, w, h]")
                    roi = _coerce_roi(roi_raw)
                entries.append(TrafficLightEntry(
                    roi=roi,
                    label=str(tl.get("label") or "main"),
                ))
            if entries:
                cal.traffic_light = TrafficLightCfg(lights=entries)
            elif cal.wants("traffic_light"):
                # Task enabled but no entries supplied — still create one
                # placeholder so the auto-calibration pre-pass runs.
                cal.traffic_light = TrafficLightCfg(
                    lights=[TrafficLightEntry(roi=_placeholder_roi(), label="main")]
                )
        except (KeyError, ValueError, TypeError) as exc:
            logger.warning("traffic_light calibration invalid (%s) — disabling", exc)
            cal.traffic_light = None
            cal.tasks_enabled.discard("traffic_light")

    # Final guard: when a task is enabled but the client sent no config block
    # at all, materialise an empty placeholder so the auto-calibration
    # pre-pass has somewhere to write its results. Without this, the
    # downstream pipeline would silently skip the task because cal.transit /
    # cal.traffic_light is None.
    if cal.wants("transit") and cal.transit is None:
        cal.transit = TransitCfg(stop_polygon=[], max_capacity=30, doors=[])
    if cal.wants("traffic_light") and cal.traffic_light is None:
        cal.traffic_light = TrafficLightCfg(
            lights=[TrafficLightEntry(roi=[0, 0, 0, 0], label="main")]
        )

    if "lpr" in data:
        # Defer the ocr import — pulls easyocr which is expensive; only needed
        # when we have a plate allowlist to normalize.
        from ocr import normalize_plate  # noqa: E402

        lpr = data["lpr"]
        raw_allowlist = lpr.get("allowlist") or []
        if not isinstance(raw_allowlist, list):
            logger.warning("lpr.allowlist must be a list — ignoring")
            raw_allowlist = []
        allowlist = [normalize_plate(str(p)) for p in raw_allowlist if str(p).strip()]
        cal.lpr = LprCfg(
            enabled=bool(lpr.get("enabled", False)),
            residential_only=bool(lpr.get("residential_only", True)),
            allowlist=allowlist,
            allowlist_source=str(lpr.get("allowlist_source", "inline")),
            hash_plates=bool(lpr.get("hash_plates", False)),
        )
        if not cal.lpr.enabled:
            cal.tasks_enabled.discard("lpr")

    logger.info("Parsed calibration: tasks=%s", sorted(cal.tasks_enabled))
    return cal
