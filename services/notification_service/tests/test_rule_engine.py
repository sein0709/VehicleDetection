"""Tests for alert rule evaluation logic."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import uuid4

from notification_service.rule_engine import (
    CountAnomalyTracker,
    evaluate_camera_offline,
    evaluate_congestion,
    evaluate_count_anomaly,
    evaluate_heavy_vehicle_share,
    evaluate_rule,
    evaluate_speed_drop,
    evaluate_stopped_vehicle,
    reset_count_anomaly_tracker,
)
from shared_contracts.enums import VehicleClass12
from shared_contracts.events import CameraHealthEvent, VehicleCrossingEvent


def _crossing(
    speed: float | None = 60.0,
    class12: VehicleClass12 = VehicleClass12.C01_PASSENGER_MINITRUCK,
    camera_id: str = "cam-001",
    timestamp: datetime | None = None,
) -> VehicleCrossingEvent:
    return VehicleCrossingEvent(
        timestamp_utc=timestamp or datetime.now(tz=UTC),
        camera_id=camera_id,
        line_id="line-001",
        track_id="track-001",
        crossing_seq=1,
        class12=class12,
        confidence=0.95,
        direction="inbound",
        model_version="v1.0",
        frame_index=100,
        speed_estimate_kmh=speed,
        org_id=str(uuid4()),
        site_id=str(uuid4()),
    )


def _health(status: str = "offline") -> CameraHealthEvent:
    return CameraHealthEvent(
        timestamp_utc=datetime.now(tz=UTC),
        camera_id="cam-001",
        status=status,
    )


class TestEvaluateCongestion:
    def test_triggers_below_threshold(self) -> None:
        event = _crossing(speed=5.0)
        assert evaluate_congestion(event, {"speed_threshold_kmh": 10.0}) is True

    def test_no_trigger_above_threshold(self) -> None:
        event = _crossing(speed=50.0)
        assert evaluate_congestion(event, {"speed_threshold_kmh": 10.0}) is False

    def test_no_trigger_when_speed_is_none(self) -> None:
        event = _crossing(speed=None)
        assert evaluate_congestion(event, {"speed_threshold_kmh": 10.0}) is False

    def test_uses_default_threshold(self) -> None:
        event = _crossing(speed=5.0)
        assert evaluate_congestion(event, {}) is True


class TestEvaluateSpeedDrop:
    def test_triggers_below_min(self) -> None:
        event = _crossing(speed=3.0)
        assert evaluate_speed_drop(event, {"min_speed_kmh": 5.0}) is True

    def test_no_trigger_above_min(self) -> None:
        event = _crossing(speed=20.0)
        assert evaluate_speed_drop(event, {"min_speed_kmh": 5.0}) is False

    def test_no_trigger_when_speed_is_none(self) -> None:
        event = _crossing(speed=None)
        assert evaluate_speed_drop(event, {"min_speed_kmh": 5.0}) is False


class TestEvaluateStoppedVehicle:
    def test_triggers_at_zero(self) -> None:
        event = _crossing(speed=0.0)
        assert evaluate_stopped_vehicle(event, {"max_speed_kmh": 2.0}) is True

    def test_triggers_at_threshold(self) -> None:
        event = _crossing(speed=2.0)
        assert evaluate_stopped_vehicle(event, {"max_speed_kmh": 2.0}) is True

    def test_no_trigger_above_threshold(self) -> None:
        event = _crossing(speed=10.0)
        assert evaluate_stopped_vehicle(event, {"max_speed_kmh": 2.0}) is False

    def test_no_trigger_when_speed_is_none(self) -> None:
        event = _crossing(speed=None)
        assert evaluate_stopped_vehicle(event, {"max_speed_kmh": 2.0}) is False


class TestEvaluateHeavyVehicleShare:
    def test_triggers_for_heavy_vehicle(self) -> None:
        event = _crossing(class12=VehicleClass12.C08_SEMI_4_AXLE)
        assert evaluate_heavy_vehicle_share(event, {"enabled": True}) is True

    def test_no_trigger_for_light_vehicle(self) -> None:
        event = _crossing(class12=VehicleClass12.C01_PASSENGER_MINITRUCK)
        assert evaluate_heavy_vehicle_share(event, {"enabled": True}) is False

    def test_no_trigger_when_disabled(self) -> None:
        event = _crossing(class12=VehicleClass12.C08_SEMI_4_AXLE)
        assert evaluate_heavy_vehicle_share(event, {"enabled": False}) is False


class TestEvaluateCameraOffline:
    def test_triggers_on_offline(self) -> None:
        event = _health("offline")
        assert evaluate_camera_offline(event, {"statuses": ["offline"]}) is True

    def test_no_trigger_on_online(self) -> None:
        event = _health("online")
        assert evaluate_camera_offline(event, {"statuses": ["offline"]}) is False

    def test_triggers_on_degraded_when_configured(self) -> None:
        event = _health("degraded")
        assert evaluate_camera_offline(event, {"statuses": ["offline", "degraded"]}) is True


class TestCountAnomalyTracker:
    def test_no_trigger_below_min_samples(self) -> None:
        tracker = CountAnomalyTracker()
        config = {"window_size": 4, "sigma_threshold": 2.0, "min_samples": 4}
        base = datetime(2026, 3, 10, 10, 0, tzinfo=UTC)

        for bucket_idx in range(3):
            ts = base + timedelta(minutes=15 * bucket_idx)
            event = _crossing(speed=60.0, timestamp=ts)
            for _ in range(10):
                result = tracker.observe(event, config)
            assert result is False

    def test_triggers_on_anomalous_count(self) -> None:
        tracker = CountAnomalyTracker()
        config = {"window_size": 6, "sigma_threshold": 2.0, "min_samples": 4}
        base = datetime(2026, 3, 10, 10, 0, tzinfo=UTC)

        bucket_counts = [10, 12, 9, 11, 10, 13]
        for bucket_idx, count in enumerate(bucket_counts):
            ts = base + timedelta(minutes=15 * bucket_idx)
            event = _crossing(speed=60.0, timestamp=ts)
            for _ in range(count):
                tracker.observe(event, config)

        anomaly_ts = base + timedelta(minutes=15 * len(bucket_counts))
        event = _crossing(speed=60.0, timestamp=anomaly_ts)
        triggered = False
        for _ in range(200):
            if tracker.observe(event, config):
                triggered = True
                break
        assert triggered is True

    def test_no_trigger_on_stable_counts(self) -> None:
        tracker = CountAnomalyTracker()
        config = {"window_size": 4, "sigma_threshold": 2.0, "min_samples": 4}
        base = datetime(2026, 3, 10, 10, 0, tzinfo=UTC)

        for bucket_idx in range(6):
            ts = base + timedelta(minutes=15 * bucket_idx)
            event = _crossing(speed=60.0, timestamp=ts)
            for _ in range(10):
                result = tracker.observe(event, config)

        assert result is False

    def test_module_level_evaluate_count_anomaly(self) -> None:
        reset_count_anomaly_tracker()
        config = {"window_size": 4, "sigma_threshold": 2.0, "min_samples": 4}
        base = datetime(2026, 3, 10, 10, 0, tzinfo=UTC)

        for bucket_idx in range(5):
            ts = base + timedelta(minutes=15 * bucket_idx)
            event = _crossing(speed=60.0, timestamp=ts)
            for _ in range(10):
                evaluate_count_anomaly(event, config)

        reset_count_anomaly_tracker()


class TestEvaluateRule:
    def test_dispatches_crossing_rule(self) -> None:
        event = _crossing(speed=3.0)
        rule = {
            "id": str(uuid4()),
            "condition_type": "congestion",
            "condition_config": {"speed_threshold_kmh": 10.0},
        }
        assert evaluate_rule(event, rule) is True

    def test_dispatches_health_rule(self) -> None:
        event = _health("offline")
        rule = {
            "id": str(uuid4()),
            "condition_type": "camera_offline",
            "condition_config": {"statuses": ["offline"]},
        }
        assert evaluate_rule(event, rule) is True

    def test_returns_false_for_mismatched_event_type(self) -> None:
        event = _crossing(speed=3.0)
        rule = {
            "id": str(uuid4()),
            "condition_type": "camera_offline",
            "condition_config": {},
        }
        assert evaluate_rule(event, rule) is False

    def test_dispatches_count_anomaly_rule(self) -> None:
        reset_count_anomaly_tracker()
        event = _crossing(speed=3.0)
        rule = {
            "id": str(uuid4()),
            "condition_type": "count_anomaly",
            "condition_config": {"min_samples": 4},
        }
        result = evaluate_rule(event, rule)
        assert result is False
        reset_count_anomaly_tracker()
