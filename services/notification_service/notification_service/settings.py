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

    # Redis (cooldown tracking + rule cache)
    redis_url: str = "redis://localhost:6379/0"

    # Postgres (alert_rules, alert_events)
    database_url: str = "postgresql+asyncpg://greyeye:greyeye_dev@localhost:5432/greyeye"

    # JWT (token validation — tokens issued by auth-service)
    jwt_secret: str = "dev-secret-change-in-production"
    jwt_algorithm: str = "HS256"

    # SMTP (optional — email delivery)
    smtp_host: str | None = None
    smtp_port: int = 587
    smtp_user: str | None = None
    smtp_password: str | None = None

    # FCM (optional — push notifications)
    fcm_server_key: str | None = None

    # Webhook delivery
    webhook_timeout: int = 10

    # Alert cooldown
    default_cooldown_minutes: int = 15

    # Service
    service_name: str = "notification-service"
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
