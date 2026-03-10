"""Load test configuration — environment-driven settings for all scenarios."""

from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class LoadTestSettings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="GREYEYE_LT_",
        env_file=".env.loadtest",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Target services
    ingest_url: str = "http://localhost:8001"
    reporting_url: str = "http://localhost:8003"
    gateway_url: str = "http://localhost:8080"
    nats_url: str = "nats://localhost:4222"
    redis_url: str = "redis://localhost:6379/0"

    # Auth
    jwt_secret: str = "dev-secret-change-in-production"
    jwt_algorithm: str = "HS256"

    # MVP scenario (NFR-3: 10 cameras @ 10 FPS)
    mvp_cameras: int = 10
    mvp_fps_per_camera: int = 10
    mvp_duration_seconds: int = 120

    # Scale scenario (100 cameras)
    scale_cameras: int = 100
    scale_fps_per_camera: int = 10
    scale_duration_seconds: int = 300

    # NFR targets
    nfr1_live_kpi_refresh_ms: int = 2000
    nfr2_inference_latency_ms: int = 1500
    nfr3_min_cameras: int = 10

    # Backpressure test
    backpressure_flood_rps: int = 200
    backpressure_duration_seconds: int = 60

    # Frame generation
    frame_width: int = 1920
    frame_height: int = 1080
    frame_jpeg_quality: int = 50

    # Test identity
    org_id: str = "org_loadtest"
    site_id: str = "site_loadtest"

    # Reporting
    output_dir: str = "tests/loadtest/results"


_settings: LoadTestSettings | None = None


def get_settings() -> LoadTestSettings:
    global _settings
    if _settings is None:
        _settings = LoadTestSettings()
    return _settings
