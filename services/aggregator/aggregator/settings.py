"""Application settings loaded from environment variables."""

from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict
from shared_contracts.env import repo_env_file


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="GREYEYE_",
        env_file=repo_env_file(),
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # NATS
    nats_url: str = "nats://localhost:4222"
    nats_connect_timeout: int = 10
    nats_max_reconnect_attempts: int = 60
    nats_reconnect_time_wait: float = 2.0

    # Redis (live KPI pub/sub)
    redis_url: str = "redis://localhost:6379/0"

    # PostgreSQL (aggregated counts)
    database_url: str = "postgresql+asyncpg://greyeye:greyeye@localhost:5432/greyeye"

    # JWT (tokens issued by auth-service)
    jwt_secret: str = "dev-secret-change-in-production"
    jwt_algorithm: str = "HS256"

    # Accumulator tuning
    flush_interval_seconds: float = 5.0
    max_buffer_size: int = 1000

    # Service
    service_name: str = "aggregator"
    debug: bool = False

    # Observability
    log_level: str = "INFO"
    json_logs: bool = True
    tracing_enabled: bool = True
    otlp_endpoint: str = "http://localhost:4317"


_settings: Settings | None = None


def get_settings() -> Settings:
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings
