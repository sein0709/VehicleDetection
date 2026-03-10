"""Tests for the export engine — CSV, JSON, and PDF generation."""

from __future__ import annotations

import csv
import io
import json
from datetime import UTC, datetime
from typing import Any
from uuid import uuid4

import pytest

from reporting_api.export_engine import (
    VEHICLE_CLASS_NAMES,
    generate_csv,
    generate_csv_streaming,
    generate_json_export,
    generate_pdf,
)


@pytest.fixture()
def sample_rows() -> list[dict[str, Any]]:
    camera_id = uuid4()
    line_id = uuid4()
    base = datetime(2026, 3, 9, 10, 0, tzinfo=UTC)
    return [
        {
            "camera_id": camera_id,
            "line_id": line_id,
            "bucket_start": base,
            "class12": 1,
            "direction": "inbound",
            "count": 25,
            "sum_confidence": 22.5,
            "sum_speed_kmh": 1250.0,
            "min_speed_kmh": 30.0,
            "max_speed_kmh": 70.0,
        },
        {
            "camera_id": camera_id,
            "line_id": line_id,
            "bucket_start": base,
            "class12": 5,
            "direction": "outbound",
            "count": 10,
            "sum_confidence": 9.0,
            "sum_speed_kmh": 500.0,
            "min_speed_kmh": 25.0,
            "max_speed_kmh": 65.0,
        },
        {
            "camera_id": camera_id,
            "line_id": line_id,
            "bucket_start": base,
            "class12": 10,
            "direction": "inbound",
            "count": 3,
            "sum_confidence": 2.7,
            "sum_speed_kmh": 150.0,
            "min_speed_kmh": 40.0,
            "max_speed_kmh": 60.0,
        },
    ]


class TestGenerateCSV:
    def test_csv_has_header_and_rows(self, sample_rows: list[dict[str, Any]]) -> None:
        data = generate_csv(sample_rows)
        text = data.decode("utf-8")
        assert text.startswith("\ufeff")

        reader = csv.DictReader(io.StringIO(text.lstrip("\ufeff")))
        rows = list(reader)
        assert len(rows) == 3

    def test_csv_class_names(self, sample_rows: list[dict[str, Any]]) -> None:
        data = generate_csv(sample_rows)
        text = data.decode("utf-8")
        assert "Sedan/Passenger" in text
        assert "Small Truck" in text
        assert "Large Bus" in text

    def test_csv_avg_speed(self, sample_rows: list[dict[str, Any]]) -> None:
        data = generate_csv(sample_rows)
        text = data.decode("utf-8")
        reader = csv.DictReader(io.StringIO(text.lstrip("\ufeff")))
        rows = list(reader)
        assert float(rows[0]["avg_speed_kmh"]) == pytest.approx(50.0, abs=0.01)

    def test_csv_empty_rows(self) -> None:
        data = generate_csv([])
        text = data.decode("utf-8")
        lines = text.strip().split("\n")
        assert len(lines) == 1  # header only


class TestGenerateCSVStreaming:
    def test_streaming_yields_lines(self, sample_rows: list[dict[str, Any]]) -> None:
        lines = list(generate_csv_streaming(sample_rows))
        assert len(lines) == 4  # BOM+header + 3 data rows
        assert "bucket_start" in lines[0]
        assert "Sedan/Passenger" in lines[1]

    def test_streaming_empty(self) -> None:
        lines = list(generate_csv_streaming([]))
        assert len(lines) == 1  # header only


class TestGenerateJSON:
    def test_json_structure(self, sample_rows: list[dict[str, Any]]) -> None:
        data = generate_json_export(
            sample_rows,
            scope="camera:test-cam",
            start="2026-03-09T10:00:00Z",
            end="2026-03-09T11:00:00Z",
        )
        doc = json.loads(data)
        assert "report" in doc
        assert "data" in doc
        assert doc["report"]["scope"] == "camera:test-cam"
        assert doc["report"]["total_count"] == 38
        assert doc["report"]["record_count"] == 3

    def test_json_records_have_class_names(
        self, sample_rows: list[dict[str, Any]]
    ) -> None:
        data = generate_json_export(
            sample_rows,
            scope="camera:test-cam",
            start="2026-03-09T10:00:00Z",
            end="2026-03-09T11:00:00Z",
        )
        doc = json.loads(data)
        names = {r["class_name"] for r in doc["data"]}
        assert "Sedan/Passenger" in names
        assert "Small Truck" in names

    def test_json_empty(self) -> None:
        data = generate_json_export(
            [],
            scope="camera:test-cam",
            start="2026-03-09T10:00:00Z",
            end="2026-03-09T11:00:00Z",
        )
        doc = json.loads(data)
        assert doc["report"]["total_count"] == 0
        assert doc["data"] == []


class TestGeneratePDF:
    def test_pdf_is_valid(self, sample_rows: list[dict[str, Any]]) -> None:
        data = generate_pdf(
            sample_rows,
            scope="camera:test-cam",
            start="2026-03-09T10:00:00Z",
            end="2026-03-09T11:00:00Z",
        )
        assert isinstance(data, bytes)
        assert len(data) > 0
        assert data[:4] == b"%PDF"

    def test_pdf_empty_rows(self) -> None:
        data = generate_pdf(
            [],
            scope="camera:test-cam",
            start="2026-03-09T10:00:00Z",
            end="2026-03-09T11:00:00Z",
        )
        assert isinstance(data, bytes)
        assert data[:4] == b"%PDF"

    def test_pdf_with_many_classes(self) -> None:
        rows = [
            {
                "camera_id": uuid4(),
                "line_id": uuid4(),
                "bucket_start": datetime(2026, 3, 9, 10, 0, tzinfo=UTC),
                "class12": cls,
                "direction": "inbound",
                "count": cls * 5,
                "sum_confidence": cls * 4.5,
                "sum_speed_kmh": cls * 250.0,
                "min_speed_kmh": 20.0,
                "max_speed_kmh": 80.0,
            }
            for cls in range(1, 13)
        ]
        data = generate_pdf(
            rows,
            scope="site:test-site",
            start="2026-03-09T08:00:00Z",
            end="2026-03-09T20:00:00Z",
        )
        assert data[:4] == b"%PDF"


class TestVehicleClassNames:
    def test_all_12_classes_named(self) -> None:
        for i in range(1, 13):
            assert i in VEHICLE_CLASS_NAMES
        assert len(VEHICLE_CLASS_NAMES) == 12
