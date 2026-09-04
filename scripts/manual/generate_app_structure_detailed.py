#!/usr/bin/env python3
"""Generate owner-readable docs/APP_STRUCTURE_DETAILED.md — unique per file/folder."""

from __future__ import annotations

import re
import subprocess
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date
from pathlib import Path, PurePosixPath

from structure_guide_data import (
    BAD_PHRASES,
    BANNED_EN_PHRASES,
    BANNED_FOLDER_PHRASES,
    BANNED_RU_PHRASES,
    FOLDERS,
    infer_folder_guide,
    platform_file_description,
)
from structure_en_ru_adapt import (
    adapt_file_guide_ru,
    BANNED_MEANINGLESS_RU_FILLER,
    has_banned_filler,
    ru_field_ok,
)
from structure_ru_class_adapters import BANNED_ENGLISH_IN_RU, BANNED_GENERIC_RU_WRAPPERS, BANNED_GENERIC_PLATFORM_WRAPPERS, BANNED_GENERIC_DOC_WRAPPERS, BANNED_SEMI_RUSSIAN_WRAPPERS, has_semi_russian_or_english_leak
from structure_file_ru_curated import FILE_RU_CURATED
from structure_role_guides import humanize_guide
from structure_root_guides import ROOT_FILE_GUIDES
from structure_ru_helpers import cyrillic_count, delete_en_to_ru, looks_english_prose
from structure_evidence_index import (
    VALID_CONFIDENCE,
    VALID_NECESSITY,
    EvidenceIndex,
    EvidenceRecord,
    build_evidence_index,
    format_evidence_block,
    WATCHLIST_PATHS,
    HYGIENE_AUDIT,
)

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "APP_STRUCTURE_DETAILED.md"
APP_STRUCTURE = ROOT / "docs" / "APP_STRUCTURE.md"

SYMBOL_RE = re.compile(
    r"^(?:abstract\s+(?:final\s+)?class|class|enum|extension|mixin|typedef)\s+(\w+)"
    r"|^void\s+main\s*\(",
    re.M,
)
EXPORT_RE = re.compile(r"^export\s+'([^']+)'", re.M)
DETAIL_FILE_ROW_RE = re.compile(r"^\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*$")

RU_FOLDER_REQUIRED_PREFIXES: tuple[str, ...] = (
    "- **Что это за папка:**",
    "- **Зачем нужна:**",
    "- **Что здесь лежит:**",
    "- **На что влияет в приложении:**",
)

GENERIC_EN_MARKERS: tuple[str, ...] = (
    "Fulfill the documented role",
    "required for current app behavior",
    "documented workflow",
    "see source file",
    "Source file `",
    "Dart source `",
    "for the Life OS repository",
    "possibly useful",
    "support file",
    "used by the app",
    "cannot be deleted",
    "matching files under lib",
    "nearby files",
)

BANNED_EN_WRAPPER_IN_RU: tuple[str, ...] = (
    "Fulfill the documented role",
    "Source file",
    "Role:",
    "required for current app behavior",
)

BANNED_EN_IN_RU: tuple[str, ...] = BANNED_EN_WRAPPER_IN_RU + BANNED_GENERIC_PLATFORM_WRAPPERS + BANNED_GENERIC_DOC_WRAPPERS + (
    "implementation details in the source file",
    "required for ",
    "if macOS builds are kept",
    "required for iOS CocoaPods workflow",
    "required for native/web builds",
    "Android APK build or permission issues",
    "if Windows desktop is supported",
    "safe for app",
    "used by debug/profile builds",
    "documents required env.dart structure",
    "features depend on these widgets",
)
TABLE_ROW_RE = re.compile(r"^\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|")
FEATURE_FOLDER_ROW_RE = re.compile(r"^\|\s*`([^`]+)/`\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*$")

RU_REQUIRED_PREFIXES: tuple[str, ...] = (
    "- **Что это:**",
    "- **Зачем:**",
    "- **Содержимое:**",
    "- **Обязанности:**",
    "- **Связано с:**",
)


def ru_line_value(line: str, prefix: str) -> str:
    """Value after a RU bullet prefix (avoid false non-empty from markdown ``**``)."""
    if not line.startswith(prefix):
        return ""
    return line[len(prefix) :].strip()


def is_generic_en(text: str) -> bool:
    if not text:
        return False
    return any(m in text for m in GENERIC_EN_MARKERS)


@dataclass
class FileGuide:
    what: str
    why: str
    contains: str
    responsibilities: str
    when: str
    delete: str
    connected: str
    layer: str
    what_ru: str = ""
    why_ru: str = ""
    contains_ru: str = ""
    responsibilities_ru: str = ""
    when_ru: str = ""
    delete_ru: str = ""
    connected_ru: str = ""
    layer_ru: str = ""
    # Evidence-backed fields (filled by enrich_with_evidence)
    repo_role: str = ""
    evidence_en: str = ""
    evidence_ru: str = ""
    necessity: str = ""
    deletion_consequence_en: str = ""
    deletion_consequence_ru: str = ""
    confidence: str = ""
    owner_en: str = ""
    owner_ru: str = ""


# Global evidence index set in main() before rendering.
EVIDENCE: EvidenceIndex | None = None


def tracked() -> list[str]:
    out = subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True)
    return sorted(
        path
        for line in out.splitlines()
        if (path := line.strip().replace("\\", "/"))
        and not path.startswith("marketing/")
    )


def sha() -> str:
    return subprocess.check_output(
        ["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True
    ).strip()


def symbols(path: str) -> list[str]:
    p = ROOT / path
    if not p.is_file() or not path.endswith(".dart"):
        return []
    try:
        text = p.read_text(encoding="utf-8")[:12000]
    except OSError:
        return []
    found: list[str] = []
    for m in SYMBOL_RE.finditer(text):
        name = m.group(1)
        if name and name not in found:
            found.append(name)
        if m.group(0).startswith("void main"):
            found.append("main")
    return found[:10]


def dart_exports(path: str) -> list[str]:
    p = ROOT / path
    if not p.is_file() or not path.endswith(".dart"):
        return []
    try:
        text = p.read_text(encoding="utf-8")[:12000]
    except OSError:
        return []
    return EXPORT_RE.findall(text)[:12]


def _first_nonempty(*values: str) -> str:
    return next((value for value in values if value.strip()), "")


def _parse_app_structure() -> tuple[dict[str, str], dict[str, str], dict[str, str]]:
    """Return file, folder, and feature-domain guides extracted from APP_STRUCTURE."""
    text = APP_STRUCTURE.read_text(encoding="utf-8")
    files: dict[str, str] = {}
    folders: dict[str, str] = {}
    features: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip()
        match = TABLE_ROW_RE.match(line)
        if match:
            key = match.group(1).strip().strip("/")
            description = match.group(2).strip()
            if key.endswith((".dart", ".md", ".yml", ".yaml", ".json", ".ps1", ".py", ".sh", ".html", ".xml", ".plist", ".gradle", ".kts", ".toml", ".txt", ".iss", ".lock")):
                files[key] = description
            elif key:
                folders[key] = description
        feature_match = FEATURE_FOLDER_ROW_RE.match(line)
        if feature_match:
            features[feature_match.group(1).strip()] = feature_match.group(3).strip()
    return files, folders, features


APP_FILE_GUIDES, APP_FOLDER_GUIDES, APP_FEATURE_GUIDES = _parse_app_structure()


def _path_candidates(path: str) -> list[str]:
    p = PurePosixPath(path)
    candidates = [path]
    if path.startswith("lib/"):
        candidates.append(path[4:])
    candidates.append(p.name)
    return candidates


def _folder_candidates(path: str) -> list[str]:
    p = PurePosixPath(path)
    parents = [str(parent) for parent in p.parents if str(parent) != "."]
    out: list[str] = []
    for parent in parents:
        out.append(parent)
        if parent.startswith("lib/"):
            out.append(parent[4:])
    return out


def app_description(path: str) -> str:
    for candidate in _path_candidates(path):
        if candidate in APP_FILE_GUIDES:
            return APP_FILE_GUIDES[candidate]
    for candidate in _folder_candidates(path):
        if candidate in APP_FOLDER_GUIDES:
            return APP_FOLDER_GUIDES[candidate]
    parts = PurePosixPath(path).parts
    if len(parts) >= 3 and parts[0] == "lib" and parts[1] == "features":
        feature = parts[2]
        if feature in APP_FEATURE_GUIDES:
            return APP_FEATURE_GUIDES[feature]
    return ""


def _folder_guide(path: str) -> str:
    for candidate in _folder_candidates(path) + [path.strip("/")]:
        if candidate in APP_FOLDER_GUIDES:
            return APP_FOLDER_GUIDES[candidate]
    parts = PurePosixPath(path).parts
    if len(parts) >= 3 and parts[0] == "lib" and parts[1] == "features":
        return APP_FEATURE_GUIDES.get(parts[2], "")
    return ""


def _default_file_guide(path: str) -> FileGuide:
    role = app_description(path)
    platform = platform_file_description(path)
    base = _first_nonempty(role, platform, "Repository file with a project-specific role.")
    p = PurePosixPath(path)
    parent_role = _folder_guide(str(p.parent))
    return FileGuide(
        what=base,
        why=_first_nonempty(role, parent_role, "Supports the repository behavior represented by this path."),
        contains=_first_nonempty(platform, role, f"Implementation or configuration stored in `{p.name}`."),
        responsibilities=_first_nonempty(role, platform, "Owns the responsibilities documented for this repository path."),
        when=f"Change this file when work explicitly targets `{path}` or its documented owner.",
        delete=f"Delete only after every live reference and responsibility of `{path}` has moved or been retired.",
        connected=_first_nonempty(parent_role, role, "Nearby files in the same owned layer."),
        layer=_first_nonempty(parent_role, role, str(p.parent)),
    )


def guide_for(path: str) -> FileGuide:
    curated = ROOT_FILE_GUIDES.get(path)
    if curated is not None:
        return curated
    guide = _default_file_guide(path)
    return humanize_guide(path, guide)


def enrich_with_evidence(path: str, guide: FileGuide) -> FileGuide:
    if EVIDENCE is None:
        return guide
    record = EVIDENCE.files.get(path)
    if record is None:
        return guide
    guide.repo_role = record.repo_role
    guide.evidence_en = format_evidence_block(record, locale="en")
    guide.evidence_ru = format_evidence_block(record, locale="ru")
    guide.necessity = record.necessity
    guide.deletion_consequence_en = record.deletion_consequence_en
    guide.deletion_consequence_ru = record.deletion_consequence_ru
    guide.confidence = record.confidence
    guide.owner_en = record.owner_en
    guide.owner_ru = record.owner_ru
    return guide


def _field(guide: FileGuide, name: str, fallback: str) -> str:
    value = getattr(guide, name, "")
    return value.strip() if value and value.strip() else fallback


def _ru_field(guide: FileGuide, name: str, fallback: str) -> str:
    value = getattr(guide, name, "")
    return value.strip() if value and value.strip() else fallback


def file_block(path: str) -> str:
    guide = enrich_with_evidence(path, guide_for(path))
    fallback = app_description(path) or f"Repository file `{path}`."
    what = _field(guide, "what", fallback)
    why = _field(guide, "why", fallback)
    contains = _field(guide, "contains", fallback)
    responsibilities = _field(guide, "responsibilities", fallback)
    when = _field(guide, "when", f"Change when work targets `{path}`.")
    delete = _field(guide, "delete", f"Delete only after `{path}` is no longer referenced or responsible for live behavior.")
    connected = _field(guide, "connected", str(PurePosixPath(path).parent))
    layer = _field(guide, "layer", str(PurePosixPath(path).parent))

    what_ru = _ru_field(guide, "what_ru", what)
    why_ru = _ru_field(guide, "why_ru", why)
    contains_ru = _ru_field(guide, "contains_ru", contains)
    responsibilities_ru = _ru_field(guide, "responsibilities_ru", responsibilities)
    when_ru = _ru_field(guide, "when_ru", when)
    delete_ru = _ru_field(guide, "delete_ru", delete)
    connected_ru = _ru_field(guide, "connected_ru", connected)
    layer_ru = _ru_field(guide, "layer_ru", layer)

    symbols_found = symbols(path)
    exports_found = dart_exports(path)
    symbols_text = ", ".join(f"`{symbol}`" for symbol in symbols_found) or "—"
    exports_text = ", ".join(f"`{export}`" for export in exports_found) or "—"

    lines = [
        f"### `{path}`",
        "",
        f"- **What it is:** {what}",
        f"- **Why it exists:** {why}",
        f"- **Contains:** {contains}",
        f"- **Responsibilities:** {responsibilities}",
        f"- **Change when:** {when}",
        f"- **Delete when:** {delete}",
        f"- **Connected to:** {connected}",
        f"- **Layer / owner:** {layer}",
        f"- **Symbols:** {symbols_text}",
        f"- **Dart exports:** {exports_text}",
        "",
        f"- **Что это:** {what_ru}",
        f"- **Зачем:** {why_ru}",
        f"- **Содержимое:** {contains_ru}",
        f"- **Обязанности:** {responsibilities_ru}",
        f"- **Когда менять:** {when_ru}",
        f"- **Когда удалять:** {delete_ru}",
        f"- **Связано с:** {connected_ru}",
        f"- **Слой / владелец:** {layer_ru}",
    ]
    if guide.repo_role:
        lines += ["", f"- **Repo role:** {guide.repo_role}"]
    if guide.evidence_en:
        lines += [f"- **Evidence:** {guide.evidence_en}"]
    if guide.necessity:
        lines += [f"- **Necessity:** {guide.necessity}"]
    if guide.deletion_consequence_en:
        lines += [f"- **Deletion consequence:** {guide.deletion_consequence_en}"]
    if guide.confidence:
        lines += [f"- **Confidence:** {guide.confidence}"]
    if guide.owner_en:
        lines += [f"- **Owner evidence:** {guide.owner_en}"]
    if guide.evidence_ru:
        lines += [f"- **Доказательства:** {guide.evidence_ru}"]
    if guide.deletion_consequence_ru:
        lines += [f"- **Последствия удаления:** {guide.deletion_consequence_ru}"]
    if guide.owner_ru:
        lines += [f"- **Подтверждение владельца:** {guide.owner_ru}"]
    return "\n".join(lines)


def _folder_description(path: str) -> str:
    direct = APP_FOLDER_GUIDES.get(path.strip("/"))
    if direct:
        return direct
    feature = PurePosixPath(path).parts
    if len(feature) >= 3 and feature[0] == "lib" and feature[1] == "features":
        desc = APP_FEATURE_GUIDES.get(feature[2])
        if desc:
            return desc
    return infer_folder_guide(path)


def folder_block(path: str, child_files: list[str], child_dirs: list[str]) -> str:
    guide = _folder_description(path)
    files_preview = ", ".join(f"`{PurePosixPath(f).name}`" for f in child_files[:8]) or "—"
    dirs_preview = ", ".join(f"`{PurePosixPath(d).name}/`" for d in child_dirs[:8]) or "—"
    return "\n".join(
        [
            f"## `{path}/`",
            "",
            f"- **What this folder is:** {guide}",
            f"- **Why it exists:** {guide}",
            f"- **What lives here:** files {files_preview}; folders {dirs_preview}",
            f"- **What it affects:** {guide}",
            "",
            f"- **Что это за папка:** {guide}",
            f"- **Зачем нужна:** {guide}",
            f"- **Что здесь лежит:** файлы {files_preview}; папки {dirs_preview}",
            f"- **На что влияет в приложении:** {guide}",
        ]
    )


def build_tree(files: list[str]) -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    dir_files: dict[str, list[str]] = defaultdict(list)
    dir_dirs: dict[str, set[str]] = defaultdict(set)
    for file_path in files:
        p = PurePosixPath(file_path)
        parent = str(p.parent)
        if parent == ".":
            parent = ""
        dir_files[parent].append(file_path)
        parts = p.parts[:-1]
        for idx in range(len(parts)):
            parent_dir = "/".join(parts[:idx])
            child_dir = "/".join(parts[: idx + 1])
            dir_dirs[parent_dir].add(child_dir)
    return (
        {key: sorted(value) for key, value in dir_files.items()},
        {key: sorted(value) for key, value in dir_dirs.items()},
    )


def _validate_file_block(path: str, block: str) -> list[str]:
    issues: list[str] = []
    if is_generic_en(block):
        issues.append(f"GENERIC_EN {path}")
    for marker in BANNED_EN_IN_RU:
        if marker in block:
            issues.append(f"ENGLISH_IN_RU {path} -> {marker}")
    for marker in BANNED_SEMI_RUSSIAN_WRAPPERS:
        if marker in block:
            issues.append(f"SEMI_RU_WRAPPER {path} -> {marker}")
    if has_semi_russian_or_english_leak(block):
        issues.append(f"RU_EN_LEAK {path}")
    for marker in BANNED_MEANINGLESS_RU_FILLER:
        if marker in block:
            issues.append(f"MEANINGLESS_RU {path} -> {marker}")
    for prefix in RU_REQUIRED_PREFIXES:
        line = next((ln for ln in block.splitlines() if ln.startswith(prefix)), "")
        value = ru_line_value(line, prefix)
        if not ru_field_ok(value):
            issues.append(f"BAD_RU_FIELD {path} {prefix}")
    return issues


def validate_rendered(body: str, files: list[str]) -> None:
    problems: list[str] = []
    rendered_files = re.findall(r"^###\s+`([^`]+)`\s*$", body, re.M)
    duplicates = [path for path, count in Counter(rendered_files).items() if count != 1]
    missing = sorted(set(files) - set(rendered_files))
    stale = sorted(set(rendered_files) - set(files))
    if duplicates:
        problems += [f"DUPLICATE {path}" for path in duplicates]
    if missing:
        problems += [f"MISSING {path}" for path in missing]
    if stale:
        problems += [f"STALE {path}" for path in stale]
    for path in rendered_files:
        match = re.search(
            rf"^###\s+`{re.escape(path)}`\s*$\n(?P<body>.*?)(?=^###\s+`|^##\s+`|\Z)",
            body,
            re.M | re.S,
        )
        if match:
            problems += _validate_file_block(path, match.group("body"))
    if problems:
        print("APP_STRUCTURE_DETAILED validation failed:", file=sys.stderr)
        for problem in problems[:120]:
            print(f"  - {problem}", file=sys.stderr)
        sys.exit(1)


def main() -> int:
    global EVIDENCE
    files = tracked()
    EVIDENCE = build_evidence_index(ROOT, files)
    dir_files, dir_dirs = build_tree(files)
    blocks: list[str] = []
    blocks.append("# APP STRUCTURE — DETAILED")
    blocks.append("")
    blocks.append(f"Generated: {date.today().isoformat()} from `{sha()}`")
    blocks.append(f"**Tracked files:** {len(files)}")
    blocks.append("")
    blocks.append(
        "This file is generated from the live repository and is intended to be owner-readable. "
        "Every tracked file appears exactly once."
    )
    blocks.append("")

    def render_dir(path: str) -> None:
        if path:
            blocks.append(folder_block(path, dir_files.get(path, []), dir_dirs.get(path, [])))
            blocks.append("")
        for file_path in dir_files.get(path, []):
            blocks.append(file_block(file_path))
            blocks.append("")
        for child in dir_dirs.get(path, []):
            render_dir(child)

    render_dir("")
    body = "\n".join(blocks).rstrip() + "\n"
    validate_rendered(body, files)
    OUT.write_text(body, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)} with {len(files)} tracked files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
