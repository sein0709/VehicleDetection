"""Export the GreyEye 12-class vehicle classifier to ONNX and TorchScript.

Loads a training checkpoint, rebuilds the ``timm`` model, and exports
with proper input/output naming and dynamic batch axis.

Usage::

    python -m ml.export.export_classifier \
        --model runs/classifier/base/best.pt \
        --output-dir models/classifier/v1.0.0 \
        --input-size 224
"""

from __future__ import annotations

import argparse
import json
import logging
from datetime import datetime, timezone
from pathlib import Path

import onnx
import timm
import torch
import torch.nn as nn

from shared_contracts.enums import VehicleClass12

logger = logging.getLogger(__name__)

NUM_CLASSES = 12
CLASS_NAMES = [VehicleClass12(i + 1).english_name for i in range(NUM_CLASSES)]


def _load_model(model_path: Path, device: torch.device) -> tuple[nn.Module, dict]:
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
    return model.to(device).eval(), cfg


def export_onnx(
    model_path: Path,
    output_dir: Path,
    *,
    input_size: int = 224,
    opset: int = 17,
    dynamic_batch: bool = True,
) -> Path:
    """Export classifier to ONNX format.

    Returns the path to the exported ``.onnx`` file.
    """
    device = torch.device("cpu")
    model, _ = _load_model(model_path, device)

    dummy = torch.randn(1, 3, input_size, input_size, device=device)

    output_dir.mkdir(parents=True, exist_ok=True)
    dest = output_dir / "model.onnx"

    dynamic_axes = {}
    if dynamic_batch:
        dynamic_axes = {"input": {0: "batch"}, "output": {0: "batch"}}

    torch.onnx.export(
        model,
        dummy,
        str(dest),
        input_names=["input"],
        output_names=["output"],
        dynamic_axes=dynamic_axes,
        opset_version=opset,
        do_constant_folding=True,
    )

    onnx_model = onnx.load(str(dest))
    onnx.checker.check_model(onnx_model)

    logger.info("ONNX classifier exported to %s", dest)
    return dest


def export_torchscript(
    model_path: Path,
    output_dir: Path,
    *,
    input_size: int = 224,
) -> Path:
    """Export classifier to TorchScript (traced) format.

    Returns the path to the exported ``.pt`` file.
    """
    device = torch.device("cpu")
    model, _ = _load_model(model_path, device)

    dummy = torch.randn(1, 3, input_size, input_size, device=device)
    traced = torch.jit.trace(model, dummy)

    output_dir.mkdir(parents=True, exist_ok=True)
    dest = output_dir / "model.torchscript"
    traced.save(str(dest))

    logger.info("TorchScript classifier exported to %s", dest)
    return dest


def write_metadata(
    output_dir: Path,
    *,
    model_path: Path,
    input_size: int,
    version: str,
    config: dict | None = None,
) -> Path:
    """Write a ``metadata.json`` alongside the exported model."""
    meta = {
        "model_type": "classifier",
        "architecture": config.get("model", {}).get("backbone", "efficientnet_b0")
        if config
        else "efficientnet_b0",
        "version": version,
        "input_size": input_size,
        "num_classes": NUM_CLASSES,
        "class_names": CLASS_NAMES,
        "source_checkpoint": str(model_path),
        "exported_at": datetime.now(timezone.utc).isoformat(),
    }

    dest = output_dir / "metadata.json"
    dest.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    logger.info("Metadata written to %s", dest)
    return dest


def export_all(
    model_path: Path,
    output_dir: Path,
    *,
    input_size: int = 224,
    version: str = "v1.0.0",
    opset: int = 17,
) -> dict[str, Path]:
    """Export classifier to all formats and write metadata."""
    output_dir.mkdir(parents=True, exist_ok=True)

    _, cfg = _load_model(model_path, torch.device("cpu"))

    onnx_path = export_onnx(model_path, output_dir, input_size=input_size, opset=opset)
    ts_path = export_torchscript(model_path, output_dir, input_size=input_size)
    meta_path = write_metadata(
        output_dir,
        model_path=model_path,
        input_size=input_size,
        version=version,
        config=cfg,
    )

    return {"onnx": onnx_path, "torchscript": ts_path, "metadata": meta_path}


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Export GreyEye classifier")
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--input-size", type=int, default=224)
    parser.add_argument("--version", type=str, default="v1.0.0")
    parser.add_argument("--opset", type=int, default=17)
    parser.add_argument(
        "--format",
        choices=["onnx", "torchscript", "all"],
        default="all",
    )
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    if args.format == "onnx":
        export_onnx(args.model, args.output_dir, input_size=args.input_size, opset=args.opset)
    elif args.format == "torchscript":
        export_torchscript(args.model, args.output_dir, input_size=args.input_size)
    else:
        export_all(
            args.model,
            args.output_dir,
            input_size=args.input_size,
            version=args.version,
            opset=args.opset,
        )


if __name__ == "__main__":
    main()
