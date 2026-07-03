#!/usr/bin/env python3
"""Generate docs/APP_STRUCTURE_DETAILED.md from tracked files + light symbol scan."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "APP_STRUCTURE_DETAILED.md"
SHA = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True).strip()

SYMBOL_RE = re.compile(
    r"^(?:class|enum|extension|mixin|typedef)\s+(\w+)|^void\s+main\s*\(",
    re.M,
)


def tracked(prefix: str = "") -> list[str]:
    args = ["git", "ls-files"]
    if prefix:
        args.append(prefix)
    out = subprocess.check_output(args, cwd=ROOT, text=True)
    return [l.strip() for l in out.splitlines() if l.strip()]


def symbols(path: str) -> list[str]:
    p = ROOT / path
    if not p.is_file():
        return []
    try:
        text = p.read_text(encoding="utf-8")[:4000]
    except OSError:
        return []
    found: list[str] = []
    for m in SYMBOL_RE.finditer(text):
        name = m.group(1)
        if name and name not in found:
            found.append(name)
        if m.group(0).startswith("void main"):
            found.append("main")
    return found[:6]


def purpose_en(path: str, syms: list[str]) -> tuple[str, str, str, str]:
    sym = ", ".join(syms[:3]) if syms else "(library)"
    p = path.replace("\\", "/")

    if p.startswith("lib/data/database_service.dart"):
        return (
            "Brain library root singleton and `part` host for all PocketBase I/O extensions.",
            f"Shared Brain state, streams, static helpers; `part` declarations for domain extensions. Symbols: {sym}.",
            "Owns HTTP/PocketBase access; coordinates optimistic cache and offline outboxes.",
            "Imported by UI via `DatabaseService.instance`; domain logic lives in `part` files.",
        )
    if "/data/plans/" in p or p.endswith("plan_service.dart"):
        return (
            "Plan/list domain Brain module (coordinator or part).",
            f"Planning CRUD, Time View projection, recurrence, tags, outbox helpers. Symbols: {sym}.",
            "Fetches/mutates `plans` rows, expands RRULE, queues offline plan mutations.",
            "Used by Planning/Lists UI and shell voice routing through `DatabaseService`.",
        )
    if "/data/records/" in p or p.endswith("record_service.dart"):
        return (
            "Record/timeline domain Brain module (coordinator or part).",
            f"Start/stop records, timeline VM, realtime, overlap/Highlander, outbox. Symbols: {sym}.",
            "Maintains record cache, optimistic start/stop, PocketBase records I/O.",
            "Timeline tab, edit sheets, Wear lite load path.",
        )
    if "/data/categories/" in p or p.endswith("category_service.dart"):
        return (
            "Category domain Brain module (coordinator or part).",
            f"Category tree, fuzzy match, CRUD, stats bridge, default plan time. Symbols: {sym}.",
            "Hydrates category rules, maps category_id/category_link for records/plans.",
            "Categories screen, plan cards, record category picker, stats aggregation.",
        )
    if "/data/profile/" in p or p.endswith("profile_service.dart"):
        return (
            "Profile/tag catalog Brain module (coordinator or part).",
            f"Profile hydration, settings PATCH, timezone, tag catalog CRUD. Symbols: {sym}.",
            "Loads `profiles` row, projects wall-clock today, manages tag catalog cache.",
            "Profile settings, tag manager, tag chips, timezone header picker.",
        )
    if p.startswith("lib/data/local_sync/"):
        return (
            "Offline mutation outbox or sync UI state.",
            f"SharedPreferences queues + flush hooks. Symbols: {sym}.",
            "Enqueues retriable PB failures; drives offline banner and reconnect drain.",
            "Brain flush on boot/resume/reconnect; `_OfflineSyncStatusBar` in shell.",
        )
    if p.startswith("lib/data/models"):
        return (
            "Immutable data model or model barrel.",
            f"DTOs aligned with `docs/DATA_MAP.md`. Symbols: {sym}.",
            "Parse/serialize PocketBase fields; no UI imports.",
            "Brain + UI read types via `package:counter/data/models.dart`.",
        )
    if p.startswith("lib/features/planning/time_view/"):
        return (
            "Planning Time View UI submodule.",
            f"Canvas, drag/resize, card layer, settings. Symbols: {sym}.",
            "Renders proportional day timeline and handles Time View gestures.",
            "Composed by `planning_page.dart` / `PlanningTimeViewHost`.",
        )
    if p.startswith("lib/features/planning/"):
        return (
            "Plans tab UI module.",
            f"Planning day pager, cards, settings, bulk edit. Symbols: {sym}.",
            "Optimistic plan interactions; delegates persistence to Brain.",
            "Shell tab index 1; uses canonical `PlanTimeTaskCard` / `AppButton`.",
        )
    if p.startswith("lib/features/timeline/"):
        return (
            "Timeline tab UI module.",
            f"Day pager, record cards, header controls. Symbols: {sym}.",
            "Displays running/stopped records for profile wall days.",
            "Shell tab index 0; record edit via `ActivityDetailSheet`.",
        )
    if p.startswith("lib/features/lists/"):
        return (
            "Lists/backlog tab UI module.",
            f"Filters, cards, bulk actions, export. Symbols: {sym}.",
            "Backlog plan rows with list-domain tags; no play button on cards.",
            "Shell tab index 3.",
        )
    if p.startswith("lib/features/categories/"):
        return (
            "Category manager UI.",
            f"Tree picker, create/edit sheets, visibility prefs. Symbols: {sym}.",
            "CRUD UI calling Brain category extensions.",
            "More menu → Categories.",
        )
    if p.startswith("lib/features/profile/"):
        return (
            "Profile and tag settings UI.",
            f"Account, timezone, tag manager, desktop voice settings. Symbols: {sym}.",
            "Edits profile prefs and tag catalog through Brain profile modules.",
            "More menu → Profile; admin Component Lab gated by `isAdmin`.",
        )
    if p.startswith("lib/features/shared/"):
        return (
            "Cross-feature shared UI.",
            f"Edit sheets, voice widgets, offline banner. Symbols: {sym}.",
            "Routes plan/record edits; hosts Omni-Picker and autosave gate.",
            "Imported by Timeline, Planning, Lists, shell edit hosts.",
        )
    if p.startswith("lib/shell/"):
        return (
            "Application shell module.",
            f"Tab host, voice routing, edit modals, side nav. Symbols: {sym}.",
            "Wires bottom nav / desktop rail to feature pages.",
            "`app_shell.dart` re-exports `life_os_dashboard.dart`.",
        )
    if p.startswith("lib/core/widgets/"):
        return (
            "Canonical design-system widget.",
            f"Reusable UI primitive per `docs/DESIGN_SYSTEM.md`. Symbols: {sym}.",
            "Feature screens compose these instead of raw Material buttons.",
            "Component Lab demonstrates mappings.",
        )
    if p.startswith("lib/core/services/"):
        return (
            "Core platform/voice service (no feature imports).",
            f"Desktop voice/STT/tray/hotkey pipeline. Symbols: {sym}.",
            "Bridges OS capabilities; record submit calls Brain via injected hooks.",
            "Wired from `main.dart` / shell voice routing.",
        )
    if p.startswith("lib/core/"):
        return (
            "Core foundation utility or widget.",
            f"Theme, time, diagnostics, navigation helpers. Symbols: {sym}.",
            "Shared non-feature code; must not import `features/` or Brain HTTP.",
            "Used across UI modules and sometimes Brain (time helpers).",
        )
    if p.startswith("lib/l10n/"):
        return (
            "Localization catalog.",
            f"Dictionary keys and locale maps. Symbols: {sym}.",
            "Provides `t()` lookup for UI strings.",
            "Features import `dictionary.dart`; EN/RU are canonical SSOT.",
        )
    if p.startswith("lib/services/"):
        return (
            "Device bridge service.",
            f"Notifications/alarms without UI. Symbols: {sym}.",
            "Schedules plan alarms; no PocketBase HTTP.",
            "Brain requests reschedule via notification service.",
        )
    if p.startswith("test/"):
        return (
            "Automated test.",
            f"Widget/unit/regression coverage. Symbols: {sym}.",
            "Guards domain/UI contracts (`flutter test`).",
            "Maps to nearby production module by name.",
        )
    if p.startswith("scripts/"):
        return (
            "Developer/CI script.",
            f"Audit, deploy, locale sync, or one-off maintenance. Symbols: {sym}.",
            "Not shipped in app binary.",
            "Documented in `docs/DEPLOY.md` or audit reports when workflow-critical.",
        )
    if p.startswith("docs/"):
        return (
            "Project documentation.",
            f"Architecture, data map, reports. Symbols: {sym}.",
            "Governing specs for Brain/UI behavior.",
            "Must stay aligned with code tree (this file).",
        )
    if p.startswith("assets/"):
        return (
            "Bundled asset.",
            f"Images/fonts referenced from `pubspec.yaml`. Symbols: {sym}.",
            "Shipped with Flutter assets bundle.",
            "Loaded via `AssetBundle` or theme.",
        )
    if p in ("pubspec.yaml", "analysis_options.yaml", "update.ps1", "README.md", "CHANGELOG.md", "CLAUDE.md", "AGENTS.md"):
        return (
            "Root project manifest or meta doc.",
            f"Build/analyzer/deploy configuration or changelog. Symbols: {sym}.",
            "Defines dependencies, lints, deploy entrypoints.",
            "First stop for tooling and AI context.",
        )
    if p.startswith(("android/", "ios/", "web/", "windows/", "linux/", "macos/")):
        return (
            "Platform embedder/config.",
            f"Native runner, manifest, or web shell. Symbols: {sym}.",
            "Flutter tooling generates most files; app logic stays in `lib/`.",
            "Build targets for mobile/desktop/web CI.",
        )
    if p.startswith(".github/"):
        return (
            "GitHub Actions workflow.",
            f"CI deploy/build automation. Symbols: {sym}.",
            "Pushes web to gh-pages; optional Windows installer.",
            "Triggered from `main` or manual dispatch.",
        )
    return (
        "Project file.",
        f"Supporting source or config. Symbols: {sym}.",
        "See path prefix for ownership.",
        "Cross-check `docs/APP_STRUCTURE.md` layer rules.",
    )


def purpose_ru(path: str) -> tuple[str, str, str, str]:
    p = path.replace("\\", "/")
    if p.startswith("lib/data/"):
        return (
            "Модуль Brain (данные/PocketBase).",
            "Логика домена, кэш, optimistic UI, outbox — см. англ. блок.",
            "Единственный слой с HTTP к PocketBase (`database_service.dart` + parts).",
            "UI вызывает через `DatabaseService.instance`.",
        )
    if p.startswith("lib/features/"):
        return (
            "UI-модуль фичи.",
            "Экраны/листы/шиты без прямого HTTP.",
            "Optimistic UI через Brain; соблюдает `UX_CONTRACT`.",
            "Подключается из shell или соседних shared-компонентов.",
        )
    if p.startswith("lib/core/"):
        return (
            "Базовый слой (core).",
            "Тема, виджеты DS, time/voice утилиты.",
            "Не импортирует `features/` и Brain HTTP.",
            "Переиспользуется UI и частично Brain.",
        )
    if p.startswith("lib/shell/"):
        return (
            "Оболочка приложения (shell).",
            "Вкладки, voice routing, edit hosts.",
            "Связывает main → features.",
            "Re-export через `app_shell.dart`.",
        )
    if p.startswith("test/"):
        return (
            "Автотест.",
            "Покрытие регрессий домена/UI.",
            "Запуск: `flutter test`.",
            "Соответствует модулю по имени файла.",
        )
    if p.startswith("scripts/"):
        return (
            "Скрипт разработки/CI.",
            "Аудит, деплой, синхронизация.",
            "Не входит в релизный бинарник.",
            "См. `docs/DEPLOY.md` для deploy-пути.",
        )
    if p.startswith("docs/"):
        return (
            "Документация проекта.",
            "Контракты архитектуры и DATA_MAP.",
            "Источник правды для полей PB.",
            "Должна совпадать с деревом файлов.",
        )
    return (
        "Файл проекта.",
        "См. англ. блок Purpose/Contains.",
        "Смотри префикс пути для владения.",
        "Правила слоёв — `docs/APP_STRUCTURE.md`.",
    )


def entry(path: str) -> str:
    syms = symbols(path) if path.endswith(".dart") else []
    pe, ce, de, ce2 = purpose_en(path, syms)
    pr, cr, dr, cr2 = purpose_ru(path)
    sym_line = f"\n- **Symbols:** `{', '.join(syms)}`" if syms else ""
    return (
        f"### `{path}`\n\n"
        f"EN:\n\n"
        f"- **Purpose:** {pe}\n"
        f"- **Contains:** {ce}{sym_line}\n"
        f"- **Does:** {de}\n"
        f"- **Connected to:** {ce2}\n\n"
        f"RU:\n\n"
        f"- **Назначение:** {pr}\n"
        f"- **Что внутри:** {cr}\n"
        f"- **Что делает:** {dr}\n"
        f"- **Как связано с общей логикой:** {cr2}\n"
    )


def main() -> None:
    sections: list[tuple[str, list[str]]] = [
        ("Root project files", [p for p in tracked() if "/" not in p]),
        ("lib/ — application Dart", [p for p in tracked("lib") if p.endswith(".dart")]),
        ("lib/ — non-Dart", [p for p in tracked("lib") if not p.endswith(".dart")]),
        ("test/", tracked("test")),
        ("scripts/", tracked("scripts")),
        ("docs/", tracked("docs")),
        ("assets/", tracked("assets")),
        ("web/", tracked("web")),
        ("android/ (selected)", [p for p in tracked("android") if p.count("/") <= 3][:40]),
        ("ios/ (selected)", [p for p in tracked("ios") if p.count("/") <= 3][:40]),
        ("windows/ (selected)", [p for p in tracked("windows") if p.count("/") <= 3][:30]),
        ("linux/ (selected)", [p for p in tracked("linux") if p.count("/") <= 3][:30]),
        ("macos/ (selected)", [p for p in tracked("macos") if p.count("/") <= 3][:30]),
        (".github/", tracked(".github")),
        ("pb_hooks/", tracked("pb_hooks")),
        ("installer/", tracked("installer")),
        ("design/", tracked("design")),
    ]

    lines = [
        "# APP_STRUCTURE_DETAILED",
        "",
        "Detailed bilingual (EN/RU) file guide for the Life OS / Counter repository.",
        "",
        f"**Generated from tree scan at SHA `{SHA}` (2026-07-03).**",
        "",
        "Concise canonical map: [`APP_STRUCTURE.md`](APP_STRUCTURE.md).",
        "",
        "---",
        "",
    ]

    for title, files in sections:
        if not files:
            continue
        lines.append(f"## {title}")
        lines.append("")
        for f in sorted(files):
            lines.append(entry(f))
            lines.append("")

    platform_note = (
        "## Platform boilerplate (folder-level)\n\n"
        "EN: Deeper paths under `android/`, `ios/`, `windows/`, `linux/`, `macos/` "
        "are mostly Flutter-generated Gradle/Xcode/CMake runners, Gradle caches, and "
        "plugin registrants. They are required for builds but do not contain product "
        "business logic. Edit app identifiers, permissions, and icons at the top-level "
        "manifest/gradle files listed above.\n\n"
        "RU: Глубокие пути в platform-папках — в основном автоген Flutter (Gradle, "
        "Xcode, CMake). Бизнес-логика только в `lib/`. Манифесты верхнего уровня — "
        "точка правок permissions/icons.\n"
    )
    lines.append(platform_note)

    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT} ({len(lines)} lines)")


if __name__ == "__main__":
    main()
