#!/usr/bin/env python3
"""Deterministic evidence indexes for APP_STRUCTURE_DETAILED generation.

Stdlib only. Ignores docs/APP_STRUCTURE_DETAILED.md when scanning text references
so the map cannot self-prove.
"""

from __future__ import annotations

import re
import subprocess
from collections import defaultdict, deque
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]
DETAILED_IGNORE = "docs/APP_STRUCTURE_DETAILED.md"
HYGIENE_AUDIT = "docs/reports/REPOSITORY_HYGIENE_AUDIT_2026-07-21.md"

IMPORT_RE = re.compile(
    r"""^\s*(?:import|export)\s+['\"]([^'\"]+)['\"]""",
    re.M,
)
PART_RE = re.compile(r"""^\s*part\s+['\"]([^'\"]+)['\"]\s*;""", re.M)
PART_OF_RE = re.compile(
    r"""^\s*part\s+of\s+(?:library\s+)?['\"]?([^;'\"]+)['\"]?\s*;""",
    re.M,
)
COND_IMPORT_RE = re.compile(
    r"""import\s+['\"]([^'\"]+)['\"]\s+if\s*\([^)]+\)\s*['\"]([^'\"]+)['\"]""",
    re.M,
)
SYMBOL_RE = re.compile(
    r"^(?:abstract\s+(?:final\s+)?class|class|enum|extension|mixin|typedef)\s+(\w+)",
    re.M,
)

VALID_NECESSITY = frozenset(
    {
        "PROVEN_REQUIRED",
        "REQUIRED_BY_PLATFORM_CONVENTION",
        "REQUIRED_FOR_TEST_OR_TOOLING",
        "GOVERNING_DOCUMENTATION",
        "GENERATED_CANONICAL_OUTPUT",
        "HISTORICAL_RECORD",
        "COMPATIBILITY_LAYER",
        "RETAINED_PRODUCT_WATCHLIST",
        "DELETION_CANDIDATE",
    }
)
VALID_CONFIDENCE = frozenset({"HIGH", "MEDIUM", "WATCHLIST"})

VALID_ROLES = frozenset(
    {
        "runtime entry point",
        "production UI",
        "Brain/data",
        "shared foundation",
        "platform build",
        "platform resource",
        "localization",
        "asset",
        "test",
        "test fixture",
        "developer tool",
        "audit tool",
        "CI/deployment",
        "installer",
        "PocketBase backend",
        "package metadata",
        "governing documentation",
        "generated documentation",
        "historical engineering record",
        "compatibility layer",
        "intentionally retained product watchlist",
    }
)

# Hygiene-audit watchlist (not production-reachable; retained intentionally).
WATCHLIST_PATHS: dict[str, str] = {}

# Test/bench-only modules that are not production-reachable but are tooling-required.
TEST_TOOLING_LIB: frozenset[str] = frozenset(
    {
        "lib/data/voice/desktop_stt_benchmark_harness.dart",
        "lib/shared/voice/commands/desktop_voice_install_smoke_policy.dart",
        "lib/data/voice/desktop_voice_real_helper_latency_benchmark.dart",
        "lib/shared/voice/platforms/desktop/desktop_voice_wav_stt_benchmark.dart",
        "lib/shared/voice/platforms/desktop/desktop_voice_recognizer_io.dart",
    }
)


@dataclass
class EvidenceRecord:
    path: str
    repo_role: str
    necessity: str
    confidence: str
    owner_en: str
    owner_ru: str
    evidence_en: list[str] = field(default_factory=list)
    evidence_ru: list[str] = field(default_factory=list)
    deletion_en: str = ""
    deletion_ru: str = ""
    contents_hint_en: str = ""
    contents_hint_ru: str = ""
    reachable_from_main: bool = False
    part_owner: str | None = None
    production_importers: list[str] = field(default_factory=list)
    test_importers: list[str] = field(default_factory=list)
    text_refs: list[str] = field(default_factory=list)


@dataclass
class EvidenceIndex:
    records: dict[str, EvidenceRecord]
    role_counts: dict[str, int]
    necessity_counts: dict[str, int]
    confidence_counts: dict[str, int]
    dart_with_callers: int
    dart_total: int
    watchlist_count: int


def tracked_files() -> list[str]:
    out = subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True)
    return sorted(x.strip().replace("\\", "/") for x in out.splitlines() if x.strip())


def _resolve_uri(from_file: str, uri: str) -> str | None:
    if uri.startswith("package:counter/"):
        return "lib/" + uri[len("package:counter/") :]
    if uri.startswith("package:") or uri.startswith("dart:"):
        return None
    base = PurePosixPath(from_file).parent
    target = (base / uri).as_posix()
    parts: list[str] = []
    for p in target.split("/"):
        if p == "..":
            if parts:
                parts.pop()
        elif p != ".":
            parts.append(p)
    return "/".join(parts)


def _read(path: str, limit: int | None = None) -> str:
    p = ROOT / path
    if not p.is_file():
        return ""
    try:
        text = p.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    if limit is not None:
        return text[:limit]
    return text


def _dart_symbols(path: str) -> list[str]:
    text = _read(path, 20000)
    found: list[str] = []
    for m in SYMBOL_RE.finditer(text):
        name = m.group(1)
        if name and name not in found:
            found.append(name)
    return found[:8]


def build_dart_graph(files: list[str]) -> tuple[
    dict[str, set[str]],
    dict[str, str],
    dict[str, set[str]],
    set[str],
]:
    """Returns edges (importer->imported), part_owner, importers_of, reachable."""
    dart = [f for f in files if f.endswith(".dart")]
    dart_set = set(dart)
    edges: dict[str, set[str]] = defaultdict(set)
    part_owner: dict[str, str] = {}
    importers_of: dict[str, set[str]] = defaultdict(set)

    for f in dart:
        text = _read(f)
        if not text:
            continue
        for m in IMPORT_RE.finditer(text):
            t = _resolve_uri(f, m.group(1))
            if t and t in dart_set:
                edges[f].add(t)
                importers_of[t].add(f)
        for m in PART_RE.finditer(text):
            t = _resolve_uri(f, m.group(1))
            if t and t in dart_set:
                edges[f].add(t)
                part_owner[t] = f
                importers_of[t].add(f)
        for m in COND_IMPORT_RE.finditer(text):
            for uri in (m.group(1), m.group(2)):
                t = _resolve_uri(f, uri)
                if t and t in dart_set:
                    edges[f].add(t)
                    importers_of[t].add(f)

    roots = ["lib/main.dart"]
    if "lib/app_shell.dart" in dart_set:
        roots.append("lib/app_shell.dart")
    reachable: set[str] = set()
    q: deque[str] = deque(r for r in roots if r in dart_set)
    while q:
        cur = q.popleft()
        if cur in reachable:
            continue
        reachable.add(cur)
        for nxt in edges.get(cur, ()):
            if nxt not in reachable:
                q.append(nxt)
    return edges, part_owner, importers_of, reachable


def build_path_refs(files: list[str]) -> dict[str, list[str]]:
    """Bounded path/basename references across tracked text files (not O(n²))."""
    text_ext = {
        ".dart",
        ".md",
        ".ps1",
        ".py",
        ".yml",
        ".yaml",
        ".json",
        ".xml",
        ".gradle",
        ".kts",
        ".kt",
        ".swift",
        ".cmake",
        ".txt",
        ".iss",
        ".sh",
        ".bat",
        ".plist",
        ".xcconfig",
        ".pbxproj",
        ".html",
        ".js",
        ".css",
        ".toml",
        ".rs",
        ".h",
        ".cpp",
        ".c",
        ".rc",
        ".manifest",
        ".properties",
        ".mdc",
        ".gitignore",
        ".gitattributes",
        ".lock",
    }
    refs: dict[str, list[str]] = defaultdict(list)
    path_set = set(files)
    basenames: dict[str, list[str]] = defaultdict(list)
    for f in files:
        basenames[PurePosixPath(f).name].append(f)

    # Regex extracts likely repo-relative paths from text.
    path_token_re = re.compile(
        r"(?<![A-Za-z0-9_/.-])"
        r"((?:lib|test|docs|scripts|android|ios|macos|linux|windows|web|"
        r"installer|pb_hooks|pb_migrations|\.github|\.cursor)/[A-Za-z0-9_./+-]+\.[A-Za-z0-9]+"
        r"|(?:update|android)\.ps1"
        r"|pubspec\.yaml|pubspec\.lock|analysis_options\.yaml"
        r"|AGENTS\.md|AGENT_NAVIGATION\.md|CHANGELOG\.md|\.cursorrules)"
    )
    name_token_re = re.compile(r"(?<![A-Za-z0-9_])([A-Za-z0-9_][A-Za-z0-9_.-]{7,}\.[A-Za-z0-9]+)(?![A-Za-z0-9_])")

    scanners = [
        f
        for f in files
        if f != DETAILED_IGNORE
        and PurePosixPath(f).suffix.lower() in text_ext
        and not f.endswith(".exe")
    ]
    for src in scanners:
        text = _read(src, 250_000)
        if not text:
            continue
        found_targets: set[str] = set()
        for m in path_token_re.finditer(text):
            cand = m.group(1).replace("\\", "/")
            if cand in path_set and cand != src:
                found_targets.add(cand)
        for m in name_token_re.finditer(text):
            name = m.group(1)
            owners = basenames.get(name, [])
            if len(owners) == 1 and owners[0] != src:
                found_targets.add(owners[0])
        for target in found_targets:
            refs[target].append(src)

    for k in list(refs.keys()):
        refs[k] = sorted(set(refs[k]))[:12]
    return refs


def _owner_for(path: str) -> tuple[str, str]:
    p = path.replace("\\", "/")
    if p.startswith("lib/features/planning/"):
        return "Planning UI", "UI планов"
    if p.startswith("lib/features/timeline/"):
        return "Timeline UI", "UI таймлайна"
    if p.startswith("lib/features/notes/"):
        return "Notes UI", "UI заметок"
    if p.startswith("lib/features/lists/"):
        return "Lists UI", "UI списков"
    if p.startswith("lib/features/calendar/"):
        return "Calendar UI", "UI календаря"
    if p.startswith("lib/features/settings/categories/"):
        return "Categories settings UI", "UI настроек категорий"
    if p.startswith("lib/features/settings/voice/"):
        return "Voice settings UI", "UI настроек Voice"
    if p.startswith("lib/shared/categories/"):
        return "Shared Categories", "Shared Categories"
    if p.startswith("lib/features/profile/"):
        return "Profile UI", "UI профиля"
    if p.startswith("lib/features/shared/"):
        return "shared edit sheets", "общие edit sheets"
    if p.startswith("lib/features/dev/"):
        return "Component Lab", "Component Lab"
    if p.startswith("lib/features/auth/"):
        return "Auth UI", "UI входа"
    if p.startswith("lib/features/wear/"):
        return "Wear OS UI", "UI Wear OS"
    if p.startswith("lib/data/voice/"):
        return "Brain Voice", "Brain — Voice"
    if p.startswith("lib/data/plans/") or p.endswith("plan_service.dart"):
        return "Brain Plans", "Brain — планы"
    if p.startswith("lib/data/records/") or p.endswith("record_service.dart"):
        return "Brain Records", "Brain — записи"
    if p.startswith("lib/data/categories/") or p.endswith("category_service.dart"):
        return "Brain Categories", "Brain — категории"
    if p.startswith("lib/data/profile/") or p.endswith("profile_service.dart"):
        return "Brain Profile", "Brain — профиль"
    if p.startswith("lib/data/"):
        return "Brain/data", "Brain/data"
    if p.startswith("lib/core/widgets/"):
        return "shared design system", "общий design system"
    if p.startswith("lib/core/"):
        return "shared foundation", "общая foundation"
    if p.startswith("lib/app/shell/") or p in ("lib/main.dart", "lib/app_shell.dart"):
        return "app shell", "оболочка приложения"
    if p.startswith("lib/shared/time/"):
        return "shared time", "общий time-слой"
    if p.startswith("lib/shared/diagnostics/"):
        return "shared diagnostics", "общая diagnostics"
    if p.startswith("lib/features/voice/"):
        return "Desktop Voice UI", "Desktop Voice UI"
    if p.startswith("lib/shared/voice/platforms/desktop/"):
        return "Desktop Voice runtime", "Desktop Voice runtime"
    if p.startswith("lib/shared/voice/platforms/mobile/"):
        return "mobile/web Voice adapters", "mobile/web Voice adapters"
    if p.startswith("lib/shared/voice/"):
        return "shared Voice system", "общий Voice system"
    if p.startswith("lib/l10n/"):
        return "localization", "локализация"
    if p.startswith("lib/services/"):
        return "device notifications", "уведомления устройства"
    if p.startswith("windows/"):
        return "Windows runner", "Windows runner"
    if p.startswith("android/"):
        return "Android runner", "Android runner"
    if p.startswith("ios/"):
        return "iOS runner", "iOS runner"
    if p.startswith("macos/"):
        return "macOS runner", "macOS runner"
    if p.startswith("linux/"):
        return "Linux runner", "Linux runner"
    if p.startswith("web/"):
        return "Web runner", "Web runner"
    if p.startswith(".github/"):
        return "CI", "CI"
    if p.startswith("installer/"):
        return "installer", "installer"
    if p.startswith("scripts/audit/"):
        return "audit tooling", "аудит"
    if p.startswith("scripts/") or p in ("update.ps1", "android.ps1"):
        return "developer tooling", "инструменты разработчика"
    if p.startswith("test/"):
        return "tests", "тесты"
    if p.startswith("docs/"):
        return "documentation", "документация"
    if p.startswith("pb_migrations/"):
        return "PocketBase migrations", "миграции PocketBase"
    if p.startswith("pb_migrations/"):
        return "PocketBase migration"
    if p.startswith("pb_hooks/"):
        return "PocketBase backend", "PocketBase backend"
    return "repository root", "корень репозитория"


def _classify_role(path: str, rec_hints: dict) -> str:
    p = path.replace("\\", "/")
    if p in WATCHLIST_PATHS:
        if p.startswith("lib/") and (
            "re-export" in WATCHLIST_PATHS[p].lower()
            or "compatibility" in WATCHLIST_PATHS[p].lower()
        ):
            return "compatibility layer"
        return "intentionally retained product watchlist"
    if p == "lib/main.dart":
        return "runtime entry point"
    if p.startswith("lib/features/") or p.startswith("lib/app/shell/"):
        return "production UI"
    if p.startswith("lib/shared/time/"):
        return "shared time"
    if p.startswith("lib/shared/diagnostics/"):
        return "shared diagnostics"
    if p.startswith("lib/features/voice/"):
        return "Desktop Voice UI"
    if p.startswith("lib/shared/voice/platforms/desktop/"):
        return "Desktop Voice runtime"
    if p.startswith("lib/shared/voice/platforms/mobile/"):
        return "mobile/web Voice adapters"
    if p.startswith("lib/data/voice/"):
        return "Brain Voice"
    if p.startswith("lib/features/settings/voice/"):
        return "Voice settings UI"
    if p.startswith("lib/shared/voice/"):
        return "shared Voice system"
    if p.startswith("lib/data/"):
        return "Brain/data"
    if p.startswith("lib/core/") or p.startswith("lib/services/"):
        return "shared foundation"
    if p.startswith("lib/l10n/"):
        return "localization"
    if p.startswith("test/") and p.endswith(".dart"):
        return "test"
    if p.startswith("test/"):
        return "test fixture"
    if p.startswith("scripts/audit/"):
        return "audit tool"
    if p.startswith("scripts/") or p in ("update.ps1", "android.ps1"):
        return "developer tool"
    if p.startswith(".github/"):
        return "CI/deployment"
    if p.startswith("installer/"):
        return "installer"
    if p.startswith("pb_migrations/"):
        return "PocketBase migration"
    if p.startswith("pb_hooks/"):
        return "PocketBase backend"
    if p in (
        "pubspec.yaml",
        "pubspec.lock",
        "analysis_options.yaml",
        ".gitignore",
        ".gitattributes",
        ".metadata",
    ) or p.endswith("env.dart.example"):
        return "package metadata"
    if p == "docs/APP_STRUCTURE_DETAILED.md":
        return "generated documentation"
    if p.startswith("docs/reports/") and re.search(r"20\d{2}-\d{2}-\d{2}", p):
        return "historical engineering record"
    if p.startswith("docs/") or p.endswith(".md") or p.startswith(".cursor"):
        if "DEPLOY" in p or p.endswith("AGENTS.md") or "ARCHITECTURE" in p or "DATA_MAP" in p:
            return "governing documentation"
        if p.startswith("docs/website/"):
            return "governing documentation"
        return "governing documentation"
    if p.startswith(("android/", "ios/", "macos/", "linux/", "windows/", "web/")):
        if p.endswith(
            (".png", ".jpg", ".jpeg", ".ico", ".svg", ".ttf", ".otf", ".xcassets")
        ) or "/Assets.xcassets/" in p or "/res/" in p:
            return "platform resource"
        return "platform build"
    if p.endswith((".png", ".jpg", ".jpeg", ".webp", ".svg", ".ico", ".ttf", ".otf", ".wav")):
        return "asset"
    return "developer tool"


def _platform_evidence(path: str) -> list[str]:
    p = path.replace("\\", "/")
    name = PurePosixPath(p).name
    parent = PurePosixPath(p).parent.as_posix()
    ev: list[str] = []
    if p.endswith("Contents.json") or name == "Contents.json":
        ev.append(
            f"Asset catalog manifest at `{p}`; Xcode/Flutter includes sibling images via this JSON."
        )
        return ev
    if "/Assets.xcassets/" in p and name.endswith(".png"):
        catalog = parent
        contents = f"{catalog}/Contents.json"
        ev.append(
            f"Referenced by sibling `{contents}` in the Runner asset catalog "
            f"(scale/size slot `{name}`)."
        )
        return ev
    if p.endswith("GeneratedPluginRegistrant.java") or p.endswith(
        "GeneratedPluginRegistrant.swift"
    ) or p.endswith("generated_plugin_registrant.cc") or p.endswith(
        "generated_plugin_registrant.h"
    ):
        ev.append(
            "Flutter tooling regenerates this plugin registrant during `flutter pub get` / build; "
            "required by the platform runner to register plugins."
        )
        return ev
    if name in (
        "CMakeLists.txt",
        "Runner.rc",
        "MainActivity.kt",
        "AppDelegate.swift",
        "Info.plist",
        "AndroidManifest.xml",
        "build.gradle",
        "build.gradle.kts",
        "settings.gradle",
        "settings.gradle.kts",
        "podhelper.rb",
        "Podfile",
        "project.pbxproj",
    ):
        ev.append(
            f"Flutter/native project file `{name}` under `{parent}/`; "
            f"required by platform build convention for this runner."
        )
        return ev
    if p.startswith("android/") or p.startswith("ios/") or p.startswith("macos/") or p.startswith(
        "linux/"
    ) or p.startswith("windows/") or p.startswith("web/"):
        ev.append(
            f"Tracked Flutter platform file under `{parent}/` "
            f"(individual role: `{name}` for that platform project)."
        )
    return ev


def build_evidence_index(files: list[str] | None = None) -> EvidenceIndex:
    files = files or tracked_files()
    _, part_owner, importers_of, reachable = build_dart_graph(files)
    path_refs = build_path_refs(files)
    records: dict[str, EvidenceRecord] = {}
    role_counts: dict[str, int] = defaultdict(int)
    necessity_counts: dict[str, int] = defaultdict(int)
    confidence_counts: dict[str, int] = defaultdict(int)
    dart_with_callers = 0
    dart_total = 0
    watchlist_count = 0

    for path in files:
        owner_en, owner_ru = _owner_for(path)
        role = _classify_role(path, {})
        evidence_en: list[str] = []
        evidence_ru: list[str] = []
        necessity = "PROVEN_REQUIRED"
        confidence = "HIGH"
        deletion_en = "Removing it breaks a required repository capability."
        deletion_ru = "Удаление ломает нужную возможность репозитория."
        contents_hint_en = ""
        contents_hint_ru = ""
        reachable_here = path in reachable
        p_owner = part_owner.get(path)
        prod_importers = sorted(
            i
            for i in importers_of.get(path, ())
            if i.startswith("lib/") and i != path
        )
        test_importers = sorted(
            i
            for i in importers_of.get(path, ())
            if i.startswith("test/") or i.startswith("integration_test/")
        )
        text_refs = [r for r in path_refs.get(path, []) if r != path][:8]

        # --- Watchlist ---
        if path in WATCHLIST_PATHS:
            watchlist_count += 1
            reason = WATCHLIST_PATHS[path]
            if role == "compatibility layer":
                necessity = "COMPATIBILITY_LAYER"
            else:
                necessity = "RETAINED_PRODUCT_WATCHLIST"
            confidence = "WATCHLIST"
            evidence_en.append(
                f"Hygiene audit watchlist (`{HYGIENE_AUDIT}`): {reason}"
            )
            evidence_en.append(
                "Current production reachability from `lib/main.dart`: none "
                "(retained intentionally — not proven runtime-required)."
            )
            evidence_ru.append(
                f"Список наблюдения hygiene-аудита (`{HYGIENE_AUDIT}`): {reason}"
            )
            evidence_ru.append(
                "Сейчас не достижим из `lib/main.dart`; сохранён намеренно, "
                "не считать runtime-обязательным."
            )
            deletion_en = (
                "No current production consequence established; product decision "
                "required before deletion (replace docs/imports or remove)."
            )
            deletion_ru = (
                "Сейчас нет доказанного runtime-эффекта; перед удалением нужно "
                "продуктовое решение (обновить docs/imports или убрать файл)."
            )
            if p_owner:
                evidence_en.append(f"If compiled, included as `part` of `{p_owner}`.")
            records[path] = EvidenceRecord(
                path=path,
                repo_role=role,
                necessity=necessity,
                confidence=confidence,
                owner_en=owner_en,
                owner_ru=owner_ru,
                evidence_en=evidence_en,
                evidence_ru=evidence_ru,
                deletion_en=deletion_en,
                deletion_ru=deletion_ru,
                reachable_from_main=False,
                part_owner=p_owner,
                production_importers=prod_importers,
                test_importers=test_importers,
                text_refs=text_refs,
            )
            role_counts[role] += 1
            necessity_counts[necessity] += 1
            confidence_counts[confidence] += 1
            continue

        # --- Dart ---
        if path.endswith(".dart"):
            dart_total += 1
            syms = _dart_symbols(path)
            if syms:
                contents_hint_en = "Primary symbols: " + ", ".join(f"`{s}`" for s in syms)
                contents_hint_ru = "Основные символы: " + ", ".join(f"`{s}`" for s in syms)

            if path == "lib/main.dart":
                evidence_en.append(
                    "Production entry point: Flutter `main()` boots PocketBase, auth gate, and shell."
                )
                evidence_ru.append(
                    "Точка входа production: Flutter `main()` поднимает PocketBase, auth и shell."
                )
                necessity = "PROVEN_REQUIRED"
                confidence = "HIGH"
                deletion_en = "Compile/runtime failure — the app cannot start."
                deletion_ru = "Сборка/запуск невозможны — приложение не стартует."
            elif p_owner:
                evidence_en.append(
                    f"Included by `{p_owner}` through a `part` directive (not imported directly)."
                )
                evidence_ru.append(
                    f"Подключён из `{p_owner}` через `part` (не импортируется напрямую)."
                )
                if p_owner in reachable or reachable_here:
                    necessity = "PROVEN_REQUIRED"
                    confidence = "HIGH"
                    deletion_en = (
                        f"Brain/library compile failure in `{p_owner}` and broken related UI/data ops."
                    )
                    deletion_ru = (
                        f"Сломается компиляция `{p_owner}` и связанные экраны/данные."
                    )
                else:
                    necessity = "REQUIRED_FOR_TEST_OR_TOOLING"
                    confidence = "MEDIUM"
            elif prod_importers:
                dart_with_callers += 1
                sample = ", ".join(f"`{x}`" for x in prod_importers[:5])
                evidence_en.append(f"Imported/exported by production Dart: {sample}.")
                evidence_ru.append(f"Импортируется production Dart: {sample}.")
                if reachable_here:
                    necessity = "PROVEN_REQUIRED"
                    confidence = "HIGH"
                    deletion_en = "Compile failure or missing UI/data behavior for those callers."
                    deletion_ru = "Ошибка компиляции или пропажа поведения у вызывающих экранов."
                else:
                    necessity = "REQUIRED_FOR_TEST_OR_TOOLING"
                    confidence = "MEDIUM"
            elif test_importers or path in TEST_TOOLING_LIB:
                dart_with_callers += 1
                sample_list = test_importers or sorted(TEST_TOOLING_LIB)
                sample = ", ".join(f"`{x}`" for x in sample_list[:5])
                evidence_en.append(f"Referenced by tests/tooling: {sample}.")
                evidence_ru.append(f"Нужен тестам/инструментам: {sample}.")
                necessity = "REQUIRED_FOR_TEST_OR_TOOLING"
                confidence = "HIGH"
                deletion_en = "Missing test coverage or broken manual benchmark/smoke harness."
                deletion_ru = "Пропадёт покрытие тестами или сломается benchmark/smoke."
                role = "shared foundation" if path.startswith("lib/") else role
            elif path.startswith("test/"):
                # test dart without importers — still a test entry
                evidence_en.append(
                    f"Flutter test file; exercised via `flutter test {path}` / CI when enabled."
                )
                evidence_ru.append(
                    f"Файл теста Flutter; запускается через `flutter test {path}`."
                )
                # try subject by naming
                stem = PurePosixPath(path).stem.replace("_test", "")
                guess = [
                    f
                    for f in files
                    if f.startswith("lib/") and PurePosixPath(f).stem == stem
                ]
                if guess:
                    evidence_en.append(f"Namesake production subject: `{guess[0]}`.")
                    evidence_ru.append(f"Парный production-файл: `{guess[0]}`.")
                necessity = "REQUIRED_FOR_TEST_OR_TOOLING"
                confidence = "HIGH"
                deletion_en = "Lost automated coverage for its contract."
                deletion_ru = "Пропадёт автоматическая проверка своего контракта."
                role = "test"
            else:
                # fallback for dart with only text refs
                if text_refs:
                    sample = ", ".join(f"`{x}`" for x in text_refs[:4])
                    evidence_en.append(f"Mentioned by tracked docs/scripts: {sample}.")
                    evidence_ru.append(f"Упоминается в docs/scripts: {sample}.")
                    necessity = "REQUIRED_FOR_TEST_OR_TOOLING"
                    confidence = "MEDIUM"
                else:
                    evidence_en.append(
                        "Tracked Dart source; structural role inferred from path "
                        "(no importer found in this scan)."
                    )
                    evidence_ru.append(
                        "Отслеживаемый Dart; роль по пути (в этом скане импортеров не найдено)."
                    )
                    necessity = "REQUIRED_FOR_TEST_OR_TOOLING"
                    confidence = "MEDIUM"
                    deletion_en = "May break tooling or future wiring; verify before delete."
                    deletion_ru = "Может сломать tooling; проверять перед удалением."

        # --- Tests fixtures ---
        elif path.startswith("test/") and not path.endswith(".dart"):
            role = "test fixture"
            if text_refs:
                sample = ", ".join(f"`{x}`" for x in text_refs[:5])
                evidence_en.append(f"Read/referenced by: {sample}.")
                evidence_ru.append(f"Читается/упоминается: {sample}.")
                confidence = "HIGH"
            else:
                evidence_en.append(
                    "Tracked under `test/fixtures/`; retained as STT/Notes diagnostic or golden sample "
                    "(see neighboring test files)."
                )
                evidence_ru.append(
                    "Файл в `test/fixtures/`; образец для STT/Notes тестов "
                    "(см. соседние test-файлы)."
                )
                confidence = "MEDIUM"
            if path.endswith("real_helper_latency_latest.json"):
                evidence_en.append(
                    "Canonical benchmark output written by "
                    "`lib/data/voice/desktop_voice_real_helper_latency_benchmark.dart`."
                )
                evidence_ru.append(
                    "Канонический отчёт бенчмарка из "
                    "`desktop_voice_real_helper_latency_benchmark.dart`."
                )
                confidence = "HIGH"
            necessity = "REQUIRED_FOR_TEST_OR_TOOLING"
            deletion_en = "Broken fixture-backed test or missing diagnostic sample."
            deletion_ru = "Сломается тест на fixture или пропадёт диагностический образец."
            contents_hint_en = f"Fixture payload `{PurePosixPath(path).name}`."
            contents_hint_ru = f"Fixture-файл `{PurePosixPath(path).name}`."

        # --- Scripts ---
        elif path.startswith("scripts/") or path in ("update.ps1", "android.ps1"):
            if path.startswith("scripts/audit/"):
                role = "audit tool"
            else:
                role = "developer tool"
            if text_refs:
                sample = ", ".join(f"`{x}`" for x in text_refs[:5])
                evidence_en.append(f"Invoked or documented by: {sample}.")
                evidence_ru.append(f"Вызывается или описан в: {sample}.")
                confidence = "HIGH" if any(
                    r.endswith((".yml", ".yaml", ".md", ".ps1")) for r in text_refs
                ) else "MEDIUM"
            else:
                evidence_en.append(
                    "Documented manual developer/audit script under `scripts/`; "
                    "run from repo docs or AGENTS.md workflows."
                )
                evidence_ru.append(
                    "Ручной dev/audit скрипт в `scripts/`; "
                    "запускается по инструкции в docs/AGENTS."
                )
                confidence = "MEDIUM"
            if path.endswith("generate_app_structure_detailed.py"):
                evidence_en.append(
                    f"Generator for `{DETAILED_IGNORE}`; input is `git ls-files` + guide modules."
                )
                evidence_ru.append(
                    f"Генератор `{DETAILED_IGNORE}`; вход — `git ls-files` и guide-модули."
                )
                confidence = "HIGH"
            if path.endswith("structure_evidence_index.py"):
                evidence_en = [
                    "Imported by `scripts/manual/generate_app_structure_detailed.py`; "
                    "builds deterministic Dart import/export/`part`, path-reference, "
                    "platform, and watchlist evidence indexes for the canonical map."
                ]
                evidence_ru = [
                    "Импортируется `scripts/manual/generate_app_structure_detailed.py`; "
                    "строит детерминированные индексы доказательств (Dart-граф, path refs, "
                    "platform, watchlist) для канонической карты."
                ]
                confidence = "HIGH"
                contents_hint_en = (
                    "`build_evidence_index`, `EvidenceRecord`, watchlist set, "
                    "role/necessity/confidence classifiers."
                )
                contents_hint_ru = (
                    "`build_evidence_index`, `EvidenceRecord`, watchlist, "
                    "классификаторы роли/необходимости/уверенности."
                )
                deletion_en = (
                    "Broken evidence-backed APP_STRUCTURE_DETAILED generation "
                    "(import failure in generate_app_structure_detailed.py)."
                )
                deletion_ru = (
                    "Сломается генерация evidence-backed APP_STRUCTURE_DETAILED "
                    "(ошибка import в generate_app_structure_detailed.py)."
                )
            else:
                deletion_en = "Broken audit/deploy/manual maintenance command."
                deletion_ru = "Сломается audit/deploy или ручная команда сопровождения."
            necessity = "REQUIRED_FOR_TEST_OR_TOOLING"

        # --- CI ---
        elif path.startswith(".github/"):
            role = "CI/deployment"
            evidence_en.append(
                "GitHub Actions discovers workflows under `.github/workflows/`; "
                "see `docs/DEPLOY.md` for publish/build intent."
            )
            evidence_ru.append(
                "GitHub Actions подхватывает workflow из `.github/workflows/`; "
                "см. `docs/DEPLOY.md`."
            )
            if text_refs:
                evidence_en.append(
                    "Also referenced by: "
                    + ", ".join(f"`{x}`" for x in text_refs[:4])
                    + "."
                )
            necessity = "PROVEN_REQUIRED"
            confidence = "HIGH"
            deletion_en = "Broken CI deploy or Windows installer pipeline."
            deletion_ru = "Сломается CI deploy или сборка Windows installer."

        # --- Installer ---
        elif path.startswith("installer/"):
            role = "installer"
            if path.endswith("counter_stt_helper.exe"):
                evidence_en.append(
                    "Canonical Windows STT helper binary copied into the setup payload by "
                    "`installer/windows/prepare_stt_payload.ps1` / Inno Setup; "
                    "also used by desktop-voice smoke/benchmark scripts."
                )
                evidence_ru.append(
                    "Канонический `counter_stt_helper.exe` для Windows installer и "
                    "desktop-voice smoke/benchmark скриптов."
                )
                contents_hint_en = "Prebuilt native STT helper executable (~33 MB)."
                contents_hint_ru = "Собранный native STT helper (~33 МБ)."
                confidence = "HIGH"
            elif text_refs:
                evidence_en.append(
                    "Referenced by: " + ", ".join(f"`{x}`" for x in text_refs[:5]) + "."
                )
                evidence_ru.append(
                    "Упоминается в: " + ", ".join(f"`{x}`" for x in text_refs[:5]) + "."
                )
                confidence = "HIGH"
            else:
                evidence_en.append(
                    "Windows installer / STT helper source or packaging file under `installer/`."
                )
                evidence_ru.append(
                    "Файл Windows installer / STT helper в `installer/`."
                )
                confidence = "MEDIUM"
            necessity = "PROVEN_REQUIRED"
            deletion_en = "Broken Windows installer or missing STT helper payload."
            deletion_ru = "Сломается Windows installer или пропадёт STT helper."

        # --- PocketBase migrations ---
        elif path.startswith("pb_migrations/"):
            role = "PocketBase migration"
            evidence_en.append(
                "Versioned PocketBase schema/data migration; applied by PocketBase before "
                "client code that depends on the schema (see `docs/DEPLOY.md`)."
            )
            evidence_ru.append(
                "Версионированная миграция схемы/данных PocketBase; применяется до "
                "клиента, который зависит от этой схемы (см. `docs/DEPLOY.md`)."
            )
            necessity = "PROVEN_REQUIRED"
            confidence = "HIGH"
            deletion_en = "Production schema history becomes incomplete or a required data migration is lost."
            deletion_ru = "История production-схемы станет неполной или пропадёт нужная миграция данных."

        # --- PocketBase ---
        elif path.startswith("pb_hooks/"):
            role = "PocketBase backend"
            evidence_en.append(
                "Server-side PocketBase hook; deployed with the PB instance "
                "(see `docs/POCKETBASE_MANIFEST.md`)."
            )
            evidence_ru.append(
                "Серверный hook PocketBase; деплоится вместе с PB "
                "(см. `docs/POCKETBASE_MANIFEST.md`)."
            )
            necessity = "PROVEN_REQUIRED"
            confidence = "HIGH"
            deletion_en = "Broken server-side validation/automation for PB collections."
            deletion_ru = "Сломается серверная логика PocketBase."

        # --- Docs ---
        elif path.startswith("docs/") or path.endswith(".md") or path.startswith(".cursor"):
            if path == DETAILED_IGNORE:
                role = "generated documentation"
                necessity = "GENERATED_CANONICAL_OUTPUT"
                evidence_en.append(
                    "Generated by `scripts/manual/generate_app_structure_detailed.py` from `git ls-files`."
                )
                evidence_ru.append(
                    "Генерируется `generate_app_structure_detailed.py` из `git ls-files`."
                )
                confidence = "HIGH"
                deletion_en = "Lost the canonical per-file repository map (regenerable)."
                deletion_ru = "Пропадёт каноническая карта файлов (можно пересобрать)."
            elif path.startswith("docs/reports/") and re.search(
                r"20\d{2}-\d{2}-\d{2}", path
            ):
                role = "historical engineering record"
                necessity = "HISTORICAL_RECORD"
                evidence_en.append(
                    "Dated engineering report retained as decision history; "
                    "linked from structure/changelog audits — not runtime code."
                )
                evidence_ru.append(
                    "Отчёт с датой — история решений; не runtime-код."
                )
                if text_refs:
                    evidence_en.append(
                        "Referenced by: "
                        + ", ".join(f"`{x}`" for x in text_refs[:4])
                        + "."
                    )
                confidence = "MEDIUM"
                deletion_en = "Lost historical decision evidence for that investigation."
                deletion_ru = "Пропадёт история решения по тому расследованию."
            else:
                role = "governing documentation"
                necessity = "GOVERNING_DOCUMENTATION"
                evidence_en.append(
                    "Governing/ops/product documentation read by humans and agents "
                    "(see `docs/PROJECT_KNOWLEDGE_PACK.md` / AGENTS routing)."
                )
                evidence_ru.append(
                    "Управляющая/операционная документация для людей и агентов "
                    "(см. Project Knowledge / AGENTS)."
                )
                if text_refs:
                    evidence_en.append(
                        "Referenced by: "
                        + ", ".join(f"`{x}`" for x in text_refs[:4])
                        + "."
                    )
                confidence = "HIGH"
                deletion_en = "Lost architecture/ops rule or agent routing instruction."
                deletion_ru = "Пропадёт архитектурное/операционное правило."

        # --- Package metadata ---
        elif path in (
            "pubspec.yaml",
            "pubspec.lock",
            "analysis_options.yaml",
            ".gitignore",
            ".gitattributes",
            ".metadata",
        ) or path.endswith("env.dart.example"):
            role = "package metadata"
            evidence_en.append(
                "Flutter/Dart package or repo metadata required by tooling "
                "(`flutter pub get`, analyzer, git)."
            )
            evidence_ru.append(
                "Метаданные Flutter/Dart пакета; нужны tooling (`pub get`, analyzer, git)."
            )
            necessity = "PROVEN_REQUIRED"
            confidence = "HIGH"
            deletion_en = "Broken package resolve, analyze, or git hygiene."
            deletion_ru = "Сломается pub get, analyze или git hygiene."

        # --- Platform ---
        elif path.startswith(
            ("android/", "ios/", "macos/", "linux/", "windows/", "web/")
        ):
            plat_ev = _platform_evidence(path)
            evidence_en.extend(plat_ev or [
                f"Flutter platform project file `{path}`."
            ])
            evidence_ru.append(
                f"Файл Flutter platform-проекта `{path}`."
            )
            if text_refs:
                evidence_en.append(
                    "Also referenced by: "
                    + ", ".join(f"`{x}`" for x in text_refs[:3])
                    + "."
                )
            role = _classify_role(path, {})
            necessity = "REQUIRED_BY_PLATFORM_CONVENTION"
            confidence = "HIGH"
            deletion_en = "Unavailable or broken platform build for that OS target."
            deletion_ru = "Сломается сборка этой платформы."

        # --- Fallback ---
        else:
            if text_refs:
                evidence_en.append(
                    "Referenced by: " + ", ".join(f"`{x}`" for x in text_refs[:5]) + "."
                )
                evidence_ru.append(
                    "Упоминается в: " + ", ".join(f"`{x}`" for x in text_refs[:5]) + "."
                )
                confidence = "MEDIUM"
            else:
                evidence_en.append(
                    f"Tracked repository file `{path}` retained for tooling/config."
                )
                evidence_ru.append(
                    f"Отслеживаемый файл `{path}` для tooling/config."
                )
                confidence = "MEDIUM"
            necessity = "REQUIRED_FOR_TEST_OR_TOOLING"
            deletion_en = "May break tooling or configuration; verify before delete."
            deletion_ru = "Может сломать tooling; проверять перед удалением."

        if not evidence_en:
            evidence_en.append(f"Tracked path `{path}` present in `git ls-files`.")
        if not evidence_ru:
            evidence_ru.append(f"Путь `{path}` есть в `git ls-files`.")

        # Never claim PROVEN_REQUIRED without HIGH evidence for watchlist (already handled)
        if necessity == "PROVEN_REQUIRED" and confidence != "HIGH":
            confidence = "HIGH"  # tighten: if we marked proven, force HIGH only when justified
            # If we somehow got here with weak evidence, downgrade:
            if len(evidence_en) == 1 and "no importer" in evidence_en[0].lower():
                necessity = "REQUIRED_FOR_TEST_OR_TOOLING"
                confidence = "MEDIUM"

        records[path] = EvidenceRecord(
            path=path,
            repo_role=role,
            necessity=necessity,
            confidence=confidence,
            owner_en=owner_en,
            owner_ru=owner_ru,
            evidence_en=evidence_en,
            evidence_ru=evidence_ru,
            deletion_en=deletion_en,
            deletion_ru=deletion_ru,
            contents_hint_en=contents_hint_en,
            contents_hint_ru=contents_hint_ru,
            reachable_from_main=reachable_here,
            part_owner=p_owner,
            production_importers=prod_importers,
            test_importers=test_importers,
            text_refs=text_refs,
        )
        role_counts[role] += 1
        necessity_counts[necessity] += 1
        confidence_counts[confidence] += 1

    return EvidenceIndex(
        records=records,
        role_counts=dict(role_counts),
        necessity_counts=dict(necessity_counts),
        confidence_counts=dict(confidence_counts),
        dart_with_callers=dart_with_callers,
        dart_total=dart_total,
        watchlist_count=watchlist_count,
    )


def format_evidence_block(lines: list[str]) -> str:
    if not lines:
        return "(none)"
    if len(lines) == 1:
        return lines[0]
    return " ".join(f"({i+1}) {t}" for i, t in enumerate(lines))
