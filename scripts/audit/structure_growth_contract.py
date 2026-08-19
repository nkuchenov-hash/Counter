#!/usr/bin/env python3
"""Fail when a change makes the Dart structure harder to decompose or workstation-coupled."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SELF_PATH = Path(__file__).resolve().relative_to(ROOT).as_posix()

BRAIN_PART_PREFIXES = (
    "lib/data/records/",
    "lib/data/plans/",
    "lib/data/paths/",
    "lib/data/categories/",
    "lib/data/profile/",
    "lib/data/local_sync/",
    "lib/data/models/",
    "lib/data/voice/",
)
DEFAULT_LIMIT = 1000
BRAIN_PART_LIMIT = 1500
GENERATED_DART_SUFFIXES = (".g.dart", ".freezed.dart")
WORKSTATION_PATH_RE = re.compile(
    r"(?i)(?:[A-Z]:[\\/]+Users[\\/]+[^\\/\s]+[\\/]+|/Users/[^/\s]+/|/home/[^/\s]+/)"
)
WORKSTATION_SCOPES = (
    "lib/",
    "scripts/",
    "installer/",
    ".github/",
    "pb_hooks/",
    "pb_migrations/",
)
ROOT_BUILD_FILES = {"update.ps1", "android.ps1"}


def git(*args: str, check: bool = True) -> str:
    proc = subprocess.run(
        ["git", *args], cwd=ROOT, text=True, capture_output=True, check=False
    )
    if check and proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"git {' '.join(args)} failed")
    return proc.stdout


def resolve_base(explicit: str | None) -> str | None:
    if explicit:
        return git("rev-parse", explicit).strip()

    configured = os.environ.get("STRUCTURE_GROWTH_BASE", "").strip()
    if configured:
        return git("rev-parse", configured).strip()

    event = os.environ.get("GITHUB_EVENT_NAME", "")
    base_ref = os.environ.get("GITHUB_BASE_REF", "").strip()
    if event == "pull_request" and base_ref:
        remote = f"origin/{base_ref}"
        git("fetch", "--no-tags", "--prune", "origin", base_ref, check=False)
        return git("merge-base", "HEAD", remote).strip()

    parent = git("rev-parse", "HEAD^", check=False).strip()
    if parent:
        return parent
    return None


def parse_changes(base: str) -> list[tuple[str, str | None, str]]:
    raw = git("diff", "--name-status", "-M", f"{base}...HEAD")
    changes: list[tuple[str, str | None, str]] = []
    for line in raw.splitlines():
        if not line.strip():
            continue
        cols = line.split("\t")
        status = cols[0]
        kind = status[0]
        if kind == "R" and len(cols) >= 3:
            changes.append((kind, cols[1], cols[2]))
        elif len(cols) >= 2:
            changes.append((kind, cols[1] if kind == "D" else None, cols[1]))
    return changes


def line_limit(path: str) -> int:
    if path.startswith(BRAIN_PART_PREFIXES):
        return BRAIN_PART_LIMIT
    return DEFAULT_LIMIT


def current_line_count(path: str) -> int | None:
    p = ROOT / path
    if not p.is_file():
        return None
    try:
        return len(p.read_text(encoding="utf-8", errors="replace").splitlines())
    except OSError:
        return None


def base_line_count(base: str, path: str | None) -> int | None:
    if not path:
        return None
    body = git("show", f"{base}:{path}", check=False)
    if not body:
        return None
    return len(body.splitlines())


def is_generated_dart(path: str) -> bool:
    return path.endswith(GENERATED_DART_SUFFIXES)


def added_lines(base: str, path: str) -> list[str]:
    diff = git("diff", "--unified=0", f"{base}...HEAD", "--", path, check=False)
    out: list[str] = []
    for line in diff.splitlines():
        if line.startswith("+++"):
            continue
        if line.startswith("+"):
            out.append(line[1:])
    return out


def scans_workstation_paths(path: str) -> bool:
    if path == SELF_PATH:
        return False
    return path in ROOT_BUILD_FILES or path.startswith(WORKSTATION_SCOPES)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", help="base commit/ref; defaults to PR base merge-base or HEAD^")
    args = parser.parse_args()

    try:
        base = resolve_base(args.base)
    except RuntimeError as exc:
        print(f"structure_growth_contract: FAIL\n  - BASE_RESOLUTION {exc}", file=sys.stderr)
        return 1

    if not base:
        print("structure_growth_contract: OK (no comparison baseline available)")
        return 0

    violations: list[str] = []
    changes = parse_changes(base)

    for status, old_path, path in changes:
        if status == "D" or not path.endswith(".dart") or is_generated_dart(path):
            continue
        current = current_line_count(path)
        if current is None:
            continue
        limit = line_limit(path)
        previous = base_line_count(base, old_path if status == "R" else path)

        if status == "A" or previous is None:
            if current > limit:
                violations.append(
                    f"NEW_DART_EXCEEDS_LIMIT {path} lines={current} limit={limit}"
                )
            continue

        if previous <= limit < current:
            violations.append(
                f"DART_CROSSED_SIZE_LIMIT {path} before={previous} after={current} limit={limit}"
            )
        elif previous > limit and current > previous:
            violations.append(
                f"OVERSIZE_DART_GREW {path} before={previous} after={current} limit={limit}"
            )

    for status, _old_path, path in changes:
        if status == "D" or not scans_workstation_paths(path):
            continue
        for line in added_lines(base, path):
            if WORKSTATION_PATH_RE.search(line):
                violations.append(f"WORKSTATION_PATH_ADDED {path}: {line.strip()[:180]}")
                break

    if violations:
        print("structure_growth_contract: FAIL", file=sys.stderr)
        for violation in violations:
            print(f"  - {violation}", file=sys.stderr)
        print(f"VIOLATIONS={len(violations)}", file=sys.stderr)
        return 1

    print(f"structure_growth_contract: OK base={base[:12]} changed={len(changes)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
