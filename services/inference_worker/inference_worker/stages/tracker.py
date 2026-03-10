"""Stage 2 -- Multi-object tracking (ByteTrack / OC-SORT).

Assigns persistent track IDs across frames using IoU-based association.
Maintains per-camera TrackState objects with centroid history, age, and
lifecycle (Tentative -> Confirmed -> Deleted).
"""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING

import numpy as np

from inference_worker.models import Detection, TrackState
from shared_contracts.geometry import BoundingBox, Point2D

if TYPE_CHECKING:
    from inference_worker.settings import TrackerSettings

logger = logging.getLogger(__name__)


def _bbox_to_xyxy(bbox: BoundingBox) -> np.ndarray:
    return np.array([bbox.x, bbox.y, bbox.x + bbox.w, bbox.y + bbox.h])


def _iou_matrix(boxes_a: np.ndarray, boxes_b: np.ndarray) -> np.ndarray:
    """Compute IoU between two sets of xyxy boxes -> (M, N) matrix."""
    if len(boxes_a) == 0 or len(boxes_b) == 0:
        return np.empty((len(boxes_a), len(boxes_b)), dtype=np.float32)

    x1 = np.maximum(boxes_a[:, None, 0], boxes_b[None, :, 0])
    y1 = np.maximum(boxes_a[:, None, 1], boxes_b[None, :, 1])
    x2 = np.minimum(boxes_a[:, None, 2], boxes_b[None, :, 2])
    y2 = np.minimum(boxes_a[:, None, 3], boxes_b[None, :, 3])

    inter = np.maximum(0, x2 - x1) * np.maximum(0, y2 - y1)
    area_a = (boxes_a[:, 2] - boxes_a[:, 0]) * (boxes_a[:, 3] - boxes_a[:, 1])
    area_b = (boxes_b[:, 2] - boxes_b[:, 0]) * (boxes_b[:, 3] - boxes_b[:, 1])
    union = area_a[:, None] + area_b[None, :] - inter

    return inter / (union + 1e-6)


def _linear_assignment(cost_matrix: np.ndarray, threshold: float) -> tuple[list[tuple[int, int]], list[int], list[int]]:
    """Greedy assignment on a cost matrix (higher = better match).

    Returns (matches, unmatched_rows, unmatched_cols).
    """
    matches: list[tuple[int, int]] = []
    matched_rows: set[int] = set()
    matched_cols: set[int] = set()

    if cost_matrix.size == 0:
        return (
            [],
            list(range(cost_matrix.shape[0])),
            list(range(cost_matrix.shape[1])),
        )

    try:
        from scipy.optimize import linear_sum_assignment

        row_idx, col_idx = linear_sum_assignment(-cost_matrix)
        for r, c in zip(row_idx, col_idx):
            if cost_matrix[r, c] >= threshold:
                matches.append((r, c))
                matched_rows.add(r)
                matched_cols.add(c)
    except ImportError:
        flat = cost_matrix.flatten()
        sorted_indices = np.argsort(-flat)
        for idx in sorted_indices:
            r, c = divmod(int(idx), cost_matrix.shape[1])
            if r in matched_rows or c in matched_cols:
                continue
            if cost_matrix[r, c] < threshold:
                break
            matches.append((r, c))
            matched_rows.add(r)
            matched_cols.add(c)

    unmatched_rows = [i for i in range(cost_matrix.shape[0]) if i not in matched_rows]
    unmatched_cols = [j for j in range(cost_matrix.shape[1]) if j not in matched_cols]
    return matches, unmatched_rows, unmatched_cols


class ByteTracker:
    """ByteTrack-style multi-object tracker.

    Two-stage association: first match high-confidence detections to existing
    tracks, then attempt to recover unmatched tracks using low-confidence
    detections.
    """

    def __init__(self, settings: TrackerSettings, camera_id: str) -> None:
        self._settings = settings
        self._camera_id = camera_id
        self._next_id = 0

    def _new_track_id(self) -> str:
        tid = f"trk_{self._next_id:05d}"
        self._next_id += 1
        return tid

    def update(
        self,
        detections: list[Detection],
        existing_tracks: dict[str, TrackState],
        frame_index: int,
        fps: float = 10.0,
    ) -> dict[str, TrackState]:
        """Run one tracking step.

        Returns the updated track state dict (may add new tracks, remove dead ones).
        """
        settings = self._settings

        high_conf = [d for d in detections if d.confidence >= 0.5]
        low_conf = [d for d in detections if d.confidence < 0.5]

        confirmed = {k: v for k, v in existing_tracks.items() if v.is_confirmed}
        tentative = {k: v for k, v in existing_tracks.items() if not v.is_confirmed}

        updated: dict[str, TrackState] = {}

        matched_track_ids, remaining_high = self._associate(
            confirmed, high_conf, frame_index, fps, updated
        )

        unmatched_confirmed = {
            k: v for k, v in confirmed.items() if k not in matched_track_ids
        }
        self._associate(
            unmatched_confirmed, low_conf, frame_index, fps, updated
        )

        still_unmatched = {
            k: v for k, v in unmatched_confirmed.items() if k not in updated
        }
        for tid, ts in still_unmatched.items():
            ts.time_since_update += 1
            ts.occlusion_flag = True
            if ts.time_since_update <= settings.max_age:
                updated[tid] = ts

        tent_matched, _ = self._associate(
            tentative, remaining_high, frame_index, fps, updated
        )
        unmatched_tentative = {
            k: v for k, v in tentative.items() if k not in tent_matched and k not in updated
        }
        for tid, ts in unmatched_tentative.items():
            ts.time_since_update += 1
            if ts.time_since_update <= settings.max_age:
                updated[tid] = ts

        all_remaining_dets = [d for d in remaining_high if d not in []]
        matched_det_indices: set[int] = set()
        for d_idx, det in enumerate(remaining_high):
            already_used = False
            for ts in updated.values():
                if ts.last_seen_frame == frame_index and ts.bbox == det.bbox:
                    already_used = True
                    break
            if already_used:
                matched_det_indices.add(d_idx)

        for d_idx, det in enumerate(remaining_high):
            if d_idx in matched_det_indices:
                continue
            new_id = self._new_track_id()
            centroid = det.bbox.center
            updated[new_id] = TrackState(
                track_id=new_id,
                bbox=det.bbox,
                centroid=centroid,
                centroid_history=[centroid],
                first_seen_frame=frame_index,
                last_seen_frame=frame_index,
                age=1,
                hits=1,
                time_since_update=0,
                is_confirmed=False,
            )

        for ts in updated.values():
            if not ts.is_confirmed and ts.hits >= settings.min_hits:
                ts.is_confirmed = True

        return updated

    def _associate(
        self,
        tracks: dict[str, TrackState],
        detections: list[Detection],
        frame_index: int,
        fps: float,
        output: dict[str, TrackState],
    ) -> tuple[set[str], list[Detection]]:
        """Associate detections to tracks via IoU, update matched tracks.

        Returns (matched_track_ids, unmatched_detections).
        """
        if not tracks or not detections:
            return set(), list(detections)

        track_ids = list(tracks.keys())
        track_boxes = np.array([_bbox_to_xyxy(tracks[tid].bbox) for tid in track_ids])
        det_boxes = np.array([_bbox_to_xyxy(d.bbox) for d in detections])

        iou = _iou_matrix(track_boxes, det_boxes)
        matches, unmatched_t, unmatched_d = _linear_assignment(
            iou, self._settings.iou_threshold
        )

        matched_tids: set[str] = set()
        matched_dets: set[int] = set()

        for t_idx, d_idx in matches:
            tid = track_ids[t_idx]
            det = detections[d_idx]
            ts = tracks[tid]

            centroid = det.bbox.center
            ts.bbox = det.bbox
            ts.centroid = centroid
            ts.centroid_history.append(centroid)
            if len(ts.centroid_history) > self._settings.centroid_history_length:
                ts.centroid_history = ts.centroid_history[-self._settings.centroid_history_length :]
            ts.last_seen_frame = frame_index
            ts.age += 1
            ts.hits += 1
            ts.time_since_update = 0
            ts.occlusion_flag = False

            if len(ts.centroid_history) >= 2 and fps > 0:
                prev = ts.centroid_history[-2]
                disp = ((centroid.x - prev.x) ** 2 + (centroid.y - prev.y) ** 2) ** 0.5
                ts.speed_estimate_kmh = disp * fps * 3.6

            output[tid] = ts
            matched_tids.add(tid)
            matched_dets.add(d_idx)

        remaining = [d for i, d in enumerate(detections) if i not in matched_dets]
        return matched_tids, remaining

    def set_next_id(self, next_id: int) -> None:
        self._next_id = next_id
