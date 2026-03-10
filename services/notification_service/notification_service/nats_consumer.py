"""NATS JetStream consumer for crossing and health events.

Subscribes to events.crossings.> and events.health.>, evaluates active
alert rules against each event, checks cooldown in Redis, creates
alert_event records, publishes AlertEvent to NATS, and dispatches
notifications through configured channels.
"""

from __future__ import annotations

import asyncio
import json
import logging
import time
from typing import Any
from uuid import UUID

import nats
import redis.asyncio as aioredis
from nats.js import JetStreamContext

from notification_service.db import NotificationDB
from notification_service.delivery import deliver_alert
from notification_service.rule_engine import evaluate_rule
from notification_service.settings import Settings
from shared_contracts.enums import AlertSeverity, AlertStatus
from shared_contracts.events import (
    AlertEvent,
    CameraHealthEvent,
    VehicleCrossingEvent,
)
from shared_contracts.nats_dlq import DLQHandler
from shared_contracts.nats_streams import (
    CONSUMER_NOTIFICATION_CROSSINGS,
    CONSUMER_NOTIFICATION_HEALTH,
    STREAM_ALERTS,
    STREAM_CROSSINGS,
    STREAM_HEALTH,
    SUBJECT_ALERTS,
    ensure_consumers,
    ensure_streams,
)

logger = logging.getLogger(__name__)

COOLDOWN_PREFIX = "alert:cooldown:"
RULES_CACHE_KEY = "notification:rules_cache"
RULES_CACHE_TTL = 60

METRIC_ALERTS_FIRED = "notification_alerts_fired_total"
METRIC_ALERTS_SUPPRESSED = "notification_alerts_suppressed_total"
METRIC_DELIVERY_DURATION = "notification_delivery_duration_seconds"
METRIC_EVENTS_PROCESSED = "notification_events_processed_total"


class EventConsumer:
    """Consumes NATS events and evaluates alert rules."""

    def __init__(self, settings: Settings, db: NotificationDB) -> None:
        self._settings = settings
        self._db = db
        self._nc: nats.NATS | None = None
        self._js: JetStreamContext | None = None
        self._redis: aioredis.Redis | None = None
        self._running = False
        self._tasks: list[asyncio.Task] = []
        self.stats = _ConsumerStats()

    @property
    def is_running(self) -> bool:
        return self._running

    async def start(self) -> None:
        self._nc = await nats.connect(self._settings.nats_url)
        self._js = self._nc.jetstream()
        self._redis = aioredis.from_url(
            self._settings.redis_url, decode_responses=True
        )

        from shared_contracts.nats_streams import CONSUMER_DEFS, STREAM_DEFS

        await ensure_streams(
            self._js,
            streams=[
                s
                for s in STREAM_DEFS
                if s.name in (STREAM_CROSSINGS, STREAM_HEALTH, STREAM_ALERTS)
            ],
        )
        await ensure_consumers(
            self._js,
            consumers=[
                c
                for c in CONSUMER_DEFS
                if c.durable_name
                in (CONSUMER_NOTIFICATION_CROSSINGS, CONSUMER_NOTIFICATION_HEALTH)
            ],
        )

        self._running = True

        self._tasks.append(
            asyncio.create_task(
                self._consume_crossings(), name="consume-crossings"
            )
        )
        self._tasks.append(
            asyncio.create_task(
                self._consume_health(), name="consume-health"
            )
        )

        logger.info("NATS event consumer started")

    async def stop(self) -> None:
        self._running = False
        for task in self._tasks:
            task.cancel()
        await asyncio.gather(*self._tasks, return_exceptions=True)
        self._tasks.clear()

        if self._redis:
            await self._redis.aclose()
        if self._nc and not self._nc.is_closed:
            await self._nc.close()

        logger.info("NATS event consumer stopped")

    async def invalidate_rules_cache(self) -> None:
        """Delete all cached rule entries so the next evaluation reloads from DB."""
        if not self._redis:
            return
        try:
            cursor: int | bytes = 0
            while True:
                cursor, keys = await self._redis.scan(
                    cursor=cursor, match=f"{RULES_CACHE_KEY}:*", count=100
                )
                if keys:
                    await self._redis.delete(*keys)
                if cursor == 0:
                    break
        except Exception:
            logger.exception("Failed to invalidate rules cache")

    async def _consume_crossings(self) -> None:
        assert self._js is not None
        dlq = DLQHandler(self._js, max_deliver=3)
        sub = await self._js.pull_subscribe(
            "events.crossings.>",
            durable=CONSUMER_NOTIFICATION_CROSSINGS,
            stream=STREAM_CROSSINGS,
        )

        while self._running:
            try:
                messages = await sub.fetch(batch=10, timeout=5)
                for msg in messages:
                    await dlq.process(msg, self._handle_crossing)
            except nats.errors.TimeoutError:
                continue
            except asyncio.CancelledError:
                break
            except Exception:
                logger.exception("Error in crossings consumer loop")
                await asyncio.sleep(1)

    async def _consume_health(self) -> None:
        assert self._js is not None
        dlq = DLQHandler(self._js, max_deliver=3)
        sub = await self._js.pull_subscribe(
            "events.health.>",
            durable=CONSUMER_NOTIFICATION_HEALTH,
            stream=STREAM_HEALTH,
        )

        while self._running:
            try:
                messages = await sub.fetch(batch=10, timeout=5)
                for msg in messages:
                    await dlq.process(msg, self._handle_health)
            except nats.errors.TimeoutError:
                continue
            except asyncio.CancelledError:
                break
            except Exception:
                logger.exception("Error in health consumer loop")
                await asyncio.sleep(1)

    async def _handle_crossing(self, msg: Any) -> None:
        data = json.loads(msg.data)
        event = VehicleCrossingEvent(**data)
        self.stats.events_processed += 1

        rules = await self._load_rules(
            camera_id=event.camera_id, site_id=event.site_id
        )

        for rule in rules:
            if evaluate_rule(event, rule):
                if await self._check_cooldown(rule):
                    self.stats.alerts_suppressed += 1
                    continue
                await self._fire_alert(event, rule)

    async def _handle_health(self, msg: Any) -> None:
        data = json.loads(msg.data)
        event = CameraHealthEvent(**data)
        self.stats.events_processed += 1

        rules = await self._load_rules(camera_id=event.camera_id)

        for rule in rules:
            if evaluate_rule(event, rule):
                if await self._check_cooldown(rule):
                    self.stats.alerts_suppressed += 1
                    continue
                await self._fire_alert(event, rule)

    async def _load_rules(
        self,
        *,
        camera_id: str | None = None,
        site_id: str | None = None,
    ) -> list[dict[str, Any]]:
        """Load active rules, using Redis cache when available."""
        cache_key = f"{RULES_CACHE_KEY}:{camera_id or 'all'}:{site_id or 'all'}"
        if self._redis:
            try:
                cached = await self._redis.get(cache_key)
                if cached:
                    return json.loads(cached)
            except Exception:
                logger.warning("Redis cache read failed, falling back to DB")

        rules = await self._db.list_active_rules(
            camera_id=camera_id, site_id=site_id
        )

        if self._redis:
            try:
                serializable = _serialize_rules(rules)
                await self._redis.setex(
                    cache_key, RULES_CACHE_TTL, json.dumps(serializable)
                )
            except Exception:
                logger.warning("Redis cache write failed")

        return rules

    async def _check_cooldown(self, rule: dict[str, Any]) -> bool:
        """Return True if the rule is still in cooldown (alert suppressed)."""
        if not self._redis:
            return False

        rule_id = str(rule["id"])
        cooldown_key = f"{COOLDOWN_PREFIX}{rule_id}"
        try:
            exists = await self._redis.exists(cooldown_key)
            return bool(exists)
        except Exception:
            logger.warning("Redis cooldown check failed for rule %s", rule_id)
            return False

    async def _set_cooldown(self, rule: dict[str, Any]) -> None:
        if not self._redis:
            return

        rule_id = str(rule["id"])
        cooldown_minutes = rule.get(
            "cooldown_minutes", self._settings.default_cooldown_minutes
        )
        cooldown_key = f"{COOLDOWN_PREFIX}{rule_id}"
        try:
            await self._redis.setex(cooldown_key, cooldown_minutes * 60, "1")
        except Exception:
            logger.warning("Redis cooldown set failed for rule %s", rule_id)

    async def _fire_alert(
        self,
        event: VehicleCrossingEvent | CameraHealthEvent,
        rule: dict[str, Any],
    ) -> None:
        """Create an alert_event record, publish to NATS, and dispatch notifications."""
        camera_id = event.camera_id
        site_id = getattr(event, "site_id", None)
        org_id = str(rule["org_id"])

        message = (
            f"[{rule.get('severity', 'warning').upper()}] "
            f"Rule '{rule.get('name', 'unnamed')}' triggered "
            f"on camera {camera_id}"
        )

        context: dict[str, Any] = {
            "event_type": event.event_type,
            "camera_id": camera_id,
            "timestamp_utc": event.timestamp_utc.isoformat(),
        }
        if isinstance(event, VehicleCrossingEvent):
            context["speed_estimate_kmh"] = event.speed_estimate_kmh
            context["class12"] = event.class12.value
            context["direction"] = event.direction

        alert_data = {
            "org_id": org_id,
            "rule_id": str(rule["id"]),
            "camera_id": camera_id,
            "site_id": site_id,
            "severity": rule.get("severity", "warning"),
            "status": AlertStatus.TRIGGERED,
            "message": message,
            "context": context,
        }

        alert_record = await self._db.create_alert_event(data=alert_data)
        await self._set_cooldown(rule)
        self.stats.alerts_fired += 1

        await self._publish_alert_event(alert_record, rule)

        delivery_start = time.monotonic()
        try:
            await deliver_alert(alert_record, rule)
            self.stats.deliveries_succeeded += 1
        except Exception:
            self.stats.deliveries_failed += 1
            logger.exception("Failed to deliver alert %s", alert_record.get("id"))
        finally:
            elapsed = time.monotonic() - delivery_start
            self.stats.last_delivery_duration_s = elapsed

    async def _publish_alert_event(
        self,
        alert_record: dict[str, Any],
        rule: dict[str, Any],
    ) -> None:
        """Publish an AlertEvent to the NATS ALERTS stream for downstream consumers."""
        if not self._js:
            return

        alert_id = alert_record.get("id")
        rule_id = rule.get("id")

        nats_event = AlertEvent(
            event_type="AlertTriggered",
            timestamp_utc=alert_record.get("triggered_at", event_now()),
            alert_id=_to_uuid(alert_id),
            rule_id=_to_uuid(rule_id),
            org_id=str(alert_record.get("org_id", "")),
            severity=AlertSeverity(alert_record.get("severity", "warning")),
            message=alert_record.get("message", ""),
            scope={
                "camera_id": str(alert_record.get("camera_id", "")),
                "site_id": str(alert_record.get("site_id", "")),
            },
        )

        subject = f"{SUBJECT_ALERTS}.{alert_record.get('org_id', 'unknown')}"
        try:
            await self._js.publish(
                subject,
                nats_event.model_dump_json().encode(),
            )
            logger.info("Published AlertTriggered to %s (alert_id=%s)", subject, alert_id)
        except Exception:
            logger.exception("Failed to publish AlertEvent to NATS")


class _ConsumerStats:
    """In-memory counters exposed via the /metrics endpoint."""

    __slots__ = (
        "alerts_fired",
        "alerts_suppressed",
        "deliveries_failed",
        "deliveries_succeeded",
        "events_processed",
        "last_delivery_duration_s",
    )

    def __init__(self) -> None:
        self.events_processed: int = 0
        self.alerts_fired: int = 0
        self.alerts_suppressed: int = 0
        self.deliveries_succeeded: int = 0
        self.deliveries_failed: int = 0
        self.last_delivery_duration_s: float = 0.0


def _serialize_rules(rules: list[dict[str, Any]]) -> list[dict[str, Any]]:
    serializable = []
    for r in rules:
        row = {}
        for k, v in r.items():
            if hasattr(v, "isoformat"):
                row[k] = v.isoformat()
            elif hasattr(v, "hex"):
                row[k] = str(v)
            else:
                row[k] = v
        serializable.append(row)
    return serializable


def _to_uuid(value: Any) -> UUID:
    if isinstance(value, UUID):
        return value
    return UUID(str(value))


def event_now():
    from datetime import UTC, datetime
    return datetime.now(tz=UTC)
