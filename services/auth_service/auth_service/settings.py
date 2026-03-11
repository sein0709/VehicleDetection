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

    # Supabase
    supabase_url: str = "http://localhost:54321"
    supabase_anon_key: str = ""
    supabase_service_role_key: str = ""

    # Postgres (direct connection for audit logs and user queries)
    database_url: str = "postgresql://greyeye:greyeye_dev@localhost:5432/greyeye"

    # Redis (for token deny-list / step-up auth cache)
    redis_url: str = "redis://localhost:6379/0"

    # JWT
    jwt_secret: str = "dev-secret-change-in-production"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 7

    # Step-up auth
    step_up_window_seconds: int = 300  # 5 minutes

    # Rate limiting
    rate_limit_per_minute: int = 60

    # Service
    service_name: str = "auth-service"
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
