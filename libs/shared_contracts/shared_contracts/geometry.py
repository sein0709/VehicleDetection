"""Geometry primitives for ROI editing, counting lines, and bounding boxes.

All coordinates use normalised values (0.0-1.0) relative to the camera frame
dimensions, making presets resolution-independent.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class Point2D(BaseModel):
    """A 2-D point in normalised image coordinates."""

    x: float = Field(ge=0.0, le=1.0)
    y: float = Field(ge=0.0, le=1.0)


class BoundingBox(BaseModel):
    """Axis-aligned bounding box in normalised coordinates (top-left origin)."""

    x: float = Field(ge=0.0, le=1.0, description="Left edge")
    y: float = Field(ge=0.0, le=1.0, description="Top edge")
    w: float = Field(ge=0.0, le=1.0, description="Width")
    h: float = Field(ge=0.0, le=1.0, description="Height")

    @property
    def center(self) -> Point2D:
        return Point2D(x=self.x + self.w / 2, y=self.y + self.h / 2)

    @property
    def area(self) -> float:
        return self.w * self.h


class DirectionVector(BaseModel):
    """Unit-ish direction vector for a counting line's positive crossing direction."""

    dx: float
    dy: float


class CountingLine(BaseModel):
    """A directional line segment used for vehicle crossing detection."""

    name: str
    start: Point2D
    end: Point2D
    direction: str = Field(description="inbound | outbound | bidirectional")
    direction_vector: DirectionVector


class LanePolyline(BaseModel):
    """A polyline representing a lane boundary or centre-line."""

    name: str
    points: list[Point2D] = Field(min_length=2)


class ROIPolygon(BaseModel):
    """GeoJSON-style polygon for the region of interest.

    Coordinates are normalised (0.0-1.0). The first and last point should be
    identical to close the ring.
    """

    type: str = "Polygon"
    coordinates: list[list[list[float]]]


class ROIPresetGeometry(BaseModel):
    """Complete geometry payload for an ROI preset."""

    roi_polygon: ROIPolygon
    counting_lines: list[CountingLine] = Field(default_factory=list)
    lane_polylines: list[LanePolyline] = Field(default_factory=list)
