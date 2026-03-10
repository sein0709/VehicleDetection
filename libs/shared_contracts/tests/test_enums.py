"""Tests for VehicleClass12 and other shared enumerations."""

from shared_contracts.enums import (
    COARSE_MAPPING,
    CoarseFallbackClass,
    VehicleClass12,
)


class TestVehicleClass12:
    def test_has_12_members(self) -> None:
        assert len(VehicleClass12) == 12

    def test_values_are_1_through_12(self) -> None:
        assert [c.value for c in VehicleClass12] == list(range(1, 13))

    def test_korean_name(self) -> None:
        assert VehicleClass12.C01_PASSENGER_MINITRUCK.korean_name == "승용차/미니트럭"
        assert VehicleClass12.C02_BUS.korean_name == "버스"

    def test_english_name(self) -> None:
        assert VehicleClass12.C01_PASSENGER_MINITRUCK.english_name == "Passenger car / Mini-truck"

    def test_heavy_vehicle_flag(self) -> None:
        assert not VehicleClass12.C01_PASSENGER_MINITRUCK.is_heavy_vehicle
        assert not VehicleClass12.C04_TRUCK_2_5_TO_8_5T.is_heavy_vehicle
        assert VehicleClass12.C05_SINGLE_3_AXLE.is_heavy_vehicle
        assert VehicleClass12.C12_SEMI_6_AXLE.is_heavy_vehicle

    def test_coarse_mapping_covers_all_classes(self) -> None:
        for cls in VehicleClass12:
            assert cls in COARSE_MAPPING

    def test_coarse_mapping_values(self) -> None:
        assert COARSE_MAPPING[VehicleClass12.C01_PASSENGER_MINITRUCK] == CoarseFallbackClass.CAR
        assert COARSE_MAPPING[VehicleClass12.C02_BUS] == CoarseFallbackClass.BUS
        assert COARSE_MAPPING[VehicleClass12.C03_TRUCK_LT_2_5T] == CoarseFallbackClass.TRUCK
        assert COARSE_MAPPING[VehicleClass12.C08_SEMI_4_AXLE] == CoarseFallbackClass.TRAILER

    def test_int_enum_lookup(self) -> None:
        assert VehicleClass12(1) == VehicleClass12.C01_PASSENGER_MINITRUCK
        assert VehicleClass12(12) == VehicleClass12.C12_SEMI_6_AXLE
