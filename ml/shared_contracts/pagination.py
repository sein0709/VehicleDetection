"""Cursor-based pagination models used by all list endpoints."""

from __future__ import annotations

from typing import Generic, TypeVar

from pydantic import BaseModel, Field

T = TypeVar("T")


class PaginationMeta(BaseModel):
    cursor: str | None = None
    has_more: bool = False
    total_count: int | None = None


class PaginatedResponse(BaseModel, Generic[T]):
    """Generic paginated response wrapper.

    Usage::

        PaginatedResponse[SiteResponse](data=[...], pagination=PaginationMeta(...))
    """

    data: list[T]
    pagination: PaginationMeta = Field(default_factory=PaginationMeta)


class PaginationParams(BaseModel):
    """Query parameters accepted by all list endpoints."""

    limit: int = Field(default=20, ge=1, le=100)
    cursor: str | None = None
