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
        "what_ru": "iOS-обёртка — Xcode-проект, Info.plist, assets, Flutter iOS embedder для iPhone/iPad.",
        "why_ru": "Apple требует эту структуру для TestFlight и App Store.",
        "inside_ru": "Xcode-проект, Info.plist, asset catalogs, Runner target.",
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
        "what_ru": "macOS desktop Flutter/Xcode-проект — собирает Counter `.app` на Apple Silicon/Intel Mac.",
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

register_folder_ru(
    "android/app",
    {
        "what_ru": "Модуль Android-приложения Counter — из него Gradle собирает APK/AAB.",
        "why_ru": "Отделяет настройки приложения от корневого Gradle-проекта `android/`.",
        "inside_ru": "`build.gradle`, каталог `src/`, при необходимости `google-services.json`.",
        "affects_ru": "Результат сборки — APK или AAB Counter для установки.",
        "when_ru": "Ошибки Gradle-модуля app, package name, подпись release.",
        "delete_ru": "Нет — без app module нет Android APK.",
        "related_ru": "`android/build.gradle.kts`, `android/settings.gradle.kts`.",
    },
)

register_folder_ru(
    "android/gradle",
    {
        "what_ru": "Gradle wrapper и каталог версий плагинов для Android-сборки.",
        "why_ru": "Фиксирует версию Gradle, чтобы сборка на CI и локально была одинаковой.",
        "inside_ru": "Wrapper jar/properties и версии Gradle-плагинов.",
        "affects_ru": "Только toolchain Android-сборки — не Dart UI.",
        "when_ru": "Ошибки несовпадения версии Gradle.",
        "delete_ru": "Нет — без wrapper Gradle sync нестабилен.",
        "related_ru": "`android/settings.gradle.kts`.",
    },
)

register_folder_ru(
    "ios/Flutter",
    {
        "what_ru": "Сгенерированные Flutter-файлы embedder для iOS (xcconfig, pod helpers).",
        "why_ru": "Flutter tool записывает pod helpers и xcconfig сюда при `flutter build ios`.",
        "inside_ru": "Generated xcconfig и настройки CocoaPods.",
        "affects_ru": "Интеграция Flutter engine с Xcode-проектом iOS.",
        "when_ru": "Падение `pod install` или `flutter build ios`.",
        "delete_ru": "Нет — перегенерируется Flutter tool.",
        "related_ru": "`ios/Podfile`, `ios/Runner/`.",
    },
)

register_folder_ru(
    "ios/Runner",
    {
        "what_ru": "iOS target Runner — иконки, launch screen, Info.plist и native glue для Flutter.",
        "why_ru": "Xcode собирает iOS-приложение Counter из этого target.",
        "inside_ru": "Asset catalogs, launch screen, Swift/ObjC glue для Flutter.",
        "affects_ru": "Сборки для TestFlight и App Store.",
        "when_ru": "Permissions iOS, иконки, launch screen.",
        "delete_ru": "Нет — без Runner target нет iOS app.",
        "related_ru": "`ios/Flutter/`, `ios/Runner.xcodeproj`.",
    },
)

register_folder_ru(
    "ios/Runner.xcodeproj",
    {
        "what_ru": "Xcode-проект для iOS target Counter — compile, sign и archive IPA.",
        "why_ru": "Xcode открывает этот project для сборки и подписи iOS-приложения.",
        "inside_ru": "Файлы `project.pbxproj`, shared schemes, workspace metadata.",
        "affects_ru": "Только iOS TestFlight и App Store builds.",
        "when_ru": "Повреждение project, смена scheme, настройки signing.",
        "delete_ru": "Нет — без project Xcode не соберёт iOS.",
        "related_ru": "`ios/Runner/`, `ios/Runner.xcworkspace`.",
    },
)

register_folder_ru(
    "ios/Runner.xcworkspace",
    {
        "what_ru": "Xcode workspace для Runner и CocoaPods — открывают после `pod install`.",
        "why_ru": "Pods интегрируются через workspace, а не через один `.xcodeproj`.",
        "inside_ru": "Workspace data, связывающая Runner и Pods.",
        "affects_ru": "Локальная iOS-разработка и CI с CocoaPods.",
        "when_ru": "Xcode просит open workspace; сломана интеграция Pods.",
        "delete_ru": "Нет — стандартный CocoaPods workflow.",
        "related_ru": "`ios/Podfile`, `ios/Runner.xcodeproj`.",
    },
)

register_folder_ru(
    "linux/flutter",
    {
        "what_ru": "Сгенерированный Flutter glue для Linux embedder — registrant plugins и CMake hooks.",
        "why_ru": "Flutter tool перегенерирует при смене plugins в `pubspec.yaml`.",
        "inside_ru": "`generated_plugin_registrant.*`, `generated_plugins.cmake`, child `CMakeLists.txt`.",
        "affects_ru": "Регистрация Flutter plugins на Linux desktop в runtime.",
        "when_ru": "Linux build падает после добавления/удаления Flutter plugin.",
        "delete_ru": "Нет — перегенерируется Flutter tool.",
        "related_ru": "`linux/CMakeLists.txt`, `linux/runner/`.",
    },
)

register_folder_ru(
    "linux/runner",
    {
        "what_ru": "Native GTK host — запускает Flutter desktop окно на Linux.",
        "why_ru": "Linux desktop build нуждается в GTK runner entry point.",
        "inside_ru": "Исходники CMake runner (GTK).",
        "affects_ru": "Только Linux desktop builds.",
        "when_ru": "Ошибки compile Linux desktop.",
        "delete_ru": "Нет — если нужна поддержка Linux desktop.",
        "related_ru": "`linux/flutter/`, `linux/CMakeLists.txt`.",
    },
)

register_folder_ru(
    "macos/Flutter",
    {
        "what_ru": "Сгенерированная конфигурация Flutter embedder для macOS.",
        "why_ru": "Flutter записывает pod/xcconfig glue для macOS-сборки.",
        "inside_ru": "Generated xcconfig и pod-настройки.",
        "affects_ru": "Интеграция Flutter с Xcode macOS target.",
        "when_ru": "Ошибки `flutter build macos`.",
        "delete_ru": "Нет — перегенерируется Flutter tool.",
        "related_ru": "`macos/Runner/`, `macos/Podfile`.",
    },
)

register_folder_ru(
    "macos/Runner",
    {
        "what_ru": "macOS target Runner — меню, иконки, entitlements для `.app` bundle.",
        "why_ru": "Apple требует Xcode target для macOS Flutter-приложения.",
        "inside_ru": "Swift runner, assets, entitlements plist.",
        "affects_ru": "Сборка Counter `.app` на macOS desktop.",
        "when_ru": "Подпись macOS, sandbox, menu bar.",
        "delete_ru": "Нет — если нужна поддержка macOS desktop.",
        "related_ru": "`macos/Flutter/`, `macos/Runner.xcodeproj`.",
    },
)

register_folder_ru(
    "windows/flutter",
    {
        "what_ru": "Сгенерированный Flutter glue для Windows embedder — registrant plugins и CMake hooks.",
        "why_ru": "Native Windows plugins (tray, hotkey, voice overlay) регистрируются через этот code.",
        "inside_ru": "`generated_plugin_registrant.*`, `generated_plugins.cmake`.",
        "affects_ru": "Регистрация plugins на Windows desktop — от неё зависят voice/tray.",
        "when_ru": "Windows build падает после смены plugin; пропал desktop voice plugin.",
        "delete_ru": "Нет — перегенерируется Flutter tool.",
        "related_ru": "`windows/runner/`, `windows/CMakeLists.txt`.",
    },
)

register_folder_ru(
    "windows/runner",
    {
        "what_ru": "Native C++ host Windows — поднимает окно Flutter desktop.",
        "why_ru": "Windows нужен C++ runner `.exe`, встраивающий Flutter engine.",
        "inside_ru": "`main.cpp`, создание окна, plugin registrant.",
        "affects_ru": "Содержимое Counter `.exe` и Windows installer.",
        "when_ru": "Desktop `.exe` не стартует или неверный заголовок окна.",
        "delete_ru": "Нет — если нужна поддержка Windows desktop.",
        "related_ru": "`installer/windows/`, `windows/flutter/`.",
    },
)

register_folder_ru(
    "lib/core/diagnostics",
    {
        "what_ru": "Debug-only логирование — startup, voice pipeline, duplicates.",
        "why_ru": "Структурированные логи для perf и desktop voice без spam в release.",
        "inside_ru": "Небольшие log wrapper, включаемые debug/profile flags.",
        "affects_ru": "Только диагностика разработчика — не UI пользователя.",
        "when_ru": "Трассировка шагов desktop voice или startup timing.",
        "delete_ru": "Нет — используется в debug/profile builds.",
        "related_ru": "`lib/core/performance/`.",
    },
)

register_folder_ru(
    "lib/core/widgets",
    {
        "what_ru": "Переиспользуемые UI-блоки — design system в коде (`AppButton`, карточки, pickers).",
        "why_ru": "Один канонический button/card — Plans, Timeline и Lists выглядят одинаково.",
        "inside_ru": "`AppButton`, `PlanTimeTaskCard`, date header, timezone picker, chips.",
        "affects_ru": "Все главные вкладки и большинство sheets.",
        "when_ru": "Миграция стиля кнопок, layout карточек, date/time picker, loading/empty states.",
        "delete_ru": "Нет — features зависят от этих widgets.",
        "related_ru": "`docs/DESIGN_SYSTEM.md`, Component Lab.",
    },
)

register_folder_ru(
    "lib/data/plans",
    {
        "what_ru": "Срез мозга для Plans/Lists — задачи по расписанию, backlog, recurrence и теги.",
        "why_ru": "Вкладки Plans и Lists читают/пишут одну таблицу `plans` через эти модули.",
        "inside_ru": "Projection Time View, RRULE expansion, sync тегов, кэш, offline outbox.",
        "affects_ru": "Plans, Time View, Lists, edit sheets планов, plan alarms.",
        "when_ru": "Планы не сохраняются, recurrence неверна, карточки Time View не на месте.",
        "delete_ru": "Нет — сломаются Plans и Lists.",
        "related_ru": "`lib/data/plan_service.dart`, `lib/features/planning/`.",
    },
)

register_folder_ru(
    "lib/data/records",
    {
        "what_ru": "Срез мозга для Timeline — старт/стоп таймера, история, realtime, offline queue.",
        "why_ru": "Timeline — ядро трекера; папка делит record-логику на читаемые модули.",
        "inside_ru": "CRUD, optimistic UI, realtime, builders Timeline, overlap/Highlander, outbox.",
        "affects_ru": "Timeline, edit sheet записи, Wear lite timer, voice «start record».",
        "when_ru": "Таймер не стартует/стопится, неверный day bucket, дубликаты running.",
        "delete_ru": "Нет — перестанет работать учёт времени.",
        "related_ru": "`lib/data/record_service.dart`, `lib/features/timeline/`.",
    },
)

register_folder_ru(
    "lib/features/planning",
    {
        "what_ru": "UI вкладки Plans — day pager, список планов, Time View, settings, bulk edit.",
        "why_ru": "Это видит пользователь на второй нижней вкладке (Plans).",
        "inside_ru": "`planning_page.dart`, подпапки `time_view/`, `settings/`, `widgets/`.",
        "affects_ru": "Только вкладка Plans (плюс calendar rows с теми же карточками).",
        "when_ru": "Неверные карточки, drag Time View, swipe дней, play/start plan.",
        "delete_ru": "Нет — вкладка Plans исчезнет.",
        "related_ru": "`lib/shell/`, `lib/data/plan_service.dart`.",
    },
)

register_folder_ru(
    "lib/features/shared",
    {
        "what_ru": "Общие edit sheets и voice UI для Timeline, Plans и Lists.",
        "why_ru": "Единый edit для plans и records — Omni picker, tags, checklist, offline banner.",
        "inside_ru": "Router activity detail, edit sheets, helpers `edit_sheet/*`, voice widgets.",
        "affects_ru": "Редактирование plans/records по tap; mobile voice sheet; desktop voice panel.",
        "when_ru": "Save edit sheet, date picker, tags на plan, voice input sheet.",
        "delete_ru": "Нет — edit flows сломаются на всех вкладках.",
        "related_ru": "`lib/shell/shell_edit_hosts.dart`, `docs/UX_CONTRACT.md`.",
    },
)

register_folder_ru(
    "macos/Runner.xcodeproj",
    {
        "what_ru": "Xcode-проект macOS desktop target Counter `.app`.",
        "why_ru": "macOS desktop builds компилируются через этот Xcode-проект.",
        "inside_ru": "Файлы `project.pbxproj`, shared schemes для macOS Runner.",
        "affects_ru": "Сборки macOS desktop для распространения.",
        "when_ru": "Ошибки macOS Xcode build/sign.",
        "delete_ru": "Нет — без project Xcode не соберёт macOS.",
        "related_ru": "`macos/Runner/`, `macos/Flutter/`.",
    },
)

register_folder_ru(
    "macos/Runner.xcworkspace",
    {
        "what_ru": "Xcode workspace для macOS desktop-приложения Counter.",
        "why_ru": "Открывает Runner и Flutter macOS pods вместе в Xcode.",
        "inside_ru": "Содержимое workspace и shared IDE checks.",
        "affects_ru": "macOS desktop разработка в Xcode.",
        "when_ru": "Workspace не открывается; сломана CocoaPods integration на macOS.",
        "delete_ru": "Нет — стандартный CocoaPods workflow.",
        "related_ru": "`macos/Runner.xcodeproj`.",
    },
)

register_folder_ru(
    "ios/RunnerTests",
    {
        "what_ru": "Xcode unit test target для smoke-тестов iOS Runner.",
        "why_ru": "Шаблон Apple project включает test target для native/iOS integration checks.",
        "inside_ru": "`RunnerTests.swift` — минимальный XCTest entry.",
        "affects_ru": "iOS test target в Xcode — не основной Flutter `test/` suite.",
        "when_ru": "Падение native iOS-тестов в Xcode.",
        "delete_ru": "Возможно — Flutter CI использует `flutter test`; оставить для Xcode workflow.",
        "related_ru": "`test/` Flutter tests, `ios/Runner/`.",
    },
)

register_folder_ru(
    "macos/RunnerTests",
    {
        "what_ru": "Xcode unit test target для smoke-тестов macOS Runner.",
        "why_ru": "Шаблон Apple project включает test target для native macOS checks.",
        "inside_ru": "`RunnerTests.swift` — минимальный XCTest entry.",
        "affects_ru": "macOS test target в Xcode — не основной Flutter `test/` suite.",
        "when_ru": "Падение native macOS-тестов в Xcode.",
        "delete_ru": "Возможно — Flutter CI использует `flutter test`; оставить для Xcode workflow.",
        "related_ru": "`test/` Flutter tests, `macos/Runner/`.",
    },
)

register_folder_ru(
    "lib/core/env",
    {
        "what_ru": "Compile-time шаблон env — копировать в gitignored `env.dart` для локальных secrets.",
        "why_ru": "Build-time значения не коммитят; example file документирует нужную форму.",
        "inside_ru": "В git только `env.dart.example`; настоящий `env.dart` локальный.",
        "affects_ru": "Только локальные dev builds, если используются env constants.",
        "when_ru": "Настройка новой dev-машины; добавление compile-time constant.",
        "delete_ru": "Нет — документирует структуру env.dart.",
        "related_ru": "`.gitignore` entry для `lib/core/env/env.dart`.",
    },
)

register_folder_ru(
    "lib/core/navigation",
    {
        "what_ru": "Root navigator key и helpers боковой desktop-навигации.",
        "why_ru": "Desktop voice overlay и hidden main window нуждаются в global navigator; side rail заменяет bottom tabs на широких экранах.",
        "inside_ru": "Файлы `app_navigator.dart` (`appRootNavigatorKey`), `shell_side_navigation.dart`.",
        "affects_ru": "Desktop/web layout (side nav) и overlay routing над вкладками.",
        "when_ru": "Desktop overlay не может push routes; неверный breakpoint side navigation.",
        "delete_ru": "Нет — сломаются desktop layout и overlays.",
        "related_ru": "`lib/shell/shell_side_navigation.dart`, `lib/core/shell_adaptive.dart`.",
    },
)

register_folder_ru(
    "lib/core/performance",
    {
        "what_ru": "Feature flags runtime и perf metrics — полоса дат, warm window, счётчики rebuild.",
        "why_ru": "Позволяет включать дорогие features или capture frame metrics без debug code для всех users.",
        "inside_ru": "Файлы `runtime_flags.dart`, `shell_flags.dart`, `rebuild_metrics.dart` (`PERF_DIAG` gated).",
        "affects_ru": "Perf: paging дат, tab stack оболочки, diagnostic builds.",
        "when_ru": "Расследование jank, warm-window kill switch, perf capture tests.",
        "delete_ru": "Нет — perf tests и diagnostics ссылаются на эти flags.",
        "related_ru": "`test/perf_*`, `lib/data/cache/`.",
    },
)

register_folder_ru(
    "android/app/src/debug",
    {
        "what_ru": "Override Android manifest для debug variant — отдельные permissions и merge rules.",
        "why_ru": "Debug APK может включать extra logging или другой application id suffix.",
        "inside_ru": "Debug `AndroidManifest.xml`, merge только в debug builds.",
        "affects_ru": "Только debug Android installs — не release APK.",
        "when_ru": "Проблемы permissions или слияния manifest только в debug-сборке.",
        "delete_ru": "Нет — нужен для Android debug builds.",
        "related_ru": "`android/app/src/main/AndroidManifest.xml`.",
    },
)

register_folder_ru(
    "android/app/src/profile",
    {
        "what_ru": "Manifest Android profile variant — сборка для performance profiling.",
        "why_ru": "Profile mode использует отдельный manifest merge для Flutter profile builds.",
        "inside_ru": "Profile `AndroidManifest.xml`.",
        "affects_ru": "Profile APK для измерения производительности.",
        "when_ru": "Ошибки merge manifest при profile build.",
        "delete_ru": "Нет — нужен для Flutter profile Android builds.",
        "related_ru": "`android/app/src/main/`.",
    },
)

# App-specific RU for remaining lib/** folders (no generic path wrappers).
import structure_folder_ru_lib  # noqa: F401,E402
