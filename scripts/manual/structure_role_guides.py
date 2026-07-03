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
        "Data shapes for how a plan looks on the clock in Time View.",
        "Time View needs projected start/end times separate from raw PocketBase fields.",
        "`TimeModeProjectedPlan`, timezone-aware projection types.",
    ),
    "plan_recurrence_helpers": (
        "Expands repeating plans (daily/weekly RRULE) into visible day rows.",
        "A single recurring gym plan must appear on every matching calendar day.",
        "RRULE JIT expansion, exception dates, virtual occurrence handling.",
    ),
    "plan_time_cascade_helpers": (
        "Calculates where plan blocks sit vertically in Time View when times overlap.",
        "Without cascade math, overlapping plans would draw on top of each other.",
        "Time View cascade layout, duration constants, wall-time estimates.",
    ),
    "plan_tags_helpers": (
        "Syncs tag chips on plan cards with PocketBase `tags_link` relations.",
        "Plan tags must save to the server and show the same on Lists and Plans.",
        "Tag catalog fetch, PB link sync for plans/lists.",
    ),
    "plan_cache_helpers": (
        "Maintains the local plan list clean and scores title similarity for smart linking.",
        "Duplicate plan rows or bad merges would break Planning and Lists tabs.",
        "Plan dedupe/scrub, title link scoring heuristics.",
    ),
    "plan_outbox_helpers": (
        "Queues plan/list edits when offline and flushes when connection returns.",
        "Checking off a list item offline must stick and sync later.",
        "Plan mutation outbox enqueue/flush/replay.",
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


def _sym_line(syms: list[str]) -> str:
    if not syms:
        return "implementation details in the source file"
    return ", ".join(f"`{s}`" for s in syms[:4])


def _part_guide(path: str, role: str, syms: list[str], part_map: dict[str, tuple[str, str, str]], area: str) -> dict[str, str]:
    stem = Path(path).stem
    what, why, contains = part_map.get(stem, (
        f"Brain module for {area} — {role.split(';')[0].strip().lower()}.",
        f"Part of the app brain that keeps {area} consistent with PocketBase.",
        f"Dart code ({_sym_line(syms)}).",
    ))
    return {
        "what": what,
        "why": why,
        "contains": contains,
        "responsibilities": role.split(";")[0].strip(),
        "what_ru": f"Brain-модуль ({area}): {role.split(';')[0].strip()}.",
        "why_ru": f"Часть brain для {area} и PocketBase.",
        "contains_ru": f"Dart-код ({_sym_line(syms)}).",
        "responsibilities_ru": f"Зона ответственности: {role.split(';')[0].strip()}.",
    }


def humanize_guide(path: str, role: str, syms: list[str]) -> dict[str, str] | None:
    """Return partial FileGuide fields, or None to fall through."""
    p = path.replace("\\", "/")
    role_clean = role.strip()
    sym = _sym_line(syms)

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

    if p.startswith("lib/features/"):
        parts = p.split("/")
        feature = parts[2] if len(parts) > 2 else "app"
        screen = FEATURE_SCREENS.get(feature, f"{feature} area")
        name = Path(p).stem.replace("_", " ")
        role_short = role_clean.split(";")[0].strip()
        if role_short.startswith("`") and "`" in role_short[1:]:
            role_short = role_short.split("`", 2)[-1].strip(" `")
        return {
            "what": f"UI code for {screen}: {role_short}.",
            "why": f"Users interact with this when using {screen}.",
            "contains": f"Flutter widgets ({sym}) implementing the visible behavior.",
            "responsibilities": role_clean,
            "what_ru": f"UI для {screen}: {role_short}.",
            "why_ru": f"Пользователь видит это на {screen}.",
            "contains_ru": f"Flutter-виджеты ({sym}).",
            "responsibilities_ru": f"UI-логика: {role_clean}.",
        }

    if p.startswith("lib/shell/"):
        role_short = role_clean.replace("*(part)*", "").strip()
        return {
            "what": f"App shell wiring — {role_short}.",
            "why": "Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.",
            "contains": f"Shell mixin or widget ({sym}).",
            "responsibilities": role_clean,
            "what_ru": f"Оболочка приложения — {role_short}.",
            "why_ru": "Связывает вкладки, voice, edit sheets, offline banner.",
            "contains_ru": f"Shell mixin/виджет ({sym}).",
            "responsibilities_ru": f"UI-логика: {role_clean}.",
        }

    if p.startswith("lib/core/widgets/"):
        role_short = role_clean.split(";")[0].strip()
        return {
            "what": f"Shared design-system widget — {role_short}.",
            "why": "Plans, Timeline, and Lists reuse this instead of copying button/card styles.",
            "contains": f"Canonical Flutter widget ({sym}).",
            "responsibilities": role_clean,
            "what_ru": f"Общий виджет design system — {role_short}.",
            "why_ru": "Один стиль кнопок/карточек на всех вкладках.",
            "contains_ru": f"Виджет ({sym}).",
            "responsibilities_ru": f"UI-логика: {role_clean}.",
        }

    if p.startswith("lib/core/"):
        role_short = role_clean.split(";")[0].strip()
        sub = PurePosixPath(p).parent.name
        return {
            "what": f"Foundation helper ({sub}) — {role_short}.",
            "why": "Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.",
            "contains": f"Dart utilities ({sym}).",
            "responsibilities": role_clean,
            "what_ru": f"Foundation-код ({sub}) — {role_short}.",
            "why_ru": "Общий код: тема, время, voice — не один экран.",
            "contains_ru": f"Утилиты ({sym}).",
            "responsibilities_ru": f"Foundation-логика: {role_clean}.",
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
                "contains_ru": "Map `kEnL10n`.",
                "responsibilities_ru": "Канонический EN; править перед sync_locales.",
            }
        if p.endswith("langs/ru.dart"):
            return {
                "what": "Russian translation strings for the UI.",
                "why": "Russian locale shows text from this map when user picks RU.",
                "contains": "`kRuL10n` map of key → Russian text.",
                "responsibilities": "Canonical Russian SSOT alongside English.",
                "what_ru": "Русские строки интерфейса.",
                "why_ru": "RU локаль берёт текст отсюда.",
                "contains_ru": "Map `kRuL10n`.",
                "responsibilities_ru": "Канонический RU.",
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
            "what_ru": f"Brain — {role_short}.",
            "why_ru": "Общая логика PocketBase для нескольких вкладок.",
            "contains_ru": f"Dart ({sym}).",
            "responsibilities_ru": f"Brain-логика: {role_clean}.",
        }

    return None
