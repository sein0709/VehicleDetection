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

from auth_service.redis_client import RedisTokenStore
from auth_service.routes.auth import router as auth_router
from auth_service.routes.users import router as users_router
from auth_service.settings import Settings, get_settings
from auth_service.supabase_client import SupabaseAuthClient
from auth_service.tokens import TokenService
from shared_contracts.errors import ErrorBody, ErrorCode, ErrorResponse, HTTP_STATUS_MAP

logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None]:
    settings = get_settings()

    supabase_client = SupabaseAuthClient(settings)
    token_service = TokenService(settings)
    redis_store = RedisTokenStore(settings)

    app.state.supabase_client = supabase_client
    app.state.token_service = token_service
    app.state.redis_store = redis_store
    app.state.settings = settings

    logger.info("Auth service started")
    yield

    await supabase_client.close()
    await redis_store.close()
    logger.info("Auth service stopped")


def create_app(settings: Settings | None = None) -> FastAPI:
    if settings is not None:
        import auth_service.settings as _mod

        _mod._settings = settings

    app = FastAPI(
        title="GreyEye Auth & RBAC Service",
        version="0.1.0",
        lifespan=lifespan,
    )

    settings = get_settings()
    setup_observability(
        app,
        service_name="auth-service",
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
    async def validation_error_handler(request: Request, exc: RequestValidationError):
        return _error_response(
            ErrorCode.VALIDATION_ERROR,
            "Request validation failed",
            request,
            details=[{"field": ".".join(str(l) for l in e["loc"]), "message": e["msg"]} for e in exc.errors()],
        )

    @app.exception_handler(httpx.HTTPStatusError)
    async def httpx_error_handler(request: Request, exc: httpx.HTTPStatusError):
        code = exc.response.status_code
        if code == 401:
            return _error_response(ErrorCode.UNAUTHORIZED, "Authentication failed", request)
        if code == 403:
            return _error_response(ErrorCode.FORBIDDEN, "Access denied", request)
        if code == 409:
            return _error_response(ErrorCode.CONFLICT, "Resource conflict", request)
        if code == 429:
            return _error_response(ErrorCode.RATE_LIMITED, "Rate limit exceeded", request)
        return _error_response(ErrorCode.INTERNAL_ERROR, "Upstream service error", request)

    @app.exception_handler(Exception)
    async def generic_error_handler(request: Request, exc: Exception):
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
        from shared_contracts.errors import ErrorDetail

        body.details = [ErrorDetail(**d) for d in details]
    return JSONResponse(
        status_code=HTTP_STATUS_MAP.get(code, 500),
        content=ErrorResponse(error=body).model_dump(mode="json"),
    )


def _register_routes(app: FastAPI) -> None:
    app.include_router(auth_router)
    app.include_router(users_router)

    @app.get("/healthz", tags=["health"])
    async def health_check():
        return {"status": "ok", "service": "auth-service"}

    @app.get("/readyz", tags=["health"])
    async def readiness_check(request: Request):
        try:
            redis_store: RedisTokenStore = request.app.state.redis_store
            await redis_store._redis.ping()
            return {"status": "ready"}
        except Exception:
            return JSONResponse(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                content={"status": "not_ready", "reason": "redis_unavailable"},
            )
