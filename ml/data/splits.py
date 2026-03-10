"""Train / validation / test split management for GreyEye datasets.

Provides deterministic, stratified splitting of annotation files and a
manifest format that records which files belong to each split for
reproducibility.
"""

from __future__ import annotations

import json
import logging
import random
from dataclasses import dataclass, field
from pathlib import Path

from ml.data.dataset import GreyEyeAnnotation

logger = logging.getLogger(__name__)


@dataclass
class SplitManifest:
    """Records which annotation files belong to each split."""

    train: list[str] = field(default_factory=list)
    val: list[str] = field(default_factory=list)
    test: list[str] = field(default_factory=list)
    seed: int = 42

    def save(self, path: Path) -> None:
        path.write_text(
            json.dumps(
                {
                    "seed": self.seed,
                    "train": self.train,
                    "val": self.val,
                    "test": self.test,
                },
                indent=2,
            ),
            encoding="utf-8",
        )

    @classmethod
    def load(cls, path: Path) -> SplitManifest:
        data = json.loads(path.read_text(encoding="utf-8"))
        return cls(
            train=data["train"],
            val=data["val"],
            test=data.get("test", []),
            seed=data.get("seed", 42),
        )


def create_splits(
    annotation_dir: Path,
    output_dir: Path | None = None,
    *,
    train_ratio: float = 0.8,
    val_ratio: float = 0.1,
    test_ratio: float = 0.1,
    seed: int = 42,
    stratify: bool = True,
) -> SplitManifest:
    """Split annotation files into train / val / test sets.

    When *stratify* is ``True`` and annotations contain ``class12`` labels,
    the split is stratified by the most frequent class in each image to
    preserve class distribution across splits.

    Parameters
    ----------
    annotation_dir:
        Directory containing GreyEye ``.json`` annotation files.
    output_dir:
        If provided, the manifest is written here as ``split_manifest.json``.
    train_ratio, val_ratio, test_ratio:
        Proportions (must sum to 1.0).
    seed:
        Random seed for reproducibility.
    stratify:
        Whether to stratify by class label.
    """
    assert abs(train_ratio + val_ratio + test_ratio - 1.0) < 1e-6

    ann_files = sorted(annotation_dir.glob("*.json"))
    if not ann_files:
        logger.warning("No annotation files found in %s", annotation_dir)
        return SplitManifest(seed=seed)

    if stratify:
        buckets: dict[int | None, list[str]] = {}
        for p in ann_files:
            ann = GreyEyeAnnotation.model_validate(json.loads(p.read_text("utf-8")))
            labels = [d.class12.value if d.class12 else None for d in ann.detections]
            key = max(set(labels), key=labels.count) if labels else None
            buckets.setdefault(key, []).append(p.name)
    else:
        buckets = {None: [p.name for p in ann_files]}

    rng = random.Random(seed)
    manifest = SplitManifest(seed=seed)

    for _key, names in sorted(buckets.items(), key=lambda kv: str(kv[0])):
        rng.shuffle(names)
        n = len(names)
        n_train = max(1, int(n * train_ratio))
        n_val = max(0, int(n * val_ratio))

        manifest.train.extend(names[:n_train])
        manifest.val.extend(names[n_train : n_train + n_val])
        manifest.test.extend(names[n_train + n_val :])

    if output_dir is not None:
        output_dir.mkdir(parents=True, exist_ok=True)
        manifest.save(output_dir / "split_manifest.json")
        logger.info(
            "Split: train=%d, val=%d, test=%d",
            len(manifest.train),
            len(manifest.val),
            len(manifest.test),
        )

    return manifest
