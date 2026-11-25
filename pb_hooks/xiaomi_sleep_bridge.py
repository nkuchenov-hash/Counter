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
import tempfile
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from mi_fitness import MiHealthClient, XiaomiAuth


XIAOMI_HEALTH_BASE_URL = os.environ.get(
    "XIAOMI_HEALTH_BASE_URL",
    "https://ru.hlth.xiaomiwear.com",
).rstrip("/")
XIAOMI_HEALTH_REGION_URLS = (
    "https://ru.hlth.xiaomiwear.com",
    "https://hlth.io.mi.com",
    "https://region.hlth.io.mi.com",
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

# Two bounded regional phases must fit below the 90-second subprocess limit.
XIAOMI_REQUEST_TIMEOUT_SECONDS = 22.0
XIAOMI_FALLBACK_TIMEOUT_SECONDS = 12.0
XIAOMI_REGION_TIMEOUT_SECONDS = 40.0
XIAOMI_ROUTE_TTL_SECONDS = 7 * 86400
XIAOMI_NETWORK_COOLDOWN_SECONDS = 30 * 60
XIAOMI_RECENT_ROUTE_SLEEP_SECONDS = 36 * 3600


class XiaomiCloudUnavailable(RuntimeError):
    pass


class XiaomiCloudTimeout(RuntimeError):
    pass


class XiaomiCloudAuthError(RuntimeError):
    pass


async def _query_sleep(client: MiHealthClient, stats: dict[str, Any], method: str, path: str, *, request_timeout: float | None = None, **kwargs: Any) -> Any:
    try:
        response = await asyncio.wait_for(
            client._request(method, path, **kwargs),
            timeout=request_timeout if request_timeout is not None else XIAOMI_REQUEST_TIMEOUT_SECONDS,
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
        code = getattr(exc, "code", None)
        name = type(exc).__name__
        if name in ("TokenExpiredError", "AuthError") or code == 2:
            name = "XiaomiCloudAuthError"
        stats["errors"].append(name)
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


def _decode_value(value: Any) -> Any:
    # Some Xiaomi raw values are JSON arrays or double-encoded JSON objects.
    for _ in range(2):
        if not isinstance(value, str) or not value:
            break
        try:
            value = json.loads(value)
        except (TypeError, ValueError):
            return None
    return value


def _value_object(row: Any) -> dict[str, Any]:
    if not isinstance(row, dict):
        return {}
    value = _decode_value(row.get("value"))
    if isinstance(value, dict):
        return value
    if isinstance(value, list):
        return {"segment_details": value}
    if value is None:
        return row
    return {}


def _rows_from_response(response: Any) -> list[Any]:
    if not isinstance(response, dict):
        return []
    result = response.get("result")
    if isinstance(result, list):
        return result
    if isinstance(result, dict):
        rows = result.get("data_list") or result.get("data") or result.get("items")
        if isinstance(rows, list):
            return rows
    rows = response.get("data_list") or response.get("data") or response.get("items")
    return rows if isinstance(rows, list) else []


def _explicit_sleep_interval(value: dict[str, Any]) -> dict[str, Any] | None:
    # Whole sleep boundaries only. Generic stage start/end/time are not
    # sufficient evidence of a completed sleep session.
    start = value.get("bedtime") or value.get("bed_time") or value.get("bedTime")
    end = (value.get("wake_up_time") or value.get("device_wake_up_time")
           or value.get("wakeUpTime") or value.get("deviceWakeUpTime"))
    return _safe_session(start, end)


def _sleep_candidates(value: Any, depth: int = 0):
    if depth > 4:
        return
    value = _decode_value(value)
    if isinstance(value, list):
        for item in value:
            yield from _sleep_candidates(item, depth + 1)
    elif isinstance(value, dict):
        # Prefer explicitly aggregated intervals where provided.
        segments = _decode_value(value.get("segment_details") or value.get("segmentDetails"))
        if isinstance(segments, list) and segments:
            yield from _sleep_candidates(segments, depth + 1)
            return
        yield value
        for key in ("sleep", "sleep_data", "sleepData", "data", "items"):
            if key in value:
                yield from _sleep_candidates(value[key], depth + 1)


def _sessions_from_rows(rows: Any) -> dict[str, dict[str, Any]]:
    sessions: dict[str, dict[str, Any]] = {}
    if not isinstance(rows, list):
        return sessions
    for row in rows:
        if not isinstance(row, dict):
            continue
        kind = str(row.get("key") or row.get("data_type") or "").lower()
        if kind and kind != "sleep":
            continue
        for candidate in _sleep_candidates(_value_object(row)):
            normalized = _explicit_sleep_interval(candidate)
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
    shared = {"relative_uid": uid, "key": "sleep", "start_time": start,
              "end_time": end, "limit": limit}
    # Run independent reads concurrently so one slow endpoint cannot starve
    # every other endpoint. The SDK serializes authentication refresh itself.
    aggregate, latest, raw = await asyncio.gather(
        _query_sleep(client, stats, "GET", XIAOMI_AGGREGATED_PATH,
                     params={**shared, "tag": "daily_report"}),
        _query_sleep(client, stats, "GET", XIAOMI_LATEST_PATH,
                     params={"relative_uid": uid}),
        _query_sleep(client, stats, "GET", XIAOMI_FITNESS_PATH, params=shared),
    )
    sessions: dict[str, dict[str, Any]] = {}
    for response in (aggregate, raw):
        sessions.update(_sessions_from_rows(_rows_from_response(response)))
    # Latest includes other health types. Only explicitly tagged sleep rows
    # can be imported from this unfiltered endpoint.
    latest_rows = [r for r in _rows_from_response(latest) if isinstance(r, dict)
                   and str(r.get("key") or r.get("data_type") or "").lower() == "sleep"]
    sessions.update(_sessions_from_rows(latest_rows))
    return sessions


async def _fetch_self_sleep_api(
    client: MiHealthClient,
    start: int,
    end: int,
    limit: int,
    stats: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    """Keep both the legacy (previously deployed) and newer self API shapes."""
    legacy = {"key": "sleep", "start_time": start, "end_time": end, "limit": limit}
    raw_data = {"key": "sleep", "startTime": start * 1000, "endTime": end * 1000,
                "reverse": True, "next_key": None}
    aggregated_data = {"key": "sleep", "tag": "daily_report", "startTime": start * 1000,
                       "endTime": end * 1000, "reverse": True, "cursor": None}

    def envelope(data: dict[str, Any]) -> dict[str, str]:
        return {"data": json.dumps(data, separators=(",", ":"))}

    responses = await asyncio.gather(
        _query_sleep(client, stats,
            "POST",
            XIAOMI_SELF_FITNESS_PATH,
            params=legacy,
        ),
        _query_sleep(client, stats, "POST", XIAOMI_SELF_AGGREGATED_PATH,
                     params={**legacy, "tag": "daily_report"}),
        _query_sleep(client, stats, "POST", XIAOMI_SELF_FITNESS_PATH,
                     params=envelope(raw_data)),
        _query_sleep(client, stats, "GET", XIAOMI_SELF_FITNESS_PATH,
                     params=envelope(raw_data)),
        _query_sleep(client, stats, "POST", XIAOMI_SELF_AGGREGATED_PATH,
                     params=envelope(aggregated_data)),
    )
    sessions: dict[str, dict[str, Any]] = {}
    for response in responses:
        sessions.update(_sessions_from_rows(_rows_from_response(response)))

    # The Singapore response showed has_more=true. Check one further page
    # only when the first page does not contain fresh sleep; retain strict
    # filtering so unrelated health records cannot become sleep intervals.
    if _latest_end_epoch(sessions) < end - 2 * 86400:
        followups = []
        for method, response in (("POST", responses[2]), ("GET", responses[3])):
            result = response.get("result")
            data = result if isinstance(result, dict) else response
            cursor = data.get("next_key")
            if data.get("has_more") and isinstance(cursor, str) and cursor:
                followups.append(_query_sleep(
                    client, stats, method, XIAOMI_SELF_FITNESS_PATH,
                    request_timeout=XIAOMI_FALLBACK_TIMEOUT_SECONDS,
                    params=envelope({**raw_data, "next_key": cursor})))
        if followups:
            for response in await asyncio.gather(*followups):
                sessions.update(_sessions_from_rows(_rows_from_response(response)))
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
            # Parallel families fit a 22-second first pass and a 12-second
            # cursor follow-up inside the 40-second region deadline.
            relatives, self_data = await asyncio.gather(
                _fetch_relatives_sleep_api(client, uid, start, end, limit, stats),
                _fetch_self_sleep_api(client, start, end, limit, stats),
            )
            sessions.update(relatives)
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


def _route_cache_path(token_path: Path) -> Path:
    return token_path.with_name(token_path.name + ".route.json")


def _route_candidates() -> tuple[str, ...]:
    # Only deployment-configured or hardcoded Xiaomi hosts may receive tokens.
    # A local cache is an optimization, never an arbitrary URL source.
    return tuple(dict.fromkeys((XIAOMI_HEALTH_BASE_URL, *XIAOMI_HEALTH_REGION_URLS)))


def _load_route_state(token_path: Path, now: float) -> tuple[str | None, dict[str, float]]:
    try:
        raw = json.loads(_route_cache_path(token_path).read_text(encoding="utf-8"))
        if not isinstance(raw, dict):
            return None, {}
        allowed = set(_route_candidates())
        preferred = raw.get("preferred")
        confirmed = raw.get("confirmed_at", 0)
        if (not isinstance(preferred, str) or preferred not in allowed
                or not isinstance(confirmed, (int, float))
                or not 0 <= now - confirmed <= XIAOMI_ROUTE_TTL_SECONDS):
            preferred = None
        failures = raw.get("cooldowns", {})
        if not isinstance(failures, dict):
            failures = {}
        cooldowns = {
            host: float(until) for host, until in failures.items()
            if host in allowed and isinstance(until, (float, int))
            and now < until <= now + XIAOMI_NETWORK_COOLDOWN_SECONDS
        }
        return preferred, cooldowns
    except (OSError, ValueError, TypeError):
        return None, {}


def _save_route_state(token_path: Path, preferred: str | None, confirmed: float,
                      cooldowns: dict[str, float]) -> None:
    # Cache failures must never prevent sleep import. Unique temporary names
    # prevent overlapping bridge processes from truncating one another's file.
    if not token_path.is_file():
        return
    tmp = None
    try:
        target = _route_cache_path(token_path)
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=target.parent, prefix=".xiaomi-route-",
            delete=False,
        ) as f:
            tmp = Path(f.name)
            json.dump({"preferred": preferred, "confirmed_at": confirmed,
                       "cooldowns": cooldowns}, f, separators=(",", ":"))
        os.chmod(tmp, 0o600)
        os.replace(tmp, target)
        tmp = None
    except OSError:
        pass
    finally:
        if tmp is not None:
            try:
                tmp.unlink()
            except OSError:
                pass


def _network_failure(stats: dict[str, Any]) -> bool:
    if stats.get("success"):
        return False
    names = [str(e).lower() for e in stats.get("errors", [])]
    return any(any(marker in name for marker in (
        "timeout", "connecterror", "networkerror", "readerror", "writeerror",
        "remoteprotocolerror", "proxyerror", "oserror", "sslerror", "gaierror",
    )) for name in names)


def _failure_class(stats: dict[str, Any]) -> type[RuntimeError]:
    errors = [str(e).lower() for e in stats.get("errors", [])]
    if errors and all("auth" in e or "unauthorized" in e for e in errors):
        return XiaomiCloudAuthError
    if _network_failure(stats):
        return XiaomiCloudTimeout if any("timeout" in e for e in errors) else XiaomiCloudUnavailable
    return XiaomiCloudUnavailable


def _merge_missing_intervals(target: dict[str, dict[str, Any]],
                             other: dict[str, dict[str, Any]]) -> None:
    # Preserve the preferred provider version of revised overlapping nights.
    # Only add independent, complete intervals from other queried regions.
    for key, row in other.items():
        if key in target:
            continue
        try:
            start = datetime.fromisoformat(row["start"].replace("Z", "+00:00")).timestamp()
            end = datetime.fromisoformat(row["end"].replace("Z", "+00:00")).timestamp()
            if end <= start:
                continue
            overlaps = False
            for current in target.values():
                a = datetime.fromisoformat(current["start"].replace("Z", "+00:00")).timestamp()
                b = datetime.fromisoformat(current["end"].replace("Z", "+00:00")).timestamp()
                shorter = min(end - start, b - a)
                if shorter > 0 and max(0, min(end, b) - max(start, a)) / shorter >= 0.60:
                    overlaps = True
                    break
            if not overlaps:
                target[key] = row
        except (KeyError, TypeError, ValueError, AttributeError):
            continue


async def _select_sleep_region(token_path: Path, uid: int, start: int, end: int,
                               limit: int, stale_cutoff: float,
                               diagnostics: dict[str, Any] | None = None) -> tuple[dict[str, dict[str, Any]], str]:
    now = time.time()
    cached, cooldowns = _load_route_state(token_path, now)
    preferred = cached or XIAOMI_HEALTH_BASE_URL
    candidates = _route_candidates()
    available = [host for host in candidates if host not in cooldowns]
    # Cooldowns must not suppress an entire sync if all routes were unhealthy.
    if not available:
        available = list(candidates)
    primary = preferred if preferred in available else available[0]
    results: dict[str, tuple[dict[str, dict[str, Any]], dict[str, Any]]] = {}
    results[primary] = await _probe_region(token_path, uid, primary, start, end, limit)
    if _latest_end_epoch(results[primary][0]) < stale_cutoff:
        others = [host for host in available if host != primary]
        # Preserve existing bounded parallel regional fallback. Always include
        # the verified Russian alias in the candidate set even on a new host.
        probed = await asyncio.gather(*(
            _probe_region(token_path, uid, host, start, end, limit) for host in others
        ))
        results.update(zip(others, probed))
    for host, (_, stats) in results.items():
        if _network_failure(stats):
            cooldowns[host] = now + XIAOMI_NETWORK_COOLDOWN_SECONDS
        elif stats.get("success"):
            cooldowns.pop(host, None)

    selected = max(results, key=lambda host: (
        _latest_end_epoch(results[host][0]), host == preferred,
        host == primary,
    ))
    sessions = dict(results[selected][0])
    for host, (candidate, _) in results.items():
        if host != selected:
            _merge_missing_intervals(sessions, candidate)

    trusted_stats = results.get(preferred, ({}, {"success": 0, "errors": []}))[1]
    total_success = sum(stats["success"] for _, stats in results.values())
    all_errors = [e for _, stats in results.values() for e in stats["errors"]]
    recent = _latest_end_epoch(results[selected][0]) >= max(1, now - XIAOMI_RECENT_ROUTE_SLEEP_SECONDS)
    if recent:
        _save_route_state(token_path, selected, now, cooldowns)
    else:
        # Do not renew an old preference on empty or historical-only responses.
        old_confirmed = 0.0
        if cached:
            try:
                old_confirmed = float(json.loads(_route_cache_path(token_path).read_text(encoding="utf-8"))["confirmed_at"])
            except (OSError, ValueError, TypeError, KeyError):
                cached = None
        _save_route_state(token_path, cached, old_confirmed, cooldowns)

    source_status = "available" if _latest_end_epoch(sessions) >= stale_cutoff else "no_fresh_sleep"
    if source_status != "available" and not trusted_stats.get("success"):
        if _network_failure(trusted_stats) or preferred in cooldowns:
            source_status = "network_unavailable"
        elif _failure_class(trusted_stats) is XiaomiCloudAuthError:
            source_status = "authorization_failed"
    if diagnostics is not None:
        diagnostics.update({"source_status": source_status})
    if not sessions and (not total_success or source_status in ("network_unavailable", "authorization_failed")):
        if source_status == "authorization_failed":
            raise XiaomiCloudAuthError()
        if source_status == "network_unavailable":
            raise XiaomiCloudTimeout() if preferred in cooldowns else _failure_class(trusted_stats)()
        raise _failure_class({"success": 0, "errors": all_errors})()
    return sessions, selected


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
            # A new authorization must never inherit an older account's routing state.
            try:
                _route_cache_path(token_path).unlink(missing_ok=True)
            except OSError:
                pass
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

        diagnostics: dict[str, Any] = {}
        sessions, selected_base = await _select_sleep_region(
            token_path, uid, start, end, limit,
            args.today_start if args.today_start is not None
            else datetime(now.year, now.month, now.day, tzinfo=timezone.utc).timestamp(),
            diagnostics=diagnostics,
        )

        ordered = sorted(sessions.values(), key=lambda item: item["start"])
        region = selected_base.split("//", 1)[-1].split(".", 1)[0]
        print(json.dumps({"ok": True, "sessions": ordered, "region": region,
                          **diagnostics}, separators=(",", ":")))
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
    sync.add_argument("--today-start", type=float, default=None,
                      help="Profile-local midnight as UTC epoch seconds")

    args = parser.parse_args()
    if args.command == "login":
        return asyncio.run(_login(args))
    if args.command == "sync":
        return asyncio.run(_sync(args))
    return 2


if __name__ == "__main__":
    sys.exit(main())
