"""Multi-channel alert delivery (push, email, webhook) with retry logic.

Each channel handler is fire-and-forget by default but records per-channel
delivery results in a ``DeliveryReport`` so callers can inspect outcomes.
Webhook delivery retries up to ``max_retries`` with exponential backoff.
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass, field
from typing import Any

import httpx

from notification_service.settings import get_settings

logger = logging.getLogger(__name__)

FCM_V1_URL = "https://fcm.googleapis.com/fcm/send"
MAX_WEBHOOK_RETRIES = 3
WEBHOOK_BACKOFF_BASE = 1.0


@dataclass
class ChannelResult:
    channel: str
    success: bool
    recipient: str = ""
    error: str | None = None


@dataclass
class DeliveryReport:
    alert_id: str
    results: list[ChannelResult] = field(default_factory=list)

    @property
    def all_succeeded(self) -> bool:
        return all(r.success for r in self.results)

    @property
    def any_failed(self) -> bool:
        return any(not r.success for r in self.results)

    @property
    def summary(self) -> dict[str, int]:
        succeeded = sum(1 for r in self.results if r.success)
        failed = sum(1 for r in self.results if not r.success)
        return {"total": len(self.results), "succeeded": succeeded, "failed": failed}


async def send_push(
    recipients: list[dict[str, Any]],
    message: str,
    data: dict[str, Any] | None = None,
) -> list[ChannelResult]:
    """Send push notification via FCM/APNs.

    Uses the FCM legacy HTTP API when fcm_server_key is configured.
    Falls back to logging when no key is set (dev/test mode).
    """
    settings = get_settings()
    results: list[ChannelResult] = []

    if not settings.fcm_server_key:
        logger.info(
            "Push delivery skipped (no FCM key): recipients=%d message=%s",
            len(recipients),
            message[:80],
        )
        for r in recipients:
            token = r.get("device_token", "unknown")
            results.append(ChannelResult(
                channel="push", success=True, recipient=token,
                error="skipped:no_fcm_key",
            ))
        return results

    async with httpx.AsyncClient(timeout=10) as client:
        for recipient in recipients:
            device_token = recipient.get("device_token")
            if not device_token:
                results.append(ChannelResult(
                    channel="push", success=False, recipient="",
                    error="missing_device_token",
                ))
                continue
            try:
                payload = {
                    "to": device_token,
                    "notification": {"title": "GreyEye Alert", "body": message},
                    "data": data or {},
                }
                resp = await client.post(
                    FCM_V1_URL,
                    json=payload,
                    headers={"Authorization": f"key={settings.fcm_server_key}"},
                )
                resp.raise_for_status()
                results.append(ChannelResult(
                    channel="push", success=True, recipient=device_token[:12],
                ))
                logger.info("FCM push → %s: %s", device_token[:12], message[:80])
            except httpx.HTTPError as exc:
                results.append(ChannelResult(
                    channel="push", success=False, recipient=device_token[:12],
                    error=str(exc),
                ))
                logger.warning("FCM push failed → %s: %s", device_token[:12], exc)

    return results


async def send_email(
    recipients: list[dict[str, Any]],
    subject: str,
    body: str,
) -> list[ChannelResult]:
    """Send email notification via SMTP.

    Stub implementation — logs the intent.  Replace with aiosmtplib when
    SMTP credentials are configured.
    """
    settings = get_settings()
    results: list[ChannelResult] = []

    if not settings.smtp_host:
        logger.info(
            "Email delivery skipped (no SMTP host): recipients=%d subject=%s",
            len(recipients),
            subject,
        )
        for r in recipients:
            email = r.get("email", "unknown")
            results.append(ChannelResult(
                channel="email", success=True, recipient=email,
                error="skipped:no_smtp_host",
            ))
        return results

    for recipient in recipients:
        email = recipient.get("email")
        if not email:
            results.append(ChannelResult(
                channel="email", success=False, recipient="",
                error="missing_email",
            ))
            continue
        logger.info("Email → %s: %s", email, subject)
        results.append(ChannelResult(channel="email", success=True, recipient=email))

    return results


async def send_webhook(
    url: str,
    payload: dict[str, Any],
    *,
    max_retries: int = MAX_WEBHOOK_RETRIES,
) -> ChannelResult:
    """POST alert payload to an external webhook URL with exponential backoff retry."""
    settings = get_settings()
    last_error: str | None = None

    for attempt in range(1, max_retries + 1):
        try:
            async with httpx.AsyncClient(timeout=settings.webhook_timeout) as client:
                resp = await client.post(url, json=payload)
                resp.raise_for_status()
                logger.info(
                    "Webhook delivered → %s (status=%d, attempt=%d)",
                    url, resp.status_code, attempt,
                )
                return ChannelResult(channel="webhook", success=True, recipient=url)
        except httpx.HTTPError as exc:
            last_error = str(exc)
            if attempt < max_retries:
                backoff = WEBHOOK_BACKOFF_BASE * (2 ** (attempt - 1))
                logger.warning(
                    "Webhook attempt %d/%d failed → %s: %s (retrying in %.1fs)",
                    attempt, max_retries, url, exc, backoff,
                )
                await asyncio.sleep(backoff)
            else:
                logger.error(
                    "Webhook delivery failed after %d attempts → %s: %s",
                    max_retries, url, exc,
                )

    return ChannelResult(
        channel="webhook", success=False, recipient=url, error=last_error,
    )


async def deliver_alert(
    alert_event: dict[str, Any],
    rule: dict[str, Any],
) -> DeliveryReport:
    """Dispatch alert to all channels configured on the rule.

    Returns a DeliveryReport with per-channel results.
    """
    channels: list[str] = rule.get("channels", [])
    recipients: list[dict[str, Any]] = rule.get("recipients", [])
    message = alert_event.get("message", "Alert triggered")
    severity = alert_event.get("severity", "warning")
    subject = f"[{severity.upper()}] {message}"
    alert_id = str(alert_event.get("id", ""))

    alert_payload = {
        "alert_id": alert_id,
        "rule_id": str(alert_event.get("rule_id", "")),
        "rule_name": rule.get("name", ""),
        "severity": severity,
        "message": message,
        "context": alert_event.get("context", {}),
        "triggered_at": str(alert_event.get("triggered_at", "")),
    }

    report = DeliveryReport(alert_id=alert_id)

    for channel in channels:
        if channel == "push":
            results = await send_push(recipients, message, data=alert_payload)
            report.results.extend(results)
        elif channel == "email":
            results = await send_email(recipients, subject, body=message)
            report.results.extend(results)
        elif channel == "webhook":
            for recipient in recipients:
                webhook_url = recipient.get("webhook_url")
                if webhook_url:
                    result = await send_webhook(webhook_url, alert_payload)
                    report.results.append(result)
        else:
            logger.warning("Unknown delivery channel: %s", channel)
            report.results.append(ChannelResult(
                channel=channel, success=False, error="unknown_channel",
            ))

    if report.any_failed:
        logger.warning(
            "Alert %s delivery partial failure: %s", alert_id, report.summary,
        )
    else:
        logger.info("Alert %s delivery complete: %s", alert_id, report.summary)

    return report
