"""Run the Reporting API with uvicorn."""

from __future__ import annotations

import uvicorn

from reporting_api.app import create_app

app = create_app()

if __name__ == "__main__":
    uvicorn.run("reporting_api.__main__:app", host="0.0.0.0", port=8005, reload=True)
