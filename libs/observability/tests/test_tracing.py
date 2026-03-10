"""Tests for the OpenTelemetry tracing module."""

from __future__ import annotations

from opentelemetry import trace

from observability.tracing import get_tracer, setup_tracing


class TestSetupTracing:
    def test_disabled_returns_none(self) -> None:
        result = setup_tracing(service_name="test", enabled=False)
        assert result is None

    def test_enabled_returns_provider(self) -> None:
        provider = setup_tracing(
            service_name="test-tracing",
            otlp_endpoint="http://localhost:4317",
            enabled=True,
        )
        assert provider is not None
        provider.shutdown()

    def test_get_tracer_returns_tracer(self) -> None:
        tracer = get_tracer("test.module")
        assert tracer is not None

    def test_tracer_creates_spans(self) -> None:
        provider = setup_tracing(
            service_name="span-test",
            otlp_endpoint="http://localhost:4317",
            enabled=True,
        )
        tracer = get_tracer("test.spans")
        with tracer.start_as_current_span("test-span") as span:
            assert span is not None
            span.set_attribute("test.key", "test-value")
        if provider:
            provider.shutdown()
