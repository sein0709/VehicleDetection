"""FastAPI application factory with lifespan management and error handlers."""

from __future__ import annotations

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from observability import get_logger, setup_observability

from config_service.db import ConfigDB
from config_service.redis_client import CameraHealthCache
from config_service.routes.cameras import router as cameras_router
from config_service.routes.config_versions import router as versions_router
from config_service.routes.roi_presets import router as roi_router
from config_service.routes.sites import router as sites_router
from config_service.settings import Settings, get_settings
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

    config_db = ConfigDB(settings)
    health_cache = CameraHealthCache(settings)

    app.state.config_db = config_db
    app.state.health_cache = health_cache
    app.state.settings = settings

    logger.info("Config service started")
    yield

    await health_cache.close()
    logger.info("Config service stopped")


def create_app(settings: Settings | None = None) -> FastAPI:
    if settings is not None:
        import config_service.settings as _mod

        _mod._settings = settings

    app = FastAPI(
        title="GreyEye Config Service",
        version="0.1.0",
        lifespan=lifespan,
    )

    settings = get_settings()
    setup_observability(
        app,
        service_name="config-service",
        log_level=settings.log_level,
        json_logs=settings.json_logs,
        tracing_enabled=settings.tracing_enabled,
        otlp_endpoint=settings.otlp_endpoint,
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
    app.include_router(sites_router)
    app.include_router(cameras_router)
    app.include_router(roi_router)
    app.include_router(versions_router)

    @app.get("/healthz", tags=["health"])
    async def health_check() -> dict:
        return {"status": "ok", "service": "config-service"}

    @app.get("/readyz", tags=["health"], response_model=None)
    async def readiness_check(request: Request):
        try:
            cache: CameraHealthCache = request.app.state.health_cache
            await cache._redis.ping()
            return {"status": "ready"}
        except Exception:
            return JSONResponse(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                content={"status": "not_ready", "reason": "redis_unavailable"},
            )
