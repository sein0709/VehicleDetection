"""Tests for JWT token creation, validation, and refresh token management."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import jwt
import pytest

from auth_service.settings import Settings
from auth_service.tokens import TokenClaims, TokenService

ORG_ID = UUID("00000000-0000-0000-0000-000000000001")
USER_ID = UUID("00000000-0000-0000-0000-000000000010")


@pytest.fixture
def svc() -> TokenService:
    settings = Settings(
        jwt_secret="test-secret",
        jwt_algorithm="HS256",
        access_token_expire_minutes=15,
        refresh_token_expire_days=7,
    )
    return TokenService(settings)


class TestAccessTokenCreation:
    def test_creates_valid_jwt(self, svc: TokenService):
        token = svc.create_access_token(
            user_id=USER_ID, org_id=ORG_ID, role="admin",
            email="a@b.com", name="Alice",
        )
        claims = svc.decode_access_token(token)
        assert claims.sub == str(USER_ID)
        assert claims.org_id == str(ORG_ID)
        assert claims.role == "admin"
        assert claims.email == "a@b.com"
        assert claims.name == "Alice"

    def test_includes_standard_claims(self, svc: TokenService):
        token = svc.create_access_token(
            user_id=USER_ID, org_id=ORG_ID, role="viewer",
            email="v@b.com", name="Viewer",
        )
        raw = jwt.decode(token, "test-secret", algorithms=["HS256"], audience="greyeye-api")
        assert raw["iss"] == "greyeye-auth"
        assert raw["aud"] == "greyeye-api"
        assert "jti" in raw
        assert "iat" in raw
        assert "exp" in raw
        assert raw["exp"] - raw["iat"] == 900  # 15 min

    def test_step_up_claim(self, svc: TokenService):
        now = datetime.now(tz=UTC)
        token = svc.create_access_token(
            user_id=USER_ID, org_id=ORG_ID, role="admin",
            email="a@b.com", name="Alice", step_up_at=now,
        )
        claims = svc.decode_access_token(token)
        assert claims.step_up_at is not None
        assert abs((claims.step_up_at - now).total_seconds()) < 2

    def test_no_step_up_by_default(self, svc: TokenService):
        token = svc.create_access_token(
            user_id=USER_ID, org_id=ORG_ID, role="admin",
            email="a@b.com", name="Alice",
        )
        claims = svc.decode_access_token(token)
        assert claims.step_up_at is None


class TestAccessTokenValidation:
    def test_rejects_expired_token(self, svc: TokenService):
        payload = {
            "sub": str(USER_ID), "org_id": str(ORG_ID), "role": "admin",
            "email": "a@b.com", "name": "Alice",
            "iat": int((datetime.now(tz=UTC) - timedelta(hours=1)).timestamp()),
            "exp": int((datetime.now(tz=UTC) - timedelta(minutes=1)).timestamp()),
            "jti": "test", "iss": "greyeye-auth", "aud": "greyeye-api",
        }
        token = jwt.encode(payload, "test-secret", algorithm="HS256")
        with pytest.raises(jwt.ExpiredSignatureError):
            svc.decode_access_token(token)

    def test_rejects_wrong_secret(self, svc: TokenService):
        payload = {
            "sub": str(USER_ID), "org_id": str(ORG_ID), "role": "admin",
            "iat": int(datetime.now(tz=UTC).timestamp()),
            "exp": int((datetime.now(tz=UTC) + timedelta(hours=1)).timestamp()),
            "jti": "test", "iss": "greyeye-auth", "aud": "greyeye-api",
        }
        token = jwt.encode(payload, "wrong-secret", algorithm="HS256")
        with pytest.raises(jwt.InvalidSignatureError):
            svc.decode_access_token(token)

    def test_rejects_wrong_audience(self, svc: TokenService):
        payload = {
            "sub": str(USER_ID), "org_id": str(ORG_ID), "role": "admin",
            "iat": int(datetime.now(tz=UTC).timestamp()),
            "exp": int((datetime.now(tz=UTC) + timedelta(hours=1)).timestamp()),
            "jti": "test", "iss": "greyeye-auth", "aud": "wrong-audience",
        }
        token = jwt.encode(payload, "test-secret", algorithm="HS256")
        with pytest.raises(jwt.InvalidAudienceError):
            svc.decode_access_token(token)

    def test_rejects_wrong_issuer(self, svc: TokenService):
        payload = {
            "sub": str(USER_ID), "org_id": str(ORG_ID), "role": "admin",
            "iat": int(datetime.now(tz=UTC).timestamp()),
            "exp": int((datetime.now(tz=UTC) + timedelta(hours=1)).timestamp()),
            "jti": "test", "iss": "wrong-issuer", "aud": "greyeye-api",
        }
        token = jwt.encode(payload, "test-secret", algorithm="HS256")
        with pytest.raises(jwt.InvalidIssuerError):
            svc.decode_access_token(token)


class TestTokenClaims:
    def test_user_id_property(self):
        claims = TokenClaims({"sub": str(USER_ID), "org_id": str(ORG_ID), "role": "admin"})
        assert claims.user_id == USER_ID

    def test_org_uuid_property(self):
        claims = TokenClaims({"sub": str(USER_ID), "org_id": str(ORG_ID), "role": "admin"})
        assert claims.org_uuid == ORG_ID

    def test_has_step_up_within_window(self):
        now = datetime.now(tz=UTC)
        claims = TokenClaims({
            "sub": str(USER_ID), "org_id": str(ORG_ID), "role": "admin",
            "step_up_at": int(now.timestamp()),
        })
        assert claims.has_step_up(300) is True

    def test_has_step_up_expired(self):
        old = datetime.now(tz=UTC) - timedelta(minutes=10)
        claims = TokenClaims({
            "sub": str(USER_ID), "org_id": str(ORG_ID), "role": "admin",
            "step_up_at": int(old.timestamp()),
        })
        assert claims.has_step_up(300) is False

    def test_has_step_up_none(self):
        claims = TokenClaims({"sub": str(USER_ID), "org_id": str(ORG_ID), "role": "admin"})
        assert claims.has_step_up(300) is False


class TestRefreshToken:
    def test_creates_unique_tokens(self, svc: TokenService):
        raw1, hash1 = svc.create_refresh_token()
        raw2, hash2 = svc.create_refresh_token()
        assert raw1 != raw2
        assert hash1 != hash2

    def test_hash_is_deterministic(self, svc: TokenService):
        raw, _ = svc.create_refresh_token()
        h1 = TokenService.hash_refresh_token(raw)
        h2 = TokenService.hash_refresh_token(raw)
        assert h1 == h2

    def test_raw_and_hash_differ(self, svc: TokenService):
        raw, hashed = svc.create_refresh_token()
        assert raw != hashed

    def test_ttl_values(self, svc: TokenService):
        assert svc.access_ttl_seconds == 900
        assert svc.refresh_ttl_seconds == 7 * 86400
