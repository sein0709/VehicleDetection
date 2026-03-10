"""Log sanitization for sensitive data redaction (SEC-10).

Provides a structlog processor and standalone function that redacts
sensitive patterns (RTSP credentials, JWT tokens, passwords, API keys,
emails) from log messages and event fields before they reach output.
"""

from __future__ import annotations

import re
from typing import Any


def _api_key_replacer(match: re.Match[str]) -> str:
    """Keep the field prefix and last 4 chars of the key value."""
    prefix = match.group(1)
    key_value = match.group(2)
    if len(key_value) <= 4:
        return prefix + "[REDACTED]"
    return prefix + "****" + key_value[-4:]


_REDACTION_RULES: list[tuple[re.Pattern[str], str | Any]] = [
    (re.compile(r"(rtsp://)[^@\s]+@"), r"\1****:****@"),
    (re.compile(r"(Bearer\s+)\S+", re.IGNORECASE), r"\1[REDACTED]"),
    (re.compile(r"(authorization[\"'\s:=]+)\S+", re.IGNORECASE), r"\1[REDACTED]"),
    (re.compile(r"(password[\"'\s:=]+)\S+", re.IGNORECASE), r"\1[REDACTED]"),
    (re.compile(r"(refresh_token[\"'\s:=]+)\S+", re.IGNORECASE), r"\1[REDACTED]"),
    (re.compile(r"(api[_-]?key[\"'\s:=]+)(\S{4,})", re.IGNORECASE), _api_key_replacer),
    (re.compile(r"(secret[\"'\s:=]+)\S+", re.IGNORECASE), r"\1[REDACTED]"),
]

_EMAIL_PATTERN = re.compile(
    r"([a-zA-Z0-9._%+-])[a-zA-Z0-9._%+-]*(@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})"
)


def sanitize_log_message(message: str, *, redact_emails: bool = True) -> str:
    """Redact sensitive patterns from a log message string."""
    for pattern, replacement in _REDACTION_RULES:
        if callable(replacement):
            message = pattern.sub(replacement, message)
        else:
            message = pattern.sub(replacement, message)
    if redact_emails:
        message = _EMAIL_PATTERN.sub(r"\1***\2", message)
    return message


def sanitize_structlog_processor(
    logger: Any, method_name: str, event_dict: dict[str, Any]
) -> dict[str, Any]:
    """structlog processor that sanitizes the event message and string values.

    Add to the structlog processor chain to automatically redact sensitive
    data from all log output.
    """
    if "event" in event_dict and isinstance(event_dict["event"], str):
        event_dict["event"] = sanitize_log_message(event_dict["event"])

    for key, value in list(event_dict.items()):
        if key == "event":
            continue
        if isinstance(value, str):
            event_dict[key] = sanitize_log_message(value)

    return event_dict
