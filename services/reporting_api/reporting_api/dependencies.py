"""FastAPI dependency injection for authentication and authorization.

Reuses the same JWT validation logic as the auth service to extract
the current user from the Authorization header.
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from typing import Annotated
from uuid import UUID

import jwt
from fastapi import Depends, Header, HTTPException, Request, status

from reporting_api.settings import Settings, get_settings
from shared_contracts.enums import UserRole

logger = logging.getLogger(__name__)

ROLE_HIERARCHY: dict[UserRole, int] = {
    UserRole.ADMIN: 40,
    UserRole.OPERATOR: 30,
    UserRole.ANALYST: 20,
    UserRole.VIEWER: 10,
}


class TokenClaims:
    """Parsed JWT access token claims (mirrors auth_service.tokens.TokenClaims)."""

    __slots__ = ("email", "exp", "iat", "jti", "name", "org_id", "role", "sub")

    def __init__(self, payload: dict) -> None:
        self.sub: str = payload["sub"]
        self.org_id: str = payload["org_id"]
        self.role: str = payload["role"]
        self.email: str = payload.get("email", "")
        self.name: str = payload.get("name", "")
        self.jti: str = payload.get("jti", "")
        self.exp: int = payload.get("exp", 0)
        self.iat: int = payload.get("iat", 0)

    @property
    def user_id(self) -> UUID:
        return UUID(self.sub)

    @property
    def org_uuid(self) -> UUID:
        return UUID(self.org_id)


async def get_current_user(
    request: Request,
    authorization: Annotated[str | None, Header()] = None,
) -> TokenClaims:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = authorization.removeprefix("Bearer ").strip()
    settings = _get_request_settings(request)

    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
            audience="greyeye-api",
            issuer="greyeye-auth",
        )
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

    return TokenClaims(payload)


def _get_request_settings(request: Request) -> Settings:
    settings = getattr(request.app.state, "settings", None)
    if isinstance(settings, Settings):
        return settings
    return get_settings()


CurrentUser = Annotated[TokenClaims, Depends(get_current_user)]


def require_role(minimum_role: UserRole) -> Callable:
    async def _check(user: CurrentUser) -> TokenClaims:
        user_role = UserRole(user.role)
        user_level = ROLE_HIERARCHY.get(user_role, 0)
        required_level = ROLE_HIERARCHY.get(minimum_role, 0)
        if user_level < required_level:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires at least {minimum_role.value} role",
            )
        return user

    return _check


AdminUser = Annotated[TokenClaims, Depends(require_role(UserRole.ADMIN))]
OperatorUser = Annotated[TokenClaims, Depends(require_role(UserRole.OPERATOR))]
