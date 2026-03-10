"""NATS JetStream consumer for vehicle crossing events and recompute commands.

Subscribes to ``events.crossings.>`` and ``commands.recompute``, feeding
crossing events to the :class:`BucketAccumulator` and recompute commands
to the database layer.  Failed messages are routed to the DLQ via
:class:`~shared_contracts.nats_dlq.DLQHandler`.
"""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime
from typing import TYPE_CHECKING, Any

import nats

from shared_contracts.events import VehicleCrossingEvent
from shared_contracts.nats_dlq import DLQHandler
from shared_contracts.nats_streams import (
    CONSUMER_AGGREGATOR_CROSSINGS,
    CONSUMER_AGGREGATOR_RECOMPUTE,
    CONSUMER_DEFS_BY_DURABLE,
    STREAM_COMMANDS,
    STREAM_CROSSINGS,
    STREAM_DEFS_BY_NAME,
    SUBJECT_CROSSINGS,
    SUBJECT_RECOMPUTE,
    ensure_consumers,
    ensure_streams,
)

if TYPE_CHECKING:
    from nats.aio.client import Client as NATSClient
    from nats.js import JetStreamContext

    from aggregator.accumulator import BucketAccumulator
    from aggregator.db import AggregatorDB
    from aggregator.redis_publisher import RedisKPIPublisher
    from aggregator.settings import Settings

logger = logging.getLogger(__name__)


class NatsCrossingConsumer:
    """Subscribes to crossing events and feeds them to the accumulator.

    Uses :class:`DLQHandler` so messages that exceed ``max_deliver`` are
    routed to the dead-letter queue instead of blocking the consumer.
    """

    def __init__(self) -> None:
        self._nc: NATSClient | None = None
        self._js: JetStreamContext | None = None
        self._running = False
        self._tasks: list[asyncio.Task] = []
        self._processed_count = 0
        self._recompute_count = 0

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

        await self._ensure_infrastructure()
        logger.info("Connected to NATS at %s", settings.nats_url)

    async def _ensure_infrastructure(self) -> None:
        """Create required streams and consumers if they don't exist."""
        assert self._js is not None

        await ensure_streams(
            self._js,
            streams=[
                STREAM_DEFS_BY_NAME[STREAM_CROSSINGS],
                STREAM_DEFS_BY_NAME[STREAM_COMMANDS],
            ],
        )
        await ensure_consumers(
            self._js,
            consumers=[
                CONSUMER_DEFS_BY_DURABLE[CONSUMER_AGGREGATOR_CROSSINGS],
                CONSUMER_DEFS_BY_DURABLE[CONSUMER_AGGREGATOR_RECOMPUTE],
            ],
        )

    async def start(
        self,
        accumulator: BucketAccumulator,
        db: AggregatorDB,
        redis_pub: RedisKPIPublisher,
    ) -> None:
        """Start pull-consumer loops for crossings and recompute commands."""
        assert self._js is not None
        self._running = True

        self._tasks.append(
            asyncio.create_task(
                self._consume_crossings(accumulator),
                name="aggregator-crossings",
            )
        )
        self._tasks.append(
            asyncio.create_task(
                self._consume_recompute(db, redis_pub),
                name="aggregator-recompute",
            )
        )

        logger.info(
            "Subscribed to %s.> (durable=%s) and %s (durable=%s)",
            SUBJECT_CROSSINGS,
            CONSUMER_AGGREGATOR_CROSSINGS,
            SUBJECT_RECOMPUTE,
            CONSUMER_AGGREGATOR_RECOMPUTE,
        )

    async def stop(self) -> None:
        """Cancel consumer loops and close the connection."""
        self._running = False
        for task in self._tasks:
            task.cancel()
        await asyncio.gather(*self._tasks, return_exceptions=True)
        self._tasks.clear()

        if self._nc and not self._nc.is_closed:
            await self._nc.close()
            logger.info("NATS connection closed")

    # ------------------------------------------------------------------
    # Consumer loops
    # ------------------------------------------------------------------

    async def _consume_crossings(self, accumulator: BucketAccumulator) -> None:
        assert self._js is not None
        crossings_def = CONSUMER_DEFS_BY_DURABLE[CONSUMER_AGGREGATOR_CROSSINGS]
        dlq = DLQHandler(self._js, max_deliver=crossings_def.max_deliver)

        sub = await self._js.pull_subscribe(
            f"{SUBJECT_CROSSINGS}.>",
            durable=CONSUMER_AGGREGATOR_CROSSINGS,
            stream=STREAM_CROSSINGS,
        )

        while self._running:
            try:
                messages = await sub.fetch(batch=50, timeout=5)
                for msg in messages:
                    await dlq.process(msg, lambda m: self._handle_crossing(m, accumulator))
            except nats.errors.TimeoutError:
                continue
            except asyncio.CancelledError:
                break
            except Exception:
                logger.exception("Error in crossings consumer loop")
                await asyncio.sleep(1)

    async def _consume_recompute(
        self,
        db: AggregatorDB,
        redis_pub: RedisKPIPublisher,
    ) -> None:
        assert self._js is not None
        recompute_def = CONSUMER_DEFS_BY_DURABLE[CONSUMER_AGGREGATOR_RECOMPUTE]
        dlq = DLQHandler(self._js, max_deliver=recompute_def.max_deliver)

        sub = await self._js.pull_subscribe(
            SUBJECT_RECOMPUTE,
            durable=CONSUMER_AGGREGATOR_RECOMPUTE,
            stream=STREAM_COMMANDS,
        )

        while self._running:
            try:
                messages = await sub.fetch(batch=1, timeout=5)
                for msg in messages:
                    await dlq.process(msg, lambda m: self._handle_recompute(m, db, redis_pub))
            except nats.errors.TimeoutError:
                continue
            except asyncio.CancelledError:
                break
            except Exception:
                logger.exception("Error in recompute consumer loop")
                await asyncio.sleep(1)

    # ------------------------------------------------------------------
    # Message handlers
    # ------------------------------------------------------------------

    async def _handle_crossing(self, msg: Any, accumulator: BucketAccumulator) -> None:
        payload = json.loads(msg.data)
        event = VehicleCrossingEvent.model_validate(payload)
        result = accumulator.add_event(event)
        if result.status == "accepted":
            self._processed_count += 1
        else:
            logger.warning(
                "Event rejected (%s): camera=%s ts=%s",
                result.status,
                event.camera_id,
                event.timestamp_utc.isoformat(),
            )

    async def _handle_recompute(
        self,
        msg: Any,
        db: AggregatorDB,
        redis_pub: RedisKPIPublisher,
    ) -> None:
        """Handle a recompute command: delete + rebuild aggregates from vehicle_crossings,
        then push updated KPIs to Redis.
        """
        payload = json.loads(msg.data)
        camera_id = payload["camera_id"]
        start = datetime.fromisoformat(payload["start"])
        end = datetime.fromisoformat(payload["end"])

        inserted = await db.recompute(camera_id, start, end)
        self._recompute_count += 1

        logger.info(
            "Recompute completed for camera=%s [%s, %s): %d rows inserted",
            camera_id,
            start,
            end,
            inserted,
        )

        if inserted > 0:
            rows = await db.fetch_bucket_totals(camera_id, start)
            if rows:
                await redis_pub.publish_flush_summary(rows)

    @property
    def is_connected(self) -> bool:
        return self._nc is not None and not self._nc.is_closed

    @property
    def stats(self) -> dict[str, int]:
        return {
            "processed": self._processed_count,
            "recomputes": self._recompute_count,
        }
