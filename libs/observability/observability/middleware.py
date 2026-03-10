"""One-call setup that wires logging, metrics, and tracing into a FastAPI app.

Usage::

    app = FastAPI(...)
    setup_observability(app, service_name="auth-service")
"""

from __future__ import annotations

import time
from typing import TYPE_CHECKING, Any
from uuid import uuid4

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

from observability.logging import (
    get_logger,
    org_id_var,
    request_id_var,
    setup_logging,
)
from observability.metrics import (
    MetricsMiddleware,
    get_metrics_app,
    register_service_info,
)
from observability.tracing import instrument_fastapi, setup_tracing

if TYPE_CHECKING:
    from fastapi import FastAPI

logger = get_logger(__name__)


class RequestContextMiddleware(BaseHTTPMiddleware):
    """Populate contextvars and response headers for every HTTP request."""

    def __init__(self, app: Any, *, service_name: str) -> None:
        super().__init__(app)
        self.service_name = service_name

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        rid = request.headers.get("x-request-id") or uuid4().hex
        request_id_var.set(rid)
        request.state.request_id = rid

        org = request.headers.get("x-org-id", "")
        if org:
            org_id_var.set(org)

        start = time.monotonic()
        response = await call_next(request)
        elapsed_ms = round((time.monotonic() - start) * 1000, 1)

        response.headers["X-Request-ID"] = rid

        logger.info(
            "http_request",
            method=request.method,
            path=request.url.path,
            status_code=response.status_code,
            duration_ms=elapsed_ms,
            service=self.service_name,
        )

        return response


def setup_observability(
    app: FastAPI,
    *,
    service_name: str,
    service_version: str = "0.1.0",
    log_level: str = "INFO",
    json_logs: bool = True,
    tracing_enabled: bool = True,
    otlp_endpoint: str = "",
) -> None:
    """Wire structured logging, Prometheus metrics, and OTel tracing into *app*.

    This replaces the per-service request-ID middleware and ad-hoc ``/metrics``
    endpoints with a unified observability stack.
    """
    setup_logging(service_name=service_name, log_level=log_level, json_output=json_logs)

    register_service_info(service_name, version=service_version)

    setup_tracing(
        service_name=service_name,
        otlp_endpoint=otlp_endpoint,
        enabled=tracing_enabled,
    )

    instrument_fastapi(app, service_name=service_name)

    app.add_middleware(RequestContextMiddleware, service_name=service_name)

    app.add_middleware(MetricsMiddleware, service_name=service_name)  # type: ignore[arg-type]

    app.mount("/metrics", get_metrics_app())
