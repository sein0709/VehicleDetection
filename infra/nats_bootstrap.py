#!/usr/bin/env python3
"""Bootstrap NATS JetStream streams and consumers for GreyEye.

Creates all streams and durable consumers defined in
``shared_contracts.nats_streams``.  Idempotent — safe to run repeatedly.

Usage::

    # Default: connect to localhost:4222, 1 replica
    python -m infra.nats_bootstrap

    # Production: 3 replicas, custom URL
    python -m infra.nats_bootstrap --url nats://nats.prod:4222 --replicas 3

    # Dry-run: print what would be created without connecting
    python -m infra.nats_bootstrap --dry-run

    # Verify: check existing streams/consumers match expected config
    python -m infra.nats_bootstrap --verify
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import sys

logger = logging.getLogger("nats_bootstrap")


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Bootstrap NATS JetStream streams and consumers for GreyEye.",
    )
    p.add_argument(
        "--url",
        default="nats://localhost:4222",
        help="NATS server URL (default: nats://localhost:4222)",
    )
    p.add_argument(
        "--replicas",
        type=int,
        default=1,
        help="Number of stream replicas (default: 1 for dev, use 3 for production)",
    )
    p.add_argument(
        "--max-bytes",
        type=int,
        default=None,
        help="Optional max bytes per stream (overrides per-stream defaults)",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print stream/consumer definitions without creating them",
    )
    p.add_argument(
        "--verify",
        action="store_true",
        help="Verify existing streams/consumers match expected configuration",
    )
    p.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable debug logging",
    )
    return p


def _print_definitions() -> None:
    """Print all stream and consumer definitions for dry-run mode."""
    from shared_contracts.nats_streams import CONSUMER_DEFS, STREAM_DEFS

    print("\n=== Streams ===\n")
    for sdef in STREAM_DEFS:
        print(f"  {sdef.name}")
        print(f"    subjects:    {sdef.subjects}")
        print(f"    max_age:     {sdef.max_age_seconds}s ({sdef.max_age_seconds / 3600:.0f}h)")
        if sdef.max_msgs:
            print(f"    max_msgs:    {sdef.max_msgs:,}")
        if sdef.max_bytes:
            print(f"    max_bytes:   {sdef.max_bytes:,}")
        if sdef.max_msg_size:
            print(f"    max_msg_sz:  {sdef.max_msg_size:,}")
        if sdef.description:
            print(f"    description: {sdef.description}")
        print()

    print("=== Consumers ===\n")
    for cdef in CONSUMER_DEFS:
        print(f"  {cdef.durable_name}  (on {cdef.stream_name})")
        print(f"    filter:      {cdef.filter_subject}")
        print(f"    policy:      {cdef.deliver_policy}")
        print(f"    ack_wait:    {cdef.ack_wait_seconds}s")
        print(f"    max_deliver: {cdef.max_deliver}")
        if cdef.description:
            print(f"    description: {cdef.description}")
        print()


async def _verify(url: str) -> bool:
    """Verify that existing streams/consumers match expected definitions."""
    import nats

    from shared_contracts.nats_streams import CONSUMER_DEFS, STREAM_DEFS

    nc = await nats.connect(url)
    js = nc.jetstream()
    all_ok = True

    print("\n=== Stream Verification ===\n")
    for sdef in STREAM_DEFS:
        try:
            info = await js.stream_info(sdef.name)
            subjects = list(info.config.subjects or [])
            if subjects == sdef.subjects:
                print(f"  [OK] {sdef.name} — subjects match, {info.state.messages} messages")
            else:
                print(f"  [MISMATCH] {sdef.name} — expected {sdef.subjects}, got {subjects}")
                all_ok = False
        except Exception:
            print(f"  [MISSING] {sdef.name}")
            all_ok = False

    print("\n=== Consumer Verification ===\n")
    for cdef in CONSUMER_DEFS:
        try:
            info = await js.consumer_info(cdef.stream_name, cdef.durable_name)
            print(
                f"  [OK] {cdef.durable_name} on {cdef.stream_name}"
                f" — {info.num_pending} pending, {info.num_ack_pending} ack-pending"
            )
        except Exception:
            print(f"  [MISSING] {cdef.durable_name} on {cdef.stream_name}")
            all_ok = False

    await nc.close()
    print()
    return all_ok


async def _bootstrap(url: str, replicas: int, max_bytes: int | None) -> None:
    """Connect to NATS and create all streams + consumers."""
    import nats

    from shared_contracts.nats_streams import ensure_all

    logger.info("Connecting to NATS at %s ...", url)
    nc = await nats.connect(url, connect_timeout=10)
    js = nc.jetstream()

    logger.info("Creating streams (replicas=%d) ...", replicas)
    stream_names, consumer_names = await ensure_all(
        js,
        replicas=replicas,
        max_bytes=max_bytes,
    )

    print(f"\nCreated/updated {len(stream_names)} streams:")
    for name in stream_names:
        print(f"  - {name}")

    print(f"\nCreated/updated {len(consumer_names)} consumers:")
    for name in consumer_names:
        print(f"  - {name}")

    await nc.close()
    print("\nDone.")


def main() -> None:
    parser = _build_parser()
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S",
    )

    if args.dry_run:
        _print_definitions()
        return

    if args.verify:
        ok = asyncio.run(_verify(args.url))
        sys.exit(0 if ok else 1)

    asyncio.run(_bootstrap(args.url, args.replicas, args.max_bytes))


if __name__ == "__main__":
    main()
