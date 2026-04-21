"""EasyOCR verifier for Korean license plates.

Gemma does plate localization + OCR in a single call (see vlm.py). EasyOCR
here is the *secondary* pass used to score agreement / fill in when Gemma is
down (circuit open) or returns low confidence.
"""
from __future__ import annotations

import logging
import re
import threading
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    import numpy as np

logger = logging.getLogger("ocr")

# Korean plate format: 2–3 digit region, 1 Hangul syllable, 4 digits.
#   e.g. "12가3456" or "123가4567"
_PLATE_RE = re.compile(r"(\d{2,3})\s*([가-힣])\s*(\d{4})")


class EasyOcrVerifier:
    """Lazy-loaded singleton; torch + easyocr is heavy, only load on first use."""

    def __init__(self) -> None:
        self._reader = None
        self._lock = threading.Lock()
        self._load_failed = False

    def _get_reader(self):
        if self._reader is not None or self._load_failed:
            return self._reader
        with self._lock:
            if self._reader is not None or self._load_failed:
                return self._reader
            try:
                import easyocr

                self._reader = easyocr.Reader(["ko", "en"], gpu=True)
                logger.info("EasyOCR reader loaded (ko+en, GPU)")
            except Exception as exc:
                logger.error("EasyOCR load failed: %s — verification disabled", exc)
                self._load_failed = True
        return self._reader

    def read(self, plate_crop: "np.ndarray") -> dict[str, Any] | None:
        reader = self._get_reader()
        if reader is None or plate_crop.size == 0:
            return None
        try:
            results = reader.readtext(plate_crop, detail=1, paragraph=False)
        except Exception as exc:
            logger.warning("EasyOCR readtext failed: %s", exc)
            return None

        if not results:
            return {"plate_text": "", "confidence": 0.0}

        joined = " ".join(r[1] for r in results)
        mean_conf = sum(r[2] for r in results) / len(results)
        m = _PLATE_RE.search(joined.replace(" ", ""))
        normalized = f"{m.group(1)}{m.group(2)}{m.group(3)}" if m else joined.strip()
        return {"plate_text": normalized, "confidence": round(mean_conf, 3)}


verifier = EasyOcrVerifier()


def normalize_plate(text: str) -> str:
    """Collapse whitespace and match canonical Korean-plate shape if possible."""
    if not text:
        return ""
    m = _PLATE_RE.search(text.replace(" ", ""))
    return f"{m.group(1)}{m.group(2)}{m.group(3)}" if m else text.strip()


# ---------------------------------------------------------------------------
# Resident vs visitor classification
# ---------------------------------------------------------------------------
import hashlib  # noqa: E402 — local to plate helpers, not performance-critical


def classify_plate(plate_text: str, allowlist: list[str]) -> str:
    """Return ``resident`` if the normalized plate matches any normalized
    allowlist entry; otherwise ``visitor``. Match is exact after normalization
    (no wildcards, no partial matches)."""
    if not plate_text:
        return "unknown"
    norm = normalize_plate(plate_text)
    if norm in allowlist:
        return "resident"
    return "visitor"


def hash_plate(plate_text: str, prefix_bytes: int = 8) -> str:
    """Short SHA-256 prefix for privacy-mode storage. 8 bytes = 64 bits = 16
    hex chars — enough to distinguish repeat visitors while being non-
    reversible for practical purposes."""
    if not plate_text:
        return ""
    digest = hashlib.sha256(normalize_plate(plate_text).encode("utf-8")).hexdigest()
    return digest[: prefix_bytes * 2]
