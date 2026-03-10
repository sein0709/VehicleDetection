"""End-to-end latency profiling for the GreyEye inference pipeline.

Measures per-stage and total latency for detection + classification
using synthetic or real frames.  Verifies the NFR-2 target of
<= 1.5 s per frame.

Usage::

    python -m ml.evaluation.benchmark_latency \
        --detector-model runs/detector/base/weights/best.onnx \
        --classifier-model runs/classifier/base/best.onnx \
        --image-dir /data/greyeye/benchmark_frames \
        --output-dir runs/benchmark \
        --num-warmup 10 --num-iterations 100
"""

from __future__ import annotations

import argparse
import json
import logging
import time
from pathlib import Path

import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

LATENCY_TARGET_MS = 1500.0


def _load_onnx_session(model_path: Path):
    """Load an ONNX model with GPU acceleration if available."""
    import onnxruntime as ort

    providers = ["CUDAExecutionProvider", "CPUExecutionProvider"]
    available = ort.get_available_providers()
    providers = [p for p in providers if p in available]
    return ort.InferenceSession(str(model_path), providers=providers)


def _preprocess_detector(image: np.ndarray, input_size: int = 640) -> np.ndarray:
    """Resize and normalise for YOLO detector."""
    from PIL import Image as _Img

    img = _Img.fromarray(image).resize((input_size, input_size))
    arr = np.array(img, dtype=np.float32) / 255.0
    arr = arr.transpose(2, 0, 1)  # HWC → CHW
    return np.expand_dims(arr, axis=0)  # add batch dim


def _preprocess_classifier(crop: np.ndarray, input_size: int = 224) -> np.ndarray:
    """Resize and normalise a vehicle crop for the classifier."""
    from PIL import Image as _Img

    img = _Img.fromarray(crop).resize((input_size, input_size))
    arr = np.array(img, dtype=np.float32) / 255.0
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    arr = (arr - mean) / std
    arr = arr.transpose(2, 0, 1)
    return np.expand_dims(arr, axis=0)


def benchmark(
    detector_model: Path,
    classifier_model: Path,
    image_dir: Path | None = None,
    output_dir: Path | None = None,
    *,
    num_warmup: int = 10,
    num_iterations: int = 100,
    detector_input_size: int = 640,
    classifier_input_size: int = 224,
    num_crops_per_frame: int = 10,
) -> dict:
    """Run latency benchmark and return timing statistics.

    If *image_dir* is provided, real images are used; otherwise synthetic
    random frames are generated.
    """
    det_session = _load_onnx_session(detector_model)
    cls_session = _load_onnx_session(classifier_model)

    det_input_name = det_session.get_inputs()[0].name
    cls_input_name = cls_session.get_inputs()[0].name

    if image_dir and image_dir.exists():
        image_paths = sorted(image_dir.glob("*.jpg")) + sorted(image_dir.glob("*.png"))
    else:
        image_paths = []

    def _get_frame(idx: int) -> np.ndarray:
        if image_paths:
            img = Image.open(image_paths[idx % len(image_paths)]).convert("RGB")
            return np.array(img)
        return np.random.randint(0, 255, (1080, 1920, 3), dtype=np.uint8)

    def _get_crop() -> np.ndarray:
        return np.random.randint(0, 255, (224, 224, 3), dtype=np.uint8)

    logger.info("Warming up (%d iterations)…", num_warmup)
    for i in range(num_warmup):
        frame = _get_frame(i)
        det_input = _preprocess_detector(frame, detector_input_size)
        det_session.run(None, {det_input_name: det_input})
        cls_input = _preprocess_classifier(_get_crop(), classifier_input_size)
        cls_session.run(None, {cls_input_name: cls_input})

    det_times: list[float] = []
    cls_times: list[float] = []
    total_times: list[float] = []

    logger.info("Benchmarking (%d iterations, %d crops/frame)…", num_iterations, num_crops_per_frame)
    for i in range(num_iterations):
        frame = _get_frame(i)

        t_total_start = time.perf_counter()

        det_input = _preprocess_detector(frame, detector_input_size)
        t_det_start = time.perf_counter()
        det_session.run(None, {det_input_name: det_input})
        t_det_end = time.perf_counter()
        det_times.append((t_det_end - t_det_start) * 1000)

        crops = [_get_crop() for _ in range(num_crops_per_frame)]
        cls_batch = np.concatenate(
            [_preprocess_classifier(c, classifier_input_size) for c in crops], axis=0
        )
        t_cls_start = time.perf_counter()
        cls_session.run(None, {cls_input_name: cls_batch})
        t_cls_end = time.perf_counter()
        cls_times.append((t_cls_end - t_cls_start) * 1000)

        t_total_end = time.perf_counter()
        total_times.append((t_total_end - t_total_start) * 1000)

    def _stats(times: list[float]) -> dict:
        arr = np.array(times)
        return {
            "mean_ms": round(float(np.mean(arr)), 2),
            "median_ms": round(float(np.median(arr)), 2),
            "p95_ms": round(float(np.percentile(arr, 95)), 2),
            "p99_ms": round(float(np.percentile(arr, 99)), 2),
            "min_ms": round(float(np.min(arr)), 2),
            "max_ms": round(float(np.max(arr)), 2),
            "std_ms": round(float(np.std(arr)), 2),
        }

    results = {
        "detector": _stats(det_times),
        "classifier": _stats(cls_times),
        "total": _stats(total_times),
        "config": {
            "num_warmup": num_warmup,
            "num_iterations": num_iterations,
            "detector_input_size": detector_input_size,
            "classifier_input_size": classifier_input_size,
            "num_crops_per_frame": num_crops_per_frame,
        },
    }

    total_p95 = results["total"]["p95_ms"]
    results["meets_nfr2"] = total_p95 <= LATENCY_TARGET_MS

    logger.info("--- Latency Benchmark Results ---")
    logger.info("Detector:   mean=%.1fms  p95=%.1fms", results["detector"]["mean_ms"], results["detector"]["p95_ms"])
    logger.info("Classifier: mean=%.1fms  p95=%.1fms", results["classifier"]["mean_ms"], results["classifier"]["p95_ms"])
    logger.info("Total:      mean=%.1fms  p95=%.1fms", results["total"]["mean_ms"], results["total"]["p95_ms"])
    logger.info("NFR-2 (<=%.0fms p95): %s", LATENCY_TARGET_MS, "PASS" if results["meets_nfr2"] else "FAIL")

    if output_dir:
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / "latency_benchmark.json").write_text(
            json.dumps(results, indent=2), encoding="utf-8"
        )

    return results


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Benchmark GreyEye inference latency")
    parser.add_argument("--detector-model", type=Path, required=True)
    parser.add_argument("--classifier-model", type=Path, required=True)
    parser.add_argument("--image-dir", type=Path, default=None)
    parser.add_argument("--output-dir", type=Path, default=None)
    parser.add_argument("--num-warmup", type=int, default=10)
    parser.add_argument("--num-iterations", type=int, default=100)
    parser.add_argument("--num-crops", type=int, default=10)
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    benchmark(
        args.detector_model,
        args.classifier_model,
        args.image_dir,
        args.output_dir,
        num_warmup=args.num_warmup,
        num_iterations=args.num_iterations,
        num_crops_per_frame=args.num_crops,
    )


if __name__ == "__main__":
    main()
