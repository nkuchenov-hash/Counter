#!/usr/bin/env python3
"""Fail when live architecture/navigation docs drift from repository paths or durable contracts."""

from __future__ import annotations

import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

DOCS = (
    ROOT / "AGENTS.md",
    ROOT / "AGENT_NAVIGATION.md",
    ROOT / "docs" / "APP_STRUCTURE.md",
    ROOT / "docs" / "ARCHITECTURE.md",
    ROOT / "docs" / "ROADMAP.md",
    ROOT / "docs" / "UX_CONTRACT.md",
    ROOT / "docs" / "DESIGN_SYSTEM.md",
    ROOT / "docs" / "DATA_MAP.md",
    ROOT / "docs" / "POCKETBASE_MANIFEST.md",
    ROOT / "docs" / "DEPLOY.md",
    ROOT / "docs" / "CALENDAR_INTEGRATIONS.md",
    ROOT / "docs" / "NOTES_EDITOR_CONTRACT.md",
    ROOT / "docs" / "PATHS_V3_REALITY_CONTRACT.md",
    ROOT / "docs" / "SERVER_SLEEP_SYNC_DEPLOY.md",
    ROOT / "docs" / "PROJECT_KNOWLEDGE_PACK.md",
    ROOT / "docs" / "website" / "PRODUCT_INVENTORY.md",
)

SEMANTIC_CONTRACT_DOCS = (
    ROOT / "AGENTS.md",
    ROOT / "AGENT_NAVIGATION.md",
    ROOT / "docs" / "APP_STRUCTURE.md",
    ROOT / "docs" / "ARCHITECTURE.md",
)
SEMANTIC_CONTRACT_RULES = (
    ("STALE_PATH_ACTIVE_REVISION_FIELD", re.compile(r"\bactive_revision_id\b")),
    ("STALE_PLAN_BACKED_PATH_CONTRACT", re.compile(r"(?i)\bplan-backed\s+Path(?:s)?\b")),
)

PATH_PREFIXES = (
    "lib/",
    "docs/",
    "scripts/",
    ".github/",
    "android/",
    "ios/",
    "web/",
    "windows/",
    "linux/",
    "macos/",
    "installer/",
    "server/",
    "pb_migrations/",
    "igropoisk/",
    "test/",
)
ROOT_FILES = {
    "AGENTS.md",
    "AGENT_NAVIGATION.md",
    "CHANGELOG.md",
    "README.md",
    "pubspec.yaml",
    "analysis_options.yaml",
}
GENERATED_PATH_EXEMPTIONS = {
    "lib/core/env/env.dart",
}
GENERATED_OUTPUT_PREFIXES = (
    "build/",
    "android/build/",
    "ios/Pods/",
    "installer/windows/output/",
)
HISTORICAL_MARKERS = (
    "removed",
    "superseded",
    "historical",
    "older ref",
    "old location",
    "former path",
    "already gone",
    "deleted",
    "retired path",
    "renamed from",
    "moved from",
)

BACKTICK_RE = re.compile(r"`([^`]+)`")
APP_ROW_RE = re.compile(r"^\|\s*`([^`]+\.dart)`\s*\|")
DETAIL_FILE_HEADING_RE = re.compile(r"^###\s+`([^`]+)`\s*$", re.M)
DETAIL_TRACKED_COUNT_RE = re.compile(r"\*\*Tracked files:\*\*\s+(\d+)\b")


def _is_historical_line(line: str) -> bool:
    low = line.lower()
    return any(marker in low for marker in HISTORICAL_MARKERS)


def _normalize_reference(raw: str) -> str | None:
    value = raw.strip().strip(".,;:()[]{}")
    if not value:
        return None
    if "#" in value:
        value = value.split("#", 1)[0]
    value = value.split()[0]
    value = value.rstrip(".,;:")
    if not value or any(token in value for token in ("*", "…", "<", ">", "${")):
        return None
    if value.startswith("package:counter/"):
        value = "lib/" + value.removeprefix("package:counter/")
    if value.startswith(PATH_PREFIXES) or value in ROOT_FILES:
        return value
    return None


def _iter_live_lines(path: Path):
    skip_removed_section = False
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if path.name == "PROJECT_KNOWLEDGE_PACK.md" and line.startswith("## "):
            skip_removed_section = line.lower().startswith("## removed")
        if skip_removed_section or _is_historical_line(line):
            continue
        yield line_no, line


def _tracked_files() -> list[str]:
    output = subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True)
    return [line.strip().replace("\\", "/") for line in output.splitlines() if line.strip()]


def check_explicit_references() -> list[str]:
    issues: list[str] = []
    for doc in DOCS:
        if not doc.exists():
            issues.append(f"MISSING_GOVERNING_DOC {doc.relative_to(ROOT).as_posix()}")
            continue
        for line_no, line in _iter_live_lines(doc):
            for raw in BACKTICK_RE.findall(line):
                ref = _normalize_reference(raw)
                if ref is None or ref in GENERATED_PATH_EXEMPTIONS:
                    continue
                if any(ref.startswith(prefix) for prefix in GENERATED_OUTPUT_PREFIXES):
                    continue
                if not (ROOT / ref).exists():
                    rel = doc.relative_to(ROOT).as_posix()
                    issues.append(f"BROKEN_DOC_REF {rel}:{line_no} -> {ref}")
    return issues


def check_app_structure_reverse_manifest() -> list[str]:
    app = ROOT / "docs" / "APP_STRUCTURE.md"
    lib_files = [p.relative_to(ROOT / "lib").as_posix() for p in (ROOT / "lib").rglob("*.dart")]
    issues: list[str] = []
    exemptions = {"env.dart", "core/env/env.dart", "lib/core/env/env.dart"}
    for line_no, line in enumerate(app.read_text(encoding="utf-8").splitlines(), 1):
        match = APP_ROW_RE.match(line)
        if not match:
            continue
        declared = match.group(1).strip().lstrip("./")
        if declared in exemptions:
            continue
        candidates = [declared]
        if declared.startswith("lib/"):
            candidates.append(declared[4:])
        exists = any(
            actual == candidate or actual.endswith("/" + candidate)
            for actual in lib_files
            for candidate in candidates
        )
        if not exists:
            issues.append(f"STALE_APP_STRUCTURE_DART docs/APP_STRUCTURE.md:{line_no} -> {declared}")
    return issues


def check_detailed_structure_exact_manifest() -> list[str]:
    detailed = ROOT / "docs" / "APP_STRUCTURE_DETAILED.md"
    if not detailed.exists():
        return ["MISSING_DETAILED_STRUCTURE docs/APP_STRUCTURE_DETAILED.md"]

    body = detailed.read_text(encoding="utf-8")
    # The public marketing site is deployed alongside LIFE OS but is not part of
    # the application architecture manifest.
    tracked = [path for path in _tracked_files() if not path.startswith("marketing/")]
    tracked_set = set(tracked)
    rendered = DETAIL_FILE_HEADING_RE.findall(body)
    rendered_set = set(rendered)
    issues: list[str] = []

    duplicates = sorted(path for path, count in Counter(rendered).items() if count != 1)
    for path in duplicates:
        issues.append(f"DETAILED_DUPLICATE_FILE {path}")
    for path in sorted(tracked_set - rendered_set):
        issues.append(f"DETAILED_MISSING_TRACKED {path}")
    for path in sorted(rendered_set - tracked_set):
        issues.append(f"DETAILED_STALE_FILE {path}")

    header_match = DETAIL_TRACKED_COUNT_RE.search(body)
    if header_match is None:
        issues.append("DETAILED_TRACKED_COUNT_HEADER_MISSING")
    elif int(header_match.group(1)) != len(tracked):
        issues.append(
            f"DETAILED_TRACKED_COUNT_MISMATCH header={header_match.group(1)} actual={len(tracked)}"
        )
    if len(rendered) != len(tracked):
        issues.append(f"DETAILED_RENDER_COUNT_MISMATCH rendered={len(rendered)} actual={len(tracked)}")

    return issues


def check_semantic_contract_drift() -> list[str]:
    issues: list[str] = []
    for doc in SEMANTIC_CONTRACT_DOCS:
        if not doc.exists():
            continue
        rel = doc.relative_to(ROOT).as_posix()
        for line_no, line in _iter_live_lines(doc):
            for code, pattern in SEMANTIC_CONTRACT_RULES:
                if pattern.search(line):
                    issues.append(f"{code} {rel}:{line_no}")
    return issues


def main() -> int:
    issues = (
        check_explicit_references()
        + check_app_structure_reverse_manifest()
        + check_detailed_structure_exact_manifest()
        + check_semantic_contract_drift()
    )
    if issues:
        print("documentation_parity: FAIL")
        for issue in issues:
            print(f"  - {issue}")
        print(f"ISSUES={len(issues)}")
        return 1
    print("documentation_parity: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
