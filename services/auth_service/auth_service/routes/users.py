"""User management endpoints: profile, role updates.

Implements GET /v1/users/me and PATCH /v1/users/{user_id}/role from the
software design doc Section 3.1.
"""

from __future__ import annotations

import logging
from uuid import UUID

from fastapi import APIRouter, HTTPException, Request, status

from auth_service.audit import AuditAction, log_audit_event
from auth_service.dependencies import CurrentUser, require_permission
from auth_service.models import RoleUpdateRequest, UserProfile
from auth_service.rbac import Permission
from auth_service.redis_client import RedisTokenStore
from auth_service.supabase_client import SupabaseAuthClient
from auth_service.tokens import TokenClaims
from shared_contracts.enums import UserRole

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/v1/users", tags=["users"])


@router.get("/me", response_model=UserProfile)
async def get_current_user_profile(
    request: Request,
    user: CurrentUser,
) -> UserProfile:
    """Get the authenticated user's profile and role."""
    db: SupabaseAuthClient = request.app.state.supabase_client
    user_record = await db.get_user_by_id(user.user_id)

    if not user_record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return UserProfile(
        id=user_record["id"],
        email=user_record["email"],
        name=user_record["name"],
        org_id=user_record["org_id"],
        role=user_record["role"],
        is_active=user_record.get("is_active", True),
        last_login_at=user_record.get("last_login_at"),
        created_at=user_record["created_at"],
    )


@router.patch("/{user_id}/role", response_model=UserProfile)
async def update_user_role(
    user_id: UUID,
    body: RoleUpdateRequest,
    request: Request,
    admin: TokenClaims = __import__("fastapi").Depends(
        require_permission(Permission.ASSIGN_ROLES)
    ),
) -> UserProfile:
    """Update a user's role. Requires admin role and step-up authentication."""
    db: SupabaseAuthClient = request.app.state.supabase_client
    redis_store: RedisTokenStore = request.app.state.redis_store

    target_user = await db.get_user_by_id(user_id)
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    if UUID(target_user["org_id"]) != admin.org_uuid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot modify users outside your organization",
        )

    if user_id == admin.user_id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Cannot change your own role",
        )

    old_role = target_user["role"]
    if old_role == body.role.value:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"User already has role {body.role.value}",
        )

    updated = await db.update_user_role(user_id, body.role.value)
    if not updated:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update user role",
        )

    try:
        await db.update_user_metadata(
            str(user_id),
            {"role": body.role.value},
        )
    except Exception:
        logger.exception("Failed to sync role to Supabase Auth metadata")

    await log_audit_event(
        request,
        action=AuditAction.USER_ROLE_CHANGED,
        entity_type="user",
        org_id=admin.org_uuid,
        user_id=admin.user_id,
        entity_id=user_id,
        old_value={"role": old_role},
        new_value={"role": body.role.value},
    )

    return UserProfile(
        id=updated["id"],
        email=updated["email"],
        name=updated["name"],
        org_id=updated["org_id"],
        role=updated["role"],
        is_active=updated.get("is_active", True),
        last_login_at=updated.get("last_login_at"),
        created_at=updated["created_at"],
    )
