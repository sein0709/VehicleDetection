"""Redis client for token deny-list and refresh token storage.

Refresh tokens are stored as hashed values in Redis with TTL matching the
token lifetime. The deny-list holds revoked JTI values for the remaining
lifetime of the access token.
"""

from __future__ import annotations

import logging
from typing import Any
from uuid import UUID

import redis.asyncio as aioredis

from auth_service.settings import Settings
from auth_service.tokens import TokenService

logger = logging.getLogger(__name__)

REFRESH_KEY_PREFIX = "rt:"
DENY_KEY_PREFIX = "deny:jti:"
STEP_UP_KEY_PREFIX = "stepup:"
FAMILY_KEY_PREFIX = "rt_family:"


class RedisTokenStore:
    """Manages refresh tokens and the access-token deny-list in Redis."""

    def __init__(self, settings: Settings) -> None:
        self._redis: aioredis.Redis = aioredis.from_url(
            settings.redis_url, decode_responses=True
        )
        self._refresh_ttl = settings.refresh_token_expire_days * 86400
        self._access_ttl = settings.access_token_expire_minutes * 60
        self._step_up_ttl = settings.step_up_window_seconds

    async def close(self) -> None:
        await self._redis.aclose()

    # ── Refresh Token Storage ───────────────────────────────────────────────

    async def store_refresh_token(
        self,
        *,
        token_hash: str,
        user_id: UUID,
        org_id: UUID,
        family_id: str,
    ) -> None:
        """Store a hashed refresh token with user metadata."""
        key = f"{REFRESH_KEY_PREFIX}{token_hash}"
        await self._redis.hset(
            key,
            mapping={
                "user_id": str(user_id),
                "org_id": str(org_id),
                "family_id": family_id,
            },
        )
        await self._redis.expire(key, self._refresh_ttl)

        family_key = f"{FAMILY_KEY_PREFIX}{family_id}"
        await self._redis.sadd(family_key, token_hash)
        await self._redis.expire(family_key, self._refresh_ttl)

    async def get_refresh_token(self, token_hash: str) -> dict[str, str] | None:
        """Retrieve refresh token metadata. Returns None if expired/missing."""
        key = f"{REFRESH_KEY_PREFIX}{token_hash}"
        data = await self._redis.hgetall(key)
        return data if data else None

    async def revoke_refresh_token(self, token_hash: str) -> None:
        """Delete a single refresh token."""
        key = f"{REFRESH_KEY_PREFIX}{token_hash}"
        await self._redis.delete(key)

    async def revoke_token_family(self, family_id: str) -> None:
        """Revoke all tokens in a family (reuse detection)."""
        family_key = f"{FAMILY_KEY_PREFIX}{family_id}"
        members = await self._redis.smembers(family_key)
        if members:
            pipe = self._redis.pipeline()
            for token_hash in members:
                pipe.delete(f"{REFRESH_KEY_PREFIX}{token_hash}")
            pipe.delete(family_key)
            await pipe.execute()
        logger.warning("Revoked token family %s (%d tokens)", family_id, len(members or []))

    async def revoke_all_user_tokens(self, user_id: UUID) -> int:
        """Revoke all refresh tokens for a user. Returns count of revoked tokens.

        Scans for all refresh tokens belonging to the user. This is an
        expensive operation used only for force-logout / security events.
        """
        pattern = f"{REFRESH_KEY_PREFIX}*"
        revoked = 0
        async for key in self._redis.scan_iter(match=pattern, count=100):
            data = await self._redis.hgetall(key)
            if data and data.get("user_id") == str(user_id):
                await self._redis.delete(key)
                revoked += 1
        return revoked

    # ── Access Token Deny-List ──────────────────────────────────────────────

    async def deny_access_token(self, jti: str, ttl_seconds: int | None = None) -> None:
        """Add a JTI to the deny-list for the remaining token lifetime."""
        key = f"{DENY_KEY_PREFIX}{jti}"
        ttl = ttl_seconds or self._access_ttl
        await self._redis.setex(key, ttl, "1")

    async def is_token_denied(self, jti: str) -> bool:
        key = f"{DENY_KEY_PREFIX}{jti}"
        return await self._redis.exists(key) > 0

    # ── Step-Up Auth ────────────────────────────────────────────────────────

    async def set_step_up(self, user_id: UUID) -> None:
        """Record that the user has completed step-up authentication."""
        key = f"{STEP_UP_KEY_PREFIX}{user_id}"
        await self._redis.setex(key, self._step_up_ttl, "1")

    async def has_step_up(self, user_id: UUID) -> bool:
        key = f"{STEP_UP_KEY_PREFIX}{user_id}"
        return await self._redis.exists(key) > 0

    async def clear_step_up(self, user_id: UUID) -> None:
        key = f"{STEP_UP_KEY_PREFIX}{user_id}"
        await self._redis.delete(key)
