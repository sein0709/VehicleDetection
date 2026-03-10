"""Config version history and rollback endpoints.

Implements configuration versioning from 02-software-design.md Section 2.3.
"""

from __future__ import annotations

import logging
from uuid import UUID

from fastapi import APIRouter, HTTPException, Request, status

from config_service.db import ConfigDB
from config_service.dependencies import CurrentUser, OperatorUser
from config_service.models import ConfigVersionResponse

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/v1/config-versions", tags=["config-versions"])


@router.get(
    "/{entity_type}/{entity_id}",
    response_model=list[ConfigVersionResponse],
)
async def list_versions(
    entity_type: str,
    entity_id: UUID,
    request: Request,
    user: CurrentUser,
) -> list[ConfigVersionResponse]:
    if entity_type not in ("site", "camera", "roi_preset"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="entity_type must be one of: site, camera, roi_preset",
        )

    db: ConfigDB = request.app.state.config_db
    versions = await db.list_config_versions(entity_type, entity_id, user.org_uuid)
    return [ConfigVersionResponse(**v) for v in versions]


@router.post("/{version_id}/rollback", response_model=ConfigVersionResponse)
async def rollback_to_version(
    version_id: UUID,
    request: Request,
    user: OperatorUser,
) -> ConfigVersionResponse:
    """Rollback an entity to a previous config version.

    Creates a new version whose snapshot is a copy of the target version's
    snapshot, with rollback_from pointing to the target.
    """
    db: ConfigDB = request.app.state.config_db

    target = await db.get_config_version(version_id, user.org_uuid)
    if not target:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Config version not found",
        )

    entity_type = target["entity_type"]
    entity_id = UUID(target["entity_id"])

    existing_versions = await db.list_config_versions(entity_type, entity_id, user.org_uuid)
    next_version = max(v["version_number"] for v in existing_versions) + 1

    new_version = await db.create_config_version(
        org_id=user.org_uuid,
        entity_type=entity_type,
        entity_id=entity_id,
        version_number=next_version,
        snapshot=target["config_snapshot"],
        created_by=user.user_id,
        rollback_from=version_id,
    )

    db.rollback_entity_version(entity_type, entity_id, next_version)

    await db.write_audit_log(
        org_id=user.org_uuid,
        user_id=user.user_id,
        action=f"{entity_type}.rollback",
        entity_type=entity_type,
        entity_id=entity_id,
        new_value={
            "rolled_back_to_version": target["version_number"],
            "new_version": next_version,
        },
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )

    return ConfigVersionResponse(**new_version)


def _client_ip(request: Request) -> str | None:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client:
        return request.client.host
    return None
