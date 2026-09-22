#!/usr/bin/env python3
"""Protect deployment ordering plus server-owned sleep synchronization invariants."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PB = ROOT / ".github/workflows/deploy-pocketbase.yml"
WEB = ROOT / ".github/workflows/deploy.yml"
SLEEP_HOOK = ROOT / "pb_hooks" / "sleep_sync.pb.js"
XIAOMI_RUNTIME = ROOT / "pb_hooks" / "xiaomi_sleep_runtime.js"
XIAOMI_BRIDGE = ROOT / "pb_hooks" / "xiaomi_sleep_bridge.py"
SLEEP_DOC = ROOT / "docs" / "SERVER_SLEEP_SYNC_DEPLOY.md"


def main() -> int:
    pb = PB.read_text(encoding="utf-8")
    web = WEB.read_text(encoding="utf-8")
    sleep_hook = SLEEP_HOOK.read_text(encoding="utf-8")
    xiaomi_runtime = XIAOMI_RUNTIME.read_text(encoding="utf-8")
    xiaomi_bridge = XIAOMI_BRIDGE.read_text(encoding="utf-8")
    sleep_doc = SLEEP_DOC.read_text(encoding="utf-8")
    violations: list[str] = []

    for token in (
        "name: Deploy PocketBase hooks and migrations",
        "branches: [main]",
        "Detect PocketBase bundle changes",
        "SERVER_CHANGED",
        "find pb_hooks pb_migrations",
        "Validate main architecture contracts",
    ):
        if token not in pb:
            violations.append(f"POCKETBASE_DEPLOY_CONTRACT_MISSING {token}")

    for token in (
        "workflow_run:",
        "Deploy PocketBase hooks and migrations",
        "types: [completed]",
        "workflow_run.conclusion == 'success'",
        "workflow_run.event == 'push'",
        "workflow_run.head_branch == 'main'",
        "workflow_run.head_sha",
        "ref: ${{ github.event.workflow_run.head_sha }}",
        "group: life-os-web-deploy",
        "cp -R /tmp/counter-gh-pages/.github/workflows build/web/.github/workflows",
        "cp .github/workflows/deploy.yml build/web/.github/workflows/deploy.yml",
        "cp .github/workflows/deploy-pocketbase.yml build/web/.github/workflows/deploy-pocketbase.yml",
    ):
        if token not in web:
            violations.append(f"WEB_DEPLOY_ORDERING_MISSING {token}")

    # Any independent Web entry could reintroduce a race with migrations.
    if "branches:\n      - main" in web or "branches: [main]" in web:
        violations.append("WEB_DEPLOY_DIRECT_MAIN_PUSH_FORBIDDEN")
    if "workflow_dispatch:" in web:
        violations.append("WEB_DEPLOY_MANUAL_BYPASS_FORBIDDEN")

    # The deployment branch is also the repository default branch. Publishing
    # must not delete the upstream PocketBase workflow or allow older SHA builds
    # to race newer ones back onto gh-pages.
    if "group: life-os-web-deploy-${{" in web:
        violations.append("WEB_DEPLOY_SHA_SCOPED_CONCURRENCY_FORBIDDEN")

    # SLEEP_SYNC_CONTRACT: Xiaomi Cloud is the primary server-owned source.
    # Current endpoints are mandatory because the legacy /app/v1/data family can
    # return successful but stale history while Mi Fitness already has newer data.
    for token in (
        'XIAOMI_AGGREGATED_PATH = "/app/v1/relatives/get_aggregated_data"',
        'XIAOMI_FITNESS_PATH = "/app/v1/relatives/get_fitness_data"',
        'XIAOMI_LATEST_PATH = "/app/v1/relatives/get_latest_data"',
        "_fetch_current_sleep_api",
        "_fetch_legacy_sleep_api",
    ):
        if token not in xiaomi_bridge:
            violations.append(f"XIAOMI_SLEEP_BRIDGE_CONTRACT_MISSING {token}")

    # Missing current-day sleep must be retried every 15 minutes regardless of
    # configured morning time. Startup uses the same self-healing rule.
    for token in (
        'cronAdd("lifeos_xiaomi_sleep_sync", "*/15 * * * *"',
        'provider = \'xiaomi\'',
        'connection.set("last_sync_at", "")',
        'xiaomi.set("last_sync_at", "")',
        "onBootstrap(function(e)",
    ):
        if token not in sleep_hook:
            violations.append(f"XIAOMI_SLEEP_SCHEDULER_CONTRACT_MISSING {token}")

    for forbidden in (
        "if (localMinutes < morningStart) continue;",
        "if (xiaomiMinutes < xiaomiMorningStart) continue;",
    ):
        if forbidden in sleep_hook:
            violations.append(f"XIAOMI_SLEEP_MORNING_GATE_FORBIDDEN {forbidden}")

    # Xiaomi may revise bedtime/wake boundaries, changing interval-based source
    # IDs. Strong overlap dedupe is therefore required in addition to exact-id
    # idempotency; non-overlapping naps remain separate.
    for token in (
        "overlap / shorter < 0.60",
        "45 * 24 * 60 * 60 * 1000",
        "app.delete(duplicate)",
    ):
        if token not in sleep_hook:
            violations.append(f"XIAOMI_SLEEP_DEDUPE_CONTRACT_MISSING {token}")

    # Runtime must remain Xiaomi-owned; legacy providers can only be disabled or
    # used through explicit recovery paths.
    for token in (
        'var __xiaomiProvider = "xiaomi"',
        'var providers = ["google_fit", "google_health"]',
    ):
        if token not in xiaomi_runtime:
            violations.append(f"XIAOMI_SLEEP_RUNTIME_CONTRACT_MISSING {token}")

    # Governing documentation is executable policy too. This prevents code from
    # being corrected while the Project Knowledge still teaches the old Google
    # Fit-primary architecture.
    for token in (
        "Xiaomi Health cloud",
        "/app/v1/relatives/get_aggregated_data",
        "/app/v1/relatives/get_fitness_data",
        "/app/v1/relatives/get_latest_data",
        "every **15 minutes**",
        "Do not wait for a configured morning clock time",
        "60% of the shorter interval",
        "Google Fit / Google Health are not the active primary pipeline",
    ):
        if token not in sleep_doc:
            violations.append(f"SLEEP_SYNC_DOC_CONTRACT_MISSING {token}")

    if violations:
        print("deployment_contract: FAIL", file=sys.stderr)
        for violation in violations:
            print(f"  - {violation}", file=sys.stderr)
        return 1

    print(
        "deployment_contract: OK server-before-web ordering, Xiaomi sleep freshness, "
        "missing-day cadence, dedupe, and documentation contracts enforced"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
