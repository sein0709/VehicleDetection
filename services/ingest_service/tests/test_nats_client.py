"""Tests for NatsFramePublisher."""

from __future__ import annotations

import json
from unittest.mock import AsyncMock, MagicMock

import pytest
from ingest_service.nats_client import STREAM_FRAMES, SUBJECT_FRAMES, NatsFramePublisher


@pytest.fixture()
def publisher() -> NatsFramePublisher:
    return NatsFramePublisher()


class TestNatsFramePublisher:
    def test_initial_state(self, publisher: NatsFramePublisher) -> None:
        assert publisher._nc is None
        assert publisher._js is None
        assert not publisher.is_connected

    @pytest.mark.asyncio
    async def test_publish_frame_not_connected(self, publisher: NatsFramePublisher) -> None:
        with pytest.raises(RuntimeError, match="not connected"):
            await publisher.publish_frame("cam_001", b"data", {})

    @pytest.mark.asyncio
    async def test_publish_health_event_not_connected(self, publisher: NatsFramePublisher) -> None:
        with pytest.raises(RuntimeError, match="not connected"):
            await publisher.publish_health_event("cam_001", {})

    @pytest.mark.asyncio
    async def test_get_queue_depth_not_connected(self, publisher: NatsFramePublisher) -> None:
        with pytest.raises(RuntimeError, match="not connected"):
            await publisher.get_queue_depth()

    @pytest.mark.asyncio
    async def test_publish_frame_with_mock_js(self, publisher: NatsFramePublisher) -> None:
        mock_js = MagicMock()
        mock_ack = MagicMock()
        mock_ack.seq = 42
        mock_js.publish = AsyncMock(return_value=mock_ack)
        publisher._js = mock_js

        seq = await publisher.publish_frame(
            "cam_001",
            b"\xff\xd8frame_data",
            {"camera_id": "cam_001", "frame_index": 0},
        )

        assert seq == 42
        mock_js.publish.assert_called_once()
        call_args = mock_js.publish.call_args
        assert call_args[0][0] == f"{SUBJECT_FRAMES}.cam_001"
        assert call_args[0][1] == b"\xff\xd8frame_data"
        headers = call_args[1]["headers"]
        assert headers["Camera-Id"] == "cam_001"

    @pytest.mark.asyncio
    async def test_publish_frame_offline_headers(self, publisher: NatsFramePublisher) -> None:
        mock_js = MagicMock()
        mock_ack = MagicMock()
        mock_ack.seq = 10
        mock_js.publish = AsyncMock(return_value=mock_ack)
        publisher._js = mock_js

        await publisher.publish_frame(
            "cam_001",
            b"data",
            {"offline_upload": True, "session_id": "sess_123"},
        )

        headers = mock_js.publish.call_args[1]["headers"]
        assert headers["X-Offline-Upload"] == "true"
        assert headers["X-Session-Id"] == "sess_123"

    @pytest.mark.asyncio
    async def test_publish_health_event_with_mock_js(self, publisher: NatsFramePublisher) -> None:
        mock_js = MagicMock()
        mock_ack = MagicMock()
        mock_ack.seq = 5
        mock_js.publish = AsyncMock(return_value=mock_ack)
        publisher._js = mock_js

        event = {"camera_id": "cam_001", "status": "online", "fps_actual": 10.0}
        seq = await publisher.publish_health_event("cam_001", event)

        assert seq == 5
        call_args = mock_js.publish.call_args
        assert call_args[0][0] == "events.health.cam_001"
        payload = json.loads(call_args[0][1])
        assert payload["camera_id"] == "cam_001"

    @pytest.mark.asyncio
    async def test_get_queue_depth_returns_message_count(
        self, publisher: NatsFramePublisher
    ) -> None:
        mock_js = MagicMock()
        mock_info = MagicMock()
        mock_info.state.messages = 123
        mock_js.stream_info = AsyncMock(return_value=mock_info)
        publisher._js = mock_js

        depth = await publisher.get_queue_depth("cam_001")

        assert depth == 123
        mock_js.stream_info.assert_called_once_with(STREAM_FRAMES)

    @pytest.mark.asyncio
    async def test_get_queue_depth_returns_zero_on_error(
        self, publisher: NatsFramePublisher
    ) -> None:
        mock_js = MagicMock()
        mock_js.stream_info = AsyncMock(side_effect=Exception("stream not found"))
        publisher._js = mock_js

        depth = await publisher.get_queue_depth("cam_001")

        assert depth == 0

    @pytest.mark.asyncio
    async def test_close_when_connected(self, publisher: NatsFramePublisher) -> None:
        mock_nc = MagicMock()
        mock_nc.close = AsyncMock()
        publisher._nc = mock_nc

        await publisher.close()

        mock_nc.close.assert_called_once()

    @pytest.mark.asyncio
    async def test_close_when_not_connected(self, publisher: NatsFramePublisher) -> None:
        await publisher.close()
