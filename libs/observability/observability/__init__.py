"""GreyEye shared observability — structured logging, Prometheus metrics, OpenTelemetry tracing.

Usage in a FastAPI service::

    from observability import setup_observability, get_logger

    app = FastAPI()
    setup_observability(app, service_name="auth-service")
    logger = get_logger("auth_service.routes")
    logger.info("request processed", user_id="abc", latency_ms=42.1)
"""

from observability.logging import get_logger, setup_logging
from observability.sanitization import sanitize_log_message, sanitize_structlog_processor
from observability.metrics import (
    MetricsMiddleware,
    get_metrics_app,
    register_service_info,
)
from observability.middleware import setup_observability
from observability.tracing import setup_tracing
from observability.security_events import (
    SecurityEvent,
    SecurityEventType,
    SecuritySeverity,
    emit_security_event,
)

__all__ = [
    "MetricsMiddleware",
    "SecurityEvent",
    "SecurityEventType",
    "SecuritySeverity",
    "emit_security_event",
    "get_logger",
    "get_metrics_app",
    "register_service_info",
    "sanitize_log_message",
    "sanitize_structlog_processor",
    "setup_logging",
    "setup_observability",
    "setup_tracing",
]
