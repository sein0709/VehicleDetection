"""NATS JetStream event publisher for the inference worker.

Publishes VehicleCrossingEvent and TrackEvent messages to the event bus,
and uploads hard examples to S3-compatible object storage.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime
from typing import TYPE_CHECKING

import nats

from inference_worker.models import HardExample
from shared_contracts.events import TrackEvent, VehicleCrossingEvent
from shared_contracts.nats_streams import (
    STREAM_CROSSINGS,
    STREAM_DEFS_BY_NAME,
    STREAM_DLQ,
    STREAM_TRACKS,
    SUBJECT_CROSSINGS,
    SUBJECT_TRACKS,
    ensure_streams,
)

if TYPE_CHECKING:
    from nats.aio.client import Client as NATSClient
    from nats.js import JetStreamContext

    from inference_worker.settings import Settings

logger = logging.getLogger(__name__)


class EventPublisher:
    """Publishes pipeline events to NATS JetStream and hard examples to S3."""

    def __init__(self) -> None:
        self._nc: NATSClient | None = None
        self._js: JetStreamContext | None = None
        self._s3_client = None

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
        self._init_s3(settings)
        logger.info("EventPublisher connected to NATS at %s", settings.nats_url)

    async def _ensure_streams(self) -> None:
        """Create output streams if they don't exist."""
        assert self._js is not None

        needed = [
            STREAM_DEFS_BY_NAME[STREAM_CROSSINGS],
            STREAM_DEFS_BY_NAME[STREAM_TRACKS],
            STREAM_DEFS_BY_NAME[STREAM_DLQ],
        ]
        await ensure_streams(self._js, streams=needed)

    def _init_s3(self, settings: Settings) -> None:
        try:
            import boto3
            from botocore.config import Config as BotoConfig

            self._s3_client = boto3.client(
                "s3",
                endpoint_url=settings.s3_endpoint,
                aws_access_key_id=settings.s3_access_key,
                aws_secret_access_key=settings.s3_secret_key,
                region_name=settings.s3_region,
                config=BotoConfig(signature_version="s3v4"),
            )
            logger.info("S3 client initialised (endpoint=%s)", settings.s3_endpoint)
        except ImportError:
            logger.warning("boto3 not available; hard-example upload disabled")
            self._s3_client = None

    async def publish_crossing(
        self,
        event: VehicleCrossingEvent,
    ) -> None:
        """Publish a VehicleCrossingEvent to the CROSSINGS stream."""
        if self._js is None:
            raise RuntimeError("EventPublisher not connected")

        subject = f"{SUBJECT_CROSSINGS}.{event.camera_id}"
        payload = event.model_dump_json().encode()
        headers = {
            "Camera-Id": event.camera_id,
            "Content-Type": "application/json",
            "Dedup-Key": event.dedup_key,
        }

        ack = await self._js.publish(subject, payload, headers=headers)
        logger.debug(
            "Published crossing event %s (seq=%d, dedup=%s)",
            event.event_id,
            ack.seq,
            event.dedup_key,
        )

    async def publish_track_event(
        self,
        event: TrackEvent,
    ) -> None:
        """Publish a TrackEvent to the TRACKS stream."""
        if self._js is None:
            raise RuntimeError("EventPublisher not connected")

        subject = f"{SUBJECT_TRACKS}.{event.camera_id}"
        payload = event.model_dump_json().encode()
        headers = {
            "Camera-Id": event.camera_id,
            "Content-Type": "application/json",
        }

        await self._js.publish(subject, payload, headers=headers)

    async def upload_hard_example(
        self,
        example: HardExample,
        bucket: str,
    ) -> None:
        """Upload a hard example (frame + crop) to S3-compatible storage."""
        if self._s3_client is None:
            logger.debug("S3 not available; skipping hard-example upload")
            return

        date_str = example.timestamp_utc.strftime("%Y-%m-%d")
        prefix = f"hard_examples/{example.camera_id}/{date_str}"

        frame_key = f"{prefix}/{example.frame_index}_{example.trigger_reason}_frame.jpg"
        try:
            self._s3_client.put_object(
                Bucket=bucket,
                Key=frame_key,
                Body=example.frame_data,
                ContentType="image/jpeg",
            )
        except Exception:
            logger.exception("Failed to upload hard-example frame to S3")
            return

        if example.crop_data:
            crop_key = f"{prefix}/{example.frame_index}_{example.trigger_reason}_crop.jpg"
            try:
                self._s3_client.put_object(
                    Bucket=bucket,
                    Key=crop_key,
                    Body=example.crop_data,
                    ContentType="image/jpeg",
                )
            except Exception:
                logger.exception("Failed to upload hard-example crop to S3")

        meta_key = f"{prefix}/{example.frame_index}_{example.trigger_reason}_meta.json"
        meta = {
            "camera_id": example.camera_id,
            "track_id": example.track_id,
            "frame_index": example.frame_index,
            "timestamp_utc": example.timestamp_utc.isoformat(),
            "predicted_class12": example.predicted_class12.value,
            "confidence": example.confidence,
            "probabilities": example.probabilities,
            "trigger_reason": example.trigger_reason,
            "model_version": example.model_version,
            "frame_path": frame_key,
            "crop_path": crop_key if example.crop_data else None,
        }
        try:
            self._s3_client.put_object(
                Bucket=bucket,
                Key=meta_key,
                Body=json.dumps(meta).encode(),
                ContentType="application/json",
            )
        except Exception:
            logger.exception("Failed to upload hard-example metadata to S3")

        logger.info(
            "Uploaded hard example: camera=%s frame=%d trigger=%s",
            example.camera_id,
            example.frame_index,
            example.trigger_reason,
        )

    @property
    def is_connected(self) -> bool:
        return self._nc is not None and not self._nc.is_closed

    async def close(self) -> None:
        if self._nc:
            await self._nc.close()
            logger.info("EventPublisher NATS connection closed")
