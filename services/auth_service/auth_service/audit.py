"""Audit logging helper for recording permission and auth events.

All permission changes (role grant/revoke, org membership changes) are
written to the audit_logs table. This module provides a high-level API
that extracts request context (IP, user-agent) automatically.
"""

from __future__ import annotations

import logging
from typing import Any
from uuid import UUID

from fastapi import Request

from auth_service.supabase_client import SupabaseAuthClient

logger = logging.getLogger(__name__)


class AuditAction:
    USER_REGISTERED = "user.registered"
    USER_LOGIN = "user.login"
    USER_LOGIN_FAILED = "user.login_failed"
    USER_LOGOUT = "user.logout"
    USER_INVITED = "user.invited"
    USER_ROLE_CHANGED = "user.role_changed"
    USER_DEACTIVATED = "user.deactivated"
    TOKEN_REFRESHED = "token.refreshed"
    TOKEN_FAMILY_REVOKED = "token.family_revoked"
    STEP_UP_COMPLETED = "auth.step_up_completed"
    STEP_UP_FAILED = "auth.step_up_failed"
    FORCE_LOGOUT = "auth.force_logout"


def _client_ip(request: Request) -> str | None:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client:
        return request.client.host
    return None


async def log_audit_event(
    request: Request,
    *,
    action: str,
    entity_type: str,
    org_id: UUID,
    user_id: UUID | None = None,
    entity_id: UUID | None = None,
    old_value: dict[str, Any] | None = None,
    new_value: dict[str, Any] | None = None,
) -> None:
    """Write an audit log entry, extracting IP and user-agent from the request."""
    db: SupabaseAuthClient = request.app.state.supabase_client
    await db.write_audit_log(
        org_id=org_id,
        user_id=user_id,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        old_value=old_value,
        new_value=new_value,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
