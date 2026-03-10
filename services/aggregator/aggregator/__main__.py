"""Entrypoint for running the aggregator directly: python -m aggregator."""

import uvicorn

from aggregator.app import create_app
from aggregator.settings import get_settings

if __name__ == "__main__":
    settings = get_settings()
    app = create_app(settings)
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8006,
        log_level="debug" if settings.debug else "info",
    )
