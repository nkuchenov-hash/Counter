#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def write(path: str, body: str) -> None:
    (ROOT / path).write_text(body.rstrip() + "\n", encoding="utf-8", newline="\n")


pb_path = ".github/workflows/deploy-pocketbase.yml"
pb = read(pb_path)
old_trigger = """on:
  pull_request:
    paths:
      - 'pb_hooks/**'
      - 'pb_migrations/**'
      - '.github/workflows/deploy-pocketbase.yml'
  push:
    branches:
      - main
    paths:
      - 'pb_hooks/**'
      - 'pb_migrations/**'
      - '.github/workflows/deploy-pocketbase.yml'
  workflow_dispatch:
"""
new_trigger = """on:
  pull_request:
    paths:
      - 'pb_hooks/**'
      - 'pb_migrations/**'
      - '.github/workflows/deploy-pocketbase.yml'
  push:
    branches: [main]
  workflow_dispatch:
"""
if old_trigger not in pb:
    raise SystemExit("deploy-pocketbase trigger anchor missing")
pb = pb.replace(old_trigger, new_trigger)

require_start = pb.find("      - name: Require production credentials\n")
checkout_start = pb.find("      - name: Checkout repository\n", require_start)
prepare_ssh_start = pb.find("      - name: Prepare SSH\n", checkout_start)
if min(require_start, checkout_start, prepare_ssh_start) < 0:
    raise SystemExit("deploy-pocketbase step ordering anchors missing")
require_block = pb[require_start:checkout_start]
checkout_block = """      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

"""
detect_block = """      - name: Detect PocketBase bundle changes
        shell: bash
        env:
          BEFORE_SHA: ${{ github.event.before }}
        run: |
          set -euo pipefail
          changed=true
          if [[ "${{ github.event_name }}" == "push" && -n "${BEFORE_SHA:-}" && ! "$BEFORE_SHA" =~ ^0+$ ]]; then
            if git diff --quiet "$BEFORE_SHA" "$GITHUB_SHA" -- pb_hooks pb_migrations .github/workflows/deploy-pocketbase.yml; then
              changed=false
            fi
          fi
          echo "SERVER_CHANGED=$changed" >> "$GITHUB_ENV"
          echo "PocketBase bundle changed: $changed"

"""
# Remove old checkout and put checkout + change detection before credential requirements.
pb = pb[:require_start] + checkout_block + detect_block + require_block + pb[prepare_ssh_start:]

for step_name in (
    "Require production credentials",
    "Prepare SSH",
    "Prepare Google Health environment",
    "Upload server bundle",
    "Install and restart PocketBase",
):
    needle = f"      - name: {step_name}\n"
    replacement = needle + "        if: env.SERVER_CHANGED == 'true'\n"
    if needle not in pb:
        raise SystemExit(f"deploy-pocketbase step missing: {step_name}")
    pb = pb.replace(needle, replacement, 1)
write(pb_path, pb)

# Web deployment is downstream of the server workflow. Every main push therefore
# completes PocketBase validation (and migrations when needed) before publishing
# a client that may depend on the new schema.
web = """name: Deploy LIFE OS Flutter Web to GitHub Pages

# LIFE OS deploy is independent from Igropoisk data collection.
# Server schema/hook validation is the release gate: a main push first completes
# "Deploy PocketBase hooks and migrations", then this workflow publishes that
# exact successful head SHA.
on:
  workflow_run:
    workflows: ["Deploy PocketBase hooks and migrations"]
    types: [completed]
  workflow_dispatch:

permissions:
  contents: write

concurrency:
  group: life-os-web-deploy
  cancel-in-progress: true

jobs:
  build-and-deploy:
    if: >-
      github.event_name == 'workflow_dispatch' ||
      (github.event.workflow_run.conclusion == 'success' &&
       github.event.workflow_run.event == 'push')
    runs-on: ubuntu-latest
    timeout-minutes: 30
    env:
      TARGET_SHA: ${{ github.event_name == 'workflow_run' && github.event.workflow_run.head_sha || github.sha }}
    steps:
      - name: Checkout release commit
        uses: actions/checkout@v4
        with:
          ref: ${{ env.TARGET_SHA }}
          fetch-depth: 0

      - name: Set up Flutter 3.41.6
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.6'
          channel: stable

      - name: Create env.dart
        run: |
          mkdir -p lib/core/env
          printf '%s\\n' 'abstract final class Env {' '  static const String placeholder = '\\'''\\'';' '}' > lib/core/env/env.dart

      - name: Install Flutter dependencies
        run: flutter pub get

      - name: Build LIFE OS web
        run: |
          SHORT_SHA=$(git rev-parse --short HEAD)
          BUILD_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
          flutter build web --release --base-href="/Counter/" --no-tree-shake-icons --no-wasm-dry-run --pwa-strategy=none \\
            --dart-define=GIT_COMMIT="$SHORT_SHA" \\
            --dart-define=BUILD_TIME="$BUILD_TIME"

      - name: Preserve published Igropoisk
        run: |
          git fetch origin gh-pages:refs/remotes/origin/gh-pages
          rm -rf /tmp/counter-gh-pages
          git worktree add --detach /tmp/counter-gh-pages refs/remotes/origin/gh-pages
          if [ -d /tmp/counter-gh-pages/igropoisk ]; then
            rm -rf build/web/igropoisk
            cp -R /tmp/counter-gh-pages/igropoisk build/web/igropoisk
          fi
          git worktree remove --force /tmp/counter-gh-pages

      - name: Deploy to gh-pages
        uses: JamesIves/github-pages-deploy-action@v4
        with:
          folder: build/web
          branch: gh-pages
"""
write(".github/workflows/deploy.yml", web)

# Keep governing deploy docs aligned with the actual ordered workflow chain.
deploy_path = "docs/DEPLOY.md"
deploy = read(deploy_path)
ordered = """

### Production release ordering law

Every `main` push starts `.github/workflows/deploy-pocketbase.yml`. It validates the complete tracked PocketBase JS bundle; if `pb_hooks/`, `pb_migrations/`, or the server workflow changed, it deploys/restarts PocketBase and lets unapplied migrations finish. `.github/workflows/deploy.yml` is triggered by the successful **workflow_run** and checks out that exact `head_sha` before publishing LIFE OS Web. Therefore a schema-dependent Web client cannot be published ahead of its server migration.

A main push with no PocketBase bundle change still completes the server validation workflow but skips SSH/restart; Web remains downstream of the successful gate. Manual Web dispatch is a deliberate redeploy of an already-released main state.
"""
if "### Production release ordering law" not in deploy:
    deploy += ordered
write(deploy_path, deploy)

print("release_order: applied")
