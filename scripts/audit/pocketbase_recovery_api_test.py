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

require_denied("anonymous profiles list", request("/api/collections/profiles/records"))
require_denied("anonymous categories list", request("/api/collections/categories/records"))
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
require_denied("anonymous records list", request("/api/collections/records/records"))

print("PASS: two-user auth, owned category/plan/record, anonymous isolation, cross-tenant rejection, tier protection")
