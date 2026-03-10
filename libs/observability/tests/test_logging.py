"""Tests for the structured logging module."""

from __future__ import annotations

import json
import logging

import structlog

from observability.logging import (
    camera_id_var,
    get_logger,
    org_id_var,
    request_id_var,
    reset_logging,
    setup_logging,
)


class TestSetupLogging:
    def setup_method(self) -> None:
        reset_logging()

    def teardown_method(self) -> None:
        reset_logging()

    def test_setup_logging_configures_root_handler(self) -> None:
        setup_logging(service_name="test-svc", log_level="DEBUG", json_output=True)
        root = logging.getLogger()
        assert len(root.handlers) == 1
        assert root.level == logging.DEBUG

    def test_setup_logging_idempotent(self) -> None:
        setup_logging(service_name="test-svc")
        handler_count = len(logging.getLogger().handlers)
        setup_logging(service_name="test-svc")
        assert len(logging.getLogger().handlers) == handler_count

    def test_json_output_produces_valid_json(self, capsys) -> None:
        setup_logging(service_name="test-svc", log_level="INFO", json_output=True)
        logger = get_logger("test.json")
        logger.info("hello", key="value")
        captured = capsys.readouterr()
        line = captured.out.strip().split("\n")[-1]
        data = json.loads(line)
        assert data["event"] == "hello"
        assert data["key"] == "value"

    def test_console_output_does_not_crash(self, capsys) -> None:
        setup_logging(service_name="test-svc", log_level="INFO", json_output=False)
        logger = get_logger("test.console")
        logger.info("hello console")
        captured = capsys.readouterr()
        assert "hello console" in captured.out


class TestContextVarInjection:
    def setup_method(self) -> None:
        reset_logging()
        setup_logging(service_name="ctx-test", log_level="DEBUG", json_output=True)

    def teardown_method(self) -> None:
        request_id_var.set("")
        camera_id_var.set("")
        org_id_var.set("")
        reset_logging()

    def test_request_id_injected(self, capsys) -> None:
        request_id_var.set("req-abc-123")
        logger = get_logger("test.ctx")
        logger.info("with_request_id")
        captured = capsys.readouterr()
        line = captured.out.strip().split("\n")[-1]
        data = json.loads(line)
        assert data["request_id"] == "req-abc-123"

    def test_camera_id_injected(self, capsys) -> None:
        camera_id_var.set("cam-42")
        logger = get_logger("test.ctx")
        logger.info("with_camera")
        captured = capsys.readouterr()
        line = captured.out.strip().split("\n")[-1]
        data = json.loads(line)
        assert data["camera_id"] == "cam-42"

    def test_org_id_injected(self, capsys) -> None:
        org_id_var.set("org-99")
        logger = get_logger("test.ctx")
        logger.info("with_org")
        captured = capsys.readouterr()
        line = captured.out.strip().split("\n")[-1]
        data = json.loads(line)
        assert data["org_id"] == "org-99"

    def test_empty_vars_not_injected(self, capsys) -> None:
        request_id_var.set("")
        camera_id_var.set("")
        org_id_var.set("")
        logger = get_logger("test.ctx")
        logger.info("no_context")
        captured = capsys.readouterr()
        line = captured.out.strip().split("\n")[-1]
        data = json.loads(line)
        assert "request_id" not in data
        assert "camera_id" not in data
        assert "org_id" not in data


class TestGetLogger:
    def setup_method(self) -> None:
        reset_logging()
        setup_logging(service_name="logger-test", json_output=True)

    def teardown_method(self) -> None:
        reset_logging()

    def test_returns_bound_logger(self) -> None:
        logger = get_logger("my.module")
        assert isinstance(logger, structlog.stdlib.BoundLogger)

    def test_logger_name_in_output(self, capsys) -> None:
        logger = get_logger("my.named.module")
        logger.info("named_test")
        captured = capsys.readouterr()
        line = captured.out.strip().split("\n")[-1]
        data = json.loads(line)
        assert data.get("logger") == "my.named.module"
