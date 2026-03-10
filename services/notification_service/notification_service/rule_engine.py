"""Alert rule evaluation engine.

Each evaluator function takes an event and a rule's condition_config dict,
returning True if the condition is met and an alert should fire.

The ``CountAnomalyTracker`` maintains a rolling window of crossing counts
per camera and fires when the count deviates from the moving average by
more than a configurable number of standard deviations.
"""

from __future__ import annotations

import logging
import math
from collections import defaultdict, deque
from typing import Any

from shared_contracts.enums import AlertConditionType
from shared_contracts.events import CameraHealthEvent, VehicleCrossingEvent

logger = logging.getLogger(__name__)


def evaluate_congestion(event: VehicleCrossingEvent, config: dict[str, Any]) -> bool:
    """Trigger when estimated speed drops below a congestion threshold.

    Config keys:
        speed_threshold_kmh (float): speed below which congestion is detected.
    """
    threshold = config.get("speed_threshold_kmh", 10.0)
    if event.speed_estimate_kmh is None:
        return False
    return event.speed_estimate_kmh < threshold


def evaluate_speed_drop(event: VehicleCrossingEvent, config: dict[str, Any]) -> bool:
    """Trigger when speed estimate is below an absolute minimum.

    Config keys:
        min_speed_kmh (float): minimum acceptable speed.
    """
    min_speed = config.get("min_speed_kmh", 5.0)
    if event.speed_estimate_kmh is None:
        return False
    return event.speed_estimate_kmh < min_speed


def evaluate_stopped_vehicle(event: VehicleCrossingEvent, config: dict[str, Any]) -> bool:
    """Trigger when speed is effectively zero (stopped vehicle on road).

    Config keys:
        max_speed_kmh (float): speed at or below which a vehicle is considered stopped.
    """
    max_speed = config.get("max_speed_kmh", 2.0)
    if event.speed_estimate_kmh is None:
        return False
    return event.speed_estimate_kmh <= max_speed


def evaluate_heavy_vehicle_share(
    event: VehicleCrossingEvent, config: dict[str, Any]
) -> bool:
    """Trigger when a heavy vehicle (class >= 5) crosses and share tracking is enabled.

    The actual share calculation happens at the aggregation layer; this
    evaluator fires on individual heavy-vehicle crossings so the NATS
    consumer can increment a counter and check the rolling share.

    Config keys:
        enabled (bool): whether to flag individual heavy-vehicle crossings.
    """
    if not config.get("enabled", True):
        return False
    return event.class12.is_heavy_vehicle


def evaluate_camera_offline(
    health_event: CameraHealthEvent, config: dict[str, Any]
) -> bool:
    """Trigger when a camera reports offline status.

    Config keys:
        statuses (list[str]): list of statuses that should trigger (default: ["offline"]).
    """
    trigger_statuses = config.get("statuses", ["offline"])
    return health_event.status in trigger_statuses


class CountAnomalyTracker:
    """Stateful tracker that detects anomalous crossing counts per camera.

    Maintains a rolling window of 15-minute bucket counts and fires when the
    current bucket's count deviates from the moving average by more than
    ``sigma_threshold`` standard deviations.

    Config keys:
        window_size (int): number of historical buckets to consider (default: 8).
        sigma_threshold (float): z-score above which an anomaly fires (default: 2.5).
        min_samples (int): minimum buckets before evaluation begins (default: 4).
    """

    def __init__(self) -> None:
        self._counts: dict[str, deque[int]] = defaultdict(lambda: deque(maxlen=96))
        self._current_bucket: dict[str, tuple[str, int]] = {}

    def observe(
        self, event: VehicleCrossingEvent, config: dict[str, Any]
    ) -> bool:
        camera_id = event.camera_id
        bucket_key = event.bucket_start.isoformat()
        window_size = config.get("window_size", 8)
        sigma_threshold = config.get("sigma_threshold", 2.5)
        min_samples = config.get("min_samples", 4)

        prev = self._current_bucket.get(camera_id)
        if prev is None or prev[0] != bucket_key:
            if prev is not None:
                self._counts[camera_id].append(prev[1])
            self._current_bucket[camera_id] = (bucket_key, 1)
        else:
            self._current_bucket[camera_id] = (bucket_key, prev[1] + 1)

        history = self._counts[camera_id]
        if len(history) < min_samples:
            return False

        recent = list(history)[-window_size:]
        n = len(recent)
        mean = sum(recent) / n
        variance = sum((x - mean) ** 2 for x in recent) / n
        std = math.sqrt(variance) if variance > 0 else 0.0

        if std == 0:
            return False

        current_count = self._current_bucket[camera_id][1]
        z_score = abs(current_count - mean) / std
        return z_score > sigma_threshold


_count_anomaly_tracker = CountAnomalyTracker()


def evaluate_count_anomaly(
    event: VehicleCrossingEvent, config: dict[str, Any]
) -> bool:
    """Trigger when crossing count deviates anomalously from the rolling average."""
    return _count_anomaly_tracker.observe(event, config)


_CROSSING_EVALUATORS: dict[AlertConditionType, Any] = {
    AlertConditionType.CONGESTION: evaluate_congestion,
    AlertConditionType.SPEED_DROP: evaluate_speed_drop,
    AlertConditionType.STOPPED_VEHICLE: evaluate_stopped_vehicle,
    AlertConditionType.HEAVY_VEHICLE_SHARE: evaluate_heavy_vehicle_share,
    AlertConditionType.COUNT_ANOMALY: evaluate_count_anomaly,
}

_HEALTH_EVALUATORS: dict[AlertConditionType, Any] = {
    AlertConditionType.CAMERA_OFFLINE: evaluate_camera_offline,
}


def evaluate_rule(
    event: VehicleCrossingEvent | CameraHealthEvent,
    rule: dict[str, Any],
) -> bool:
    """Dispatch to the correct evaluator based on rule condition_type.

    Returns True if the rule condition is satisfied by the event.
    """
    condition_type = AlertConditionType(rule["condition_type"])
    config = rule.get("condition_config", {})

    if isinstance(event, CameraHealthEvent):
        evaluator = _HEALTH_EVALUATORS.get(condition_type)
        if evaluator is None:
            return False
        return evaluator(event, config)

    evaluator = _CROSSING_EVALUATORS.get(condition_type)
    if evaluator is None:
        return False
    return evaluator(event, config)


def get_count_anomaly_tracker() -> CountAnomalyTracker:
    """Return the module-level tracker (useful for testing)."""
    return _count_anomaly_tracker


def reset_count_anomaly_tracker() -> None:
    """Reset the module-level tracker state (for testing)."""
    global _count_anomaly_tracker
    _count_anomaly_tracker = CountAnomalyTracker()
