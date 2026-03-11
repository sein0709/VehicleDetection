"""Camera management endpoints: registration, settings, health status.

Implements the camera endpoints from 02-software-design.md Section 3.2.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Request, status

from config_service.db import ConfigDB
from config_service.dependencies import CurrentUser, OperatorUser
from config_service.models import (
    CameraHeartbeatRequest,
    CameraResponse,
    CameraStatusResponse,
    CreateCameraRequest,
    MessageResponse,
    UpdateCameraRequest,
)
from config_service.redis_client import CameraHealthCache
from shared_contracts.enums import CameraStatus
from shared_contracts.pagination import PaginatedResponse, PaginationMeta

logger = logging.getLogger(__name__)
router = APIRouter(tags=["cameras"])


@router.post(
    "/v1/sites/{site_id}/cameras",
    response_model=CameraResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_camera(
    site_id: UUID,
    body: CreateCameraRequest,
    request: Request,
    user: OperatorUser,
) -> CameraResponse:
    db: ConfigDB = request.app.state.config_db

    site = await db.get_site(site_id, user.org_uuid)
    if not site:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Site not found")

    camera = await db.create_camera(
        site_id=site_id,
        org_id=user.org_uuid,
        name=body.name,
        source_type=body.source_type.value,
        rtsp_url=body.rtsp_url,
        settings=body.settings.model_dump(),
        created_by=user.user_id,
    )

    await db.write_audit_log(
        org_id=user.org_uuid,
        user_id=user.user_id,
        action="camera.created",
        entity_type="camera",
        entity_id=UUID(camera["id"]),
        new_value={"name": body.name, "source_type": body.source_type.value},
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )

    return CameraResponse(**camera)


@router.get(
    "/v1/sites/{site_id}/cameras",
    response_model=PaginatedResponse[CameraResponse],
)
async def list_cameras_for_site(
    site_id: UUID,
    request: Request,
    user: CurrentUser,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    camera_status: str | None = Query(default=None, alias="status"),
) -> PaginatedResponse[CameraResponse]:
    db: ConfigDB = request.app.state.config_db

    cameras, total = await db.list_cameras(
        user.org_uuid,
        site_id=site_id,
        status=camera_status,
        limit=limit + 1,
        cursor=cursor,
    )

    has_more = len(cameras) > limit
    if has_more:
        cameras = cameras[:limit]

    next_cursor = cameras[-1]["created_at"] if has_more and cameras else None

    return PaginatedResponse[CameraResponse](
        data=[CameraResponse(**c) for c in cameras],
        pagination=PaginationMeta(
            cursor=next_cursor,
            has_more=has_more,
            total_count=total,
        ),
    )


@router.get("/v1/cameras/{camera_id}", response_model=CameraResponse)
async def get_camera(
    camera_id: UUID,
    request: Request,
    user: CurrentUser,
) -> CameraResponse:
    db: ConfigDB = request.app.state.config_db

    camera = await db.get_camera(camera_id, user.org_uuid)
    if not camera:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Camera not found")

    return CameraResponse(**camera)


@router.patch("/v1/cameras/{camera_id}", response_model=CameraResponse)
async def update_camera(
    camera_id: UUID,
    body: UpdateCameraRequest,
    request: Request,
    user: OperatorUser,
) -> CameraResponse:
    db: ConfigDB = request.app.state.config_db

    updates: dict = {}
    if body.name is not None:
        updates["name"] = body.name
    if body.rtsp_url is not None:
        updates["rtsp_url"] = body.rtsp_url
    if body.settings is not None:
        updates["settings"] = body.settings.model_dump()

    if not updates:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No fields to update",
        )

    camera = await db.update_camera(
        camera_id, user.org_uuid, updates=updates, updated_by=user.user_id
    )
    if not camera:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Camera not found")

    await db.write_audit_log(
        org_id=user.org_uuid,
        user_id=user.user_id,
        action="camera.updated",
        entity_type="camera",
        entity_id=camera_id,
        new_value=updates,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )

    return CameraResponse(**camera)


@router.delete("/v1/cameras/{camera_id}", response_model=MessageResponse)
async def archive_camera(
    camera_id: UUID,
    request: Request,
    user: OperatorUser,
) -> MessageResponse:
    db: ConfigDB = request.app.state.config_db

    success = await db.archive_camera(camera_id, user.org_uuid)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Camera not found")

    await db.write_audit_log(
        org_id=user.org_uuid,
        user_id=user.user_id,
        action="camera.archived",
        entity_type="camera",
        entity_id=camera_id,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )

    return MessageResponse(message="Camera archived successfully")


@router.get("/v1/cameras/{camera_id}/status", response_model=CameraStatusResponse)
async def get_camera_status(
    camera_id: UUID,
    request: Request,
    user: CurrentUser,
) -> CameraStatusResponse:
    db: ConfigDB = request.app.state.config_db
    health_cache: CameraHealthCache = request.app.state.health_cache

    camera = await db.get_camera(camera_id, user.org_uuid)
    if not camera:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Camera not found")

    cached = await health_cache.get_camera_health(str(camera_id))

    if cached:
        return CameraStatusResponse(
            camera_id=camera_id,
            status=CameraStatus(cached.get("status", "offline")),
            last_seen_at=cached.get("last_seen"),
            fps_actual=float(cached["fps"]) if "fps" in cached else None,
            frame_width=int(cached["frame_width"]) if "frame_width" in cached else None,
            frame_height=int(cached["frame_height"]) if "frame_height" in cached else None,
        )

    return CameraStatusResponse(
        camera_id=camera_id,
        status=CameraStatus(camera.get("status", "offline")),
        last_seen_at=camera.get("last_seen_at"),
    )


@router.post(
    "/v1/cameras/{camera_id}/heartbeat",
    response_model=MessageResponse,
)
async def camera_heartbeat(
    camera_id: UUID,
    request: Request,
    user: CurrentUser,
    body: CameraHeartbeatRequest | None = None,
) -> MessageResponse:
    """Record a heartbeat from a camera, updating its health status in Redis.

    Called by the Ingest Service or directly by the mobile client to signal
    that the camera is alive and streaming.
    """
    db: ConfigDB = request.app.state.config_db
    health_cache: CameraHealthCache = request.app.state.health_cache

    camera = await db.get_camera(camera_id, user.org_uuid)
    if not camera:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Camera not found")

    fps = body.fps if body else None
    frame_width = body.frame_width if body else None
    frame_height = body.frame_height if body else None

    await health_cache.record_heartbeat(
        str(camera_id),
        fps=fps,
        frame_width=frame_width,
        frame_height=frame_height,
    )

    now_iso = datetime.now(tz=UTC).isoformat()
    await db.update_camera_status(str(camera_id), status="online", last_seen_at=now_iso)

    return MessageResponse(message="Heartbeat recorded")


def _client_ip(request: Request) -> str | None:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client:
        return request.client.host
    return None
