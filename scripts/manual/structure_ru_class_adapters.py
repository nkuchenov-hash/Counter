"""Class-based RU adapters — real Russian prose, no EN wrappers."""

from __future__ import annotations

from structure_ru_helpers import cyrillic_count, delete_en_to_ru

# Semi-Russian wrappers + English leakage banned in RU sections (quality gate).
BANNED_SEMI_RUSSIAN_WRAPPERS: tuple[str, ...] = (
    "Сегмент `",
    "Назначение файла:",
    "Назначение:",
    "Нужен, потому что:",
    "Нужна, потому что:",
    "Содержит:",
    "Отвечает за:",
    "На продукт влияет так:",
    "Открывать, когда:",
    "Связан с:",
    "Здесь лежит:",
)

BANNED_ENGLISH_IN_RU: tuple[str, ...] = (
    "Required for",
    "build output",
    "Flutter-generated",
    "Android application module",
    "Xcode project",
    "Native Windows host",
    "Gradle build script",
    "Source file",
    "Documented in",
    "required for current app behavior",
    "see source file",
    "minimal Flutter embedding",
    "Android compile settings",
    "Configure Android",
    "Separates app config",
    "Gradle compiles",
    "Gradle app module",
    "Gradle version mismatch",
    "Pod install",
    "wrong splash color",
    "Crash on launch",
    "deep link handling",
    "Flutter attaches to Android",
    "boots the Flutter engine",
    "App Store / TestFlight",
    "wrong app label",
    "manifest merge",
)

# Generic RU wrappers introduced by fallback adapters — must never ship.
BANNED_GENERIC_RU_WRAPPERS: tuple[str, ...] = (
    "Подмодуль `",
    " в Flutter-приложении Counter.",
    "Код под `lib/",
    " нужен для работы описанной в EN зоны ответственности.",
    "Dart-файлы и подпапки ",
    " — список ниже.",
    "Поведение части приложения, связанной с ",
    "Баг или доработка в `",
    "Файл `",
    " в каталоге `",
    "Поддерживает documented workflow каталога ",
    "Исходное содержимое `",
    "Зона ответственности `",
    "Build или maintenance ссылается на `",
    "См. также:",
    "Native/config файлы для `",
)

GENERIC_EN_MARKERS: tuple[str, ...] = (
    "Fulfill the documented role",
    "required for current app behavior",
    "documented workflow",
    "see source file",
    "Source file `",
    "Dart source `",
    "for the Life OS repository",
    "Role:",
)


def _is_generic_en(text: str) -> bool:
    if not text:
        return False
    return any(m in text for m in GENERIC_EN_MARKERS)

# Exact EN field text → RU (from FOLDER_INFERENCE + synthesize).
EXACT_EN_FIELD_RU: dict[str, str] = {
    "Android application module — the actual Counter APK target.": (
        "Модуль Android-приложения Counter — из него Gradle собирает APK/AAB."
    ),
    "Separates app config from root Gradle project settings.": (
        "Отделяет настройки приложения от корневого Gradle-проекта `android/`."
    ),
    "build.gradle, src/, google-services if present.": (
        "`build.gradle`, каталог `src/`, при необходимости `google-services.json`."
    ),
    "Android build output APK/AAB.": "Результат сборки — APK или AAB Counter для установки.",
    "Gradle app module errors, package name, signing.": (
        "Ошибки Gradle-модуля app, package name, подпись release."
    ),
    "Gradle wrapper and version catalog for Android builds.": (
        "Gradle wrapper и каталог версий плагинов для Android-сборки."
    ),
    "Pins Gradle version so builds are reproducible on CI and your PC.": (
        "Фиксирует версию Gradle, чтобы сборка на CI и локально была одинаковой."
    ),
    "Wrapper jar/properties, plugin versions.": "Wrapper jar/properties и версии Gradle-плагинов.",
    "Android build toolchain only.": "Только toolchain Android-сборки — не Dart UI.",
    "Gradle version mismatch errors.": "Ошибки несовпадения версии Gradle.",
    "Generated Flutter iOS embedding files.": (
        "Сгенерированные Flutter-файлы embedder для iOS (xcconfig, pod helpers)."
    ),
    "Flutter tool writes pod helpers and xcconfig here on build.": (
        "Flutter tool записывает pod helpers и xcconfig сюда при `flutter build ios`."
    ),
    "Generated xcconfig, pod setup.": "Generated xcconfig и настройки CocoaPods.",
    "iOS Flutter integration.": "Интеграция Flutter engine с Xcode-проектом iOS.",
    "Pod install / Flutter iOS build failures.": "Падение `pod install` или `flutter build ios`.",
    "iOS app target — icons, storyboards, Info.plist for iPhone/iPad.": (
        "iOS target Runner — иконки, launch screen, Info.plist для iPhone/iPad."
    ),
    "Xcode builds the Flutter iOS app from this target.": (
        "Xcode собирает iOS-приложение Counter из этого target: иконки, launch screen, Info.plist и native glue."
    ),
    "Assets, launch screen, native Swift/ObjC glue.": (
        "Asset catalogs, launch screen, Swift/ObjC glue для Flutter."
    ),
    "iOS App Store / TestFlight builds.": "Сборки для TestFlight и App Store.",
    "iOS permissions, icons, launch screen.": "Permissions iOS, иконки, launch screen.",
    "Shared Xcode IDE/scheme metadata for `{parent or k}`.": (
        "Общие scheme/metadata Xcode для сборки Runner."
    ),
    "Xcode stores workspace checks and build schemes here for team consistency.": (
        "Xcode хранит scheme и workspace checks для единообразной сборки."
    ),
    "Plist scheme files, IDE workspace checks.": "Plist scheme-файлы и workspace checks IDE.",
    "Which Xcode scheme builds Runner — developer workflow only.": (
        "Какой Xcode scheme собирает Runner — только workflow разработчика."
    ),
    "Xcode scheme missing or workspace check warnings.": (
        "Пропал scheme в Xcode или предупреждения workspace checks."
    ),
    "Generated Flutter macOS embedding configuration.": (
        "Сгенерированная конфигурация Flutter embedder для macOS."
    ),
    "Flutter writes pod/xcconfig glue for macOS builds.": (
        "Flutter записывает pod/xcconfig glue для macOS-сборки."
    ),
    "Generated configs.": "Generated xcconfig и pod-настройки.",
    "macOS Flutter integration.": "Интеграция Flutter с Xcode macOS target.",
    "macOS Flutter build failures.": "Ошибки `flutter build macos`.",
    "macOS app bundle target — menus, icons, entitlements.": (
        "macOS target Runner — меню, иконки, entitlements для `.app` bundle."
    ),
    "Apple requires Xcode target for macOS Flutter apps.": (
        "Apple требует Xcode target для macOS Flutter-приложения."
    ),
    "Swift runner, assets, entitlements plist.": "Swift runner, assets, entitlements plist.",
    "macOS desktop builds.": "Сборка Counter `.app` на macOS desktop.",
    "macOS signing, sandbox, menu bar.": "Подпись macOS, sandbox, menu bar.",
    "Native Linux host for Flutter desktop on Linux.": (
        "Native GTK host — запускает Flutter desktop окно на Linux."
    ),
    "Linux desktop build needs GTK runner entry point.": (
        "Linux desktop build нуждается в GTK runner entry point."
    ),
    "CMake runner sources.": "Исходники CMake runner (GTK).",
    "Linux desktop builds only.": "Только Linux desktop builds.",
    "Linux desktop compile errors.": "Ошибки compile Linux desktop.",
    "Native Windows host that launches the Flutter desktop window.": (
        "Native C++ host Windows — поднимает окно Flutter desktop."
    ),
    "Windows needs a C++ runner exe that embeds Flutter engine.": (
        "Windows нужен C++ runner `.exe`, встраивающий Flutter engine."
    ),
    "main.cpp, window creation, plugin registrant.": "`main.cpp`, создание окна, plugin registrant.",
    "Windows desktop `.exe` and installer contents.": "Содержимое Counter `.exe` и Windows installer.",
    "Windows desktop won’t start, window title wrong.": (
        "Desktop `.exe` не стартует или неверный заголовок окна."
    ),
    "Kotlin entry point where Flutter attaches to Android.": (
        "Kotlin-точка входа — Flutter engine подключается к Android Activity."
    ),
    "Android OS launches `MainActivity` which boots the Flutter engine.": (
        "Android OS запускает `MainActivity`, она поднимает Flutter engine."
    ),
    "`MainActivity.kt` — minimal Flutter embedding.": "`MainActivity.kt` — минимальный Flutter embedding.",
    "Android app startup only.": "Только cold start Android — не Dart UI.",
    "Android crash on launch, deep link handling at native layer.": (
        "Crash при launch Android, deep links на native-слое."
    ),
    "Android app module source — manifest, resources, Kotlin entry.": (
        "Исходники app-модуля: manifest, `res/`, Kotlin entry."
    ),
    "Gradle compiles this tree into the installable APK.": (
        "Gradle компилирует это дерево в устанавливаемый APK."
    ),
    "Manifest, res/, kotlin/.": "Manifest, `res/`, `kotlin/`.",
    "Android APK contents and permissions.": "Содержимое APK и permissions Android.",
    "Permission denied, wrong app label, manifest merge errors.": (
        "Permission denied, неверное имя app, ошибки merge manifest."
    ),
    "Android visual resources — splash background, themes, launcher icons.": (
        "Android-ресурсы: splash, themes, launcher icons."
    ),
    "Android packages drawables and styles separately from Dart code.": (
        "Android хранит drawable/styles отдельно от Dart-кода."
    ),
    "XML styles, splash drawable, mipmap icons.": "XML styles, splash drawable, mipmap icons.",
    "Splash screen and Android-native chrome only.": "Только splash и native chrome Android.",
    "Splash flash, theme colors on Android launch.": "Вспышка splash, цвета theme при launch.",
    "Android launcher icon PNGs at different screen densities.": (
        "PNG иконки launcher для разных плотностей экрана."
    ),
    "Home screen icon must look sharp on phones and tablets.": (
        "Иконка на home screen должна быть чёткой на телефонах и планшетах."
    ),
    "`ic_launcher.png` per density folder (hdpi, xhdpi, …).": (
        "`ic_launcher.png` в папках hdpi, xhdpi и др."
    ),
    "App icon on Android home screen and app drawer.": "Иконка Counter на home screen и в app drawer.",
    "Wrong or blurry launcher icon on Android.": "Размытая или неверная иконка launcher.",
    "Kotlin/Java package path for Android Flutter activity under `{k}`.": (
        "Путь Java/Kotlin package к `MainActivity` Flutter на Android."
    ),
    "Android package naming mirrors Java folder structure required by Gradle.": (
        "Структура папок повторяет Java package name для Gradle."
    ),
    "Package directories leading to `MainActivity.kt`.": "Папки package, ведущие к `MainActivity.kt`.",
    "Android app entry class location only.": "Только расположение entry class Android.",
    "Android package rename or activity class move.": "Переименование package или перенос Activity.",
    "Manifest, res/, kotlin/.": "Manifest, каталоги `res/` и `kotlin/`.",
    "iOS App Store / TestFlight builds only.": "Только сборки TestFlight и App Store.",
    "Xcode unit test target for iOS Runner smoke tests.": (
        "Xcode unit test target для smoke-тестов iOS Runner."
    ),
    "Apple project template includes a test target for native/iOS integration checks.": (
        "Шаблон Apple project включает test target для native/iOS integration checks."
    ),
    "`RunnerTests.swift` — minimal XCTest entry.": "`RunnerTests.swift` — минимальный XCTest entry.",
    "iOS test target in Xcode — not the main Flutter `test/` suite.": (
        "iOS test target в Xcode — не основной Flutter `test/` suite."
    ),
    "iOS native test failures in Xcode.": "Падение native iOS-тестов в Xcode.",
    "Maybe — Flutter CI uses `flutter test`; keep for Xcode workflow.": (
        "Возможно — Flutter CI использует `flutter test`; оставить для Xcode workflow."
    ),
    "Xcode project for macOS desktop Counter `.app` target.": (
        "Xcode-проект macOS desktop target Counter `.app`."
    ),
    "macOS desktop builds compile through this Xcode project.": (
        "macOS desktop builds компилируются через этот Xcode-проект."
    ),
    "`project.pbxproj`, shared schemes for macOS Runner.": (
        "Файлы `project.pbxproj`, shared schemes для macOS Runner."
    ),
    "macOS desktop distribution builds.": "Сборки macOS desktop для распространения.",
    "macOS Xcode build/sign errors.": "Ошибки macOS Xcode build/sign.",
    "Xcode workspace for macOS Counter desktop app.": (
        "Xcode workspace для macOS desktop Counter."
    ),
    "Opens Runner + Flutter macOS pods together in Xcode.": (
        "Открывает Runner и Flutter macOS pods вместе в Xcode."
    ),
    "Workspace contents and shared IDE checks.": "Содержимое workspace и shared IDE checks.",
    "macOS desktop development in Xcode.": "macOS desktop разработка в Xcode.",
    "Workspace won't open; CocoaPods integration on macOS.": (
        "Workspace не открывается; сломана CocoaPods integration на macOS."
    ),
    "Compile-time environment template — copy to gitignored `env.dart` for local secrets/constants.": (
        "Compile-time шаблон env — копировать в gitignored `env.dart` для локальных secrets."
    ),
    "Some build-time values must not be committed; example file documents the required shape.": (
        "Build-time значения не коммитят; example file документирует нужную форму."
    ),
    "`env.dart.example` only in git; real `env.dart` is local.": (
        "В git только `env.dart.example`; настоящий `env.dart` локальный."
    ),
    "Developer local builds only if env constants are referenced.": (
        "Только локальные dev builds, если используются env constants."
    ),
    "Setting up a new dev machine; adding compile-time constant.": (
        "Настройка новой dev-машины; добавление compile-time constant."
    ),
    "No — documents required env.dart structure.": (
        "Нет — документирует структуру env.dart."
    ),
    "Root navigator key and desktop side-rail navigation helpers.": (
        "Root navigator key и helpers боковой desktop-навигации."
    ),
    "Desktop voice overlay and hidden main window need a global navigator; side rail replaces bottom tabs on wide screens.": (
        "Desktop voice overlay и hidden main window нуждаются в global navigator; side rail заменяет bottom tabs на широких экранах."
    ),
    "`app_navigator.dart` (`appRootNavigatorKey`), `shell_side_navigation.dart`.": (
        "Файлы `app_navigator.dart` (`appRootNavigatorKey`), `shell_side_navigation.dart`."
    ),
    "Desktop/web layout (side nav) and overlay routing above tabs.": (
        "Desktop/web layout (side nav) и overlay routing над вкладками."
    ),
    "Desktop overlay cannot push routes; side navigation breakpoint wrong.": (
        "Desktop overlay не может push routes; неверный breakpoint side navigation."
    ),
    "No — desktop layout and overlays break.": "Нет — сломаются desktop layout и overlays.",
    "Runtime feature flags and optional perf metrics — date strip, warm window, rebuild counters.": (
        "Runtime feature flags и optional perf metrics — date strip, warm window, rebuild counters."
    ),
    "Lets developers toggle expensive features or capture frame metrics without shipping debug code to all users.": (
        "Позволяет включать дорогие features или capture frame metrics без debug code для всех users."
    ),
    "`runtime_flags.dart`, `shell_flags.dart`, `rebuild_metrics.dart` (`PERF_DIAG` gated).": (
        "Файлы `runtime_flags.dart`, `shell_flags.dart`, `rebuild_metrics.dart` (`PERF_DIAG` gated)."
    ),
    "Perf-sensitive paths: date paging, shell tab stack, diagnostic builds.": (
        "Perf-sensitive paths: date paging, shell tab stack, diagnostic builds."
    ),
    "Investigating jank, toggling warm-window kill switch, perf capture tests.": (
        "Расследование jank, warm-window kill switch, perf capture tests."
    ),
    "No — perf tests and diagnostics reference these flags.": (
        "Нет — perf tests и diagnostics ссылаются на эти flags."
    ),
    "Storyboard or xib launch UI files.": "Storyboard или xib файлы launch UI.",
    "Splash/launch appearance on Apple platforms.": "Splash/launch appearance на Apple platforms.",
    "Launch screen flash or wrong orientation on iOS/macOS.": (
        "Flash launch screen или неверная orientation на iOS/macOS."
    ),
    "No — required for Apple runner launch UX.": "Нет — нужен для Apple runner launch UX.",
    "App icon and image asset catalog for {plat} — `{k}`.": (
        "Asset catalog иконок и картинок для {plat} — `{k}`."
    ),
    "Apple platforms load icons and launch images from asset catalogs, not Dart.": (
        "Apple platforms грузят icons и launch images из asset catalogs, не из Dart."
    ),
    "PNG/AppIcon sets and related image sets.": "PNG/AppIcon sets и related image sets.",
    "Home screen / dock icon on Apple devices.": "Home screen / dock icon на Apple devices.",
    "Wrong or missing app icon on iOS/macOS.": "Неверная или пропавшая app icon на iOS/macOS.",
    "Assets, launch screen, native Swift/ObjC glue.": (
        "Assets, launch screen, native Swift/ObjC glue."
    ),
    "Xcode project, Info.plist, asset catalogs, Flutter iOS embedder.": (
        "Xcode-проект, Info.plist, asset catalogs, Flutter iOS embedder."
    ),
    # lib/data & lib/features (FOLDERS)
    "Timeline record slice of the brain — start/stop timer, edit history, realtime updates, offline queue.": (
        "Срез мозга для Timeline — старт/стоп таймера, история правок, realtime и offline queue."
    ),
    "Timeline is the core time tracker; this folder splits record logic into readable modules.": (
        "Timeline — ядро трекера; эта папка делит record-логику на читаемые модули."
    ),
    "CRUD, optimistic UI, realtime subscription, timeline list builders, overlap/Highlander rules, outbox.": (
        "CRUD, optimistic UI, realtime, builders списка Timeline, правила overlap/Highlander, outbox."
    ),
    "Timeline tab, record edit sheet, Wear lite timer, voice “start record”.": (
        "Вкладка Timeline, edit sheet записи, Wear lite timer, voice «start record»."
    ),
    "Timer won’t start/stop, wrong day bucket, duplicate running records, offline start fails.": (
        "Таймер не стартует/стопится, неверный day bucket, дубликаты running, offline start падает."
    ),
    "No — timeline tracking breaks.": "Нет — перестанет работать учёт времени на Timeline.",
    "Plans and lists slice of the brain — scheduled tasks, backlog items, recurrence, tags on plans.": (
        "Срез мозга для Plans/Lists — задачи по расписанию, backlog, recurrence и теги планов."
    ),
    "Planning tab, Lists tab, and calendar rows all read/write the same `plans` table through these modules.": (
        "Вкладки Plans и Lists и calendar rows читают/пишут одну таблицу `plans` через эти модули."
    ),
    "Projection for Time View, RRULE expansion, tag sync, plan cache, offline plan outbox.": (
        "Projection для Time View, RRULE expansion, sync тегов, кэш планов, offline outbox."
    ),
    "Plans tab, Time View layout, Lists tab, plan edit sheets, plan alarms.": (
        "Вкладка Plans, layout Time View, Lists, edit sheets планов, plan alarms."
    ),
    "Plans don’t save, recurrence wrong, Time View cards misplaced, list toggle offline.": (
        "Планы не сохраняются, recurrence неверна, карточки Time View не на месте, offline toggle списка."
    ),
    "No — planning and lists break.": "Нет — сломаются Plans и Lists.",
    "Reusable UI building blocks (buttons, cards, headers, pickers) — the design system in code.": (
        "Переиспользуемые UI-блоки (кнопки, карточки, headers, pickers) — design system в коде."
    ),
    "One canonical button/card so Plans, Timeline, and Lists look consistent.": (
        "Один канонический button/card — Plans, Timeline и Lists выглядят одинаково."
    ),
    "`AppButton`, `PlanTimeTaskCard`, date header, timezone picker, chips.": (
        "`AppButton`, `PlanTimeTaskCard`, date header, timezone picker, chips."
    ),
    "Every main tab and most sheets.": "Все главные вкладки и большинство sheets.",
    "Button style migration, plan card layout, date/time picker, loading/empty states.": (
        "Миграция стиля кнопок, layout карточек планов, date/time picker, loading/empty states."
    ),
    "No — features depend on these widgets.": "Нет — features зависят от этих widgets.",
    "Debug-only logging helpers — startup, voice pipeline, duplicates.": (
        "Debug-only логирование — startup, voice pipeline, duplicates."
    ),
    "Structured logs for diagnosing perf and desktop voice without spamming release builds.": (
        "Структурированные логи для perf и desktop voice без spam в release."
    ),
    "Small log wrapper files gated by debug/profile flags.": (
        "Небольшие log wrapper, включаемые debug/profile flags."
    ),
    "Developer diagnostics only.": "Только диагностика разработчика.",
    "Tracing desktop voice steps or startup timing.": "Трассировка шагов desktop voice или startup timing.",
    "No — used by debug/profile builds.": "Нет — используется в debug/profile builds.",
    "Plans tab UI — day pager, plan list, Time View canvas, plan settings, bulk edit.": (
        "UI вкладки Plans — day pager, список планов, canvas Time View, settings, bulk edit."
    ),
    "This is what users see on the second bottom tab (Plans).": (
        "Это видит пользователь на второй нижней вкладке (Plans)."
    ),
    "Large `planning_page.dart` plus `time_view/`, `settings/`, `widgets/` subfolders.": (
        "Большой `planning_page.dart` и подпапки `time_view/`, `settings/`, `widgets/`."
    ),
    "Plans tab only (plus calendar rows that reuse plan cards).": (
        "Только вкладка Plans (плюс calendar rows с теми же карточками)."
    ),
    "Plan cards wrong, Time View drag broken, day swipe on Plans tab, play/start plan.": (
        "Неверные карточки планов, drag Time View, swipe дней на Plans, play/start plan."
    ),
    "No — Plans tab disappears.": "Нет — вкладка Plans исчезнет.",
    "Shared edit sheets and voice UI used by Timeline, Plans, and Lists.": (
        "Общие edit sheets и voice UI для Timeline, Plans и Lists."
    ),
    "One edit experience for plans and records — Omni date/time picker, tags, checklist, offline banner.": (
        "Единый edit для plans и records — Omni date/time picker, tags, checklist, offline banner."
    ),
    "Activity detail router, planning/record edit sheets, edit_sheet/* helpers, voice widgets.": (
        "Router activity detail, edit sheets planning/record, helpers `edit_sheet/*`, voice widgets."
    ),
    "Any tap-to-edit on plans/records; mobile voice sheet; desktop voice panel.": (
        "Tap-to-edit plans/records; mobile voice sheet; desktop voice panel."
    ),
    "Edit sheet save, date picker, tags on plan, voice input sheet.": (
        "Save edit sheet, date picker, tags на plan, voice input sheet."
    ),
    "No — edit flows break on all tabs.": "Нет — edit flows сломаются на всех вкладках.",
    # iOS / macOS / linux / windows subfolders
    "Xcode project file bundle for the iOS Counter app target.": (
        "Bundle Xcode project для iOS target Counter."
    ),
    "Xcode opens this project to compile, sign, and archive the iOS IPA.": (
        "Xcode открывает этот project для compile, sign и archive iOS IPA."
    ),
    "`project.pbxproj`, shared schemes, workspace metadata.": (
        "`project.pbxproj`, shared schemes, workspace metadata."
    ),
    "Xcode project corruption, scheme changes, iOS signing settings.": (
        "Повреждение Xcode project, смена scheme, настройки iOS signing."
    ),
    "Xcode workspace wrapping the iOS Runner project and CocoaPods.": (
        "Xcode workspace, оборачивающий Runner и CocoaPods."
    ),
    "Developers open `.xcworkspace` (not `.xcodeproj` alone) after `pod install`.": (
        "После `pod install` открывают `.xcworkspace`, а не только `.xcodeproj`."
    ),
    "Workspace data linking Runner + Pods.": "Workspace data, связывающая Runner и Pods.",
    "Local iOS development and CI iOS builds using CocoaPods.": (
        "Локальная iOS-разработка и CI-сборки с CocoaPods."
    ),
    "Xcode says open workspace; Pod integration broken.": (
        "Xcode просит open workspace; сломана интеграция Pods."
    ),
    "Flutter-generated Linux embedder glue — plugin registrant and CMake hooks.": (
        "Сгенерированный Flutter glue для Linux embedder — registrant plugins и CMake hooks."
    ),
    "Flutter tool regenerates these when `pubspec.yaml` plugins change.": (
        "Flutter tool перегенерирует при смене plugins в `pubspec.yaml`."
    ),
    "`generated_plugin_registrant.*`, `generated_plugins.cmake`, child `CMakeLists.txt`.": (
        "`generated_plugin_registrant.*`, `generated_plugins.cmake`, child `CMakeLists.txt`."
    ),
    "Linux desktop plugin registration at runtime.": "Регистрация Flutter plugins на Linux desktop в runtime.",
    "Linux build fails after adding/removing Flutter plugin.": (
        "Linux build падает после добавления/удаления Flutter plugin."
    ),
    "Flutter-generated Windows embedder glue — plugin registrant and CMake hooks.": (
        "Сгенерированный Flutter glue для Windows embedder — registrant plugins и CMake hooks."
    ),
    "Native Windows plugins (tray, hotkey, voice overlay) register through this generated code.": (
        "Native Windows plugins (tray, hotkey, voice overlay) регистрируются через этот generated code."
    ),
    "Windows desktop plugin registration — desktop voice/tray depend on it.": (
        "Регистрация plugins на Windows desktop — от неё зависят voice/tray."
    ),
    "Windows build fails after plugin change; desktop voice plugin missing.": (
        "Windows build падает после смены plugin; пропал desktop voice plugin."
    ),
}


def has_semi_russian_or_english_leak(text: str) -> bool:
    if not text:
        return False
    sanitized = sanitize_ru_prose(text)
    for bad in BANNED_SEMI_RUSSIAN_WRAPPERS + BANNED_ENGLISH_IN_RU + BANNED_GENERIC_RU_WRAPPERS:
        if bad in sanitized:
            return True
    for bad in GENERIC_EN_MARKERS:
        if bad in sanitized:
            return True
    return False


def sanitize_ru_prose(text: str) -> str:
    """Replace banned English fragments with Russian equivalents inside RU prose."""
    if not text:
        return text
    repl: tuple[tuple[str, str], ...] = (
        ("Android application module", "модуль Android-приложения"),
        ("Gradle build script", "Gradle-скрипт"),
        ("Native Windows host", "native C++ host Windows"),
        ("Flutter-generated", "сгенерированный Flutter"),
        ("build output", "результат сборки"),
        ("Xcode project", "Xcode-проект"),
        ("Required for", "Нужен для"),
        ("Source file", "Исходный файл"),
    )
    out = text
    for en_frag, ru_frag in repl:
        out = out.replace(en_frag, ru_frag)
    return out


def ru_prose_ok(text: str, *, min_cyrillic: int = 10) -> bool:
    if not text or text.startswith("NEEDS HUMAN"):
        return False
    cleaned = sanitize_ru_prose(text)
    if has_semi_russian_or_english_leak(cleaned):
        return False
    if cyrillic_count(cleaned) >= min_cyrillic:
        return True
    # Path/inventory lines: Russian lead-in + backticks is OK.
    if "`" in cleaned and cyrillic_count(cleaned) >= 4 and len(cleaned) >= 18:
        return True
    return False


def _exact(en: str) -> str | None:
    if not en:
        return None
    t = en.strip()
    if t in EXACT_EN_FIELD_RU:
        return EXACT_EN_FIELD_RU[t]
    return None


# Full folder RU blocks for deep paths (class adapters).
FOLDER_CLASS_RU: dict[str, dict[str, str]] = {}


def register_folder_class(key: str, ru: dict[str, str]) -> None:
    FOLDER_CLASS_RU[key.replace("\\", "/").strip("/")] = ru


def _platform_subfolder_field(k: str, field: str, en_val: str) -> str | None:
    from structure_en_ru_adapt import _phrase_translate

    exact = _exact(en_val)
    if exact and ru_prose_ok(exact, min_cyrillic=6):
        return exact
    body = sanitize_ru_prose(_phrase_translate(en_val))
    if ru_prose_ok(body, min_cyrillic=8):
        return body
    return None


def _lib_subfolder_field(k: str, field: str, en_val: str) -> str | None:
    exact = _exact(en_val)
    if exact and ru_prose_ok(exact, min_cyrillic=6):
        return exact
    body = sanitize_ru_prose(_phrase_translate_lib(en_val))
    if ru_prose_ok(body, min_cyrillic=8):
        return body
    return None


def _phrase_translate_lib(en: str) -> str:
    """Extra EN→RU fragments for lib/ folder EN (FOLDERS + inference)."""
    repl: tuple[tuple[str, str], ...] = (
        (
            "Device services — speech-to-text, desktop voice, tray, hotkeys.",
            "Сервисы устройства — speech-to-text, desktop voice, tray, hotkeys.",
        ),
        (
            "Platform voice and tray behavior cannot live in PocketBase brain code.",
            "Platform voice и tray не могут жить в PocketBase brain code.",
        ),
        (
            "Many `desktop_voice_*.dart` modules plus STT helper subprocess client.",
            "Модули `desktop_voice_*.dart` и STT helper subprocess client.",
        ),
        (
            "Windows desktop voice, tray icon, global hotkey; mobile STT locale.",
            "Windows desktop voice, tray icon, global hotkey; mobile STT locale.",
        ),
        (
            "Wall-clock and timezone math shared by header, Plans Time View, and profile ‘today’ line.",
            "Wall-clock и timezone math для header, Time View и profile «today» line.",
        ),
        (
            "Time bucketing must follow profile timezone law — not device local time — across all tabs.",
            "Time bucketing по profile timezone law — не device local time — на всех вкладках.",
        ),
        (
            "In-memory caches and warm-window helpers for faster Timeline/Plans first paint.",
            "In-memory caches и warm-window helpers для быстрого first paint Timeline/Plans.",
        ),
        (
            "Reduces PocketBase round-trips and repeated JSON work on tab switches.",
            "Меньше PocketBase round-trips и повторного JSON при переключении вкладок.",
        ),
    )
    out = en.strip()
    for en_frag, ru_frag in repl:
        if en_frag in out:
            out = out.replace(en_frag, ru_frag)
    return out


def _xcode_scheme_folder_field(field: str, en_val: str, key: str = "") -> str | None:
    parent = key.rsplit("/", 2)[0] if key else "Runner"
    m = {
        "what": f"Shared Xcode scheme/metadata для `{parent}` — какой scheme собирает target.",
        "why": "Xcode хранит scheme и workspace checks для единообразной сборки в команде.",
        "inside": "Plist scheme-файлы и workspace checks IDE.",
        "affects": "Какой Xcode scheme собирает Runner — только workflow разработчика.",
        "when": "Пропал scheme в Xcode или предупреждения workspace checks.",
        "delete": "Нет — часть структуры Xcode-проекта.",
        "related": "Родительский Xcode-проект Runner.",
    }
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=8) else None


def _xcode_project_workspace_field(field: str, en_val: str) -> str | None:
    m = {
        "what": "Внутренний Xcode workspace внутри `.xcodeproj` — IDE metadata.",
        "why": "Xcode хранит workspace checks для project bundle.",
        "inside": "Workspace checks и IDE metadata.",
        "affects": "Только открытие project в Xcode — не runtime приложения.",
        "when": "Xcode warnings о workspace checks.",
        "delete": "Нет — часть bundle Xcode-проекта.",
        "related": "`project.pbxproj`, shared schemes.",
    }
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=8) else None


def _apple_assets_folder_field(k: str, field: str, en_val: str) -> str | None:
    m = {
        "what": f"Asset catalog `{k.split('/')[-1]}` — иконки и launch images для Apple target.",
        "why": "Apple platforms грузят icons и launch images из asset catalogs, не из Dart.",
        "inside": "PNG/AppIcon sets и related image sets.",
        "affects": "Home screen / dock icon на Apple devices.",
        "when": "Неверная или пропавшая app icon на iOS/macOS.",
        "delete": "Нет — нужен для Apple runner branding.",
        "related": f"`{k.rsplit('/', 1)[0]}` Runner target.",
    }
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=8) else None


def _apple_launch_folder_field(field: str, en_val: str) -> str | None:
    m = {
        "what": "Launch screen resources (storyboard/xib) для Apple Runner.",
        "why": "Apple показывает launch screen до первого кадра Flutter.",
        "inside": "Storyboard или xib файлы launch UI.",
        "affects": "Splash/launch appearance на Apple platforms.",
        "when": "Flash launch screen или неверная orientation на iOS/macOS.",
        "delete": "Нет — нужен для Apple runner launch UX.",
        "related": "`ios/Runner/` или `macos/Runner/` main target.",
    }
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=8) else None


def folder_class_field(key: str, field: str, en_val: str) -> str | None:
    k = key.replace("\\", "/").strip("/")
    parts = k.split("/")
    leaf = parts[-1] if parts else k
    block = FOLDER_CLASS_RU.get(k)
    if block:
        ru = block.get(f"{field}_ru")
        if ru and ru_prose_ok(ru, min_cyrillic=8):
            return sanitize_ru_prose(ru)
    if "xcshareddata" in k or leaf == "xcschemes":
        ru = _xcode_scheme_folder_field(field, en_val, k)
        if ru:
            return sanitize_ru_prose(ru)
    if leaf == "project.xcworkspace":
        ru = _xcode_project_workspace_field(field, en_val)
        if ru:
            return sanitize_ru_prose(ru)
    if leaf in ("Assets.xcassets", "AppIcon.appiconset") or k.endswith(".xcassets"):
        ru = _apple_assets_folder_field(k, field, en_val)
        if ru:
            return sanitize_ru_prose(ru)
    if leaf == "Base.lproj":
        ru = _apple_launch_folder_field(field, en_val)
        if ru:
            return sanitize_ru_prose(ru)
    if "/res/" in k and k.startswith("android/app/"):
        ru = _android_res_folder_field(k, field, en_val)
        if ru:
            return sanitize_ru_prose(ru)
    if k.startswith("lib/"):
        ru = _lib_subfolder_field(k, field, en_val)
        if ru:
            return sanitize_ru_prose(ru)
    if k.split("/")[0] in ("android", "ios", "web", "windows", "linux", "macos"):
        ru = _platform_subfolder_field(k, field, en_val)
        if ru:
            return sanitize_ru_prose(ru)
    exact = _exact(en_val)
    if exact and ru_prose_ok(exact, min_cyrillic=6):
        return sanitize_ru_prose(exact)
    return None


def file_class_field(path: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    if field == "delete":
        return delete_en_to_ru(en_val)

    p = path.replace("\\", "/")
    name = p.split("/")[-1].lower()

    exact = _exact(en_val)
    if exact and ru_prose_ok(exact, min_cyrillic=6):
        return sanitize_ru_prose(exact)

    ru: str | None = None
    if p.startswith(".github/workflows/") and name.endswith(".yml"):
        ru = _github_workflow_field(p, name, field, en_val, en)
    elif name in ("build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"):
        ru = _android_gradle_field(p, name, field, en_val, en)
    elif name == "androidmanifest.xml":
        ru = _android_manifest_field(p, field, en_val, en)
    elif name == "launch_background.xml":
        ru = _launch_background_field(p, field, en_val, en)
    elif name == "styles.xml":
        ru = _android_styles_field(p, field, en_val, en)
    elif name == "ic_launcher.png":
        ru = _launcher_icon_field(p, field, en_val, en)
    elif name == "mainactivity.kt":
        ru = _main_activity_field(field, en_val, en)
    elif p.startswith("docs/") and name.endswith(".md"):
        ru = _governing_doc_field(p, name, field, en_val, en)
    elif p.startswith((".cursor/", ".github/", "pb_hooks/", "installer/")) or name.endswith(".pb.js") or name == "env.dart.example":
        ru = _platform_native_file_field(p, name, field, en_val, en)
    elif p.startswith("lib/"):
        ru = _dart_file_field(p, field, en_val, en)
    elif (p.startswith("test/") or p.startswith("integration_test/")) and name.endswith(".dart"):
        ru = _test_file_field(p, name, field, en_val, en)
    elif name.endswith(".pb.js"):
        ru = _pb_hook_field(name, field, en_val, en)
    elif name in (
        "generatedpluginregistrant.java",
        "generated_plugin_registrant.cc",
        "generated_plugin_registrant.h",
    ):
        ru = _plugin_registrant_field(p, field, en_val, en)
    elif name == "cmakelists.txt":
        ru = _cmake_file_field(p, field, en_val, en)
    elif p.startswith(("android/", "ios/", "web/", "windows/", "linux/", "macos/")):
        ru = _platform_native_file_field(p, name, field, en_val, en)
    elif p.startswith("scripts/"):
        ru = _script_file_field(p, name, field, en_val, en)

    if ru:
        ru = sanitize_ru_prose(ru)
        if ru_prose_ok(ru, min_cyrillic=6):
            return ru

    return _generic_file_field(p, name, field, en_val, en)


def _cmake_file_field(p: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    name = p.split("/")[-1].lower()
    plat = p.split("/")[0]
    plat_ru = {
        "windows": "Windows desktop runner",
        "linux": "Linux desktop runner",
        "macos": "macOS desktop runner",
    }.get(plat, f"{plat} native runner")
    if p.endswith("/CMakeLists.txt") and p.count("/") == 1:
        m = {
            "what": f"Главный CMake-файл {plat_ru}. Описывает native targets, source files и link rules, через которые Flutter engine собирается в {plat} binary.",
            "why": f"Flutter {plat} build не соберёт runner без корневого CMake project.",
            "contains": "project(), add_subdirectory для `flutter/` и `runner/`, toolchain settings.",
            "responsibilities": f"Собрать native binary для `{plat}/` embedder через CMake.",
            "when": f"{plat} desktop build падает на configure/link; installer не получит рабочий runner.",
            "connected": f"`{plat}/runner/`, `{plat}/flutter/CMakeLists.txt`.",
            "layer": f"{plat} native build — не Dart UI.",
        }
    elif "runner" in p and name == "cmakelists.txt":
        m = {
            "what": f"CMake target `{plat}/runner` — собирает native host, который запускает Flutter engine.",
            "why": f"Executable Counter на {plat} создаётся из runner sources и Flutter glue.",
            "contains": "Список runner sources, link libraries и install rules для desktop binary.",
            "responsibilities": f"Собрать {plat} host app и подключить Flutter plugins.",
            "when": f"Link errors runner target, missing plugin registration на {plat}.",
            "connected": f"`{plat}/CMakeLists.txt`, `{plat}/flutter/`.",
            "layer": f"{plat} runner native — не Dart business logic.",
        }
    elif "flutter" in p and name == "cmakelists.txt":
        m = {
            "what": f"Flutter-generated CMake glue для {plat} — подключает engine и plugin build steps.",
            "why": "Flutter tool перезаписывает этот файл при build; связывает Dart AOT с native runner.",
            "contains": "Сгенерированные targets для `libflutter`, assets и plugin registrant.",
            "responsibilities": f"Встраивает Flutter engine и assets в {plat} desktop build.",
            "when": f"Flutter upgrade изменил generated CMake; plugin link fail на {plat}.",
            "connected": f"`{plat}/CMakeLists.txt`, `{plat}/runner/`.",
            "layer": f"Flutter-generated {plat} glue — не править вручную без причины.",
        }
    else:
        return None
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=6) else None


def _generic_file_field(p: str, name: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    if field == "connected":
        if en_val and "`" in en_val:
            return en_val.rstrip(".") + "."
        return None
    from structure_en_ru_adapt import _phrase_translate

    body = sanitize_ru_prose(_phrase_translate(en_val))
    if ru_prose_ok(body, min_cyrillic=6):
        return body
    return None


def _github_workflow_field(p: str, name: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    if "deploy" in name:
        m = {
            "what": "Workflow GitHub Actions для публикации web-версии Counter на GitHub Pages.",
            "why": "После push автоматически собирает Flutter web с base href `/Counter/` и выкладывает сайт.",
            "contains": "Шаги checkout, `flutter build web`, deploy в ветку `gh-pages`.",
            "responsibilities": "Собрать и опубликовать web build без ручного `update.ps1` на runner.",
            "when": "Сайт не обновился после merge; смотреть log job deploy.",
            "connected": "`docs/DEPLOY.md`, `update.ps1`, `web/index.html`.",
            "layer": "CI deploy — не runtime приложения.",
        }
    elif "windows" in name:
        m = {
            "what": "Workflow GitHub Actions для сборки Windows installer `CounterSetup.exe`.",
            "why": "Автоматизирует release Windows desktop build и упаковку installer artifact.",
            "contains": "Шаги `flutter build windows`, подготовка STT payload, Inno Setup.",
            "responsibilities": "Собрать `.exe` installer и загрузить artifact в Actions.",
            "when": "Нет `CounterSetup.exe` в Actions artifacts после push.",
            "connected": "`installer/windows/`, `docs/DEPLOY.md`.",
            "layer": "CI Windows installer — не runtime приложения.",
        }
    else:
        return None
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=8) else None


def _android_gradle_field(p: str, name: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    is_settings = "settings" in name
    is_app = "/app/" in p or p.endswith("/app/build.gradle.kts") or p.endswith("/app/build.gradle")
    if is_settings:
        m = {
            "what": "Gradle settings — подключает модули Android-проекта и версии плагинов.",
            "why": "Gradle читает этот файл первым, чтобы знать какие модули собирать.",
            "contains": "Список include modules, pluginManagement, версии AGP.",
            "responsibilities": "Задать структуру multi-module Gradle проекта Counter.",
            "when": "Gradle sync падает на settings или не видит `:app` module.",
            "connected": "`android/build.gradle.kts`, `android/app/build.gradle.kts`.",
            "layer": "Android Gradle config — не Dart.",
        }
    elif is_app:
        m = {
            "what": "Gradle-скрипт модуля `android/app` — SDK, plugins, signing, зависимости APK.",
            "why": "Именно этот module Gradle превращает Flutter Android build в APK/AAB Counter.",
            "contains": "compileSdk, minSdk, Flutter Gradle plugin hook, dependencies.",
            "responsibilities": "Настроить compile/target SDK, plugins Flutter, hooks подписи release.",
            "when": "Ошибка сборки app module, SDK version, signing config.",
            "connected": "`android/settings.gradle.kts`, `AndroidManifest.xml`.",
            "layer": "Android app module build — не Dart UI.",
        }
    else:
        m = {
            "what": "Корневой Gradle-скрипт проекта `android/` — общие версии и classpath плагинов.",
            "why": "Связывает wrapper, AGP и Flutter Gradle plugin для всего Android tree.",
            "contains": "buildscript classpath, allprojects repos, clean task.",
            "responsibilities": "Общие настройки Gradle для root Android project.",
            "when": "Root Gradle sync fail, classpath/plugin version errors.",
            "connected": "`android/settings.gradle.kts`, `android/app/`.",
            "layer": "Android root Gradle — не Dart.",
        }
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=8) else None


def _android_manifest_field(p: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    variant = "debug" if "/debug/" in p else "profile" if "/profile/" in p else "release/main"
    m = {
        "what": f"Android manifest ({variant}) — permissions, label приложения и Flutter activity.",
        "why": "Android читает XML при установке: mic, notifications, запуск Counter.",
        "contains": "Теги `<uses-permission>`, application label, intent filters.",
        "responsibilities": "Задать permissions ОС и deep links для этой build variant.",
        "when": "Permission denied на устройстве, неверное имя app, intent filters.",
        "connected": "`android/app/build.gradle.kts`, Kotlin MainActivity.",
        "layer": "Android manifest — не Dart business logic.",
    }
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=8) else None


def _launch_background_field(p: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    m = {
        "what": "XML-фон splash Android — показывается до первого кадра Flutter.",
        "why": "Убирает белую вспышку при cold start, пока engine грузит UI.",
        "contains": "Layer-list drawable с цветом или картинкой фона.",
        "responsibilities": "Native splash до появления Flutter content.",
        "when": "Белая вспышка при launch или неверный цвет splash.",
        "connected": "`styles.xml`, theme в `AndroidManifest.xml`.",
        "layer": "Android drawable resource.",
    }
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=8) else None


def _android_styles_field(p: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    night = "night" in p
    m = {
        "what": f"XML-стили Android{' (night)' if night else ''} — theme launch и окна приложения.",
        "why": "Задаёт цвета/status bar/splash theme до и после старта Flutter.",
        "contains": "Theme `LaunchTheme`, `NormalTheme`, ссылки на `@drawable/launch_background`.",
        "responsibilities": "Внешний вид native chrome при launch Android.",
        "when": "Неверные цвета splash/status bar на Android.",
        "connected": "`launch_background.xml`, `AndroidManifest.xml`.",
        "layer": "Android styles resource.",
    }
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=8) else None


def _launcher_icon_field(p: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    density = p.split("/")[-2] if "/" in p else "mipmap"
    m = {
        "what": f"PNG иконка launcher Android ({density}) — иконка Counter на home screen.",
        "why": "Для этой плотности экрана нужен отдельный размер PNG, иначе icon blur.",
        "contains": "Растровый PNG `ic_launcher.png`.",
        "responsibilities": "Чёткая иконка Counter на устройствах с этой density.",
        "when": "Размытая или неверная иконка на home screen Android.",
        "connected": "`AndroidManifest.xml` application icon.",
        "layer": "Android mipmap asset.",
    }
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=8) else None


def _main_activity_field(field: str, en_val: str, en: dict[str, str]) -> str | None:
    m = {
        "what": "Минимальная Android Activity — поднимает Flutter engine и показывает Dart UI.",
        "why": "Без этой Activity APK не может открыть Flutter интерфейс после tap по иконке.",
        "contains": "Subclass `FlutterActivity` — несколько строк Kotlin.",
        "responsibilities": "Запуск Flutter engine при старте Counter на Android.",
        "when": "Crash при launch Android или native deep link handling.",
        "connected": "`AndroidManifest.xml`, Flutter Android embedding.",
        "layer": "Android entry point — не Dart business logic.",
    }
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=8) else None


def _governing_doc_field(p: str, name: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    docs = {
        "app_structure.md": {
            "what": "Краткая карта структуры repo — папки, слои, import rules, команды guard.",
            "why": "Быстрый ответ «где живёт X» без чтения всей encyclopedia.",
            "contains": "Таблицы `lib/data`, features, scripts; команды architecture guard.",
            "responsibilities": "Канонический structure contract для guard и AI.",
            "when": "Ищете ownership модуля; перед переносом файлов.",
            "connected": "`APP_STRUCTURE_DETAILED.md`, `architecture_guard.ps1`.",
            "layer": "Governing structure doc — Project Knowledge pack.",
        },
        "architecture.md": {
            "what": "Iron Laws проекта — optimistic UI, Brain/UI split, PocketBase rules, main-thread law.",
            "why": "Авторитетный технический контракт для owner и AI.",
            "contains": "Правила data flow, offline, singleton record, performance.",
            "responsibilities": "Ответ на «как система обязана работать».",
            "when": "Спор об architecture; перед refactor Brain или UI.",
            "connected": "`docs/DATA_MAP.md`, `docs/POCKETBASE_MANIFEST.md`.",
            "layer": "Governing architecture doc — Project Knowledge pack.",
        },
        "data_map.md": {
            "what": "Словарь полей PocketBase — имена колонок, business IDs, relation fields.",
            "why": "Brain и UI должны использовать одни имена полей при POST/PATCH.",
            "contains": "Таблицы records, plans, categories, tags, profiles.",
            "responsibilities": "SSOT имён полей — не выдумывать alternate names.",
            "when": "Ошибка parse поля PB; добавление нового поля в schema.",
            "connected": "`docs/POCKETBASE_MANIFEST.md`, `lib/data/models/`.",
            "layer": "Governing data doc — Project Knowledge pack.",
        },
        "design_system.md": {
            "what": "Design system контракт — Figma → Flutter mapping, canonical components.",
            "why": "Запрещает локальные копии кнопок/карточек в feature screens.",
            "contains": "Token categories, `AppButton`, `AppIconButton`, forbidden local UI.",
            "responsibilities": "Правила V7 component migration и Component Lab acceptance.",
            "when": "Миграция UI на canonical widgets; pixel QA.",
            "connected": "`lib/core/widgets/`, Component Lab.",
            "layer": "Governing design doc — Project Knowledge pack.",
        },
        "deploy.md": {
            "what": "Пошаговый deploy — GitHub Pages, PocketBase auth admin, Windows installer.",
            "why": "Deploy и OAuth легко сломать без VPS checklist.",
            "contains": "`update.ps1`, GitHub Pages flow, Windows installer, OAuth admin steps.",
            "responsibilities": "Инструкция публикации сайта и production auth.",
            "when": "Сайт не обновился; OAuth broken; сборка installer.",
            "connected": "`.github/workflows/`, `update.ps1`, `installer/`.",
            "layer": "Deploy guide — Project Knowledge pack.",
        },
    }
    key = name.lower()
    m = docs.get(key)
    if not m:
        topic = name.replace(".md", "").replace("_", " ")
        m = {
            "what": f"Markdown-документ `{name}` — правила и заметки по теме «{topic}».",
            "why": "Читается owner и AI; не исполняется приложением.",
            "contains": "Markdown-секции по этой теме.",
            "responsibilities": f"Ответы на вопросы по `{topic}`.",
            "when": f"Нужна written-инструкция по `{topic}`.",
            "connected": "`docs/PROJECT_KNOWLEDGE_PACK.md`.",
            "layer": "Документация — не runtime.",
        }
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=6) else None


def _dart_file_field(p: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    from structure_role_guides import humanize_guide

    role = en.get("responsibilities", en_val)
    if _is_generic_en(role):
        role = ""
    human = humanize_guide(p, role, [])
    if human:
        ru_key = f"{field}_ru"
        if field == "contains":
            ru_key = "contains_ru"
        ru = human.get(ru_key)
        if ru and ru_prose_ok(ru, min_cyrillic=6):
            return sanitize_ru_prose(ru)
    exact = _exact(en_val)
    if exact and ru_prose_ok(exact, min_cyrillic=6):
        return exact
    from structure_en_ru_adapt import _phrase_translate

    body = sanitize_ru_prose(_phrase_translate(en_val))
    if ru_prose_ok(body, min_cyrillic=8):
        return body
    return None


def _test_file_field(p: str, name: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    stem = name.replace("_test.dart", "")
    m = {
        "what": f"Автотест `{stem}` — проверяет поведение без ручного UI.",
        "why": "Ловит регрессии при изменении связанного production-кода.",
        "contains": f"Test cases для сценария `{stem}`.",
        "responsibilities": f"Assert ожидаемого поведения `{stem}`.",
        "when": f"Падение CI или правка кода рядом с `{stem}`.",
        "connected": f"Production files под `lib/` с похожим именем.",
        "layer": "Автотест — не попадает пользователю в APK.",
    }
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=8) else None


def _android_res_folder_field(k: str, field: str, en_val: str) -> str | None:
    leaf = k.split("/")[-1]
    kind = leaf
    if leaf.startswith("drawable"):
        kind = "drawable splash/фон"
    elif leaf.startswith("mipmap"):
        kind = f"mipmap иконки ({leaf})"
    elif leaf.startswith("values"):
        kind = f"values/styles ({leaf})"
    else:
        kind = f"ресурсы `{leaf}`"
    m = {
        "what": f"Android `{kind}` — ресурсы в `{k}`.",
        "why": "Android хранит drawable/styles/icons отдельно от Dart-кода.",
        "inside": f"XML/PNG ресурсы для `{leaf}`.",
        "affects": "Splash, theme или launcher icon на Android (только native chrome).",
        "when": f"Проблема с `{leaf}` при launch или иконке Android.",
        "delete": "Нет — нужен для Android APK.",
        "related": "`android/app/src/main/AndroidManifest.xml`, `styles.xml`.",
    }
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=8) else None


def _pb_hook_field(name: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    hook = name.replace(".pb.js", "")
    m = {
        "what": f"JS hook PocketBase `{hook}` на VPS — серверное правило, не код в APK.",
        "why": "Server-side правила (auth reset, overlap records) нельзя доверить только клиенту.",
        "contains": f"JavaScript handler для события `{hook}`.",
        "responsibilities": f"Логика hook `{hook}` по `docs/POCKETBASE_MANIFEST.md`.",
        "when": f"Server behavior не совпадает с ожиданиями app для `{hook}`.",
        "connected": f"См. также: {en.get('connected', '`docs/APP_STRUCTURE.md`')}.",
        "layer": "Server hook — не бинарник приложения.",
    }
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=8) else None


def _plugin_registrant_field(p: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    plat = p.split("/")[0]
    m = {
        "what": f"Generated registrant Flutter plugins ({plat}) — подключает native plugins embedder.",
        "why": "Flutter tooling генерирует этот файл; без него plugins не подключатся.",
        "contains": "Auto-generated код регистрации plugins.",
        "responsibilities": "Подключить Flutter plugins к native runner.",
        "when": "Plugin missing после `flutter pub get` / clean build.",
        "connected": "Flutter tooling, `pubspec.yaml` plugins.",
        "layer": "Generated platform glue.",
    }
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=8) else None


def _platform_file_field(p: str, name: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    """Defer to generic file adapter — avoids banned legacy platform filler phrases."""
    return None


def _platform_native_file_field(p: str, name: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    plat = p.split("/")[0]
    plat_ru = {
        "android": "Android",
        "ios": "iOS",
        "web": "Web",
        "windows": "Windows",
        "linux": "Linux",
        "macos": "macOS",
    }.get(plat, plat)
    if name == ".gitignore":
        m = {
            "what": f"Git ignore для `{plat}/` — не коммитить локальный build-мусор платформы.",
            "why": f"Gradle/Xcode/CMake генерируют файлы в `{plat}/`, которые не должны попадать в git.",
            "contains": f"Ignore patterns для build cache и IDE metadata в `{plat}/`.",
            "responsibilities": f"Держать `{plat}/` tree чистым от generated artifacts.",
            "when": f"Случайно добавили build output `{plat}/` в git.",
            "connected": f"`{plat}/`, `.gitignore` в root.",
            "layer": f"Git hygiene {plat_ru} — не runtime.",
        }
    elif name == "info.plist":
        m = {
            "what": f"Файл Info.plist bundle {plat_ru} Runner — разрешения, bundle id и display name.",
            "why": f"Apple OS читает plist для metadata приложения и permission prompts.",
            "contains": "Ключи CFBundle, usage descriptions (микрофон и др.).",
            "responsibilities": f"Идентичность app и permission strings на {plat_ru}.",
            "when": f"Неверное имя app или permission prompt на {plat_ru}.",
            "connected": f"`{plat}/Runner/`, Xcode project.",
            "layer": f"{plat_ru} bundle metadata — не Dart.",
        }
    elif name == "gradle.properties":
        m = {
            "what": "Свойства Gradle Android — JVM args, AndroidX flags и версии toolchain.",
            "why": "Gradle читает defaults отсюда до сборки `:app` module.",
            "contains": "Строки key=value; часто local SDK path в gitignore.",
            "responsibilities": "Общие Gradle/Android build settings для Counter.",
            "when": "Gradle sync fail, JVM OOM, AndroidX migration warnings.",
            "connected": "`android/settings.gradle.kts`, `android/app/`.",
            "layer": "Android Gradle config — не Dart.",
        }
    elif name == "proguard-rules.pro":
        m = {
            "what": "Правила ProGuard/R8 keep для Android release minification.",
            "why": "R8/ProGuard не должен вырезать Flutter/plugin classes в release APK.",
            "contains": "Правила keep для Flutter embedding и plugins.",
            "responsibilities": "Предотвратить crash release APK от over-shrinking.",
            "when": "Release APK падает после включения minify/shrink.",
            "connected": "`android/app/build.gradle.kts`.",
            "layer": "Android release shrink — не Dart.",
        }
    elif name == "google-services.json":
        m = {
            "what": "Заглушка конфига Firebase/Google services для Android Gradle plugin.",
            "why": "Некоторые Gradle setups ожидают файл даже без Firebase features.",
            "contains": "JSON project ids (без секретов в repo copy).",
            "responsibilities": "Удовлетворить google-services plugin если включён.",
            "when": "Gradle ищет google-services.json при sync/build.",
            "connected": "`android/app/build.gradle.kts`.",
            "layer": "Android Gradle config — не Dart UI.",
        }
    elif name == "index.html":
        m = {
            "what": "HTML-оболочка web — загружает скомпилированный Flutter web app.",
            "why": "Браузеру нужен entry с base href `/Counter/` для GitHub Pages.",
            "contains": "Теги script для `flutter.js` и base href `/Counter/`.",
            "responsibilities": "Запустить Flutter web engine в браузере.",
            "when": "Пустая страница после web deploy.",
            "connected": "`flutter build web`, `docs/DEPLOY.md`.",
            "layer": "Web platform entry — не Dart business logic.",
        }
    elif name == "manifest.json":
        m = {
            "what": "Web app manifest — имя, theme color, пути иконок PWA.",
            "why": "Браузер использует manifest для install prompt и tab theming.",
            "contains": "JSON с массивом icons и режимом display для PWA.",
            "responsibilities": "PWA metadata для GitHub Pages сайта.",
            "when": "PWA install prompt или theme color неверны на web.",
            "connected": "`web/icons/`, `web/index.html`.",
            "layer": "Web PWA config — не Dart.",
        }
    elif name in ("favicon.png", "ic_launcher.png") or (name.startswith("icon-") and name.endswith(".png")):
        m = {
            "what": f"PNG-иконка web/{plat_ru} — tab icon или PWA asset `{name}`.",
            "why": "Браузер и manifest ссылаются на этот PNG после `flutter build web`.",
            "contains": f"Растровый PNG `{name}`.",
            "responsibilities": f"Показать иконку Counter в UI браузера/PWA.",
            "when": f"Пропала иконка вкладки или PWA tile для `{name}`.",
            "connected": "`web/manifest.json`, `web/index.html`.",
            "layer": "Web asset — не Dart.",
        }
    elif name == "counter.iss":
        m = {
            "what": "Inno Setup script — рецепт сборки installer `CounterSetup.exe`.",
            "why": "Упаковывает Flutter Windows build + STT helper + icons в setup wizard.",
            "contains": "Правила копирования файлов, shortcuts, optional autostart.",
            "responsibilities": "Шаги installer и layout установленных файлов.",
            "when": "Installer не копирует файлы или неверный install path на Windows.",
            "connected": "`prepare_stt_payload.ps1`, GitHub Actions workflow.",
            "layer": "Windows installer config — не runtime.",
        }
    elif name == "env.dart.example":
        m = {
            "what": "Шаблон compile-time secrets — копировать в `env.dart` (файл в gitignore).",
            "why": "Разработчикам нужны локальные env-константы без commit секретов в git.",
            "contains": "Пример ключей с placeholder values для локальной сборки.",
            "responsibilities": "Документирует обязательную форму `env.dart`.",
            "when": "Новый разработчик не знает какие ключи нужны в `env.dart`.",
            "connected": "`lib/core/env/env.dart`, `docs/DEPLOY.md`.",
            "layer": "Dev template — не runtime без копирования в `env.dart`.",
        }
    elif name.endswith(".mdc") and ".cursor/rules" in p:
        m = {
            "what": "Always-applied правила Cursor Agent для Flutter/PocketBase архитектуры Counter.",
            "why": "Cursor подхватывает iron laws: optimistic UI, Brain/UI split, main-thread law.",
            "contains": "Markdown-правила Cursor: PocketBase IDs, запрет spam polling, законы структуры.",
            "responsibilities": "Удерживать AI codegen в рамках governing docs.",
            "when": "AI предлагает refactor, ломающий architecture guard или Brain.",
            "connected": "`.cursorrules`, `docs/ARCHITECTURE.md`.",
            "layer": "IDE agent rules — не runtime приложения.",
        }
    elif name.endswith(".pb.js"):
        hook = name.replace(".pb.js", "")
        m = {
            "what": f"PocketBase hook `{hook}` — серверная логика при API-событиях на VPS.",
            "why": "Часть правил (reset пароля, overlap записей) должна выполняться на сервере, не в APK.",
            "contains": f"JavaScript handler `{name}` — копируется в PocketBase `pb_hooks/` на VPS.",
            "responsibilities": f"Серверная логика для `{hook}` (см. `docs/POCKETBASE_MANIFEST.md`).",
            "when": f"Поведение auth/records на сервере не совпадает с ожиданиями приложения.",
            "connected": "PocketBase Admin, Flutter auth/records client.",
            "layer": "Server hook — не в бинарнике приложения.",
        }
    else:
        return None
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=6) else None


def _script_file_field(p: str, name: str, field: str, en_val: str, en: dict[str, str]) -> str | None:
    m = {
        "what": f"Dev/CI скрипт `{name}` — повторяемая команда из repo docs.",
        "why": "Автоматизирует deploy, audit или maintenance без ad-hoc notes.",
        "contains": f"Команды PowerShell/Python/Dart в `{name}`.",
        "responsibilities": f"Workflow, описанный в header или `docs/DEPLOY.md`.",
            "when": f"Owner или CI запускает `{name}` по инструкции в repo docs.",
        "connected": "`scripts/manual/`, `docs/DEPLOY.md`.",
        "layer": "Dev/CI script — не runtime приложения.",
    }
    v = m.get(field)
    return v if v and ru_prose_ok(v, min_cyrillic=8) else None
