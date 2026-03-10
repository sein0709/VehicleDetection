"""Convert COCO-format annotations (vehicle subset) to GreyEye format.

Extracts annotations for COCO categories that correspond to vehicles
(car, bus, truck, motorcycle) and converts them to GreyEye's internal
``DetectionAnnotation`` format with normalised bounding boxes.

Usage::

    python -m ml.data.coco_to_greyeye \
        --coco-json /data/coco/annotations/instances_train2017.json \
        --image-dir /data/coco/train2017 \
        --output-dir /data/greyeye/coco/train
"""

from __future__ import annotations

import argparse
import json
import logging
from collections import defaultdict
from pathlib import Path

from ml.data.dataset import DetectionAnnotation, GreyEyeAnnotation
from shared_contracts.geometry import BoundingBox

logger = logging.getLogger(__name__)

SOURCE_TAG = "coco"

COCO_VEHICLE_CATEGORIES: dict[str, str] = {
    "car": "vehicle",
    "bus": "vehicle",
    "truck": "vehicle",
    "motorcycle": "vehicle",
}


def convert_coco(
    coco_json: Path,
    image_dir: Path,
    output_dir: Path,
) -> list[Path]:
    """Convert COCO annotations to GreyEye format, keeping only vehicles.

    Parameters
    ----------
    coco_json:
        Path to a COCO ``instances_*.json`` file.
    image_dir:
        Directory containing the COCO images.
    output_dir:
        Where to write the converted ``.json`` files.

    Returns
    -------
    list[Path]
        Paths to the written annotation files.
    """
    with open(coco_json, encoding="utf-8") as f:
        coco = json.load(f)

    cat_id_to_name: dict[int, str] = {}
    for cat in coco.get("categories", []):
        name = cat["name"].lower()
        if name in COCO_VEHICLE_CATEGORIES:
            cat_id_to_name[cat["id"]] = name

    if not cat_id_to_name:
        logger.warning("No vehicle categories found in %s", coco_json)
        return []

    img_id_to_info: dict[int, dict] = {
        img["id"]: img for img in coco.get("images", [])
    }

    anns_by_image: dict[int, list[dict]] = defaultdict(list)
    for ann in coco.get("annotations", []):
        if ann["category_id"] in cat_id_to_name and not ann.get("iscrowd", False):
            anns_by_image[ann["image_id"]].append(ann)

    output_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []

    logger.info(
        "Converting %d COCO images with vehicle annotations", len(anns_by_image)
    )

    for image_id, annotations in sorted(anns_by_image.items()):
        img_info = img_id_to_info.get(image_id)
        if img_info is None:
            continue

        img_w = img_info["width"]
        img_h = img_info["height"]
        filename = img_info["file_name"]

        detections: list[DetectionAnnotation] = []
        for ann in annotations:
            x, y, w, h = ann["bbox"]  # COCO format: absolute (x, y, w, h)
            norm_bbox = BoundingBox(
                x=max(x / img_w, 0.0),
                y=max(y / img_h, 0.0),
                w=min(w / img_w, 1.0),
                h=min(h / img_h, 1.0),
            )
            detections.append(
                DetectionAnnotation(
                    bbox=norm_bbox,
                    class12=None,
                    coarse_class="vehicle",
                    source=SOURCE_TAG,
                )
            )

        ge_ann = GreyEyeAnnotation(
            image_path=str(image_dir / filename),
            image_width=img_w,
            image_height=img_h,
            detections=detections,
        )

        stem = Path(filename).stem
        out_path = output_dir / f"{stem}.json"
        out_path.write_text(ge_ann.model_dump_json(indent=2), encoding="utf-8")
        written.append(out_path)

    logger.info("Wrote %d GreyEye annotations from COCO", len(written))
    return written


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Convert COCO vehicle annotations to GreyEye format",
    )
    parser.add_argument(
        "--coco-json",
        type=Path,
        required=True,
        help="Path to COCO instances JSON",
    )
    parser.add_argument(
        "--image-dir",
        type=Path,
        required=True,
        help="Directory containing COCO images",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        required=True,
        help="Output directory for converted JSON",
    )
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    convert_coco(args.coco_json, args.image_dir, args.output_dir)


if __name__ == "__main__":
    main()
