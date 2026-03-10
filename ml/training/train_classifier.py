"""Train the GreyEye 12-class vehicle classifier.

Uses a ``timm`` backbone (EfficientNet-B0 or MobileNetV3) with focal loss
and inverse-frequency weighted sampling to handle the heavily skewed
traffic class distribution.

Usage::

    python -m ml.training.train_classifier \
        --config ml/training/config/classifier_base.yaml \
        --train-dir /data/greyeye/classifier/train \
        --val-dir /data/greyeye/classifier/val \
        --output-dir runs/classifier/exp1
"""

from __future__ import annotations

import argparse
import copy
import json
import logging
import time
from pathlib import Path

import timm
import torch
import torch.nn as nn
import yaml
from torch.utils.data import DataLoader

from ml.data.dataset import GreyEyeClassifierDataset
from ml.data.sampler import ClassWeightedSampler
from ml.training.augmentations import classifier_train_transform, classifier_val_transform
from ml.training.losses import FocalLoss, LabelSmoothingCrossEntropy

logger = logging.getLogger(__name__)

NUM_CLASSES = 12


def _build_model(cfg: dict) -> nn.Module:
    model_cfg = cfg["model"]
    backbone_name = model_cfg.get("backbone", "efficientnet_b0")
    model = timm.create_model(
        backbone_name,
        pretrained=model_cfg.get("pretrained", True),
        num_classes=NUM_CLASSES,
        drop_rate=model_cfg.get("dropout", 0.3),
    )
    return model


def _build_loss(cfg: dict, class_weights: torch.Tensor | None) -> nn.Module:
    loss_cfg = cfg.get("loss", {})
    loss_type = loss_cfg.get("type", "focal")

    if loss_type == "focal":
        alpha = class_weights if loss_cfg.get("class_weights", True) else None
        return FocalLoss(
            gamma=loss_cfg.get("gamma", 2.0),
            alpha=alpha,
            label_smoothing=loss_cfg.get("label_smoothing", 0.1),
        )
    else:
        return LabelSmoothingCrossEntropy(
            epsilon=loss_cfg.get("label_smoothing", 0.1),
        )


def _build_optimizer(model: nn.Module, cfg: dict) -> torch.optim.Optimizer:
    train_cfg = cfg["training"]
    return torch.optim.AdamW(
        model.parameters(),
        lr=train_cfg.get("lr", 3e-4),
        weight_decay=train_cfg.get("weight_decay", 1e-4),
    )


def _build_scheduler(
    optimizer: torch.optim.Optimizer, cfg: dict
) -> torch.optim.lr_scheduler.LRScheduler:
    train_cfg = cfg["training"]
    sched_type = train_cfg.get("scheduler", "cosine_warm_restarts")
    if sched_type == "cosine_warm_restarts":
        return torch.optim.lr_scheduler.CosineAnnealingWarmRestarts(
            optimizer,
            T_0=train_cfg.get("t_0", 10),
            T_mult=train_cfg.get("t_mult", 2),
        )
    return torch.optim.lr_scheduler.CosineAnnealingLR(
        optimizer,
        T_max=train_cfg.get("epochs", 50),
    )


def _train_one_epoch(
    model: nn.Module,
    loader: DataLoader,
    criterion: nn.Module,
    optimizer: torch.optim.Optimizer,
    device: torch.device,
) -> float:
    model.train()
    running_loss = 0.0
    n_samples = 0

    for images, labels in loader:
        images = images.to(device)
        labels = labels.to(device)

        optimizer.zero_grad()
        logits = model(images)
        loss = criterion(logits, labels)
        loss.backward()
        optimizer.step()

        running_loss += loss.item() * images.size(0)
        n_samples += images.size(0)

    return running_loss / max(n_samples, 1)


@torch.no_grad()
def _validate(
    model: nn.Module,
    loader: DataLoader,
    criterion: nn.Module,
    device: torch.device,
) -> dict[str, float]:
    model.eval()
    running_loss = 0.0
    correct = 0
    total = 0
    per_class_correct = [0] * NUM_CLASSES
    per_class_total = [0] * NUM_CLASSES

    for images, labels in loader:
        images = images.to(device)
        labels = labels.to(device)

        logits = model(images)
        loss = criterion(logits, labels)
        running_loss += loss.item() * images.size(0)

        preds = logits.argmax(dim=1)
        correct += (preds == labels).sum().item()
        total += labels.size(0)

        for c in range(NUM_CLASSES):
            mask = labels == c
            per_class_correct[c] += (preds[mask] == c).sum().item()
            per_class_total[c] += mask.sum().item()

    per_class_acc = [
        per_class_correct[c] / max(per_class_total[c], 1) for c in range(NUM_CLASSES)
    ]
    macro_f1 = sum(per_class_acc) / NUM_CLASSES  # simplified macro metric

    return {
        "val_loss": running_loss / max(total, 1),
        "val_accuracy": correct / max(total, 1),
        "val_f1_macro": macro_f1,
        "per_class_accuracy": per_class_acc,
    }


def train(
    config_path: Path,
    train_dir: Path | None = None,
    val_dir: Path | None = None,
    output_dir: Path | None = None,
    resume: Path | None = None,
) -> Path:
    """Run classifier training and return the path to the best checkpoint.

    Parameters
    ----------
    config_path:
        YAML config file (see ``config/classifier_base.yaml``).
    train_dir, val_dir:
        Override annotation directories from config.
    output_dir:
        Override output directory.
    resume:
        Path to a checkpoint to resume from.
    """
    with open(config_path, encoding="utf-8") as f:
        cfg = yaml.safe_load(f)

    model_cfg = cfg["model"]
    train_cfg = cfg["training"]
    data_cfg = cfg.get("data", {})
    out_cfg = cfg.get("output", {})

    project = output_dir or Path(out_cfg.get("project", "runs/classifier"))
    name = out_cfg.get("name", "base")
    save_dir = project / name
    save_dir.mkdir(parents=True, exist_ok=True)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    logger.info("Device: %s", device)

    input_size = model_cfg.get("input_size", 224)
    t_dir = train_dir or Path(data_cfg.get("train_dir", ""))
    v_dir = val_dir or Path(data_cfg.get("val_dir", ""))

    train_ds = GreyEyeClassifierDataset(
        t_dir,
        transform=classifier_train_transform(input_size),
        min_crop_px=data_cfg.get("min_crop_px", 16),
    )
    val_ds = GreyEyeClassifierDataset(
        v_dir,
        transform=classifier_val_transform(input_size),
        min_crop_px=data_cfg.get("min_crop_px", 16),
    )

    logger.info("Train samples: %d, Val samples: %d", len(train_ds), len(val_ds))

    sampling_cfg = cfg.get("sampling", {})
    if sampling_cfg.get("weighted", True) and len(train_ds) > 0:
        sampler_factory = ClassWeightedSampler(
            train_ds, smoothing=sampling_cfg.get("smoothing", 0.5)
        )
        train_sampler = sampler_factory.build()
        class_weights = sampler_factory.class_weights_tensor()
        shuffle = False
    else:
        train_sampler = None
        class_weights = None
        shuffle = True

    workers = data_cfg.get("workers", 8)
    batch_size = train_cfg.get("batch_size", 64)

    train_loader = DataLoader(
        train_ds,
        batch_size=batch_size,
        sampler=train_sampler,
        shuffle=shuffle,
        num_workers=workers,
        pin_memory=True,
        drop_last=True,
    )
    val_loader = DataLoader(
        val_ds,
        batch_size=batch_size,
        shuffle=False,
        num_workers=workers,
        pin_memory=True,
    )

    model = _build_model(cfg).to(device)
    criterion = _build_loss(cfg, class_weights).to(device)
    optimizer = _build_optimizer(model, cfg)
    scheduler = _build_scheduler(optimizer, cfg)

    start_epoch = 0
    if resume:
        ckpt = torch.load(resume, map_location=device, weights_only=False)
        model.load_state_dict(ckpt["model_state_dict"])
        optimizer.load_state_dict(ckpt["optimizer_state_dict"])
        start_epoch = ckpt.get("epoch", 0) + 1
        logger.info("Resumed from epoch %d", start_epoch)

    epochs = train_cfg.get("epochs", 50)
    patience = train_cfg.get("early_stopping", {}).get("patience", 10)
    metric_key = train_cfg.get("early_stopping", {}).get("metric", "val_f1_macro")
    save_period = out_cfg.get("save_period", 5)

    best_metric = -float("inf")
    best_state = None
    epochs_without_improvement = 0

    history: list[dict] = []

    for epoch in range(start_epoch, epochs):
        t0 = time.time()
        train_loss = _train_one_epoch(model, train_loader, criterion, optimizer, device)
        val_metrics = _validate(model, val_loader, criterion, device)
        scheduler.step()
        elapsed = time.time() - t0

        current_metric = val_metrics.get(metric_key, val_metrics["val_accuracy"])

        record = {
            "epoch": epoch,
            "train_loss": train_loss,
            **{k: v for k, v in val_metrics.items() if k != "per_class_accuracy"},
            "lr": optimizer.param_groups[0]["lr"],
            "elapsed_s": round(elapsed, 1),
        }
        history.append(record)

        logger.info(
            "Epoch %d/%d — train_loss=%.4f  val_acc=%.4f  val_f1=%.4f  lr=%.2e  (%.1fs)",
            epoch + 1,
            epochs,
            train_loss,
            val_metrics["val_accuracy"],
            val_metrics["val_f1_macro"],
            optimizer.param_groups[0]["lr"],
            elapsed,
        )

        if current_metric > best_metric:
            best_metric = current_metric
            best_state = copy.deepcopy(model.state_dict())
            epochs_without_improvement = 0
            torch.save(
                {
                    "epoch": epoch,
                    "model_state_dict": model.state_dict(),
                    "optimizer_state_dict": optimizer.state_dict(),
                    "best_metric": best_metric,
                    "config": cfg,
                },
                save_dir / "best.pt",
            )
        else:
            epochs_without_improvement += 1

        if epoch % save_period == 0 or epoch == epochs - 1:
            torch.save(
                {
                    "epoch": epoch,
                    "model_state_dict": model.state_dict(),
                    "optimizer_state_dict": optimizer.state_dict(),
                    "config": cfg,
                },
                save_dir / f"epoch_{epoch:03d}.pt",
            )

        if patience and epochs_without_improvement >= patience:
            logger.info("Early stopping at epoch %d (patience=%d)", epoch + 1, patience)
            break

    if best_state is not None:
        model.load_state_dict(best_state)
        torch.save(
            {"model_state_dict": best_state, "config": cfg, "best_metric": best_metric},
            save_dir / "best.pt",
        )

    (save_dir / "history.json").write_text(
        json.dumps(history, indent=2), encoding="utf-8"
    )

    logger.info("Training complete — best %s=%.4f", metric_key, best_metric)
    return save_dir / "best.pt"


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Train GreyEye 12-class vehicle classifier"
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("ml/training/config/classifier_base.yaml"),
    )
    parser.add_argument("--train-dir", type=Path, default=None)
    parser.add_argument("--val-dir", type=Path, default=None)
    parser.add_argument("--output-dir", type=Path, default=None)
    parser.add_argument("--resume", type=Path, default=None)
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    train(args.config, args.train_dir, args.val_dir, args.output_dir, args.resume)


if __name__ == "__main__":
    main()
