"""Request and response Pydantic models for the Notification Service API."""

from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field

from shared_contracts.enums import AlertConditionType, AlertSeverity, AlertStatus


# ── Alert Rule Models ────────────────────────────────────────────────────────


class CreateAlertRuleRequest(BaseModel):
    site_id: UUID | None = None
    camera_id: UUID | None = None
    name: str = Field(min_length=1, max_length=255)
    condition_type: AlertConditionType
    condition_config: dict[str, Any] = Field(default_factory=dict)
    severity: AlertSeverity = AlertSeverity.WARNING
    channels: list[str] = Field(default_factory=lambda: ["push"])
    recipients: list[dict[str, Any]] = Field(default_factory=list)
    cooldown_minutes: int | None = None
    enabled: bool = True


class UpdateAlertRuleRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    condition_config: dict[str, Any] | None = None
    severity: AlertSeverity | None = None
    channels: list[str] | None = None
    recipients: list[dict[str, Any]] | None = None
    cooldown_minutes: int | None = None
    enabled: bool | None = None


class AlertRuleResponse(BaseModel):
    id: UUID
    org_id: UUID
    site_id: UUID | None = None
    camera_id: UUID | None = None
    name: str
    condition_type: AlertConditionType
    condition_config: dict[str, Any]
    severity: AlertSeverity
    channels: list[str]
    recipients: list[dict[str, Any]]
    cooldown_minutes: int
    enabled: bool
    created_at: datetime
    updated_at: datetime
    created_by: UUID | None = None


# ── Alert Event Models ───────────────────────────────────────────────────────


class AlertEventResponse(BaseModel):
    id: UUID
    org_id: UUID
    rule_id: UUID
    camera_id: str | None = None
    site_id: str | None = None
    severity: AlertSeverity
    status: AlertStatus
    message: str
    context: dict[str, Any] = Field(default_factory=dict)
    triggered_at: datetime
    acknowledged_at: datetime | None = None
    acknowledged_by: UUID | None = None
    assigned_to: UUID | None = None
    resolved_at: datetime | None = None
    resolved_by: UUID | None = None


class AcknowledgeRequest(BaseModel):
    pass


class AssignRequest(BaseModel):
    assigned_to: UUID


class ResolveRequest(BaseModel):
    resolution_note: str | None = None


class SuppressRequest(BaseModel):
    reason: str | None = None


# ── Common ───────────────────────────────────────────────────────────────────


class MessageResponse(BaseModel):
    message: str
