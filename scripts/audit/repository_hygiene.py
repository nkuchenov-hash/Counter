#!/usr/bin/env python3
"""Repository hygiene + structure-growth ratchet for current and future repo changes."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]
SELF_PATH = Path(__file__).resolve().relative_to(ROOT).as_posix()
DART_EDGE_RE = re.compile(r"^\s*(?:import|export|part)\s+['\"]([^'\"]+)['\"]", re.M)
EXPORT_STMT_RE = re.compile(r"export\s+['\"][^'\"]+['\"][^;]*;", re.S)
MAX_BINARY_BYTES = 5_000_000
BINARY_SUFFIXES = {
    ".exe", ".dll", ".so", ".dylib", ".wav", ".mp3", ".mp4", ".png", ".jpg",
    ".jpeg", ".webp", ".ico", ".jar", ".zip", ".7z", ".pdf",
}
STT_BINARY_PATH = "installer/windows/stt_helper_build/counter_stt_helper.exe"
STT_MANIFEST_PATH = "installer/windows/stt_helper_artifact.json"
STT_ASSET_NAME = "counter_stt_helper.exe"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")

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
DEFAULT_DART_LINE_LIMIT = 1000
BRAIN_PART_LINE_LIMIT = 1500
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


def git_files() -> list[str]:
    return git("ls-files").splitlines()


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


def resolve_growth_base() -> str | None:
    configured = os.environ.get("STRUCTURE_GROWTH_BASE", "").strip()
    if configured and not re.fullmatch(r"0+", configured):
        resolved = git("rev-parse", configured, check=False).strip()
        if resolved:
            return resolved

    event_path = os.environ.get("GITHUB_EVENT_PATH", "").strip()
    if event_path:
        try:
            event_payload = json.loads(Path(event_path).read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            event_payload = {}
        before = str(event_payload.get("before") or "").strip()
        if before and not re.fullmatch(r"0+", before):
            resolved = git("rev-parse", before, check=False).strip()
            if resolved:
                return resolved

    event = os.environ.get("GITHUB_EVENT_NAME", "")
    base_ref = os.environ.get("GITHUB_BASE_REF", "").strip()
    if event == "pull_request" and base_ref:
        remote = f"origin/{base_ref}"
        git("fetch", "--no-tags", "--prune", "origin", base_ref, check=False)
        merge_base = git("merge-base", "HEAD", remote, check=False).strip()
        if merge_base:
            return merge_base

    parent = git("rev-parse", "HEAD^", check=False).strip()
    return parent or None


def parse_changes(base: str) -> list[tuple[str, str | None, str]]:
    raw = git("diff", "--name-status", "-M", f"{base}...HEAD")
    changes: list[tuple[str, str | None, str]] = []
    for line in raw.splitlines():
        if not line.strip():
            continue
        cols = line.split("\t")
        kind = cols[0][0]
        if kind == "R" and len(cols) >= 3:
            changes.append((kind, cols[1], cols[2]))
        elif len(cols) >= 2:
            changes.append((kind, cols[1] if kind == "D" else None, cols[1]))
    return changes


def dart_line_limit(path: str) -> int:
    return BRAIN_PART_LINE_LIMIT if path.startswith(BRAIN_PART_PREFIXES) else DEFAULT_DART_LINE_LIMIT


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


def added_lines(base: str, path: str) -> list[str]:
    diff = git("diff", "--unified=0", f"{base}...HEAD", "--", path, check=False)
    return [
        line[1:]
        for line in diff.splitlines()
        if line.startswith("+") and not line.startswith("+++")
    ]


def scans_workstation_paths(path: str) -> bool:
    if path == SELF_PATH:
        return False
    return path in ROOT_BUILD_FILES or path.startswith(WORKSTATION_SCOPES)


def check_structure_growth(violations: list[str]) -> tuple[str | None, int]:
    try:
        base = resolve_growth_base()
    except RuntimeError as exc:
        violations.append(f"STRUCTURE_GROWTH_BASE_RESOLUTION {exc}")
        return None, 0
    if not base:
        return None, 0

    changes = parse_changes(base)
    for status, old_path, path in changes:
        if (
            status == "D"
            or not path.endswith(".dart")
            or path.endswith(GENERATED_DART_SUFFIXES)
        ):
            continue
        current = current_line_count(path)
        if current is None:
            continue
        limit = dart_line_limit(path)
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

    return base, len(changes)


def check_stt_artifact_contract(tracked: set[str], violations: list[str]) -> None:
    if STT_BINARY_PATH in tracked:
        violations.append(f"TRACKED_STT_BINARY_FORBIDDEN {STT_BINARY_PATH}")

    manifest_path = ROOT / STT_MANIFEST_PATH
    if STT_MANIFEST_PATH not in tracked or not manifest_path.is_file():
        violations.append(f"MISSING_STT_ARTIFACT_MANIFEST {STT_MANIFEST_PATH}")
        return

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        violations.append(f"INVALID_STT_ARTIFACT_MANIFEST {STT_MANIFEST_PATH}: {exc}")
        return

    if manifest.get("schema_version") != 1:
        violations.append("STT_ARTIFACT_SCHEMA_VERSION must equal 1")
    tag = manifest.get("release_tag")
    if not isinstance(tag, str) or not tag.startswith("counter-stt-helper-artifact-"):
        violations.append(f"INVALID_STT_ARTIFACT_RELEASE_TAG {tag!r}")
    if manifest.get("asset_name") != STT_ASSET_NAME:
        violations.append(f"INVALID_STT_ARTIFACT_ASSET_NAME {manifest.get('asset_name')!r}")
    digest = manifest.get("sha256")
    if not isinstance(digest, str) or not SHA256_RE.fullmatch(digest):
        violations.append(f"INVALID_STT_ARTIFACT_SHA256 {digest!r}")
    size = manifest.get("size_bytes")
    if not isinstance(size, int) or size <= MAX_BINARY_BYTES:
        violations.append(f"INVALID_STT_ARTIFACT_SIZE {size!r}")


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
        if path.startswith("lib/") and "compatibility" in PurePosixPath(path).parts:
            violations.append(f"RUNTIME_COMPATIBILITY_DIR {path}")

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
        if is_binary:
            violations.append(f"UNAPPROVED_LARGE_BINARY {path} bytes={size}")

    sys.path.insert(0, str(ROOT / "scripts" / "manual"))
    from structure_evidence_index import WATCHLIST_PATHS  # noqa: PLC0415

    tracked = set(files)
    for path in WATCHLIST_PATHS:
        if path not in tracked:
            violations.append(f"STALE_WATCHLIST_PATH {path}")

    check_stt_artifact_contract(tracked, violations)
    growth_base, changed_count = check_structure_growth(violations)

    if violations:
        print("repository_hygiene: FAIL", file=sys.stderr)
        for item in violations:
            print(f"  - {item}", file=sys.stderr)
        print(f"VIOLATIONS={len(violations)}", file=sys.stderr)
        return 1

    if growth_base:
        print(f"structure_growth: OK base={growth_base[:12]} changed={changed_count}")
    else:
        print("structure_growth: OK no comparison baseline available")
    print("stt_artifact_contract: OK")
    print("repository_hygiene: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
