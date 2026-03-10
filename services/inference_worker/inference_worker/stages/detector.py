"""Stage 1 -- YOLO-based vehicle detection.

Runs a YOLO model (via ONNX Runtime) on full frames to produce bounding boxes
with confidence scores.  The detector outputs a single 'vehicle' class;
fine-grained 12-class discrimination is deferred to Stage 3.
"""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING, Protocol, runtime_checkable

import numpy as np

from inference_worker.models import Detection
from shared_contracts.geometry import BoundingBox

if TYPE_CHECKING:
    from inference_worker.settings import DetectorSettings

logger = logging.getLogger(__name__)

NUM_CLASSES = 12


def _letterbox(
    image: np.ndarray,
    target_size: int,
) -> tuple[np.ndarray, float, tuple[int, int]]:
    """Resize with letterboxing to preserve aspect ratio.

    Returns (padded_image, scale_factor, (pad_w, pad_h)).
    """
    h, w = image.shape[:2]
    scale = target_size / max(h, w)
    new_w, new_h = int(w * scale), int(h * scale)

    resized = np.zeros((target_size, target_size, 3), dtype=np.uint8) + 114
    pad_w = (target_size - new_w) // 2
    pad_h = (target_size - new_h) // 2

    from numpy import ascontiguousarray

    if new_w != w or new_h != h:
        try:
            import cv2

            resized_img = cv2.resize(image, (new_w, new_h), interpolation=cv2.INTER_LINEAR)
        except ImportError:
            from PIL import Image

            pil_img = Image.fromarray(image).resize((new_w, new_h), Image.BILINEAR)
            resized_img = np.array(pil_img)
    else:
        resized_img = image

    resized[pad_h : pad_h + new_h, pad_w : pad_w + new_w] = resized_img
    return ascontiguousarray(resized), scale, (pad_w, pad_h)


def _nms(
    boxes: np.ndarray,
    scores: np.ndarray,
    iou_threshold: float,
) -> list[int]:
    """Non-maximum suppression on (N, 4) boxes in xyxy format."""
    if len(boxes) == 0:
        return []

    x1, y1, x2, y2 = boxes[:, 0], boxes[:, 1], boxes[:, 2], boxes[:, 3]
    areas = (x2 - x1) * (y2 - y1)
    order = scores.argsort()[::-1]
    keep: list[int] = []

    while order.size > 0:
        i = order[0]
        keep.append(int(i))
        if order.size == 1:
            break

        xx1 = np.maximum(x1[i], x1[order[1:]])
        yy1 = np.maximum(y1[i], y1[order[1:]])
        xx2 = np.minimum(x2[i], x2[order[1:]])
        yy2 = np.minimum(y2[i], y2[order[1:]])

        inter = np.maximum(0.0, xx2 - xx1) * np.maximum(0.0, yy2 - yy1)
        iou = inter / (areas[i] + areas[order[1:]] - inter + 1e-6)

        remaining = np.where(iou <= iou_threshold)[0]
        order = order[remaining + 1]

    return keep


@runtime_checkable
class DetectorBackend(Protocol):
    """Protocol for swappable detection backends (ONNX, TorchScript, stub)."""

    def detect(
        self,
        preprocessed: np.ndarray,
    ) -> np.ndarray:
        """Run detection on a preprocessed (1, 3, H, W) float32 tensor.

        Returns raw model output whose shape depends on the backend.
        """
        ...


class OnnxDetectorBackend:
    """ONNX Runtime detection backend."""

    def __init__(self, model_path: str) -> None:
        import onnxruntime as ort

        providers = ["CUDAExecutionProvider", "CPUExecutionProvider"]
        self._session = ort.InferenceSession(model_path, providers=providers)
        self._input_name = self._session.get_inputs()[0].name
        logger.info("Loaded ONNX detector from %s", model_path)

    def detect(self, preprocessed: np.ndarray) -> np.ndarray:
        outputs = self._session.run(None, {self._input_name: preprocessed})
        return outputs[0]


class StubDetectorBackend:
    """Deterministic stub for testing without a real model file."""

    def detect(self, preprocessed: np.ndarray) -> np.ndarray:
        return np.empty((1, 0, 6), dtype=np.float32)


class VehicleDetector:
    """Stage 1: full-frame vehicle detection with YOLO.

    Accepts raw BGR/RGB frames, applies letterbox preprocessing, runs the
    detection model, and returns normalised BoundingBox detections.
    """

    def __init__(self, settings: DetectorSettings, backend: DetectorBackend | None = None) -> None:
        self._settings = settings
        if backend is not None:
            self._backend = backend
        else:
            try:
                self._backend = OnnxDetectorBackend(settings.model_path)
            except Exception:
                logger.warning("Could not load ONNX detector; falling back to stub")
                self._backend = StubDetectorBackend()

    def detect_frame(
        self,
        frame: np.ndarray,
        frame_index: int,
    ) -> list[Detection]:
        """Run detection on a single frame (H, W, 3) uint8 array.

        Returns a list of Detection objects with normalised bbox coordinates.
        """
        h_orig, w_orig = frame.shape[:2]
        target = self._settings.input_size

        padded, scale, (pad_w, pad_h) = _letterbox(frame, target)

        blob = padded.astype(np.float32) / 255.0
        blob = blob.transpose(2, 0, 1)[np.newaxis]  # (1, 3, H, W)

        raw = self._backend.detect(blob)
        return self._postprocess(raw, w_orig, h_orig, scale, pad_w, pad_h, frame_index)

    def _postprocess(
        self,
        raw: np.ndarray,
        w_orig: int,
        h_orig: int,
        scale: float,
        pad_w: int,
        pad_h: int,
        frame_index: int,
    ) -> list[Detection]:
        """Convert raw model output to normalised Detection objects.

        Handles the common YOLO output format: (1, N, 4+1+num_classes) or
        (1, 4+1+num_classes, N) where the 4 values are cx, cy, w, h.
        """
        if raw.size == 0:
            return []

        if raw.ndim == 3:
            preds = raw[0]
        else:
            preds = raw

        if preds.ndim == 2 and preds.shape[0] in (4, 5, 5 + NUM_CLASSES, 4 + NUM_CLASSES):
            if preds.shape[0] < preds.shape[1]:
                preds = preds.T

        if preds.shape[1] < 5:
            return []

        conf_threshold = self._settings.confidence_threshold
        target = self._settings.input_size

        if preds.shape[1] == 5:
            scores = preds[:, 4]
        elif preds.shape[1] == 5 + NUM_CLASSES:
            scores = preds[:, 4] * preds[:, 5:].max(axis=1)
        elif preds.shape[1] == 4 + NUM_CLASSES:
            scores = preds[:, 4:].max(axis=1)
        else:
            scores = preds[:, 4]

        mask = scores >= conf_threshold
        preds = preds[mask]
        scores = scores[mask]

        if len(preds) == 0:
            return []

        cx, cy, bw, bh = preds[:, 0], preds[:, 1], preds[:, 2], preds[:, 3]
        x1 = cx - bw / 2
        y1 = cy - bh / 2
        x2 = cx + bw / 2
        y2 = cy + bh / 2

        boxes_xyxy = np.stack([x1, y1, x2, y2], axis=1)

        keep = _nms(boxes_xyxy, scores, self._settings.nms_iou_threshold)
        keep = keep[: self._settings.max_detections]

        detections: list[Detection] = []
        for idx in keep:
            bx1 = (boxes_xyxy[idx, 0] - pad_w) / scale
            by1 = (boxes_xyxy[idx, 1] - pad_h) / scale
            bx2 = (boxes_xyxy[idx, 2] - pad_w) / scale
            by2 = (boxes_xyxy[idx, 3] - pad_h) / scale

            nx = max(0.0, min(1.0, bx1 / w_orig))
            ny = max(0.0, min(1.0, by1 / h_orig))
            nw = max(0.0, min(1.0, (bx2 - bx1) / w_orig))
            nh = max(0.0, min(1.0, (by2 - by1) / h_orig))

            if nw < 0.005 or nh < 0.005:
                continue

            detections.append(
                Detection(
                    bbox=BoundingBox(x=nx, y=ny, w=nw, h=nh),
                    confidence=float(scores[idx]),
                    frame_index=frame_index,
                )
            )

        return detections
