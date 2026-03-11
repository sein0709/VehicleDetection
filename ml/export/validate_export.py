"""Validate exported models by checking numerical equivalence with PyTorch.

Compares ONNX Runtime inference output against the original PyTorch model
to ensure the export did not introduce numerical divergence beyond an
acceptable tolerance.

Usage::

    python -m ml.export.validate_export \
        --pytorch-model runs/classifier/base/best.pt \
        --onnx-model models/classifier/v1.0.0/model.onnx \
        --model-type classifier \
        --input-size 224 \
        --num-samples 50
"""

from __future__ import annotations

import argparse
import logging
from pathlib import Path

import numpy as np
import onnxruntime as ort
import timm
import torch
import torch.nn as nn

from ml.shared_contracts.enums import VehicleClass12

logger = logging.getLogger(__name__)

NUM_CLASSES = 12

ATOL = 1e-4
RTOL = 1e-3


def _load_classifier(model_path: Path, device: torch.device) -> nn.Module:
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


def _load_detector(model_path: Path):
    from ultralytics import YOLO
    return YOLO(str(model_path))


def validate_classifier(
    pytorch_model_path: Path,
    onnx_model_path: Path,
    *,
    input_size: int = 224,
    num_samples: int = 50,
    batch_size: int = 1,
) -> dict:
    """Compare PyTorch vs ONNX classifier outputs.

    Returns
    -------
    dict
        Includes ``max_abs_diff``, ``mean_abs_diff``, ``all_close``,
        ``class_agreement_rate``.
    """
    device = torch.device("cpu")
    pt_model = _load_classifier(pytorch_model_path, device)

    session = ort.InferenceSession(
        str(onnx_model_path), providers=["CPUExecutionProvider"]
    )
    input_name = session.get_inputs()[0].name

    max_diffs: list[float] = []
    mean_diffs: list[float] = []
    class_agreements = 0

    for _ in range(num_samples):
        dummy = torch.randn(batch_size, 3, input_size, input_size)

        with torch.no_grad():
            pt_out = pt_model(dummy).numpy()

        ort_out = session.run(None, {input_name: dummy.numpy()})[0]

        abs_diff = np.abs(pt_out - ort_out)
        max_diffs.append(float(np.max(abs_diff)))
        mean_diffs.append(float(np.mean(abs_diff)))

        if np.argmax(pt_out, axis=1).tolist() == np.argmax(ort_out, axis=1).tolist():
            class_agreements += 1

    results = {
        "max_abs_diff": round(max(max_diffs), 8),
        "mean_abs_diff": round(float(np.mean(mean_diffs)), 8),
        "all_close": all(d < ATOL for d in max_diffs),
        "class_agreement_rate": round(class_agreements / num_samples, 4),
        "num_samples": num_samples,
        "atol": ATOL,
        "rtol": RTOL,
    }

    if results["all_close"]:
        logger.info(
            "PASS — max_abs_diff=%.2e  class_agreement=%.1f%%",
            results["max_abs_diff"],
            results["class_agreement_rate"] * 100,
        )
    else:
        logger.warning(
            "FAIL — max_abs_diff=%.2e exceeds atol=%.2e",
            results["max_abs_diff"],
            ATOL,
        )

    return results


def validate_detector(
    pytorch_model_path: Path,
    onnx_model_path: Path,
    *,
    input_size: int = 640,
    num_samples: int = 10,
) -> dict:
    """Compare PyTorch vs ONNX detector outputs.

    Uses the Ultralytics API for both PyTorch and ONNX inference, then
    compares bounding box outputs.
    """
    from ultralytics import YOLO

    pt_model = YOLO(str(pytorch_model_path))
    onnx_model = YOLO(str(onnx_model_path))

    box_diffs: list[float] = []
    detection_count_matches = 0

    for _ in range(num_samples):
        dummy = np.random.randint(0, 255, (input_size, input_size, 3), dtype=np.uint8)

        pt_results = pt_model.predict(dummy, imgsz=input_size, verbose=False)
        onnx_results = onnx_model.predict(dummy, imgsz=input_size, verbose=False)

        pt_boxes = pt_results[0].boxes.xyxy.cpu().numpy() if len(pt_results[0].boxes) > 0 else np.array([])
        onnx_boxes = onnx_results[0].boxes.xyxy.cpu().numpy() if len(onnx_results[0].boxes) > 0 else np.array([])

        if pt_boxes.shape == onnx_boxes.shape and pt_boxes.size > 0:
            box_diffs.append(float(np.max(np.abs(pt_boxes - onnx_boxes))))

        if len(pt_boxes) == len(onnx_boxes):
            detection_count_matches += 1

    results = {
        "detection_count_agreement": round(detection_count_matches / max(num_samples, 1), 4),
        "max_box_diff": round(max(box_diffs), 4) if box_diffs else 0.0,
        "mean_box_diff": round(float(np.mean(box_diffs)), 4) if box_diffs else 0.0,
        "num_samples": num_samples,
    }

    logger.info(
        "Detector validation — count_agreement=%.1f%%  max_box_diff=%.4f",
        results["detection_count_agreement"] * 100,
        results["max_box_diff"],
    )

    return results


def validate(
    pytorch_model_path: Path,
    onnx_model_path: Path,
    model_type: str = "classifier",
    **kwargs,
) -> dict:
    """Dispatch to the appropriate validation function."""
    if model_type == "classifier":
        return validate_classifier(pytorch_model_path, onnx_model_path, **kwargs)
    elif model_type == "detector":
        return validate_detector(pytorch_model_path, onnx_model_path, **kwargs)
    else:
        raise ValueError(f"Unknown model_type: {model_type}")


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Validate ONNX export against PyTorch model"
    )
    parser.add_argument("--pytorch-model", type=Path, required=True)
    parser.add_argument("--onnx-model", type=Path, required=True)
    parser.add_argument(
        "--model-type", choices=["classifier", "detector"], default="classifier"
    )
    parser.add_argument("--input-size", type=int, default=224)
    parser.add_argument("--num-samples", type=int, default=50)
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    validate(
        args.pytorch_model,
        args.onnx_model,
        model_type=args.model_type,
        input_size=args.input_size,
        num_samples=args.num_samples,
    )


if __name__ == "__main__":
    main()
