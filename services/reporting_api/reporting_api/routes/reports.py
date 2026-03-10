"""Report export and shared-link endpoints."""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import UTC, datetime, timedelta
from typing import Annotated, Any
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import StreamingResponse

from reporting_api import db
from reporting_api.dependencies import CurrentUser, require_role
from reporting_api.export_engine import (
    CONTENT_TYPES,
    generate_csv,
    generate_csv_streaming,
    generate_json_export,
    generate_pdf,
    get_file_extension,
    upload_to_s3,
)
from reporting_api.models import (
    ExportFormat,
    ExportRequest,
    ExportResponse,
    ExportStatus,
    ShareLinkRequest,
    ShareLinkResponse,
    SharedReportDataResponse,
)
from reporting_api.settings import get_settings
from shared_contracts.enums import UserRole

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1/reports", tags=["reports"])

AnalystUser = Annotated[Any, Depends(require_role(UserRole.ANALYST))]

_exports: dict[str, dict[str, Any]] = {}


@router.post("/export", response_model=ExportResponse, status_code=status.HTTP_202_ACCEPTED)
async def create_export(
    request: Request,
    body: ExportRequest,
    user: AnalystUser,
) -> ExportResponse:
    """Enqueue a report export job (CSV / JSON / PDF).

    The export is generated in a background task. Poll
    ``GET /v1/reports/export/{export_id}`` for status and download URL.
    """
    export_id = uuid4().hex
    now = datetime.now(tz=UTC)

    _exports[export_id] = {
        "export_id": export_id,
        "status": ExportStatus.PENDING,
        "scope": body.scope,
        "start": body.start.isoformat(),
        "end": body.end.isoformat(),
        "format": body.format,
        "filters": body.filters,
        "org_id": user.org_id,
        "created_by": user.sub,
        "created_at": now.isoformat(),
        "download_url": None,
    }

    asyncio.get_event_loop().create_task(
        _run_export(export_id, body, user.org_uuid)
    )

    return ExportResponse(
        export_id=export_id,
        status=ExportStatus.PENDING,
        format=body.format,
        created_at=now,
    )


async def _run_export(export_id: str, body: ExportRequest, org_id) -> None:
    """Background task: query data, generate file, upload to S3."""
    job = _exports.get(export_id)
    if job is None:
        return

    job["status"] = ExportStatus.PROCESSING

    try:
        rows = await db.query_export_data(
            org_id=org_id,
            scope=body.scope,
            start=body.start,
            end=body.end,
            filters=body.filters or None,
        )

        if body.format == ExportFormat.CSV:
            data = generate_csv(rows)
            content_type = CONTENT_TYPES[ExportFormat.CSV]
        elif body.format == ExportFormat.JSON:
            data = generate_json_export(
                rows,
                scope=body.scope,
                start=body.start.isoformat(),
                end=body.end.isoformat(),
            )
            content_type = CONTENT_TYPES[ExportFormat.JSON]
        elif body.format == ExportFormat.PDF:
            data = generate_pdf(
                rows,
                scope=body.scope,
                start=body.start.isoformat(),
                end=body.end.isoformat(),
            )
            content_type = CONTENT_TYPES[ExportFormat.PDF]
        else:
            raise ValueError(f"Unsupported format: {body.format}")

        settings = get_settings()
        ext = get_file_extension(body.format)
        s3_key = f"exports/{job['org_id']}/{export_id}.{ext}"

        download_url = upload_to_s3(
            data,
            s3_key,
            content_type,
            endpoint=settings.s3_endpoint,
            bucket=settings.s3_bucket,
            access_key=settings.s3_access_key,
            secret_key=settings.s3_secret_key,
        )

        job["status"] = ExportStatus.COMPLETED
        job["download_url"] = download_url
        logger.info("Export %s completed: %s", export_id, s3_key)

    except Exception:
        logger.exception("Export %s failed", export_id)
        job["status"] = ExportStatus.FAILED


@router.get("/export/{export_id}", response_model=ExportResponse)
async def get_export_status(
    export_id: str,
    user: CurrentUser,
) -> ExportResponse:
    """Check export job status or retrieve the download URL."""
    job = _exports.get(export_id)
    if job is None or job["org_id"] != user.org_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Export job not found",
        )

    return ExportResponse(
        export_id=job["export_id"],
        status=ExportStatus(job["status"]),
        format=ExportFormat(job["format"]) if job.get("format") else None,
        download_url=job.get("download_url"),
        created_at=datetime.fromisoformat(job["created_at"]) if job.get("created_at") else None,
    )


@router.get("/export/{export_id}/download")
async def download_export(
    export_id: str,
    user: CurrentUser,
) -> StreamingResponse:
    """Stream the export file directly if still in memory.

    For large exports that have been uploaded to S3, the ``download_url``
    from the status endpoint should be used instead.
    """
    job = _exports.get(export_id)
    if job is None or job["org_id"] != user.org_id:
        raise HTTPException(status_code=404, detail="Export job not found")

    if job["status"] != ExportStatus.COMPLETED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Export is {job['status']}, not ready for download",
        )

    if job.get("download_url"):
        return StreamingResponse(
            iter([b""]),
            status_code=status.HTTP_307_TEMPORARY_REDIRECT,
            headers={"Location": job["download_url"]},
        )

    raise HTTPException(status_code=404, detail="Export file not available")


@router.post("/export/stream")
async def stream_csv_export(
    body: ExportRequest,
    user: AnalystUser,
) -> StreamingResponse:
    """Stream a CSV export directly without storing to S3.

    Suitable for smaller exports where the client wants an immediate download.
    """
    rows = await db.query_export_data(
        org_id=user.org_uuid,
        scope=body.scope,
        start=body.start,
        end=body.end,
        filters=body.filters or None,
    )

    return StreamingResponse(
        generate_csv_streaming(rows),
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": f'attachment; filename="greyeye_export_{datetime.now(tz=UTC).strftime("%Y%m%d_%H%M%S")}.csv"',
        },
    )


# ── Shared Links ─────────────────────────────────────────────────────────────


@router.post("/share", response_model=ShareLinkResponse, status_code=status.HTTP_201_CREATED)
async def create_share_link(
    body: ShareLinkRequest,
    user: AnalystUser,
) -> ShareLinkResponse:
    """Create a time-limited shareable link for a report view."""
    settings = get_settings()
    ttl_days = min(body.ttl_days, settings.share_link_ttl_days)
    expires_at = datetime.now(tz=UTC) + timedelta(days=ttl_days)

    record = await db.create_shared_link(
        org_id=user.org_uuid,
        created_by=user.user_id,
        scope=body.scope,
        filters=body.filters,
        expires_at=expires_at,
    )

    token = record["token"]
    return ShareLinkResponse(
        token=token,
        url=f"/v1/reports/shared/{token}",
        expires_at=expires_at,
    )


@router.get("/shared/{token}")
async def access_shared_report(token: str) -> dict:
    """Access a shared report — no authentication required.

    Returns the report scope, filters, and expiration metadata.
    """
    record = await db.get_shared_link(token)
    if record is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Shared link not found or expired",
        )

    scope = record["scope"]
    if isinstance(scope, str):
        try:
            scope = json.loads(scope)
        except (json.JSONDecodeError, TypeError):
            pass

    filters = record["filters"]
    if isinstance(filters, str):
        try:
            filters = json.loads(filters)
        except (json.JSONDecodeError, TypeError):
            pass

    return {
        "scope": scope,
        "filters": filters,
        "expires_at": record["expires_at"].isoformat()
        if isinstance(record["expires_at"], datetime)
        else record["expires_at"],
    }


@router.get("/shared/{token}/data", response_model=SharedReportDataResponse)
async def access_shared_report_data(token: str) -> SharedReportDataResponse:
    """Access the full analytics data for a shared report — no auth required.

    Returns the report metadata plus the underlying aggregate rows.
    """
    link, data = await db.get_shared_link_data(token)
    if link is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Shared link not found or expired",
        )

    scope = link["scope"]
    if isinstance(scope, str):
        try:
            scope = json.loads(scope)
        except (json.JSONDecodeError, TypeError):
            pass

    filters = link["filters"]
    if isinstance(filters, str):
        try:
            filters = json.loads(filters)
        except (json.JSONDecodeError, TypeError):
            pass

    serialized_data = []
    for row in data:
        serialized_row = {}
        for k, v in row.items():
            if isinstance(v, datetime):
                serialized_row[k] = v.isoformat()
            elif hasattr(v, "hex"):
                serialized_row[k] = str(v)
            else:
                serialized_row[k] = v
        serialized_data.append(serialized_row)

    return SharedReportDataResponse(
        scope=scope,
        filters=filters,
        expires_at=link["expires_at"].isoformat()
        if isinstance(link["expires_at"], datetime)
        else link["expires_at"],
        data=serialized_data,
    )
