"""Environment-file helpers shared across local services."""

from __future__ import annotations

from pathlib import Path


def repo_env_file() -> str:
    """Return the repository-level .env path when present."""
    current = Path(__file__).resolve()
    for parent in current.parents:
        candidate = parent / ".env"
        if candidate.exists():
            return str(candidate)
    return ".env"
