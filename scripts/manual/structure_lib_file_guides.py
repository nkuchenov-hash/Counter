"""Curated EN+RU guides for specific lib/ files — no generic placeholders."""

from __future__ import annotations

import re
from pathlib import Path

GENERIC_ROLE_MARKERS: tuple[str, ...] = (
    "Fulfill the documented role",
    "required for current app behavior",
    "Role:",
    "Source file `",
    "implementation details in the source file",
)

# Full guides keyed by repo path (forward slashes).
LIB_FILE_GUIDES: dict[str, dict[str, str]] = {
    "lib/shared/voice/platforms/desktop/desktop_stt_helper_process_lifecycle.dart": {
        "what": "`DesktopSttHelperProcessLifecycle` — spawns, restarts, and kills the GOLOS STT helper process; resolves helper/model/settings paths.",
        "why": "Isolates process install/lifecycle from HTTP readiness interpretation and transcription without duplicating `_process` / `_ready` ownership.",
        "contains": "`part of desktop_stt_helper_service.dart`; `helperPath`, `modelPathFor`, `ensureStarted`, `_ensureHelperRunning`, `_restartHelper`, `_killHelperProcess`, stdout/stderr tails.",
        "responsibilities": "Find helper exe; start/restart/kill subprocess; poll until ping responds; call shared `_configureAndWaitReady`; preserve spawn markers and restart policy.",
        "what_ru": "`DesktopSttHelperProcessLifecycle` — spawn/restart/kill процесса GOLOS STT helper; пути helper/model/settings.",
        "why_ru": "Отделяет process lifecycle от HTTP readiness и transcription без дублирования владения `_process` / `_ready`.",
        "contains_ru": "`part of desktop_stt_helper_service.dart`; `helperPath`, `modelPathFor`, `ensureStarted`, `_ensureHelperRunning`, `_restartHelper`, `_killHelperProcess`, хвосты stdout/stderr.",
        "responsibilities_ru": "Находит exe; start/restart/kill; ждёт ping; вызывает `_configureAndWaitReady`; маркеры spawn и restart policy.",
    },
    "lib/shared/voice/platforms/desktop/desktop_stt_helper_diagnostics_builder.dart": {
        "what": "`DesktopSttHelperDiagnosticsBuilder` — assembles `DesktopSttDiagnostics`, WAV duration fallbacks, and last-attempt persistence for the GOLOS STT helper.",
        "why": "Isolates diagnostics/reporting from helper spawn, capture, and transcribe orchestration without duplicating `_lastDiagnostics` ownership.",
        "contains": "`part of desktop_stt_helper_service.dart`; `_updateDiagnostics`, `_resolveRawWavDurationMs`, `_resolveWavDurationMs`, `fetchDiagnostics`, capture-mix/ms helpers.",
        "responsibilities": "Build diagnostics snapshot; emit pipeline markers; write `DesktopVoiceLastAttemptStore`; preserve null/default and WAV duration fallback semantics.",
        "what_ru": "`DesktopSttHelperDiagnosticsBuilder` — собирает `DesktopSttDiagnostics`, fallback длительности WAV и persistence last-attempt для GOLOS STT helper.",
        "why_ru": "Отделяет diagnostics/reporting от spawn/capture/transcribe оркестрации без дублирования владения `_lastDiagnostics`.",
        "contains_ru": "`part of desktop_stt_helper_service.dart`; `_updateDiagnostics`, `_resolveRawWavDurationMs`, `_resolveWavDurationMs`, `fetchDiagnostics`, helpers capture-mix/ms.",
        "responsibilities_ru": "Снимок diagnostics; pipeline markers; запись `DesktopVoiceLastAttemptStore`; семантика null/default и WAV duration fallback.",
    },
    "lib/features/notes/widgets/note_editor_block_widgets.dart": {
        "what": "`NoteEditorBlockRow` / `NoteEditorAddBlockRow` — visual note blocks and add-block chrome for the full-screen Notes editor.",
        "why": "Separates block-local input UI from editor document orchestration, autosave, and Brain writes.",
        "contains": "`NoteEditorBlockPatch`, `NoteEditorBlockRow`, `NoteEditorAddBlockRow`; private image/drawing/control helpers.",
        "responsibilities": "Render text/checklist/heading/image/drawing blocks; emit patches and add/media callbacks — no DatabaseService.",
        "what_ru": "`NoteEditorBlockRow` / `NoteEditorAddBlockRow` — визуальные блоки заметки и ряд «добавить блок» полноэкранного редактора Notes.",
        "why_ru": "Отделяет локальный UI блока от оркестрации документа, autosave и записи в Brain.",
        "contains_ru": "`NoteEditorBlockPatch`, `NoteEditorBlockRow`, `NoteEditorAddBlockRow`; приватные helpers image/drawing/control.",
        "responsibilities_ru": "Рисует text/checklist/heading/image/drawing; отдаёт patches и add/media callbacks — без DatabaseService.",
    },
    "lib/features/planning/planning_quick_add_tags_controller.dart": {
        "what": "`PlanningQuickAddTagsController` — quick-add tag strip state: catalog merge, synthetic “No Tags” prefs, creation selection, reorder persistence.",
        "why": "Moves tag-strip prefs and selection out of the Planning day-page orchestrator without changing submit or Time View behavior.",
        "contains": "`PlanningQuickAddTagsController` with reload/merge/reorder/persist and TagSettingsHub navigation.",
        "responsibilities": "Own quick-add tag UI state and SharedPreferences order; notify PlanningPage via setState callbacks.",
        "what_ru": "`PlanningQuickAddTagsController` — состояние полосы тегов quick-add: merge каталога, prefs «Без тегов», выбор при создании, persist reorder.",
        "why_ru": "Выносит prefs и выбор тегов из оркестратора дня Plans без смены submit и Time View.",
        "contains_ru": "`PlanningQuickAddTagsController` с reload/merge/reorder/persist и навигацией в TagSettingsHub.",
        "responsibilities_ru": "Владеет UI-состоянием тегов quick-add и порядком в SharedPreferences; уведомляет PlanningPage через setState.",
    },
    "lib/features/planning/planning_view.dart": {
        "what": "Planning feature barrel — re-exports `planning_page.dart`, `planning_page_shell.dart`, and `planning_sort_mode.dart`.",
        "why": "Shell and tests import one stable path instead of three planning entry files.",
        "contains": "Three `export` lines only — no widgets in this file.",
        "responsibilities": "Public entry surface for the Plans tab modules.",
        "what_ru": "Barrel вкладки Plans — re-export `planning_page.dart`, `planning_page_shell.dart`, `planning_sort_mode.dart`.",
        "why_ru": "Shell импортирует один путь вместо трёх entry-файлов planning.",
        "contains_ru": "Только три строки `export` — виджетов здесь нет.",
        "responsibilities_ru": "Единая точка входа для модулей вкладки Plans.",
    },
    "lib/features/timeline/timeline_view.dart": {
        "what": "Timeline tab root — `TimelineSwipeWrapper` day pager plus `TimelinePage` body (header, day list, record cards).",
        "why": "First bottom tab: swipe days, start/stop records, toggle stats — all wired from here.",
        "contains": "`TimelineSwipeWrapper`, `_TimelineSwipeWrapperState`; imports day page, header controls, stats.",
        "responsibilities": "Compose Timeline UI; profile-timezone day keys; warm-window paging hooks.",
        "what_ru": "Корень вкладки Timeline — day pager `TimelineSwipeWrapper` и тело `TimelinePage` (header, список дня, карточки записей).",
        "why_ru": "Первая вкладка: свайп дней, старт/стоп записей, stats — собрано здесь.",
        "contains_ru": "`TimelineSwipeWrapper`, `_TimelineSwipeWrapperState`; подключает day page, header controls, stats.",
        "responsibilities_ru": "Собирает UI Timeline; day keys по profile timezone; warm-window paging.",
    },
    "lib/shared/voice/ui/voice_input_sheet.dart": {
        "what": "Mobile/web mic bottom sheet — speech-to-text capture routed by `VoiceCaptureConfig`.",
        "why": "Voice submit on Timeline, Plans, and Lists opens this sheet; must not block main thread.",
        "contains": "`VoiceInputSheet`, `_VoiceInputSheetState`; STT engine handle, permission prompts.",
        "responsibilities": "Listen/transcribe user speech; return text to shell voice routing.",
        "what_ru": "Нижняя шторка микрофона (mobile/web) — speech-to-text по `VoiceCaptureConfig`.",
        "why_ru": "Voice submit на Timeline, Plans и Lists открывает эту шторку; не блокирует main thread.",
        "contains_ru": "`VoiceInputSheet`, `_VoiceInputSheetState`; STT handle, запрос permissions.",
        "responsibilities_ru": "Слушает/транскрибирует речь; отдаёт текст в shell voice routing.",
    },
    "lib/core/app_build_info.dart": {
        "what": "Compile-time build stamp — git commit and build time from `--dart-define`.",
        "why": "Logcat/console markers (`APP_BUILD`, P0N/P0O diagnostics) identify which APK build ran on device.",
        "contains": "`AppBuildInfo` — `gitCommit`, `builtAt`, `bootLogLine()`, perf test markers.",
        "responsibilities": "Expose build identity strings; no runtime PocketBase logic.",
        "what_ru": "Compile-time метка сборки — git commit и время из `--dart-define`.",
        "why_ru": "Маркеры logcat/console (`APP_BUILD`, P0N/P0O) показывают, какой APK на устройстве.",
        "contains_ru": "`AppBuildInfo` — `gitCommit`, `builtAt`, `bootLogLine()`, perf-маркеры.",
        "responsibilities_ru": "Отдаёт строки идентификации сборки; без логики PocketBase.",
    },
    "lib/core/app_colors.dart": {
        "what": "Design-system color tokens (V3/V7) — action primary, surfaces, semantic success, dark scheme.",
        "why": "Change `actionPrimary` once to retint buttons, tabs, and nav chrome app-wide.",
        "contains": "`AppColors` constants; `lightColorScheme()` / `darkColorScheme()` factories.",
        "responsibilities": "Single source for default UI colors — not per-category data colors.",
        "what_ru": "Токены цветов design system (V3/V7) — action primary, surfaces, success и dark scheme.",
        "why_ru": "Смена `actionPrimary` перекрашивает кнопки, tabs и nav chrome во всём приложении.",
        "contains_ru": "Константы `AppColors`; фабрики `lightColorScheme()` / `darkColorScheme()`.",
        "responsibilities_ru": "Единый источник цветов UI — не цвета данных категорий.",
    },
    "lib/data/voice/desktop_stt_cloud_backend.dart": {
        "what": "Brain-owned cloud command STT transport — PocketBase auth, `/api/ai/transcribe-command` POST, 25s timeout.",
        "why": "Core desktop STT must not import `database_service.dart`; Brain owns auth/token/HTTP for cloud fallback.",
        "contains": "`DesktopSttCloudBackend` hooks consumed by Core via `main.dart` injection (AppClock-style).",
        "responsibilities": "Ready check, Authorization header, POST body, timeout — no WAV DSP.",
        "what_ru": "Транспорт облачного command STT в Brain — авторизация PocketBase, POST `/api/ai/transcribe-command`, таймаут 25 с.",
        "why_ru": "Ядро desktop STT не должно импортировать `database_service.dart`; Brain владеет токеном и HTTP для облачного fallback.",
        "contains_ru": "Хуки `DesktopSttCloudBackend`, подключение из `main.dart` в стиле AppClock.",
        "responsibilities_ru": "Проверка готовности, заголовок Authorization, тело POST, таймаут — без обработки WAV.",
    },
    "lib/data/voice/voice_domain_resolver.dart": {
        "what": "`VoiceDomainResolver` — fuzzy voice-domain match against the live category index (`part` of `voice_command_parser.dart`).",
        "why": "Price Reporter and scoped voice commands must resolve spoken domains to category system IDs with confidence gates.",
        "contains": "`VoiceDomainMatchCandidate`, `VoiceDomainResolution`, accept/reject status, diagnostic snapshots.",
        "responsibilities": "Score transcript vs category phrases; reject low-confidence/ambiguous; feed parser.",
        "what_ru": "`VoiceDomainResolver` — нечёткое сопоставление голосового домена с живым индексом категорий (`part` файла `voice_command_parser.dart`).",
        "why_ru": "Price Reporter и scoped-команды должны превращать произнесённые домены в system ID категорий с порогом уверенности.",
        "contains_ru": "`VoiceDomainMatchCandidate`, `VoiceDomainResolution`, статусы accept/reject, диагностические снимки.",
        "responsibilities_ru": "Оценивает транскрипт против фраз категорий; отклоняет низкую уверенность и неоднозначность; питает парсер.",
    },
    "lib/services/plan_alarm_schedule.dart": {
        "what": "UI-free plan reminder schedule specs — wall-time conversion, dedupe, cancel/reconcile limits.",
        "why": "Notification plugin scheduling must stay deterministic and outside feature widgets.",
        "contains": "Schedule/cancel helpers, profile-timezone fire UTC, occurrence id stability.",
        "responsibilities": "Build OS alarm specs; no Flutter UI; consumed by `NotificationService` / Brain helpers.",
        "what_ru": "Спецификации напоминаний планов без UI — перевод wall-time, дедуп, лимиты cancel/reconcile.",
        "why_ru": "Планирование через notification plugin должно быть детерминированным и вне feature-виджетов.",
        "contains_ru": "Хелперы schedule/cancel, время срабатывания UTC по timezone профиля, стабильные occurrence id.",
        "responsibilities_ru": "Строит спецификации OS-будильников; без Flutter UI; вызывается из `NotificationService` и Brain helpers.",
    },
    "lib/core/widgets/radial_menu_viewport.dart": {
        "what": "`RadialMenuViewport` — clamps radial/semi-circle card action menus inside the visible viewport.",
        "why": "Lists and Plans radial menus near screen edges must keep satellites and labels on-screen.",
        "contains": "`clampCanvasTopLeft` geometry helper; safe-margin constants.",
        "responsibilities": "Pure geometry — no Brain/PocketBase imports.",
        "what_ru": "`RadialMenuViewport` — сдвигает радиальное/полукруглое меню карточки внутрь видимой области экрана.",
        "why_ru": "Радиальные меню Lists и Plans у края экрана должны оставлять спутники и подписи видимыми.",
        "contains_ru": "Геометрический хелпер `clampCanvasTopLeft`; константы безопасного отступа.",
        "responsibilities_ru": "Чистая геометрия — без импортов Brain и PocketBase.",
    },
    "lib/app/shell/phone/shell_bottom_navigation.dart": {
        "what": "`ShellCompactBottomNav` — equal-column phone-safe bottom tab bar (compact labels).",
        "why": "Material `NavigationBar` clips five labels on ~390px widths; this bar matches APK phone metrics.",
        "contains": "`ShellCompactBottomNav`, `kShellBottomNavHeight`, compact vs full label keys.",
        "responsibilities": "Render five shell tabs; no PocketBase I/O.",
        "what_ru": "`ShellCompactBottomNav` — компактная нижняя панель вкладок с равными колонками для узких телефонов.",
        "why_ru": "Material `NavigationBar` обрезает пять подписей на ширине ~390px; эта панель совпадает с метриками APK.",
        "contains_ru": "`ShellCompactBottomNav`, `kShellBottomNavHeight`, ключи коротких и полных подписей.",
        "responsibilities_ru": "Рисует пять вкладок оболочки; без обращений к PocketBase.",
    },
    "lib/features/categories/create_category_from_picker.dart": {
        "what": "`showCreateCategoryFromPickerDialog` — explicit-parent create flow from category tree pickers.",
        "why": "Edit sheets and recursive tree must create a child under a known parent without inferring from search UI.",
        "contains": "`CategoryPickerCreateTarget`, submit helper, create dialog widget.",
        "responsibilities": "Collect name/parent; call Brain create; return new local category id.",
        "what_ru": "`showCreateCategoryFromPickerDialog` — создание категории с явным родителем из дерева выбора.",
        "why_ru": "Edit sheets и recursive tree создают потомка под известным родителем без угадывания из поиска.",
        "contains_ru": "`CategoryPickerCreateTarget`, хелпер submit, виджет диалога создания.",
        "responsibilities_ru": "Собирает имя и родителя; вызывает создание в Brain; возвращает новый local id категории.",
    },
    "lib/features/shared/edit_sheet/record_edit_save_policy.dart": {
        "what": "`validateRecordEditSave` / `RecordEditSaveMode` — Timeline record edit Save classify/validate policy.",
        "why": "Save must distinguish create-completed vs running metadata vs stopped interval without guessing from empty UUID filters.",
        "contains": "Mode enum, validation result, classify/validate helpers (UI-free).",
        "responsibilities": "Return ok/error with start/end UTC; consumed by `timeline_record_edit_sheet.dart`.",
        "what_ru": "`validateRecordEditSave` / `RecordEditSaveMode` — политика классификации и проверки Save в редакторе записи Timeline.",
        "why_ru": "Save различает завершённый интервал, метаданные running и остановленный интервал без догадок по пустым UUID.",
        "contains_ru": "Перечисление режимов, результат проверки, хелперы classify/validate без UI.",
        "responsibilities_ru": "Возвращает ok/error со start/end UTC; используется в `timeline_record_edit_sheet.dart`.",
    },
}


def normalize_role_short(role: str, path: str) -> str:
    """Readable role line — never broken `, TimelinePage` fragments."""
    role = (role or "").strip()
    if not role:
        return Path(path).stem.replace("_", " ")
    if any(m in role for m in GENERIC_ROLE_MARKERS):
        return Path(path).stem.replace("_", " ")

    ticks = re.findall(r"`([^`]+)`", role)
    if ticks:
        return ", ".join(ticks)

    short = role.split(";")[0].strip().replace("`", "").strip()
    short = re.sub(r"^\s*,\s*", "", short).strip()
    if not short or re.match(r"^[,.\s]+$", short):
        return Path(path).stem.replace("_", " ")
    return short


def describe_contains(
    path: str, syms: list[str], exports: list[str]
) -> tuple[str, str, str, str]:
    """Return (contains_en, contains_ru, resp_hint_en, resp_hint_ru) — no placeholders."""
    fname = Path(path).name
    stem = Path(path).stem

    if exports and not syms:
        exp = ", ".join(f"`{e}`" for e in exports[:5])
        en = f"Barrel `export` lines: {exp}."
        ru = f"Barrel `export`: {exp}."
        hint_en = f"Re-exports planning entry modules via `{fname}`."
        hint_ru = f"Re-export entry-модулей через `{fname}`."
        return en, ru, hint_en, hint_ru

    if syms:
        sym_txt = ", ".join(f"`{s}`" for s in syms[:6])
        en = f"Primary symbols: {sym_txt}."
        ru = f"Основные символы: {sym_txt}."
        hint_en = f"Implements `{syms[0]}` and related API in `{fname}`."
        hint_ru = f"Реализует `{syms[0]}` и связанный API в `{fname}`."
        return en, ru, hint_en, hint_ru

    if stem.endswith("_view") or stem.endswith("_page"):
        en = f"Screen composition and state for `{fname}`."
        ru = f"Компоновка экрана и state в `{fname}`."
        hint_en = f"Owns visible Timeline/Plans UI wired in `{fname}`."
        hint_ru = f"Отвечает за видимый UI, собранный в `{fname}`."
        return en, ru, hint_en, hint_ru

    if stem.endswith("_sheet") or stem.endswith("_dialog"):
        en = f"Modal UI widgets and controllers in `{fname}`."
        ru = f"Modal UI и controllers в `{fname}`."
        hint_en = f"User opens this sheet/dialog from `{stem}` entry points."
        hint_ru = f"Пользователь открывает sheet/dialog из entry `{stem}`."
        return en, ru, hint_en, hint_ru

    en = f"Dart module `{fname}` — open file for classes and helpers."
    ru = f"Dart-модуль `{fname}` — классы и helpers в исходнике."
    hint_en = f"Supports `{stem}` behavior in this feature area."
    hint_ru = f"Поддерживает поведение `{stem}` в этой feature-зоне."
    return en, ru, hint_en, hint_ru


FEATURE_SCREENS_RU: dict[str, str] = {
    "planning": "вкладка Plans (вторая снизу)",
    "timeline": "вкладка Timeline (первая снизу)",
    "lists": "вкладка Lists (четвёртая снизу)",
    "calendar": "вкладка Calendar",
    "categories": "More → Categories",
    "profile": "More → Profile и настройки",
    "shared": "edit sheets и voice UI на всех вкладках",
    "notes": "Notes library/editor (Lists + full-screen editor)",
    "dev": "Component Lab (More → Dev, только admin)",
    "wear": "Wear OS companion",
    "auth": "экран входа и регистрации",
    "stats": "панель stats внутри Timeline",
}


def _ru_field(en_text: str, fallback_ru: str) -> str:
    from structure_en_ru_adapt import _phrase_translate
    from structure_ru_class_adapters import sanitize_ru_prose

    tr = sanitize_ru_prose(_phrase_translate(en_text))
    cy = sum(1 for c in tr if "\u0400" <= c <= "\u04FF")
    if cy >= 10 and "implementation details" not in tr:
        return tr
    return fallback_ru


def feature_file_guide(
    path: str, role: str, syms: list[str], exports: list[str]
) -> dict[str, str] | None:
    """Concrete feature-file guide — prefer curated, else role + symbols."""
    p = path.replace("\\", "/")
    if p in LIB_FILE_GUIDES:
        return dict(LIB_FILE_GUIDES[p])

    parts = p.split("/")
    feature = parts[2] if len(parts) > 2 else "app"
    fname = Path(p).name
    screen_en = {
        "planning": "Plans tab (second bottom tab)",
        "timeline": "Timeline tab (first bottom tab)",
        "lists": "Lists tab (fourth bottom tab)",
        "calendar": "Calendar tab",
        "categories": "More → Categories manager",
        "profile": "More → Profile and settings",
        "shared": "edit sheets and voice UI on every tab",
        "dev": "admin-only Component Lab (More → Dev)",
        "wear": "Wear OS watch companion",
        "auth": "sign-in and registration screen",
        "stats": "stats panel inside Timeline",
    }.get(feature, f"{feature} area")
    screen_ru = FEATURE_SCREENS_RU.get(feature, feature)

    role_short = normalize_role_short(role, p)
    contains_en, contains_ru, hint_en, hint_ru = describe_contains(p, syms, exports)

    if exports and not syms:
        what_en = f"Barrel `{fname}` for {screen_en} — re-exports entry modules."
        what_ru = f"Barrel `{fname}` для {screen_ru} — re-export entry-модулей."
    else:
        what_en = f"`{fname}` on {screen_en} — {role_short}."
        what_ru = f"`{fname}` на {screen_ru} — {_ru_field(role_short, hint_ru)}."

    why_en = f"Users see `{fname}` when using {screen_en}."
    why_ru = f"Пользователь видит UI из `{fname}` на {screen_ru}."

    resp_en = role_short if role_short != Path(p).stem.replace("_", " ") else hint_en
    resp_ru = _ru_field(resp_en, hint_ru)

    return {
        "what": what_en,
        "why": why_en,
        "contains": contains_en,
        "responsibilities": resp_en,
        "what_ru": what_ru,
        "why_ru": why_ru,
        "contains_ru": contains_ru,
        "responsibilities_ru": resp_ru,
    }
