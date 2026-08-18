#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def write(path: str, body: str) -> None:
    (ROOT / path).write_text(body.rstrip() + "\n", encoding="utf-8", newline="\n")


architecture_path = ".github/workflows/architecture-guard.yml"
architecture = read(architecture_path)
trigger = """on:
  pull_request:
    branches:
      - main
  workflow_dispatch:
"""
replacement = """on:
  pull_request:
    branches:
      - main
  push:
    branches: [main]
  workflow_dispatch:
"""
if trigger not in architecture:
    raise SystemExit("Architecture Guard trigger anchor missing")
architecture = architecture.replace(trigger, replacement, 1)
write(architecture_path, architecture)

pb_path = ".github/workflows/deploy-pocketbase.yml"
pb = read(pb_path)
checkout = """      - name: Checkout repository
        uses: actions/checkout@v4

"""
checkout_with_gate = """      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Validate main architecture contracts
        run: |
          pwsh -NoProfile -NonInteractive -File ./scripts/audit/architecture_guard.ps1 -Strict
          python scripts/audit/documentation_parity.py
          python scripts/audit/repository_hygiene.py
          python scripts/audit/pocketbase_schema_contract.py
          python scripts/audit/deployment_contract.py

"""
if "Validate main architecture contracts" not in pb:
    if checkout not in pb:
        raise SystemExit("PocketBase validate checkout anchor missing")
    pb = pb.replace(checkout, checkout_with_gate, 1)
write(pb_path, pb)

contract_path = "scripts/audit/deployment_contract.py"
contract = read(contract_path)
contract = contract.replace(
    '        "find pb_hooks pb_migrations",\n',
    '        "find pb_hooks pb_migrations",\n        "Validate main architecture contracts",\n',
    1,
)
write(contract_path, contract)

deploy_path = "docs/DEPLOY.md"
deploy = read(deploy_path)
extra = """

**Main integrity gate:** Architecture Guard runs on PRs and on every `main` push. Independently, the PocketBase release workflow reruns strict architecture, documentation parity, repository hygiene, PocketBase schema, and deployment-order contracts before its server stage. Web publication is downstream of that successful workflow, so a structurally invalid direct push cannot be released even when repository branch-protection settings are unavailable.
"""
if "**Main integrity gate:**" not in deploy:
    marker = "### Production release ordering law"
    idx = deploy.find(marker)
    if idx < 0:
        deploy += extra
    else:
        deploy += extra
write(deploy_path, deploy)

print("main_integrity_gate: applied")
