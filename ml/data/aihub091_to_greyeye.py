"""Convert AI Hub 091 (차량 외관 영상 데이터) annotations to GreyEye format.

AI Hub 091 annotates vehicle *parts* (bumper, headlight, wheel, …), not whole
vehicles.  This converter computes the union bounding box of all parts per
image to produce a single whole-vehicle detection annotation.

The 12-class label is set to ``None`` because AI Hub 091 does not carry
KICT/MOLIT class information — it is used only for detector pre-training and
backbone feature learning.

Usage::

    python -m ml.data.aihub091_to_greyeye \
        --input-dir /data/091.차량_외관_영상_데이터/01.데이터/1.Training \
        --output-dir /data/greyeye/aihub091/train \
        --split train
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
from pathlib import Path

from pydantic import BaseModel

from ml.data.dataset import DetectionAnnotation, GreyEyeAnnotation
from ml.shared_contracts.geometry import BoundingBox

logger = logging.getLogger(__name__)

SOURCE_TAG = "aihub091"

IMAGE_SUBDIR = "원천데이터"
LABEL_SUBDIR = "라벨링데이터"


class _RawPartBbox(BaseModel):
    x: int
    y: int
    w: int
    h: int


def _union_bbox(parts: list[_RawPartBbox]) -> tuple[int, int, int, int]:
    """Return (x, y, w, h) of the axis-aligned union of all part bboxes."""
    x_min = min(p.x for p in parts)
    y_min = min(p.y for p in parts)
    x_max = max(p.x + p.w for p in parts)
    y_max = max(p.y + p.h for p in parts)
    return x_min, y_min, x_max - x_min, y_max - y_min


def _parse_resolution(resolution_str: str) -> tuple[int, int]:
    """Parse '1920x1080' → (1920, 1080)."""
    parts = resolution_str.lower().split("x")
    return int(parts[0]), int(parts[1])


def convert_annotation(label_path: Path, image_dir: Path) -> GreyEyeAnnotation | None:
    """Convert a single AI Hub 091 JSON annotation to GreyEye format.

    Returns ``None`` if the annotation has no usable part bboxes.
    """
    with open(label_path, encoding="utf-8") as f:
        data = json.load(f)

    raw_info = data.get("rawDataInfo", {})
    filename = raw_info.get("filename", "")
    resolution = raw_info.get("resolution", "1920x1080")
    img_w, img_h = _parse_resolution(resolution)

    learning = data.get("learningDataInfo", {})
    objects = learning.get("objects", [])
    if not objects:
        logger.debug("No objects in %s — skipping", label_path.name)
        return None

    parts = [_RawPartBbox(**obj["bbox"]) for obj in objects if "bbox" in obj]
    if not parts:
        return None

    ux, uy, uw, uh = _union_bbox(parts)

    norm_bbox = BoundingBox(
        x=max(ux / img_w, 0.0),
        y=max(uy / img_h, 0.0),
        w=min(uw / img_w, 1.0),
        h=min(uh / img_h, 1.0),
    )

    image_path = image_dir / filename
    if not image_path.exists():
        stem = label_path.stem
        for ext in (".jpg", ".jpeg", ".png"):
            candidate = image_dir / f"{stem}{ext}"
            if candidate.exists():
                image_path = candidate
                break

    detection = DetectionAnnotation(
        bbox=norm_bbox,
        class12=None,
        coarse_class="vehicle",
        source=SOURCE_TAG,
    )

    return GreyEyeAnnotation(
        image_path=str(image_path),
        image_width=img_w,
        image_height=img_h,
        detections=[detection],
    )


def convert_directory(
    input_dir: Path,
    output_dir: Path,
    *,
    split: str = "train",
) -> list[Path]:
    """Convert all AI Hub 091 annotations in *input_dir* to GreyEye JSON.

    Parameters
    ----------
    input_dir:
        Root of a split, e.g. ``…/1.Training``.  Expected children:
        ``원천데이터/`` (images) and ``라벨링데이터/`` (JSON labels).
    output_dir:
        Where to write the converted ``.json`` files.
    split:
        ``"train"`` or ``"val"`` — embedded in the output metadata.

    Returns
    -------
    list[Path]
        Paths to the written annotation files.
    """
    image_dir = input_dir / IMAGE_SUBDIR
    label_dir = input_dir / LABEL_SUBDIR

    if not label_dir.exists():
        logger.error("Label directory not found: %s", label_dir)
        return []

    output_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []

    label_files = sorted(label_dir.rglob("*.json"))
    logger.info(
        "Converting %d AI Hub 091 annotations (split=%s)", len(label_files), split
    )

    skipped = 0
    for label_path in label_files:
        annotation = convert_annotation(label_path, image_dir)
        if annotation is None:
            skipped += 1
            continue

        out_path = output_dir / f"{label_path.stem}.json"
        out_path.write_text(annotation.model_dump_json(indent=2), encoding="utf-8")
        written.append(out_path)

    logger.info(
        "Wrote %d annotations, skipped %d (split=%s)",
        len(written),
        skipped,
        split,
    )
    return written


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Convert AI Hub 091 annotations to GreyEye format",
    )
    parser.add_argument(
        "--input-dir",
        type=Path,
        required=True,
        help="Root of a split (e.g. …/1.Training)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        required=True,
        help="Output directory for converted JSON",
    )
    parser.add_argument(
        "--split",
        choices=["train", "val"],
        default="train",
    )
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    convert_directory(args.input_dir, args.output_dir, split=args.split)


if __name__ == "__main__":
    main()
