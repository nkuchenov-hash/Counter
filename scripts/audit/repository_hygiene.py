#!/usr/bin/env python3
"""Repository hygiene gate: reject orphan aliases and accidental huge tracked binaries."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]
DART_EDGE_RE = re.compile(r"^\s*(?:import|export|part)\s+['\"]([^'\"]+)['\"]", re.M)
EXPORT_STMT_RE = re.compile(r"export\s+['\"][^'\"]+['\"][^;]*;", re.S)
MAX_BINARY_BYTES = 5_000_000
LARGE_BINARY_ALLOWLIST: dict[str, str] = {
    "installer/windows/stt_helper_build/counter_stt_helper.exe": (
        "Required offline desktop-voice HTTP sidecar. Keep tracked until its source/artifact "
        "pipeline is reproducible independently of a developer workstation."
    ),
}
BINARY_SUFFIXES = {
    ".exe", ".dll", ".so", ".dylib", ".wav", ".mp3", ".mp4", ".png", ".jpg",
    ".jpeg", ".webp", ".ico", ".jar", ".zip", ".7z", ".pdf",
}


def git_files() -> list[str]:
    return subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True).splitlines()


def text(path: Path) -> str | None:
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


def resolve_edge(source: str, uri: str) -> str | None:
    if uri.startswith("dart:") or "://" in uri:
        return None
    if uri.startswith("package:counter/"):
        return "lib/" + uri.removeprefix("package:counter/")
    if uri.startswith("package:"):
        return None
    return str(PurePosixPath(source).parent.joinpath(uri))


def pure_reexport(source: str) -> bool:
    cleaned = re.sub(r"//.*", "", source)
    cleaned = re.sub(r"/\*.*?\*/", "", cleaned, flags=re.S)
    if "export" not in cleaned:
        return False
    return not EXPORT_STMT_RE.sub("", cleaned).strip()


def main() -> int:
    files = git_files()
    incoming: dict[str, set[str]] = {}
    violations: list[str] = []

    for source in files:
        if not source.endswith(".dart"):
            continue
        body = text(ROOT / source)
        if body is None:
            continue
        for uri in DART_EDGE_RE.findall(body):
            target = resolve_edge(source, uri)
            if target:
                incoming.setdefault(target, set()).add(source)

    for path in files:
        if path.startswith(".github/workflows/tmp-"):
            violations.append(f"TEMP_WORKFLOW_TRACKED {path}")

    for path in files:
        if not path.startswith("lib/") or not path.endswith(".dart"):
            continue
        body = text(ROOT / path)
        if body is not None and pure_reexport(body) and not incoming.get(path):
            violations.append(f"ORPHAN_REEXPORT {path}")

    for path in files:
        p = ROOT / path
        try:
            size = p.stat().st_size
        except OSError:
            continue
        if size <= MAX_BINARY_BYTES:
            continue
        is_binary = p.suffix.lower() in BINARY_SUFFIXES or text(p) is None
        if not is_binary:
            continue
        if path not in LARGE_BINARY_ALLOWLIST:
            violations.append(f"UNAPPROVED_LARGE_BINARY {path} bytes={size}")

    # Watchlist metadata itself must never point to files that no longer exist.
    sys.path.insert(0, str(ROOT / "scripts" / "manual"))
    from structure_evidence_index import WATCHLIST_PATHS  # noqa: PLC0415

    tracked = set(files)
    for path in WATCHLIST_PATHS:
        if path not in tracked:
            violations.append(f"STALE_WATCHLIST_PATH {path}")

    if violations:
        print("repository_hygiene: FAIL", file=sys.stderr)
        for item in violations:
            print(f"  - {item}", file=sys.stderr)
        return 1

    for path, reason in LARGE_BINARY_ALLOWLIST.items():
        if path in tracked:
            size = (ROOT / path).stat().st_size
            print(f"allowed_large_binary: {path} bytes={size} reason={reason}")
    print("repository_hygiene: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
