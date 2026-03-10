"""Shared enumerations used across all GreyEye services.

The VehicleClass12 enum follows the KICT/MOLIT 12-class vehicle classification
standard used in Korean national traffic surveys.
"""

from __future__ import annotations

from enum import IntEnum, StrEnum


class VehicleClass12(IntEnum):
    """KICT/MOLIT 12-class vehicle classification (한국건설기술연구원 / 국토교통부)."""

    C01_PASSENGER_MINITRUCK = 1  # 1종 승용차/미니트럭
    C02_BUS = 2  # 2종 버스
    C03_TRUCK_LT_2_5T = 3  # 3종 1~2.5톤 미만
    C04_TRUCK_2_5_TO_8_5T = 4  # 4종 2.5~8.5톤 미만
    C05_SINGLE_3_AXLE = 5  # 5종 1단위 3축
    C06_SINGLE_4_AXLE = 6  # 6종 1단위 4축
    C07_SINGLE_5_AXLE = 7  # 7종 1단위 5축
    C08_SEMI_4_AXLE = 8  # 8종 2단위 4축 세미
    C09_FULL_4_AXLE = 9  # 9종 2단위 4축 풀
    C10_SEMI_5_AXLE = 10  # 10종 2단위 5축 세미
    C11_FULL_5_AXLE = 11  # 11종 2단위 5축 풀
    C12_SEMI_6_AXLE = 12  # 12종 2단위 6축 세미

    @property
    def korean_name(self) -> str:
        return _KOREAN_NAMES[self]

    @property
    def english_name(self) -> str:
        return _ENGLISH_NAMES[self]

    @property
    def is_heavy_vehicle(self) -> bool:
        """Classes 5-12 are considered heavy vehicles for alert thresholds."""
        return self.value >= 5


class CoarseFallbackClass(StrEnum):
    """Fallback classes when 12-class confidence is below threshold (FR-4.6)."""

    CAR = "car"
    BUS = "bus"
    TRUCK = "truck"
    TRAILER = "trailer"
    UNKNOWN = "unknown"


COARSE_MAPPING: dict[VehicleClass12, CoarseFallbackClass] = {
    VehicleClass12.C01_PASSENGER_MINITRUCK: CoarseFallbackClass.CAR,
    VehicleClass12.C02_BUS: CoarseFallbackClass.BUS,
    VehicleClass12.C03_TRUCK_LT_2_5T: CoarseFallbackClass.TRUCK,
    VehicleClass12.C04_TRUCK_2_5_TO_8_5T: CoarseFallbackClass.TRUCK,
    VehicleClass12.C05_SINGLE_3_AXLE: CoarseFallbackClass.TRUCK,
    VehicleClass12.C06_SINGLE_4_AXLE: CoarseFallbackClass.TRUCK,
    VehicleClass12.C07_SINGLE_5_AXLE: CoarseFallbackClass.TRUCK,
    VehicleClass12.C08_SEMI_4_AXLE: CoarseFallbackClass.TRAILER,
    VehicleClass12.C09_FULL_4_AXLE: CoarseFallbackClass.TRAILER,
    VehicleClass12.C10_SEMI_5_AXLE: CoarseFallbackClass.TRAILER,
    VehicleClass12.C11_FULL_5_AXLE: CoarseFallbackClass.TRAILER,
    VehicleClass12.C12_SEMI_6_AXLE: CoarseFallbackClass.TRAILER,
}


class UserRole(StrEnum):
    ADMIN = "admin"
    OPERATOR = "operator"
    ANALYST = "analyst"
    VIEWER = "viewer"


class CameraSourceType(StrEnum):
    SMARTPHONE = "smartphone"
    RTSP = "rtsp"
    ONVIF = "onvif"


class CameraStatus(StrEnum):
    ONLINE = "online"
    DEGRADED = "degraded"
    OFFLINE = "offline"
    ARCHIVED = "archived"


class SiteStatus(StrEnum):
    ACTIVE = "active"
    ARCHIVED = "archived"


class CrossingDirection(StrEnum):
    INBOUND = "inbound"
    OUTBOUND = "outbound"


class LineDirection(StrEnum):
    INBOUND = "inbound"
    OUTBOUND = "outbound"
    BIDIRECTIONAL = "bidirectional"


class AlertSeverity(StrEnum):
    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"


class AlertStatus(StrEnum):
    TRIGGERED = "triggered"
    ACKNOWLEDGED = "acknowledged"
    ASSIGNED = "assigned"
    RESOLVED = "resolved"
    SUPPRESSED = "suppressed"


class AlertConditionType(StrEnum):
    CONGESTION = "congestion"
    SPEED_DROP = "speed_drop"
    STOPPED_VEHICLE = "stopped_vehicle"
    HEAVY_VEHICLE_SHARE = "heavy_vehicle_share"
    CAMERA_OFFLINE = "camera_offline"
    COUNT_ANOMALY = "count_anomaly"


class ClassificationMode(StrEnum):
    FULL_12CLASS = "full_12class"
    COARSE_ONLY = "coarse_only"
    DISABLED = "disabled"


_KOREAN_NAMES: dict[VehicleClass12, str] = {
    VehicleClass12.C01_PASSENGER_MINITRUCK: "승용차/미니트럭",
    VehicleClass12.C02_BUS: "버스",
    VehicleClass12.C03_TRUCK_LT_2_5T: "1~2.5톤 미만",
    VehicleClass12.C04_TRUCK_2_5_TO_8_5T: "2.5~8.5톤 미만",
    VehicleClass12.C05_SINGLE_3_AXLE: "1단위 3축",
    VehicleClass12.C06_SINGLE_4_AXLE: "1단위 4축",
    VehicleClass12.C07_SINGLE_5_AXLE: "1단위 5축",
    VehicleClass12.C08_SEMI_4_AXLE: "2단위 4축 세미 트레일러",
    VehicleClass12.C09_FULL_4_AXLE: "2단위 4축 풀 트레일러",
    VehicleClass12.C10_SEMI_5_AXLE: "2단위 5축 세미 트레일러",
    VehicleClass12.C11_FULL_5_AXLE: "2단위 5축 풀 트레일러",
    VehicleClass12.C12_SEMI_6_AXLE: "2단위 6축 세미 트레일러",
}

_ENGLISH_NAMES: dict[VehicleClass12, str] = {
    VehicleClass12.C01_PASSENGER_MINITRUCK: "Passenger car / Mini-truck",
    VehicleClass12.C02_BUS: "Bus",
    VehicleClass12.C03_TRUCK_LT_2_5T: "Truck (< 2.5 t)",
    VehicleClass12.C04_TRUCK_2_5_TO_8_5T: "Truck (2.5 t - 8.5 t)",
    VehicleClass12.C05_SINGLE_3_AXLE: "Single unit, 3-axle",
    VehicleClass12.C06_SINGLE_4_AXLE: "Single unit, 4-axle",
    VehicleClass12.C07_SINGLE_5_AXLE: "Single unit, 5-axle",
    VehicleClass12.C08_SEMI_4_AXLE: "Combination, 4-axle semi-trailer",
    VehicleClass12.C09_FULL_4_AXLE: "Combination, 4-axle full trailer",
    VehicleClass12.C10_SEMI_5_AXLE: "Combination, 5-axle semi-trailer",
    VehicleClass12.C11_FULL_5_AXLE: "Combination, 5-axle full trailer",
    VehicleClass12.C12_SEMI_6_AXLE: "Combination, 6-axle semi-trailer",
}
