"""FastAPI dependency injection for authentication and authorization.

Provides reusable dependencies that extract and validate the current user
from the Authorization header, enforce RBAC permissions, and check step-up
authentication status.
"""

from __future__ import annotations

import logging
from typing import Annotated, Callable
from uuid import UUID

import jwt
from fastapi import Depends, Header, HTTPException, Request, status

from auth_service.rbac import Permission, has_minimum_role, has_permission, requires_step_up
from auth_service.redis_client import RedisTokenStore
from auth_service.settings import Settings, get_settings
from auth_service.supabase_client import SupabaseAuthClient
from auth_service.tokens import TokenClaims, TokenService
from shared_contracts.enums import UserRole

logger = logging.getLogger(__name__)


def _get_token_service() -> TokenService:
    return TokenService(get_settings())


async def get_current_user(
    request: Request,
    authorization: Annotated[str | None, Header()] = None,
) -> TokenClaims:
    """Extract and validate the JWT access token from the Authorization header."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = authorization.removeprefix("Bearer ").strip()
    token_service: TokenService = request.app.state.token_service
    redis_store: RedisTokenStore = request.app.state.redis_store

    try:
        claims = token_service.decode_access_token(token)
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Access token has expired",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid access token: {exc}",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if claims.jti and await redis_store.is_token_denied(claims.jti):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has been revoked",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return claims


CurrentUser = Annotated[TokenClaims, Depends(get_current_user)]


def require_role(minimum_role: UserRole) -> Callable:
    """Dependency factory that enforces a minimum role level."""

    async def _check(user: CurrentUser) -> TokenClaims:
        user_role = UserRole(user.role)
        if not has_minimum_role(user_role, minimum_role):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires at least {minimum_role.value} role",
            )
        return user

    return _check


def require_permission(permission: Permission) -> Callable:
    """Dependency factory that enforces a specific permission."""

    async def _check(
        request: Request,
        user: CurrentUser,
    ) -> TokenClaims:
        user_role = UserRole(user.role)
        if not has_permission(user_role, permission):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Missing required permission: {permission.value}",
            )

        if requires_step_up(permission):
            redis_store: RedisTokenStore = request.app.state.redis_store
            if not await redis_store.has_step_up(user.user_id):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Step-up authentication required. Please re-authenticate.",
                )

        return user

    return _check


AdminUser = Annotated[TokenClaims, Depends(require_role(UserRole.ADMIN))]
OperatorUser = Annotated[TokenClaims, Depends(require_role(UserRole.OPERATOR))]
AnalystUser = Annotated[TokenClaims, Depends(require_role(UserRole.ANALYST))]
