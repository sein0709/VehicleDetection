"""Synthetic JPEG frame generator for load testing.

Produces minimal but valid JPEG frames with camera-specific visual markers
so that downstream services can distinguish traffic from different cameras.
"""

from __future__ import annotations

import io
import struct
from datetime import UTC, datetime


def _minimal_jpeg(width: int, height: int, camera_idx: int, frame_idx: int) -> bytes:
    """Build a small valid JPEG without PIL/Pillow dependency.

    Creates a single-colour JPEG where the colour varies by camera_idx,
    keeping the payload small (~2-4 KB) to avoid network bottlenecks
    during load tests.
    """
    r = (camera_idx * 37 + 50) % 256
    g = (camera_idx * 73 + 100) % 256
    b = (frame_idx * 11 + 30) % 256

    block_w = (width + 7) // 8
    block_h = (height + 7) // 8

    buf = io.BytesIO()

    buf.write(b"\xff\xd8")  # SOI

    # JFIF APP0
    app0 = struct.pack(">HH5sBBBHHBB", 16, 0x0101, b"JFIF\x00", 1, 1, 0, 1, 1, 0, 0)
    buf.write(b"\xff\xe0")
    buf.write(struct.pack(">H", len(app0) + 2))
    buf.write(app0)

    # DQT — flat quantisation table (all 1s for speed, quality irrelevant)
    qt = bytes([1] * 64)
    buf.write(b"\xff\xdb")
    buf.write(struct.pack(">H", 67))
    buf.write(b"\x00")
    buf.write(qt)

    # SOF0 — baseline, 3 components (YCbCr), 1x1 subsampling
    buf.write(b"\xff\xc0")
    buf.write(struct.pack(">HBHH", 11, 8, height, width))
    buf.write(struct.pack("BBB", 1, 0x11, 0))  # Y
    buf.write(struct.pack("BBB", 2, 0x11, 0))  # Cb
    buf.write(struct.pack("BBB", 3, 0x11, 0))  # Cr

    # DHT — minimal Huffman tables (DC + AC for luminance)
    def _write_dht(cls: int, tid: int, lengths: bytes, values: bytes) -> None:
        buf.write(b"\xff\xc4")
        payload = bytes([(cls << 4) | tid]) + lengths + values
        buf.write(struct.pack(">H", len(payload) + 2))
        buf.write(payload)

    dc_lengths = bytes([0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    dc_values = bytes([0])
    _write_dht(0, 0, dc_lengths, dc_values)

    ac_lengths = bytes([0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    ac_values = bytes([0])
    _write_dht(1, 0, ac_lengths, ac_values)

    # SOS
    buf.write(b"\xff\xda")
    buf.write(struct.pack(">H", 8))
    buf.write(struct.pack("B", 3))  # 3 components
    buf.write(struct.pack("BB", 1, 0x00))
    buf.write(struct.pack("BB", 2, 0x00))
    buf.write(struct.pack("BB", 3, 0x00))

    total_blocks = block_w * block_h * 3
    scan_data = bytes([r & 0xFE] * max(total_blocks, 1))
    buf.write(scan_data)

    buf.write(b"\xff\xd9")  # EOI
    return buf.getvalue()


def generate_frame(
    camera_idx: int,
    frame_idx: int,
    width: int = 640,
    height: int = 480,
) -> bytes:
    """Generate a synthetic JPEG frame for load testing."""
    return _minimal_jpeg(width, height, camera_idx, frame_idx)


def frame_metadata_json(
    camera_id: str,
    frame_idx: int,
    timestamp: datetime | None = None,
) -> str:
    """Build the JSON metadata string expected by POST /v1/ingest/frames."""
    ts = (timestamp or datetime.now(tz=UTC)).isoformat()
    return (
        f'{{"camera_id":"{camera_id}",'
        f'"frame_index":{frame_idx},'
        f'"timestamp_utc":"{ts}",'
        f'"offline_upload":false,'
        f'"content_type":"image/jpeg"}}'
    )
