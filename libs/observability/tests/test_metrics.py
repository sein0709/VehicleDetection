"""Tests for the Prometheus metrics module."""

from __future__ import annotations

from prometheus_client import REGISTRY

from observability.metrics import (
    AGGREGATOR_EVENTS_CONSUMED,
    ALERTS_FIRED,
    HTTP_ACTIVE_REQUESTS,
    HTTP_REQUEST_DURATION,
    HTTP_REQUESTS_TOTAL,
    INFERENCE_CROSSINGS,
    INFERENCE_DETECTIONS,
    INFERENCE_FRAME_DURATION,
    NATS_MESSAGES_RECEIVED,
    SERVICE_INFO,
    _normalize_path,
    register_service_info,
)


class TestNormalizePath:
    def test_uuid_collapsed(self) -> None:
        path = "/v1/sites/550e8400-e29b-41d4-a716-446655440000/cameras"
        assert _normalize_path(path) == "/v1/sites/{id}/cameras"

    def test_numeric_id_collapsed(self) -> None:
        path = "/v1/users/12345"
        assert _normalize_path(path) == "/v1/users/{id}"

    def test_no_ids_unchanged(self) -> None:
        path = "/v1/auth/login"
        assert _normalize_path(path) == "/v1/auth/login"

    def test_multiple_uuids(self) -> None:
        path = "/v1/orgs/550e8400-e29b-41d4-a716-446655440000/sites/660e8400-e29b-41d4-a716-446655440001"
        assert _normalize_path(path) == "/v1/orgs/{id}/sites/{id}"


class TestMetricsRegistered:
    """Verify that all expected metrics are registered in the global registry."""

    def test_http_metrics_exist(self) -> None:
        names = {m.name for m in REGISTRY.collect()}
        assert "http_request_duration_seconds" in names
        assert "http_requests_total" in names
        assert "http_active_requests" in names

    def test_inference_metrics_exist(self) -> None:
        names = {m.name for m in REGISTRY.collect()}
        assert "inference_frame_duration_seconds" in names
        assert "inference_stage_duration_seconds" in names
        assert "inference_detections_total" in names
        assert "inference_crossings_total" in names
        assert "inference_queue_pending_messages" in names

    def test_aggregator_metrics_exist(self) -> None:
        names = {m.name for m in REGISTRY.collect()}
        assert "aggregator_bucket_lag_seconds" in names
        assert "aggregator_flush_rows" in names
        assert "aggregator_events_consumed_total" in names
        assert "aggregator_late_events_total" in names

    def test_alert_metrics_exist(self) -> None:
        names = {m.name for m in REGISTRY.collect()}
        assert "alerts_fired_total" in names
        assert "alerts_suppressed_total" in names
        assert "alert_delivery_duration_seconds" in names
        assert "alert_delivery_failures_total" in names

    def test_nats_metrics_exist(self) -> None:
        names = {m.name for m in REGISTRY.collect()}
        assert "nats_messages_received_total" in names
        assert "nats_messages_acked_total" in names
        assert "nats_messages_nacked_total" in names
        assert "nats_dlq_messages_total" in names

    def test_db_pool_metrics_exist(self) -> None:
        names = {m.name for m in REGISTRY.collect()}
        assert "db_pool_connections" in names


class TestMetricsIncrement:
    def test_counter_increment(self) -> None:
        before = INFERENCE_DETECTIONS.labels(camera_id="test-cam")._value.get()
        INFERENCE_DETECTIONS.labels(camera_id="test-cam").inc()
        after = INFERENCE_DETECTIONS.labels(camera_id="test-cam")._value.get()
        assert after == before + 1

    def test_histogram_observe(self) -> None:
        INFERENCE_FRAME_DURATION.labels(camera_id="test-cam").observe(0.42)

    def test_labeled_counter(self) -> None:
        INFERENCE_CROSSINGS.labels(
            camera_id="cam-1", direction="inbound", vehicle_class="sedan"
        ).inc()
        NATS_MESSAGES_RECEIVED.labels(
            stream="frames", consumer="inference-worker", service="inference-worker"
        ).inc()

    def test_gauge_set(self) -> None:
        HTTP_ACTIVE_REQUESTS.labels(service="test").set(5)
        assert HTTP_ACTIVE_REQUESTS.labels(service="test")._value.get() == 5


class TestServiceInfo:
    def test_register_service_info(self) -> None:
        register_service_info("test-service", version="1.2.3", commit="abc123")
