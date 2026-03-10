"""Tests for multi-channel alert delivery with retry logic."""

from __future__ import annotations

from typing import Any
from unittest.mock import AsyncMock, patch

import httpx
import pytest

from notification_service.delivery import (
    ChannelResult,
    DeliveryReport,
    deliver_alert,
    send_email,
    send_push,
    send_webhook,
)


@pytest.fixture()
def alert_event() -> dict[str, Any]:
    return {
        "id": "alert-001",
        "rule_id": "rule-001",
        "severity": "warning",
        "message": "Speed drop detected on camera cam-001",
        "context": {"camera_id": "cam-001"},
        "triggered_at": "2026-03-10T12:00:00+00:00",
    }


@pytest.fixture()
def rule_with_all_channels() -> dict[str, Any]:
    return {
        "id": "rule-001",
        "name": "Speed Alert",
        "channels": ["push", "email", "webhook"],
        "recipients": [
            {"device_token": "fcm-token-abc123", "email": "ops@test.com", "webhook_url": "https://hooks.example.com/alert"},
        ],
    }


class TestSendPush:
    @pytest.mark.asyncio
    async def test_skips_when_no_fcm_key(self) -> None:
        with patch("notification_service.delivery.get_settings") as mock_settings:
            mock_settings.return_value.fcm_server_key = None
            results = await send_push(
                [{"device_token": "tok"}], "test message"
            )
            assert len(results) == 1
            assert results[0].success is True
            assert "skipped" in (results[0].error or "")

    @pytest.mark.asyncio
    async def test_skips_recipient_without_token(self) -> None:
        with patch("notification_service.delivery.get_settings") as mock_settings:
            mock_settings.return_value.fcm_server_key = "key-123"
            with patch("httpx.AsyncClient.post", new_callable=AsyncMock):
                results = await send_push([{"email": "no-token@test.com"}], "msg")
                assert len(results) == 1
                assert results[0].success is False
                assert results[0].error == "missing_device_token"


class TestSendEmail:
    @pytest.mark.asyncio
    async def test_skips_when_no_smtp_host(self) -> None:
        with patch("notification_service.delivery.get_settings") as mock_settings:
            mock_settings.return_value.smtp_host = None
            results = await send_email(
                [{"email": "test@test.com"}], "Subject", "Body"
            )
            assert len(results) == 1
            assert results[0].success is True
            assert "skipped" in (results[0].error or "")

    @pytest.mark.asyncio
    async def test_skips_recipient_without_email(self) -> None:
        with patch("notification_service.delivery.get_settings") as mock_settings:
            mock_settings.return_value.smtp_host = "smtp.test.com"
            results = await send_email(
                [{"device_token": "tok"}], "Subject", "Body"
            )
            assert len(results) == 1
            assert results[0].success is False
            assert results[0].error == "missing_email"

    @pytest.mark.asyncio
    async def test_sends_when_smtp_configured(self) -> None:
        with patch("notification_service.delivery.get_settings") as mock_settings:
            mock_settings.return_value.smtp_host = "smtp.test.com"
            results = await send_email(
                [{"email": "ops@test.com"}], "Alert", "Body"
            )
            assert len(results) == 1
            assert results[0].success is True
            assert results[0].recipient == "ops@test.com"


class TestSendWebhook:
    @pytest.mark.asyncio
    async def test_successful_delivery(self) -> None:
        mock_response = AsyncMock()
        mock_response.status_code = 200
        mock_response.raise_for_status = lambda: None

        with patch("httpx.AsyncClient.post", new_callable=AsyncMock, return_value=mock_response):
            with patch("notification_service.delivery.get_settings") as mock_settings:
                mock_settings.return_value.webhook_timeout = 10
                result = await send_webhook(
                    "https://hooks.example.com/alert",
                    {"alert_id": "a1"},
                    max_retries=1,
                )
                assert result.success is True
                assert result.recipient == "https://hooks.example.com/alert"

    @pytest.mark.asyncio
    async def test_retries_on_failure(self) -> None:
        with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
            mock_post.side_effect = httpx.ConnectError("connection refused")
            with patch("notification_service.delivery.get_settings") as mock_settings:
                mock_settings.return_value.webhook_timeout = 5
                with patch("asyncio.sleep", new_callable=AsyncMock):
                    result = await send_webhook(
                        "https://hooks.example.com/alert",
                        {"alert_id": "a1"},
                        max_retries=2,
                    )
                    assert result.success is False
                    assert mock_post.call_count == 2


class TestDeliverAlert:
    @pytest.mark.asyncio
    async def test_dispatches_to_all_channels(
        self, alert_event: dict, rule_with_all_channels: dict
    ) -> None:
        with patch("notification_service.delivery.send_push", new_callable=AsyncMock) as mock_push, \
             patch("notification_service.delivery.send_email", new_callable=AsyncMock) as mock_email, \
             patch("notification_service.delivery.send_webhook", new_callable=AsyncMock) as mock_webhook:
            mock_push.return_value = [ChannelResult(channel="push", success=True)]
            mock_email.return_value = [ChannelResult(channel="email", success=True)]
            mock_webhook.return_value = ChannelResult(channel="webhook", success=True)

            report = await deliver_alert(alert_event, rule_with_all_channels)

            assert isinstance(report, DeliveryReport)
            assert report.all_succeeded
            assert report.summary["total"] == 3
            mock_push.assert_called_once()
            mock_email.assert_called_once()
            mock_webhook.assert_called_once()

    @pytest.mark.asyncio
    async def test_handles_unknown_channel(self) -> None:
        with patch("notification_service.delivery.get_settings") as mock_settings:
            mock_settings.return_value.fcm_server_key = None
            mock_settings.return_value.smtp_host = None

            rule = {"channels": ["carrier_pigeon"], "recipients": []}
            report = await deliver_alert(
                {"id": "a1", "message": "test", "severity": "info"},
                rule,
            )
            assert report.any_failed
            assert report.results[0].error == "unknown_channel"

    @pytest.mark.asyncio
    async def test_partial_failure_reported(self, alert_event: dict) -> None:
        with patch("notification_service.delivery.send_push", new_callable=AsyncMock) as mock_push, \
             patch("notification_service.delivery.send_email", new_callable=AsyncMock) as mock_email:
            mock_push.return_value = [ChannelResult(channel="push", success=True)]
            mock_email.return_value = [ChannelResult(channel="email", success=False, error="smtp_error")]

            rule = {"channels": ["push", "email"], "recipients": [{"device_token": "t", "email": "e"}]}
            report = await deliver_alert(alert_event, rule)

            assert report.any_failed
            assert report.summary["succeeded"] == 1
            assert report.summary["failed"] == 1


class TestDeliveryReport:
    def test_all_succeeded(self) -> None:
        report = DeliveryReport(
            alert_id="a1",
            results=[
                ChannelResult(channel="push", success=True),
                ChannelResult(channel="email", success=True),
            ],
        )
        assert report.all_succeeded is True
        assert report.any_failed is False

    def test_any_failed(self) -> None:
        report = DeliveryReport(
            alert_id="a1",
            results=[
                ChannelResult(channel="push", success=True),
                ChannelResult(channel="webhook", success=False, error="timeout"),
            ],
        )
        assert report.all_succeeded is False
        assert report.any_failed is True

    def test_summary(self) -> None:
        report = DeliveryReport(
            alert_id="a1",
            results=[
                ChannelResult(channel="push", success=True),
                ChannelResult(channel="email", success=False),
                ChannelResult(channel="webhook", success=True),
            ],
        )
        assert report.summary == {"total": 3, "succeeded": 2, "failed": 1}
