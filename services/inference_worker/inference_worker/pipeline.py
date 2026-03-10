"""Five-stage inference pipeline orchestrator.

Wires together the five stages (detect -> track -> classify -> smooth ->
line-cross) and handles event emission, live-state push, and hard-example
collection for each processed frame.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import TYPE_CHECKING

import numpy as np

from inference_worker.hard_examples import HardExampleCollector
from inference_worker.models import (
    CameraInferenceState,
    CrossingResult,
    FrameMetadata,
    TrackState,
)
from inference_worker.stages.classifier import VehicleClassifier
from inference_worker.stages.detector import VehicleDetector
from inference_worker.stages.line_crossing import LineCrossingDetector
from inference_worker.stages.smoother import TemporalSmoother
from inference_worker.stages.tracker import ByteTracker
from shared_contracts.enums import VehicleClass12
from shared_contracts.events import TrackEvent, VehicleCrossingEvent
from shared_contracts.geometry import BoundingBox, CountingLine, Point2D

if TYPE_CHECKING:
    from inference_worker.event_publisher import EventPublisher
    from inference_worker.redis_state import RedisLiveState
    from inference_worker.settings import Settings

logger = logging.getLogger(__name__)


class InferencePipeline:
    """Orchestrates the 5-stage inference pipeline for all camera streams.

    Maintains per-camera state and delegates to the individual stage components.
    """

    def __init__(
        self,
        settings: Settings,
        publisher: EventPublisher,
        redis_state: RedisLiveState,
        detector: VehicleDetector | None = None,
        classifier: VehicleClassifier | None = None,
    ) -> None:
        self._settings = settings
        self._publisher = publisher
        self._redis_state = redis_state

        self._detector = detector or VehicleDetector(settings.detector)
        self._classifier = classifier or VehicleClassifier(settings.classifier)
        self._smoother = TemporalSmoother(settings.smoother)
        self._crossing_detector = LineCrossingDetector(settings.crossing)
        self._hard_example_collector = HardExampleCollector(settings.hard_example)

        self._camera_states: dict[str, CameraInferenceState] = {}
        self._trackers: dict[str, ByteTracker] = {}

    def _get_or_create_camera_state(
        self,
        camera_id: str,
        org_id: str = "",
        site_id: str = "",
    ) -> CameraInferenceState:
        if camera_id not in self._camera_states:
            self._camera_states[camera_id] = CameraInferenceState(
                camera_id=camera_id,
                org_id=org_id,
                site_id=site_id,
                model_version=self._settings.model_version,
            )
            self._trackers[camera_id] = ByteTracker(
                self._settings.tracker,
                camera_id,
            )
        state = self._camera_states[camera_id]
        if org_id:
            state.org_id = org_id
        if site_id:
            state.site_id = site_id
        return state

    def update_counting_lines(
        self,
        camera_id: str,
        lines: list[CountingLine],
    ) -> None:
        """Hot-reload counting lines for a camera."""
        state = self._get_or_create_camera_state(camera_id)
        state.counting_lines = lines
        logger.info("Updated %d counting lines for camera %s", len(lines), camera_id)

    async def process_frame(
        self,
        frame: np.ndarray,
        frame_data: bytes,
        metadata: FrameMetadata,
    ) -> list[VehicleCrossingEvent]:
        """Run the full 5-stage pipeline on a single frame.

        Returns a list of VehicleCrossingEvent objects emitted during processing.
        """
        camera_id = metadata.camera_id
        frame_index = metadata.frame_index
        timestamp = metadata.timestamp_utc

        cam_state = self._get_or_create_camera_state(
            camera_id, metadata.org_id, metadata.site_id
        )
        cam_state.last_frame_index = frame_index

        # --- Stage 1: Detection ---
        detections = self._detector.detect_frame(frame, frame_index)
        logger.debug(
            "Stage 1: %d detections for camera %s frame %d",
            len(detections),
            camera_id,
            frame_index,
        )

        # --- Stage 2: Tracking ---
        tracker = self._trackers[camera_id]
        updated_tracks = tracker.update(
            detections,
            cam_state.track_states,
            frame_index,
            fps=self._settings.camera_fps,
        )

        ended_track_ids = set(cam_state.track_states.keys()) - set(updated_tracks.keys())
        new_track_ids = set(updated_tracks.keys()) - set(cam_state.track_states.keys())
        newly_confirmed = {
            tid
            for tid, ts in updated_tracks.items()
            if ts.is_confirmed and tid in new_track_ids
        }

        cam_state.track_states = updated_tracks
        cam_state.next_track_id = tracker._next_id

        for tid in newly_confirmed:
            ts = updated_tracks[tid]
            await self._publisher.publish_track_event(
                TrackEvent(
                    event_type="TrackStarted",
                    timestamp_utc=timestamp,
                    camera_id=camera_id,
                    track_id=tid,
                    bbox=ts.bbox,
                    centroid=ts.centroid,
                    frame_index=frame_index,
                )
            )

        for tid in ended_track_ids:
            old_ts = cam_state.track_states.get(tid)
            if old_ts is None:
                continue
            await self._publisher.publish_track_event(
                TrackEvent(
                    event_type="TrackEnded",
                    timestamp_utc=timestamp,
                    camera_id=camera_id,
                    track_id=tid,
                    class12=old_ts.smoothed_class,
                    confidence=old_ts.smoothed_confidence,
                    bbox=old_ts.bbox,
                    centroid=old_ts.centroid,
                    frame_index=frame_index,
                )
            )

        # --- Stage 3: Classification ---
        confirmed_tracks = {
            tid: ts for tid, ts in updated_tracks.items() if ts.is_confirmed
        }
        bboxes_to_classify = [ts.bbox for ts in confirmed_tracks.values()]
        track_ids_ordered = list(confirmed_tracks.keys())

        predictions = self._classifier.classify_crops(frame, bboxes_to_classify)

        for tid, pred in zip(track_ids_ordered, predictions):
            ts = confirmed_tracks[tid]
            ts.class_history.append(pred)
            max_history = self._settings.smoother.window * 3
            if len(ts.class_history) > max_history:
                ts.class_history = ts.class_history[-max_history:]

        # --- Stage 4: Temporal Smoothing ---
        crossing_events: list[VehicleCrossingEvent] = []

        for tid, ts in confirmed_tracks.items():
            if not ts.class_history:
                continue

            previous_class = ts.smoothed_class
            smoothed = self._smoother.smooth(ts.class_history, ts.age)

            if smoothed is None:
                continue

            ts.smoothed_class = smoothed.class12
            ts.smoothed_confidence = smoothed.confidence

            # --- Hard-example collection ---
            he = self._hard_example_collector.check_and_collect(
                track=ts,
                smoothed=smoothed,
                previous_class=previous_class,
                frame_data=frame_data,
                frame=frame,
                camera_id=camera_id,
                frame_index=frame_index,
                timestamp_utc=timestamp,
                model_version=cam_state.model_version,
            )
            if he is not None:
                await self._publisher.upload_hard_example(
                    he, self._settings.hard_example.storage_bucket
                )

            # --- Stage 5: Line Crossing ---
            crossings = self._crossing_detector.check_crossings(
                ts, cam_state.counting_lines, frame_index
            )

            for crossing in crossings:
                seq = ts.crossing_sequences.get(crossing.line_id, 1)
                event = VehicleCrossingEvent(
                    timestamp_utc=timestamp,
                    camera_id=camera_id,
                    line_id=crossing.line_id,
                    track_id=ts.track_id,
                    crossing_seq=seq,
                    class12=smoothed.class12,
                    confidence=smoothed.confidence,
                    direction=crossing.direction,
                    model_version=cam_state.model_version,
                    frame_index=frame_index,
                    speed_estimate_kmh=ts.speed_estimate_kmh,
                    bbox=ts.bbox,
                    org_id=cam_state.org_id,
                    site_id=cam_state.site_id,
                )

                await self._publisher.publish_crossing(event)
                await self._redis_state.increment_crossing_count(
                    camera_id,
                    crossing.line_id,
                    crossing.direction,
                    smoothed.class12.value,
                )
                crossing_events.append(event)

            await self._publisher.publish_track_event(
                TrackEvent(
                    event_type="TrackUpdated",
                    timestamp_utc=timestamp,
                    camera_id=camera_id,
                    track_id=tid,
                    class12=smoothed.class12,
                    confidence=smoothed.confidence,
                    bbox=ts.bbox,
                    centroid=ts.centroid,
                    frame_index=frame_index,
                )
            )

        # --- Live state push ---
        await self._redis_state.push_tracks(camera_id, updated_tracks, frame_index)

        logger.debug(
            "Pipeline complete: camera=%s frame=%d tracks=%d crossings=%d",
            camera_id,
            frame_index,
            len(confirmed_tracks),
            len(crossing_events),
        )

        return crossing_events

    def get_camera_state(self, camera_id: str) -> CameraInferenceState | None:
        return self._camera_states.get(camera_id)

    @property
    def active_cameras(self) -> list[str]:
        return list(self._camera_states.keys())
