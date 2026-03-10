"""Main Inference Worker process.

Pull-based NATS JetStream consumer that feeds frames through the 5-stage
inference pipeline.  This is the entry point for the service.
"""

from __future__ import annotations

import asyncio
import io
import json
import signal
from datetime import datetime, timezone

import nats
import numpy as np

from observability import get_logger, setup_logging
from observability.logging import camera_id_var
from observability.metrics import (
    INFERENCE_CROSSINGS,
    INFERENCE_DETECTIONS,
    INFERENCE_FRAME_DURATION,
    NATS_MESSAGES_ACKED,
    NATS_MESSAGES_NACKED,
    NATS_MESSAGES_RECEIVED,
    register_service_info,
)
from observability.tracing import get_tracer, setup_tracing

from inference_worker.event_publisher import EventPublisher
from inference_worker.models import FrameMetadata
from inference_worker.pipeline import InferencePipeline
from inference_worker.redis_state import RedisLiveState
from inference_worker.settings import Settings, get_settings
from shared_contracts.nats_dlq import DLQHandler
from shared_contracts.nats_streams import (
    CONSUMER_INFERENCE_WORKER,
    STREAM_DEFS_BY_NAME,
    STREAM_FRAMES,
    ensure_streams,
)

logger = get_logger(__name__)
tracer = get_tracer(__name__)

CONSUMER_NAME = CONSUMER_INFERENCE_WORKER


def _decode_frame(data: bytes, content_type: str = "image/jpeg") -> np.ndarray:
    """Decode raw bytes into an (H, W, 3) uint8 numpy array."""
    try:
        import cv2

        buf = np.frombuffer(data, dtype=np.uint8)
        frame = cv2.imdecode(buf, cv2.IMREAD_COLOR)
        if frame is not None:
            return frame
    except ImportError:
        pass

    from PIL import Image

    img = Image.open(io.BytesIO(data)).convert("RGB")
    return np.array(img)


def _parse_metadata(msg) -> FrameMetadata:
    """Extract FrameMetadata from NATS message headers and subject."""
    headers = msg.headers or {}
    camera_id = headers.get("Camera-Id", "")

    if not camera_id and msg.subject:
        parts = msg.subject.split(".")
        if len(parts) >= 2:
            camera_id = parts[-1]

    meta_json = headers.get("X-Metadata", "{}")
    try:
        meta_dict = json.loads(meta_json)
    except (json.JSONDecodeError, TypeError):
        meta_dict = {}

    ts_str = meta_dict.get("timestamp_utc")
    if ts_str:
        try:
            timestamp = datetime.fromisoformat(ts_str)
        except ValueError:
            timestamp = datetime.now(timezone.utc)
    else:
        timestamp = datetime.now(timezone.utc)

    return FrameMetadata(
        camera_id=camera_id,
        frame_index=meta_dict.get("frame_index", 0),
        timestamp_utc=timestamp,
        content_type=headers.get("Content-Type", "image/jpeg"),
        offline_upload=headers.get("X-Offline-Upload", "false").lower() == "true",
        org_id=meta_dict.get("org_id", ""),
        site_id=meta_dict.get("site_id", ""),
    )


class InferenceWorker:
    """NATS consumer that runs the inference pipeline on incoming frames."""

    def __init__(self, settings: Settings | None = None) -> None:
        self._settings = settings or get_settings()
        self._publisher = EventPublisher()
        self._redis_state = RedisLiveState()
        self._pipeline: InferencePipeline | None = None
        self._nc = None
        self._js = None
        self._subscription = None
        self._running = False

    async def start(self) -> None:
        """Connect to NATS/Redis and start consuming frames."""
        settings = self._settings

        await self._publisher.connect(settings)
        await self._redis_state.connect(settings)

        self._pipeline = InferencePipeline(
            settings=settings,
            publisher=self._publisher,
            redis_state=self._redis_state,
        )

        async def error_cb(e: Exception) -> None:
            logger.error("NATS error: %s", e)

        async def disconnected_cb() -> None:
            logger.warning("NATS disconnected")

        async def reconnected_cb() -> None:
            logger.info("NATS reconnected")

        self._nc = await nats.connect(
            settings.nats_url,
            connect_timeout=settings.nats_connect_timeout,
            max_reconnect_attempts=settings.nats_max_reconnect_attempts,
            reconnect_time_wait=settings.nats_reconnect_time_wait,
            error_cb=error_cb,
            disconnected_cb=disconnected_cb,
            reconnected_cb=reconnected_cb,
        )
        self._js = self._nc.jetstream()

        await ensure_streams(self._js, streams=[STREAM_DEFS_BY_NAME[STREAM_FRAMES]])

        self._subscription = await self._js.pull_subscribe(
            "frames.>",
            durable=CONSUMER_NAME,
            stream=STREAM_FRAMES,
        )

        self._running = True
        logger.info("Inference Worker started, consuming from %s", STREAM_FRAMES)

        await self._consume_loop()

    async def _consume_loop(self) -> None:
        """Main consumption loop: pull frames, process, ack/nak/DLQ."""
        batch_size = self._settings.fetch_batch_size
        timeout_s = self._settings.fetch_timeout_ms / 1000.0
        dlq = DLQHandler(self._js, max_deliver=3)

        while self._running:
            try:
                msgs = await self._subscription.fetch(
                    batch=batch_size,
                    timeout=timeout_s,
                )
            except nats.errors.TimeoutError:
                continue
            except Exception:
                logger.exception("Error fetching messages from NATS")
                await asyncio.sleep(1)
                continue

            for msg in msgs:
                await dlq.process(msg, callback=self._process_message)

    async def _process_message(self, msg) -> None:
        """Decode a single NATS message and run it through the pipeline."""
        NATS_MESSAGES_RECEIVED.labels(
            stream=STREAM_FRAMES, consumer=CONSUMER_NAME, service="inference-worker"
        ).inc()

        metadata = _parse_metadata(msg)

        if not metadata.camera_id:
            logger.warning("frame_skipped_no_camera_id")
            NATS_MESSAGES_NACKED.labels(
                stream=STREAM_FRAMES, consumer=CONSUMER_NAME, service="inference-worker"
            ).inc()
            return

        camera_id_var.set(metadata.camera_id)

        with tracer.start_as_current_span(
            "inference.process_frame",
            attributes={
                "camera_id": metadata.camera_id,
                "frame_index": metadata.frame_index,
            },
        ):
            with INFERENCE_FRAME_DURATION.labels(camera_id=metadata.camera_id).time():
                frame = _decode_frame(msg.data, metadata.content_type)

                events = await self._pipeline.process_frame(
                    frame=frame,
                    frame_data=msg.data,
                    metadata=metadata,
                )

            INFERENCE_DETECTIONS.labels(camera_id=metadata.camera_id).inc()

            if events:
                for ev in events:
                    INFERENCE_CROSSINGS.labels(
                        camera_id=metadata.camera_id,
                        direction=getattr(ev, "direction", "unknown"),
                        vehicle_class=getattr(ev, "vehicle_class", "unknown"),
                    ).inc()
                logger.info(
                    "crossing_events_emitted",
                    camera_id=metadata.camera_id,
                    frame_index=metadata.frame_index,
                    count=len(events),
                )

            NATS_MESSAGES_ACKED.labels(
                stream=STREAM_FRAMES, consumer=CONSUMER_NAME, service="inference-worker"
            ).inc()

    async def stop(self) -> None:
        """Gracefully shut down the worker."""
        self._running = False
        logger.info("Shutting down Inference Worker...")

        if self._subscription:
            try:
                await self._subscription.unsubscribe()
            except Exception:
                pass

        if self._nc and not self._nc.is_closed:
            await self._nc.close()

        await self._redis_state.close()
        await self._publisher.close()
        logger.info("Inference Worker stopped")


async def run_worker() -> None:
    """Entry point: create and run the inference worker until interrupted."""
    settings = get_settings()

    log_level = "DEBUG" if settings.debug else settings.log_level
    setup_logging(
        service_name="inference-worker",
        log_level=log_level,
        json_output=settings.json_logs,
    )
    register_service_info("inference-worker", model_version=settings.model_version)
    setup_tracing(
        service_name="inference-worker",
        otlp_endpoint=settings.otlp_endpoint,
        enabled=settings.tracing_enabled,
    )

    worker = InferenceWorker(settings)

    loop = asyncio.get_running_loop()
    stop_event = asyncio.Event()

    def _signal_handler() -> None:
        logger.info("Received shutdown signal")
        stop_event.set()

    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, _signal_handler)

    start_task = asyncio.create_task(worker.start())

    await stop_event.wait()
    await worker.stop()

    start_task.cancel()
    try:
        await start_task
    except asyncio.CancelledError:
        pass


def main() -> None:
    """CLI entry point."""
    asyncio.run(run_worker())


if __name__ == "__main__":
    main()
