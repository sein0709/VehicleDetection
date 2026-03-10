"""Analytics endpoints — bucket aggregates, KPIs, live data, and comparisons."""

from __future__ import annotations

import asyncio
import logging
from datetime import timedelta
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse

from reporting_api import db, redis_client
from reporting_api.dependencies import CurrentUser
from reporting_api.models import (
    BucketResponse,
    BucketRow,
    ComparisonResponse,
    KPIResponse,
    LiveKPIUpdate,
    PaginationMeta,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1/analytics", tags=["analytics"])

_HEARTBEAT_INTERVAL = 15.0


@router.get("/15m", response_model=BucketResponse)
async def get_15m_buckets(
    user: CurrentUser,
    start: str = Query(..., description="ISO 8601 start timestamp"),
    end: str = Query(..., description="ISO 8601 end timestamp"),
    camera_id: UUID | None = Query(default=None),
    site_id: UUID | None = Query(default=None),
    line_id: UUID | None = Query(default=None),
    group_by: str | None = Query(default=None, pattern="^(class|direction)$"),
    class_filter: str | None = Query(default=None, description="Comma-separated class12 IDs"),
    direction: str | None = Query(default=None, pattern="^(inbound|outbound)$"),
    limit: int = Query(default=100, ge=1, le=1000),
    cursor: str | None = Query(default=None),
) -> BucketResponse:
    from datetime import datetime

    start_dt = datetime.fromisoformat(start)
    end_dt = datetime.fromisoformat(end)

    classes = [int(c) for c in class_filter.split(",")] if class_filter else None

    rows, next_cursor = await db.query_15m_buckets(
        start=start_dt,
        end=end_dt,
        org_id=user.org_uuid,
        camera_id=camera_id,
        site_id=site_id,
        line_id=line_id,
        group_by=group_by,
        class_filter=classes,
        direction_filter=direction,
        limit=limit,
        cursor=cursor,
    )

    buckets: list[BucketRow] = []
    for row in rows:
        bucket_start = row["bucket_start"]
        bucket_end = bucket_start + timedelta(minutes=15)
        by_class: dict[int, int] = {}
        by_direction: dict[str, int] = {}

        if "class12" in row:
            by_class[row["class12"]] = row["count"]
        if "direction" in row:
            by_direction[row["direction"]] = row["count"]

        avg_speed: float | None = None
        if row.get("sum_speed_kmh") and row["count"]:
            avg_speed = round(float(row["sum_speed_kmh"]) / row["count"], 2)

        buckets.append(
            BucketRow(
                bucket_start=bucket_start,
                bucket_end=bucket_end,
                total_count=row["count"],
                by_class=by_class,
                by_direction=by_direction,
                avg_speed_kmh=avg_speed,
            )
        )

    return BucketResponse(
        buckets=buckets,
        pagination=PaginationMeta(
            cursor=next_cursor,
            has_more=next_cursor is not None,
        ),
    )


@router.get("/kpi", response_model=KPIResponse)
async def get_kpi(
    user: CurrentUser,
    start: str = Query(...),
    end: str = Query(...),
    camera_id: UUID | None = Query(default=None),
    site_id: UUID | None = Query(default=None),
) -> KPIResponse:
    from datetime import datetime

    start_dt = datetime.fromisoformat(start)
    end_dt = datetime.fromisoformat(end)

    kpi = await db.query_kpi(
        start=start_dt,
        end=end_dt,
        org_id=user.org_uuid,
        camera_id=camera_id,
        site_id=site_id,
    )
    return KPIResponse(
        camera_id=camera_id,
        site_id=site_id,
        start=start_dt,
        end=end_dt,
        total_count=kpi["total_count"],
        flow_rate_per_hour=kpi["flow_rate_per_hour"],
        class_distribution=kpi["class_distribution"],
        heavy_vehicle_ratio=kpi["heavy_vehicle_ratio"],
        avg_speed_kmh=kpi.get("avg_speed_kmh"),
    )


@router.get("/live", response_model=LiveKPIUpdate)
async def get_live_kpi(
    user: CurrentUser,
    camera_id: str = Query(...),
) -> LiveKPIUpdate:
    data = await redis_client.get_live_bucket(camera_id)
    if data is None:
        return LiveKPIUpdate(camera_id=camera_id)

    counts: dict[str, Any] = {}
    by_class = data.get("class_counts", {})
    if isinstance(by_class, dict):
        counts["by_class"] = by_class
    direction_counts = data.get("direction_counts", {})
    if isinstance(direction_counts, dict):
        counts["by_direction"] = direction_counts
    counts["total"] = data.get("total_count", 0)

    return LiveKPIUpdate(
        camera_id=camera_id,
        current_bucket=data.get("bucket_start") or data.get("bucket_starts", [None])[0],
        elapsed_seconds=float(data.get("elapsed_seconds", 0)),
        counts=counts,
        active_tracks=int(data.get("active_tracks", 0)),
        flow_rate_per_hour=float(data.get("flow_rate_per_hour", 0)),
    )


@router.websocket("/live/ws")
async def live_kpi_ws(websocket: WebSocket, camera_id: str = Query(...)) -> None:
    """WebSocket endpoint for real-time KPI push.

    Sends a heartbeat ping every 15 seconds to keep the connection alive.
    Pushes live KPI updates from Redis pub/sub as they arrive (≤2s refresh).
    """
    await websocket.accept()

    async def _push_updates() -> None:
        async for update in redis_client.subscribe_live_kpi(camera_id):
            await websocket.send_json(update)

    async def _heartbeat() -> None:
        while True:
            await asyncio.sleep(_HEARTBEAT_INTERVAL)
            try:
                await websocket.send_json({"type": "heartbeat"})
            except Exception:
                break

    try:
        async with asyncio.TaskGroup() as tg:
            tg.create_task(_push_updates())
            tg.create_task(_heartbeat())
    except* WebSocketDisconnect:
        logger.debug("WebSocket client disconnected for camera %s", camera_id)
    except* asyncio.CancelledError:
        pass
    except* Exception as eg:
        logger.warning("WebSocket error for camera %s: %s", camera_id, eg.exceptions)


@router.get("/compare", response_model=ComparisonResponse)
async def compare_ranges(
    user: CurrentUser,
    range1_start: str = Query(...),
    range1_end: str = Query(...),
    range2_start: str = Query(...),
    range2_end: str = Query(...),
    camera_id: UUID | None = Query(default=None),
    site_id: UUID | None = Query(default=None),
) -> ComparisonResponse:
    from datetime import datetime

    result = await db.query_comparison(
        org_id=user.org_uuid,
        camera_id=camera_id,
        site_id=site_id,
        range1_start=datetime.fromisoformat(range1_start),
        range1_end=datetime.fromisoformat(range1_end),
        range2_start=datetime.fromisoformat(range2_start),
        range2_end=datetime.fromisoformat(range2_end),
    )
    return ComparisonResponse(
        camera_id=camera_id,
        site_id=site_id,
        range1=result["range1"],
        range2=result["range2"],
        count_delta=result["count_delta"],
        count_change_pct=result["count_change_pct"],
    )
