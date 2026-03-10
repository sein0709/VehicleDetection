"""FastAPI application factory with lifespan management and error handlers."""

from __future__ import annotations

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request, status
from sqlalchemy import text
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from observability import get_logger, setup_observability

from notification_service.db import NotificationDB
from notification_service.nats_consumer import EventConsumer
from notification_service.routes.alerts import router as alerts_router
from notification_service.settings import Settings, get_settings
from shared_contracts.errors import (
    HTTP_STATUS_MAP,
    ErrorBody,
    ErrorCode,
    ErrorDetail,
    ErrorResponse,
)

logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None]:
    settings = get_settings()

    notification_db = NotificationDB(settings)
    consumer = EventConsumer(settings, notification_db)

    app.state.notification_db = notification_db
    app.state.consumer = consumer
    app.state.settings = settings

    try:
        await consumer.start()
    except Exception:
        logger.warning("NATS consumer failed to start — running in API-only mode")

    logger.info("Notification service started")
    yield

    await consumer.stop()
    await notification_db.close()
    logger.info("Notification service stopped")


def create_app(settings: Settings | None = None) -> FastAPI:
    if settings is not None:
        import notification_service.settings as _mod

        _mod._settings = settings

    _settings = settings or get_settings()

    app = FastAPI(
        title="GreyEye Notification Service",
        version="0.1.0",
        lifespan=lifespan,
    )

    setup_observability(
        app,
        service_name="notification-service",
        log_level=_settings.log_level,
        json_logs=_settings.json_logs,
        tracing_enabled=_settings.tracing_enabled,
        otlp_endpoint=_settings.otlp_endpoint,
    )

    _register_middleware(app)
    _register_error_handlers(app)
    _register_routes(app)

    return app


def _register_middleware(app: FastAPI) -> None:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


def _register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        return _error_response(
            ErrorCode.VALIDATION_ERROR,
            "Request validation failed",
            request,
            details=[
                {"field": ".".join(str(loc) for loc in e["loc"]), "message": e["msg"]}
                for e in exc.errors()
            ],
        )

    @app.exception_handler(httpx.HTTPStatusError)
    async def httpx_error_handler(request: Request, exc: httpx.HTTPStatusError) -> JSONResponse:
        code = exc.response.status_code
        if code == 401:
            return _error_response(ErrorCode.UNAUTHORIZED, "Authentication failed", request)
        if code == 403:
            return _error_response(ErrorCode.FORBIDDEN, "Access denied", request)
        if code == 409:
            return _error_response(ErrorCode.CONFLICT, "Resource conflict", request)
        return _error_response(ErrorCode.INTERNAL_ERROR, "Upstream service error", request)

    @app.exception_handler(Exception)
    async def generic_error_handler(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled exception on %s %s", request.method, request.url.path)
        return _error_response(ErrorCode.INTERNAL_ERROR, "Internal server error", request)


def _error_response(
    code: ErrorCode,
    message: str,
    request: Request,
    details: list | None = None,
) -> JSONResponse:
    request_id = getattr(request.state, "request_id", None)
    body = ErrorBody(code=code, message=message, request_id=request_id)
    if details:
        body.details = [ErrorDetail(**d) for d in details]
    return JSONResponse(
        status_code=HTTP_STATUS_MAP.get(code, 500),
        content=ErrorResponse(error=body).model_dump(mode="json"),
    )


def _register_routes(app: FastAPI) -> None:
    app.include_router(alerts_router)

    @app.get("/healthz", tags=["health"])
    async def health_check() -> dict:
        return {"status": "ok", "service": "notification-service"}

    @app.get("/readyz", tags=["health"], response_model=None)
    async def readiness_check(request: Request):
        checks: dict[str, str] = {}
        try:
            db: NotificationDB = request.app.state.notification_db
            async with db._engine.connect() as conn:
                await conn.execute(text("SELECT 1"))
            checks["database"] = "ok"
        except Exception:
            checks["database"] = "unavailable"

        consumer: EventConsumer = getattr(request.app.state, "consumer", None)
        if consumer is not None:
            checks["nats_consumer"] = "ok" if consumer.is_running else "degraded"

        all_ok = all(v == "ok" for v in checks.values())
        if all_ok:
            return {"status": "ready", "checks": checks}
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "not_ready", "checks": checks},
        )
