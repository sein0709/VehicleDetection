"""Convert CoreML (.mlpackage) YOLO models to TFLite for on-device inference.

Both models were exported from Ultralytics YOLO via coremltools. This script
converts them through the CoreML -> ONNX -> TF SavedModel -> TFLite pipeline.

Usage::

    # Convert Stage 1 (car/bus/truck) detector
    python -m ml.export.convert_coreml_to_tflite \
        --input "ml/best 2.mlpackage" \
        --output apps/mobile_flutter/assets/models/stage1_detector.tflite \
        --input-size 640

    # Convert Stage 2 (wheel/joint) detector
    python -m ml.export.convert_coreml_to_tflite \
        --input ml/best.mlpackage \
        --output apps/mobile_flutter/assets/models/stage2_detector.tflite \
        --input-size 640

Requirements::

    pip install coremltools onnx onnxruntime tf2onnx tensorflow
"""

from __future__ import annotations

import argparse
import logging
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

logger = logging.getLogger(__name__)


def convert_coreml_to_onnx(mlpackage_path: Path, onnx_path: Path, input_size: int) -> Path:
    """Convert a CoreML .mlpackage to ONNX via coremltools."""
    import coremltools as ct

    logger.info("Loading CoreML model from %s", mlpackage_path)
    model = ct.models.MLModel(str(mlpackage_path))

    spec = model.get_spec()
    logger.info(
        "Model type: %s, inputs: %s, outputs: %s",
        spec.WhichOneof("Type"),
        [inp.name for inp in spec.description.input],
        [out.name for out in spec.description.output],
    )

    import coremltools.converters as cvt  # noqa: F811

    try:
        from coremltools.converters import _onnx as coreml_onnx
        coreml_onnx.convert(model, str(onnx_path))
    except (ImportError, AttributeError):
        logger.info("Direct coremltools->ONNX not available, using onnxmltools")
        try:
            from onnxmltools import convert_coreml
            onnx_model = convert_coreml(model)
            import onnx
            onnx.save(onnx_model, str(onnx_path))
        except ImportError:
            logger.info("onnxmltools not available, falling back to manual export")
            _convert_via_traced_export(mlpackage_path, onnx_path, input_size)

    logger.info("ONNX model saved to %s", onnx_path)
    return onnx_path


def _convert_via_traced_export(mlpackage_path: Path, onnx_path: Path, input_size: int) -> None:
    """Fallback: use coremltools to get weights and re-export via torch tracing."""
    raise RuntimeError(
        "Could not convert CoreML to ONNX. Install onnxmltools: "
        "pip install onnxmltools"
    )


def convert_onnx_to_tflite(onnx_path: Path, tflite_path: Path, input_size: int) -> Path:
    """Convert ONNX model to TFLite via tf2onnx and TensorFlow."""
    import onnx
    import tensorflow as tf

    tmpdir = Path(tempfile.mkdtemp())
    saved_model_dir = tmpdir / "saved_model"

    logger.info("Converting ONNX -> TF SavedModel")
    subprocess.check_call([
        sys.executable, "-m", "tf2onnx.convert",
        "--onnx", str(onnx_path),
        "--output", str(tmpdir / "model_tf.onnx"),
        "--opset", "13",
    ])

    try:
        import onnx_tf.backend as backend
        onnx_model = onnx.load(str(onnx_path))
        tf_rep = backend.prepare(onnx_model)
        tf_rep.export_graph(str(saved_model_dir))
    except ImportError:
        logger.info("onnx-tf not available, using tf2onnx saved_model conversion")
        subprocess.check_call([
            sys.executable, "-m", "tf2onnx.convert",
            "--onnx", str(onnx_path),
            "--saved-model", str(saved_model_dir),
        ])

    logger.info("Converting TF SavedModel -> TFLite")
    converter = tf.lite.TFLiteConverter.from_saved_model(str(saved_model_dir))
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    tflite_model = converter.convert()

    tflite_path.parent.mkdir(parents=True, exist_ok=True)
    tflite_path.write_bytes(tflite_model)

    shutil.rmtree(tmpdir, ignore_errors=True)
    logger.info(
        "TFLite model saved to %s (%.1f MB)",
        tflite_path,
        tflite_path.stat().st_size / 1e6,
    )
    return tflite_path


def convert_ultralytics_direct(mlpackage_path: Path, tflite_path: Path, input_size: int) -> Path:
    """Preferred path: if the .mlpackage came from Ultralytics, reload and
    re-export directly to TFLite using the Ultralytics API."""
    from ultralytics import YOLO

    logger.info("Attempting Ultralytics direct export from %s", mlpackage_path)
    model = YOLO(str(mlpackage_path))
    export_path = model.export(format="tflite", imgsz=input_size)

    tflite_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(export_path, tflite_path)
    logger.info(
        "TFLite model saved to %s (%.1f MB)",
        tflite_path,
        tflite_path.stat().st_size / 1e6,
    )
    return tflite_path


def convert(
    mlpackage_path: Path,
    tflite_path: Path,
    *,
    input_size: int = 640,
) -> Path:
    """Convert a CoreML .mlpackage to TFLite.

    Tries the Ultralytics direct path first, then falls back to the
    CoreML -> ONNX -> TF -> TFLite pipeline.
    """
    try:
        return convert_ultralytics_direct(mlpackage_path, tflite_path, input_size)
    except Exception as e:
        logger.warning("Ultralytics direct export failed (%s), trying ONNX pipeline", e)

    tmpdir = Path(tempfile.mkdtemp())
    onnx_path = tmpdir / "model.onnx"

    try:
        convert_coreml_to_onnx(mlpackage_path, onnx_path, input_size)
        return convert_onnx_to_tflite(onnx_path, tflite_path, input_size)
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Convert CoreML .mlpackage to TFLite",
    )
    parser.add_argument("--input", type=Path, required=True, help="Path to .mlpackage")
    parser.add_argument("--output", type=Path, required=True, help="Output .tflite path")
    parser.add_argument("--input-size", type=int, default=640)
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    if not args.input.exists():
        parser.error(f"Input path does not exist: {args.input}")

    convert(args.input, args.output, input_size=args.input_size)
    logger.info("Done.")


if __name__ == "__main__":
    main()
