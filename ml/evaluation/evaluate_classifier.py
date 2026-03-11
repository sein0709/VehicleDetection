"""Evaluate the GreyEye 12-class vehicle classifier.

Computes top-1 accuracy, per-class precision / recall / F1, macro-averaged
F1, and a confusion matrix.

Usage::

    python -m ml.evaluation.evaluate_classifier \
        --model runs/classifier/base/best.pt \
        --val-dir /data/greyeye/classifier/val \
        --output-dir runs/classifier/base/eval
"""

from __future__ import annotations

import argparse
import json
import logging
from pathlib import Path

import numpy as np
import timm
import torch
import torch.nn as nn
from torch.utils.data import DataLoader

from ml.data.dataset import GreyEyeClassifierDataset
from ml.training.augmentations import classifier_val_transform
from ml.shared_contracts.enums import VehicleClass12

logger = logging.getLogger(__name__)

NUM_CLASSES = 12

CLASS_NAMES = [VehicleClass12(i + 1).english_name for i in range(NUM_CLASSES)]


def _load_model(model_path: Path, device: torch.device) -> nn.Module:
    ckpt = torch.load(model_path, map_location=device, weights_only=False)
    cfg = ckpt.get("config", {})
    model_cfg = cfg.get("model", {})

    backbone = model_cfg.get("backbone", "efficientnet_b0")
    model = timm.create_model(
        backbone,
        pretrained=False,
        num_classes=NUM_CLASSES,
        drop_rate=model_cfg.get("dropout", 0.3),
    )
    model.load_state_dict(ckpt["model_state_dict"])
    return model.to(device).eval()


def _compute_metrics(
    all_preds: np.ndarray, all_labels: np.ndarray
) -> dict:
    """Compute per-class and aggregate classification metrics."""
    accuracy = float(np.mean(all_preds == all_labels))

    per_class: list[dict] = []
    for c in range(NUM_CLASSES):
        tp = int(np.sum((all_preds == c) & (all_labels == c)))
        fp = int(np.sum((all_preds == c) & (all_labels != c)))
        fn = int(np.sum((all_preds != c) & (all_labels == c)))
        support = int(np.sum(all_labels == c))

        precision = tp / max(tp + fp, 1)
        recall = tp / max(tp + fn, 1)
        f1 = 2 * precision * recall / max(precision + recall, 1e-8)

        per_class.append(
            {
                "class_index": c,
                "class_name": CLASS_NAMES[c],
                "precision": round(precision, 4),
                "recall": round(recall, 4),
                "f1": round(f1, 4),
                "support": support,
            }
        )

    macro_f1 = float(np.mean([m["f1"] for m in per_class]))
    weighted_f1 = float(
        np.average(
            [m["f1"] for m in per_class],
            weights=[m["support"] for m in per_class]
            if any(m["support"] > 0 for m in per_class)
            else None,
        )
    )

    confusion = np.zeros((NUM_CLASSES, NUM_CLASSES), dtype=int)
    for pred, label in zip(all_preds, all_labels):
        confusion[label, pred] += 1

    return {
        "accuracy": round(accuracy, 4),
        "macro_f1": round(macro_f1, 4),
        "weighted_f1": round(weighted_f1, 4),
        "per_class": per_class,
        "confusion_matrix": confusion.tolist(),
    }


@torch.no_grad()
def evaluate(
    model_path: Path,
    val_dir: Path,
    output_dir: Path | None = None,
    *,
    input_size: int = 224,
    batch_size: int = 64,
    workers: int = 8,
) -> dict:
    """Run classifier evaluation and return metrics.

    Returns
    -------
    dict
        Includes ``accuracy``, ``macro_f1``, ``weighted_f1``,
        ``per_class`` metrics, and ``confusion_matrix``.
    """
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = _load_model(model_path, device)

    val_ds = GreyEyeClassifierDataset(
        val_dir, transform=classifier_val_transform(input_size)
    )
    val_loader = DataLoader(
        val_ds, batch_size=batch_size, shuffle=False, num_workers=workers, pin_memory=True
    )

    all_preds: list[int] = []
    all_labels: list[int] = []

    for images, labels in val_loader:
        images = images.to(device)
        logits = model(images)
        preds = logits.argmax(dim=1).cpu().tolist()
        all_preds.extend(preds)
        all_labels.extend(labels.tolist())

    metrics = _compute_metrics(np.array(all_preds), np.array(all_labels))

    logger.info(
        "Classifier eval — accuracy=%.4f  macro_F1=%.4f  weighted_F1=%.4f",
        metrics["accuracy"],
        metrics["macro_f1"],
        metrics["weighted_f1"],
    )

    for m in metrics["per_class"]:
        logger.info(
            "  %-35s  P=%.3f  R=%.3f  F1=%.3f  (n=%d)",
            m["class_name"],
            m["precision"],
            m["recall"],
            m["f1"],
            m["support"],
        )

    target_acc = 0.80
    if metrics["accuracy"] < target_acc:
        logger.warning(
            "Top-1 accuracy (%.4f) is below target (%.2f)",
            metrics["accuracy"],
            target_acc,
        )

    if output_dir:
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / "classifier_metrics.json").write_text(
            json.dumps(metrics, indent=2), encoding="utf-8"
        )
        logger.info("Metrics written to %s", output_dir / "classifier_metrics.json")

    return metrics


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Evaluate GreyEye 12-class vehicle classifier"
    )
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--val-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=None)
    parser.add_argument("--input-size", type=int, default=224)
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--workers", type=int, default=8)
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    evaluate(
        args.model,
        args.val_dir,
        args.output_dir,
        input_size=args.input_size,
        batch_size=args.batch_size,
        workers=args.workers,
    )


if __name__ == "__main__":
    main()
