"""Request and response Pydantic models for the Auth Service API."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field

from shared_contracts.enums import UserRole


# ── Request Models ──────────────────────────────────────────────────────────


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    name: str = Field(min_length=1, max_length=255)
    org_name: str = Field(min_length=1, max_length=255)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)


class RefreshRequest(BaseModel):
    refresh_token: str


class InviteRequest(BaseModel):
    email: EmailStr
    name: str = Field(min_length=1, max_length=255)
    role: UserRole = UserRole.VIEWER


class RoleUpdateRequest(BaseModel):
    role: UserRole


class StepUpRequest(BaseModel):
    password: str = Field(min_length=1)


# ── Response Models ─────────────────────────────────────────────────────────


class UserProfile(BaseModel):
    id: UUID
    email: str
    name: str
    org_id: UUID
    role: UserRole
    is_active: bool = True
    last_login_at: datetime | None = None
    created_at: datetime


class AuthTokens(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int


class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int
    user: UserProfile


class MessageResponse(BaseModel):
    message: str


class InviteResponse(BaseModel):
    message: str
    user_id: UUID
    email: str
    role: UserRole
