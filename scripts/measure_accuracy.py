"""Ground-truth comparison harness for any configured site.

Sites live in ``scripts/sites/<name>.json`` — each declares its video directory,
a ground-truth source (currently ``bundang_xls`` only), and a default
calibration file. The harness runs the pipeline on the chosen clip, compares
per-class counts against pro-rated ground truth, and prints a diff.

Usage:
    .venv/bin/python scripts/measure_accuracy.py                   # defaults to seodang site
    .venv/bin/python scripts/measure_accuracy.py --clip 07:30
    .venv/bin/python scripts/measure_accuracy.py --site scripts/sites/other.json
    .venv/bin/python scripts/measure_accuracy.py --calibration scripts/custom.json
    .venv/bin/python scripts/measure_accuracy.py --trim-seconds 60  # fast-iterate

To onboard a new site:
    1. Drop videos into a directory (filenames starting with HH.MM.SS-)
    2. Provide a ground-truth source (xls / csv / inline JSON)
    3. Author scripts/sites/<name>.json mirroring scripts/sites/seodang.json
    4. Run: measure_accuracy.py --site scripts/sites/<name>.json --clip HH:MM

Ground-truth source types (dispatched by ``ground_truth.type``):
    * bundang_xls  — 3-direction manual count xls, 8 cols per direction
"""
from __future__ import annotations

import argparse
import json
import logging
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "runpod"))

import pandas as pd  # noqa: E402

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("measure")

DEFAULT_SITE_PATH = REPO_ROOT / "scripts" / "sites" / "seodang.json"

# Korean ground-truth column headers (xls row 3) → MOLIT class buckets we
# can actually compare. The xls collapses MOLIT classes into 4 buckets per
# direction, so we aggregate the pipeline's 12 MOLIT classes the same way.
GT_BUCKETS = ["small_passenger", "small_bus", "large_bus", "small_truck", "midlarge_truck", "trailer"]

# MOLIT class id → ground-truth bucket name. Keep aligned with config.py
# VEHICLE_CLASS_NAMES.
MOLIT_TO_BUCKET = {
    2:  "small_passenger",   # Class 1 Passenger/Van
    6:  "large_bus",         # Class 2 Bus (xls bus is split small/large; we put MOLIT bus → large)
    7:  "small_truck",       # Class 3 Rigid <2.5t
    8:  "midlarge_truck",    # Class 4 Rigid >=2.5t
    9:  "midlarge_truck",    # Class 5 Rigid 3-axle
    10: "midlarge_truck",    # Class 6 Rigid 4-axle
    11: "midlarge_truck",    # Class 7 Rigid 5-axle
    12: "trailer",           # Class 8 Semi 4-axle
    13: "trailer",           # Class 9 Full 4-axle
    3:  "trailer",           # Class 10 Semi 5-axle
    4:  "trailer",           # Class 11 Full 5-axle
    5:  "trailer",           # Class 12 6+ axle
}


# ---------------------------------------------------------------------------
# Site config
# ---------------------------------------------------------------------------
@dataclass
class Site:
    name: str
    display_name: str
    road_type: str                                      # straight | 3way | 4way | roundabout
    video_dir: Path
    calibration_default: Path | None
    ground_truth: dict[str, Any]                        # {"type": ..., rest varies}

    @classmethod
    def from_json(cls, path: Path) -> "Site":
        raw = json.loads(path.read_text())
        return cls(
            name=raw["name"],
            display_name=raw.get("display_name", raw["name"]),
            road_type=raw.get("road_type", "unknown"),
            video_dir=Path(raw["video_dir"]),
            calibration_default=(
                (REPO_ROOT / raw["calibration_default"]).resolve()
                if raw.get("calibration_default") else None
            ),
            ground_truth=raw["ground_truth"],
        )

    @property
    def slot_minutes(self) -> int:
        return int(self.ground_truth.get("slot_minutes", 15))


# ---------------------------------------------------------------------------
# Ground-truth parser
# ---------------------------------------------------------------------------
@dataclass
class GroundTruthSlot:
    """One slot of ground-truth counts, summed across all approach directions."""
    label: str                                  # e.g. "07:00-07:15"
    counts: dict[str, int] = field(default_factory=lambda: {b: 0 for b in GT_BUCKETS})

    def total(self) -> int:
        return sum(self.counts.values())

    def prorate(self, factor: float, label_suffix: str = "") -> "GroundTruthSlot":
        return GroundTruthSlot(
            label=self.label + label_suffix,
            counts={k: round(v * factor) for k, v in self.counts.items()},
        )


def parse_ground_truth(site: Site) -> dict[str, GroundTruthSlot]:
    """Dispatch to a format-specific parser based on site.ground_truth['type']."""
    gt_type = site.ground_truth.get("type")
    if gt_type == "bundang_xls":
        return _parse_bundang_xls(site.ground_truth)
    raise SystemExit(
        f"Unsupported ground_truth type {gt_type!r} in site {site.name}. "
        "Supported: bundang_xls"
    )


def _parse_bundang_xls(cfg: dict[str, Any]) -> dict[str, GroundTruthSlot]:
    """3-direction Bundang xls: each direction = 8 columns (6 vehicle buckets
    + subtotal vehicles + PCU); directions sit back-to-back with no gap col."""
    xls_path = Path(cfg["path"])
    sheet = cfg.get("sheet", "1")
    # The xls layout within each direction (6 vehicle buckets + 2 totals):
    #   0 소형 승용, 1 버스 소형, 2 버스 대형, 3 화물 소형, 4 화물 중·대,
    #   5 화물 트레일, 6 소계, 7 PCU
    bucket_offsets = {
        "small_passenger": 0,
        "small_bus": 1,
        "large_bus": 2,
        "small_truck": 3,
        "midlarge_truck": 4,
        "trailer": 5,
    }
    direction_starts: list[int] = list(cfg.get("direction_starts", [1, 9, 17]))
    df = pd.read_excel(xls_path, sheet_name=sheet, header=None)

    slots: dict[str, GroundTruthSlot] = {}
    # Time-slot rows for the AM+PM peak layout: 4-7, 10-13, 16-19.
    # Override via cfg['slot_rows'] for differently-shaped sheets.
    slot_rows = cfg.get("slot_rows", [4, 5, 6, 7, 10, 11, 12, 13, 16, 17, 18, 19])
    for row in slot_rows:
        label_cell = df.iat[row, 0]
        if not isinstance(label_cell, str) or "-" not in label_cell:
            continue
        label = label_cell.strip()
        slot = GroundTruthSlot(label=label)
        for dir_start in direction_starts:
            for bucket, offset in bucket_offsets.items():
                v = df.iat[row, dir_start + offset]
                if pd.isna(v):
                    continue
                try:
                    slot.counts[bucket] += int(v)
                except (TypeError, ValueError):
                    pass
        slots[label] = slot
    return slots


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------
def aggregate_predicted(report: dict[str, Any]) -> dict[str, int]:
    """Sum the pipeline's per-class breakdown into the same buckets as the xls."""
    from config import VEHICLE_CLASS_NAMES

    out = {b: 0 for b in GT_BUCKETS}
    breakdown = report.get("vehicle_breakdown") or report.get("breakdown") or {}

    name_to_id = {v: k for k, v in VEHICLE_CLASS_NAMES.items()}
    for name, count in breakdown.items():
        cls_id = name_to_id.get(name)
        if cls_id is None:
            continue
        bucket = MOLIT_TO_BUCKET.get(cls_id)
        if bucket is None:
            continue
        out[bucket] += int(count)
    return out


# ---------------------------------------------------------------------------
# Pipeline runner
# ---------------------------------------------------------------------------
def run_clip(video_path: Path, calibration_json: str | None, cache_path: Path | None) -> dict[str, Any]:
    """Run the pipeline, optionally caching the report to disk so subsequent
    invocations skip the 25-min CPU re-run while we iterate on the comparison."""
    if cache_path and cache_path.exists():
        logger.info("Using cached pipeline report: %s", cache_path)
        return json.loads(cache_path.read_text())

    from calibration import parse_calibration
    from pipeline import run_pipeline

    cal = parse_calibration(calibration_json)
    report = run_pipeline(str(video_path), cal)
    if cache_path:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(json.dumps(report, indent=2, ensure_ascii=False, default=str))
        logger.info("Cached pipeline report: %s", cache_path)
    return report


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
def print_report(
    *,
    clip_path: Path,
    slot_label: str,
    truth_scaled: GroundTruthSlot,
    predicted: dict[str, int],
    full_pipeline_report: dict[str, Any],
) -> None:
    """truth_scaled has already been pro-rated to the clip's duration."""
    pred_total = sum(predicted.values())
    truth_total = truth_scaled.total()

    width = 22
    print("=" * 72)
    print(f"Clip:   {clip_path.name}")
    print(f"Slot:   {slot_label}")
    print(f"Method: {full_pipeline_report['counting']['method']}")
    print("=" * 72)
    print(f"{'BUCKET':<{width}}  {'PREDICTED':>10}  {'TRUTH':>10}  {'DIFF':>8}  {'DIFF%':>8}")
    print("-" * 72)
    for bucket in GT_BUCKETS:
        p = predicted.get(bucket, 0)
        t = truth_scaled.counts.get(bucket, 0)
        diff = p - t
        pct = (diff / t * 100) if t > 0 else (float("inf") if p > 0 else 0.0)
        pct_str = f"{pct:+.0f}%" if t > 0 else ("—" if p == 0 else "∞")
        print(f"{bucket:<{width}}  {p:>10}  {t:>10}  {diff:>+8}  {pct_str:>8}")
    print("-" * 72)
    print(f"{'TOTAL':<{width}}  {pred_total:>10}  {truth_total:>10}  "
          f"{pred_total - truth_total:>+8}  "
          f"{((pred_total - truth_total) / truth_total * 100) if truth_total else 0:+.0f}%")
    print("=" * 72)
    print(f"Pipeline meta: {full_pipeline_report['meta']}")
    counting = full_pipeline_report["counting"]
    cand = counting.get("candidate_tracks", "?")
    kept = counting["unique_tracks_counted"]
    filtered = cand - kept if isinstance(cand, int) else "?"
    print(f"Counting:      method={counting['method']}, "
          f"candidate_tracks={cand}, kept={kept} "
          f"(filtered {filtered} phantom/flash tracks), "
          f"tripwire_in={counting['tripwire_crossings_in']}, "
          f"tripwire_out={counting['tripwire_crossings_out']}")
    hist = counting.get("observation_hist")
    if hist:
        print(f"Obs hist:      (samples-per-track buckets @ 12.5Hz) {hist}")
    excluded = counting.get("polygon_inside_only_excluded")
    if excluded is not None:
        print(f"Traversal:     polygon_inside_only_excluded={excluded} (waiting/parked cars filtered out)")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def find_clip(site: Site, start_hhmm: str) -> Path:
    """Find the 5-min mp4 starting at HH:MM (e.g., '07:00' → 07.00.00-07.05.00...mp4)."""
    pattern = f"{start_hhmm.replace(':', '.')}.00-"
    candidates = sorted(site.video_dir.glob(f"{pattern}*.mp4"))
    if not candidates:
        raise SystemExit(f"No clip found starting at {start_hhmm} in {site.video_dir}")
    return candidates[0]


def trim_clip(src: Path, seconds: float, out_dir: Path) -> Path:
    """Copy the first ``seconds`` of ``src`` into ``out_dir`` as a new mp4.

    Used for fast iteration on tracker / filter thresholds — a 60-second trim
    runs in ~3-5 minutes on CPU instead of ~25 minutes for the full 5-min clip.
    The caller scales the ground-truth slot proportionally.
    """
    import cv2

    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{src.stem}__trim{int(seconds)}s.mp4"
    if out_path.exists() and out_path.stat().st_size > 0:
        return out_path

    cap = cv2.VideoCapture(str(src))
    fps = cap.get(cv2.CAP_PROP_FPS) or 25.0
    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    n_frames = int(fps * seconds)

    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(str(out_path), fourcc, fps, (w, h))
    try:
        for _ in range(n_frames):
            ok, frame = cap.read()
            if not ok:
                break
            writer.write(frame)
    finally:
        writer.release()
        cap.release()
    return out_path


def slot_for_clip(
    site: Site,
    start_hhmm: str,
    ground_truth: dict[str, GroundTruthSlot],
) -> tuple[str, GroundTruthSlot]:
    """Map a clip start time to its containing slot label using the site's
    ``ground_truth.slot_minutes`` granularity (default 15)."""
    h, m = (int(x) for x in start_hhmm.split(":"))
    step = site.slot_minutes
    bucket = (m // step) * step
    if bucket + step >= 60:
        label = f"{h:02d}:{bucket:02d}-{h+1:02d}:00"
    else:
        label = f"{h:02d}:{bucket:02d}-{h:02d}:{bucket+step:02d}"
    if label not in ground_truth:
        raise SystemExit(
            f"No ground-truth slot {label} for site {site.name}; "
            f"available: {list(ground_truth)[:5]}…"
        )
    return label, ground_truth[label]


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--site", default=str(DEFAULT_SITE_PATH),
                        help=f"Site config JSON (default: {DEFAULT_SITE_PATH.relative_to(REPO_ROOT)})")
    parser.add_argument("--clip", default="07:00", help="Clip start HH:MM (default 07:00)")
    parser.add_argument("--clips",
                        help="Comma-separated list of HH:MM starts to batch "
                             "(e.g. '07:00,07:30,08:00'). Overrides --clip. "
                             "Aggregate summary printed at the end.")
    parser.add_argument("--calibration",
                        help="Calibration JSON (defaults to site's calibration_default)")
    parser.add_argument("--no-cache", action="store_true",
                        help="Force pipeline re-run, ignore cached report")
    parser.add_argument("--trim-seconds", type=float, default=None,
                        help="Run on only the first N seconds of the clip (fast iteration)")
    args = parser.parse_args()

    site = Site.from_json(Path(args.site))
    logger.info("Site: %s (%s, %s)", site.name, site.display_name, site.road_type)

    # Resolve calibration path: explicit --calibration wins, else site default.
    cal_json: str | None = None
    cal_tag = "default"
    cal_path: Path | None = None
    if args.calibration:
        cal_path = Path(args.calibration)
    elif site.calibration_default and site.calibration_default.exists():
        cal_path = site.calibration_default
    if cal_path is not None:
        cal_json = cal_path.read_text()
        cal_tag = cal_path.stem

    truth_slots = parse_ground_truth(site)

    # Decide which start times to run.
    if args.clips:
        starts = [s.strip() for s in args.clips.split(",") if s.strip()]
    else:
        starts = [args.clip]

    cache_dir = REPO_ROOT / "scripts" / ".measure_cache"
    slot_seconds = site.slot_minutes * 60
    aggregate_rows: list[tuple[str, dict[str, int], dict[str, int]]] = []

    for start in starts:
        slot_label, slot = slot_for_clip(site, start, truth_slots)
        clip_path = find_clip(site, start)
        tag = cal_tag
        # Clip duration depends on the MP4 itself — 5-min clips at Seodang
        # but we pro-rate explicitly so other sites work too.
        if args.trim_seconds:
            clip_path = trim_clip(clip_path, args.trim_seconds, cache_dir / "trims")
            ratio = args.trim_seconds / slot_seconds
            slot_label_display = f"{slot_label} (×{ratio:.3f} for {args.trim_seconds:.0f}s trim)"
            truth_scaled = slot.prorate(ratio, label_suffix=f" ({args.trim_seconds:.0f}s)")
            tag = f"{cal_tag}_trim{int(args.trim_seconds)}s"
        else:
            clip_seconds = _probe_clip_duration(clip_path)
            ratio = clip_seconds / slot_seconds
            slot_label_display = (
                f"{slot_label} (×{ratio:.3f} for {clip_seconds:.0f}s clip)"
            )
            truth_scaled = slot.prorate(ratio, label_suffix=f" (×{ratio:.2f})")
        cache_path = (
            None if args.no_cache
            else cache_dir / f"{site.name}__{clip_path.stem}__{tag}.json"
        )

        logger.info("Running pipeline on %s …", clip_path.name)
        report = run_clip(clip_path, cal_json, cache_path)
        predicted = aggregate_predicted(report)
        print_report(
            clip_path=clip_path,
            slot_label=slot_label_display,
            truth_scaled=truth_scaled,
            predicted=predicted,
            full_pipeline_report=report,
        )
        aggregate_rows.append((start, predicted, dict(truth_scaled.counts)))

    # Batch summary when more than one clip was processed.
    if len(aggregate_rows) > 1:
        _print_batch_summary(aggregate_rows)


def _print_batch_summary(
    rows: list[tuple[str, dict[str, int], dict[str, int]]],
) -> None:
    """Aggregate predicted vs truth across all clips in a batch run."""
    print("\n" + "=" * 72)
    print("BATCH SUMMARY (all clips)")
    print("=" * 72)
    header = f"{'START':<8}  {'TOTAL_PRED':>10}  {'TOTAL_TRUTH':>11}  {'DIFF':>6}  {'DIFF%':>6}"
    print(header)
    print("-" * 72)
    tot_pred = 0
    tot_truth = 0
    for start, pred, truth in rows:
        p = sum(pred.values())
        t = sum(truth.values())
        diff = p - t
        pct = (diff / t * 100) if t > 0 else 0.0
        print(f"{start:<8}  {p:>10}  {t:>11}  {diff:>+6}  {pct:>+5.0f}%")
        tot_pred += p
        tot_truth += t
    print("-" * 72)
    tot_diff = tot_pred - tot_truth
    tot_pct = (tot_diff / tot_truth * 100) if tot_truth > 0 else 0.0
    print(f"{'TOTAL':<8}  {tot_pred:>10}  {tot_truth:>11}  {tot_diff:>+6}  {tot_pct:>+5.0f}%")
    print("=" * 72)


def _probe_clip_duration(clip_path: Path) -> float:
    import cv2

    cap = cv2.VideoCapture(str(clip_path))
    fps = cap.get(cv2.CAP_PROP_FPS) or 25.0
    frames = cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0
    cap.release()
    return float(frames) / fps if fps else 0.0


if __name__ == "__main__":
    main()
