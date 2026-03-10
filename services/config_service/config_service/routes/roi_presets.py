"""ROI preset and counting line management endpoints.

Implements the ROI endpoints from 02-software-design.md Section 3.3.
"""

from __future__ import annotations

import logging
from uuid import UUID

from fastapi import APIRouter, HTTPException, Request, status

from config_service.db import ConfigDB
from config_service.dependencies import CurrentUser, OperatorUser
from config_service.models import (
    CreateROIPresetRequest,
    MessageResponse,
    ROIPresetResponse,
    UpdateROIPresetRequest,
)

logger = logging.getLogger(__name__)
router = APIRouter(tags=["roi-presets"])


@router.post(
    "/v1/cameras/{camera_id}/roi-presets",
    response_model=ROIPresetResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_roi_preset(
    camera_id: UUID,
    body: CreateROIPresetRequest,
    request: Request,
    user: OperatorUser,
) -> ROIPresetResponse:
    db: ConfigDB = request.app.state.config_db

    camera = await db.get_camera(camera_id, user.org_uuid)
    if not camera:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Camera not found")

    counting_lines_raw = [cl.model_dump() for cl in body.counting_lines]
    lane_polylines_raw = [lp.model_dump() for lp in body.lane_polylines]

    preset = await db.create_roi_preset(
        camera_id=camera_id,
        org_id=user.org_uuid,
        name=body.name,
        roi_polygon=body.roi_polygon.model_dump(),
        lane_polylines=lane_polylines_raw,
        counting_lines=counting_lines_raw,
        created_by=user.user_id,
    )

    await db.write_audit_log(
        org_id=user.org_uuid,
        user_id=user.user_id,
        action="roi_preset.created",
        entity_type="roi_preset",
        entity_id=UUID(preset["id"]),
        new_value={"name": body.name, "camera_id": str(camera_id)},
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )

    return ROIPresetResponse(**preset)


@router.get(
    "/v1/cameras/{camera_id}/roi-presets",
    response_model=list[ROIPresetResponse],
)
async def list_roi_presets(
    camera_id: UUID,
    request: Request,
    user: CurrentUser,
) -> list[ROIPresetResponse]:
    db: ConfigDB = request.app.state.config_db

    presets = await db.list_roi_presets(camera_id, user.org_uuid)
    return [ROIPresetResponse(**p) for p in presets]


@router.get("/v1/roi-presets/{preset_id}", response_model=ROIPresetResponse)
async def get_roi_preset(
    preset_id: UUID,
    request: Request,
    user: CurrentUser,
) -> ROIPresetResponse:
    db: ConfigDB = request.app.state.config_db

    preset = await db.get_roi_preset(preset_id, user.org_uuid)
    if not preset:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="ROI preset not found")

    return ROIPresetResponse(**preset)


@router.put("/v1/roi-presets/{preset_id}", response_model=ROIPresetResponse)
async def update_roi_preset(
    preset_id: UUID,
    body: UpdateROIPresetRequest,
    request: Request,
    user: OperatorUser,
) -> ROIPresetResponse:
    db: ConfigDB = request.app.state.config_db

    counting_lines_raw = (
        [cl.model_dump() for cl in body.counting_lines] if body.counting_lines is not None else None
    )
    lane_polylines_raw = (
        [lp.model_dump() for lp in body.lane_polylines] if body.lane_polylines is not None else None
    )

    preset = await db.update_roi_preset(
        preset_id,
        user.org_uuid,
        name=body.name,
        roi_polygon=body.roi_polygon.model_dump() if body.roi_polygon else None,
        lane_polylines=lane_polylines_raw,
        counting_lines=counting_lines_raw,
        updated_by=user.user_id,
    )
    if not preset:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="ROI preset not found")

    await db.write_audit_log(
        org_id=user.org_uuid,
        user_id=user.user_id,
        action="roi_preset.updated",
        entity_type="roi_preset",
        entity_id=preset_id,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )

    return ROIPresetResponse(**preset)


@router.post(
    "/v1/roi-presets/{preset_id}/activate",
    response_model=ROIPresetResponse,
)
async def activate_roi_preset(
    preset_id: UUID,
    request: Request,
    user: OperatorUser,
) -> ROIPresetResponse:
    db: ConfigDB = request.app.state.config_db

    preset = await db.activate_roi_preset(preset_id, user.org_uuid)
    if not preset:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="ROI preset not found")

    await db.write_audit_log(
        org_id=user.org_uuid,
        user_id=user.user_id,
        action="roi_preset.activated",
        entity_type="roi_preset",
        entity_id=preset_id,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )

    return ROIPresetResponse(**preset)


@router.delete("/v1/roi-presets/{preset_id}", response_model=MessageResponse)
async def delete_roi_preset(
    preset_id: UUID,
    request: Request,
    user: OperatorUser,
) -> MessageResponse:
    db: ConfigDB = request.app.state.config_db

    success = await db.delete_roi_preset(preset_id, user.org_uuid)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="ROI preset not found")

    await db.write_audit_log(
        org_id=user.org_uuid,
        user_id=user.user_id,
        action="roi_preset.deleted",
        entity_type="roi_preset",
        entity_id=preset_id,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )

    return MessageResponse(message="ROI preset deleted successfully")


def _client_ip(request: Request) -> str | None:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client:
        return request.client.host
    return None
