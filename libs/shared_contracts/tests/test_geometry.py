"""Tests for geometry types."""

import pytest
from pydantic import ValidationError

from shared_contracts.geometry import BoundingBox, Point2D


class TestPoint2D:
    def test_valid_point(self) -> None:
        p = Point2D(x=0.5, y=0.5)
        assert p.x == 0.5
        assert p.y == 0.5

    def test_boundary_values(self) -> None:
        Point2D(x=0.0, y=0.0)
        Point2D(x=1.0, y=1.0)

    def test_out_of_range(self) -> None:
        with pytest.raises(ValidationError):
            Point2D(x=1.1, y=0.5)
        with pytest.raises(ValidationError):
            Point2D(x=0.5, y=-0.1)


class TestBoundingBox:
    def test_center(self) -> None:
        bbox = BoundingBox(x=0.2, y=0.3, w=0.1, h=0.2)
        center = bbox.center
        assert abs(center.x - 0.25) < 1e-9
        assert abs(center.y - 0.4) < 1e-9

    def test_area(self) -> None:
        bbox = BoundingBox(x=0.0, y=0.0, w=0.5, h=0.4)
        assert abs(bbox.area - 0.2) < 1e-9
