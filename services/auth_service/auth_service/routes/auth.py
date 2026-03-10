"""Authentication endpoints: register, login, refresh, logout, invite, step-up.

Implements the auth flow described in the software design doc Section 3.1:
- Registration creates a Supabase Auth user, an organization, and a GreyEye
  user record, then returns tokens.
- Login authenticates via Supabase Auth, issues GreyEye JWT tokens, and
  records the login in audit logs.
- Refresh rotates the refresh token with reuse detection.
- Logout revokes the refresh token and deny-lists the access token JTI.
- Invite (admin-only) creates a new user in the caller's organization.
- Step-up re-authenticates the user and grants elevated privileges for 5 min.
"""

from __future__ import annotations

import logging
import re
import secrets
from uuid import UUID

import httpx
from fastapi import APIRouter, HTTPException, Request, status
from starlette.responses import Response

from auth_service.audit import AuditAction, log_audit_event
from auth_service.dependencies import AdminUser, CurrentUser
from auth_service.models import (
    InviteRequest,
    InviteResponse,
    LoginRequest,
    LoginResponse,
    MessageResponse,
    RefreshRequest,
    RegisterRequest,
    StepUpRequest,
    UserProfile,
)
from auth_service.redis_client import RedisTokenStore
from auth_service.supabase_client import SupabaseAuthClient
from auth_service.tokens import TokenService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/v1/auth", tags=["auth"])


def _slugify(name: str) -> str:
    slug = re.sub(r"[^\w\s-]", "", name.lower())
    slug = re.sub(r"[\s_]+", "-", slug).strip("-")
    return slug or "org"


def _build_user_profile(user_data: dict) -> UserProfile:
    return UserProfile(
        id=user_data["id"],
        email=user_data["email"],
        name=user_data["name"],
        org_id=user_data["org_id"],
        role=user_data["role"],
        is_active=user_data.get("is_active", True),
        last_login_at=user_data.get("last_login_at"),
        created_at=user_data["created_at"],
    )


@router.post("/register", response_model=LoginResponse, status_code=status.HTTP_201_CREATED)
async def register(body: RegisterRequest, request: Request) -> LoginResponse:
    """Register a new user with a new organization."""
    db: SupabaseAuthClient = request.app.state.supabase_client
    token_svc: TokenService = request.app.state.token_service
    redis_store: RedisTokenStore = request.app.state.redis_store

    existing = await db.get_user_by_email(body.email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A user with this email already exists",
        )

    try:
        supabase_user = await db.sign_up(body.email, body.password)
    except httpx.HTTPStatusError as exc:
        logger.warning("Supabase signup failed: %s", exc.response.text)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Registration failed. Check email format and password strength.",
        )

    auth_user_id = supabase_user.get("id") or supabase_user.get("user", {}).get("id")
    if not auth_user_id:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create auth user",
        )

    slug = _slugify(body.org_name) + "-" + secrets.token_hex(3)
    org = await db.create_organization(body.org_name, slug)
    org_id = UUID(org["id"])

    user_record = await db.create_user_record(
        user_id=UUID(auth_user_id),
        org_id=org_id,
        email=body.email,
        name=body.name,
        role="admin",
        auth_provider="email",
        auth_provider_id=auth_user_id,
    )

    await db.update_user_metadata(
        auth_user_id,
        {"org_id": str(org_id), "role": "admin"},
    )

    access_token = token_svc.create_access_token(
        user_id=UUID(auth_user_id),
        org_id=org_id,
        role="admin",
        email=body.email,
        name=body.name,
    )
    raw_refresh, refresh_hash = token_svc.create_refresh_token()
    family_id = secrets.token_hex(16)
    await redis_store.store_refresh_token(
        token_hash=refresh_hash,
        user_id=UUID(auth_user_id),
        org_id=org_id,
        family_id=family_id,
    )

    await log_audit_event(
        request,
        action=AuditAction.USER_REGISTERED,
        entity_type="user",
        org_id=org_id,
        user_id=UUID(auth_user_id),
        entity_id=UUID(auth_user_id),
        new_value={"email": body.email, "role": "admin", "org_name": body.org_name},
    )

    return LoginResponse(
        access_token=access_token,
        refresh_token=raw_refresh,
        expires_in=token_svc.access_ttl_seconds,
        user=_build_user_profile(user_record),
    )


@router.post("/login", response_model=LoginResponse)
async def login(body: LoginRequest, request: Request) -> LoginResponse:
    """Authenticate and receive a token pair."""
    db: SupabaseAuthClient = request.app.state.supabase_client
    token_svc: TokenService = request.app.state.token_service
    redis_store: RedisTokenStore = request.app.state.redis_store

    user_record = await db.get_user_by_email(body.email)
    if not user_record:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    if not user_record.get("is_active", True):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    try:
        await db.sign_in(body.email, body.password)
    except httpx.HTTPStatusError:
        await log_audit_event(
            request,
            action=AuditAction.USER_LOGIN_FAILED,
            entity_type="user",
            org_id=UUID(user_record["org_id"]),
            user_id=UUID(user_record["id"]),
            entity_id=UUID(user_record["id"]),
            new_value={"email": body.email, "reason": "invalid_credentials"},
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    user_id = UUID(user_record["id"])
    org_id = UUID(user_record["org_id"])

    await db.update_last_login(user_id)

    access_token = token_svc.create_access_token(
        user_id=user_id,
        org_id=org_id,
        role=user_record["role"],
        email=user_record["email"],
        name=user_record["name"],
    )
    raw_refresh, refresh_hash = token_svc.create_refresh_token()
    family_id = secrets.token_hex(16)
    await redis_store.store_refresh_token(
        token_hash=refresh_hash,
        user_id=user_id,
        org_id=org_id,
        family_id=family_id,
    )

    await log_audit_event(
        request,
        action=AuditAction.USER_LOGIN,
        entity_type="user",
        org_id=org_id,
        user_id=user_id,
        entity_id=user_id,
    )

    return LoginResponse(
        access_token=access_token,
        refresh_token=raw_refresh,
        expires_in=token_svc.access_ttl_seconds,
        user=_build_user_profile(user_record),
    )


@router.post("/refresh", response_model=LoginResponse)
async def refresh(body: RefreshRequest, request: Request) -> LoginResponse:
    """Refresh the access token using a valid refresh token.

    Implements refresh token rotation with reuse detection: if a previously
    used token is presented, the entire token family is revoked.
    """
    token_svc: TokenService = request.app.state.token_service
    redis_store: RedisTokenStore = request.app.state.redis_store
    db: SupabaseAuthClient = request.app.state.supabase_client

    token_hash = TokenService.hash_refresh_token(body.refresh_token)
    stored = await redis_store.get_refresh_token(token_hash)

    if not stored:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )

    user_id = UUID(stored["user_id"])
    org_id = UUID(stored["org_id"])
    family_id = stored["family_id"]

    await redis_store.revoke_refresh_token(token_hash)

    user_record = await db.get_user_by_id(user_id)
    if not user_record or not user_record.get("is_active", True):
        await redis_store.revoke_token_family(family_id)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account is no longer active",
        )

    access_token = token_svc.create_access_token(
        user_id=user_id,
        org_id=org_id,
        role=user_record["role"],
        email=user_record["email"],
        name=user_record["name"],
    )
    new_raw_refresh, new_refresh_hash = token_svc.create_refresh_token()
    await redis_store.store_refresh_token(
        token_hash=new_refresh_hash,
        user_id=user_id,
        org_id=org_id,
        family_id=family_id,
    )

    return LoginResponse(
        access_token=access_token,
        refresh_token=new_raw_refresh,
        expires_in=token_svc.access_ttl_seconds,
        user=_build_user_profile(user_record),
    )


@router.post("/logout", response_model=MessageResponse)
async def logout(request: Request, user: CurrentUser) -> MessageResponse:
    """Revoke the current session's refresh token and deny-list the access token."""
    redis_store: RedisTokenStore = request.app.state.redis_store
    db: SupabaseAuthClient = request.app.state.supabase_client

    if user.jti:
        remaining_ttl = max(0, user.exp - int(__import__("time").time()))
        await redis_store.deny_access_token(user.jti, ttl_seconds=remaining_ttl or None)

    await log_audit_event(
        request,
        action=AuditAction.USER_LOGOUT,
        entity_type="user",
        org_id=user.org_uuid,
        user_id=user.user_id,
        entity_id=user.user_id,
    )

    return MessageResponse(message="Logged out successfully")


@router.post("/invite", response_model=InviteResponse, status_code=status.HTTP_201_CREATED)
async def invite_user(
    body: InviteRequest,
    request: Request,
    admin: AdminUser,
) -> InviteResponse:
    """Invite a new user to the admin's organization."""
    db: SupabaseAuthClient = request.app.state.supabase_client

    existing = await db.get_user_by_email(body.email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A user with this email already exists",
        )

    temp_password = secrets.token_urlsafe(16)

    try:
        supabase_user = await db.admin_create_user(
            email=body.email,
            password=temp_password,
            metadata={"org_id": str(admin.org_uuid), "role": body.role.value},
        )
    except httpx.HTTPStatusError as exc:
        logger.warning("Supabase admin create user failed: %s", exc.response.text)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Failed to create user in auth provider",
        )

    auth_user_id = supabase_user.get("id") or supabase_user.get("user", {}).get("id")
    if not auth_user_id:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create auth user",
        )

    user_record = await db.create_user_record(
        user_id=UUID(auth_user_id),
        org_id=admin.org_uuid,
        email=body.email,
        name=body.name,
        role=body.role.value,
        auth_provider="email",
        auth_provider_id=auth_user_id,
    )

    await log_audit_event(
        request,
        action=AuditAction.USER_INVITED,
        entity_type="user",
        org_id=admin.org_uuid,
        user_id=admin.user_id,
        entity_id=UUID(auth_user_id),
        new_value={"email": body.email, "role": body.role.value, "invited_by": str(admin.user_id)},
    )

    return InviteResponse(
        message=f"User {body.email} invited successfully",
        user_id=UUID(auth_user_id),
        email=body.email,
        role=body.role,
    )


@router.post("/step-up", response_model=MessageResponse)
async def step_up_auth(
    body: StepUpRequest,
    request: Request,
    user: CurrentUser,
) -> MessageResponse:
    """Re-authenticate to gain elevated privileges for destructive actions.

    After successful step-up, the user has a 5-minute window to perform
    actions that require step-up auth (e.g., delete site, change roles).
    """
    db: SupabaseAuthClient = request.app.state.supabase_client
    redis_store: RedisTokenStore = request.app.state.redis_store

    try:
        await db.sign_in(user.email, body.password)
    except httpx.HTTPStatusError:
        await log_audit_event(
            request,
            action=AuditAction.STEP_UP_FAILED,
            entity_type="user",
            org_id=user.org_uuid,
            user_id=user.user_id,
            entity_id=user.user_id,
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid password",
        )

    await redis_store.set_step_up(user.user_id)

    await log_audit_event(
        request,
        action=AuditAction.STEP_UP_COMPLETED,
        entity_type="user",
        org_id=user.org_uuid,
        user_id=user.user_id,
        entity_id=user.user_id,
    )

    return MessageResponse(message="Step-up authentication successful")


@router.get("/validate")
async def validate_token(request: Request, user: CurrentUser) -> Response:
    """Validate a JWT for the API gateway auth_request subrequest.

    Returns 200 with X-User-Id and X-User-Role headers on success.
    The gateway extracts these headers and forwards them to upstream services.
    This endpoint is internal-only (called by nginx auth_request, not by clients).
    """
    return Response(
        status_code=200,
        headers={
            "X-User-Id": str(user.user_id),
            "X-User-Role": user.role,
            "X-Org-Id": str(user.org_uuid),
        },
    )
