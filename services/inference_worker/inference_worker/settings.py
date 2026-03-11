"""Inference Worker settings loaded from environment variables.

Covers all configurable parameters from docs/05-ai-ml-pipeline.md Section 13.
"""

from __future__ import annotations

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict
from shared_contracts.env import repo_env_file


class DetectorSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="GREYEYE_DETECTOR_", extra="ignore")

    input_size: int = 640
    confidence_threshold: float = 0.25
    nms_iou_threshold: float = 0.45
    max_detections: int = 100
    model_path: str = "models/detector/model.onnx"


class TrackerSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="GREYEYE_TRACKER_", extra="ignore")

    type: str = "bytetrack"
    min_hits: int = 3
    max_age: int = 30
    iou_threshold: float = 0.3
    centroid_history_length: int = 50


class ClassifierSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="GREYEYE_CLASSIFIER_", extra="ignore")

    mode: str = "full_12class"
    fallback_threshold: float = 0.4
    input_size: int = 224
    model_path: str = "models/classifier/model.onnx"


class SmootherSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="GREYEYE_SMOOTHER_", extra="ignore")

    strategy: str = "majority"
    window: int = 5
    ema_alpha: float = 0.3
    min_track_age: int = 3


class CrossingSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="GREYEYE_CROSSING_", extra="ignore")

    cooldown_frames: int = 10
    min_displacement: float = 0.01


class HardExampleSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="GREYEYE_HARD_EXAMPLE_", extra="ignore")

    enabled: bool = True
    confidence_threshold: float = 0.5
    max_per_hour: int = 100
    rare_class_ids: list[int] = Field(default=[5, 6, 7, 8, 9, 10, 11, 12])
    storage_bucket: str = "greyeye-hard-examples"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="GREYEYE_",
        env_file=repo_env_file(),
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    nats_url: str = "nats://localhost:4222"
    nats_connect_timeout: int = 10
    nats_max_reconnect_attempts: int = 60
    nats_reconnect_time_wait: float = 2.0

    redis_url: str = "redis://localhost:6379/0"
    redis_live_state_ttl: int = 30

    s3_endpoint: str = "http://localhost:9000"
    s3_access_key: str = "minioadmin"
    s3_secret_key: str = "minioadmin"
    s3_region: str = "us-east-1"

    model_version: str = "v0.1.0"
    camera_fps: float = 10.0

    fetch_batch_size: int = 1
    fetch_timeout_ms: int = 5000

    service_name: str = "inference-worker"
    debug: bool = False

    # Observability
    log_level: str = "INFO"
    json_logs: bool = True
    tracing_enabled: bool = True
    otlp_endpoint: str = "http://localhost:4317"

    detector: DetectorSettings = Field(default_factory=DetectorSettings)
    tracker: TrackerSettings = Field(default_factory=TrackerSettings)
    classifier: ClassifierSettings = Field(default_factory=ClassifierSettings)
    smoother: SmootherSettings = Field(default_factory=SmootherSettings)
    crossing: CrossingSettings = Field(default_factory=CrossingSettings)
    hard_example: HardExampleSettings = Field(default_factory=HardExampleSettings)


_settings: Settings | None = None


def get_settings() -> Settings:
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings
