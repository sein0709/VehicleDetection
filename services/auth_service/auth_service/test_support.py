"""Test-only helpers for auth service tests."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from uuid import UUID

TEST_ORG_ID = UUID("00000000-0000-0000-0000-000000000001")
TEST_USER_ID = UUID("00000000-0000-0000-0000-000000000010")
TEST_ADMIN_ID = UUID("00000000-0000-0000-0000-000000000020")


def make_user_record(
    user_id: UUID = TEST_USER_ID,
    org_id: UUID = TEST_ORG_ID,
    role: str = "operator",
    email: str = "operator@example.com",
    name: str = "Test Operator",
    is_active: bool = True,
) -> dict[str, Any]:
    return {
        "id": str(user_id),
        "org_id": str(org_id),
        "email": email,
        "name": name,
        "role": role,
        "auth_provider": "email",
        "auth_provider_id": str(user_id),
        "is_active": is_active,
        "last_login_at": None,
        "created_at": datetime.now(tz=UTC).isoformat(),
        "updated_at": datetime.now(tz=UTC).isoformat(),
    }
