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

    if "branches:\n      - main" in web or "branches: [main]" in web:
        violations.append("WEB_DEPLOY_DIRECT_MAIN_PUSH_FORBIDDEN")
    if "workflow_dispatch:" in web:
        violations.append("WEB_DEPLOY_MANUAL_BYPASS_FORBIDDEN")
    if "group: life-os-web-deploy-${{" in web:
        violations.append("WEB_DEPLOY_SHA_SCOPED_CONCURRENCY_FORBIDDEN")

    # SLEEP_SYNC_CONTRACT: Xiaomi Cloud is the primary server-owned source.
    # Relatives/share and authenticated self-account API families can lag
    # independently while returning success, so every pass must merge both.
    for token in (
        'XIAOMI_AGGREGATED_PATH = "/app/v1/relatives/get_aggregated_data"',
        'XIAOMI_FITNESS_PATH = "/app/v1/relatives/get_fitness_data"',
        'XIAOMI_LATEST_PATH = "/app/v1/relatives/get_latest_data"',
        'XIAOMI_SELF_FITNESS_PATH = "/app/v1/data/get_fitness_data_by_time"',
        "_fetch_relatives_sleep_api",
        "_fetch_self_sleep_api",
        '"POST",\n            XIAOMI_SELF_FITNESS_PATH',
        "sessions.update(relatives)",
        "sessions.update(self_data)",
    ):
        if token not in xiaomi_bridge:
            violations.append(f"XIAOMI_SLEEP_BRIDGE_CONTRACT_MISSING {token}")

    if "if current:\n                return current" in xiaomi_bridge:
        violations.append("XIAOMI_SLEEP_STALE_NONEMPTY_SHORT_CIRCUIT_FORBIDDEN")

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

    for token in (
        "overlap / shorter < 0.60",
        "45 * 24 * 60 * 60 * 1000",
        "app.delete(duplicate)",
    ):
        if token not in sleep_hook:
            violations.append(f"XIAOMI_SLEEP_DEDUPE_CONTRACT_MISSING {token}")

    for token in (
        'var __xiaomiProvider = "xiaomi"',
        'var providers = ["google_fit", "google_health"]',
    ):
        if token not in xiaomi_runtime:
            violations.append(f"XIAOMI_SLEEP_RUNTIME_CONTRACT_MISSING {token}")

    for token in (
        "Xiaomi Health cloud",
        "/app/v1/relatives/get_aggregated_data",
        "/app/v1/relatives/get_latest_data",
        "/app/v1/data/get_fitness_data_by_time",
        "merge both Xiaomi API families",
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
        "deployment_contract: OK server-before-web ordering, merged Xiaomi sleep freshness, "
        "missing-day cadence, dedupe, and documentation contracts enforced"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
