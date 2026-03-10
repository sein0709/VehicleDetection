"""Tests for the NATS event consumer: rule loading, cooldown, alert firing."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest

from notification_service.nats_consumer import EventConsumer, _serialize_rules
from notification_service.settings import Settings
from shared_contracts.enums import VehicleClass12
from shared_contracts.events import CameraHealthEvent, VehicleCrossingEvent


@pytest.fixture()
def settings() -> Settings:
    return Settings(
        nats_url="nats://localhost:4222",
        redis_url="redis://localhost:6379/0",
        database_url="postgresql+asyncpg://test:test@localhost:5432/test",
        jwt_secret="test-secret",
        default_cooldown_minutes=15,
    )


@pytest.fixture()
def mock_db() -> MagicMock:
    from notification_service.db import NotificationDB
    return MagicMock(spec=NotificationDB)


@pytest.fixture()
def consumer(settings: Settings, mock_db: MagicMock) -> EventConsumer:
    return EventConsumer(settings, mock_db)


@pytest.fixture()
def sample_rule() -> dict[str, Any]:
    return {
        "id": uuid4(),
        "org_id": uuid4(),
        "name": "Speed Alert",
        "condition_type": "speed_drop",
        "condition_config": {"min_speed_kmh": 10.0},
        "severity": "warning",
        "channels": ["push"],
        "recipients": [{"device_token": "tok"}],
        "cooldown_minutes": 15,
        "enabled": True,
    }


def _make_crossing_msg(
    speed: float = 5.0,
    camera_id: str = "cam-001",
) -> MagicMock:
    event = VehicleCrossingEvent(
        timestamp_utc=datetime.now(tz=UTC),
        camera_id=camera_id,
        line_id="line-001",
        track_id="track-001",
        crossing_seq=1,
        class12=VehicleClass12.C01_PASSENGER_MINITRUCK,
        confidence=0.95,
        direction="inbound",
        model_version="v1.0",
        frame_index=100,
        speed_estimate_kmh=speed,
        org_id=str(uuid4()),
        site_id=str(uuid4()),
    )
    msg = MagicMock()
    msg.data = event.model_dump_json().encode()
    msg.subject = f"events.crossings.{camera_id}"
    return msg


def _make_health_msg(
    status: str = "offline",
    camera_id: str = "cam-001",
) -> MagicMock:
    event = CameraHealthEvent(
        timestamp_utc=datetime.now(tz=UTC),
        camera_id=camera_id,
        status=status,
    )
    msg = MagicMock()
    msg.data = event.model_dump_json().encode()
    msg.subject = f"events.health.{camera_id}"
    return msg


class TestHandleCrossing:
    @pytest.mark.asyncio
    async def test_fires_alert_when_rule_matches(
        self, consumer: EventConsumer, mock_db: MagicMock, sample_rule: dict
    ) -> None:
        consumer._redis = AsyncMock()
        consumer._redis.get = AsyncMock(return_value=None)
        consumer._redis.exists = AsyncMock(return_value=0)
        consumer._redis.setex = AsyncMock()

        mock_db.list_active_rules = AsyncMock(return_value=[sample_rule])
        mock_db.create_alert_event = AsyncMock(return_value={
            "id": uuid4(), "org_id": str(sample_rule["org_id"]),
            "rule_id": str(sample_rule["id"]), "severity": "warning",
            "message": "test", "triggered_at": datetime.now(tz=UTC),
            "context": {},
        })

        with patch("notification_service.nats_consumer.deliver_alert", new_callable=AsyncMock):
            consumer._js = AsyncMock()
            consumer._js.publish = AsyncMock()
            msg = _make_crossing_msg(speed=3.0)
            await consumer._handle_crossing(msg)

            mock_db.create_alert_event.assert_called_once()
            assert consumer.stats.alerts_fired == 1

    @pytest.mark.asyncio
    async def test_suppresses_when_in_cooldown(
        self, consumer: EventConsumer, mock_db: MagicMock, sample_rule: dict
    ) -> None:
        consumer._redis = AsyncMock()
        consumer._redis.get = AsyncMock(return_value=None)
        consumer._redis.exists = AsyncMock(return_value=1)

        mock_db.list_active_rules = AsyncMock(return_value=[sample_rule])

        msg = _make_crossing_msg(speed=3.0)
        await consumer._handle_crossing(msg)

        mock_db.create_alert_event.assert_not_called()
        assert consumer.stats.alerts_suppressed == 1

    @pytest.mark.asyncio
    async def test_no_alert_when_rule_does_not_match(
        self, consumer: EventConsumer, mock_db: MagicMock, sample_rule: dict
    ) -> None:
        consumer._redis = AsyncMock()
        consumer._redis.get = AsyncMock(return_value=None)

        mock_db.list_active_rules = AsyncMock(return_value=[sample_rule])

        msg = _make_crossing_msg(speed=50.0)
        await consumer._handle_crossing(msg)

        mock_db.create_alert_event.assert_not_called()
        assert consumer.stats.alerts_fired == 0


class TestHandleHealth:
    @pytest.mark.asyncio
    async def test_fires_alert_on_camera_offline(
        self, consumer: EventConsumer, mock_db: MagicMock
    ) -> None:
        rule = {
            "id": uuid4(),
            "org_id": uuid4(),
            "name": "Camera Offline",
            "condition_type": "camera_offline",
            "condition_config": {"statuses": ["offline"]},
            "severity": "critical",
            "channels": ["email"],
            "recipients": [{"email": "ops@test.com"}],
            "cooldown_minutes": 30,
            "enabled": True,
        }

        consumer._redis = AsyncMock()
        consumer._redis.get = AsyncMock(return_value=None)
        consumer._redis.exists = AsyncMock(return_value=0)
        consumer._redis.setex = AsyncMock()

        mock_db.list_active_rules = AsyncMock(return_value=[rule])
        mock_db.create_alert_event = AsyncMock(return_value={
            "id": uuid4(), "org_id": str(rule["org_id"]),
            "rule_id": str(rule["id"]), "severity": "critical",
            "message": "test", "triggered_at": datetime.now(tz=UTC),
            "context": {},
        })

        with patch("notification_service.nats_consumer.deliver_alert", new_callable=AsyncMock):
            consumer._js = AsyncMock()
            consumer._js.publish = AsyncMock()
            msg = _make_health_msg(status="offline")
            await consumer._handle_health(msg)

            mock_db.create_alert_event.assert_called_once()
            assert consumer.stats.alerts_fired == 1


class TestCooldown:
    @pytest.mark.asyncio
    async def test_check_cooldown_returns_false_without_redis(
        self, consumer: EventConsumer, sample_rule: dict
    ) -> None:
        consumer._redis = None
        result = await consumer._check_cooldown(sample_rule)
        assert result is False

    @pytest.mark.asyncio
    async def test_set_cooldown_uses_rule_minutes(
        self, consumer: EventConsumer, sample_rule: dict
    ) -> None:
        consumer._redis = AsyncMock()
        consumer._redis.setex = AsyncMock()

        await consumer._set_cooldown(sample_rule)

        consumer._redis.setex.assert_called_once()
        args = consumer._redis.setex.call_args
        assert args[0][1] == 15 * 60


class TestLoadRules:
    @pytest.mark.asyncio
    async def test_uses_cache_when_available(
        self, consumer: EventConsumer, mock_db: MagicMock, sample_rule: dict
    ) -> None:
        cached = json.dumps([{
            "id": str(sample_rule["id"]),
            "condition_type": "speed_drop",
            "condition_config": {"min_speed_kmh": 10.0},
        }])
        consumer._redis = AsyncMock()
        consumer._redis.get = AsyncMock(return_value=cached)

        rules = await consumer._load_rules(camera_id="cam-001")

        assert len(rules) == 1
        mock_db.list_active_rules.assert_not_called()

    @pytest.mark.asyncio
    async def test_falls_back_to_db_on_cache_miss(
        self, consumer: EventConsumer, mock_db: MagicMock, sample_rule: dict
    ) -> None:
        consumer._redis = AsyncMock()
        consumer._redis.get = AsyncMock(return_value=None)
        consumer._redis.setex = AsyncMock()

        mock_db.list_active_rules = AsyncMock(return_value=[sample_rule])

        rules = await consumer._load_rules(camera_id="cam-001")

        assert len(rules) == 1
        mock_db.list_active_rules.assert_called_once()


class TestCacheInvalidation:
    @pytest.mark.asyncio
    async def test_invalidate_deletes_cache_keys(
        self, consumer: EventConsumer
    ) -> None:
        consumer._redis = AsyncMock()
        consumer._redis.scan = AsyncMock(return_value=(0, ["notification:rules_cache:cam:site"]))
        consumer._redis.delete = AsyncMock()

        await consumer.invalidate_rules_cache()

        consumer._redis.delete.assert_called_once()


class TestSerializeRules:
    def test_serializes_datetime_and_uuid(self) -> None:
        now = datetime.now(tz=UTC)
        uid = uuid4()
        rules = [{"id": uid, "created_at": now, "name": "test"}]
        result = _serialize_rules(rules)
        assert result[0]["id"] == str(uid)
        assert result[0]["created_at"] == now.isoformat()
        assert result[0]["name"] == "test"


class TestConsumerStats:
    def test_initial_stats(self, consumer: EventConsumer) -> None:
        assert consumer.stats.events_processed == 0
        assert consumer.stats.alerts_fired == 0
        assert consumer.stats.alerts_suppressed == 0
        assert consumer.stats.deliveries_succeeded == 0
        assert consumer.stats.deliveries_failed == 0
