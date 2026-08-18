#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]
DART_EDGE_RE = re.compile(r"^\s*(?:import|export|part)\s+['\"]([^'\"]+)['\"]", re.M)


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


def resolve_dart_edge(source: str, uri: str) -> str | None:
    if uri.startswith("dart:") or "://" in uri:
        return None
    if uri.startswith("package:counter/"):
        return "lib/" + uri.removeprefix("package:counter/")
    if uri.startswith("package:"):
        return None
    return str(PurePosixPath(source).parent.joinpath(uri))


files = tracked()
tracked_set = set(files)

incoming: dict[str, list[str]] = {}
for source in files:
    if not source.endswith(".dart"):
        continue
    text = readable_text(ROOT / source)
    if text is None:
        continue
    for uri in DART_EDGE_RE.findall(text):
        target = resolve_dart_edge(source, uri)
        if target:
            incoming.setdefault(target, []).append(source)

sys.path.insert(0, str(ROOT / "scripts" / "manual"))
from structure_evidence_index import WATCHLIST_PATHS  # noqa: E402

print("=== TRACKED WATCHLIST EXACT DART INCOMING ===")
for target, reason in WATCHLIST_PATHS.items():
    if target not in tracked_set:
        continue
    size = (ROOT / target).stat().st_size
    exact_incoming = sorted(set(incoming.get(target, [])))
    refs: list[str] = []
    needle_full = target.replace("\\", "/")
    needle_pkg = "package:counter/" + needle_full.removeprefix("lib/")
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
        if needle_full in text or needle_pkg in text:
            refs.append(p)
    print(json.dumps({"path": target, "size": size, "reason": reason,
                      "dart_incoming": exact_incoming, "literal_refs": refs}, ensure_ascii=False))

print("=== LARGE TRACKED FILES >= 50 KB ===")
large: list[tuple[int, str]] = []
for p in files:
    try:
        size = (ROOT / p).stat().st_size
    except OSError:
        continue
    if size >= 50_000:
        large.append((size, p))
for size, p in sorted(large, reverse=True):
    print(json.dumps({"path": p, "size": size}, ensure_ascii=False))

print("=== LARGE BINARIES >= 500 KB WITH TEXT REFS ===")
for size, p in sorted(large, reverse=True):
    if size < 500_000 or readable_text(ROOT / p) is not None:
        continue
    refs: list[str] = []
    base = Path(p).name
    for other in files:
        if other == p or other in {"docs/APP_STRUCTURE_DETAILED.md", "scripts/manual/_repo_hygiene_audit.py"}:
            continue
        text = readable_text(ROOT / other)
        if text is None:
            continue
        if p in text or base in text:
            refs.append(other)
    print(json.dumps({"path": p, "size": size, "refs": refs}, ensure_ascii=False))
