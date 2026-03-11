#!/usr/bin/env python3
"""Scan for local model artifacts and wire ONNX files into the repo layout.

Examples:
    uv run python infra/scripts/prepare_local_models.py --scan-root /Users/sein/Desktop
    uv run python infra/scripts/prepare_local_models.py \
        --detector /abs/path/detector/model.onnx \
        --classifier /abs/path/classifier/model.onnx
"""

from __future__ import annotations

import argparse
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path

import onnxruntime as ort


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SCAN_ROOTS = (
    REPO_ROOT,
    Path.home() / "Desktop",
    Path.home() / "Documents",
    Path.home() / "Downloads",
)
MODEL_FILENAMES = {"model.onnx", "best.onnx", "best.pt", "last.pt"}
IGNORE_PARTS = {".venv", ".git", "node_modules", "__pycache__", ".mypy_cache", ".pytest_cache"}


@dataclass
class Candidates:
    detector: list[Path]
    classifier: list[Path]


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Find local model artifacts and wire real ONNX files into the repo.",
    )
    parser.add_argument("--scan-root", action="append", type=Path, dest="scan_roots")
    parser.add_argument("--detector", type=Path)
    parser.add_argument("--classifier", type=Path)
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument("--mode", choices=("symlink", "copy"), default="symlink")
    parser.add_argument("--skip-validation", action="store_true")
    return parser.parse_args(argv)


def scan_candidates(roots: list[Path]) -> Candidates:
    detector: list[Path] = []
    classifier: list[Path] = []
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            if any(part in IGNORE_PARTS for part in path.parts):
                continue
            if path.name not in MODEL_FILENAMES:
                continue
            lowered = str(path).lower()
            if "detector" in lowered or "yolo" in lowered:
                detector.append(path)
            if "classifier" in lowered or "efficientnet" in lowered:
                classifier.append(path)
    return Candidates(
        detector=sorted(set(detector)),
        classifier=sorted(set(classifier)),
    )


def validate_onnx(path: Path, label: str) -> None:
    if path.suffix.lower() != ".onnx":
        raise RuntimeError(f"{label} file must be ONNX, got: {path}")
    ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])


def wire_model(source: Path, dest: Path, mode: str) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() or dest.is_symlink():
        dest.unlink()
    if mode == "symlink":
        dest.symlink_to(source)
    else:
        shutil.copy2(source, dest)


def print_candidates(name: str, paths: list[Path]) -> None:
    print(f"{name} candidates:")
    if not paths:
        print("  <none found>")
        return
    for path in paths[:20]:
        print(f"  {path}")


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    scan_roots = args.scan_roots or list(DEFAULT_SCAN_ROOTS)

    candidates = scan_candidates(scan_roots)
    print_candidates("detector", candidates.detector)
    print_candidates("classifier", candidates.classifier)

    if args.detector is None or args.classifier is None:
        print("\nNo wiring applied. Supply both --detector and --classifier to wire local models.")
        return 0

    detector = args.detector.expanduser().resolve()
    classifier = args.classifier.expanduser().resolve()

    if not detector.exists():
        raise FileNotFoundError(f"Detector artifact not found: {detector}")
    if not classifier.exists():
        raise FileNotFoundError(f"Classifier artifact not found: {classifier}")

    if not args.skip_validation:
        validate_onnx(detector, "Detector")
        validate_onnx(classifier, "Classifier")

    repo_root = args.repo_root.resolve()
    detector_dest = repo_root / "models" / "detector" / "model.onnx"
    classifier_dest = repo_root / "models" / "classifier" / "model.onnx"

    wire_model(detector, detector_dest, args.mode)
    wire_model(classifier, classifier_dest, args.mode)

    print("\nWired local models:")
    print(f"  detector -> {detector_dest}")
    print(f"  classifier -> {classifier_dest}")
    print("\nWorker can now use the repo-default model paths.")
    print("Restart the inference worker to load the new artifacts:")
    print("  cd services/inference_worker && uv run python -m inference_worker.worker")
    print("\nAlternative env-var override:")
    print(f"  export GREYEYE_DETECTOR_MODEL_PATH={detector}")
    print(f"  export GREYEYE_CLASSIFIER_MODEL_PATH={classifier}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
