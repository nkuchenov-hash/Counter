#!/usr/bin/env python3
"""Small server-only bridge between PocketBase JSVM and Xiaomi Health cloud.

The script never prints or logs Xiaomi credentials. Login state contains only the
QR/browser URLs needed to complete the one-time authorization. Sync writes only
normalized sleep intervals to stdout.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any

from mi_fitness import MiHealthClient, XiaomiAuth


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _atomic_json(path: Path, payload: dict[str, Any], mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    os.chmod(tmp, mode)
    os.replace(tmp, path)
    os.chmod(path, mode)


def _epoch_seconds(raw: Any) -> float | None:
    try:
        value = float(raw or 0)
    except (TypeError, ValueError):
        return None
    if value <= 0:
        return None
    if value >= 1_000_000_000_000:
        value /= 1000.0
    if value >= 10_000_000_000:
        value /= 1000.0
    return value


def _iso_from_epoch(raw: Any) -> str | None:
    value = _epoch_seconds(raw)
    if value is None:
        return None
    try:
        return datetime.fromtimestamp(value, tz=timezone.utc).isoformat().replace("+00:00", "Z")
    except (OverflowError, OSError, ValueError):
        return None


def _safe_session(start_raw: Any, end_raw: Any, duration_hint: Any = 0) -> dict[str, Any] | None:
    start_s = _epoch_seconds(start_raw)
    end_s = _epoch_seconds(end_raw)
    if start_s is None or end_s is None or end_s <= start_s:
        return None
    now_s = datetime.now(timezone.utc).timestamp()
    if end_s > now_s + 300:
        return None
    elapsed = end_s - start_s
    if elapsed < 20 * 60 or elapsed > 36 * 3600:
        return None
    start = _iso_from_epoch(start_raw)
    end = _iso_from_epoch(end_raw)
    if not start or not end:
        return None
    duration_min = 0
    try:
        duration_min = int(duration_hint or round(elapsed / 60))
    except (TypeError, ValueError):
        duration_min = round(elapsed / 60)
    external_id = f"xiaomi:{int(start_s)}:{int(end_s)}"
    return {
        "external_id": external_id,
        "start": start,
        "end": end,
        "duration_minutes": duration_min,
    }


async def _login(args: argparse.Namespace) -> int:
    token_path = Path(args.token_path)
    state_path = Path(args.state_path)
    _atomic_json(state_path, {"status": "starting", "updated_at": _utc_now()})

    # Keep each Xiaomi QR/browser-login session alive long enough for a human to
    # complete account login. Regenerate only after the SDK reports that attempt
    # expired; rotating every ~45 seconds invalidated browser logins in flight.
    total_wait = max(540.0, float(args.max_wait))
    loop = asyncio.get_running_loop()
    deadline = loop.time() + total_wait
    generation = 0
    last_error_class = "TimeoutError"

    while loop.time() < deadline:
        generation += 1
        remaining = max(1.0, deadline - loop.time())
        attempt_wait = min(240.0, remaining)
        try:
            async with XiaomiAuth() as auth:
                async def on_qr(qr_image_url: str, login_url: str) -> None:
                    _atomic_json(
                        state_path,
                        {
                            "status": "awaiting_scan",
                            "qr_image_url": str(qr_image_url or ""),
                            "login_url": str(login_url or ""),
                            "generation": generation,
                            "updated_at": _utc_now(),
                        },
                    )

                await auth.login_qr(
                    qr_callback=on_qr,
                    poll_interval=2.0,
                    max_wait=attempt_wait,
                )
                tmp_token = token_path.with_name(token_path.name + ".tmp")
                auth.save_token(tmp_token)
                os.chmod(tmp_token, 0o600)
                os.replace(tmp_token, token_path)
                os.chmod(token_path, 0o600)
            _atomic_json(state_path, {"status": "connected", "updated_at": _utc_now()})
            return 0
        except Exception as exc:
            last_error_class = type(exc).__name__
            if loop.time() >= deadline:
                break
            _atomic_json(
                state_path,
                {
                    "status": "refreshing",
                    "generation": generation,
                    "updated_at": _utc_now(),
                },
            )
            await asyncio.sleep(0.25)

    _atomic_json(
        state_path,
        {
            "status": "error",
            "error_class": last_error_class,
            "updated_at": _utc_now(),
        },
    )
    return 2


async def _sync(args: argparse.Namespace) -> int:
    token_path = Path(args.token_path)
    if not token_path.is_file():
        print(json.dumps({"ok": False, "error": "not_connected"}))
        return 2

    try:
        token_doc = json.loads(token_path.read_text(encoding="utf-8"))
        uid = int(str(token_doc.get("user_id") or "").strip())
        if uid <= 0:
            raise ValueError("missing Xiaomi user id")

        sessions: dict[str, dict[str, Any]] = {}
        async with MiHealthClient.from_token(token_path) as client:
            rows = await client.get_sleep(uid, date.today(), days=max(1, min(int(args.days), 30)))

        for row in rows or []:
            for segment in getattr(row, "segment_details", None) or []:
                normalized = _safe_session(
                    getattr(segment, "bedtime", 0),
                    getattr(segment, "wake_up_time", 0),
                    getattr(segment, "duration", 0),
                )
                if normalized:
                    sessions[normalized["external_id"]] = normalized

        ordered = sorted(sessions.values(), key=lambda item: item["start"])
        print(json.dumps({"ok": True, "sessions": ordered}, separators=(",", ":")))
        return 0
    except Exception as exc:
        print(
            json.dumps(
                {"ok": False, "error": "xiaomi_sync_failed", "error_class": type(exc).__name__},
                separators=(",", ":"),
            )
        )
        return 3


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    login = sub.add_parser("login")
    login.add_argument("--token-path", required=True)
    login.add_argument("--state-path", required=True)
    login.add_argument("--max-wait", type=float, default=300.0)

    sync = sub.add_parser("sync")
    sync.add_argument("--token-path", required=True)
    sync.add_argument("--days", type=int, default=7)

    args = parser.parse_args()
    if args.command == "login":
        return asyncio.run(_login(args))
    if args.command == "sync":
        return asyncio.run(_sync(args))
    return 2


if __name__ == "__main__":
    sys.exit(main())
