"""Tests for config version history and rollback endpoints."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

from fastapi.testclient import TestClient

from tests.conftest import TEST_ORG_ID, TEST_SITE_ID, TEST_USER_ID


def _make_version(
    entity_type: str = "site",
    entity_id: str | None = None,
    version_number: int = 1,
    is_active: bool = True,
    rollback_from: str | None = None,
) -> dict[str, Any]:
    return {
        "id": str(uuid4()),
        "org_id": str(TEST_ORG_ID),
        "entity_type": entity_type,
        "entity_id": entity_id or str(TEST_SITE_ID),
        "version_number": version_number,
        "config_snapshot": {"name": "snapshot"},
        "is_active": is_active,
        "created_by": str(TEST_USER_ID),
        "rollback_from": rollback_from,
        "created_at": datetime.now(tz=UTC).isoformat(),
    }


class TestListVersions:
    def test_list_versions_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
    ) -> None:
        versions = [
            _make_version(version_number=2, is_active=True),
            _make_version(version_number=1, is_active=False),
        ]
        mock_db.list_config_versions = AsyncMock(return_value=versions)

        resp = client.get(
            f"/v1/config-versions/site/{TEST_SITE_ID}",
            headers=operator_headers,
        )

        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 2
        assert data[0]["version_number"] == 2
        assert data[0]["is_active"] is True

    def test_list_versions_invalid_entity_type(
        self,
        client: TestClient,
        operator_headers: dict,
    ) -> None:
        resp = client.get(
            f"/v1/config-versions/invalid_type/{TEST_SITE_ID}",
            headers=operator_headers,
        )
        assert resp.status_code == 422

    def test_list_versions_requires_auth(self, client: TestClient) -> None:
        resp = client.get(f"/v1/config-versions/site/{TEST_SITE_ID}")
        assert resp.status_code == 401

    def test_list_versions_viewer_allowed(
        self,
        client: TestClient,
        mock_db: MagicMock,
        viewer_headers: dict,
    ) -> None:
        mock_db.list_config_versions = AsyncMock(return_value=[])

        resp = client.get(
            f"/v1/config-versions/site/{TEST_SITE_ID}",
            headers=viewer_headers,
        )
        assert resp.status_code == 200


class TestRollbackVersion:
    def test_rollback_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
    ) -> None:
        target_version = _make_version(version_number=1, is_active=False)
        new_version = _make_version(
            version_number=3,
            is_active=True,
            rollback_from=target_version["id"],
        )

        mock_db.get_config_version = AsyncMock(return_value=target_version)
        mock_db.list_config_versions = AsyncMock(
            return_value=[
                _make_version(version_number=2, is_active=True),
                target_version,
            ]
        )
        mock_db.create_config_version = AsyncMock(return_value=new_version)
        mock_db.rollback_entity_version = MagicMock()

        resp = client.post(
            f"/v1/config-versions/{target_version['id']}/rollback",
            headers=operator_headers,
        )

        assert resp.status_code == 200
        data = resp.json()
        assert data["version_number"] == 3
        assert data["is_active"] is True
        mock_db.create_config_version.assert_called_once()
        mock_db.rollback_entity_version.assert_called_once_with("site", TEST_SITE_ID, 3)

    def test_rollback_version_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
    ) -> None:
        mock_db.get_config_version = AsyncMock(return_value=None)

        resp = client.post(
            f"/v1/config-versions/{uuid4()}/rollback",
            headers=operator_headers,
        )
        assert resp.status_code == 404

    def test_rollback_requires_operator(
        self,
        client: TestClient,
        viewer_headers: dict,
    ) -> None:
        resp = client.post(
            f"/v1/config-versions/{uuid4()}/rollback",
            headers=viewer_headers,
        )
        assert resp.status_code == 403

    def test_rollback_creates_audit_log(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
    ) -> None:
        target_version = _make_version(version_number=1, is_active=False)
        new_version = _make_version(version_number=2, is_active=True)

        mock_db.get_config_version = AsyncMock(return_value=target_version)
        mock_db.list_config_versions = AsyncMock(return_value=[target_version])
        mock_db.create_config_version = AsyncMock(return_value=new_version)
        mock_db.rollback_entity_version = MagicMock()

        client.post(
            f"/v1/config-versions/{target_version['id']}/rollback",
            headers=operator_headers,
        )

        mock_db.write_audit_log.assert_called_once()
        call_kwargs = mock_db.write_audit_log.call_args.kwargs
        assert call_kwargs["action"] == "site.rollback"
