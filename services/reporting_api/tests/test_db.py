"""Tests for the database layer utilities."""

from __future__ import annotations

from datetime import UTC, datetime

import pytest

from reporting_api.db import decode_cursor, encode_cursor


class TestCursorEncoding:
    def test_roundtrip(self) -> None:
        ts = datetime(2026, 3, 9, 10, 15, 0, tzinfo=UTC)
        cursor = encode_cursor(ts)
        assert isinstance(cursor, str)
        decoded = decode_cursor(cursor)
        assert decoded == ts

    def test_naive_datetime(self) -> None:
        ts = datetime(2026, 3, 9, 10, 15, 0)
        cursor = encode_cursor(ts)
        decoded = decode_cursor(cursor)
        assert decoded == ts

    def test_different_timestamps_produce_different_cursors(self) -> None:
        ts1 = datetime(2026, 3, 9, 10, 0, 0, tzinfo=UTC)
        ts2 = datetime(2026, 3, 9, 10, 15, 0, tzinfo=UTC)
        assert encode_cursor(ts1) != encode_cursor(ts2)
