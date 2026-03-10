"""NATS JetStream stream, consumer, and DLQ configuration for GreyEye.

This is the single source of truth for all stream/subject definitions used
across the system.  Every service imports from here rather than defining
its own constants.

The module is split into two layers:

1. **Pure-Python constants and dataclasses** — importable without nats-py
   (stream names, subject prefixes, consumer durable names).
2. **Async helpers** that require a live ``JetStreamContext`` — stream
   creation, consumer creation, DLQ routing.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from nats.js import JetStreamContext

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Stream names
# ---------------------------------------------------------------------------
STREAM_FRAMES = "FRAMES"
STREAM_CROSSINGS = "CROSSINGS"
STREAM_TRACKS = "TRACKS"
STREAM_HEALTH = "HEALTH"
STREAM_ALERTS = "ALERTS"
STREAM_COMMANDS = "COMMANDS"
STREAM_DLQ = "DLQ"

ALL_STREAM_NAMES: list[str] = [
    STREAM_FRAMES,
    STREAM_CROSSINGS,
    STREAM_TRACKS,
    STREAM_HEALTH,
    STREAM_ALERTS,
    STREAM_COMMANDS,
    STREAM_DLQ,
]

# ---------------------------------------------------------------------------
# Subject prefixes  (wildcard patterns use NATS ">" token)
# ---------------------------------------------------------------------------
SUBJECT_FRAMES = "frames"
SUBJECT_CROSSINGS = "events.crossings"
SUBJECT_TRACKS = "events.tracks"
SUBJECT_HEALTH = "events.health"
SUBJECT_ALERTS = "events.alerts"
SUBJECT_COMMANDS = "commands"
SUBJECT_DLQ = "events.dlq"

# Recompute command subject consumed by the Aggregation Service
SUBJECT_RECOMPUTE = "commands.recompute"

# ---------------------------------------------------------------------------
# Consumer durable names
# ---------------------------------------------------------------------------
CONSUMER_INFERENCE_WORKER = "inference-worker-consumer"
CONSUMER_AGGREGATOR_CROSSINGS = "aggregator-crossings-consumer"
CONSUMER_NOTIFICATION_CROSSINGS = "notification-crossings-consumer"
CONSUMER_NOTIFICATION_HEALTH = "notification-health-consumer"
CONSUMER_AGGREGATOR_RECOMPUTE = "aggregator-recompute-consumer"

# ---------------------------------------------------------------------------
# Time constants (nanoseconds for NATS API, seconds for readability)
# ---------------------------------------------------------------------------
_SECONDS = 1
_HOURS = 3600 * _SECONDS
_DAYS = 24 * _HOURS

MAX_AGE_24H_S = 24 * _HOURS
MAX_AGE_7D_S = 7 * _DAYS
MAX_AGE_30D_S = 30 * _DAYS


# ---------------------------------------------------------------------------
# Declarative configuration dataclasses
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class StreamDef:
    """Declarative definition of a NATS JetStream stream."""

    name: str
    subjects: list[str]
    max_age_seconds: float
    description: str = ""
    max_bytes: int | None = None
    max_msgs: int | None = None
    max_msg_size: int | None = None

    def subject_for(self, token: str) -> str:
        """Return a concrete subject by appending *token* to the first prefix.

        >>> StreamDef("X", ["events.crossings.>"], 0).subject_for("cam_001")
        'events.crossings.cam_001'
        """
        base = self.subjects[0].removesuffix(".>").removesuffix(".*")
        return f"{base}.{token}"


@dataclass(frozen=True)
class ConsumerDef:
    """Declarative definition of a NATS JetStream pull consumer."""

    stream_name: str
    durable_name: str
    filter_subject: str
    deliver_policy: str = "all"
    ack_wait_seconds: float = 30.0
    max_deliver: int = 3
    description: str = ""


# ---------------------------------------------------------------------------
# Stream definitions
# ---------------------------------------------------------------------------
STREAM_DEFS: list[StreamDef] = [
    StreamDef(
        name=STREAM_FRAMES,
        subjects=[f"{SUBJECT_FRAMES}.>"],
        max_age_seconds=MAX_AGE_24H_S,
        max_msgs=100_000,
        max_msg_size=10 * 1024 * 1024,
        description="Raw camera frames from ingest → inference worker",
    ),
    StreamDef(
        name=STREAM_CROSSINGS,
        subjects=[f"{SUBJECT_CROSSINGS}.>"],
        max_age_seconds=MAX_AGE_7D_S,
        description="Vehicle crossing events → aggregator, notification service",
    ),
    StreamDef(
        name=STREAM_TRACKS,
        subjects=[f"{SUBJECT_TRACKS}.>"],
        max_age_seconds=MAX_AGE_7D_S,
        description="Track lifecycle events → live monitor (Redis)",
    ),
    StreamDef(
        name=STREAM_HEALTH,
        subjects=[f"{SUBJECT_HEALTH}.>"],
        max_age_seconds=MAX_AGE_7D_S,
        description="Camera health events → notification service",
    ),
    StreamDef(
        name=STREAM_ALERTS,
        subjects=[f"{SUBJECT_ALERTS}.>"],
        max_age_seconds=MAX_AGE_7D_S,
        description="Alert lifecycle events → mobile push, email, webhook",
    ),
    StreamDef(
        name=STREAM_COMMANDS,
        subjects=[f"{SUBJECT_COMMANDS}.>"],
        max_age_seconds=MAX_AGE_7D_S,
        description="Operator commands (recompute, config reload, etc.)",
    ),
    StreamDef(
        name=STREAM_DLQ,
        subjects=[f"{SUBJECT_DLQ}.>"],
        max_age_seconds=MAX_AGE_30D_S,
        description="Dead-letter queue for messages that exceeded max_deliver",
    ),
]

STREAM_DEFS_BY_NAME: dict[str, StreamDef] = {s.name: s for s in STREAM_DEFS}

# ---------------------------------------------------------------------------
# Consumer definitions
# ---------------------------------------------------------------------------
CONSUMER_DEFS: list[ConsumerDef] = [
    # Inference worker pulls raw frames
    ConsumerDef(
        stream_name=STREAM_FRAMES,
        durable_name=CONSUMER_INFERENCE_WORKER,
        filter_subject=f"{SUBJECT_FRAMES}.>",
        deliver_policy="last",
        ack_wait_seconds=30.0,
        max_deliver=3,
        description="Inference worker consuming camera frames",
    ),
    # Aggregator consumes crossing events for 15-min bucket rollup
    ConsumerDef(
        stream_name=STREAM_CROSSINGS,
        durable_name=CONSUMER_AGGREGATOR_CROSSINGS,
        filter_subject=f"{SUBJECT_CROSSINGS}.>",
        deliver_policy="all",
        ack_wait_seconds=30.0,
        max_deliver=5,
        description="Aggregator consuming crossing events for bucket rollup",
    ),
    # Notification service consumes crossing events for alert rule evaluation
    ConsumerDef(
        stream_name=STREAM_CROSSINGS,
        durable_name=CONSUMER_NOTIFICATION_CROSSINGS,
        filter_subject=f"{SUBJECT_CROSSINGS}.>",
        deliver_policy="last",
        ack_wait_seconds=15.0,
        max_deliver=3,
        description="Notification service consuming crossing events for alerts",
    ),
    # Notification service consumes health events for camera-offline alerts
    ConsumerDef(
        stream_name=STREAM_HEALTH,
        durable_name=CONSUMER_NOTIFICATION_HEALTH,
        filter_subject=f"{SUBJECT_HEALTH}.>",
        deliver_policy="last",
        ack_wait_seconds=15.0,
        max_deliver=3,
        description="Notification service consuming camera health events",
    ),
    # Aggregator consumes recompute commands
    ConsumerDef(
        stream_name=STREAM_COMMANDS,
        durable_name=CONSUMER_AGGREGATOR_RECOMPUTE,
        filter_subject=SUBJECT_RECOMPUTE,
        deliver_policy="all",
        ack_wait_seconds=60.0,
        max_deliver=3,
        description="Aggregator consuming recompute commands",
    ),
]

CONSUMER_DEFS_BY_DURABLE: dict[str, ConsumerDef] = {c.durable_name: c for c in CONSUMER_DEFS}


# ---------------------------------------------------------------------------
# DLQ subject mapping
# ---------------------------------------------------------------------------
def dlq_subject_for(original_subject: str) -> str:
    """Map an original subject to its DLQ counterpart.

    >>> dlq_subject_for("events.crossings.cam_001")
    'events.dlq.crossings.cam_001'
    >>> dlq_subject_for("frames.cam_002")
    'events.dlq.frames.cam_002'
    """
    if original_subject.startswith("events."):
        remainder = original_subject.removeprefix("events.")
        return f"{SUBJECT_DLQ}.{remainder}"
    return f"{SUBJECT_DLQ}.{original_subject}"


# ---------------------------------------------------------------------------
# Async helpers (require nats-py at runtime)
# ---------------------------------------------------------------------------
def _to_stream_config(sdef: StreamDef, *, replicas: int, max_bytes_override: int | None):
    """Convert a StreamDef to a nats StreamConfig."""
    from nats.js.api import RetentionPolicy, StorageType, StreamConfig

    kwargs: dict = {
        "name": sdef.name,
        "subjects": list(sdef.subjects),
        "retention": RetentionPolicy.LIMITS,
        "storage": StorageType.FILE,
        "max_age": sdef.max_age_seconds,
        "num_replicas": replicas,
    }
    effective_max_bytes = max_bytes_override or sdef.max_bytes
    if effective_max_bytes is not None:
        kwargs["max_bytes"] = effective_max_bytes
    if sdef.max_msgs is not None:
        kwargs["max_msgs"] = sdef.max_msgs
    if sdef.max_msg_size is not None:
        kwargs["max_msg_size"] = sdef.max_msg_size
    if sdef.description:
        kwargs["description"] = sdef.description
    return StreamConfig(**kwargs)


def _to_consumer_config(cdef: ConsumerDef):
    """Convert a ConsumerDef to a nats ConsumerConfig."""
    from nats.js.api import ConsumerConfig, DeliverPolicy

    policy_map = {
        "all": DeliverPolicy.ALL,
        "last": DeliverPolicy.LAST,
        "new": DeliverPolicy.NEW,
        "last_per_subject": DeliverPolicy.LAST_PER_SUBJECT,
    }
    return ConsumerConfig(
        durable_name=cdef.durable_name,
        filter_subject=cdef.filter_subject,
        deliver_policy=policy_map.get(cdef.deliver_policy, DeliverPolicy.ALL),
        ack_wait=cdef.ack_wait_seconds,
        max_deliver=cdef.max_deliver,
        description=cdef.description or None,
    )


async def ensure_streams(
    js: JetStreamContext,
    *,
    replicas: int = 1,
    max_bytes: int | None = None,
    streams: list[StreamDef] | None = None,
) -> list[str]:
    """Create or update all JetStream streams.  Idempotent.

    Args:
        js: Active JetStream context.
        replicas: Number of replicas (1 for dev, 3 for production).
        max_bytes: Optional global max-bytes override for every stream.
        streams: Subset of streams to create.  Defaults to all.

    Returns:
        List of stream names that were created/updated.
    """
    targets = streams or STREAM_DEFS
    created: list[str] = []
    for sdef in targets:
        cfg = _to_stream_config(sdef, replicas=replicas, max_bytes_override=max_bytes)
        try:
            await js.add_stream(cfg)
            created.append(sdef.name)
            logger.info("Stream %s ensured (subjects=%s)", sdef.name, sdef.subjects)
        except Exception:
            logger.exception("Failed to create/update stream %s", sdef.name)
            raise
    return created


async def ensure_consumers(
    js: JetStreamContext,
    *,
    consumers: list[ConsumerDef] | None = None,
) -> list[str]:
    """Create or update all JetStream consumers.  Idempotent.

    Args:
        js: Active JetStream context.
        consumers: Subset of consumers to create.  Defaults to all.

    Returns:
        List of durable names that were created/updated.
    """
    targets = consumers or CONSUMER_DEFS
    created: list[str] = []
    for cdef in targets:
        cfg = _to_consumer_config(cdef)
        try:
            await js.add_consumer(cdef.stream_name, cfg)
            created.append(cdef.durable_name)
            logger.info(
                "Consumer %s ensured on stream %s",
                cdef.durable_name,
                cdef.stream_name,
            )
        except Exception:
            logger.exception(
                "Failed to create/update consumer %s on %s",
                cdef.durable_name,
                cdef.stream_name,
            )
            raise
    return created


async def ensure_all(
    js: JetStreamContext,
    *,
    replicas: int = 1,
    max_bytes: int | None = None,
) -> tuple[list[str], list[str]]:
    """Create all streams and consumers in the correct order.

    Returns:
        Tuple of (stream_names, consumer_durable_names) created.
    """
    stream_names = await ensure_streams(js, replicas=replicas, max_bytes=max_bytes)
    consumer_names = await ensure_consumers(js)
    return stream_names, consumer_names


# ---------------------------------------------------------------------------
# DLQ routing helper
# ---------------------------------------------------------------------------
async def publish_to_dlq(
    js: JetStreamContext,
    *,
    original_subject: str,
    payload: bytes,
    headers: dict[str, str] | None = None,
    error_reason: str = "",
) -> None:
    """Republish a failed message to the dead-letter queue stream.

    Preserves the original subject hierarchy under ``events.dlq.`` and
    attaches diagnostic headers.
    """
    dlq_subj = dlq_subject_for(original_subject)
    dlq_headers = dict(headers or {})
    dlq_headers["X-DLQ-Original-Subject"] = original_subject
    if error_reason:
        dlq_headers["X-DLQ-Error-Reason"] = error_reason

    try:
        await js.publish(dlq_subj, payload, headers=dlq_headers)
        logger.warning(
            "Message routed to DLQ: %s → %s (reason=%s)",
            original_subject,
            dlq_subj,
            error_reason or "max_deliver_exceeded",
        )
    except Exception:
        logger.exception("Failed to publish to DLQ subject %s", dlq_subj)
        raise
