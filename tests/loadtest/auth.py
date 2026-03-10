"""JWT token generation for load test users."""

from __future__ import annotations

import secrets
from datetime import UTC, datetime, timedelta

import jwt

from tests.loadtest.config import get_settings


def make_token(
    role: str = "operator",
    user_id: str = "user_loadtest",
    org_id: str | None = None,
) -> str:
    settings = get_settings()
    now = datetime.now(tz=UTC)
    payload = {
        "sub": user_id,
        "org_id": org_id or settings.org_id,
        "role": role,
        "email": f"loadtest-{role}@greyeye.test",
        "name": f"Load Test {role.title()}",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(hours=4)).timestamp()),
        "jti": secrets.token_hex(16),
        "iss": "greyeye-auth",
        "aud": "greyeye-api",
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def operator_headers(user_id: str = "user_loadtest") -> dict[str, str]:
    return {"Authorization": f"Bearer {make_token('operator', user_id)}"}


def viewer_headers(user_id: str = "user_loadtest_viewer") -> dict[str, str]:
    return {"Authorization": f"Bearer {make_token('viewer', user_id)}"}
