"""Export the GreyEye YOLO detector to ONNX, TorchScript, and TFLite formats.

Uses the Ultralytics export API which handles graph optimization,
dynamic axes, and opset version selection.

Usage::

    python -m ml.export.export_detector \
        --model runs/detector/base/weights/best.pt \
        --output-dir models/detector/v1.0.0 \
        --input-size 640

    # TFLite only (for on-device inference)
    python -m ml.export.export_detector \
        --model runs/detector/base/weights/best.pt \
        --output-dir models/detector/v1.0.0 \
        --format tflite
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


def export_tflite(
    model_path: Path,
    output_dir: Path,
    *,
    input_size: int = 640,
    half: bool = False,
    int8: bool = False,
) -> Path:
    """Export YOLO detector to TFLite format for on-device inference.

    Ultralytics handles the PyTorch -> TF SavedModel -> TFLite conversion
    internally, including NMS baking when supported.

    Returns the path to the exported ``.tflite`` file.
    """
    model = YOLO(str(model_path))
    export_path = model.export(
        format="tflite",
        imgsz=input_size,
        half=half,
        int8=int8,
    )

    export_path = Path(export_path)
    output_dir.mkdir(parents=True, exist_ok=True)
    dest = output_dir / "model.tflite"
    shutil.copy2(export_path, dest)
    logger.info("TFLite model exported to %s (%.1f MB)", dest, dest.stat().st_size / 1e6)
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
    formats = []
    if (output_dir / "model.onnx").exists():
        formats.append("onnx")
    if (output_dir / "model.torchscript").exists():
        formats.append("torchscript")
    if (output_dir / "model.tflite").exists():
        formats.append("tflite")

    meta = {
        "model_type": "detector",
        "architecture": "yolo",
        "version": version,
        "input_size": input_size,
        "num_classes": 1,
        "class_names": ["vehicle"],
        "exported_formats": formats,
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
    tflite_path = export_tflite(model_path, output_dir, input_size=input_size)
    meta_path = write_metadata(
        output_dir, model_path=model_path, input_size=input_size, version=version
    )

    return {
        "onnx": onnx_path,
        "torchscript": ts_path,
        "tflite": tflite_path,
        "metadata": meta_path,
    }


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Export GreyEye detector")
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--input-size", type=int, default=640)
    parser.add_argument("--version", type=str, default="v1.0.0")
    parser.add_argument("--opset", type=int, default=17)
    parser.add_argument(
        "--format",
        choices=["onnx", "torchscript", "tflite", "all"],
        default="all",
    )
    parser.add_argument("--half", action="store_true", help="FP16 quantization (TFLite)")
    parser.add_argument("--int8", action="store_true", help="INT8 quantization (TFLite)")
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    if args.format == "onnx":
        export_onnx(args.model, args.output_dir, input_size=args.input_size, opset=args.opset)
    elif args.format == "torchscript":
        export_torchscript(args.model, args.output_dir, input_size=args.input_size)
    elif args.format == "tflite":
        export_tflite(
            args.model,
            args.output_dir,
            input_size=args.input_size,
            half=args.half,
            int8=args.int8,
        )
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
