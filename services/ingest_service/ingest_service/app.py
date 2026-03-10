"""FastAPI application factory with lifespan management and error handlers."""

from __future__ import annotations

from contextlib import asynccontextmanager
from typing import TYPE_CHECKING

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from ingest_service.nats_client import NatsFramePublisher
from ingest_service.redis_client import CameraHealthCache, SessionStore
from ingest_service.routes.ingest import router as ingest_router
from ingest_service.settings import Settings, get_settings
from observability import get_logger, setup_observability
from shared_contracts.errors import (
    HTTP_STATUS_MAP,
    ErrorBody,
    ErrorCode,
    ErrorDetail,
    ErrorResponse,
)

if TYPE_CHECKING:
    from collections.abc import AsyncGenerator

logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None]:
    settings = get_settings()

    nats_publisher = NatsFramePublisher()
    await nats_publisher.connect(settings)

    health_cache = CameraHealthCache(settings)
    session_store = SessionStore(settings)

    app.state.nats_publisher = nats_publisher
    app.state.health_cache = health_cache
    app.state.session_store = session_store
    app.state.settings = settings

    logger.info("Ingest service started")
    yield

    await nats_publisher.close()
    await health_cache.close()
    await session_store.close()
    logger.info("Ingest service stopped")


def create_app(settings: Settings | None = None) -> FastAPI:
    if settings is not None:
        import ingest_service.settings as _mod

        _mod._settings = settings

    _settings = settings or get_settings()

    app = FastAPI(
        title="GreyEye Ingest Service",
        version="0.1.0",
        lifespan=lifespan,
    )

    setup_observability(
        app,
        service_name="ingest-service",
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
    app.include_router(ingest_router)

    @app.get("/healthz", tags=["health"])
    async def health_check() -> dict:
        return {"status": "ok", "service": "ingest-service"}

    @app.get("/readyz", tags=["health"], response_model=None)
    async def readiness_check(request: Request):
        errors = []

        try:
            cache: CameraHealthCache = request.app.state.health_cache
            await cache._redis.ping()
        except Exception:
            errors.append("redis_unavailable")

        try:
            publisher: NatsFramePublisher = request.app.state.nats_publisher
            if not publisher.is_connected:
                errors.append("nats_disconnected")
        except Exception:
            errors.append("nats_unavailable")

        if errors:
            return JSONResponse(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                content={"status": "not_ready", "reasons": errors},
            )
        return {"status": "ready"}
