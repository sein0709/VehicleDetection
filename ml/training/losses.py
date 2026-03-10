"""Custom loss functions for GreyEye classifier training.

Provides focal loss (to handle class imbalance) and label-smoothing
cross-entropy, both used for the 12-class vehicle classifier.
"""

from __future__ import annotations

import torch
import torch.nn as nn
import torch.nn.functional as F


class FocalLoss(nn.Module):
    """Focal loss for multi-class classification (Lin et al., 2017).

    Down-weights well-classified examples so the model focuses on hard,
    misclassified samples — critical for the heavily skewed 12-class
    vehicle distribution.

    Parameters
    ----------
    gamma:
        Focusing parameter.  ``gamma=0`` recovers standard CE.
    alpha:
        Per-class weight tensor of shape ``(num_classes,)``.  If ``None``,
        all classes are weighted equally.
    label_smoothing:
        Label smoothing factor ``epsilon``.  Distributes ``epsilon``
        probability mass uniformly across all classes.
    """

    def __init__(
        self,
        gamma: float = 2.0,
        alpha: torch.Tensor | None = None,
        label_smoothing: float = 0.1,
    ) -> None:
        super().__init__()
        self.gamma = gamma
        self.label_smoothing = label_smoothing
        if alpha is not None:
            self.register_buffer("alpha", alpha.float())
        else:
            self.alpha: torch.Tensor | None = None

    def forward(self, logits: torch.Tensor, targets: torch.Tensor) -> torch.Tensor:
        """Compute focal loss.

        Parameters
        ----------
        logits:
            Raw model output, shape ``(B, C)``.
        targets:
            Ground-truth class indices, shape ``(B,)``.
        """
        num_classes = logits.size(1)
        ce = F.cross_entropy(
            logits, targets, reduction="none", label_smoothing=self.label_smoothing
        )
        p_t = torch.exp(-ce)
        focal_weight = (1.0 - p_t) ** self.gamma

        if self.alpha is not None:
            alpha_t = self.alpha.to(logits.device)[targets]
            focal_weight = focal_weight * alpha_t

        return (focal_weight * ce).mean()


class LabelSmoothingCrossEntropy(nn.Module):
    """Cross-entropy with label smoothing.

    Parameters
    ----------
    epsilon:
        Smoothing factor.  ``epsilon=0`` is standard CE.
    """

    def __init__(self, epsilon: float = 0.1) -> None:
        super().__init__()
        self.epsilon = epsilon

    def forward(self, logits: torch.Tensor, targets: torch.Tensor) -> torch.Tensor:
        return F.cross_entropy(
            logits, targets, label_smoothing=self.epsilon
        )
