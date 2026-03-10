"""Tests for RBAC permission matrix and role hierarchy."""

from __future__ import annotations

import pytest

from auth_service.rbac import (
    Permission,
    STEP_UP_REQUIRED,
    get_permissions_for_role,
    has_minimum_role,
    has_permission,
    requires_step_up,
)
from shared_contracts.enums import UserRole


class TestPermissionMatrix:
    """Verify the permission matrix matches the design doc exactly."""

    @pytest.mark.parametrize("perm", [
        Permission.MANAGE_ORGANIZATION,
        Permission.INVITE_USERS,
        Permission.REMOVE_USERS,
        Permission.ASSIGN_ROLES,
        Permission.MODEL_ROLLBACK,
        Permission.VIEW_AUDIT_LOGS,
        Permission.CONFIGURE_RETENTION,
    ])
    def test_admin_only_permissions(self, perm: Permission):
        assert has_permission(UserRole.ADMIN, perm) is True
        assert has_permission(UserRole.OPERATOR, perm) is False
        assert has_permission(UserRole.ANALYST, perm) is False
        assert has_permission(UserRole.VIEWER, perm) is False

    @pytest.mark.parametrize("perm", [
        Permission.CREATE_SITE,
        Permission.EDIT_SITE,
        Permission.CREATE_CAMERA,
        Permission.EDIT_CAMERA,
        Permission.DELETE_CAMERA,
        Permission.EDIT_ROI,
        Permission.START_STOP_MONITORING,
        Permission.CREATE_ALERT_RULES,
        Permission.EDIT_ALERT_RULES,
    ])
    def test_admin_and_operator_permissions(self, perm: Permission):
        assert has_permission(UserRole.ADMIN, perm) is True
        assert has_permission(UserRole.OPERATOR, perm) is True
        assert has_permission(UserRole.ANALYST, perm) is False
        assert has_permission(UserRole.VIEWER, perm) is False

    @pytest.mark.parametrize("perm", [
        Permission.EXPORT_REPORTS,
        Permission.ACKNOWLEDGE_ALERTS,
    ])
    def test_admin_operator_analyst_permissions(self, perm: Permission):
        assert has_permission(UserRole.ADMIN, perm) is True
        assert has_permission(UserRole.OPERATOR, perm) is True
        assert has_permission(UserRole.ANALYST, perm) is True
        assert has_permission(UserRole.VIEWER, perm) is False

    @pytest.mark.parametrize("perm", [
        Permission.VIEW_LIVE_MONITOR,
        Permission.VIEW_ANALYTICS,
        Permission.VIEW_ALERT_HISTORY,
    ])
    def test_all_roles_view_permissions(self, perm: Permission):
        for role in UserRole:
            assert has_permission(role, perm) is True

    def test_delete_site_admin_only(self):
        assert has_permission(UserRole.ADMIN, Permission.DELETE_SITE) is True
        assert has_permission(UserRole.OPERATOR, Permission.DELETE_SITE) is False


class TestRoleHierarchy:
    def test_admin_has_all_minimum_roles(self):
        for role in UserRole:
            assert has_minimum_role(UserRole.ADMIN, role) is True

    def test_viewer_only_meets_viewer(self):
        assert has_minimum_role(UserRole.VIEWER, UserRole.VIEWER) is True
        assert has_minimum_role(UserRole.VIEWER, UserRole.ANALYST) is False
        assert has_minimum_role(UserRole.VIEWER, UserRole.OPERATOR) is False
        assert has_minimum_role(UserRole.VIEWER, UserRole.ADMIN) is False

    def test_operator_meets_operator_and_below(self):
        assert has_minimum_role(UserRole.OPERATOR, UserRole.OPERATOR) is True
        assert has_minimum_role(UserRole.OPERATOR, UserRole.ANALYST) is True
        assert has_minimum_role(UserRole.OPERATOR, UserRole.VIEWER) is True
        assert has_minimum_role(UserRole.OPERATOR, UserRole.ADMIN) is False

    def test_analyst_meets_analyst_and_below(self):
        assert has_minimum_role(UserRole.ANALYST, UserRole.ANALYST) is True
        assert has_minimum_role(UserRole.ANALYST, UserRole.VIEWER) is True
        assert has_minimum_role(UserRole.ANALYST, UserRole.OPERATOR) is False


class TestStepUpRequirements:
    def test_destructive_actions_require_step_up(self):
        assert requires_step_up(Permission.DELETE_SITE) is True
        assert requires_step_up(Permission.ASSIGN_ROLES) is True
        assert requires_step_up(Permission.REMOVE_USERS) is True
        assert requires_step_up(Permission.CONFIGURE_RETENTION) is True
        assert requires_step_up(Permission.MODEL_ROLLBACK) is True

    def test_normal_actions_do_not_require_step_up(self):
        assert requires_step_up(Permission.VIEW_ANALYTICS) is False
        assert requires_step_up(Permission.CREATE_SITE) is False
        assert requires_step_up(Permission.EXPORT_REPORTS) is False


class TestGetPermissionsForRole:
    def test_admin_has_all_permissions(self):
        perms = get_permissions_for_role(UserRole.ADMIN)
        assert len(perms) == len(Permission)

    def test_viewer_has_limited_permissions(self):
        perms = get_permissions_for_role(UserRole.VIEWER)
        assert Permission.VIEW_LIVE_MONITOR in perms
        assert Permission.VIEW_ANALYTICS in perms
        assert Permission.VIEW_ALERT_HISTORY in perms
        assert Permission.CREATE_SITE not in perms
        assert Permission.MANAGE_ORGANIZATION not in perms
