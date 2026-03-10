"""Dead-letter queue (DLQ) handler for NATS JetStream consumers.

Provides ``DLQHandler`` — a reusable component that wraps message processing
with automatic DLQ routing when a message exceeds its retry budget.

Usage in a consumer service::

    handler = DLQHandler(js)
    async for msg in subscription.messages:
        await handler.process(msg, callback=my_processing_fn)
"""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING, Awaitable, Callable

from shared_contracts.nats_streams import dlq_subject_for

if TYPE_CHECKING:
    from nats.aio.msg import Msg
    from nats.js import JetStreamContext

logger = logging.getLogger(__name__)

MessageCallback = Callable[["Msg"], Awaitable[None]]


class DLQHandler:
    """Wraps message processing with dead-letter routing on terminal failure.

    When a message's ``num_delivered`` reaches ``max_deliver``, the handler
    publishes a copy to the DLQ stream and ACKs the original (removing it
    from the source stream) so it doesn't block the consumer.

    For messages that haven't exhausted retries, a processing failure
    triggers a NAK so NATS redelivers according to the consumer's backoff.
    """

    def __init__(
        self,
        js: JetStreamContext,
        *,
        max_deliver: int = 3,
    ) -> None:
        self._js = js
        self._max_deliver = max_deliver
        self._dlq_count = 0
        self._processed_count = 0
        self._error_count = 0

    @property
    def stats(self) -> dict[str, int]:
        return {
            "processed": self._processed_count,
            "errors": self._error_count,
            "dlq_routed": self._dlq_count,
        }

    async def process(
        self,
        msg: Msg,
        callback: MessageCallback,
    ) -> bool:
        """Process a single message with DLQ fallback.

        Returns True if the message was successfully processed, False if it
        was NAK'd or routed to the DLQ.
        """
        num_delivered = _get_num_delivered(msg)
        is_last_attempt = num_delivered >= self._max_deliver

        try:
            await callback(msg)
            await msg.ack()
            self._processed_count += 1
            return True

        except Exception as exc:
            self._error_count += 1
            error_reason = f"{type(exc).__name__}: {exc}"

            if is_last_attempt:
                await self._route_to_dlq(msg, error_reason)
                return False

            logger.warning(
                "Processing failed (attempt %d/%d, subject=%s): %s",
                num_delivered,
                self._max_deliver,
                msg.subject,
                error_reason,
            )
            try:
                await msg.nak()
            except Exception:
                logger.exception("Failed to NAK message on subject %s", msg.subject)
            return False

    async def _route_to_dlq(self, msg: Msg, error_reason: str) -> None:
        """Publish the message to the DLQ and ACK the original."""
        dlq_subj = dlq_subject_for(msg.subject)
        headers = dict(msg.headers) if msg.headers else {}
        headers["X-DLQ-Original-Subject"] = msg.subject
        headers["X-DLQ-Error-Reason"] = error_reason
        headers["X-DLQ-Attempts"] = str(_get_num_delivered(msg))

        try:
            await self._js.publish(dlq_subj, msg.data, headers=headers)
            self._dlq_count += 1
            logger.warning(
                "Message routed to DLQ after %d attempts: %s → %s (reason=%s)",
                _get_num_delivered(msg),
                msg.subject,
                dlq_subj,
                error_reason,
            )
        except Exception:
            logger.exception(
                "Failed to publish to DLQ %s; message will be redelivered",
                dlq_subj,
            )
            try:
                await msg.nak()
            except Exception:
                pass
            return

        try:
            await msg.ack()
        except Exception:
            logger.exception("Failed to ACK original message after DLQ routing")


def _get_num_delivered(msg: Msg) -> int:
    """Extract the delivery count from a JetStream message.

    The ``num_delivered`` attribute is set by the NATS server on each
    redelivery.  Falls back to 1 if unavailable.
    """
    meta = getattr(msg, "metadata", None)
    if meta is not None:
        return getattr(meta, "num_delivered", 1)
    return 1
