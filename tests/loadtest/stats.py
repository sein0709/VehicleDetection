"""Statistics collection and reporting for load test results."""

from __future__ import annotations

import json
import math
import time
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class LatencyBucket:
    """Collects latency samples and computes percentile statistics."""

    name: str
    samples: list[float] = field(default_factory=list)

    def record(self, latency_ms: float) -> None:
        self.samples.append(latency_ms)

    @property
    def count(self) -> int:
        return len(self.samples)

    def percentile(self, p: float) -> float:
        if not self.samples:
            return 0.0
        s = sorted(self.samples)
        k = (len(s) - 1) * (p / 100.0)
        f = math.floor(k)
        c = math.ceil(k)
        if f == c:
            return s[int(k)]
        return s[f] * (c - k) + s[c] * (k - f)

    def summary(self) -> dict:
        if not self.samples:
            return {"name": self.name, "count": 0}
        s = sorted(self.samples)
        return {
            "name": self.name,
            "count": len(s),
            "mean_ms": round(sum(s) / len(s), 2),
            "median_ms": round(self.percentile(50), 2),
            "p95_ms": round(self.percentile(95), 2),
            "p99_ms": round(self.percentile(99), 2),
            "min_ms": round(s[0], 2),
            "max_ms": round(s[-1], 2),
        }


@dataclass
class LoadTestResult:
    """Aggregate result for a load test scenario."""

    scenario: str
    num_cameras: int
    fps_per_camera: int
    duration_seconds: float
    start_time: float = field(default_factory=time.time)
    end_time: float = 0.0

    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0
    backpressure_429s: int = 0
    rate_limited_429s: int = 0
    server_errors_5xx: int = 0

    latencies: dict[str, LatencyBucket] = field(default_factory=dict)
    nfr_checks: dict[str, bool] = field(default_factory=dict)
    notes: list[str] = field(default_factory=list)

    def get_bucket(self, name: str) -> LatencyBucket:
        if name not in self.latencies:
            self.latencies[name] = LatencyBucket(name=name)
        return self.latencies[name]

    def finish(self) -> None:
        self.end_time = time.time()

    @property
    def elapsed_seconds(self) -> float:
        end = self.end_time or time.time()
        return end - self.start_time

    @property
    def effective_rps(self) -> float:
        elapsed = self.elapsed_seconds
        if elapsed <= 0:
            return 0.0
        return self.total_requests / elapsed

    @property
    def success_rate(self) -> float:
        if self.total_requests == 0:
            return 0.0
        return self.successful_requests / self.total_requests

    @property
    def error_rate(self) -> float:
        return 1.0 - self.success_rate

    def to_dict(self) -> dict:
        return {
            "scenario": self.scenario,
            "num_cameras": self.num_cameras,
            "fps_per_camera": self.fps_per_camera,
            "duration_seconds": round(self.elapsed_seconds, 2),
            "total_requests": self.total_requests,
            "successful_requests": self.successful_requests,
            "failed_requests": self.failed_requests,
            "backpressure_429s": self.backpressure_429s,
            "rate_limited_429s": self.rate_limited_429s,
            "server_errors_5xx": self.server_errors_5xx,
            "effective_rps": round(self.effective_rps, 2),
            "success_rate": round(self.success_rate, 4),
            "latencies": {k: v.summary() for k, v in self.latencies.items()},
            "nfr_checks": self.nfr_checks,
            "notes": self.notes,
        }

    def save(self, output_dir: str | Path) -> Path:
        out = Path(output_dir)
        out.mkdir(parents=True, exist_ok=True)
        filename = f"{self.scenario}_{int(self.start_time)}.json"
        path = out / filename
        path.write_text(json.dumps(self.to_dict(), indent=2), encoding="utf-8")
        return path


def print_result(result: LoadTestResult) -> None:
    """Print a human-readable summary to stdout."""
    d = result.to_dict()
    print(f"\n{'='*72}")
    print(f"  LOAD TEST: {d['scenario']}")
    print(f"{'='*72}")
    print(f"  Cameras: {d['num_cameras']}  |  FPS/cam: {d['fps_per_camera']}")
    print(f"  Duration: {d['duration_seconds']:.1f}s  |  RPS: {d['effective_rps']:.1f}")
    print(f"  Requests: {d['total_requests']}  |  Success: {d['success_rate']*100:.1f}%")
    print(f"  429 (backpressure): {d['backpressure_429s']}")
    print(f"  429 (rate-limit):   {d['rate_limited_429s']}")
    print(f"  5xx errors:         {d['server_errors_5xx']}")

    for name, stats in d["latencies"].items():
        if stats["count"] == 0:
            continue
        print(f"\n  {name}:")
        print(f"    mean={stats['mean_ms']:.1f}ms  p50={stats['median_ms']:.1f}ms"
              f"  p95={stats['p95_ms']:.1f}ms  p99={stats['p99_ms']:.1f}ms")

    if d["nfr_checks"]:
        print(f"\n  NFR Checks:")
        for check, passed in d["nfr_checks"].items():
            status = "PASS" if passed else "FAIL"
            print(f"    [{status}] {check}")

    if d["notes"]:
        print(f"\n  Notes:")
        for note in d["notes"]:
            print(f"    - {note}")

    print(f"{'='*72}\n")
