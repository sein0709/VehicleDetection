"""Entrypoint for running the auth service directly: python -m auth_service."""

import uvicorn

from auth_service.app import create_app
from auth_service.settings import get_settings

if __name__ == "__main__":
    settings = get_settings()
    app = create_app(settings)
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8001,
        log_level="debug" if settings.debug else "info",
    )
