#!/usr/bin/env python3
"""PocketBase recovery: disposable local API smoke / tenant-isolation tests.

Never run against a production URL. This test creates fake users/data.
Use only with a private 127.0.0.1:port instance and disposable pb_data.
"""
import json
import os
import urllib.error
import urllib.request
from uuid import uuid4

BASE = os.environ.get("LIFEOS_RECOVERY_TEST_URL", "http://127.0.0.1:18099")
assert BASE.startswith("http://127.0.0.1:"), "Refusing non-loopback target"
PASS = "TestingOnly!7" + uuid4().hex[:8]
seed = uuid4().hex[:9]


def request(path, method="GET", payload=None, token=None):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = token
    req = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=8) as response:
            body = response.read().decode("utf-8")
            return response.status, json.loads(body) if body else {}
    except urllib.error.HTTPError as ex:
        try:
            body = json.loads(ex.read().decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            body = {}
        return ex.code, body


def require_ok(name, response):
    code, body = response
    if code < 200 or code >= 300:
        raise AssertionError(f"{name}: unexpected HTTP {code}; {body!r}")
    return body


def require_empty_list(name, response):
    code, body = response
    if code != 200 or body.get("items") != []:
        raise AssertionError(f"{name}: expected empty list, got HTTP {code}; {body!r}")


def require_denied(name, response):
    code, _ = response
    if code < 400:
        raise AssertionError(f"{name}: forbidden request succeeded (HTTP {code})")


require_ok("health", request("/api/health"))
users = []
for index in (1, 2):
    email = f"pb-recovery-{index}-{seed}@example.invalid"
    u = require_ok("create auth user", request(
        "/api/collections/profiles/records", "POST", {
            "email": email, "password": PASS, "passwordConfirm": PASS,
        }
    ))
    assert len(u["id"]) == 15
    auth = require_ok("password login", request(
        "/api/collections/profiles/auth-with-password",
        "POST", {"identity": email, "password": PASS}
    ))
    assert auth["record"]["id"] == u["id"]
    users.append((u["id"], auth["token"]))

alice_id, alice_token = users[0]
bob_id, bob_token = users[1]

require_empty_list("anonymous profiles list", request("/api/collections/profiles/records"))
require_empty_list("anonymous categories list", request("/api/collections/categories/records"))
require_denied("anonymous category create", request(
    "/api/collections/categories/records", "POST",
    {"name": "Unauthorized", "category_id": "anon"}
))
require_denied("users cannot promote own tier", request(
    "/api/collections/profiles/records/" + alice_id, "PATCH", {"tier": "pro"}, alice_token
))
require_denied("users cannot change is_admin", request(
    "/api/collections/profiles/records/" + alice_id, "PATCH", {"is_admin": True}, alice_token
))
category = require_ok("create owned category", request(
    "/api/collections/categories/records", "POST",
    {"user_id": alice_id, "category_id": "work-" + seed, "name": "Recovery Test"},
    alice_token
))
category_id = category["id"]
require_denied("cross-user category read", request(
    "/api/collections/categories/records/" + category_id, token=bob_token
))
require_denied("cross-user category update", request(
    "/api/collections/categories/records/" + category_id, "PATCH",
    {"name": "Stolen"}, bob_token
))
require_denied("cross-user category create", request(
    "/api/collections/categories/records", "POST",
    {"user_id": alice_id, "category_id": "malice-" + seed, "name": "Malice"},
    bob_token
))
require_denied("cross-user plan with stolen category", request(
    "/api/collections/plans/records", "POST",
    {"user_id": bob_id, "plan_id": "malice-" + seed,
     "category_id": category_id, "title": "Cannot link cross-user"},
    bob_token
))
plan = require_ok("create owned plan", request(
    "/api/collections/plans/records", "POST",
    {"user_id": alice_id, "plan_id": "p-" + seed,
     "category_id": category_id, "title": "Test plan"},
    alice_token
))
require_denied("cross-user plan read", request(
    "/api/collections/plans/records/" + plan["id"], token=bob_token
))
require_denied("cross-user plan change", request(
    "/api/collections/plans/records/" + plan["id"], "PATCH",
    {"title": "Stolen plan"}, bob_token
))
record = require_ok("create owned record", request(
    "/api/collections/records/records", "POST",
    {"user_id": alice_id, "record_id": "r-" + seed, "title": "Test record",
     "start_time": "2026-11-03 10:00:00.000Z", "end_time": "2026-11-03 10:15:00.000Z",
     "category_id": category_id, "category_link": category_id,
     "source_plan_id": plan["id"], "status": "completed", "type": "record"},
    alice_token
))
require_denied("cross-user record read", request(
    "/api/collections/records/records/" + record["id"], token=bob_token
))
require_denied("cross-user record update", request(
    "/api/collections/records/records/" + record["id"], "PATCH",
    {"title": "Tampered"}, bob_token
))
require_empty_list("anonymous records list", request("/api/collections/records/records"))


# Atomic running-primary invariant: requests from two clients cannot leave
# multiple primary records open, even after out-of-order offline replay.
def make_running(key, when):
    return require_ok("create running " + key, request(
        "/api/collections/records/records", "POST",
        {"user_id": alice_id, "record_id": "run-" + key + "-" + seed,
         "title": "Running " + key, "start_time": when,
         "category_id": category_id, "category_link": category_id,
         "status": "running", "type": "record"},
        alice_token
    ))

first = make_running("first", "2026-11-03 12:00:00.000Z")
second = make_running("second", "2026-11-03 13:00:00.000Z")
assert require_ok("read stopped predecessor", request(
    "/api/collections/records/records/" + first["id"], token=alice_token
))["status"] == "stopped"
assert require_ok("read current running", request(
    "/api/collections/records/records/" + second["id"], token=alice_token
))["status"] == "running"
assert require_ok("read previous end", request(
    "/api/collections/records/records/" + first["id"], token=alice_token
))["end_time"].startswith("2026-11-03 13:00:00")

# Late/offline arrival may not re-activate a record that predates a newer one.
late = make_running("out-of-order", "2026-11-03 11:30:00.000Z")
late_actual = require_ok("read late create", request(
    "/api/collections/records/records/" + late["id"], token=alice_token
))
assert late_actual["status"] == "stopped", late_actual
assert late_actual["end_time"].startswith("2026-11-03 12:00:00")
assert require_ok("current still running", request(
    "/api/collections/records/records/" + second["id"], token=alice_token
))["status"] == "running"

from concurrent.futures import ThreadPoolExecutor
with ThreadPoolExecutor(max_workers=2) as pool:
    pending = [
        pool.submit(make_running, "concurrent" + str(i),
                    f"2026-11-03 {14+i}:00:00.000Z")
        for i in (0, 1)
    ]
    [f.result() for f in pending]

running = require_ok("single running primary", request(
    "/api/collections/records/records?filter=status%3D%22running%22",
    token=alice_token
))
open_primaries = [
    x for x in running["items"]
    if x["user_id"] == alice_id and not x.get("parent_id") and
    not x.get("end_time")
]
assert len(open_primaries) == 1, open_primaries

# Re-activating an older record is likewise refused/closed by the timeline.
reactivated = require_ok("historic status reactivation", request(
    "/api/collections/records/records/" + first["id"], "PATCH",
    {"status": "running", "end_time": ""}, alice_token
))
assert reactivated["status"] == "stopped", reactivated
running = require_ok("single running after historical edit", request(
    "/api/collections/records/records?filter=status%3D%22running%22",
    token=alice_token
))
assert len([x for x in running["items"] if x["user_id"] == alice_id
            and not x.get("parent_id") and not x.get("end_time")]) == 1
print("PASS: server serializes simultaneous starts, handoffs, backdated offline replays, and record updates")

print("PASS: two-user auth, owned category/plan/record, anonymous isolation, cross-tenant rejection, tier protection")
