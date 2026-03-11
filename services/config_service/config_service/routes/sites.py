"""Site management endpoints: CRUD with geofence and config versioning.

Implements the site endpoints from 02-software-design.md Section 3.2.
"""

from __future__ import annotations

import struct
import logging
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Request, status

from config_service.db import ConfigDB
from config_service.dependencies import AdminUser, CurrentUser, OperatorUser
from config_service.models import (
    CreateSiteRequest,
    MessageResponse,
    SiteResponse,
    UpdateSiteRequest,
)
from shared_contracts.pagination import PaginatedResponse, PaginationMeta

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/v1/sites", tags=["sites"])


def _normalize_site(site: dict) -> dict:
    normalized = dict(site)
    normalized["location"] = _normalize_location(site.get("location"))
    return normalized


def _normalize_location(value: object) -> dict | None | object:
    if value is None or isinstance(value, dict):
        return value
    if not isinstance(value, str):
        return value

    if value.startswith("POINT(") and value.endswith(")"):
        try:
            longitude, latitude = value[6:-1].split()
            return {
                "type": "Point",
                "coordinates": [float(longitude), float(latitude)],
            }
        except ValueError:
            return value

    try:
        raw = bytes.fromhex(value)
    except ValueError:
        return value

    if len(raw) < 21:
        return value

    byte_order = raw[0]
    endian = "<" if byte_order == 1 else ">"
    geom_type = struct.unpack(f"{endian}I", raw[1:5])[0]
    has_srid = bool(geom_type & 0x20000000)
    base_type = geom_type & 0xFF
    offset = 5
    if has_srid:
        offset += 4
    if base_type != 1 or len(raw) < offset + 16:
        return value

    longitude, latitude = struct.unpack(f"{endian}dd", raw[offset : offset + 16])
    return {
        "type": "Point",
        "coordinates": [longitude, latitude],
    }


@router.post("", response_model=SiteResponse, status_code=status.HTTP_201_CREATED)
async def create_site(
    body: CreateSiteRequest,
    request: Request,
    user: OperatorUser,
) -> SiteResponse:
    db: ConfigDB = request.app.state.config_db

    site = await db.create_site(
        org_id=user.org_uuid,
        name=body.name,
        address=body.address,
        latitude=body.location.latitude if body.location else None,
        longitude=body.location.longitude if body.location else None,
        geofence=body.geofence.model_dump() if body.geofence else None,
        timezone=body.timezone,
        created_by=user.user_id,
    )

    await db.write_audit_log(
        org_id=user.org_uuid,
        user_id=user.user_id,
        action="site.created",
        entity_type="site",
        entity_id=UUID(site["id"]),
        new_value={"name": body.name},
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )

    return SiteResponse(**_normalize_site(site))


@router.get("", response_model=PaginatedResponse[SiteResponse])
async def list_sites(
    request: Request,
    user: CurrentUser,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    site_status: str | None = Query(default=None, alias="status"),
) -> PaginatedResponse[SiteResponse]:
    db: ConfigDB = request.app.state.config_db

    sites, total = await db.list_sites(
        user.org_uuid,
        status=site_status,
        limit=limit + 1,
        cursor=cursor,
    )

    has_more = len(sites) > limit
    if has_more:
        sites = sites[:limit]

    next_cursor = sites[-1]["created_at"] if has_more and sites else None

    return PaginatedResponse[SiteResponse](
        data=[SiteResponse(**_normalize_site(s)) for s in sites],
        pagination=PaginationMeta(
            cursor=next_cursor,
            has_more=has_more,
            total_count=total,
        ),
    )


@router.get("/{site_id}", response_model=SiteResponse)
async def get_site(
    site_id: UUID,
    request: Request,
    user: CurrentUser,
) -> SiteResponse:
    db: ConfigDB = request.app.state.config_db

    site = await db.get_site(site_id, user.org_uuid)
    if not site:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Site not found")

    return SiteResponse(**_normalize_site(site))


@router.patch("/{site_id}", response_model=SiteResponse)
async def update_site(
    site_id: UUID,
    body: UpdateSiteRequest,
    request: Request,
    user: OperatorUser,
) -> SiteResponse:
    db: ConfigDB = request.app.state.config_db

    updates: dict = {}
    if body.name is not None:
        updates["name"] = body.name
    if body.address is not None:
        updates["address"] = body.address
    if body.timezone is not None:
        updates["timezone"] = body.timezone
    if body.geofence is not None:
        updates["geofence"] = body.geofence.model_dump()
    if body.location is not None:
        updates["location"] = f"POINT({body.location.longitude} {body.location.latitude})"

    if not updates:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No fields to update",
        )

    site = await db.update_site(site_id, user.org_uuid, updates=updates, updated_by=user.user_id)
    if not site:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Site not found")

    await db.write_audit_log(
        org_id=user.org_uuid,
        user_id=user.user_id,
        action="site.updated",
        entity_type="site",
        entity_id=site_id,
        new_value=updates,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )

    return SiteResponse(**_normalize_site(site))


@router.delete("/{site_id}", response_model=MessageResponse)
async def archive_site(
    site_id: UUID,
    request: Request,
    user: AdminUser,
) -> MessageResponse:
    """Soft-delete a site by setting its status to archived (Admin only)."""
    db: ConfigDB = request.app.state.config_db

    success = await db.archive_site(site_id, user.org_uuid)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Site not found")

    await db.write_audit_log(
        org_id=user.org_uuid,
        user_id=user.user_id,
        action="site.archived",
        entity_type="site",
        entity_id=site_id,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )

    return MessageResponse(message="Site archived successfully")


def _client_ip(request: Request) -> str | None:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client:
        return request.client.host
    return None
