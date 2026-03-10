"""Shared fixtures for API Gateway configuration tests."""

from __future__ import annotations

from pathlib import Path

import pytest

GATEWAY_DIR = Path(__file__).resolve().parent.parent


@pytest.fixture()
def nginx_conf_text() -> str:
    return (GATEWAY_DIR / "nginx.conf").read_text()


@pytest.fixture()
def nginx_dev_conf_text() -> str:
    return (GATEWAY_DIR / "nginx.dev.conf").read_text()


@pytest.fixture()
def proxy_params_text() -> str:
    return (GATEWAY_DIR / "proxy_params").read_text()


@pytest.fixture()
def entrypoint_text() -> str:
    return (GATEWAY_DIR / "docker-entrypoint.sh").read_text()


@pytest.fixture()
def dockerfile_text() -> str:
    return (GATEWAY_DIR / "Dockerfile").read_text()
