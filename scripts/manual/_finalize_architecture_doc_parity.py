from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(text: str, old: str, new: str, *, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"missing replacement anchor: {label}")
    return text.replace(old, new, 1)


def replace_regex(text: str, pattern: str, replacement: str, *, label: str, flags: int = 0) -> str:
    out, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count != 1:
        raise RuntimeError(f"regex replacement failed ({count}): {label}")
    return out


# ---------------------------------------------------------------------------
# APP_STRUCTURE — remove stale rows and make duplicate manifest sections agree
# with the canonical ownership map.
# ---------------------------------------------------------------------------
app = read("docs/APP_STRUCTURE.md")
app = replace_once(
    app,
    "| `app/shell/shared/shell_top_status_bars.dart` | Presentation-only top status bars for Profile hydration and unfilled-time notices |",
    "| `app/shell/shared/shell_top_status_bars.dart` | Presentation-only top status stack for offline sync, Profile hydration, and unfilled-time notices |\n"
    "| `app/shell/shared/offline_sync_status_bar.dart` | Shell-owned O1 offline/sync status UI; renders Brain `OfflineSyncController` state and forwards tap-to-retry |",
    label="shell top status ownership",
)
app = replace_once(
    app,
    "Compatibility re-exports (remove when callers migrate): root `lib/app_shell.dart`, `core/navigation/shell_side_navigation.dart`, `features/shared/profile_hydration_status_bar.dart`, `features/profile/settings/settings_page.dart`.",
    "Compatibility re-exports (remove when callers migrate): root `lib/app_shell.dart`, `core/navigation/shell_side_navigation.dart`, `app/shell/shared/settings_page.dart`.",
    label="compatibility re-export list",
)
app = replace_once(
    app,
    "Multi-feature category presentation, tree, picker, and local visibility prefs. Brain keeps PocketBase CRUD under `lib/data/categories/`. Settings manager UI lives under `lib/features/settings/categories/`.",
    "Multi-feature category presentation, tree, and picker contracts. Brain keeps PocketBase CRUD under `lib/data/categories/`. Settings manager UI lives under `lib/features/settings/categories/`.",
    label="shared categories scope",
)
app = app.replace(
    "| `visibility/category_visibility_prefs.dart` | Local hidden ids (`hidden_category_ids_json`) |\n",
    "",
)
app = app.replace(
    "| `notes/widgets/notes_special_block_widgets.dart` | Divider, table, link card, and Life OS reference block renderers |\n",
    "",
)
app = replace_once(
    app,
    "| `notes/widgets/notes_component_structural_blocks.dart` | Canonical quote, divider, table, and parameterized compact/extended table picker *(part)* |",
    "| `notes/widgets/notes_component_structural_blocks.dart` | Canonical quote, divider, table, link/reference structural blocks, and parameterized compact/extended table picker *(part)* |",
    label="notes structural owner",
)
app = replace_once(
    app,
    "| `shared/` | `shared_widgets.dart` (barrel), `activity_detail_sheet.dart`, `planning_task_edit_sheet.dart`, `timeline_record_edit_sheet.dart`, `empty_state_placeholder.dart`, **`edit_sheet/`** (autosave gate, time helpers/picker, checklist, repeat RRULE helpers, quill toolbar, parallel record panels, **`category_edit_draft.dart`**, **`planning_edit_result_actions.dart`**, **`timeline_edit_result_actions.dart`**), **`notes_editor/`** (`notes_editor_launcher.dart`, `notes_editor_sheet.dart`), `offline_sync_status_bar.dart` | Activity edit sheets, Notes launch/sheet routing, Omni-Picker entry, offline sync banner, plan/record category draft helpers |",
    "| `shared/` | `shared_widgets.dart` (barrel), `activity_detail_sheet.dart`, `planning_task_edit_sheet.dart`, `timeline_record_edit_sheet.dart`, `empty_state_placeholder.dart`, **`edit_sheet/`** (autosave gate, time helpers/picker, checklist, repeat RRULE helpers, quill toolbar, parallel record panels, **`category_edit_draft.dart`**, **`planning_edit_result_actions.dart`**, **`timeline_edit_result_actions.dart`**), **`notes_editor/`** (`notes_editor_launcher.dart`, `notes_editor_sheet.dart`) | Activity edit sheets, Notes launch/sheet routing, Omni-Picker entry, and plan/record category draft helpers |",
    label="features shared summary",
)
old_shell_manifest = """| `app/shell/app_shell.dart` | Shell dashboard entry (see §3.1.1) |
| `app/shell/shared/shell_core.dart` | Shell core logic *(part)* |
| `app/shell/shared/shell_tab_host.dart` | Tab host builders *(part)* |
| `app/shell/shared/shell_edit_hosts.dart` | Edit sheet hosts *(part)* |
| `app/shell/shared/shell_more_menu.dart` | More menu *(part)* |
| `app/shell/shared/shell_voice_routing.dart` | Voice routing *(part)* |
| `app/shell/shared/shell_offline_banner.dart` | Offline banner slot |
| `app/shell/shared/shell_shared.dart` | Shell shared helpers |
| `app/shell/shared/shell_form_factor.dart` | Form-factor width resolve |"""
new_shell_manifest = """| `app/shell/app_shell.dart` | Shell dashboard entry/composition root (see §3.1.1) |
| `app/shell/shared/shell_core.dart` | Core shell date/task-loading state *(part)* |
| `app/shell/shared/shell_task_actions.dart` | Shell task/record action orchestration *(part)* |
| `app/shell/shared/shell_edit_hosts.dart` | Timeline/Planning edit-sheet hosts *(part)* |
| `app/shell/shared/shell_tab_host.dart` | Feature tab composition; depends on edit hosts *(part)* |
| `app/shell/shared/shell_more_menu.dart` | More navigation actions *(part)* |
| `app/shell/shared/shell_voice_routing.dart` | Desktop voice command/hotkey/overlay routing *(part)* |
| `app/shell/shared/shell_voice_input.dart` | Generic FAB / VoiceInputSheet routing *(part)* |
| `app/shell/shared/shell_voice_integration.dart` | Desktop tray/global-hotkey attachment *(part)* |
| `app/shell/shared/shell_lifecycle.dart` | Shell startup/dispose wiring *(part)* |
| `app/shell/shared/shell_chrome.dart` | Responsive shell scaffold/chrome *(part)* |
| `app/shell/shared/shell_top_status_bars.dart` | Top status stack for sync/Profile/time-gap notices |
| `app/shell/shared/offline_sync_status_bar.dart` | O1 offline/sync tap-to-retry status bar |
| `app/shell/shared/shell_shared.dart` | Shell shared helpers |
| `app/shell/shared/shell_form_factor.dart` | Form-factor width resolve |"""
app = replace_once(app, old_shell_manifest, new_shell_manifest, label="duplicate shell manifest")
app = app.replace(
    "| `shared/profile_hydration_status_bar.dart` | Profile hydration error banner |\n",
    "",
)
app = app.replace(
    "| `shared/offline_sync_status_bar.dart` | O1 offline/sync tap-to-retry banner |\n",
    "",
)
write("docs/APP_STRUCTURE.md", app)

# ---------------------------------------------------------------------------
# ARCHITECTURE — point contracts at current owners.
# ---------------------------------------------------------------------------
architecture = read("docs/ARCHITECTURE.md")
architecture = replace_once(
    architecture,
    "Anchors: `lib/data/local_sync/record_mutation_outbox.dart`, `lib/data/local_sync/plan_mutation_outbox.dart`, `lib/data/local_sync/offline_sync_state.dart`, `lib/data/local_sync/sync_manager.dart`, `DbCoreExtension.flushPendingLocalMutations`, `RecordServiceExtension.flushPendingRecordMutations`, `PlanServiceExtension.flushPendingPlanMutations`, `_OfflineSyncStatusBar` in `app_shell.dart`.",
    "Anchors: `lib/data/local_sync/record_mutation_outbox.dart`, `lib/data/local_sync/plan_mutation_outbox.dart`, `lib/data/local_sync/offline_sync_state.dart`, `lib/data/local_sync/sync_manager.dart`, `DbCoreExtension.flushPendingLocalMutations`, `RecordServiceExtension.flushPendingRecordMutations`, `PlanServiceExtension.flushPendingPlanMutations`, and shell presentation `lib/app/shell/shared/offline_sync_status_bar.dart`.",
    label="offline architecture anchor",
)
architecture = architecture.replace(
    "| **NOCODB_MANIFEST.md** | Legacy Noco contract — do not use for new work. |\n",
    "",
)
write("docs/ARCHITECTURE.md", architecture)

# ---------------------------------------------------------------------------
# ROADMAP — current names/anchors; preserve history without presenting old paths
# as live architecture.
# ---------------------------------------------------------------------------
roadmap = read("docs/ROADMAP.md")
roadmap = replace_once(
    roadmap,
    "**Single canonical plan.** Drawn from the April 2026 audit (findings captured in Phase 1 below). Updated 2026-06-09.",
    "**Single canonical plan.** Drawn from the April 2026 audit (findings captured in Phase 1 below). Last architecture/documentation parity verification: 2026-08-18.",
    label="roadmap verification date",
)
roadmap = roadmap.replace("V1~~ ✅ (CLAUDE.md nav map)", "V1~~ ✅ (AGENT_NAVIGATION.md nav map)")
roadmap = replace_once(
    roadmap,
    "**Docs:** `docs/ARCHITECTURE.md` § PERFORMANCE_KILL_SWITCH_LAW · `docs/UX_CONTRACT.md` § Performance & Responsiveness Contract · `AGENT_NAVIGATION.md` · `lib/core/perf_flags.dart` · `lib/core/p0u_feature_flags.dart`",
    "**Docs:** `docs/ARCHITECTURE.md` § PERFORMANCE_KILL_SWITCH_LAW · `docs/UX_CONTRACT.md` § Performance & Responsiveness Contract · `AGENT_NAVIGATION.md` · `lib/shared/diagnostics/performance/runtime_flags.dart` · `lib/shared/diagnostics/performance/shell_flags.dart`",
    label="roadmap performance anchors",
)
roadmap = replace_once(
    roadmap,
    "**UI (`app_shell.dart`):**",
    "**UI (`lib/app/shell/shared/offline_sync_status_bar.dart` via `ShellTopStatusBars`):**",
    label="roadmap offline UI owner",
)
roadmap = replace_once(
    roadmap,
    "Low severity (defer): `auth_service.dart:134, 163` — non-deterministic UID fallbacks.",
    "No open Phase 1 architecture item remains in the retired root auth-service path; authentication now lives behind `lib/data/auth_bridge.dart` and `lib/features/auth/`.",
    label="retired auth service roadmap note",
)
roadmap = replace_once(
    roadmap,
    "**Status:** Repository cleanup complete with explicitly deferred feature work. Ordinary repository-structure cleanup is **formally closed** as of Phase 2G (2026-07-23). Do not open another generic structure-cleanup pass; remaining items need separate product/design approval (V7 adoption, Phase 2D wiring, Notes/Lists/Voice watchlist orphans, Stage E seams, notifications/alarms — not cleanup).",
    "**Status:** Repository cleanup is complete. The 2026-08-18 targeted ownership/parity pass additionally aligned Shell, Profile, Planning startup, Voice, Paths compatibility boundaries, restored the O1 sync indicator to its shell owner, and made documentation parity machine-checked. Do not open generic cleanup by line count; future structural work must be triggered by a concrete ownership violation or product requirement.",
    label="roadmap cleanup status",
)
roadmap = roadmap.replace(
    "| **C** | Doc sync (APP_STRUCTURE, CLAUDE, audit) | ✅ |",
    "| **C** | Doc sync (`APP_STRUCTURE`, `AGENT_NAVIGATION`, audit) | ✅ |",
)
roadmap = replace_regex(
    roadmap,
    r"### ~~V1\. Sharpen `CLAUDE\.md` into a navigation map~~ ✅ \(shipped 2026-06-10\)\n\n`CLAUDE\.md` updated for O1 local sync \(`lib/data/local_sync/`\), flush/resume symbols, offline banner, and shipped F1 status\. Goal: any AI session answers \"where do I open first\?\" from `CLAUDE\.md` alone — \*\*keep this table current when symbols move\.\*\*",
    "### ~~V1. Maintain `AGENT_NAVIGATION.md` as the navigation map~~ ✅ (shipped 2026-06-10; renamed later)\n\n`AGENT_NAVIGATION.md` is the canonical symbol/path navigation map for AI work. It covers O1 local sync (`lib/data/local_sync/`), shell ownership, feature entry points, and current diagnostics/cache owners. Keep it synchronized whenever canonical symbols move.",
    label="V1 navigation map",
)
write("docs/ROADMAP.md", roadmap)

# ---------------------------------------------------------------------------
# AGENT_NAVIGATION — remove obsolete ownership/debt language and point every
# canonical entry at the current source path.
# ---------------------------------------------------------------------------
nav = read("AGENT_NAVIGATION.md")
nav = replace_regex(
    nav,
    r"Verified 2026-06-10 .*?\n\n\*\*Known drift\*\* \(harmless; do not “fix” unless asked\):\n\n\| Item \| Actual \| Doc says \|\n\| :--- \| :--- \| :--- \|\n(?:\|.*\n)+?\n---",
    "Verified 2026-08-18 after the Shell/Profile/Planning/Voice ownership pass and repo-wide documentation parity audit. **Current governing docs have no accepted structure drift.** Historical reports may describe earlier paths, but this navigation map points only at live canonical owners.\n\n---",
    label="agent navigation drift section",
    flags=re.S,
)
nav = nav.replace(
    "| **Offline / sync banner** | `lib/features/shared/offline_sync_status_bar.dart` | `OfflineSyncStatusBar` — tap → `flushPendingLocalMutations`; labels via `offline_sync_*` in `dictionary.dart` |",
    "| **Offline / sync banner** | `lib/app/shell/shared/offline_sync_status_bar.dart` | `OfflineSyncStatusBar` — shell presentation over `OfflineSyncController`; tap → `flushPendingLocalMutations`; labels via `offline_sync_*` |",
)
nav = nav.replace(
    "| **Tag UI — pickers** | `lib/features/shared/chip_component.dart` | `TagQuickPickStrip`, `TagChip` |",
    "| **Tag UI — pickers** | `lib/core/widgets/chip_component.dart` | `TagQuickPickStrip`, `TagChip`, `CategoryChip` |",
)
nav = nav.replace(
    "| **Offline sync banner** | `lib/features/shared/offline_sync_status_bar.dart` | `OfflineSyncStatusBar` (top of shell `IndexedStack`) |",
    "| **Offline sync banner** | `lib/app/shell/shared/offline_sync_status_bar.dart` | `OfflineSyncStatusBar` via `ShellTopStatusBars` |",
)
nav = nav.replace(
    "| Shell sync / offline banner | `lib/features/shared/offline_sync_status_bar.dart` | `OfflineSyncStatusBar` |",
    "| Shell sync / offline banner | `lib/app/shell/shared/offline_sync_status_bar.dart` | `OfflineSyncStatusBar` |",
)
nav = nav.replace(
    "| **Sheet host (modal)** | `lib/app_shell.dart` | `_openEditDialog` / `_showEditRecordSheetForTimeline` → `showModalBottomSheet` + `ActivityDetailSheet` |",
    "| **Sheet host (modal)** | `lib/app/shell/shared/shell_edit_hosts.dart` | Timeline/Planning edit-sheet host methods → `ActivityDetailSheet` |",
)
nav = nav.replace(
    "| **More overflow menu** | `lib/app_shell.dart` | `_openMoreMenu()` modal bottom sheet — Categories, Profile, admin Component Lab (removed orphan `more_view.dart` in Stage A) |",
    "| **More overflow menu** | `lib/app/shell/shared/shell_more_menu.dart` | More bottom sheet + shell navigation actions |",
)
nav = nav.replace(
    "| Voice input dispatcher (routes by active tab) | `lib/app/shell/shared/shell_voice_routing.dart` | Shell Voice routing mixin (via `app_shell.dart`) |",
    "| Generic voice input dispatcher (routes by active tab) | `lib/app/shell/shared/shell_voice_input.dart` | `ShellVoiceInput` — FAB/VoiceInputSheet → Timeline/Planning/Backlog |",
)
nav = nav.replace(
    "| Desktop voice shell wiring | `lib/app/shell/shared/shell_voice_routing.dart` | `toggleDesktopVoiceWidget`, submit parsed, init layer |",
    "| Desktop voice command routing | `lib/app/shell/shared/shell_voice_routing.dart` | `toggleDesktopVoiceWidget`, overlay/command submit routing |\n| Desktop voice attachment lifecycle | `lib/app/shell/shared/shell_voice_integration.dart` | tray/global-hotkey attach and reattach |",
)
nav = nav.replace(
    "| UI dispatch wrappers (shell-side, debounced) | `lib/app_shell.dart` | `_stopRecordByDocId` / `_deleteRecordByDocId` / `_startTaskFromInput` |",
    "| UI task/record action orchestration | `lib/app/shell/shared/shell_task_actions.dart` | start/stop/delete/retry and source-plan suggestion presentation |",
)
old_perf = """## P0 / performance layer (active architecture debt)

**Not random garbage — active diagnostics + warm-cache for Timeline/Planning date paging (P0U track).** Consolidate later; do not delete while paging work is open. Full file list: `docs/APP_STRUCTURE.md` §5.3–5.4. Structure guard: `scripts/audit/architecture_guard.ps1 -Strict`.

| Concept | File | Notes |
| :--- | :--- | :--- |
| Master perf probe | `lib/core/perf_diag.dart` | `--dart-define=PERF_DIAG=true` |
| Bisect toggles | `lib/core/perf_flags.dart` | LazyIndexedStack, pager sync |
| Runtime diagnostics | `lib/shared/diagnostics/runtime_log.dart` | Release-safe runtime markers |
| Runtime flags | `lib/shared/diagnostics/performance/runtime_flags.dart` | Kill switches (default off) |
| Startup log | `lib/shared/diagnostics/startup_log.dart` | Boot timing |
| Rebuild metrics | `lib/shared/diagnostics/performance/rebuild_metrics.dart` | `--dart-define=PERF_DIAG=true` only |
| Shell flags | `lib/shared/diagnostics/performance/shell_flags.dart` | Shell + Planning Time View canvas bisect toggles |
| Day cache | `lib/data/cache/day_snapshot_window.dart` | Warm day snapshot window |
| Render cache | `lib/data/cache/render_snapshot.dart`, `rendered_day_body_cache.dart` | Rendered day-body cache |
| Structure guard | `scripts/audit/architecture_guard.ps1` | `-Strict` enforces `docs/APP_STRUCTURE.md` |
| Structure guide (RU) | `docs/APP_STRUCTURE_DETAILED.md` | Bilingual EN/RU per-file guide |
| Plan duplicate log | `lib/data/plans/diagnostics/plan_duplicate_log.dart` | Planning-domain Brain duplicate / stream lifecycle markers |
| Warm snapshot data | `lib/data/warm_day_window.dart` | WarmSnapshotWindow |
| Rendered body cache | `lib/data/rendered_day_body_cache.dart` | Day-body LRU |
| Render snapshot | `lib/data/p0t_render_snapshot.dart` | Snapshot helpers |
| Eager day strip | `lib/core/widgets/eager_day_content_strip.dart` | P0U widget |
| Mounted day window | `lib/core/widgets/mounted_day_window.dart` | P0U widget |
| Structure guard | `scripts/audit/architecture_guard.ps1` | Warning-mode audit |"""
new_perf = """## Performance / diagnostics layer (current owners)

Performance law is permanent, but the old P0U experiment filenames are retired. Current diagnostics, caches, and strip owners are below; use these paths instead of resurrecting old experiment modules.

| Concept | File | Notes |
| :--- | :--- | :--- |
| Runtime diagnostics | `lib/shared/diagnostics/runtime_log.dart` | Release-safe runtime markers |
| Runtime flags | `lib/shared/diagnostics/performance/runtime_flags.dart` | Kill switches and focused diagnostics |
| Startup log | `lib/shared/diagnostics/startup_log.dart` | Boot timing |
| Rebuild metrics | `lib/shared/diagnostics/performance/rebuild_metrics.dart` | Rebuild instrumentation |
| Shell flags | `lib/shared/diagnostics/performance/shell_flags.dart` | Shell + Planning Time View canvas bisect toggles |
| Warm day snapshots | `lib/data/cache/day_snapshot_window.dart` | `WarmSnapshotWindow` + day snapshot DTOs |
| Render snapshots | `lib/data/cache/render_snapshot.dart` | Timeline/Planning render snapshot DTOs + cache |
| Rendered body cache | `lib/data/cache/rendered_day_body_cache.dart` | Day-body LRU |
| Mounted/eager day strip | `lib/core/widgets/day_content_strip.dart` | `EagerDayContentStrip` + mounted slot implementation |
| Plan duplicate log | `lib/data/plans/diagnostics/plan_duplicate_log.dart` | Planning-domain duplicate/stream lifecycle markers |
| Structure guard | `scripts/audit/architecture_guard.ps1` | `-Strict` enforces architecture boundaries + APP_STRUCTURE manifest |
| Documentation parity | `scripts/audit/documentation_parity.py` | Live governing-doc path checks + reverse APP_STRUCTURE check |
| Detailed structure guide | `docs/APP_STRUCTURE_DETAILED.md` | Generated bilingual per-file guide |"""
nav = replace_once(nav, old_perf, new_perf, label="agent navigation performance section")
write("AGENT_NAVIGATION.md", nav)

# ---------------------------------------------------------------------------
# Other live docs with obsolete offline-sync ownership.
# ---------------------------------------------------------------------------
product_inventory = read("docs/website/PRODUCT_INVENTORY.md")
product_inventory = product_inventory.replace(
    "`lib/data/local_sync/*`; `lib/app_shell.dart` — `_OfflineSyncStatusBar`; `docs/ROADMAP.md` O1 ✅",
    "`lib/data/local_sync/*`; `lib/app/shell/shared/offline_sync_status_bar.dart`; `docs/ROADMAP.md` O1 ✅",
)
write("docs/website/PRODUCT_INVENTORY.md", product_inventory)

# Brain comments should name the live UI symbol without a retired private name.
offline_state = read("lib/data/local_sync/offline_sync_state.dart")
offline_state = offline_state.replace(
    "/// Global offline / sync indicator state for [app_shell.dart].",
    "/// Global offline / sync indicator state rendered by shell presentation.",
)
offline_state = offline_state.replace(
    "/// Mirrors [_OfflineSyncStatusBar] label branch for diagnostics.",
    "/// Mirrors [OfflineSyncStatusBar] label branches for diagnostics.",
)
write("lib/data/local_sync/offline_sync_state.dart", offline_state)

# ---------------------------------------------------------------------------
# Architecture Guard: make APP_STRUCTURE bidirectional, with the generated env
# file as the only explicit exception.
# ---------------------------------------------------------------------------
guard = read("scripts/audit/architecture_guard.ps1")
needle = """# --- 5. Deleted-file regressions ---
"""
reverse_check = r'''# --- 4b. APP_STRUCTURE rows pointing at deleted Dart files ---
# Section 4 guarantees code -> docs. This reverse pass guarantees docs -> code,
# preventing renamed/deleted implementation rows from lingering indefinitely.
$appStructureDartRowMatches = [regex]::Matches(
    $appStructure,
    '(?m)^\|\s*`([^`]+\.dart)`\s*\|'
)
$appStructureReverseExemptions = @(
    'env.dart',
    'core/env/env.dart',
    'lib/core/env/env.dart'
)
foreach ($match in $appStructureDartRowMatches) {
    $declared = $match.Groups[1].Value.Trim().TrimStart('.', '/')
    if ($appStructureReverseExemptions -contains $declared) { continue }
    $candidates = [System.Collections.Generic.List[string]]::new()
    $candidates.Add($declared)
    if ($declared.StartsWith('lib/')) {
        $candidates.Add($declared.Substring(4))
    }
    $found = $false
    foreach ($f in $libDart) {
        $actual = (Get-RepoRelativePath $f.FullName) -replace '^lib/', ''
        foreach ($candidate in $candidates) {
            if ($actual -eq $candidate -or $actual.EndsWith('/' + $candidate)) {
                $found = $true
                break
            }
        }
        if ($found) { break }
    }
    if (-not $found) {
        Add-Violation "STALE_APP_STRUCTURE_DART $declared"
    }
}

# --- 5. Deleted-file regressions ---
'''
guard = replace_once(guard, needle, reverse_check, label="reverse APP_STRUCTURE guard")
write("scripts/audit/architecture_guard.ps1", guard)

# ---------------------------------------------------------------------------
# Detailed structure generator: generic folder fallback must always produce
# genuine RU prose instead of copying synthesized EN fields into the RU block.
# ---------------------------------------------------------------------------
guide = read("scripts/manual/structure_guide_data.py")
start = guide.index("def _folder_ru_auto(")
end = guide.index("\ndef ensure_folder_ru(", start)
new_auto = r'''def _folder_ru_auto(key: str, en: dict[str, str]) -> dict[str, str]:
    """Return a clean Russian fallback for folders without curated RU text."""
    k = key.replace("\\", "/").strip("/")
    top = k.split("/")[0] if k else ""
    platform = {
        "android": "Android",
        "ios": "iOS",
        "web": "Web",
        "windows": "Windows",
        "linux": "Linux",
        "macos": "macOS",
    }.get(top)
    if platform:
        return {
            "what_ru": f"Каталог системной части Flutter-сборки для {platform}: `{k}/`.",
            "why_ru": f"Содержит платформенные файлы, которые нужны инструментам Flutter и {platform} при сборке.",
            "inside_ru": "Конфигурация платформы, ресурсы и исходники системной части; конкретные файлы описаны ниже.",
            "affects_ru": f"Влияет на сборку и системное поведение версии для {platform}; интерфейс приложения в `lib/` остаётся отдельным слоем.",
            "when_ru": f"Открывать при ошибках сборки {platform}, разрешений, ресурсов или системного запуска.",
            "delete_ru": "Нет — каталог участвует в поддерживаемой платформенной сборке.",
            "related_ru": f"`{top}/`, `docs/APP_STRUCTURE.md`.",
        }
    if k.startswith("lib/"):
        area = k[4:]
        return {
            "what_ru": f"Каталог исходного Dart-кода `{k}/`, отвечающий за область `{area}`.",
            "why_ru": "Собирает рядом файлы одного владельца, чтобы UI, данные и общая инфраструктура не смешивали обязанности.",
            "inside_ru": "Dart-файлы и дочерние каталоги этого владельца; каждый файл описан ниже.",
            "affects_ru": f"Поведение приложения в области `{area}` и связанные с ней потоки данных или интерфейс.",
            "when_ru": f"Открывать при изменениях или ошибках в области `{area}`.",
            "delete_ru": "Нет — это часть исходного кода приложения, пока владелец присутствует в архитектуре.",
            "related_ru": "`lib/`, `docs/APP_STRUCTURE.md`.",
        }
    if k.startswith("docs/"):
        return {
            "what_ru": f"Тематический каталог документации `{k}/`.",
            "why_ru": "Группирует правила, спецификации и справочные материалы по одной теме, не смешивая их с runtime-кодом.",
            "inside_ru": "Markdown-документы и связанные справочные файлы; конкретный состав описан ниже.",
            "affects_ru": "Определяет контекст разработки и проверки решений; в пользовательскую сборку не входит.",
            "when_ru": "Открывать при проверке или обновлении документации по этой теме.",
            "delete_ru": "Нет — сначала нужно подтвердить, что документы действительно утратили роль и ссылки на них отсутствуют.",
            "related_ru": "`docs/PROJECT_KNOWLEDGE_PACK.md`, `docs/APP_STRUCTURE.md`.",
        }
    if k.startswith("scripts/"):
        return {
            "what_ru": f"Каталог автоматизации `{k}/`.",
            "why_ru": "Хранит воспроизводимые команды для проверки, сборки, публикации или обслуживания репозитория.",
            "inside_ru": "Скрипты PowerShell, Python, Dart или вспомогательные файлы; конкретный состав описан ниже.",
            "affects_ru": "Влияет на процессы разработки и CI, но не является пользовательским экраном приложения.",
            "when_ru": "Открывать при запуске или изменении соответствующей автоматизированной процедуры.",
            "delete_ru": "Нет — пока на эти сценарии опираются задокументированные процессы.",
            "related_ru": "`scripts/`, `docs/DEPLOY.md`, `docs/APP_STRUCTURE.md`.",
        }
    if k.startswith("test/") or k == "test":
        return {
            "what_ru": f"Каталог автоматических проверок `{k}/`.",
            "why_ru": "Собирает регрессионные тесты и их вспомогательные данные по одной области продукта.",
            "inside_ru": "Тестовые Dart-файлы, фикстуры или вспомогательные данные; конкретный состав описан ниже.",
            "affects_ru": "Влияет на качество и проверки CI; в пользовательскую сборку не входит.",
            "when_ru": "Открывать при падении соответствующего теста или изменении покрываемого поведения.",
            "delete_ru": "Нет — удаление уменьшит регрессионное покрытие без замены.",
            "related_ru": "`test/`, соответствующие владельцы под `lib/`.",
        }
    return {
        "what_ru": f"Служебный каталог репозитория `{k}/`.",
        "why_ru": "Хранит файлы, необходимые отдельной части сборки, данных проекта или сопровождения репозитория.",
        "inside_ru": "Отслеживаемые Git файлы и дочерние каталоги; каждый элемент описан ниже.",
        "affects_ru": "Влияет на ту часть продукта или процесса сборки, которой принадлежит этот путь.",
        "when_ru": f"Открывать при работе с файлами и процессами, связанными с `{k}/`.",
        "delete_ru": "Нет — сначала нужно подтвердить отсутствие runtime, build, data и CI-зависимостей.",
        "related_ru": "`docs/APP_STRUCTURE.md`, `CHANGELOG.md`.",
    }

'''
guide = guide[:start] + new_auto + guide[end + 1 :]
return_anchor = """    if en_delete:
        from structure_ru_helpers import delete_en_to_ru

        merged[\"delete_ru\"] = delete_en_to_ru(en_delete)
    return merged
"""
return_replacement = """    if en_delete:
        from structure_ru_helpers import delete_en_to_ru

        merged[\"delete_ru\"] = delete_en_to_ru(en_delete)

    # Final safety net: synthesized EN must never leak into the RU half of the
    # generated guide. Curated/adapted text wins when valid; only invalid or
    # missing prose is replaced by the clean class fallback above.
    auto = _folder_ru_auto(k, merged)
    for suffix in (
        \"what_ru\",
        \"why_ru\",
        \"inside_ru\",
        \"affects_ru\",
        \"when_ru\",
        \"delete_ru\",
    ):
        current = merged.get(suffix, \"\")
        if not ru_field_ok(current, min_cyrillic=6):
            merged[suffix] = auto[suffix]
    if not merged.get(\"related_ru\"):
        merged[\"related_ru\"] = auto[\"related_ru\"]
    return merged
"""
guide = replace_once(guide, return_anchor, return_replacement, label="folder RU final safety net")
write("scripts/manual/structure_guide_data.py", guide)

# ---------------------------------------------------------------------------
# PROJECT_KNOWLEDGE_PACK and CHANGELOG — state the new machine-checked contract.
# ---------------------------------------------------------------------------
pack = read("docs/PROJECT_KNOWLEDGE_PACK.md")
if "Last parity verification: **2026-08-18**." not in pack:
    pack = pack.replace(
        "# LIFE OS — Project Knowledge Pack",
        "# LIFE OS — Project Knowledge Pack\n\nLast parity verification: **2026-08-18**. Live governing-path references are checked by `scripts/audit/documentation_parity.py`; the full bilingual tree is generated by `scripts/manual/generate_app_structure_detailed.py`.",
        1,
    )
write("docs/PROJECT_KNOWLEDGE_PACK.md", pack)

changelog = read("CHANGELOG.md")
entry = """## 2026-08-18 — Final architecture/documentation parity [engineering]\n\n- Restored the O1 offline/sync indicator under its correct shell-presentation owner and wired it into `ShellTopStatusBars`; Brain queue/retry semantics remain in `OfflineSyncController`.\n- Removed stale structure rows and updated Shell, Voice, Planning, Profile, tag-picker, cache/performance, and navigation ownership references to current paths.\n- Architecture Guard now checks `APP_STRUCTURE.md` in both directions; `documentation_parity.py` rejects live governing-doc references to missing repo paths.\n- Repaired the detailed-structure generator fallback so generated RU folder descriptions cannot silently copy synthesized EN prose, then regenerated the full tree guide from tracked files.\n\n"""
if not changelog.startswith("## 2026-08-18 — Final architecture/documentation parity [engineering]"):
    changelog = entry + changelog
write("CHANGELOG.md", changelog)
