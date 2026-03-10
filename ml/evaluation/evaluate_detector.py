"""Evaluate the GreyEye vehicle detector: mAP, precision-recall curves.

Runs the YOLO model on a validation set and computes COCO-style metrics
using the Ultralytics built-in evaluator.

Usage::

    python -m ml.evaluation.evaluate_detector \
        --model runs/detector/base/weights/best.pt \
        --data-yaml /data/greyeye/detector_dataset.yaml \
        --output-dir runs/detector/base/eval
"""

from __future__ import annotations

import argparse
import json
import logging
from pathlib import Path

from ultralytics import YOLO

logger = logging.getLogger(__name__)


def evaluate(
    model_path: Path,
    data_yaml: Path,
    output_dir: Path | None = None,
    *,
    input_size: int = 640,
    conf_threshold: float = 0.25,
    iou_threshold: float = 0.45,
    batch_size: int = 16,
) -> dict:
    """Run detector evaluation and return metrics.

    Returns
    -------
    dict
        Keys include ``mAP50``, ``mAP50-95``, ``precision``, ``recall``,
        and per-class breakdowns.
    """
    model = YOLO(str(model_path))

    results = model.val(
        data=str(data_yaml),
        imgsz=input_size,
        conf=conf_threshold,
        iou=iou_threshold,
        batch=batch_size,
        verbose=True,
    )

    metrics = {
        "mAP50": float(results.box.map50),
        "mAP50-95": float(results.box.map),
        "precision": float(results.box.mp),
        "recall": float(results.box.mr),
    }

    if hasattr(results.box, "maps") and results.box.maps is not None:
        metrics["per_class_mAP50"] = [float(v) for v in results.box.maps]

    if output_dir:
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / "detector_metrics.json").write_text(
            json.dumps(metrics, indent=2), encoding="utf-8"
        )
        logger.info("Metrics written to %s", output_dir / "detector_metrics.json")

    logger.info(
        "Detector eval — mAP@0.5=%.4f  mAP@0.5:0.95=%.4f  P=%.4f  R=%.4f",
        metrics["mAP50"],
        metrics["mAP50-95"],
        metrics["precision"],
        metrics["recall"],
    )

    target_map50 = 0.85
    if metrics["mAP50"] < target_map50:
        logger.warning(
            "mAP@0.5 (%.4f) is below target (%.2f)", metrics["mAP50"], target_map50
        )

    return metrics


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Evaluate GreyEye vehicle detector")
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--data-yaml", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=None)
    parser.add_argument("--input-size", type=int, default=640)
    parser.add_argument("--conf", type=float, default=0.25)
    parser.add_argument("--iou", type=float, default=0.45)
    parser.add_argument("--batch-size", type=int, default=16)
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    evaluate(
        args.model,
        args.data_yaml,
        args.output_dir,
        input_size=args.input_size,
        conf_threshold=args.conf,
        iou_threshold=args.iou,
        batch_size=args.batch_size,
    )


if __name__ == "__main__":
    main()
