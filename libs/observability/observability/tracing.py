"""OpenTelemetry distributed tracing setup.

Configures the OTLP gRPC exporter targeting a Tempo/Jaeger collector.
Automatically instruments FastAPI, httpx, Redis, and SQLAlchemy when
their instrumentors are available.
"""

from __future__ import annotations

import os
from typing import TYPE_CHECKING

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

if TYPE_CHECKING:
    pass


def setup_tracing(
    *,
    service_name: str,
    otlp_endpoint: str = "",
    enabled: bool = True,
) -> TracerProvider | None:
    """Initialise the OTel TracerProvider and auto-instrument known libraries.

    Returns the configured provider, or ``None`` if tracing is disabled.
    """
    if not enabled:
        return None

    endpoint = otlp_endpoint or os.getenv(
        "OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317"
    )

    resource = Resource.create(
        {
            "service.name": service_name,
            "service.namespace": "greyeye",
            "deployment.environment": os.getenv("GREYEYE_ENV", "development"),
        }
    )

    provider = TracerProvider(resource=resource)

    from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

    exporter = OTLPSpanExporter(endpoint=endpoint, insecure=True)
    provider.add_span_processor(BatchSpanProcessor(exporter))

    trace.set_tracer_provider(provider)

    _auto_instrument(service_name)

    return provider


def _auto_instrument(service_name: str) -> None:
    """Best-effort auto-instrumentation for common libraries."""
    try:
        from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

        HTTPXClientInstrumentor().instrument()
    except (ImportError, Exception):
        pass

    try:
        from opentelemetry.instrumentation.redis import RedisInstrumentor

        RedisInstrumentor().instrument()
    except (ImportError, Exception):
        pass

    try:
        from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

        SQLAlchemyInstrumentor().instrument()
    except (ImportError, Exception):
        pass

    try:
        from opentelemetry.instrumentation.logging import LoggingInstrumentor

        LoggingInstrumentor().instrument(set_logging_format=False)
    except (ImportError, Exception):
        pass


def instrument_fastapi(app: object, *, service_name: str) -> None:
    """Instrument a FastAPI/Starlette app with OpenTelemetry."""
    try:
        from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

        FastAPIInstrumentor.instrument_app(
            app,  # type: ignore[arg-type]
            excluded_urls="healthz,readyz,metrics",
        )
    except (ImportError, Exception):
        pass


def get_tracer(name: str) -> trace.Tracer:
    """Return an OTel tracer bound to the given module name."""
    return trace.get_tracer(name)
