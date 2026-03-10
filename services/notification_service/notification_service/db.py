"""Async database client for alert_rules and alert_events tables.

Uses SQLAlchemy Core with asyncpg for non-blocking Postgres access.
"""

from __future__ import annotations

import logging
import ssl
from datetime import UTC, datetime
from typing import Any
from uuid import UUID, uuid4

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Integer,
    MetaData,
    String,
    Table,
    Text,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

from notification_service.settings import Settings

logger = logging.getLogger(__name__)

metadata = MetaData()

alert_rules = Table(
    "alert_rules",
    metadata,
    Column("id", PG_UUID(as_uuid=True), primary_key=True, default=uuid4),
    Column("org_id", PG_UUID(as_uuid=True), nullable=False),
    Column("site_id", PG_UUID(as_uuid=True), nullable=True),
    Column("camera_id", PG_UUID(as_uuid=True), nullable=True),
    Column("name", String(255), nullable=False),
    Column("condition_type", String(50), nullable=False),
    Column("condition_config", JSONB, nullable=False, server_default=text("'{}'")),
    Column("severity", String(20), nullable=False, server_default="warning"),
    Column("channels", JSONB, nullable=False, server_default=text("'[\"push\"]'")),
    Column("recipients", JSONB, nullable=False, server_default=text("'[]'")),
    Column("cooldown_minutes", Integer, nullable=False, server_default=text("15")),
    Column("enabled", Boolean, nullable=False, server_default=text("true")),
    Column("created_at", DateTime(timezone=True), nullable=False, server_default=text("now()")),
    Column("updated_at", DateTime(timezone=True), nullable=False, server_default=text("now()")),
    Column("created_by", PG_UUID(as_uuid=True), nullable=True),
)

alert_events = Table(
    "alert_events",
    metadata,
    Column("id", PG_UUID(as_uuid=True), primary_key=True, default=uuid4),
    Column("org_id", PG_UUID(as_uuid=True), nullable=False),
    Column("rule_id", PG_UUID(as_uuid=True), nullable=False),
    Column("camera_id", String(255), nullable=True),
    Column("site_id", String(255), nullable=True),
    Column("severity", String(20), nullable=False),
    Column("status", String(20), nullable=False, server_default="triggered"),
    Column("message", Text, nullable=False),
    Column("context", JSONB, nullable=False, server_default=text("'{}'")),
    Column("triggered_at", DateTime(timezone=True), nullable=False, server_default=text("now()")),
    Column("acknowledged_at", DateTime(timezone=True), nullable=True),
    Column("acknowledged_by", PG_UUID(as_uuid=True), nullable=True),
    Column("assigned_to", PG_UUID(as_uuid=True), nullable=True),
    Column("resolved_at", DateTime(timezone=True), nullable=True),
    Column("resolved_by", PG_UUID(as_uuid=True), nullable=True),
)


class NotificationDB:
    """Async database client for alert rules and events."""

    def __init__(self, settings: Settings) -> None:
        dsn = settings.database_url
        if not dsn.startswith("postgresql+asyncpg://"):
            dsn = dsn.replace("postgresql://", "postgresql+asyncpg://", 1)
        connect_args: dict[str, Any] = {}
        if ".supabase.com" in dsn or ".supabase.co" in dsn:
            ssl_ctx = ssl.create_default_context()
            ssl_ctx.check_hostname = False
            ssl_ctx.verify_mode = ssl.CERT_NONE
            connect_args["ssl"] = ssl_ctx
        self._engine: AsyncEngine = create_async_engine(
            dsn,
            pool_size=5,
            max_overflow=10,
            connect_args=connect_args,
        )

    async def close(self) -> None:
        await self._engine.dispose()

    # ── Alert Rules ──────────────────────────────────────────────────────────

    async def create_rule(self, *, org_id: UUID, data: dict[str, Any]) -> dict[str, Any]:
        row_id = uuid4()
        now = datetime.now(tz=UTC)
        row = {
            "id": row_id,
            "org_id": org_id,
            "created_at": now,
            "updated_at": now,
            **data,
        }
        async with self._engine.begin() as conn:
            await conn.execute(alert_rules.insert().values(**row))
            result = await conn.execute(
                alert_rules.select().where(alert_rules.c.id == row_id)
            )
            return dict(result.mappings().one())

    async def get_rule(self, rule_id: UUID, org_id: UUID) -> dict[str, Any] | None:
        async with self._engine.connect() as conn:
            result = await conn.execute(
                alert_rules.select()
                .where(alert_rules.c.id == rule_id)
                .where(alert_rules.c.org_id == org_id)
            )
            row = result.mappings().first()
            return dict(row) if row else None

    async def list_rules(
        self,
        org_id: UUID,
        *,
        enabled_only: bool = False,
        site_id: UUID | None = None,
        camera_id: UUID | None = None,
        condition_type: str | None = None,
        limit: int = 50,
        cursor: str | None = None,
    ) -> tuple[list[dict[str, Any]], int]:
        query = (
            alert_rules.select()
            .where(alert_rules.c.org_id == org_id)
            .order_by(alert_rules.c.created_at.desc())
            .limit(limit)
        )
        count_query = (
            text("SELECT count(*) FROM alert_rules WHERE org_id = :org_id")
        )
        params: dict[str, Any] = {"org_id": org_id}

        if enabled_only:
            query = query.where(alert_rules.c.enabled.is_(True))
        if site_id:
            query = query.where(alert_rules.c.site_id == site_id)
        if camera_id:
            query = query.where(alert_rules.c.camera_id == camera_id)
        if condition_type:
            query = query.where(alert_rules.c.condition_type == condition_type)
        if cursor:
            query = query.where(alert_rules.c.created_at < cursor)

        async with self._engine.connect() as conn:
            result = await conn.execute(query)
            rows = [dict(r) for r in result.mappings().all()]
            count_result = await conn.execute(count_query, params)
            total = count_result.scalar() or 0
            return rows, total

    async def update_rule(
        self, rule_id: UUID, org_id: UUID, *, updates: dict[str, Any]
    ) -> dict[str, Any] | None:
        updates["updated_at"] = datetime.now(tz=UTC)
        async with self._engine.begin() as conn:
            result = await conn.execute(
                alert_rules.update()
                .where(alert_rules.c.id == rule_id)
                .where(alert_rules.c.org_id == org_id)
                .values(**updates)
                .returning(*alert_rules.c)
            )
            row = result.mappings().first()
            return dict(row) if row else None

    async def delete_rule(self, rule_id: UUID, org_id: UUID) -> bool:
        async with self._engine.begin() as conn:
            result = await conn.execute(
                alert_rules.delete()
                .where(alert_rules.c.id == rule_id)
                .where(alert_rules.c.org_id == org_id)
            )
            return result.rowcount > 0

    async def list_active_rules(
        self,
        *,
        camera_id: str | None = None,
        site_id: str | None = None,
    ) -> list[dict[str, Any]]:
        """Load enabled rules matching the given scope (used by NATS consumer)."""
        query = alert_rules.select().where(alert_rules.c.enabled.is_(True))
        if camera_id:
            query = query.where(
                (alert_rules.c.camera_id == UUID(camera_id))
                | alert_rules.c.camera_id.is_(None)
            )
        if site_id:
            query = query.where(
                (alert_rules.c.site_id == UUID(site_id))
                | alert_rules.c.site_id.is_(None)
            )
        async with self._engine.connect() as conn:
            result = await conn.execute(query)
            return [dict(r) for r in result.mappings().all()]

    # ── Alert Events ─────────────────────────────────────────────────────────

    async def create_alert_event(self, *, data: dict[str, Any]) -> dict[str, Any]:
        row_id = uuid4()
        now = datetime.now(tz=UTC)
        row = {"id": row_id, "triggered_at": now, **data}
        async with self._engine.begin() as conn:
            await conn.execute(alert_events.insert().values(**row))
            result = await conn.execute(
                alert_events.select().where(alert_events.c.id == row_id)
            )
            return dict(result.mappings().one())

    async def get_alert_event(self, alert_id: UUID, org_id: UUID) -> dict[str, Any] | None:
        async with self._engine.connect() as conn:
            result = await conn.execute(
                alert_events.select()
                .where(alert_events.c.id == alert_id)
                .where(alert_events.c.org_id == org_id)
            )
            row = result.mappings().first()
            return dict(row) if row else None

    async def list_alert_events(
        self,
        org_id: UUID,
        *,
        status_filter: str | None = None,
        severity: str | None = None,
        site_id: str | None = None,
        camera_id: str | None = None,
        limit: int = 50,
        cursor: str | None = None,
    ) -> tuple[list[dict[str, Any]], int]:
        query = (
            alert_events.select()
            .where(alert_events.c.org_id == org_id)
            .order_by(alert_events.c.triggered_at.desc())
            .limit(limit)
        )
        count_query = text("SELECT count(*) FROM alert_events WHERE org_id = :org_id")
        params: dict[str, Any] = {"org_id": org_id}

        if status_filter:
            query = query.where(alert_events.c.status == status_filter)
        if severity:
            query = query.where(alert_events.c.severity == severity)
        if site_id:
            query = query.where(alert_events.c.site_id == site_id)
        if camera_id:
            query = query.where(alert_events.c.camera_id == camera_id)
        if cursor:
            query = query.where(alert_events.c.triggered_at < cursor)

        async with self._engine.connect() as conn:
            result = await conn.execute(query)
            rows = [dict(r) for r in result.mappings().all()]
            count_result = await conn.execute(count_query, params)
            total = count_result.scalar() or 0
            return rows, total

    async def update_alert_status(
        self,
        alert_id: UUID,
        org_id: UUID,
        *,
        updates: dict[str, Any],
    ) -> dict[str, Any] | None:
        async with self._engine.begin() as conn:
            result = await conn.execute(
                alert_events.update()
                .where(alert_events.c.id == alert_id)
                .where(alert_events.c.org_id == org_id)
                .values(**updates)
                .returning(*alert_events.c)
            )
            row = result.mappings().first()
            return dict(row) if row else None

    async def list_alert_history(
        self,
        org_id: UUID,
        *,
        since: datetime | None = None,
        until: datetime | None = None,
        rule_id: UUID | None = None,
        limit: int = 50,
        cursor: str | None = None,
    ) -> tuple[list[dict[str, Any]], int]:
        query = (
            alert_events.select()
            .where(alert_events.c.org_id == org_id)
            .order_by(alert_events.c.triggered_at.desc())
            .limit(limit)
        )
        count_query = text("SELECT count(*) FROM alert_events WHERE org_id = :org_id")
        params: dict[str, Any] = {"org_id": org_id}

        if since:
            query = query.where(alert_events.c.triggered_at >= since)
        if until:
            query = query.where(alert_events.c.triggered_at <= until)
        if rule_id:
            query = query.where(alert_events.c.rule_id == rule_id)
        if cursor:
            query = query.where(alert_events.c.triggered_at < cursor)

        async with self._engine.connect() as conn:
            result = await conn.execute(query)
            rows = [dict(r) for r in result.mappings().all()]
            count_result = await conn.execute(count_query, params)
            total = count_result.scalar() or 0
            return rows, total
