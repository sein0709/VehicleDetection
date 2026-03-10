"""Supabase client wrapper for auth operations and database access.

Wraps the Supabase Python SDK to provide typed methods for user management,
authentication, and direct database queries for the users/orgs/audit tables.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import Any
from uuid import UUID, uuid4

import httpx
from supabase import Client, create_client

from auth_service.settings import Settings

logger = logging.getLogger(__name__)


class SupabaseAuthClient:
    """Thin wrapper around the Supabase SDK focused on auth + user management."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._client: Client = create_client(
            settings.supabase_url,
            settings.supabase_service_role_key or settings.supabase_anon_key,
        )
        self._http = httpx.AsyncClient(
            base_url=settings.supabase_url,
            headers={
                "apikey": settings.supabase_service_role_key or settings.supabase_anon_key,
                "Authorization": f"Bearer {settings.supabase_service_role_key}",
            },
            timeout=15.0,
        )

    async def close(self) -> None:
        await self._http.aclose()

    # ── Supabase Auth Operations ────────────────────────────────────────────

    async def sign_up(self, email: str, password: str) -> dict[str, Any]:
        """Register a new user via Supabase Auth."""
        resp = await self._http.post(
            "/auth/v1/signup",
            json={"email": email, "password": password},
        )
        resp.raise_for_status()
        return resp.json()

    async def sign_in(self, email: str, password: str) -> dict[str, Any]:
        """Authenticate a user and get Supabase session tokens."""
        resp = await self._http.post(
            "/auth/v1/token",
            params={"grant_type": "password"},
            json={"email": email, "password": password},
        )
        resp.raise_for_status()
        return resp.json()

    async def refresh_session(self, refresh_token: str) -> dict[str, Any]:
        """Refresh an access token using a Supabase refresh token."""
        resp = await self._http.post(
            "/auth/v1/token",
            params={"grant_type": "refresh_token"},
            json={"refresh_token": refresh_token},
        )
        resp.raise_for_status()
        return resp.json()

    async def sign_out(self, access_token: str) -> None:
        """Revoke a user's session."""
        await self._http.post(
            "/auth/v1/logout",
            headers={"Authorization": f"Bearer {access_token}"},
        )

    async def get_user(self, access_token: str) -> dict[str, Any]:
        """Get the authenticated user from Supabase Auth."""
        resp = await self._http.get(
            "/auth/v1/user",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        resp.raise_for_status()
        return resp.json()

    async def update_user_metadata(
        self, user_id: str, metadata: dict[str, Any]
    ) -> dict[str, Any]:
        """Update app_metadata on a Supabase Auth user (service-role only)."""
        resp = await self._http.put(
            f"/auth/v1/admin/users/{user_id}",
            json={"app_metadata": metadata},
        )
        resp.raise_for_status()
        return resp.json()

    async def admin_create_user(
        self, email: str, password: str, metadata: dict[str, Any]
    ) -> dict[str, Any]:
        """Create a user via the admin API (for invites)."""
        resp = await self._http.post(
            "/auth/v1/admin/users",
            json={
                "email": email,
                "password": password,
                "email_confirm": True,
                "app_metadata": metadata,
            },
        )
        resp.raise_for_status()
        return resp.json()

    # ── Direct Database Operations ──────────────────────────────────────────

    def _table(self, name: str):
        return self._client.table(name)

    async def create_organization(self, name: str, slug: str) -> dict[str, Any]:
        result = (
            self._table("organizations")
            .insert({"name": name, "slug": slug})
            .execute()
        )
        return result.data[0]

    async def get_organization(self, org_id: UUID) -> dict[str, Any] | None:
        result = (
            self._table("organizations")
            .select("*")
            .eq("id", str(org_id))
            .maybe_single()
            .execute()
        )
        return result.data

    async def create_user_record(
        self,
        *,
        user_id: UUID,
        org_id: UUID,
        email: str,
        name: str,
        role: str,
        auth_provider: str = "email",
        auth_provider_id: str | None = None,
    ) -> dict[str, Any]:
        result = (
            self._table("users")
            .insert(
                {
                    "id": str(user_id),
                    "org_id": str(org_id),
                    "email": email,
                    "name": name,
                    "role": role,
                    "auth_provider": auth_provider,
                    "auth_provider_id": auth_provider_id,
                }
            )
            .execute()
        )
        return result.data[0]

    async def get_user_by_id(self, user_id: UUID) -> dict[str, Any] | None:
        result = (
            self._table("users")
            .select("*")
            .eq("id", str(user_id))
            .maybe_single()
            .execute()
        )
        return result.data

    async def get_user_by_email(self, email: str) -> dict[str, Any] | None:
        result = (
            self._table("users")
            .select("*")
            .eq("email", email)
            .maybe_single()
            .execute()
        )
        return result.data

    async def get_users_by_org(self, org_id: UUID) -> list[dict[str, Any]]:
        result = (
            self._table("users")
            .select("*")
            .eq("org_id", str(org_id))
            .execute()
        )
        return result.data

    async def update_user_role(
        self, user_id: UUID, role: str
    ) -> dict[str, Any] | None:
        result = (
            self._table("users")
            .update({"role": role, "updated_at": datetime.now(tz=UTC).isoformat()})
            .eq("id", str(user_id))
            .execute()
        )
        return result.data[0] if result.data else None

    async def update_last_login(self, user_id: UUID) -> None:
        self._table("users").update(
            {"last_login_at": datetime.now(tz=UTC).isoformat()}
        ).eq("id", str(user_id)).execute()

    async def deactivate_user(self, user_id: UUID) -> None:
        self._table("users").update(
            {"is_active": False, "updated_at": datetime.now(tz=UTC).isoformat()}
        ).eq("id", str(user_id)).execute()

    # ── Audit Logging ───────────────────────────────────────────────────────

    async def write_audit_log(
        self,
        *,
        org_id: UUID,
        user_id: UUID | None,
        action: str,
        entity_type: str,
        entity_id: UUID | None = None,
        old_value: dict[str, Any] | None = None,
        new_value: dict[str, Any] | None = None,
        ip_address: str | None = None,
        user_agent: str | None = None,
    ) -> None:
        row: dict[str, Any] = {
            "id": str(uuid4()),
            "org_id": str(org_id),
            "action": action,
            "entity_type": entity_type,
        }
        if user_id is not None:
            row["user_id"] = str(user_id)
        if entity_id is not None:
            row["entity_id"] = str(entity_id)
        if old_value is not None:
            row["old_value"] = old_value
        if new_value is not None:
            row["new_value"] = new_value
        if ip_address is not None:
            row["ip_address"] = ip_address
        if user_agent is not None:
            row["user_agent"] = user_agent

        try:
            self._table("audit_logs").insert(row).execute()
        except Exception:
            logger.exception("Failed to write audit log: %s", action)
