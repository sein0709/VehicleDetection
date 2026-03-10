"""Role-Based Access Control (RBAC) enforcement.

Implements the 4-role permission matrix from the software design doc.
Roles are hierarchical: Admin > Operator > Analyst > Viewer.
"""

from __future__ import annotations

from enum import StrEnum
from typing import Any

from shared_contracts.enums import UserRole

ROLE_HIERARCHY: dict[UserRole, int] = {
    UserRole.ADMIN: 40,
    UserRole.OPERATOR: 30,
    UserRole.ANALYST: 20,
    UserRole.VIEWER: 10,
}


class Permission(StrEnum):
    # Organization management
    MANAGE_ORGANIZATION = "manage_organization"
    INVITE_USERS = "invite_users"
    REMOVE_USERS = "remove_users"
    ASSIGN_ROLES = "assign_roles"

    # Site & camera management
    CREATE_SITE = "create_site"
    EDIT_SITE = "edit_site"
    DELETE_SITE = "delete_site"
    CREATE_CAMERA = "create_camera"
    EDIT_CAMERA = "edit_camera"
    DELETE_CAMERA = "delete_camera"
    EDIT_ROI = "edit_roi"
    START_STOP_MONITORING = "start_stop_monitoring"

    # Viewing
    VIEW_LIVE_MONITOR = "view_live_monitor"
    VIEW_ANALYTICS = "view_analytics"
    VIEW_ALERT_HISTORY = "view_alert_history"

    # Reporting
    EXPORT_REPORTS = "export_reports"

    # Alerts
    CREATE_ALERT_RULES = "create_alert_rules"
    EDIT_ALERT_RULES = "edit_alert_rules"
    ACKNOWLEDGE_ALERTS = "acknowledge_alerts"

    # Admin-only
    MODEL_ROLLBACK = "model_rollback"
    VIEW_AUDIT_LOGS = "view_audit_logs"
    CONFIGURE_RETENTION = "configure_retention"


_PERMISSION_MATRIX: dict[Permission, set[UserRole]] = {
    Permission.MANAGE_ORGANIZATION: {UserRole.ADMIN},
    Permission.INVITE_USERS: {UserRole.ADMIN},
    Permission.REMOVE_USERS: {UserRole.ADMIN},
    Permission.ASSIGN_ROLES: {UserRole.ADMIN},
    Permission.CREATE_SITE: {UserRole.ADMIN, UserRole.OPERATOR},
    Permission.EDIT_SITE: {UserRole.ADMIN, UserRole.OPERATOR},
    Permission.DELETE_SITE: {UserRole.ADMIN},
    Permission.CREATE_CAMERA: {UserRole.ADMIN, UserRole.OPERATOR},
    Permission.EDIT_CAMERA: {UserRole.ADMIN, UserRole.OPERATOR},
    Permission.DELETE_CAMERA: {UserRole.ADMIN, UserRole.OPERATOR},
    Permission.EDIT_ROI: {UserRole.ADMIN, UserRole.OPERATOR},
    Permission.START_STOP_MONITORING: {UserRole.ADMIN, UserRole.OPERATOR},
    Permission.VIEW_LIVE_MONITOR: {UserRole.ADMIN, UserRole.OPERATOR, UserRole.ANALYST, UserRole.VIEWER},
    Permission.VIEW_ANALYTICS: {UserRole.ADMIN, UserRole.OPERATOR, UserRole.ANALYST, UserRole.VIEWER},
    Permission.VIEW_ALERT_HISTORY: {UserRole.ADMIN, UserRole.OPERATOR, UserRole.ANALYST, UserRole.VIEWER},
    Permission.EXPORT_REPORTS: {UserRole.ADMIN, UserRole.OPERATOR, UserRole.ANALYST},
    Permission.CREATE_ALERT_RULES: {UserRole.ADMIN, UserRole.OPERATOR},
    Permission.EDIT_ALERT_RULES: {UserRole.ADMIN, UserRole.OPERATOR},
    Permission.ACKNOWLEDGE_ALERTS: {UserRole.ADMIN, UserRole.OPERATOR, UserRole.ANALYST},
    Permission.MODEL_ROLLBACK: {UserRole.ADMIN},
    Permission.VIEW_AUDIT_LOGS: {UserRole.ADMIN},
    Permission.CONFIGURE_RETENTION: {UserRole.ADMIN},
}

STEP_UP_REQUIRED: set[Permission] = {
    Permission.DELETE_SITE,
    Permission.ASSIGN_ROLES,
    Permission.REMOVE_USERS,
    Permission.CONFIGURE_RETENTION,
    Permission.MODEL_ROLLBACK,
}


def has_permission(role: UserRole, permission: Permission) -> bool:
    allowed = _PERMISSION_MATRIX.get(permission, set())
    return role in allowed


def has_minimum_role(role: UserRole, minimum: UserRole) -> bool:
    return ROLE_HIERARCHY.get(role, 0) >= ROLE_HIERARCHY.get(minimum, 0)


def requires_step_up(permission: Permission) -> bool:
    return permission in STEP_UP_REQUIRED


def get_permissions_for_role(role: UserRole) -> list[Permission]:
    return [p for p, roles in _PERMISSION_MATRIX.items() if role in roles]
