#!/usr/bin/env python3
"""Server-only bridge between PocketBase JSVM and Xiaomi Health cloud.

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
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from mi_fitness import MiHealthClient, XiaomiAuth


XIAOMI_HEALTH_BASE_URL = os.environ.get(
    "XIAOMI_HEALTH_BASE_URL",
    "https://ru.hlth.io.mi.com",
).rstrip("/")
XIAOMI_HEALTH_REGION_URLS = (
    "https://hlth.io.mi.com",
    "https://ru.hlth.io.mi.com",
    "https://de.hlth.io.mi.com",
    "https://i2.hlth.io.mi.com",
    "https://sg.hlth.io.mi.com",
    "https://us.hlth.io.mi.com",
)

# Xiaomi exposes both relatives/share endpoints and self-account data endpoints.
# Either family may lag while still returning HTTP success, so every sync merges
# all successful sleep sources and chooses freshness by the resulting sessions.
XIAOMI_AGGREGATED_PATH = "/app/v1/relatives/get_aggregated_data"
XIAOMI_FITNESS_PATH = "/app/v1/relatives/get_fitness_data"
XIAOMI_LATEST_PATH = "/app/v1/relatives/get_latest_data"
XIAOMI_SELF_AGGREGATED_PATH = "/app/v1/data/get_aggregated_fitness_data_by_time"
XIAOMI_SELF_FITNESS_PATH = "/app/v1/data/get_fitness_data_by_time"

# Five serial endpoint calls per region; two bounded regional phases must fit
# below the PocketBase subprocess hard limit of 90 seconds.
XIAOMI_REQUEST_TIMEOUT_SECONDS = 6.0
XIAOMI_REGION_TIMEOUT_SECONDS = 35.0


class XiaomiCloudUnavailable(RuntimeError):
    pass


class XiaomiCloudTimeout(RuntimeError):
    pass


class XiaomiCloudAuthError(RuntimeError):
    pass


async def _query_sleep(client: MiHealthClient, stats: dict[str, Any], method: str, path: str, **kwargs: Any) -> Any:
    try:
        response = await asyncio.wait_for(
            client._request(method, path, **kwargs),
            timeout=XIAOMI_REQUEST_TIMEOUT_SECONDS,
        )
        if not isinstance(response, dict):
            raise ValueError("invalid Xiaomi response")
        code = response.get("code")
        if code is not None and str(code) not in ("0", "200"):
            if str(code) in ("401", "403"):
                raise XiaomiCloudAuthError()
            raise XiaomiCloudUnavailable()
        stats["success"] += 1
        return response
    except Exception as exc:
        # Store only sanitized error classes, never credentials or response bodies.
        stats["errors"].append(type(exc).__name__)
        return {}


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
    while value >= 1_000_000_000_000:
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


def _safe_session(start_raw: Any, end_raw: Any) -> dict[str, Any] | None:
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
    external_id = f"xiaomi:{int(start_s)}:{int(end_s)}"
    return {
        "external_id": external_id,
        "start": start,
        "end": end,
        "duration_minutes": round(elapsed / 60),
    }


def _value_object(row: Any) -> dict[str, Any]:
    if not isinstance(row, dict):
        return {}
    value = row.get("value")
    if isinstance(value, dict):
        return value
    if not isinstance(value, str) or not value:
        return {}
    try:
        parsed = json.loads(value)
    except (TypeError, ValueError, json.JSONDecodeError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _rows_from_response(response: Any) -> list[Any]:
    if not isinstance(response, dict):
        return []
    result = response.get("result")
    if isinstance(result, dict):
        rows = result.get("data_list") or result.get("data") or result.get("items")
        if isinstance(rows, list):
            return rows
    rows = response.get("data_list") or response.get("data") or response.get("items")
    return rows if isinstance(rows, list) else []


def _sessions_from_rows(rows: Any) -> dict[str, dict[str, Any]]:
    sessions: dict[str, dict[str, Any]] = {}
    if not isinstance(rows, list):
        return sessions
    for row in rows:
        value = _value_object(row)
        segments = value.get("segment_details") or value.get("items") or []
        if not isinstance(segments, list):
            continue
        for segment in segments:
            if not isinstance(segment, dict):
                continue
            normalized = _safe_session(
                segment.get("bedtime"),
                segment.get("wake_up_time"),
            )
            if normalized:
                sessions[normalized["external_id"]] = normalized
    return sessions


def _latest_end_epoch(sessions: dict[str, dict[str, Any]]) -> float:
    latest = 0.0
    for session in sessions.values():
        value = str(session.get("end") or "")
        if not value:
            continue
        try:
            latest = max(latest, datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp())
        except ValueError:
            continue
    return latest


async def _fetch_relatives_sleep_api(
    client: MiHealthClient,
    uid: int,
    start: int,
    end: int,
    limit: int,
    stats: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    sessions: dict[str, dict[str, Any]] = {}

    try:
        response = await _query_sleep(client, stats,
            "GET",
            XIAOMI_AGGREGATED_PATH,
            params={
                "relative_uid": uid,
                "key": "sleep",
                "tag": "daily_report",
                "start_time": start,
                "end_time": end,
                "limit": limit,
            },
        )
        sessions.update(_sessions_from_rows(_rows_from_response(response)))
    except Exception:
        pass

    try:
        latest_response = await _query_sleep(client, stats,
            "GET",
            XIAOMI_LATEST_PATH,
            params={"relative_uid": uid},
        )
        latest_rows = _rows_from_response(latest_response)
        sleep_rows = [
            row for row in latest_rows
            if isinstance(row, dict) and str(row.get("key") or row.get("data_type") or "").lower() == "sleep"
        ]
        sessions.update(_sessions_from_rows(sleep_rows or latest_rows))
    except Exception:
        pass

    try:
        raw_response = await _query_sleep(client, stats,
            "GET",
            XIAOMI_FITNESS_PATH,
            params={
                "relative_uid": uid,
                "key": "sleep",
                "start_time": start,
                "end_time": end,
                "limit": limit,
            },
        )
        sessions.update(_sessions_from_rows(_rows_from_response(raw_response)))
    except Exception:
        pass

    return sessions


async def _fetch_self_sleep_api(
    client: MiHealthClient,
    start: int,
    end: int,
    limit: int,
    stats: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    """Read the authenticated account's own sleep through Xiaomi data APIs.

    These endpoints use encrypted POST requests and intentionally do not pass a
    relative_uid. They are merged with the relatives API because either Xiaomi
    family can be stale independently while still returning a successful result.
    """
    sessions: dict[str, dict[str, Any]] = {}

    try:
        response = await _query_sleep(client, stats,
            "POST",
            XIAOMI_SELF_AGGREGATED_PATH,
            params={
                "key": "sleep",
                "tag": "daily_report",
                "start_time": start,
                "end_time": end,
                "limit": limit,
            },
        )
        sessions.update(_sessions_from_rows(_rows_from_response(response)))
    except Exception:
        pass

    try:
        raw_response = await _query_sleep(client, stats,
            "POST",
            XIAOMI_SELF_FITNESS_PATH,
            params={
                "key": "sleep",
                "start_time": start,
                "end_time": end,
                "limit": limit,
            },
        )
        sessions.update(_sessions_from_rows(_rows_from_response(raw_response)))
    except Exception:
        pass

    return sessions


async def _fetch_sleep_for_base(
    token_path: Path,
    uid: int,
    base_url: str,
    start: int,
    end: int,
    limit: int,
) -> tuple[dict[str, dict[str, Any]], dict[str, Any]]:
    stats: dict[str, Any] = {"success": 0, "errors": []}
    sessions: dict[str, dict[str, Any]] = {}
    try:
        async with MiHealthClient.from_token(token_path, base_url=base_url) as client:
            relatives = await _fetch_relatives_sleep_api(client, uid, start, end, limit, stats)
            sessions.update(relatives)
            self_data = await _fetch_self_sleep_api(client, start, end, limit, stats)
            sessions.update(self_data)
    except Exception as exc:
        stats["errors"].append(type(exc).__name__)
    return sessions, stats


async def _probe_region(token_path: Path, uid: int, base_url: str, start: int, end: int, limit: int) -> tuple[dict[str, dict[str, Any]], dict[str, Any]]:
    try:
        return await asyncio.wait_for(
            _fetch_sleep_for_base(token_path, uid, base_url, start, end, limit),
            timeout=XIAOMI_REGION_TIMEOUT_SECONDS,
        )
    except Exception as exc:
        return {}, {"success": 0, "errors": [type(exc).__name__]}


async def _select_sleep_region(token_path: Path, uid: int, start: int, end: int, limit: int, stale_cutoff: float) -> tuple[dict[str, dict[str, Any]], str]:
    selected_base = XIAOMI_HEALTH_BASE_URL
    sessions, stats = await _probe_region(token_path, uid, selected_base, start, end, limit)
    total_success = stats["success"]
    errors = list(stats["errors"])
    if _latest_end_epoch(sessions) < stale_cutoff:
        bases = [base for base in XIAOMI_HEALTH_REGION_URLS if base != selected_base]
        # Each region has an independent client. Do not serialize five regions
        # behind the slowest one, or share an authenticated client across them.
        results = await asyncio.gather(*(
            _probe_region(token_path, uid, base, start, end, limit) for base in bases
        ))
        for base, (candidate, candidate_stats) in zip(bases, results):
            total_success += candidate_stats["success"]
            errors.extend(candidate_stats["errors"])
            if _latest_end_epoch(candidate) > _latest_end_epoch(sessions):
                sessions, selected_base = candidate, base
    if not total_success:
        if errors and all("auth" in e.lower() or "unauthorized" in e.lower() for e in errors):
            raise XiaomiCloudAuthError()
        if any("timeout" in e.lower() for e in errors):
            raise XiaomiCloudTimeout()
        raise XiaomiCloudUnavailable()
    return sessions, selected_base


async def _login(args: argparse.Namespace) -> int:
    token_path = Path(args.token_path)
    state_path = Path(args.state_path)
    _atomic_json(state_path, {"status": "starting", "updated_at": _utc_now()})

    # The generated Xiaomi QR/loginUrl has its own much shorter lifetime than
    # the overall LIFE OS authorization page. Rotate it proactively.
    total_wait = max(60.0, min(540.0, float(args.max_wait)))
    loop = asyncio.get_running_loop()
    deadline = loop.time() + total_wait
    generation = 0
    last_error_class = "TimeoutError"

    while loop.time() < deadline:
        generation += 1
        remaining = max(1.0, deadline - loop.time())
        attempt_wait = min(75.0, remaining)
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
                            # The user-facing login link is valid only while
                            # fresh; do not expose a several-minute-old link.
                            "fresh_until": (
                                datetime.now(timezone.utc) + timedelta(seconds=45)
                            ).isoformat().replace("+00:00", "Z"),
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
            # Avoid rapid credential/QR endpoint retries if Xiaomi is throttling.
            await asyncio.sleep(2.0)

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

        days = max(1, min(int(args.days), 30))
        now = datetime.now(timezone.utc)
        end = int(datetime(now.year, now.month, now.day, 23, 59, 59, tzinfo=timezone.utc).timestamp())
        start = end - (days + 1) * 86400 + 1
        limit = max(30, days + 2)

        sessions, selected_base = await _select_sleep_region(
            token_path, uid, start, end, limit, now.timestamp() - 36 * 3600
        )

        ordered = sorted(sessions.values(), key=lambda item: item["start"])
        region = selected_base.split("//", 1)[-1].split(".", 1)[0]
        print(json.dumps({"ok": True, "sessions": ordered, "region": region}, separators=(",", ":")))
        return 0
    except Exception as exc:
        print(
            json.dumps(
                {"ok": False, "error": "xiaomi_sync_failed", "error_class": type(exc).__name__},
                separators=(",", ":"),
            )
        )
        # The JSVM reads stdout using cmd.output(), which discards the JSON
        # when the child exits nonzero. Report handled cloud failures through
        # the existing ok=false protocol; process crashes still fail normally.
        return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    login = sub.add_parser("login")
    login.add_argument("--token-path", required=True)
    login.add_argument("--state-path", required=True)
    login.add_argument("--max-wait", type=float, default=300.0)

    sync = sub.add_parser("sync")
    sync.add_argument("--token-path", required=True)
    sync.add_argument("--days", type=int, default=14)

    args = parser.parse_args()
    if args.command == "login":
        return asyncio.run(_login(args))
    if args.command == "sync":
        return asyncio.run(_sync(args))
    return 2


if __name__ == "__main__":
    sys.exit(main())
