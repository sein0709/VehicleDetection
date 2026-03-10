"""Prometheus metrics via prometheus_client.

Defines standard metrics for every GreyEye service (HTTP request duration,
active connections, etc.) and domain-specific metrics for the inference
pipeline, aggregation, and alerting subsystems.

The ``/metrics`` endpoint is served by a separate ASGI app so that Prometheus
scraping does not inflate the main app's request counters.
"""

from __future__ import annotations

import time
from typing import TYPE_CHECKING, Any

from prometheus_client import (
    REGISTRY,
    CollectorRegistry,
    Counter,
    Gauge,
    Histogram,
    Info,
    generate_latest,
)

if TYPE_CHECKING:
    from starlette.requests import Request
    from starlette.responses import Response

# ---------------------------------------------------------------------------
# Global registry — shared across the process
# ---------------------------------------------------------------------------

_registry: CollectorRegistry = REGISTRY

# ---------------------------------------------------------------------------
# HTTP metrics (attached by MetricsMiddleware)
# ---------------------------------------------------------------------------

HTTP_REQUEST_DURATION = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    labelnames=["method", "path", "status_code", "service"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0),
    registry=_registry,
)

HTTP_REQUESTS_TOTAL = Counter(
    "http_requests_total",
    "Total HTTP requests",
    labelnames=["method", "path", "status_code", "service"],
    registry=_registry,
)

HTTP_ACTIVE_REQUESTS = Gauge(
    "http_active_requests",
    "Currently in-flight HTTP requests",
    labelnames=["service"],
    registry=_registry,
)

# ---------------------------------------------------------------------------
# Inference pipeline metrics
# ---------------------------------------------------------------------------

INFERENCE_FRAME_DURATION = Histogram(
    "inference_frame_duration_seconds",
    "End-to-end inference latency per frame",
    labelnames=["camera_id"],
    buckets=(0.05, 0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 5.0),
    registry=_registry,
)

INFERENCE_STAGE_DURATION = Histogram(
    "inference_stage_duration_seconds",
    "Duration of each inference pipeline stage",
    labelnames=["stage"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0),
    registry=_registry,
)

INFERENCE_DETECTIONS = Counter(
    "inference_detections_total",
    "Total vehicle detections",
    labelnames=["camera_id"],
    registry=_registry,
)

INFERENCE_CROSSINGS = Counter(
    "inference_crossings_total",
    "Total line crossing events emitted",
    labelnames=["camera_id", "direction", "vehicle_class"],
    registry=_registry,
)

INFERENCE_QUEUE_DEPTH = Gauge(
    "inference_queue_pending_messages",
    "Pending messages in the inference consumer queue",
    registry=_registry,
)

INFERENCE_GPU_UTILIZATION = Gauge(
    "inference_gpu_utilization_percent",
    "GPU utilization percentage (if available)",
    registry=_registry,
)

# ---------------------------------------------------------------------------
# Aggregation metrics
# ---------------------------------------------------------------------------

AGGREGATOR_BUCKET_LAG = Histogram(
    "aggregator_bucket_lag_seconds",
    "Lag between event timestamp and aggregation flush",
    buckets=(0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0),
    registry=_registry,
)

AGGREGATOR_FLUSH_ROWS = Histogram(
    "aggregator_flush_rows",
    "Number of rows per flush batch",
    buckets=(1, 5, 10, 25, 50, 100, 250, 500, 1000),
    registry=_registry,
)

AGGREGATOR_EVENTS_CONSUMED = Counter(
    "aggregator_events_consumed_total",
    "Total crossing events consumed by the aggregator",
    registry=_registry,
)

AGGREGATOR_LATE_EVENTS = Counter(
    "aggregator_late_events_total",
    "Events arriving for already-flushed buckets",
    registry=_registry,
)

# ---------------------------------------------------------------------------
# Notification / alert metrics
# ---------------------------------------------------------------------------

ALERTS_FIRED = Counter(
    "alerts_fired_total",
    "Total alerts triggered",
    labelnames=["condition_type", "severity"],
    registry=_registry,
)

ALERTS_SUPPRESSED = Counter(
    "alerts_suppressed_total",
    "Alerts suppressed by cooldown deduplication",
    registry=_registry,
)

ALERT_DELIVERY_DURATION = Histogram(
    "alert_delivery_duration_seconds",
    "Time to deliver an alert notification",
    labelnames=["channel"],
    buckets=(0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0),
    registry=_registry,
)

ALERT_DELIVERY_FAILURES = Counter(
    "alert_delivery_failures_total",
    "Failed alert deliveries",
    labelnames=["channel"],
    registry=_registry,
)

# ---------------------------------------------------------------------------
# NATS consumer metrics
# ---------------------------------------------------------------------------

NATS_MESSAGES_RECEIVED = Counter(
    "nats_messages_received_total",
    "Total NATS messages received",
    labelnames=["stream", "consumer", "service"],
    registry=_registry,
)

NATS_MESSAGES_ACKED = Counter(
    "nats_messages_acked_total",
    "Total NATS messages acknowledged",
    labelnames=["stream", "consumer", "service"],
    registry=_registry,
)

NATS_MESSAGES_NACKED = Counter(
    "nats_messages_nacked_total",
    "Total NATS messages negatively acknowledged",
    labelnames=["stream", "consumer", "service"],
    registry=_registry,
)

NATS_DLQ_MESSAGES = Counter(
    "nats_dlq_messages_total",
    "Messages sent to the dead-letter queue",
    labelnames=["stream", "service"],
    registry=_registry,
)

# ---------------------------------------------------------------------------
# Database connection pool metrics
# ---------------------------------------------------------------------------

DB_POOL_SIZE = Gauge(
    "db_pool_connections",
    "Current database connection pool size",
    labelnames=["state", "service"],
    registry=_registry,
)

# ---------------------------------------------------------------------------
# Service info
# ---------------------------------------------------------------------------

SERVICE_INFO = Info(
    "greyeye_service",
    "Service build information",
    registry=_registry,
)


def register_service_info(
    service_name: str,
    version: str = "0.1.0",
    **extra: str,
) -> None:
    SERVICE_INFO.info({"service": service_name, "version": version, **extra})


# ---------------------------------------------------------------------------
# Metrics ASGI app (mounted at /metrics)
# ---------------------------------------------------------------------------


def _normalize_path(path: str) -> str:
    """Collapse UUID/numeric path segments to reduce cardinality."""
    import re

    path = re.sub(
        r"/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
        "/{id}",
        path,
    )
    path = re.sub(r"/\d+", "/{id}", path)
    return path


class MetricsMiddleware:
    """Starlette middleware that records HTTP request metrics."""

    def __init__(self, app: Any, *, service_name: str) -> None:
        self.app = app
        self.service_name = service_name

    async def __call__(self, scope: dict, receive: Any, send: Any) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        path = _normalize_path(scope.get("path", ""))
        method = scope.get("method", "GET")

        if path == "/metrics" or path == "/healthz":
            await self.app(scope, receive, send)
            return

        HTTP_ACTIVE_REQUESTS.labels(service=self.service_name).inc()
        start = time.monotonic()
        status_code = "500"

        async def send_wrapper(message: dict) -> None:
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = str(message["status"])
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)
        finally:
            duration = time.monotonic() - start
            HTTP_REQUEST_DURATION.labels(
                method=method,
                path=path,
                status_code=status_code,
                service=self.service_name,
            ).observe(duration)
            HTTP_REQUESTS_TOTAL.labels(
                method=method,
                path=path,
                status_code=status_code,
                service=self.service_name,
            ).inc()
            HTTP_ACTIVE_REQUESTS.labels(service=self.service_name).dec()


def get_metrics_app() -> Any:
    """Return a minimal ASGI app that serves ``/metrics`` in Prometheus format."""
    from starlette.applications import Starlette
    from starlette.responses import Response
    from starlette.routing import Route

    async def metrics_endpoint(request: Request) -> Response:
        body = generate_latest(_registry)
        return Response(content=body, media_type="text/plain; version=0.0.4; charset=utf-8")

    return Starlette(routes=[Route("/metrics", metrics_endpoint)])
