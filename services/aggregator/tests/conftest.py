"""Shared fixtures for Aggregator Service tests."""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, PropertyMock

import pytest
from aggregator.accumulator import BucketAccumulator
from aggregator.app import create_app
from aggregator.db import AggregatorDB
from aggregator.nats_consumer import NatsCrossingConsumer
from aggregator.redis_publisher import RedisKPIPublisher
from aggregator.settings import Settings
from fastapi.testclient import TestClient

from aggregator.test_support import make_crossing_event


@pytest.fixture()
def settings() -> Settings:
    return Settings(
        nats_url="nats://localhost:4222",
        redis_url="redis://localhost:6379/0",
        database_url="postgresql+asyncpg://test:test@localhost:5432/test",
        jwt_secret="test-secret",
        jwt_algorithm="HS256",
        flush_interval_seconds=5.0,
        max_buffer_size=1000,
    )


@pytest.fixture()
def accumulator() -> BucketAccumulator:
    return BucketAccumulator(flush_interval_seconds=5.0, max_buffer_size=1000)


@pytest.fixture()
def mock_db() -> MagicMock:
    db = MagicMock(spec=AggregatorDB)
    db.connect = AsyncMock()
    db.close = AsyncMock()
    db.upsert_bucket = AsyncMock()
    db.batch_upsert = AsyncMock(return_value=0)
    db.recompute = AsyncMock(return_value=0)
    db.delete_and_recompute = AsyncMock(return_value=0)
    db.fetch_bucket_totals = AsyncMock(return_value=[])

    pool = MagicMock()
    conn = AsyncMock()
    conn.fetchval = AsyncMock(return_value=1)
    pool.acquire.return_value.__aenter__ = AsyncMock(return_value=conn)
    pool.acquire.return_value.__aexit__ = AsyncMock(return_value=False)
    type(db).pool = PropertyMock(return_value=pool)

    return db


@pytest.fixture()
def mock_consumer() -> MagicMock:
    consumer = MagicMock(spec=NatsCrossingConsumer)
    consumer.connect = AsyncMock()
    consumer.start = AsyncMock()
    consumer.stop = AsyncMock()
    type(consumer).is_connected = PropertyMock(return_value=True)
    type(consumer).stats = PropertyMock(return_value={"processed": 0, "recomputes": 0})
    return consumer


@pytest.fixture()
def mock_redis_pub() -> MagicMock:
    pub = MagicMock(spec=RedisKPIPublisher)
    pub.publish_bucket_update = AsyncMock(return_value=0)
    pub.publish_flush_summary = AsyncMock()
    pub.set_current_bucket = AsyncMock()
    pub.close = AsyncMock()
    return pub


@pytest.fixture()
def client(
    settings: Settings,
    mock_db: MagicMock,
    mock_consumer: MagicMock,
    mock_redis_pub: MagicMock,
) -> TestClient:
    app = create_app(settings)
    app.state.db = mock_db
    app.state.consumer = mock_consumer
    app.state.redis_pub = mock_redis_pub
    app.state.accumulator = BucketAccumulator()
    app.state.settings = settings
    return TestClient(app, raise_server_exceptions=False)
