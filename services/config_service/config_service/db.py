"""Supabase client wrapper for config service database operations.

Provides typed methods for CRUD on sites, cameras, ROI presets, counting
lines, and config versions.  The Supabase Python SDK is synchronous, so
methods are ``async def`` only for interface consistency with the FastAPI
route layer — no actual I/O is awaited inside.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import Any
from uuid import UUID, uuid4

from config_service.settings import Settings
from supabase import Client, create_client

logger = logging.getLogger(__name__)


class ConfigDB:
    """Thin wrapper around the Supabase SDK for config-related tables."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._client: Client = create_client(
            settings.supabase_url,
            settings.supabase_service_role_key or settings.supabase_anon_key,
        )

    def _table(self, name: str):
        return self._client.table(name)

    def _now_iso(self) -> str:
        return datetime.now(tz=UTC).isoformat()

    # ── Sites ────────────────────────────────────────────────────────────────

    async def create_site(
        self,
        *,
        org_id: UUID,
        name: str,
        address: str | None,
        latitude: float | None,
        longitude: float | None,
        geofence: dict[str, Any] | None,
        timezone: str,
        created_by: UUID,
    ) -> dict[str, Any]:
        row: dict[str, Any] = {
            "org_id": str(org_id),
            "name": name,
            "timezone": timezone,
            "created_by": str(created_by),
        }
        if address is not None:
            row["address"] = address
        if latitude is not None and longitude is not None:
            row["location"] = f"POINT({longitude} {latitude})"
        if geofence is not None:
            row["geofence"] = geofence

        result = self._table("sites").insert(row).execute()
        site = result.data[0]

        self._create_config_version_sync(
            org_id=org_id,
            entity_type="site",
            entity_id=UUID(site["id"]),
            version_number=1,
            snapshot=site,
            created_by=created_by,
        )
        return site

    async def get_site(self, site_id: UUID, org_id: UUID) -> dict[str, Any] | None:
        result = (
            self._table("sites")
            .select("*")
            .eq("id", str(site_id))
            .eq("org_id", str(org_id))
            .maybe_single()
            .execute()
        )
        return result.data if result else None

    async def list_sites(
        self,
        org_id: UUID,
        *,
        status: str | None = None,
        limit: int = 20,
        cursor: str | None = None,
    ) -> tuple[list[dict[str, Any]], int]:
        query = (
            self._table("sites")
            .select("*", count="exact")
            .eq("org_id", str(org_id))
            .order("created_at", desc=True)
            .limit(limit)
        )
        if status:
            query = query.eq("status", status)
        if cursor:
            query = query.lt("created_at", cursor)

        result = query.execute()
        return result.data, result.count or 0

    async def update_site(
        self,
        site_id: UUID,
        org_id: UUID,
        *,
        updates: dict[str, Any],
        updated_by: UUID,
    ) -> dict[str, Any] | None:
        updates["updated_at"] = self._now_iso()

        result = (
            self._table("sites")
            .update(updates)
            .eq("id", str(site_id))
            .eq("org_id", str(org_id))
            .execute()
        )
        if not result.data:
            return None

        site = result.data[0]

        current_version = site.get("active_config_version", 1)
        new_version = current_version + 1
        self._table("sites").update({"active_config_version": new_version}).eq(
            "id", str(site_id)
        ).execute()
        site["active_config_version"] = new_version

        self._create_config_version_sync(
            org_id=org_id,
            entity_type="site",
            entity_id=site_id,
            version_number=new_version,
            snapshot=site,
            created_by=updated_by,
        )
        return site

    async def archive_site(self, site_id: UUID, org_id: UUID) -> bool:
        result = (
            self._table("sites")
            .update({"status": "archived", "updated_at": self._now_iso()})
            .eq("id", str(site_id))
            .eq("org_id", str(org_id))
            .execute()
        )
        return bool(result.data)

    # ── Cameras ──────────────────────────────────────────────────────────────

    async def create_camera(
        self,
        *,
        site_id: UUID,
        org_id: UUID,
        name: str,
        source_type: str,
        rtsp_url: str | None = None,
        settings: dict[str, Any] | None = None,
        created_by: UUID | None = None,
    ) -> dict[str, Any]:
        row: dict[str, Any] = {
            "site_id": str(site_id),
            "org_id": str(org_id),
            "name": name,
            "source_type": source_type,
        }
        if rtsp_url is not None:
            row["rtsp_url"] = rtsp_url
        if settings is not None:
            row["settings"] = settings

        result = self._table("cameras").insert(row).execute()
        camera = result.data[0]

        self._create_config_version_sync(
            org_id=org_id,
            entity_type="camera",
            entity_id=UUID(camera["id"]),
            version_number=1,
            snapshot=camera,
            created_by=created_by,
        )
        return camera

    async def get_camera(self, camera_id: UUID, org_id: UUID) -> dict[str, Any] | None:
        result = (
            self._table("cameras")
            .select("*")
            .eq("id", str(camera_id))
            .eq("org_id", str(org_id))
            .maybe_single()
            .execute()
        )
        return result.data if result else None

    async def list_cameras(
        self,
        org_id: UUID,
        *,
        site_id: UUID | None = None,
        status: str | None = None,
        limit: int = 20,
        cursor: str | None = None,
    ) -> tuple[list[dict[str, Any]], int]:
        query = (
            self._table("cameras")
            .select("*", count="exact")
            .eq("org_id", str(org_id))
            .order("created_at", desc=True)
            .limit(limit)
        )
        if site_id:
            query = query.eq("site_id", str(site_id))
        if status:
            query = query.eq("status", status)
        if cursor:
            query = query.lt("created_at", cursor)

        result = query.execute()
        return result.data, result.count or 0

    async def update_camera(
        self,
        camera_id: UUID,
        org_id: UUID,
        *,
        updates: dict[str, Any],
        updated_by: UUID | None = None,
    ) -> dict[str, Any] | None:
        updates["updated_at"] = self._now_iso()

        result = (
            self._table("cameras")
            .update(updates)
            .eq("id", str(camera_id))
            .eq("org_id", str(org_id))
            .execute()
        )
        if not result.data:
            return None

        camera = result.data[0]
        current_version = camera.get("active_config_version", 1)
        new_version = current_version + 1
        self._table("cameras").update({"active_config_version": new_version}).eq(
            "id", str(camera_id)
        ).execute()
        camera["active_config_version"] = new_version

        self._create_config_version_sync(
            org_id=org_id,
            entity_type="camera",
            entity_id=camera_id,
            version_number=new_version,
            snapshot=camera,
            created_by=updated_by,
        )
        return camera

    async def archive_camera(self, camera_id: UUID, org_id: UUID) -> bool:
        result = (
            self._table("cameras")
            .update({"status": "archived", "updated_at": self._now_iso()})
            .eq("id", str(camera_id))
            .eq("org_id", str(org_id))
            .execute()
        )
        return bool(result.data)

    async def update_camera_status(
        self,
        camera_id: str,
        *,
        status: str,
        last_seen_at: str | None = None,
    ) -> None:
        updates: dict[str, Any] = {"status": status}
        if last_seen_at:
            updates["last_seen_at"] = last_seen_at
        self._table("cameras").update(updates).eq("id", camera_id).execute()

    # ── ROI Presets ──────────────────────────────────────────────────────────

    async def create_roi_preset(
        self,
        *,
        camera_id: UUID,
        org_id: UUID,
        name: str,
        roi_polygon: dict[str, Any],
        lane_polylines: list[dict[str, Any]] | None = None,
        counting_lines: list[dict[str, Any]] | None = None,
        created_by: UUID,
    ) -> dict[str, Any]:
        row = {
            "camera_id": str(camera_id),
            "org_id": str(org_id),
            "name": name,
            "roi_polygon": roi_polygon,
            "lane_polylines": lane_polylines or [],
            "created_by": str(created_by),
        }
        result = self._table("roi_presets").insert(row).execute()
        preset = result.data[0]
        preset_id = UUID(preset["id"])

        if counting_lines:
            for idx, line in enumerate(counting_lines):
                self._table("counting_lines").insert(
                    {
                        "preset_id": str(preset_id),
                        "camera_id": str(camera_id),
                        "org_id": str(org_id),
                        "name": line["name"],
                        "start_point": line["start"],
                        "end_point": line["end"],
                        "direction": line["direction"],
                        "direction_vector": line["direction_vector"],
                        "sort_order": idx,
                    }
                ).execute()

        lines = self._get_counting_lines_sync(preset_id)
        preset["counting_lines"] = lines

        self._create_config_version_sync(
            org_id=org_id,
            entity_type="roi_preset",
            entity_id=preset_id,
            version_number=1,
            snapshot=preset,
            created_by=created_by,
        )
        return preset

    async def get_roi_preset(self, preset_id: UUID, org_id: UUID) -> dict[str, Any] | None:
        result = (
            self._table("roi_presets")
            .select("*")
            .eq("id", str(preset_id))
            .eq("org_id", str(org_id))
            .maybe_single()
            .execute()
        )
        if not result or not result.data:
            return None
        preset = result.data
        preset["counting_lines"] = self._get_counting_lines_sync(preset_id)
        return preset

    async def list_roi_presets(self, camera_id: UUID, org_id: UUID) -> list[dict[str, Any]]:
        result = (
            self._table("roi_presets")
            .select("*")
            .eq("camera_id", str(camera_id))
            .eq("org_id", str(org_id))
            .order("created_at", desc=True)
            .execute()
        )
        presets = result.data
        for preset in presets:
            preset["counting_lines"] = self._get_counting_lines_sync(UUID(preset["id"]))
        return presets

    async def update_roi_preset(
        self,
        preset_id: UUID,
        org_id: UUID,
        *,
        name: str | None = None,
        roi_polygon: dict[str, Any] | None = None,
        lane_polylines: list[dict[str, Any]] | None = None,
        counting_lines: list[dict[str, Any]] | None = None,
        updated_by: UUID,
    ) -> dict[str, Any] | None:
        existing = await self.get_roi_preset(preset_id, org_id)
        if not existing:
            return None

        updates: dict[str, Any] = {}
        if name is not None:
            updates["name"] = name
        if roi_polygon is not None:
            updates["roi_polygon"] = roi_polygon
        if lane_polylines is not None:
            updates["lane_polylines"] = lane_polylines

        new_version = existing.get("version", 1) + 1
        updates["version"] = new_version

        self._table("roi_presets").update(updates).eq("id", str(preset_id)).execute()

        if counting_lines is not None:
            camera_id = existing["camera_id"]
            self._table("counting_lines").delete().eq("preset_id", str(preset_id)).execute()
            for idx, line in enumerate(counting_lines):
                self._table("counting_lines").insert(
                    {
                        "preset_id": str(preset_id),
                        "camera_id": camera_id,
                        "org_id": str(org_id),
                        "name": line["name"],
                        "start_point": line["start"],
                        "end_point": line["end"],
                        "direction": line["direction"],
                        "direction_vector": line["direction_vector"],
                        "sort_order": idx,
                    }
                ).execute()

        preset = await self.get_roi_preset(preset_id, org_id)
        if preset:
            self._create_config_version_sync(
                org_id=org_id,
                entity_type="roi_preset",
                entity_id=preset_id,
                version_number=new_version,
                snapshot=preset,
                created_by=updated_by,
            )
        return preset

    async def activate_roi_preset(self, preset_id: UUID, org_id: UUID) -> dict[str, Any] | None:
        preset = await self.get_roi_preset(preset_id, org_id)
        if not preset:
            return None

        camera_id = preset["camera_id"]

        self._table("roi_presets").update({"is_active": False}).eq("camera_id", camera_id).eq(
            "org_id", str(org_id)
        ).execute()

        self._table("roi_presets").update({"is_active": True}).eq("id", str(preset_id)).execute()

        preset["is_active"] = True
        return preset

    async def delete_roi_preset(self, preset_id: UUID, org_id: UUID) -> bool:
        self._table("counting_lines").delete().eq("preset_id", str(preset_id)).execute()
        result = (
            self._table("roi_presets")
            .delete()
            .eq("id", str(preset_id))
            .eq("org_id", str(org_id))
            .execute()
        )
        return bool(result.data)

    def _get_counting_lines_sync(self, preset_id: UUID) -> list[dict[str, Any]]:
        result = (
            self._table("counting_lines")
            .select("*")
            .eq("preset_id", str(preset_id))
            .order("sort_order")
            .execute()
        )
        return result.data

    # ── Config Versions ──────────────────────────────────────────────────────

    def _create_config_version_sync(
        self,
        *,
        org_id: UUID,
        entity_type: str,
        entity_id: UUID,
        version_number: int,
        snapshot: dict[str, Any],
        created_by: UUID | None,
        rollback_from: UUID | None = None,
    ) -> dict[str, Any]:
        """Create a new config version row (sync — used internally)."""
        self._table("config_versions").update({"is_active": False}).eq(
            "entity_type", entity_type
        ).eq("entity_id", str(entity_id)).execute()

        row: dict[str, Any] = {
            "org_id": str(org_id),
            "entity_type": entity_type,
            "entity_id": str(entity_id),
            "version_number": version_number,
            "config_snapshot": snapshot,
            "is_active": True,
        }
        if created_by:
            row["created_by"] = str(created_by)
        if rollback_from:
            row["rollback_from"] = str(rollback_from)

        result = self._table("config_versions").insert(row).execute()
        return result.data[0]

    async def create_config_version(
        self,
        *,
        org_id: UUID,
        entity_type: str,
        entity_id: UUID,
        version_number: int,
        snapshot: dict[str, Any],
        created_by: UUID | None,
        rollback_from: UUID | None = None,
    ) -> dict[str, Any]:
        """Async facade for route-layer callers."""
        return self._create_config_version_sync(
            org_id=org_id,
            entity_type=entity_type,
            entity_id=entity_id,
            version_number=version_number,
            snapshot=snapshot,
            created_by=created_by,
            rollback_from=rollback_from,
        )

    async def list_config_versions(
        self, entity_type: str, entity_id: UUID, org_id: UUID
    ) -> list[dict[str, Any]]:
        result = (
            self._table("config_versions")
            .select("*")
            .eq("entity_type", entity_type)
            .eq("entity_id", str(entity_id))
            .eq("org_id", str(org_id))
            .order("version_number", desc=True)
            .execute()
        )
        return result.data

    async def get_config_version(self, version_id: UUID, org_id: UUID) -> dict[str, Any] | None:
        result = (
            self._table("config_versions")
            .select("*")
            .eq("id", str(version_id))
            .eq("org_id", str(org_id))
            .maybe_single()
            .execute()
        )
        return result.data if result else None

    def rollback_entity_version(self, entity_type: str, entity_id: UUID, new_version: int) -> None:
        """Update the active version number on the entity table after rollback."""
        if entity_type == "site":
            self._table("sites").update({"active_config_version": new_version}).eq(
                "id", str(entity_id)
            ).execute()
        elif entity_type == "camera":
            self._table("cameras").update({"active_config_version": new_version}).eq(
                "id", str(entity_id)
            ).execute()
        elif entity_type == "roi_preset":
            self._table("roi_presets").update({"version": new_version}).eq(
                "id", str(entity_id)
            ).execute()

    # ── Audit Logging ────────────────────────────────────────────────────────

    async def write_audit_log(
        self,
        *,
        org_id: UUID,
        user_id: UUID | None,
        action: str,
        entity_type: str,
        entity_id: UUID | None = None,
        old_value: dict[str, Any] | None = None,
        new_value: dict[str, Any] | None = None,
        ip_address: str | None = None,
        user_agent: str | None = None,
    ) -> None:
        row: dict[str, Any] = {
            "id": str(uuid4()),
            "org_id": str(org_id),
            "action": action,
            "entity_type": entity_type,
        }
        if user_id is not None:
            row["user_id"] = str(user_id)
        if entity_id is not None:
            row["entity_id"] = str(entity_id)
        if old_value is not None:
            row["old_value"] = old_value
        if new_value is not None:
            row["new_value"] = new_value
        if ip_address is not None:
            row["ip_address"] = ip_address
        if user_agent is not None:
            row["user_agent"] = user_agent

        try:
            self._table("audit_logs").insert(row).execute()
        except Exception:
            logger.exception("Failed to write audit log: %s", action)
