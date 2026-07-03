"""Curated meaningful RU for top-level and lib folders — registered at import."""

from __future__ import annotations

from structure_en_ru_adapt import register_folder_ru

register_folder_ru(
    ".cursor",
    {
        "what_ru": "Правила Cursor IDE для этого repo — куда смотреть AI-ассистентам и какие архитектурные законы соблюдать.",
        "why_ru": "Cursor подхватывает `.cursorrules` и файлы здесь, чтобы не предлагать запрещённые PocketBase/optimistic UI ходы.",
        "inside_ru": "Файлы правил Cursor, включая `rules/flutter_expert.mdc`.",
        "affects_ru": "Подсказки AI в Cursor — не runtime приложения.",
        "when_ru": "AI предлагает refactor, ломающий Brain/UI split или main-thread law.",
        "delete_ru": "Нет — Cursor root discovery ожидает rules здесь.",
        "related_ru": "`.cursorrules`, `docs/ARCHITECTURE.md`.",
    },
)

register_folder_ru(
    ".cursor/rules",
    {
        "what_ru": "Markdown-правила для Cursor Agent: Flutter-архитектура, PocketBase, optimistic UI и запрет spam polling.",
        "why_ru": "Always-applied rules для codegen в Cursor; дополняют governing docs.",
        "inside_ru": "`flutter_expert.mdc` и другие rule-файлы.",
        "affects_ru": "Качество AI-патчей — не APK пользователю.",
        "when_ru": "Обновили архитектурный закон и нужно, чтобы AI его видел сразу.",
        "delete_ru": "Нет — основной rule pack Cursor.",
        "related_ru": "`.cursorrules`, `docs/ARCHITECTURE.md`.",
    },
)

register_folder_ru(
    ".github/workflows",
    {
        "what_ru": "YAML workflow GitHub Actions — автоматическая сборка web и Windows installer после push.",
        "why_ru": "Без них deploy на GitHub Pages и артеfact `CounterSetup.exe` не собираются на сервере GitHub.",
        "inside_ru": "YAML workflows: `deploy.yml` (GitHub Pages) и `windows-desktop-build.yml` (installer).",
        "affects_ru": "Живой сайт `/Counter/` и Windows installer artifact в Actions.",
        "when_ru": "Deploy упал, сайт не обновился, нет exe в Actions artifacts.",
        "delete_ru": "Нет — если нужны GitHub Pages и Windows installer.",
        "related_ru": "`update.ps1`, `docs/DEPLOY.md`.",
    },
)

register_folder_ru(
    "docs/reports",
    {
        "what_ru": "Отчёты аудита, cleanup и design inventory — история решений, не governing law.",
        "why_ru": "Фиксируют findings April 2026 audit, parity checks, design system inventory.",
        "inside_ru": "Отчёты audit/cleanup: `AUDIT_NOTES.md`, `FINAL_*`, `DESIGN_SYSTEM_INVENTORY.md` и др.",
        "affects_ru": "Контекст для owner/AI — не runtime.",
        "when_ru": "Нужно понять, почему roadmap/guard rule существует.",
        "delete_ru": "Нет — история cleanup и audit.",
        "related_ru": "`docs/ROADMAP.md`, `CHANGELOG.md`.",
    },
)

register_folder_ru(
    "docs/website",
    {
        "what_ru": "Маркетинговые тексты будущего/текущего сайта — repo-only, не Project Knowledge pack.",
        "why_ru": "Owner правит landing copy отдельно от governing 14-doc pack.",
        "inside_ru": "Markdown страниц сайта и internal notes (repo-only).",
        "affects_ru": "Планирование публичного сайта — не Flutter binary.",
        "when_ru": "Обновление marketing copy или internal site notes.",
        "delete_ru": "Нет — repo-only marketing copy.",
        "related_ru": "`docs/DEPLOY.md`, GitHub Pages.",
    },
)

register_folder_ru(
    "integration_test",
    {
        "what_ru": "Integration-тесты Flutter на устройстве/эмуляторе — полные сценарии медленнее widget tests.",
        "why_ru": "Ловят login shell, tab navigation и flows, которые unit-тесты не покрывают.",
        "inside_ru": "Dart integration test drivers и сценарии.",
        "affects_ru": "CI/integration QA — не APK пользователю.",
        "when_ru": "Падает integration test или меняется shell navigation.",
        "delete_ru": "Нет — если integration QA остаётся в pipeline.",
        "related_ru": "`test/`, `lib/shell/`.",
    },
)

register_folder_ru(
    "scripts/audit",
    {
        "what_ru": "Audit-скрипты — architecture guard и проверки структуры перед merge.",
        "why_ru": "Блокируют forbidden imports, missing docs, drift от `APP_STRUCTURE.md`.",
        "inside_ru": "`architecture_guard.ps1` и связанные audit helpers.",
        "affects_ru": "Качество repo — не экраны приложения.",
        "when_ru": "Перед merge или после перемещения файлов — `-Strict` guard.",
        "delete_ru": "Нет — задокументированный audit workflow.",
        "related_ru": "`docs/APP_STRUCTURE.md`, `docs/ARCHITECTURE.md`.",
    },
)

register_folder_ru(
    "scripts/manual",
    {
        "what_ru": "Ручные dev-скрипты — deploy (`td.ps1`), генерация structure doc, locale sync, smoke tests.",
        "why_ru": "Owner запускает их по `DEPLOY.md` и structure maintenance без запоминания длинных команд.",
        "inside_ru": "`generate_app_structure_detailed.py`, `td.ps1`, export/billing utilities.",
        "affects_ru": "Deploy, регенерация docs и owner utilities — не runtime UI.",
        "when_ru": "Deploy сайта, regenerate APP_STRUCTURE_DETAILED, sync locales.",
        "delete_ru": "Нет — задокументированные manual workflows.",
        "related_ru": "`update.ps1`, `docs/DEPLOY.md`.",
    },
)

register_folder_ru(
    "web/icons",
    {
        "what_ru": "PNG-иконки PWA/web — разные размеры для вкладки браузера и «Add to Home Screen».",
        "why_ru": "Браузер и manifest ссылаются на эти PNG после `flutter build web`.",
        "inside_ru": "Набор `Icon-*.png` для web manifest.",
        "affects_ru": "Иконка web-версии на GitHub Pages.",
        "when_ru": "Пропала иконка вкладки после web deploy.",
        "delete_ru": "Нет — нужен для web-сборки.",
        "related_ru": "`web/manifest.json`, `web/index.html`.",
    },
)

register_folder_ru(
    "lib/data",
    {
        "what_ru": "«Мозг» приложения — PocketBase I/O, локальный кэш, optimistic UI и offline outboxes.",
        "why_ru": "Один набор правил save/load для Timeline, Plans, Lists и Categories; offline-safe.",
        "inside_ru": "Координаторы `*_service.dart`, `database_service.dart` и `part`-модули в subfolders.",
        "affects_ru": "Записи Timeline, планы, списки, категории, теги, настройки профиля и offline queue.",
        "when_ru": "Неверные данные, failed save, rollback optimistic UI, offline banner, ошибки полей PB.",
        "delete_ru": "Нет — UI не работает без мозга.",
        "related_ru": "`docs/DATA_MAP.md`, `docs/POCKETBASE_MANIFEST.md`, `lib/features/`.",
    },
)

register_folder_ru(
    "lib/core",
    {
        "what_ru": "Базовый слой: design system в коде, shared widgets, тема/цвета, time helpers, desktop voice, diagnostics.",
        "why_ru": "Экраны не дублируют кнопки, date header и voice — общая foundation-база.",
        "inside_ru": "`theme.dart`, каталог `core/widgets/`, `core/time/`, `core/services/` (desktop voice), diagnostics.",
        "affects_ru": "Внешний вид всех вкладок; desktop voice/tray; часы/timezone в header; perf debug flags.",
        "when_ru": "Миграция кнопок/карточек, неверный timezone header, сломан desktop voice, смена theme token.",
        "delete_ru": "Нет — features импортируют foundation повсюду.",
        "related_ru": "`docs/DESIGN_SYSTEM.md`, `lib/features/`, `lib/data/models.dart`.",
    },
)

register_folder_ru(
    "lib/features",
    {
        "what_ru": "Видимые экраны — Timeline, Plans, Lists, Profile, Categories, auth, Wear, shared edit sheets.",
        "why_ru": "Отделяет UI от PocketBase-мозга в `lib/data/`.",
        "inside_ru": "Папка на tab/flow: `timeline/`, `planning/`, `lists/`, `shared/`, `profile/` и др.",
        "affects_ru": "Вся видимая часть приложения кроме platform wrappers.",
        "when_ru": "UI bug на вкладке, новый экран, edit sheet, voice sheet layout.",
        "delete_ru": "Нет — удаление убирает весь UI продукта.",
        "related_ru": "`lib/shell/`, `lib/data/`.",
    },
)

register_folder_ru(
    "lib/shell",
    {
        "what_ru": "Оболочка — нижние вкладки, desktop side nav, More menu, voice routing, edit modals, offline banner.",
        "why_ru": "Связывает `main.dart` с feature pages и глобальным поведением (voice, sync banner).",
        "inside_ru": "Dashboard scaffold, IndexedStack вкладок, More menu, voice submit routing.",
        "affects_ru": "Навигация, global header, voice commands между вкладками.",
        "when_ru": "Неверная вкладка, voice уходит не туда, edit sheet host, offline banner.",
        "delete_ru": "Нет — навигация приложения рушится.",
        "related_ru": "`lib/app_shell.dart`, все `lib/features/*`.",
    },
)

register_folder_ru(
    "lib/l10n",
    {
        "what_ru": "Словарь переводов — подписи кнопок, ошибки, пункты меню на всех языках.",
        "why_ru": "Смена языка в settings; весь текст через `t()` и locale maps.",
        "inside_ru": "`dictionary.dart`, `langs/en.dart`, `langs/ru.dart`, partial other locales.",
        "affects_ru": "Все видимые строки UI.",
        "when_ru": "Missing translation key, неверный текст языка, новая UI label.",
        "delete_ru": "Нет — без l10n сырые keys или crash.",
        "related_ru": "`scripts/sync_locales.dart`, HELP в `langs/`.",
    },
)

register_folder_ru(
    "lib/services",
    {
        "what_ru": "Сервисы устройства вне PocketBase — сейчас plan alarm notifications.",
        "why_ru": "OS notifications вне brain; `lib/data/` без platform notification API.",
        "inside_ru": "`notification_service.dart` — local notifications и plan alarm reschedule.",
        "affects_ru": "Напоминания по планам на phone/desktop.",
        "when_ru": "Plan alarm не срабатывает, permission notifications.",
        "delete_ru": "Нет — plan alarms перестанут работать.",
        "related_ru": "`lib/data/plan_service.dart` alarm reschedule.",
    },
)

register_folder_ru(
    "android",
    {
        "what_ru": "Android-обёртка — Gradle, `AndroidManifest`, permissions (mic, notifications), launcher icons, Kotlin entry.",
        "why_ru": "Flutter собирает устанавливаемый APK/AAB из native Android project.",
        "inside_ru": "Gradle, manifest, Kotlin entry, иконки и splash в `res/`.",
        "affects_ru": "Сборка и установка только на Android (телефон, планшет, Wear).",
        "when_ru": "APK build fail, permission denied, package name, Gradle errors.",
        "delete_ru": "Нет — если нужна поддержка Android APK.",
        "related_ru": "`android.ps1`, `.github/workflows/`.",
    },
)

register_folder_ru(
    "ios",
    {
        "what_ru": "iOS-обёртка — Xcode project, Info.plist, assets, Flutter iOS embedder для iPhone/iPad.",
        "why_ru": "Apple требует эту структуру для TestFlight и App Store.",
        "inside_ru": "Xcode project, Info.plist, asset catalogs, Runner target.",
        "affects_ru": "Только iOS builds.",
        "when_ru": "iOS compile/signing, permissions, icons.",
        "delete_ru": "Нет — если нужна сборка iOS.",
        "related_ru": "`lib/`, Flutter tooling.",
    },
)

register_folder_ru(
    "web",
    {
        "what_ru": "Web-оболочка — `index.html`, PWA manifest, favicon/icons; base href `/Counter/` для GitHub Pages.",
        "why_ru": "Браузер грузит Flutter web build; GitHub Pages живёт под `/Counter/`.",
        "inside_ru": "Точка входа браузера, favicon, каталог `icons/`, `manifest.json`.",
        "affects_ru": "Публичный web-сайт: https://nkuchenov-hash.github.io/Counter/",
        "when_ru": "Blank page после deploy, wrong base href, missing icons.",
        "delete_ru": "Нет — web deploy ломается.",
        "related_ru": "`docs/DEPLOY.md`, `.github/workflows/deploy.yml`.",
    },
)

register_folder_ru(
    "windows",
    {
        "what_ru": "Windows desktop runner — native `.exe`, Flutter engine, desktop voice/tray/hotkey; связь с installer.",
        "why_ru": "Desktop voice и `CounterSetup.exe` упаковка нуждаются в Windows embedder.",
        "inside_ru": "CMake-проект, runner main, plugin registration, иконка `.ico`.",
        "affects_ru": "Windows desktop app и содержимое installer.",
        "when_ru": "Windows build fail, desktop voice/tray на уровне OS.",
        "delete_ru": "Нет — если поддерживается Windows desktop.",
        "related_ru": "`installer/windows/`, `docs/DEPLOY.md`.",
    },
)

register_folder_ru(
    "docs",
    {
        "what_ru": "Письменные правила проекта — architecture, DATA_MAP, design system, roadmap, deploy.",
        "why_ru": "Owner и AI нужен источник «как должно работать» помимо кода.",
        "inside_ru": "Governing specs, Project Knowledge pack list, reports, `docs/website/` copy.",
        "affects_ru": "Решения при разработке и AI context — не runtime binary.",
        "when_ru": "Любой structural/behavior вопрос; upload list в `PROJECT_KNOWLEDGE_PACK.md`.",
        "delete_ru": "Нет — governing documentation.",
        "related_ru": "14-doc Project Knowledge pack, `CHANGELOG.md`.",
    },
)

register_folder_ru(
    "scripts",
    {
        "what_ru": "Скрипты dev/CI — deploy, audit guard, sync локалей, генерация structure doc, smoke desktop voice.",
        "why_ru": "Повторяемые команды вместо ad-hoc notes.",
        "inside_ru": "Папки скриптов: `audit/`, `manual/`, плюс `sync_locales.dart`.",
        "affects_ru": "Deploy, architecture guard и regeneration structure doc — не UI приложения.",
        "when_ru": "Deploy сайта, strict guard, regenerate structure map, voice smoke Windows.",
        "delete_ru": "Нет — deploy/audit/doc workflows в repo.",
        "related_ru": "`update.ps1`, `docs/DEPLOY.md`, `docs/APP_STRUCTURE.md` §6.",
    },
)

register_folder_ru(
    "test",
    {
        "what_ru": "Автотесты `flutter test` — регрессии без ручного UI.",
        "why_ru": "Ловят voice parse, timezone, plan cards, perf contracts до релиза.",
        "inside_ru": "Widget-, domain- и perf-тесты — файлы `*_test.dart` ниже.",
        "affects_ru": "CI quality gate — не в APK пользователю.",
        "when_ru": "Добавление/изменение поведения; падение CI.",
        "delete_ru": "Нет — нужен для тестов.",
        "related_ru": "Production files под `lib/` с похожими именами.",
    },
)

register_folder_ru(
    "pb_hooks",
    {
        "what_ru": "JS hooks для PocketBase на VPS — правила сервера, не код в телефоне.",
        "why_ru": "Сервер проводит password reset и sanitize overlapping records.",
        "inside_ru": "Два hook-файла (auth reset, record interval sanitize).",
        "affects_ru": "Forgot-password email на сервере; server-side cleanup пересекающихся running records.",
        "when_ru": "Password reset fail server-side; duplicate running records на сервере.",
        "delete_ru": "Нет — production PocketBase ожидает hooks по manifest.",
        "related_ru": "`docs/POCKETBASE_MANIFEST.md`, `docs/DEPLOY.md` auth admin.",
    },
)

register_folder_ru(
    "installer",
    {
        "what_ru": "Сборка Windows-установщика `CounterSetup.exe` — упаковка Release build + STT helper + icons.",
        "why_ru": "Flutter build — папка файлов; installer даёт один setup wizard пользователю.",
        "inside_ru": "Inno Setup `counter.iss`, STT payload scripts, helper build.",
        "affects_ru": "Дистрибуция Windows через artifact GitHub Actions.",
        "when_ru": "Installer missing files, STT helper не bundled, SmartScreen packaging.",
        "delete_ru": "Нет — пока нужен Windows installer distribution.",
        "related_ru": "`.github/workflows/windows-desktop-build.yml`, `docs/DEPLOY.md`.",
    },
)

register_folder_ru(
    "installer/windows",
    {
        "what_ru": "Inno Setup и PowerShell для Windows setup `.exe` — копирование Release + speech helper.",
        "why_ru": "Автоматизирует упаковку `flutter build windows` + GOLOS STT в install package.",
        "inside_ru": "Inno Setup `counter.iss`, `prepare_stt_payload.ps1` и helper build scripts.",
        "affects_ru": "CI artifact `CounterSetup` и локальные installer builds.",
        "when_ru": "Installer build broken, STT missing после install.",
        "delete_ru": "Нет — нужен для Windows installer.",
        "related_ru": "`flutter build windows`, GitHub Actions workflow.",
    },
)

register_folder_ru(
    "installer/windows/scripts",
    {
        "what_ru": "Вспомогательные PowerShell-скрипты установщика — захват WAV для речи Windows.",
        "why_ru": "Windows speech и installer prep копируют эти scripts рядом с setup `.exe`.",
        "inside_ru": "`win_speech_wav.ps1` и related helpers.",
        "affects_ru": "Поведение speech helper после установки на Windows.",
        "when_ru": "Installer missing speech script, WAV path broken.",
        "delete_ru": "Нет — Windows installer packaging ожидает scripts.",
        "related_ru": "`prepare_stt_payload.ps1`, `counter.iss`.",
    },
)

register_folder_ru(
    "linux",
    {
        "what_ru": "Linux desktop embedder — CMake-проект для сборки Counter на Linux через GTK runner.",
        "why_ru": "Flutter нужны native runner sources для Linux desktop target.",
        "inside_ru": "Корневой `CMakeLists.txt`, generated glue в `flutter/`, GTK entry в `runner/`.",
        "affects_ru": "Только Linux desktop builds — не Android/iOS/web.",
        "when_ru": "Падает Linux desktop compile, ошибки GTK runner.",
        "delete_ru": "Нет — если нужна поддержка Linux desktop.",
        "related_ru": "`windows/`, `macos/` — sibling desktop folders.",
    },
)

register_folder_ru(
    "macos",
    {
        "what_ru": "macOS desktop Flutter/Xcode project — собирает Counter `.app` на Apple Silicon/Intel Mac.",
        "why_ru": "Apple desktop builds нуждаются в Xcode target, entitlements и Flutter macOS embedder.",
        "inside_ru": "`Runner/`, generated configs в `Flutter/`, `Runner.xcodeproj`.",
        "affects_ru": "Только сборка и распространение macOS desktop `.app`.",
        "when_ru": "macOS signing, sandbox entitlements, menu bar, ошибки desktop build.",
        "delete_ru": "Нет — если нужна поддержка macOS desktop.",
        "related_ru": "`ios/` (mobile Apple) vs этот desktop target.",
    },
)

register_folder_ru(
    "installer/windows/stt_helper_build",
    {
        "what_ru": "Собранный `counter_stt_helper.exe` для bundling в installer.",
        "why_ru": "Desktop voice на Windows использует GOLOS STT subprocess; installer должен ship exe.",
        "inside_ru": "Pre-built или CI-built `counter_stt_helper.exe`.",
        "affects_ru": "Расшифровка desktop voice на Windows после установки.",
        "when_ru": "Voice в dev OK, но не в installed app; rebuild STT helper.",
        "delete_ru": "Нет — без exe STT bundle неполный.",
        "related_ru": "`build_stt_helper_en.ps1`, `desktop_stt_helper_service.dart`.",
    },
)
