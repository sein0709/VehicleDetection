"""FastAPI application factory with lifespan management and error handlers.

The aggregator runs as a FastAPI service with background tasks:
- A NATS consumer that pulls crossing events and recompute commands
- A periodic flush loop that drains the in-memory accumulator to Postgres
  and pushes live KPI updates to Redis
"""

from __future__ import annotations

import asyncio
import contextlib
from contextlib import asynccontextmanager
from typing import TYPE_CHECKING

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from observability import get_logger, setup_observability

from aggregator.accumulator import BucketAccumulator
from aggregator.db import AggregatorDB
from aggregator.nats_consumer import NatsCrossingConsumer
from aggregator.redis_publisher import RedisKPIPublisher
from aggregator.settings import Settings, get_settings
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


async def _flush_loop(
    accumulator: BucketAccumulator,
    db: AggregatorDB,
    redis_pub: RedisKPIPublisher,
    interval: float,
) -> None:
    """Periodically flush the accumulator to the database and publish KPI updates.

    Flush triggers (from Section 5.4):
    - Timer fires every ``interval`` seconds
    - Accumulator's own should_flush() also checks buffer size and bucket boundaries
    """
    while True:
        await asyncio.sleep(interval)
        if not accumulator.should_flush():
            continue

        rows = accumulator.flush()
        if not rows:
            continue

        try:
            await db.batch_upsert(rows)
            await redis_pub.publish_flush_summary(rows)
            logger.debug("Flushed %d bucket rows", len(rows))
        except Exception:
            logger.exception("Flush failed — %d rows lost", len(rows))


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None]:
    settings = get_settings()

    db = AggregatorDB()
    await db.connect(settings.database_url)

    redis_pub = RedisKPIPublisher(settings.redis_url)

    consumer = NatsCrossingConsumer()
    await consumer.connect(settings)

    accumulator = BucketAccumulator(
        flush_interval_seconds=settings.flush_interval_seconds,
        max_buffer_size=settings.max_buffer_size,
    )

    await consumer.start(accumulator, db, redis_pub)

    app.state.db = db
    app.state.consumer = consumer
    app.state.redis_pub = redis_pub
    app.state.accumulator = accumulator
    app.state.settings = settings

    flush_task = asyncio.create_task(
        _flush_loop(accumulator, db, redis_pub, settings.flush_interval_seconds),
        name="aggregator-flush",
    )
    app.state._flush_task = flush_task

    logger.info("Aggregator service started")
    yield

    flush_task.cancel()
    with contextlib.suppress(asyncio.CancelledError):
        await flush_task

    remaining = accumulator.flush()
    if remaining:
        try:
            await db.batch_upsert(remaining)
            logger.info("Final flush: %d rows persisted on shutdown", len(remaining))
        except Exception:
            logger.exception("Final flush on shutdown failed — %d rows lost", len(remaining))

    await consumer.stop()
    await redis_pub.close()
    await db.close()
    logger.info("Aggregator service stopped")


def create_app(settings: Settings | None = None) -> FastAPI:
    if settings is not None:
        import aggregator.settings as _mod

        _mod._settings = settings

    _settings = settings or get_settings()

    app = FastAPI(
        title="GreyEye Aggregation Service",
        version="0.1.0",
        lifespan=lifespan,
    )

    setup_observability(
        app,
        service_name="aggregator",
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
    @app.get("/healthz", tags=["health"])
    async def health_check() -> dict:
        return {"status": "ok", "service": "aggregator"}

    @app.get("/readyz", tags=["health"], response_model=None)
    async def readiness_check(request: Request):
        errors = []

        try:
            db: AggregatorDB = request.app.state.db
            async with db.pool.acquire() as conn:
                await conn.fetchval("SELECT 1")
        except Exception:
            errors.append("database_unavailable")

        try:
            consumer: NatsCrossingConsumer = request.app.state.consumer
            if not consumer.is_connected:
                errors.append("nats_disconnected")
        except Exception:
            errors.append("nats_unavailable")

        if errors:
            return JSONResponse(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                content={"status": "not_ready", "reasons": errors},
            )
        return {"status": "ready"}
