"""Ingest endpoints — frame upload, heartbeat, and upload sessions."""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from uuid import uuid4

from fastapi import APIRouter, File, Form, Request, UploadFile, status
from fastapi.responses import JSONResponse

from ingest_service.dependencies import CurrentUser, OperatorUser  # noqa: TC001
from ingest_service.models import (
    BackpressureResponse,
    CreateSessionRequest,
    FrameMetadata,
    FrameUploadResponse,
    HeartbeatRequest,
    HeartbeatResponse,
    ResumeSessionRequest,
    SessionResponse,
)
from ingest_service.nats_client import NatsFramePublisher  # noqa: TC001
from ingest_service.redis_client import CameraHealthCache, SessionStore  # noqa: TC001
from ingest_service.settings import get_settings
from shared_contracts.events import CameraHealthEvent

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1/ingest", tags=["ingest"])


# ---------------------------------------------------------------------------
# Frame upload
# ---------------------------------------------------------------------------

@router.post(
    "/frames",
    response_model=FrameUploadResponse,
    status_code=status.HTTP_202_ACCEPTED,
    responses={
        429: {"model": BackpressureResponse},
        413: {"description": "Frame exceeds size limit"},
    },
)
async def upload_frame(
    request: Request,
    user: OperatorUser,
    metadata: str = Form(..., description="JSON-encoded FrameMetadata"),
    frame: UploadFile = File(..., description="JPEG frame or H.264 chunk"),  # noqa: B008
) -> FrameUploadResponse | JSONResponse:
    settings = get_settings()
    publisher: NatsFramePublisher = request.app.state.nats_publisher

    meta = FrameMetadata.model_validate_json(metadata)

    queue_depth = await publisher.get_queue_depth(meta.camera_id)
    if queue_depth >= settings.max_queue_depth:
        logger.warning(
            "Backpressure triggered for camera %s: depth=%d limit=%d",
            meta.camera_id,
            queue_depth,
            settings.max_queue_depth,
        )
        return JSONResponse(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            content=BackpressureResponse(
                message=f"Queue depth {queue_depth} exceeds limit {settings.max_queue_depth}",
                retry_after_seconds=settings.backpressure_retry_after,
            ).model_dump(mode="json"),
            headers={"Retry-After": str(settings.backpressure_retry_after)},
        )

    frame_data = await frame.read()

    if len(frame_data) > settings.max_frame_size_bytes:
        return JSONResponse(
            status_code=413,
            content={
                "error": "frame_too_large",
                "message": (
                    f"Frame size {len(frame_data)} bytes exceeds "
                    f"limit {settings.max_frame_size_bytes} bytes"
                ),
            },
        )

    if len(frame_data) == 0:
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={"error": "empty_frame", "message": "Frame data is empty"},
        )

    meta_dict = meta.model_dump(mode="json")
    meta_dict["uploaded_by"] = str(user.user_id)
    meta_dict["org_id"] = user.org_id

    seq = await publisher.publish_frame(meta.camera_id, frame_data, meta_dict)

    if meta.session_id:
        session_store: SessionStore = request.app.state.session_store
        await session_store.increment_frames(meta.session_id)

    estimated_latency = queue_depth * 50.0

    return FrameUploadResponse(
        queue_position=seq,
        estimated_latency_ms=estimated_latency,
    )


# ---------------------------------------------------------------------------
# Heartbeat
# ---------------------------------------------------------------------------

@router.post(
    "/heartbeat",
    response_model=HeartbeatResponse,
)
async def heartbeat(
    request: Request,
    body: HeartbeatRequest,
    user: CurrentUser,
) -> HeartbeatResponse:
    cache: CameraHealthCache = request.app.state.health_cache
    publisher: NatsFramePublisher = request.app.state.nats_publisher

    await cache.record_heartbeat(
        body.camera_id,
        fps_actual=body.fps_actual,
        frame_width=body.frame_width,
        frame_height=body.frame_height,
        last_frame_index=body.last_frame_index,
    )

    health_event = CameraHealthEvent(
        timestamp_utc=datetime.now(tz=UTC),
        camera_id=body.camera_id,
        status=body.status,  # type: ignore[arg-type]
        fps_actual=body.fps_actual,
        last_frame_index=body.last_frame_index,
    )
    try:
        await publisher.publish_health_event(
            body.camera_id,
            health_event.model_dump(mode="json"),
        )
    except Exception:
        logger.warning(
            "Failed to publish health event for camera %s", body.camera_id
        )

    settings = get_settings()
    target_fps = body.fps_actual or 10.0
    expected_interval = settings.offline_threshold_multiplier / target_fps

    return HeartbeatResponse(
        status="ok",
        message=f"Heartbeat recorded for {body.camera_id}",
        expected_interval_seconds=round(expected_interval, 2),
    )


# ---------------------------------------------------------------------------
# Upload sessions (offline / resumable)
# ---------------------------------------------------------------------------

@router.post(
    "/sessions",
    response_model=SessionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_session(
    request: Request,
    body: CreateSessionRequest,
    user: OperatorUser,
) -> SessionResponse:
    from ingest_service.models import SessionState

    session_store: SessionStore = request.app.state.session_store
    session_id = uuid4().hex
    now = datetime.now(tz=UTC)

    state = SessionState(
        session_id=session_id,
        camera_id=body.camera_id,
        status="created",
        frame_count=body.frame_count,
        frames_uploaded=0,
        start_ts=body.start_ts,
        end_ts=body.end_ts,
        offline_upload=body.offline_upload,
        created_by=str(user.user_id),
        created_at=now,
        last_activity_at=now,
        resume_from_index=0,
    )
    await session_store.create(state)

    logger.info(
        "Upload session %s created for camera %s (%d frames)",
        session_id,
        body.camera_id,
        body.frame_count,
    )

    return SessionResponse(
        session_id=session_id,
        camera_id=body.camera_id,
        status="created",
        frame_count=body.frame_count,
        frames_uploaded=0,
        resume_from_index=0,
    )


@router.get(
    "/sessions/{session_id}",
    response_model=SessionResponse,
)
async def get_session(
    request: Request,
    session_id: str,
    user: CurrentUser,
) -> SessionResponse | JSONResponse:
    session_store: SessionStore = request.app.state.session_store
    state = await session_store.get(session_id)

    if state is None:
        return JSONResponse(
            status_code=status.HTTP_404_NOT_FOUND,
            content={"error": "not_found", "message": f"Session {session_id} not found or expired"},
        )

    return SessionResponse(
        session_id=state.session_id,
        camera_id=state.camera_id,
        status=state.status,
        frame_count=state.frame_count,
        frames_uploaded=state.frames_uploaded,
        resume_from_index=state.resume_from_index,
    )


@router.patch(
    "/sessions/{session_id}",
    response_model=SessionResponse,
)
async def resume_session(
    request: Request,
    session_id: str,
    body: ResumeSessionRequest,
    user: OperatorUser,
) -> SessionResponse | JSONResponse:
    session_store: SessionStore = request.app.state.session_store
    state = await session_store.get(session_id)

    if state is None:
        return JSONResponse(
            status_code=status.HTTP_404_NOT_FOUND,
            content={"error": "not_found", "message": f"Session {session_id} not found or expired"},
        )

    if state.status == "completed":
        return JSONResponse(
            status_code=status.HTTP_409_CONFLICT,
            content={"error": "session_completed", "message": "Session already completed"},
        )

    state.resume_from_index = body.last_frame_index + 1
    state.status = "uploading"
    state.last_activity_at = datetime.now(tz=UTC)
    await session_store.update(state)

    logger.info(
        "Session %s resumed from index %d",
        session_id,
        state.resume_from_index,
    )

    return SessionResponse(
        session_id=state.session_id,
        camera_id=state.camera_id,
        status=state.status,
        frame_count=state.frame_count,
        frames_uploaded=state.frames_uploaded,
        resume_from_index=state.resume_from_index,
    )
