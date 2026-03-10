"""Tests for event schemas and bucketing logic."""

from datetime import UTC, datetime

from shared_contracts.enums import VehicleClass12
from shared_contracts.events import VehicleCrossingEvent, compute_bucket_start


class TestComputeBucketStart:
    def test_on_boundary(self) -> None:
        ts = datetime(2026, 3, 9, 10, 0, 0, tzinfo=UTC)
        assert compute_bucket_start(ts) == datetime(2026, 3, 9, 10, 0, 0, tzinfo=UTC)

    def test_mid_bucket(self) -> None:
        ts = datetime(2026, 3, 9, 10, 7, 32, tzinfo=UTC)
        assert compute_bucket_start(ts) == datetime(2026, 3, 9, 10, 0, 0, tzinfo=UTC)

    def test_just_before_boundary(self) -> None:
        ts = datetime(2026, 3, 9, 10, 14, 59, tzinfo=UTC)
        assert compute_bucket_start(ts) == datetime(2026, 3, 9, 10, 0, 0, tzinfo=UTC)

    def test_on_15_boundary(self) -> None:
        ts = datetime(2026, 3, 9, 10, 15, 0, tzinfo=UTC)
        assert compute_bucket_start(ts) == datetime(2026, 3, 9, 10, 15, 0, tzinfo=UTC)

    def test_on_45_boundary(self) -> None:
        ts = datetime(2026, 3, 9, 10, 45, 0, tzinfo=UTC)
        assert compute_bucket_start(ts) == datetime(2026, 3, 9, 10, 45, 0, tzinfo=UTC)

    def test_end_of_day(self) -> None:
        ts = datetime(2026, 3, 9, 23, 59, 59, tzinfo=UTC)
        assert compute_bucket_start(ts) == datetime(2026, 3, 9, 23, 45, 0, tzinfo=UTC)


class TestVehicleCrossingEvent:
    def _make_event(self, **kwargs: object) -> VehicleCrossingEvent:
        defaults: dict[str, object] = {
            "timestamp_utc": datetime(2026, 3, 9, 14, 7, 32, 451000, tzinfo=UTC),
            "camera_id": "cam_abc123",
            "line_id": "line_01",
            "track_id": "trk_00042",
            "crossing_seq": 1,
            "class12": VehicleClass12.C02_BUS,
            "confidence": 0.91,
            "direction": "inbound",
            "model_version": "v2.3.1",
            "frame_index": 4217,
            "org_id": "org_xyz789",
            "site_id": "site_a1b2c3",
        }
        defaults.update(kwargs)
        return VehicleCrossingEvent(**defaults)  # type: ignore[arg-type]

    def test_dedup_key(self) -> None:
        event = self._make_event()
        assert event.dedup_key == "cam_abc123:line_01:trk_00042:1"

    def test_bucket_start(self) -> None:
        event = self._make_event()
        expected = datetime(2026, 3, 9, 14, 0, 0, tzinfo=UTC)
        assert event.bucket_start == expected

    def test_json_round_trip(self) -> None:
        event = self._make_event()
        json_str = event.model_dump_json()
        restored = VehicleCrossingEvent.model_validate_json(json_str)
        assert restored.dedup_key == event.dedup_key
        assert restored.class12 == VehicleClass12.C02_BUS

    def test_confidence_bounds(self) -> None:
        import pytest
        from pydantic import ValidationError

        with pytest.raises(ValidationError):
            self._make_event(confidence=1.5)
        with pytest.raises(ValidationError):
            self._make_event(confidence=-0.1)
