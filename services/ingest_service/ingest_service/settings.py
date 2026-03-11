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

    # NATS (frame queue)
    nats_url: str = "nats://localhost:4222"
    nats_connect_timeout: int = 10
    nats_max_reconnect_attempts: int = 60
    nats_reconnect_time_wait: float = 2.0

    # Redis (camera health cache + session store)
    redis_url: str = "redis://localhost:6379/0"

    # JWT (tokens issued by auth-service)
    jwt_secret: str = "dev-secret-change-in-production"
    jwt_algorithm: str = "HS256"

    # Backpressure
    max_queue_depth: int = 500
    backpressure_retry_after: int = 5

    # Frame upload limits
    max_frame_size_bytes: int = 10 * 1024 * 1024  # 10 MB

    # Upload sessions
    session_ttl_seconds: int = 3600  # 1 hour
    session_max_idle_seconds: int = 300  # 5 min idle before expiry

    # Camera health
    health_ttl_seconds: int = 300  # 5 min
    offline_threshold_multiplier: float = 2.0

    # Service
    service_name: str = "ingest-service"
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
