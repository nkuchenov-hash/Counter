#!/usr/bin/env python3
"""Protect server-schema-before-client deployment ordering."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PB = ROOT / ".github/workflows/deploy-pocketbase.yml"
WEB = ROOT / ".github/workflows/deploy.yml"


def main() -> int:
    pb = PB.read_text(encoding="utf-8")
    web = WEB.read_text(encoding="utf-8")
    violations: list[str] = []

    for token in (
        "name: Deploy PocketBase hooks and migrations",
        "branches: [main]",
        "Detect PocketBase bundle changes",
        "SERVER_CHANGED",
        "find pb_hooks pb_migrations",
    ):
        if token not in pb:
            violations.append(f"POCKETBASE_DEPLOY_CONTRACT_MISSING {token}")

    for token in (
        "workflow_run:",
        "Deploy PocketBase hooks and migrations",
        "types: [completed]",
        "workflow_run.conclusion == 'success'",
        "workflow_run.event == 'push'",
        "workflow_run.head_sha",
    ):
        if token not in web:
            violations.append(f"WEB_DEPLOY_ORDERING_MISSING {token}")

    # Any independent Web entry could reintroduce a race with migrations.
    if "branches:\n      - main" in web or "branches: [main]" in web:
        violations.append("WEB_DEPLOY_DIRECT_MAIN_PUSH_FORBIDDEN")
    if "workflow_dispatch:" in web:
        violations.append("WEB_DEPLOY_MANUAL_BYPASS_FORBIDDEN")

    if violations:
        print("deployment_contract: FAIL", file=sys.stderr)
        for violation in violations:
            print(f"  - {violation}", file=sys.stderr)
        return 1

    print("deployment_contract: OK server-before-web ordering enforced")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
