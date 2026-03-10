"""Stage 4 -- Temporal smoothing of per-track classification predictions.

Stabilises class labels by aggregating predictions over a sliding window,
using either majority voting (default) or exponential moving average (EMA).
"""

from __future__ import annotations

import logging
from collections import Counter
from typing import TYPE_CHECKING

from inference_worker.models import ClassPrediction, SmoothedPrediction
from shared_contracts.enums import VehicleClass12

if TYPE_CHECKING:
    from inference_worker.settings import SmootherSettings

logger = logging.getLogger(__name__)


def _average_probabilities(preds: list[ClassPrediction]) -> list[float]:
    """Element-wise mean of probability vectors."""
    n = len(preds)
    if n == 0:
        return [0.0] * 12
    avg = [0.0] * 12
    for p in preds:
        for i in range(12):
            avg[i] += p.probabilities[i]
    return [v / n for v in avg]


def smooth_majority(
    class_history: list[ClassPrediction],
    window: int,
) -> SmoothedPrediction:
    """Majority voting over the last N predictions."""
    recent = class_history[-window:]
    votes = Counter(p.class12 for p in recent)
    winner, count = votes.most_common(1)[0]
    smoothed_confidence = count / len(recent)

    return SmoothedPrediction(
        class12=winner,
        confidence=smoothed_confidence,
        probabilities=_average_probabilities(recent),
        raw_prediction=recent[-1],
    )


def smooth_ema(
    class_history: list[ClassPrediction],
    alpha: float,
) -> SmoothedPrediction:
    """Exponential moving average over probability vectors, then argmax."""
    ema = [0.0] * 12
    for pred in class_history:
        for i in range(12):
            ema[i] = alpha * pred.probabilities[i] + (1 - alpha) * ema[i]

    total = sum(ema)
    if total > 0:
        ema = [v / total for v in ema]

    best_idx = max(range(12), key=lambda i: ema[i])

    return SmoothedPrediction(
        class12=VehicleClass12(best_idx + 1),
        confidence=ema[best_idx],
        probabilities=ema,
        raw_prediction=class_history[-1],
    )


class TemporalSmoother:
    """Stage 4: temporal smoothing of per-track class predictions."""

    def __init__(self, settings: SmootherSettings) -> None:
        self._settings = settings

    def smooth(
        self,
        class_history: list[ClassPrediction],
        track_age: int,
    ) -> SmoothedPrediction | None:
        """Produce a smoothed prediction from a track's class history.

        Returns None if the track hasn't accumulated enough frames yet.
        """
        if track_age < self._settings.min_track_age or not class_history:
            return None

        if self._settings.strategy == "ema":
            return smooth_ema(class_history, self._settings.ema_alpha)
        return smooth_majority(class_history, self._settings.window)

    def detect_class_flip(
        self,
        class_history: list[ClassPrediction],
        previous_smoothed: VehicleClass12 | None,
        current_smoothed: VehicleClass12,
    ) -> bool:
        """Return True if the smoothed class changed (triggers hard-example collection)."""
        if previous_smoothed is None:
            return False
        return previous_smoothed != current_smoothed
