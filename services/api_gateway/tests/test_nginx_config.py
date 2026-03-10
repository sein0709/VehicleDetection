"""Tests for the Nginx configuration structure, routing, rate limiting, TLS,
circuit breaker, CORS, and request correlation."""

from __future__ import annotations

import re
from pathlib import Path
from typing import ClassVar

import pytest

GATEWAY_DIR = Path(__file__).resolve().parent.parent


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _extract_upstreams(text: str) -> dict[str, dict[str, str]]:
    """Return {name: {max_fails, fail_timeout}} for each upstream block."""
    pattern = re.compile(
        r"upstream\s+(\w+)\s*\{[^}]*"
        r"server\s+\S+\s+"
        r"max_fails=(\d+)\s+fail_timeout=(\d+)s",
        re.DOTALL,
    )
    return {
        m.group(1): {"max_fails": m.group(2), "fail_timeout": m.group(3)}
        for m in pattern.finditer(text)
    }


def _extract_rate_limit_zones(text: str) -> dict[str, dict[str, str]]:
    """Return {zone_name: {key, size, rate}} for each limit_req_zone."""
    pattern = re.compile(r"limit_req_zone\s+(\S+)\s+zone=(\w+):(\w+)\s+rate=(\S+);")
    return {
        m.group(2): {"key": m.group(1), "size": m.group(3), "rate": m.group(4)}
        for m in pattern.finditer(text)
    }


def _extract_locations(text: str) -> list[str]:
    """Return all location paths defined in the config."""
    return re.findall(r"location\s+(?:=\s+)?(/\S+)", text)


# ---------------------------------------------------------------------------
# Rate Limiting
# ---------------------------------------------------------------------------


class TestRateLimiting:
    """Verify rate limit zones match the design specification."""

    def test_per_ip_zone(self, nginx_conf_text: str) -> None:
        zones = _extract_rate_limit_zones(nginx_conf_text)
        assert "per_ip" in zones
        assert zones["per_ip"]["rate"] == "1r/s"

    def test_per_user_zone(self, nginx_conf_text: str) -> None:
        zones = _extract_rate_limit_zones(nginx_conf_text)
        assert "per_user" in zones
        assert zones["per_user"]["rate"] == "5r/s"

    def test_per_camera_zone(self, nginx_conf_text: str) -> None:
        zones = _extract_rate_limit_zones(nginx_conf_text)
        assert "per_camera" in zones
        assert zones["per_camera"]["rate"] == "15r/s"

    def test_auth_ip_zone(self, nginx_conf_text: str) -> None:
        zones = _extract_rate_limit_zones(nginx_conf_text)
        assert "auth_ip" in zones
        assert zones["auth_ip"]["rate"] == "10r/m"

    def test_export_user_zone(self, nginx_conf_text: str) -> None:
        zones = _extract_rate_limit_zones(nginx_conf_text)
        assert "export_user" in zones

    def test_rate_limit_status_429(self, nginx_conf_text: str) -> None:
        assert "limit_req_status 429" in nginx_conf_text

    def test_auth_endpoint_uses_auth_ip_zone(self, nginx_conf_text: str) -> None:
        auth_block = re.search(r"location /v1/auth/\s*\{([^}]+)\}", nginx_conf_text)
        assert auth_block is not None
        assert "zone=auth_ip" in auth_block.group(1)

    def test_ingest_uses_per_camera_zone(self, nginx_conf_text: str) -> None:
        ingest_block = re.search(r"location /v1/ingest/\s*\{([^}]+)\}", nginx_conf_text)
        assert ingest_block is not None
        assert "zone=per_camera" in ingest_block.group(1)

    def test_export_uses_export_zone(self, nginx_conf_text: str) -> None:
        export_block = re.search(r"location /v1/reports/export\s*\{([^}]+)\}", nginx_conf_text)
        assert export_block is not None
        assert "zone=export_user" in export_block.group(1)


# ---------------------------------------------------------------------------
# Circuit Breaker (upstream fail parameters)
# ---------------------------------------------------------------------------


class TestCircuitBreaker:
    """Verify upstream circuit breaker config: open after 5 failures, half-open after 15s."""

    EXPECTED_UPSTREAMS: ClassVar[list[str]] = [
        "auth_upstream",
        "config_upstream",
        "ingest_upstream",
        "reporting_upstream",
        "aggregator_upstream",
        "notification_upstream",
    ]

    def test_all_upstreams_defined(self, nginx_conf_text: str) -> None:
        upstreams = _extract_upstreams(nginx_conf_text)
        for name in self.EXPECTED_UPSTREAMS:
            assert name in upstreams, f"Missing upstream: {name}"

    @pytest.mark.parametrize("upstream", EXPECTED_UPSTREAMS)
    def test_max_fails_is_5(self, nginx_conf_text: str, upstream: str) -> None:
        upstreams = _extract_upstreams(nginx_conf_text)
        assert upstreams[upstream]["max_fails"] == "5"

    @pytest.mark.parametrize("upstream", EXPECTED_UPSTREAMS)
    def test_fail_timeout_is_15s(self, nginx_conf_text: str, upstream: str) -> None:
        upstreams = _extract_upstreams(nginx_conf_text)
        assert upstreams[upstream]["fail_timeout"] == "15"

    def test_proxy_next_upstream_configured(self, proxy_params_text: str) -> None:
        assert "proxy_next_upstream" in proxy_params_text
        assert "error" in proxy_params_text
        assert "timeout" in proxy_params_text


# ---------------------------------------------------------------------------
# TLS Configuration
# ---------------------------------------------------------------------------


class TestTLS:
    """Verify TLS settings in the production config."""

    def test_ssl_listen_443(self, nginx_conf_text: str) -> None:
        assert "listen 443 ssl" in nginx_conf_text

    def test_tls_protocols(self, nginx_conf_text: str) -> None:
        assert "TLSv1.2" in nginx_conf_text
        assert "TLSv1.3" in nginx_conf_text

    def test_no_tls_1_0_or_1_1(self, nginx_conf_text: str) -> None:
        proto_line = re.search(r"ssl_protocols\s+([^;]+);", nginx_conf_text)
        assert proto_line is not None
        protocols = proto_line.group(1)
        assert "TLSv1.0" not in protocols
        assert "TLSv1.1" not in protocols

    def test_cipher_suites_present(self, nginx_conf_text: str) -> None:
        assert "TLS_AES_256_GCM_SHA384" in nginx_conf_text
        assert "ECDHE-RSA-AES256-GCM-SHA384" in nginx_conf_text

    def test_ssl_prefer_server_ciphers(self, nginx_conf_text: str) -> None:
        assert "ssl_prefer_server_ciphers on" in nginx_conf_text

    def test_ssl_session_tickets_off(self, nginx_conf_text: str) -> None:
        assert "ssl_session_tickets off" in nginx_conf_text

    def test_hsts_header(self, nginx_conf_text: str) -> None:
        assert "Strict-Transport-Security" in nginx_conf_text
        assert "max-age=31536000" in nginx_conf_text

    def test_http_to_https_redirect(self, nginx_conf_text: str) -> None:
        assert "return 301 https://$host$request_uri" in nginx_conf_text

    def test_dev_config_has_no_ssl(self, nginx_dev_conf_text: str) -> None:
        assert "listen 443 ssl" not in nginx_dev_conf_text
        assert "ssl_certificate" not in nginx_dev_conf_text


# ---------------------------------------------------------------------------
# CORS
# ---------------------------------------------------------------------------


class TestCORS:
    """Verify CORS headers and preflight handling."""

    def test_allow_origin_header(self, nginx_conf_text: str) -> None:
        assert "Access-Control-Allow-Origin" in nginx_conf_text

    def test_allow_methods(self, nginx_conf_text: str) -> None:
        assert "GET, POST, PUT, PATCH, DELETE, OPTIONS" in nginx_conf_text

    def test_allow_headers(self, nginx_conf_text: str) -> None:
        assert "Authorization" in nginx_conf_text
        assert "Content-Type" in nginx_conf_text
        assert "X-Request-ID" in nginx_conf_text

    def test_expose_headers(self, nginx_conf_text: str) -> None:
        assert "Access-Control-Expose-Headers" in nginx_conf_text
        assert "Retry-After" in nginx_conf_text

    def test_allow_credentials(self, nginx_conf_text: str) -> None:
        assert 'Access-Control-Allow-Credentials "true"' in nginx_conf_text

    def test_max_age(self, nginx_conf_text: str) -> None:
        assert "Access-Control-Max-Age 86400" in nginx_conf_text

    def test_options_preflight_returns_204(self, nginx_conf_text: str) -> None:
        assert "return 204" in nginx_conf_text


# ---------------------------------------------------------------------------
# Request Correlation
# ---------------------------------------------------------------------------


class TestRequestCorrelation:
    """Verify X-Request-ID propagation."""

    def test_request_id_map(self, nginx_conf_text: str) -> None:
        assert "map $http_x_request_id $request_id_out" in nginx_conf_text

    def test_request_id_added_to_response(self, nginx_conf_text: str) -> None:
        assert "add_header X-Request-ID $request_id_out always" in nginx_conf_text

    def test_request_id_forwarded_to_upstream(self, proxy_params_text: str) -> None:
        assert "X-Request-ID" in proxy_params_text
        assert "$request_id_out" in proxy_params_text

    def test_json_log_includes_request_id(self, nginx_conf_text: str) -> None:
        assert '"request_id":"$request_id_out"' in nginx_conf_text


# ---------------------------------------------------------------------------
# Routing
# ---------------------------------------------------------------------------


class TestRouting:
    """Verify all API routes are present and map to correct upstreams."""

    ROUTE_UPSTREAM_MAP: ClassVar[dict[str, str]] = {
        "/v1/auth/": "auth_upstream",
        "/v1/users/": "auth_upstream",
        "/v1/sites/": "config_upstream",
        "/v1/cameras/": "config_upstream",
        "/v1/roi-presets/": "config_upstream",
        "/v1/config-versions/": "config_upstream",
        "/v1/ingest/": "ingest_upstream",
        "/v1/analytics/": "reporting_upstream",
        "/v1/analytics/live/ws": "reporting_upstream",
        "/v1/reports/": "reporting_upstream",
        "/v1/reports/export": "reporting_upstream",
        "/v1/alerts/": "notification_upstream",
        "/v1/alert-rules/": "notification_upstream",
    }

    @pytest.mark.parametrize(
        "path,upstream",
        list(ROUTE_UPSTREAM_MAP.items()),
        ids=list(ROUTE_UPSTREAM_MAP.keys()),
    )
    def test_route_maps_to_upstream(self, nginx_conf_text: str, path: str, upstream: str) -> None:
        block = re.search(
            rf"location\s+(?:=\s+)?{re.escape(path)}\s*\{{([^}}]+)\}}",
            nginx_conf_text,
        )
        assert block is not None, f"Location block not found for {path}"
        assert upstream in block.group(1), f"Expected {upstream} in location {path}"

    def test_healthz_endpoint(self, nginx_conf_text: str) -> None:
        assert "location = /healthz" in nginx_conf_text

    def test_readyz_endpoint(self, nginx_conf_text: str) -> None:
        assert "location = /readyz" in nginx_conf_text

    def test_catch_all_returns_404(self, nginx_conf_text: str) -> None:
        assert "return 404" in nginx_conf_text
        assert "NOT_FOUND" in nginx_conf_text

    def test_websocket_upgrade_headers(self, nginx_conf_text: str) -> None:
        ws_block = re.search(
            r"location /v1/analytics/live/ws\s*\{([^}]+)\}",
            nginx_conf_text,
        )
        assert ws_block is not None
        content = ws_block.group(1)
        assert "Upgrade" in content
        assert "3600s" in content


# ---------------------------------------------------------------------------
# JWT Auth Subrequest
# ---------------------------------------------------------------------------


class TestJWTValidation:
    """Verify JWT validation via auth_request subrequest."""

    def test_auth_validate_location(self, nginx_conf_text: str) -> None:
        assert "location = /_auth_validate" in nginx_conf_text
        assert "internal" in nginx_conf_text

    def test_auth_validate_proxies_to_auth_service(self, nginx_conf_text: str) -> None:
        validate_block = re.search(r"location = /_auth_validate\s*\{([^}]+)\}", nginx_conf_text)
        assert validate_block is not None
        assert "auth_upstream" in validate_block.group(1)

    PROTECTED_ROUTES: ClassVar[list[str]] = [
        "/v1/users/",
        "/v1/sites/",
        "/v1/cameras/",
        "/v1/roi-presets/",
        "/v1/config-versions/",
        "/v1/ingest/",
        "/v1/analytics/",
        "/v1/reports/",
        "/v1/alerts/",
        "/v1/alert-rules/",
    ]

    @pytest.mark.parametrize("path", PROTECTED_ROUTES)
    def test_protected_route_has_auth_request(self, nginx_conf_text: str, path: str) -> None:
        block = re.search(
            rf"location\s+{re.escape(path)}\s*\{{([^}}]+)\}}",
            nginx_conf_text,
        )
        assert block is not None, f"Location block not found for {path}"
        assert "auth_request /_auth_validate" in block.group(1), f"auth_request missing in {path}"

    def test_auth_endpoint_has_no_auth_request(self, nginx_conf_text: str) -> None:
        auth_block = re.search(r"location /v1/auth/\s*\{([^}]+)\}", nginx_conf_text)
        assert auth_block is not None
        assert "auth_request" not in auth_block.group(1)

    def test_dev_config_has_no_auth_request(self, nginx_dev_conf_text: str) -> None:
        assert "auth_request" not in nginx_dev_conf_text


# ---------------------------------------------------------------------------
# Security Headers
# ---------------------------------------------------------------------------


class TestSecurityHeaders:
    """Verify security headers in the production config."""

    def test_x_frame_options(self, nginx_conf_text: str) -> None:
        assert 'X-Frame-Options "DENY"' in nginx_conf_text

    def test_x_content_type_options(self, nginx_conf_text: str) -> None:
        assert 'X-Content-Type-Options "nosniff"' in nginx_conf_text

    def test_referrer_policy(self, nginx_conf_text: str) -> None:
        assert "Referrer-Policy" in nginx_conf_text

    def test_content_security_policy(self, nginx_conf_text: str) -> None:
        assert "Content-Security-Policy" in nginx_conf_text


# ---------------------------------------------------------------------------
# Error Handling
# ---------------------------------------------------------------------------


class TestErrorHandling:
    """Verify error pages and JSON error responses."""

    def test_429_error_page(self, nginx_conf_text: str) -> None:
        assert "error_page 429" in nginx_conf_text

    def test_429_returns_json(self, nginx_conf_text: str) -> None:
        assert "RATE_LIMITED" in nginx_conf_text

    def test_50x_error_page(self, nginx_conf_text: str) -> None:
        assert "error_page 502 503 504" in nginx_conf_text

    def test_50x_html_exists(self) -> None:
        assert (GATEWAY_DIR / "html" / "50x.html").exists()

    def test_retry_after_on_429(self, nginx_conf_text: str) -> None:
        rate_limited = re.search(r"location @rate_limited\s*\{([^}]+)\}", nginx_conf_text)
        assert rate_limited is not None
        assert "Retry-After" in rate_limited.group(1)


# ---------------------------------------------------------------------------
# Docker / Entrypoint
# ---------------------------------------------------------------------------


class TestDockerEntrypoint:
    """Verify the entrypoint script handles TLS and env substitution."""

    def test_tls_enabled_variable(self, entrypoint_text: str) -> None:
        assert "TLS_ENABLED" in entrypoint_text

    def test_self_signed_cert_generation(self, entrypoint_text: str) -> None:
        assert "openssl req" in entrypoint_text
        assert "server.crt" in entrypoint_text
        assert "server.key" in entrypoint_text

    def test_envsubst_for_all_hosts(self, entrypoint_text: str) -> None:
        for host in [
            "AUTH_SERVICE_HOST",
            "CONFIG_SERVICE_HOST",
            "INGEST_SERVICE_HOST",
            "REPORTING_API_HOST",
            "AGGREGATOR_HOST",
            "NOTIFICATION_SERVICE_HOST",
        ]:
            assert host in entrypoint_text

    def test_nginx_config_validation(self, entrypoint_text: str) -> None:
        assert "nginx -t" in entrypoint_text

    def test_dev_config_selected_when_tls_false(self, entrypoint_text: str) -> None:
        assert "nginx.dev.conf" in entrypoint_text


class TestDockerfile:
    """Verify the Dockerfile structure."""

    def test_based_on_nginx_alpine(self, dockerfile_text: str) -> None:
        assert "nginx:" in dockerfile_text
        assert "alpine" in dockerfile_text

    def test_openssl_installed(self, dockerfile_text: str) -> None:
        assert "openssl" in dockerfile_text

    def test_healthcheck_defined(self, dockerfile_text: str) -> None:
        assert "HEALTHCHECK" in dockerfile_text
        assert "/healthz" in dockerfile_text

    def test_exposes_80_and_443(self, dockerfile_text: str) -> None:
        assert "EXPOSE 80 443" in dockerfile_text


# ---------------------------------------------------------------------------
# Proxy Params
# ---------------------------------------------------------------------------


class TestProxyParams:
    """Verify proxy parameter configuration."""

    def test_forwarded_headers(self, proxy_params_text: str) -> None:
        assert "X-Real-IP" in proxy_params_text
        assert "X-Forwarded-For" in proxy_params_text
        assert "X-Forwarded-Proto" in proxy_params_text

    def test_keepalive_to_upstream(self, proxy_params_text: str) -> None:
        assert "proxy_http_version 1.1" in proxy_params_text
        assert 'Connection ""' in proxy_params_text

    def test_connect_timeout(self, proxy_params_text: str) -> None:
        assert "proxy_connect_timeout" in proxy_params_text

    def test_buffering_enabled(self, proxy_params_text: str) -> None:
        assert "proxy_buffering" in proxy_params_text


# ---------------------------------------------------------------------------
# Dev vs Production Config Parity
# ---------------------------------------------------------------------------


class TestDevProdParity:
    """Verify dev and production configs share the same route structure."""

    def test_both_configs_have_same_api_routes(
        self, nginx_conf_text: str, nginx_dev_conf_text: str
    ) -> None:
        api_routes_prod = {
            loc for loc in _extract_locations(nginx_conf_text) if loc.startswith("/v1/")
        }
        api_routes_dev = {
            loc for loc in _extract_locations(nginx_dev_conf_text) if loc.startswith("/v1/")
        }
        assert api_routes_prod == api_routes_dev

    def test_both_have_healthz(self, nginx_conf_text: str, nginx_dev_conf_text: str) -> None:
        assert "/healthz" in nginx_conf_text
        assert "/healthz" in nginx_dev_conf_text

    def test_both_have_same_rate_limit_zones(
        self, nginx_conf_text: str, nginx_dev_conf_text: str
    ) -> None:
        prod_zones = set(_extract_rate_limit_zones(nginx_conf_text).keys())
        dev_zones = set(_extract_rate_limit_zones(nginx_dev_conf_text).keys())
        assert prod_zones == dev_zones

    def test_both_have_same_upstreams(self, nginx_conf_text: str, nginx_dev_conf_text: str) -> None:
        prod_upstreams = set(_extract_upstreams(nginx_conf_text).keys())
        dev_upstreams = set(_extract_upstreams(nginx_dev_conf_text).keys())
        assert prod_upstreams == dev_upstreams
