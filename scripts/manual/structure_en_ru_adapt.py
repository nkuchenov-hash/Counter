"""Adapt EN structure guide fields to meaningful RU — never path-based filler."""

from __future__ import annotations

from structure_ru_helpers import cyrillic_count, delete_en_to_ru
from structure_ru_class_adapters import (
    file_class_field,
    folder_class_field,
    has_semi_russian_or_english_leak,
    sanitize_ru_prose,
)

# Banned meaningless RU filler (quality gate + generation guard).
BANNED_MEANINGLESS_RU_FILLER: tuple[str, ...] = (
    "Папка `",
    "репозитория Life OS",
    "Файлы здесь нужны для сборки, CI или сопровождения проекта",
    "Tracked-файлы перечислены ниже",
    "Tracked-файлы в",
    "описаны ниже по одному",
    "Workflow или сборка, связанная с этим путём",
    "Сопровождение или сборка, связанная с",
    "Код приложения в `",
    "часть Flutter-приложения",
    "Всё под `lib/` попадает",
    "Dart-модули в",
    "перечень файлов ниже",
    "Поведение и UI модуля, названного в пути папки",
    "Правки или баги в",
    "Платформенная папка",
    "native-обёртка",
    "Native-конфиги",
    "generated-файлы embedder",
    "Platform-файл",
    "Native/config-содержимое",
    "Поддержка embedder-сборки",
    "см. EN-блок",
    "platform/config файл",
    "Нужен для workflow или сборки",
    "Содержимое `",
    "— открыть файл при правках",
    "Роль `",
    " в модуле `",
    "Связи файла `",
)

FIELD_KEYS = ("what", "why", "inside", "affects", "when", "delete", "related")
FILE_FIELD_KEYS = (
    "what",
    "why",
    "contains",
    "responsibilities",
    "when",
    "delete",
    "connected",
    "layer",
)


def has_banned_filler(text: str) -> bool:
    if not text:
        return False
    if any(bad in text for bad in BANNED_MEANINGLESS_RU_FILLER):
        return True
    return has_semi_russian_or_english_leak(text)


def ru_field_ok(text: str, *, min_cyrillic: int = 8) -> bool:
    if not text or text.startswith("NEEDS HUMAN"):
        return False
    if has_banned_filler(text):
        return False
    cleaned = sanitize_ru_prose(text)
    if cyrillic_count(cleaned) >= min_cyrillic:
        return True
    if "`" in cleaned and cyrillic_count(cleaned) >= 4 and len(cleaned) >= 18:
        return True
    return False


# Exact EN → RU for folder fields (highest priority).
EXACT_FOLDER_RU: dict[str, dict[str, str]] = {}


def register_folder_ru(key: str, ru: dict[str, str]) -> None:
    EXACT_FOLDER_RU[key.replace("\\", "/").strip("/")] = ru


def _phrase_translate(en: str) -> str:
    """Translate EN guide prose to RU by preserving backtick segments."""
    if not en or not en.strip():
        return en
    # Longest-first phrase replacements (EN fragment → RU fragment).
    repl: tuple[tuple[str, str], ...] = (
        (
            "GitHub automation folder — CI workflows that publish the web site and build the Windows installer.",
            "Папка с автоматическими задачами GitHub. После push GitHub Actions берёт эти workflow-файлы: один публикует web-версию на GitHub Pages, второй собирает установщик Windows.",
        ),
        (
            "Robots run here after git push: one workflow deploys GitHub Pages, another builds `CounterSetup.exe`.",
            "После push здесь запускаются роботы: один workflow выкладывает GitHub Pages, другой собирает `CounterSetup.exe`.",
        ),
        (
            "Foundation layer — theme colors, shared widgets, clock/time math, desktop voice services, diagnostics.",
            "Базовый слой приложения. Здесь лежат общие вещи, которыми пользуются разные экраны: тема, цвета, кнопки, карточки, расчёты времени, desktop voice, диагностика и performance flags.",
        ),
        (
            "Feature screens must not duplicate buttons, date headers, or voice plumbing; this is the design-system and utility base.",
            "Экраны не должны дублировать кнопки, заголовки дат и voice — это база design system и утилит.",
        ),
        (
            "The app “brain” — everything that talks to PocketBase, holds cached data, and applies changes before the server confirms.",
            "«Мозг» приложения — всё, что общается с PocketBase, держит кэш и применяет изменения до ответа сервера.",
        ),
        (
            "Single place for save/load rules so Timeline, Plans, Lists, and Categories stay consistent and offline-safe.",
            "Единые правила сохранения/загрузки, чтобы Timeline, Plans, Lists и Categories были согласованы и offline-safe.",
        ),
        (
            "All user-facing screens — Timeline, Plans, Lists, Profile, Categories, auth, Wear, shared edit sheets.",
            "Все экраны для пользователя — Timeline, Plans, Lists, Profile, Categories, вход, Wear и общие edit sheets.",
        ),
        (
            "Separates what users see and tap from the PocketBase brain in `lib/data/`.",
            "Отделяет то, что пользователь видит и нажимает, от PocketBase-мозга в `lib/data/`.",
        ),
        (
            "App shell — bottom tabs, desktop side nav, voice routing, edit modals, offline banner slot.",
            "Оболочка приложения — нижние вкладки, боковая навигация на desktop, маршрутизация voice, edit modals и слот offline banner.",
        ),
        (
            "Connects `main.dart` to feature pages and global behaviors (voice, sync banner).",
            "Связывает `main.dart` с экранами и глобальным поведением (voice, sync banner).",
        ),
        (
            "Translations — every button label, error message, and menu title the app shows.",
            "Переводы — каждая подпись кнопки, сообщение об ошибке и пункт меню, который видит пользователь.",
        ),
        (
            "Users switch language in settings; all text must resolve through one dictionary.",
            "Пользователь меняет язык в настройках; весь текст идёт через один словарь.",
        ),
        (
            "Device-only services that are not PocketBase — currently plan alarm notifications.",
            "Сервисы устройства, не PocketBase — сейчас уведомления-напоминания по планам.",
        ),
        (
            "OS notification scheduling lives outside the brain; keeps `lib/data/` free of platform notification APIs.",
            "Планирование уведомлений ОС вне мозга; `lib/data/` не тянет platform notification API.",
        ),
        (
            "Android wrapper — tells Android how to build the APK, permissions, icons, Google services file.",
            "Android-обёртка — Gradle, `AndroidManifest`, permissions, иконки launcher и файлы Google services для сборки APK/AAB.",
        ),
        (
            "Flutter needs native Android project files to produce installable APK/AAB.",
            "Flutter нужны native-файлы Android-проекта, чтобы получить устанавливаемый APK/AAB.",
        ),
        (
            "iOS wrapper — Xcode project for iPhone/iPad builds.",
            "iOS-обёртка — Xcode-проект для сборки на iPhone/iPad (TestFlight/App Store).",
        ),
        (
            "Apple requires this structure for App Store or TestFlight builds.",
            "Apple требует эту структуру для TestFlight и App Store.",
        ),
        (
            "Web shell — `index.html`, PWA manifest, icons for GitHub Pages site.",
            "Web-оболочка — `index.html`, PWA manifest и иконки для сайта на GitHub Pages с base href `/Counter/`.",
        ),
        (
            "Browser version loads Flutter web build; base href `/Counter/` for GitHub Pages.",
            "Браузерная версия грузит Flutter web; base href `/Counter/` для GitHub Pages.",
        ),
        (
            "Windows desktop runner — native `.exe` host for Flutter on Windows.",
            "Windows desktop runner — native `.exe`, который поднимает Flutter engine на Windows.",
        ),
        (
            "Desktop voice, tray, hotkey, and installer packaging need Windows embedder.",
            "Desktop voice, tray, hotkey и упаковка installer опираются на Windows embedder.",
        ),
        (
            "Windows installer packaging — builds `CounterSetup.exe` users can run to install the app.",
            "Папка для сборки обычного Windows-установщика `CounterSetup.exe`. Она не отвечает за экран приложения; она упаковывает готовую Windows-сборку, STT helper, иконки и правила установки в один setup-файл.",
        ),
        (
            "Flutter build alone is a folder of files; installer bundles app + STT helper + icons.",
            "Сборка Flutter — это папка файлов; installer собирает app + STT helper + иконки в один wizard.",
        ),
        (
            "JavaScript hooks copied to the PocketBase server — rules that run on the VPS, not in the phone app.",
            "JavaScript hooks для сервера PocketBase на VPS — правила вне телефонного приложения.",
        ),
        (
            "Server enforces password-reset flow and prevents overlapping running records.",
            "Сервер проводит сброс пароля и не даёт пересекаться running-записям.",
        ),
        (
            "Developer and CI scripts — deploy, audits, locale sync, structure docs, desktop voice smoke tests.",
            "Скрипты разработки и CI — deploy, audit, sync локалей, генерация structure doc, smoke desktop voice.",
        ),
        (
            "Repeatable commands so builds and doc checks don’t rely on memory.",
            "Повторяемые команды, чтобы deploy и проверки не держались в голове.",
        ),
        (
            "Written project law — architecture, data fields, design system, roadmap, deploy steps.",
            "Письменные правила проекта — архитектура, поля данных, design system, roadmap, deploy.",
        ),
        (
            "Owner and AI assistants need one place for “how the app must behave” beyond code.",
            "Owner и AI нужен один источник «как приложение должно себя вести» помимо кода.",
        ),
        (
            "Automated tests run by `flutter test` — guards regressions without manual tapping.",
            "Автотесты `flutter test` — ловят регрессии без ручного тапания по UI.",
        ),
        (
            "Catches broken voice parse, timezone, plan cards, perf contracts before release.",
            "Ловит поломки voice parse, timezone, карточек планов и perf-контрактов до релиза.",
        ),
        (
            "The Flutter application itself — screens, navigation, cards, buttons, data brain, PocketBase sync, offline queue, localization, shared UI.",
            "Само Flutter-приложение — экраны, навигация, карточки, кнопки, мозг данных, PocketBase sync, offline queue, локализация и общий UI.",
        ),
        (
            "Everything users see and everything that saves data lives here; without `lib/` there is no app.",
            "Всё, что пользователь видит и что сохраняет данные, живёт здесь; без `lib/` приложения нет.",
        ),
        (
            "Cursor IDE project rules — points AI assistants to governing docs and architecture laws.",
            "Правила Cursor для AI — указывают на governing docs и архитектурные законы проекта.",
        ),
        (
            "Cursor reads `.cursorrules` or rules here so codegen follows PocketBase/optimistic UI laws.",
            "Cursor читает `.cursorrules` и файлы здесь, чтобы codegen следовал законам PocketBase и optimistic UI.",
        ),
        (
            "Flutter integration/end-to-end tests on a device or emulator — slower than unit/widget tests.",
            "Integration-тесты Flutter на устройстве/эмуляторе — медленнее unit/widget тестов.",
        ),
        (
            "Guards full app flows (login shell, tab navigation) that widget tests alone miss.",
            "Проверяет полные сценарии (login shell, навигация вкладок), которые widget-тесты не покрывают.",
        ),
        ("No — ", "Нет — "),
        ("Maybe — ", "Возможно — "),
        ("required for app runtime", "нужен для работы приложения"),
        ("required for tests", "нужен для тестов"),
        ("required for Android build", "нужен для сборки Android"),
        ("required for iOS build", "нужен для сборки iOS"),
        ("required for web build", "нужен для web-сборки"),
        ("not shipped to users", "не попадает к пользователю"),
        ("not app runtime", "не runtime приложения"),
        ("PocketBase", "PocketBase"),
    )
    out = en.strip()
    for en_frag, ru_frag in repl:
        if en_frag in out:
            out = out.replace(en_frag, ru_frag)
    return out


def adapt_folder_field_ru(key: str, field: str, en_val: str) -> str:
    k = key.replace("\\", "/").strip("/")
    curated = EXACT_FOLDER_RU.get(k, {})
    ru_key = f"{field}_ru"
    if curated.get(ru_key) and not has_banned_filler(curated[ru_key]):
        return sanitize_ru_prose(curated[ru_key])
    if field == "delete":
        return delete_en_to_ru(en_val)
    if field == "related":
        return en_val
    class_ru = folder_class_field(k, field, en_val)
    if class_ru and ru_field_ok(class_ru, min_cyrillic=6):
        return class_ru
    adapted = sanitize_ru_prose(_phrase_translate(en_val))
    if ru_field_ok(adapted, min_cyrillic=6):
        return adapted
    return f"NEEDS HUMAN DESCRIPTION ({k}/{field})"


def adapt_folder_guide_ru(key: str, en: dict[str, str]) -> dict[str, str]:
    out: dict[str, str] = {}
    for field in FIELD_KEYS:
        en_v = en.get(field, "")
        if not en_v:
            continue
        out[f"{field}_ru"] = adapt_folder_field_ru(key, field, en_v)
    return out


def adapt_file_field_ru(path: str, field: str, en_val: str, en_guide: dict[str, str]) -> str:
    if field == "delete":
        return delete_en_to_ru(en_val)
    class_ru = file_class_field(path, field, en_val, en_guide)
    if class_ru and ru_field_ok(class_ru, min_cyrillic=6):
        return class_ru
    adapted = sanitize_ru_prose(_phrase_translate(en_val))
    if ru_field_ok(adapted, min_cyrillic=6) and not has_banned_filler(adapted):
        return adapted
    return f"NEEDS HUMAN DESCRIPTION ({path}/{field})"


def adapt_file_guide_ru(path: str, en: dict[str, str]) -> dict[str, str]:
    out: dict[str, str] = {}
    for field in FILE_FIELD_KEYS:
        en_v = en.get(field, "")
        if not en_v:
            continue
        out[f"{field}_ru"] = adapt_file_field_ru(path, field, en_v, en)
    return out


def validate_ru_guide(ru_fields: dict[str, str], context: str) -> list[str]:
    issues: list[str] = []
    for k, v in ru_fields.items():
        if not v:
            issues.append(f"Missing {k} for {context}")
            continue
        if v.startswith("NEEDS HUMAN"):
            issues.append(f"No RU for {context}: {k}")
        for bad in BANNED_MEANINGLESS_RU_FILLER:
            if bad in v:
                issues.append(f"Banned filler '{bad}' in {context} {k}: {v[:80]}")
    return issues
