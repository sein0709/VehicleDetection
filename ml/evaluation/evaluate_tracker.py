"""Evaluate multi-object tracker performance: MOTA, IDF1, ID switches.

Compares tracker output against ground-truth track annotations in
MOTChallenge format.

Usage::

    python -m ml.evaluation.evaluate_tracker \
        --gt-dir /data/greyeye/tracker_eval/gt \
        --pred-dir /data/greyeye/tracker_eval/pred \
        --output-dir runs/tracker/eval
"""

from __future__ import annotations

import argparse
import json
import logging
from pathlib import Path

import numpy as np

logger = logging.getLogger(__name__)


def _load_mot_file(path: Path) -> dict[int, list[tuple[int, float, float, float, float]]]:
    """Load a MOTChallenge-format file.

    Format: ``frame, id, x, y, w, h, conf, -1, -1, -1``

    Returns
    -------
    dict[int, list[...]]
        Mapping from frame number to list of ``(track_id, x, y, w, h)``.
    """
    tracks: dict[int, list[tuple[int, float, float, float, float]]] = {}
    if not path.exists():
        return tracks

    for line in path.read_text(encoding="utf-8").strip().splitlines():
        parts = line.strip().split(",")
        if len(parts) < 6:
            continue
        frame = int(parts[0])
        tid = int(parts[1])
        x, y, w, h = float(parts[2]), float(parts[3]), float(parts[4]), float(parts[5])
        tracks.setdefault(frame, []).append((tid, x, y, w, h))
    return tracks


def _iou(box_a: tuple[float, float, float, float], box_b: tuple[float, float, float, float]) -> float:
    """Compute IoU between two (x, y, w, h) boxes."""
    ax1, ay1 = box_a[0], box_a[1]
    ax2, ay2 = ax1 + box_a[2], ay1 + box_a[3]
    bx1, by1 = box_b[0], box_b[1]
    bx2, by2 = bx1 + box_b[2], by1 + box_b[3]

    ix1 = max(ax1, bx1)
    iy1 = max(ay1, by1)
    ix2 = min(ax2, bx2)
    iy2 = min(ay2, by2)

    inter = max(0.0, ix2 - ix1) * max(0.0, iy2 - iy1)
    area_a = box_a[2] * box_a[3]
    area_b = box_b[2] * box_b[3]
    union = area_a + area_b - inter
    return inter / max(union, 1e-8)


def compute_mot_metrics(
    gt: dict[int, list[tuple[int, float, float, float, float]]],
    pred: dict[int, list[tuple[int, float, float, float, float]]],
    iou_threshold: float = 0.5,
) -> dict[str, float]:
    """Compute CLEAR MOT metrics.

    Returns
    -------
    dict
        Keys: ``MOTA``, ``IDF1``, ``id_switches``, ``mostly_tracked``,
        ``mostly_lost``, ``false_positives``, ``missed``, ``num_gt``.
    """
    all_frames = sorted(set(list(gt.keys()) + list(pred.keys())))

    total_gt = 0
    total_fp = 0
    total_missed = 0
    total_id_switches = 0
    total_matches = 0

    prev_mapping: dict[int, int] = {}  # gt_id → pred_id from previous frame

    gt_track_frames: dict[int, int] = {}
    gt_track_matched: dict[int, int] = {}

    for frame in all_frames:
        gt_objs = gt.get(frame, [])
        pred_objs = pred.get(frame, [])
        total_gt += len(gt_objs)

        for gt_id, *_ in gt_objs:
            gt_track_frames[gt_id] = gt_track_frames.get(gt_id, 0) + 1

        if not gt_objs:
            total_fp += len(pred_objs)
            continue
        if not pred_objs:
            total_missed += len(gt_objs)
            continue

        iou_matrix = np.zeros((len(gt_objs), len(pred_objs)))
        for i, (_, *gt_box) in enumerate(gt_objs):
            for j, (_, *pred_box) in enumerate(pred_objs):
                iou_matrix[i, j] = _iou(tuple(gt_box), tuple(pred_box))

        matched_gt: set[int] = set()
        matched_pred: set[int] = set()
        current_mapping: dict[int, int] = {}

        pairs = []
        for i in range(len(gt_objs)):
            for j in range(len(pred_objs)):
                if iou_matrix[i, j] >= iou_threshold:
                    pairs.append((iou_matrix[i, j], i, j))
        pairs.sort(reverse=True)

        for _, i, j in pairs:
            if i in matched_gt or j in matched_pred:
                continue
            matched_gt.add(i)
            matched_pred.add(j)

            gt_id = gt_objs[i][0]
            pred_id = pred_objs[j][0]
            current_mapping[gt_id] = pred_id

            gt_track_matched[gt_id] = gt_track_matched.get(gt_id, 0) + 1

            if gt_id in prev_mapping and prev_mapping[gt_id] != pred_id:
                total_id_switches += 1

            total_matches += 1

        total_missed += len(gt_objs) - len(matched_gt)
        total_fp += len(pred_objs) - len(matched_pred)
        prev_mapping = current_mapping

    mota = 1.0 - (total_missed + total_fp + total_id_switches) / max(total_gt, 1)

    idf1_precision = total_matches / max(total_matches + total_fp, 1)
    idf1_recall = total_matches / max(total_matches + total_missed, 1)
    idf1 = (
        2 * idf1_precision * idf1_recall / max(idf1_precision + idf1_recall, 1e-8)
    )

    mostly_tracked = sum(
        1
        for tid, total in gt_track_frames.items()
        if gt_track_matched.get(tid, 0) / max(total, 1) >= 0.8
    )
    mostly_lost = sum(
        1
        for tid, total in gt_track_frames.items()
        if gt_track_matched.get(tid, 0) / max(total, 1) <= 0.2
    )

    return {
        "MOTA": round(mota, 4),
        "IDF1": round(idf1, 4),
        "id_switches": total_id_switches,
        "mostly_tracked": mostly_tracked,
        "mostly_lost": mostly_lost,
        "false_positives": total_fp,
        "missed": total_missed,
        "num_gt": total_gt,
        "num_gt_tracks": len(gt_track_frames),
    }


def evaluate(
    gt_dir: Path,
    pred_dir: Path,
    output_dir: Path | None = None,
    *,
    iou_threshold: float = 0.5,
) -> dict:
    """Evaluate tracker on all sequences in *gt_dir* / *pred_dir*.

    Each sequence is a ``.txt`` file in MOTChallenge format.
    """
    gt_files = sorted(gt_dir.glob("*.txt"))
    if not gt_files:
        logger.warning("No ground-truth files found in %s", gt_dir)
        return {}

    all_metrics: dict[str, dict] = {}
    for gt_file in gt_files:
        pred_file = pred_dir / gt_file.name
        gt = _load_mot_file(gt_file)
        pred = _load_mot_file(pred_file)
        metrics = compute_mot_metrics(gt, pred, iou_threshold=iou_threshold)
        all_metrics[gt_file.stem] = metrics
        logger.info(
            "Sequence %-20s  MOTA=%.4f  IDF1=%.4f  IDsw=%d",
            gt_file.stem,
            metrics["MOTA"],
            metrics["IDF1"],
            metrics["id_switches"],
        )

    if len(all_metrics) > 1:
        agg = {}
        for key in ["MOTA", "IDF1"]:
            agg[key] = round(
                float(np.mean([m[key] for m in all_metrics.values()])), 4
            )
        agg["total_id_switches"] = sum(m["id_switches"] for m in all_metrics.values())
        all_metrics["_aggregate"] = agg
        logger.info(
            "Aggregate — MOTA=%.4f  IDF1=%.4f  total_IDsw=%d",
            agg["MOTA"],
            agg["IDF1"],
            agg["total_id_switches"],
        )

    target_mota = 0.75
    avg_mota = all_metrics.get("_aggregate", {}).get(
        "MOTA", next(iter(all_metrics.values()), {}).get("MOTA", 0)
    )
    if avg_mota < target_mota:
        logger.warning("MOTA (%.4f) is below target (%.2f)", avg_mota, target_mota)

    if output_dir:
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / "tracker_metrics.json").write_text(
            json.dumps(all_metrics, indent=2), encoding="utf-8"
        )

    return all_metrics


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Evaluate GreyEye tracker")
    parser.add_argument("--gt-dir", type=Path, required=True)
    parser.add_argument("--pred-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=None)
    parser.add_argument("--iou-threshold", type=float, default=0.5)
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    evaluate(args.gt_dir, args.pred_dir, args.output_dir, iou_threshold=args.iou_threshold)


if __name__ == "__main__":
    main()
