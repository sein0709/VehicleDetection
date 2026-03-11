"""Tests for auth route handlers: register, login, refresh, logout, invite, step-up."""

from __future__ import annotations

import secrets
from datetime import UTC, datetime
from unittest.mock import AsyncMock
from uuid import UUID, uuid4

import httpx
import pytest
from fastapi.testclient import TestClient

from auth_service.tokens import TokenService

from auth_service.test_support import (
    TEST_ADMIN_ID,
    TEST_ORG_ID,
    TEST_USER_ID,
    make_user_record as _make_user_record,
)


class TestRegister:
    def test_successful_registration(self, client: TestClient, mock_supabase: AsyncMock):
        auth_user_id = str(uuid4())
        mock_supabase.get_user_by_email.return_value = None
        mock_supabase.sign_up.return_value = {"id": auth_user_id}
        mock_supabase.create_organization.return_value = {"id": str(TEST_ORG_ID)}
        mock_supabase.create_user_record.return_value = _make_user_record(
            user_id=UUID(auth_user_id), role="admin", email="new@example.com", name="New User",
        )
        mock_supabase.update_user_metadata.return_value = {}

        resp = client.post("/v1/auth/register", json={
            "email": "new@example.com",
            "password": "strongpassword123",
            "name": "New User",
            "org_name": "Test Org",
        })

        assert resp.status_code == 201
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "Bearer"
        assert data["user"]["email"] == "new@example.com"
        assert data["user"]["role"] == "admin"

    def test_duplicate_email_returns_409(self, client: TestClient, mock_supabase: AsyncMock):
        mock_supabase.get_user_by_email.return_value = _make_user_record()

        resp = client.post("/v1/auth/register", json={
            "email": "existing@example.com",
            "password": "strongpassword123",
            "name": "Duplicate",
            "org_name": "Test Org",
        })

        assert resp.status_code == 409

    def test_weak_password_returns_400(self, client: TestClient):
        resp = client.post("/v1/auth/register", json={
            "email": "new@example.com",
            "password": "short",
            "name": "New User",
            "org_name": "Test Org",
        })
        assert resp.status_code == 400
        assert resp.json()["error"]["code"] == "VALIDATION_ERROR"

    def test_invalid_email_returns_400(self, client: TestClient):
        resp = client.post("/v1/auth/register", json={
            "email": "not-an-email",
            "password": "strongpassword123",
            "name": "New User",
            "org_name": "Test Org",
        })
        assert resp.status_code == 400
        assert resp.json()["error"]["code"] == "VALIDATION_ERROR"

    def test_supabase_signup_failure(self, client: TestClient, mock_supabase: AsyncMock):
        mock_supabase.get_user_by_email.return_value = None
        mock_supabase.sign_up.side_effect = httpx.HTTPStatusError(
            "Bad Request",
            request=httpx.Request("POST", "http://test"),
            response=httpx.Response(400, text="weak password"),
        )

        resp = client.post("/v1/auth/register", json={
            "email": "new@example.com",
            "password": "strongpassword123",
            "name": "New User",
            "org_name": "Test Org",
        })

        assert resp.status_code == 422


class TestLogin:
    def test_successful_login(self, client: TestClient, mock_supabase: AsyncMock):
        user = _make_user_record()
        mock_supabase.get_user_by_email.return_value = user
        mock_supabase.sign_in.return_value = {"access_token": "supabase-token"}
        mock_supabase.update_last_login.return_value = None

        resp = client.post("/v1/auth/login", json={
            "email": "operator@example.com",
            "password": "correctpassword",
        })

        assert resp.status_code == 200
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["user"]["role"] == "operator"

    def test_unknown_email_returns_401(self, client: TestClient, mock_supabase: AsyncMock):
        mock_supabase.get_user_by_email.return_value = None

        resp = client.post("/v1/auth/login", json={
            "email": "unknown@example.com",
            "password": "somepassword",
        })

        assert resp.status_code == 401

    def test_wrong_password_returns_401(self, client: TestClient, mock_supabase: AsyncMock):
        mock_supabase.get_user_by_email.return_value = _make_user_record()
        mock_supabase.sign_in.side_effect = httpx.HTTPStatusError(
            "Unauthorized",
            request=httpx.Request("POST", "http://test"),
            response=httpx.Response(401),
        )

        resp = client.post("/v1/auth/login", json={
            "email": "operator@example.com",
            "password": "wrongpassword",
        })

        assert resp.status_code == 401

    def test_deactivated_user_returns_403(self, client: TestClient, mock_supabase: AsyncMock):
        mock_supabase.get_user_by_email.return_value = _make_user_record(is_active=False)

        resp = client.post("/v1/auth/login", json={
            "email": "operator@example.com",
            "password": "correctpassword",
        })

        assert resp.status_code == 403

    def test_login_records_audit_on_failure(self, client: TestClient, mock_supabase: AsyncMock):
        mock_supabase.get_user_by_email.return_value = _make_user_record()
        mock_supabase.sign_in.side_effect = httpx.HTTPStatusError(
            "Unauthorized",
            request=httpx.Request("POST", "http://test"),
            response=httpx.Response(401),
        )

        client.post("/v1/auth/login", json={
            "email": "operator@example.com",
            "password": "wrongpassword",
        })

        mock_supabase.write_audit_log.assert_called_once()
        call_kwargs = mock_supabase.write_audit_log.call_args.kwargs
        assert call_kwargs["action"] == "user.login_failed"


class TestRefresh:
    def test_successful_refresh(
        self, client: TestClient, mock_supabase: AsyncMock, mock_redis: AsyncMock,
        token_service: TokenService,
    ):
        raw_token = "test-refresh-token"
        token_hash = TokenService.hash_refresh_token(raw_token)
        family_id = "test-family"

        mock_redis.get_refresh_token.return_value = {
            "user_id": str(TEST_USER_ID),
            "org_id": str(TEST_ORG_ID),
            "family_id": family_id,
        }
        mock_supabase.get_user_by_id.return_value = _make_user_record()

        resp = client.post("/v1/auth/refresh", json={"refresh_token": raw_token})

        assert resp.status_code == 200
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["refresh_token"] != raw_token  # rotated
        mock_redis.revoke_refresh_token.assert_called_once_with(token_hash)
        mock_redis.store_refresh_token.assert_called_once()

    def test_invalid_refresh_token_returns_401(
        self, client: TestClient, mock_redis: AsyncMock,
    ):
        mock_redis.get_refresh_token.return_value = None

        resp = client.post("/v1/auth/refresh", json={"refresh_token": "invalid-token"})

        assert resp.status_code == 401

    def test_deactivated_user_revokes_family(
        self, client: TestClient, mock_supabase: AsyncMock, mock_redis: AsyncMock,
    ):
        family_id = "test-family"
        mock_redis.get_refresh_token.return_value = {
            "user_id": str(TEST_USER_ID),
            "org_id": str(TEST_ORG_ID),
            "family_id": family_id,
        }
        mock_supabase.get_user_by_id.return_value = _make_user_record(is_active=False)

        resp = client.post("/v1/auth/refresh", json={"refresh_token": "some-token"})

        assert resp.status_code == 401
        mock_redis.revoke_token_family.assert_called_once_with(family_id)


class TestLogout:
    def test_successful_logout(
        self, client: TestClient, operator_headers: dict, mock_redis: AsyncMock,
    ):
        resp = client.post("/v1/auth/logout", headers=operator_headers)

        assert resp.status_code == 200
        assert resp.json()["message"] == "Logged out successfully"
        mock_redis.deny_access_token.assert_called_once()

    def test_logout_without_token_returns_401(self, client: TestClient):
        resp = client.post("/v1/auth/logout")
        assert resp.status_code == 401


class TestInvite:
    def test_admin_can_invite(
        self, client: TestClient, admin_headers: dict, mock_supabase: AsyncMock,
    ):
        new_user_id = str(uuid4())
        mock_supabase.get_user_by_email.return_value = None
        mock_supabase.admin_create_user.return_value = {"id": new_user_id}
        mock_supabase.create_user_record.return_value = _make_user_record(
            user_id=UUID(new_user_id), role="analyst", email="invited@example.com",
        )

        resp = client.post("/v1/auth/invite", headers=admin_headers, json={
            "email": "invited@example.com",
            "name": "Invited User",
            "role": "analyst",
        })

        assert resp.status_code == 201
        data = resp.json()
        assert data["email"] == "invited@example.com"
        assert data["role"] == "analyst"

    def test_operator_cannot_invite(
        self, client: TestClient, operator_headers: dict,
    ):
        resp = client.post("/v1/auth/invite", headers=operator_headers, json={
            "email": "invited@example.com",
            "name": "Invited User",
            "role": "viewer",
        })

        assert resp.status_code == 403

    def test_viewer_cannot_invite(
        self, client: TestClient, viewer_headers: dict,
    ):
        resp = client.post("/v1/auth/invite", headers=viewer_headers, json={
            "email": "invited@example.com",
            "name": "Invited User",
            "role": "viewer",
        })

        assert resp.status_code == 403

    def test_invite_duplicate_email_returns_409(
        self, client: TestClient, admin_headers: dict, mock_supabase: AsyncMock,
    ):
        mock_supabase.get_user_by_email.return_value = _make_user_record()

        resp = client.post("/v1/auth/invite", headers=admin_headers, json={
            "email": "existing@example.com",
            "name": "Duplicate",
            "role": "viewer",
        })

        assert resp.status_code == 409


class TestStepUp:
    def test_successful_step_up(
        self, client: TestClient, operator_headers: dict,
        mock_supabase: AsyncMock, mock_redis: AsyncMock,
    ):
        mock_supabase.sign_in.return_value = {"access_token": "ok"}

        resp = client.post("/v1/auth/step-up", headers=operator_headers, json={
            "password": "correctpassword",
        })

        assert resp.status_code == 200
        assert resp.json()["message"] == "Step-up authentication successful"
        mock_redis.set_step_up.assert_called_once()

    def test_step_up_wrong_password(
        self, client: TestClient, operator_headers: dict,
        mock_supabase: AsyncMock, mock_redis: AsyncMock,
    ):
        mock_supabase.sign_in.side_effect = httpx.HTTPStatusError(
            "Unauthorized",
            request=httpx.Request("POST", "http://test"),
            response=httpx.Response(401),
        )

        resp = client.post("/v1/auth/step-up", headers=operator_headers, json={
            "password": "wrongpassword",
        })

        assert resp.status_code == 401
        mock_redis.set_step_up.assert_not_called()

    def test_step_up_requires_auth(self, client: TestClient):
        resp = client.post("/v1/auth/step-up", json={"password": "test"})
        assert resp.status_code == 401
