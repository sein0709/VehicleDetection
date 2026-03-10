"""Export generation engine for CSV, JSON, and PDF reports.

Generates report files from aggregate data and uploads them to S3-compatible
storage. PDF reports include server-side rendered charts using matplotlib.
"""

from __future__ import annotations

import csv
import io
import json
import logging
from datetime import UTC, datetime
from typing import Any

import boto3
from botocore.config import Config as BotoConfig

from reporting_api.models import ExportFormat

logger = logging.getLogger(__name__)

VEHICLE_CLASS_NAMES: dict[int, str] = {
    1: "Sedan/Passenger",
    2: "SUV/RV",
    3: "Van",
    4: "Pickup Truck",
    5: "Small Truck",
    6: "Medium Truck",
    7: "Large Truck",
    8: "Special Truck",
    9: "Small Bus",
    10: "Large Bus",
    11: "Motorcycle",
    12: "Trailer/Container",
}

CSV_COLUMNS = [
    "bucket_start",
    "camera_id",
    "line_id",
    "class12",
    "class_name",
    "direction",
    "count",
    "avg_confidence",
    "avg_speed_kmh",
    "min_speed_kmh",
    "max_speed_kmh",
]


def _s3_client(
    endpoint: str,
    access_key: str,
    secret_key: str,
):
    return boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=BotoConfig(signature_version="s3v4"),
    )


def generate_csv(rows: list[dict[str, Any]]) -> bytes:
    """Render aggregate rows as a UTF-8 CSV with BOM for Excel compatibility."""
    buf = io.StringIO()
    buf.write("\ufeff")
    writer = csv.DictWriter(buf, fieldnames=CSV_COLUMNS, extrasaction="ignore")
    writer.writeheader()

    for row in rows:
        count = row.get("count", 0)
        writer.writerow(
            {
                "bucket_start": _fmt_ts(row.get("bucket_start")),
                "camera_id": str(row.get("camera_id", "")),
                "line_id": str(row.get("line_id", "")),
                "class12": row.get("class12", ""),
                "class_name": VEHICLE_CLASS_NAMES.get(row.get("class12", 0), "Unknown"),
                "direction": row.get("direction", ""),
                "count": count,
                "avg_confidence": _safe_div(row.get("sum_confidence"), count),
                "avg_speed_kmh": _safe_div(row.get("sum_speed_kmh"), count),
                "min_speed_kmh": row.get("min_speed_kmh", ""),
                "max_speed_kmh": row.get("max_speed_kmh", ""),
            }
        )

    return buf.getvalue().encode("utf-8")


def generate_csv_streaming(rows: list[dict[str, Any]]):
    """Yield CSV lines one at a time for streaming responses."""
    header = ",".join(CSV_COLUMNS) + "\n"
    yield "\ufeff" + header

    for row in rows:
        count = row.get("count", 0)
        values = [
            _fmt_ts(row.get("bucket_start")),
            str(row.get("camera_id", "")),
            str(row.get("line_id", "")),
            str(row.get("class12", "")),
            VEHICLE_CLASS_NAMES.get(row.get("class12", 0), "Unknown"),
            row.get("direction", ""),
            str(count),
            str(_safe_div(row.get("sum_confidence"), count)),
            str(_safe_div(row.get("sum_speed_kmh"), count)),
            str(row.get("min_speed_kmh", "")),
            str(row.get("max_speed_kmh", "")),
        ]
        yield ",".join(values) + "\n"


def generate_json_export(
    rows: list[dict[str, Any]],
    scope: str,
    start: str,
    end: str,
) -> bytes:
    """Render aggregate rows as a structured JSON document."""
    records = []
    for row in rows:
        count = row.get("count", 0)
        records.append(
            {
                "bucket_start": _fmt_ts(row.get("bucket_start")),
                "camera_id": str(row.get("camera_id", "")),
                "line_id": str(row.get("line_id", "")),
                "class12": row.get("class12"),
                "class_name": VEHICLE_CLASS_NAMES.get(row.get("class12", 0), "Unknown"),
                "direction": row.get("direction"),
                "count": count,
                "avg_confidence": _safe_div(row.get("sum_confidence"), count),
                "avg_speed_kmh": _safe_div(row.get("sum_speed_kmh"), count),
                "min_speed_kmh": row.get("min_speed_kmh"),
                "max_speed_kmh": row.get("max_speed_kmh"),
            }
        )

    total_count = sum(r["count"] for r in records)
    doc = {
        "report": {
            "scope": scope,
            "start": start,
            "end": end,
            "generated_at": datetime.now(tz=UTC).isoformat(),
            "total_count": total_count,
            "record_count": len(records),
        },
        "data": records,
    }
    return json.dumps(doc, indent=2, default=str).encode("utf-8")


def generate_pdf(
    rows: list[dict[str, Any]],
    scope: str,
    start: str,
    end: str,
) -> bytes:
    """Render a PDF report with summary charts and a data table.

    Uses matplotlib for chart generation with the Agg backend (no display).
    """
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.backends.backend_pdf import PdfPages

    buf = io.BytesIO()

    class_totals: dict[int, int] = {}
    direction_totals: dict[str, int] = {"inbound": 0, "outbound": 0}
    bucket_totals: dict[str, int] = {}

    for row in rows:
        cls = row.get("class12", 0)
        cnt = row.get("count", 0)
        class_totals[cls] = class_totals.get(cls, 0) + cnt

        d = row.get("direction", "unknown")
        direction_totals[d] = direction_totals.get(d, 0) + cnt

        bs = _fmt_ts(row.get("bucket_start"))
        bucket_totals[bs] = bucket_totals.get(bs, 0) + cnt

    total_count = sum(class_totals.values())

    with PdfPages(buf) as pdf:
        # Title page
        fig, ax = plt.subplots(figsize=(8.5, 11))
        ax.axis("off")
        ax.text(
            0.5, 0.7,
            "GreyEye Traffic Report",
            ha="center", va="center", fontsize=24, fontweight="bold",
        )
        ax.text(
            0.5, 0.6,
            f"Scope: {scope}",
            ha="center", va="center", fontsize=14, color="gray",
        )
        ax.text(
            0.5, 0.55,
            f"Period: {start}  →  {end}",
            ha="center", va="center", fontsize=12, color="gray",
        )
        ax.text(
            0.5, 0.45,
            f"Total Vehicles: {total_count:,}",
            ha="center", va="center", fontsize=16,
        )
        pdf.savefig(fig)
        plt.close(fig)

        # Time-series bar chart
        if bucket_totals:
            fig, ax = plt.subplots(figsize=(11, 5))
            labels = list(bucket_totals.keys())
            display_labels = [_short_time(l) for l in labels]
            values = list(bucket_totals.values())
            ax.bar(range(len(values)), values, color="#3b82f6", alpha=0.85)
            ax.set_title("Vehicle Count per 15-min Bucket", fontsize=14, pad=12)
            ax.set_ylabel("Count")
            step = max(1, len(display_labels) // 20)
            ax.set_xticks(range(0, len(display_labels), step))
            ax.set_xticklabels(display_labels[::step], rotation=45, ha="right", fontsize=8)
            fig.tight_layout()
            pdf.savefig(fig)
            plt.close(fig)

        # Class distribution pie chart
        if class_totals:
            fig, ax = plt.subplots(figsize=(8, 6))
            labels = [
                f"{VEHICLE_CLASS_NAMES.get(k, f'C{k:02d}')} ({v:,})"
                for k, v in sorted(class_totals.items())
            ]
            sizes = [v for _, v in sorted(class_totals.items())]
            colors = plt.cm.Set3([i / max(len(sizes), 1) for i in range(len(sizes))])
            ax.pie(sizes, labels=labels, colors=colors, autopct="%1.1f%%", startangle=90)
            ax.set_title("Vehicle Class Distribution", fontsize=14, pad=12)
            fig.tight_layout()
            pdf.savefig(fig)
            plt.close(fig)

        # Direction split
        if any(v > 0 for v in direction_totals.values()):
            fig, ax = plt.subplots(figsize=(6, 4))
            dirs = [d for d, v in direction_totals.items() if v > 0]
            vals = [v for v in direction_totals.values() if v > 0]
            ax.bar(dirs, vals, color=["#22c55e", "#ef4444"][:len(dirs)], alpha=0.85)
            ax.set_title("Direction Split", fontsize=14, pad=12)
            ax.set_ylabel("Count")
            for i, v in enumerate(vals):
                ax.text(i, v + max(vals) * 0.02, f"{v:,}", ha="center", fontsize=10)
            fig.tight_layout()
            pdf.savefig(fig)
            plt.close(fig)

    return buf.getvalue()


def upload_to_s3(
    data: bytes,
    key: str,
    content_type: str,
    *,
    endpoint: str,
    bucket: str,
    access_key: str,
    secret_key: str,
) -> str:
    """Upload bytes to S3 and return a pre-signed download URL (1-hour TTL)."""
    client = _s3_client(endpoint, access_key, secret_key)

    try:
        client.head_bucket(Bucket=bucket)
    except Exception:
        try:
            client.create_bucket(Bucket=bucket)
        except Exception:
            pass

    client.put_object(
        Bucket=bucket,
        Key=key,
        Body=data,
        ContentType=content_type,
    )

    url = client.generate_presigned_url(
        "get_object",
        Params={"Bucket": bucket, "Key": key},
        ExpiresIn=3600,
    )
    return url


# ── Helpers ──────────────────────────────────────────────────────────────────


def _fmt_ts(val: Any) -> str:
    if val is None:
        return ""
    if isinstance(val, datetime):
        return val.isoformat()
    return str(val)


def _short_time(ts_str: str) -> str:
    """Extract HH:MM from an ISO timestamp for chart labels."""
    try:
        dt = datetime.fromisoformat(ts_str)
        return dt.strftime("%H:%M")
    except Exception:
        return ts_str[:16]


def _safe_div(numerator: Any, denominator: int) -> str:
    if numerator is None or denominator == 0:
        return ""
    return f"{float(numerator) / denominator:.4f}"


CONTENT_TYPES: dict[ExportFormat, str] = {
    ExportFormat.CSV: "text/csv; charset=utf-8",
    ExportFormat.JSON: "application/json",
    ExportFormat.PDF: "application/pdf",
}


def get_file_extension(fmt: ExportFormat) -> str:
    return {"csv": "csv", "json": "json", "pdf": "pdf"}[fmt.value]
