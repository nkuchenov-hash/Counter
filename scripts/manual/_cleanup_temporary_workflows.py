#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

for rel in (
    ".github/workflows/tmp-google-health-prod-check.yml",
    ".github/workflows/tmp-monitor-health-sleep-apk.yml",
):
    path = ROOT / rel
    if path.exists():
        path.unlink()

hygiene_path = ROOT / "scripts/audit/repository_hygiene.py"
hygiene = hygiene_path.read_text(encoding="utf-8-sig")
anchor = """    for path in files:
        if not path.startswith("lib/") or not path.endswith(".dart"):
            continue
"""
insert = """    for path in files:
        if path.startswith(".github/workflows/tmp-"):
            violations.append(f"TEMP_WORKFLOW_TRACKED {path}")

    for path in files:
        if not path.startswith("lib/") or not path.endswith(".dart"):
            continue
"""
if "TEMP_WORKFLOW_TRACKED" not in hygiene:
    if anchor not in hygiene:
        raise SystemExit("repository_hygiene workflow anchor missing")
    hygiene = hygiene.replace(anchor, insert)
hygiene_path.write_text(hygiene.rstrip() + "\n", encoding="utf-8", newline="\n")

print("temporary_workflow_cleanup: applied")
