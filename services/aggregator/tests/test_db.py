"""Tests for the database layer — verifies SQL generation and parameter handling."""

from __future__ import annotations

from aggregator.db import _DELETE_RANGE_SQL, _RECOMPUTE_SQL, _UPSERT_SQL, AggregatorDB


class TestUpsertSQL:
    """Verify the upsert SQL template is well-formed."""

    def test_upsert_sql_contains_on_conflict(self) -> None:
        assert "ON CONFLICT" in _UPSERT_SQL

    def test_upsert_sql_conflict_columns(self) -> None:
        assert "(camera_id, line_id, bucket_start, class12, direction)" in _UPSERT_SQL

    def test_upsert_sql_increments_count(self) -> None:
        assert "agg_vehicle_counts_15m.count + EXCLUDED.count" in _UPSERT_SQL

    def test_upsert_sql_uses_least_for_min(self) -> None:
        assert "LEAST(agg_vehicle_counts_15m.min_speed_kmh, EXCLUDED.min_speed_kmh)" in _UPSERT_SQL

    def test_upsert_sql_uses_greatest_for_max(self) -> None:
        expected = "GREATEST(agg_vehicle_counts_15m.max_speed_kmh, EXCLUDED.max_speed_kmh)"
        assert expected in _UPSERT_SQL

    def test_upsert_sql_sums_confidence(self) -> None:
        assert "agg_vehicle_counts_15m.sum_confidence + EXCLUDED.sum_confidence" in _UPSERT_SQL

    def test_upsert_sql_sums_speed(self) -> None:
        assert "agg_vehicle_counts_15m.sum_speed_kmh + EXCLUDED.sum_speed_kmh" in _UPSERT_SQL

    def test_upsert_sql_sets_last_updated(self) -> None:
        assert "last_updated_at" in _UPSERT_SQL

    def test_upsert_sql_has_11_placeholders(self) -> None:
        count = sum(1 for i in range(1, 12) if f"${i}" in _UPSERT_SQL)
        assert count == 11

    def test_upsert_sql_inserts_into_correct_table(self) -> None:
        assert "agg_vehicle_counts_15m" in _UPSERT_SQL

    def test_upsert_sql_includes_org_id(self) -> None:
        assert "org_id" in _UPSERT_SQL


class TestDeleteSQL:
    """Verify the delete-and-recompute SQL template."""

    def test_delete_sql_targets_correct_table(self) -> None:
        assert "agg_vehicle_counts_15m" in _DELETE_RANGE_SQL

    def test_delete_sql_filters_by_camera(self) -> None:
        assert "camera_id = $1" in _DELETE_RANGE_SQL

    def test_delete_sql_filters_by_range(self) -> None:
        assert "bucket_start >= $2" in _DELETE_RANGE_SQL
        assert "bucket_start < $3" in _DELETE_RANGE_SQL


class TestRecomputeSQL:
    """Verify the recompute SQL rebuilds aggregates from vehicle_crossings."""

    def test_recompute_inserts_into_agg_table(self) -> None:
        assert "INSERT INTO agg_vehicle_counts_15m" in _RECOMPUTE_SQL

    def test_recompute_selects_from_crossings(self) -> None:
        assert "FROM vehicle_crossings" in _RECOMPUTE_SQL

    def test_recompute_uses_15_min_bucketing(self) -> None:
        assert "INTERVAL '15 minutes'" in _RECOMPUTE_SQL
        assert "FLOOR(EXTRACT(MINUTE FROM timestamp_utc) / 15)" in _RECOMPUTE_SQL

    def test_recompute_groups_correctly(self) -> None:
        assert "GROUP BY" in _RECOMPUTE_SQL
        for col in ("org_id", "camera_id", "line_id", "class12", "direction"):
            assert col in _RECOMPUTE_SQL

    def test_recompute_aggregates_count(self) -> None:
        assert "COUNT(*)" in _RECOMPUTE_SQL

    def test_recompute_aggregates_confidence(self) -> None:
        assert "SUM(confidence)" in _RECOMPUTE_SQL

    def test_recompute_aggregates_speed(self) -> None:
        assert "SUM(speed_estimate_kmh)" in _RECOMPUTE_SQL
        assert "MIN(speed_estimate_kmh)" in _RECOMPUTE_SQL
        assert "MAX(speed_estimate_kmh)" in _RECOMPUTE_SQL

    def test_recompute_filters_by_camera_and_range(self) -> None:
        assert "camera_id = $1" in _RECOMPUTE_SQL
        assert "timestamp_utc >= $2" in _RECOMPUTE_SQL
        assert "timestamp_utc < $3" in _RECOMPUTE_SQL


class TestAggregatorDBInit:
    """Verify AggregatorDB initialisation."""

    def test_pool_raises_when_not_connected(self) -> None:
        db = AggregatorDB()
        try:
            _ = db.pool
            raise AssertionError("Expected RuntimeError")
        except RuntimeError as e:
            assert "not connected" in str(e).lower()
