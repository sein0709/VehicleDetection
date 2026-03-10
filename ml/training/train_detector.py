"""Train the GreyEye vehicle detector using the Ultralytics YOLO API.

The detector is a single-class ("vehicle") model.  Pre-training follows:
COCO weights → fine-tune on AI Hub 091 union bboxes → fine-tune on field data.

Usage::

    python -m ml.training.train_detector \
        --config ml/training/config/detector_base.yaml \
        --data-yaml /data/greyeye/detector_dataset.yaml \
        --output-dir runs/detector/exp1
"""

from __future__ import annotations

import argparse
import logging
import shutil
from pathlib import Path

import yaml
from ultralytics import YOLO

logger = logging.getLogger(__name__)


def _load_config(config_path: Path) -> dict:
    with open(config_path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def _create_dataset_yaml(
    train_dir: str,
    val_dir: str,
    output_path: Path,
) -> Path:
    """Generate a YOLO-format dataset YAML if one is not provided."""
    ds = {
        "path": str(output_path.parent),
        "train": train_dir,
        "val": val_dir,
        "nc": 1,
        "names": ["vehicle"],
    }
    output_path.write_text(yaml.dump(ds, default_flow_style=False), encoding="utf-8")
    return output_path


def train(
    config_path: Path,
    data_yaml: Path | None = None,
    output_dir: Path | None = None,
    resume: Path | None = None,
) -> Path:
    """Run detector training and return the path to the best checkpoint.

    Parameters
    ----------
    config_path:
        Path to a YAML config file (see ``config/detector_base.yaml``).
    data_yaml:
        Ultralytics-format dataset YAML.  If ``None``, one is generated
        from the ``data.train_dir`` / ``data.val_dir`` in the config.
    output_dir:
        Override for the output directory.
    resume:
        Path to a checkpoint to resume training from.
    """
    cfg = _load_config(config_path)
    model_cfg = cfg["model"]
    train_cfg = cfg["training"]
    aug_cfg = cfg.get("augmentation", {})
    data_cfg = cfg.get("data", {})
    out_cfg = cfg.get("output", {})

    project = output_dir or Path(out_cfg.get("project", "runs/detector"))
    name = out_cfg.get("name", "base")

    if data_yaml is None:
        data_yaml = project / name / "dataset.yaml"
        data_yaml.parent.mkdir(parents=True, exist_ok=True)
        _create_dataset_yaml(
            data_cfg.get("train_dir", ""),
            data_cfg.get("val_dir", ""),
            data_yaml,
        )

    if resume:
        model = YOLO(str(resume))
        logger.info("Resuming from %s", resume)
    else:
        model = YOLO(model_cfg.get("pretrained", "yolov8m.pt"))
        logger.info("Starting from %s", model_cfg.get("pretrained"))

    results = model.train(
        data=str(data_yaml),
        epochs=train_cfg.get("epochs", 100),
        batch=train_cfg.get("batch_size", 16),
        imgsz=model_cfg.get("input_size", 640),
        optimizer=train_cfg.get("optimizer", "AdamW"),
        lr0=train_cfg.get("lr", 1e-3),
        weight_decay=train_cfg.get("weight_decay", 5e-4),
        cos_lr=train_cfg.get("scheduler") == "cosine",
        warmup_epochs=train_cfg.get("warmup_epochs", 3),
        patience=train_cfg.get("early_stopping", {}).get("patience", 15),
        workers=data_cfg.get("workers", 8),
        project=str(project),
        name=name,
        save_period=out_cfg.get("save_period", 10),
        mosaic=aug_cfg.get("mosaic", 1.0),
        mixup=aug_cfg.get("mixup", 0.15),
        hsv_h=aug_cfg.get("hsv_h", 0.015),
        hsv_s=aug_cfg.get("hsv_s", 0.7),
        hsv_v=aug_cfg.get("hsv_v", 0.4),
        flipud=aug_cfg.get("flipud", 0.0),
        fliplr=aug_cfg.get("fliplr", 0.5),
        scale=aug_cfg.get("scale", 0.5),
        translate=aug_cfg.get("translate", 0.1),
        exist_ok=True,
        verbose=True,
    )

    best_pt = project / name / "weights" / "best.pt"
    if not best_pt.exists():
        best_pt = project / name / "weights" / "last.pt"

    logger.info("Training complete — best checkpoint: %s", best_pt)
    return best_pt


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Train GreyEye vehicle detector")
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("ml/training/config/detector_base.yaml"),
    )
    parser.add_argument("--data-yaml", type=Path, default=None)
    parser.add_argument("--output-dir", type=Path, default=None)
    parser.add_argument("--resume", type=Path, default=None)
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    train(args.config, args.data_yaml, args.output_dir, args.resume)


if __name__ == "__main__":
    main()
