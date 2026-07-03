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
from structure_ru_class_adapters import BANNED_ENGLISH_IN_RU, BANNED_GENERIC_RU_WRAPPERS, BANNED_SEMI_RUSSIAN_WRAPPERS
from structure_file_ru_curated import FILE_RU_CURATED
from structure_role_guides import humanize_guide
from structure_root_guides import ROOT_FILE_GUIDES
from structure_ru_helpers import cyrillic_count, delete_en_to_ru, looks_english_prose

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "APP_STRUCTURE_DETAILED.md"
APP_STRUCTURE = ROOT / "docs" / "APP_STRUCTURE.md"

SYMBOL_RE = re.compile(
    r"^(?:class|enum|extension|mixin|typedef)\s+(\w+)|^void\s+main\s*\(",
    re.M,
)
TABLE_ROW_RE = re.compile(r"^\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|")
FEATURE_FOLDER_ROW_RE = re.compile(r"^\|\s*`([^`]+)/`\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*$")

GENERIC_EN_MARKERS: tuple[str, ...] = (
    "Fulfill the documented role",
    "required for current app behavior",
    "documented workflow",
    "see source file",
    "Source file `",
    "Dart source `",
    "for the Life OS repository",
)

BANNED_EN_WRAPPER_IN_RU: tuple[str, ...] = (
    "Fulfill the documented role",
    "Source file",
    "Role:",
    "required for current app behavior",
)

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


def tracked() -> list[str]:
    out = subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True)
    return sorted(l.strip().replace("\\", "/") for l in out.splitlines() if l.strip())


def sha() -> str:
    return subprocess.check_output(
        ["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True
    ).strip()


def symbols(path: str) -> list[str]:
    p = ROOT / path
    if not p.is_file() or not path.endswith(".dart"):
        return []
    try:
        text = p.read_text(encoding="utf-8")[:6000]
    except OSError:
        return []
    found: list[str] = []
    for m in SYMBOL_RE.finditer(text):
        name = m.group(1)
        if name and name not in found:
            found.append(name)
        if m.group(0).startswith("void main"):
            found.append("main")
    return found[:8]


def clean_role(role: str) -> str:
    r = role.strip()
    r = re.sub(r"\s*\*\(part\)\*", "", r)
    r = r.replace("*(part)*", "").strip()
    return r


def parse_app_structure_roles() -> dict[str, str]:
    """Extract `path` → role from docs/APP_STRUCTURE.md tables."""
    if not APP_STRUCTURE.is_file():
        return {}
    text = APP_STRUCTURE.read_text(encoding="utf-8")
    roles: dict[str, str] = {}
    prefix_stack: list[str] = []

    section_prefix = {
        "3.2": "lib/data/",
        "3.3": "lib/core/",
        "3.5": "lib/l10n/",
        "3.6": "lib/services/",
    }

    current_prefix = ""

    for line in text.splitlines():
        if line.startswith("###"):
            current_prefix = ""
            for key, pref in section_prefix.items():
                if key in line:
                    current_prefix = pref
                    break
            if "3.4.1" in line or ("3.4" in line and "features" in line):
                current_prefix = "lib/features/"
            if "3.1.1" in line and "shell" in line:
                current_prefix = "lib/shell/"
            if "3.1 Entry" in line:
                current_prefix = "lib/"
            if "PocketBase hooks" in line:
                current_prefix = "pb_hooks/"
            continue

        fm = FEATURE_FOLDER_ROW_RE.match(line.strip())
        if fm and current_prefix == "lib/features/":
            folder, files_cell, role = fm.group(1).strip(), fm.group(2), clean_role(fm.group(3))
            if role and not is_generic_en(role):
                for file_m in re.finditer(r"`([^`]+)`", files_cell):
                    raw = file_m.group(1).strip("* ")
                    if raw.endswith("/") or "/" in raw:
                        continue
                    fname = raw if raw.endswith(".dart") else f"{raw}.dart"
                    full = f"lib/features/{folder}/{fname}"
                    roles[full] = role
                    roles[Path(full).name] = role
            continue

        m = TABLE_ROW_RE.match(line.strip())
        if not m:
            continue
        raw_path, role = m.group(1).strip(), clean_role(m.group(2))
        if not role or role in ("Role", "File", "File / folder", "File / pattern"):
            continue
        if raw_path.startswith("lib/") or raw_path.startswith("pb_hooks/"):
            full = raw_path
        elif raw_path.startswith(("shell/", "core/")):
            full = "lib/" + raw_path
        elif "/" in raw_path or raw_path.endswith(".dart"):
            if current_prefix:
                full = current_prefix + raw_path.lstrip("/")
            else:
                full = raw_path
        else:
            continue
        full = full.replace("\\", "/")
        roles[full] = role
        # basename alias for coordinators listed without folder
        roles[Path(full).name] = role

    # Hard-coded mandatory category files (ensure unique even if table drifts)
    roles.setdefault(
        "lib/data/categories/category_cache_helpers.dart",
        "Category fetch from PocketBase, slug reservation, reload rules into memory after changes",
    )
    roles.setdefault(
        "lib/data/categories/category_tree.dart",
        "Parent/child category tree build, sort, path from root, subtree record id collection",
    )
    roles.setdefault(
        "lib/data/categories/category_lookup.dart",
        "Find/match categories by title words, business id, PocketBase row id, fuzzy voice match",
    )
    roles.setdefault(
        "lib/data/categories/category_crud.dart",
        "Create, update, archive, restore, reorder categories; PocketBase PATCH/POST payloads",
    )
    roles.setdefault(
        "lib/data/categories/category_stats.dart",
        "Sum record durations per category and subtree for stats screens",
    )
    roles.setdefault(
        "lib/data/categories/category_record_bridge.dart",
        "Link records to categories; resolve REST ids; repair missing category on save",
    )
    roles.setdefault(
        "lib/data/categories/category_default_time.dart",
        "Per-category default plan start time and timezone inheritance for new plans",
    )
    roles.setdefault(
        "lib/app_shell.dart",
        "Re-exports `shell/life_os_dashboard.dart` (thin entry)",
    )
    roles.setdefault(
        "lib/services/notification_service.dart",
        "Local notifications and plan alarms",
    )
    roles.setdefault(
        ".cursor/rules/flutter_expert.mdc",
        "Always-applied Cursor Agent rules — PocketBase, optimistic UI, main-thread law",
    )
    return roles


CATEGORY_GUIDES: dict[str, FileGuide] = {
    "lib/data/categories/category_cache_helpers.dart": FileGuide(
        what="Loads your category list from PocketBase and refreshes the in-memory category tree after sync.",
        why="Every screen that shows a category name, color, or picker needs an up-to-date list for the signed-in user.",
        contains="Fetch/filter code for `categories` rows plus reload hooks used after edits.",
        responsibilities="Download categories; rebuild local rules; handle backoff when PocketBase is unreachable.",
        when="Categories missing after login, stale tree after edit, or empty picker when server has data.",
        delete="No — required for app runtime.",
        connected="Category manager UI, record start category, plan cards, `category_service.dart`.",
        layer="Brain — `part` of `database_service.dart` (cache/load).",
        what_ru="Загружает список категорий из PocketBase и обновляет дерево категорий в памяти.",
        why_ru="Без актуального списка не работают picker, цвета и привязка записей к категориям.",
        contains_ru="HTTP-загрузка категорий и пересборка локальных правил.",
        responsibilities_ru="Скачать категории пользователя; обновить кэш после изменений.",
        when_ru="Категории не появляются или не обновляются после правок.",
        delete_ru="Нет — нужен для работы приложения.",
        connected_ru="Экран категорий, старт записи, карточки планов.",
        layer_ru="Brain — часть `database_service.dart`.",
    ),
    "lib/data/categories/category_tree.dart": FileGuide(
        what="Builds the parent/child category tree and answers “path from root” questions.",
        why="Categories are nested (clients under Price Reporter, etc.); the app must walk the tree for pickers and stats.",
        contains="Tree walk/sort helpers, `CategoryRule` hierarchy operations, subtree id lists.",
        responsibilities="Sort siblings; find node by PocketBase id; list all record ids under a branch.",
        when="Wrong order in category list, breadcrumb path wrong, stats include wrong subtree.",
        delete="No — required for app runtime.",
        connected="Category tree picker, stats aggregation, voice category path.",
        layer="Brain — `part` of `database_service.dart` (tree structure).",
        what_ru="Строит дерево категорий «родитель → дочерние».",
        why_ru="Нужен для вложенных категорий и хлебных крошек.",
        contains_ru="Обход дерева, сортировка, поиск узла по id.",
        responsibilities_ru="Путь от корня; список id поддерева для статистики.",
        when_ru="Неверный порядок или путь категории в UI.",
        delete_ru="Нет — нужен для работы приложения.",
        connected_ru="Picker категорий, статистика.",
        layer_ru="Brain — часть `database_service.dart`.",
    ),
    "lib/data/categories/category_lookup.dart": FileGuide(
        what="Finds the best matching category when the user types, speaks, or only provides a partial name.",
        why="Voice commands and smart input must map “Price Reporter Planning” to the right category without creating duplicates.",
        contains="Fuzzy word match, deepest-match scoring, business-id ↔ PocketBase id resolution.",
        responsibilities="Score titles against category names; pick deepest match; map legacy ids for saves.",
        when="Voice picks wrong client, plan/record category wrong from title, fuzzy match too aggressive.",
        delete="No — required for app runtime.",
        connected="Voice parser, smart plan input, record start, category pickers.",
        layer="Brain — `part` of `database_service.dart` (search/match).",
        what_ru="Ищет категорию по названию, пути или голосовой фразе.",
        why_ru="Нужен для голоса и умного ввода без дубликатов категорий.",
        contains_ru="Fuzzy-match, scoring, сопоставление id.",
        responsibilities_ru="Выбрать лучшую категорию по тексту.",
        when_ru="Голос или автоподбор выбрал не ту категорию.",
        delete_ru="Нет — нужен для работы приложения.",
        connected_ru="Голос, smart input, picker.",
        layer_ru="Brain — часть `database_service.dart`.",
    ),
    "lib/data/categories/category_crud.dart": FileGuide(
        what="Creates, renames, archives, restores, and reorders categories on the server and in local cache.",
        why="Category manager screen edits must persist to PocketBase and immediately update what Timeline/Plans show.",
        contains="POST/PATCH payloads for `categories` collection, order fields, archive flags.",
        responsibilities="Add nested category; update color/icon/name; archive/restore; write sibling order.",
        when="Category save fails, archive doesn’t stick, drag-reorder not persisted.",
        delete="No — required for app runtime.",
        connected="`lib/features/categories/`, category manager sheets.",
        layer="Brain — `part` of `database_service.dart` (network writes).",
        what_ru="Создаёт и редактирует категории на сервере.",
        why_ru="Экран категорий должен сохранять изменения в PocketBase.",
        contains_ru="POST/PATCH для коллекции categories.",
        responsibilities_ru="CRUD, архив, порядок sibling.",
        when_ru="Категория не сохраняется или не архивируется.",
        delete_ru="Нет — нужен для работы приложения.",
        connected_ru="UI категорий.",
        layer_ru="Brain — часть `database_service.dart`.",
    ),
    "lib/data/categories/category_stats.dart": FileGuide(
        what="Adds up time spent per category (including child categories) for stats views.",
        why="Stats tab shows hours per category; must include entire subtree, not only direct records.",
        contains="Duration rollups filtered by category id set from subtree walk.",
        responsibilities="Filter records by category subtree; sum seconds for day or range.",
        when="Stats totals wrong for parent category, missing child hours.",
        delete="No — required for app runtime.",
        connected="`lib/features/stats/`, Timeline stats tab.",
        layer="Brain — `part` of `database_service.dart` (read-only aggregation).",
        what_ru="Считает длительность записей по категории и поддереву.",
        why_ru="Нужен для вкладки статистики.",
        contains_ru="Суммирование секунд по id поддерева.",
        responsibilities_ru="Длительность за день/период по ветке категории.",
        when_ru="Неверные часы в статистике по категории.",
        delete_ru="Нет — нужен для работы приложения.",
        connected_ru="Stats во Timeline.",
        layer_ru="Brain — часть `database_service.dart`.",
    ),
    "lib/data/categories/category_record_bridge.dart": FileGuide(
        what="Connects timeline records to the correct PocketBase category row when saving or fixing bad links.",
        why="Records must store the 15-char PocketBase category id, not a stale UUID or wrong slug — or saves fail silently.",
        contains="REST id resolution, record/category relation repair, ghost record cleanup hooks.",
        responsibilities="Translate record id for PATCH; map category_link fields; purge dead cache rows.",
        when="Record saves without category, stop/delete uses wrong id, 404 cleanup needed.",
        delete="No — required for app runtime.",
        connected="Record start/stop, edit sheet category field, PocketBase `records` hooks.",
        layer="Brain — `part` of `database_service.dart` (record↔category bridge).",
        what_ru="Связывает записи Timeline с правильной строкой категории в PocketBase.",
        why_ru="Без этого записи сохраняются без категории или с неверным id.",
        contains_ru="Разрешение REST id, починка relation полей.",
        responsibilities_ru="Правильный category id при PATCH записи.",
        when_ru="Запись без категории или ошибка stop/delete по id.",
        delete_ru="Нет — нужен для работы приложения.",
        connected_ru="Timeline, edit sheet, hooks на сервере.",
        layer_ru="Brain — часть `database_service.dart`.",
    ),
    "lib/data/categories/category_default_time.dart": FileGuide(
        what="Stores and applies each category’s default plan start time (e.g. Gym → 19:00).",
        why="Creating a plan under a category should pre-fill sensible time without manual picking every time.",
        contains="Validation for HH:MM, timezone option per category, inheritance when creating plans.",
        responsibilities="Read/write `default_plan_time` fields; apply to new plan drafts; show short TZ label.",
        when="Default time not applied on new plan, wrong timezone on category default, Time View search.",
        delete="No — required for app runtime.",
        connected="Plan create/edit sheets, Time View settings, category editor.",
        layer="Brain — `part` of `database_service.dart` (category schedule defaults).",
        what_ru="Задаёт время по умолчанию для планов в категории (например Gym → 19:00).",
        why_ru="Новые планы должны получать разумное время автоматически.",
        contains_ru="Валидация времени и timezone для категории.",
        responsibilities_ru="Чтение/запись default_plan_time.",
        when_ru="Время по умолчанию не подставляется в новый план.",
        delete_ru="Нет — нужен для работы приложения.",
        connected_ru="Создание/редактирование планов, Time View.",
        layer_ru="Brain — часть `database_service.dart`.",
    ),
}


def layer_for(path: str) -> tuple[str, str]:
    p = path.replace("\\", "/")
    if p.startswith("lib/data/"):
        if p.endswith("_service.dart") or p == "lib/data/database_service.dart":
            return (
                "Brain coordinator — entry point for this domain inside `database_service.dart`.",
                "Brain — координатор домена.",
            )
        if "/local_sync/" in p:
            return ("Brain offline queue / sync state.", "Brain — офлайн-очередь.")
        if "/models/" in p or p == "lib/data/models.dart":
            return ("Data shape only — no network.", "Модели данных — без HTTP.")
        if "/cache/" in p:
            return ("Brain performance cache — faster date paging.", "Brain — кэш производительности.")
        return (
            "Brain module — `part` file merged into `database_service.dart`.",
            "Brain — модуль `part` в `database_service.dart`.",
        )
    if p.startswith("lib/features/"):
        area = p.split("/")[2] if len(p.split("/")) > 2 else "feature"
        return (
            f"UI code for the {area} area of the app (what users see and tap).",
            f"UI — экран/виджет ({area}).",
        )
    if p.startswith("lib/core/widgets/"):
        return (
            "Shared visual widget — reused on multiple tabs.",
            "Общий UI-виджет design system.",
        )
    if p.startswith("lib/core/"):
        return (
            "Foundation code — theme, time, voice services, diagnostics (not a full screen).",
            "Foundation — тема, время, voice, диагностика.",
        )
    if p.startswith("lib/shell/"):
        return ("App shell — navigation and global wiring.", "Shell — навигация приложения.")
    if p.startswith("lib/l10n/"):
        return ("Translations and text keys.", "Локализация — строки UI.")
    if p.startswith("lib/services/"):
        return ("Device service (notifications) — no PocketBase.", "Сервис устройства (уведомления).")
    if p.startswith("test/"):
        return ("Automated test — not shipped to users.", "Автотест.")
    if p.startswith("scripts/"):
        return ("Developer/CI script — run manually or in pipeline.", "Скрипт разработки/CI.")
    if p.startswith("docs/"):
        if "Project Knowledge" in p or "Governing" in p:
            return (
                "Documentation — explains rules, not runtime code.",
                "Governing doc — Project Knowledge pack.",
            )
        return ("Documentation — explains rules, not runtime code.", "Документация — правила, не runtime.")
    if p.startswith((".github/", "installer/", "pb_hooks/")):
        return ("Build/deploy/server configuration.", "Сборка/деплой/сервер.")
    if p.startswith(("android/", "ios/", "web/", "windows/", "linux/", "macos/")):
        return ("Platform wrapper — required for native/web builds.", "Платформенная обёртка Flutter.")
    return ("Repository support file.", "Вспомогательный файл репозитория.")


def delete_for(path: str) -> tuple[str, str]:
    p = path.replace("\\", "/")
    if p.startswith("lib/"):
        return (
            "No — required for app runtime.",
            "Нет — нужен для работы приложения.",
        )
    if p.startswith("test/") or p.startswith("integration_test/"):
        return ("No — required for tests.", "Нет — нужен для тестов.")
    if p in (
        "scripts/manual/export_price_reporter_timesheet.dart",
    ):
        return (
            "Maybe — manual owner billing export; keep unless you no longer run Price Reporter exports.",
            "Возможно — ручной экспорт для биллинга; удалять только если не используете.",
        )
    if p.startswith("docs/"):
        if "reports/FULL_" in p or "FINAL_" in p or p.endswith("PROJECT_KNOWLEDGE_PACK.md"):
            return (
                "No — current cleanup/structure report or upload checklist.",
                "Нет — актуальный отчёт или чеклист.",
            )
        if "website/" in p:
            return (
                "No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).",
                "Нет — маркетинговые тексты сайта.",
            )
        return ("No — governing/current documentation.", "Нет — governing документация.")
    if p.startswith(("scripts/", "installer/", "pb_hooks/", ".github/")):
        return (
            "No — required for build/deploy/audit workflows documented in repo.",
            "Нет — нужен для сборки/деплоя/аудита.",
        )
    if p.startswith(("android/", "ios/", "web/", "windows/", "linux/", "macos/")):
        return (
            "No — required for build/deploy/platform tooling.",
            "Нет — нужен для сборки платформы.",
        )
    return (
        "No — part of repository tooling or config.",
        "Нет — конфигурация/инструмент репозитория.",
    )


def when_for(path: str) -> tuple[str, str]:
    p = path.replace("\\", "/")
    name = Path(p).name
    if "category" in p and p.startswith("lib/data/categories/"):
        return (
            "Category data wrong: missing list, bad match, save/archive/reorder, default plan time.",
            "Проблемы с категориями: список, match, сохранение, время по умолчанию.",
        )
    if p.startswith("lib/data/records/"):
        return (
            "Timeline timer, record edit, offline start/stop, duplicate running record.",
            "Timeline: старт/стоп, правка, офлайн, дубликат running.",
        )
    if p.startswith("lib/data/plans/"):
        return (
            "Plan/list save, Time View layout, recurrence, tags on plans, offline queue.",
            "Планы/списки: сохранение, Time View, повтор, теги.",
        )
    if p.startswith("lib/data/profile/"):
        return (
            "Profile settings, timezone, tags catalog, tag display prefs.",
            "Профиль, timezone, теги.",
        )
    if p.startswith("lib/features/planning/time_view/"):
        return (
            "Time View visual schedule: drag, resize, hour grid, card placement.",
            "Time View: перетаскивание, сетка часов, карточки.",
        )
    if p.startswith("lib/features/planning/"):
        return (
            "Plans tab: day swipe, plan cards, play/start plan, bulk edit.",
            "Вкладка Plans: день, карточки, play.",
        )
    if p.startswith("lib/features/timeline/"):
        return (
            "Timeline tab: day list, record cards, stats toggle, date swipe.",
            "Вкладка Timeline: записи, день, stats.",
        )
    if p.startswith("lib/features/lists/"):
        return (
            "Lists tab: filters, done checkbox, bulk actions, export.",
            "Вкладка Lists: фильтры, done, экспорт.",
        )
    if p.startswith("lib/features/shared/"):
        return (
            "Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.",
            "Шторка редактирования, picker, voice, offline banner.",
        )
    if p.startswith("lib/core/widgets/plan_time_task_card/"):
        return (
            "Plan card look/feel: height, tags, play button, Time View density.",
            "Внешний вид карточки плана.",
        )
    if p.startswith("lib/shell/"):
        return (
            "Bottom tabs, voice routing, edit modal host, offline banner slot.",
            "Навигация, voice, edit host.",
        )
    if p.startswith("scripts/audit/"):
        return (
            "Before merge: run architecture guard to catch forbidden imports/layout drift.",
            "Перед merge: architecture guard.",
        )
    if p.endswith("td.ps1") or p == "update.ps1":
        return (
            "Publishing website to GitHub Pages (`docs/DEPLOY.md`).",
            "Публикация сайта на GitHub Pages.",
        )
    if p.startswith("installer/"):
        return (
            "Building or fixing Windows `CounterSetup.exe` installer.",
            "Сборка Windows installer.",
        )
    if p.startswith("docs/"):
        return (
            "Understanding project rules, deploy steps, or structure — not runtime debugging.",
            "Правила проекта и деплой — не runtime.",
        )
    if p.startswith("android/") or name == "android.ps1":
        return ("Android APK build or permission issues.", "Сборка/permissions Android.")
    if p.startswith("web/"):
        return ("Web deploy blank page, icons, base href.", "Web deploy.")
    return (
        f"When behavior tied to `{name}` breaks or you need to change its documented role.",
        f"Когда ломается поведение, связанное с `{name}`.",
    )


def connected_for(path: str, role: str) -> tuple[str, str]:
    p = path.replace("\\", "/")
    en_parts: list[str] = []
    ru_parts: list[str] = []
    if p.startswith("lib/data/"):
        en_parts.append("UI calls via `DatabaseService.instance`")
        ru_parts.append("UI вызывает `DatabaseService.instance`")
        if "categories" in p:
            en_parts.append("Categories screen, record start, plan cards")
            ru_parts.append("Экран Categories, старт записи, карточки планов")
        elif "records" in p:
            en_parts.append("Timeline tab, edit sheet, Wear")
            ru_parts.append("Timeline, edit sheet, Wear")
        elif "plans" in p:
            en_parts.append("Plans tab, Lists tab, Time View")
            ru_parts.append("Plans, Lists, Time View")
        elif "profile" in p:
            en_parts.append("Profile, tag manager, header timezone")
            ru_parts.append("Profile, tag manager, timezone в header")
        elif "local_sync" in p:
            en_parts.append("Offline banner in shell, reconnect flush")
            ru_parts.append("Offline banner в shell, flush при reconnect")
    elif p.startswith("lib/features/planning"):
        en_parts.append("Plans tab (shell index 1)")
        ru_parts.append("Вкладка Plans (shell index 1)")
    elif p.startswith("lib/features/timeline"):
        en_parts.append("Timeline tab (shell index 0)")
        ru_parts.append("Вкладка Timeline (shell index 0)")
    elif p.startswith("lib/features/lists"):
        en_parts.append("Lists tab (shell index 3)")
        ru_parts.append("Вкладка Lists (shell index 3)")
    elif p.startswith("lib/features/auth"):
        en_parts.append("Login gate from `main.dart`")
        ru_parts.append("Login gate из `main.dart`")
    elif p.startswith("lib/features/shared"):
        en_parts.append("Edit sheets and voice UI on every tab")
        ru_parts.append("Edit sheets и voice UI на всех вкладках")
    elif p.startswith("lib/shell"):
        en_parts.append("All main tabs, `app_shell.dart`")
        ru_parts.append("Все main tabs, `app_shell.dart`")
    elif p.startswith("lib/services/"):
        en_parts.append("`lib/data/plan_service.dart` alarm reschedule")
        ru_parts.append("`lib/data/plan_service.dart` — reschedule alarm")
    elif p.startswith("pb_hooks/"):
        en_parts.append("PocketBase server on VPS — not in Flutter binary")
        ru_parts.append("PocketBase server на VPS — не в APK")
    elif p.startswith(".cursor/"):
        en_parts.append("`.cursorrules`, `docs/ARCHITECTURE.md`")
        ru_parts.append("`.cursorrules`, `docs/ARCHITECTURE.md`")
    if role and not is_generic_en(role):
        short = role.split(";")[0].strip()[:120]
        en_parts.append(f"APP_STRUCTURE role: {short}")
        # English role text belongs in EN block only — never copy into RU «Связано с».
    parent = PurePosixPath(p).parent.as_posix()
    en = "; ".join(en_parts) if en_parts else f"`{parent}/`, `docs/APP_STRUCTURE.md`"
    ru = "; ".join(ru_parts) if ru_parts else f"`{parent}/`, `docs/APP_STRUCTURE.md`"
    return en, ru


def guide_from_role(path: str, role: str, syms: list[str]) -> FileGuide:
    layer_en, layer_ru = layer_for(path)
    del_en, del_ru = delete_for(path)
    when_en, when_ru = when_for(path)
    conn_en, conn_ru = connected_for(path, role)

    human = humanize_guide(path, role, syms)
    if human:
        return FileGuide(
            what=human["what"],
            why=human["why"],
            contains=human["contains"],
            responsibilities=human["responsibilities"],
            when=when_en,
            delete=del_en,
            connected=conn_en,
            layer=layer_en,
            what_ru=human.get("what_ru", ""),
            why_ru=human.get("why_ru", ""),
            contains_ru=human.get("contains_ru", ""),
            responsibilities_ru=human.get("responsibilities_ru", ""),
            when_ru=when_ru,
            delete_ru=del_ru,
            connected_ru=conn_ru,
            layer_ru=layer_ru,
        )

    sym_txt = ", ".join(f"`{s}`" for s in syms[:4]) if syms else "implementation in source"
    role_short = role.split(";")[0].strip()
    if is_generic_en(role_short):
        role_short = Path(path).stem.replace("_", " ")
    return FileGuide(
        what=f"Source file `{Path(path).name}` — {role_short}.",
        why=f"Part of `{PurePosixPath(path).parent}`; see `docs/APP_STRUCTURE.md` for ownership.",
        contains=f"Implementation in `{Path(path).name}` ({sym_txt}).",
        responsibilities=role_short,
        when=when_en,
        delete=del_en,
        connected=conn_en,
        layer=layer_en,
        what_ru="",
        why_ru="",
        contains_ru="",
        responsibilities_ru="",
        when_ru=when_ru,
        delete_ru=del_ru,
        connected_ru=conn_ru,
        layer_ru=layer_ru,
    )


ROOT_FILES_LEGACY: dict[str, FileGuide] = {}


DOC_FILES: dict[str, FileGuide] = {
    "docs/APP_STRUCTURE.md": FileGuide(
        what="Concise map of folders, layers, and import rules.",
        why="Quick answer to ‘where does X live?’ without reading the whole encyclopedia.",
        contains="Tables of lib/data, features, scripts; guard commands.",
        responsibilities="Canonical structure contract for architecture guard.",
        when="Finding module ownership; before moving files.",
        delete="No — Project Knowledge pack.",
        connected="`APP_STRUCTURE_DETAILED.md`, `architecture_guard.ps1`.",
        layer="Governing structure doc.",
    ),
    "docs/PROJECT_KNOWLEDGE_PACK.md": FileGuide(
        what="Checklist of exactly 14 docs to upload to Project Knowledge (not architecture law itself).",
        why="Owner limit of 25 uploaded docs — lists what to include/exclude.",
        contains="Upload list, excluded repo-only docs, removed-doc log.",
        responsibilities="Upload manifest only.",
        when="Refreshing AI project files.",
        delete="No — upload checklist.",
        connected="14-doc pack listed inside.",
        layer="Meta checklist — repo-only.",
    ),
    "docs/DEPLOY.md": FileGuide(
        what="How to publish the website and set up PocketBase auth/admin on the server.",
        why="Deploy and OAuth are easy to get wrong without step-by-step VPS notes.",
        contains="`update.ps1` flow, GitHub Pages, Windows installer section, OAuth admin checklist.",
        responsibilities="Deploy + production auth configuration guide.",
        when="Site not updating, OAuth broken, building Windows installer.",
        delete="No — Project Knowledge pack.",
        connected="`.github/workflows/`, `update.ps1`, `installer/`.",
        layer="Deploy guide — Project Knowledge.",
    ),
}


def platform_guide(path: str) -> FileGuide:
    name = Path(path).name
    parent = PurePosixPath(path).parent.as_posix()
    del_en, del_ru = delete_for(path)
    when_en, when_ru = when_for(path)
    layer_en, layer_ru = layer_for(path)

    inferred = platform_file_description(path)
    if inferred:
        return FileGuide(
            what=inferred["what"],
            why=inferred["why"],
            contains=inferred["contains"],
            responsibilities=inferred["responsibilities"],
            when=when_en,
            delete=del_en,
            connected=f"Flutter `{parent.split('/')[0] if parent else 'repo'}` tooling.",
            layer=layer_en,
            when_ru=when_ru,
            delete_ru=del_ru,
            layer_ru=layer_ru,
            connected_ru=f"`{parent.split('/')[0] if parent else 'repo'}/`, Flutter tooling.",
        )

    if name == "AndroidManifest.xml":
        return FileGuide(
            what="Android app manifest — permissions, app name, deep links, activity entry.",
            why="Android OS reads this at install/run time for permissions and launcher icon.",
            contains="XML permissions (mic, notifications), application label, Flutter activity.",
            responsibilities="Declare what Android allows the app to do.",
            when="Permission denied on Android, app name wrong, intent filters.",
            delete="No — required for Android build.",
            connected="`android/app/build.gradle`, Flutter embedding.",
            layer="Android platform config.",
        )
    if name.endswith("build.gradle") or name.endswith("build.gradle.kts"):
        return FileGuide(
            what=f"Gradle build script for `{parent}` — Android compile settings and plugins.",
            why="Gradle uses this to compile Kotlin/Java and bundle Flutter Android build.",
            contains="SDK versions, Flutter Gradle plugin hook, dependencies.",
            responsibilities="Configure Android compile/target SDK, signing hooks.",
            when="Gradle sync fails, SDK version errors.",
            delete="No — required for Android build.",
            connected="Flutter tooling, `AndroidManifest.xml`.",
            layer="Android build config.",
        )
    if name == "index.html":
        return FileGuide(
            what="Web page shell that loads the compiled Flutter web app.",
            why="Browser needs an HTML entry with base href for GitHub Pages `/Counter/`.",
            contains="Script tags bootstrapping `flutter.js`, base href.",
            responsibilities="Start Flutter web engine in browser.",
            when="Blank web page after deploy.",
            delete="No — required for web build.",
            connected="`flutter build web`, `docs/DEPLOY.md`.",
            layer="Web platform entry.",
        )
    if name == "counter.iss":
        return FileGuide(
            what="Inno Setup script — recipe for building `CounterSetup.exe` installer.",
            why="Packages Flutter Windows build + STT helper + icons into one setup wizard.",
            contains="File copy rules, shortcuts, optional autostart task.",
            responsibilities="Define installer steps and installed file layout.",
            when="Installer missing files or wrong install path on Windows.",
            delete="No — required for Windows installer.",
            connected="`prepare_stt_payload.ps1`, GitHub Actions workflow.",
            layer="Windows installer config.",
        )
    if name.endswith(".pb.js"):
        hook = name.replace(".pb.js", "")
        return FileGuide(
            what=f"PocketBase server hook `{hook}` — runs on VPS when specific API events fire.",
            why="Some rules (password reset email, overlapping records) must be enforced server-side.",
            contains="JavaScript hook handler copied to PocketBase `pb_hooks/` on server.",
            responsibilities=f"Server-side logic for `{hook}` (see `docs/POCKETBASE_MANIFEST.md`).",
            when="Server behavior differs from app expectations for auth/records.",
            delete="No — production PocketBase deployment.",
            connected="PocketBase Admin, Flutter auth/records client.",
            layer="Server hook — not in app binary.",
        )
    plat = p.split("/")[0] if (p := path.replace("\\", "/")) else "repo"
    return FileGuide(
        what=f"{plat} build file `{name}` in `{parent}` — required by Flutter/native toolchain.",
        why=f"Without `{name}`, {plat} compile or packaging step for this folder may fail.",
        contains=f"Native/config source for `{parent}` (open file only when build errors cite it).",
        responsibilities=f"Support {plat} embedder build for `{parent}` — not Dart business logic.",
        when=f"Build log mentions `{name}` or `{parent}`.",
        delete="No — required for build/deploy/platform tooling.",
        connected=f"`{plat}/` platform folder, Flutter embedder.",
        layer=layer_en,
        what_ru=f"Файл сборки {plat}: `{name}` в `{parent}`.",
        why_ru=f"Нужен для сборки {plat}; без него возможны ошибки compile.",
        contains_ru=f"Native/config для `{parent}`.",
        responsibilities_ru=f"Поддержка embedder {plat}.",
        when_ru=f"Ошибка сборки с `{name}`.",
        delete_ru=del_ru,
        connected_ru=f"`{plat}/`, Flutter embedder.",
        layer_ru=layer_ru,
    )


def script_guide(path: str) -> FileGuide:
    name = Path(path).name
    if name == "architecture_guard.ps1":
        return FileGuide(
            what="Checks repo structure rules — forbidden imports, required docs, large-file warnings.",
            why="Prevents accidental architecture breaks during refactors.",
            contains="PowerShell rules matching `docs/APP_STRUCTURE.md`.",
            responsibilities="Exit non-zero in `-Strict` mode on violations.",
            when="Before merge; after moving files.",
            delete="No — required for audit workflow.",
            connected="`docs/APP_STRUCTURE.md`, CI optional.",
            layer="Audit script.",
        )
    if name == "generate_app_structure_detailed.py":
        return FileGuide(
            what="Builds this document (`APP_STRUCTURE_DETAILED.md`) from git file list + role map.",
            why="Maintains owner-readable structure guide in sync with repo after changes.",
            contains="Python generator + curated folder/file descriptions.",
            responsibilities="Regenerate detailed structure encyclopedia.",
            when="After adding/removing tracked files; after editing structure docs.",
            delete="No — required for structure doc generation.",
            connected="`docs/APP_STRUCTURE.md`, `structure_guide_data.py`.",
            layer="Doc generation script.",
        )
    if name == "sync_locales.dart":
        return FileGuide(
            what="Copies translation keys from English/Russian source files into other locale files.",
            why="Synchronizes `lib/l10n/langs/*.dart` when dictionary keys are added.",
            contains="Dart script scanning dictionary keys.",
            responsibilities="Run after editing `en.dart` / `ru.dart`.",
            when="Missing translation key in non-EN/RU locale.",
            delete="No — locale SSOT workflow.",
            connected="`lib/l10n/langs/HELP HOW TO UPDATE the languages`.",
            layer="Locale maintenance script.",
        )
    if name == "export_price_reporter_timesheet.dart":
        return FileGuide(
            what="Manual export of Price Reporter timeline records to CSV for owner billing/reporting.",
            why="Internal business reporting — not an in-app user feature.",
            contains="Read-only PocketBase queries + CSV writer to `exports/`.",
            responsibilities="Generate timesheet CSV for configured date range.",
            when="Owner runs monthly Price Reporter billing export.",
            delete="Maybe — manual owner utility; keep unless export no longer used.",
            connected="`docs/website/INTERNAL_NOTES_NOT_FOR_SITE.md`, `exports/` folder.",
            layer="Manual owner script — not shipped in app.",
        )
    return FileGuide(
        what=f"Developer script `{name}` — run manually for maintenance, smoke test, or deploy helper.",
        why="Automates a repeatable task documented in repo notes or `DEPLOY.md`.",
        contains=f"PowerShell, Python, or Dart commands for `{name}`.",
        responsibilities="See script header comments for exact behavior.",
        when=f"When workflow documented for `{name}` is needed.",
        delete="No — part of documented dev workflow unless cleanup report removed it.",
        connected="`scripts/manual/`, `docs/DEPLOY.md`.",
        layer="Developer script.",
    )


def test_guide(path: str, syms: list[str]) -> FileGuide:
    stem = Path(path).stem
    return FileGuide(
        what=f"Automated test `{stem}` — verifies behavior without manual tapping.",
        why="Prevents regressions when related production code changes.",
        contains=f"Test cases (symbols: {', '.join(syms[:3]) or 'test groups'}).",
        responsibilities=f"Assert expected behavior for `{stem}` scenario.",
        when=f"CI failure or changing code near `{stem.replace('_test', '')}`.",
        delete="No — required for tests.",
        connected=f"Matching files under `lib/` with similar name.",
        layer="Test — not shipped to users.",
    )


def file_guide_from_dict(data: dict[str, str]) -> FileGuide:
    return FileGuide(
        what=data["what"],
        why=data["why"],
        contains=data["contains"],
        responsibilities=data["responsibilities"],
        when=data["when"],
        delete=data["delete"],
        connected=data["connected"],
        layer=data["layer"],
        what_ru=data.get("what_ru", ""),
        why_ru=data.get("why_ru", ""),
        contains_ru=data.get("contains_ru", ""),
        responsibilities_ru=data.get("responsibilities_ru", ""),
        when_ru=data.get("when_ru", ""),
        delete_ru=data.get("delete_ru", ""),
        connected_ru=data.get("connected_ru", ""),
        layer_ru=data.get("layer_ru", ""),
    )


def finalize_file_guide(path: str, g: FileGuide) -> FileGuide:
    """Merge curated RU + EN-adapted RU; reject meaningless filler."""
    en = {
        "what": g.what,
        "why": g.why,
        "contains": g.contains,
        "responsibilities": g.responsibilities,
        "when": g.when,
        "delete": g.delete,
        "connected": g.connected,
        "layer": g.layer,
    }
    existing = {
        "what_ru": g.what_ru,
        "why_ru": g.why_ru,
        "contains_ru": g.contains_ru,
        "responsibilities_ru": g.responsibilities_ru,
        "when_ru": g.when_ru,
        "delete_ru": g.delete_ru,
        "connected_ru": g.connected_ru,
        "layer_ru": g.layer_ru,
    }
    curated = FILE_RU_CURATED.get(path, {})
    adapted = adapt_file_guide_ru(path, en)
    _, layer_fallback = layer_for(path)
    when_en, when_fallback = when_for(path)
    del_en, del_fallback = delete_for(path)

    def pick(ru_key: str, fallback: str = "") -> str:
        en_key = ru_key.replace("_ru", "")
        for src in (curated.get(ru_key), existing.get(ru_key), adapted.get(ru_key), fallback):
            if (
                src
                and not str(src).startswith("NEEDS HUMAN")
                and ru_field_ok(src, min_cyrillic=6)
                and not has_banned_filler(src)
            ):
                return src
        en_val = en.get(en_key, "")
        if en_val:
            from structure_en_ru_adapt import _phrase_translate
            from structure_ru_class_adapters import sanitize_ru_prose

            tr = sanitize_ru_prose(_phrase_translate(en_val))
            if tr and ru_field_ok(tr, min_cyrillic=6) and not has_banned_filler(tr) and not is_generic_en(tr):
                return tr
        tail = fallback or existing.get(ru_key) or curated.get(ru_key) or ""
        if not tail and path.endswith(".dart"):
            from structure_role_guides import humanize_guide

            human = humanize_guide(path, en.get("responsibilities", ""), [])
            if human:
                hv = human.get(ru_key, "")
                if hv and not has_banned_filler(hv):
                    return hv
        if tail and not str(tail).startswith("NEEDS HUMAN"):
            return tail
        if ru_key == "connected_ru" and en.get("connected"):
            return en["connected"].rstrip(".") + "."
        if ru_key == "layer_ru" and fallback:
            return fallback
        return ""

    return FileGuide(
        what=g.what,
        why=g.why,
        contains=g.contains,
        responsibilities=g.responsibilities,
        when=g.when,
        delete=g.delete,
        connected=g.connected,
        layer=g.layer,
        what_ru=pick("what_ru"),
        why_ru=pick("why_ru"),
        contains_ru=pick("contains_ru"),
        responsibilities_ru=pick("responsibilities_ru"),
        when_ru=pick("when_ru", when_fallback),
        delete_ru=pick("delete_ru", del_fallback),
        connected_ru=pick("connected_ru"),
        layer_ru=pick("layer_ru", layer_fallback),
    )


def build_guide(path: str, roles: dict[str, str], syms: list[str]) -> FileGuide:
    if path in ROOT_FILE_GUIDES:
        return file_guide_from_dict(ROOT_FILE_GUIDES[path])
    if path in CATEGORY_GUIDES:
        return CATEGORY_GUIDES[path]
    if path in ROOT_FILES_LEGACY:
        return ROOT_FILES_LEGACY[path]
    if path in DOC_FILES:
        return DOC_FILES[path]
    if path.startswith(("android/", "ios/", "web/", "windows/", "linux/", "macos/", ".github/", "installer/", "pb_hooks/", ".cursor/")):
        return platform_guide(path)
    role = roles.get(path) or roles.get(Path(path).name, "")
    if role:
        return guide_from_role(path, role, syms)
    if path.startswith("scripts/"):
        return script_guide(path)
    if path.startswith("docs/"):
        doc_name = Path(path).name
        return FileGuide(
            what=f"Documentation file `{doc_name}` — explains part of project rules, deploy, or reports.",
            why="Human/AI readable spec; not executed by the app.",
            contains="Markdown sections for this topic.",
            responsibilities=f"Answer questions about `{doc_name.replace('.md', '').replace('_', ' ')}`.",
            when=f"Need written guidance for topic covered by `{doc_name}`.",
            delete=delete_for(path)[0],
            connected="Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.",
            layer="Documentation.",
        )
    if path.startswith("test/") or path.startswith("integration_test/"):
        return test_guide(path, syms)
    # lib/**/*.dart without APP_STRUCTURE row — still use humanize, never generic last-resort
    if path.endswith(".dart") and path.startswith("lib/"):
        role = roles.get(path) or roles.get(Path(path).name, "")
        if is_generic_en(role):
            role = ""
        return guide_from_role(path, role or Path(path).stem.replace("_", " "), syms)
    # Last-resort: unique by path + extension
    p = path.replace("\\", "/")
    name = Path(p).name
    parent = PurePosixPath(p).parent.as_posix()
    ext = Path(p).suffix.lower()
    del_en, del_ru = delete_for(path)
    layer_en, layer_ru = layer_for(path)
    when_en, when_ru = when_for(path)
    kind = {
        ".md": "Markdown document",
        ".yaml": "YAML configuration",
        ".yml": "YAML configuration",
        ".json": "JSON data/config",
        ".xml": "XML configuration",
        ".properties": "Java/Gradle properties",
        ".gradle": "Gradle script",
        ".kts": "Kotlin Gradle script",
        ".kt": "Kotlin source",
        ".swift": "Swift source",
        ".cpp": "C++ native source",
        ".h": "C/C++ header",
        ".rc": "Windows resource script",
        ".ico": "Windows icon asset",
        ".plist": "Apple property list",
        ".xcconfig": "Xcode build setting",
        ".pbxproj": "Xcode project file",
        ".dart": "Dart source",
        ".ps1": "PowerShell script",
        ".py": "Python script",
        ".js": "JavaScript source",
        ".pb.js": "PocketBase hook script",
        ".iss": "Inno Setup installer script",
        ".bat": "Windows batch script",
        ".sh": "Shell script",
        ".png": "PNG image asset",
        ".jpg": "JPEG image asset",
        ".svg": "SVG vector asset",
        ".ttf": "Font file",
        ".otf": "Font file",
    }.get(ext, f"{ext.lstrip('.') or 'text'} file")
    return FileGuide(
        what=f"{kind} `{name}` in `{parent}` — repo tooling or config.",
        why=f"Tracked because `{parent}` needs `{name}` for build, CI, or maintenance.",
        contains=f"Open `{name}` when working on `{parent}` (see folder section above).",
        responsibilities=f"Supports `{parent}` workflow for `{name}`.",
        when=f"When build output or maintenance cites `{name}`.",
        delete=del_en,
        connected=f"`{parent}/`, `docs/APP_STRUCTURE.md`.",
        layer=layer_en,
        what_ru="",
        why_ru="",
        contains_ru="",
        responsibilities_ru="",
        when_ru=when_ru,
        delete_ru=del_ru,
        connected_ru=f"`{parent}/`, `docs/APP_STRUCTURE.md`.",
        layer_ru=layer_ru,
    )


def render_folder(dirpath: str) -> str:
    key = dirpath.replace("\\", "/").strip("/") or "."
    data = infer_folder_guide(key)
    display = f"`{key}/`" if key != "." else "Repository root"
    return (
        f"## Folder: {display}\n\n"
        f"EN:\n\n"
        f"- **What this folder is:** {data['what']}\n"
        f"- **Why it exists:** {data['why']}\n"
        f"- **What lives here:** {data['inside']}\n"
        f"- **What part of the app it affects:** {data['affects']}\n"
        f"- **When to open it:** {data['when']}\n"
        f"- **Can it be deleted?** {data['delete']}\n"
        f"- **Main related paths:** {data['related']}\n\n"
        f"RU:\n\n"
        f"- **Что это за папка:** {data['what_ru']}\n"
        f"- **Зачем нужна:** {data['why_ru']}\n"
        f"- **Что здесь лежит:** {data['inside_ru']}\n"
        f"- **На что влияет в приложении:** {data['affects_ru']}\n"
        f"- **Когда открывать:** {data['when_ru']}\n"
        f"- **Можно удалить?** {data['delete_ru']}\n"
        f"- **Связанные пути:** {data['related_ru']}\n"
    )


def render_file(path: str, g: FileGuide, syms: list[str]) -> str:
    sym_line = f"\n- **Key code names:** {', '.join(f'`{s}`' for s in syms)}" if syms else ""
    return (
        f"### `{path}`\n\n"
        f"EN:\n\n"
        f"- **What this is:** {g.what}\n"
        f"- **Why needed:** {g.why}\n"
        f"- **What it contains:** {g.contains}{sym_line}\n"
        f"- **Responsibilities:** {g.responsibilities}\n"
        f"- **When to open:** {g.when}\n"
        f"- **Can it be deleted?** {g.delete}\n"
        f"- **Connected to:** {g.connected}\n"
        f"- **Layer / owner:** {g.layer}\n\n"
        f"RU:\n\n"
        f"- **Что это:** {g.what_ru}\n"
        f"- **Зачем:** {g.why_ru}\n"
        f"- **Содержимое:** {g.contains_ru}\n"
        f"- **Обязанности:** {g.responsibilities_ru}\n"
        f"- **Когда открывать:** {g.when_ru}\n"
        f"- **Можно удалить?** {g.delete_ru}\n"
        f"- **Связано с:** {g.connected_ru}\n"
        f"- **Слой:** {g.layer_ru}\n"
    )


def quality_check(text: str, paths: list[str], expected_sha: str) -> list[str]:
    issues: list[str] = []
    whats: list[str] = []
    all_banned_en = BAD_PHRASES + BANNED_EN_PHRASES

    if f"**Generated at git SHA `{expected_sha}`" not in text:
        issues.append(f"SHA mismatch: header must contain `{expected_sha}`")

    en_ru_pairs = (
        ("- **What this folder is:**", "- **Что это за папка:**"),
        ("- **Why it exists:**", "- **Зачем нужна:**"),
        ("- **What lives here:**", "- **Что здесь лежит:**"),
        ("- **What part of the app it affects:**", "- **На что влияет в приложении:**"),
        ("- **When to open it:**", "- **Когда открывать:**"),
        ("- **Can it be deleted?**", "- **Можно удалить?**"),
        ("- **What this is:**", "- **Что это:**"),
        ("- **Why needed:**", "- **Зачем:**"),
        ("- **What it contains:**", "- **Содержимое:**"),
        ("- **Responsibilities:**", "- **Обязанности:**"),
        ("- **When to open:**", "- **Когда открывать:**"),
        ("- **Connected to:**", "- **Связано с:**"),
        ("- **Layer / owner:**", "- **Слой:**"),
    )
    en_by_ru = {ru: en for en, ru in en_ru_pairs}

    desc_prefixes = (
        "- **What this is:**",
        "- **Why needed:**",
        "- **What it contains:**",
        "- **Responsibilities:**",
        "- **What this folder is:**",
        "- **Why it exists:**",
        "- **What lives here:**",
        "- **What part of the app it affects:**",
        "- **When to open:**",
        "- **When to open it:**",
        "- **Что это:**",
        "- **Что это за папка:**",
        "- **Зачем:**",
        "- **Зачем нужна:**",
        "- **Содержимое:**",
        "- **Что здесь лежит:**",
        "- **Обязанности:**",
        "- **На что влияет в приложении:**",
    )
    ru_prefixes = ("- **Что", "- **Зачем", "- **Содержимое", "- **Обязанности", "- **На что", "- **Можно удалить", "- **Связано", "- **Слой", "- **Когда открывать")

    section_en: dict[str, str] = {}
    in_ru = False
    section_title = ""

    for line in text.splitlines():
        if line.startswith("## Folder:") or line.startswith("### `"):
            section_en = {}
            in_ru = False
            section_title = line[:80]
        elif line.strip() == "RU:":
            in_ru = True
        elif line.strip() == "EN:":
            in_ru = False

        if line.startswith("- **What this is:**"):
            whats.append(line.split(":", 1)[1].strip())

        for prefix in desc_prefixes:
            if not line.startswith(prefix):
                continue
            val = line.split(":", 1)[1].strip()
            is_ru = any(line.startswith(p) for p in ru_prefixes)
            banned = BANNED_RU_PHRASES if is_ru else all_banned_en
            for bad in banned:
                if bad in val:
                    issues.append(f"Banned phrase '{bad}' in: {line[:120]}")
                    break
            if line.startswith("- **What this folder is:**") and val.startswith("Folder `"):
                issues.append(f"Generic folder prefix in: {val[:90]}")
            if not is_ru:
                section_en[prefix] = val
            elif in_ru:
                en_prefix = en_by_ru.get(prefix)
                en_val = section_en.get(en_prefix, "") if en_prefix else ""
                if "NEEDS HUMAN DESCRIPTION" in val:
                    break
                path_like = val.startswith("`") or val.startswith("http") or "@" in val
                skip_en_copy = prefix in (
                    "- **Что здесь лежит:**",
                    "- **Связанные пути:**",
                    "- **Связано с:**",
                ) and (path_like or val == en_val)
                if val == en_val and en_val and not skip_en_copy:
                    issues.append(f"RU copies EN in {section_title}: {line[:100]}")
                if line.startswith("- **Можно удалить?**") and (
                    val.startswith("No —") or val.startswith("Maybe —")
                ):
                    issues.append(f"English delete prefix in RU: {line[:100]}")
                skip_prose = prefix in (
                    "- **Связано с:**",
                    "- **Слой:**",
                    "- **Связанные пути:**",
                    "- **Содержимое:**",
                    "- **Что здесь лежит:**",
                ) or (cyrillic_count(val) >= 6 and "`" in val) or cyrillic_count(val) >= 6
                if not skip_prose and looks_english_prose(val):
                    if len(val) > 35 and "NEEDS HUMAN DESCRIPTION" not in val:
                        issues.append(f"English prose in RU block ({section_title}): {line[:100]}")
            break

    counts = Counter(whats)
    dupes = [(w, c) for w, c in counts.items() if c > 2 and len(w) < 100]
    if dupes:
        issues.append(
            "Duplicate 'What this is' (>2): "
            + "; ".join(f"{c}x {w[:60]}" for w, c in dupes[:8])
        )
    if len(paths) != len(set(paths)):
        issues.append("Duplicate file paths in output")

    folder_whats_ru: list[str] = []
    file_whats_ru: list[str] = []
    in_ru_block = False
    for line in text.splitlines():
        if line.strip() == "RU:":
            in_ru_block = True
        elif line.strip() == "EN:" or line.startswith("## Folder:") or line.startswith("### `"):
            if line.startswith("## Folder:") or line.startswith("### `"):
                in_ru_block = False
            elif line.strip() == "EN:":
                in_ru_block = False
        if in_ru_block and line.startswith("- **") and ":" in line:
            val_part = line.split(":", 1)[1].strip()
            for bad in (
                BANNED_MEANINGLESS_RU_FILLER
                + BANNED_SEMI_RUSSIAN_WRAPPERS
                + BANNED_ENGLISH_IN_RU
                + BANNED_GENERIC_RU_WRAPPERS
            ):
                if bad in val_part:
                    issues.append(f"Banned RU filler '{bad}' in: {line[:120]}")
                    break
            if line.startswith("- **Что это за папка:**"):
                folder_whats_ru.append(line.split(":", 1)[1].strip())
            if line.startswith("- **Что это:**"):
                file_whats_ru.append(line.split(":", 1)[1].strip())

    needs_count = text.count("NEEDS HUMAN DESCRIPTION")
    if needs_count > 0:
        issues.append(
            f"NEEDS HUMAN DESCRIPTION entries remain: {needs_count} (class adapters incomplete)"
        )

    for label, vals in (("folder", folder_whats_ru), ("file", file_whats_ru)):
        counts = Counter(vals)
        dupes = [(v, c) for v, c in counts.items() if c > 8 and len(v) < 120]
        if dupes:
            issues.append(
                f"Duplicate RU 'Что это' ({label}, >3): "
                + "; ".join(f"{c}x {v[:50]}" for v, c in dupes[:6])
            )

    in_ru_block = False
    for line in text.splitlines():
        if line.strip() == "RU:":
            in_ru_block = True
        elif line.strip() == "EN:" or line.startswith("## Folder:") or line.startswith("### `"):
            if line.startswith("## Folder:") or line.startswith("### `"):
                in_ru_block = False
            elif line.strip() == "EN:":
                in_ru_block = False
        if not in_ru_block:
            continue
        for prefix in RU_REQUIRED_PREFIXES:
            if line.startswith(prefix):
                val = ru_line_value(line, prefix)
                if not val:
                    issues.append(f"Empty RU field: {line[:100]}")
                for bad in BANNED_EN_WRAPPER_IN_RU:
                    if bad in val:
                        issues.append(f"EN wrapper in RU: {line[:100]}")
                break

    return issues


def main() -> None:
    all_files = tracked()
    roles = parse_app_structure_roles()

    # Unique folders deepest-first for section order
    folders: set[str] = set()
    for f in all_files:
        parts = PurePosixPath(f).parts
        for i in range(len(parts)):
            folders.add("/".join(parts[:i]) if i else "")

    folder_order = sorted(folders, key=lambda x: (x.count("/"), x))

    lines = [
        "# APP_STRUCTURE_DETAILED",
        "",
        "Owner-readable guide: every tracked folder and file in plain language (EN + RU).",
        "",
    ]
    head_sha = sha()
    lines.extend(
        [
            f"**Generated at git SHA `{head_sha}` on {date.today().isoformat()}.**",
            "",
            "Concise map: [`APP_STRUCTURE.md`](APP_STRUCTURE.md) · Upload checklist: [`PROJECT_KNOWLEDGE_PACK.md`](PROJECT_KNOWLEDGE_PACK.md)",
            "",
            "Regenerate after tree changes:",
            "",
            "```powershell",
            "python scripts/manual/generate_app_structure_detailed.py",
            "```",
            "",
            "---",
            "",
            "## How to read this document",
            "",
            "Each **folder** section explains why that part of the repo exists. Each **file** section is unique — if two files did the same job, one of them would not belong in the repo.",
            "",
            "---",
            "",
        ]
    )

    # Folder sections (skip empty root duplicate)
    for folder in folder_order:
        if folder == "":
            continue
        # Only emit folders that are prefixes of tracked files
        if not any(f == folder or f.startswith(folder + "/") for f in all_files):
            continue
        lines.append(render_folder(folder))
        lines.append("---")
        lines.append("")

    lines.append("## All tracked files (alphabetical)")
    lines.append("")

    what_samples: list[str] = []
    for path in all_files:
        syms = symbols(path)
        g = finalize_file_guide(path, build_guide(path, roles, syms))
        what_samples.append(g.what)
        lines.append(render_file(path, g, syms))
        lines.append("")

    body = "\n".join(lines)
    issues = quality_check(body, all_files, head_sha)
    OUT.write_text(body, encoding="utf-8")
    print(f"Wrote {OUT} ({len(all_files)} files, {len(folder_order)} folders, {len(body.splitlines())} lines)")
    if issues:
        print("QUALITY FAILURES:", file=sys.stderr)
        for i in issues[:30]:
            print(f"  - {i}", file=sys.stderr)
        print(f"Quality check: {len(issues)} issue(s)", file=sys.stderr)
        sys.exit(1)
    print("Quality check: OK")


if __name__ == "__main__":
    main()
