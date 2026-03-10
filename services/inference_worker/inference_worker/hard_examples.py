"""Hard-example collection for active learning (FR-9.4).

Flags low-confidence, class-flip, and rare-class frames for human review.
Saves frame + crop to S3-compatible object storage with rate limiting.
"""

from __future__ import annotations

import io
import logging
import time
from datetime import datetime
from typing import TYPE_CHECKING

import numpy as np

from inference_worker.models import ClassPrediction, HardExample, SmoothedPrediction, TrackState
from shared_contracts.enums import VehicleClass12

if TYPE_CHECKING:
    from inference_worker.settings import HardExampleSettings

logger = logging.getLogger(__name__)


class HardExampleCollector:
    """Collects hard examples for the active-learning pipeline.

    Triggers:
    - Low confidence: smoothed_confidence < threshold
    - Class flip: temporal smoother changes the class label
    - Rare class: vehicle classified as a heavy/combination class (5-12)
    """

    def __init__(self, settings: HardExampleSettings) -> None:
        self._settings = settings
        self._hour_counter: int = 0
        self._hour_start: float = time.monotonic()
        self._rare_class_ids = set(settings.rare_class_ids)

    def _check_rate_limit(self) -> bool:
        now = time.monotonic()
        if now - self._hour_start >= 3600:
            self._hour_counter = 0
            self._hour_start = now

        if self._hour_counter >= self._settings.max_per_hour:
            return False
        return True

    def _increment(self) -> None:
        self._hour_counter += 1

    def check_and_collect(
        self,
        track: TrackState,
        smoothed: SmoothedPrediction,
        previous_class: VehicleClass12 | None,
        frame_data: bytes,
        frame: np.ndarray,
        camera_id: str,
        frame_index: int,
        timestamp_utc: datetime,
        model_version: str,
    ) -> HardExample | None:
        """Evaluate whether this prediction should be flagged as a hard example.

        Returns a HardExample if any trigger fires and rate limit allows, else None.
        """
        if not self._settings.enabled:
            return None

        trigger: str | None = None

        if smoothed.confidence < self._settings.confidence_threshold:
            trigger = "low_confidence"
        elif previous_class is not None and previous_class != smoothed.class12:
            trigger = "class_flip"
        elif smoothed.class12.value in self._rare_class_ids:
            trigger = "rare_class"

        if trigger is None:
            return None

        if not self._check_rate_limit():
            return None

        self._increment()

        crop_data = self._extract_crop(frame, smoothed.raw_prediction)

        return HardExample(
            frame_data=frame_data,
            crop_data=crop_data,
            camera_id=camera_id,
            track_id=track.track_id,
            frame_index=frame_index,
            timestamp_utc=timestamp_utc,
            predicted_class12=smoothed.class12,
            confidence=smoothed.confidence,
            probabilities=smoothed.probabilities,
            trigger_reason=trigger,
            model_version=model_version,
        )

    def _extract_crop(
        self,
        frame: np.ndarray,
        prediction: ClassPrediction,
    ) -> bytes | None:
        """Extract the vehicle crop as JPEG bytes."""
        h, w = frame.shape[:2]
        bbox = prediction.crop_bbox
        x1 = max(0, int(bbox.x * w))
        y1 = max(0, int(bbox.y * h))
        x2 = min(w, int((bbox.x + bbox.w) * w))
        y2 = min(h, int((bbox.y + bbox.h) * h))

        crop = frame[y1:y2, x1:x2]
        if crop.size == 0:
            return None

        try:
            import cv2

            _, buf = cv2.imencode(".jpg", crop, [cv2.IMWRITE_JPEG_QUALITY, 90])
            return buf.tobytes()
        except ImportError:
            try:
                from PIL import Image

                pil_img = Image.fromarray(crop)
                buffer = io.BytesIO()
                pil_img.save(buffer, format="JPEG", quality=90)
                return buffer.getvalue()
            except ImportError:
                return None
