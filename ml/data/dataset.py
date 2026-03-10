"""PyTorch datasets for GreyEye detector and classifier training.

``GreyEyeDetectionDataset`` loads annotation JSONs for object detection
(YOLO-style).  ``GreyEyeClassifierDataset`` loads cropped vehicle images
for 12-class classification.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import numpy as np
import torch
from PIL import Image
from pydantic import BaseModel
from torch.utils.data import Dataset

from shared_contracts.enums import VehicleClass12
from shared_contracts.geometry import BoundingBox


# ---------------------------------------------------------------------------
# Annotation schemas (shared with converters)
# ---------------------------------------------------------------------------

class DetectionAnnotation(BaseModel):
    """A single object annotation within an image."""

    bbox: BoundingBox
    class12: VehicleClass12 | None = None
    coarse_class: str = "vehicle"
    source: str = "field"


class GreyEyeAnnotation(BaseModel):
    """Full annotation for one image, produced by converters or manual labeling."""

    image_path: str
    image_width: int
    image_height: int
    detections: list[DetectionAnnotation]


# ---------------------------------------------------------------------------
# Detection dataset
# ---------------------------------------------------------------------------

class GreyEyeDetectionDataset(Dataset):
    """Dataset for vehicle detection training.

    Each sample returns ``(image_tensor, targets)`` where *targets* is a dict
    with ``boxes`` (N×4, normalised xywh) and ``labels`` (N, all zeros for
    single-class detection).

    Parameters
    ----------
    annotation_dir:
        Directory containing GreyEye annotation ``.json`` files.
    transform:
        An Albumentations ``Compose`` pipeline (must accept ``image`` and
        ``bboxes`` keyword arguments).
    """

    def __init__(
        self,
        annotation_dir: str | Path,
        transform: Any | None = None,
    ) -> None:
        self.annotation_dir = Path(annotation_dir)
        self.transform = transform
        self.annotations = self._load_annotations()

    def _load_annotations(self) -> list[GreyEyeAnnotation]:
        ann_files = sorted(self.annotation_dir.glob("*.json"))
        annotations: list[GreyEyeAnnotation] = []
        for p in ann_files:
            with open(p, encoding="utf-8") as f:
                annotations.append(GreyEyeAnnotation.model_validate(json.load(f)))
        return annotations

    def __len__(self) -> int:
        return len(self.annotations)

    def __getitem__(self, idx: int) -> tuple[torch.Tensor, dict[str, torch.Tensor]]:
        ann = self.annotations[idx]
        image = Image.open(ann.image_path).convert("RGB")
        img_np = np.array(image)

        bboxes_norm = [
            [d.bbox.x, d.bbox.y, d.bbox.w, d.bbox.h] for d in ann.detections
        ]
        labels = [0] * len(ann.detections)  # single-class

        if self.transform is not None:
            transformed = self.transform(
                image=img_np,
                bboxes=bboxes_norm,
                class_labels=labels,
            )
            img_np = transformed["image"]
            bboxes_norm = transformed["bboxes"]
            labels = transformed["class_labels"]

        if isinstance(img_np, np.ndarray):
            img_tensor = torch.from_numpy(img_np).permute(2, 0, 1).float() / 255.0
        else:
            img_tensor = img_np

        targets = {
            "boxes": torch.tensor(bboxes_norm, dtype=torch.float32)
            if bboxes_norm
            else torch.zeros((0, 4), dtype=torch.float32),
            "labels": torch.tensor(labels, dtype=torch.long),
        }
        return img_tensor, targets


# ---------------------------------------------------------------------------
# Classifier dataset
# ---------------------------------------------------------------------------

class GreyEyeClassifierDataset(Dataset):
    """Dataset for 12-class vehicle classification training.

    Expects a directory of annotation JSONs where each detection has a
    non-null ``class12`` label.  Crops are extracted from the source images
    at load time.

    Parameters
    ----------
    annotation_dir:
        Directory containing GreyEye annotation ``.json`` files.
    transform:
        An Albumentations ``Compose`` pipeline (accepts ``image``).
    min_crop_px:
        Minimum crop dimension in pixels; smaller crops are skipped.
    """

    def __init__(
        self,
        annotation_dir: str | Path,
        transform: Any | None = None,
        min_crop_px: int = 16,
    ) -> None:
        self.annotation_dir = Path(annotation_dir)
        self.transform = transform
        self.min_crop_px = min_crop_px
        self.samples: list[tuple[str, BoundingBox, VehicleClass12]] = []
        self._build_index()

    def _build_index(self) -> None:
        for p in sorted(self.annotation_dir.glob("*.json")):
            with open(p, encoding="utf-8") as f:
                ann = GreyEyeAnnotation.model_validate(json.load(f))
            for det in ann.detections:
                if det.class12 is not None:
                    self.samples.append((ann.image_path, det.bbox, det.class12))

    def __len__(self) -> int:
        return len(self.samples)

    def __getitem__(self, idx: int) -> tuple[torch.Tensor, int]:
        image_path, bbox, class12 = self.samples[idx]
        image = Image.open(image_path).convert("RGB")
        w, h = image.size

        x1 = max(int(bbox.x * w), 0)
        y1 = max(int(bbox.y * h), 0)
        x2 = min(int((bbox.x + bbox.w) * w), w)
        y2 = min(int((bbox.y + bbox.h) * h), h)

        crop = image.crop((x1, y1, x2, y2))
        if crop.width < self.min_crop_px or crop.height < self.min_crop_px:
            crop = crop.resize((self.min_crop_px, self.min_crop_px), Image.BILINEAR)

        crop_np = np.array(crop)

        if self.transform is not None:
            transformed = self.transform(image=crop_np)
            crop_np = transformed["image"]

        if isinstance(crop_np, np.ndarray):
            tensor = torch.from_numpy(crop_np).permute(2, 0, 1).float() / 255.0
        else:
            tensor = crop_np

        label = class12.value - 1  # 0-indexed for CrossEntropyLoss
        return tensor, label

    def class_counts(self) -> dict[int, int]:
        """Return {label_index: count} for computing sample weights."""
        counts: dict[int, int] = {}
        for _, _, c12 in self.samples:
            lbl = c12.value - 1
            counts[lbl] = counts.get(lbl, 0) + 1
        return counts
