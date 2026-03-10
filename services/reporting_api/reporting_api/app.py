"""FastAPI application factory with lifespan management and error handlers."""

from __future__ import annotations

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from observability import get_logger, setup_observability
from reporting_api import db, redis_client
from reporting_api.routes.analytics import router as analytics_router
from reporting_api.routes.reports import router as reports_router
from reporting_api.settings import Settings, get_settings
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

    await db.connect(settings.database_url)
    await redis_client.connect(settings.redis_url)

    app.state.settings = settings

    logger.info("Reporting API started")
    yield

    await redis_client.close()
    await db.close()
    logger.info("Reporting API stopped")


def create_app(settings: Settings | None = None) -> FastAPI:
    if settings is not None:
        import reporting_api.settings as _mod

        _mod._settings = settings

    _settings = settings or get_settings()

    app = FastAPI(
        title="GreyEye Reporting API",
        version="0.1.0",
        lifespan=lifespan,
    )

    setup_observability(
        app,
        service_name="reporting-api",
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
    app.include_router(analytics_router)
    app.include_router(reports_router)

    @app.get("/healthz", tags=["health"])
    async def health_check() -> dict:
        return {"status": "ok", "service": "reporting-api"}

    @app.get("/readyz", tags=["health"], response_model=None)
    async def readiness_check(request: Request):
        checks: dict[str, str] = {}
        try:
            pool = db._get_pool()
            async with pool.acquire() as conn:
                await conn.fetchval("SELECT 1")
            checks["postgres"] = "ok"
        except Exception:
            checks["postgres"] = "unavailable"

        try:
            r = redis_client._get_redis()
            await r.ping()
            checks["redis"] = "ok"
        except Exception:
            checks["redis"] = "unavailable"

        all_ok = all(v == "ok" for v in checks.values())
        if all_ok:
            return {"status": "ready", "checks": checks}
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "not_ready", "checks": checks},
        )
