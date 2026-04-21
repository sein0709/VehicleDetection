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
    intersection_polygon: IntersectionPolygonCfg | None = None
    speed: SpeedCfg | None = None
    transit: TransitCfg | None = None
    traffic_light: TrafficLightCfg | None = None
    lpr: LprCfg = field(default_factory=LprCfg)

    def wants(self, task: str) -> bool:
        return task in self.tasks_enabled


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

    if "tripwire" in data and isinstance(data["tripwire"], dict):
        y = data["tripwire"].get("y_ratio", 0.60)
        cal.tripwire = TripwireCfg(y_ratio=float(y))

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
            cal.speed = SpeedCfg(
                source_quad=[[float(x), float(y)] for x, y in s["source_quad"]],
                real_world_m={
                    "width": float(s["real_world_m"]["width"]),
                    "length": float(s["real_world_m"]["length"]),
                },
                lines_y_ratio=[float(v) for v in s["lines_y_ratio"]],
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
            bus_zone = t.get("bus_zone_polygon")
            cal.transit = TransitCfg(
                stop_polygon=[[float(x), float(y)] for x, y in t["stop_polygon"]],
                max_capacity=int(t.get("max_capacity", 30)),
                doors=list(t.get("doors", [])),
                bus_zone_polygon=(
                    [[float(x), float(y)] for x, y in bus_zone]
                    if bus_zone else None
                ),
                output_video=bool(t.get("output_video", False)),
            )
            if len(cal.transit.stop_polygon) < 3:
                raise ValueError("stop_polygon needs at least 3 points")
            if cal.transit.bus_zone_polygon is not None \
               and len(cal.transit.bus_zone_polygon) < 3:
                raise ValueError("bus_zone_polygon needs at least 3 points")
        except (KeyError, ValueError, TypeError) as exc:
            logger.warning("transit calibration invalid (%s) — disabling transit task", exc)
            cal.transit = None
            cal.tasks_enabled.discard("transit")

    # Accept both legacy singular "traffic_light" and new plural "traffic_lights"
    # shapes. Singular becomes a one-entry list with label "main".
    if cal.wants("traffic_light"):
        try:
            entries: list[TrafficLightEntry] = []
            if isinstance(data.get("traffic_lights"), list):
                for i, item in enumerate(data["traffic_lights"]):
                    roi = item["roi"]
                    if len(roi) != 4:
                        raise ValueError(f"traffic_lights[{i}].roi must be [x, y, w, h]")
                    entries.append(TrafficLightEntry(
                        roi=[int(v) for v in roi],
                        label=str(item.get("label") or f"light_{i}"),
                    ))
            elif isinstance(data.get("traffic_light"), dict):
                roi = data["traffic_light"]["roi"]
                if len(roi) != 4:
                    raise ValueError("traffic_light.roi must be [x, y, w, h]")
                entries.append(TrafficLightEntry(
                    roi=[int(v) for v in roi],
                    label=str(data["traffic_light"].get("label") or "main"),
                ))
            if entries:
                cal.traffic_light = TrafficLightCfg(lights=entries)
            else:
                cal.tasks_enabled.discard("traffic_light")
        except (KeyError, ValueError, TypeError) as exc:
            logger.warning("traffic_light calibration invalid (%s) — disabling", exc)
            cal.traffic_light = None
            cal.tasks_enabled.discard("traffic_light")

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
