"""Tests for user management endpoints: GET /me, PATCH role."""

from __future__ import annotations

from unittest.mock import AsyncMock
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient

from auth_service.test_support import (
    TEST_ADMIN_ID,
    TEST_ORG_ID,
    TEST_USER_ID,
    make_user_record as _make_user_record,
)


class TestGetMe:
    def test_returns_current_user_profile(
        self, client: TestClient, operator_headers: dict, mock_supabase: AsyncMock,
    ):
        mock_supabase.get_user_by_id.return_value = _make_user_record()

        resp = client.get("/v1/users/me", headers=operator_headers)

        assert resp.status_code == 200
        data = resp.json()
        assert data["email"] == "operator@example.com"
        assert data["role"] == "operator"
        assert data["org_id"] == str(TEST_ORG_ID)

    def test_requires_auth(self, client: TestClient):
        resp = client.get("/v1/users/me")
        assert resp.status_code == 401

    def test_user_not_found_returns_404(
        self, client: TestClient, operator_headers: dict, mock_supabase: AsyncMock,
    ):
        mock_supabase.get_user_by_id.return_value = None

        resp = client.get("/v1/users/me", headers=operator_headers)

        assert resp.status_code == 404


class TestUpdateRole:
    def test_admin_can_change_role(
        self, client: TestClient, admin_headers: dict,
        mock_supabase: AsyncMock, mock_redis: AsyncMock,
    ):
        mock_redis.has_step_up.return_value = True
        target_user = _make_user_record(
            user_id=TEST_USER_ID, role="operator",
        )
        updated_user = {**target_user, "role": "analyst"}
        mock_supabase.get_user_by_id.return_value = target_user
        mock_supabase.update_user_role.return_value = updated_user
        mock_supabase.update_user_metadata.return_value = {}

        resp = client.patch(
            f"/v1/users/{TEST_USER_ID}/role",
            headers=admin_headers,
            json={"role": "analyst"},
        )

        assert resp.status_code == 200
        assert resp.json()["role"] == "analyst"

    def test_requires_step_up_auth(
        self, client: TestClient, admin_headers: dict,
        mock_supabase: AsyncMock, mock_redis: AsyncMock,
    ):
        mock_redis.has_step_up.return_value = False
        mock_supabase.get_user_by_id.return_value = _make_user_record()

        resp = client.patch(
            f"/v1/users/{TEST_USER_ID}/role",
            headers=admin_headers,
            json={"role": "analyst"},
        )

        assert resp.status_code == 403
        assert "step-up" in resp.json()["detail"].lower()

    def test_operator_cannot_change_roles(
        self, client: TestClient, operator_headers: dict,
    ):
        resp = client.patch(
            f"/v1/users/{uuid4()}/role",
            headers=operator_headers,
            json={"role": "viewer"},
        )

        assert resp.status_code == 403

    def test_cannot_change_own_role(
        self, client: TestClient, admin_headers: dict,
        mock_supabase: AsyncMock, mock_redis: AsyncMock,
    ):
        mock_redis.has_step_up.return_value = True
        mock_supabase.get_user_by_id.return_value = _make_user_record(
            user_id=TEST_ADMIN_ID, role="admin",
        )

        resp = client.patch(
            f"/v1/users/{TEST_ADMIN_ID}/role",
            headers=admin_headers,
            json={"role": "operator"},
        )

        assert resp.status_code == 422
        assert "own role" in resp.json()["detail"].lower()

    def test_cannot_change_cross_org_user(
        self, client: TestClient, admin_headers: dict,
        mock_supabase: AsyncMock, mock_redis: AsyncMock,
    ):
        mock_redis.has_step_up.return_value = True
        other_org = uuid4()
        mock_supabase.get_user_by_id.return_value = _make_user_record(
            user_id=TEST_USER_ID, org_id=other_org,
        )

        resp = client.patch(
            f"/v1/users/{TEST_USER_ID}/role",
            headers=admin_headers,
            json={"role": "viewer"},
        )

        assert resp.status_code == 403
        assert "outside your organization" in resp.json()["detail"].lower()

    def test_user_not_found_returns_404(
        self, client: TestClient, admin_headers: dict,
        mock_supabase: AsyncMock, mock_redis: AsyncMock,
    ):
        mock_redis.has_step_up.return_value = True
        mock_supabase.get_user_by_id.return_value = None

        resp = client.patch(
            f"/v1/users/{uuid4()}/role",
            headers=admin_headers,
            json={"role": "viewer"},
        )

        assert resp.status_code == 404

    def test_same_role_returns_422(
        self, client: TestClient, admin_headers: dict,
        mock_supabase: AsyncMock, mock_redis: AsyncMock,
    ):
        mock_redis.has_step_up.return_value = True
        mock_supabase.get_user_by_id.return_value = _make_user_record(
            user_id=TEST_USER_ID, role="operator",
        )

        resp = client.patch(
            f"/v1/users/{TEST_USER_ID}/role",
            headers=admin_headers,
            json={"role": "operator"},
        )

        assert resp.status_code == 422

    def test_audit_log_written_on_role_change(
        self, client: TestClient, admin_headers: dict,
        mock_supabase: AsyncMock, mock_redis: AsyncMock,
    ):
        mock_redis.has_step_up.return_value = True
        target_user = _make_user_record(user_id=TEST_USER_ID, role="operator")
        updated_user = {**target_user, "role": "analyst"}
        mock_supabase.get_user_by_id.return_value = target_user
        mock_supabase.update_user_role.return_value = updated_user
        mock_supabase.update_user_metadata.return_value = {}

        client.patch(
            f"/v1/users/{TEST_USER_ID}/role",
            headers=admin_headers,
            json={"role": "analyst"},
        )

        mock_supabase.write_audit_log.assert_called_once()
        call_kwargs = mock_supabase.write_audit_log.call_args.kwargs
        assert call_kwargs["action"] == "user.role_changed"
        assert call_kwargs["old_value"] == {"role": "operator"}
        assert call_kwargs["new_value"] == {"role": "analyst"}


class TestHealthEndpoints:
    def test_healthz(self, client: TestClient):
        resp = client.get("/healthz")
        assert resp.status_code == 200
        assert resp.json()["status"] == "ok"

    def test_readyz_healthy(self, client: TestClient, mock_redis: AsyncMock):
        mock_redis._redis.ping.return_value = True
        resp = client.get("/readyz")
        assert resp.status_code == 200
        assert resp.json()["status"] == "ready"
