"""NATS JetStream client wrapper for frame publishing and health events."""

from __future__ import annotations

import json
import logging
from typing import TYPE_CHECKING

import nats

from shared_contracts.nats_streams import (
    STREAM_DEFS_BY_NAME,
    STREAM_FRAMES,
    STREAM_HEALTH,
    SUBJECT_FRAMES,
    SUBJECT_HEALTH,
    ensure_streams,
)

if TYPE_CHECKING:
    from nats.aio.client import Client as NATSClient
    from nats.js import JetStreamContext

    from ingest_service.settings import Settings

logger = logging.getLogger(__name__)


class NatsFramePublisher:
    """Publishes camera frames and health events to NATS JetStream."""

    def __init__(self) -> None:
        self._nc: NATSClient | None = None
        self._js: JetStreamContext | None = None

    async def connect(self, settings: Settings) -> None:
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

        await self._ensure_streams()
        logger.info("Connected to NATS at %s", settings.nats_url)

    async def _ensure_streams(self) -> None:
        """Create FRAMES and HEALTH streams if they don't exist. Idempotent."""
        assert self._js is not None

        needed = [STREAM_DEFS_BY_NAME[STREAM_FRAMES], STREAM_DEFS_BY_NAME[STREAM_HEALTH]]
        await ensure_streams(self._js, streams=needed)

    async def publish_frame(
        self,
        camera_id: str,
        frame_data: bytes,
        metadata: dict,
    ) -> int:
        """Publish a frame to the JetStream subject for this camera.

        Returns the stream sequence number assigned by JetStream.
        """
        if self._js is None:
            raise RuntimeError("NATS client not connected")

        headers = {
            "Camera-Id": camera_id,
            "Content-Type": metadata.get("content_type", "image/jpeg"),
            "X-Metadata": json.dumps(metadata),
        }

        if metadata.get("offline_upload"):
            headers["X-Offline-Upload"] = "true"
            if metadata.get("session_id"):
                headers["X-Session-Id"] = metadata["session_id"]

        subject = f"{SUBJECT_FRAMES}.{camera_id}"
        ack = await self._js.publish(subject, frame_data, headers=headers)
        return ack.seq

    async def publish_health_event(
        self,
        camera_id: str,
        event_data: dict,
    ) -> int:
        """Publish a camera health event to the HEALTH stream."""
        if self._js is None:
            raise RuntimeError("NATS client not connected")

        headers = {
            "Camera-Id": camera_id,
            "Content-Type": "application/json",
        }

        subject = f"{SUBJECT_HEALTH}.{camera_id}"
        payload = json.dumps(event_data).encode()
        ack = await self._js.publish(subject, payload, headers=headers)
        return ack.seq

    async def get_queue_depth(self, camera_id: str | None = None) -> int:
        """Return the number of pending messages in the FRAMES stream.

        If camera_id is provided, returns an estimate based on the full
        stream message count (NATS doesn't expose per-subject counts
        without a consumer). For backpressure purposes the total stream
        depth is the relevant metric.
        """
        if self._js is None:
            raise RuntimeError("NATS client not connected")

        try:
            stream_info = await self._js.stream_info(STREAM_FRAMES)
            return stream_info.state.messages
        except Exception:
            logger.warning(
                "Could not fetch queue depth for camera %s, defaulting to 0",
                camera_id,
            )
            return 0

    @property
    def is_connected(self) -> bool:
        return self._nc is not None and not self._nc.is_closed

    async def close(self) -> None:
        if self._nc:
            await self._nc.close()
            logger.info("NATS connection closed")
