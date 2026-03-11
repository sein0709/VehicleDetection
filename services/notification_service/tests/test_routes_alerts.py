"""Tests for alert CRUD and lifecycle endpoints."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

from fastapi.testclient import TestClient


class TestCreateAlertRule:
    def test_create_rule_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_rule: dict[str, Any],
    ) -> None:
        mock_db.create_rule = AsyncMock(return_value=sample_rule)

        resp = client.post(
            "/v1/alerts/rules",
            json={
                "name": "속도 저하 알림",
                "condition_type": "speed_drop",
                "condition_config": {"min_speed_kmh": 10.0},
                "severity": "warning",
                "channels": ["push", "email"],
            },
            headers=operator_headers,
        )

        assert resp.status_code == 201
        data = resp.json()
        assert data["name"] == "속도 저하 알림"
        assert data["condition_type"] == "speed_drop"
        mock_db.create_rule.assert_called_once()

    def test_create_rule_requires_auth(self, client: TestClient) -> None:
        resp = client.post(
            "/v1/alerts/rules",
            json={"name": "Test", "condition_type": "congestion"},
        )
        assert resp.status_code == 401

    def test_create_rule_applies_default_cooldown_when_omitted(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_rule: dict[str, Any],
    ) -> None:
        mock_db.create_rule = AsyncMock(return_value=sample_rule)

        resp = client.post(
            "/v1/alerts/rules",
            json={
                "name": "속도 저하 알림",
                "condition_type": "speed_drop",
                "condition_config": {"min_speed_kmh": 10.0},
            },
            headers=operator_headers,
        )

        assert resp.status_code == 201
        assert mock_db.create_rule.call_args.kwargs["data"]["cooldown_minutes"] == 15

    def test_create_rule_viewer_forbidden(
        self, client: TestClient, viewer_headers: dict
    ) -> None:
        resp = client.post(
            "/v1/alerts/rules",
            json={"name": "Test", "condition_type": "congestion"},
            headers=viewer_headers,
        )
        assert resp.status_code == 403


class TestGetAlertRule:
    def test_get_rule_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_rule: dict[str, Any],
    ) -> None:
        mock_db.get_rule = AsyncMock(return_value=sample_rule)

        resp = client.get(
            f"/v1/alerts/rules/{sample_rule['id']}",
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert resp.json()["name"] == sample_rule["name"]

    def test_get_rule_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
    ) -> None:
        mock_db.get_rule = AsyncMock(return_value=None)

        resp = client.get(
            f"/v1/alerts/rules/{uuid4()}",
            headers=operator_headers,
        )
        assert resp.status_code == 404

    def test_get_rule_requires_auth(self, client: TestClient) -> None:
        resp = client.get(f"/v1/alerts/rules/{uuid4()}")
        assert resp.status_code == 401


class TestListAlertRules:
    def test_list_rules_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_rule: dict[str, Any],
    ) -> None:
        mock_db.list_rules = AsyncMock(return_value=([sample_rule], 1))

        resp = client.get("/v1/alerts/rules", headers=operator_headers)

        assert resp.status_code == 200
        data = resp.json()
        assert len(data["data"]) == 1
        assert data["pagination"]["total_count"] == 1


class TestUpdateAlertRule:
    def test_update_rule_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_rule: dict[str, Any],
    ) -> None:
        updated = {**sample_rule, "name": "Updated Rule"}
        mock_db.update_rule = AsyncMock(return_value=updated)

        resp = client.patch(
            f"/v1/alerts/rules/{sample_rule['id']}",
            json={"name": "Updated Rule"},
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert resp.json()["name"] == "Updated Rule"

    def test_update_rule_empty_body(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_rule: dict[str, Any],
    ) -> None:
        resp = client.patch(
            f"/v1/alerts/rules/{sample_rule['id']}",
            json={},
            headers=operator_headers,
        )
        assert resp.status_code == 422

    def test_update_rule_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
    ) -> None:
        mock_db.update_rule = AsyncMock(return_value=None)

        resp = client.patch(
            f"/v1/alerts/rules/{uuid4()}",
            json={"name": "New Name"},
            headers=operator_headers,
        )
        assert resp.status_code == 404


class TestDeleteAlertRule:
    def test_delete_rule_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_rule: dict[str, Any],
    ) -> None:
        mock_db.delete_rule = AsyncMock(return_value=True)

        resp = client.delete(
            f"/v1/alerts/rules/{sample_rule['id']}",
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert "deleted" in resp.json()["message"].lower()

    def test_delete_rule_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
    ) -> None:
        mock_db.delete_rule = AsyncMock(return_value=False)

        resp = client.delete(
            f"/v1/alerts/rules/{uuid4()}",
            headers=operator_headers,
        )
        assert resp.status_code == 404


class TestListAlerts:
    def test_list_alerts_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        mock_db.list_alert_events = AsyncMock(return_value=([sample_alert_event], 1))

        resp = client.get("/v1/alerts", headers=operator_headers)

        assert resp.status_code == 200
        data = resp.json()
        assert len(data["data"]) == 1
        assert data["data"][0]["status"] == "triggered"


class TestGetAlert:
    def test_get_alert_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        mock_db.get_alert_event = AsyncMock(return_value=sample_alert_event)

        resp = client.get(
            f"/v1/alerts/{sample_alert_event['id']}",
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert resp.json()["status"] == "triggered"

    def test_get_alert_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
    ) -> None:
        mock_db.get_alert_event = AsyncMock(return_value=None)

        resp = client.get(
            f"/v1/alerts/{uuid4()}",
            headers=operator_headers,
        )
        assert resp.status_code == 404


class TestAcknowledgeAlert:
    def test_acknowledge_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        mock_db.get_alert_event = AsyncMock(return_value=sample_alert_event)
        acked = {**sample_alert_event, "status": "acknowledged"}
        mock_db.update_alert_status = AsyncMock(return_value=acked)

        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/acknowledge",
            json={},
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert resp.json()["status"] == "acknowledged"

    def test_acknowledge_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
    ) -> None:
        mock_db.get_alert_event = AsyncMock(return_value=None)

        resp = client.post(
            f"/v1/alerts/{uuid4()}/acknowledge",
            json={},
            headers=operator_headers,
        )
        assert resp.status_code == 404

    def test_acknowledge_already_resolved(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        resolved = {**sample_alert_event, "status": "resolved"}
        mock_db.get_alert_event = AsyncMock(return_value=resolved)

        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/acknowledge",
            json={},
            headers=operator_headers,
        )
        assert resp.status_code == 422

    def test_acknowledge_already_suppressed(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        suppressed = {**sample_alert_event, "status": "suppressed"}
        mock_db.get_alert_event = AsyncMock(return_value=suppressed)

        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/acknowledge",
            json={},
            headers=operator_headers,
        )
        assert resp.status_code == 422


class TestAssignAlert:
    def test_assign_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        assignee = uuid4()
        mock_db.get_alert_event = AsyncMock(return_value=sample_alert_event)
        assigned = {**sample_alert_event, "status": "assigned", "assigned_to": assignee}
        mock_db.update_alert_status = AsyncMock(return_value=assigned)

        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/assign",
            json={"assigned_to": str(assignee)},
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert resp.json()["status"] == "assigned"

    def test_assign_viewer_forbidden(
        self,
        client: TestClient,
        mock_db: MagicMock,
        viewer_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/assign",
            json={"assigned_to": str(uuid4())},
            headers=viewer_headers,
        )
        assert resp.status_code == 403

    def test_assign_resolved_alert_fails(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        resolved = {**sample_alert_event, "status": "resolved"}
        mock_db.get_alert_event = AsyncMock(return_value=resolved)

        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/assign",
            json={"assigned_to": str(uuid4())},
            headers=operator_headers,
        )
        assert resp.status_code == 422


class TestResolveAlert:
    def test_resolve_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        mock_db.get_alert_event = AsyncMock(return_value=sample_alert_event)
        resolved = {
            **sample_alert_event,
            "status": "resolved",
            "resolved_at": datetime.now(tz=UTC).isoformat(),
        }
        mock_db.update_alert_status = AsyncMock(return_value=resolved)

        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/resolve",
            json={},
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert resp.json()["status"] == "resolved"

    def test_resolve_already_resolved(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        resolved = {**sample_alert_event, "status": "resolved"}
        mock_db.get_alert_event = AsyncMock(return_value=resolved)

        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/resolve",
            json={},
            headers=operator_headers,
        )
        assert resp.status_code == 422

    def test_resolve_with_note(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        mock_db.get_alert_event = AsyncMock(return_value=sample_alert_event)
        resolved = {
            **sample_alert_event,
            "status": "resolved",
            "context": {"resolution_note": "Fixed by adjusting threshold"},
        }
        mock_db.update_alert_status = AsyncMock(return_value=resolved)

        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/resolve",
            json={"resolution_note": "Fixed by adjusting threshold"},
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert resp.json()["status"] == "resolved"


class TestSuppressAlert:
    def test_suppress_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        mock_db.get_alert_event = AsyncMock(return_value=sample_alert_event)
        suppressed = {**sample_alert_event, "status": "suppressed"}
        mock_db.update_alert_status = AsyncMock(return_value=suppressed)

        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/suppress",
            json={},
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert resp.json()["status"] == "suppressed"

    def test_suppress_with_reason(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        mock_db.get_alert_event = AsyncMock(return_value=sample_alert_event)
        suppressed = {
            **sample_alert_event,
            "status": "suppressed",
            "context": {"suppression_reason": "Known maintenance window"},
        }
        mock_db.update_alert_status = AsyncMock(return_value=suppressed)

        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/suppress",
            json={"reason": "Known maintenance window"},
            headers=operator_headers,
        )

        assert resp.status_code == 200
        assert resp.json()["status"] == "suppressed"

    def test_suppress_not_found(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
    ) -> None:
        mock_db.get_alert_event = AsyncMock(return_value=None)

        resp = client.post(
            f"/v1/alerts/{uuid4()}/suppress",
            json={},
            headers=operator_headers,
        )
        assert resp.status_code == 404

    def test_suppress_viewer_forbidden(
        self,
        client: TestClient,
        mock_db: MagicMock,
        viewer_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/suppress",
            json={},
            headers=viewer_headers,
        )
        assert resp.status_code == 403

    def test_suppress_resolved_alert_fails(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        resolved = {**sample_alert_event, "status": "resolved"}
        mock_db.get_alert_event = AsyncMock(return_value=resolved)

        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/suppress",
            json={},
            headers=operator_headers,
        )
        assert resp.status_code == 422


class TestAlertHistory:
    def test_history_success(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        mock_db.list_alert_history = AsyncMock(return_value=([sample_alert_event], 1))

        resp = client.get("/v1/alerts/history", headers=operator_headers)

        assert resp.status_code == 200
        data = resp.json()
        assert len(data["data"]) == 1
        assert data["pagination"]["total_count"] == 1


class TestStateTransitions:
    """Verify the full alert lifecycle state machine."""

    def test_triggered_to_acknowledged(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        mock_db.get_alert_event = AsyncMock(return_value=sample_alert_event)
        acked = {**sample_alert_event, "status": "acknowledged"}
        mock_db.update_alert_status = AsyncMock(return_value=acked)

        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/acknowledge",
            json={},
            headers=operator_headers,
        )
        assert resp.status_code == 200

    def test_acknowledged_to_assigned(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        acked = {**sample_alert_event, "status": "acknowledged"}
        mock_db.get_alert_event = AsyncMock(return_value=acked)
        assigned = {**sample_alert_event, "status": "assigned", "assigned_to": uuid4()}
        mock_db.update_alert_status = AsyncMock(return_value=assigned)

        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/assign",
            json={"assigned_to": str(uuid4())},
            headers=operator_headers,
        )
        assert resp.status_code == 200

    def test_assigned_to_resolved(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        assigned = {**sample_alert_event, "status": "assigned"}
        mock_db.get_alert_event = AsyncMock(return_value=assigned)
        resolved = {**sample_alert_event, "status": "resolved"}
        mock_db.update_alert_status = AsyncMock(return_value=resolved)

        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/resolve",
            json={},
            headers=operator_headers,
        )
        assert resp.status_code == 200

    def test_suppressed_cannot_acknowledge(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        suppressed = {**sample_alert_event, "status": "suppressed"}
        mock_db.get_alert_event = AsyncMock(return_value=suppressed)

        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/acknowledge",
            json={},
            headers=operator_headers,
        )
        assert resp.status_code == 422

    def test_suppressed_cannot_assign(
        self,
        client: TestClient,
        mock_db: MagicMock,
        operator_headers: dict,
        sample_alert_event: dict[str, Any],
    ) -> None:
        suppressed = {**sample_alert_event, "status": "suppressed"}
        mock_db.get_alert_event = AsyncMock(return_value=suppressed)

        resp = client.post(
            f"/v1/alerts/{sample_alert_event['id']}/assign",
            json={"assigned_to": str(uuid4())},
            headers=operator_headers,
        )
        assert resp.status_code == 422


class TestHealthAndMetrics:
    def test_healthz(self, client: TestClient) -> None:
        resp = client.get("/healthz")
        assert resp.status_code == 200
        assert resp.json()["status"] == "ok"

    def test_metrics_endpoint(self, client: TestClient) -> None:
        resp = client.get("/metrics")
        assert resp.status_code == 200
