"""Security event logging for SIEM integration (SEC-12).

Emits structured security events separate from business audit logs.
Events are written to the application log stream with a ``security_event``
marker so log collectors (Fluentd/Vector) can route them to the SIEM
(Elastic Security / Splunk) while also forwarding to Loki for operational use.

All events carry correlation fields for cross-referencing:
request_id, user_id, org_id, ip_address, timestamp_utc, service, severity.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from enum import StrEnum
from typing import Any

from observability.logging import get_logger, request_id_var, org_id_var

_security_logger = get_logger("greyeye.security")


class SecuritySeverity(StrEnum):
    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"


class SecurityEventType(StrEnum):
    LOGIN_FAILED = "auth.login_failed"
    LOGIN_FAILED_THRESHOLD = "auth.login_failed_threshold"
    ACCOUNT_LOCKED = "auth.account_locked"
    INVALID_JWT = "auth.invalid_jwt"
    EXPIRED_TOKEN_REUSE = "auth.expired_token_reuse"
    REFRESH_TOKEN_REUSE = "auth.refresh_token_reuse"
    RATE_LIMIT_EXCEEDED = "gateway.rate_limit_exceeded"
    RATE_LIMIT_SUSTAINED = "gateway.rate_limit_sustained"
    RLS_VIOLATION = "database.rls_violation"
    WAF_RULE_TRIGGERED = "network.waf_rule_triggered"
    ROOT_JAILBREAK_DETECTED = "device.root_jailbreak_detected"
    CERT_PINNING_FAILURE = "device.cert_pinning_failure"
    SERVICE_AUTH_FAILURE = "service.mtls_auth_failure"
    SECRET_ACCESS = "vault.secret_access"
    ANOMALOUS_PATTERN = "siem.anomalous_pattern"
    BRUTE_FORCE_DETECTED = "auth.brute_force_detected"
    CREDENTIAL_STUFFING = "gateway.credential_stuffing"
    STEP_UP_FAILED = "auth.step_up_failed"
    STEP_UP_LOCKOUT = "auth.step_up_lockout"


_SEVERITY_MAP: dict[SecurityEventType, SecuritySeverity] = {
    SecurityEventType.LOGIN_FAILED: SecuritySeverity.INFO,
    SecurityEventType.LOGIN_FAILED_THRESHOLD: SecuritySeverity.WARNING,
    SecurityEventType.ACCOUNT_LOCKED: SecuritySeverity.CRITICAL,
    SecurityEventType.INVALID_JWT: SecuritySeverity.WARNING,
    SecurityEventType.EXPIRED_TOKEN_REUSE: SecuritySeverity.WARNING,
    SecurityEventType.REFRESH_TOKEN_REUSE: SecuritySeverity.CRITICAL,
    SecurityEventType.RATE_LIMIT_EXCEEDED: SecuritySeverity.INFO,
    SecurityEventType.RATE_LIMIT_SUSTAINED: SecuritySeverity.WARNING,
    SecurityEventType.RLS_VIOLATION: SecuritySeverity.WARNING,
    SecurityEventType.WAF_RULE_TRIGGERED: SecuritySeverity.WARNING,
    SecurityEventType.ROOT_JAILBREAK_DETECTED: SecuritySeverity.WARNING,
    SecurityEventType.CERT_PINNING_FAILURE: SecuritySeverity.CRITICAL,
    SecurityEventType.SERVICE_AUTH_FAILURE: SecuritySeverity.CRITICAL,
    SecurityEventType.SECRET_ACCESS: SecuritySeverity.INFO,
    SecurityEventType.ANOMALOUS_PATTERN: SecuritySeverity.WARNING,
    SecurityEventType.BRUTE_FORCE_DETECTED: SecuritySeverity.CRITICAL,
    SecurityEventType.CREDENTIAL_STUFFING: SecuritySeverity.CRITICAL,
    SecurityEventType.STEP_UP_FAILED: SecuritySeverity.WARNING,
    SecurityEventType.STEP_UP_LOCKOUT: SecuritySeverity.WARNING,
}

_ALERT_EVENTS: set[SecurityEventType] = {
    SecurityEventType.LOGIN_FAILED_THRESHOLD,
    SecurityEventType.ACCOUNT_LOCKED,
    SecurityEventType.EXPIRED_TOKEN_REUSE,
    SecurityEventType.REFRESH_TOKEN_REUSE,
    SecurityEventType.RATE_LIMIT_SUSTAINED,
    SecurityEventType.RLS_VIOLATION,
    SecurityEventType.WAF_RULE_TRIGGERED,
    SecurityEventType.ROOT_JAILBREAK_DETECTED,
    SecurityEventType.CERT_PINNING_FAILURE,
    SecurityEventType.SERVICE_AUTH_FAILURE,
    SecurityEventType.BRUTE_FORCE_DETECTED,
    SecurityEventType.CREDENTIAL_STUFFING,
}


@dataclass
class SecurityEvent:
    """Structured security event for SIEM ingestion."""

    event_type: SecurityEventType
    service: str
    severity: SecuritySeverity = field(init=False)
    timestamp_utc: float = field(default_factory=time.time)
    request_id: str = ""
    user_id: str = ""
    org_id: str = ""
    ip_address: str = ""
    user_agent: str = ""
    details: dict[str, Any] = field(default_factory=dict)
    should_alert: bool = field(init=False)

    def __post_init__(self) -> None:
        self.severity = _SEVERITY_MAP.get(self.event_type, SecuritySeverity.INFO)
        self.should_alert = self.event_type in _ALERT_EVENTS
        if not self.request_id:
            self.request_id = request_id_var.get("")
        if not self.org_id:
            self.org_id = org_id_var.get("")

    def to_dict(self) -> dict[str, Any]:
        return {
            "security_event": True,
            "event_type": self.event_type.value,
            "service": self.service,
            "severity": self.severity.value,
            "timestamp_utc": self.timestamp_utc,
            "request_id": self.request_id,
            "user_id": self.user_id,
            "org_id": self.org_id,
            "ip_address": self.ip_address,
            "user_agent": self.user_agent,
            "should_alert": self.should_alert,
            **self.details,
        }


def emit_security_event(
    event_type: SecurityEventType,
    *,
    service: str,
    user_id: str = "",
    ip_address: str = "",
    user_agent: str = "",
    **details: Any,
) -> SecurityEvent:
    """Create and log a security event.

    The event is emitted as a structured log entry with ``security_event=True``
    so log collectors can route it to the SIEM pipeline.
    """
    event = SecurityEvent(
        event_type=event_type,
        service=service,
        user_id=user_id,
        ip_address=ip_address,
        user_agent=user_agent,
        details=details,
    )

    log_method = _security_logger.warning
    if event.severity == SecuritySeverity.CRITICAL:
        log_method = _security_logger.critical
    elif event.severity == SecuritySeverity.INFO:
        log_method = _security_logger.info

    log_method("security_event", **event.to_dict())
    return event
