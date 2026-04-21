"""Calibration Studio — interactive click-point tool for per-site calibration.

Loads one frame from a video (or an image), lets the operator click polygons,
a perspective quad, a traffic-light ROI, bus-stop polygon, door lines, and a
tripwire y_ratio, then writes a calibration JSON that ``runpod/calibration.py``
already knows how to parse.

Usage:
    python scripts/calibration_studio.py VIDEO_OR_IMAGE [--output FILE] [--frame N]
    python scripts/calibration_studio.py VIDEO --validate existing.json

Keyboard:
    1  Intersection polygon     (3+ clicks, Enter to close)
    2  Speed quad               (4 clicks, then CLI prompts width/length in metres)
    3  Traffic light ROI        (2 clicks: top-left, bottom-right)
    4  Bus stop polygon         (3+ clicks, Enter to close)
    5  Bus door line            (2 clicks; repeat for multiple doors)
    T  Tripwire y_ratio         (1 click — y becomes ratio of frame height)
    Enter   Commit polygon / line
    U / Bksp  Undo last point
    C  Clear current selection / exit current mode
    S  Save JSON
    H  Toggle help overlay
    Q / Esc  Quit (prompts when unsaved)

Output JSON matches the schema consumed by ``runpod/calibration.py``.
"""
from __future__ import annotations

import argparse
import json
import logging
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import cv2
import numpy as np

logger = logging.getLogger("calibration_studio")


# ---------------------------------------------------------------------------
# Overlay constants
# ---------------------------------------------------------------------------
_COLORS = {
    "intersection_polygon": (0, 255, 255),     # yellow
    "speed_quad":           (255, 128, 0),     # orange-blue (BGR)
    "traffic_light":        (0, 255, 0),       # green
    "transit_polygon":      (255, 0, 255),     # magenta
    "transit_door":         (255, 192, 0),     # cyan
    "tripwire":             (0, 0, 255),       # red
    "pending":              (255, 255, 255),   # white — in-progress selection
}

_MODE_KEYS = {
    ord('1'): "intersection_polygon",
    ord('2'): "speed_quad",
    ord('3'): "traffic_light",
    ord('4'): "transit_polygon",
    ord('5'): "transit_door",
    ord('t'): "tripwire",
    ord('T'): "tripwire",
}

_HELP_TEXT = """\
1  intersection_polygon  (3+ clicks, Enter)
2  speed_quad            (4 clicks, prompt dims)
3  traffic_light         (2 clicks: TL, BR)
4  transit_polygon       (3+ clicks, Enter)
5  transit_door          (2 clicks; repeatable)
T  tripwire              (1 click)
Enter commit   U/Bksp undo   C clear   S save   H help   Q quit"""


# ---------------------------------------------------------------------------
# Frame loading
# ---------------------------------------------------------------------------
VIDEO_EXTS = {".mp4", ".mov", ".avi", ".mkv", ".m4v"}


def extract_frame(source: Path, frame_idx: int) -> np.ndarray:
    """Load one frame from video or image."""
    if source.suffix.lower() in VIDEO_EXTS:
        cap = cv2.VideoCapture(str(source))
        if not cap.isOpened():
            raise SystemExit(f"Cannot open video: {source}")
        cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
        ok, frame = cap.read()
        cap.release()
        if not ok:
            raise SystemExit(f"Cannot read frame {frame_idx} from {source}")
        return frame
    frame = cv2.imread(str(source))
    if frame is None:
        raise SystemExit(f"Cannot read image: {source}")
    return frame


# ---------------------------------------------------------------------------
# Display scaler — keep JSON coords in original resolution
# ---------------------------------------------------------------------------
class DisplayScaler:
    def __init__(self, fw: int, fh: int, max_w: int = 1600, max_h: int = 900):
        self.fw, self.fh = fw, fh
        self.scale = min(1.0, max_w / fw, max_h / fh)
        self.dw = int(fw * self.scale)
        self.dh = int(fh * self.scale)

    def to_display(self, x: float, y: float) -> tuple[int, int]:
        return int(x * self.scale), int(y * self.scale)

    def to_original(self, x: int, y: int) -> tuple[int, int]:
        return int(round(x / self.scale)), int(round(y / self.scale))


# ---------------------------------------------------------------------------
# Calibration model — mirrors the schema of runpod/calibration.py
# ---------------------------------------------------------------------------
@dataclass
class CalibrationDoc:
    frame_w: int
    frame_h: int
    intersection_polygon: list[list[int]] = field(default_factory=list)
    speed_quad: list[list[int]] = field(default_factory=list)
    speed_width_m: float | None = None
    speed_length_m: float | None = None
    speed_lines_y_ratio: list[float] = field(default_factory=lambda: [0.45, 0.75])
    # Multi-light: each entry is (label, [x, y, w, h]). Key '3' in the studio
    # appends a new light each time it's triggered, so operators can capture
    # main + left-turn + pedestrian signals in one session.
    traffic_lights: list[tuple[str, list[int]]] = field(default_factory=list)
    transit_polygon: list[list[int]] = field(default_factory=list)
    transit_doors: list[list[list[int]]] = field(default_factory=list)
    transit_max_capacity: int = 30
    tripwire_y_ratio: float = 0.55
    tasks_enabled: set[str] = field(default_factory=lambda: {"vehicles"})

    # ------------------------------------------------------ serialization
    def to_json(self, source: Path, frame_idx: int) -> dict[str, Any]:
        out: dict[str, Any] = {
            "_source": f"{source.name} frame {frame_idx}",
            "_generated_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
            "_frame_dimensions": [self.frame_w, self.frame_h],
            "tasks_enabled": sorted(self.tasks_enabled),
            "tripwire": {"y_ratio": round(self.tripwire_y_ratio, 3)},
        }
        if self.intersection_polygon:
            out["intersection_polygon"] = {"polygon": self.intersection_polygon}
        if (self.speed_quad and len(self.speed_quad) == 4
                and self.speed_width_m and self.speed_length_m):
            out["speed"] = {
                "source_quad": self.speed_quad,
                "real_world_m": {
                    "width": self.speed_width_m,
                    "length": self.speed_length_m,
                },
                "lines_y_ratio": self.speed_lines_y_ratio,
            }
        if self.traffic_lights:
            out["traffic_lights"] = [
                {"label": label, "roi": roi} for label, roi in self.traffic_lights
            ]
        if self.transit_polygon:
            out["transit"] = {
                "stop_polygon": self.transit_polygon,
                "max_capacity": self.transit_max_capacity,
                "doors": [{"line": d} for d in self.transit_doors],
            }
        return out

    @classmethod
    def from_json(cls, data: dict, fw: int, fh: int) -> "CalibrationDoc":
        d = cls(frame_w=fw, frame_h=fh)
        if isinstance(data.get("tasks_enabled"), list):
            d.tasks_enabled = set(data["tasks_enabled"])
        tw = data.get("tripwire", {})
        d.tripwire_y_ratio = float(tw.get("y_ratio", 0.55))
        ip = data.get("intersection_polygon") or {}
        d.intersection_polygon = [[int(x), int(y)] for x, y in ip.get("polygon", [])]
        sp = data.get("speed")
        if isinstance(sp, dict):
            d.speed_quad = [[int(x), int(y)] for x, y in sp.get("source_quad", [])]
            rw = sp.get("real_world_m", {})
            d.speed_width_m = float(rw.get("width", 0)) or None
            d.speed_length_m = float(rw.get("length", 0)) or None
            if isinstance(sp.get("lines_y_ratio"), list) and len(sp["lines_y_ratio"]) == 2:
                d.speed_lines_y_ratio = [float(v) for v in sp["lines_y_ratio"]]
        # Load multi-light form if present; fall back to legacy singular.
        tls = data.get("traffic_lights")
        if isinstance(tls, list):
            for i, item in enumerate(tls):
                if not isinstance(item, dict):
                    continue
                roi = item.get("roi")
                if isinstance(roi, list) and len(roi) == 4:
                    label = str(item.get("label") or f"light_{i}")
                    d.traffic_lights.append((label, [int(v) for v in roi]))
        else:
            tl = data.get("traffic_light")
            if isinstance(tl, dict) and isinstance(tl.get("roi"), list) and len(tl["roi"]) == 4:
                label = str(tl.get("label") or "main")
                d.traffic_lights.append((label, [int(v) for v in tl["roi"]]))
        tr = data.get("transit")
        if isinstance(tr, dict):
            d.transit_polygon = [[int(x), int(y)] for x, y in tr.get("stop_polygon", [])]
            d.transit_doors = [
                [[int(x), int(y)] for x, y in door.get("line", [])]
                for door in tr.get("doors", []) if isinstance(door, dict)
            ]
            d.transit_max_capacity = int(tr.get("max_capacity", 30))
        return d


# ---------------------------------------------------------------------------
# Interactive studio
# ---------------------------------------------------------------------------
class Studio:
    def __init__(
        self,
        frame: np.ndarray,
        source: Path,
        frame_idx: int,
        doc: CalibrationDoc | None = None,
    ):
        self.frame_orig = frame
        self.source = source
        self.frame_idx = frame_idx
        h, w = frame.shape[:2]
        self.scaler = DisplayScaler(w, h)
        self.doc = doc or CalibrationDoc(frame_w=w, frame_h=h)
        self.current_mode: str | None = None
        self.current_points: list[list[int]] = []
        self.show_help = True
        self.dirty = False
        self.msg: str = ""
        self.msg_until: float = 0.0

    # ---------------------------------------------------- input helpers
    def _flash(self, text: str, seconds: float = 2.5) -> None:
        self.msg = text
        self.msg_until = time.time() + seconds

    # ---------------------------------------------------- rendering
    def _render(self) -> np.ndarray:
        img = cv2.resize(
            self.frame_orig, (self.scaler.dw, self.scaler.dh),
            interpolation=cv2.INTER_AREA,
        )
        # committed features
        self._draw_polygon(img, self.doc.intersection_polygon,
                           "intersection_polygon", closed=True)
        self._draw_polygon(img, self.doc.speed_quad, "speed_quad", closed=True)
        for label, roi in self.doc.traffic_lights:
            self._draw_rect(img, roi, "traffic_light", label=label)
        self._draw_polygon(img, self.doc.transit_polygon,
                           "transit_polygon", closed=True)
        for i, door in enumerate(self.doc.transit_doors):
            self._draw_polygon(img, door, "transit_door", closed=False,
                               label=f"door_{i}")

        # tripwire horizontal guideline
        wy = int(self.doc.tripwire_y_ratio * self.doc.frame_h)
        _, dy = self.scaler.to_display(0, wy)
        cv2.line(img, (0, dy), (self.scaler.dw, dy),
                 _COLORS["tripwire"], 1, cv2.LINE_AA)
        cv2.putText(img, f"tripwire y={self.doc.tripwire_y_ratio:.2f}",
                    (5, dy - 5), cv2.FONT_HERSHEY_SIMPLEX,
                    0.5, _COLORS["tripwire"], 1)

        # in-progress selection
        if self.current_points:
            self._draw_polygon(img, self.current_points, "pending",
                               closed=False, label=None)
            for (x, y) in self.current_points:
                dx, dy_ = self.scaler.to_display(x, y)
                cv2.circle(img, (dx, dy_), 4, _COLORS["pending"], -1)

        # header
        cv2.rectangle(img, (0, 0), (self.scaler.dw, 45), (0, 0, 0), -1)
        status = (
            f"Mode: {self.current_mode or 'idle'}    "
            f"points={len(self.current_points)}    "
            f"{'*UNSAVED*' if self.dirty else ''}"
        )
        cv2.putText(img, status, (8, 30), cv2.FONT_HERSHEY_SIMPLEX,
                    0.6, (255, 255, 255), 2)

        if self.show_help:
            self._draw_help(img)

        if self.msg and time.time() < self.msg_until:
            (tw, th), _ = cv2.getTextSize(self.msg, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)
            cv2.rectangle(img, (10, self.scaler.dh - th - 20),
                          (20 + tw, self.scaler.dh - 5),
                          (0, 0, 0), -1)
            cv2.putText(img, self.msg, (15, self.scaler.dh - 15),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
        return img

    def _draw_polygon(
        self,
        img: np.ndarray,
        points: list[list[int]],
        kind: str,
        *,
        closed: bool,
        label: str | None = None,
    ) -> None:
        if not points:
            return
        pts = np.array(
            [self.scaler.to_display(x, y) for x, y in points], dtype=np.int32,
        )
        color = _COLORS[kind]
        if closed and len(pts) >= 3:
            overlay = img.copy()
            cv2.fillPoly(overlay, [pts], color)
            cv2.addWeighted(overlay, 0.15, img, 0.85, 0, img)
            cv2.polylines(img, [pts], True, color, 2, cv2.LINE_AA)
        else:
            cv2.polylines(img, [pts], False, color, 2, cv2.LINE_AA)
        if label is None:
            label = kind
        if label:
            cv2.putText(img, label, tuple(pts[0]), cv2.FONT_HERSHEY_SIMPLEX,
                        0.5, color, 1, cv2.LINE_AA)

    def _draw_rect(
        self,
        img: np.ndarray,
        roi: list[int],
        kind: str,
        *,
        label: str | None = None,
    ) -> None:
        x, y, w, h = roi
        dx1, dy1 = self.scaler.to_display(x, y)
        dx2, dy2 = self.scaler.to_display(x + w, y + h)
        overlay = img.copy()
        cv2.rectangle(overlay, (dx1, dy1), (dx2, dy2), _COLORS[kind], -1)
        cv2.addWeighted(overlay, 0.15, img, 0.85, 0, img)
        cv2.rectangle(img, (dx1, dy1), (dx2, dy2), _COLORS[kind], 2)
        cv2.putText(img, label or kind, (dx1, dy1 - 5),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, _COLORS[kind], 1, cv2.LINE_AA)

    def _draw_help(self, img: np.ndarray) -> None:
        pad, line_h = 10, 18
        lines = _HELP_TEXT.split("\n")
        box_h = pad * 2 + line_h * len(lines)
        box_w = 520
        x0 = self.scaler.dw - box_w - 10
        y0 = 55
        cv2.rectangle(img, (x0, y0), (x0 + box_w, y0 + box_h), (0, 0, 0), -1)
        for i, line in enumerate(lines):
            cv2.putText(img, line, (x0 + pad, y0 + pad + (i + 1) * line_h - 4),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.45, (220, 220, 220), 1,
                        cv2.LINE_AA)

    # ---------------------------------------------------- input
    def _on_mouse(self, event, x, y, flags, param) -> None:
        if event != cv2.EVENT_LBUTTONDOWN:
            return
        if self.current_mode is None:
            return
        ox, oy = self.scaler.to_original(x, y)

        if self.current_mode == "tripwire":
            ratio = round(max(0.0, min(1.0, oy / self.doc.frame_h)), 3)
            self.doc.tripwire_y_ratio = ratio
            self.current_mode = None
            self.dirty = True
            self._flash(f"tripwire y_ratio = {ratio}")
            return

        if self.current_mode == "traffic_light":
            self.current_points.append([ox, oy])
            if len(self.current_points) == 2:
                p1, p2 = self.current_points
                x1, y1 = min(p1[0], p2[0]), min(p1[1], p2[1])
                x2, y2 = max(p1[0], p2[0]), max(p1[1], p2[1])
                idx = len(self.doc.traffic_lights)
                label = f"light_{idx}" if idx else "main"
                self.doc.traffic_lights.append((label, [x1, y1, x2 - x1, y2 - y1]))
                self.doc.tasks_enabled.add("traffic_light")
                self.current_mode = None
                self.current_points = []
                self.dirty = True
                self._flash(f"added {label} (total lights={idx + 1})")
            return

        if self.current_mode == "transit_door":
            self.current_points.append([ox, oy])
            if len(self.current_points) == 2:
                self.doc.transit_doors.append(list(self.current_points))
                self.current_mode = None
                self.current_points = []
                self.dirty = True
                self._flash(f"added door (total={len(self.doc.transit_doors)})")
            return

        if self.current_mode == "speed_quad":
            self.current_points.append([ox, oy])
            if len(self.current_points) == 4:
                self._commit_speed_quad()
            return

        if self.current_mode in ("intersection_polygon", "transit_polygon"):
            self.current_points.append([ox, oy])

    def _commit_speed_quad(self) -> None:
        print("\n  Speed quad clicked. Enter real-world metres.")
        print("  Convention: points 1→2 = TOP-EDGE width, points 2→3 = RIGHT-EDGE length.")
        try:
            w_m = float(input("  width_m (1→2): ").strip())
            l_m = float(input("  length_m (2→3): ").strip())
        except (ValueError, EOFError, KeyboardInterrupt):
            self._flash("speed quad cancelled (bad input)")
            self.current_points = []
            self.current_mode = None
            return
        self.doc.speed_quad = list(self.current_points)
        self.doc.speed_width_m = w_m
        self.doc.speed_length_m = l_m
        self.doc.tasks_enabled.add("speed")
        self.current_mode = None
        self.current_points = []
        self.dirty = True
        self._flash(f"speed quad set ({w_m}m × {l_m}m)")

    def _commit_current_polygon(self) -> None:
        if self.current_mode == "intersection_polygon":
            if len(self.current_points) >= 3:
                self.doc.intersection_polygon = list(self.current_points)
                self.dirty = True
                self._flash(f"intersection polygon ({len(self.current_points)} pts)")
        elif self.current_mode == "transit_polygon":
            if len(self.current_points) >= 3:
                self.doc.transit_polygon = list(self.current_points)
                self.doc.tasks_enabled.add("transit")
                self.dirty = True
                self._flash(f"transit polygon ({len(self.current_points)} pts)")
        else:
            return
        self.current_mode = None
        self.current_points = []

    def _save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(self.doc.to_json(self.source, self.frame_idx),
                       indent=2, ensure_ascii=False),
        )
        self._flash(f"saved {path.name}")
        self.dirty = False
        print(f"\n  → wrote {path}\n")

    # ---------------------------------------------------- main loop
    def run(self, output_path: Path) -> None:
        win = "Calibration Studio"
        cv2.namedWindow(win, cv2.WINDOW_NORMAL)
        cv2.resizeWindow(win, self.scaler.dw, self.scaler.dh)
        cv2.setMouseCallback(win, self._on_mouse)
        while True:
            cv2.imshow(win, self._render())
            key = cv2.waitKey(30) & 0xFF
            if key == 255:
                continue
            if key in (ord('q'), 27):
                if self.dirty:
                    self._flash("unsaved! Press S to save, or Q again to discard")
                    cv2.imshow(win, self._render())
                    key2 = cv2.waitKey(0) & 0xFF
                    if key2 == ord('s'):
                        self._save(output_path)
                        break
                    if key2 not in (ord('q'), 27):
                        continue
                break
            if key in _MODE_KEYS:
                self.current_mode = _MODE_KEYS[key]
                self.current_points = []
                self._flash(f"mode: {self.current_mode}")
            elif key == 13:                               # Enter
                self._commit_current_polygon()
            elif key in (ord('u'), 8):                    # U / Backspace
                if self.current_points:
                    self.current_points.pop()
            elif key == ord('c'):
                self.current_points = []
                self.current_mode = None
                self._flash("cleared selection")
            elif key == ord('s'):
                self._save(output_path)
            elif key == ord('h'):
                self.show_help = not self.show_help
        cv2.destroyAllWindows()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(
        description="Interactive calibration JSON generator.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("source", help="Video or image path")
    parser.add_argument("--output", "-o", help="Output JSON (default: <source>.calibration.json)")
    parser.add_argument("--frame", "-f", type=int, default=30,
                        help="Video frame to extract (default 30)")
    parser.add_argument("--validate",
                        help="Load existing calibration JSON and display overlay")
    parser.add_argument("--max-capacity", type=int, default=30,
                        help="Transit max_capacity (default 30)")
    args = parser.parse_args()

    source = Path(args.source)
    if not source.exists():
        raise SystemExit(f"Not found: {source}")

    out = Path(args.output) if args.output else source.with_suffix(".calibration.json")
    frame = extract_frame(source, args.frame)
    logger.info("Loaded %s frame %d — %dx%d",
                source.name, args.frame, frame.shape[1], frame.shape[0])

    doc: CalibrationDoc | None = None
    if args.validate:
        with Path(args.validate).open("r", encoding="utf-8") as f:
            doc = CalibrationDoc.from_json(
                json.load(f), frame.shape[1], frame.shape[0],
            )
        print(f"Loaded calibration: {args.validate}")
    if doc is not None:
        doc.transit_max_capacity = args.max_capacity

    studio = Studio(frame, source, args.frame, doc=doc)
    studio.run(out)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    main()
