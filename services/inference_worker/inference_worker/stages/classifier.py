"""Stage 3 -- 12-class vehicle classification.

Crops detected vehicle regions, resizes to 224x224, and runs through an
EfficientNet-B0/MobileNetV3 classifier to produce a probability distribution
over the 12 KICT/MOLIT vehicle classes.
"""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING, Protocol, runtime_checkable

import numpy as np

from inference_worker.models import ClassPrediction
from shared_contracts.enums import COARSE_MAPPING, ClassificationMode, CoarseFallbackClass, VehicleClass12
from shared_contracts.geometry import BoundingBox

if TYPE_CHECKING:
    from inference_worker.settings import ClassifierSettings

logger = logging.getLogger(__name__)

NUM_CLASSES = 12

COARSE_MAP: dict[str, list[VehicleClass12]] = {
    "car": [VehicleClass12.C01_PASSENGER_MINITRUCK],
    "bus": [VehicleClass12.C02_BUS],
    "truck": [
        VehicleClass12.C03_TRUCK_LT_2_5T,
        VehicleClass12.C04_TRUCK_2_5_TO_8_5T,
        VehicleClass12.C05_SINGLE_3_AXLE,
        VehicleClass12.C06_SINGLE_4_AXLE,
        VehicleClass12.C07_SINGLE_5_AXLE,
    ],
    "trailer": [
        VehicleClass12.C08_SEMI_4_AXLE,
        VehicleClass12.C09_FULL_4_AXLE,
        VehicleClass12.C10_SEMI_5_AXLE,
        VehicleClass12.C11_FULL_5_AXLE,
        VehicleClass12.C12_SEMI_6_AXLE,
    ],
}


def apply_coarse_fallback(pred: ClassPrediction, threshold: float) -> ClassPrediction:
    """Collapse to coarse group when fine-grained confidence is below threshold."""
    if pred.confidence >= threshold:
        return pred

    coarse_probs: dict[str, float] = {}
    for group, members in COARSE_MAP.items():
        coarse_probs[group] = sum(pred.probabilities[c.value - 1] for c in members)

    best_group = max(coarse_probs, key=lambda k: coarse_probs[k])
    representative = COARSE_MAP[best_group][0]

    return ClassPrediction(
        class12=representative,
        probabilities=pred.probabilities,
        confidence=coarse_probs[best_group],
        crop_bbox=pred.crop_bbox,
    )


def _softmax(x: np.ndarray) -> np.ndarray:
    e = np.exp(x - np.max(x, axis=-1, keepdims=True))
    return e / (e.sum(axis=-1, keepdims=True) + 1e-9)


@runtime_checkable
class ClassifierBackend(Protocol):
    """Protocol for swappable classification backends."""

    def classify_batch(self, crops: np.ndarray) -> np.ndarray:
        """Run classification on (N, 3, H, W) float32 tensor.

        Returns (N, 12) logits or probabilities.
        """
        ...


class OnnxClassifierBackend:
    """ONNX Runtime classification backend."""

    def __init__(self, model_path: str) -> None:
        import onnxruntime as ort

        providers = ["CUDAExecutionProvider", "CPUExecutionProvider"]
        self._session = ort.InferenceSession(model_path, providers=providers)
        self._input_name = self._session.get_inputs()[0].name
        logger.info("Loaded ONNX classifier from %s", model_path)

    def classify_batch(self, crops: np.ndarray) -> np.ndarray:
        outputs = self._session.run(None, {self._input_name: crops})
        return outputs[0]


class StubClassifierBackend:
    """Deterministic stub that returns uniform probabilities."""

    def classify_batch(self, crops: np.ndarray) -> np.ndarray:
        n = crops.shape[0]
        return np.full((n, NUM_CLASSES), 1.0 / NUM_CLASSES, dtype=np.float32)


class VehicleClassifier:
    """Stage 3: 12-class vehicle classification from cropped regions."""

    IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

    def __init__(
        self,
        settings: ClassifierSettings,
        backend: ClassifierBackend | None = None,
    ) -> None:
        self._settings = settings
        if backend is not None:
            self._backend = backend
        else:
            try:
                self._backend = OnnxClassifierBackend(settings.model_path)
            except Exception:
                logger.warning("Could not load ONNX classifier; falling back to stub")
                self._backend = StubClassifierBackend()

    def classify_crops(
        self,
        frame: np.ndarray,
        bboxes: list[BoundingBox],
    ) -> list[ClassPrediction]:
        """Classify a batch of vehicle crops from a single frame.

        Args:
            frame: Original frame (H, W, 3) uint8.
            bboxes: Normalised bounding boxes for each detected vehicle.

        Returns:
            List of ClassPrediction, one per bbox.
        """
        mode = self._settings.mode
        if mode == ClassificationMode.DISABLED:
            return [
                ClassPrediction(
                    class12=VehicleClass12.C01_PASSENGER_MINITRUCK,
                    probabilities=[1.0 / NUM_CLASSES] * NUM_CLASSES,
                    confidence=0.0,
                    crop_bbox=bbox,
                )
                for bbox in bboxes
            ]

        if not bboxes:
            return []

        crops = self._extract_crops(frame, bboxes)
        preprocessed = self._preprocess_batch(crops)

        raw_output = self._backend.classify_batch(preprocessed)
        probs = _softmax(raw_output)

        results: list[ClassPrediction] = []
        fallback_threshold = self._settings.fallback_threshold

        for i, bbox in enumerate(bboxes):
            prob_vec = probs[i].tolist()
            best_idx = int(np.argmax(probs[i]))
            best_conf = prob_vec[best_idx]
            cls = VehicleClass12(best_idx + 1)

            pred = ClassPrediction(
                class12=cls,
                probabilities=prob_vec,
                confidence=best_conf,
                crop_bbox=bbox,
            )

            if mode == ClassificationMode.COARSE_ONLY or best_conf < fallback_threshold:
                pred = apply_coarse_fallback(pred, threshold=0.0)

            results.append(pred)

        return results

    def _extract_crops(
        self,
        frame: np.ndarray,
        bboxes: list[BoundingBox],
    ) -> list[np.ndarray]:
        """Extract and resize vehicle crops from the frame."""
        h, w = frame.shape[:2]
        target = self._settings.input_size
        crops: list[np.ndarray] = []

        for bbox in bboxes:
            x1 = max(0, int(bbox.x * w))
            y1 = max(0, int(bbox.y * h))
            x2 = min(w, int((bbox.x + bbox.w) * w))
            y2 = min(h, int((bbox.y + bbox.h) * h))

            crop = frame[y1:y2, x1:x2]
            if crop.size == 0:
                crop = np.zeros((target, target, 3), dtype=np.uint8)
            else:
                try:
                    import cv2

                    crop = cv2.resize(crop, (target, target), interpolation=cv2.INTER_LINEAR)
                except ImportError:
                    from PIL import Image

                    pil_crop = Image.fromarray(crop).resize((target, target), Image.BILINEAR)
                    crop = np.array(pil_crop)

            crops.append(crop)

        return crops

    def _preprocess_batch(self, crops: list[np.ndarray]) -> np.ndarray:
        """Normalise and stack crops into (N, 3, H, W) float32 tensor."""
        batch = np.stack(crops, axis=0).astype(np.float32) / 255.0
        batch = (batch - self.IMAGENET_MEAN) / self.IMAGENET_STD
        batch = batch.transpose(0, 3, 1, 2)
        return np.ascontiguousarray(batch)
