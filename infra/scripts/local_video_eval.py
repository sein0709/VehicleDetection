#!/usr/bin/env python3
"""Upload a local video to the GreyEye dev stack for real-data pipeline testing.

This script targets a locally running stack:
    - API gateway on http://127.0.0.1:8080
    - Redis on redis://localhost:6379/0

It validates the parts that are currently externally reachable:
    1. auth/register or login
    2. site + camera creation (unless a camera is supplied)
    3. ingest session creation
    4. frame upload + heartbeat
    5. live inference state presence in Redis
    6. current KPI bucket presence in Redis

Important limitation:
The inference worker in this repo does not automatically load counting-line
config from the config service. That means bucket/count validation will often
remain empty even when frame ingestion succeeds, unless the worker is given
counting lines through custom code or local instrumentation.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import time
from dataclasses import asdict, dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any
from uuid import uuid4

import cv2
import httpx
import redis


@dataclass
class EvaluationSummary:
    api_base_url: str
    video_path: str
    email: str
    site_id: str | None
    camera_id: str
    video_fps: float
    uploaded_frames: int
    uploaded_seconds: float
    session_id: str
    session_frames_uploaded: int | None
    last_queue_position: int | None
    live_state_seen: bool
    live_track_count: int
    live_frame_index: int | None
    live_bucket_seen: bool
    live_bucket_total_count: int | None
    analytics_live_status: int | None
    notes: list[str]


class GreyEyeLocalEvaluator:
    def __init__(self, args: argparse.Namespace) -> None:
        self._args = args
        self._client = httpx.Client(
            base_url=args.api_base_url,
            timeout=args.timeout_seconds,
            follow_redirects=False,
        )
        self._redis = redis.Redis.from_url(args.redis_url, decode_responses=False)
        self._token: str = ""
        self._site_id: str | None = args.site_id
        self._camera_id: str | None = args.camera_id

    def close(self) -> None:
        self._client.close()
        self._redis.close()

    def run(self) -> EvaluationSummary:
        self._check_gateway()
        self._authenticate()
        if self._camera_id is None:
            self._ensure_site_and_camera()

        assert self._camera_id is not None

        video_info = self._probe_video(self._args.video)
        session_id = self._create_session(video_info)
        uploaded_frames, uploaded_seconds, last_queue_position = self._upload_video(
            self._args.video,
            video_info["fps"],
            session_id,
        )
        session_frames_uploaded = self._fetch_session_frames_uploaded(session_id)
        live_state = self._poll_live_state(self._camera_id)
        live_bucket = self._poll_live_bucket(self._camera_id)
        analytics_live_status = self._fetch_live_kpi_status(self._camera_id)

        notes: list[str] = []
        if not live_state:
            notes.append(
                "No live track state observed. If ONNX models are missing, the worker is still on stub backends."
            )
        if not live_bucket:
            notes.append(
                "No live KPI bucket observed. This repo does not currently push counting-line config into the worker automatically."
            )

        return EvaluationSummary(
            api_base_url=self._args.api_base_url,
            video_path=str(self._args.video),
            email=self._args.email,
            site_id=self._site_id,
            camera_id=self._camera_id,
            video_fps=video_info["fps"],
            uploaded_frames=uploaded_frames,
            uploaded_seconds=uploaded_seconds,
            session_id=session_id,
            session_frames_uploaded=session_frames_uploaded,
            last_queue_position=last_queue_position,
            live_state_seen=bool(live_state),
            live_track_count=int(live_state.get("track_count", 0)) if live_state else 0,
            live_frame_index=int(live_state["frame_index"]) if live_state else None,
            live_bucket_seen=bool(live_bucket),
            live_bucket_total_count=(
                int(_parse_json_or_raw(live_bucket.get(b"total_count")) or 0)
                if live_bucket
                else None
            ),
            analytics_live_status=analytics_live_status,
            notes=notes,
        )

    def _check_gateway(self) -> None:
        response = self._client.get("/healthz")
        response.raise_for_status()

    def _authenticate(self) -> None:
        register_payload = {
            "email": self._args.email,
            "password": self._args.password,
            "name": self._args.name,
            "org_name": self._args.org_name,
        }
        response = self._client.post("/v1/auth/register", json=register_payload)
        if response.status_code not in {201, 409}:
            raise RuntimeError(f"Registration failed: {response.status_code} {response.text}")

        login = self._client.post(
            "/v1/auth/login",
            json={"email": self._args.email, "password": self._args.password},
        )
        login.raise_for_status()
        self._token = login.json()["access_token"]

    def _ensure_site_and_camera(self) -> None:
        headers = self._auth_headers
        if self._site_id is None:
            response = self._client.post(
                "/v1/sites",
                headers=headers,
                json={
                    "name": self._args.site_name,
                    "address": self._args.site_address,
                    "timezone": self._args.timezone,
                    "location": {
                        "latitude": self._args.latitude,
                        "longitude": self._args.longitude,
                    },
                },
            )
            response.raise_for_status()
            self._site_id = response.json()["id"]

        response = self._client.post(
            f"/v1/sites/{self._site_id}/cameras",
            headers=headers,
            json={
                "name": self._args.camera_name,
                "source_type": "smartphone",
                "settings": {
                    "target_fps": int(self._args.heartbeat_fps),
                    "resolution": self._args.camera_resolution,
                    "night_mode": False,
                    "classification_mode": "full_12class",
                },
            },
        )
        response.raise_for_status()
        self._camera_id = response.json()["id"]

    def _probe_video(self, video_path: Path) -> dict[str, float | int]:
        cap = cv2.VideoCapture(str(video_path))
        if not cap.isOpened():
            raise RuntimeError(f"Could not open video: {video_path}")

        fps = float(cap.get(cv2.CAP_PROP_FPS) or 0.0)
        if fps <= 0.0:
            fps = float(self._args.default_fps)

        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
        cap.release()

        if self._args.max_frames is not None:
            bounded_frames = min(total_frames, self._args.max_frames) if total_frames else self._args.max_frames
        else:
            bounded_frames = total_frames

        sample_every = self._args.sample_every
        selected_frames = (
            math.ceil(bounded_frames / sample_every)
            if bounded_frames
            else max(1, math.ceil(self._args.default_frame_count / sample_every))
        )

        return {
            "fps": fps,
            "total_frames": total_frames,
            "selected_frames": selected_frames,
        }

    def _create_session(self, video_info: dict[str, float | int]) -> str:
        now = datetime.now(UTC)
        duration_seconds = max(1.0, float(video_info["selected_frames"]) / float(video_info["fps"]))
        response = self._client.post(
            "/v1/ingest/sessions",
            headers=self._auth_headers,
            json={
                "camera_id": self._camera_id,
                "frame_count": int(video_info["selected_frames"]),
                "start_ts": now.isoformat(),
                "end_ts": (now + timedelta(seconds=duration_seconds)).isoformat(),
                "offline_upload": False,
            },
        )
        response.raise_for_status()
        return response.json()["session_id"]

    def _upload_video(
        self,
        video_path: Path,
        fps: float,
        session_id: str,
    ) -> tuple[int, float, int | None]:
        cap = cv2.VideoCapture(str(video_path))
        if not cap.isOpened():
            raise RuntimeError(f"Could not open video for upload: {video_path}")

        sample_every = self._args.sample_every
        max_frames = self._args.max_frames
        uploaded = 0
        last_queue_position: int | None = None
        started_at = time.monotonic()
        frame_index = 0
        last_uploaded_frame: Any | None = None
        last_uploaded_frame_index = 0

        try:
            while True:
                ok, frame = cap.read()
                if not ok:
                    break
                if max_frames is not None and frame_index >= max_frames:
                    break
                if frame_index % sample_every != 0:
                    frame_index += 1
                    continue

                timestamp_utc = datetime.now(UTC).isoformat()
                metadata = {
                    "camera_id": self._camera_id,
                    "frame_index": frame_index,
                    "timestamp_utc": timestamp_utc,
                    "offline_upload": False,
                    "session_id": session_id,
                    "content_type": "image/jpeg",
                }
                jpeg = _encode_jpeg(frame, self._args.jpeg_quality)
                response = self._post_with_retry(
                    "/v1/ingest/frames",
                    headers=self._ingest_headers,
                    data={"metadata": json.dumps(metadata)},
                    files={"frame": ("frame.jpg", jpeg, "image/jpeg")},
                )
                last_queue_position = response.json().get("queue_position")
                uploaded += 1
                last_uploaded_frame = frame
                last_uploaded_frame_index = frame_index

                if uploaded == 1 or uploaded % self._args.heartbeat_every == 0:
                    self._send_heartbeat(frame, frame_index)

                frame_index += 1
        finally:
            cap.release()

        if last_uploaded_frame is not None:
            self._send_heartbeat(last_uploaded_frame, last_uploaded_frame_index)
        elapsed = time.monotonic() - started_at
        return uploaded, elapsed, last_queue_position

    def _send_heartbeat(self, frame: Any, frame_index: int) -> None:
        height, width = frame.shape[:2]
        response = self._post_with_retry(
            "/v1/ingest/heartbeat",
            headers=self._ingest_headers,
            json={
                "camera_id": self._camera_id,
                "fps_actual": self._args.heartbeat_fps,
                "status": "online",
                "frame_width": width,
                "frame_height": height,
                "last_frame_index": frame_index,
            },
        )

    def _fetch_session_frames_uploaded(self, session_id: str) -> int | None:
        response = self._client.get(
            f"/v1/ingest/sessions/{session_id}",
            headers=self._auth_headers,
        )
        response.raise_for_status()
        return response.json().get("frames_uploaded")

    def _poll_live_state(self, camera_id: str) -> dict[str, Any] | None:
        key = f"live:camera:{camera_id}"
        deadline = time.monotonic() + self._args.poll_seconds
        while time.monotonic() < deadline:
            raw = self._redis.get(key)
            if raw:
                try:
                    return json.loads(raw)
                except json.JSONDecodeError:
                    return {"raw": raw.decode(errors="replace")}
            time.sleep(0.5)
        return None

    def _poll_live_bucket(self, camera_id: str) -> dict[bytes, bytes] | None:
        key = f"bucket:current:{camera_id}:latest"
        deadline = time.monotonic() + self._args.poll_seconds
        while time.monotonic() < deadline:
            raw = self._redis.hgetall(key)
            if raw:
                return raw
            time.sleep(0.5)
        return None

    def _fetch_live_kpi_status(self, camera_id: str) -> int | None:
        response = self._client.get(
            "/v1/analytics/live",
            headers=self._auth_headers,
            params={"camera_id": camera_id},
        )
        return response.status_code

    @property
    def _auth_headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self._token}"}

    @property
    def _ingest_headers(self) -> dict[str, str]:
        headers = dict(self._auth_headers)
        if self._camera_id is not None:
            headers["X-Camera-Id"] = self._camera_id
        return headers

    def _post_with_retry(self, path: str, **kwargs: Any) -> httpx.Response:
        attempts = self._args.max_retries + 1
        for attempt in range(attempts):
            response = self._client.post(path, **kwargs)
            if response.status_code != 429:
                response.raise_for_status()
                return response

            if attempt >= self._args.max_retries:
                response.raise_for_status()

            retry_after = response.headers.get("Retry-After")
            try:
                sleep_seconds = float(retry_after) if retry_after is not None else self._args.retry_delay_seconds
            except ValueError:
                sleep_seconds = self._args.retry_delay_seconds
            time.sleep(max(sleep_seconds, self._args.retry_delay_seconds))

        raise RuntimeError(f"Exhausted retries for {path}")


def _encode_jpeg(frame: Any, quality: int) -> bytes:
    ok, encoded = cv2.imencode(
        ".jpg",
        frame,
        [int(cv2.IMWRITE_JPEG_QUALITY), quality],
    )
    if not ok:
        raise RuntimeError("Failed to encode frame as JPEG")
    return encoded.tobytes()


def _parse_json_or_raw(value: bytes | None) -> Any:
    if value is None:
        return None
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        try:
            return value.decode()
        except UnicodeDecodeError:
            return value


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Upload a local video to the GreyEye dev stack for model/inference testing.",
    )
    parser.add_argument("video", type=Path, help="Path to a local video file")
    parser.add_argument("--api-base-url", default="http://127.0.0.1:8080")
    parser.add_argument("--redis-url", default="redis://localhost:6379/0")
    parser.add_argument("--email", default=f"video-eval-{uuid4().hex[:8]}@example.com")
    parser.add_argument("--password", default="strongpassword123")
    parser.add_argument("--name", default="Video Eval User")
    parser.add_argument("--org-name", default="Video Eval Org")
    parser.add_argument("--site-id")
    parser.add_argument("--camera-id")
    parser.add_argument("--site-name", default=f"Video Eval Site {uuid4().hex[:6]}")
    parser.add_argument("--site-address", default="123 Verification Ave")
    parser.add_argument("--camera-name", default=f"Video Eval Camera {uuid4().hex[:6]}")
    parser.add_argument("--timezone", default="Asia/Seoul")
    parser.add_argument("--latitude", type=float, default=37.4979)
    parser.add_argument("--longitude", type=float, default=127.0276)
    parser.add_argument("--camera-resolution", default="1920x1080")
    parser.add_argument("--sample-every", type=int, default=5)
    parser.add_argument("--max-frames", type=int)
    parser.add_argument("--heartbeat-every", type=int, default=10)
    parser.add_argument("--heartbeat-fps", type=float, default=10.0)
    parser.add_argument("--default-fps", type=float, default=10.0)
    parser.add_argument("--default-frame-count", type=int, default=120)
    parser.add_argument("--jpeg-quality", type=int, default=90)
    parser.add_argument("--poll-seconds", type=float, default=8.0)
    parser.add_argument("--timeout-seconds", type=float, default=30.0)
    parser.add_argument("--max-retries", type=int, default=3)
    parser.add_argument("--retry-delay-seconds", type=float, default=0.25)
    parser.add_argument("--output-json", type=Path)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if not args.video.exists():
        print(f"Video file not found: {args.video}", file=sys.stderr)
        return 2

    evaluator = GreyEyeLocalEvaluator(args)
    try:
        summary = evaluator.run()
    finally:
        evaluator.close()

    payload = asdict(summary)
    rendered = json.dumps(payload, indent=2)
    print(rendered)
    if args.output_json is not None:
        args.output_json.write_text(rendered + "\n", encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
