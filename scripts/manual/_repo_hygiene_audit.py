#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def tracked() -> list[str]:
    return subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True).splitlines()


def readable_text(path: Path) -> str | None:
    try:
        data = path.read_bytes()
    except OSError:
        return None
    if b"\x00" in data[:8192]:
        return None
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return None


files = tracked()
tracked_set = set(files)

# Import the canonical watchlist without duplicating it here.
import sys
sys.path.insert(0, str(ROOT / "scripts" / "manual"))
from structure_evidence_index import WATCHLIST_PATHS  # noqa: E402

print("=== TRACKED WATCHLIST ===")
for target, reason in WATCHLIST_PATHS.items():
    if target not in tracked_set:
        continue
    target_path = ROOT / target
    size = target_path.stat().st_size
    needle_full = target.replace("\\", "/")
    needle_pkg = "package:counter/" + needle_full.removeprefix("lib/")
    basename = Path(target).name
    refs: list[str] = []
    code_refs: list[str] = []
    for p in files:
        if p == target or p in {
            "docs/APP_STRUCTURE_DETAILED.md",
            "scripts/manual/structure_evidence_index.py",
            "scripts/manual/_repo_hygiene_audit.py",
        }:
            continue
        text = readable_text(ROOT / p)
        if text is None:
            continue
        hit = needle_full in text or needle_pkg in text
        # For Dart import/export/part references, basename is sufficient and catches relatives.
        if not hit and p.endswith(".dart") and basename in text:
            hit = True
        if hit:
            refs.append(p)
            if p.endswith((".dart", ".yaml", ".yml", ".ps1", ".rs", ".kt", ".swift", ".cpp", ".h")):
                code_refs.append(p)
    print(json.dumps({
        "path": target,
        "size": size,
        "reason": reason,
        "code_refs": code_refs,
        "all_refs": refs,
    }, ensure_ascii=False))

print("=== LARGE TRACKED FILES >= 50 KB ===")
large = []
for p in files:
    path = ROOT / p
    try:
        size = path.stat().st_size
    except OSError:
        continue
    if size >= 50_000:
        large.append((size, p))
for size, p in sorted(large, reverse=True):
    print(json.dumps({"path": p, "size": size}, ensure_ascii=False))

print("=== LARGE BINARIES >= 1 MB ===")
for size, p in sorted(large, reverse=True):
    if size < 1_000_000:
        continue
    if readable_text(ROOT / p) is None:
        print(json.dumps({"path": p, "size": size}, ensure_ascii=False))
