"""AsyncPG database queries for the aggregated vehicle-count table.

All queries target the ``agg_vehicle_counts_15m`` hypertable and the
``shared_report_links`` table for shareable report URLs.
"""

from __future__ import annotations

import json
import logging
import secrets
from base64 import b64decode, b64encode
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID

import ssl

import asyncpg

logger = logging.getLogger(__name__)

_pool: asyncpg.Pool | None = None


async def connect(database_url: str) -> None:
    """Create the module-level connection pool."""
    global _pool
    from urllib.parse import urlparse

    dsn = database_url.replace("postgresql+asyncpg://", "postgresql://")
    kwargs: dict[str, Any] = {"min_size": 2, "max_size": 10}
    if ".supabase.co" in dsn or ".supabase.com" in dsn:
        ssl_ctx = ssl.create_default_context()
        ssl_ctx.check_hostname = False
        ssl_ctx.verify_mode = ssl.CERT_NONE
        kwargs["ssl"] = ssl_ctx
        parsed = urlparse(dsn)
        kwargs.update(
            host=parsed.hostname,
            port=parsed.port or 5432,
            user=parsed.username,
            password=parsed.password,
            database=parsed.path.lstrip("/") or "postgres",
        )
        _pool = await asyncpg.create_pool(**kwargs)
    else:
        _pool = await asyncpg.create_pool(dsn, **kwargs)
    logger.info("AsyncPG pool connected")


async def close() -> None:
    """Gracefully close the connection pool."""
    global _pool
    if _pool is not None:
        await _pool.close()
        _pool = None
        logger.info("AsyncPG pool closed")


def _get_pool() -> asyncpg.Pool:
    if _pool is None:
        raise RuntimeError("Database pool is not initialised — call connect() first")
    return _pool


# ── Cursor helpers ───────────────────────────────────────────────────────────


def encode_cursor(bucket_start: datetime) -> str:
    return b64encode(bucket_start.isoformat().encode()).decode()


def decode_cursor(cursor: str) -> datetime:
    return datetime.fromisoformat(b64decode(cursor).decode())


# ── 15-minute bucket queries ────────────────────────────────────────────────


async def query_15m_buckets(
    *,
    start: datetime,
    end: datetime,
    org_id: UUID,
    camera_id: UUID | None = None,
    site_id: UUID | None = None,
    line_id: UUID | None = None,
    group_by: str | None = None,
    class_filter: list[int] | None = None,
    direction_filter: str | None = None,
    limit: int = 100,
    cursor: str | None = None,
) -> tuple[list[dict[str, Any]], str | None]:
    """Return 15-minute aggregate rows within a time range.

    Supports scoping by camera, site, or org, with optional class/direction
    filters and cursor-based pagination.

    Returns ``(rows, next_cursor)``.
    """
    pool = _get_pool()

    conditions = ["org_id = $1", "bucket_start >= $2", "bucket_start < $3"]
    params: list[Any] = [org_id, start, end]

    if cursor is not None:
        cursor_ts = decode_cursor(cursor)
        params[1] = cursor_ts

    if camera_id is not None:
        conditions.append(f"camera_id = ${len(params) + 1}")
        params.append(camera_id)

    if site_id is not None:
        conditions.append(
            f"camera_id IN (SELECT id FROM cameras WHERE site_id = ${len(params) + 1})"
        )
        params.append(site_id)

    if line_id is not None:
        conditions.append(f"line_id = ${len(params) + 1}")
        params.append(line_id)

    if class_filter:
        conditions.append(f"class12 = ANY(${len(params) + 1}::smallint[])")
        params.append(class_filter)

    if direction_filter:
        conditions.append(f"direction = ${len(params) + 1}")
        params.append(direction_filter)

    where = " AND ".join(conditions)
    fetch_limit = limit + 1

    if group_by == "class":
        sql = f"""
            SELECT bucket_start, class12,
                   SUM(count)::bigint AS count,
                   SUM(sum_confidence) AS sum_confidence,
                   SUM(sum_speed_kmh) AS sum_speed_kmh,
                   MIN(min_speed_kmh) AS min_speed_kmh,
                   MAX(max_speed_kmh) AS max_speed_kmh
            FROM agg_vehicle_counts_15m
            WHERE {where}
            GROUP BY bucket_start, class12
            ORDER BY bucket_start, class12
            LIMIT {fetch_limit}
        """
    elif group_by == "direction":
        sql = f"""
            SELECT bucket_start, direction,
                   SUM(count)::bigint AS count,
                   SUM(sum_confidence) AS sum_confidence,
                   SUM(sum_speed_kmh) AS sum_speed_kmh,
                   MIN(min_speed_kmh) AS min_speed_kmh,
                   MAX(max_speed_kmh) AS max_speed_kmh
            FROM agg_vehicle_counts_15m
            WHERE {where}
            GROUP BY bucket_start, direction
            ORDER BY bucket_start, direction
            LIMIT {fetch_limit}
        """
    else:
        sql = f"""
            SELECT bucket_start,
                   SUM(count)::bigint AS count,
                   SUM(sum_confidence) AS sum_confidence,
                   SUM(sum_speed_kmh) AS sum_speed_kmh,
                   MIN(min_speed_kmh) AS min_speed_kmh,
                   MAX(max_speed_kmh) AS max_speed_kmh
            FROM agg_vehicle_counts_15m
            WHERE {where}
            GROUP BY bucket_start
            ORDER BY bucket_start
            LIMIT {fetch_limit}
        """

    rows = await pool.fetch(sql, *params)
    result = [dict(r) for r in rows]

    next_cursor: str | None = None
    if len(result) > limit:
        result = result[:limit]
        last_bucket = result[-1]["bucket_start"]
        next_cursor = encode_cursor(last_bucket + timedelta(minutes=15))

    return result, next_cursor


# ── KPI queries ──────────────────────────────────────────────────────────────


async def query_kpi(
    *,
    start: datetime,
    end: datetime,
    org_id: UUID,
    camera_id: UUID | None = None,
    site_id: UUID | None = None,
) -> dict[str, Any]:
    """Derive high-level KPIs from the 15-minute aggregates."""
    pool = _get_pool()

    conditions = ["org_id = $1", "bucket_start >= $2", "bucket_start < $3"]
    params: list[Any] = [org_id, start, end]

    if camera_id is not None:
        conditions.append(f"camera_id = ${len(params) + 1}")
        params.append(camera_id)

    if site_id is not None:
        conditions.append(
            f"camera_id IN (SELECT id FROM cameras WHERE site_id = ${len(params) + 1})"
        )
        params.append(site_id)

    where = " AND ".join(conditions)

    sql = f"""
        SELECT
            class12,
            SUM(count)::bigint AS class_count,
            SUM(sum_speed_kmh) AS total_speed_sum,
            SUM(count)::bigint AS speed_count
        FROM agg_vehicle_counts_15m
        WHERE {where}
        GROUP BY class12
    """
    rows = await pool.fetch(sql, *params)

    total_count = 0
    class_distribution: dict[int, int] = {}
    heavy_count = 0
    total_speed_sum = 0.0
    total_speed_count = 0

    for row in rows:
        cnt = row["class_count"]
        cls = row["class12"]
        total_count += cnt
        class_distribution[cls] = cnt
        if cls >= 5:
            heavy_count += cnt
        if row["total_speed_sum"] is not None:
            total_speed_sum += float(row["total_speed_sum"])
            total_speed_count += cnt

    hours = max((end - start).total_seconds() / 3600, 1 / 60)
    flow_rate = total_count / hours
    heavy_ratio = heavy_count / total_count if total_count > 0 else 0.0
    avg_speed = (
        round(total_speed_sum / total_speed_count, 2) if total_speed_count > 0 else None
    )

    return {
        "total_count": total_count,
        "flow_rate_per_hour": round(flow_rate, 2),
        "class_distribution": class_distribution,
        "heavy_vehicle_ratio": round(heavy_ratio, 4),
        "avg_speed_kmh": avg_speed,
    }


# ── Comparison queries ───────────────────────────────────────────────────────


async def query_comparison(
    *,
    org_id: UUID,
    camera_id: UUID | None = None,
    site_id: UUID | None = None,
    range1_start: datetime,
    range1_end: datetime,
    range2_start: datetime,
    range2_end: datetime,
) -> dict[str, Any]:
    """Compare aggregated counts across two time ranges."""
    pool = _get_pool()

    scope_clause = "org_id = $1"
    scope_params: list[Any] = [org_id]

    if camera_id is not None:
        scope_clause += f" AND camera_id = ${len(scope_params) + 1}"
        scope_params.append(camera_id)

    if site_id is not None:
        scope_clause += (
            f" AND camera_id IN (SELECT id FROM cameras WHERE site_id = ${len(scope_params) + 1})"
        )
        scope_params.append(site_id)

    n = len(scope_params)
    sql = f"""
        SELECT
            COALESCE(SUM(count), 0)::bigint AS total_count,
            SUM(sum_speed_kmh) AS total_speed_sum,
            SUM(count)::bigint AS speed_count
        FROM agg_vehicle_counts_15m
        WHERE {scope_clause}
          AND bucket_start >= ${n + 1} AND bucket_start < ${n + 2}
    """

    r1 = await pool.fetchrow(sql, *scope_params, range1_start, range1_end)
    r2 = await pool.fetchrow(sql, *scope_params, range2_start, range2_end)

    def _stats(row: asyncpg.Record | None) -> dict[str, Any]:
        if row is None or row["total_count"] == 0:
            return {"total_count": 0, "avg_speed_kmh": None}
        return {
            "total_count": row["total_count"],
            "avg_speed_kmh": round(
                float(row["total_speed_sum"]) / row["speed_count"], 2
            )
            if row["speed_count"]
            else None,
        }

    range1 = _stats(r1)
    range2 = _stats(r2)

    delta = range2["total_count"] - range1["total_count"]
    pct = (delta / range1["total_count"] * 100) if range1["total_count"] else None

    return {
        "range1": range1,
        "range2": range2,
        "count_delta": delta,
        "count_change_pct": round(pct, 2) if pct is not None else None,
    }


# ── Export data queries ──────────────────────────────────────────────────────


async def query_export_data(
    *,
    org_id: UUID,
    scope: str,
    start: datetime,
    end: datetime,
    filters: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    """Fetch detailed aggregate rows for export generation.

    ``scope`` is a string like ``"camera:<uuid>"`` or ``"site:<uuid>"``.
    Returns raw rows suitable for CSV/JSON/PDF rendering.
    """
    pool = _get_pool()

    conditions = ["org_id = $1", "bucket_start >= $2", "bucket_start < $3"]
    params: list[Any] = [org_id, start, end]

    scope_type, _, scope_id = scope.partition(":")
    if scope_type == "camera" and scope_id:
        conditions.append(f"camera_id = ${len(params) + 1}")
        params.append(UUID(scope_id))
    elif scope_type == "site" and scope_id:
        conditions.append(
            f"camera_id IN (SELECT id FROM cameras WHERE site_id = ${len(params) + 1})"
        )
        params.append(UUID(scope_id))

    if filters:
        if "class12" in filters:
            conditions.append(f"class12 = ANY(${len(params) + 1}::smallint[])")
            params.append(filters["class12"])
        if "direction" in filters:
            conditions.append(f"direction = ${len(params) + 1}")
            params.append(filters["direction"])

    where = " AND ".join(conditions)

    sql = f"""
        SELECT
            camera_id, line_id, bucket_start, class12, direction,
            count, sum_confidence, sum_speed_kmh,
            min_speed_kmh, max_speed_kmh
        FROM agg_vehicle_counts_15m
        WHERE {where}
        ORDER BY bucket_start, camera_id, class12
    """

    rows = await pool.fetch(sql, *params)
    return [dict(r) for r in rows]


async def stream_export_rows(
    *,
    org_id: UUID,
    scope: str,
    start: datetime,
    end: datetime,
    filters: dict[str, Any] | None = None,
    batch_size: int = 500,
):
    """Async generator that yields batches of rows for streaming CSV export."""
    pool = _get_pool()

    conditions = ["org_id = $1", "bucket_start >= $2", "bucket_start < $3"]
    params: list[Any] = [org_id, start, end]

    scope_type, _, scope_id = scope.partition(":")
    if scope_type == "camera" and scope_id:
        conditions.append(f"camera_id = ${len(params) + 1}")
        params.append(UUID(scope_id))
    elif scope_type == "site" and scope_id:
        conditions.append(
            f"camera_id IN (SELECT id FROM cameras WHERE site_id = ${len(params) + 1})"
        )
        params.append(UUID(scope_id))

    if filters:
        if "class12" in filters:
            conditions.append(f"class12 = ANY(${len(params) + 1}::smallint[])")
            params.append(filters["class12"])
        if "direction" in filters:
            conditions.append(f"direction = ${len(params) + 1}")
            params.append(filters["direction"])

    where = " AND ".join(conditions)

    sql = f"""
        SELECT
            camera_id, line_id, bucket_start, class12, direction,
            count, sum_confidence, sum_speed_kmh,
            min_speed_kmh, max_speed_kmh
        FROM agg_vehicle_counts_15m
        WHERE {where}
        ORDER BY bucket_start, camera_id, class12
    """

    async with pool.acquire() as conn:
        async with conn.transaction():
            cur = conn.cursor(sql, *params)
            batch: list[dict[str, Any]] = []
            async for record in cur:
                batch.append(dict(record))
                if len(batch) >= batch_size:
                    yield batch
                    batch = []
            if batch:
                yield batch


# ── Shared Links ─────────────────────────────────────────────────────────────


async def create_shared_link(
    *,
    org_id: UUID,
    created_by: UUID,
    scope: str,
    filters: dict[str, Any],
    expires_at: datetime,
) -> dict[str, Any]:
    """Insert a new shared-link row and return it."""
    pool = _get_pool()
    token = secrets.token_urlsafe(32)

    sql = """
        INSERT INTO shared_report_links (token, org_id, created_by, scope, filters, expires_at)
        VALUES ($1, $2, $3, $4::jsonb, $5::jsonb, $6)
        RETURNING id, token, org_id, created_by, scope, filters, expires_at, created_at
    """
    row = await pool.fetchrow(
        sql,
        token,
        org_id,
        created_by,
        json.dumps(scope),
        json.dumps(filters),
        expires_at,
    )
    return dict(row) if row else {"token": token}


async def get_shared_link(token: str) -> dict[str, Any] | None:
    """Look up a shared link by token, returning ``None`` if expired or missing."""
    pool = _get_pool()

    sql = """
        SELECT id, token, org_id, created_by, scope, filters, expires_at, created_at
        FROM shared_report_links
        WHERE token = $1 AND expires_at > $2
    """
    row = await pool.fetchrow(sql, token, datetime.now(tz=UTC))
    return dict(row) if row else None


async def get_shared_link_data(
    token: str,
) -> tuple[dict[str, Any] | None, list[dict[str, Any]]]:
    """Look up a shared link and fetch its associated analytics data.

    Returns ``(link_record, data_rows)`` or ``(None, [])`` if invalid.
    """
    link = await get_shared_link(token)
    if link is None:
        return None, []

    scope_raw = link["scope"]
    scope = json.loads(scope_raw) if isinstance(scope_raw, str) else scope_raw

    filters_raw = link["filters"]
    filters = json.loads(filters_raw) if isinstance(filters_raw, str) else filters_raw

    scope_str = scope if isinstance(scope, str) else f"{scope.get('type', 'org')}:{scope.get('id', '')}"

    start = filters.get("start")
    end = filters.get("end")

    if start and end:
        start_dt = datetime.fromisoformat(start) if isinstance(start, str) else start
        end_dt = datetime.fromisoformat(end) if isinstance(end, str) else end
        data = await query_export_data(
            org_id=link["org_id"],
            scope=scope_str,
            start=start_dt,
            end=end_dt,
            filters=filters,
        )
    else:
        data = []

    return link, data
