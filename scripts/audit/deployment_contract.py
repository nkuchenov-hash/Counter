#!/usr/bin/env python3
"""Protect server-schema-before-client deployment ordering and default-branch continuity."""

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

    if violations:
        print("deployment_contract: FAIL", file=sys.stderr)
        for violation in violations:
            print(f"  - {violation}", file=sys.stderr)
        return 1

    print("deployment_contract: OK server-before-web ordering and workflow continuity enforced")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
