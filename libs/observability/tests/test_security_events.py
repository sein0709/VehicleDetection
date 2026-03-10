"""Tests for security event logging (SEC-12)."""

from __future__ import annotations

from observability.security_events import (
    SecurityEvent,
    SecurityEventType,
    SecuritySeverity,
    emit_security_event,
)


class TestSecurityEvent:
    def test_severity_auto_assigned(self) -> None:
        event = SecurityEvent(
            event_type=SecurityEventType.ACCOUNT_LOCKED,
            service="auth-service",
        )
        assert event.severity == SecuritySeverity.CRITICAL

    def test_info_severity(self) -> None:
        event = SecurityEvent(
            event_type=SecurityEventType.LOGIN_FAILED,
            service="auth-service",
        )
        assert event.severity == SecuritySeverity.INFO

    def test_warning_severity(self) -> None:
        event = SecurityEvent(
            event_type=SecurityEventType.INVALID_JWT,
            service="api-gateway",
        )
        assert event.severity == SecuritySeverity.WARNING

    def test_should_alert_for_critical_events(self) -> None:
        event = SecurityEvent(
            event_type=SecurityEventType.BRUTE_FORCE_DETECTED,
            service="auth-service",
        )
        assert event.should_alert is True

    def test_should_not_alert_for_info_events(self) -> None:
        event = SecurityEvent(
            event_type=SecurityEventType.LOGIN_FAILED,
            service="auth-service",
        )
        assert event.should_alert is False

    def test_to_dict_includes_all_fields(self) -> None:
        event = SecurityEvent(
            event_type=SecurityEventType.WAF_RULE_TRIGGERED,
            service="api-gateway",
            user_id="usr_123",
            ip_address="203.0.113.42",
            details={"rule_id": "sqli-body", "uri": "/v1/sites"},
        )
        d = event.to_dict()
        assert d["security_event"] is True
        assert d["event_type"] == "network.waf_rule_triggered"
        assert d["service"] == "api-gateway"
        assert d["user_id"] == "usr_123"
        assert d["ip_address"] == "203.0.113.42"
        assert d["rule_id"] == "sqli-body"

    def test_correlation_fields_present(self) -> None:
        event = SecurityEvent(
            event_type=SecurityEventType.RATE_LIMIT_EXCEEDED,
            service="api-gateway",
            request_id="req-abc-123",
            org_id="org-xyz",
        )
        d = event.to_dict()
        assert d["request_id"] == "req-abc-123"
        assert d["org_id"] == "org-xyz"
        assert "timestamp_utc" in d


class TestEmitSecurityEvent:
    def test_returns_event_object(self) -> None:
        event = emit_security_event(
            SecurityEventType.LOGIN_FAILED,
            service="auth-service",
            user_id="usr_456",
            ip_address="10.0.0.1",
            email="test@example.com",
            reason="invalid_password",
        )
        assert isinstance(event, SecurityEvent)
        assert event.event_type == SecurityEventType.LOGIN_FAILED
        assert event.details["email"] == "test@example.com"
        assert event.details["reason"] == "invalid_password"
