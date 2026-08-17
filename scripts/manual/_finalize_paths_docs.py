#!/usr/bin/env python3
"""Temporary branch finalizer for the 2026-08-17 Paths/docs audit.

This file is deleted by the finalization workflow after it runs successfully.
"""

from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    if old not in text:
        raise RuntimeError(f"anchor missing in {path}: {old[:120]!r}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


def patch_ru_adapter() -> None:
    p = Path("scripts/manual/structure_en_ru_adapt.py")
    text = p.read_text(encoding="utf-8")

    helper = r'''

def _generic_folder_field_ru(key: str, field: str) -> str:
    """Meaningful Russian fallback for newly tracked folder classes."""
    k = key.replace("\\", "/").strip("/")
    leaf = k.rsplit("/", 1)[-1] if k else "root"

    if k == "test" or k.startswith("test/") or k == "integration_test" or k.startswith("integration_test/"):
        values = {
            "what": f"Каталог `{k}/` объединяет автоматические проверки области `{leaf}`.",
            "why": f"Отдельная группа проверок позволяет контролировать `{leaf}` независимо от других сценариев приложения.",
            "inside": "Содержит тестовые сценарии, входные данные и вспомогательные материалы, перечисленные ниже по файлам.",
            "affects": "Не входит в пользовательскую сборку; влияет на обнаружение регрессий до публикации приложения.",
            "when": f"Открывать при изменении поведения `{leaf}` или при падении связанной автоматической проверки.",
        }
        return values.get(field, "")

    if k == "docs" or k.startswith("docs/"):
        values = {
            "what": f"Раздел документации `{k}/` хранит материалы по теме `{leaf}`.",
            "why": f"Выделенная тема отделяет сведения о `{leaf}` от других архитектурных, продуктовых и эксплуатационных документов.",
            "inside": "Содержит спецификации, отчёты или справочные материалы, перечисленные ниже по файлам.",
            "affects": "Влияет на решения при разработке и сопровождении; содержимое само по себе не исполняется в приложении.",
            "when": f"Открывать при проверке требований, истории решений или текущего состояния темы `{leaf}`.",
        }
        return values.get(field, "")

    if k == "scripts" or k.startswith("scripts/") or k.endswith("/scripts") or "/scripts/" in k:
        values = {
            "what": f"Каталог `{k}/` объединяет автоматизацию и обслуживающие команды для области `{leaf}`.",
            "why": "Повторяемые операции вынесены в код, чтобы сборка, аудит и обслуживание не зависели от ручного набора команд.",
            "inside": "Содержит скрипты и вспомогательные файлы; точное действие каждого скрипта описано в его собственной записи.",
            "affects": "Влияет на разработку, проверку или публикацию, но не является пользовательским экраном приложения.",
            "when": f"Открывать при запуске или исправлении автоматизации, связанной с `{leaf}`.",
        }
        return values.get(field, "")

    if k == "lib" or k.startswith("lib/"):
        values = {
            "what": f"Раздел исходного кода `{k}/` объединяет ответственность `{leaf}` внутри текущей архитектуры.",
            "why": f"Выделение `{leaf}` удерживает эту ответственность отдельно от соседних слоёв и упрощает поиск владельца поведения.",
            "inside": "Содержит отслеживаемые исходники и подкаталоги этой ответственности; конкретные роли описаны ниже по файлам.",
            "affects": f"Изменения здесь могут менять работу области `{leaf}` в собранном приложении.",
            "when": f"Открывать при реализации, диагностике или рефакторинге ответственности `{leaf}`.",
        }
        return values.get(field, "")

    platform_roots = ("android", "ios", "web", "windows", "linux", "macos", "installer")
    top = k.split("/", 1)[0] if k else "repo"
    if top in platform_roots:
        values = {
            "what": f"Раздел `{k}/` содержит файлы цели `{top}`, относящиеся к `{leaf}`.",
            "why": f"Эти файлы нужны инструментам цели `{top}` для сборки, упаковки или запуска соответствующей части приложения.",
            "inside": "Содержит конфигурацию, ресурсы или исходники платформенного слоя; назначение уточняется в дочерних записях.",
            "affects": f"Влияет только на сборку или поведение приложения на цели `{top}` и не заменяет продуктовую логику Dart.",
            "when": f"Открывать, когда ошибка сборки или запуска цели `{top}` указывает на `{leaf}`.",
        }
        return values.get(field, "")

    values = {
        "what": f"Каталог `{k}/` хранит отслеживаемые материалы области `{leaf}`.",
        "why": f"Он выделяет ответственность `{leaf}` из соседних частей проекта и фиксирует её отдельным путём в системе контроля версий.",
        "inside": "Содержит конфигурацию, данные, ресурсы или инструменты; точные роли определяются дочерними файлами.",
        "affects": "Влияет на сборку, данные, обслуживание или отдельную подсистему согласно дочерним файлам этого каталога.",
        "when": f"Открывать при работе с областью `{leaf}` или когда на этот путь указывает сборка, аудит либо документация.",
    }
    return values.get(field, "")
'''

    if "def _generic_folder_field_ru(" not in text:
        marker = "\ndef adapt_folder_field_ru(key: str, field: str, en_val: str) -> str:\n"
        if marker not in text:
            raise RuntimeError("adapt_folder_field_ru marker missing")
        text = text.replace(marker, helper + marker, 1)

    start_marker = "def adapt_folder_field_ru(key: str, field: str, en_val: str) -> str:\n"
    end_marker = "\ndef adapt_file_field_ru(path: str, field: str, en_val: str) -> str:\n"
    before, rest = text.split(start_marker, 1)
    func, after = rest.split(end_marker, 1)
    old_tail = '''    adapted = sanitize_ru_prose(_phrase_translate(en_val))
    if ru_field_ok(adapted, min_cyrillic=6):
        return adapted
    return ""
'''
    new_tail = '''    adapted = sanitize_ru_prose(_phrase_translate(en_val))
    if ru_field_ok(adapted, min_cyrillic=6):
        return adapted
    fallback = sanitize_ru_prose(_generic_folder_field_ru(k, field))
    if fallback and ru_field_ok(fallback, min_cyrillic=6):
        return fallback
    return ""
'''
    if old_tail not in func:
        raise RuntimeError("adapt_folder_field_ru tail missing")
    func = func.replace(old_tail, new_tail, 1)
    p.write_text(before + start_marker + func + end_marker + after, encoding="utf-8")


def patch_navigation() -> None:
    p = Path("AGENT_NAVIGATION.md")
    text = p.read_text(encoding="utf-8")
    if "PATHS_FIRST_CLASS_AND_REPO_AUDIT_2026-08-17.md" not in text:
        text = text.replace(
            "| `docs/reports/FINAL_STRUCTURE_AUDIT_2026-07-06.md` | Final structure audit verdict + watchlist (repo-only). |",
            "| `docs/reports/FINAL_STRUCTURE_AUDIT_2026-07-06.md` | Final structure audit verdict + watchlist (repo-only). |\n"
            "| `docs/reports/PATHS_FIRST_CLASS_AND_REPO_AUDIT_2026-08-17.md` | Current Paths ownership migration + repository/doc-drift audit. |",
            1,
        )
    text = text.replace(
        "`lib/data/` (Brain + part files + `data/voice/` + `data/categories/`), `lib/data/local_sync/` (offline outboxes), `lib/features/` (UI modules + `settings/voice/` + `settings/categories/`),",
        "`lib/data/` (Brain + part files + `data/voice/` + `data/categories/` + `data/paths/` + `data/health/`), `lib/data/local_sync/` (offline outboxes), `lib/features/` (UI modules + `paths/` + `settings/voice/` + `settings/categories/` + `settings/health/` + `settings/notifications/`),",
        1,
    )
    if "| **Paths screen** |" not in text:
        anchor = "| **Plans screen** | `lib/features/planning/planning_view.dart` (barrel), `planning_page.dart`, `planning_page_shell.dart` | `PlanningSwipeWrapper` → `PlanningPage`; shell index 1 |"
        rows = (
            anchor
            + "\n| **Paths screen** | `lib/features/paths/paths_page.dart` | `PathsPage`; shell index 6 on every form factor; desktop side nav and mobile/tablet More select the same destination |"
            + "\n| **Paths domain** | `lib/data/paths/path_repository.dart` | `PathRepository`, `ProjectPathSnapshot`, `auditPathStructure`; transition adapter over existing active Path roots |"
        )
        if anchor not in text:
            raise RuntimeError("AGENT_NAVIGATION Plans row missing")
        text = text.replace(anchor, rows, 1)
    p.write_text(text, encoding="utf-8")


def patch_roadmap() -> None:
    p = Path("docs/ROADMAP.md")
    text = p.read_text(encoding="utf-8").replace("Updated 2026-06-09.", "Updated 2026-08-17.", 1)
    if "### P1P — Paths first-class architecture (#93)" not in text:
        anchor = "**Docs:** `docs/ARCHITECTURE.md` § PERFORMANCE_KILL_SWITCH_LAW · `docs/UX_CONTRACT.md` § Performance & Responsiveness Contract · `AGENT_NAVIGATION.md` · `lib/core/perf_flags.dart` · `lib/core/p0u_feature_flags.dart`\n\n"
        section = """### P1P — Paths first-class architecture (#93) — in progress

**Goal:** make Paths a real domain and app destination that can later support safe AI-assisted Draft → Review → Publish → Planner workflows without granting AI direct application/database authority.

**Foundation completed 2026-08-17:**
- ✅ `lib/data/paths/path_repository.dart` is the Path domain/transition boundary over current active roots; feature UI no longer parses storage markers.
- ✅ `lib/features/paths/paths_page.dart` is the first-class responsive destination; opening it is read-only with respect to migration/bootstrap/governance/Planner generation.
- ✅ Main shell index 6 owns Paths on desktop/mobile/tablet; desktop no longer needs a nested second shell for the active destination.
- ✅ Duplicate active roots are detected without read-time deletion.
- ✅ Generic Path structure validation is pure and covered by three focused tests.
- ✅ Existing Health Connect/sleep/unfilled-time production modules discovered by strict audit were added to the canonical structure manifest.
- ✅ Completed one-off category-default-time self-patching workflow removed.
- ✅ `APP_STRUCTURE_DETAILED` generation now has a Russian-first fallback for newly tracked folder classes instead of copying EN prose into RU sections.

**Remaining phases:**
1. extract legacy Path migration/repair and Planner bridge/governance out of shell;
2. durable `draft` / `reviewed` / `active` / `archived` revisions plus Project Memory fields;
3. move hard-coded project-specific policy from Dart into stored project/Path context;
4. provider-neutral `/api/ai/...` Path proposal layer with whitelisted tools, validation, approval for sensitive actions, audit and undo;
5. idempotent live migration and parity proof; only then delete old V1/V2/V3/project-specific shell code.

Report: `docs/reports/PATHS_FIRST_CLASS_AND_REPO_AUDIT_2026-08-17.md`.

"""
        if anchor not in text:
            raise RuntimeError("ROADMAP P0V docs anchor missing")
        text = text.replace(anchor, anchor + section, 1)
    p.write_text(text, encoding="utf-8")


def patch_changelog() -> None:
    p = Path("CHANGELOG.md")
    text = p.read_text(encoding="utf-8")
    marker = "## 2026-08-17 — Paths first-class foundation and repository audit"
    if not text.startswith(marker):
        entry = """## 2026-08-17 — Paths first-class foundation and repository audit [engineering]

- Added `lib/data/paths/path_repository.dart` + `lib/features/paths/paths_page.dart`; Paths is now main-shell destination 6 and page-open no longer requires migration/bootstrap/governance/Planner side effects.
- Preserved current Path rows through a transition repository, report duplicate active roots without deleting on read, and added three focused structure-audit tests.
- Strict repository audit exposed 13 already-shipped Health Connect/sleep/unfilled-time Dart files missing from `APP_STRUCTURE.md`; the canonical manifest was repaired instead of weakening the guard.
- Fixed generated structure-doc bilingual fallback so newly tracked folders receive meaningful Russian text instead of copied English.
- Removed completed `.github/workflows/temp-fix-category-default-time.yml`; synchronized Architecture, UX, structure, agent routing, Roadmap and detailed structure documentation.
- Verification: strict architecture guard + `git diff --check`, analyzer, 3 Paths tests, release web build and Android arm64 release build all pass on the production Flutter 3.41.6 toolchain.

"""
        p.write_text(entry + text, encoding="utf-8")


def add_folder_block(text: str, anchor: str, key: str, block: str) -> str:
    if f'"{key}": {{' in text:
        return text
    if anchor not in text:
        raise RuntimeError(f"folder guide anchor missing for {key}")
    return text.replace(anchor, block + anchor, 1)


def patch_folder_guides() -> None:
    p = Path("scripts/manual/structure_guide_data.py")
    text = p.read_text(encoding="utf-8")
    data_anchor = '    "lib/data/profile": {'
    text = add_folder_block(
        text,
        data_anchor,
        "lib/data/paths",
        '''    "lib/data/paths": {
        "what": "First-class Path domain boundary — structured project paths, transition storage interpretation, and generic validation.",
        "why": "Paths must be usable by UI, Planner, and future AI proposals without feature/shell code parsing storage markers.",
        "inside": "`path_repository.dart`: Path snapshots, status vocabulary, compatibility load/save, duplicate-root reporting, structure audit.",
        "affects": "Paths screen and future explicit Path → Planner / AI proposal services.",
        "when": "Path loading, stage/action structure, active-root conflicts, or Path storage migration.",
        "delete": "No — first-class Paths depends on this domain boundary.",
        "related": "`lib/features/paths/`, `docs/ARCHITECTURE.md` §6.1, issue #93.",
    },
''',
    )
    text = add_folder_block(
        text,
        data_anchor,
        "lib/data/health",
        '''    "lib/data/health": {
        "what": "Sleep/health Brain services — pure sleep policy plus device/cloud sleep synchronization orchestration.",
        "why": "Imported health sleep must be normalized and conflict-checked before becoming Life OS timeline data.",
        "inside": "Health sleep policy, device sync service, cloud sleep sync service.",
        "affects": "Sleep history, Morning Start Day, health integration status and background sync.",
        "when": "Recent sleep is missing, duplicated, overlaps manual records, or a health sync reports stale/error state.",
        "delete": "No — shipped health/sleep integration depends on it.",
        "related": "`lib/services/health_connect/`, Timeline sleep policy, health settings.",
    },
''',
    )
    feature_anchor = '    "lib/features/planning": {'
    text = add_folder_block(
        text,
        feature_anchor,
        "lib/features/paths",
        '''    "lib/features/paths": {
        "what": "First-class Paths UI — project list/detail, goal, stages, actions, progress, and structure warnings.",
        "why": "Paths is a real app destination rather than product UI embedded inside shell/More code.",
        "inside": "`paths_page.dart`.",
        "affects": "Desktop side-nav Paths and phone/tablet More → Paths.",
        "when": "Path navigation, responsive layout, Path goal/stage/action editing.",
        "delete": "No — the Paths destination disappears.",
        "related": "`lib/data/paths/path_repository.dart`, `lib/app/shell/app_shell.dart`.",
    },
''',
    )
    text = add_folder_block(
        text,
        feature_anchor,
        "lib/features/settings/health",
        '''    "lib/features/settings/health": {
        "what": "Health integration settings UI.",
        "why": "Users need connection/sync state and explicit controls for supported health sleep sources.",
        "inside": "`health_connect_settings_section.dart`.",
        "affects": "Profile/settings health integration controls.",
        "when": "Health Connect setup, sync status, or permissions UI is wrong.",
        "delete": "No — shipped health settings depend on it.",
        "related": "`lib/data/health/`, `lib/services/health_connect/`.",
    },
''',
    )
    text = add_folder_block(
        text,
        feature_anchor,
        "lib/features/settings/notifications",
        '''    "lib/features/settings/notifications": {
        "what": "Notification-specific settings UI.",
        "why": "Users control reminder behavior separately from Timeline rendering and OS notification delivery.",
        "inside": "`unfilled_time_notifications_section.dart`.",
        "affects": "Unfilled Timeline-gap reminder preferences.",
        "when": "Gap reminder enable/disable or notification preference UI is wrong.",
        "delete": "No — shipped notification settings depend on it.",
        "related": "`lib/data/records/unfilled_time_gap_service.dart`, `lib/services/unfilled_time_notification_service.dart`.",
    },
''',
    )
    text = add_folder_block(
        text,
        feature_anchor,
        "lib/services/health_connect",
        '''    "lib/services/health_connect": {
        "what": "Platform bridge for Health Connect sleep reads and permissions.",
        "why": "Brain health sync needs one capability-gated interface across Android and unsupported platforms.",
        "inside": "Sleep models, conditional facade, Android/IO implementation, unsupported-platform stub.",
        "affects": "Android Health Connect sleep import only; other platforms safely stub the capability.",
        "when": "Health Connect permission/read behavior or platform gating breaks.",
        "delete": "No — Android health integration depends on it.",
        "related": "`lib/data/health/health_sleep_sync_service.dart`.",
    },
''',
    )
    p.write_text(text, encoding="utf-8")


def patch_report() -> None:
    p = Path("docs/reports/PATHS_FIRST_CLASS_AND_REPO_AUDIT_2026-08-17.md")
    text = p.read_text(encoding="utf-8")
    start = "## Verification required before merge\n\n"
    if start not in text:
        return
    prefix, _ = text.split(start, 1)
    final = """## Repository-wide structural drift found by this pass

Strict `architecture_guard.ps1 -Strict` initially found 13 production Dart files that already existed on `main` but were absent from `APP_STRUCTURE.md`: Health Connect sleep services/models, health sleep sync/policy, cloud sleep sync, unfilled-time gap service/policy/banner, notification bridge/settings, and health settings. These were documented in the canonical manifest; the guard was not weakened.

Regenerating `APP_STRUCTURE_DETAILED.md` then exposed a second documentation defect: newly tracked folder classes could fall through the RU adapter and silently reuse English prose in the Russian block. The generator now supplies a Russian-first semantic fallback for `lib`, tests, docs, scripts, platform trees and other tracked directories while keeping the quality gate enabled.

The guard continues to report its pre-existing watchlist warnings for large/mixed shell files and raw legacy Material controls. Those are not automatic delete/split targets; `shell_more_menu.dart` remains especially relevant to issue #93 because old Path migration/UI code still lives there.

## Verification recorded 2026-08-17

- `architecture_guard.ps1 -Strict` — passed after manifest parity repair.
- `git diff --check` — passed.
- `flutter analyze --no-fatal-infos --no-fatal-warnings` — passed.
- `flutter test test/paths/path_structure_audit_test.dart` — 3/3 passed.
- Release web build — passed with the production Flutter **3.41.6** toolchain.
- Android arm64 release APK build — passed with the same production toolchain.
- A first verifier attempt used floating Flutter `stable` (3.47.0) and failed inside `flutter_quill 11.5.0` because that dependency is incompatible with the newer `TextInputClient` API. Production deploy pins Flutter 3.41.6, so verification was corrected to the production toolchain rather than changing application code for a false gate.

## Merge boundary

This pass is safe to review/merge as the **foundation** of #93, but #93 itself remains open. Old Path migration/bootstrap/governance code is deliberately retained until an idempotent migration/repair service, durable revisions/Project Memory, and Planner bridge parity exist.
"""
    p.write_text(prefix + final, encoding="utf-8")


if __name__ == "__main__":
    patch_ru_adapter()
    patch_navigation()
    patch_roadmap()
    patch_changelog()
    patch_folder_guides()
    patch_report()
