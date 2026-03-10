"""JWT token creation and validation.

Access tokens are short-lived JWTs (15 min) containing user claims.
Refresh tokens are opaque strings stored server-side with rotation and
reuse detection.
"""

from __future__ import annotations

import hashlib
import logging
import secrets
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID

import jwt

from auth_service.settings import Settings

logger = logging.getLogger(__name__)


class TokenClaims:
    """Parsed and validated JWT access token claims."""

    __slots__ = ("sub", "org_id", "role", "email", "name", "step_up_at", "exp", "iat", "jti")

    def __init__(self, payload: dict[str, Any]) -> None:
        self.sub: str = payload["sub"]
        self.org_id: str = payload["org_id"]
        self.role: str = payload["role"]
        self.email: str = payload.get("email", "")
        self.name: str = payload.get("name", "")
        self.jti: str = payload.get("jti", "")
        self.exp: int = payload.get("exp", 0)
        self.iat: int = payload.get("iat", 0)

        step_up_raw = payload.get("step_up_at")
        if step_up_raw is not None:
            self.step_up_at: datetime | None = datetime.fromtimestamp(step_up_raw, tz=UTC)
        else:
            self.step_up_at = None

    @property
    def user_id(self) -> UUID:
        return UUID(self.sub)

    @property
    def org_uuid(self) -> UUID:
        return UUID(self.org_id)

    def has_step_up(self, window_seconds: int) -> bool:
        if self.step_up_at is None:
            return False
        elapsed = (datetime.now(tz=UTC) - self.step_up_at).total_seconds()
        return elapsed <= window_seconds


class TokenService:
    """Creates and validates JWT access tokens and opaque refresh tokens."""

    def __init__(self, settings: Settings) -> None:
        self._secret = settings.jwt_secret
        self._algorithm = settings.jwt_algorithm
        self._access_ttl = timedelta(minutes=settings.access_token_expire_minutes)
        self._refresh_ttl = timedelta(days=settings.refresh_token_expire_days)

    def create_access_token(
        self,
        *,
        user_id: UUID,
        org_id: UUID,
        role: str,
        email: str,
        name: str,
        step_up_at: datetime | None = None,
    ) -> str:
        now = datetime.now(tz=UTC)
        payload: dict[str, Any] = {
            "sub": str(user_id),
            "org_id": str(org_id),
            "role": role,
            "email": email,
            "name": name,
            "iat": int(now.timestamp()),
            "exp": int((now + self._access_ttl).timestamp()),
            "jti": secrets.token_hex(16),
            "iss": "greyeye-auth",
            "aud": "greyeye-api",
        }
        if step_up_at is not None:
            payload["step_up_at"] = int(step_up_at.timestamp())
        return jwt.encode(payload, self._secret, algorithm=self._algorithm)

    def decode_access_token(self, token: str) -> TokenClaims:
        """Decode and validate an access token. Raises jwt.PyJWTError on failure."""
        payload = jwt.decode(
            token,
            self._secret,
            algorithms=[self._algorithm],
            audience="greyeye-api",
            issuer="greyeye-auth",
        )
        return TokenClaims(payload)

    def create_refresh_token(self) -> tuple[str, str]:
        """Return (raw_token, hashed_token). Store the hash, send the raw."""
        raw = secrets.token_urlsafe(48)
        hashed = self._hash_refresh_token(raw)
        return raw, hashed

    @property
    def refresh_ttl_seconds(self) -> int:
        return int(self._refresh_ttl.total_seconds())

    @property
    def access_ttl_seconds(self) -> int:
        return int(self._access_ttl.total_seconds())

    @staticmethod
    def _hash_refresh_token(token: str) -> str:
        return hashlib.sha256(token.encode()).hexdigest()

    @staticmethod
    def hash_refresh_token(token: str) -> str:
        return hashlib.sha256(token.encode()).hexdigest()
