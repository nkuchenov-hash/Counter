"""Turn APP_STRUCTURE roles + file paths into owner-readable FileGuide text."""

from __future__ import annotations

from pathlib import Path, PurePosixPath

# Visible screen names for lib/features/* UI files
FEATURE_SCREENS: dict[str, str] = {
    "planning": "Plans tab (second bottom tab)",
    "timeline": "Timeline tab (first bottom tab)",
    "lists": "Lists tab (fourth bottom tab)",
    "calendar": "Calendar tab",
    "categories": "More → Categories manager",
    "profile": "More → Profile and settings",
    "shared": "edit sheets and voice UI on every tab",
    "notes": "Notes library/editor (Lists tab + full-screen editor)",
    "dev": "admin-only Component Lab (More → Dev)",
    "wear": "Wear OS watch companion",
    "auth": "sign-in and registration screen",
    "stats": "stats panel inside Timeline",
}

RECORD_PART: dict[str, tuple[str, str, str]] = {
    "record_crud": (
        "Sends timeline record start, stop, edit, and delete to PocketBase.",
        "When you tap Start or Stop, this file builds the network request and updates the local record list.",
        "POST/PATCH/DELETE for the `records` table; `writeRecord`, `stopRecord`, `updateRecord`.",
    ),
    "record_optimistic": (
        "Shows timer start/stop on screen immediately — before PocketBase confirms.",
        "The 100ms rule: users must see the running timer without waiting on Wi‑Fi.",
        "Shadow state maps, optimistic stop overlay, pending-start handoff.",
    ),
    "record_realtime": (
        "Listens for live record changes from PocketBase on the server.",
        "If another device stops a record, Timeline should update without manual refresh.",
        "Realtime subscription connect/disconnect, event merge into cache.",
    ),
    "record_timeline_vm": (
        "Prepares which record rows appear on each Timeline day page.",
        "Timeline swipe between days needs pre-built lists and warm-window paging.",
        "Day index, warm window, row view-model builders for Timeline cards.",
    ),
    "record_outbox_helpers": (
        "Queues record changes when offline and replays them when back online.",
        "Start/stop on bad Wi‑Fi must not be lost — changes wait in SharedPreferences.",
        "Record mutation outbox enqueue, flush, Highlander server sync phase.",
    ),
    "record_overlap_helpers": (
        "Ensures only one running record at a time (Highlander rule).",
        "Starting a new task must auto-stop the previous running timer.",
        "Singleton reconcile, overlap probes, local apply before server.",
    ),
    "record_ghost_cleanup": (
        "Removes dead record rows from local cache after server 404.",
        "Stale cache entries would show ghost timers that no longer exist on PocketBase.",
        "404 dead-letter prune against live cache.",
    ),
    "record_cache_helpers": (
        "Filters and streams the in-memory record list for Timeline display.",
        "Every Timeline day reads from this cache instead of hitting the network each swipe.",
        "`recordsStream`, per-day filter, display-time helpers.",
    ),
}

PLAN_PART: dict[str, tuple[str, str, str]] = {
    "plan_projection_types": (
        "Owns Time Mode projected DTOs, UTC/profile-wall conversion, and wall-day visibility for Planning.",
        "Plans must show correct wall times after profile timezone changes without mutating stored UTC instants.",
        "`TimeModeProjectedPlan`; `PlanProfileTimezoneProjectionExtension`; `reprojectAllPlansForProfileTimezone`; `plansProjectionCacheSignature`.",
    ),
    "plan_recurrence_helpers": (
        "Expands repeating plans (daily/weekly RRULE) into visible day rows.",
        "A single recurring gym plan must appear on every matching calendar day.",
        "RRULE JIT expansion, exception dates, virtual occurrence handling.",
    ),
    "plan_time_cascade_helpers": (
        "Owns Time View duration/snap policy, collision avoidance, sequential cascade, and new-plan auto-scheduling.",
        "Overlapping plans and new inserts must land in valid wall slots without blocking the Planning tap path.",
        "`normalizeSequentialPlanTimesForDay`; `resolveAutoPlanSchedule`; `evaluatePlanDayScheduleOverload`; overload constants.",
    ),
    "plan_tags_helpers": (
        "Syncs tag chips on plan cards with PocketBase `tags_link` relations.",
        "Plan tags must save to the server and show the same on Lists and Plans.",
        "Tag catalog fetch, PB link sync for plans/lists.",
    ),
    "plan_cache_helpers": (
        "Maintains the local plan list clean, persists/restores offline day caches, and scores title similarity for smart linking.",
        "Duplicate plan rows, stale virt-* day-cache entries, or bad merges would break Planning and Lists tabs.",
        "Plan dedupe/scrub; offline day-cache codec (`cache_plans_day_v1_*`); SharedPreferences day-cache persist/restore; title link scoring.",
    ),
    "plan_outbox_helpers": (
        "Runs immediate plan update/delete network phases and queues/replays mutations when offline or auth-paused.",
        "Checking off a list item or editing a plan offline must stick locally, then sync later without losing retry/auth classification.",
        "Immediate `_patchPlanUpdateNetworkPhase` / `_deletePlanNetworkPhase`; outbox enqueue/flush/replay; mutation retry and auth pause classification.",
    ),
    "plan_snapshot_helpers": (
        "Builds and caches Planning warm day snapshots, rendered day bodies, and P0t render snapshots for swipe-ready UI.",
        "Plans tab boot and day swipe must show cached bodies instantly without waiting on PocketBase or full-history scans.",
        "Warm window ±1/full DayWindow prep; body cache center/radius; disk restore/persist; `buildPlansDayRenderSnapshot` readiness.",
    ),
    "plan_stream_helpers": (
        "Owns shared Planning day-stream hubs, refresh-event publication, and cache-first/network-pump coordination.",
        "Many PlanningPage instances stay alive under PageView; hubs must be ref-counted with no periodic polling and a single 400ms network debounce.",
        "`_PlanningDayStreamHub`; `planningStream`; `notifyPlanningRefresh`; `planningRefreshNotifications` / `planningRefreshEvents`.",
    ),
    "plan_optimistic_helpers": (
        "Owns dated/backlog optimistic overlay state for Planning and Lists instant UI.",
        "Cross-day edits must hide the row on the previous day, merge overlay-wins on the target day, and rekey after profile timezone changes without duplicating cache state.",
        "`_planningOptimisticByDateKey`; `applyOptimisticPlanningTask`; `clearOptimisticPlanningForPlanRow`; `_mergePlanningOptimistic`; `getBacklogPlansSnapshot`.",
    ),
    "plan_order_helpers": (
        "Owns Planning optimistic reorder, first-drag baseline tracking, and debounced diff-only PocketBase order sync.",
        "Plan drag-reorder must update UI instantly, PATCH only changed `order` values after a 2s debounce, and roll back on total failure.",
        "`persistPlanningTaskOrder`; `flushPlanningOrderSyncNow`; `_planReorderBaselineByPlanId`; rollback on all-patch failure.",
    ),
    "plan_record_link_helpers": (
        "Owns plan-to-record source linkage, actual-time aggregation, and plan-vs-fact day statistics.",
        "Play/start-from-plan and Stats need Brain-owned source_plan_id inheritance and wall-day planned-vs-actual rollups.",
        "`aggregateSourcePlanActualSecondsForWallCalendarDay`; `getBasicDayStats`; `suggestSourcePlanForFreeStart`; `resolveCurrentPlanCategoryForRecordStart`.",
    ),
    "plan_ai_parse_helpers": (
        "Calls the AI parse-task backend and normalizes planning items from the response.",
        "Smart plan sheet and voice-ish plan drafts need one Brain entry for parse-task.",
        "`parseTaskViaAiBackend`, `parsePlanningItemsViaAiBackend`, HH:mm helpers.",
    ),
    "plan_alarm_helpers": (
        "Reconciles plan reminder alarms from the hydrated plan cache (no network on the hot path).",
        "Planning refresh/hydrate/resume must schedule OS alarms without blocking Timeline taps.",
        "`reconcilePlanNotifications`, debounced OS alarm bridge from `_allPlansUserCache`.",
    ),
    "notes_brain_helpers": (
        "Bridges versioned `NoteDocument` envelopes with `plans.notes_delta` / mirrors and debounced PATCH.",
        "Notes editor/library must stay local-first: cache first, then one PATCH per debounce window.",
        "Parse/apply/pin/done helpers; `createEmptyNote`; optimistic NotesBrainExtension.",
    ),
}

CATEGORY_PART: dict[str, tuple[str, str, str]] = {
    "category_order_helpers": (
        "Owns category sibling optimistic reorder, baseline tracking, and debounced PocketBase order sync.",
        "Category drag-reorder must update the tree instantly and PATCH only changed indices after a 2s debounce.",
        "`applyLocalCategorySiblingOrder`; `persistCategorySiblingOrder`; `flushCategoryOrderSyncNow`; baseline bulk PATCH.",
    ),
}

PROFILE_PART: dict[str, tuple[str, str, str]] = {
    "profile_hydration": (
        "Downloads your profile from PocketBase when the app starts or after login.",
        "Timezone, language, and tag settings cannot render until profile loads.",
        "Profile fetch lifecycle, PB map apply, retry on failure.",
    ),
    "profile_settings": (
        "Saves profile preference changes back to PocketBase.",
        "Settings toggles in Profile must persist for the signed-in user only.",
        "Profile PATCH, diff fields, locale sync after save.",
    ),
    "profile_timezone": (
        "Calculates “today” and wall-clock labels using your profile timezone.",
        "Timeline day boundaries follow profile TZ, not phone local time.",
        "Timezone normalize/offset, projected today, TZ writes.",
    ),
    "profile_cache_helpers": (
        "Mirrors profile settings to device storage for faster next launch.",
        "Reduces flicker on cold start before PocketBase responds.",
        "SharedPreferences mirror/hydrate for profile settings.",
    ),
    "profile_preferences": (
        "Reloads data region when profile preferences change.",
        "Some settings require refreshing cached lists after save.",
        "Data region reload hook after preference change.",
    ),
    "profile_admin": (
        "Reads whether your account is admin (Component Lab gate).",
        "Only admins see More → Dev / Design Lab.",
        "Parses `profiles.is_admin` during hydration — never written by normal UI.",
    ),
    "tag_catalog": (
        "Loads and edits the tag list (plan tags and list tags) in PocketBase.",
        "Tag manager and tag chips on cards read from this catalog.",
        "Tag CRUD, sort order, PocketBase `tags_link` id resolution.",
    ),
    "tag_display_settings": (
        "Stores how tag chips appear on list cards (hidden, compact, etc.).",
        "Tag display mode is a profile preference, not per-plan.",
        "List tag strip visibility prefs, display-mode merge.",
    ),
}

MODEL_PART: dict[str, tuple[str, str, str]] = {
    "_shared": (
        "Shared helper functions used by multiple data model classes.",
        "Avoids duplicating date/id parsing across record, plan, and category models.",
        "Small pure helpers — no PocketBase calls.",
    ),
    "profile": (
        "Defines the shape of user settings (`UserSettings`) — timezone, language, admin flag.",
        "UI and brain must agree on field names from `docs/DATA_MAP.md`.",
        "`UserSettings` class and profile field parsers.",
    ),
    "category": (
        "Defines `CategoryRule` — name, color, icon, parent, PocketBase ids.",
        "Category picker and manager display this shape.",
        "`CategoryRule` with stable hash for category business id.",
    ),
    "record": (
        "Defines `TimelineRecord` — start/stop times, status, category, date key.",
        "Every Timeline card is a `TimelineRecord` instance.",
        "UTC storage, profile-timezone date key bucketing.",
    ),
    "planning": (
        "Defines `PlanningTask` — scheduled plans and backlog list rows.",
        "Plans tab, Lists tab, and Time View cards use this shape.",
        "Plan fields: time, done flag, recurrence, tags.",
    ),
    "tag": (
        "Defines `Tag` and `TagCatalogScope` for plan vs list tag domains.",
        "Tag manager and chip strips use these types.",
        "Tag name, color, default duration minutes.",
    ),
    "stats": (
        "Defines aggregated stats numbers for Timeline stats tab.",
        "Stats views sum records without re-parsing raw JSON each frame.",
        "Stats aggregate structs.",
    ),
    "note_document": (
        "Defines versioned Notes block documents (`lifeos_notes_blocks_v1`) stored in `plans.notes_delta`.",
        "Block editor and library cards need typed paragraphs/checklists/images/drawings with legacy Quill migration.",
        "`NoteDocument`, `NoteBlock`, parse/serialize, payload size guards — pure data, no Flutter/PB.",
    ),
}

LOCAL_SYNC_PART: dict[str, tuple[str, str, str]] = {
    "record_mutation_outbox": (
        "Remembers record start/stop/edit/delete when the network fails.",
        "Offline-first law: tap must succeed locally even on airplane mode.",
        "SharedPreferences queue for record mutations; coalesces duplicate ops.",
    ),
    "plan_mutation_outbox": (
        "Remembers plan/list create/update/delete when offline.",
        "List checkbox and plan edits queue here until reconnect.",
        "SharedPreferences queue for plan mutations.",
    ),
    "plan_create_outbox": (
        "Legacy re-export file — points importers to `plan_mutation_outbox.dart`.",
        "Older code imported this name; kept so imports do not break.",
        "Single export line only — no logic.",
    ),
    "offline_sync_state": (
        "Tracks pending sync count and “auth paused” for the top banner.",
        "Users see how many changes wait to upload; tap banner to retry.",
        "`OfflineSyncController`: pendingCount, isSyncing, authPaused.",
    ),
    "sync_manager": (
        "Watches network connectivity and triggers queue flush on reconnect.",
        "When Wi‑Fi returns, pending offline changes should upload automatically.",
        "Connectivity listener → `flushPendingLocalMutations`.",
    ),
}


def _sym_line(syms: list[str], path: str = "") -> str:
    if syms:
        return ", ".join(f"`{s}`" for s in syms[:6])
    stem = Path(path).stem if path else "module"
    return f"logic in `{stem}`"


def _part_guide(path: str, role: str, syms: list[str], part_map: dict[str, tuple[str, str, str]], area: str) -> dict[str, str]:
    from structure_en_ru_adapt import _phrase_translate
    from structure_ru_class_adapters import sanitize_ru_prose

    stem = Path(path).stem
    what, why, contains = part_map.get(stem, (
        f"Brain module for {area} — {role.split(';')[0].strip().lower()}.",
        f"Part of the app brain that keeps {area} consistent with PocketBase.",
        f"Dart code ({_sym_line(syms, path)}).",
    ))
    role_line = role.split(";")[0].strip()
    sym = _sym_line(syms, path)
    what_ru = sanitize_ru_prose(_phrase_translate(what))
    why_ru = sanitize_ru_prose(_phrase_translate(why))
    contains_ru = sanitize_ru_prose(_phrase_translate(contains))
    if sum(1 for c in what_ru if "\u0400" <= c <= "\u04FF") < 8:
        what_ru = f"Модуль brain для {area} — файл `{stem}`."
    if sum(1 for c in why_ru if "\u0400" <= c <= "\u04FF") < 8:
        why_ru = f"Держит {area} согласованным с PocketBase и UI."
    if sum(1 for c in contains_ru if "\u0400" <= c <= "\u04FF") < 4:
        contains_ru = f"Dart-код ({sym})."
    return {
        "what": what,
        "why": why,
        "contains": contains,
        "responsibilities": role_line,
        "what_ru": what_ru,
        "why_ru": why_ru,
        "contains_ru": contains_ru,
        "responsibilities_ru": f"Реализует в коде: {role_line}.",
    }


def humanize_guide(
    path: str, role: str, syms: list[str], exports: list[str] | None = None
) -> dict[str, str] | None:
    """Return partial FileGuide fields, or None to fall through."""
    from structure_lib_file_guides import LIB_FILE_GUIDES, feature_file_guide

    p = path.replace("\\", "/")
    role_clean = role.strip()
    sym = _sym_line(syms, p)
    exp = exports or []

    if p in LIB_FILE_GUIDES:
        return dict(LIB_FILE_GUIDES[p])

    if p == "lib/data/database_service.dart":
        return {
            "what": "The single “brain” front door — one place all screens ask for data and saves.",
            "why": "Timeline, Plans, Lists, and Categories share one singleton so PocketBase rules stay consistent.",
            "contains": "Shared streams, caches, and `part` declarations for records, plans, categories, profile.",
            "responsibilities": "Host extensions; route work to `record_service`, `plan_service`, etc.",
            "what_ru": "Единая «мозговая» точка входа — все экраны обращаются сюда за данными.",
            "why_ru": "Один singleton держит правила PocketBase для всех вкладок.",
            "contains_ru": "Потоки, кэш, объявления `part` для records/plans/categories/profile.",
            "responsibilities_ru": "Маршрутизация к domain-файлам brain.",
        }

    if p.endswith("_service.dart") and p.startswith("lib/data/"):
        domain = Path(p).stem.replace("_service", "")
        domain_label = {
            "record": "timeline records (timer start/stop)",
            "plan": "plans and backlog lists",
            "category": "categories (tree, colors, matching)",
            "profile": "profile, timezone, and tags",
        }.get(domain, domain)
        return {
            "what": f"Main coordinator for {domain_label} inside the brain.",
            "why": f"UI calls one {domain} entry point; this file delegates to focused modules in the subfolder.",
            "contains": f"Coordinator extensions plus links to `part` files under `{domain}s/` or `{domain}/`.",
            "responsibilities": role_clean.split(";")[0].strip(),
            "what_ru": f"Главный координатор для {domain_label}.",
            "why_ru": "UI вызывает один вход; детали — в модулях subfolder.",
            "contains_ru": f"Extensions + `part` файлы для {domain}.",
            "responsibilities_ru": f"Координатор домена: {role_clean.split(';')[0].strip()}.",
        }

    if p.startswith("lib/data/records/"):
        return _part_guide(p, role, syms, RECORD_PART, "timeline records")

    if p.startswith("lib/data/plans/"):
        return _part_guide(p, role, syms, PLAN_PART, "plans and lists")

    if p.startswith("lib/data/categories/"):
        return _part_guide(p, role, syms, CATEGORY_PART, "categories")

    if p.startswith("lib/data/profile/"):
        return _part_guide(p, role, syms, PROFILE_PART, "profile and tags")

    if p.startswith("lib/data/models/"):
        return _part_guide(p, role, syms, MODEL_PART, "data models")

    if p.startswith("lib/data/local_sync/"):
        return _part_guide(p, role, syms, LOCAL_SYNC_PART, "offline sync")

    if p == "lib/data/models.dart":
        return {
            "what": "Barrel file that declares all data model `part` files in one place.",
            "why": "Other code imports `models.dart` once to get `TimelineRecord`, `PlanningTask`, etc.",
            "contains": "`part` directives only — no logic.",
            "responsibilities": "Export surface for model types listed in `docs/DATA_MAP.md`.",
            "what_ru": "Собирает все model `part` в одном import.",
            "why_ru": "Один import для всех типов данных.",
            "contains_ru": "Только `part` директивы.",
            "responsibilities_ru": "Экспорт моделей.",
        }

    if p == "lib/app_shell.dart":
        return {
            "what": "Thin shell entry — re-exports `shell/life_os_dashboard.dart`.",
            "why": "Provides a stable import path for the main dashboard without duplicating shell code.",
            "contains": "Re-export of the dashboard shell widget.",
            "responsibilities": "Re-exports `shell/life_os_dashboard.dart` (thin entry).",
            "what_ru": "Тонкий entry-point приложения — re-export `shell/life_os_dashboard.dart`.",
            "why_ru": "Стабильный import path для dashboard без дублирования shell-кода.",
            "contains_ru": "Re-export виджета dashboard из `lib/shell/`.",
            "responsibilities_ru": "Подключает shell dashboard как единую точку входа UI.",
        }

    if p == "lib/main.dart":
        return {
            "what": "Flutter app entry — `main()` bootstraps auth gate, brain load, and dashboard.",
            "why": "OS launches this file first; it wires PocketBase session and initial data before tabs render.",
            "contains": "`main()`, app widget tree, auth routing to dashboard or login.",
            "responsibilities": "Start Flutter binding; load settings; show loading until brain ready.",
            "what_ru": "Точка входа Flutter — `main()` запускает auth gate, загрузку brain и dashboard.",
            "why_ru": "ОС стартует приложение отсюда; до вкладок нужны session PocketBase и initial data.",
            "contains_ru": "`main()`, дерево виджетов, routing login ↔ dashboard.",
            "responsibilities_ru": "Инициализация Flutter; loading до готовности brain.",
        }

    if p.startswith("lib/l10n/"):
        fname = Path(p).name
        stem = Path(p).stem
        if stem == "dictionary":
            role_ru = "мастер-ключи UI-текста (SSOT для подписей)."
        elif stem == "app_locales":
            role_ru = "реестр поддерживаемых локалей и fallback на English."
        elif stem == "category_db_display":
            role_ru = "отображение названий категорий из brain в UI."
        elif stem.startswith("langs/") or "/langs/" in p:
            lang = stem if stem != "langs" else Path(p).stem
            role_ru = f"строки локали `{lang}` (частичный перевод поверх English)."
        else:
            role_ru = "локализация UI-текста приложения."
        return {
            "what": f"Localization module `{fname}` — {role_ru}",
            "why": "UI labels resolve through l10n maps instead of hard-coded strings in widgets.",
            "contains": f"Dart maps/keys in `{fname}`.",
            "responsibilities": f"Provide translated strings for `{fname}`.",
            "what_ru": f"Модуль локализации `{fname}` — {role_ru}",
            "why_ru": "Подписи UI берутся из l10n maps, а не из hard-coded строк в виджетах.",
            "contains_ru": f"Dart-карты ключей в `{fname}`.",
            "responsibilities_ru": f"Даёт переведённые строки для `{fname}`.",
        }

    from structure_lib_file_guides import feature_file_guide

    if p.startswith("lib/features/"):
        fg = feature_file_guide(p, role_clean, syms, exp)
        if fg:
            return fg

    if p.startswith("lib/services/"):
        fname = Path(p).name
        stem = Path(p).stem.replace("_", " ")
        role_short = role_clean.split(";")[0].strip() or stem
        return {
            "what": f"Device-side service `{fname}` — {role_short}.",
            "why": f"OS APIs (notifications, voice, tray) cannot live in PocketBase brain code.",
            "contains": f"Platform service code in `{fname}` ({sym}).",
            "responsibilities": role_clean or role_short,
            "what_ru": f"Сервис устройства `{fname}` — {role_short}.",
            "why_ru": "OS API (уведомления, voice, tray) не могут жить в PocketBase brain.",
            "contains_ru": f"Platform-код сервиса в `{fname}` ({sym}).",
            "responsibilities_ru": f"Реализует сервис: {role_short}.",
        }

    if p.startswith("lib/shell/"):
        role_short = role_clean.replace("*(part)*", "").strip()
        return {
            "what": f"App shell wiring — {role_short}.",
            "why": "Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.",
            "contains": f"Shell mixin or widget ({sym}).",
            "responsibilities": role_clean,
            "what_ru": f"Оболочка приложения (shell) — {role_short}.",
            "why_ru": "Связывает вкладки, voice, edit sheets и offline banner.",
            "contains_ru": f"Shell mixin или виджет ({sym}).",
            "responsibilities_ru": f"Реализует в shell: {role_clean}.",
        }

    if p.startswith("lib/core/widgets/"):
        role_short = role_clean.split(";")[0].strip()
        return {
            "what": f"Shared design-system widget — {role_short}.",
            "why": "Plans, Timeline, and Lists reuse this instead of copying button/card styles.",
            "contains": f"Canonical Flutter widget ({sym}).",
            "responsibilities": role_clean,
            "what_ru": f"Общий виджет design system — {role_short}.",
            "why_ru": "Один стиль кнопок и карточек на Plans, Timeline и Lists.",
            "contains_ru": f"Канонический Flutter-виджет ({sym}).",
            "responsibilities_ru": f"Реализует в UI: {role_clean}.",
        }

    if p.startswith("lib/core/"):
        from structure_lib_file_guides import describe_contains, normalize_role_short

        if p in LIB_FILE_GUIDES:
            return dict(LIB_FILE_GUIDES[p])
        role_short = normalize_role_short(role_clean, p)
        contains_en, contains_ru, _, _ = describe_contains(p, syms, exp)
        sub = PurePosixPath(p).parent.name
        return {
            "what": f"Foundation module `{Path(p).name}` ({sub}) — {role_short}.",
            "why": "Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.",
            "contains": contains_en,
            "responsibilities": role_short,
            "what_ru": f"Foundation-модуль `{Path(p).name}` ({sub}) — {role_short}.",
            "why_ru": "Общий код вне одного экрана: тема, время, voice, diagnostics.",
            "contains_ru": contains_ru,
            "responsibilities_ru": f"Foundation-логика: {role_short}.",
        }

    if p.startswith("lib/l10n/"):
        if p.endswith("langs/en.dart"):
            return {
                "what": "English translation strings — master copy for all UI text keys.",
                "why": "Every label in the app resolves through keys defined here first.",
                "contains": "`kEnL10n` map of key → English text.",
                "responsibilities": "Canonical English SSOT; edit here before running locale sync.",
                "what_ru": "Английские строки UI — мастер-копия ключей.",
                "why_ru": "Все подписи начинаются с ключей здесь.",
                "contains_ru": "Карта ключей `kEnL10n` для английских подписей.",
                "responsibilities_ru": "Канонический английский SSOT; править перед sync_locales.",
            }
        if p.endswith("langs/ru.dart"):
            return {
                "what": "Russian translation strings for the UI.",
                "why": "Russian locale shows text from this map when user picks RU.",
                "contains": "`kRuL10n` map of key → Russian text.",
                "responsibilities": "Canonical Russian SSOT alongside English.",
                "what_ru": "Русские строки интерфейса.",
                "why_ru": "RU локаль берёт текст отсюда.",
                "contains_ru": "Карта ключей `kRuL10n` для русских подписей.",
                "responsibilities_ru": "Канонический русский SSOT рядом с English.",
            }
        if "/langs/" in p:
            lang = Path(p).stem
            return {
                "what": f"Partial `{lang}` locale file — keys not translated fall back to English.",
                "why": "Supports additional languages without duplicating the entire dictionary.",
                "contains": f"Locale map layered on English keys.",
                "responsibilities": f"Translate high-traffic keys for `{lang}` users.",
                "what_ru": f"Частичная локаль `{lang}`.",
                "why_ru": "Непереведённые ключи → English.",
                "contains_ru": f"Map локали `{lang}`.",
                "responsibilities_ru": f"Перевод ключей для `{lang}`.",
            }

    if p.startswith("lib/data/"):
        role_short = role_clean.split(";")[0].strip()
        return {
            "what": f"Brain support file — {role_short}.",
            "why": "Shared PocketBase/auth/parse logic used by multiple tabs.",
            "contains": f"Dart code ({sym}).",
            "responsibilities": role_clean,
            "what_ru": f"Вспомогательный модуль brain — {role_short}.",
            "why_ru": "Общая логика PocketBase и auth для нескольких вкладок.",
            "contains_ru": f"Dart-код ({sym}).",
            "responsibilities_ru": f"Реализует в brain: {role_clean}.",
        }

    return None
