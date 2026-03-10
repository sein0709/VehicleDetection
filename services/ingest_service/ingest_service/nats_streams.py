"""Deprecated — use ``shared_contracts.nats_streams`` instead.

This module re-exports from the canonical shared location for backwards
compatibility.  It will be removed in a future release.
"""

from shared_contracts.nats_streams import (  # noqa: F401
    ALL_STREAM_NAMES,
    CONSUMER_AGGREGATOR_CROSSINGS,
    CONSUMER_AGGREGATOR_RECOMPUTE,
    CONSUMER_DEFS,
    CONSUMER_INFERENCE_WORKER,
    CONSUMER_NOTIFICATION_CROSSINGS,
    CONSUMER_NOTIFICATION_HEALTH,
    STREAM_ALERTS,
    STREAM_COMMANDS,
    STREAM_CROSSINGS,
    STREAM_DEFS,
    STREAM_DLQ,
    STREAM_FRAMES,
    STREAM_HEALTH,
    STREAM_TRACKS,
    ensure_all,
    ensure_consumers,
    ensure_streams,
)
