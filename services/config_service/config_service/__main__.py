"""Run the Config Service with uvicorn."""

import uvicorn

from config_service.app import create_app

app = create_app()

if __name__ == "__main__":
    uvicorn.run("config_service.__main__:app", host="0.0.0.0", port=8002, reload=True)
