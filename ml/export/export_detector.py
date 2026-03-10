"""Export the GreyEye YOLO detector to ONNX and TorchScript formats.

Uses the Ultralytics export API which handles graph optimization,
dynamic axes, and opset version selection.

Usage::

    python -m ml.export.export_detector \
        --model runs/detector/base/weights/best.pt \
        --output-dir models/detector/v1.0.0 \
        --input-size 640
"""

from __future__ import annotations

import argparse
import json
import logging
import shutil
from datetime import datetime, timezone
from pathlib import Path

from ultralytics import YOLO

logger = logging.getLogger(__name__)


def export_onnx(
    model_path: Path,
    output_dir: Path,
    *,
    input_size: int = 640,
    opset: int = 17,
    simplify: bool = True,
    dynamic: bool = False,
    half: bool = False,
) -> Path:
    """Export YOLO detector to ONNX format.

    Returns the path to the exported ``.onnx`` file.
    """
    model = YOLO(str(model_path))
    export_path = model.export(
        format="onnx",
        imgsz=input_size,
        opset=opset,
        simplify=simplify,
        dynamic=dynamic,
        half=half,
    )

    output_dir.mkdir(parents=True, exist_ok=True)
    dest = output_dir / "model.onnx"
    shutil.copy2(export_path, dest)
    logger.info("ONNX model exported to %s", dest)
    return dest


def export_torchscript(
    model_path: Path,
    output_dir: Path,
    *,
    input_size: int = 640,
) -> Path:
    """Export YOLO detector to TorchScript format.

    Returns the path to the exported ``.torchscript`` file.
    """
    model = YOLO(str(model_path))
    export_path = model.export(
        format="torchscript",
        imgsz=input_size,
    )

    output_dir.mkdir(parents=True, exist_ok=True)
    dest = output_dir / "model.torchscript"
    shutil.copy2(export_path, dest)
    logger.info("TorchScript model exported to %s", dest)
    return dest


def write_metadata(
    output_dir: Path,
    *,
    model_path: Path,
    input_size: int,
    version: str,
    extra: dict | None = None,
) -> Path:
    """Write a ``metadata.json`` alongside the exported model."""
    meta = {
        "model_type": "detector",
        "architecture": "yolo",
        "version": version,
        "input_size": input_size,
        "num_classes": 1,
        "class_names": ["vehicle"],
        "source_checkpoint": str(model_path),
        "exported_at": datetime.now(timezone.utc).isoformat(),
    }
    if extra:
        meta.update(extra)

    dest = output_dir / "metadata.json"
    dest.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    logger.info("Metadata written to %s", dest)
    return dest


def export_all(
    model_path: Path,
    output_dir: Path,
    *,
    input_size: int = 640,
    version: str = "v1.0.0",
    opset: int = 17,
) -> dict[str, Path]:
    """Export detector to all formats and write metadata.

    Returns a dict mapping format names to output paths.
    """
    output_dir.mkdir(parents=True, exist_ok=True)

    onnx_path = export_onnx(model_path, output_dir, input_size=input_size, opset=opset)
    ts_path = export_torchscript(model_path, output_dir, input_size=input_size)
    meta_path = write_metadata(
        output_dir, model_path=model_path, input_size=input_size, version=version
    )

    return {"onnx": onnx_path, "torchscript": ts_path, "metadata": meta_path}


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Export GreyEye detector")
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--input-size", type=int, default=640)
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
