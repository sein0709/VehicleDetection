"""Weighted sampler for class-imbalanced vehicle classification training.

Traffic class distributions are heavily skewed — Class 1 (passenger cars)
dominates at 70-80 % of real-world traffic while Classes 7, 11, 12 may be
< 0.5 %.  This sampler assigns weights inversely proportional to class
frequency so that rare classes are oversampled during training.
"""

from __future__ import annotations

import math

import torch
from torch.utils.data import WeightedRandomSampler

from ml.data.dataset import GreyEyeClassifierDataset

NUM_CLASSES = 12


class ClassWeightedSampler:
    """Factory for ``WeightedRandomSampler`` based on inverse class frequency.

    Parameters
    ----------
    dataset:
        A ``GreyEyeClassifierDataset`` instance.
    num_samples:
        How many samples per epoch.  Defaults to ``len(dataset)``.
    smoothing:
        Smoothing exponent applied to inverse frequencies.  ``1.0`` gives
        pure inverse frequency; ``0.5`` applies square-root smoothing for
        a gentler rebalance.
    """

    def __init__(
        self,
        dataset: GreyEyeClassifierDataset,
        num_samples: int | None = None,
        smoothing: float = 0.5,
    ) -> None:
        self.dataset = dataset
        self.num_samples = num_samples or len(dataset)
        self.smoothing = smoothing

    def build(self) -> WeightedRandomSampler:
        counts = self.dataset.class_counts()
        total = sum(counts.values())

        class_weight: dict[int, float] = {}
        for lbl in range(NUM_CLASSES):
            freq = counts.get(lbl, 0)
            if freq == 0:
                class_weight[lbl] = 0.0
            else:
                inv_freq = total / freq
                class_weight[lbl] = math.pow(inv_freq, self.smoothing)

        sample_weights: list[float] = []
        for _, _, c12 in self.dataset.samples:
            lbl = c12.value - 1
            sample_weights.append(class_weight[lbl])

        return WeightedRandomSampler(
            weights=torch.tensor(sample_weights, dtype=torch.double),
            num_samples=self.num_samples,
            replacement=True,
        )

    def class_weights_tensor(self) -> torch.Tensor:
        """Return a (12,) tensor of per-class weights for use in loss functions."""
        counts = self.dataset.class_counts()
        total = sum(counts.values())
        weights = []
        for lbl in range(NUM_CLASSES):
            freq = counts.get(lbl, 0)
            if freq == 0:
                weights.append(0.0)
            else:
                weights.append(math.pow(total / freq, self.smoothing))
        return torch.tensor(weights, dtype=torch.float32)
