"""Run the Notification Service with uvicorn."""

import uvicorn

from notification_service.app import create_app

app = create_app()

if __name__ == "__main__":
    uvicorn.run("notification_service.__main__:app", host="0.0.0.0", port=8007, reload=True)
