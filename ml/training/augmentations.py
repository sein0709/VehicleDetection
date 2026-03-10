"""Albumentations augmentation pipelines for detector and classifier training.

Detector augmentations operate on full frames with bounding-box-aware
transforms.  Classifier augmentations operate on cropped vehicle regions.
"""

from __future__ import annotations

import albumentations as A
from albumentations.pytorch import ToTensorV2

IMAGENET_MEAN = (0.485, 0.456, 0.406)
IMAGENET_STD = (0.229, 0.224, 0.225)


def detector_train_transform(input_size: int = 640) -> A.Compose:
    return A.Compose(
        [
            A.RandomResizedCrop(
                height=input_size,
                width=input_size,
                scale=(0.5, 1.0),
            ),
            A.HorizontalFlip(p=0.5),
            A.ColorJitter(
                brightness=0.3, contrast=0.3, saturation=0.3, hue=0.1, p=0.8
            ),
            A.GaussNoise(var_limit=(10, 50), p=0.3),
            A.MotionBlur(blur_limit=7, p=0.2),
            A.RandomBrightnessContrast(
                brightness_limit=0.3, contrast_limit=0.3, p=0.5
            ),
            A.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
            ToTensorV2(),
        ],
        bbox_params=A.BboxParams(
            format="yolo",
            label_fields=["class_labels"],
            min_visibility=0.3,
        ),
    )


def detector_val_transform(input_size: int = 640) -> A.Compose:
    return A.Compose(
        [
            A.Resize(height=input_size, width=input_size),
            A.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
            ToTensorV2(),
        ],
        bbox_params=A.BboxParams(
            format="yolo",
            label_fields=["class_labels"],
            min_visibility=0.3,
        ),
    )


def classifier_train_transform(input_size: int = 224) -> A.Compose:
    return A.Compose(
        [
            A.RandomResizedCrop(
                height=input_size,
                width=input_size,
                scale=(0.7, 1.0),
            ),
            A.HorizontalFlip(p=0.5),
            A.ColorJitter(
                brightness=0.4, contrast=0.4, saturation=0.4, hue=0.15, p=0.8
            ),
            A.GaussNoise(var_limit=(10, 30), p=0.2),
            A.CoarseDropout(
                max_holes=8, max_height=28, max_width=28, p=0.3
            ),
            A.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
            ToTensorV2(),
        ]
    )


def classifier_val_transform(input_size: int = 224) -> A.Compose:
    return A.Compose(
        [
            A.Resize(height=input_size, width=input_size),
            A.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
            ToTensorV2(),
        ]
    )
