"""Locust load test definitions for GreyEye services.

Run with::

    locust -f tests/loadtest/locustfile.py --host http://localhost:8080

Or headless::

    locust -f tests/loadtest/locustfile.py --host http://localhost:8080 \
        --headless -u 100 -r 10 --run-time 2m

User classes:
- CameraUser: Simulates a camera uploading frames + heartbeats
- AnalystUser: Simulates an analyst querying reporting endpoints
- MixedUser: Weighted combination of both patterns
"""

from __future__ import annotations

import random
import secrets
from datetime import UTC, datetime, timedelta

import jwt
from locust import HttpUser, between, events, tag, task

from tests.loadtest.config import get_settings
from tests.loadtest.frame_gen import frame_metadata_json, generate_frame

_settings = get_settings()

_VEHICLE_CLASSES = list(range(1, 13))


def _make_token(role: str = "operator", user_suffix: str = "") -> str:
    now = datetime.now(tz=UTC)
    user_id = f"locust_{role}_{user_suffix or secrets.token_hex(4)}"
    payload = {
        "sub": user_id,
        "org_id": _settings.org_id,
        "role": role,
        "email": f"{user_id}@greyeye.test",
        "name": f"Locust {role.title()}",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(hours=4)).timestamp()),
        "jti": secrets.token_hex(16),
        "iss": "greyeye-auth",
        "aud": "greyeye-api",
    }
    return jwt.encode(payload, _settings.jwt_secret, algorithm=_settings.jwt_algorithm)


class CameraUser(HttpUser):
    """Simulates a camera feed uploading frames at ~10 FPS."""

    wait_time = between(0.08, 0.12)
    weight = 7

    def on_start(self) -> None:
        self._camera_idx = random.randint(0, 999)
        self._camera_id = f"cam_locust_{self._camera_idx:04d}"
        self._frame_idx = 0
        self._token = _make_token("operator", f"cam_{self._camera_idx}")
        self._headers = {"Authorization": f"Bearer {self._token}"}

    @tag("ingest", "frames")
    @task(10)
    def upload_frame(self) -> None:
        frame_data = generate_frame(self._camera_idx, self._frame_idx)
        metadata = frame_metadata_json(self._camera_id, self._frame_idx)

        with self.client.post(
            "/v1/ingest/frames",
            data={"metadata": metadata},
            files={"frame": ("frame.jpg", frame_data, "image/jpeg")},
            headers=self._headers,
            catch_response=True,
            name="/v1/ingest/frames",
        ) as resp:
            if resp.status_code == 202:
                resp.success()
            elif resp.status_code == 429:
                resp.failure("Backpressure 429")
            else:
                resp.failure(f"Unexpected {resp.status_code}")

        self._frame_idx += 1

    @tag("ingest", "heartbeat")
    @task(1)
    def send_heartbeat(self) -> None:
        with self.client.post(
            "/v1/ingest/heartbeat",
            json={
                "camera_id": self._camera_id,
                "fps_actual": 10.0,
                "status": "online",
                "frame_width": 1920,
                "frame_height": 1080,
            },
            headers={**self._headers, "Content-Type": "application/json"},
            catch_response=True,
            name="/v1/ingest/heartbeat",
        ) as resp:
            if resp.status_code == 200:
                resp.success()
            else:
                resp.failure(f"Heartbeat failed: {resp.status_code}")


class AnalystUser(HttpUser):
    """Simulates an analyst querying reporting and analytics endpoints."""

    wait_time = between(1, 3)
    weight = 3

    def on_start(self) -> None:
        self._token = _make_token("viewer")
        self._headers = {"Authorization": f"Bearer {self._token}"}

    @tag("reporting", "analytics")
    @task(5)
    def query_15m_buckets(self) -> None:
        now = datetime.now(tz=UTC)
        start = (now - timedelta(hours=random.randint(1, 24))).isoformat()
        end = now.isoformat()

        with self.client.get(
            "/v1/analytics/15m",
            params={"start": start, "end": end, "limit": 100},
            headers=self._headers,
            catch_response=True,
            name="/v1/analytics/15m",
        ) as resp:
            if resp.status_code == 200:
                resp.success()
            else:
                resp.failure(f"15m query failed: {resp.status_code}")

    @tag("reporting", "kpi")
    @task(3)
    def query_kpi(self) -> None:
        now = datetime.now(tz=UTC)
        start = (now - timedelta(hours=1)).isoformat()
        end = now.isoformat()

        with self.client.get(
            "/v1/analytics/kpi",
            params={"start": start, "end": end},
            headers=self._headers,
            catch_response=True,
            name="/v1/analytics/kpi",
        ) as resp:
            if resp.status_code == 200:
                resp.success()
            else:
                resp.failure(f"KPI query failed: {resp.status_code}")

    @tag("reporting", "live")
    @task(2)
    def query_live_kpi(self) -> None:
        camera_id = f"cam_locust_{random.randint(0, 9):04d}"
        with self.client.get(
            "/v1/analytics/live",
            params={"camera_id": camera_id},
            headers=self._headers,
            catch_response=True,
            name="/v1/analytics/live",
        ) as resp:
            if resp.status_code == 200:
                resp.success()
            else:
                resp.failure(f"Live KPI failed: {resp.status_code}")

    @tag("health")
    @task(1)
    def health_check(self) -> None:
        self.client.get("/healthz", name="/healthz")
