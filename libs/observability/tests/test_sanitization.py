"""Tests for log sanitization (SEC-10)."""

from __future__ import annotations

from observability.sanitization import sanitize_log_message, sanitize_structlog_processor


class TestSanitizeLogMessage:
    def test_rtsp_url_redaction(self) -> None:
        msg = "Connecting to rtsp://admin:p4ssw0rd@192.168.1.100:554/stream1"
        result = sanitize_log_message(msg, redact_emails=False)
        assert "admin" not in result
        assert "p4ssw0rd" not in result
        assert "****:****@192.168.1.100" in result

    def test_bearer_token_redaction(self) -> None:
        msg = "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload.signature"
        result = sanitize_log_message(msg, redact_emails=False)
        assert "eyJhbGci" not in result
        assert "[REDACTED]" in result

    def test_password_redaction(self) -> None:
        msg = 'Login attempt with password="super_secret_123"'
        result = sanitize_log_message(msg, redact_emails=False)
        assert "super_secret_123" not in result
        assert "[REDACTED]" in result

    def test_refresh_token_redaction(self) -> None:
        msg = "refresh_token=abc123def456"
        result = sanitize_log_message(msg, redact_emails=False)
        assert "abc123def456" not in result
        assert "[REDACTED]" in result

    def test_api_key_keeps_last_4(self) -> None:
        msg = "api_key=sk_live_abcdefghijklmnop"
        result = sanitize_log_message(msg, redact_emails=False)
        assert "abcdefghij" not in result
        assert "mnop" in result

    def test_email_redaction(self) -> None:
        msg = "User operator@example.com logged in"
        result = sanitize_log_message(msg, redact_emails=True)
        assert "operator@" not in result
        assert "o***@example.com" in result

    def test_email_not_redacted_when_disabled(self) -> None:
        msg = "User operator@example.com logged in"
        result = sanitize_log_message(msg, redact_emails=False)
        assert "operator@example.com" in result

    def test_secret_redaction(self) -> None:
        msg = 'webhook secret="wh_sec_abc123xyz"'
        result = sanitize_log_message(msg, redact_emails=False)
        assert "wh_sec_abc123xyz" not in result
        assert "[REDACTED]" in result

    def test_no_false_positives_on_normal_text(self) -> None:
        msg = "Processing frame 42 from camera cam_001 at site site_abc"
        result = sanitize_log_message(msg, redact_emails=False)
        assert result == msg


class TestStructlogProcessor:
    def test_sanitizes_event_field(self) -> None:
        event_dict = {"event": "Bearer eyJtoken123 received"}
        result = sanitize_structlog_processor(None, "info", event_dict)
        assert "eyJtoken123" not in result["event"]

    def test_sanitizes_string_values(self) -> None:
        event_dict = {
            "event": "request processed",
            "auth_header": "Bearer secret_token_here",
        }
        result = sanitize_structlog_processor(None, "info", event_dict)
        assert "secret_token_here" not in result["auth_header"]

    def test_preserves_non_string_values(self) -> None:
        event_dict = {
            "event": "request",
            "status_code": 200,
            "duration_ms": 42.5,
        }
        result = sanitize_structlog_processor(None, "info", event_dict)
        assert result["status_code"] == 200
        assert result["duration_ms"] == 42.5
