"""Structured JSON logging via structlog.

Produces machine-parseable JSON lines in production and human-friendly coloured
output during local development.  Every log event carries ``service``,
``request_id``, ``camera_id``, and ``org_id`` when available (via contextvars).
"""

from __future__ import annotations

import logging
import sys
from contextvars import ContextVar
from typing import Any

import structlog

from observability.sanitization import sanitize_structlog_processor

request_id_var: ContextVar[str] = ContextVar("request_id", default="")
camera_id_var: ContextVar[str] = ContextVar("camera_id", default="")
org_id_var: ContextVar[str] = ContextVar("org_id", default="")

_configured = False


def _inject_context(
    logger: Any, method_name: str, event_dict: dict[str, Any]
) -> dict[str, Any]:
    """Inject correlation IDs from contextvars into every log event."""
    if rid := request_id_var.get():
        event_dict.setdefault("request_id", rid)
    if cid := camera_id_var.get():
        event_dict.setdefault("camera_id", cid)
    if oid := org_id_var.get():
        event_dict.setdefault("org_id", oid)
    return event_dict


def setup_logging(
    *,
    service_name: str,
    log_level: str = "INFO",
    json_output: bool = True,
) -> None:
    """Configure structlog + stdlib logging for the entire process.

    Call once at startup.  ``json_output=False`` gives coloured console output
    suitable for local development.
    """
    global _configured
    if _configured:
        return
    _configured = True

    shared_processors: list[structlog.types.Processor] = [
        structlog.contextvars.merge_contextvars,
        _inject_context,
        sanitize_structlog_processor,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
    ]

    if json_output:
        renderer: structlog.types.Processor = structlog.processors.JSONRenderer()
    else:
        renderer = structlog.dev.ConsoleRenderer(colors=True)

    structlog.configure(
        processors=[
            *shared_processors,
            structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
        ],
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )

    formatter = structlog.stdlib.ProcessorFormatter(
        processors=[
            structlog.stdlib.ProcessorFormatter.remove_processors_meta,
            renderer,
        ],
        foreign_pre_chain=shared_processors,
    )

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)

    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(getattr(logging, log_level.upper(), logging.INFO))

    for noisy in ("uvicorn.access", "httpcore", "httpx"):
        logging.getLogger(noisy).setLevel(logging.WARNING)

    bound = structlog.get_logger().bind(service=service_name)
    bound.info("logging configured", log_level=log_level, json_output=json_output)


def get_logger(name: str | None = None) -> structlog.stdlib.BoundLogger:
    """Return a bound structlog logger, optionally with a module name."""
    logger = structlog.get_logger(name)
    return logger


def reset_logging() -> None:
    """Reset the logging configuration flag (for testing)."""
    global _configured
    _configured = False
    structlog.reset_defaults()
