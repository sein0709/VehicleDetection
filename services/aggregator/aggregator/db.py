"""AsyncPG database client for aggregated vehicle count upserts and recomputation.

Implements the idempotent upsert from Section 5.3 and the recompute query
from Section 5.6 of the software design doc.
"""

from __future__ import annotations

import logging
from datetime import datetime  # noqa: TC003
from typing import Any

import asyncpg

logger = logging.getLogger(__name__)

_UPSERT_SQL = """
INSERT INTO agg_vehicle_counts_15m (
    org_id, camera_id, line_id, bucket_start, class12, direction,
    count, sum_confidence, sum_speed_kmh, min_speed_kmh, max_speed_kmh,
    last_updated_at
)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, now())
ON CONFLICT (camera_id, line_id, bucket_start, class12, direction)
DO UPDATE SET
    count            = agg_vehicle_counts_15m.count + EXCLUDED.count,
    sum_confidence   = agg_vehicle_counts_15m.sum_confidence + EXCLUDED.sum_confidence,
    sum_speed_kmh    = agg_vehicle_counts_15m.sum_speed_kmh + EXCLUDED.sum_speed_kmh,
    min_speed_kmh    = LEAST(agg_vehicle_counts_15m.min_speed_kmh, EXCLUDED.min_speed_kmh),
    max_speed_kmh    = GREATEST(agg_vehicle_counts_15m.max_speed_kmh, EXCLUDED.max_speed_kmh),
    last_updated_at  = now()
"""

_DELETE_RANGE_SQL = """
DELETE FROM agg_vehicle_counts_15m
WHERE camera_id = $1
  AND bucket_start >= $2
  AND bucket_start < $3
"""

_RECOMPUTE_SQL = """
INSERT INTO agg_vehicle_counts_15m (
    org_id, camera_id, line_id, bucket_start, class12, direction,
    count, sum_confidence, sum_speed_kmh, min_speed_kmh, max_speed_kmh,
    last_updated_at
)
SELECT
    org_id,
    camera_id,
    line_id,
    date_trunc('hour', timestamp_utc)
        + INTERVAL '15 minutes' * FLOOR(EXTRACT(MINUTE FROM timestamp_utc) / 15),
    class12,
    direction,
    COUNT(*)::INT,
    SUM(confidence)::REAL,
    SUM(speed_estimate_kmh)::REAL,
    MIN(speed_estimate_kmh)::REAL,
    MAX(speed_estimate_kmh)::REAL,
    now()
FROM vehicle_crossings
WHERE camera_id = $1
  AND timestamp_utc >= $2
  AND timestamp_utc < $3
GROUP BY
    org_id, camera_id, line_id,
    date_trunc('hour', timestamp_utc)
        + INTERVAL '15 minutes' * FLOOR(EXTRACT(MINUTE FROM timestamp_utc) / 15),
    class12, direction
"""

_FETCH_BUCKET_TOTALS_SQL = """
SELECT
    camera_id,
    line_id,
    bucket_start,
    class12,
    direction,
    count,
    sum_confidence,
    sum_speed_kmh,
    min_speed_kmh,
    max_speed_kmh
FROM agg_vehicle_counts_15m
WHERE camera_id = $1
  AND bucket_start = $2
"""


class AggregatorDB:
    """Thin async wrapper around an asyncpg connection pool."""

    def __init__(self) -> None:
        self._pool: asyncpg.Pool | None = None

    async def connect(self, database_url: str) -> None:
        dsn = database_url.replace("postgresql+asyncpg://", "postgresql://")
        self._pool = await asyncpg.create_pool(dsn, min_size=2, max_size=10)
        logger.info("Database pool opened")

    async def close(self) -> None:
        if self._pool:
            await self._pool.close()
            logger.info("Database pool closed")

    @property
    def pool(self) -> asyncpg.Pool:
        if self._pool is None:
            raise RuntimeError("Database not connected")
        return self._pool

    async def upsert_bucket(
        self,
        org_id: str,
        camera_id: str,
        line_id: str,
        bucket_start: datetime,
        class12: int,
        direction: str,
        count: int,
        sum_confidence: float,
        sum_speed_kmh: float | None,
        min_speed_kmh: float | None,
        max_speed_kmh: float | None,
    ) -> None:
        await self.pool.execute(
            _UPSERT_SQL,
            org_id,
            camera_id,
            line_id,
            bucket_start,
            class12,
            direction,
            count,
            sum_confidence,
            sum_speed_kmh,
            min_speed_kmh,
            max_speed_kmh,
        )

    async def batch_upsert(self, rows: list[dict[str, Any]]) -> int:
        """Upsert a batch of accumulated rows inside a single transaction.

        Returns the number of rows upserted.
        """
        if not rows:
            return 0

        async with self.pool.acquire() as conn, conn.transaction():
            stmt = await conn.prepare(_UPSERT_SQL)
            for row in rows:
                await stmt.fetch(
                    row["org_id"],
                    row["camera_id"],
                    row["line_id"],
                    row["bucket_start"],
                    row["class12"],
                    row["direction"],
                    row["count"],
                    row["sum_confidence"],
                    row["sum_speed_kmh"],
                    row["min_speed_kmh"],
                    row["max_speed_kmh"],
                )
        logger.debug("Batch upserted %d rows", len(rows))
        return len(rows)

    async def recompute(
        self,
        camera_id: str,
        start: datetime,
        end: datetime,
    ) -> int:
        """Delete aggregated rows for a camera within [start, end) and rebuild
        them from the vehicle_crossings source-of-truth table.

        This is the full recompute per Section 5.6 of the design doc.
        Returns the number of newly inserted aggregate rows.
        """
        async with self.pool.acquire() as conn, conn.transaction():
            result: str = await conn.execute(_DELETE_RANGE_SQL, camera_id, start, end)
            deleted = int(result.split()[-1])
            logger.info(
                "Recompute: deleted %d old rows for camera=%s [%s, %s)",
                deleted,
                camera_id,
                start,
                end,
            )

            result = await conn.execute(_RECOMPUTE_SQL, camera_id, start, end)
            inserted = int(result.split()[-1])
            logger.info(
                "Recompute: inserted %d new rows for camera=%s [%s, %s)",
                inserted,
                camera_id,
                start,
                end,
            )

        return inserted

    async def fetch_bucket_totals(
        self,
        camera_id: str,
        bucket_start: datetime,
    ) -> list[dict[str, Any]]:
        """Fetch all aggregate rows for a camera and bucket, used for KPI push after recompute."""
        rows = await self.pool.fetch(_FETCH_BUCKET_TOTALS_SQL, camera_id, bucket_start)
        return [dict(r) for r in rows]

    async def delete_and_recompute(
        self,
        camera_id: str,
        start: datetime,
        end: datetime,
    ) -> int:
        """Alias for recompute() — kept for backward compatibility."""
        return await self.recompute(camera_id, start, end)
