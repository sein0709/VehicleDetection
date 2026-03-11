"""Alert rule and event management endpoints.

Provides CRUD for alert rules, alert event listing with filtering,
and the full alert lifecycle state machine:
    triggered → acknowledged → assigned → resolved
    triggered → suppressed
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Request, status

from notification_service.db import NotificationDB
from notification_service.dependencies import CurrentUser, OperatorUser
from notification_service.models import (
    AcknowledgeRequest,
    AlertEventResponse,
    AlertRuleResponse,
    AssignRequest,
    CreateAlertRuleRequest,
    MessageResponse,
    ResolveRequest,
    SuppressRequest,
    UpdateAlertRuleRequest,
)
from notification_service.settings import get_settings
from shared_contracts.enums import AlertStatus
from shared_contracts.pagination import PaginatedResponse, PaginationMeta

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/v1/alerts", tags=["alerts"])


def _get_db(request: Request) -> NotificationDB:
    return request.app.state.notification_db


async def _invalidate_cache(request: Request) -> None:
    """Invalidate the NATS consumer's rule cache after a mutation."""
    consumer = getattr(request.app.state, "consumer", None)
    if consumer is not None:
        try:
            await consumer.invalidate_rules_cache()
        except Exception:
            logger.warning("Failed to invalidate rules cache after mutation")


def _extract_cursor(
    rows: list[dict], field: str = "created_at"
) -> str | None:
    if not rows:
        return None
    val = rows[-1].get(field)
    if hasattr(val, "isoformat"):
        return val.isoformat()
    return str(val) if val is not None else None


# ── Alert Rules ──────────────────────────────────────────────────────────────


@router.post("/rules", response_model=AlertRuleResponse, status_code=status.HTTP_201_CREATED)
async def create_alert_rule(
    body: CreateAlertRuleRequest,
    request: Request,
    user: OperatorUser,
) -> AlertRuleResponse:
    db = _get_db(request)

    data = body.model_dump()
    if data.get("cooldown_minutes") is None:
        data["cooldown_minutes"] = get_settings().default_cooldown_minutes
    data["created_by"] = user.user_id

    rule = await db.create_rule(org_id=user.org_uuid, data=data)
    await _invalidate_cache(request)
    return AlertRuleResponse(**rule)


@router.get("/rules", response_model=PaginatedResponse[AlertRuleResponse])
async def list_alert_rules(
    request: Request,
    user: CurrentUser,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    site_id: UUID | None = Query(default=None),
    camera_id: UUID | None = Query(default=None),
    enabled: bool | None = Query(default=None),
    condition_type: str | None = Query(default=None),
) -> PaginatedResponse[AlertRuleResponse]:
    db = _get_db(request)

    rules, total = await db.list_rules(
        user.org_uuid,
        enabled_only=enabled is True,
        site_id=site_id,
        camera_id=camera_id,
        condition_type=condition_type,
        limit=limit + 1,
        cursor=cursor,
    )

    has_more = len(rules) > limit
    if has_more:
        rules = rules[:limit]

    return PaginatedResponse[AlertRuleResponse](
        data=[AlertRuleResponse(**r) for r in rules],
        pagination=PaginationMeta(
            cursor=_extract_cursor(rules) if has_more else None,
            has_more=has_more,
            total_count=total,
        ),
    )


@router.get("/rules/{rule_id}", response_model=AlertRuleResponse)
async def get_alert_rule(
    rule_id: UUID,
    request: Request,
    user: CurrentUser,
) -> AlertRuleResponse:
    db = _get_db(request)
    rule = await db.get_rule(rule_id, user.org_uuid)
    if not rule:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Alert rule not found"
        )
    return AlertRuleResponse(**rule)


@router.patch("/rules/{rule_id}", response_model=AlertRuleResponse)
async def update_alert_rule(
    rule_id: UUID,
    body: UpdateAlertRuleRequest,
    request: Request,
    user: OperatorUser,
) -> AlertRuleResponse:
    db = _get_db(request)

    updates = body.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No fields to update",
        )

    rule = await db.update_rule(rule_id, user.org_uuid, updates=updates)
    if not rule:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Alert rule not found"
        )

    await _invalidate_cache(request)
    return AlertRuleResponse(**rule)


@router.delete("/rules/{rule_id}", response_model=MessageResponse)
async def delete_alert_rule(
    rule_id: UUID,
    request: Request,
    user: OperatorUser,
) -> MessageResponse:
    db = _get_db(request)

    deleted = await db.delete_rule(rule_id, user.org_uuid)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Alert rule not found"
        )

    await _invalidate_cache(request)
    return MessageResponse(message="Alert rule deleted successfully")


# ── Alert Events ─────────────────────────────────────────────────────────────


@router.get("", response_model=PaginatedResponse[AlertEventResponse])
async def list_alerts(
    request: Request,
    user: CurrentUser,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    alert_status: str | None = Query(default=None, alias="status"),
    severity: str | None = Query(default=None),
    site_id: str | None = Query(default=None),
    camera_id: str | None = Query(default=None),
) -> PaginatedResponse[AlertEventResponse]:
    db = _get_db(request)

    events, total = await db.list_alert_events(
        user.org_uuid,
        status_filter=alert_status,
        severity=severity,
        site_id=site_id,
        camera_id=camera_id,
        limit=limit + 1,
        cursor=cursor,
    )

    has_more = len(events) > limit
    if has_more:
        events = events[:limit]

    return PaginatedResponse[AlertEventResponse](
        data=[AlertEventResponse(**e) for e in events],
        pagination=PaginationMeta(
            cursor=_extract_cursor(events, "triggered_at") if has_more else None,
            has_more=has_more,
            total_count=total,
        ),
    )


@router.get("/history", response_model=PaginatedResponse[AlertEventResponse])
async def alert_history(
    request: Request,
    user: CurrentUser,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    since: datetime | None = Query(default=None),
    until: datetime | None = Query(default=None),
    rule_id: UUID | None = Query(default=None),
) -> PaginatedResponse[AlertEventResponse]:
    db = _get_db(request)

    events, total = await db.list_alert_history(
        user.org_uuid,
        since=since,
        until=until,
        rule_id=rule_id,
        limit=limit + 1,
        cursor=cursor,
    )

    has_more = len(events) > limit
    if has_more:
        events = events[:limit]

    return PaginatedResponse[AlertEventResponse](
        data=[AlertEventResponse(**e) for e in events],
        pagination=PaginationMeta(
            cursor=_extract_cursor(events, "triggered_at") if has_more else None,
            has_more=has_more,
            total_count=total,
        ),
    )


@router.get("/{alert_id}", response_model=AlertEventResponse)
async def get_alert(
    alert_id: UUID,
    request: Request,
    user: CurrentUser,
) -> AlertEventResponse:
    db = _get_db(request)
    event = await db.get_alert_event(alert_id, user.org_uuid)
    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Alert not found"
        )
    return AlertEventResponse(**event)


_VALID_TRANSITIONS: dict[str, set[str]] = {
    AlertStatus.TRIGGERED: {
        AlertStatus.ACKNOWLEDGED,
        AlertStatus.ASSIGNED,
        AlertStatus.RESOLVED,
        AlertStatus.SUPPRESSED,
    },
    AlertStatus.ACKNOWLEDGED: {
        AlertStatus.ASSIGNED,
        AlertStatus.RESOLVED,
    },
    AlertStatus.ASSIGNED: {
        AlertStatus.ACKNOWLEDGED,
        AlertStatus.RESOLVED,
    },
}


def _validate_transition(current: str, target: str) -> None:
    allowed = _VALID_TRANSITIONS.get(current, set())
    if target not in allowed:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Cannot transition from '{current}' to '{target}'",
        )


@router.post("/{alert_id}/acknowledge", response_model=AlertEventResponse)
async def acknowledge_alert(
    alert_id: UUID,
    body: AcknowledgeRequest,
    request: Request,
    user: CurrentUser,
) -> AlertEventResponse:
    db = _get_db(request)

    existing = await db.get_alert_event(alert_id, user.org_uuid)
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Alert not found"
        )

    _validate_transition(existing["status"], AlertStatus.ACKNOWLEDGED)

    updated = await db.update_alert_status(
        alert_id,
        user.org_uuid,
        updates={
            "status": AlertStatus.ACKNOWLEDGED,
            "acknowledged_at": datetime.now(tz=UTC),
            "acknowledged_by": user.user_id,
        },
    )
    return AlertEventResponse(**updated)


@router.post("/{alert_id}/assign", response_model=AlertEventResponse)
async def assign_alert(
    alert_id: UUID,
    body: AssignRequest,
    request: Request,
    user: OperatorUser,
) -> AlertEventResponse:
    db = _get_db(request)

    existing = await db.get_alert_event(alert_id, user.org_uuid)
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Alert not found"
        )

    _validate_transition(existing["status"], AlertStatus.ASSIGNED)

    updated = await db.update_alert_status(
        alert_id,
        user.org_uuid,
        updates={
            "status": AlertStatus.ASSIGNED,
            "assigned_to": body.assigned_to,
        },
    )
    return AlertEventResponse(**updated)


@router.post("/{alert_id}/resolve", response_model=AlertEventResponse)
async def resolve_alert(
    alert_id: UUID,
    body: ResolveRequest,
    request: Request,
    user: CurrentUser,
) -> AlertEventResponse:
    db = _get_db(request)

    existing = await db.get_alert_event(alert_id, user.org_uuid)
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Alert not found"
        )

    _validate_transition(existing["status"], AlertStatus.RESOLVED)

    updates: dict = {
        "status": AlertStatus.RESOLVED,
        "resolved_at": datetime.now(tz=UTC),
        "resolved_by": user.user_id,
    }
    if body.resolution_note:
        context = existing.get("context", {})
        context["resolution_note"] = body.resolution_note
        updates["context"] = context

    updated = await db.update_alert_status(
        alert_id, user.org_uuid, updates=updates
    )
    return AlertEventResponse(**updated)


@router.post("/{alert_id}/suppress", response_model=AlertEventResponse)
async def suppress_alert(
    alert_id: UUID,
    body: SuppressRequest,
    request: Request,
    user: OperatorUser,
) -> AlertEventResponse:
    db = _get_db(request)

    existing = await db.get_alert_event(alert_id, user.org_uuid)
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Alert not found"
        )

    _validate_transition(existing["status"], AlertStatus.SUPPRESSED)

    updates: dict = {"status": AlertStatus.SUPPRESSED}
    if body.reason:
        context = existing.get("context", {})
        context["suppression_reason"] = body.reason
        updates["context"] = context

    updated = await db.update_alert_status(
        alert_id, user.org_uuid, updates=updates
    )
    return AlertEventResponse(**updated)
