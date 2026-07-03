# APP_STRUCTURE_DETAILED

Owner-readable guide: every tracked folder and file in plain language (EN + RU).

**Generated at git SHA `5dc9b6c` on 2026-07-03.**

Concise map: [`APP_STRUCTURE.md`](APP_STRUCTURE.md) · Upload checklist: [`PROJECT_KNOWLEDGE_PACK.md`](PROJECT_KNOWLEDGE_PACK.md)

Regenerate after tree changes:

```powershell
python scripts/manual/generate_app_structure_detailed.py
```

---

## How to read this document

Each **folder** section explains why that part of the repo exists. Each **file** section is unique — if two files did the same job, one of them would not belong in the repo.

---

## Folder: `.cursor/`

EN:

- **What this folder is:** Cursor IDE project rules for AI assistants in this repo.
- **Why it exists:** Ensures Cursor agents follow Flutter/PocketBase iron laws.
- **What lives here:** `.cursor/rules/flutter_expert.mdc`.
- **What part of the app it affects:** AI coding sessions in Cursor only — not app runtime.
- **When to open it:** Cursor agent ignores architecture rules.
- **Can it be deleted?** Maybe — safe for app; keep for Cursor workflow.
- **Main related paths:** `.cursorrules` pointer at repo root.

RU:

- **Что это за папка:** Правила Cursor IDE для этого repo — куда смотреть AI-ассистентам и какие архитектурные законы соблюдать.
- **Зачем нужна:** Cursor подхватывает `.cursorrules` и файлы здесь, чтобы не предлагать запрещённые PocketBase/optimistic UI ходы.
- **Что здесь лежит:** Файлы правил Cursor, включая `rules/flutter_expert.mdc`.
- **На что влияет в приложении:** Подсказки AI в Cursor — не runtime приложения.
- **Когда открывать:** AI предлагает refactor, ломающий Brain/UI split или main-thread law.
- **Можно удалить?** Возможно — безопасно для app; оставить для Cursor workflow.
- **Связанные пути:** `.cursorrules`, `docs/ARCHITECTURE.md`.

---

## Folder: `.github/`

EN:

- **What this folder is:** GitHub automation folder — CI workflows that publish the web site and build the Windows installer.
- **Why it exists:** Robots run here after git push: one workflow deploys GitHub Pages, another builds `CounterSetup.exe`.
- **What lives here:** `workflows/deploy.yml`, `workflows/windows-desktop-build.yml`, `copilot-instructions.md`.
- **What part of the app it affects:** Live site at GitHub Pages and Windows installer artifact — not in-app screens.
- **When to open it:** CI deploy failed, site not updating, Windows installer artifact missing.
- **Can it be deleted?** No — if GitHub Pages deploy and Windows installer artifacts are required.
- **Main related paths:** `update.ps1`, `docs/DEPLOY.md`.

RU:

- **Что это за папка:** Папка автоматизации GitHub. Здесь workflow-файлы: один публикует web build на GitHub Pages после push, другой собирает Windows installer artifact.
- **Зачем нужна:** Это не экран приложения, а роботы сборки и публикации.
- **Что здесь лежит:** Workflow-файлы: `deploy.yml`, `windows-desktop-build.yml`, `copilot-instructions.md`.
- **На что влияет в приложении:** Живой сайт и артефакт Windows installer.
- **Когда открывать:** CI deploy упал, сайт не обновился, нет CounterSetup.exe в Actions.
- **Можно удалить?** Нет — если нужны GitHub Pages и Windows installer.
- **Связанные пути:** `update.ps1`, `docs/DEPLOY.md`.

---

## Folder: `android/`

EN:

- **What this folder is:** Android wrapper — tells Android how to build the APK, permissions, icons, Google services file.
- **Why it exists:** Flutter needs native Android project files to produce installable APK/AAB.
- **What lives here:** Gradle scripts, `AndroidManifest.xml`, Kotlin/Java plugin registrant.
- **What part of the app it affects:** Android phone/tablet/Wear builds only.
- **When to open it:** APK build fails, permission denied, package name, Gradle errors.
- **Can it be deleted?** No — if Android APK support is required.
- **Main related paths:** `android.ps1`, `.github/workflows/`.

RU:

- **Что это за папка:** Android-обёртка — Gradle, `AndroidManifest`, permissions (mic, notifications), launcher icons, Kotlin entry.
- **Зачем нужна:** Flutter собирает устанавливаемый APK/AAB из native Android project.
- **Что здесь лежит:** Gradle, manifest, Kotlin entry, иконки и splash в `res/`.
- **На что влияет в приложении:** Сборка и установка только на Android (телефон, планшет, Wear).
- **Когда открывать:** APK build fail, permission denied, package name, Gradle errors.
- **Можно удалить?** Нет — если нужна поддержка Android APK.
- **Связанные пути:** `android.ps1`, `.github/workflows/`.

---

## Folder: `docs/`

EN:

- **What this folder is:** Written project law — architecture, data fields, design system, roadmap, deploy steps.
- **Why it exists:** Owner and AI assistants need one place for “how the app must behave” beyond code.
- **What lives here:** Governing specs, Project Knowledge pack, reports, website copy (`docs/website/`).
- **What part of the app it affects:** Development decisions, AI context, website planning — not runtime binary.
- **When to open it:** Any structural or behavior question; upload list in `PROJECT_KNOWLEDGE_PACK.md`.
- **Can it be deleted?** No — governing/current documentation.
- **Main related paths:** 14-doc Project Knowledge pack, `CHANGELOG.md`.

RU:

- **Что это за папка:** Письменные правила проекта — architecture, DATA_MAP, design system, roadmap, deploy.
- **Зачем нужна:** Owner и AI нужен источник «как должно работать» помимо кода.
- **Что здесь лежит:** Governing specs, Project Knowledge pack list, reports, `docs/website/` copy.
- **На что влияет в приложении:** Решения при разработке и AI context — не runtime binary.
- **Когда открывать:** Любой structural/behavior вопрос; upload list в `PROJECT_KNOWLEDGE_PACK.md`.
- **Можно удалить?** Нет — governing-документация проекта.
- **Связанные пути:** 14-doc Project Knowledge pack, `CHANGELOG.md`.

---

## Folder: `installer/`

EN:

- **What this folder is:** Windows installer packaging — builds `CounterSetup.exe` users can run to install the app.
- **Why it exists:** Flutter build alone is a folder of files; installer bundles app + STT helper + icons.
- **What lives here:** Inno Setup script (`counter.iss`), STT payload prep scripts, optional helper build.
- **What part of the app it affects:** Windows distribution via GitHub Actions artifact.
- **When to open it:** Installer missing files, STT helper not bundled, SmartScreen packaging.
- **Can it be deleted?** No — while Windows installer distribution is needed.
- **Main related paths:** `.github/workflows/windows-desktop-build.yml`, `docs/DEPLOY.md`.

RU:

- **Что это за папка:** Сборка Windows-установщика `CounterSetup.exe` — упаковка Release build + STT helper + icons.
- **Зачем нужна:** Flutter build — папка файлов; installer даёт один setup wizard пользователю.
- **Что здесь лежит:** Inno Setup `counter.iss`, STT payload scripts, helper build.
- **На что влияет в приложении:** Дистрибуция Windows через artifact GitHub Actions.
- **Когда открывать:** Installer missing files, STT helper не bundled, SmartScreen packaging.
- **Можно удалить?** Нет — пока нужен Windows installer.
- **Связанные пути:** `.github/workflows/windows-desktop-build.yml`, `docs/DEPLOY.md`.

---

## Folder: `integration_test/`

EN:

- **What this folder is:** On-device integration tests — full app flows on emulator/phone.
- **Why it exists:** Catches issues unit tests miss (navigation, real widgets).
- **What lives here:** Dart integration test entry files.
- **What part of the app it affects:** Quality gate only — not shipped to users.
- **When to open it:** Adding end-to-end test before release.
- **Can it be deleted?** No — required for integration testing.
- **Main related paths:** `test/` unit tests.

RU:

- **Что это за папка:** Integration-тесты Flutter на устройстве/эмуляторе — полные сценарии медленнее widget tests.
- **Зачем нужна:** Ловят login shell, tab navigation и flows, которые unit-тесты не покрывают.
- **Что здесь лежит:** Dart integration test drivers и сценарии.
- **На что влияет в приложении:** CI/integration QA — не APK пользователю.
- **Когда открывать:** Падает integration test или меняется shell navigation.
- **Можно удалить?** Нет — нужен для integration-тестов.
- **Связанные пути:** `test/`, `lib/shell/`.

---

## Folder: `ios/`

EN:

- **What this folder is:** iOS wrapper — Xcode project for iPhone/iPad builds.
- **Why it exists:** Apple requires this structure for App Store or TestFlight builds.
- **What lives here:** Xcode project, Info.plist, asset catalogs, Flutter iOS embedder.
- **What part of the app it affects:** iOS builds only.
- **When to open it:** iOS compile/signing issues, permissions, icons.
- **Can it be deleted?** No — if iOS builds are required.
- **Main related paths:** `lib/`, Flutter tooling.

RU:

- **Что это за папка:** iOS-обёртка — Xcode-проект, Info.plist, assets, Flutter iOS embedder для iPhone/iPad.
- **Зачем нужна:** Apple требует эту структуру для TestFlight и App Store.
- **Что здесь лежит:** Xcode-проект, Info.plist, asset catalogs, Runner target.
- **На что влияет в приложении:** Только iOS builds.
- **Когда открывать:** iOS compile/signing, permissions, icons.
- **Можно удалить?** Нет — если нужна сборка iOS.
- **Связанные пути:** `lib/`, Flutter tooling.

---

## Folder: `lib/`

EN:

- **What this folder is:** The Flutter application itself — screens, navigation, cards, buttons, data brain, PocketBase sync, offline queue, localization, shared UI.
- **Why it exists:** Everything users see and everything that saves data lives here; without `lib/` there is no app.
- **What lives here:** `lib/data/` brain · `lib/features/` screens · `lib/core/` design system · `lib/shell/` navigation · `lib/l10n/` texts · `lib/services/` device notifications.
- **What part of the app it affects:** The entire product on Android, iOS, web, Windows, Wear.
- **When to open it:** Almost any product bug, UI change, or PocketBase behavior fix.
- **Can it be deleted?** No — deleting `lib/` removes the application.
- **Main related paths:** `pubspec.yaml`, `main.dart`, platform folders.

RU:

- **Что это за папка:** Это само Flutter-приложение. Здесь живут экраны, навигация, карточки, кнопки, мозг данных, PocketBase-синхронизация, offline queue, локализация и общие UI-компоненты.
- **Зачем нужна:** Если удалить `lib`, приложения больше нет — весь продукт собран из этой папки.
- **Что здесь лежит:** `lib/data/` — мозг (PocketBase, cache, optimistic UI, offline). `lib/features/` — экраны Timeline, Plans, Lists, Calendar, Profile, Categories. `lib/core/` — design system, тема, time, desktop voice. `lib/shell/` — вкладки, More, edit sheets, offline banner. `lib/l10n/` — тексты UI. `lib/services/` — уведомления устройства.
- **На что влияет в приложении:** Весь продукт на всех платформах.
- **Когда открывать:** Любой баг UI, сохранение данных, offline, локализация.
- **Можно удалить?** Нет — deleting `lib/` removes the application.
- **Связанные пути:** `pubspec.yaml`, `main.dart`, platform-папки.

---

## Folder: `linux/`

EN:

- **What this folder is:** Linux desktop Flutter embedder — CMake project to build Counter on Linux.
- **Why it exists:** Flutter requires native runner sources for Linux desktop target.
- **What lives here:** Top-level `CMakeLists.txt`, `flutter/` generated glue, `runner/` GTK entry.
- **What part of the app it affects:** Linux desktop builds only — not Android/iOS/web.
- **When to open it:** Linux desktop compile fails, GTK runner errors.
- **Can it be deleted?** No — if Linux desktop support is kept.
- **Main related paths:** `windows/`, `macos/` sibling desktop folders.

RU:

- **Что это за папка:** Linux desktop embedder — CMake-проект для сборки Counter на Linux через GTK runner.
- **Зачем нужна:** Flutter нужны native runner sources для Linux desktop target.
- **Что здесь лежит:** Корневой `CMakeLists.txt`, generated glue в `flutter/`, GTK entry в `runner/`.
- **На что влияет в приложении:** Только Linux desktop builds — не Android/iOS/web.
- **Когда открывать:** Падает Linux desktop compile, ошибки GTK runner.
- **Можно удалить?** Нет — если нужна поддержка Linux desktop.
- **Связанные пути:** `windows/`, `macos/` — sibling desktop folders.

---

## Folder: `macos/`

EN:

- **What this folder is:** macOS desktop Flutter/Xcode project — builds Counter `.app` on Apple Silicon/Intel Mac.
- **Why it exists:** Apple desktop builds need Xcode target, entitlements, and Flutter macOS embedder.
- **What lives here:** `Runner/`, `Flutter/` generated configs, `Runner.xcodeproj`.
- **What part of the app it affects:** macOS desktop distribution only.
- **When to open it:** macOS signing, sandbox entitlements, menu bar, desktop build errors.
- **Can it be deleted?** No — if macOS desktop support is kept.
- **Main related paths:** `ios/` (mobile Apple) vs this desktop target.

RU:

- **Что это за папка:** macOS desktop Flutter/Xcode-проект — собирает Counter `.app` на Apple Silicon/Intel Mac.
- **Зачем нужна:** Apple desktop builds нуждаются в Xcode target, entitlements и Flutter macOS embedder.
- **Что здесь лежит:** `Runner/`, generated configs в `Flutter/`, `Runner.xcodeproj`.
- **На что влияет в приложении:** Только сборка и распространение macOS desktop `.app`.
- **Когда открывать:** macOS signing, sandbox entitlements, menu bar, ошибки desktop build.
- **Можно удалить?** Нет — если нужна поддержка macOS desktop.
- **Связанные пути:** `ios/` (mobile Apple) vs этот desktop target.

---

## Folder: `pb_hooks/`

EN:

- **What this folder is:** JavaScript hooks copied to the PocketBase server — rules that run on the VPS, not in the phone app.
- **Why it exists:** Server enforces password-reset flow and prevents overlapping running records.
- **What lives here:** Two hook files (auth reset, record interval sanitize).
- **What part of the app it affects:** Forgot-password email flow; server-side record overlap cleanup.
- **When to open it:** Password reset fails server-side; duplicate running records on server.
- **Can it be deleted?** No — production PocketBase expects these hooks per manifest.
- **Main related paths:** `docs/POCKETBASE_MANIFEST.md`, `docs/DEPLOY.md` auth admin section.

RU:

- **Что это за папка:** JS hooks для PocketBase на VPS — правила сервера, не код в телефоне.
- **Зачем нужна:** Сервер проводит password reset и sanitize overlapping records.
- **Что здесь лежит:** Два hook-файла (auth reset, record interval sanitize).
- **На что влияет в приложении:** Forgot-password email на сервере; server-side cleanup пересекающихся running records.
- **Когда открывать:** Password reset fail server-side; duplicate running records на сервере.
- **Можно удалить?** Нет — production PocketBase ожидает эти hooks.
- **Связанные пути:** `docs/POCKETBASE_MANIFEST.md`, `docs/DEPLOY.md` auth admin.

---

## Folder: `scripts/`

EN:

- **What this folder is:** Developer and CI scripts — deploy, audits, locale sync, structure docs, desktop voice smoke tests.
- **Why it exists:** Repeatable commands so builds and doc checks don’t rely on memory.
- **What lives here:** `audit/`, `manual/`, `sync_locales.dart`.
- **What part of the app it affects:** Deploy pipeline, architecture guard, this detailed structure doc regeneration.
- **When to open it:** Deploy web site, run strict guard, regenerate structure map, voice smoke on Windows.
- **Can it be deleted?** No — required for deploy/audit/doc workflows documented in repo.
- **Main related paths:** `update.ps1`, `docs/DEPLOY.md`, `docs/APP_STRUCTURE.md` §6.

RU:

- **Что это за папка:** Скрипты dev/CI — deploy, audit guard, sync локалей, генерация structure doc, smoke desktop voice.
- **Зачем нужна:** Повторяемые команды вместо ad-hoc notes.
- **Что здесь лежит:** Папки скриптов: `audit/`, `manual/`, плюс `sync_locales.dart`.
- **На что влияет в приложении:** Deploy, architecture guard и regeneration structure doc — не UI приложения.
- **Когда открывать:** Deploy сайта, strict guard, regenerate structure map, voice smoke Windows.
- **Можно удалить?** Нет — нужен для deploy/audit/doc workflows documented in repo.
- **Связанные пути:** `update.ps1`, `docs/DEPLOY.md`, `docs/APP_STRUCTURE.md` §6.

---

## Folder: `test/`

EN:

- **What this folder is:** Automated tests run by `flutter test` — guards regressions without manual clicking.
- **Why it exists:** Catches broken voice parse, timezone, plan cards, perf contracts before release.
- **What lives here:** Widget tests, domain unit tests, perf diagnostic tests.
- **What part of the app it affects:** CI quality gate; not shipped to users.
- **When to open it:** Adding/changing behavior that must stay stable; CI failures.
- **Can it be deleted?** No — required for tests.
- **Main related paths:** Production files with matching names under `lib/`.

RU:

- **Что это за папка:** Автотесты `flutter test` — регрессии без ручного UI.
- **Зачем нужна:** Ловят voice parse, timezone, plan cards, perf contracts до релиза.
- **Что здесь лежит:** Widget-, domain- и perf-тесты — файлы `*_test.dart` ниже.
- **На что влияет в приложении:** CI quality gate — не в APK пользователю.
- **Когда открывать:** Добавление/изменение поведения; падение CI.
- **Можно удалить?** Нет — нужен для тестов.
- **Связанные пути:** Production files под `lib/` с похожими именами.

---

## Folder: `web/`

EN:

- **What this folder is:** Web shell — `index.html`, PWA manifest, icons for GitHub Pages site.
- **Why it exists:** Browser version loads Flutter web build; base href `/Counter/` for GitHub Pages.
- **What lives here:** HTML entry, favicon, web icons.
- **What part of the app it affects:** https://nkuchenov-hash.github.io/Counter/
- **When to open it:** Web deploy blank page, wrong base href, missing icons.
- **Can it be deleted?** No — web deploy breaks.
- **Main related paths:** `docs/DEPLOY.md`, `.github/workflows/deploy.yml`.

RU:

- **Что это за папка:** Web-оболочка — `index.html`, PWA manifest, favicon/icons; base href `/Counter/` для GitHub Pages.
- **Зачем нужна:** Браузер грузит Flutter web build; GitHub Pages живёт под `/Counter/`.
- **Что здесь лежит:** Точка входа браузера, favicon, каталог `icons/`, `manifest.json`.
- **На что влияет в приложении:** Публичный web-сайт: https://nkuchenov-hash.github.io/Counter/
- **Когда открывать:** Blank page после deploy, wrong base href, missing icons.
- **Можно удалить?** Нет — web deploy breaks.
- **Связанные пути:** `docs/DEPLOY.md`, `.github/workflows/deploy.yml`.

---

## Folder: `windows/`

EN:

- **What this folder is:** Windows desktop runner — native `.exe` host for Flutter on Windows.
- **Why it exists:** Desktop voice, tray, hotkey, and installer packaging need Windows embedder.
- **What lives here:** CMake project, runner main, plugin registration.
- **What part of the app it affects:** Windows desktop app and `CounterSetup.exe` contents.
- **When to open it:** Windows build fails, desktop voice/tray issues at OS level.
- **Can it be deleted?** No — if Windows desktop is supported.
- **Main related paths:** `installer/windows/`, `docs/DEPLOY.md` Windows section.

RU:

- **Что это за папка:** Windows desktop runner — native `.exe`, Flutter engine, desktop voice/tray/hotkey; связь с installer.
- **Зачем нужна:** Desktop voice и `CounterSetup.exe` упаковка нуждаются в Windows embedder.
- **Что здесь лежит:** CMake-проект, runner main, plugin registration, иконка `.ico`.
- **На что влияет в приложении:** Windows desktop app и содержимое installer.
- **Когда открывать:** Windows build fail, desktop voice/tray на уровне OS.
- **Можно удалить?** Нет — если поддерживается Windows desktop.
- **Связанные пути:** `installer/windows/`, `docs/DEPLOY.md`.

---

## Folder: `.cursor/rules/`

EN:

- **What this folder is:** Cursor IDE project rules for AI assistants in this repo.
- **Why it exists:** Ensures Cursor agents follow Flutter/PocketBase iron laws.
- **What lives here:** `.cursor/rules/flutter_expert.mdc`.
- **What part of the app it affects:** AI coding sessions in Cursor only — not app runtime.
- **When to open it:** Cursor agent ignores architecture rules.
- **Can it be deleted?** Maybe — safe for app; keep for Cursor workflow.
- **Main related paths:** `.cursorrules` pointer at repo root.

RU:

- **Что это за папка:** Markdown-правила для Cursor Agent: Flutter-архитектура, PocketBase, optimistic UI и запрет spam polling.
- **Зачем нужна:** Always-applied rules для codegen в Cursor; дополняют governing docs.
- **Что здесь лежит:** `flutter_expert.mdc` и другие rule-файлы.
- **На что влияет в приложении:** Качество AI-патчей — не APK пользователю.
- **Когда открывать:** Обновили архитектурный закон и нужно, чтобы AI его видел сразу.
- **Можно удалить?** Возможно — безопасно для app; оставить для Cursor workflow.
- **Связанные пути:** `.cursorrules`, `docs/ARCHITECTURE.md`.

---

## Folder: `.github/workflows/`

EN:

- **What this folder is:** GitHub Actions job definitions — web deploy and Windows installer CI.
- **Why it exists:** Automates publishing site and building `CounterSetup.exe` without manual steps.
- **What lives here:** `deploy.yml`, `windows-desktop-build.yml`.
- **What part of the app it affects:** Live GitHub Pages site and release artifacts.
- **When to open it:** CI deploy failed, installer artifact missing.
- **Can it be deleted?** No — required for CI/deploy.
- **Main related paths:** `docs/DEPLOY.md`, `update.ps1`.

RU:

- **Что это за папка:** YAML workflow GitHub Actions — автоматическая сборка web и Windows installer после push.
- **Зачем нужна:** Без них deploy на GitHub Pages и артеfact `CounterSetup.exe` не собираются на сервере GitHub.
- **Что здесь лежит:** YAML workflows: `deploy.yml` (GitHub Pages) и `windows-desktop-build.yml` (installer).
- **На что влияет в приложении:** Живой сайт `/Counter/` и Windows installer artifact в Actions.
- **Когда открывать:** Deploy упал, сайт не обновился, нет exe в Actions artifacts.
- **Можно удалить?** Нет — нужен для CI и деплоя.
- **Связанные пути:** `update.ps1`, `docs/DEPLOY.md`.

---

## Folder: `android/app/`

EN:

- **What this folder is:** Android application module — the actual Counter APK target.
- **Why it exists:** Separates app config from root Gradle project settings.
- **What lives here:** build.gradle, src/, google-services if present.
- **What part of the app it affects:** Android build output APK/AAB.
- **When to open it:** Gradle app module errors, package name, signing.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `android/` root Gradle.

RU:

- **Что это за папка:** Модуль Android-приложения Counter — из него Gradle собирает APK/AAB.
- **Зачем нужна:** Отделяет настройки приложения от корневого Gradle-проекта `android/`.
- **Что здесь лежит:** `build.gradle`, каталог `src/`, при необходимости `google-services.json`.
- **На что влияет в приложении:** Результат сборки — APK или AAB Counter для установки.
- **Когда открывать:** Ошибки Gradle-модуля app, package name, подпись release.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `android/build.gradle.kts`, `android/settings.gradle.kts`.

---

## Folder: `android/gradle/`

EN:

- **What this folder is:** Gradle wrapper and version catalog for Android builds.
- **Why it exists:** Pins Gradle version so builds are reproducible on CI and your PC.
- **What lives here:** Wrapper jar/properties, plugin versions.
- **What part of the app it affects:** Android build toolchain only.
- **When to open it:** Gradle version mismatch errors.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `android/settings.gradle`.

RU:

- **Что это за папка:** Gradle wrapper и каталог версий плагинов для Android-сборки.
- **Зачем нужна:** Фиксирует версию Gradle, чтобы сборка на CI и локально была одинаковой.
- **Что здесь лежит:** Wrapper jar/properties и версии Gradle-плагинов.
- **На что влияет в приложении:** Только toolchain Android-сборки — не Dart UI.
- **Когда открывать:** Ошибки несовпадения версии Gradle.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `android/settings.gradle.kts`.

---

## Folder: `docs/reports/`

EN:

- **What this folder is:** Point-in-time audit and cleanup reports (not governing law).
- **Why it exists:** Records why files were deleted or docs reorganized.
- **What lives here:** Structure parity, design inventory, necessity cleanup reports.
- **What part of the app it affects:** Historical context for owner/AI — not runtime.
- **When to open it:** Understanding past cleanup decisions.
- **Can it be deleted?** No — current reports referenced from CHANGELOG.
- **Main related paths:** `CHANGELOG.md`, governing docs in `docs/`.

RU:

- **Что это за папка:** Отчёты аудита, cleanup и design inventory — история решений, не governing law.
- **Зачем нужна:** Фиксируют findings April 2026 audit, parity checks, design system inventory.
- **Что здесь лежит:** Отчёты audit/cleanup: `AUDIT_NOTES.md`, `FINAL_*`, `DESIGN_SYSTEM_INVENTORY.md` и др.
- **На что влияет в приложении:** Контекст для owner/AI — не runtime.
- **Когда открывать:** Нужно понять, почему roadmap/guard rule существует.
- **Можно удалить?** Нет — current reports referenced from CHANGELOG.
- **Связанные пути:** `docs/ROADMAP.md`, `CHANGELOG.md`.

---

## Folder: `docs/website/`

EN:

- **What this folder is:** Marketing and internal website copy — not loaded by the Flutter app.
- **Why it exists:** Planning public site text separately from app strings.
- **What lives here:** Markdown notes for future site pages.
- **What part of the app it affects:** Website planning only.
- **When to open it:** Updating public site messaging.
- **Can it be deleted?** No — intentionally maintained repo-only copy.
- **Main related paths:** `docs/DEPLOY.md` GitHub Pages.

RU:

- **Что это за папка:** Маркетинговые тексты будущего/текущего сайта — repo-only, не Project Knowledge pack.
- **Зачем нужна:** Owner правит landing copy отдельно от governing 14-doc pack.
- **Что здесь лежит:** Markdown страниц сайта и internal notes (repo-only).
- **На что влияет в приложении:** Планирование публичного сайта — не Flutter binary.
- **Когда открывать:** Обновление marketing copy или internal site notes.
- **Можно удалить?** Нет — intentionally maintained repo-only copy.
- **Связанные пути:** `docs/DEPLOY.md`, GitHub Pages.

---

## Folder: `installer/windows/`

EN:

- **What this folder is:** Scripts and Inno Setup rules for the Windows setup `.exe`.
- **Why it exists:** Automates copying Release build, speech helper, and whisper model into install package.
- **What lives here:** `counter.iss`, `prepare_stt_payload.ps1`, helper build scripts.
- **What part of the app it affects:** CI `CounterSetup` artifact and local installer builds.
- **When to open it:** Installer build broken, missing STT on installed app.
- **Can it be deleted?** No — required for Windows installer.
- **Main related paths:** `flutter build windows`, GitHub Actions workflow.

RU:

- **Что это за папка:** Inno Setup и PowerShell для Windows setup `.exe` — копирование Release + speech helper.
- **Зачем нужна:** Автоматизирует упаковку `flutter build windows` + GOLOS STT в install package.
- **Что здесь лежит:** Inno Setup `counter.iss`, `prepare_stt_payload.ps1` и helper build scripts.
- **На что влияет в приложении:** CI artifact `CounterSetup` и локальные installer builds.
- **Когда открывать:** Installer build broken, STT missing после install.
- **Можно удалить?** Нет — нужен для Windows installer.
- **Связанные пути:** `flutter build windows`, GitHub Actions workflow.

---

## Folder: `ios/Flutter/`

EN:

- **What this folder is:** Generated Flutter iOS embedding files.
- **Why it exists:** Flutter tool writes pod helpers and xcconfig here on build.
- **What lives here:** Generated xcconfig, pod setup.
- **What part of the app it affects:** iOS Flutter integration.
- **When to open it:** Pod install / Flutter iOS build failures.
- **Can it be deleted?** No — required for iOS build.
- **Main related paths:** `ios/Podfile`.

RU:

- **Что это за папка:** Сгенерированные Flutter-файлы embedder для iOS (xcconfig, pod helpers).
- **Зачем нужна:** Flutter tool записывает pod helpers и xcconfig сюда при `flutter build ios`.
- **Что здесь лежит:** Generated xcconfig и настройки CocoaPods.
- **На что влияет в приложении:** Интеграция Flutter engine с Xcode-проектом iOS.
- **Когда открывать:** Падение `pod install` или `flutter build ios`.
- **Можно удалить?** Нет — нужен для сборки iOS.
- **Связанные пути:** `ios/Podfile`, `ios/Runner/`.

---

## Folder: `ios/Runner/`

EN:

- **What this folder is:** iOS app target — icons, storyboards, Info.plist for iPhone/iPad.
- **Why it exists:** Xcode builds the Flutter iOS app from this target.
- **What lives here:** Assets, launch screen, native Swift/ObjC glue.
- **What part of the app it affects:** iOS App Store / TestFlight builds.
- **When to open it:** iOS permissions, icons, launch screen.
- **Can it be deleted?** No — required for iOS build.
- **Main related paths:** `ios/Flutter/`.

RU:

- **Что это за папка:** iOS target Runner — иконки, launch screen, Info.plist и native glue для Flutter.
- **Зачем нужна:** Xcode собирает iOS-приложение Counter из этого target.
- **Что здесь лежит:** Asset catalogs, launch screen, Swift/ObjC glue для Flutter.
- **На что влияет в приложении:** Сборки для TestFlight и App Store.
- **Когда открывать:** Permissions iOS, иконки, launch screen.
- **Можно удалить?** Нет — нужен для сборки iOS.
- **Связанные пути:** `ios/Flutter/`, `ios/Runner.xcodeproj`.

---

## Folder: `ios/Runner.xcodeproj/`

EN:

- **What this folder is:** Xcode project file bundle for the iOS Counter app target.
- **Why it exists:** Xcode opens this project to compile, sign, and archive the iOS IPA.
- **What lives here:** `project.pbxproj`, shared schemes, workspace metadata.
- **What part of the app it affects:** iOS App Store / TestFlight builds only.
- **When to open it:** Xcode project corruption, scheme changes, iOS signing settings.
- **Can it be deleted?** No — required for iOS build.
- **Main related paths:** `ios/Runner/`, `ios/Flutter/`.

RU:

- **Что это за папка:** Xcode-проект для iOS target Counter — compile, sign и archive IPA.
- **Зачем нужна:** Xcode открывает этот project для сборки и подписи iOS-приложения.
- **Что здесь лежит:** Файлы `project.pbxproj`, shared schemes, workspace metadata.
- **На что влияет в приложении:** Только iOS TestFlight и App Store builds.
- **Когда открывать:** Повреждение project, смена scheme, настройки signing.
- **Можно удалить?** Нет — нужен для сборки iOS.
- **Связанные пути:** `ios/Runner/`, `ios/Runner.xcworkspace`.

---

## Folder: `ios/Runner.xcworkspace/`

EN:

- **What this folder is:** Xcode workspace wrapping the iOS Runner project and CocoaPods.
- **Why it exists:** Developers open `.xcworkspace` (not `.xcodeproj` alone) after `pod install`.
- **What lives here:** Workspace data linking Runner + Pods.
- **What part of the app it affects:** Local iOS development and CI iOS builds using CocoaPods.
- **When to open it:** Xcode says open workspace; Pod integration broken.
- **Can it be deleted?** No — required for iOS CocoaPods workflow.
- **Main related paths:** `ios/Podfile`, `ios/Runner.xcodeproj`.

RU:

- **Что это за папка:** Xcode workspace для Runner и CocoaPods — открывают после `pod install`.
- **Зачем нужна:** Pods интегрируются через workspace, а не через один `.xcodeproj`.
- **Что здесь лежит:** Workspace data, связывающая Runner и Pods.
- **На что влияет в приложении:** Локальная iOS-разработка и CI с CocoaPods.
- **Когда открывать:** Xcode просит open workspace; сломана интеграция Pods.
- **Можно удалить?** Нет — нужен для CocoaPods workflow iOS.
- **Связанные пути:** `ios/Podfile`, `ios/Runner.xcodeproj`.

---

## Folder: `ios/RunnerTests/`

EN:

- **What this folder is:** Xcode unit test target for iOS Runner smoke tests.
- **Why it exists:** Apple project template includes a test target for native/iOS integration checks.
- **What lives here:** `RunnerTests.swift` — minimal XCTest entry.
- **What part of the app it affects:** iOS test target in Xcode — not the main Flutter `test/` suite.
- **When to open it:** iOS native test failures in Xcode.
- **Can it be deleted?** Maybe — Flutter CI uses `flutter test`; keep for Xcode workflow.
- **Main related paths:** `test/` Flutter tests, `ios/Runner/`.

RU:

- **Что это за папка:** Xcode unit test target для smoke-тестов iOS Runner.
- **Зачем нужна:** Шаблон Apple project включает test target для native/iOS integration checks.
- **Что здесь лежит:** `RunnerTests.swift` — минимальный XCTest entry.
- **На что влияет в приложении:** iOS test target в Xcode — не основной Flutter `test/` suite.
- **Когда открывать:** Падение native iOS-тестов в Xcode.
- **Можно удалить?** Возможно — Flutter CI uses `flutter test`; keep for Xcode workflow.
- **Связанные пути:** `test/` Flutter tests, `ios/Runner/`.

---

## Folder: `lib/core/`

EN:

- **What this folder is:** Foundation layer — theme colors, shared widgets, clock/time math, desktop voice services, diagnostics.
- **Why it exists:** Feature screens must not duplicate buttons, date headers, or voice plumbing; this is the design-system and utility base.
- **What lives here:** `theme.dart`, `core/widgets/` (AppButton, plan cards), `core/time/`, `core/services/` (desktop voice), `core/diagnostics/`.
- **What part of the app it affects:** Look and feel on every tab; desktop voice/tray; header clock/timezone; perf debug flags.
- **When to open it:** Button/card migration, timezone header wrong, desktop voice broken, theme token change.
- **Can it be deleted?** No — features import foundation code everywhere.
- **Main related paths:** `docs/DESIGN_SYSTEM.md`, `lib/features/`, `lib/data/models.dart` (types only).

RU:

- **Что это за папка:** Базовый слой: design system в коде, shared widgets, тема/цвета, time helpers, desktop voice, diagnostics.
- **Зачем нужна:** Экраны не дублируют кнопки, date header и voice — общая foundation-база.
- **Что здесь лежит:** `theme.dart`, каталог `core/widgets/`, `core/time/`, `core/services/` (desktop voice), diagnostics.
- **На что влияет в приложении:** Внешний вид всех вкладок; desktop voice/tray; часы/timezone в header; perf debug flags.
- **Когда открывать:** Миграция кнопок/карточек, неверный timezone header, сломан desktop voice, смена theme token.
- **Можно удалить?** Нет — features import foundation code everywhere.
- **Связанные пути:** `docs/DESIGN_SYSTEM.md`, `lib/features/`, `lib/data/models.dart`.

---

## Folder: `lib/data/`

EN:

- **What this folder is:** The app “brain” — everything that talks to PocketBase, holds cached data, and applies changes before the server confirms.
- **Why it exists:** Single place for save/load rules so Timeline, Plans, Lists, and Categories stay consistent and offline-safe.
- **What lives here:** Coordinator files (`*_service.dart`, `database_service.dart`) and focused `part` modules in subfolders.
- **What part of the app it affects:** Timeline records, plans, lists, categories, tags, profile settings, offline queue.
- **When to open it:** Wrong data, failed save, optimistic UI rollback, offline banner, or PocketBase field errors.
- **Can it be deleted?** No — the UI cannot work without the brain.
- **Main related paths:** `docs/DATA_MAP.md`, `docs/POCKETBASE_MANIFEST.md`, `lib/features/`.

RU:

- **Что это за папка:** «Мозг» приложения — PocketBase I/O, локальный кэш, optimistic UI и offline outboxes.
- **Зачем нужна:** Один набор правил save/load для Timeline, Plans, Lists и Categories; offline-safe.
- **Что здесь лежит:** Координаторы `*_service.dart`, `database_service.dart` и `part`-модули в subfolders.
- **На что влияет в приложении:** Записи Timeline, планы, списки, категории, теги, настройки профиля и offline queue.
- **Когда открывать:** Неверные данные, failed save, rollback optimistic UI, offline banner, ошибки полей PB.
- **Можно удалить?** Нет — the UI cannot work without the brain.
- **Связанные пути:** `docs/DATA_MAP.md`, `docs/POCKETBASE_MANIFEST.md`, `lib/features/`.

---

## Folder: `lib/features/`

EN:

- **What this folder is:** All user-facing screens — Timeline, Plans, Lists, Profile, Categories, auth, Wear, shared edit sheets.
- **Why it exists:** Separates what users see and tap from the PocketBase brain in `lib/data/`.
- **What lives here:** One folder per tab or flow: `timeline/`, `planning/`, `lists/`, `shared/`, `profile/`, etc.
- **What part of the app it affects:** Every visible part of the app except raw platform wrappers.
- **When to open it:** UI bug on a specific tab, new screen, edit sheet behavior, voice sheet layout.
- **Can it be deleted?** No — deleting this removes the entire product UI.
- **Main related paths:** `lib/shell/` (navigation host), `lib/data/` (saves/loads).

RU:

- **Что это за папка:** Видимые экраны — Timeline, Plans, Lists, Profile, Categories, auth, Wear, shared edit sheets.
- **Зачем нужна:** Отделяет UI от PocketBase-мозга в `lib/data/`.
- **Что здесь лежит:** Папка на tab/flow: `timeline/`, `planning/`, `lists/`, `shared/`, `profile/` и др.
- **На что влияет в приложении:** Вся видимая часть приложения кроме platform wrappers.
- **Когда открывать:** UI bug на вкладке, новый экран, edit sheet, voice sheet layout.
- **Можно удалить?** Нет — deleting this removes the entire product UI.
- **Связанные пути:** `lib/shell/`, `lib/data/`.

---

## Folder: `lib/l10n/`

EN:

- **What this folder is:** Translations — every button label, error message, and menu title the app shows.
- **Why it exists:** Users switch language in settings; all text must resolve through one dictionary.
- **What lives here:** `dictionary.dart` (`t()` lookup), `langs/en.dart` + `langs/ru.dart` (canonical), partial other locales.
- **What part of the app it affects:** All visible strings in every locale.
- **When to open it:** Missing translation key, wrong language text, adding a new UI label.
- **Can it be deleted?** No — app shows raw keys or crashes without l10n.
- **Main related paths:** `scripts/sync_locales.dart`, `lib/l10n/langs/HELP HOW TO UPDATE the languages`.

RU:

- **Что это за папка:** Словарь переводов — подписи кнопок, ошибки, пункты меню на всех языках.
- **Зачем нужна:** Смена языка в settings; весь текст через `t()` и locale maps.
- **Что здесь лежит:** `dictionary.dart`, `langs/en.dart`, `langs/ru.dart`, partial other locales.
- **На что влияет в приложении:** Все видимые строки UI.
- **Когда открывать:** Missing translation key, неверный текст языка, новая UI label.
- **Можно удалить?** Нет — app shows raw keys or crashes without l10n.
- **Связанные пути:** `scripts/sync_locales.dart`, HELP в `langs/`.

---

## Folder: `lib/services/`

EN:

- **What this folder is:** Device-only services that are not PocketBase — currently plan alarm notifications.
- **Why it exists:** OS notification scheduling lives outside the brain; keeps `lib/data/` free of platform notification APIs.
- **What lives here:** `notification_service.dart` — local notifications and plan alarm reschedule hooks.
- **What part of the app it affects:** Plan reminder notifications on phone/desktop.
- **When to open it:** Plan alarm not firing, notification permission issues.
- **Can it be deleted?** No — plan alarms stop working.
- **Main related paths:** `lib/data/plan_service.dart` alarm reschedule requests.

RU:

- **Что это за папка:** Сервисы устройства вне PocketBase — сейчас plan alarm notifications.
- **Зачем нужна:** OS notifications вне brain; `lib/data/` без platform notification API.
- **Что здесь лежит:** `notification_service.dart` — local notifications и plan alarm reschedule.
- **На что влияет в приложении:** Напоминания по планам на phone/desktop.
- **Когда открывать:** Plan alarm не срабатывает, permission notifications.
- **Можно удалить?** Нет — plan alarms stop working.
- **Связанные пути:** `lib/data/plan_service.dart` alarm reschedule.

---

## Folder: `lib/shell/`

EN:

- **What this folder is:** App shell — bottom tabs, desktop side nav, voice routing, edit modals, offline banner slot.
- **Why it exists:** Connects `main.dart` to feature pages and global behaviors (voice, sync banner).
- **What lives here:** Dashboard scaffold, tab IndexedStack, More menu, voice submit routing.
- **What part of the app it affects:** Navigation, global header, cross-tab voice commands.
- **When to open it:** Wrong tab, voice command routes to wrong screen, edit sheet host, offline banner.
- **Can it be deleted?** No — app navigation collapses.
- **Main related paths:** `lib/app_shell.dart`, all `lib/features/*` tabs.

RU:

- **Что это за папка:** Оболочка — нижние вкладки, desktop side nav, More menu, voice routing, edit modals, offline banner.
- **Зачем нужна:** Связывает `main.dart` с feature pages и глобальным поведением (voice, sync banner).
- **Что здесь лежит:** Dashboard scaffold, IndexedStack вкладок, More menu, voice submit routing.
- **На что влияет в приложении:** Навигация, global header, voice commands между вкладками.
- **Когда открывать:** Неверная вкладка, voice уходит не туда, edit sheet host, offline banner.
- **Можно удалить?** Нет — app navigation collapses.
- **Связанные пути:** `lib/app_shell.dart`, все `lib/features/*`.

---

## Folder: `linux/flutter/`

EN:

- **What this folder is:** Flutter-generated Linux embedder glue — plugin registrant and CMake hooks.
- **Why it exists:** Flutter tool regenerates these when `pubspec.yaml` plugins change.
- **What lives here:** `generated_plugin_registrant.*`, `generated_plugins.cmake`, child `CMakeLists.txt`.
- **What part of the app it affects:** Linux desktop plugin registration at runtime.
- **When to open it:** Linux build fails after adding/removing Flutter plugin.
- **Can it be deleted?** No — regenerated by Flutter; required for Linux build.
- **Main related paths:** `linux/CMakeLists.txt`, `flutter pub get`.

RU:

- **Что это за папка:** Сгенерированный Flutter glue для Linux embedder — registrant plugins и CMake hooks.
- **Зачем нужна:** Flutter tool перегенерирует при смене plugins в `pubspec.yaml`.
- **Что здесь лежит:** `generated_plugin_registrant.*`, `generated_plugins.cmake`, child `CMakeLists.txt`.
- **На что влияет в приложении:** Регистрация Flutter plugins на Linux desktop в runtime.
- **Когда открывать:** Linux build падает после добавления/удаления Flutter plugin.
- **Можно удалить?** Нет — генерируется Flutter; нужен для Linux-сборки.
- **Связанные пути:** `linux/CMakeLists.txt`, `linux/runner/`.

---

## Folder: `linux/runner/`

EN:

- **What this folder is:** Native Linux host for Flutter desktop on Linux.
- **Why it exists:** Linux desktop build needs GTK runner entry point.
- **What lives here:** CMake runner sources.
- **What part of the app it affects:** Linux desktop builds only.
- **When to open it:** Linux desktop compile errors.
- **Can it be deleted?** No — if Linux desktop support is kept.
- **Main related paths:** `linux/CMakeLists.txt`.

RU:

- **Что это за папка:** Native GTK host — запускает Flutter desktop окно на Linux.
- **Зачем нужна:** Linux desktop build нуждается в GTK runner entry point.
- **Что здесь лежит:** Исходники CMake runner (GTK).
- **На что влияет в приложении:** Только Linux desktop builds.
- **Когда открывать:** Ошибки compile Linux desktop.
- **Можно удалить?** Нет — если нужна поддержка Linux desktop.
- **Связанные пути:** `linux/flutter/`, `linux/CMakeLists.txt`.

---

## Folder: `macos/Flutter/`

EN:

- **What this folder is:** Generated Flutter macOS embedding configuration.
- **Why it exists:** Flutter writes pod/xcconfig glue for macOS builds.
- **What lives here:** Generated configs.
- **What part of the app it affects:** macOS Flutter integration.
- **When to open it:** macOS Flutter build failures.
- **Can it be deleted?** No — required for macOS build.
- **Main related paths:** `macos/Runner/`.

RU:

- **Что это за папка:** Сгенерированная конфигурация Flutter embedder для macOS.
- **Зачем нужна:** Flutter записывает pod/xcconfig glue для macOS-сборки.
- **Что здесь лежит:** Generated xcconfig и pod-настройки.
- **На что влияет в приложении:** Интеграция Flutter с Xcode macOS target.
- **Когда открывать:** Ошибки `flutter build macos`.
- **Можно удалить?** Нет — нужен для сборки macOS.
- **Связанные пути:** `macos/Runner/`, `macos/Podfile`.

---

## Folder: `macos/Runner/`

EN:

- **What this folder is:** macOS app bundle target — menus, icons, entitlements.
- **Why it exists:** Apple requires Xcode target for macOS Flutter apps.
- **What lives here:** Swift runner, assets, entitlements plist.
- **What part of the app it affects:** macOS desktop builds.
- **When to open it:** macOS signing, sandbox, menu bar.
- **Can it be deleted?** No — if macOS builds are kept.
- **Main related paths:** `macos/Flutter/`.

RU:

- **Что это за папка:** macOS target Runner — меню, иконки, entitlements для `.app` bundle.
- **Зачем нужна:** Apple требует Xcode target для macOS Flutter-приложения.
- **Что здесь лежит:** Swift runner, assets, entitlements plist.
- **На что влияет в приложении:** Сборка Counter `.app` на macOS desktop.
- **Когда открывать:** Подпись macOS, sandbox, menu bar.
- **Можно удалить?** Нет — если поддерживается сборка macOS.
- **Связанные пути:** `macos/Flutter/`, `macos/Runner.xcodeproj`.

---

## Folder: `macos/Runner.xcodeproj/`

EN:

- **What this folder is:** Xcode project for macOS desktop Counter `.app` target.
- **Why it exists:** macOS desktop builds compile through this Xcode project.
- **What lives here:** `project.pbxproj`, shared schemes for macOS Runner.
- **What part of the app it affects:** macOS desktop distribution builds.
- **When to open it:** macOS Xcode build/sign errors.
- **Can it be deleted?** No — required for macOS desktop build.
- **Main related paths:** `macos/Runner/`, `macos/Flutter/`.

RU:

- **Что это за папка:** Xcode-проект macOS desktop target Counter `.app`.
- **Зачем нужна:** macOS desktop builds компилируются через этот Xcode-проект.
- **Что здесь лежит:** Файлы `project.pbxproj`, shared schemes для macOS Runner.
- **На что влияет в приложении:** Сборки macOS desktop для распространения.
- **Когда открывать:** Ошибки macOS Xcode build/sign.
- **Можно удалить?** Нет — нужен для сборки macOS desktop.
- **Связанные пути:** `macos/Runner/`, `macos/Flutter/`.

---

## Folder: `macos/Runner.xcworkspace/`

EN:

- **What this folder is:** Xcode workspace for macOS Counter desktop app.
- **Why it exists:** Opens Runner + Flutter macOS pods together in Xcode.
- **What lives here:** Workspace contents and shared IDE checks.
- **What part of the app it affects:** macOS desktop development in Xcode.
- **When to open it:** Workspace won't open; CocoaPods integration on macOS.
- **Can it be deleted?** No — required for macOS Xcode workflow.
- **Main related paths:** `macos/Runner.xcodeproj`.

RU:

- **Что это за папка:** Xcode workspace для macOS desktop-приложения Counter.
- **Зачем нужна:** Открывает Runner и Flutter macOS pods вместе в Xcode.
- **Что здесь лежит:** Содержимое workspace и shared IDE checks.
- **На что влияет в приложении:** macOS desktop разработка в Xcode.
- **Когда открывать:** Workspace не открывается; сломана CocoaPods integration на macOS.
- **Можно удалить?** Нет — нужен для Xcode workflow macOS.
- **Связанные пути:** `macos/Runner.xcodeproj`.

---

## Folder: `macos/RunnerTests/`

EN:

- **What this folder is:** Xcode test target for macOS Runner.
- **Why it exists:** Template XCTest target for macOS native smoke checks.
- **What lives here:** `RunnerTests.swift`.
- **What part of the app it affects:** macOS Xcode test runs only.
- **When to open it:** macOS native unit test failures.
- **Can it be deleted?** Maybe — primary QA is `flutter test`.
- **Main related paths:** `macos/Runner/`.

RU:

- **Что это за папка:** Xcode unit test target для smoke-тестов macOS Runner.
- **Зачем нужна:** Шаблон Apple project включает test target для native macOS checks.
- **Что здесь лежит:** `RunnerTests.swift` — минимальный XCTest entry.
- **На что влияет в приложении:** macOS test target в Xcode — не основной Flutter `test/` suite.
- **Когда открывать:** Падение native macOS-тестов в Xcode.
- **Можно удалить?** Возможно — основной QA — `flutter test`.
- **Связанные пути:** `test/` Flutter tests, `macos/Runner/`.

---

## Folder: `scripts/audit/`

EN:

- **What this folder is:** Architecture guard scripts — verify repo follows structure law.
- **Why it exists:** Prevents forbidden imports and doc drift before merge.
- **What lives here:** `architecture_guard.ps1`.
- **What part of the app it affects:** Developer/CI checks only.
- **When to open it:** Before merge; after moving files under `lib/`.
- **Can it be deleted?** No — required for audit workflow.
- **Main related paths:** `docs/APP_STRUCTURE.md`.

RU:

- **Что это за папка:** Audit-скрипты — architecture guard и проверки структуры перед merge.
- **Зачем нужна:** Блокируют forbidden imports, missing docs, drift от `APP_STRUCTURE.md`.
- **Что здесь лежит:** `architecture_guard.ps1` и связанные audit helpers.
- **На что влияет в приложении:** Качество repo — не экраны приложения.
- **Когда открывать:** Перед merge или после перемещения файлов — `-Strict` guard.
- **Можно удалить?** Нет — нужен для audit workflow.
- **Связанные пути:** `docs/APP_STRUCTURE.md`, `docs/ARCHITECTURE.md`.

---

## Folder: `scripts/manual/`

EN:

- **What this folder is:** Manual maintainer scripts — deploy, structure doc generation, exports.
- **Why it exists:** Repeatable owner/developer tasks without memorizing commands.
- **What lives here:** Python/PowerShell/Dart one-offs including this generator.
- **What part of the app it affects:** Deploy, docs, optional billing export.
- **When to open it:** Regenerate structure map, run deploy, Price Reporter CSV export.
- **Can it be deleted?** No — documented workflows depend on these.
- **Main related paths:** `update.ps1`, `docs/DEPLOY.md`.

RU:

- **Что это за папка:** Ручные dev-скрипты — deploy (`td.ps1`), генерация structure doc, locale sync, smoke tests.
- **Зачем нужна:** Owner запускает их по `DEPLOY.md` и structure maintenance без запоминания длинных команд.
- **Что здесь лежит:** `generate_app_structure_detailed.py`, `td.ps1`, export/billing utilities.
- **На что влияет в приложении:** Deploy, регенерация docs и owner utilities — не runtime UI.
- **Когда открывать:** Deploy сайта, regenerate APP_STRUCTURE_DETAILED, sync locales.
- **Можно удалить?** Нет — documented workflows depend on these.
- **Связанные пути:** `update.ps1`, `docs/DEPLOY.md`.

---

## Folder: `web/icons/`

EN:

- **What this folder is:** PWA / browser tab icons for the web version.
- **Why it exists:** Browser tab and “Add to Home Screen” need sized PNG icons.
- **What lives here:** Multiple PNG sizes referenced from manifest.
- **What part of the app it affects:** Web app icon in browser.
- **When to open it:** Missing favicon after web deploy.
- **Can it be deleted?** No — required for web build.
- **Main related paths:** `web/manifest.json`, `web/index.html`.

RU:

- **Что это за папка:** PNG-иконки PWA/web — разные размеры для вкладки браузера и «Add to Home Screen».
- **Зачем нужна:** Браузер и manifest ссылаются на эти PNG после `flutter build web`.
- **Что здесь лежит:** Набор `Icon-*.png` для web manifest.
- **На что влияет в приложении:** Иконка web-версии на GitHub Pages.
- **Когда открывать:** Пропала иконка вкладки после web deploy.
- **Можно удалить?** Нет — нужен для web-сборки.
- **Связанные пути:** `web/manifest.json`, `web/index.html`.

---

## Folder: `windows/flutter/`

EN:

- **What this folder is:** Flutter-generated Windows embedder glue — plugin registrant and CMake hooks.
- **Why it exists:** Native Windows plugins (tray, hotkey, voice overlay) register through this generated code.
- **What lives here:** `generated_plugin_registrant.*`, `generated_plugins.cmake`.
- **What part of the app it affects:** Windows desktop plugin registration — desktop voice/tray depend on it.
- **When to open it:** Windows build fails after plugin change; desktop voice plugin missing.
- **Can it be deleted?** No — required for Windows desktop build.
- **Main related paths:** `windows/runner/`, `windows/CMakeLists.txt`.

RU:

- **Что это за папка:** Сгенерированный Flutter glue для Windows embedder — registrant plugins и CMake hooks.
- **Зачем нужна:** Native Windows plugins (tray, hotkey, voice overlay) регистрируются через этот code.
- **Что здесь лежит:** `generated_plugin_registrant.*`, `generated_plugins.cmake`.
- **На что влияет в приложении:** Регистрация plugins на Windows desktop — от неё зависят voice/tray.
- **Когда открывать:** Windows build падает после смены plugin; пропал desktop voice plugin.
- **Можно удалить?** Нет — нужен для сборки Windows desktop.
- **Связанные пути:** `windows/runner/`, `windows/CMakeLists.txt`.

---

## Folder: `windows/runner/`

EN:

- **What this folder is:** Native Windows host that launches the Flutter desktop window.
- **Why it exists:** Windows needs a C++ runner exe that embeds Flutter engine.
- **What lives here:** main.cpp, window creation, plugin registrant.
- **What part of the app it affects:** Windows desktop `.exe` and installer contents.
- **When to open it:** Windows desktop won’t start, window title wrong.
- **Can it be deleted?** No — required for Windows desktop build.
- **Main related paths:** `installer/windows/`.

RU:

- **Что это за папка:** Native C++ host Windows — поднимает окно Flutter desktop.
- **Зачем нужна:** Windows нужен C++ runner `.exe`, встраивающий Flutter engine.
- **Что здесь лежит:** `main.cpp`, создание окна, plugin registrant.
- **На что влияет в приложении:** Содержимое Counter `.exe` и Windows installer.
- **Когда открывать:** Desktop `.exe` не стартует или неверный заголовок окна.
- **Можно удалить?** Нет — нужен для сборки Windows desktop.
- **Связанные пути:** `installer/windows/`, `windows/flutter/`.

---

## Folder: `android/app/src/`

EN:

- **What this folder is:** Android app module source — manifest, resources, Kotlin entry.
- **Why it exists:** Gradle compiles this tree into the installable APK.
- **What lives here:** Manifest, res/, kotlin/.
- **What part of the app it affects:** Android APK contents and permissions.
- **When to open it:** Permission denied, wrong app label, manifest merge errors.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `android/app/build.gradle`.

RU:

- **Что это за папка:** Исходники app-модуля: manifest, `res/`, Kotlin entry.
- **Зачем нужна:** Gradle компилирует это дерево в устанавливаемый APK.
- **Что здесь лежит:** Manifest, каталоги `res/` и `kotlin/`.
- **На что влияет в приложении:** Содержимое APK и permissions Android.
- **Когда открывать:** Permission denied, неверное имя app, ошибки merge manifest.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `android/app/build.gradle`.

---

## Folder: `android/gradle/wrapper/`

EN:

- **What this folder is:** Gradle wrapper and version catalog for Android builds.
- **Why it exists:** Pins Gradle version so builds are reproducible on CI and your PC.
- **What lives here:** Wrapper jar/properties, plugin versions.
- **What part of the app it affects:** Android build toolchain only.
- **When to open it:** Gradle version mismatch errors.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `android/settings.gradle`.

RU:

- **Что это за папка:** Gradle wrapper и каталог версий плагинов для Android-сборки.
- **Зачем нужна:** Фиксирует версию Gradle, чтобы сборка на CI и локально была одинаковой.
- **Что здесь лежит:** Wrapper jar/properties и версии Gradle-плагинов.
- **На что влияет в приложении:** Только toolchain Android-сборки — не Dart UI.
- **Когда открывать:** Ошибки несовпадения версии Gradle.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `android/settings.gradle`.

---

## Folder: `installer/windows/scripts/`

EN:

- **What this folder is:** Helper PowerShell scripts bundled into or used by the Windows installer pipeline.
- **Why it exists:** Windows speech and installer prep need small scripts copied beside the setup `.exe`.
- **What lives here:** `win_speech_wav.ps1` — WAV capture helper for Windows speech path.
- **What part of the app it affects:** Installed Windows app speech helper behavior post-install.
- **When to open it:** Installer missing speech helper script, Windows voice WAV path broken.
- **Can it be deleted?** No — Windows installer packaging expects these scripts.
- **Main related paths:** `installer/windows/prepare_stt_payload.ps1`, `counter.iss`.

RU:

- **Что это за папка:** Вспомогательные PowerShell-скрипты установщика — захват WAV для речи Windows.
- **Зачем нужна:** Windows speech и installer prep копируют эти scripts рядом с setup `.exe`.
- **Что здесь лежит:** `win_speech_wav.ps1` и related helpers.
- **На что влияет в приложении:** Поведение speech helper после установки на Windows.
- **Когда открывать:** Installer missing speech script, WAV path broken.
- **Можно удалить?** Нет — Windows installer packaging expects these scripts.
- **Связанные пути:** `prepare_stt_payload.ps1`, `counter.iss`.

---

## Folder: `installer/windows/stt_helper_build/`

EN:

- **What this folder is:** Built speech-to-text helper binary folder — `counter_stt_helper.exe` copied into installer.
- **Why it exists:** Desktop voice on Windows uses a GOLOS STT helper subprocess; installer must ship the compiled exe.
- **What lives here:** Pre-built or CI-built `counter_stt_helper.exe` (tracked artifact for packaging).
- **What part of the app it affects:** Windows desktop voice transcription after install.
- **When to open it:** Voice works in dev but not in installed app; rebuild STT helper for installer.
- **Can it be deleted?** No — Windows installer STT bundle incomplete without it.
- **Main related paths:** `installer/windows/build_stt_helper_en.ps1`, `lib/core/services/desktop_stt_helper_service.dart`.

RU:

- **Что это за папка:** Собранный `counter_stt_helper.exe` для bundling в installer.
- **Зачем нужна:** Desktop voice на Windows использует GOLOS STT subprocess; installer должен ship exe.
- **Что здесь лежит:** Pre-built или CI-built `counter_stt_helper.exe`.
- **На что влияет в приложении:** Расшифровка desktop voice на Windows после установки.
- **Когда открывать:** Voice в dev OK, но не в installed app; rebuild STT helper.
- **Можно удалить?** Нет — Windows installer STT bundle incomplete without it.
- **Связанные пути:** `build_stt_helper_en.ps1`, `desktop_stt_helper_service.dart`.

---

## Folder: `ios/Runner.xcodeproj/project.xcworkspace/`

EN:

- **What this folder is:** Xcode project file bundle for the iOS Counter app target.
- **Why it exists:** Xcode opens this project to compile, sign, and archive the iOS IPA.
- **What lives here:** `project.pbxproj`, shared schemes, workspace metadata.
- **What part of the app it affects:** iOS App Store / TestFlight builds only.
- **When to open it:** Xcode project corruption, scheme changes, iOS signing settings.
- **Can it be deleted?** No — required for iOS build.
- **Main related paths:** `ios/Runner/`, `ios/Flutter/`.

RU:

- **Что это за папка:** Внутренний Xcode workspace внутри `.xcodeproj` — IDE metadata.
- **Зачем нужна:** Xcode хранит workspace checks для project bundle.
- **Что здесь лежит:** `project.pbxproj`, shared schemes, workspace metadata.
- **На что влияет в приложении:** Только открытие project в Xcode — не runtime приложения.
- **Когда открывать:** Повреждение Xcode-проекта, смена scheme, настройки iOS signing.
- **Можно удалить?** Нет — нужен для сборки iOS.
- **Связанные пути:** `ios/Runner/`, `ios/Flutter/`.

---

## Folder: `ios/Runner.xcodeproj/xcshareddata/`

EN:

- **What this folder is:** Xcode project file bundle for the iOS Counter app target.
- **Why it exists:** Xcode opens this project to compile, sign, and archive the iOS IPA.
- **What lives here:** `project.pbxproj`, shared schemes, workspace metadata.
- **What part of the app it affects:** iOS App Store / TestFlight builds only.
- **When to open it:** Xcode project corruption, scheme changes, iOS signing settings.
- **Can it be deleted?** No — required for iOS build.
- **Main related paths:** `ios/Runner/`, `ios/Flutter/`.

RU:

- **Что это за папка:** Shared Xcode scheme/metadata для `ios` — какой scheme собирает target.
- **Зачем нужна:** Xcode хранит scheme и workspace checks для единообразной сборки в команде.
- **Что здесь лежит:** `project.pbxproj`, shared schemes, workspace metadata.
- **На что влияет в приложении:** Какой Xcode scheme собирает Runner — только workflow разработчика.
- **Когда открывать:** Пропал scheme в Xcode или предупреждения workspace checks.
- **Можно удалить?** Нет — нужен для сборки iOS.
- **Связанные пути:** `ios/Runner/`, `ios/Flutter/`.

---

## Folder: `ios/Runner.xcworkspace/xcshareddata/`

EN:

- **What this folder is:** Xcode workspace wrapping the iOS Runner project and CocoaPods.
- **Why it exists:** Developers open `.xcworkspace` (not `.xcodeproj` alone) after `pod install`.
- **What lives here:** Workspace data linking Runner + Pods.
- **What part of the app it affects:** Local iOS development and CI iOS builds using CocoaPods.
- **When to open it:** Xcode says open workspace; Pod integration broken.
- **Can it be deleted?** No — required for iOS CocoaPods workflow.
- **Main related paths:** `ios/Podfile`, `ios/Runner.xcodeproj`.

RU:

- **Что это за папка:** Shared Xcode scheme/metadata для `ios` — какой scheme собирает target.
- **Зачем нужна:** Xcode хранит scheme и workspace checks для единообразной сборки в команде.
- **Что здесь лежит:** Workspace data, связывающая Runner и Pods.
- **На что влияет в приложении:** Какой Xcode scheme собирает Runner — только workflow разработчика.
- **Когда открывать:** Пропал scheme в Xcode или предупреждения workspace checks.
- **Можно удалить?** Нет — нужен для CocoaPods workflow iOS.
- **Связанные пути:** `ios/Podfile`, `ios/Runner.xcodeproj`.

---

## Folder: `ios/Runner/Assets.xcassets/`

EN:

- **What this folder is:** iOS app target — icons, storyboards, Info.plist for iPhone/iPad.
- **Why it exists:** Xcode builds the Flutter iOS app from this target.
- **What lives here:** Assets, launch screen, native Swift/ObjC glue.
- **What part of the app it affects:** iOS App Store / TestFlight builds.
- **When to open it:** iOS permissions, icons, launch screen.
- **Can it be deleted?** No — required for iOS build.
- **Main related paths:** `ios/Flutter/`.

RU:

- **Что это за папка:** Asset catalog `Assets.xcassets` — иконки и launch images для Apple target.
- **Зачем нужна:** Apple platforms грузят icons и launch images из asset catalogs, не из Dart.
- **Что здесь лежит:** Assets, launch screen, native Swift/ObjC glue.
- **На что влияет в приложении:** Сборки для TestFlight и App Store.
- **Когда открывать:** Неверная или пропавшая app icon на iOS/macOS.
- **Можно удалить?** Нет — нужен для сборки iOS.
- **Связанные пути:** `ios/Flutter/`.

---

## Folder: `ios/Runner/Base.lproj/`

EN:

- **What this folder is:** iOS app target — icons, storyboards, Info.plist for iPhone/iPad.
- **Why it exists:** Xcode builds the Flutter iOS app from this target.
- **What lives here:** Assets, launch screen, native Swift/ObjC glue.
- **What part of the app it affects:** iOS App Store / TestFlight builds.
- **When to open it:** iOS permissions, icons, launch screen.
- **Can it be deleted?** No — required for iOS build.
- **Main related paths:** `ios/Flutter/`.

RU:

- **Что это за папка:** iOS target Runner — иконки, launch screen, Info.plist для iPhone/iPad.
- **Зачем нужна:** Apple показывает launch screen до первого кадра Flutter.
- **Что здесь лежит:** Storyboard или xib файлы launch UI.
- **На что влияет в приложении:** Сборки для TestFlight и App Store.
- **Когда открывать:** Flash launch screen или неверная orientation на iOS/macOS.
- **Можно удалить?** Нет — нужен для сборки iOS.
- **Связанные пути:** `ios/Flutter/`.

---

## Folder: `lib/core/diagnostics/`

EN:

- **What this folder is:** Debug-only logging helpers — startup, voice pipeline, duplicates.
- **Why it exists:** Structured logs for diagnosing perf and desktop voice without spamming release builds.
- **What lives here:** Small log wrapper files gated by debug/profile flags.
- **What part of the app it affects:** Developer diagnostics only.
- **When to open it:** Tracing desktop voice steps or startup timing.
- **Can it be deleted?** No — used by debug/profile builds.
- **Main related paths:** `lib/core/performance/`.

RU:

- **Что это за папка:** Debug-only логирование — startup, voice pipeline, duplicates.
- **Зачем нужна:** Структурированные логи для perf и desktop voice без spam в release.
- **Что здесь лежит:** Небольшие log wrapper, включаемые debug/profile flags.
- **На что влияет в приложении:** Только диагностика разработчика — не UI пользователя.
- **Когда открывать:** Трассировка шагов desktop voice или startup timing.
- **Можно удалить?** Нет — используется debug/profile builds.
- **Связанные пути:** `lib/core/performance/`.

---

## Folder: `lib/core/env/`

EN:

- **What this folder is:** Compile-time environment template — copy to gitignored `env.dart` for local secrets/constants.
- **Why it exists:** Some build-time values must not be committed; example file documents the required shape.
- **What lives here:** `env.dart.example` only in git; real `env.dart` is local.
- **What part of the app it affects:** Developer local builds only if env constants are referenced.
- **When to open it:** Setting up a new dev machine; adding compile-time constant.
- **Can it be deleted?** No — documents required env.dart structure.
- **Main related paths:** `.gitignore` entry for `lib/core/env/env.dart`.

RU:

- **Что это за папка:** Compile-time шаблон env — копировать в gitignored `env.dart` для локальных secrets.
- **Зачем нужна:** Build-time значения не коммитят; example file документирует нужную форму.
- **Что здесь лежит:** В git только `env.dart.example`; настоящий `env.dart` локальный.
- **На что влияет в приложении:** Только локальные dev builds, если используются env constants.
- **Когда открывать:** Настройка новой dev-машины; добавление compile-time constant.
- **Можно удалить?** Нет — описывает требуемую структуру env.dart.
- **Связанные пути:** `.gitignore` entry для `lib/core/env/env.dart`.

---

## Folder: `lib/core/navigation/`

EN:

- **What this folder is:** Root navigator key and desktop side-rail navigation helpers.
- **Why it exists:** Desktop voice overlay and hidden main window need a global navigator; side rail replaces bottom tabs on wide screens.
- **What lives here:** `app_navigator.dart` (`appRootNavigatorKey`), `shell_side_navigation.dart`.
- **What part of the app it affects:** Desktop/web layout (side nav) and overlay routing above tabs.
- **When to open it:** Desktop overlay cannot push routes; side navigation breakpoint wrong.
- **Can it be deleted?** No — desktop layout and overlays break.
- **Main related paths:** `lib/shell/shell_side_navigation.dart`, `lib/core/shell_adaptive.dart`.

RU:

- **Что это за папка:** Root navigator key и helpers боковой desktop-навигации.
- **Зачем нужна:** Desktop voice overlay и hidden main window нуждаются в global navigator; side rail заменяет bottom tabs на широких экранах.
- **Что здесь лежит:** Файлы `app_navigator.dart` (`appRootNavigatorKey`), `shell_side_navigation.dart`.
- **На что влияет в приложении:** Desktop/web layout (side nav) и overlay routing над вкладками.
- **Когда открывать:** Desktop overlay не может push routes; неверный breakpoint side navigation.
- **Можно удалить?** Нет — desktop layout and overlays break.
- **Связанные пути:** `lib/shell/shell_side_navigation.dart`, `lib/core/shell_adaptive.dart`.

---

## Folder: `lib/core/performance/`

EN:

- **What this folder is:** Runtime feature flags and optional perf metrics — date strip, warm window, rebuild counters.
- **Why it exists:** Lets developers toggle expensive features or capture frame metrics without shipping debug code to all users.
- **What lives here:** `runtime_flags.dart`, `shell_flags.dart`, `rebuild_metrics.dart` (`PERF_DIAG` gated).
- **What part of the app it affects:** Perf-sensitive paths: date paging, shell tab stack, diagnostic builds.
- **When to open it:** Investigating jank, toggling warm-window kill switch, perf capture tests.
- **Can it be deleted?** No — perf tests and diagnostics reference these flags.
- **Main related paths:** `test/perf_*`, `lib/data/cache/`.

RU:

- **Что это за папка:** Feature flags runtime и perf metrics — полоса дат, warm window, счётчики rebuild.
- **Зачем нужна:** Позволяет включать дорогие features или capture frame metrics без debug code для всех users.
- **Что здесь лежит:** Файлы `runtime_flags.dart`, `shell_flags.dart`, `rebuild_metrics.dart` (`PERF_DIAG` gated).
- **На что влияет в приложении:** Perf: paging дат, tab stack оболочки, diagnostic builds.
- **Когда открывать:** Расследование jank, warm-window kill switch, perf capture tests.
- **Можно удалить?** Нет — perf tests and diagnostics reference these flags.
- **Связанные пути:** `test/perf_*`, `lib/data/cache/`.

---

## Folder: `lib/core/services/`

EN:

- **What this folder is:** Device services — speech-to-text, desktop voice, tray, hotkeys.
- **Why it exists:** Platform voice and tray behavior cannot live in PocketBase brain code.
- **What lives here:** Many `desktop_voice_*.dart` modules plus STT helper subprocess client.
- **What part of the app it affects:** Windows desktop voice, tray icon, global hotkey; mobile STT locale.
- **When to open it:** Desktop voice not recording, hotkey dead, tray missing.
- **Can it be deleted?** No — desktop voice product feature.
- **Main related paths:** `lib/features/shared/desktop_voice_*.dart`.

RU:

- **Что это за папка:** Сервисы устройства — speech-to-text, desktop voice, tray, global hotkeys.
- **Зачем нужна:** Platform voice и tray не могут жить в PocketBase brain code.
- **Что здесь лежит:** Модули `desktop_voice_*.dart` и STT helper subprocess client.
- **На что влияет в приложении:** Windows desktop voice, иконка tray, global hotkey; mobile STT locale.
- **Когда открывать:** Desktop voice не пишет, hotkey мёртв, tray пропал.
- **Можно удалить?** Нет — desktop voice product feature.
- **Связанные пути:** `lib/features/shared/desktop_voice_*.dart`.

---

## Folder: `lib/core/time/`

EN:

- **What this folder is:** Wall-clock and timezone math shared by header, Plans Time View, and profile ‘today’ line.
- **Why it exists:** Time bucketing must follow profile timezone law — not device local time — across all tabs.
- **What lives here:** `app_clock.dart`, `profile_timezone_catalog.dart`, `plan_time_visible_window.dart`, wall-clock formatters.
- **What part of the app it affects:** Global header clock, Time View hour window (−3..27 h), timezone picker labels.
- **When to open it:** Wrong ‘today’, header TZ label, Time View visible hours, DST label wrong.
- **Can it be deleted?** No — timeline and planning time display breaks.
- **Main related paths:** `lib/data/profile/profile_timezone.dart`, `lib/core/widgets/global_app_header.dart`.

RU:

- **Что это за папка:** Расчёт wall-clock и timezone для header, Time View на Plans и линии «today» в profile.
- **Зачем нужна:** Границы дней и time bucketing следуют profile timezone law — не device local time — на всех вкладках.
- **Что здесь лежит:** `app_clock.dart`, `profile_timezone_catalog.dart`, `plan_time_visible_window.dart`, форматтеры wall-clock.
- **На что влияет в приложении:** Часы в global header, окно часов Time View (−3..27 h), подписи timezone picker.
- **Когда открывать:** Неверный «today», label TZ в header, visible hours Time View, DST label.
- **Можно удалить?** Нет — timeline and planning time display breaks.
- **Связанные пути:** `lib/data/profile/profile_timezone.dart`, `lib/core/widgets/global_app_header.dart`.

---

## Folder: `lib/core/widgets/`

EN:

- **What this folder is:** Reusable UI building blocks (buttons, cards, headers, pickers) — the design system in code.
- **Why it exists:** One canonical button/card so Plans, Timeline, and Lists look consistent.
- **What lives here:** `AppButton`, `PlanTimeTaskCard`, date header, timezone picker, chips.
- **What part of the app it affects:** Every main tab and most sheets.
- **When to open it:** Button style migration, plan card layout, date/time picker, loading/empty states.
- **Can it be deleted?** No — features depend on these widgets.
- **Main related paths:** `docs/DESIGN_SYSTEM.md`, `lib/features/dev/component_lab_view.dart`.

RU:

- **Что это за папка:** Переиспользуемые UI-блоки — design system в коде (`AppButton`, карточки, pickers).
- **Зачем нужна:** Один канонический button/card — Plans, Timeline и Lists выглядят одинаково.
- **Что здесь лежит:** `AppButton`, `PlanTimeTaskCard`, date header, timezone picker, chips.
- **На что влияет в приложении:** Все главные вкладки и большинство sheets.
- **Когда открывать:** Миграция стиля кнопок, layout карточек, date/time picker, loading/empty states.
- **Можно удалить?** Нет — features зависят от этих widgets.
- **Связанные пути:** `docs/DESIGN_SYSTEM.md`, Component Lab.

---

## Folder: `lib/data/cache/`

EN:

- **What this folder is:** Performance caches for fast date paging — warm day snapshots and rendered list bodies.
- **Why it exists:** Swiping Timeline/Plans days must stay smooth with large record/plan histories.
- **What lives here:** `day_snapshot_window.dart`, `rendered_day_body_cache.dart`, `render_snapshot.dart`.
- **What part of the app it affects:** Day swipe smoothness on Timeline and Planning; not user-visible data correctness.
- **When to open it:** Jank swiping days, stale day content after edit, perf regression.
- **Can it be deleted?** No — paging becomes slow or glitchy.
- **Main related paths:** `lib/data/records/record_timeline_vm.dart`, `lib/core/performance/runtime_flags.dart`.

RU:

- **Что это за папка:** Performance caches для быстрого paging по дням — warm day snapshots и rendered list bodies.
- **Зачем нужна:** Swipe между днями Timeline/Plans должен оставаться плавным при больших history records/plans.
- **Что здесь лежит:** `day_snapshot_window.dart`, `rendered_day_body_cache.dart`, `render_snapshot.dart`.
- **На что влияет в приложении:** Плавность day swipe на Timeline и Planning; не влияет на корректность данных для пользователя.
- **Когда открывать:** Jank при swipe дней, stale day content после edit, perf regression.
- **Можно удалить?** Нет — paging becomes slow or glitchy.
- **Связанные пути:** `lib/data/records/record_timeline_vm.dart`, `lib/core/performance/runtime_flags.dart`.

---

## Folder: `lib/data/categories/`

EN:

- **What this folder is:** Category-management slice of the brain — tree, colors, matching names, and linking records to categories.
- **Why it exists:** Categories organize timeline time, plans, stats, and voice commands like “Price Reporter …”.
- **What lives here:** Seven focused `part` files; each handles one category job (see file entries below).
- **What part of the app it affects:** Category picker, category manager screen, record category on start/stop, plan category chips, stats by category.
- **When to open it:** Categories missing, wrong color/icon, fuzzy match picks wrong client, records saved without category.
- **Can it be deleted?** No — category features stop working.
- **Main related paths:** `lib/data/category_service.dart`, `lib/features/categories/`.

RU:

- **Что это за папка:** Срез brain для категорий — дерево, цвета, fuzzy-match названий и привязка записей к категориям.
- **Зачем нужна:** Категории группируют время на Timeline, планы, stats и voice-команды вроде «Price Reporter …».
- **Что здесь лежит:** Семь `part`-файлов; каждый закрывает одну задачу категорий (см. file entries ниже).
- **На что влияет в приложении:** Category picker, экран Categories, category на start/stop записи, chips на планах, stats по категориям.
- **Когда открывать:** Категории пропали, неверный color/icon, fuzzy match выбрал не того клиента, запись без category.
- **Можно удалить?** Нет — category features stop working.
- **Связанные пути:** `lib/data/category_service.dart`, `lib/features/categories/`.

---

## Folder: `lib/data/local_sync/`

EN:

- **What this folder is:** Offline queue — remembers record/plan changes when the network or login fails, then retries later.
- **Why it exists:** Life OS promises tap-first UX; users must not lose starts/stops/edits on bad Wi‑Fi.
- **What lives here:** SharedPreferences outboxes, pending-count state, connectivity listener to flush queues.
- **What part of the app it affects:** Top offline/sync banner, background retry on reconnect, auth-paused state.
- **When to open it:** “Pending sync” stuck, changes lost offline, banner tap does nothing.
- **Can it be deleted?** No — offline-first behavior is shipped product law.
- **Main related paths:** `lib/app_shell.dart` offline banner, `docs/UX_CONTRACT.md`.

RU:

- **Что это за папка:** Offline queue — помнит изменения records/plans при сбое сети или login и повторяет позже.
- **Зачем нужна:** Life OS обещает tap-first UX: start/stop/edit не должны теряться на плохом Wi‑Fi.
- **Что здесь лежит:** SharedPreferences outboxes, pending-count state, connectivity listener для flush очередей.
- **На что влияет в приложении:** Верхний offline/sync banner, фоновый retry при reconnect, auth-paused state.
- **Когда открывать:** «Pending sync» завис, изменения offline потерялись, tap по banner ничего не делает.
- **Можно удалить?** Нет — offline-first behavior is shipped product law.
- **Связанные пути:** `lib/app_shell.dart` offline banner, `docs/UX_CONTRACT.md`.

---

## Folder: `lib/data/models/`

EN:

- **What this folder is:** Plain data shapes (records, plans, categories, tags, profile) — no network code.
- **Why it exists:** Same field names everywhere; aligns with `docs/DATA_MAP.md` so UI and brain agree on what a “record” is.
- **What lives here:** Dart classes like `TimelineRecord`, `PlanningTask`, `CategoryRule`, `Tag`.
- **What part of the app it affects:** Every screen that displays or edits user data.
- **When to open it:** Wrong date on timeline, parsing errors after PocketBase schema change.
- **Can it be deleted?** No — types are required across the app.
- **Main related paths:** `lib/data/models.dart` barrel, `docs/DATA_MAP.md`.

RU:

- **Что это за папка:** Plain data shapes (records, plans, categories, tags, profile) — без network-кода.
- **Зачем нужна:** Одинаковые field names везде; совпадает с `docs/DATA_MAP.md`, чтобы UI и brain понимали «record» одинаково.
- **Что здесь лежит:** Dart-классы `TimelineRecord`, `PlanningTask`, `CategoryRule`, `Tag` и др.
- **На что влияет в приложении:** Каждый экран, который показывает или редактирует user data.
- **Когда открывать:** Неверная дата на Timeline, parsing errors после смены PocketBase schema.
- **Можно удалить?** Нет — types are required across the app.
- **Связанные пути:** `lib/data/models.dart` barrel, `docs/DATA_MAP.md`.

---

## Folder: `lib/data/plans/`

EN:

- **What this folder is:** Plans and lists slice of the brain — scheduled tasks, backlog items, recurrence, tags on plans.
- **Why it exists:** Planning tab, Lists tab, and calendar rows all read/write the same `plans` table through these modules.
- **What lives here:** Projection for Time View, RRULE expansion, tag sync, plan cache, offline plan outbox.
- **What part of the app it affects:** Plans tab, Time View layout, Lists tab, plan edit sheets, plan alarms.
- **When to open it:** Plans don’t save, recurrence wrong, Time View cards misplaced, list toggle offline.
- **Can it be deleted?** No — planning and lists break.
- **Main related paths:** `lib/data/plan_service.dart`, `lib/features/planning/`, `lib/features/lists/`.

RU:

- **Что это за папка:** Срез мозга для Plans/Lists — задачи по расписанию, backlog, recurrence и теги.
- **Зачем нужна:** Вкладки Plans и Lists читают/пишут одну таблицу `plans` через эти модули.
- **Что здесь лежит:** Projection Time View, RRULE expansion, sync тегов, кэш, offline outbox.
- **На что влияет в приложении:** Plans, Time View, Lists, edit sheets планов, plan alarms.
- **Когда открывать:** Планы не сохраняются, recurrence неверна, карточки Time View не на месте.
- **Можно удалить?** Нет — planning and lists break.
- **Связанные пути:** `lib/data/plan_service.dart`, `lib/features/planning/`.

---

## Folder: `lib/data/profile/`

EN:

- **What this folder is:** User profile and tags slice of the brain — timezone, settings, tag catalog, admin flag.
- **Why it exists:** Wall-clock “today”, language, tag chips, and tag manager all depend on profile + tag rows in PocketBase.
- **What lives here:** Profile hydration, settings PATCH, timezone math, tag CRUD, tag display prefs.
- **What part of the app it affects:** Profile screen, tag settings, timezone header, Component Lab admin gate.
- **When to open it:** Wrong “today” line, timezone not sticking, tags missing on cards, settings won’t save.
- **Can it be deleted?** No — profile and tags break.
- **Main related paths:** `lib/data/profile_service.dart`, `lib/features/profile/`.

RU:

- **Что это за папка:** Срез brain для profile и tags — timezone, settings, tag catalog, admin flag.
- **Зачем нужна:** Wall-clock «today», язык, tag chips и tag manager зависят от profile + tag rows в PocketBase.
- **Что здесь лежит:** Profile hydration, settings PATCH, timezone math, tag CRUD, tag display prefs.
- **На что влияет в приложении:** Экран Profile, настройки tags, timezone в header, admin gate для Component Lab.
- **Когда открывать:** Неверная «today» line, timezone не сохраняется, tags пропали на cards, settings не пишутся.
- **Можно удалить?** Нет — profile and tags break.
- **Связанные пути:** `lib/data/profile_service.dart`, `lib/features/profile/`.

---

## Folder: `lib/data/records/`

EN:

- **What this folder is:** Timeline record slice of the brain — start/stop timer, edit history, realtime updates, offline queue.
- **Why it exists:** Timeline is the core time tracker; this folder splits record logic into readable modules.
- **What lives here:** CRUD, optimistic UI, realtime subscription, timeline list builders, overlap/Highlander rules, outbox.
- **What part of the app it affects:** Timeline tab, record edit sheet, Wear lite timer, voice “start record”.
- **When to open it:** Timer won’t start/stop, wrong day bucket, duplicate running records, offline start fails.
- **Can it be deleted?** No — timeline tracking breaks.
- **Main related paths:** `lib/data/record_service.dart`, `lib/features/timeline/`.

RU:

- **Что это за папка:** Срез мозга для Timeline — старт/стоп таймера, история, realtime, offline queue.
- **Зачем нужна:** Timeline — ядро трекера; папка делит record-логику на читаемые модули.
- **Что здесь лежит:** CRUD, optimistic UI, realtime, builders Timeline, overlap/Highlander, outbox.
- **На что влияет в приложении:** Timeline, edit sheet записи, Wear lite timer, voice «start record».
- **Когда открывать:** Таймер не стартует/стопится, неверный day bucket, дубликаты running.
- **Можно удалить?** Нет — timeline tracking breaks.
- **Связанные пути:** `lib/data/record_service.dart`, `lib/features/timeline/`.

---

## Folder: `lib/features/auth/`

EN:

- **What this folder is:** Sign-in, registration, OAuth, and password-reset screens before the main app loads.
- **Why it exists:** Users must authenticate to PocketBase before Timeline/Plans data is available.
- **What lives here:** `auth_view.dart`, `auth_screen.dart`, `oauth_session.dart`.
- **What part of the app it affects:** Login gate shown from `main.dart` when session invalid.
- **When to open it:** OAuth redirect broken, login form, register flow, password reset UI.
- **Can it be deleted?** No — users cannot sign in.
- **Main related paths:** `lib/data/auth_bridge.dart`, `docs/DEPLOY.md` OAuth admin section.

RU:

- **Что это за папка:** Sign-in, registration, OAuth и password-reset screens до загрузки main app.
- **Зачем нужна:** Users должны authenticate в PocketBase до Timeline/Plans data.
- **Что здесь лежит:** `auth_view.dart`, `auth_screen.dart`, `oauth_session.dart`.
- **На что влияет в приложении:** Login gate из `main.dart` когда session invalid.
- **Когда открывать:** OAuth redirect broken, login form, register flow, password reset UI.
- **Можно удалить?** Нет — users cannot sign in.
- **Связанные пути:** `lib/data/auth_bridge.dart`, `docs/DEPLOY.md` OAuth admin section.

---

## Folder: `lib/features/calendar/`

EN:

- **What this folder is:** Calendar tab UI — month view of plans (when enabled in navigation).
- **Why it exists:** Alternative plan browsing by calendar month alongside Plans tab list/Time View.
- **What lives here:** `calendar_view.dart`.
- **What part of the app it affects:** Calendar tab in bottom/side navigation (when present in shell).
- **When to open it:** Calendar month layout, plan dots on dates, calendar navigation.
- **Can it be deleted?** Maybe — if calendar tab removed from shell; keep while route exists.
- **Main related paths:** `lib/features/planning/`, plan card widgets in `core/widgets/`.

RU:

- **Что это за папка:** UI вкладки Calendar — month view планов (когда route включён в navigation).
- **Зачем нужна:** Альтернативный просмотр планов по calendar month рядом с list/Time View на Plans.
- **Что здесь лежит:** `calendar_view.dart`.
- **На что влияет в приложении:** Calendar tab в bottom/side navigation (когда присутствует в shell).
- **Когда открывать:** Calendar month layout, plan dots на dates, calendar navigation.
- **Можно удалить?** Возможно — if calendar tab removed from shell; keep while route exists.
- **Связанные пути:** `lib/features/planning/`, plan card widgets в `core/widgets/`.

---

## Folder: `lib/features/categories/`

EN:

- **What this folder is:** Category manager UI — tree, create/edit, visibility preferences.
- **Why it exists:** Users organize work/personal/client categories from More → Categories.
- **What lives here:** List view, recursive tree picker, create dialog, visibility prefs.
- **What part of the app it affects:** More → Categories; category pickers elsewhere call into these widgets.
- **When to open it:** Create category, reorder, archive, pick category in tree dialog.
- **Can it be deleted?** No — category management UI gone.
- **Main related paths:** `lib/data/categories/`.

RU:

- **Что это за папка:** UI менеджера категорий — дерево, создание/редактирование, настройки видимости.
- **Зачем нужна:** Пользователь организует work/personal/client categories из More → Categories.
- **Что здесь лежит:** List view, recursive tree picker, create dialog, visibility prefs.
- **На что влияет в приложении:** More → Categories; category pickers в других экранах используют эти widgets.
- **Когда открывать:** Create category, reorder, archive, pick category в tree dialog.
- **Можно удалить?** Нет — category management UI gone.
- **Связанные пути:** `lib/data/categories/`.

---

## Folder: `lib/features/dev/`

EN:

- **What this folder is:** Admin-only Component Lab — design-system preview, not shown to normal users.
- **Why it exists:** Validates buttons/cards/chips against `docs/DESIGN_SYSTEM.md` before production migration.
- **What lives here:** Component lab page and card demos.
- **What part of the app it affects:** More menu only when `profiles.is_admin` is true.
- **When to open it:** Design-system QA, V7 component acceptance.
- **Can it be deleted?** Maybe — safe for product runtime, but V7 work uses it; keep for admins.
- **Main related paths:** `docs/DESIGN_SYSTEM.md`, `docs/reports/DESIGN_SYSTEM_INVENTORY.md`.

RU:

- **Что это за папка:** Admin-only Component Lab — preview design system, скрыт от обычных users.
- **Зачем нужна:** Проверяет buttons/cards/chips против `docs/DESIGN_SYSTEM.md` до production migration.
- **Что здесь лежит:** Component lab page и card demos.
- **На что влияет в приложении:** More menu только когда `profiles.is_admin` true.
- **Когда открывать:** Design-system QA, V7 component acceptance.
- **Можно удалить?** Возможно — safe for product runtime, but V7 work uses it; keep for admins.
- **Связанные пути:** `docs/DESIGN_SYSTEM.md`, `docs/reports/DESIGN_SYSTEM_INVENTORY.md`.

---

## Folder: `lib/features/lists/`

EN:

- **What this folder is:** Lists tab UI — backlog/checklist tasks with filters, bulk select, export.
- **Why it exists:** Third productivity tab for non-scheduled list items (same `plans` table, backlog mode).
- **What lives here:** Filters, cards, inline add, bulk bar, clipboard export.
- **What part of the app it affects:** Lists tab (bottom nav index 3).
- **When to open it:** List filters, checkbox done, bulk delete, export visible list as text.
- **Can it be deleted?** No — Lists tab disappears.
- **Main related paths:** `lib/data/plan_service.dart`.

RU:

- **Что это за папка:** UI вкладки Lists — backlog/checklist tasks с filters, bulk select и export.
- **Зачем нужна:** Третья productivity tab для non-scheduled list items (та же таблица `plans`, backlog mode).
- **Что здесь лежит:** Filters, cards, inline add, bulk bar, clipboard export.
- **На что влияет в приложении:** Вкладка Lists (четвёртая bottom tab, index 3).
- **Когда открывать:** List filters, checkbox done, bulk delete, export visible list as text.
- **Можно удалить?** Нет — Lists tab disappears.
- **Связанные пути:** `lib/data/plan_service.dart`.

---

## Folder: `lib/features/planning/`

EN:

- **What this folder is:** Plans tab UI — day pager, plan list, Time View canvas, plan settings, bulk edit.
- **Why it exists:** This is what users see on the second bottom tab (Plans).
- **What lives here:** Large `planning_page.dart` plus `time_view/`, `settings/`, `widgets/` subfolders.
- **What part of the app it affects:** Plans tab only (plus calendar rows that reuse plan cards).
- **When to open it:** Plan cards wrong, Time View drag broken, day swipe on Plans tab, play/start plan.
- **Can it be deleted?** No — Plans tab disappears.
- **Main related paths:** `lib/shell/` tab host, `lib/data/plan_service.dart`.

RU:

- **Что это за папка:** UI вкладки Plans — day pager, список планов, Time View, settings, bulk edit.
- **Зачем нужна:** Это видит пользователь на второй нижней вкладке (Plans).
- **Что здесь лежит:** `planning_page.dart`, подпапки `time_view/`, `settings/`, `widgets/`.
- **На что влияет в приложении:** Только вкладка Plans (плюс calendar rows с теми же карточками).
- **Когда открывать:** Неверные карточки, drag Time View, swipe дней, play/start plan.
- **Можно удалить?** Нет — Plans tab disappears.
- **Связанные пути:** `lib/shell/`, `lib/data/plan_service.dart`.

---

## Folder: `lib/features/profile/`

EN:

- **What this folder is:** Profile and tag settings screens from the More menu.
- **Why it exists:** Account, timezone, language, tag manager, desktop voice settings (Windows).
- **What lives here:** Profile view, settings sections, tag manager pages, desktop voice diagnostics.
- **What part of the app it affects:** More → Profile, tag settings routes, desktop voice card.
- **When to open it:** Login profile, change timezone, manage tags, desktop hotkey settings.
- **Can it be deleted?** No — profile/settings unavailable.
- **Main related paths:** `lib/data/profile/`, `lib/features/dev/` (admin only).

RU:

- **Что это за папка:** Profile и tag settings screens из меню More.
- **Зачем нужна:** Аккаунт, timezone, язык, tag manager и настройки desktop voice (Windows).
- **Что здесь лежит:** Profile view, секции settings, страницы tag manager, диагностика desktop voice.
- **На что влияет в приложении:** More → Profile, маршруты tag settings, карточка desktop voice.
- **Когда открывать:** Login profile, смена timezone, manage tags, desktop hotkey settings.
- **Можно удалить?** Нет — profile/settings unavailable.
- **Связанные пути:** `lib/data/profile/`, `lib/features/dev/` (admin only).

---

## Folder: `lib/features/shared/`

EN:

- **What this folder is:** Shared edit sheets and voice UI used by Timeline, Plans, and Lists.
- **Why it exists:** One edit experience for plans and records — Omni date/time picker, tags, checklist, offline banner.
- **What lives here:** Activity detail router, planning/record edit sheets, edit_sheet/* helpers, voice widgets.
- **What part of the app it affects:** Any tap-to-edit on plans/records; mobile voice sheet; desktop voice panel.
- **When to open it:** Edit sheet save, date picker, tags on plan, voice input sheet.
- **Can it be deleted?** No — edit flows break on all tabs.
- **Main related paths:** `lib/shell/shell_edit_hosts.dart`, `docs/UX_CONTRACT.md`.

RU:

- **Что это за папка:** Общие edit sheets и voice UI для Timeline, Plans и Lists.
- **Зачем нужна:** Единый edit для plans и records — Omni picker, tags, checklist, offline banner.
- **Что здесь лежит:** Router activity detail, edit sheets, helpers `edit_sheet/*`, voice widgets.
- **На что влияет в приложении:** Редактирование plans/records по tap; mobile voice sheet; desktop voice panel.
- **Когда открывать:** Save edit sheet, date picker, tags на plan, voice input sheet.
- **Можно удалить?** Нет — edit flows break on all tabs.
- **Связанные пути:** `lib/shell/shell_edit_hosts.dart`, `docs/UX_CONTRACT.md`.

---

## Folder: `lib/features/stats/`

EN:

- **What this folder is:** Productivity stats views embedded inside Timeline — hours by category, plan vs fact.
- **Why it exists:** Stats toggle on Timeline header switches list mode to analytics without a separate app area.
- **What lives here:** `stats_view.dart`, `plan_vs_fact_tab.dart`.
- **What part of the app it affects:** Timeline tab when user taps Stats segmented control.
- **When to open it:** Stats totals wrong, plan-vs-fact chart, stats tab toggle.
- **Can it be deleted?** No — Timeline stats mode disappears.
- **Main related paths:** `lib/data/categories/category_stats.dart`, `lib/features/timeline/timeline_header_controls.dart`.

RU:

- **Что это за папка:** Productivity stats views внутри Timeline — hours by category, plan vs fact.
- **Зачем нужна:** Stats toggle в header Timeline переключает list mode на analytics без отдельной area.
- **Что здесь лежит:** `stats_view.dart`, `plan_vs_fact_tab.dart`.
- **На что влияет в приложении:** Вкладка Timeline, когда пользователь нажимает Stats segmented control.
- **Когда открывать:** Stats totals неверны, plan-vs-fact chart, stats tab toggle.
- **Можно удалить?** Нет — Timeline stats mode disappears.
- **Связанные пути:** `lib/data/categories/category_stats.dart`, `lib/features/timeline/timeline_header_controls.dart`.

---

## Folder: `lib/features/timeline/`

EN:

- **What this folder is:** Timeline tab UI — day pager, running/stopped record cards, stats entry.
- **Why it exists:** Primary time-tracking screen (first bottom tab).
- **What lives here:** Swipe wrapper, day list, record cards, header controls (stats toggle, input).
- **What part of the app it affects:** Timeline tab and embedded stats view.
- **When to open it:** Records on wrong day, now-line, swipe between days, record card tap/edit.
- **Can it be deleted?** No — Timeline tab disappears.
- **Main related paths:** `lib/data/record_service.dart`, `ActivityDetailSheet`.

RU:

- **Что это за папка:** UI вкладки Timeline — day pager, running/stopped record cards, вход в stats.
- **Зачем нужна:** Главный экран time tracking (первая bottom tab).
- **Что здесь лежит:** Swipe wrapper, day list, record cards, header controls (stats toggle, input).
- **На что влияет в приложении:** Вкладка Timeline и встроенный stats view.
- **Когда открывать:** Records на неверном дне, now-line, swipe между днями, tap/edit record card.
- **Можно удалить?** Нет — Timeline tab disappears.
- **Связанные пути:** `lib/data/record_service.dart`, `ActivityDetailSheet`.

---

## Folder: `lib/features/wear/`

EN:

- **What this folder is:** Wear OS watch companion — simplified timer screen on Android watches.
- **Why it exists:** Watch form factor needs a lite UI and `loadInitialDataWearLite` brain path.
- **What lives here:** `wear_timer_screen.dart`, `wear_main_wrapper.dart`, platform channel shims.
- **What part of the app it affects:** Wear OS APK companion only — not phone Timeline UI.
- **When to open it:** Watch timer sync, Wear build entry, companion crashes on watch.
- **Can it be deleted?** No — if Wear OS companion is a supported target.
- **Main related paths:** `lib/data/db_core.dart` Wear lite load, `android/` Wear module if configured.

RU:

- **Что это за папка:** Wear OS watch companion — упрощённый timer screen на Android watches.
- **Зачем нужна:** Watch form factor нужен lite UI и brain path `loadInitialDataWearLite`.
- **Что здесь лежит:** `wear_timer_screen.dart`, `wear_main_wrapper.dart`, platform channel shims.
- **На что влияет в приложении:** Только Wear OS APK companion — не phone Timeline UI.
- **Когда открывать:** Watch timer sync, Wear build entry, companion crashes на watch.
- **Можно удалить?** Нет — если нужен Wear OS companion.
- **Связанные пути:** `lib/data/db_core.dart` Wear lite load, `android/` Wear module если настроен.

---

## Folder: `lib/l10n/langs/`

EN:

- **What this folder is:** Per-language string maps for UI labels.
- **Why it exists:** Each locale file supplies translated text for dictionary keys.
- **What lives here:** en.dart and ru.dart are canonical; others partial.
- **What part of the app it affects:** All visible UI text when user switches language.
- **When to open it:** Missing translation key, wrong language string.
- **Can it be deleted?** No — required for localization.
- **Main related paths:** `lib/l10n/dictionary.dart`, `scripts/sync_locales.dart`.

RU:

- **Что это за папка:** Карты строк UI для каждой локали — key → переведённый текст.
- **Зачем нужна:** Каждый locale-файл даёт переводы для ключей из `dictionary.dart`.
- **Что здесь лежит:** `en.dart` и `ru.dart` — канонические; остальные локали частичные.
- **На что влияет в приложении:** Все видимые подписи UI при смене языка в настройках.
- **Когда открывать:** Пропал ключ перевода, неверная строка на выбранном языке.
- **Можно удалить?** Нет — нужен для localization.
- **Связанные пути:** `lib/l10n/dictionary.dart`, `scripts/sync_locales.dart`.

---

## Folder: `macos/Runner.xcodeproj/project.xcworkspace/`

EN:

- **What this folder is:** Xcode project for macOS desktop Counter `.app` target.
- **Why it exists:** macOS desktop builds compile through this Xcode project.
- **What lives here:** `project.pbxproj`, shared schemes for macOS Runner.
- **What part of the app it affects:** macOS desktop distribution builds.
- **When to open it:** macOS Xcode build/sign errors.
- **Can it be deleted?** No — required for macOS desktop build.
- **Main related paths:** `macos/Runner/`, `macos/Flutter/`.

RU:

- **Что это за папка:** Внутренний Xcode workspace внутри `.xcodeproj` — IDE metadata.
- **Зачем нужна:** Xcode хранит workspace checks для project bundle.
- **Что здесь лежит:** Файлы `project.pbxproj`, shared schemes для macOS Runner.
- **На что влияет в приложении:** Только открытие project в Xcode — не runtime приложения.
- **Когда открывать:** Ошибки macOS Xcode build/sign.
- **Можно удалить?** Нет — нужен для сборки macOS desktop.
- **Связанные пути:** `macos/Runner/`, `macos/Flutter/`.

---

## Folder: `macos/Runner.xcodeproj/xcshareddata/`

EN:

- **What this folder is:** Xcode project for macOS desktop Counter `.app` target.
- **Why it exists:** macOS desktop builds compile through this Xcode project.
- **What lives here:** `project.pbxproj`, shared schemes for macOS Runner.
- **What part of the app it affects:** macOS desktop distribution builds.
- **When to open it:** macOS Xcode build/sign errors.
- **Can it be deleted?** No — required for macOS desktop build.
- **Main related paths:** `macos/Runner/`, `macos/Flutter/`.

RU:

- **Что это за папка:** Shared Xcode scheme/metadata для `macos` — какой scheme собирает target.
- **Зачем нужна:** Xcode хранит scheme и workspace checks для единообразной сборки в команде.
- **Что здесь лежит:** Файлы `project.pbxproj`, shared schemes для macOS Runner.
- **На что влияет в приложении:** Какой Xcode scheme собирает Runner — только workflow разработчика.
- **Когда открывать:** Пропал scheme в Xcode или предупреждения workspace checks.
- **Можно удалить?** Нет — нужен для сборки macOS desktop.
- **Связанные пути:** `macos/Runner/`, `macos/Flutter/`.

---

## Folder: `macos/Runner.xcworkspace/xcshareddata/`

EN:

- **What this folder is:** Xcode workspace for macOS Counter desktop app.
- **Why it exists:** Opens Runner + Flutter macOS pods together in Xcode.
- **What lives here:** Workspace contents and shared IDE checks.
- **What part of the app it affects:** macOS desktop development in Xcode.
- **When to open it:** Workspace won't open; CocoaPods integration on macOS.
- **Can it be deleted?** No — required for macOS Xcode workflow.
- **Main related paths:** `macos/Runner.xcodeproj`.

RU:

- **Что это за папка:** Shared Xcode scheme/metadata для `macos` — какой scheme собирает target.
- **Зачем нужна:** Xcode хранит scheme и workspace checks для единообразной сборки в команде.
- **Что здесь лежит:** Содержимое workspace и shared IDE checks.
- **На что влияет в приложении:** Какой Xcode scheme собирает Runner — только workflow разработчика.
- **Когда открывать:** Пропал scheme в Xcode или предупреждения workspace checks.
- **Можно удалить?** Нет — нужен для Xcode workflow macOS.
- **Связанные пути:** `macos/Runner.xcodeproj`.

---

## Folder: `macos/Runner/Assets.xcassets/`

EN:

- **What this folder is:** macOS app bundle target — menus, icons, entitlements.
- **Why it exists:** Apple requires Xcode target for macOS Flutter apps.
- **What lives here:** Swift runner, assets, entitlements plist.
- **What part of the app it affects:** macOS desktop builds.
- **When to open it:** macOS signing, sandbox, menu bar.
- **Can it be deleted?** No — if macOS builds are kept.
- **Main related paths:** `macos/Flutter/`.

RU:

- **Что это за папка:** Asset catalog `Assets.xcassets` — иконки и launch images для Apple target.
- **Зачем нужна:** Apple platforms грузят icons и launch images из asset catalogs, не из Dart.
- **Что здесь лежит:** Swift runner, assets, entitlements plist.
- **На что влияет в приложении:** Сборка Counter `.app` на macOS desktop.
- **Когда открывать:** Неверная или пропавшая app icon на iOS/macOS.
- **Можно удалить?** Нет — если поддерживается сборка macOS.
- **Связанные пути:** `macos/Flutter/`.

---

## Folder: `macos/Runner/Base.lproj/`

EN:

- **What this folder is:** macOS app bundle target — menus, icons, entitlements.
- **Why it exists:** Apple requires Xcode target for macOS Flutter apps.
- **What lives here:** Swift runner, assets, entitlements plist.
- **What part of the app it affects:** macOS desktop builds.
- **When to open it:** macOS signing, sandbox, menu bar.
- **Can it be deleted?** No — if macOS builds are kept.
- **Main related paths:** `macos/Flutter/`.

RU:

- **Что это за папка:** macOS target Runner — меню, иконки, entitlements для `.app` bundle.
- **Зачем нужна:** Apple показывает launch screen до первого кадра Flutter.
- **Что здесь лежит:** Storyboard или xib файлы launch UI.
- **На что влияет в приложении:** Сборка Counter `.app` на macOS desktop.
- **Когда открывать:** Flash launch screen или неверная orientation на iOS/macOS.
- **Можно удалить?** Нет — если поддерживается сборка macOS.
- **Связанные пути:** `macos/Flutter/`.

---

## Folder: `macos/Runner/Configs/`

EN:

- **What this folder is:** macOS app bundle target — menus, icons, entitlements.
- **Why it exists:** Apple requires Xcode target for macOS Flutter apps.
- **What lives here:** Swift runner, assets, entitlements plist.
- **What part of the app it affects:** macOS desktop builds.
- **When to open it:** macOS signing, sandbox, menu bar.
- **Can it be deleted?** No — if macOS builds are kept.
- **Main related paths:** `macos/Flutter/`.

RU:

- **Что это за папка:** macOS target Runner — меню, иконки, entitlements для `.app` bundle.
- **Зачем нужна:** Apple требует Xcode target для macOS Flutter-приложения.
- **Что здесь лежит:** Swift runner, assets, entitlements plist.
- **На что влияет в приложении:** Сборка Counter `.app` на macOS desktop.
- **Когда открывать:** Подпись macOS, sandbox, menu bar.
- **Можно удалить?** Нет — если поддерживается сборка macOS.
- **Связанные пути:** `macos/Flutter/`.

---

## Folder: `windows/runner/resources/`

EN:

- **What this folder is:** Native Windows host that launches the Flutter desktop window.
- **Why it exists:** Windows needs a C++ runner exe that embeds Flutter engine.
- **What lives here:** main.cpp, window creation, plugin registrant.
- **What part of the app it affects:** Windows desktop `.exe` and installer contents.
- **When to open it:** Windows desktop won’t start, window title wrong.
- **Can it be deleted?** No — required for Windows desktop build.
- **Main related paths:** `installer/windows/`.

RU:

- **Что это за папка:** Native C++ host Windows — поднимает окно Flutter desktop.
- **Зачем нужна:** Windows нужен C++ runner `.exe`, встраивающий Flutter engine.
- **Что здесь лежит:** `main.cpp`, создание окна, plugin registrant.
- **На что влияет в приложении:** Содержимое Counter `.exe` и Windows installer.
- **Когда открывать:** Desktop `.exe` не стартует или неверный заголовок окна.
- **Можно удалить?** Нет — нужен для сборки Windows desktop.
- **Связанные пути:** `installer/windows/`.

---

## Folder: `android/app/src/debug/`

EN:

- **What this folder is:** Android debug build variant manifest overrides.
- **Why it exists:** Debug APK may enable extra logging or different application id suffix.
- **What lives here:** Debug `AndroidManifest.xml` merged into debug builds.
- **What part of the app it affects:** Debug Android installs only — not release APK.
- **When to open it:** Debug-only permission or manifest merge issue.
- **Can it be deleted?** No — required for Android debug builds.
- **Main related paths:** `android/app/src/main/AndroidManifest.xml`.

RU:

- **Что это за папка:** Override Android manifest для debug variant — отдельные permissions и merge rules.
- **Зачем нужна:** Debug APK может включать extra logging или другой application id suffix.
- **Что здесь лежит:** Debug `AndroidManifest.xml`, merge только в debug builds.
- **На что влияет в приложении:** Только debug Android installs — не release APK.
- **Когда открывать:** Проблемы permissions или слияния manifest только в debug-сборке.
- **Можно удалить?** Нет — нужен для debug-сборки Android.
- **Связанные пути:** `android/app/src/main/AndroidManifest.xml`.

---

## Folder: `android/app/src/main/`

EN:

- **What this folder is:** Android app module source — manifest, resources, Kotlin entry.
- **Why it exists:** Gradle compiles this tree into the installable APK.
- **What lives here:** Manifest, res/, kotlin/.
- **What part of the app it affects:** Android APK contents and permissions.
- **When to open it:** Permission denied, wrong app label, manifest merge errors.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `android/app/build.gradle`.

RU:

- **Что это за папка:** Исходники app-модуля: manifest, `res/`, Kotlin entry.
- **Зачем нужна:** Gradle компилирует это дерево в устанавливаемый APK.
- **Что здесь лежит:** Manifest, каталоги `res/` и `kotlin/`.
- **На что влияет в приложении:** Содержимое APK и permissions Android.
- **Когда открывать:** Permission denied, неверное имя app, ошибки merge manifest.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `android/app/build.gradle`.

---

## Folder: `android/app/src/profile/`

EN:

- **What this folder is:** Android profile build variant manifest (performance profiling).
- **Why it exists:** Profile mode uses separate manifest merge for Flutter profile builds.
- **What lives here:** Profile `AndroidManifest.xml`.
- **What part of the app it affects:** Profile APK used for performance measurement.
- **When to open it:** Profile build manifest merge errors.
- **Can it be deleted?** No — required for Flutter profile Android builds.
- **Main related paths:** `android/app/src/main/`.

RU:

- **Что это за папка:** Manifest Android profile variant — сборка для performance profiling.
- **Зачем нужна:** Profile-сборка Android мержит отдельный AndroidManifest для Flutter profile APK.
- **Что здесь лежит:** Profile `AndroidManifest.xml`.
- **На что влияет в приложении:** Profile APK для измерения производительности.
- **Когда открывать:** Ошибки merge manifest при profile build.
- **Можно удалить?** Нет — нужен для profile-сборки Android.
- **Связанные пути:** `android/app/src/main/`.

---

## Folder: `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/`

EN:

- **What this folder is:** Xcode project file bundle for the iOS Counter app target.
- **Why it exists:** Xcode opens this project to compile, sign, and archive the iOS IPA.
- **What lives here:** `project.pbxproj`, shared schemes, workspace metadata.
- **What part of the app it affects:** iOS App Store / TestFlight builds only.
- **When to open it:** Xcode project corruption, scheme changes, iOS signing settings.
- **Can it be deleted?** No — required for iOS build.
- **Main related paths:** `ios/Runner/`, `ios/Flutter/`.

RU:

- **Что это за папка:** Shared Xcode scheme/metadata для `ios/Runner.xcodeproj` — какой scheme собирает target.
- **Зачем нужна:** Xcode хранит scheme и workspace checks для единообразной сборки в команде.
- **Что здесь лежит:** `project.pbxproj`, shared schemes, workspace metadata.
- **На что влияет в приложении:** Какой Xcode scheme собирает Runner — только workflow разработчика.
- **Когда открывать:** Пропал scheme в Xcode или предупреждения workspace checks.
- **Можно удалить?** Нет — нужен для сборки iOS.
- **Связанные пути:** `ios/Runner/`, `ios/Flutter/`.

---

## Folder: `ios/Runner.xcodeproj/xcshareddata/xcschemes/`

EN:

- **What this folder is:** Xcode project file bundle for the iOS Counter app target.
- **Why it exists:** Xcode opens this project to compile, sign, and archive the iOS IPA.
- **What lives here:** `project.pbxproj`, shared schemes, workspace metadata.
- **What part of the app it affects:** iOS App Store / TestFlight builds only.
- **When to open it:** Xcode project corruption, scheme changes, iOS signing settings.
- **Can it be deleted?** No — required for iOS build.
- **Main related paths:** `ios/Runner/`, `ios/Flutter/`.

RU:

- **Что это за папка:** Shared Xcode scheme/metadata для `ios/Runner.xcodeproj` — какой scheme собирает target.
- **Зачем нужна:** Xcode хранит scheme и workspace checks для единообразной сборки в команде.
- **Что здесь лежит:** `project.pbxproj`, shared schemes, workspace metadata.
- **На что влияет в приложении:** Какой Xcode scheme собирает Runner — только workflow разработчика.
- **Когда открывать:** Пропал scheme в Xcode или предупреждения workspace checks.
- **Можно удалить?** Нет — нужен для сборки iOS.
- **Связанные пути:** `ios/Runner/`, `ios/Flutter/`.

---

## Folder: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

EN:

- **What this folder is:** iOS app target — icons, storyboards, Info.plist for iPhone/iPad.
- **Why it exists:** Xcode builds the Flutter iOS app from this target.
- **What lives here:** Assets, launch screen, native Swift/ObjC glue.
- **What part of the app it affects:** iOS App Store / TestFlight builds.
- **When to open it:** iOS permissions, icons, launch screen.
- **Can it be deleted?** No — required for iOS build.
- **Main related paths:** `ios/Flutter/`.

RU:

- **Что это за папка:** Asset catalog `AppIcon.appiconset` — иконки и launch images для Apple target.
- **Зачем нужна:** Apple platforms грузят icons и launch images из asset catalogs, не из Dart.
- **Что здесь лежит:** Assets, launch screen, native Swift/ObjC glue.
- **На что влияет в приложении:** Сборки для TestFlight и App Store.
- **Когда открывать:** Неверная или пропавшая app icon на iOS/macOS.
- **Можно удалить?** Нет — нужен для сборки iOS.
- **Связанные пути:** `ios/Flutter/`.

---

## Folder: `ios/Runner/Assets.xcassets/LaunchImage.imageset/`

EN:

- **What this folder is:** iOS app target — icons, storyboards, Info.plist for iPhone/iPad.
- **Why it exists:** Xcode builds the Flutter iOS app from this target.
- **What lives here:** Assets, launch screen, native Swift/ObjC glue.
- **What part of the app it affects:** iOS App Store / TestFlight builds.
- **When to open it:** iOS permissions, icons, launch screen.
- **Can it be deleted?** No — required for iOS build.
- **Main related paths:** `ios/Flutter/`.

RU:

- **Что это за папка:** iOS target Runner — иконки, launch screen, Info.plist для iPhone/iPad.
- **Зачем нужна:** Xcode собирает iOS-приложение Counter из этого target: иконки, launch screen, Info.plist и native glue.
- **Что здесь лежит:** Assets, launch screen, native Swift/ObjC glue.
- **На что влияет в приложении:** Сборки для TestFlight и App Store.
- **Когда открывать:** Permissions iOS, иконки, launch screen.
- **Можно удалить?** Нет — нужен для сборки iOS.
- **Связанные пути:** `ios/Flutter/`.

---

## Folder: `lib/core/widgets/plan_card/`

EN:

- **What this folder is:** Compatibility re-exports pointing to `plan_time_task_card/` canonical files.
- **Why it exists:** Older imports used `plan_card/` path during design-system migration.
- **What lives here:** Thin export stubs only.
- **What part of the app it affects:** Legacy import paths still resolving.
- **When to open it:** Removing migration stubs after all imports updated.
- **Can it be deleted?** Maybe — after confirming no imports use `plan_card/` path.
- **Main related paths:** `lib/core/widgets/plan_time_task_card/`.

RU:

- **Что это за папка:** Переэкспорт совместимости на канонические файлы `plan_time_task_card/`.
- **Зачем нужна:** Старые import использовали путь `plan_card/` во время migration design system.
- **Что здесь лежит:** Тонкие export stubs без логики.
- **На что влияет в приложении:** Legacy import paths всё ещё резолвятся.
- **Когда открывать:** Удаление migration stubs после обновления всех import.
- **Можно удалить?** Возможно — after confirming no imports use `plan_card/` path.
- **Связанные пути:** `lib/core/widgets/plan_time_task_card/`.

---

## Folder: `lib/core/widgets/plan_time_task_card/`

EN:

- **What this folder is:** Plan task card visuals — list rows, Time View blocks, calendar rows (CardPlan design).
- **Why it exists:** Plans look the same in list mode, Time View, and calendar; play/checkbox/menu shared.
- **What lives here:** Split modules: density, geometry, layouts, tags, progress, controls.
- **What part of the app it affects:** Planning cards, Time View blocks, calendar plan rows.
- **When to open it:** Card height, tag pills, play button, Time View density bands.
- **Can it be deleted?** No — plan UI breaks everywhere.
- **Main related paths:** `lib/features/planning/`, `plan_card_layouts.dart`.

RU:

- **Что это за папка:** Каноническая карточка плана для list mode, Time View и calendar rows (CardPlan design).
- **Зачем нужна:** Plans выглядят одинаково в list, Time View и calendar; play/checkbox/menu shared.
- **Что здесь лежит:** Разделены density, geometry, layouts, tags, progress и controls.
- **На что влияет в приложении:** Карточки на Plans, блоки Time View и строки calendar.
- **Когда открывать:** Высота card, tag pills, play button, density bands Time View.
- **Можно удалить?** Нет — plan UI breaks everywhere.
- **Связанные пути:** `lib/features/planning/`, `plan_card_layouts.dart`.

---

## Folder: `lib/features/planning/settings/`

EN:

- **What this folder is:** Planning settings sheets — visible hours, default category/timezone search.
- **Why it exists:** Time View and plan defaults need dedicated settings UI.
- **What lives here:** Bounds slider, record→plan link prefs, no-tags chip settings.
- **What part of the app it affects:** Plans → settings routes and Time View configuration.
- **When to open it:** Visible hour range, default plan category/timezone search.
- **Can it be deleted?** No — plan settings unavailable.
- **Main related paths:** `time_view/time_view_settings_sheet.dart`.

RU:

- **Что это за папка:** Sheets настроек Plans — visible hours, default category, timezone search.
- **Зачем нужна:** Time View и defaults планов требуют отдельного settings UI.
- **Что здесь лежит:** Bounds slider, prefs record→plan link, no-tags chip settings.
- **На что влияет в приложении:** Маршруты Plans → settings и конфигурация Time View.
- **Когда открывать:** Диапазон visible hours, default category/timezone search.
- **Можно удалить?** Нет — plan settings unavailable.
- **Связанные пути:** `time_view/time_view_settings_sheet.dart`.

---

## Folder: `lib/features/planning/time_view/`

EN:

- **What this folder is:** Planning “Time View” — proportional day timeline with draggable plan blocks.
- **Why it exists:** Visual schedule mode: plans positioned by clock time, resize/drag, hour grid.
- **What lives here:** Canvas, card layer, drag/resize controllers, settings sheet, search for default times.
- **What part of the app it affects:** Time View sub-mode inside Plans tab.
- **When to open it:** Cards overlap wrong, drag/resize jank, hour scale, fixed-time tags.
- **Can it be deleted?** No — Time View is a core Plans feature.
- **Main related paths:** `planning_page.dart`, `PlanTimeTaskCard` widgets in `core/widgets/`.

RU:

- **Что это за папка:** Код визуального расписания Plans → Time View: дневная временная шкала, слой карточек, drag/resize, настройки видимого окна и поиск default time.
- **Зачем нужна:** Режим visual schedule — планы по clock time на шкале, resize/drag, hour grid.
- **Что здесь лежит:** Canvas, card layer, drag/resize controllers, settings sheet, search default times.
- **На что влияет в приложении:** Sub-mode Time View внутри вкладки Plans.
- **Когда открывать:** Карточки overlap неверно, jank drag/resize, масштаб часов, fixed-time tags, жесты Time View.
- **Можно удалить?** Нет — Time View is a core Plans feature.
- **Связанные пути:** `planning_page.dart`, `PlanTimeTaskCard` в `core/widgets/`.

---

## Folder: `lib/features/planning/widgets/`

EN:

- **What this folder is:** Smaller Planning tab widgets — filters, bulk bar, empty states, menus.
- **Why it exists:** Split from giant planning page for readability and guard compliance.
- **What lives here:** Bulk selection bar, filter controls, quick-add strip, card menus.
- **What part of the app it affects:** Plans tab list mode UI pieces.
- **When to open it:** Bulk edit bar, plan card menu, empty state wrong.
- **Can it be deleted?** No — Plans tab UI breaks.
- **Main related paths:** `planning_page.dart`.

RU:

- **Что это за папка:** Мелкие виджеты вкладки Plans — filters, bulk bar, empty states, menus.
- **Зачем нужна:** Вынесены из большого planning page для читаемости и architecture guard.
- **Что здесь лежит:** Bulk selection bar, filter controls, quick-add strip, card menus.
- **На что влияет в приложении:** Части list mode UI на вкладке Plans.
- **Когда открывать:** Bulk edit bar, menu карточки plan, неверный empty state.
- **Можно удалить?** Нет — Plans tab UI breaks.
- **Связанные пути:** `planning_page.dart`.

---

## Folder: `lib/features/profile/settings/`

EN:

- **What this folder is:** Profile settings sections — account, notifications, security.
- **Why it exists:** Split settings page into focused sections for More → Settings.
- **What lives here:** Logout row, notification permission, password reset, biometric lock.
- **What part of the app it affects:** Settings routes from shell and profile.
- **When to open it:** Logout, notification permission, password reset UI.
- **Can it be deleted?** No — settings sections missing.
- **Main related paths:** `lib/shell/settings_page.dart`.

RU:

- **Что это за папка:** Секции настроек Profile — account, notifications, security.
- **Зачем нужна:** Settings page разбита на секции для More → Settings.
- **Что здесь лежит:** Logout row, notification permission, password reset, biometric lock.
- **На что влияет в приложении:** Маршруты settings из shell и profile.
- **Когда открывать:** Logout, notification permission, password reset UI.
- **Можно удалить?** Нет — settings sections missing.
- **Связанные пути:** `lib/shell/settings_page.dart`.

---

## Folder: `lib/features/shared/edit_sheet/`

EN:

- **What this folder is:** Helpers inside plan/record edit bottom sheets.
- **Why it exists:** Autosave, time picker, checklist, repeat rules shared between plan and record sheets.
- **What lives here:** Omni picker entry, debounced autosave, RRULE helpers, Quill toolbar.
- **What part of the app it affects:** Any edit sheet save, date/time change, checklist rows.
- **When to open it:** Edit sheet autosave, date picker, repeat preset wrong.
- **Can it be deleted?** No — edit sheets break.
- **Main related paths:** `activity_detail_sheet.dart`.

RU:

- **Что это за папка:** Helpers внутри bottom sheets редактирования plan/record.
- **Зачем нужна:** Autosave, time picker, checklist и repeat rules общие для plan и record sheets.
- **Что здесь лежит:** Omni picker entry, debounced autosave, RRULE helpers, Quill toolbar.
- **На что влияет в приложении:** Сохранение edit sheet, смена date/time, строки checklist.
- **Когда открывать:** Autosave edit sheet, date picker, неверный repeat preset.
- **Можно удалить?** Нет — edit sheets break.
- **Связанные пути:** `activity_detail_sheet.dart`.

---

## Folder: `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/`

EN:

- **What this folder is:** Xcode project for macOS desktop Counter `.app` target.
- **Why it exists:** macOS desktop builds compile through this Xcode project.
- **What lives here:** `project.pbxproj`, shared schemes for macOS Runner.
- **What part of the app it affects:** macOS desktop distribution builds.
- **When to open it:** macOS Xcode build/sign errors.
- **Can it be deleted?** No — required for macOS desktop build.
- **Main related paths:** `macos/Runner/`, `macos/Flutter/`.

RU:

- **Что это за папка:** Shared Xcode scheme/metadata для `macos/Runner.xcodeproj` — какой scheme собирает target.
- **Зачем нужна:** Xcode хранит scheme и workspace checks для единообразной сборки в команде.
- **Что здесь лежит:** Файлы `project.pbxproj`, shared schemes для macOS Runner.
- **На что влияет в приложении:** Какой Xcode scheme собирает Runner — только workflow разработчика.
- **Когда открывать:** Пропал scheme в Xcode или предупреждения workspace checks.
- **Можно удалить?** Нет — нужен для сборки macOS desktop.
- **Связанные пути:** `macos/Runner/`, `macos/Flutter/`.

---

## Folder: `macos/Runner.xcodeproj/xcshareddata/xcschemes/`

EN:

- **What this folder is:** Xcode project for macOS desktop Counter `.app` target.
- **Why it exists:** macOS desktop builds compile through this Xcode project.
- **What lives here:** `project.pbxproj`, shared schemes for macOS Runner.
- **What part of the app it affects:** macOS desktop distribution builds.
- **When to open it:** macOS Xcode build/sign errors.
- **Can it be deleted?** No — required for macOS desktop build.
- **Main related paths:** `macos/Runner/`, `macos/Flutter/`.

RU:

- **Что это за папка:** Shared Xcode scheme/metadata для `macos/Runner.xcodeproj` — какой scheme собирает target.
- **Зачем нужна:** Xcode хранит scheme и workspace checks для единообразной сборки в команде.
- **Что здесь лежит:** Файлы `project.pbxproj`, shared schemes для macOS Runner.
- **На что влияет в приложении:** Какой Xcode scheme собирает Runner — только workflow разработчика.
- **Когда открывать:** Пропал scheme в Xcode или предупреждения workspace checks.
- **Можно удалить?** Нет — нужен для сборки macOS desktop.
- **Связанные пути:** `macos/Runner/`, `macos/Flutter/`.

---

## Folder: `macos/Runner/Assets.xcassets/AppIcon.appiconset/`

EN:

- **What this folder is:** macOS app bundle target — menus, icons, entitlements.
- **Why it exists:** Apple requires Xcode target for macOS Flutter apps.
- **What lives here:** Swift runner, assets, entitlements plist.
- **What part of the app it affects:** macOS desktop builds.
- **When to open it:** macOS signing, sandbox, menu bar.
- **Can it be deleted?** No — if macOS builds are kept.
- **Main related paths:** `macos/Flutter/`.

RU:

- **Что это за папка:** Asset catalog `AppIcon.appiconset` — иконки и launch images для Apple target.
- **Зачем нужна:** Apple platforms грузят icons и launch images из asset catalogs, не из Dart.
- **Что здесь лежит:** Swift runner, assets, entitlements plist.
- **На что влияет в приложении:** Сборка Counter `.app` на macOS desktop.
- **Когда открывать:** Неверная или пропавшая app icon на iOS/macOS.
- **Можно удалить?** Нет — если поддерживается сборка macOS.
- **Связанные пути:** `macos/Flutter/`.

---

## Folder: `android/app/src/main/kotlin/`

EN:

- **What this folder is:** Kotlin entry point where Flutter attaches to Android.
- **Why it exists:** Android OS launches `MainActivity` which boots the Flutter engine.
- **What lives here:** `MainActivity.kt` — minimal Flutter embedding.
- **What part of the app it affects:** Android app startup only.
- **When to open it:** Android crash on launch, deep link handling at native layer.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `AndroidManifest.xml`.

RU:

- **Что это за папка:** Kotlin-точка входа — Flutter engine подключается к Android Activity.
- **Зачем нужна:** Android OS запускает `MainActivity`, она поднимает Flutter engine.
- **Что здесь лежит:** `MainActivity.kt` — минимальный Flutter embedding.
- **На что влияет в приложении:** Только cold start Android — не Dart UI.
- **Когда открывать:** Crash при launch Android, deep links на native-слое.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `AndroidManifest.xml`.

---

## Folder: `android/app/src/main/res/`

EN:

- **What this folder is:** Android visual resources — splash background, themes, launcher icons.
- **Why it exists:** Android packages drawables and styles separately from Dart code.
- **What lives here:** XML styles, splash drawable, mipmap icons.
- **What part of the app it affects:** Splash screen and Android-native chrome only.
- **When to open it:** Splash flash, theme colors on Android launch.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `android/app/`.

RU:

- **Что это за папка:** Android-ресурсы: splash, themes, launcher icons.
- **Зачем нужна:** Android хранит drawable/styles отдельно от Dart-кода.
- **Что здесь лежит:** XML styles, splash drawable, mipmap icons.
- **На что влияет в приложении:** Только splash и native chrome Android.
- **Когда открывать:** Вспышка splash, цвета theme при launch.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `android/app/`.

---

## Folder: `android/app/src/main/kotlin/com/`

EN:

- **What this folder is:** Kotlin entry point where Flutter attaches to Android.
- **Why it exists:** Android OS launches `MainActivity` which boots the Flutter engine.
- **What lives here:** `MainActivity.kt` — minimal Flutter embedding.
- **What part of the app it affects:** Android app startup only.
- **When to open it:** Android crash on launch, deep link handling at native layer.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `AndroidManifest.xml`.

RU:

- **Что это за папка:** Kotlin-точка входа — Flutter engine подключается к Android Activity.
- **Зачем нужна:** Android OS запускает `MainActivity`, она поднимает Flutter engine.
- **Что здесь лежит:** `MainActivity.kt` — минимальный Flutter embedding.
- **На что влияет в приложении:** Только cold start Android — не Dart UI.
- **Когда открывать:** Crash при launch Android, deep links на native-слое.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `AndroidManifest.xml`.

---

## Folder: `android/app/src/main/res/drawable/`

EN:

- **What this folder is:** Android visual resources — splash background, themes, launcher icons.
- **Why it exists:** Android packages drawables and styles separately from Dart code.
- **What lives here:** XML styles, splash drawable, mipmap icons.
- **What part of the app it affects:** Splash screen and Android-native chrome only.
- **When to open it:** Splash flash, theme colors on Android launch.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `android/app/`.

RU:

- **Что это за папка:** Android `drawable splash/фон` — ресурсы в `android/app/src/main/res/drawable`.
- **Зачем нужна:** Android хранит drawable/styles/icons отдельно от Dart-кода.
- **Что здесь лежит:** XML/PNG ресурсы для `drawable`.
- **На что влияет в приложении:** Splash, theme или launcher icon на Android (только native chrome).
- **Когда открывать:** Проблема с `drawable` при launch или иконке Android.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `android/app/`.

---

## Folder: `android/app/src/main/res/drawable-v21/`

EN:

- **What this folder is:** Android visual resources — splash background, themes, launcher icons.
- **Why it exists:** Android packages drawables and styles separately from Dart code.
- **What lives here:** XML styles, splash drawable, mipmap icons.
- **What part of the app it affects:** Splash screen and Android-native chrome only.
- **When to open it:** Splash flash, theme colors on Android launch.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `android/app/`.

RU:

- **Что это за папка:** Android `drawable splash/фон` — ресурсы в `android/app/src/main/res/drawable-v21`.
- **Зачем нужна:** Android хранит drawable/styles/icons отдельно от Dart-кода.
- **Что здесь лежит:** XML/PNG ресурсы для `drawable-v21`.
- **На что влияет в приложении:** Splash, theme или launcher icon на Android (только native chrome).
- **Когда открывать:** Проблема с `drawable-v21` при launch или иконке Android.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `android/app/`.

---

## Folder: `android/app/src/main/res/mipmap-hdpi/`

EN:

- **What this folder is:** Android visual resources — splash background, themes, launcher icons.
- **Why it exists:** Android packages drawables and styles separately from Dart code.
- **What lives here:** XML styles, splash drawable, mipmap icons.
- **What part of the app it affects:** Splash screen and Android-native chrome only.
- **When to open it:** Splash flash, theme colors on Android launch.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `android/app/`.

RU:

- **Что это за папка:** Android `mipmap иконки (mipmap-hdpi)` — ресурсы в `android/app/src/main/res/mipmap-hdpi`.
- **Зачем нужна:** Android хранит drawable/styles/icons отдельно от Dart-кода.
- **Что здесь лежит:** XML/PNG ресурсы для `mipmap-hdpi`.
- **На что влияет в приложении:** Splash, theme или launcher icon на Android (только native chrome).
- **Когда открывать:** Проблема с `mipmap-hdpi` при launch или иконке Android.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `android/app/`.

---

## Folder: `android/app/src/main/res/mipmap-mdpi/`

EN:

- **What this folder is:** Android visual resources — splash background, themes, launcher icons.
- **Why it exists:** Android packages drawables and styles separately from Dart code.
- **What lives here:** XML styles, splash drawable, mipmap icons.
- **What part of the app it affects:** Splash screen and Android-native chrome only.
- **When to open it:** Splash flash, theme colors on Android launch.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `android/app/`.

RU:

- **Что это за папка:** Android `mipmap иконки (mipmap-mdpi)` — ресурсы в `android/app/src/main/res/mipmap-mdpi`.
- **Зачем нужна:** Android хранит drawable/styles/icons отдельно от Dart-кода.
- **Что здесь лежит:** XML/PNG ресурсы для `mipmap-mdpi`.
- **На что влияет в приложении:** Splash, theme или launcher icon на Android (только native chrome).
- **Когда открывать:** Проблема с `mipmap-mdpi` при launch или иконке Android.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `android/app/`.

---

## Folder: `android/app/src/main/res/mipmap-xhdpi/`

EN:

- **What this folder is:** Android visual resources — splash background, themes, launcher icons.
- **Why it exists:** Android packages drawables and styles separately from Dart code.
- **What lives here:** XML styles, splash drawable, mipmap icons.
- **What part of the app it affects:** Splash screen and Android-native chrome only.
- **When to open it:** Splash flash, theme colors on Android launch.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `android/app/`.

RU:

- **Что это за папка:** Android `mipmap иконки (mipmap-xhdpi)` — ресурсы в `android/app/src/main/res/mipmap-xhdpi`.
- **Зачем нужна:** Android хранит drawable/styles/icons отдельно от Dart-кода.
- **Что здесь лежит:** XML/PNG ресурсы для `mipmap-xhdpi`.
- **На что влияет в приложении:** Splash, theme или launcher icon на Android (только native chrome).
- **Когда открывать:** Проблема с `mipmap-xhdpi` при launch или иконке Android.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `android/app/`.

---

## Folder: `android/app/src/main/res/mipmap-xxhdpi/`

EN:

- **What this folder is:** Android visual resources — splash background, themes, launcher icons.
- **Why it exists:** Android packages drawables and styles separately from Dart code.
- **What lives here:** XML styles, splash drawable, mipmap icons.
- **What part of the app it affects:** Splash screen and Android-native chrome only.
- **When to open it:** Splash flash, theme colors on Android launch.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `android/app/`.

RU:

- **Что это за папка:** Android `mipmap иконки (mipmap-xxhdpi)` — ресурсы в `android/app/src/main/res/mipmap-xxhdpi`.
- **Зачем нужна:** Android хранит drawable/styles/icons отдельно от Dart-кода.
- **Что здесь лежит:** XML/PNG ресурсы для `mipmap-xxhdpi`.
- **На что влияет в приложении:** Splash, theme или launcher icon на Android (только native chrome).
- **Когда открывать:** Проблема с `mipmap-xxhdpi` при launch или иконке Android.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `android/app/`.

---

## Folder: `android/app/src/main/res/mipmap-xxxhdpi/`

EN:

- **What this folder is:** Android visual resources — splash background, themes, launcher icons.
- **Why it exists:** Android packages drawables and styles separately from Dart code.
- **What lives here:** XML styles, splash drawable, mipmap icons.
- **What part of the app it affects:** Splash screen and Android-native chrome only.
- **When to open it:** Splash flash, theme colors on Android launch.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `android/app/`.

RU:

- **Что это за папка:** Android `mipmap иконки (mipmap-xxxhdpi)` — ресурсы в `android/app/src/main/res/mipmap-xxxhdpi`.
- **Зачем нужна:** Android хранит drawable/styles/icons отдельно от Dart-кода.
- **Что здесь лежит:** XML/PNG ресурсы для `mipmap-xxxhdpi`.
- **На что влияет в приложении:** Splash, theme или launcher icon на Android (только native chrome).
- **Когда открывать:** Проблема с `mipmap-xxxhdpi` при launch или иконке Android.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `android/app/`.

---

## Folder: `android/app/src/main/res/values/`

EN:

- **What this folder is:** Android visual resources — splash background, themes, launcher icons.
- **Why it exists:** Android packages drawables and styles separately from Dart code.
- **What lives here:** XML styles, splash drawable, mipmap icons.
- **What part of the app it affects:** Splash screen and Android-native chrome only.
- **When to open it:** Splash flash, theme colors on Android launch.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `android/app/`.

RU:

- **Что это за папка:** Android `values/styles (values)` — ресурсы в `android/app/src/main/res/values`.
- **Зачем нужна:** Android хранит drawable/styles/icons отдельно от Dart-кода.
- **Что здесь лежит:** XML/PNG ресурсы для `values`.
- **На что влияет в приложении:** Splash, theme или launcher icon на Android (только native chrome).
- **Когда открывать:** Проблема с `values` при launch или иконке Android.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `android/app/`.

---

## Folder: `android/app/src/main/res/values-night/`

EN:

- **What this folder is:** Android visual resources — splash background, themes, launcher icons.
- **Why it exists:** Android packages drawables and styles separately from Dart code.
- **What lives here:** XML styles, splash drawable, mipmap icons.
- **What part of the app it affects:** Splash screen and Android-native chrome only.
- **When to open it:** Splash flash, theme colors on Android launch.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `android/app/`.

RU:

- **Что это за папка:** Android `values/styles (values-night)` — ресурсы в `android/app/src/main/res/values-night`.
- **Зачем нужна:** Android хранит drawable/styles/icons отдельно от Dart-кода.
- **Что здесь лежит:** XML/PNG ресурсы для `values-night`.
- **На что влияет в приложении:** Splash, theme или launcher icon на Android (только native chrome).
- **Когда открывать:** Проблема с `values-night` при launch или иконке Android.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `android/app/`.

---

## Folder: `android/app/src/main/kotlin/com/example/`

EN:

- **What this folder is:** Kotlin entry point where Flutter attaches to Android.
- **Why it exists:** Android OS launches `MainActivity` which boots the Flutter engine.
- **What lives here:** `MainActivity.kt` — minimal Flutter embedding.
- **What part of the app it affects:** Android app startup only.
- **When to open it:** Android crash on launch, deep link handling at native layer.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `AndroidManifest.xml`.

RU:

- **Что это за папка:** Kotlin-точка входа — Flutter engine подключается к Android Activity.
- **Зачем нужна:** Android OS запускает `MainActivity`, она поднимает Flutter engine.
- **Что здесь лежит:** `MainActivity.kt` — минимальный Flutter embedding.
- **На что влияет в приложении:** Только cold start Android — не Dart UI.
- **Когда открывать:** Crash при launch Android, deep links на native-слое.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `AndroidManifest.xml`.

---

## Folder: `android/app/src/main/kotlin/com/example/counter/`

EN:

- **What this folder is:** Kotlin entry point where Flutter attaches to Android.
- **Why it exists:** Android OS launches `MainActivity` which boots the Flutter engine.
- **What lives here:** `MainActivity.kt` — minimal Flutter embedding.
- **What part of the app it affects:** Android app startup only.
- **When to open it:** Android crash on launch, deep link handling at native layer.
- **Can it be deleted?** No — required for Android build.
- **Main related paths:** `AndroidManifest.xml`.

RU:

- **Что это за папка:** Kotlin-точка входа — Flutter engine подключается к Android Activity.
- **Зачем нужна:** Android OS запускает `MainActivity`, она поднимает Flutter engine.
- **Что здесь лежит:** `MainActivity.kt` — минимальный Flutter embedding.
- **На что влияет в приложении:** Только cold start Android — не Dart UI.
- **Когда открывать:** Crash при launch Android, deep links на native-слое.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связанные пути:** `AndroidManifest.xml`.

---

## All tracked files (alphabetical)

### `.cursor/rules/flutter_expert.mdc`

EN:

- **What this is:** Authoritative Cursor AI rules — architecture iron laws for this repo.
- **Why needed:** Cursor agents must follow PocketBase, optimistic UI, and structure rules.
- **What it contains:** Long-form expert rules referenced from `.cursorrules`.
- **Responsibilities:** Bind AI edits to governing architecture.
- **When to open:** When behavior tied to `flutter_expert.mdc` breaks or you need to change its documented role.
- **Can it be deleted?** No — part of repository tooling or config.
- **Connected to:** Flutter `.cursor` tooling.
- **Layer / owner:** Repository support file.

RU:

- **Что это:** Always-applied правила Cursor Agent для Flutter/PocketBase архитектуры Counter.
- **Зачем:** Cursor подхватывает iron laws: optimistic UI, Brain/UI split, main-thread law.
- **Содержимое:** Markdown-правила Cursor: PocketBase IDs, запрет spam polling, законы структуры.
- **Обязанности:** Удерживать AI codegen в рамках governing docs.
- **Когда открывать:** AI предлагает refactor, ломающий architecture guard или Brain.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** `.cursor/`, Flutter tooling.
- **Слой:** IDE agent rules — не runtime приложения.


### `.cursorrules`

EN:

- **What this is:** Cursor IDE rules pointer at repo root — Cursor discovers project rules from this filename.
- **Why needed:** Cursor reads `.cursorrules` in the project root by convention; this file redirects to the authoritative rules file.
- **What it contains:** Short pointer to `.cursor/rules/flutter_expert.mdc` (architecture iron laws, main-thread law).
- **Responsibilities:** Compatibility entry so Cursor agents load real rules from `.cursor/rules/`.
- **When to open:** Cursor agent ignores architecture — verify pointer and open `flutter_expert.mdc`.
- **Can it be deleted?** No — Cursor root discovery expects this file or equivalent config.
- **Connected to:** `.cursor/rules/flutter_expert.mdc`, `docs/ARCHITECTURE.md`.
- **Layer / owner:** IDE agent config — not app runtime.

RU:

- **Что это:** Указатель правил Cursor в корне репозитория — Cursor ищет project rules именно здесь.
- **Зачем:** Cursor по convention читает `.cursorrules` в root; файл перенаправляет на полные правила в `.cursor/rules/flutter_expert.mdc`.
- **Содержимое:** Короткий pointer на iron laws Flutter/PocketBase и main-thread law.
- **Обязанности:** Совместимость: чтобы агент Cursor подхватил настоящие правила.
- **Когда открывать:** Агент Cursor нарушает архитектуру — проверить pointer и открыть `flutter_expert.mdc`.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** `.cursor/rules/flutter_expert.mdc`, `docs/ARCHITECTURE.md`.
- **Слой:** IDE agent config — не runtime приложения.


### `.github/copilot-instructions.md`

EN:

- **What this is:** GitHub Copilot guidance — points to governing docs and iron laws.
- **Why needed:** Copilot reads this file for repo-specific coding rules.
- **What it contains:** Short priority doc list and architecture reminders.
- **Responsibilities:** Steer Copilot away from forbidden patterns.
- **When to open:** When behavior tied to `copilot-instructions.md` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/audit workflows documented in repo.
- **Connected to:** Flutter `.github` tooling.
- **Layer / owner:** Build/deploy/server configuration.

RU:

- **Что это:** Краткие правила для GitHub Copilot внутри repo — главные ограничения проекта.
- **Зачем:** Copilot видит architecture laws и не предлагает запрещённые PocketBase/Brain паттерны.
- **Содержимое:** Markdown с iron rules, ссылками на governing docs.
- **Обязанности:** Сжатый контекст для Copilot в GitHub UI.
- **Когда открывать:** Copilot предлагает refactor, ломающий Brain/UI или optimistic UI.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `.github/`, Flutter tooling.
- **Слой:** Сборка/деплой/сервер.


### `.github/workflows/deploy.yml`

EN:

- **What this is:** GitHub Actions workflow YAML for web deploy.
- **Why needed:** CI runs these steps on push or manual dispatch.
- **What it contains:** Jobs, checkout, flutter build, artifact upload.
- **Responsibilities:** Automate web deploy per `docs/DEPLOY.md`.
- **When to open:** When behavior tied to `deploy.yml` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/audit workflows documented in repo.
- **Connected to:** Flutter `.github` tooling.
- **Layer / owner:** Build/deploy/server configuration.

RU:

- **Что это:** Workflow GitHub Actions для публикации web-версии. После push собирает Flutter web с base href `/Counter/` и выкладывает на GitHub Pages.
- **Зачем:** Автоматизирует deploy сайта без ручного `update.ps1` на CI runner.
- **Содержимое:** Шаги checkout, `flutter build web`, deploy в `gh-pages` branch.
- **Обязанности:** Собрать и опубликовать web build при push в main.
- **Когда открывать:** Сайт не обновился после merge; проверка CI deploy log.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `.github/`, Flutter tooling.
- **Слой:** CI deploy — не runtime приложения.


### `.github/workflows/windows-desktop-build.yml`

EN:

- **What this is:** GitHub Actions workflow YAML for Windows installer build.
- **Why needed:** CI runs these steps on push or manual dispatch.
- **What it contains:** Jobs, checkout, flutter build, artifact upload.
- **Responsibilities:** Automate Windows installer build per `docs/DEPLOY.md`.
- **When to open:** When behavior tied to `windows-desktop-build.yml` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/audit workflows documented in repo.
- **Connected to:** Flutter `.github` tooling.
- **Layer / owner:** Build/deploy/server configuration.

RU:

- **Что это:** Workflow GitHub Actions для сборки Windows installer `CounterSetup.exe`.
- **Зачем:** Автоматизирует release Windows desktop build и упаковку installer artifact.
- **Содержимое:** Шаги `flutter build windows`, подготовка STT payload, Inno Setup.
- **Обязанности:** Собрать `.exe` installer и загрузить artifact в Actions.
- **Когда открывать:** Нет `CounterSetup.exe` в Actions artifacts после push.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `.github/`, Flutter tooling.
- **Слой:** CI Windows installer — не runtime приложения.


### `.gitignore`

EN:

- **What this is:** Git ignore list — tells Git which files and folders must never be committed.
- **Why needed:** Protects the repo from build output, temp logs, local env secrets, Gradle junk, exports, and IDE cache accidentally landing in git.
- **What it contains:** Ignore patterns for `build/`, `.dart_tool/`, `lib/core/env/env.dart`, perf captures, `exports/`, Android `.gradle`.
- **Responsibilities:** Block secrets and generated artifacts from version control.
- **When to open:** A new local output folder appears and should stay untracked; accidental `git add` of build files.
- **Can it be deleted?** No — repo hygiene and safety.
- **Connected to:** All developers, CI, `flutter build` output paths.
- **Layer / owner:** Repo hygiene — not app runtime.

RU:

- **Что это:** Список того, что Git не должен коммитить: результат сборки, временные логи, локальные env-файлы, Android/Gradle мусор, exports, IDE/cache.
- **Зачем:** Protects the repo from результат сборки, temp logs, local env secrets, Gradle junk, exports, and IDE cache accidentally landing in git.
- **Содержимое:** Паттерны для `build/`, `.dart_tool/`, `lib/core/env/env.dart`, perf captures, `exports/`, `.gradle`.
- **Обязанности:** Не допускать commit build-артефактов и секретов.
- **Когда открывать:** Появилась новая локальная папка, которую нельзя коммитить; случайно добавили build в git.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** Все разработчики, CI, вывод `flutter build`.
- **Слой:** Repo hygiene — не runtime приложения.


### `.metadata`

EN:

- **What this is:** Flutter project metadata card — Flutter CLI reads this to know project type and enabled platforms.
- **Why needed:** Flutter tool uses revision/channel and platform migration data for upgrades and `flutter create` migrations.
- **What it contains:** YAML: `project_type: app`, Flutter stable revision, platform list (root, web, android, …).
- **Responsibilities:** Identify this tree as a Flutter app; track migrate-tool platform revisions.
- **When to open:** Flutter CLI warns about project version mismatch; after `flutter upgrade` changes project metadata.
- **Can it be deleted?** No — unless Flutter safely regenerates it and you verify the diff; normally keep tracked.
- **Connected to:** Flutter CLI, `flutter pub get`, platform folders.
- **Layer / owner:** Flutter tooling metadata — not app runtime.

RU:

- **Что это:** Служебная карточка Flutter-проекта. Flutter CLI использует её, чтобы понимать, что это Flutter app, какие платформы включены и какие project/tooling данные связаны с проектом.
- **Зачем:** Нужна для `flutter upgrade`, migrate и корректной работы CLI с этим деревом.
- **Содержимое:** YAML: тип проекта, revision канала stable, список платформ и migrate-метаданные.
- **Обязанности:** Идентифицировать проект для Flutter CLI.
- **Когда открывать:** CLI ругается на версию проекта; после обновления Flutter изменился `.metadata`.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** Flutter CLI, `pubspec.yaml`, platform-папки.
- **Слой:** Flutter tooling metadata — не runtime приложения.


### `AGENTS.md`

EN:

- **What this is:** Compact root guide for Codex and other AI agents — what to read before editing.
- **Why needed:** Routes assistants to governing docs and iron laws without duplicating full architecture text.
- **What it contains:** Start-here doc list, PocketBase rules summary, structure boundaries, deploy notes.
- **Responsibilities:** First file for Codex; points to `docs/ARCHITECTURE.md` and pack docs.
- **When to open:** Starting Codex or generic agent work in this repo.
- **Can it be deleted?** No — Project Knowledge pack doc #1.
- **Connected to:** `AGENT_NAVIGATION.md`, `docs/APP_STRUCTURE.md`, 14-doc pack.
- **Layer / owner:** Agent instructions — Project Knowledge.

RU:

- **Что это:** Краткий root-гид для Codex и других AI-агентов — что прочитать перед правками.
- **Зачем:** Направляет ассистента к governing docs и iron laws без копирования всей архитектуры.
- **Содержимое:** Список docs «start here», правила PocketBase, границы структуры.
- **Обязанности:** Первый файл для Codex; ссылки на ARCHITECTURE и pack.
- **Когда открывать:** Начало работы Codex/агента в репозитории.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** `AGENT_NAVIGATION.md`, `docs/APP_STRUCTURE.md`.
- **Слой:** Инструкции для AI — Project Knowledge.


### `AGENT_NAVIGATION.md`

EN:

- **What this is:** AI navigation map — file→symbol tables, shipped feature status, where to open first in this repo.
- **Why needed:** Assistants answer ‘where is start/stop record?’ without searching the whole tree; renamed from legacy `CLAUDE.md` filename (no external service dependency).
- **What it contains:** Symbol routing tables, local sync map, Iron Laws pointers, governing doc list.
- **Responsibilities:** Orientation doc for AI sessions; update when symbols move.
- **When to open:** Finding which file owns a feature; starting an AI coding session.
- **Can it be deleted?** No — Project Knowledge pack doc (formerly listed as `CLAUDE.md`).
- **Connected to:** `AGENTS.md`, `docs/ARCHITECTURE.md`, `CHANGELOG.md`, 14-doc pack.
- **Layer / owner:** Agent instructions — Project Knowledge.

RU:

- **Что это:** Карта навигации для AI — таблицы файл→символ, статус фич, куда смотреть первым делом.
- **Зачем:** Чтобы ассистент быстро находил start/stop record и модули brain; файл переименован из legacy `CLAUDE.md` (не привязан к внешнему сервису).
- **Содержимое:** Таблицы символов, offline sync, Iron Laws, список governing docs.
- **Обязанности:** Ориентация для AI; обновлять при переносе символов.
- **Когда открывать:** Ищете, в каком файле живёт фича; начало AI-сессии.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** `AGENTS.md`, `docs/ARCHITECTURE.md`, `CHANGELOG.md`.
- **Слой:** Инструкции для AI — Project Knowledge.


### `CHANGELOG.md`

EN:

- **What this is:** Development journal — dated list of shipped fixes and structure passes.
- **Why needed:** Prevents rebuilding features; shows what already landed and when.
- **What it contains:** Technical bullets with file names, tagged [shipped]/[wip]/[rollback].
- **Responsibilities:** Record verified work after each session; newest entries on top.
- **When to open:** Checking if a bug or feature was already fixed.
- **Can it be deleted?** No — Project Knowledge pack history.
- **Connected to:** Every structure/deploy report, `docs/ROADMAP.md`.
- **Layer / owner:** History — Project Knowledge.

RU:

- **Что это:** Журнал разработки — датированный список shipped-изменений и structure passes.
- **Зачем:** Чтобы не пересобирать уже сделанное; видно, что и когда уже внедрено.
- **Содержимое:** Технические пункты с именами файлов, теги [shipped]/[wip].
- **Обязанности:** Фиксировать проверенную работу; новые записи сверху.
- **Когда открывать:** Проверка, исправляли ли баг или фичу раньше.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** Отчёты structure/deploy, `docs/ROADMAP.md`.
- **Слой:** История — Project Knowledge.


### `README.md`

EN:

- **What this is:** GitHub repository front page — short intro visible to visitors on github.com.
- **Why needed:** First human-readable page for anyone opening the repo; not part of the 14-doc Project Knowledge law pack.
- **What it contains:** Default Flutter starter text (minimal); not the authoritative product spec.
- **Responsibilities:** Orient new visitors; link to Flutter docs.
- **When to open:** Updating public repo description on GitHub.
- **Can it be deleted?** Maybe — GitHub works without it, but keep for repo presentation.
- **Connected to:** GitHub repo home; governing specs live in `docs/`.
- **Layer / owner:** Repo presentation — not app runtime.

RU:

- **Что это:** Главная страница репозитория на GitHub — короткое описание для посетителей.
- **Зачем:** Первое, что видит человек на github.com; это не governing spec (она в `docs/`).
- **Содержимое:** Минимальный starter-текст Flutter.
- **Обязанности:** Ориентация новых посетителей репозитория.
- **Когда открывать:** Обновление публичного описания на GitHub.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** GitHub; законы проекта — в `docs/`.
- **Слой:** Repo presentation — не runtime приложения.


### `analysis_options.yaml`

EN:

- **What this is:** Dart analyzer and lint rule configuration for the whole project.
- **Why needed:** `flutter analyze` and IDE use this to flag errors, warnings, and style issues before merge.
- **What it contains:** `include: package:flutter_lints/flutter.yaml` plus project-specific lint toggles.
- **Responsibilities:** Define static analysis policy for CI and local development.
- **When to open:** Adding/disabling a lint rule; analyzer behaves differently than expected.
- **Can it be deleted?** No — CI and IDE analysis depend on it.
- **Connected to:** `flutter analyze`, CI, all Dart files under `lib/` and `test/`.
- **Layer / owner:** Static analysis config — not app runtime.

RU:

- **Что это:** Настройки Dart analyzer и lint для всего проекта.
- **Зачем:** `flutter analyze` и IDE читают этот файл, чтобы ловить ошибки и стиль до merge.
- **Содержимое:** Подключение `flutter_lints` и локальные переключатели правил.
- **Обязанности:** Политика статического анализа для CI и разработки.
- **Когда открывать:** Добавление/отключение lint; analyzer ведёт себя неожиданно.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** `flutter analyze`, CI, `lib/`, `test/`.
- **Слой:** Static analysis config — не runtime приложения.


### `android.ps1`

EN:

- **What this is:** Local Android release APK builder — split per CPU ABI with git commit stamp in the app.
- **Why needed:** Faster than typing long `flutter build apk` commands; injects `GIT_COMMIT` and `BUILD_TIME` for About/build info screen.
- **What it contains:** `flutter pub get` → `flutter build apk --release --split-per-abi` with dart-defines; retries with `--no-tree-shake-icons` if icon tree-shake fails; prints APK sizes.
- **Responsibilities:** Produce release APKs under `build/app/outputs/flutter-apk/` (main phone file: `app-arm64-v8a-release.apk`).
- **When to open:** Testing release APK on a physical Android device.
- **Can it be deleted?** No — documented local Android build path in `docs/APP_STRUCTURE.md`.
- **Connected to:** `android/` Gradle project, `lib/core/app_build_info.dart`.
- **Layer / owner:** Build tooling — not app runtime.

RU:

- **Что это:** Локальная сборка Android release APK — split per ABI со штампом git commit в About.
- **Зачем:** Короче ручного `flutter build apk`; подставляет `GIT_COMMIT` и `BUILD_TIME`.
- **Содержимое:** `flutter pub get` → `flutter build apk --release --split-per-abi` с dart-defines; при ошибке icon tree-shake — повтор с `--no-tree-shake-icons`; выводит размеры APK.
- **Обязанности:** APK в `build/app/outputs/flutter-apk/` (`app-arm64-v8a-release.apk` для телефонов).
- **Когда открывать:** Тест release APK на физическом Android.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** `android/`, `lib/core/app_build_info.dart`.
- **Слой:** Сборка Android — не runtime логика.


### `android/.gitignore`

EN:

- **What this is:** Git ignore rules for `android` — files not to commit.
- **Why needed:** Prevents build output and secrets from entering git history.
- **What it contains:** Ignore patterns for this folder scope.
- **Responsibilities:** Prevent accidental commit of generated files.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Git ignore для `android/` — не коммитить локальный build-мусор платформы.
- **Зачем:** Gradle/Xcode/CMake генерируют файлы в `android/`, которые не должны попадать в git.
- **Содержимое:** Ignore patterns для build cache и IDE metadata в `android/`.
- **Обязанности:** Держать `android/` tree чистым от generated artifacts.
- **Когда открывать:** Случайно добавили результат сборки `android/` в git.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** Flutter `android` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `android/app/build.gradle.kts`

EN:

- **What this is:** Gradle build script for `android/app` — Android compile settings and plugins.
- **Why needed:** Gradle uses this to compile Kotlin/Java and bundle Flutter Android build.
- **What it contains:** SDK versions, Flutter Gradle plugin hook, dependencies.
- **Responsibilities:** Configure Android compile/target SDK, signing hooks.
- **When to open:** Gradle sync fails, SDK version errors.
- **Can it be deleted?** No — required for Android build.
- **Connected to:** Flutter tooling, `AndroidManifest.xml`.
- **Layer / owner:** Android build config.

RU:

- **Что это:** Gradle-скрипт модуля `android/app` — SDK, plugins, signing, зависимости APK.
- **Зачем:** Именно этот module Gradle превращает Flutter Android build в APK/AAB Counter.
- **Содержимое:** compileSdk, minSdk, Flutter Gradle plugin hook, dependencies.
- **Обязанности:** Настроить compile/target SDK, plugins Flutter, hooks подписи release.
- **Когда открывать:** Ошибка сборки app module, SDK version, signing config.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** `android/settings.gradle.kts`, `AndroidManifest.xml`.
- **Слой:** Android app module build — не Dart UI.


### `android/app/google-services.json`

EN:

- **What this is:** Firebase/Google services config placeholder for Android Gradle plugin.
- **Why needed:** Some Gradle setups expect this file even if Firebase features are unused.
- **What it contains:** JSON project ids (no secrets in repo copy).
- **Responsibilities:** Satisfy Android Gradle google-services plugin if enabled.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Заглушка конфига Firebase/Google services для Android Gradle plugin.
- **Зачем:** Некоторые Gradle setups ожидают файл даже без Firebase features.
- **Содержимое:** JSON project ids (без секретов в repo copy).
- **Обязанности:** Удовлетворить google-services plugin если включён.
- **Когда открывать:** Gradle ищет google-services.json при sync/build.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** Flutter `android` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `android/app/proguard-rules.pro`

EN:

- **What this is:** ProGuard keep rules for Android release minification.
- **Why needed:** R8/ProGuard must not strip Flutter/plugin classes needed at runtime.
- **What it contains:** Keep rules for Flutter embedding.
- **Responsibilities:** Prevent release APK crashes from over-shrinking.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Правила ProGuard/R8 keep для Android release minification.
- **Зачем:** R8/ProGuard не должен вырезать Flutter/plugin classes в release APK.
- **Содержимое:** Правила keep для Flutter embedding и plugins.
- **Обязанности:** Предотвратить crash release APK от over-shrinking.
- **Когда открывать:** Release APK падает после включения minify/shrink.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** Flutter `android` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `android/app/src/debug/AndroidManifest.xml`

EN:

- **What this is:** Android manifest (debug/profile) — declares permissions, app label, and Flutter activity.
- **Why needed:** Android reads XML at install/run to grant mic, notifications, and launch the app.
- **What it contains:** `<uses-permission>`, application name, intent filters.
- **Responsibilities:** Gate OS permissions and deep links for this build variant.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Android manifest (debug) — permissions и overrides для debug-сборки.
- **Зачем:** Debug variant может добавлять или ослаблять permissions для разработки.
- **Содержимое:** Теги `<uses-permission>`, application label, intent filters.
- **Обязанности:** Отличия debug build от release на уровне manifest.
- **Когда открывать:** Debug APK ведёт себя иначе по permissions чем release.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** `android/app/src/main/AndroidManifest.xml`.
- **Слой:** Android manifest debug — не Dart.


### `android/app/src/main/AndroidManifest.xml`

EN:

- **What this is:** Android manifest (release/main) — declares permissions, app label, and Flutter activity.
- **Why needed:** Android reads XML at install/run to grant mic, notifications, and launch the app.
- **What it contains:** `<uses-permission>`, application name, intent filters.
- **Responsibilities:** Gate OS permissions and deep links for this build variant.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Android manifest (release/main) — permissions, label приложения и Flutter activity.
- **Зачем:** Android читает XML при установке: mic, notifications, запуск Counter.
- **Содержимое:** Теги `<uses-permission>`, application label, intent filters.
- **Обязанности:** Задать permissions ОС и deep links для release build.
- **Когда открывать:** Permission denied на устройстве, неверное имя app, intent filters.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** `android/app/build.gradle.kts`, Kotlin MainActivity.
- **Слой:** Android manifest — не Dart business logic.


### `android/app/src/main/kotlin/com/example/counter/MainActivity.kt`

EN:

- **What this is:** Kotlin activity that starts the Flutter engine on Android.
- **Why needed:** Android OS entry point — without it the APK cannot show the Flutter UI.
- **What it contains:** Minimal `FlutterActivity` subclass.
- **Responsibilities:** Boot Flutter when user taps the app icon.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Минимальная Android Activity — поднимает Flutter engine и показывает Dart UI.
- **Зачем:** Без этой Activity APK не может открыть Flutter интерфейс после tap по иконке.
- **Содержимое:** Subclass `FlutterActivity` — несколько строк Kotlin.
- **Обязанности:** Запуск Flutter engine при старте Counter на Android.
- **Когда открывать:** Сборка Android APK или ошибки permissions ОС.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** `AndroidManifest.xml`, Flutter Android embedding.
- **Слой:** Android entry point — не Dart business logic.


### `android/app/src/main/res/drawable-v21/launch_background.xml`

EN:

- **What this is:** Drawable behind Flutter splash while engine loads on Android.
- **Why needed:** Avoids white flash before first Flutter frame.
- **What it contains:** Layer-list XML referencing background color/image.
- **Responsibilities:** Splash appearance on cold start.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** XML-фон splash Android (API 21+) — тот же splash для новых версий ОС.
- **Зачем:** На API 21+ drawable может отличаться от legacy `drawable/` варианта.
- **Содержимое:** Layer-list drawable для splash на API 21+.
- **Обязанности:** Native splash на Android 5.0+ до первого Flutter frame.
- **Когда открывать:** Splash на новых Android отличается от старых или неверный цвет.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** `drawable/launch_background.xml`, `styles.xml`.
- **Слой:** Android drawable resource.


### `android/app/src/main/res/drawable/launch_background.xml`

EN:

- **What this is:** Drawable behind Flutter splash while engine loads on Android.
- **Why needed:** Avoids white flash before first Flutter frame.
- **What it contains:** Layer-list XML referencing background color/image.
- **Responsibilities:** Splash appearance on cold start.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** XML-фон splash Android — показывается до первого кадра Flutter.
- **Зачем:** Убирает белую вспышку при cold start, пока engine грузит UI.
- **Содержимое:** Layer-list drawable с цветом или картинкой фона.
- **Обязанности:** Native splash до появления Flutter content.
- **Когда открывать:** Белая вспышка при launch или неверный цвет splash.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** `styles.xml`, theme в `AndroidManifest.xml`.
- **Слой:** Android drawable resource.


### `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`

EN:

- **What this is:** Launcher icon PNG for Android density `hdpi`.
- **Why needed:** Home screen icon must match pixel density of the device screen.
- **What it contains:** Raster PNG icon asset.
- **Responsibilities:** Display sharp icon on hdpi devices.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG иконка launcher Android (mipmap-hdpi) — иконка Counter на home screen.
- **Зачем:** Для hdpi нужен отдельный размер PNG, иначе icon blur на экране.
- **Содержимое:** Растровый PNG `ic_launcher.png` для hdpi.
- **Обязанности:** Чёткая иконка Counter на устройствах hdpi.
- **Когда открывать:** Размытая или неверная иконка на home screen Android.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** `AndroidManifest.xml` application icon.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`

EN:

- **What this is:** Launcher icon PNG for Android density `mdpi`.
- **Why needed:** Home screen icon must match pixel density of the device screen.
- **What it contains:** Raster PNG icon asset.
- **Responsibilities:** Display sharp icon on mdpi devices.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG иконка launcher Android (mipmap-mdpi) — иконка Counter на home screen.
- **Зачем:** Для этой плотности экрана нужен отдельный размер PNG, иначе icon blur.
- **Содержимое:** Растровый PNG `ic_launcher.png`.
- **Обязанности:** Чёткая иконка Counter на устройствах с этой density.
- **Когда открывать:** Размытая или неверная иконка на home screen Android.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** Flutter `android` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`

EN:

- **What this is:** Launcher icon PNG for Android density `xhdpi`.
- **Why needed:** Home screen icon must match pixel density of the device screen.
- **What it contains:** Raster PNG icon asset.
- **Responsibilities:** Display sharp icon on xhdpi devices.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG иконка launcher Android (mipmap-xhdpi) — иконка Counter на home screen.
- **Зачем:** Для этой плотности экрана нужен отдельный размер PNG, иначе icon blur.
- **Содержимое:** Растровый PNG `ic_launcher.png`.
- **Обязанности:** Чёткая иконка Counter на устройствах с этой density.
- **Когда открывать:** Размытая или неверная иконка на home screen Android.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** Flutter `android` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`

EN:

- **What this is:** Launcher icon PNG for Android density `xxhdpi`.
- **Why needed:** Home screen icon must match pixel density of the device screen.
- **What it contains:** Raster PNG icon asset.
- **Responsibilities:** Display sharp icon on xxhdpi devices.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG иконка launcher Android (mipmap-xxhdpi) — иконка Counter на home screen.
- **Зачем:** Для этой плотности экрана нужен отдельный размер PNG, иначе icon blur.
- **Содержимое:** Растровый PNG `ic_launcher.png`.
- **Обязанности:** Чёткая иконка Counter на устройствах с этой density.
- **Когда открывать:** Размытая или неверная иконка на home screen Android.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** Flutter `android` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

EN:

- **What this is:** Launcher icon PNG for Android density `xxxhdpi`.
- **Why needed:** Home screen icon must match pixel density of the device screen.
- **What it contains:** Raster PNG icon asset.
- **Responsibilities:** Display sharp icon on xxxhdpi devices.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG иконка launcher Android (mipmap-xxxhdpi) — иконка Counter на home screen.
- **Зачем:** Для этой плотности экрана нужен отдельный размер PNG, иначе icon blur.
- **Содержимое:** Растровый PNG `ic_launcher.png`.
- **Обязанности:** Чёткая иконка Counter на устройствах с этой density.
- **Когда открывать:** Размытая или неверная иконка на home screen Android.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** Flutter `android` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `android/app/src/main/res/values-night/styles.xml`

EN:

- **What this is:** Android `night` theme styles for launch window and normal UI chrome.
- **Why needed:** Native Android window uses XML themes before Flutter draws.
- **What it contains:** Theme items for LaunchTheme and NormalTheme.
- **Responsibilities:** Status bar and splash styling on Android.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** XML-стили Android (night) — theme launch и окна в тёмном режиме ОС.
- **Зачем:** Night resources подхватываются когда система в dark mode.
- **Содержимое:** Night variants `LaunchTheme` и `NormalTheme`.
- **Обязанности:** Splash/status bar в dark mode Android.
- **Когда открывать:** Splash/status bar неверны только в тёмной теме ОС.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** `values/styles.xml`, `launch_background.xml`.
- **Слой:** Android styles resource (night).


### `android/app/src/main/res/values/styles.xml`

EN:

- **What this is:** Android `default` theme styles for launch window and normal UI chrome.
- **Why needed:** Native Android window uses XML themes before Flutter draws.
- **What it contains:** Theme items for LaunchTheme and NormalTheme.
- **Responsibilities:** Status bar and splash styling on Android.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** XML-стили Android — theme launch и окна приложения.
- **Зачем:** Задаёт цвета/status bar/splash theme до и после старта Flutter.
- **Содержимое:** Theme `LaunchTheme`, `NormalTheme`, ссылки на `@drawable/launch_background`.
- **Обязанности:** Внешний вид native chrome при launch Android.
- **Когда открывать:** Неверные цвета splash/status bar на Android.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** `launch_background.xml`, `AndroidManifest.xml`.
- **Слой:** Android styles resource.


### `android/app/src/profile/AndroidManifest.xml`

EN:

- **What this is:** Android manifest (debug/profile) — declares permissions, app label, and Flutter activity.
- **Why needed:** Android reads XML at install/run to grant mic, notifications, and launch the app.
- **What it contains:** `<uses-permission>`, application name, intent filters.
- **Responsibilities:** Gate OS permissions and deep links for this build variant.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Android manifest (profile) — permissions, label приложения и Flutter activity.
- **Зачем:** Android читает XML при установке: mic, notifications, запуск Counter.
- **Содержимое:** Теги `<uses-permission>`, application label, intent filters.
- **Обязанности:** Задать permissions ОС и deep links для этой build variant.
- **Когда открывать:** Permission denied на устройстве, неверное имя app, intent filters.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** Flutter `android` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `android/build.gradle.kts`

EN:

- **What this is:** Gradle build script for `android` — Android compile settings and plugins.
- **Why needed:** Gradle uses this to compile Kotlin/Java and bundle Flutter Android build.
- **What it contains:** SDK versions, Flutter Gradle plugin hook, dependencies.
- **Responsibilities:** Configure Android compile/target SDK, signing hooks.
- **When to open:** Gradle sync fails, SDK version errors.
- **Can it be deleted?** No — required for Android build.
- **Connected to:** Flutter tooling, `AndroidManifest.xml`.
- **Layer / owner:** Android build config.

RU:

- **Что это:** Корневой Gradle-скрипт проекта `android/` — общие версии и classpath плагинов.
- **Зачем:** Связывает wrapper, AGP и Flutter Gradle plugin для всего Android tree.
- **Содержимое:** buildscript classpath, allprojects repos, clean task.
- **Обязанности:** Общие настройки Gradle для root Android project.
- **Когда открывать:** Root Gradle sync fail, classpath/plugin version errors.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** `android/settings.gradle.kts`, `android/app/`.
- **Слой:** Android root Gradle — не Dart.


### `android/gradle.properties`

EN:

- **What this is:** Gradle `gradle.properties` — JVM/ AndroidX flags or local SDK path.
- **Why needed:** Gradle reads properties to locate Android SDK and tune build.
- **What it contains:** Key=value lines (local SDK path often gitignored).
- **Responsibilities:** Configure Gradle daemon and SDK location.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Свойства Gradle Android — JVM args, AndroidX flags и версии toolchain.
- **Зачем:** Gradle читает defaults отсюда до сборки `:app` module.
- **Содержимое:** Строки key=value; часто local SDK path в gitignore.
- **Обязанности:** Общие Gradle/Android build settings для Counter.
- **Когда открывать:** Сборка Android APK или ошибки permissions ОС.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** Flutter `android` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `android/gradle/wrapper/gradle-wrapper.properties`

EN:

- **What this is:** Gradle Wrapper properties — pins Gradle distribution URL and version for Android builds.
- **Why needed:** CI and local machines must run the same Gradle version when building APK/AAB.
- **What it contains:** `distributionUrl`, `distributionSha256Sum` for the wrapper.
- **Responsibilities:** Pin Gradle distribution for the entire `android/` tree.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Gradle Wrapper properties для Android build. Фиксирует Gradle distribution URL/version, чтобы CI и локальная машина запускали одну и ту же Gradle-версию.
- **Зачем:** Без pinned Gradle version Android sync на CI и у разработчика расходятся.
- **Содержимое:** `distributionUrl`, `distributionSha256Sum` для Gradle wrapper.
- **Обязанности:** Pin Gradle distribution для всего `android/` tree.
- **Когда открывать:** Gradle wrapper version mismatch; CI Android build использует другую Gradle.
- **Можно удалить?** Нет — без него `./gradlew` не скачает нужную Gradle.
- **Связано с:** `android/gradlew`, `android/settings.gradle.kts`.
- **Слой:** Android Gradle wrapper — не Dart.


### `android/settings.gradle.kts`

EN:

- **What this is:** Gradle settings — declares included modules (`:app`).
- **Why needed:** Root Gradle project must list app module to compile APK.
- **What it contains:** Module includes, plugin management.
- **Responsibilities:** Wire Gradle multi-module Android project.
- **When to open:** Android APK build or permission issues.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `android` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Gradle settings — подключает модули Android-проекта и версии плагинов.
- **Зачем:** Gradle читает этот файл первым, чтобы знать какие модули собирать.
- **Содержимое:** Список include modules, pluginManagement, версии AGP.
- **Обязанности:** Задать структуру multi-module Gradle проекта Counter.
- **Когда открывать:** Gradle sync падает на settings или не видит `:app` module.
- **Можно удалить?** Нет — без него не соберётся Android APK.
- **Связано с:** `android/build.gradle.kts`, `android/app/build.gradle.kts`.
- **Слой:** Android Gradle config — не Dart.


### `docs/APP_STRUCTURE.md`

EN:

- **What this is:** Concise map of folders, layers, import rules, and guard commands.
- **Why needed:** Quick answer to ‘where does X live?’ without reading the full encyclopedia.
- **What it contains:** Tables of `lib/data`, features, scripts; architecture guard entry points.
- **Responsibilities:** Canonical structure contract referenced by guard and AI assistants.
- **When to open:** Finding module ownership; before moving or renaming files.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** `APP_STRUCTURE_DETAILED.md`, `architecture_guard.ps1`.
- **Layer / owner:** Governing structure doc — Project Knowledge pack.

RU:

- **Что это:** Краткая карта структуры repo — папки, слои, import rules, команды guard.
- **Зачем:** Быстрый ответ «где живёт X» без чтения всей encyclopedia.
- **Содержимое:** Таблицы `lib/data`, features, scripts; команды architecture guard.
- **Обязанности:** Канонический structure contract для guard и AI.
- **Когда открывать:** Ищете ownership модуля; перед переносом файлов.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** `docs/APP_STRUCTURE_DETAILED.md`, `scripts/audit/architecture_guard.ps1`.
- **Слой:** Документация — правила, не runtime.


### `docs/APP_STRUCTURE_DETAILED.md`

EN:

- **What this is:** Full owner-readable encyclopedia of every tracked folder and file (EN + RU), generated from the repo tree.
- **Why needed:** Source text for the HTML owner map and deep onboarding; complements the concise `APP_STRUCTURE.md`.
- **What it contains:** Per-path EN/RU blocks: what, why, contains, responsibilities, when, delete, connected, layer.
- **Responsibilities:** Explain every tracked path in plain language for owner and AI; regenerate after tree changes.
- **When to open:** Onboarding, auditing repo necessity, or checking what a path does before editing.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** `generate_app_structure_detailed.py`, `APP_STRUCTURE.md`, `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Generated structure encyclopedia — Project Knowledge pack.

RU:

- **Что это:** Полная owner-readable encyclopedia каждой tracked папки и файла (EN+RU), генерируется из дерева repo.
- **Зачем:** Источник для HTML owner map и глубокого onboarding; дополняет краткий `APP_STRUCTURE.md`.
- **Содержимое:** Блоки EN/RU на каждый путь: что, зачем, содержимое, обязанности, когда открывать, удаление, связи, слой.
- **Обязанности:** Объяснить каждый tracked путь plain language для owner и AI; перегенерировать после изменений дерева.
- **Когда открывать:** Onboarding, audit «нужен ли файл», проверка роли пути перед правкой.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** `scripts/manual/generate_app_structure_detailed.py`, `docs/APP_STRUCTURE.md`.
- **Слой:** Сгенерированная structure encyclopedia — Project Knowledge pack.


### `docs/ARCHITECTURE.md`

EN:

- **What this is:** Iron Laws — optimistic UI, Brain/UI split, PocketBase rules, main-thread and performance kill-switch law.
- **Why needed:** Authoritative technical contract for how the system must behave under load and offline.
- **What it contains:** Data flow, offline outboxes, singleton running record, anti-spam polling, performance law.
- **Responsibilities:** Answer ‘how must the app work?’ before refactors or new Brain/UI patterns.
- **When to open:** Architecture disputes, performance regressions, or optimistic UI violations.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** `docs/DATA_MAP.md`, `docs/POCKETBASE_MANIFEST.md`, `docs/UX_CONTRACT.md`.
- **Layer / owner:** Governing architecture doc — Project Knowledge pack.

RU:

- **Что это:** Железные законы проекта — optimistic UI, Brain/UI split, PocketBase, main-thread law.
- **Зачем:** Авторитетный технический контракт для owner и AI.
- **Содержимое:** Правила data flow, offline, singleton record, performance.
- **Обязанности:** Ответ на «как система обязана работать».
- **Когда открывать:** Спор об architecture; перед refactor Brain или UI.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** `docs/DATA_MAP.md`, `docs/POCKETBASE_MANIFEST.md`, `docs/UX_CONTRACT.md`.
- **Слой:** Документация — правила, не runtime.


### `docs/DATA_MAP.md`

EN:

- **What this is:** Field dictionary for PocketBase — column names, business IDs, relation fields.
- **Why needed:** Brain and UI must POST/PATCH the same field names; prevents invented alternate keys.
- **What it contains:** Tables for records, plans, categories, tags, profiles and relation semantics.
- **Responsibilities:** Single source of truth for field names aligned with `lib/data/models/`.
- **When to open:** Parse errors on PB fields; adding or renaming a schema field.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** `docs/POCKETBASE_MANIFEST.md`, `lib/data/models/`.
- **Layer / owner:** Governing data doc — Project Knowledge pack.

RU:

- **Что это:** Словарь полей PocketBase — имена колонок, business IDs, relation fields.
- **Зачем:** Brain и UI должны использовать одни имена полей при POST/PATCH.
- **Содержимое:** Таблицы records, plans, categories, tags, profiles.
- **Обязанности:** SSOT имён полей — не выдумывать alternate names.
- **Когда открывать:** Ошибка parse поля PB; добавление нового поля в schema.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** `docs/POCKETBASE_MANIFEST.md`, `lib/data/models/`.
- **Слой:** Документация — правила, не runtime.


### `docs/DEPLOY.md`

EN:

- **What this is:** Step-by-step deploy — GitHub Pages web app, PocketBase auth admin, Windows installer.
- **Why needed:** Deploy and OAuth break easily without VPS checklist and `update.ps1` order.
- **What it contains:** `update.ps1`, GitHub Pages base href, Windows installer, OAuth admin steps.
- **Responsibilities:** Publish site and configure production auth without guessing server steps.
- **When to open:** Site not updating after merge; OAuth broken; building `CounterSetup.exe`.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** `.github/workflows/`, `update.ps1`, `installer/windows/`.
- **Layer / owner:** Deploy guide — Project Knowledge pack.

RU:

- **Что это:** Пошаговый deploy — GitHub Pages, PocketBase auth admin, Windows installer.
- **Зачем:** Deploy и OAuth легко сломать без VPS checklist.
- **Содержимое:** `update.ps1`, GitHub Pages base href, Windows installer, шаги OAuth admin.
- **Обязанности:** Инструкция публикации сайта и production auth.
- **Когда открывать:** Сайт не обновился; OAuth broken; сборка installer.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** `.github/workflows/`, `update.ps1`, `installer/windows/`.
- **Слой:** Документация — правила, не runtime.


### `docs/DESIGN_SYSTEM.md`

EN:

- **What this is:** Design system contract — Figma → Flutter mapping and canonical shared components.
- **Why needed:** Forbids local copies of buttons/cards in feature screens; V7 migration target.
- **What it contains:** Token categories, `AppButton`, `AppIconButton`, forbidden raw Material in features.
- **Responsibilities:** Rules for Component Lab acceptance and production UI migration.
- **When to open:** Migrating UI to canonical widgets; pixel QA against Figma.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** `lib/core/widgets/`, `docs/reports/DESIGN_SYSTEM_INVENTORY.md`, Component Lab.
- **Layer / owner:** Governing design doc — Project Knowledge pack.

RU:

- **Что это:** Design system контракт — Figma → Flutter mapping, canonical components.
- **Зачем:** Запрещает локальные копии кнопок/карточек в feature screens.
- **Содержимое:** Token categories, `AppButton`, `AppIconButton`, запрет raw Material в features.
- **Обязанности:** Правила V7 component migration и Component Lab acceptance.
- **Когда открывать:** Миграция UI на canonical widgets; pixel QA.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** `lib/core/widgets/`, `docs/reports/DESIGN_SYSTEM_INVENTORY.md`, Component Lab.
- **Слой:** Документация — правила, не runtime.


### `docs/POCKETBASE_MANIFEST.md`

EN:

- **What this is:** Production PocketBase law — base URL, collections, auth, relations, expand paths, hooks, server rules.
- **Why needed:** Client Brain must not invent URL shapes, relation payloads, or hook behavior.
- **What it contains:** Collection table, auth id law, API routes, `pb_hooks/` deployment notes, rule intent.
- **Responsibilities:** Single manifest for how Counter talks to PocketBase in production.
- **When to open:** PB 401/403, wrong expand, hook deploy, or schema mismatch with `DATA_MAP.md`.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** `lib/data/pb_config.dart`, `docs/DATA_MAP.md`, `pb_hooks/`.
- **Layer / owner:** Governing PocketBase doc — Project Knowledge pack.

RU:

- **Что это:** Закон production PocketBase — collections, URLs, auth/providers, hooks, ожидания сервера и факты schema/deploy.
- **Зачем:** Brain не должен выдумывать URL shapes, relation payloads или поведение hooks на VPS.
- **Содержимое:** Таблица collections, auth id law, API routes, deploy `pb_hooks/`, intent API rules.
- **Обязанности:** Единый manifest: как Counter общается с PocketBase в production.
- **Когда открывать:** PB 401/403, неверный expand, deploy hook, расхождение schema с `DATA_MAP.md`.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** `lib/data/pb_config.dart`, `docs/DATA_MAP.md`, `pb_hooks/`.
- **Слой:** Документация — правила, не runtime.


### `docs/PROJECT_KNOWLEDGE_PACK.md`

EN:

- **What this is:** Upload checklist for Claude Project Knowledge — which 14 docs to attach, which stay repo-only.
- **Why needed:** Owner limit (~25 uploads); this file is meta — not architecture law itself.
- **What it contains:** Included pack list, excluded repo-only docs, removed-doc log.
- **Responsibilities:** Tell owner/AI what to upload without duplicating governing docs incorrectly.
- **When to open:** Refreshing Claude Project files or arguing which doc is authoritative.
- **Can it be deleted?** No — current cleanup/structure report or upload checklist.
- **Connected to:** The 14 governing docs listed inside; `docs/APP_STRUCTURE.md`.
- **Layer / owner:** Meta checklist — repo-only, not uploaded as law.

RU:

- **Что это:** Чеклист upload для AI Project Knowledge: какие docs загружать, какие остаются только в repo.
- **Зачем:** Лимит upload у owner (~25 файлов); это meta-чеклист, а не architecture law.
- **Содержимое:** Список 14 docs для upload, excluded repo-only, log удалённых docs.
- **Обязанности:** Сказать owner/AI что uploadить — без путаницы governing docs и repo-only.
- **Когда открывать:** Обновление Project Knowledge или спор «какой doc канонический».
- **Можно удалить?** Нет — актуальный отчёт или чеклист.
- **Связано с:** 14 governing docs внутри файла; `docs/APP_STRUCTURE.md`.
- **Слой:** Meta-чеклист — repo-only, не architecture law.


### `docs/ROADMAP.md`

EN:

- **What this is:** Current work plan — shipped/WIP priorities, V3/V7 focus, paused feature scope, what to do next.
- **Why needed:** Single canonical plan so AI and owner do not maintain a second roadmap elsewhere.
- **What it contains:** Correctness vs velocity tracks, phase status, O1/V1/F1 shipped notes, active V3/V7 scope.
- **Responsibilities:** Prioritize bugs and compounding tidy work before new feature scope.
- **When to open:** Before planning new feature work or choosing the next session goal.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** `docs/UX_CONTRACT.md`, `docs/DESIGN_SYSTEM.md`, `docs/ARCHITECTURE.md`.
- **Layer / owner:** Governing plan doc — Project Knowledge pack.

RU:

- **Что это:** Текущий план работ: shipped/WIP приоритеты, фокус V3/V7, paused feature scope и что делать дальше.
- **Зачем:** Единый canonical plan — чтобы AI и owner не вели второй roadmap в других файлах.
- **Содержимое:** Correctness vs velocity tracks, статусы фаз, shipped O1/V1/F1, активный scope V3/V7.
- **Обязанности:** Приоритизировать bugs и compounding tidy work перед новым feature scope.
- **Когда открывать:** Перед планированием новой feature work или выбором цели следующей сессии.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** `docs/UX_CONTRACT.md`, `docs/DESIGN_SYSTEM.md`, `docs/ARCHITECTURE.md`.
- **Слой:** Документация — правила, не runtime.


### `docs/UX_CONTRACT.md`

EN:

- **What this is:** Tap-first UX rules — save/loading/offline behavior, optimistic UI, banners, user-visible contracts.
- **Why needed:** Behavioral source beside `ARCHITECTURE.md`; screens must follow before inventing new patterns.
- **What it contains:** 100ms feedback, shadow state, debounced errors, empty/loading/offline, sheet close rules.
- **Responsibilities:** Define how taps, saves, and sync banners must feel to the user.
- **When to open:** Before changing interaction flows, edit sheets, or offline banner behavior.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** `docs/ARCHITECTURE.md`, `lib/app_shell.dart` offline bar, `docs/DESIGN_SYSTEM.md`.
- **Layer / owner:** Governing UX doc — Project Knowledge pack.

RU:

- **Что это:** Tap-first UX rules: save/loading/offline, optimistic UI, banners и контракты поведения для пользователя.
- **Зачем:** Behavioral source рядом с `ARCHITECTURE.md`; экраны обязаны следовать до новых паттернов.
- **Содержимое:** 100ms feedback, shadow state, debounced errors, empty/loading/offline, правила sheet close.
- **Обязанности:** Как taps, saves и sync banners должны ощущаться пользователю.
- **Когда открывать:** Перед изменением interaction flows, edit sheets или offline banner.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** `docs/ARCHITECTURE.md`, offline bar в `app_shell.dart`, `docs/DESIGN_SYSTEM.md`.
- **Слой:** Документация — правила, не runtime.


### `docs/reports/DESIGN_SYSTEM_INVENTORY.md`

EN:

- **What this is:** Audit inventory of raw vs canonical UI — what feature screens still use forbidden local widgets.
- **Why needed:** V7 migration needs a scoped list before replacing buttons/cards screen by screen.
- **What it contains:** Classification legend, per-screen raw `FilledButton`/`IconButton` counts, migration status.
- **Responsibilities:** Track design-system debt; pair with Component Lab acceptance.
- **When to open:** Planning V7 UI migration or verifying a screen is canonical-compliant.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** `docs/DESIGN_SYSTEM.md`, `lib/features/dev/component_lab_view.dart`.
- **Layer / owner:** Repo-only audit report — not Project Knowledge pack.

RU:

- **Что это:** Audit inventory raw vs canonical UI — какие feature screens ещё используют forbidden local widgets.
- **Зачем:** V7 migration нужен scoped list перед заменой buttons/cards по экранам.
- **Содержимое:** Classification legend, per-screen counts raw buttons, статус migration.
- **Обязанности:** Отслеживать design-system debt; в паре с Component Lab acceptance.
- **Когда открывать:** Планирование V7 UI migration или проверка canonical-compliance экрана.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** `docs/DESIGN_SYSTEM.md`, `lib/features/dev/component_lab_view.dart`.
- **Слой:** Документация — правила, не runtime.


### `docs/reports/FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md`

EN:

- **What this is:** Session report — structure parity fixes and APP_STRUCTURE_DETAILED doc cleanup acceptance criteria.
- **Why needed:** Records what was verified fixed so later sessions do not re-debate the same doc gates.
- **What it contains:** Before/after notes, quality gate checklist, paths touched in generator scripts.
- **Responsibilities:** Historical evidence for 2026-07-03 structure/doc cleanup arc.
- **When to open:** Checking why a doc quality rule exists or what ‘accepted’ meant that day.
- **Can it be deleted?** No — current cleanup/structure report or upload checklist.
- **Connected to:** `docs/APP_STRUCTURE_DETAILED.md`, `generate_app_structure_detailed.py`.
- **Layer / owner:** Repo-only session report.

RU:

- **Что это:** Отчёт сессии — structure parity fixes и критерии приёмки cleanup `APP_STRUCTURE_DETAILED`.
- **Зачем:** Фиксирует что уже verified fixed — чтобы следующие сессии не спорили о тех же doc gates.
- **Содержимое:** Before/after notes, checklist quality gate, пути в generator scripts.
- **Обязанности:** Историческое evidence для arc structure/doc cleanup 2026-07-03.
- **Когда открывать:** Проверка почему существует doc quality rule или что значило «accepted» в тот день.
- **Можно удалить?** Нет — актуальный отчёт или чеклист.
- **Связано с:** `docs/APP_STRUCTURE_DETAILED.md`, `generate_app_structure_detailed.py`.
- **Слой:** Документация — правила, не runtime.


### `docs/reports/FULL_REPO_NECESSITY_CLEANUP_2026-07-03.md`

EN:

- **What this is:** Full-repo necessity audit — which tracked paths are required vs optional hygiene.
- **Why needed:** Supports deleting or ignoring dead files without breaking build, deploy, or governing docs.
- **What it contains:** Tier labels, platform vs app vs docs classification, cleanup recommendations.
- **Responsibilities:** Answer ‘can we delete this folder?’ with evidence, not guesswork.
- **When to open:** Repo bloat debate, pre-commit cleanup, or onboarding ‘what is safe to ignore’.
- **Can it be deleted?** No — current cleanup/structure report or upload checklist.
- **Connected to:** `docs/APP_STRUCTURE_DETAILED.md`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** Repo-only audit report.

RU:

- **Что это:** Full-repo necessity audit — какие tracked paths обязательны vs optional hygiene.
- **Зачем:** Помогает удалять dead files без поломки build, deploy или governing docs.
- **Содержимое:** Tier labels, классификация platform vs app vs docs, рекомендации cleanup.
- **Обязанности:** Ответ «можно ли удалить эту папку?» с evidence, не guesswork.
- **Когда открывать:** Спор о repo bloat, pre-commit cleanup, onboarding «что safe ignore».
- **Можно удалить?** Нет — актуальный отчёт или чеклист.
- **Связано с:** `docs/APP_STRUCTURE_DETAILED.md`, `docs/APP_STRUCTURE.md`.
- **Слой:** Документация — правила, не runtime.


### `docs/website/CONTENT_LIBRARY.md`

EN:

- **What this is:** Website content library — reusable EN/RU blocks for CMS, designers, and copywriters.
- **Why needed:** Ensures product names, positioning, and feature blurbs stay consistent across pages.
- **What it contains:** Product names table, positioning statements, feature one-liners, FAQ snippets.
- **Responsibilities:** Source blocks for `PUBLIC_COPY_DRAFTS.md` and future static site pages.
- **When to open:** Writing or translating marketing copy; avoiding duplicate phrasing across pages.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** `docs/website/PUBLIC_COPY_DRAFTS.md`, `docs/website/FEATURE_MATRIX.md`.
- **Layer / owner:** Repo-only marketing content — not Project Knowledge pack.

RU:

- **Что это:** Content library сайта — переиспользуемые EN/RU блоки для CMS, designers и copywriters.
- **Зачем:** Держит product names, positioning и feature blurbs согласованными между страницами.
- **Содержимое:** Таблица product names, positioning statements, feature one-liners, FAQ snippets.
- **Обязанности:** Source blocks для `PUBLIC_COPY_DRAFTS.md` и будущих static pages.
- **Когда открывать:** Написание/перевод marketing copy; избежание duplicate phrasing между страницами.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** `docs/website/PUBLIC_COPY_DRAFTS.md`, `docs/website/FEATURE_MATRIX.md`.
- **Слой:** Документация — правила, не runtime.


### `docs/website/FEATURE_MATRIX.md`

EN:

- **What this is:** Website feature matrix — which product capabilities appear on v1 site vs deferred.
- **Why needed:** Prevents over-promising on landing pages; aligns with `WEBSITE_V1_SCOPE.md`.
- **What it contains:** Tier tables (hero / soft / excluded), platform and honesty flags per feature.
- **Responsibilities:** Gate marketing claims against real shipped app behavior.
- **When to open:** Choosing hero screenshots or writing Features page bullets.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** `docs/website/WEBSITE_V1_SCOPE.md`, `docs/website/WEBSITE_CLAIMS_REVIEW.md`.
- **Layer / owner:** Repo-only marketing planning.

RU:

- **Что это:** Feature matrix сайта — какие capabilities продукта на v1 site vs deferred.
- **Зачем:** Не over-promise на landing; согласован с `WEBSITE_V1_SCOPE.md`.
- **Содержимое:** Tier tables (hero / soft / excluded), platform и honesty flags по feature.
- **Обязанности:** Gate marketing claims против реального shipped behavior приложения.
- **Когда открывать:** Выбор hero screenshots или bullets для Features page.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** `docs/website/WEBSITE_V1_SCOPE.md`, `docs/website/WEBSITE_CLAIMS_REVIEW.md`.
- **Слой:** Документация — правила, не runtime.


### `docs/website/HOMEPAGE_WIREFRAME_V1.md`

EN:

- **What this is:** Homepage wireframe v1 — section order, hero, feature strips, FAQ teaser, primary CTA.
- **Why needed:** Static v1 landing must fit one scroll story before pixel implementation.
- **What it contains:** ASCII/block layout notes, CTA placement, screenshot slots.
- **Responsibilities:** Blueprint for `/` or `/index.html` marketing shell beside Flutter web app.
- **When to open:** Designing or implementing the public homepage layout.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** `docs/website/WEBSITE_PAGE_STRUCTURE.md`, `docs/website/SCREENSHOT_SHOTLIST.md`.
- **Layer / owner:** Repo-only marketing wireframe.

RU:

- **Что это:** Homepage wireframe v1 — порядок секций, hero, feature strips, FAQ teaser, primary CTA.
- **Зачем:** Static v1 landing должен уложиться в one scroll story до pixel implementation.
- **Содержимое:** ASCII/block layout notes, placement CTA, слоты screenshots.
- **Обязанности:** Blueprint для marketing shell `/` рядом с Flutter web app.
- **Когда открывать:** Правила проекта и деплой — не runtime.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** `docs/website/WEBSITE_PAGE_STRUCTURE.md`, `docs/website/SCREENSHOT_SHOTLIST.md`.
- **Слой:** Документация — правила, не runtime.


### `docs/website/INTERNAL_NOTES_NOT_FOR_SITE.md`

EN:

- **What this is:** Internal website notes — strategy and risks not for public copy.
- **Why needed:** Separates honest internal debate from visitor-facing drafts.
- **What it contains:** Open questions, competitor notes, defer lists, tone guardrails.
- **Responsibilities:** Owner-only context; must not be pasted into live site verbatim.
- **When to open:** Deciding positioning trade-offs without polluting public drafts.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** `docs/website/POSITIONING_V1.md`, `exports/` if present.
- **Layer / owner:** Repo-only internal notes.

RU:

- **Что это:** Internal notes по сайту — strategy и risks не для public copy.
- **Зачем:** Отделяет honest internal debate от visitor-facing drafts.
- **Содержимое:** Открытые вопросы, заметки о конкурентах, defer lists, tone guardrails.
- **Обязанности:** Owner-only context; нельзя paste verbatim на live site.
- **Когда открывать:** Trade-offs positioning без загрязнения public drafts.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** `docs/website/POSITIONING_V1.md`, `exports/` если есть.
- **Слой:** Документация — правила, не runtime.


### `docs/website/POSITIONING_V1.md`

EN:

- **What this is:** Website positioning v1 — promise, audience, differentiation vs generic time trackers.
- **Why needed:** Hero and meta description must say one clear sentence, not feature soup.
- **What it contains:** Headline options, anti-patterns, traveler/offline angles.
- **Responsibilities:** Anchor all v1 public copy to the same product promise.
- **When to open:** Rewriting hero, tagline, or social preview text.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** `docs/website/CONTENT_LIBRARY.md`, `docs/website/PUBLIC_COPY_DRAFTS.md`.
- **Layer / owner:** Repo-only marketing positioning.

RU:

- **Что это:** Positioning v1 сайта — promise, audience, отличие от обычных time trackers.
- **Зачем:** Hero и meta description должны давать one clear sentence, не feature soup.
- **Содержимое:** Варианты headline, anti-patterns, traveler/offline angles.
- **Обязанности:** Якорь всего v1 public copy на одном product promise.
- **Когда открывать:** Правила проекта и деплой — не runtime.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** `docs/website/CONTENT_LIBRARY.md`, `docs/website/PUBLIC_COPY_DRAFTS.md`.
- **Слой:** Документация — правила, не runtime.


### `docs/website/PRODUCT_INVENTORY.md`

EN:

- **What this is:** Product inventory for website — shipped surfaces mapped to marketing names.
- **Why needed:** Copywriters need accurate feature names tied to real tabs and flows.
- **What it contains:** Tab index map, feature aliases, screenshot-friendly labels.
- **Responsibilities:** Prevent website from inventing features the app does not ship.
- **When to open:** Naming Features page sections or tour captions.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** `docs/APP_STRUCTURE.md`, `docs/website/FEATURE_MATRIX.md`.
- **Layer / owner:** Repo-only product/marketing bridge.

RU:

- **Что это:** Product inventory для сайта — shipped surfaces с marketing names.
- **Зачем:** Copywriters нужны accurate feature names, привязанные к real tabs и flows.
- **Содержимое:** Tab index map, feature aliases, подписи для screenshots.
- **Обязанности:** Не дать сайту invent features, которых нет в shipped app.
- **Когда открывать:** Naming секций Features page или tour captions.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** `docs/APP_STRUCTURE.md`, `docs/website/FEATURE_MATRIX.md`.
- **Слой:** Документация — правила, не runtime.


### `docs/website/PUBLIC_COPY_DRAFTS.md`

EN:

- **What this is:** Public copy drafts — polished EN/RU visitor text ready for static pages.
- **Why needed:** Separates draft polish from internal notes and content library atoms.
- **What it contains:** Page-ready paragraphs, FAQ answers, CTA strings.
- **Responsibilities:** Candidate text for GitHub Pages marketing shell — review before publish.
- **When to open:** Implementing HTML pages or reviewing tone before deploy.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** `docs/website/CONTENT_LIBRARY.md`, `docs/website/WEBSITE_CLAIMS_REVIEW.md`.
- **Layer / owner:** Repo-only public copy drafts.

RU:

- **Что это:** Черновики public copy — polished EN/RU visitor text для static pages.
- **Зачем:** Отделяет draft polish от internal notes и atoms content library.
- **Содержимое:** Готовые абзацы страниц, FAQ answers, CTA strings.
- **Обязанности:** Candidate text для marketing shell GitHub Pages — review перед publish.
- **Когда открывать:** Implementation HTML pages или review tone перед deploy.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** `docs/website/CONTENT_LIBRARY.md`, `docs/website/WEBSITE_CLAIMS_REVIEW.md`.
- **Слой:** Документация — правила, не runtime.


### `docs/website/SCREENSHOT_SHOTLIST.md`

EN:

- **What this is:** Screenshot shotlist — six curated captures, captions, and honesty notes for v1 tour.
- **Why needed:** Tour page quality depends on planned shots, not random emulator grabs.
- **What it contains:** Per-shot route, device density, caption EN/RU, soft-claim warnings.
- **Responsibilities:** Define which UI states must be captured before website launch.
- **When to open:** Preparing `/tour` gallery or marketing assets export.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** `docs/website/HOMEPAGE_WIREFRAME_V1.md`, `docs/website/WEBSITE_V1_SCOPE.md`.
- **Layer / owner:** Repo-only marketing asset plan.

RU:

- **Что это:** Screenshot shotlist — шесть curated captures, captions и honesty notes для v1 tour.
- **Зачем:** Tour page quality зависит от planned shots, не random emulator grabs.
- **Содержимое:** Per-shot route, device density, caption EN/RU, предупреждения soft-claim.
- **Обязанности:** Какие UI states capture перед website launch.
- **Когда открывать:** Подготовка gallery `/tour` или export marketing assets.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** `docs/website/HOMEPAGE_WIREFRAME_V1.md`, `docs/website/WEBSITE_V1_SCOPE.md`.
- **Слой:** Документация — правила, не runtime.


### `docs/website/WEBSITE_CLAIMS_REVIEW.md`

EN:

- **What this is:** Website claims review — fact-check marketing statements against shipped app behavior.
- **Why needed:** Prevents false promises (auto-save, drag Time View, store badges) on public pages.
- **What it contains:** Claim / evidence / verdict table, red-line exclusions for v1.
- **Responsibilities:** Legal-honest gate before any copy goes live.
- **When to open:** Editing hero, FAQ, or Features page; before approving deploy.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** `docs/website/FEATURE_MATRIX.md`, `docs/UX_CONTRACT.md`.
- **Layer / owner:** Repo-only claims audit.

RU:

- **Что это:** Claims review сайта — fact-check marketing statements против shipped app behavior.
- **Зачем:** Предотвращает false promises (auto-save, drag Time View, store badges) на public pages.
- **Содержимое:** Таблица claim / evidence / verdict, red-line exclusions для v1.
- **Обязанности:** Legal-honest gate перед publish любого copy.
- **Когда открывать:** Правка hero, FAQ или Features page; перед approve deploy.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** `docs/website/FEATURE_MATRIX.md`, `docs/UX_CONTRACT.md`.
- **Слой:** Документация — правила, не runtime.


### `docs/website/WEBSITE_IMPLEMENTATION_OPTIONS.md`

EN:

- **What this is:** Website implementation options — static HTML vs generator vs Flutter-adjacent trade-offs.
- **Why needed:** Marketing site must not break `/Counter/` Flutter web deploy path.
- **What it contains:** Pros/cons tables, GitHub Pages constraints, base href notes.
- **Responsibilities:** Choose build approach for v1 without forking app release pipeline.
- **When to open:** Starting website code or arguing static vs integrated hosting.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** `docs/DEPLOY.md`, `docs/website/WEBSITE_V1_SCOPE.md`.
- **Layer / owner:** Repo-only implementation planning.

RU:

- **Что это:** Варианты реализации сайта — static HTML, generator или Flutter-adjacent подходы.
- **Зачем:** Marketing site не должен ломать deploy path Flutter web `/Counter/`.
- **Содержимое:** Pros/cons tables, ограничения GitHub Pages, notes base href.
- **Обязанности:** Выбор build approach для v1 без fork app release pipeline.
- **Когда открывать:** Старт website code или спор static vs integrated hosting.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** `docs/DEPLOY.md`, `docs/website/WEBSITE_V1_SCOPE.md`.
- **Слой:** Документация — правила, не runtime.


### `docs/website/WEBSITE_PAGE_STRUCTURE.md`

EN:

- **What this is:** Website page structure — v2+ full sitemap reference (routes, nav, page purposes).
- **Why needed:** v1 uses fewer pages; this doc holds the longer information architecture target.
- **What it contains:** Route list, nav hierarchy, deferred pages beyond v1 scope.
- **Responsibilities:** Future expansion map — do not treat every route as v1 commitment.
- **When to open:** Planning v2 SEO split or additional marketing routes.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** `docs/website/WEBSITE_V1_SCOPE.md`, `docs/website/HOMEPAGE_WIREFRAME_V1.md`.
- **Layer / owner:** Repo-only IA reference.

RU:

- **Что это:** Page structure сайта — v2+ full sitemap reference (routes, nav, purposes страниц).
- **Зачем:** v1 использует меньше pages; здесь longer information architecture target.
- **Содержимое:** Список routes, nav hierarchy, отложенные pages beyond v1 scope.
- **Обязанности:** Future expansion map — не каждый route = v1 commitment.
- **Когда открывать:** Планирование v2 SEO split или дополнительных marketing routes.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** `docs/website/WEBSITE_V1_SCOPE.md`, `docs/website/HOMEPAGE_WIREFRAME_V1.md`.
- **Слой:** Документация — правила, не runtime.


### `docs/website/WEBSITE_TZ.md`

EN:

- **What this is:** Website TZ (technical brief) — timezone and legal copy requirements for public pages.
- **Why needed:** FAQ must honestly explain profile timezone vs device time without legal overreach.
- **What it contains:** Timezone FAQ bullets, privacy tone, RU summary section rules for v1.
- **Responsibilities:** Keep legal/timezone messaging aligned with real app settings UX.
- **When to open:** Writing FAQ, privacy footer, or RU summary blocks on Home.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** `docs/website/PUBLIC_COPY_DRAFTS.md`, profile timezone in app.
- **Layer / owner:** Repo-only legal/timezone copy brief.

RU:

- **Что это:** TZ сайта (technical brief) — timezone и legal copy requirements для public pages.
- **Зачем:** FAQ должен honestly explain profile timezone vs device time без legal overreach.
- **Содержимое:** Timezone FAQ bullets, privacy tone, правила RU summary section для v1.
- **Обязанности:** Legal/timezone messaging согласован с real app settings UX.
- **Когда открывать:** Правила проекта и деплой — не runtime.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** `docs/website/PUBLIC_COPY_DRAFTS.md`, profile timezone в app.
- **Слой:** Документация — правила, не runtime.


### `docs/website/WEBSITE_V1_SCOPE.md`

EN:

- **What this is:** Website v1 scope — max five static pages, hero features, excluded roadmap/store claims.
- **Why needed:** Ship one convincing landing before building a product encyclopedia site.
- **What it contains:** Included/deferred page tables, messaging tiers, CTA to live web app.
- **Responsibilities:** Cap v1 work; supersedes page list only for implementation, not IA ideas.
- **When to open:** Cutting scope, choosing hero features, or rejecting new page requests.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** `docs/website/WEBSITE_PAGE_STRUCTURE.md`, `docs/website/FEATURE_MATRIX.md`.
- **Layer / owner:** Repo-only v1 scope contract.

RU:

- **Что это:** Website v1 scope — максимум пять static pages, hero features, excluded roadmap/store claims.
- **Зачем:** Сначала один убедительный landing, потом encyclopedia site о продукте.
- **Содержимое:** Included/deferred page tables, messaging tiers, CTA к live web app.
- **Обязанности:** Cap v1 work; supersedes page list только для implementation.
- **Когда открывать:** Cutting scope, выбор hero features или reject new page requests.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** `docs/website/WEBSITE_PAGE_STRUCTURE.md`, `docs/website/FEATURE_MATRIX.md`.
- **Слой:** Документация — правила, не runtime.


### `installer/windows/build_stt_helper_en.ps1`

EN:

- **What this is:** PowerShell build script for English STT helper shipped in Windows installer.
- **Why needed:** Desktop voice needs `counter_stt_helper.exe` in the setup package after install.
- **What it contains:** Commands building/copying STT helper into `stt_helper_build/`.
- **Responsibilities:** Produce/update STT helper binary for installer payload.
- **When to open:** Building or fixing Windows `CounterSetup.exe` installer.
- **Can it be deleted?** No — required for build/deploy/audit workflows documented in repo.
- **Connected to:** Flutter `installer` tooling.
- **Layer / owner:** Build/deploy/server configuration.

RU:

- **Что это:** PowerShell-сборка English STT helper для installer. Нужна, чтобы `counter_stt_helper.exe` попал в setup package, а desktop voice работал после установки.
- **Зачем:** Desktop voice на Windows вызывает GOLOS STT subprocess — exe должен быть собран до Inno Setup.
- **Содержимое:** Команды сборки/копирования `counter_stt_helper.exe` в `stt_helper_build/`.
- **Обязанности:** Собрать или обновить STT helper binary для installer payload.
- **Когда открывать:** Voice работает в dev, но не в installed app; после обновления STT toolchain.
- **Можно удалить?** Нет — без него installer не получит свежий STT helper.
- **Связано с:** `prepare_stt_payload.ps1`, `stt_helper_build/counter_stt_helper.exe`.
- **Слой:** Windows STT build script — не runtime Dart.


### `installer/windows/counter.iss`

EN:

- **What this is:** Inno Setup script — recipe for building `CounterSetup.exe` installer.
- **Why needed:** Packages Flutter Windows build + STT helper + icons into one setup wizard.
- **What it contains:** File copy rules, shortcuts, optional autostart task.
- **Responsibilities:** Define installer steps and installed file layout.
- **When to open:** Installer missing files or wrong install path on Windows.
- **Can it be deleted?** No — required for Windows installer.
- **Connected to:** `prepare_stt_payload.ps1`, GitHub Actions workflow.
- **Layer / owner:** Windows installer config.

RU:

- **Что это:** Inno Setup script — рецепт сборки installer `CounterSetup.exe`.
- **Зачем:** Упаковывает Flutter Windows build + STT helper + icons в setup wizard.
- **Содержимое:** Правила копирования файлов, shortcuts, optional autostart.
- **Обязанности:** Шаги installer и layout установленных файлов.
- **Когда открывать:** Installer не копирует файлы или неверный install path на Windows.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `prepare_stt_payload.ps1`, GitHub Actions workflow.
- **Слой:** Windows installer config.


### `installer/windows/install-cpp-atl.ps1`

EN:

- **What this is:** installer build file `install-cpp-atl.ps1` in `installer/windows` — required by Flutter/native toolchain.
- **Why needed:** Without `install-cpp-atl.ps1`, installer compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `installer/windows` (open file only when build errors cite it).
- **Responsibilities:** Support installer embedder build for `installer/windows` — not Dart business logic.
- **When to open:** Build log mentions `install-cpp-atl.ps1` or `installer/windows`.
- **Can it be deleted?** No — required for build/deploy/audit workflows documented in repo.
- **Connected to:** `installer/` platform folder, Flutter embedder.
- **Layer / owner:** Build/deploy/server configuration.

RU:

- **Что это:** PowerShell script `install-cpp-atl.ps1` — шаг installer/STT pipeline для Windows setup package.
- **Зачем:** Inno Setup/CI вызывает этот script перед упаковкой `CounterSetup.exe` installer.
- **Содержимое:** PowerShell commands для `install-cpp-atl` workflow.
- **Обязанности:** Automate installer prep step: `install-cpp-atl`.
- **Когда открывать:** Windows installer build fail на step `install-cpp-atl.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `installer/windows/counter.iss`, `docs/DEPLOY.md`.
- **Слой:** Windows installer script — не runtime Dart.


### `installer/windows/prepare_stt_payload.ps1`

EN:

- **What this is:** PowerShell script preparing STT payload before Windows installer build.
- **Why needed:** Inno Setup expects helper exe, models, and runtime files copied into installer layout.
- **What it contains:** Steps copying/checking `counter_stt_helper.exe` and STT runtime payload.
- **Responsibilities:** Prepare STT bundle for `counter.iss` before building setup.
- **When to open:** Building or fixing Windows `CounterSetup.exe` installer.
- **Can it be deleted?** No — required for build/deploy/audit workflows documented in repo.
- **Connected to:** Flutter `installer` tooling.
- **Layer / owner:** Build/deploy/server configuration.

RU:

- **Что это:** PowerShell-скрипт подготовки STT payload для Windows installer. Копирует/проверяет helper exe, model files и runtime payload перед сборкой Inno Setup.
- **Зачем:** Inno Setup script ожидает готовый STT bundle — иначе installed app не найдёт speech helper.
- **Содержимое:** Шаги копирования `counter_stt_helper.exe`, моделей и runtime файлов в layout installer.
- **Обязанности:** Подготовить STT файлы для `counter.iss` перед сборкой setup.
- **Когда открывать:** Installed app не видит speech helper; перед локальной сборкой `CounterSetup.exe`.
- **Можно удалить?** Нет — без него installer STT bundle неполный.
- **Связано с:** `installer/windows/counter.iss`, `build_stt_helper_en.ps1`, `stt_helper_build/`.
- **Слой:** Windows installer prep — не runtime Dart.


### `installer/windows/scripts/win_speech_wav.ps1`

EN:

- **What this is:** installer build file `win_speech_wav.ps1` in `installer/windows/scripts` — required by Flutter/native toolchain.
- **Why needed:** Without `win_speech_wav.ps1`, installer compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `installer/windows/scripts` (open file only when build errors cite it).
- **Responsibilities:** Support installer embedder build for `installer/windows/scripts` — not Dart business logic.
- **When to open:** Build log mentions `win_speech_wav.ps1` or `installer/windows/scripts`.
- **Can it be deleted?** No — required for build/deploy/audit workflows documented in repo.
- **Connected to:** `installer/` platform folder, Flutter embedder.
- **Layer / owner:** Build/deploy/server configuration.

RU:

- **Что это:** PowerShell script `win_speech_wav.ps1` — шаг installer/STT pipeline для Windows setup package.
- **Зачем:** Inno Setup/CI вызывает этот script перед упаковкой `CounterSetup.exe` installer.
- **Содержимое:** PowerShell commands для `win speech wav` workflow.
- **Обязанности:** Automate installer prep step: `win speech wav`.
- **Когда открывать:** Windows installer build fail на step `win_speech_wav.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `installer/windows/counter.iss`, `docs/DEPLOY.md`.
- **Слой:** Windows installer script — не runtime Dart.


### `installer/windows/stt_helper_build/counter_stt_helper.exe`

EN:

- **What this is:** Built STT helper binary bundled beside the installed Windows app.
- **Why needed:** Desktop voice invokes this subprocess for transcription after setup install.
- **What it contains:** Compiled GOLOS STT helper executable (English).
- **Responsibilities:** Speech transcription subprocess for installed desktop voice.
- **When to open:** Building or fixing Windows `CounterSetup.exe` installer.
- **Can it be deleted?** No — required for build/deploy/audit workflows documented in repo.
- **Connected to:** Flutter `installer` tooling.
- **Layer / owner:** Build/deploy/server configuration.

RU:

- **Что это:** Собранный STT helper binary, который installer кладёт рядом с Windows-приложением. Desktop voice вызывает его как subprocess для transcription.
- **Зачем:** Installed Counter на Windows не использует mobile STT API — нужен отдельный native helper exe.
- **Содержимое:** Скомпилированный GOLOS STT helper (English) для subprocess voice pipeline.
- **Обязанности:** Transcription subprocess для desktop voice после установки через setup.
- **Когда открывать:** Installed app: voice mic работает, но transcription пустая или helper not found.
- **Можно удалить?** Нет — удаление ломает voice в installed app.
- **Связано с:** `lib/core/services/desktop_stt_helper_service.dart`, `prepare_stt_payload.ps1`.
- **Слой:** Windows STT binary — не Dart UI.


### `integration_test/perf_date_swipe_test.dart`

EN:

- **What this is:** Automated test `perf_date_swipe_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `perf_date_swipe_test` scenario.
- **When to open:** CI failure or changing code near `perf_date_swipe`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `perf_date_swipe` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `perf_date_swipe`.
- **Обязанности:** Assert ожидаемого поведения `perf_date_swipe`.
- **Когда открывать:** Падение CI или правка кода рядом с `perf_date_swipe`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `ios/.gitignore`

EN:

- **What this is:** Git ignore rules for `ios` — files not to commit.
- **Why needed:** Prevents build output and secrets from entering git history.
- **What it contains:** Ignore patterns for this folder scope.
- **Responsibilities:** Prevent accidental commit of generated files.
- **When to open:** When behavior tied to `.gitignore` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `ios` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Git ignore для `ios/` — не коммитить локальный build-мусор платформы.
- **Зачем:** Gradle/Xcode/CMake генерируют файлы в `ios/`, которые не должны попадать в git.
- **Содержимое:** Ignore patterns для build cache и IDE metadata в `ios/`.
- **Обязанности:** Держать `ios/` tree чистым от generated artifacts.
- **Когда открывать:** Случайно добавили результат сборки `ios/` в git.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** Flutter `ios` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Flutter/AppFrameworkInfo.plist`

EN:

- **What this is:** ios build file `AppFrameworkInfo.plist` in `ios/Flutter` — required by Flutter/native toolchain.
- **Why needed:** Without `AppFrameworkInfo.plist`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Flutter` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Flutter` — not Dart business logic.
- **When to open:** Build log mentions `AppFrameworkInfo.plist` or `ios/Flutter`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Plist `appframeworkinfo.plist` — метаданные и конфиг Xcode/CocoaPods для iOS IPA/TestFlight build.
- **Зачем:** Xcode/Xcode/CocoaPods читает plist при сборке или packaging iOS IPA/TestFlight build.
- **Содержимое:** XML plist keys для `ios/Flutter`.
- **Обязанности:** Конфигурация/IDE checks для ios build pipeline.
- **Когда открывать:** Build/packaging error ссылается на `appframeworkinfo.plist`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner.xcodeproj/`, Flutter embedder.
- **Слой:** ios plist config — не Dart.


### `ios/Flutter/Debug.xcconfig`

EN:

- **What this is:** Flutter ios `Debug.xcconfig` — passes Flutter/CocoaPods settings into Xcode build.
- **Why needed:** Xcode reads xcconfig when compiling Runner Debug; Flutter flags must flow into native build.
- **What it contains:** #include generated Flutter settings and Debug compiler flags.
- **Responsibilities:** Wire Flutter engine paths and flags into ios Debug compile.
- **When to open:** When behavior tied to `Debug.xcconfig` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `ios` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Xcode build configuration для Flutter iOS target (Debug). Передаёт Flutter/CocoaPods settings в Debug сборку.
- **Зачем:** Xcode читает xcconfig при сборке Runner Debug — без него Flutter flags не попадут в compile.
- **Содержимое:** #include Flutter generated settings, Debug preprocessor flags.
- **Обязанности:** Debug compile flags и пути Flutter engine для iOS.
- **Когда открывать:** Debug iOS build или pod integration падает после Flutter upgrade.
- **Можно удалить?** Нет — без него Debug iOS build или pod integration падает.
- **Связано с:** `ios/Podfile`, `ios/Flutter/Release.xcconfig`, Xcode Runner target.
- **Слой:** Flutter iOS generated config — не править вручную без причины.


### `ios/Flutter/Release.xcconfig`

EN:

- **What this is:** Flutter ios `Release.xcconfig` — passes Flutter/CocoaPods settings into Xcode build.
- **Why needed:** Xcode reads xcconfig when compiling Runner Release; Flutter flags must flow into native build.
- **What it contains:** #include generated Flutter settings and Release compiler flags.
- **Responsibilities:** Wire Flutter engine paths and flags into ios Release compile.
- **When to open:** When behavior tied to `Release.xcconfig` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `ios` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Xcode build configuration для Flutter iOS target (Release). Передаёт Flutter/CocoaPods settings в Release/IPA сборку.
- **Зачем:** Release archive/TestFlight использует эти flags для AOT и stripped build.
- **Содержимое:** #include Flutter generated settings, Release optimization flags.
- **Обязанности:** Release compile flags и пути Flutter engine для iOS IPA.
- **Когда открывать:** Release iOS archive или TestFlight build падает после Flutter upgrade.
- **Можно удалить?** Нет — без него Release iOS build или pod integration падает.
- **Связано с:** `ios/Podfile`, `ios/Flutter/Debug.xcconfig`, Xcode Runner target.
- **Слой:** Flutter iOS generated config — не править вручную без причины.


### `ios/Runner.xcodeproj/project.pbxproj`

EN:

- **What this is:** Xcode project database for iOS Runner — targets, build phases, signing, resources.
- **Why needed:** Xcode opens and builds IPA through this `project.pbxproj`.
- **What it contains:** PBX targets, file references, build settings, code signing configuration.
- **Responsibilities:** Describe iOS Runner target and build pipeline for IPA.
- **When to open:** When behavior tied to `project.pbxproj` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `ios` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Главная project database Xcode для iOS Runner. Хранит targets, build phases, signing/build settings и ссылки на resources.
- **Зачем:** Xcode открывает и собирает IPA только через корректный `project.pbxproj`.
- **Содержимое:** PBX targets, build phases, file references, code signing settings.
- **Обязанности:** Описать iOS Runner target, resources и build pipeline для IPA.
- **Когда открывать:** Xcode-проект не открывается, scheme/signing errors, missing file references.
- **Можно удалить?** Нет — повреждение файла ломает iOS Xcode-проект и IPA build.
- **Связано с:** `ios/Runner/`, `ios/Flutter/`, CocoaPods workspace.
- **Слой:** Xcode iOS project database — не Dart.


### `ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata`

EN:

- **What this is:** ios build file `contents.xcworkspacedata` in `ios/Runner.xcodeproj/project.xcworkspace` — required by Flutter/native toolchain.
- **Why needed:** Without `contents.xcworkspacedata`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner.xcodeproj/project.xcworkspace` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner.xcodeproj/project.xcworkspace` — not Dart business logic.
- **When to open:** Build log mentions `contents.xcworkspacedata` or `ios/Runner.xcodeproj/project.xcworkspace`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Xcode workspace metadata для ios — связывает Runner project и CocoaPods workspace.
- **Зачем:** Xcode открывает `.xcworkspace`, а не `.xcodeproj`, когда подключены Flutter pods.
- **Содержимое:** File references на Runner project и Pods.
- **Обязанности:** IDE workspace glue для Xcode/CocoaPods + Flutter pods.
- **Когда открывать:** Xcode workspace не открывается; CocoaPods integration broken на ios.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner.xcodeproj/`, `ios/Podfile`.
- **Слой:** Xcode workspace ios — IDE metadata.


### `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`

EN:

- **What this is:** ios build file `IDEWorkspaceChecks.plist` in `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata` — required by Flutter/native toolchain.
- **Why needed:** Without `IDEWorkspaceChecks.plist`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata` — not Dart business logic.
- **When to open:** Build log mentions `IDEWorkspaceChecks.plist` or `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Plist `ideworkspacechecks.plist` — метаданные и конфиг Xcode/CocoaPods для iOS IPA/TestFlight build.
- **Зачем:** Xcode/Xcode/CocoaPods читает plist при сборке или packaging iOS IPA/TestFlight build.
- **Содержимое:** XML plist keys для `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata`.
- **Обязанности:** Конфигурация/IDE checks для ios build pipeline.
- **Когда открывать:** Build/packaging error ссылается на `ideworkspacechecks.plist`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner.xcodeproj/`, Flutter embedder.
- **Слой:** ios plist config — не Dart.


### `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings`

EN:

- **What this is:** ios build file `WorkspaceSettings.xcsettings` in `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata` — required by Flutter/native toolchain.
- **Why needed:** Without `WorkspaceSettings.xcsettings`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata` — not Dart business logic.
- **When to open:** Build log mentions `WorkspaceSettings.xcsettings` or `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Xcode workspace settings `workspacesettings.xcsettings` — IDE metadata для ios Runner workspace.
- **Зачем:** Xcode хранит workspace checks/settings для reproducible iOS IPA/TestFlight build builds.
- **Содержимое:** Plist workspace settings (LastUpgradeVersion, IDE prefs).
- **Обязанности:** Workspace consistency для команды при сборке iOS IPA/TestFlight build.
- **Когда открывать:** Xcode workspace warnings или IDE upgrade drift на ios.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner.xcworkspace/`, `ios/Runner.xcodeproj/`.
- **Слой:** Xcode workspace metadata ios.


### `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`

EN:

- **What this is:** ios build file `Runner.xcscheme` in `ios/Runner.xcodeproj/xcshareddata/xcschemes` — required by Flutter/native toolchain.
- **Why needed:** Without `Runner.xcscheme`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner.xcodeproj/xcshareddata/xcschemes` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner.xcodeproj/xcshareddata/xcschemes` — not Dart business logic.
- **When to open:** Build log mentions `Runner.xcscheme` or `ios/Runner.xcodeproj/xcshareddata/xcschemes`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Xcode scheme `runner.xcscheme` — какой target/configuration Xcode запускает для ios Runner.
- **Зачем:** Run/Archive/Test в Xcode используют scheme; без него team не соберёт {artifact}.
- **Содержимое:** Build/run/test actions, selected target Runner, configuration Debug/Release.
- **Обязанности:** Developer workflow: Run/Archive iOS IPA/TestFlight build из Xcode.
- **Когда открывать:** Scheme missing в Xcode; Archive использует wrong configuration.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner.xcodeproj/`, `ios/Runner/`.
- **Слой:** Xcode scheme ios — developer workflow.


### `ios/Runner.xcworkspace/contents.xcworkspacedata`

EN:

- **What this is:** ios build file `contents.xcworkspacedata` in `ios/Runner.xcworkspace` — required by Flutter/native toolchain.
- **Why needed:** Without `contents.xcworkspacedata`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner.xcworkspace` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner.xcworkspace` — not Dart business logic.
- **When to open:** Build log mentions `contents.xcworkspacedata` or `ios/Runner.xcworkspace`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Xcode workspace metadata для ios — связывает Runner project и CocoaPods workspace.
- **Зачем:** Xcode открывает `.xcworkspace`, а не `.xcodeproj`, когда подключены Flutter pods.
- **Содержимое:** File references на Runner project и Pods.
- **Обязанности:** IDE workspace glue для Xcode/CocoaPods + Flutter pods.
- **Когда открывать:** Xcode workspace не открывается; CocoaPods integration broken на ios.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner.xcodeproj/`, `ios/Podfile`.
- **Слой:** Xcode workspace ios — IDE metadata.


### `ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`

EN:

- **What this is:** ios build file `IDEWorkspaceChecks.plist` in `ios/Runner.xcworkspace/xcshareddata` — required by Flutter/native toolchain.
- **Why needed:** Without `IDEWorkspaceChecks.plist`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner.xcworkspace/xcshareddata` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner.xcworkspace/xcshareddata` — not Dart business logic.
- **When to open:** Build log mentions `IDEWorkspaceChecks.plist` or `ios/Runner.xcworkspace/xcshareddata`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Plist `ideworkspacechecks.plist` — метаданные и конфиг Xcode/CocoaPods для iOS IPA/TestFlight build.
- **Зачем:** Xcode/Xcode/CocoaPods читает plist при сборке или packaging iOS IPA/TestFlight build.
- **Содержимое:** XML plist keys для `ios/Runner.xcworkspace/xcshareddata`.
- **Обязанности:** Конфигурация/IDE checks для ios build pipeline.
- **Когда открывать:** Build/packaging error ссылается на `ideworkspacechecks.plist`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner.xcodeproj/`, Flutter embedder.
- **Слой:** ios plist config — не Dart.


### `ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings`

EN:

- **What this is:** ios build file `WorkspaceSettings.xcsettings` in `ios/Runner.xcworkspace/xcshareddata` — required by Flutter/native toolchain.
- **Why needed:** Without `WorkspaceSettings.xcsettings`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner.xcworkspace/xcshareddata` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner.xcworkspace/xcshareddata` — not Dart business logic.
- **When to open:** Build log mentions `WorkspaceSettings.xcsettings` or `ios/Runner.xcworkspace/xcshareddata`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Xcode workspace settings `workspacesettings.xcsettings` — IDE metadata для ios Runner workspace.
- **Зачем:** Xcode хранит workspace checks/settings для reproducible iOS IPA/TestFlight build builds.
- **Содержимое:** Plist workspace settings (LastUpgradeVersion, IDE prefs).
- **Обязанности:** Workspace consistency для команды при сборке iOS IPA/TestFlight build.
- **Когда открывать:** Xcode workspace warnings или IDE upgrade drift на ios.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner.xcworkspace/`, `ios/Runner.xcodeproj/`.
- **Слой:** Xcode workspace metadata ios.


### `ios/Runner/AppDelegate.swift`

EN:

- **What this is:** ios build file `AppDelegate.swift` in `ios/Runner` — required by Flutter/native toolchain.
- **Why needed:** Without `AppDelegate.swift`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner` — not Dart business logic.
- **When to open:** Build log mentions `AppDelegate.swift` or `ios/Runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Swift native glue (AppDelegate/Flutter glue) для ios Runner — старт Flutter engine и lifecycle hooks.
- **Зачем:** Apple runner target вызывает Swift glue до первого Dart frame в iOS IPA/TestFlight build.
- **Содержимое:** Swift-классы embedding Flutter на ios.
- **Обязанности:** Native lifecycle/window hooks между Apple OS и Flutter engine на ios.
- **Когда открывать:** Build log mentions `AppDelegate.swift` or `ios/Runner`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner/Info.plist`, Flutter embedder.
- **Слой:** ios Swift glue — не Dart UI.


### `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`

EN:

- **What this is:** ios build file `Contents.json` in `ios/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Contents.json`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Contents.json` or `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** JSON manifest `contents.json` в xcassets (AppIcon) — описывает набор PNG для iOS IPA/TestFlight build.
- **Зачем:** Xcode читает `contents.json`, чтобы собрать AppIcon в iOS IPA/TestFlight build.
- **Содержимое:** Список image scales/files для `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Связать PNG assets с AppIcon в Xcode catalog.
- **Когда открывать:** Missing/wrong AppIcon после сборки ios.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner.xcodeproj/`, Info.plist.
- **Слой:** ios asset catalog manifest.


### `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`

EN:

- **What this is:** ios build file `Icon-App-1024x1024@1x.png` in `ios/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Icon-App-1024x1024@1x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Icon-App-1024x1024@1x.png` or `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/iOS — tab icon или PWA asset `icon-app-1024x1024@1x.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-app-1024x1024@1x.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-app-1024x1024@1x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png`

EN:

- **What this is:** ios build file `Icon-App-20x20@1x.png` in `ios/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Icon-App-20x20@1x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Icon-App-20x20@1x.png` or `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/iOS — tab icon или PWA asset `icon-app-20x20@1x.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-app-20x20@1x.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-app-20x20@1x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png`

EN:

- **What this is:** ios build file `Icon-App-20x20@2x.png` in `ios/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Icon-App-20x20@2x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Icon-App-20x20@2x.png` or `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/iOS — tab icon или PWA asset `icon-app-20x20@2x.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-app-20x20@2x.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-app-20x20@2x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png`

EN:

- **What this is:** ios build file `Icon-App-20x20@3x.png` in `ios/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Icon-App-20x20@3x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Icon-App-20x20@3x.png` or `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/iOS — tab icon или PWA asset `icon-app-20x20@3x.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-app-20x20@3x.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-app-20x20@3x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png`

EN:

- **What this is:** ios build file `Icon-App-29x29@1x.png` in `ios/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Icon-App-29x29@1x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Icon-App-29x29@1x.png` or `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/iOS — tab icon или PWA asset `icon-app-29x29@1x.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-app-29x29@1x.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-app-29x29@1x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png`

EN:

- **What this is:** ios build file `Icon-App-29x29@2x.png` in `ios/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Icon-App-29x29@2x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Icon-App-29x29@2x.png` or `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/iOS — tab icon или PWA asset `icon-app-29x29@2x.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-app-29x29@2x.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-app-29x29@2x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png`

EN:

- **What this is:** ios build file `Icon-App-29x29@3x.png` in `ios/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Icon-App-29x29@3x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Icon-App-29x29@3x.png` or `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/iOS — tab icon или PWA asset `icon-app-29x29@3x.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-app-29x29@3x.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-app-29x29@3x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png`

EN:

- **What this is:** ios build file `Icon-App-40x40@1x.png` in `ios/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Icon-App-40x40@1x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Icon-App-40x40@1x.png` or `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/iOS — tab icon или PWA asset `icon-app-40x40@1x.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-app-40x40@1x.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-app-40x40@1x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png`

EN:

- **What this is:** ios build file `Icon-App-40x40@2x.png` in `ios/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Icon-App-40x40@2x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Icon-App-40x40@2x.png` or `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/iOS — tab icon или PWA asset `icon-app-40x40@2x.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-app-40x40@2x.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-app-40x40@2x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png`

EN:

- **What this is:** ios build file `Icon-App-40x40@3x.png` in `ios/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Icon-App-40x40@3x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Icon-App-40x40@3x.png` or `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/iOS — tab icon или PWA asset `icon-app-40x40@3x.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-app-40x40@3x.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-app-40x40@3x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png`

EN:

- **What this is:** ios build file `Icon-App-60x60@2x.png` in `ios/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Icon-App-60x60@2x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Icon-App-60x60@2x.png` or `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/iOS — tab icon или PWA asset `icon-app-60x60@2x.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-app-60x60@2x.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-app-60x60@2x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png`

EN:

- **What this is:** ios build file `Icon-App-60x60@3x.png` in `ios/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Icon-App-60x60@3x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Icon-App-60x60@3x.png` or `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/iOS — tab icon или PWA asset `icon-app-60x60@3x.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-app-60x60@3x.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-app-60x60@3x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png`

EN:

- **What this is:** ios build file `Icon-App-76x76@1x.png` in `ios/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Icon-App-76x76@1x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Icon-App-76x76@1x.png` or `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/iOS — tab icon или PWA asset `icon-app-76x76@1x.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-app-76x76@1x.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-app-76x76@1x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png`

EN:

- **What this is:** ios build file `Icon-App-76x76@2x.png` in `ios/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Icon-App-76x76@2x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Icon-App-76x76@2x.png` or `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/iOS — tab icon или PWA asset `icon-app-76x76@2x.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-app-76x76@2x.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-app-76x76@2x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png`

EN:

- **What this is:** ios build file `Icon-App-83.5x83.5@2x.png` in `ios/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Icon-App-83.5x83.5@2x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Icon-App-83.5x83.5@2x.png` or `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/iOS — tab icon или PWA asset `icon-app-83.5x83.5@2x.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-app-83.5x83.5@2x.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-app-83.5x83.5@2x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json`

EN:

- **What this is:** ios build file `Contents.json` in `ios/Runner/Assets.xcassets/LaunchImage.imageset` — required by Flutter/native toolchain.
- **Why needed:** Without `Contents.json`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/LaunchImage.imageset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/LaunchImage.imageset` — not Dart business logic.
- **When to open:** Build log mentions `Contents.json` or `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** JSON manifest `contents.json` в xcassets (LaunchImage) — описывает набор PNG для iOS IPA/TestFlight build.
- **Зачем:** Xcode читает `contents.json`, чтобы собрать LaunchImage в iOS IPA/TestFlight build.
- **Содержимое:** Список image scales/files для `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Обязанности:** Связать PNG assets с LaunchImage в Xcode catalog.
- **Когда открывать:** Missing/wrong LaunchImage после сборки ios.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner.xcodeproj/`, Info.plist.
- **Слой:** ios asset catalog manifest.


### `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png`

EN:

- **What this is:** ios build file `LaunchImage.png` in `ios/Runner/Assets.xcassets/LaunchImage.imageset` — required by Flutter/native toolchain.
- **Why needed:** Without `LaunchImage.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/LaunchImage.imageset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/LaunchImage.imageset` — not Dart business logic.
- **When to open:** Build log mentions `LaunchImage.png` or `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG `launchimage.png` в xcassets — raster launchimage.png для iOS IPA/TestFlight build.
- **Зачем:** Xcode упаковывает imageset PNG в iOS IPA/TestFlight build bundle.
- **Содержимое:** Растровый PNG в `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Обязанности:** Launch/icon imagery на ios из asset catalog.
- **Когда открывать:** Wrong/missing launch/icon image для `launchimage.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner.xcodeproj/`, Info.plist.
- **Слой:** ios asset catalog PNG.


### `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png`

EN:

- **What this is:** ios build file `LaunchImage@2x.png` in `ios/Runner/Assets.xcassets/LaunchImage.imageset` — required by Flutter/native toolchain.
- **Why needed:** Without `LaunchImage@2x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/LaunchImage.imageset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/LaunchImage.imageset` — not Dart business logic.
- **When to open:** Build log mentions `LaunchImage@2x.png` or `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG `launchimage@2x.png` в xcassets — raster launchimage 2x.png для iOS IPA/TestFlight build.
- **Зачем:** Xcode упаковывает imageset PNG в iOS IPA/TestFlight build bundle.
- **Содержимое:** Растровый PNG в `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Обязанности:** Launch/icon imagery на ios из asset catalog.
- **Когда открывать:** Wrong/missing launch/icon image для `launchimage@2x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner.xcodeproj/`, Info.plist.
- **Слой:** ios asset catalog PNG.


### `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png`

EN:

- **What this is:** ios build file `LaunchImage@3x.png` in `ios/Runner/Assets.xcassets/LaunchImage.imageset` — required by Flutter/native toolchain.
- **Why needed:** Without `LaunchImage@3x.png`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/LaunchImage.imageset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/LaunchImage.imageset` — not Dart business logic.
- **When to open:** Build log mentions `LaunchImage@3x.png` or `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG `launchimage@3x.png` в xcassets — raster launchimage 3x.png для iOS IPA/TestFlight build.
- **Зачем:** Xcode упаковывает imageset PNG в iOS IPA/TestFlight build bundle.
- **Содержимое:** Растровый PNG в `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Обязанности:** Launch/icon imagery на ios из asset catalog.
- **Когда открывать:** Wrong/missing launch/icon image для `launchimage@3x.png`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner.xcodeproj/`, Info.plist.
- **Слой:** ios asset catalog PNG.


### `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md`

EN:

- **What this is:** ios build file `README.md` in `ios/Runner/Assets.xcassets/LaunchImage.imageset` — required by Flutter/native toolchain.
- **Why needed:** Without `README.md`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Assets.xcassets/LaunchImage.imageset` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Assets.xcassets/LaunchImage.imageset` — not Dart business logic.
- **When to open:** Build log mentions `README.md` or `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Platform file `readme.md` в `ios/Runner/Assets.xcassets/LaunchImage.imageset` — читает Xcode/CocoaPods при сборке iOS IPA/TestFlight build.
- **Зачем:** Без этого файла Xcode/CocoaPods может не собрать или упаковать iOS IPA/TestFlight build.
- **Содержимое:** Содержимое native/config слоя `ios/Runner/Assets.xcassets/LaunchImage.imageset` (смотреть файл при build errors).
- **Обязанности:** Участвует в Xcode/CocoaPods pipeline для iOS IPA/TestFlight build — не Dart business logic.
- **Когда открывать:** Build log ios ссылается на `readme.md` или `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/`, Flutter embedder, Xcode/CocoaPods.
- **Слой:** ios platform file — не Dart UI.


### `ios/Runner/Base.lproj/LaunchScreen.storyboard`

EN:

- **What this is:** ios build file `LaunchScreen.storyboard` in `ios/Runner/Base.lproj` — required by Flutter/native toolchain.
- **Why needed:** Without `LaunchScreen.storyboard`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Base.lproj` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Base.lproj` — not Dart business logic.
- **When to open:** Build log mentions `LaunchScreen.storyboard` or `ios/Runner/Base.lproj`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Launch UI storyboard/xib для ios Runner — native splash до первого Flutter frame.
- **Зачем:** Apple показывает launch screen из storyboard/xib пока Flutter engine грузит UI.
- **Содержимое:** Interface Builder layout launch screen для ios.
- **Обязанности:** Native launch appearance ios — не Dart widgets.
- **Когда открывать:** Launch flash/orientation wrong на ios; missing launch screen.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner/Info.plist`, asset catalogs.
- **Слой:** ios launch UI — native only.


### `ios/Runner/Base.lproj/Main.storyboard`

EN:

- **What this is:** ios build file `Main.storyboard` in `ios/Runner/Base.lproj` — required by Flutter/native toolchain.
- **Why needed:** Without `Main.storyboard`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner/Base.lproj` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner/Base.lproj` — not Dart business logic.
- **When to open:** Build log mentions `Main.storyboard` or `ios/Runner/Base.lproj`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Launch UI storyboard/xib для ios Runner — native splash до первого Flutter frame.
- **Зачем:** Apple показывает launch screen из storyboard/xib пока Flutter engine грузит UI.
- **Содержимое:** Interface Builder layout launch screen для ios.
- **Обязанности:** Native launch appearance ios — не Dart widgets.
- **Когда открывать:** Launch flash/orientation wrong на ios; missing launch screen.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner/Info.plist`, asset catalogs.
- **Слой:** ios launch UI — native only.


### `ios/Runner/Info.plist`

EN:

- **What this is:** iOS/macOS bundle Info.plist — permissions, bundle id, display name.
- **Why needed:** Apple OS reads plist for app metadata and permission prompts.
- **What it contains:** CFBundle keys, usage descriptions (mic, etc.).
- **Responsibilities:** App identity and iOS permission strings.
- **When to open:** When behavior tied to `Info.plist` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `ios` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Файл Info.plist bundle iOS Runner — разрешения, bundle id и display name.
- **Зачем:** Apple OS читает plist для metadata приложения и permission prompts.
- **Содержимое:** Ключи CFBundle, usage descriptions (микрофон и др.).
- **Обязанности:** Идентичность app и permission strings на iOS.
- **Когда открывать:** Неверное имя app или permission prompt на iOS.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner/`, Xcode-проект.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `ios/Runner/Runner-Bridging-Header.h`

EN:

- **What this is:** ios build file `Runner-Bridging-Header.h` in `ios/Runner` — required by Flutter/native toolchain.
- **Why needed:** Without `Runner-Bridging-Header.h`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner` — not Dart business logic.
- **When to open:** Build log mentions `Runner-Bridging-Header.h` or `ios/Runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Bridging header `runner-bridging-header.h` — экспортирует C/ObjC symbols в Swift Runner ios.
- **Зачем:** Swift glue в iOS IPA/TestFlight build видит C headers Flutter/plugins через этот bridge.
- **Содержимое:** #import directives для `ios/Runner`.
- **Обязанности:** Связать Swift Runner с C/ObjC Flutter embedding на ios.
- **Когда открывать:** Swift compile error: unknown C symbol из bridging header.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner/`, Flutter embedder.
- **Слой:** ios Swift/ObjC bridge — не Dart.


### `ios/Runner/SceneDelegate.swift`

EN:

- **What this is:** ios build file `SceneDelegate.swift` in `ios/Runner` — required by Flutter/native toolchain.
- **Why needed:** Without `SceneDelegate.swift`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner` — not Dart business logic.
- **When to open:** Build log mentions `SceneDelegate.swift` or `ios/Runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Swift native glue (AppDelegate/Flutter glue) для ios Runner — старт Flutter engine и lifecycle hooks.
- **Зачем:** Apple runner target вызывает Swift glue до первого Dart frame в iOS IPA/TestFlight build.
- **Содержимое:** Swift-классы embedding Flutter на ios.
- **Обязанности:** Native lifecycle/window hooks между Apple OS и Flutter engine на ios.
- **Когда открывать:** Build log mentions `SceneDelegate.swift` or `ios/Runner`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner/Info.plist`, Flutter embedder.
- **Слой:** ios Swift glue — не Dart UI.


### `ios/RunnerTests/RunnerTests.swift`

EN:

- **What this is:** ios build file `RunnerTests.swift` in `ios/RunnerTests` — required by Flutter/native toolchain.
- **Why needed:** Without `RunnerTests.swift`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/RunnerTests` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/RunnerTests` — not Dart business logic.
- **When to open:** Build log mentions `RunnerTests.swift` or `ios/RunnerTests`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Swift native glue (XCTest smoke entry) для ios Runner — старт Flutter engine и lifecycle hooks.
- **Зачем:** Apple runner target вызывает Swift glue до первого Dart frame в iOS IPA/TestFlight build.
- **Содержимое:** Swift-классы embedding Flutter на ios.
- **Обязанности:** Native lifecycle/window hooks между Apple OS и Flutter engine на ios.
- **Когда открывать:** Build log mentions `RunnerTests.swift` or `ios/RunnerTests`.
- **Можно удалить?** Нет — без него не соберётся iOS IPA/TestFlight build.
- **Связано с:** `ios/Runner/Info.plist`, Flutter embedder.
- **Слой:** ios Swift glue — не Dart UI.


### `lib/app_shell.dart`

EN:

- **What this is:** Thin shell entry — re-exports `shell/life_os_dashboard.dart`.
- **Why needed:** Provides a stable import path for the main dashboard without duplicating shell code.
- **What it contains:** Re-export of the dashboard shell widget.
- **Responsibilities:** Re-exports `shell/life_os_dashboard.dart` (thin entry).
- **When to open:** When behavior tied to `app_shell.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Re-exports `shell/life_os_dashboard.dart` (thin entry)
- **Layer / owner:** Repository support file.

RU:

- **Что это:** Тонкий entry-point приложения — re-export `shell/life_os_dashboard.dart`.
- **Зачем:** Стабильный import path для dashboard без дублирования shell-кода.
- **Содержимое:** Re-export виджета dashboard из `lib/shell/`.
- **Обязанности:** Подключает shell dashboard как единую точку входа UI.
- **Когда открывать:** Когда ломается поведение, связанное с `app_shell.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/`, `docs/APP_STRUCTURE.md`
- **Слой:** Вспомогательный файл репозитория.


### `lib/core/app_build_info.dart`

EN:

- **What this is:** Compile-time build stamp — git commit and build time from `--dart-define`.
- **Why needed:** Logcat/console markers (`APP_BUILD`, P0N/P0O diagnostics) identify which APK build ran on device.
- **What it contains:** `AppBuildInfo` — `gitCommit`, `builtAt`, `bootLogLine()`, perf test markers.
- **Key code names:** `AppBuildInfo`
- **Responsibilities:** Expose build identity strings; no runtime PocketBase logic.
- **When to open:** When behavior tied to `app_build_info.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Build metadata
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Compile-time метка сборки — git commit и время из `--dart-define`.
- **Зачем:** Маркеры logcat/console (`APP_BUILD`, P0N/P0O) показывают, какой APK на устройстве.
- **Содержимое:** `AppBuildInfo` — `gitCommit`, `builtAt`, `bootLogLine()`, perf-маркеры.
- **Обязанности:** Отдаёт строки идентификации сборки; без логики PocketBase.
- **Когда открывать:** Когда ломается поведение, связанное с `app_build_info.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/app_colors.dart`

EN:

- **What this is:** Design-system color tokens (V3/V7) — action primary, surfaces, semantic success, dark scheme.
- **Why needed:** Change `actionPrimary` once to retint buttons, tabs, and nav chrome app-wide.
- **What it contains:** `AppColors` constants; `lightColorScheme()` / `darkColorScheme()` factories.
- **Key code names:** `AppColors`
- **Responsibilities:** Single source for default UI colors — not per-category data colors.
- **When to open:** When behavior tied to `app_colors.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Color tokens
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Токены цветов design system (V3/V7) — action primary, surfaces, success и dark scheme.
- **Зачем:** Смена `actionPrimary` перекрашивает кнопки, tabs и nav chrome во всём приложении.
- **Содержимое:** Константы `AppColors`; фабрики `lightColorScheme()` / `darkColorScheme()`.
- **Обязанности:** Единый источник цветов UI — не цвета данных категорий.
- **Когда открывать:** Когда ломается поведение, связанное с `app_colors.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/app_icons.dart`

EN:

- **What this is:** Foundation module `app_icons.dart` (core) — Canonical icon tokens (timezone family, shared glyphs).
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `AppTimezoneIconKey`.
- **Key code names:** `AppTimezoneIconKey`
- **Responsibilities:** Canonical icon tokens (timezone family, shared glyphs)
- **When to open:** When behavior tied to `app_icons.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Canonical icon tokens (timezone family, shared glyphs)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `app_icons.dart` (core) — Canonical icon tokens (timezone family, shared glyphs).
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `app_icons.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Canonical icon tokens (timezone family, shared glyphs).
- **Когда открывать:** Когда ломается поведение, связанное с `app_icons.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/app_snackbar.dart`

EN:

- **What this is:** Foundation module `app_snackbar.dart` (core) — AppSnack.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `AppSnack`.
- **Key code names:** `AppSnack`
- **Responsibilities:** AppSnack
- **When to open:** When behavior tied to `app_snackbar.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: `AppSnack` toasts
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `app_snackbar.dart` (core) — AppSnack.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `app_snackbar.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: AppSnack.
- **Когда открывать:** Когда ломается поведение, связанное с `app_snackbar.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/category_color_palette.dart`

EN:

- **What this is:** Foundation module `category_color_palette.dart` (core) — Category tile palette.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `category_color_palette.dart` — open file for classes and helpers.
- **Responsibilities:** Category tile palette
- **When to open:** When behavior tied to `category_color_palette.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Category tile palette
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `category_color_palette.dart` (core) — Category tile palette.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `category_color_palette.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Category tile palette.
- **Когда открывать:** Когда ломается поведение, связанное с `category_color_palette.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/constants.dart`

EN:

- **What this is:** Foundation module `constants.dart` (core) — UI limits, global keys.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `TableNames`, `AppLimits`.
- **Key code names:** `TableNames`, `AppLimits`
- **Responsibilities:** UI limits, global keys
- **When to open:** When behavior tied to `constants.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: UI limits, global keys
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `constants.dart` (core) — UI limits, global keys.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `constants.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: UI limits, global keys.
- **Когда открывать:** Когда ломается поведение, связанное с `constants.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/date_pager_settle_gate.dart`

EN:

- **What this is:** Foundation module `date_pager_settle_gate.dart` (core) — PageView.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `date_pager_settle_gate.dart` — open file for classes and helpers.
- **Responsibilities:** PageView
- **When to open:** When behavior tied to `date_pager_settle_gate.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Shared date `PageView` settle coordinator
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `date_pager_settle_gate.dart` (core) — PageView.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `date_pager_settle_gate.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: PageView.
- **Когда открывать:** Когда ломается поведение, связанное с `date_pager_settle_gate.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/date_swipe_physics.dart`

EN:

- **What this is:** Foundation module `date_swipe_physics.dart` (core) — Date swipe physics.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `LightDateSwipePhysics`, `FeatherDateSwipePhysics`.
- **Key code names:** `LightDateSwipePhysics`, `FeatherDateSwipePhysics`
- **Responsibilities:** Date swipe physics
- **When to open:** When behavior tied to `date_swipe_physics.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Date swipe physics
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `date_swipe_physics.dart` (core) — Date swipe physics.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `date_swipe_physics.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Date swipe physics.
- **Когда открывать:** Когда ломается поведение, связанное с `date_swipe_physics.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/diagnostics/desktop_voice_log.dart`

EN:

- **What this is:** Foundation module `desktop_voice_log.dart` (diagnostics) — DesktopVoiceLog.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceLog`.
- **Key code names:** `DesktopVoiceLog`
- **Responsibilities:** DesktopVoiceLog
- **When to open:** When behavior tied to `desktop_voice_log.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: `DesktopVoiceLog` — concise desktop-voice pipeline markers (debug/profile only
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_log.dart` (diagnostics) — DesktopVoiceLog.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_log.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: DesktopVoiceLog.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_log.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/diagnostics/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/diagnostics/desktop_voice_pipeline.dart`

EN:

- **What this is:** Foundation module `desktop_voice_pipeline.dart` (diagnostics) — DesktopVoiceLog.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoicePipeline`.
- **Key code names:** `DesktopVoicePipeline`
- **Responsibilities:** DesktopVoiceLog
- **When to open:** When behavior tied to `desktop_voice_pipeline.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Desktop-voice pipeline step helpers built on `DesktopVoiceLog`
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_pipeline.dart` (diagnostics) — DesktopVoiceLog.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_pipeline.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: DesktopVoiceLog.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_pipeline.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/diagnostics/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/diagnostics/plan_duplicate_log.dart`

EN:

- **What this is:** Foundation module `plan_duplicate_log.dart` (diagnostics) — Plan duplicate detection logs.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `plan_duplicate_log.dart` — open file for classes and helpers.
- **Responsibilities:** Plan duplicate detection logs
- **When to open:** When behavior tied to `plan_duplicate_log.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Plan duplicate detection logs
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `plan_duplicate_log.dart` (diagnostics) — Plan duplicate detection logs.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `plan_duplicate_log.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Plan duplicate detection logs.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_duplicate_log.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/diagnostics/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/diagnostics/platform_log.dart`

EN:

- **What this is:** Foundation module `platform_log.dart` (diagnostics) — Platform-specific log sinks.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `platform_log.dart` — open file for classes and helpers.
- **Responsibilities:** Platform-specific log sinks
- **When to open:** When behavior tied to `platform_log.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Platform-specific log sinks
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `platform_log.dart` (diagnostics) — Platform-specific log sinks.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `platform_log.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Platform-specific log sinks.
- **Когда открывать:** Когда ломается поведение, связанное с `platform_log.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/diagnostics/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/diagnostics/runtime_log.dart`

EN:

- **What this is:** Foundation module `runtime_log.dart` (diagnostics) — Uncaught error logging.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `RuntimeLog`.
- **Key code names:** `RuntimeLog`
- **Responsibilities:** Uncaught error logging
- **When to open:** When behavior tied to `runtime_log.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Uncaught error logging
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `runtime_log.dart` (diagnostics) — Uncaught error logging.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `runtime_log.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Uncaught error logging.
- **Когда открывать:** Когда ломается поведение, связанное с `runtime_log.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/diagnostics/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/diagnostics/startup_log.dart`

EN:

- **What this is:** Foundation module `startup_log.dart` (diagnostics) — Boot-phase structured logs.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `StartupLog`.
- **Key code names:** `StartupLog`
- **Responsibilities:** Boot-phase structured logs
- **When to open:** When behavior tied to `startup_log.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Boot-phase structured logs
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `startup_log.dart` (diagnostics) — Boot-phase structured logs.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `startup_log.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Boot-phase structured logs.
- **Когда открывать:** Когда ломается поведение, связанное с `startup_log.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/diagnostics/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/env/env.dart.example`

EN:

- **What this is:** example file `env.dart.example` in `lib/core/env` — repo tooling or config.
- **Why needed:** Tracked because `lib/core/env` needs `env.dart.example` for build, CI, or maintenance.
- **What it contains:** Open `env.dart.example` when working on `lib/core/env` (see folder section above).
- **Responsibilities:** Supports `lib/core/env` workflow for `env.dart.example`.
- **When to open:** When build output or maintenance cites `env.dart.example`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** `lib/core/env/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Шаблон compile-time secrets — копировать в `env.dart` (файл в gitignore).
- **Зачем:** Разработчикам нужны локальные env-константы без commit секретов в git.
- **Содержимое:** Пример ключей с placeholder values для локальной сборки.
- **Обязанности:** Документирует обязательную форму `env.dart`.
- **Когда открывать:** Новый разработчик не знает какие ключи нужны в `env.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/env/`, `docs/APP_STRUCTURE.md`.
- **Слой:** Dev template — не runtime без копирования в `env.dart`.


### `lib/core/link_scalar.dart`

EN:

- **What this is:** Foundation module `link_scalar.dart` (core) — Plan link scalar helper.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `link_scalar.dart` — open file for classes and helpers.
- **Responsibilities:** Plan link scalar helper
- **When to open:** When behavior tied to `link_scalar.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Plan link scalar helper
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `link_scalar.dart` (core) — Plan link scalar helper.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `link_scalar.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Plan link scalar helper.
- **Когда открывать:** Когда ломается поведение, связанное с `link_scalar.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/navigation/app_navigator.dart`

EN:

- **What this is:** Foundation module `app_navigator.dart` (navigation) — appRootNavigatorKey.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `app_navigator.dart` — open file for classes and helpers.
- **Responsibilities:** appRootNavigatorKey
- **When to open:** When behavior tied to `app_navigator.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: `appRootNavigatorKey` — root navigator for desktop overlays when main window is hidden
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `app_navigator.dart` (navigation) — appRootNavigatorKey.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `app_navigator.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: appRootNavigatorKey.
- **Когда открывать:** Когда ломается поведение, связанное с `app_navigator.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/navigation/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/navigation/shell_side_navigation.dart`

EN:

- **What this is:** Foundation module `shell_side_navigation.dart` (navigation) — Desktop/web side navigation rail.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Barrel `export` lines: `shell_side_navigation.dart`.
- **Responsibilities:** Desktop/web side navigation rail
- **When to open:** When behavior tied to `shell_side_navigation.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Desktop/web side navigation rail
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `shell_side_navigation.dart` (navigation) — Desktop/web side navigation rail.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `shell_side_navigation.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Desktop/web side navigation rail.
- **Когда открывать:** Когда ломается поведение, связанное с `shell_side_navigation.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/navigation/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/performance/rebuild_metrics.dart`

EN:

- **What this is:** Foundation module `rebuild_metrics.dart` (performance) — --dart-define=PERF_DIAG.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `RebuildMetrics`.
- **Key code names:** `RebuildMetrics`
- **Responsibilities:** --dart-define=PERF_DIAG
- **When to open:** When behavior tied to `rebuild_metrics.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Rebuild/frame metrics (`--dart-define=PERF_DIAG` gated)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `rebuild_metrics.dart` (performance) — --dart-define=PERF_DIAG.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `rebuild_metrics.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: --dart-define=PERF_DIAG.
- **Когда открывать:** Когда ломается поведение, связанное с `rebuild_metrics.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/performance/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/performance/runtime_flags.dart`

EN:

- **What this is:** Foundation module `runtime_flags.dart` (performance) — Feature kill switches (date strip, warm window, etc.).
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `runtime_flags.dart` — open file for classes and helpers.
- **Responsibilities:** Feature kill switches (date strip, warm window, etc.)
- **When to open:** When behavior tied to `runtime_flags.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Feature kill switches (date strip, warm window, etc.)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `runtime_flags.dart` (performance) — Feature kill switches (date strip, warm window, etc.).
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `runtime_flags.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Feature kill switches (date strip, warm window, etc.).
- **Когда открывать:** Когда ломается поведение, связанное с `runtime_flags.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/performance/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/performance/shell_flags.dart`

EN:

- **What this is:** Foundation module `shell_flags.dart` (performance) — Shell tab stack behavior flags.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `ShellFlags`.
- **Key code names:** `ShellFlags`
- **Responsibilities:** Shell tab stack behavior flags
- **When to open:** When behavior tied to `shell_flags.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Shell tab stack behavior flags
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `shell_flags.dart` (performance) — Shell tab stack behavior flags.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `shell_flags.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Shell tab stack behavior flags.
- **Когда открывать:** Когда ломается поведение, связанное с `shell_flags.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/performance/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/picker_entry_modes.dart`

EN:

- **What this is:** Foundation module `picker_entry_modes.dart` (core) — Platform-aware picker entry (keyboard vs touch).
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `picker_entry_modes.dart` — open file for classes and helpers.
- **Responsibilities:** Platform-aware picker entry (keyboard vs touch)
- **When to open:** When behavior tied to `picker_entry_modes.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Platform-aware picker entry (keyboard vs touch)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `picker_entry_modes.dart` (core) — Platform-aware picker entry (keyboard vs touch).
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `picker_entry_modes.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Platform-aware picker entry (keyboard vs touch).
- **Когда открывать:** Когда ломается поведение, связанное с `picker_entry_modes.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/plan_category_lookup.dart`

EN:

- **What this is:** Foundation module `plan_category_lookup.dart` (core) — Category presentation lookup (shell-injected).
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `PlanCategoryPresentation`, `PlanCategoryLookup`.
- **Key code names:** `PlanCategoryPresentation`, `PlanCategoryLookup`
- **Responsibilities:** Category presentation lookup (shell-injected)
- **When to open:** When behavior tied to `plan_category_lookup.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Category presentation lookup (shell-injected)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `plan_category_lookup.dart` (core) — Category presentation lookup (shell-injected).
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `plan_category_lookup.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Category presentation lookup (shell-injected).
- **Когда открывать:** Когда ломается поведение, связанное с `plan_category_lookup.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_hotkey_codec.dart`

EN:

- **What this is:** Foundation module `desktop_hotkey_codec.dart` (services) — Desktop hotkey string encode/decode.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopHotkeyCodec`.
- **Key code names:** `DesktopHotkeyCodec`
- **Responsibilities:** Desktop hotkey string encode/decode
- **When to open:** When behavior tied to `desktop_hotkey_codec.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Desktop hotkey string encode/decode
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_hotkey_codec.dart` (services) — Desktop hotkey string encode/decode.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_hotkey_codec.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Desktop hotkey string encode/decode.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_hotkey_codec.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_stt_diagnostics.dart`

EN:

- **What this is:** Foundation module `desktop_stt_diagnostics.dart` (services) — STT helper diagnostics markers.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopSttDiagnostics`.
- **Key code names:** `DesktopSttDiagnostics`
- **Responsibilities:** STT helper diagnostics markers
- **When to open:** When behavior tied to `desktop_stt_diagnostics.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: STT helper diagnostics markers
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_stt_diagnostics.dart` (services) — STT helper diagnostics markers.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_stt_diagnostics.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: STT helper diagnostics markers.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_stt_diagnostics.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_stt_helper_service.dart`

EN:

- **What this is:** Foundation module `desktop_stt_helper_service.dart` (services) — Desktop GOLOS STT helper subprocess and HTTP transcribe.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopSttHelperService`.
- **Key code names:** `DesktopSttHelperService`
- **Responsibilities:** Desktop GOLOS STT helper subprocess and HTTP transcribe
- **When to open:** When behavior tied to `desktop_stt_helper_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Desktop GOLOS STT helper subprocess and HTTP transcribe
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_stt_helper_service.dart` (services) — Desktop GOLOS STT helper subprocess and HTTP transcribe.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_stt_helper_service.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Desktop GOLOS STT helper subprocess and HTTP transcribe.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_stt_helper_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_tray_service.dart`

EN:

- **What this is:** Foundation module `desktop_tray_service.dart` (services) — System tray entry (conditional export).
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopTrayService`.
- **Key code names:** `DesktopTrayService`
- **Responsibilities:** System tray entry (conditional export)
- **When to open:** When behavior tied to `desktop_tray_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: System tray entry (conditional export)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_tray_service.dart` (services) — System tray entry (conditional export).
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_tray_service.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: System tray entry (conditional export).
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_tray_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_tray_service_io.dart`

EN:

- **What this is:** Foundation module `desktop_tray_service_io.dart` (services) — Windows tray implementation.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `_DesktopTrayListener`.
- **Key code names:** `_DesktopTrayListener`
- **Responsibilities:** Windows tray implementation
- **When to open:** When behavior tied to `desktop_tray_service_io.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Windows tray implementation
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_tray_service_io.dart` (services) — Windows tray implementation.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_tray_service_io.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Windows tray implementation.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_tray_service_io.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_tray_service_stub.dart`

EN:

- **What this is:** Foundation module `desktop_tray_service_stub.dart` (services) — Non-desktop tray stub.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `desktop_tray_service_stub.dart` — open file for classes and helpers.
- **Responsibilities:** Non-desktop tray stub
- **When to open:** When behavior tied to `desktop_tray_service_stub.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Non-desktop tray stub
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_tray_service_stub.dart` (services) — Non-desktop tray stub.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_tray_service_stub.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Non-desktop tray stub.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_tray_service_stub.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_acceptance_bridge.dart`

EN:

- **What this is:** Foundation module `desktop_voice_acceptance_bridge.dart` (services) — Acceptance-test hooks for desktop voice.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceAcceptanceBridge`.
- **Key code names:** `DesktopVoiceAcceptanceBridge`
- **Responsibilities:** Acceptance-test hooks for desktop voice
- **When to open:** When behavior tied to `desktop_voice_acceptance_bridge.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Acceptance-test hooks for desktop voice
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_acceptance_bridge.dart` (services) — Acceptance-test hooks for desktop voice.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_acceptance_bridge.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Acceptance-test hooks for desktop voice.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_acceptance_bridge.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_attempt_log.dart`

EN:

- **What this is:** Foundation module `desktop_voice_attempt_log.dart` (services) — Persisted voice attempt history for profile UI.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceAttemptStatus`, `DesktopVoiceAttempt`, `DesktopVoiceAttemptLog`.
- **Key code names:** `DesktopVoiceAttemptStatus`, `DesktopVoiceAttempt`, `DesktopVoiceAttemptLog`
- **Responsibilities:** Persisted voice attempt history for profile UI
- **When to open:** When behavior tied to `desktop_voice_attempt_log.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Persisted voice attempt history for profile UI
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_attempt_log.dart` (services) — Persisted voice attempt history for profile UI.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_attempt_log.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Persisted voice attempt history for profile UI.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_attempt_log.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_audio_capture.dart`

EN:

- **What this is:** Foundation module `desktop_voice_audio_capture.dart` (services) — Mic capture for desktop voice.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceAudioCapture`, `DesktopVoiceCaptureResult`.
- **Key code names:** `DesktopVoiceAudioCapture`, `DesktopVoiceCaptureResult`
- **Responsibilities:** Mic capture for desktop voice
- **When to open:** When behavior tied to `desktop_voice_audio_capture.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Mic capture for desktop voice
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_audio_capture.dart` (services) — Mic capture for desktop voice.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_audio_capture.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Mic capture for desktop voice.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_audio_capture.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_benchmark_service.dart`

EN:

- **What this is:** Foundation module `desktop_voice_benchmark_service.dart` (services) — Desktop voice benchmark harness.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceBenchmarkService`.
- **Key code names:** `DesktopVoiceBenchmarkService`
- **Responsibilities:** Desktop voice benchmark harness
- **When to open:** When behavior tied to `desktop_voice_benchmark_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Desktop voice benchmark harness
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_benchmark_service.dart` (services) — Desktop voice benchmark harness.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_benchmark_service.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Desktop voice benchmark harness.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_benchmark_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_command_normalize.dart`

EN:

- **What this is:** Foundation module `desktop_voice_command_normalize.dart` (services) — Transcript normalization before parse/submit.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceNormalizedCommand`.
- **Key code names:** `DesktopVoiceNormalizedCommand`
- **Responsibilities:** Transcript normalization before parse/submit
- **When to open:** When behavior tied to `desktop_voice_command_normalize.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Transcript normalization before parse/submit
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_command_normalize.dart` (services) — Transcript normalization before parse/submit.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_command_normalize.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Transcript normalization before parse/submit.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_command_normalize.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_confirmation.dart`

EN:

- **What this is:** Foundation module `desktop_voice_confirmation.dart` (services) — Start/stop voice confirmation copy.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceConfirmation`.
- **Key code names:** `DesktopVoiceConfirmation`
- **Responsibilities:** Start/stop voice confirmation copy
- **When to open:** When behavior tied to `desktop_voice_confirmation.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Start/stop voice confirmation copy
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_confirmation.dart` (services) — Start/stop voice confirmation copy.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_confirmation.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Start/stop voice confirmation copy.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_confirmation.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_engine.dart`

EN:

- **What this is:** Foundation module `desktop_voice_engine.dart` (services) — Desktop voice engine lifecycle.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceEngineId`, `DesktopVoiceEngineBenchmark`.
- **Key code names:** `DesktopVoiceEngineId`, `DesktopVoiceEngineBenchmark`
- **Responsibilities:** Desktop voice engine lifecycle
- **When to open:** When behavior tied to `desktop_voice_engine.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Desktop voice engine lifecycle
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_engine.dart` (services) — Desktop voice engine lifecycle.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_engine.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Desktop voice engine lifecycle.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_engine.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_hotkey.dart`

EN:

- **What this is:** Foundation module `desktop_voice_hotkey.dart` (services) — Global desktop voice hotkey coordinator.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceHotkey`, `DesktopVoiceHotkeyAction`.
- **Key code names:** `DesktopVoiceHotkey`, `DesktopVoiceHotkeyAction`
- **Responsibilities:** Global desktop voice hotkey coordinator
- **When to open:** When behavior tied to `desktop_voice_hotkey.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Global desktop voice hotkey coordinator
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_hotkey.dart` (services) — Global desktop voice hotkey coordinator.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_hotkey.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Global desktop voice hotkey coordinator.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_hotkey.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_hotkey_io.dart`

EN:

- **What this is:** Foundation module `desktop_voice_hotkey_io.dart` (services) — Windows hotkey registration.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `desktop_voice_hotkey_io.dart` — open file for classes and helpers.
- **Responsibilities:** Windows hotkey registration
- **When to open:** When behavior tied to `desktop_voice_hotkey_io.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Windows hotkey registration
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_hotkey_io.dart` (services) — Windows hotkey registration.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_hotkey_io.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Windows hotkey registration.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_hotkey_io.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_hotkey_markers.dart`

EN:

- **What this is:** Foundation module `desktop_voice_hotkey_markers.dart` (services) — Hotkey self-test / acceptance markers.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceHotkeyMarkers`.
- **Key code names:** `DesktopVoiceHotkeyMarkers`
- **Responsibilities:** Hotkey self-test / acceptance markers
- **When to open:** When behavior tied to `desktop_voice_hotkey_markers.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Hotkey self-test / acceptance markers
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_hotkey_markers.dart` (services) — Hotkey self-test / acceptance markers.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_hotkey_markers.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Hotkey self-test / acceptance markers.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_hotkey_markers.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_hotkey_stub.dart`

EN:

- **What this is:** Foundation module `desktop_voice_hotkey_stub.dart` (services) — Non-desktop hotkey stub.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `desktop_voice_hotkey_stub.dart` — open file for classes and helpers.
- **Responsibilities:** Non-desktop hotkey stub
- **When to open:** When behavior tied to `desktop_voice_hotkey_stub.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Non-desktop hotkey stub
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_hotkey_stub.dart` (services) — Non-desktop hotkey stub.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_hotkey_stub.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Non-desktop hotkey stub.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_hotkey_stub.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_native_overlay.dart`

EN:

- **What this is:** Foundation module `desktop_voice_native_overlay.dart` (services) — Native overlay channel bridge.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceNativeOverlay`.
- **Key code names:** `DesktopVoiceNativeOverlay`
- **Responsibilities:** Native overlay channel bridge
- **When to open:** When behavior tied to `desktop_voice_native_overlay.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Native overlay channel bridge
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_native_overlay.dart` (services) — Native overlay channel bridge.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_native_overlay.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Native overlay channel bridge.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_native_overlay.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_overlay_bridge.dart`

EN:

- **What this is:** Foundation module `desktop_voice_overlay_bridge.dart` (services) — Overlay ↔ Flutter bridge.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceOverlayBridge`.
- **Key code names:** `DesktopVoiceOverlayBridge`
- **Responsibilities:** Overlay ↔ Flutter bridge
- **When to open:** When behavior tied to `desktop_voice_overlay_bridge.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Overlay ↔ Flutter bridge
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_overlay_bridge.dart` (services) — Overlay ↔ Flutter bridge.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_overlay_bridge.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Overlay ↔ Flutter bridge.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_overlay_bridge.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_overlay_host.dart`

EN:

- **What this is:** Foundation module `desktop_voice_overlay_host.dart` (services) — Overlay host conditional export.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceOverlayHost`.
- **Key code names:** `DesktopVoiceOverlayHost`
- **Responsibilities:** Overlay host conditional export
- **When to open:** When behavior tied to `desktop_voice_overlay_host.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Overlay host conditional export
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_overlay_host.dart` (services) — Overlay host conditional export.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_overlay_host.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Overlay host conditional export.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_overlay_host.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_overlay_host_io.dart`

EN:

- **What this is:** Foundation module `desktop_voice_overlay_host_io.dart` (services) — Windows overlay host.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `desktop_voice_overlay_host_io.dart` — open file for classes and helpers.
- **Responsibilities:** Windows overlay host
- **When to open:** When behavior tied to `desktop_voice_overlay_host_io.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Windows overlay host
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_overlay_host_io.dart` (services) — Windows overlay host.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_overlay_host_io.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Windows overlay host.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_overlay_host_io.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_overlay_host_stub.dart`

EN:

- **What this is:** Foundation module `desktop_voice_overlay_host_stub.dart` (services) — Non-desktop overlay host stub.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `desktop_voice_overlay_host_stub.dart` — open file for classes and helpers.
- **Responsibilities:** Non-desktop overlay host stub
- **When to open:** When behavior tied to `desktop_voice_overlay_host_stub.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Non-desktop overlay host stub
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_overlay_host_stub.dart` (services) — Non-desktop overlay host stub.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_overlay_host_stub.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Non-desktop overlay host stub.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_overlay_host_stub.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_overlay_service.dart`

EN:

- **What this is:** Foundation module `desktop_voice_overlay_service.dart` (services) — Native overlay state machine.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceOverlayService`.
- **Key code names:** `DesktopVoiceOverlayService`
- **Responsibilities:** Native overlay state machine
- **When to open:** When behavior tied to `desktop_voice_overlay_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Native overlay state machine
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_overlay_service.dart` (services) — Native overlay state machine.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_overlay_service.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Native overlay state machine.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_overlay_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_recognizer.dart`

EN:

- **What this is:** Foundation module `desktop_voice_recognizer.dart` (services) — Desktop voice recognizer interface.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceRecognitionResult`, `DesktopVoiceRecognizer`.
- **Key code names:** `DesktopVoiceRecognitionResult`, `DesktopVoiceRecognizer`
- **Responsibilities:** Desktop voice recognizer interface
- **When to open:** When behavior tied to `desktop_voice_recognizer.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Desktop voice recognizer interface
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_recognizer.dart` (services) — Desktop voice recognizer interface.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_recognizer.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Desktop voice recognizer interface.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_recognizer.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_recognizer_factory.dart`

EN:

- **What this is:** Foundation module `desktop_voice_recognizer_factory.dart` (services) — Platform recognizer factory.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Barrel `export` lines: `desktop_voice_recognizer.dart`, `desktop_voice_recognizer_stub.dart`.
- **Responsibilities:** Platform recognizer factory
- **When to open:** When behavior tied to `desktop_voice_recognizer_factory.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Platform recognizer factory
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_recognizer_factory.dart` (services) — Platform recognizer factory.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_recognizer_factory.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Platform recognizer factory.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_recognizer_factory.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_recognizer_io.dart`

EN:

- **What this is:** Foundation module `desktop_voice_recognizer_io.dart` (services) — Windows recognizer implementation.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceRecognizerGolosHelper`.
- **Key code names:** `DesktopVoiceRecognizerGolosHelper`
- **Responsibilities:** Windows recognizer implementation
- **When to open:** When behavior tied to `desktop_voice_recognizer_io.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Windows recognizer implementation
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_recognizer_io.dart` (services) — Windows recognizer implementation.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_recognizer_io.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Windows recognizer implementation.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_recognizer_io.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_recognizer_stub.dart`

EN:

- **What this is:** Foundation module `desktop_voice_recognizer_stub.dart` (services) — Non-desktop recognizer stub.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `_DesktopVoiceRecognizerUnsupported`.
- **Key code names:** `_DesktopVoiceRecognizerUnsupported`
- **Responsibilities:** Non-desktop recognizer stub
- **When to open:** When behavior tied to `desktop_voice_recognizer_stub.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Non-desktop recognizer stub
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_recognizer_stub.dart` (services) — Non-desktop recognizer stub.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_recognizer_stub.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Non-desktop recognizer stub.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_recognizer_stub.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_record_submit.dart`

EN:

- **What this is:** Foundation module `desktop_voice_record_submit.dart` (services) — writeRecord.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceWriteRecordRequest`, `DesktopVoiceWriteRecordFn`, `DesktopVoiceSubmitOutcome`, `DesktopVoiceRecordSubmit`.
- **Key code names:** `DesktopVoiceWriteRecordRequest`, `DesktopVoiceWriteRecordFn`, `DesktopVoiceSubmitOutcome`, `DesktopVoiceRecordSubmit`
- **Responsibilities:** writeRecord
- **When to open:** When behavior tied to `desktop_voice_record_submit.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Parsed voice command → `writeRecord` bridge
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_record_submit.dart` (services) — writeRecord.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_record_submit.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: writeRecord.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_record_submit.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_settings.dart`

EN:

- **What this is:** Foundation module `desktop_voice_settings.dart` (services) — Local desktop voice prefs (SharedPreferences).
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceHotkeyConfig`, `DesktopVoiceSettings`.
- **Key code names:** `DesktopVoiceHotkeyConfig`, `DesktopVoiceSettings`
- **Responsibilities:** Local desktop voice prefs (SharedPreferences)
- **When to open:** When behavior tied to `desktop_voice_settings.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Local desktop voice prefs (SharedPreferences)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_settings.dart` (services) — Local desktop voice prefs (SharedPreferences).
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_settings.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Local desktop voice prefs (SharedPreferences).
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_settings.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_smoke_bridge.dart`

EN:

- **What this is:** Foundation module `desktop_voice_smoke_bridge.dart` (services) — Smoke-test hooks for desktop voice.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceSmokeBridge`.
- **Key code names:** `DesktopVoiceSmokeBridge`
- **Responsibilities:** Smoke-test hooks for desktop voice
- **When to open:** When behavior tied to `desktop_voice_smoke_bridge.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Smoke-test hooks for desktop voice
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_smoke_bridge.dart` (services) — Smoke-test hooks for desktop voice.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_smoke_bridge.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Smoke-test hooks for desktop voice.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_smoke_bridge.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_user_error.dart`

EN:

- **What this is:** Foundation module `desktop_voice_user_error.dart` (services) — Friendly desktop voice error mapping.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopVoiceErrorStage`, `DesktopVoiceUserError`.
- **Key code names:** `DesktopVoiceErrorStage`, `DesktopVoiceUserError`
- **Responsibilities:** Friendly desktop voice error mapping
- **When to open:** When behavior tied to `desktop_voice_user_error.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Friendly desktop voice error mapping
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_user_error.dart` (services) — Friendly desktop voice error mapping.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_user_error.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Friendly desktop voice error mapping.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_user_error.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_voice_window_flags.dart`

EN:

- **What this is:** Foundation module `desktop_voice_window_flags.dart` (services) — Desktop window visibility flags.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `desktop_voice_window_flags.dart` — open file for classes and helpers.
- **Responsibilities:** Desktop window visibility flags
- **When to open:** When behavior tied to `desktop_voice_window_flags.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Desktop window visibility flags
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_voice_window_flags.dart` (services) — Desktop window visibility flags.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_voice_window_flags.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Desktop window visibility flags.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_window_flags.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/desktop_win_speech_service.dart`

EN:

- **What this is:** Foundation module `desktop_win_speech_service.dart` (services) — Windows speech platform adapter.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `DesktopWinSpeechService`.
- **Key code names:** `DesktopWinSpeechService`
- **Responsibilities:** Windows speech platform adapter
- **When to open:** When behavior tied to `desktop_win_speech_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Windows speech platform adapter
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `desktop_win_speech_service.dart` (services) — Windows speech platform adapter.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `desktop_win_speech_service.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Windows speech platform adapter.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_win_speech_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/pcm_audio_utils.dart`

EN:

- **What this is:** Foundation module `pcm_audio_utils.dart` (services) — PCM/WAV audio helpers for desktop STT.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `pcm_audio_utils.dart` — open file for classes and helpers.
- **Responsibilities:** PCM/WAV audio helpers for desktop STT
- **When to open:** When behavior tied to `pcm_audio_utils.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: PCM/WAV audio helpers for desktop STT
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `pcm_audio_utils.dart` (services) — PCM/WAV audio helpers for desktop STT.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `pcm_audio_utils.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: PCM/WAV audio helpers for desktop STT.
- **Когда открывать:** Когда ломается поведение, связанное с `pcm_audio_utils.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/speech_engine_handle.dart`

EN:

- **What this is:** Foundation module `speech_engine_handle.dart` (services) — Speech-to-text engine lifecycle.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `speech_engine_handle.dart` — open file for classes and helpers.
- **Responsibilities:** Speech-to-text engine lifecycle
- **When to open:** When behavior tied to `speech_engine_handle.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Speech-to-text engine lifecycle
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `speech_engine_handle.dart` (services) — Speech-to-text engine lifecycle.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `speech_engine_handle.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Speech-to-text engine lifecycle.
- **Когда открывать:** Когда ломается поведение, связанное с `speech_engine_handle.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/services/speech_listen_locale.dart`

EN:

- **What this is:** Foundation module `speech_listen_locale.dart` (services) — STT locale resolution.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `SpeechListenLocale`.
- **Key code names:** `SpeechListenLocale`
- **Responsibilities:** STT locale resolution
- **When to open:** When behavior tied to `speech_listen_locale.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: STT locale resolution
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `speech_listen_locale.dart` (services) — STT locale resolution.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `speech_listen_locale.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: STT locale resolution.
- **Когда открывать:** Когда ломается поведение, связанное с `speech_listen_locale.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/services/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/shell_adaptive.dart`

EN:

- **What this is:** Foundation module `shell_adaptive.dart` (core) — Side vs bottom navigation breakpoint.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `shell_adaptive.dart` — open file for classes and helpers.
- **Responsibilities:** Side vs bottom navigation breakpoint
- **When to open:** When behavior tied to `shell_adaptive.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Side vs bottom navigation breakpoint
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `shell_adaptive.dart` (core) — Side vs bottom navigation breakpoint.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `shell_adaptive.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Side vs bottom navigation breakpoint.
- **Когда открывать:** Когда ломается поведение, связанное с `shell_adaptive.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/shell_layout_state.dart`

EN:

- **What this is:** Foundation module `shell_layout_state.dart` (core) — ShellLayoutController.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `ShellLayoutController`, `ShellLayoutScope`.
- **Key code names:** `ShellLayoutController`, `ShellLayoutScope`
- **Responsibilities:** ShellLayoutController
- **When to open:** When behavior tied to `shell_layout_state.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: `ShellLayoutController` / FAB clearance
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `shell_layout_state.dart` (core) — ShellLayoutController.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `shell_layout_state.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: ShellLayoutController.
- **Когда открывать:** Когда ломается поведение, связанное с `shell_layout_state.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/tag_contrast.dart`

EN:

- **What this is:** Foundation module `tag_contrast.dart` (core) — Tag foreground/background contrast.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `tag_contrast.dart` — open file for classes and helpers.
- **Responsibilities:** Tag foreground/background contrast
- **When to open:** When behavior tied to `tag_contrast.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Tag foreground/background contrast
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `tag_contrast.dart` (core) — Tag foreground/background contrast.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `tag_contrast.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Tag foreground/background contrast.
- **Когда открывать:** Когда ломается поведение, связанное с `tag_contrast.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/theme.dart`

EN:

- **What this is:** Foundation module `theme.dart` (core) — ThemeData.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `theme.dart` — open file for classes and helpers.
- **Responsibilities:** ThemeData
- **When to open:** When behavior tied to `theme.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: `ThemeData`, density, input decoration
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `theme.dart` (core) — ThemeData.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `theme.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: ThemeData.
- **Когда открывать:** Когда ломается поведение, связанное с `theme.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/time/app_clock.dart`

EN:

- **What this is:** Foundation module `app_clock.dart` (time) — Injectable wall clock + timezone label.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `WallNowFn`, `AppClock`.
- **Key code names:** `WallNowFn`, `AppClock`
- **Responsibilities:** Injectable wall clock + timezone label
- **When to open:** When behavior tied to `app_clock.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Injectable wall clock + timezone label
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `app_clock.dart` (time) — Injectable wall clock + timezone label.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `app_clock.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Injectable wall clock + timezone label.
- **Когда открывать:** Когда ломается поведение, связанное с `app_clock.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/time/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/time/category_timezone_options.dart`

EN:

- **What this is:** Foundation module `category_timezone_options.dart` (time) — Per-category timezone option list.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `CategoryDefaultTimezoneOption`.
- **Key code names:** `CategoryDefaultTimezoneOption`
- **Responsibilities:** Per-category timezone option list
- **When to open:** When behavior tied to `category_timezone_options.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Per-category timezone option list
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `category_timezone_options.dart` (time) — Per-category timezone option list.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `category_timezone_options.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Per-category timezone option list.
- **Когда открывать:** Когда ломается поведение, связанное с `category_timezone_options.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/time/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/time/plan_time_labels.dart`

EN:

- **What this is:** Foundation module `plan_time_labels.dart` (time) — Plan time label formatting.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `plan_time_labels.dart` — open file for classes and helpers.
- **Responsibilities:** Plan time label formatting
- **When to open:** When behavior tied to `plan_time_labels.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Plan time label formatting
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `plan_time_labels.dart` (time) — Plan time label formatting.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `plan_time_labels.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Plan time label formatting.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_time_labels.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/time/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/time/plan_time_visible_window.dart`

EN:

- **What this is:** Foundation module `plan_time_visible_window.dart` (time) — Extended Time View day window math (−3..27 h).
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `PlanTimeVisibleWindow`.
- **Key code names:** `PlanTimeVisibleWindow`
- **Responsibilities:** Extended Time View day window math (−3..27 h)
- **When to open:** When behavior tied to `plan_time_visible_window.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Extended Time View day window math (−3..27 h)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `plan_time_visible_window.dart` (time) — Extended Time View day window math (−3..27 h).
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `plan_time_visible_window.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Extended Time View day window math (−3..27 h).
- **Когда открывать:** Когда ломается поведение, связанное с `plan_time_visible_window.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/time/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/time/profile_timezone_actions.dart`

EN:

- **What this is:** Foundation module `profile_timezone_actions.dart` (time) — ProfileTimezoneActions.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `ProfileTimezoneShortLabelFn`, `SaveProfileTimezoneFn`, `CurrentUserSettingsFn`, `ProfileTimezoneActions`.
- **Key code names:** `ProfileTimezoneShortLabelFn`, `SaveProfileTimezoneFn`, `CurrentUserSettingsFn`, `ProfileTimezoneActions`
- **Responsibilities:** ProfileTimezoneActions
- **When to open:** When behavior tied to `profile_timezone_actions.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Injectable profile timezone read/write hooks (`ProfileTimezoneActions`)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `profile_timezone_actions.dart` (time) — ProfileTimezoneActions.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `profile_timezone_actions.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: ProfileTimezoneActions.
- **Когда открывать:** Когда ломается поведение, связанное с `profile_timezone_actions.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/time/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/time/profile_timezone_catalog.dart`

EN:

- **What this is:** Foundation module `profile_timezone_catalog.dart` (time) — Canonical profile timezone catalog, IANA IDs, DST labels.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Primary symbols: `ProfileTimezoneCatalogEntry`.
- **Key code names:** `ProfileTimezoneCatalogEntry`
- **Responsibilities:** Canonical profile timezone catalog, IANA IDs, DST labels
- **When to open:** When behavior tied to `profile_timezone_catalog.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Canonical profile timezone catalog, IANA IDs, DST labels
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `profile_timezone_catalog.dart` (time) — Canonical profile timezone catalog, IANA IDs, DST labels.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `profile_timezone_catalog.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Canonical profile timezone catalog, IANA IDs, DST labels.
- **Когда открывать:** Когда ломается поведение, связанное с `profile_timezone_catalog.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/time/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/time/wall_clock.dart`

EN:

- **What this is:** Foundation module `wall_clock.dart` (time) — Wall-clock formatting helpers.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `wall_clock.dart` — open file for classes and helpers.
- **Responsibilities:** Wall-clock formatting helpers
- **When to open:** When behavior tied to `wall_clock.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Wall-clock formatting helpers
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `wall_clock.dart` (time) — Wall-clock formatting helpers.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `wall_clock.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Wall-clock formatting helpers.
- **Когда открывать:** Когда ломается поведение, связанное с `wall_clock.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/time/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/url_strategy_stub.dart`

EN:

- **What this is:** Foundation module `url_strategy_stub.dart` (core) — Web URL strategy conditional import.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `url_strategy_stub.dart` — open file for classes and helpers.
- **Responsibilities:** Web URL strategy conditional import
- **When to open:** When behavior tied to `url_strategy_stub.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Web URL strategy conditional import
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `url_strategy_stub.dart` (core) — Web URL strategy conditional import.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `url_strategy_stub.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Web URL strategy conditional import.
- **Когда открывать:** Когда ломается поведение, связанное с `url_strategy_stub.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/web_redirect.dart`

EN:

- **What this is:** Foundation module `web_redirect.dart` (core) — Production web OAuth redirect URI helper.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart module `web_redirect.dart` — open file for classes and helpers.
- **Responsibilities:** Production web OAuth redirect URI helper
- **When to open:** When behavior tied to `web_redirect.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Production web OAuth redirect URI helper
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Foundation-модуль `web_redirect.dart` (core) — Production web OAuth redirect URI helper.
- **Зачем:** Общий код вне одного экрана: тема, время, voice, diagnostics.
- **Содержимое:** Dart-модуль `web_redirect.dart` — классы и helpers в исходнике.
- **Обязанности:** Foundation-логика: Production web OAuth redirect URI helper.
- **Когда открывать:** Когда ломается поведение, связанное с `web_redirect.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/`, `docs/APP_STRUCTURE.md`
- **Слой:** Foundation — тема, время, voice, диагностика.


### `lib/core/widgets/app_bar_live_clock.dart`

EN:

- **What this is:** Shared design-system widget — Live clock chip.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppBarLiveClock`, `_AppBarLiveClockState`).
- **Key code names:** `AppBarLiveClock`, `_AppBarLiveClockState`
- **Responsibilities:** Live clock chip
- **When to open:** When behavior tied to `app_bar_live_clock.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Live clock chip
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Live clock chip.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `app_bar_live_clock`).
- **Обязанности:** Реализует в UI: Live clock chip.
- **Когда открывать:** Когда ломается поведение, связанное с `app_bar_live_clock.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/app_button.dart`

EN:

- **What this is:** Shared design-system widget — `AppButton`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppButtonVariant`, `AppButtonSize`, `AppButton`).
- **Key code names:** `AppButtonVariant`, `AppButtonSize`, `AppButton`
- **Responsibilities:** `AppButton`
- **When to open:** When behavior tied to `app_button.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: `AppButton`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — `AppButton`.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `app_button`).
- **Обязанности:** Реализует в UI: `AppButton`.
- **Когда открывать:** Когда ломается поведение, связанное с `app_button.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/app_icon_button.dart`

EN:

- **What this is:** Shared design-system widget — `AppIconButton`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppIconButtonVariant`, `AppIconButtonSize`, `AppIconButton`).
- **Key code names:** `AppIconButtonVariant`, `AppIconButtonSize`, `AppIconButton`
- **Responsibilities:** `AppIconButton`
- **When to open:** When behavior tied to `app_icon_button.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: `AppIconButton`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — `AppIconButton`.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `app_icon_button`).
- **Обязанности:** Реализует в UI: `AppIconButton`.
- **Когда открывать:** Когда ломается поведение, связанное с `app_icon_button.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/app_loading.dart`

EN:

- **What this is:** Shared design-system widget — `AppLoading`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppLoadingSize`, `AppLoading`).
- **Key code names:** `AppLoadingSize`, `AppLoading`
- **Responsibilities:** `AppLoading`
- **When to open:** When behavior tied to `app_loading.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: `AppLoading`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — `AppLoading`.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `app_loading`).
- **Обязанности:** Реализует в UI: `AppLoading`.
- **Когда открывать:** Когда ломается поведение, связанное с `app_loading.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/app_mic_level_bars.dart`

EN:

- **What this is:** Shared design-system widget — Mic level visualization bars for voice UI.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppMicLevelBars`).
- **Key code names:** `AppMicLevelBars`
- **Responsibilities:** Mic level visualization bars for voice UI
- **When to open:** When behavior tied to `app_mic_level_bars.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Mic level visualization bars for voice UI
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Mic level visualization bars for voice UI.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `app_mic_level_bars`).
- **Обязанности:** Реализует в UI: Mic level visualization bars for voice UI.
- **Когда открывать:** Когда ломается поведение, связанное с `app_mic_level_bars.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/app_settings_layout.dart`

EN:

- **What this is:** Shared design-system widget — `AppSettingsPageBody`, `AppSettingsSectionCard`, settings row helpers.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppSettingsTab`, `AppSettingsCategoryTabs`, `AppHotkeyKeycaps`, `_Keycap`, `AppSettingsPageBody`, `AppSettingsSectionCard`).
- **Key code names:** `AppSettingsTab`, `AppSettingsCategoryTabs`, `AppHotkeyKeycaps`, `_Keycap`, `AppSettingsPageBody`, `AppSettingsSectionCard`, `AppSettingsSwitchRow`, `AppSettingsInfoRow`, `AppSettingsActionRow`, `AppSettingsCardGrid`
- **Responsibilities:** `AppSettingsPageBody`, `AppSettingsSectionCard`, settings row helpers
- **When to open:** When behavior tied to `app_settings_layout.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: `AppSettingsPageBody`, `AppSettingsSectionCard`, settings row helpers
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — `AppSettingsPageBody`, `AppSettingsSectionCard`, settings row helpers.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `app_settings_layout`).
- **Обязанности:** Реализует в UI: `AppSettingsPageBody`, `AppSettingsSectionCard`, settings row helpers.
- **Когда открывать:** Когда ломается поведение, связанное с `app_settings_layout.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/app_state_views.dart`

EN:

- **What this is:** Shared design-system widget — `AppErrorState`, `AppEmptyState`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppErrorState`, `AppEmptyState`).
- **Key code names:** `AppErrorState`, `AppEmptyState`
- **Responsibilities:** `AppErrorState`, `AppEmptyState`
- **When to open:** When behavior tied to `app_state_views.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: `AppErrorState`, `AppEmptyState`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — `AppErrorState`, `AppEmptyState`.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `app_state_views`).
- **Обязанности:** Реализует в UI: `AppErrorState`, `AppEmptyState`.
- **Когда открывать:** Когда ломается поведение, связанное с `app_state_views.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/app_timezone_icon.dart`

EN:

- **What this is:** Shared design-system widget — Canonical solid timezone icon family.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppTimezoneIcon`, `_AppTimezoneIconPainter`).
- **Key code names:** `AppTimezoneIcon`, `_AppTimezoneIconPainter`
- **Responsibilities:** Canonical solid timezone icon family
- **When to open:** When behavior tied to `app_timezone_icon.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Canonical solid timezone icon family
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Canonical solid timezone icon family.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `app_timezone_icon`).
- **Обязанности:** Реализует в UI: Canonical solid timezone icon family.
- **Когда открывать:** Когда ломается поведение, связанное с `app_timezone_icon.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/chip_component.dart`

EN:

- **What this is:** Shared design-system widget — `TagChip`, `CategoryChip`, tag quick-pick strip.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`CategoryBreadcrumb`, `CategoryChipVariant`, `CategoryChip`).
- **Key code names:** `CategoryBreadcrumb`, `CategoryChipVariant`, `CategoryChip`
- **Responsibilities:** `TagChip`, `CategoryChip`, tag quick-pick strip
- **When to open:** When behavior tied to `chip_component.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: `TagChip`, `CategoryChip`, tag quick-pick strip
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — `TagChip`, `CategoryChip`, tag quick-pick strip.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `chip_component`).
- **Обязанности:** Реализует в UI: `TagChip`, `CategoryChip`, tag quick-pick strip.
- **Когда открывать:** Когда ломается поведение, связанное с `chip_component.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/compact_nav_controls.dart`

EN:

- **What this is:** Shared design-system widget — Compact segmented controls.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppCompactSegmentLabel`, `AppCompactTextTab`).
- **Key code names:** `AppCompactSegmentLabel`, `AppCompactTextTab`
- **Responsibilities:** Compact segmented controls
- **When to open:** When behavior tied to `compact_nav_controls.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Compact segmented controls
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Compact segmented controls.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `compact_nav_controls`).
- **Обязанности:** Реализует в UI: Compact segmented controls.
- **Когда открывать:** Когда ломается поведение, связанное с `compact_nav_controls.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/confirm_dialog.dart`

EN:

- **What this is:** Shared design-system widget — `showConfirmDialog`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (logic in `confirm_dialog`).
- **Responsibilities:** `showConfirmDialog`
- **When to open:** When behavior tied to `confirm_dialog.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: `showConfirmDialog`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — `showConfirmDialog`.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `confirm_dialog`).
- **Обязанности:** Реализует в UI: `showConfirmDialog`.
- **Когда открывать:** Когда ломается поведение, связанное с `confirm_dialog.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/day_content_strip.dart`

EN:

- **What this is:** Shared design-system widget — Day content pager strip.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`EagerDayItemBuilder`, `EagerDayContentStripController`, `EagerDayContentStrip`, `_EagerDayContentStripState`, `_MountedDaySlot`, `_MountedDaySlotState`).
- **Key code names:** `EagerDayItemBuilder`, `EagerDayContentStripController`, `EagerDayContentStrip`, `_EagerDayContentStripState`, `_MountedDaySlot`, `_MountedDaySlotState`
- **Responsibilities:** Day content pager strip
- **When to open:** When behavior tied to `day_content_strip.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Day content pager strip
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Day content pager strip.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `day_content_strip`).
- **Обязанности:** Реализует в UI: Day content pager strip.
- **Когда открывать:** Когда ломается поведение, связанное с `day_content_strip.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/day_window.dart`

EN:

- **What this is:** Shared design-system widget — Mounted day window.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (logic in `day_window`).
- **Responsibilities:** Mounted day window
- **When to open:** When behavior tied to `day_window.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Mounted day window
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Mounted day window.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `day_window`).
- **Обязанности:** Реализует в UI: Mounted day window.
- **Когда открывать:** Когда ломается поведение, связанное с `day_window.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/global_app_header.dart`

EN:

- **What this is:** Shared design-system widget — Date/time header strip.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`GlobalAppHeader`).
- **Key code names:** `GlobalAppHeader`
- **Responsibilities:** Date/time header strip
- **When to open:** When behavior tied to `global_app_header.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Date/time header strip
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Date/time header strip.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `global_app_header`).
- **Обязанности:** Реализует в UI: Date/time header strip.
- **Когда открывать:** Когда ломается поведение, связанное с `global_app_header.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/lazy_indexed_stack.dart`

EN:

- **What this is:** Shared design-system widget — Optional lazy shell tab stack.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`LazyIndexedStack`, `_LazyIndexedStackState`).
- **Key code names:** `LazyIndexedStack`, `_LazyIndexedStackState`
- **Responsibilities:** Optional lazy shell tab stack
- **When to open:** When behavior tied to `lazy_indexed_stack.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Optional lazy shell tab stack
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Optional lazy shell tab stack.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `lazy_indexed_stack`).
- **Обязанности:** Реализует в UI: Optional lazy shell tab stack.
- **Когда открывать:** Когда ломается поведение, связанное с `lazy_indexed_stack.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/life_card.dart`

EN:

- **What this is:** Shared design-system widget — Card foundation for Component Lab.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`LifeCardState`, `LifeCardDensity`, `AppTaskCardType`, `LifeCard`, `AppTaskCard`, `_TaskMetaPill`).
- **Key code names:** `LifeCardState`, `LifeCardDensity`, `AppTaskCardType`, `LifeCard`, `AppTaskCard`, `_TaskMetaPill`, `_TaskTagPill`
- **Responsibilities:** Card foundation for Component Lab
- **When to open:** When behavior tied to `life_card.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Card foundation for Component Lab
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Card foundation for Component Lab.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `life_card`).
- **Обязанности:** Реализует в UI: Card foundation for Component Lab.
- **Когда открывать:** Когда ломается поведение, связанное с `life_card.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/mouse_drag_scroll_behavior.dart`

EN:

- **What this is:** Shared design-system widget — Desktop/web drag scroll.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`MouseDragScrollBehavior`).
- **Key code names:** `MouseDragScrollBehavior`
- **Responsibilities:** Desktop/web drag scroll
- **When to open:** When behavior tied to `mouse_drag_scroll_behavior.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Desktop/web drag scroll
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Desktop/web drag scroll.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `mouse_drag_scroll_behavior`).
- **Обязанности:** Реализует в UI: Desktop/web drag scroll.
- **Когда открывать:** Когда ломается поведение, связанное с `mouse_drag_scroll_behavior.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/omni_date_time_picker_dialog.dart`

EN:

- **What this is:** Shared design-system widget — Unified date+time picker.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`_OmniDateTimePickerDialog`, `_OmniDateTimePickerDialogState`).
- **Key code names:** `_OmniDateTimePickerDialog`, `_OmniDateTimePickerDialogState`
- **Responsibilities:** Unified date+time picker
- **When to open:** When behavior tied to `omni_date_time_picker_dialog.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Unified date+time picker
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Unified date+time picker.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `omni_date_time_picker_dialog`).
- **Обязанности:** Реализует в UI: Unified date+time picker.
- **Когда открывать:** Когда ломается поведение, связанное с `omni_date_time_picker_dialog.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/plan_card.dart`

EN:

- **What this is:** Shared design-system widget — `PlanCard` wrapper.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`PlanCard`).
- **Key code names:** `PlanCard`
- **Responsibilities:** `PlanCard` wrapper
- **When to open:** When behavior tied to `plan_card.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: `PlanCard` wrapper
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — `PlanCard` wrapper.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `plan_card`).
- **Обязанности:** Реализует в UI: `PlanCard` wrapper.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_card.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/plan_card/plan_card_controls.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_controls.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (logic in `plan_card_controls`).
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_controls.dart`
- **When to open:** When behavior tied to `plan_card_controls.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Re-export stub → `plan_time_task_card/plan_card_controls.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_controls.dart`.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `plan_card_controls`).
- **Обязанности:** Реализует в UI: Re-export stub → `plan_time_task_card/plan_card_controls.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_card_controls.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/plan_card/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/plan_card/plan_card_geometry.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_geometry.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (logic in `plan_card_geometry`).
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_geometry.dart`
- **When to open:** When behavior tied to `plan_card_geometry.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Re-export stub → `plan_time_task_card/plan_card_geometry.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_geometry.dart`.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `plan_card_geometry`).
- **Обязанности:** Реализует в UI: Re-export stub → `plan_time_task_card/plan_card_geometry.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_card_geometry.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/plan_card/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/plan_card/plan_card_metrics.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_metrics.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (logic in `plan_card_metrics`).
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_metrics.dart`
- **When to open:** When behavior tied to `plan_card_metrics.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Re-export stub → `plan_time_task_card/plan_card_metrics.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_metrics.dart`.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `plan_card_metrics`).
- **Обязанности:** Реализует в UI: Re-export stub → `plan_time_task_card/plan_card_metrics.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_card_metrics.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/plan_card/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/plan_card/plan_card_sections.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_sections.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (logic in `plan_card_sections`).
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_sections.dart`
- **When to open:** When behavior tied to `plan_card_sections.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Re-export stub → `plan_time_task_card/plan_card_sections.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_sections.dart`.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `plan_card_sections`).
- **Обязанности:** Реализует в UI: Re-export stub → `plan_time_task_card/plan_card_sections.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_card_sections.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/plan_card/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/plan_card/plan_time_card_density.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_density.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (logic in `plan_time_card_density`).
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_density.dart`
- **When to open:** When behavior tied to `plan_time_card_density.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Re-export stub → `plan_time_task_card/plan_card_density.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_density.dart`.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `plan_time_card_density`).
- **Обязанности:** Реализует в UI: Re-export stub → `plan_time_task_card/plan_card_density.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_time_card_density.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/plan_card/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/plan_time_task_card.dart`

EN:

- **What this is:** Shared design-system widget — Public `PlanTimeTaskCard` widget.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (logic in `plan_time_task_card`).
- **Responsibilities:** Public `PlanTimeTaskCard` widget
- **When to open:** When behavior tied to `plan_time_task_card.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Public `PlanTimeTaskCard` widget
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Public `PlanTimeTaskCard` widget.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `plan_time_task_card`).
- **Обязанности:** Реализует в UI: Public `PlanTimeTaskCard` widget.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_time_task_card.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/plan_time_task_card/plan_card_controls.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_controls.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`PlanCardCheckbox`, `PlanCardCheckboxState`, `PlanCardPlayButton`, `PlanCardPlayButtonState`, `PlanCardPlayIconPainter`, `PlanCardRecurringGlyph`).
- **Key code names:** `PlanCardCheckbox`, `PlanCardCheckboxState`, `PlanCardPlayButton`, `PlanCardPlayButtonState`, `PlanCardPlayIconPainter`, `PlanCardRecurringGlyph`, `PlanCardMenuButton`, `PlanCardMenuButtonState`, `PlanCardMenuIconPainter`, `PlanCardTitleRow`
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_controls.dart`
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Re-export stub → `plan_time_task_card/plan_card_controls.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_controls.dart`.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `plan_card_controls`).
- **Обязанности:** Реализует в UI: Re-export stub → `plan_time_task_card/plan_card_controls.dart`.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/plan_time_task_card/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/plan_time_task_card/plan_card_density.dart`

EN:

- **What this is:** Shared design-system widget — Density bands + measure helpers.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`PlanTimeCardVisualDensity`).
- **Key code names:** `PlanTimeCardVisualDensity`
- **Responsibilities:** Density bands + measure helpers
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Density bands + measure helpers
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Density bands + measure helpers.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `plan_card_density`).
- **Обязанности:** Реализует в UI: Density bands + measure helpers.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/plan_time_task_card/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/plan_time_task_card/plan_card_geometry.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_geometry.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`PlanCardGeom`, `PlanCardTokens`).
- **Key code names:** `PlanCardGeom`, `PlanCardTokens`
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_geometry.dart`
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Re-export stub → `plan_time_task_card/plan_card_geometry.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_geometry.dart`.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `plan_card_geometry`).
- **Обязанности:** Реализует в UI: Re-export stub → `plan_time_task_card/plan_card_geometry.dart`.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/plan_time_task_card/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/plan_time_task_card/plan_card_layouts.dart`

EN:

- **What this is:** Shared design-system widget — Time View CardPlan layout variants.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`TimeViewDensityBody`, `TimeViewCardCommon`, `TimeViewLeftControls`, `TimeViewResponsiveShell`, `TimeViewVerticalShell`, `TimeViewVerySmallLayout`).
- **Key code names:** `TimeViewDensityBody`, `TimeViewCardCommon`, `TimeViewLeftControls`, `TimeViewResponsiveShell`, `TimeViewVerticalShell`, `TimeViewVerySmallLayout`, `TimeViewSmallLayout`, `TimeViewMoreCompactLayout`, `TimeViewTwoRowCenterLayout`
- **Responsibilities:** Time View CardPlan layout variants
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Time View CardPlan layout variants
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Time View CardPlan layout variants.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `plan_card_layouts`).
- **Обязанности:** Реализует в UI: Time View CardPlan layout variants.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/plan_time_task_card/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/plan_time_task_card/plan_card_metrics.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_metrics.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`PlanTimeTaskCardDensity`, `PlanCardSurface`).
- **Key code names:** `PlanTimeTaskCardDensity`, `PlanCardSurface`
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_metrics.dart`
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Re-export stub → `plan_time_task_card/plan_card_metrics.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_metrics.dart`.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `plan_card_metrics`).
- **Обязанности:** Реализует в UI: Re-export stub → `plan_time_task_card/plan_card_metrics.dart`.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/plan_time_task_card/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/plan_time_task_card/plan_card_progress.dart`

EN:

- **What this is:** Shared design-system widget — Progress/invariant card shells.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`PlanCardProgressSlot`, `PlanCardInvariantBody`, `PlanCardRailShell`, `PlanCardProgressRow`).
- **Key code names:** `PlanCardProgressSlot`, `PlanCardInvariantBody`, `PlanCardRailShell`, `PlanCardProgressRow`
- **Responsibilities:** Progress/invariant card shells
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Progress/invariant card shells
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Progress/invariant card shells.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `plan_card_progress`).
- **Обязанности:** Реализует в UI: Progress/invariant card shells.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/plan_time_task_card/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/plan_time_task_card/plan_card_sections.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_sections.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`PlanCardTagsRow`, `PlanCardTimeText`, `PlanCardFooterRow`, `PlanCardWatermark`).
- **Key code names:** `PlanCardTagsRow`, `PlanCardTimeText`, `PlanCardFooterRow`, `PlanCardWatermark`
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_sections.dart`
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Re-export stub → `plan_time_task_card/plan_card_sections.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_sections.dart`.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `plan_card_sections`).
- **Обязанности:** Реализует в UI: Re-export stub → `plan_time_task_card/plan_card_sections.dart`.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/plan_time_task_card/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/plan_time_task_card/plan_card_tags.dart`

EN:

- **What this is:** Shared design-system widget — Time View tag row/stack/pill widgets.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`TimeViewTagsRow`, `TimeViewTagStack`, `TimeViewCompactTagPill`).
- **Key code names:** `TimeViewTagsRow`, `TimeViewTagStack`, `TimeViewCompactTagPill`
- **Responsibilities:** Time View tag row/stack/pill widgets
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Time View tag row/stack/pill widgets
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Time View tag row/stack/pill widgets.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `plan_card_tags`).
- **Обязанности:** Реализует в UI: Time View tag row/stack/pill widgets.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/plan_time_task_card/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/plan_time_task_card/plan_time_task_card.dart`

EN:

- **What this is:** Shared design-system widget — Public `PlanTimeTaskCard` widget.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`PlanTimeTaskCard`, `_PlanTimeTaskCardState`).
- **Key code names:** `PlanTimeTaskCard`, `_PlanTimeTaskCardState`
- **Responsibilities:** Public `PlanTimeTaskCard` widget
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Public `PlanTimeTaskCard` widget
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Public `PlanTimeTaskCard` widget.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `plan_time_task_card`).
- **Обязанности:** Реализует в UI: Public `PlanTimeTaskCard` widget.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/plan_time_task_card/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/tag_display_mode_scope.dart`

EN:

- **What this is:** Shared design-system widget — Tag display mode inherited widget.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`TagDisplayModeScope`).
- **Key code names:** `TagDisplayModeScope`
- **Responsibilities:** Tag display mode inherited widget
- **When to open:** When behavior tied to `tag_display_mode_scope.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Tag display mode inherited widget
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Tag display mode inherited widget.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `tag_display_mode_scope`).
- **Обязанности:** Реализует в UI: Tag display mode inherited widget.
- **Когда открывать:** Когда ломается поведение, связанное с `tag_display_mode_scope.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/core/widgets/timezone_quick_picker.dart`

EN:

- **What this is:** Shared design-system widget — `HeaderTimezoneQuickSwitcher`, profile timezone quick picker.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`HeaderTimezoneQuickSwitcher`, `TimezonePickerField`, `_TimezoneQuickPickerSheet`, `_TimezoneQuickPickerSheetState`, `TimezonePickerOptionRow`, `_TimezoneOptionText`).
- **Key code names:** `HeaderTimezoneQuickSwitcher`, `TimezonePickerField`, `_TimezoneQuickPickerSheet`, `_TimezoneQuickPickerSheetState`, `TimezonePickerOptionRow`, `_TimezoneOptionText`
- **Responsibilities:** `HeaderTimezoneQuickSwitcher`, profile timezone quick picker
- **When to open:** When behavior tied to `timezone_quick_picker.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: `HeaderTimezoneQuickSwitcher`, profile timezone quick picker
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — `HeaderTimezoneQuickSwitcher`, profile timezone quick picker.
- **Зачем:** Один стиль кнопок и карточек на Plans, Timeline и Lists.
- **Содержимое:** Канонический Flutter-виджет (logic in `timezone_quick_picker`).
- **Обязанности:** Реализует в UI: `HeaderTimezoneQuickSwitcher`, profile timezone quick picker.
- **Когда открывать:** Когда ломается поведение, связанное с `timezone_quick_picker.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/core/widgets/`, `docs/APP_STRUCTURE.md`
- **Слой:** Общий UI-виджет design system.


### `lib/data/auth_bridge.dart`

EN:

- **What this is:** Brain support file — Session check, OAuth routing.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`OAuthSignInResult`, `PasswordResetRequestResult`, `AuthBridgeException`, `AuthBridgeCancelled`, `AuthBridge`).
- **Key code names:** `OAuthSignInResult`, `PasswordResetRequestResult`, `AuthBridgeException`, `AuthBridgeCancelled`, `AuthBridge`
- **Responsibilities:** Session check, OAuth routing
- **When to open:** When behavior tied to `auth_bridge.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Session check, OAuth routing
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Вспомогательный модуль brain — Session check, OAuth routing.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (`OAuthSignInResult`, `PasswordResetRequestResult`, `AuthBridgeException`, `AuthBridgeCancelled`, `AuthBridge`).
- **Обязанности:** Реализует в brain: Session check, OAuth routing.
- **Когда открывать:** Когда ломается поведение, связанное с `auth_bridge.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/cache/day_snapshot_window.dart`

EN:

- **What this is:** Brain support file — Rolling warm day snapshots for date paging.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`WarmDayWindowConstants`, `TimelineDaySnapshot`, `PlansDaySnapshot`, `WarmSnapshotWindow`).
- **Key code names:** `WarmDayWindowConstants`, `TimelineDaySnapshot`, `PlansDaySnapshot`, `WarmSnapshotWindow`
- **Responsibilities:** Rolling warm day snapshots for date paging
- **When to open:** When behavior tied to `day_snapshot_window.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Rolling warm day snapshots for date paging
- **Layer / owner:** Brain performance cache — faster date paging.

RU:

- **Что это:** Вспомогательный модуль brain — Rolling warm day snapshots for date paging.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (`WarmDayWindowConstants`, `TimelineDaySnapshot`, `PlansDaySnapshot`, `WarmSnapshotWindow`).
- **Обязанности:** Реализует в brain: Rolling warm day snapshots for date paging.
- **Когда открывать:** Когда ломается поведение, связанное с `day_snapshot_window.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — кэш производительности.


### `lib/data/cache/render_snapshot.dart`

EN:

- **What this is:** Brain support file — Render snapshot helpers for day strips.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`PlanCardRenderDto`, `PlansDayRenderSnapshot`, `TimelineCardRenderDto`, `TimelineDayRenderSnapshot`).
- **Key code names:** `PlanCardRenderDto`, `PlansDayRenderSnapshot`, `TimelineCardRenderDto`, `TimelineDayRenderSnapshot`
- **Responsibilities:** Render snapshot helpers for day strips
- **When to open:** When behavior tied to `render_snapshot.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Render snapshot helpers for day strips
- **Layer / owner:** Brain performance cache — faster date paging.

RU:

- **Что это:** Вспомогательный модуль brain — Render snapshot helpers for day strips.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (`PlanCardRenderDto`, `PlansDayRenderSnapshot`, `TimelineCardRenderDto`, `TimelineDayRenderSnapshot`).
- **Обязанности:** Реализует в brain: Render snapshot helpers for day strips.
- **Когда открывать:** Когда ломается поведение, связанное с `render_snapshot.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — кэш производительности.


### `lib/data/cache/rendered_day_body_cache.dart`

EN:

- **What this is:** Brain support file — Rendered day-body LRU cache.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`RenderedDayBodyConstants`, `TimelineDayBodyEntry`, `PlansDayBodyEntry`).
- **Key code names:** `RenderedDayBodyConstants`, `TimelineDayBodyEntry`, `PlansDayBodyEntry`
- **Responsibilities:** Rendered day-body LRU cache
- **When to open:** When behavior tied to `rendered_day_body_cache.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Rendered day-body LRU cache
- **Layer / owner:** Brain performance cache — faster date paging.

RU:

- **Что это:** Вспомогательный модуль brain — Rendered day-body LRU cache.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (`RenderedDayBodyConstants`, `TimelineDayBodyEntry`, `PlansDayBodyEntry`).
- **Обязанности:** Реализует в brain: Rendered day-body LRU cache.
- **Когда открывать:** Когда ломается поведение, связанное с `rendered_day_body_cache.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — кэш производительности.


### `lib/data/categories/category_cache_helpers.dart`

EN:

- **What this is:** Loads your category list from PocketBase and refreshes the in-memory category tree after sync.
- **Why needed:** Every screen that shows a category name, color, or picker needs an up-to-date list for the signed-in user.
- **What it contains:** Fetch/filter code for `categories` rows plus reload hooks used after edits.
- **Key code names:** `CategoryCacheExtension`
- **Responsibilities:** Download categories; rebuild local rules; handle backoff when PocketBase is unreachable.
- **When to open:** Categories missing after login, stale tree after edit, or empty picker when server has data.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Category manager UI, record start category, plan cards, `category_service.dart`.
- **Layer / owner:** Brain — `part` of `database_service.dart` (cache/load).

RU:

- **Что это:** Вспомогательный модуль brain — Download categories.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** HTTP-загрузка категорий и пересборка локальных правил.
- **Обязанности:** Реализует в brain: Download categories; rebuild local rules; handle backoff when PocketBase is unreachable..
- **Когда открывать:** Категории не появляются или не обновляются после правок.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Экран категорий, старт записи, карточки планов.
- **Слой:** Brain — часть `database_service.dart`.


### `lib/data/categories/category_crud.dart`

EN:

- **What this is:** Creates, renames, archives, restores, and reorders categories on the server and in local cache.
- **Why needed:** Category manager screen edits must persist to PocketBase and immediately update what Timeline/Plans show.
- **What it contains:** POST/PATCH payloads for `categories` collection, order fields, archive flags.
- **Key code names:** `CategoryCrudExtension`
- **Responsibilities:** Add nested category; update color/icon/name; archive/restore; write sibling order.
- **When to open:** Category save fails, archive doesn’t stick, drag-reorder not persisted.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** `lib/features/categories/`, category manager sheets.
- **Layer / owner:** Brain — `part` of `database_service.dart` (network writes).

RU:

- **Что это:** Вспомогательный модуль brain — Add nested category.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** POST/PATCH для коллекции categories.
- **Обязанности:** Реализует в brain: Add nested category; update color/icon/name; archive/restore; write sibling order..
- **Когда открывать:** Категория не сохраняется или не архивируется.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI категорий.
- **Слой:** Brain — часть `database_service.dart`.


### `lib/data/categories/category_default_time.dart`

EN:

- **What this is:** Stores and applies each category’s default plan start time (e.g. Gym → 19:00).
- **Why needed:** Creating a plan under a category should pre-fill sensible time without manual picking every time.
- **What it contains:** Validation for HH:MM, timezone option per category, inheritance when creating plans.
- **Key code names:** `CategoryDefaultTimeExtension`
- **Responsibilities:** Read/write `default_plan_time` fields; apply to new plan drafts; show short TZ label.
- **When to open:** Default time not applied on new plan, wrong timezone on category default, Time View search.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plan create/edit sheets, Time View settings, category editor.
- **Layer / owner:** Brain — `part` of `database_service.dart` (category schedule defaults).

RU:

- **Что это:** Вспомогательный модуль brain — Read/write `default_plan_time` fields.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Валидация времени и timezone для категории.
- **Обязанности:** Реализует в brain: Read/write `default_plan_time` fields; apply to new plan drafts; show short TZ label..
- **Когда открывать:** Время по умолчанию не подставляется в новый план.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Создание/редактирование планов, Time View.
- **Слой:** Brain — часть `database_service.dart`.


### `lib/data/categories/category_lookup.dart`

EN:

- **What this is:** Finds the best matching category when the user types, speaks, or only provides a partial name.
- **Why needed:** Voice commands and smart input must map “Price Reporter Planning” to the right category without creating duplicates.
- **What it contains:** Fuzzy word match, deepest-match scoring, business-id ↔ PocketBase id resolution.
- **Key code names:** `CategoryLookupExtension`
- **Responsibilities:** Score titles against category names; pick deepest match; map legacy ids for saves.
- **When to open:** Voice picks wrong client, plan/record category wrong from title, fuzzy match too aggressive.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Voice parser, smart plan input, record start, category pickers.
- **Layer / owner:** Brain — `part` of `database_service.dart` (search/match).

RU:

- **Что это:** Вспомогательный модуль brain — Score titles against category names.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Fuzzy-match, scoring, сопоставление id.
- **Обязанности:** Реализует в brain: Score titles against category names; pick deepest match; map legacy ids for saves..
- **Когда открывать:** Голос или автоподбор выбрал не ту категорию.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Голос, smart input, picker.
- **Слой:** Brain — часть `database_service.dart`.


### `lib/data/categories/category_record_bridge.dart`

EN:

- **What this is:** Connects timeline records to the correct PocketBase category row when saving or fixing bad links.
- **Why needed:** Records must store the 15-char PocketBase category id, not a stale UUID or wrong slug — or saves fail silently.
- **What it contains:** REST id resolution, record/category relation repair, ghost record cleanup hooks.
- **Key code names:** `CategoryRecordBridgeExtension`
- **Responsibilities:** Translate record id for PATCH; map category_link fields; purge dead cache rows.
- **When to open:** Record saves without category, stop/delete uses wrong id, 404 cleanup needed.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Record start/stop, edit sheet category field, PocketBase `records` hooks.
- **Layer / owner:** Brain — `part` of `database_service.dart` (record↔category bridge).

RU:

- **Что это:** Вспомогательный модуль brain — Translate record id for PATCH.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Разрешение REST id, починка relation полей.
- **Обязанности:** Реализует в brain: Translate record id for PATCH; map category_link fields; purge dead cache rows..
- **Когда открывать:** Запись без категории или ошибка stop/delete по id.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Timeline, edit sheet, hooks на сервере.
- **Слой:** Brain — часть `database_service.dart`.


### `lib/data/categories/category_stats.dart`

EN:

- **What this is:** Adds up time spent per category (including child categories) for stats views.
- **Why needed:** Stats tab shows hours per category; must include entire subtree, not only direct records.
- **What it contains:** Duration rollups filtered by category id set from subtree walk.
- **Key code names:** `CategoryStatsExtension`
- **Responsibilities:** Filter records by category subtree; sum seconds for day or range.
- **When to open:** Stats totals wrong for parent category, missing child hours.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** `lib/features/stats/`, Timeline stats tab.
- **Layer / owner:** Brain — `part` of `database_service.dart` (read-only aggregation).

RU:

- **Что это:** Вспомогательный модуль brain — Filter records by category subtree.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Суммирование секунд по id поддерева.
- **Обязанности:** Реализует в brain: Filter records by category subtree; sum seconds for day or range..
- **Когда открывать:** Неверные часы в статистике по категории.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Stats во Timeline.
- **Слой:** Brain — часть `database_service.dart`.


### `lib/data/categories/category_tree.dart`

EN:

- **What this is:** Builds the parent/child category tree and answers “path from root” questions.
- **Why needed:** Categories are nested (clients under Price Reporter, etc.); the app must walk the tree for pickers and stats.
- **What it contains:** Tree walk/sort helpers, `CategoryRule` hierarchy operations, subtree id lists.
- **Key code names:** `CategoryTreeExtension`
- **Responsibilities:** Sort siblings; find node by PocketBase id; list all record ids under a branch.
- **When to open:** Wrong order in category list, breadcrumb path wrong, stats include wrong subtree.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Category tree picker, stats aggregation, voice category path.
- **Layer / owner:** Brain — `part` of `database_service.dart` (tree structure).

RU:

- **Что это:** Вспомогательный модуль brain — Sort siblings.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Обход дерева, сортировка, поиск узла по id.
- **Обязанности:** Реализует в brain: Sort siblings; find node by PocketBase id; list all record ids under a branch..
- **Когда открывать:** Неверный порядок или путь категории в UI.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Picker категорий, статистика.
- **Слой:** Brain — часть `database_service.dart`.


### `lib/data/category_fuzzy_match.dart`

EN:

- **What this is:** Brain support file — Category name scoring.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (logic in `category_fuzzy_match`).
- **Responsibilities:** Category name scoring
- **When to open:** When behavior tied to `category_fuzzy_match.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Category name scoring
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Вспомогательный модуль brain — Category name scoring.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (logic in `category_fuzzy_match`).
- **Обязанности:** Реализует в brain: Category name scoring.
- **Когда открывать:** Когда ломается поведение, связанное с `category_fuzzy_match.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/category_service.dart`

EN:

- **What this is:** Main coordinator for categories (tree, colors, matching) inside the brain.
- **Why needed:** UI calls one category entry point; this file delegates to focused modules in the subfolder.
- **What it contains:** Coordinator extensions plus links to `part` files under `categorys/` or `category/`.
- **Key code names:** `CategoryServiceExtension`
- **Responsibilities:** Category coordinator: flatten/PB bridge statics, stats duration helpers, local task prefs helpers
- **When to open:** When behavior tied to `category_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Category coordinator: flatten/PB bridge statics, stats duration helpers, local task prefs helpers
- **Layer / owner:** Brain coordinator — entry point for this domain inside `database_service.dart`.

RU:

- **Что это:** Главный координатор для categories (tree, colors, matching).
- **Зачем:** UI вызывает один вход; детали — в модулях subfolder.
- **Содержимое:** Extensions + `part` файлы для category.
- **Обязанности:** Координатор домена: Category coordinator: flatten/PB bridge statics, stats duration helpers, local task prefs helpers.
- **Когда открывать:** Когда ломается поведение, связанное с `category_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — координатор домена.


### `lib/data/database_service.dart`

EN:

- **What this is:** The single “brain” front door — one place all screens ask for data and saves.
- **Why needed:** Timeline, Plans, Lists, and Categories share one singleton so PocketBase rules stay consistent.
- **What it contains:** Shared streams, caches, and `part` declarations for records, plans, categories, profile.
- **Key code names:** `_BuildNode`, `_OptimisticEndPatch`, `LegacyIdResolutionException`, `AuthenticatedUserIdRequiredException`, `AiBackendException`, `_DatabaseServiceLifecycleObserver`, `_HighlanderRollbackToken`, `DatabaseService`
- **Responsibilities:** Host extensions; route work to `record_service`, `plan_service`, etc.
- **When to open:** When behavior tied to `database_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Singleton root: shared state, streams, static helpers
- **Layer / owner:** Brain coordinator — entry point for this domain inside `database_service.dart`.

RU:

- **Что это:** Единая «мозговая» точка входа — все экраны обращаются сюда за данными.
- **Зачем:** Один singleton держит правила PocketBase для всех вкладок.
- **Содержимое:** Потоки, кэш, объявления `part` для records/plans/categories/profile.
- **Обязанности:** Маршрутизация к domain-файлам brain.
- **Когда открывать:** Когда ломается поведение, связанное с `database_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — координатор домена.


### `lib/data/db_core.dart`

EN:

- **What this is:** Brain support file — Bootstrap: `loadInitialData`, PocketBase health, lifecycle, flush outboxes.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`DbCoreExtension`).
- **Key code names:** `DbCoreExtension`
- **Responsibilities:** Bootstrap: `loadInitialData`, PocketBase health, lifecycle, flush outboxes
- **When to open:** When behavior tied to `db_core.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Bootstrap: `loadInitialData`, PocketBase health, lifecycle, flush outboxes
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Вспомогательный модуль brain — Bootstrap: `loadInitialData`, PocketBase health, lifecycle, flush outboxes.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (`DbCoreExtension`).
- **Обязанности:** Реализует в brain: Bootstrap: `loadInitialData`, PocketBase health, lifecycle, flush outboxes.
- **Когда открывать:** Когда ломается поведение, связанное с `db_core.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/local_sync/offline_sync_state.dart`

EN:

- **What this is:** Tracks pending sync count and “auth paused” for the top banner.
- **Why needed:** Users see how many changes wait to upload; tap banner to retry.
- **What it contains:** `OfflineSyncController`: pendingCount, isSyncing, authPaused.
- **Key code names:** `OfflineSyncController`
- **Responsibilities:** Pending count, syncing, auth-paused UI state
- **When to open:** When behavior tied to `offline_sync_state.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Offline banner in shell, reconnect flush; APP_STRUCTURE role: Pending count, syncing, auth-paused UI state
- **Layer / owner:** Brain offline queue / sync state.

RU:

- **Что это:** Модуль brain для offline sync — файл `offline_sync_state`.
- **Зачем:** Держит offline sync согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`OfflineSyncController`).
- **Обязанности:** Реализует в коде: Pending count, syncing, auth-paused UI state.
- **Когда открывать:** Когда ломается поведение, связанное с `offline_sync_state.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Offline banner в shell, flush при reconnect
- **Слой:** Brain — офлайн-очередь.


### `lib/data/local_sync/plan_create_outbox.dart`

EN:

- **What this is:** Legacy re-export file — points importers to `plan_mutation_outbox.dart`.
- **Why needed:** Older code imported this name; kept so imports do not break.
- **What it contains:** Single export line only — no logic.
- **Responsibilities:** Re-export of `plan_mutation_outbox.dart`
- **When to open:** When behavior tied to `plan_create_outbox.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Offline banner in shell, reconnect flush; APP_STRUCTURE role: Re-export of `plan_mutation_outbox.dart`
- **Layer / owner:** Brain offline queue / sync state.

RU:

- **Что это:** Модуль brain для offline sync — файл `plan_create_outbox`.
- **Зачем:** Держит offline sync согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (logic in `plan_create_outbox`).
- **Обязанности:** Реализует в коде: Re-export of `plan_mutation_outbox.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_create_outbox.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Offline banner в shell, flush при reconnect
- **Слой:** Brain — офлайн-очередь.


### `lib/data/local_sync/plan_mutation_outbox.dart`

EN:

- **What this is:** Remembers plan/list create/update/delete when offline.
- **Why needed:** List checkbox and plan edits queue here until reconnect.
- **What it contains:** SharedPreferences queue for plan mutations.
- **Key code names:** `PlanMutationOutbox`
- **Responsibilities:** Offline queue: plan/list create/update/delete
- **When to open:** When behavior tied to `plan_mutation_outbox.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Offline banner in shell, reconnect flush; APP_STRUCTURE role: Offline queue: plan/list create/update/delete
- **Layer / owner:** Brain offline queue / sync state.

RU:

- **Что это:** Модуль brain для offline sync — файл `plan_mutation_outbox`.
- **Зачем:** Держит offline sync согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`PlanMutationOutbox`).
- **Обязанности:** Реализует в коде: Offline queue: plan/list create/update/delete.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_mutation_outbox.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Offline banner в shell, flush при reconnect
- **Слой:** Brain — офлайн-очередь.


### `lib/data/local_sync/record_mutation_outbox.dart`

EN:

- **What this is:** Remembers record start/stop/edit/delete when the network fails.
- **Why needed:** Offline-first law: tap must succeed locally even on airplane mode.
- **What it contains:** SharedPreferences queue for record mutations; coalesces duplicate ops.
- **Key code names:** `RecordMutationOutbox`
- **Responsibilities:** Offline queue: record start/stop/update/delete
- **When to open:** When behavior tied to `record_mutation_outbox.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Offline banner in shell, reconnect flush; APP_STRUCTURE role: Offline queue: record start/stop/update/delete
- **Layer / owner:** Brain offline queue / sync state.

RU:

- **Что это:** Модуль brain для offline sync — файл `record_mutation_outbox`.
- **Зачем:** Держит offline sync согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`RecordMutationOutbox`).
- **Обязанности:** Реализует в коде: Offline queue: record start/stop/update/delete.
- **Когда открывать:** Когда ломается поведение, связанное с `record_mutation_outbox.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Offline banner в shell, flush при reconnect
- **Слой:** Brain — офлайн-очередь.


### `lib/data/local_sync/sync_manager.dart`

EN:

- **What this is:** Watches network connectivity and triggers queue flush on reconnect.
- **Why needed:** When Wi‑Fi returns, pending offline changes should upload automatically.
- **What it contains:** Connectivity listener → `flushPendingLocalMutations`.
- **Key code names:** `SyncManager`
- **Responsibilities:** Connectivity / resume → flush trigger
- **When to open:** When behavior tied to `sync_manager.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Offline banner in shell, reconnect flush; APP_STRUCTURE role: Connectivity / resume → flush trigger
- **Layer / owner:** Brain offline queue / sync state.

RU:

- **Что это:** Модуль brain для offline sync — файл `sync_manager`.
- **Зачем:** Держит offline sync согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`SyncManager`).
- **Обязанности:** Реализует в коде: Connectivity / resume → flush trigger.
- **Когда открывать:** Когда ломается поведение, связанное с `sync_manager.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Offline banner в shell, flush при reconnect
- **Слой:** Brain — офлайн-очередь.


### `lib/data/models.dart`

EN:

- **What this is:** Barrel file that declares all data model `part` files in one place.
- **Why needed:** Other code imports `models.dart` once to get `TimelineRecord`, `PlanningTask`, etc.
- **What it contains:** `part` directives only — no logic.
- **Responsibilities:** Export surface for model types listed in `docs/DATA_MAP.md`.
- **When to open:** When behavior tied to `models.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: `part` declarations
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Собирает все model `part` в одном import.
- **Зачем:** Один import для всех типов данных.
- **Содержимое:** Только `part` директивы.
- **Обязанности:** Экспорт моделей.
- **Когда открывать:** Когда ломается поведение, связанное с `models.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Модели данных — без HTTP.


### `lib/data/models/_shared.dart`

EN:

- **What this is:** Shared helper functions used by multiple data model classes.
- **Why needed:** Avoids duplicating date/id parsing across record, plan, and category models.
- **What it contains:** Small pure helpers — no PocketBase calls.
- **Key code names:** `CategoryDisplayMode`, `CategoryDisplayModeWire`
- **Responsibilities:** Shared model helpers
- **When to open:** When behavior tied to `_shared.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Shared model helpers
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Модуль brain для data models — файл `_shared`.
- **Зачем:** Держит data models согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`CategoryDisplayMode`, `CategoryDisplayModeWire`).
- **Обязанности:** Реализует в коде: Shared model helpers.
- **Когда открывать:** Когда ломается поведение, связанное с `_shared.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Модели данных — без HTTP.


### `lib/data/models/category.dart`

EN:

- **What this is:** Defines `CategoryRule` — name, color, icon, parent, PocketBase ids.
- **Why needed:** Category picker and manager display this shape.
- **What it contains:** `CategoryRule` with stable hash for category business id.
- **Key code names:** `Category`, `CategoryNameInputKind`, `CategoryNameInputStatus`, `CategoryRule`
- **Responsibilities:** `CategoryRule`
- **When to open:** When behavior tied to `category.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: `CategoryRule`
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Модуль brain для data models — файл `category`.
- **Зачем:** Держит data models согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`Category`, `CategoryNameInputKind`, `CategoryNameInputStatus`, `CategoryRule`).
- **Обязанности:** Реализует в коде: `CategoryRule`.
- **Когда открывать:** Когда ломается поведение, связанное с `category.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Модели данных — без HTTP.


### `lib/data/models/planning.dart`

EN:

- **What this is:** Defines `PlanningTask` — scheduled plans and backlog list rows.
- **Why needed:** Plans tab, Lists tab, and Time View cards use this shape.
- **What it contains:** Plan fields: time, done flag, recurrence, tags.
- **Key code names:** `AiParsedTaskHint`, `SourcePlanLinkSuggestion`, `PlanDayOverloadReport`, `PlanningTask`
- **Responsibilities:** `PlanningTask`
- **When to open:** When behavior tied to `planning.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: `PlanningTask`
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Модуль brain для data models — файл `planning`.
- **Зачем:** Держит data models согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`AiParsedTaskHint`, `SourcePlanLinkSuggestion`, `PlanDayOverloadReport`, `PlanningTask`).
- **Обязанности:** Реализует в коде: `PlanningTask`.
- **Когда открывать:** Когда ломается поведение, связанное с `planning.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Модели данных — без HTTP.


### `lib/data/models/profile.dart`

EN:

- **What this is:** Defines the shape of user settings (`UserSettings`) — timezone, language, admin flag.
- **Why needed:** UI and brain must agree on field names from `docs/DATA_MAP.md`.
- **What it contains:** `UserSettings` class and profile field parsers.
- **Key code names:** `Profile`, `UserProfile`, `ProfileUpdate`, `TagCatalogScope`, `TagCatalogScopeMatch`, `UserSettings`
- **Responsibilities:** `UserSettings`, profile fields
- **When to open:** When behavior tied to `profile.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; APP_STRUCTURE role: `UserSettings`, profile fields
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Модуль brain для data models — файл `profile`.
- **Зачем:** Держит data models согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`Profile`, `UserProfile`, `ProfileUpdate`, `TagCatalogScope`, `TagCatalogScopeMatch`, `UserSettings`).
- **Обязанности:** Реализует в коде: `UserSettings`, profile fields.
- **Когда открывать:** Когда ломается поведение, связанное с `profile.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Profile, tag manager, timezone в header
- **Слой:** Модели данных — без HTTP.


### `lib/data/models/record.dart`

EN:

- **What this is:** Defines `TimelineRecord` — start/stop times, status, category, date key.
- **Why needed:** Every Timeline card is a `TimelineRecord` instance.
- **What it contains:** UTC storage, profile-timezone date key bucketing.
- **Key code names:** `Record`, `TimelineRecord`
- **Responsibilities:** `TimelineRecord`
- **When to open:** When behavior tied to `record.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: `TimelineRecord`
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Модуль brain для data models — файл `record`.
- **Зачем:** Держит data models согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`Record`, `TimelineRecord`).
- **Обязанности:** Реализует в коде: `TimelineRecord`.
- **Когда открывать:** Когда ломается поведение, связанное с `record.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Модели данных — без HTTP.


### `lib/data/models/stats.dart`

EN:

- **What this is:** Defines aggregated stats numbers for Timeline stats tab.
- **Why needed:** Stats views sum records without re-parsing raw JSON each frame.
- **What it contains:** Stats aggregate structs.
- **Key code names:** `BasicDayStats`, `StatsTreeNode`, `SessionGroup`, `StatsNode`
- **Responsibilities:** Stats aggregates
- **When to open:** When behavior tied to `stats.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Stats aggregates
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Модуль brain для data models — файл `stats`.
- **Зачем:** Держит data models согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`BasicDayStats`, `StatsTreeNode`, `SessionGroup`, `StatsNode`).
- **Обязанности:** Реализует в коде: Stats aggregates.
- **Когда открывать:** Когда ломается поведение, связанное с `stats.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Модели данных — без HTTP.


### `lib/data/models/tag.dart`

EN:

- **What this is:** Defines `Tag` and `TagCatalogScope` for plan vs list tag domains.
- **Why needed:** Tag manager and chip strips use these types.
- **What it contains:** Tag name, color, default duration minutes.
- **Key code names:** `Tag`
- **Responsibilities:** `Tag`, `TagCatalogScope`
- **When to open:** When behavior tied to `tag.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: `Tag`, `TagCatalogScope`
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Модуль brain для data models — файл `tag`.
- **Зачем:** Держит data models согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`Tag`).
- **Обязанности:** Реализует в коде: `Tag`, `TagCatalogScope`.
- **Когда открывать:** Когда ломается поведение, связанное с `tag.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Модели данных — без HTTP.


### `lib/data/pb_config.dart`

EN:

- **What this is:** Brain support file — PocketBase URL, collection names, expand constants.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`PbAppApiRoutes`, `PbCollections`, `PbOauthProviderNames`).
- **Key code names:** `PbAppApiRoutes`, `PbCollections`, `PbOauthProviderNames`
- **Responsibilities:** PocketBase URL, collection names, expand constants
- **When to open:** When behavior tied to `pb_config.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: PocketBase URL, collection names, expand constants
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Вспомогательный модуль brain — PocketBase URL, collection names, expand constants.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (`PbAppApiRoutes`, `PbCollections`, `PbOauthProviderNames`).
- **Обязанности:** Реализует в brain: PocketBase URL, collection names, expand constants.
- **Когда открывать:** Когда ломается поведение, связанное с `pb_config.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/plan_service.dart`

EN:

- **What this is:** Main coordinator for plans and backlog lists inside the brain.
- **Why needed:** UI calls one plan entry point; this file delegates to focused modules in the subfolder.
- **What it contains:** Coordinator extensions plus links to `part` files under `plans/` or `plan/`.
- **Key code names:** `PlanServiceExtension`
- **Responsibilities:** Plans/lists coordinator: CRUD, streams, wall-time projection, alarms, AI parse
- **When to open:** When behavior tied to `plan_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Plans/lists coordinator: CRUD, streams, wall-time projection, alarms, AI parse
- **Layer / owner:** Brain coordinator — entry point for this domain inside `database_service.dart`.

RU:

- **Что это:** Главный координатор для plans and backlog lists.
- **Зачем:** UI вызывает один вход; детали — в модулях subfolder.
- **Содержимое:** Extensions + `part` файлы для plan.
- **Обязанности:** Координатор домена: Plans/lists coordinator: CRUD, streams, wall-time projection, alarms, AI parse.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — координатор домена.


### `lib/data/plan_time_sequential_cascade.dart`

EN:

- **What this is:** Brain support file — Plan time sequential layout math + `computeTimeViewInsertionCascade`.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`PlanTimeSequentialCascadePatch`, `TimeViewTargetDropSchedule`, `TimeViewInsertPosition`, `TimeViewInsertionSource`, `TimeViewInsertionIntent`, `TimeViewCardLayout`).
- **Key code names:** `PlanTimeSequentialCascadePatch`, `TimeViewTargetDropSchedule`, `TimeViewInsertPosition`, `TimeViewInsertionSource`, `TimeViewInsertionIntent`, `TimeViewCardLayout`, `TimeViewDropIntentKind`, `TimeViewDropIntent`
- **Responsibilities:** Plan time sequential layout math + `computeTimeViewInsertionCascade`
- **When to open:** When behavior tied to `plan_time_sequential_cascade.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Plan time sequential layout math + `computeTimeViewInsertionCascade`
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Вспомогательный модуль brain — Plan time sequential layout math + `computeTimeViewInsertionCascade`.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (`PlanTimeSequentialCascadePatch`, `TimeViewTargetDropSchedule`, `TimeViewInsertPosition`, `TimeViewInsertionSource`, `TimeViewInsertionIntent`, `TimeViewCardLayout`).
- **Обязанности:** Реализует в brain: Plan time sequential layout math + `computeTimeViewInsertionCascade`.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_time_sequential_cascade.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/plans/plan_cache_helpers.dart`

EN:

- **What this is:** Maintains the local plan list clean and scores title similarity for smart linking.
- **Why needed:** Duplicate plan rows or bad merges would break Planning and Lists tabs.
- **What it contains:** Plan dedupe/scrub, title link scoring heuristics.
- **Key code names:** `PlanCacheProjectionExtension`
- **Responsibilities:** Plan dedupe/scrub, title link scoring heuristics
- **When to open:** Plan/list save, Time View layout, recurrence, tags on plans, offline queue.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Plans tab, Lists tab, Time View; APP_STRUCTURE role: Plan dedupe/scrub, title link scoring heuristics
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для plans and lists — файл `plan_cache_helpers`.
- **Зачем:** Держит plans and lists согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`PlanCacheProjectionExtension`).
- **Обязанности:** Реализует в коде: Plan dedupe/scrub, title link scoring heuristics.
- **Когда открывать:** Планы/списки: сохранение, Time View, повтор, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Plans, Lists, Time View
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/plans/plan_outbox_helpers.dart`

EN:

- **What this is:** Queues plan/list edits when offline and flushes when connection returns.
- **Why needed:** Checking off a list item offline must stick and sync later.
- **What it contains:** Plan mutation outbox enqueue/flush/replay.
- **Key code names:** `PlanOutboxSyncExtension`
- **Responsibilities:** Plan mutation outbox enqueue/flush/replay
- **When to open:** Plan/list save, Time View layout, recurrence, tags on plans, offline queue.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Plans tab, Lists tab, Time View; APP_STRUCTURE role: Plan mutation outbox enqueue/flush/replay
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для plans and lists — файл `plan_outbox_helpers`.
- **Зачем:** Держит plans and lists согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`PlanOutboxSyncExtension`).
- **Обязанности:** Реализует в коде: Plan mutation outbox enqueue/flush/replay.
- **Когда открывать:** Планы/списки: сохранение, Time View, повтор, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Plans, Lists, Time View
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/plans/plan_projection_types.dart`

EN:

- **What this is:** Data shapes for how a plan looks on the clock in Time View.
- **Why needed:** Time View needs projected start/end times separate from raw PocketBase fields.
- **What it contains:** `TimeModeProjectedPlan`, timezone-aware projection types.
- **Key code names:** `TimeModeProjectedPlan`, `PlanTimeModeProjection`
- **Responsibilities:** `TimeModeProjectedPlan`, `PlanTimeModeProjection`
- **When to open:** Plan/list save, Time View layout, recurrence, tags on plans, offline queue.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Plans tab, Lists tab, Time View; APP_STRUCTURE role: `TimeModeProjectedPlan`, `PlanTimeModeProjection`
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для plans and lists — файл `plan_projection_types`.
- **Зачем:** Держит plans and lists согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`TimeModeProjectedPlan`, `PlanTimeModeProjection`).
- **Обязанности:** Реализует в коде: `TimeModeProjectedPlan`, `PlanTimeModeProjection`.
- **Когда открывать:** Планы/списки: сохранение, Time View, повтор, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Plans, Lists, Time View
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/plans/plan_recurrence_helpers.dart`

EN:

- **What this is:** Expands repeating plans (daily/weekly RRULE) into visible day rows.
- **Why needed:** A single recurring gym plan must appear on every matching calendar day.
- **What it contains:** RRULE JIT expansion, exception dates, virtual occurrence handling.
- **Key code names:** `PlanRecurrenceExtension`
- **Responsibilities:** RRULE JIT expansion, exception-date parse helpers
- **When to open:** Plan/list save, Time View layout, recurrence, tags on plans, offline queue.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Plans tab, Lists tab, Time View; APP_STRUCTURE role: RRULE JIT expansion, exception-date parse helpers
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для plans and lists — файл `plan_recurrence_helpers`.
- **Зачем:** Держит plans and lists согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`PlanRecurrenceExtension`).
- **Обязанности:** Реализует в коде: RRULE JIT expansion, exception-date parse helpers.
- **Когда открывать:** Планы/списки: сохранение, Time View, повтор, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Plans, Lists, Time View
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/plans/plan_tags_helpers.dart`

EN:

- **What this is:** Syncs tag chips on plan cards with PocketBase `tags_link` relations.
- **Why needed:** Plan tags must save to the server and show the same on Lists and Plans.
- **What it contains:** Tag catalog fetch, PB link sync for plans/lists.
- **Key code names:** `PlanTagsExtension`
- **Responsibilities:** Plan/list tag catalog fetch + PB `tags_link` sync
- **When to open:** Plan/list save, Time View layout, recurrence, tags on plans, offline queue.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Plans tab, Lists tab, Time View; APP_STRUCTURE role: Plan/list tag catalog fetch + PB `tags_link` sync
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для plans and lists — файл `plan_tags_helpers`.
- **Зачем:** Держит plans and lists согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`PlanTagsExtension`).
- **Обязанности:** Реализует в коде: Plan/list tag catalog fetch + PB `tags_link` sync.
- **Когда открывать:** Планы/списки: сохранение, Time View, повтор, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Plans, Lists, Time View
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/plans/plan_time_cascade_helpers.dart`

EN:

- **What this is:** Calculates where plan blocks sit vertically in Time View when times overlap.
- **Why needed:** Without cascade math, overlapping plans would draw on top of each other.
- **What it contains:** Time View cascade layout, duration constants, wall-time estimates.
- **Key code names:** `PlanTimeCascadeExtension`
- **Responsibilities:** Time View cascade, duration consts, `planningWallEstimateSeconds`
- **When to open:** Plan/list save, Time View layout, recurrence, tags on plans, offline queue.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Plans tab, Lists tab, Time View; APP_STRUCTURE role: Time View cascade, duration consts, `planningWallEstimateSeconds`
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для plans and lists — файл `plan_time_cascade_helpers`.
- **Зачем:** Держит plans and lists согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`PlanTimeCascadeExtension`).
- **Обязанности:** Реализует в коде: Time View cascade, duration consts, `planningWallEstimateSeconds`.
- **Когда открывать:** Планы/списки: сохранение, Time View, повтор, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Plans, Lists, Time View
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/price_reporter_client_match.dart`

EN:

- **What this is:** Brain support file — Price Reporter client-category token guard for voice parse.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`PriceReporterAliasEntry`, `PriceReporterClientMatchResult`, `PriceReporterCategoryNode`, `PriceReporterClientIndex`).
- **Key code names:** `PriceReporterAliasEntry`, `PriceReporterClientMatchResult`, `PriceReporterCategoryNode`, `PriceReporterClientIndex`
- **Responsibilities:** Price Reporter client-category token guard for voice parse
- **When to open:** When behavior tied to `price_reporter_client_match.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Price Reporter client-category token guard for voice parse
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Вспомогательный модуль brain — Price Reporter client-category token guard for voice parse.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (`PriceReporterAliasEntry`, `PriceReporterClientMatchResult`, `PriceReporterCategoryNode`, `PriceReporterClientIndex`).
- **Обязанности:** Реализует в brain: Price Reporter client-category token guard for voice parse.
- **Когда открывать:** Когда ломается поведение, связанное с `price_reporter_client_match.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/profile/profile_admin.dart`

EN:

- **What this is:** Reads whether your account is admin (Component Lab gate).
- **Why needed:** Only admins see More → Dev / Design Lab.
- **What it contains:** Parses `profiles.is_admin` during hydration — never written by normal UI.
- **Responsibilities:** Admin bool parse helper for hydration
- **When to open:** Profile settings, timezone, tags catalog, tag display prefs.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; APP_STRUCTURE role: Admin bool parse helper for hydration
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для profile and tags — файл `profile_admin`.
- **Зачем:** Держит profile and tags согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (logic in `profile_admin`).
- **Обязанности:** Реализует в коде: Admin bool parse helper for hydration.
- **Когда открывать:** Профиль, timezone, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Profile, tag manager, timezone в header
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/profile/profile_cache_helpers.dart`

EN:

- **What this is:** Mirrors profile settings to device storage for faster next launch.
- **Why needed:** Reduces flicker on cold start before PocketBase responds.
- **What it contains:** SharedPreferences mirror/hydrate for profile settings.
- **Key code names:** `ProfileCacheExtension`
- **Responsibilities:** Device prefs mirror/hydrate for profile settings
- **When to open:** Profile settings, timezone, tags catalog, tag display prefs.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; APP_STRUCTURE role: Device prefs mirror/hydrate for profile settings
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для profile and tags — файл `profile_cache_helpers`.
- **Зачем:** Держит profile and tags согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`ProfileCacheExtension`).
- **Обязанности:** Реализует в коде: Device prefs mirror/hydrate for profile settings.
- **Когда открывать:** Профиль, timezone, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Profile, tag manager, timezone в header
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/profile/profile_hydration.dart`

EN:

- **What this is:** Downloads your profile from PocketBase when the app starts or after login.
- **Why needed:** Timezone, language, and tag settings cannot render until profile loads.
- **What it contains:** Profile fetch lifecycle, PB map apply, retry on failure.
- **Key code names:** `ProfileHydrationExtension`
- **Responsibilities:** Profile fetch/hydration lifecycle, PB map apply, retry
- **When to open:** Profile settings, timezone, tags catalog, tag display prefs.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; APP_STRUCTURE role: Profile fetch/hydration lifecycle, PB map apply, retry
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для profile and tags — файл `profile_hydration`.
- **Зачем:** Держит profile and tags согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`ProfileHydrationExtension`).
- **Обязанности:** Реализует в коде: Profile fetch/hydration lifecycle, PB map apply, retry.
- **Когда открывать:** Профиль, timezone, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Profile, tag manager, timezone в header
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/profile/profile_preferences.dart`

EN:

- **What this is:** Reloads data region when profile preferences change.
- **Why needed:** Some settings require refreshing cached lists after save.
- **What it contains:** Data region reload hook after preference change.
- **Key code names:** `ProfilePreferencesExtension`
- **Responsibilities:** Data region reload hook
- **When to open:** Profile settings, timezone, tags catalog, tag display prefs.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; APP_STRUCTURE role: Data region reload hook
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для profile and tags — файл `profile_preferences`.
- **Зачем:** Держит profile and tags согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`ProfilePreferencesExtension`).
- **Обязанности:** Реализует в коде: Data region reload hook.
- **Когда открывать:** Профиль, timezone, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Profile, tag manager, timezone в header
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/profile/profile_settings.dart`

EN:

- **What this is:** Saves profile preference changes back to PocketBase.
- **Why needed:** Settings toggles in Profile must persist for the signed-in user only.
- **What it contains:** Profile PATCH, diff fields, locale sync after save.
- **Key code names:** `ProfileSettingsExtension`
- **Responsibilities:** Profile PATCH/save, diff fields, locale sync
- **When to open:** Profile settings, timezone, tags catalog, tag display prefs.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; APP_STRUCTURE role: Profile PATCH/save, diff fields, locale sync
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для profile and tags — файл `profile_settings`.
- **Зачем:** Держит profile and tags согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`ProfileSettingsExtension`).
- **Обязанности:** Реализует в коде: Profile PATCH/save, diff fields, locale sync.
- **Когда открывать:** Профиль, timezone, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Profile, tag manager, timezone в header
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/profile/profile_timezone.dart`

EN:

- **What this is:** Calculates “today” and wall-clock labels using your profile timezone.
- **Why needed:** Timeline day boundaries follow profile TZ, not phone local time.
- **What it contains:** Timezone normalize/offset, projected today, TZ writes.
- **Key code names:** `ProfileTimezoneExtension`
- **Responsibilities:** Timezone normalize/offset, projected today, TZ writes
- **When to open:** Profile settings, timezone, tags catalog, tag display prefs.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; APP_STRUCTURE role: Timezone normalize/offset, projected today, TZ writes
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для profile and tags — файл `profile_timezone`.
- **Зачем:** Держит profile and tags согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`ProfileTimezoneExtension`).
- **Обязанности:** Реализует в коде: Timezone normalize/offset, projected today, TZ writes.
- **Когда открывать:** Профиль, timezone, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Profile, tag manager, timezone в header
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/profile/tag_catalog.dart`

EN:

- **What this is:** Loads and edits the tag list (plan tags and list tags) in PocketBase.
- **Why needed:** Tag manager and tag chips on cards read from this catalog.
- **What it contains:** Tag CRUD, sort order, PocketBase `tags_link` id resolution.
- **Key code names:** `TagCatalogExtension`
- **Responsibilities:** Tag catalog fetch/CRUD, sort order, PB `tags_link` id resolution
- **When to open:** Profile settings, timezone, tags catalog, tag display prefs.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; APP_STRUCTURE role: Tag catalog fetch/CRUD, sort order, PB `tags_link` id resolution
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для profile and tags — файл `tag_catalog`.
- **Зачем:** Держит profile and tags согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`TagCatalogExtension`).
- **Обязанности:** Реализует в коде: Tag catalog fetch/CRUD, sort order, PB `tags_link` id resolution.
- **Когда открывать:** Профиль, timezone, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Profile, tag manager, timezone в header
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/profile/tag_display_settings.dart`

EN:

- **What this is:** Stores how tag chips appear on list cards (hidden, compact, etc.).
- **Why needed:** Tag display mode is a profile preference, not per-plan.
- **What it contains:** List tag strip visibility prefs, display-mode merge.
- **Key code names:** `TagDisplaySettingsExtension`
- **Responsibilities:** List tag strip visibility prefs, display-mode prefs merge
- **When to open:** Profile settings, timezone, tags catalog, tag display prefs.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; APP_STRUCTURE role: List tag strip visibility prefs, display-mode prefs merge
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для profile and tags — файл `tag_display_settings`.
- **Зачем:** Держит profile and tags согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`TagDisplaySettingsExtension`).
- **Обязанности:** Реализует в коде: List tag strip visibility prefs, display-mode prefs merge.
- **Когда открывать:** Профиль, timezone, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Profile, tag manager, timezone в header
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/profile_service.dart`

EN:

- **What this is:** Main coordinator for profile, timezone, and tags inside the brain.
- **Why needed:** UI calls one profile entry point; this file delegates to focused modules in the subfolder.
- **What it contains:** Coordinator extensions plus links to `part` files under `profiles/` or `profile/`.
- **Key code names:** `_ProfileFetchFailedException`, `ProfileServiceExtension`
- **Responsibilities:** Profile coordinator: shared Brain state, display label resolver
- **When to open:** When behavior tied to `profile_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; APP_STRUCTURE role: Profile coordinator: shared Brain state, display label resolver
- **Layer / owner:** Brain coordinator — entry point for this domain inside `database_service.dart`.

RU:

- **Что это:** Главный координатор для profile, timezone, and tags.
- **Зачем:** UI вызывает один вход; детали — в модулях subfolder.
- **Содержимое:** Extensions + `part` файлы для profile.
- **Обязанности:** Координатор домена: Profile coordinator: shared Brain state, display label resolver.
- **Когда открывать:** Когда ломается поведение, связанное с `profile_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Profile, tag manager, timezone в header
- **Слой:** Brain — координатор домена.


### `lib/data/record_service.dart`

EN:

- **What this is:** Main coordinator for timeline records (timer start/stop) inside the brain.
- **Why needed:** UI calls one record entry point; this file delegates to focused modules in the subfolder.
- **What it contains:** Coordinator extensions plus links to `part` files under `records/` or `record/`.
- **Key code names:** `RecordServiceExtension`
- **Responsibilities:** Records coordinator: cache, fetch, upsert, start/stop entry, streams
- **When to open:** When behavior tied to `record_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Records coordinator: cache, fetch, upsert, start/stop entry, streams
- **Layer / owner:** Brain coordinator — entry point for this domain inside `database_service.dart`.

RU:

- **Что это:** Главный координатор для timeline records (timer start/stop).
- **Зачем:** UI вызывает один вход; детали — в модулях subfolder.
- **Содержимое:** Extensions + `part` файлы для record.
- **Обязанности:** Координатор домена: Records coordinator: cache, fetch, upsert, start/stop entry, streams.
- **Когда открывать:** Когда ломается поведение, связанное с `record_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — координатор домена.


### `lib/data/records/record_cache_helpers.dart`

EN:

- **What this is:** Filters and streams the in-memory record list for Timeline display.
- **Why needed:** Every Timeline day reads from this cache instead of hitting the network each swipe.
- **What it contains:** `recordsStream`, per-day filter, display-time helpers.
- **Key code names:** `RecordCacheProjectionExtension`
- **Responsibilities:** Per-day filter, `recordsStream`, display-time helpers
- **When to open:** Timeline timer, record edit, offline start/stop, duplicate running record.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; APP_STRUCTURE role: Per-day filter, `recordsStream`, display-time helpers
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для timeline records — файл `record_cache_helpers`.
- **Зачем:** Держит timeline records согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`RecordCacheProjectionExtension`).
- **Обязанности:** Реализует в коде: Per-day filter, `recordsStream`, display-time helpers.
- **Когда открывать:** Timeline: старт/стоп, правка, офлайн, дубликат running.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Timeline, edit sheet, Wear
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/records/record_crud.dart`

EN:

- **What this is:** Sends timeline record start, stop, edit, and delete to PocketBase.
- **Why needed:** When you tap Start or Stop, this file builds the network request and updates the local record list.
- **What it contains:** POST/PATCH/DELETE for the `records` table; `writeRecord`, `stopRecord`, `updateRecord`.
- **Key code names:** `RecordCrudExtension`
- **Responsibilities:** Record CRUD, PATCH/DELETE network phases, `writeRecord` / `updateRecord` / `stopRecord`
- **When to open:** Timeline timer, record edit, offline start/stop, duplicate running record.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; APP_STRUCTURE role: Record CRUD, PATCH/DELETE network phases, `writeRecord` / `updateRecord` / `stopRecord`
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для timeline records — файл `record_crud`.
- **Зачем:** Держит timeline records согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`RecordCrudExtension`).
- **Обязанности:** Реализует в коде: Record CRUD, PATCH/DELETE network phases, `writeRecord` / `updateRecord` / `stopRecord`.
- **Когда открывать:** Timeline: старт/стоп, правка, офлайн, дубликат running.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Timeline, edit sheet, Wear
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/records/record_ghost_cleanup.dart`

EN:

- **What this is:** Removes dead record rows from local cache after server 404.
- **Why needed:** Stale cache entries would show ghost timers that no longer exist on PocketBase.
- **What it contains:** 404 dead-letter prune against live cache.
- **Key code names:** `RecordGhostCleanupExtension`
- **Responsibilities:** 404 deadletter prune against live cache
- **When to open:** Timeline timer, record edit, offline start/stop, duplicate running record.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; APP_STRUCTURE role: 404 deadletter prune against live cache
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для timeline records — файл `record_ghost_cleanup`.
- **Зачем:** Держит timeline records согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`RecordGhostCleanupExtension`).
- **Обязанности:** Реализует в коде: 404 deadletter prune against live cache.
- **Когда открывать:** Timeline: старт/стоп, правка, офлайн, дубликат running.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Timeline, edit sheet, Wear
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/records/record_optimistic.dart`

EN:

- **What this is:** Shows timer start/stop on screen immediately — before PocketBase confirms.
- **Why needed:** The 100ms rule: users must see the running timer without waiting on Wi‑Fi.
- **What it contains:** Shadow state maps, optimistic stop overlay, pending-start handoff.
- **Key code names:** `RecordOptimisticExtension`
- **Responsibilities:** Optimistic stop overlay, sacred handoff, pending-start map
- **When to open:** Timeline timer, record edit, offline start/stop, duplicate running record.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; APP_STRUCTURE role: Optimistic stop overlay, sacred handoff, pending-start map
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для timeline records — файл `record_optimistic`.
- **Зачем:** Держит timeline records согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`RecordOptimisticExtension`).
- **Обязанности:** Реализует в коде: Optimistic stop overlay, sacred handoff, pending-start map.
- **Когда открывать:** Timeline: старт/стоп, правка, офлайн, дубликат running.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Timeline, edit sheet, Wear
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/records/record_outbox_helpers.dart`

EN:

- **What this is:** Queues record changes when offline and replays them when back online.
- **Why needed:** Start/stop on bad Wi‑Fi must not be lost — changes wait in SharedPreferences.
- **What it contains:** Record mutation outbox enqueue, flush, Highlander server sync phase.
- **Key code names:** `RecordOutboxSyncExtension`
- **Responsibilities:** Record mutation outbox enqueue/flush/replay, Highlander server phase
- **When to open:** Timeline timer, record edit, offline start/stop, duplicate running record.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; APP_STRUCTURE role: Record mutation outbox enqueue/flush/replay, Highlander server phase
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для timeline records — файл `record_outbox_helpers`.
- **Зачем:** Держит timeline records согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`RecordOutboxSyncExtension`).
- **Обязанности:** Реализует в коде: Record mutation outbox enqueue/flush/replay, Highlander server phase.
- **Когда открывать:** Timeline: старт/стоп, правка, офлайн, дубликат running.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Timeline, edit sheet, Wear
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/records/record_overlap_helpers.dart`

EN:

- **What this is:** Ensures only one running record at a time (Highlander rule).
- **Why needed:** Starting a new task must auto-stop the previous running timer.
- **What it contains:** Singleton reconcile, overlap probes, local apply before server.
- **Key code names:** `RecordOverlapExtension`
- **Responsibilities:** Highlander local apply, singleton reconcile, overlap probes
- **When to open:** Timeline timer, record edit, offline start/stop, duplicate running record.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; APP_STRUCTURE role: Highlander local apply, singleton reconcile, overlap probes
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для timeline records — файл `record_overlap_helpers`.
- **Зачем:** Держит timeline records согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`RecordOverlapExtension`).
- **Обязанности:** Реализует в коде: Highlander local apply, singleton reconcile, overlap probes.
- **Когда открывать:** Timeline: старт/стоп, правка, офлайн, дубликат running.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Timeline, edit sheet, Wear
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/records/record_realtime.dart`

EN:

- **What this is:** Listens for live record changes from PocketBase on the server.
- **Why needed:** If another device stops a record, Timeline should update without manual refresh.
- **What it contains:** Realtime subscription connect/disconnect, event merge into cache.
- **Key code names:** `RecordRealtimeExtension`
- **Responsibilities:** PocketBase records realtime subscribe/unsubscribe
- **When to open:** Timeline timer, record edit, offline start/stop, duplicate running record.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; APP_STRUCTURE role: PocketBase records realtime subscribe/unsubscribe
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для timeline records — файл `record_realtime`.
- **Зачем:** Держит timeline records согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`RecordRealtimeExtension`).
- **Обязанности:** Реализует в коде: PocketBase records realtime subscribe/unsubscribe.
- **Когда открывать:** Timeline: старт/стоп, правка, офлайн, дубликат running.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Timeline, edit sheet, Wear
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/records/record_timeline_vm.dart`

EN:

- **What this is:** Prepares which record rows appear on each Timeline day page.
- **Why needed:** Timeline swipe between days needs pre-built lists and warm-window paging.
- **What it contains:** Day index, warm window, row view-model builders for Timeline cards.
- **Key code names:** `RecordTimelineVmExtension`
- **Responsibilities:** Timeline day index, warm window, row VM builders
- **When to open:** Timeline timer, record edit, offline start/stop, duplicate running record.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; APP_STRUCTURE role: Timeline day index, warm window, row VM builders
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Модуль brain для timeline records — файл `record_timeline_vm`.
- **Зачем:** Держит timeline records согласованным с PocketBase и UI.
- **Содержимое:** Dart-код (`RecordTimelineVmExtension`).
- **Обязанности:** Реализует в коде: Timeline day index, warm window, row VM builders.
- **Когда открывать:** Timeline: старт/стоп, правка, офлайн, дубликат running.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`; Timeline, edit sheet, Wear
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/recurrence_edit_scope.dart`

EN:

- **What this is:** Brain support file — `RecurrenceEditScope` enum for recurring plan edit/delete scope.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`RecurrenceEditScope`).
- **Key code names:** `RecurrenceEditScope`
- **Responsibilities:** `RecurrenceEditScope` enum for recurring plan edit/delete scope
- **When to open:** When behavior tied to `recurrence_edit_scope.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: `RecurrenceEditScope` enum for recurring plan edit/delete scope
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Вспомогательный модуль brain — `RecurrenceEditScope` enum for recurring plan edit/delete scope.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (`RecurrenceEditScope`).
- **Обязанности:** Реализует в brain: `RecurrenceEditScope` enum for recurring plan edit/delete scope.
- **Когда открывать:** Когда ломается поведение, связанное с `recurrence_edit_scope.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/smart_input_parser.dart`

EN:

- **What this is:** Brain support file — Natural-language plan/list parse (client + AI backend hook).
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`SmartTimeParseResult`, `SmartTimeRangeParseResult`, `SmartInputParser`).
- **Key code names:** `SmartTimeParseResult`, `SmartTimeRangeParseResult`, `SmartInputParser`
- **Responsibilities:** Natural-language plan/list parse (client + AI backend hook)
- **When to open:** When behavior tied to `smart_input_parser.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Natural-language plan/list parse (client + AI backend hook)
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Вспомогательный модуль brain — Natural-language plan/list parse (client + AI backend hook).
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (`SmartTimeParseResult`, `SmartTimeRangeParseResult`, `SmartInputParser`).
- **Обязанности:** Реализует в brain: Natural-language plan/list parse (client + AI backend hook).
- **Когда открывать:** Когда ломается поведение, связанное с `smart_input_parser.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/time_view_fixed_time_policy.dart`

EN:

- **What this is:** Brain support file — Local prefs `time_view_fixed_tag_ids_v1`.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`TimeViewFixedTagPrefs`).
- **Key code names:** `TimeViewFixedTagPrefs`
- **Responsibilities:** Local prefs `time_view_fixed_tag_ids_v1`; `isPlanFixedInTimeView` (schema gap: no PB sync yet)
- **When to open:** When behavior tied to `time_view_fixed_time_policy.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Local prefs `time_view_fixed_tag_ids_v1`
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Вспомогательный модуль brain — Local prefs `time_view_fixed_tag_ids_v1`.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (`TimeViewFixedTagPrefs`).
- **Обязанности:** Реализует в brain: Local prefs `time_view_fixed_tag_ids_v1`; `isPlanFixedInTimeView` (schema gap: no PB sync yet).
- **Когда открывать:** Когда ломается поведение, связанное с `time_view_fixed_time_policy.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/voice_audio_stub.dart`

EN:

- **What this is:** Brain support file — Non-web voice audio stub.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (logic in `voice_audio_stub`).
- **Responsibilities:** Non-web voice audio stub
- **When to open:** When behavior tied to `voice_audio_stub.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Non-web voice audio stub
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Вспомогательный модуль brain — Non-web voice audio stub.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (logic in `voice_audio_stub`).
- **Обязанности:** Реализует в brain: Non-web voice audio stub.
- **Когда открывать:** Когда ломается поведение, связанное с `voice_audio_stub.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/voice_audio_web.dart`

EN:

- **What this is:** Brain support file — Web voice audio implementation.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (logic in `voice_audio_web`).
- **Responsibilities:** Web voice audio implementation
- **When to open:** When behavior tied to `voice_audio_web.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Web voice audio implementation
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Вспомогательный модуль brain — Web voice audio implementation.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (logic in `voice_audio_web`).
- **Обязанности:** Реализует в brain: Web voice audio implementation.
- **Когда открывать:** Когда ломается поведение, связанное с `voice_audio_web.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/voice_command_parser.dart`

EN:

- **What this is:** Brain support file — Deterministic desktop/mobile voice command parse (`parsePriceReporterVoiceCommand`, `VoiceCommandCategoryIndex`).
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`VoiceCommandMatchConfidence`, `VoiceCommandParseResult`, `VoiceCommandCategoryCandidate`, `VoiceCommandCategoryIndex`, `VoiceCommandCategoryScope`).
- **Key code names:** `VoiceCommandMatchConfidence`, `VoiceCommandParseResult`, `VoiceCommandCategoryCandidate`, `VoiceCommandCategoryIndex`, `VoiceCommandCategoryScope`
- **Responsibilities:** Deterministic desktop/mobile voice command parse (`parsePriceReporterVoiceCommand`, `VoiceCommandCategoryIndex`)
- **When to open:** When behavior tied to `voice_command_parser.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Deterministic desktop/mobile voice command parse (`parsePriceReporterVoiceCommand`, `VoiceCommandCategoryIndex`)
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Вспомогательный модуль brain — Deterministic desktop/mobile voice command parse (`parsePriceReporterVoiceCommand`, `VoiceCommandCategoryIndex`).
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (`VoiceCommandMatchConfidence`, `VoiceCommandParseResult`, `VoiceCommandCategoryCandidate`, `VoiceCommandCategoryIndex`, `VoiceCommandCategoryScope`).
- **Обязанности:** Реализует в brain: Deterministic desktop/mobile voice command parse (`parsePriceReporterVoiceCommand`, `VoiceCommandCategoryIndex`).
- **Когда открывать:** Когда ломается поведение, связанное с `voice_command_parser.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/web_history.dart`

EN:

- **What this is:** Brain support file — Web history API conditional export.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (logic in `web_history`).
- **Responsibilities:** Web history API conditional export
- **When to open:** When behavior tied to `web_history.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Web history API conditional export
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Вспомогательный модуль brain — Web history API conditional export.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (logic in `web_history`).
- **Обязанности:** Реализует в brain: Web history API conditional export.
- **Когда открывать:** Когда ломается поведение, связанное с `web_history.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/web_history_stub.dart`

EN:

- **What this is:** Brain support file — Non-web history stub.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (logic in `web_history_stub`).
- **Responsibilities:** Non-web history stub
- **When to open:** When behavior tied to `web_history_stub.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Non-web history stub
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Вспомогательный модуль brain — Non-web history stub.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (logic in `web_history_stub`).
- **Обязанности:** Реализует в brain: Non-web history stub.
- **Когда открывать:** Когда ломается поведение, связанное с `web_history_stub.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/data/web_history_web.dart`

EN:

- **What this is:** Brain support file — Web history implementation.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (logic in `web_history_web`).
- **Responsibilities:** Web history implementation
- **When to open:** When behavior tied to `web_history_web.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; APP_STRUCTURE role: Web history implementation
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Вспомогательный модуль brain — Web history implementation.
- **Зачем:** Общая логика PocketBase и auth для нескольких вкладок.
- **Содержимое:** Dart-код (logic in `web_history_web`).
- **Обязанности:** Реализует в brain: Web history implementation.
- **Когда открывать:** Когда ломается поведение, связанное с `web_history_web.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает `DatabaseService.instance`
- **Слой:** Brain — модуль `part` в `database_service.dart`.


### `lib/features/auth/auth_screen.dart`

EN:

- **What this is:** `auth_screen.dart` on sign-in and registration screen — Sign-in, register, OAuth, password reset.
- **Why needed:** Users see `auth_screen.dart` when using sign-in and registration screen.
- **What it contains:** Primary symbols: `AuthScreen`.
- **Key code names:** `AuthScreen`
- **Responsibilities:** Sign-in, register, OAuth, password reset
- **When to open:** When behavior tied to `auth_screen.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Login gate from `main.dart`; APP_STRUCTURE role: Sign-in, register, OAuth, password reset
- **Layer / owner:** UI code for the auth area of the app (what users see and tap).

RU:

- **Что это:** `auth_screen.dart` на экран входа и регистрации — Поддерживает поведение `auth_screen` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `auth_screen.dart` на экран входа и регистрации.
- **Содержимое:** Dart-модуль `auth_screen.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `auth_screen` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `auth_screen.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Login gate из `main.dart`
- **Слой:** UI — экран/виджет (auth).


### `lib/features/auth/auth_view.dart`

EN:

- **What this is:** `auth_view.dart` on sign-in and registration screen — Sign-in, register, OAuth, password reset.
- **Why needed:** Users see `auth_view.dart` when using sign-in and registration screen.
- **What it contains:** Primary symbols: `AuthView`, `_AuthViewState`.
- **Key code names:** `AuthView`, `_AuthViewState`
- **Responsibilities:** Sign-in, register, OAuth, password reset
- **When to open:** When behavior tied to `auth_view.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Login gate from `main.dart`; APP_STRUCTURE role: Sign-in, register, OAuth, password reset
- **Layer / owner:** UI code for the auth area of the app (what users see and tap).

RU:

- **Что это:** `auth_view.dart` на экран входа и регистрации — Отвечает за видимый UI, собранный в `auth_view.dart`..
- **Зачем:** Пользователь видит UI из `auth_view.dart` на экран входа и регистрации.
- **Содержимое:** Компоновка экрана и state в `auth_view.dart`.
- **Обязанности:** Отвечает за видимый UI, собранный в `auth_view.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `auth_view.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Login gate из `main.dart`
- **Слой:** UI — экран/виджет (auth).


### `lib/features/auth/oauth_session.dart`

EN:

- **What this is:** `oauth_session.dart` on sign-in and registration screen — Sign-in, register, OAuth, password reset.
- **Why needed:** Users see `oauth_session.dart` when using sign-in and registration screen.
- **What it contains:** Primary symbols: `OAuthUser`, `OAuthSession`.
- **Key code names:** `OAuthUser`, `OAuthSession`
- **Responsibilities:** Sign-in, register, OAuth, password reset
- **When to open:** When behavior tied to `oauth_session.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Login gate from `main.dart`; APP_STRUCTURE role: Sign-in, register, OAuth, password reset
- **Layer / owner:** UI code for the auth area of the app (what users see and tap).

RU:

- **Что это:** `oauth_session.dart` на экран входа и регистрации — Поддерживает поведение `oauth_session` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `oauth_session.dart` на экран входа и регистрации.
- **Содержимое:** Dart-модуль `oauth_session.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `oauth_session` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `oauth_session.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Login gate из `main.dart`
- **Слой:** UI — экран/виджет (auth).


### `lib/features/calendar/calendar_view.dart`

EN:

- **What this is:** `calendar_view.dart` on Calendar tab — Calendar tab.
- **Why needed:** Users see `calendar_view.dart` when using Calendar tab.
- **What it contains:** Primary symbols: `_CalendarViewMode`, `CalendarView`, `_CalendarViewState`, `_CalendarChromeHeader`.
- **Key code names:** `_CalendarViewMode`, `CalendarView`, `_CalendarViewState`, `_CalendarChromeHeader`
- **Responsibilities:** Calendar tab
- **When to open:** When behavior tied to `calendar_view.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Calendar tab
- **Layer / owner:** UI code for the calendar area of the app (what users see and tap).

RU:

- **Что это:** `calendar_view.dart` на вкладка Calendar — Отвечает за видимый UI, собранный в `calendar_view.dart`..
- **Зачем:** Пользователь видит UI из `calendar_view.dart` на вкладка Calendar.
- **Содержимое:** Компоновка экрана и state в `calendar_view.dart`.
- **Обязанности:** Отвечает за видимый UI, собранный в `calendar_view.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `calendar_view.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/calendar/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (calendar).


### `lib/features/categories/category_list_view.dart`

EN:

- **What this is:** `category_list_view.dart` on More → Categories manager — Category manager (More menu).
- **Why needed:** Users see `category_list_view.dart` when using More → Categories manager.
- **What it contains:** Primary symbols: `_CategoryDepthLayout`, `CategoryBandLayout`, `CategoryRowWidget`.
- **Key code names:** `_CategoryDepthLayout`, `CategoryBandLayout`, `CategoryRowWidget`
- **Responsibilities:** Category manager (More menu)
- **When to open:** When behavior tied to `category_list_view.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Category manager (More menu)
- **Layer / owner:** UI code for the categories area of the app (what users see and tap).

RU:

- **Что это:** `category_list_view.dart` на More → Categories — Отвечает за видимый UI, собранный в `category_list_view.dart`..
- **Зачем:** Пользователь видит UI из `category_list_view.dart` на More → Categories.
- **Содержимое:** Компоновка экрана и state в `category_list_view.dart`.
- **Обязанности:** Отвечает за видимый UI, собранный в `category_list_view.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `category_list_view.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/categories/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (categories).


### `lib/features/categories/category_recursive_tree.dart`

EN:

- **What this is:** `category_recursive_tree.dart` on More → Categories manager — Category manager (More menu).
- **Why needed:** Users see `category_recursive_tree.dart` when using More → Categories manager.
- **What it contains:** Primary symbols: `CategoryTreeSheetPicked`, `CategoryTreeSheetAll`, `CategoryFilterTreeField`, `CategoryTreeFormField`, `_CategoryTreeBody`, `_CategoryTreeBodyState`.
- **Key code names:** `CategoryTreeSheetPicked`, `CategoryTreeSheetAll`, `CategoryFilterTreeField`, `CategoryTreeFormField`, `_CategoryTreeBody`, `_CategoryTreeBodyState`, `_CategoryTreeNode`
- **Responsibilities:** Category manager (More menu)
- **When to open:** When behavior tied to `category_recursive_tree.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Category manager (More menu)
- **Layer / owner:** UI code for the categories area of the app (what users see and tap).

RU:

- **Что это:** `category_recursive_tree.dart` на More → Categories — Поддерживает поведение `category_recursive_tree` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `category_recursive_tree.dart` на More → Categories.
- **Содержимое:** Dart-модуль `category_recursive_tree.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `category_recursive_tree` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `category_recursive_tree.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/categories/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (categories).


### `lib/features/categories/category_visibility_prefs.dart`

EN:

- **What this is:** `category_visibility_prefs.dart` on More → Categories manager — Category manager (More menu).
- **Why needed:** Users see `category_visibility_prefs.dart` when using More → Categories manager.
- **What it contains:** Primary symbols: `CategoryVisibilityPrefs`.
- **Key code names:** `CategoryVisibilityPrefs`
- **Responsibilities:** Category manager (More menu)
- **When to open:** When behavior tied to `category_visibility_prefs.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Category manager (More menu)
- **Layer / owner:** UI code for the categories area of the app (what users see and tap).

RU:

- **Что это:** `category_visibility_prefs.dart` на More → Categories — Поддерживает поведение `category_visibility_prefs` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `category_visibility_prefs.dart` на More → Categories.
- **Содержимое:** Dart-модуль `category_visibility_prefs.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `category_visibility_prefs` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `category_visibility_prefs.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/categories/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (categories).


### `lib/features/categories/create_category_dialog.dart`

EN:

- **What this is:** `create_category_dialog.dart` on More → Categories manager — Category manager (More menu).
- **Why needed:** Users see `create_category_dialog.dart` when using More → Categories manager.
- **What it contains:** Primary symbols: `_CreateCategoryDialog`, `_CreateCategoryDialogState`.
- **Key code names:** `_CreateCategoryDialog`, `_CreateCategoryDialogState`
- **Responsibilities:** Category manager (More menu)
- **When to open:** When behavior tied to `create_category_dialog.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Category manager (More menu)
- **Layer / owner:** UI code for the categories area of the app (what users see and tap).

RU:

- **Что это:** `create_category_dialog.dart` на More → Categories — Пользователь открывает sheet/dialog из entry `create_category_dialog`..
- **Зачем:** Пользователь видит UI из `create_category_dialog.dart` на More → Categories.
- **Содержимое:** Основные символы: `_CreateCategoryDialog`, `_CreateCategoryDialogState`.
- **Обязанности:** Пользователь открывает sheet/dialog из entry `create_category_dialog`.
- **Когда открывать:** Когда ломается поведение, связанное с `create_category_dialog.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/categories/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (categories).


### `lib/features/dev/component_lab_cards_demo.dart`

EN:

- **What this is:** `component_lab_cards_demo.dart` on admin-only Component Lab (More → Dev) — Admin-only Component Lab.
- **Why needed:** Users see `component_lab_cards_demo.dart` when using admin-only Component Lab (More → Dev).
- **What it contains:** Primary symbols: `ComponentLabPlanCardsDemo`.
- **Key code names:** `ComponentLabPlanCardsDemo`
- **Responsibilities:** Admin-only Component Lab
- **When to open:** When behavior tied to `component_lab_cards_demo.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Admin-only Component Lab
- **Layer / owner:** UI code for the dev area of the app (what users see and tap).

RU:

- **Что это:** `component_lab_cards_demo.dart` на Component Lab (More → Dev, только admin) — Поддерживает поведение `component_lab_cards_demo` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `component_lab_cards_demo.dart` на Component Lab (More → Dev, только admin).
- **Содержимое:** Dart-модуль `component_lab_cards_demo.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `component_lab_cards_demo` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `component_lab_cards_demo.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/dev/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (dev).


### `lib/features/dev/component_lab_view.dart`

EN:

- **What this is:** `component_lab_view.dart` on admin-only Component Lab (More → Dev) — Admin-only Component Lab.
- **Why needed:** Users see `component_lab_view.dart` when using admin-only Component Lab (More → Dev).
- **What it contains:** Primary symbols: `ComponentLabPage`, `_LabSection`, `_ButtonsDemo`, `_IconButtonsDemo`.
- **Key code names:** `ComponentLabPage`, `_LabSection`, `_ButtonsDemo`, `_IconButtonsDemo`
- **Responsibilities:** Admin-only Component Lab
- **When to open:** When behavior tied to `component_lab_view.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Admin-only Component Lab
- **Layer / owner:** UI code for the dev area of the app (what users see and tap).

RU:

- **Что это:** `component_lab_view.dart` на Component Lab (More → Dev, только admin) — Отвечает за видимый UI, собранный в `component_lab_view.dart`..
- **Зачем:** Пользователь видит UI из `component_lab_view.dart` на Component Lab (More → Dev, только admin).
- **Содержимое:** Компоновка экрана и state в `component_lab_view.dart`.
- **Обязанности:** Отвечает за видимый UI, собранный в `component_lab_view.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `component_lab_view.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/dev/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (dev).


### `lib/features/lists/lists_bulk_actions.dart`

EN:

- **What this is:** `lists_bulk_actions.dart` on Lists tab (fourth bottom tab) — Select-mode header + bulk action bottom bar.
- **Why needed:** Users see `lists_bulk_actions.dart` when using Lists tab (fourth bottom tab).
- **What it contains:** Primary symbols: `ListsBulkSelectModeBar`, `ListsBulkBottomBar`.
- **Key code names:** `ListsBulkSelectModeBar`, `ListsBulkBottomBar`
- **Responsibilities:** Select-mode header + bulk action bottom bar
- **When to open:** Lists tab: filters, done checkbox, bulk actions, export.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Lists tab (shell index 3); APP_STRUCTURE role: Select-mode header + bulk action bottom bar
- **Layer / owner:** UI code for the lists area of the app (what users see and tap).

RU:

- **Что это:** `lists_bulk_actions.dart` на вкладка Lists (четвёртая снизу) — Поддерживает поведение `lists_bulk_actions` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `lists_bulk_actions.dart` на вкладка Lists (четвёртая снизу).
- **Содержимое:** Dart-модуль `lists_bulk_actions.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `lists_bulk_actions` в этой feature-зоне.
- **Когда открывать:** Вкладка Lists: фильтры, done, экспорт.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Lists (shell index 3)
- **Слой:** UI — экран/виджет (lists).


### `lib/features/lists/lists_card.dart`

EN:

- **What this is:** `lists_card.dart` on Lists tab (fourth bottom tab) — BacklogPlanCard.
- **Why needed:** Users see `lists_card.dart` when using Lists tab (fourth bottom tab).
- **What it contains:** Primary symbols: `ListsQuadraticChip`, `BacklogPlanCard`, `ListsSemicircleMenuOverlay`, `ListsSemicircleMenuOverlayState`.
- **Key code names:** `ListsQuadraticChip`, `BacklogPlanCard`, `ListsSemicircleMenuOverlay`, `ListsSemicircleMenuOverlayState`
- **Responsibilities:** BacklogPlanCard
- **When to open:** Lists tab: filters, done checkbox, bulk actions, export.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Lists tab (shell index 3); APP_STRUCTURE role: `BacklogPlanCard`, filter chips, semicircle menu
- **Layer / owner:** UI code for the lists area of the app (what users see and tap).

RU:

- **Что это:** `lists_card.dart` на вкладка Lists (четвёртая снизу) — Поддерживает поведение `lists_card` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `lists_card.dart` на вкладка Lists (четвёртая снизу).
- **Содержимое:** Dart-модуль `lists_card.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `lists_card` в этой feature-зоне.
- **Когда открывать:** Вкладка Lists: фильтры, done, экспорт.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Lists (shell index 3)
- **Слой:** UI — экран/виджет (lists).


### `lib/features/lists/lists_empty_state.dart`

EN:

- **What this is:** `lists_empty_state.dart` on Lists tab (fourth bottom tab) — Loading / filtered / no-category empty panels.
- **Why needed:** Users see `lists_empty_state.dart` when using Lists tab (fourth bottom tab).
- **What it contains:** Primary symbols: `ListsNoCategoryEmptyPanel`, `ListsFilteredEmptyPanel`, `ListsLoadingPanel`.
- **Key code names:** `ListsNoCategoryEmptyPanel`, `ListsFilteredEmptyPanel`, `ListsLoadingPanel`
- **Responsibilities:** Loading / filtered / no-category empty panels
- **When to open:** Lists tab: filters, done checkbox, bulk actions, export.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Lists tab (shell index 3); APP_STRUCTURE role: Loading / filtered / no-category empty panels
- **Layer / owner:** UI code for the lists area of the app (what users see and tap).

RU:

- **Что это:** `lists_empty_state.dart` на вкладка Lists (четвёртая снизу) — Поддерживает поведение `lists_empty_state` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `lists_empty_state.dart` на вкладка Lists (четвёртая снизу).
- **Содержимое:** Dart-модуль `lists_empty_state.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `lists_empty_state` в этой feature-зоне.
- **Когда открывать:** Вкладка Lists: фильтры, done, экспорт.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Lists (shell index 3)
- **Слой:** UI — экран/виджет (lists).


### `lib/features/lists/lists_export.dart`

EN:

- **What this is:** `lists_export.dart` on Lists tab (fourth bottom tab) — Export visible list as clipboard text.
- **Why needed:** Users see `lists_export.dart` when using Lists tab (fourth bottom tab).
- **What it contains:** Dart module `lists_export.dart` — open file for classes and helpers.
- **Responsibilities:** Export visible list as clipboard text
- **When to open:** Lists tab: filters, done checkbox, bulk actions, export.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Lists tab (shell index 3); APP_STRUCTURE role: Export visible list as clipboard text
- **Layer / owner:** UI code for the lists area of the app (what users see and tap).

RU:

- **Что это:** `lists_export.dart` на вкладка Lists (четвёртая снизу) — Поддерживает поведение `lists_export` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `lists_export.dart` на вкладка Lists (четвёртая снизу).
- **Содержимое:** Dart-модуль `lists_export.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `lists_export` в этой feature-зоне.
- **Когда открывать:** Вкладка Lists: фильтры, done, экспорт.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Lists (shell index 3)
- **Слой:** UI — экран/виджет (lists).


### `lib/features/lists/lists_filters.dart`

EN:

- **What this is:** `lists_filters.dart` on Lists tab (fourth bottom tab) — Tag/category filter chips, chip bar, settings sheet.
- **Why needed:** Users see `lists_filters.dart` when using Lists tab (fourth bottom tab).
- **What it contains:** Primary symbols: `ListsTagFilterChip`, `ListsCategoryChipBar`, `ListsTagFilterBar`, `ListsFilterToolbarRow`.
- **Key code names:** `ListsTagFilterChip`, `ListsCategoryChipBar`, `ListsTagFilterBar`, `ListsFilterToolbarRow`
- **Responsibilities:** Tag/category filter chips, chip bar, settings sheet
- **When to open:** Lists tab: filters, done checkbox, bulk actions, export.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Lists tab (shell index 3); APP_STRUCTURE role: Tag/category filter chips, chip bar, settings sheet
- **Layer / owner:** UI code for the lists area of the app (what users see and tap).

RU:

- **Что это:** `lists_filters.dart` на вкладка Lists (четвёртая снизу) — Поддерживает поведение `lists_filters` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `lists_filters.dart` на вкладка Lists (четвёртая снизу).
- **Содержимое:** Dart-модуль `lists_filters.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `lists_filters` в этой feature-зоне.
- **Когда открывать:** Вкладка Lists: фильтры, done, экспорт.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Lists (shell index 3)
- **Слой:** UI — экран/виджет (lists).


### `lib/features/lists/lists_inline_add.dart`

EN:

- **What this is:** `lists_inline_add.dart` on Lists tab (fourth bottom tab) — Inline quick-add input row.
- **Why needed:** Users see `lists_inline_add.dart` when using Lists tab (fourth bottom tab).
- **What it contains:** Primary symbols: `ListsInlineAddRow`.
- **Key code names:** `ListsInlineAddRow`
- **Responsibilities:** Inline quick-add input row
- **When to open:** Lists tab: filters, done checkbox, bulk actions, export.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Lists tab (shell index 3); APP_STRUCTURE role: Inline quick-add input row
- **Layer / owner:** UI code for the lists area of the app (what users see and tap).

RU:

- **Что это:** `lists_inline_add.dart` на вкладка Lists (четвёртая снизу) — Поддерживает поведение `lists_inline_add` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `lists_inline_add.dart` на вкладка Lists (четвёртая снизу).
- **Содержимое:** Dart-модуль `lists_inline_add.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `lists_inline_add` в этой feature-зоне.
- **Когда открывать:** Вкладка Lists: фильтры, done, экспорт.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Lists (shell index 3)
- **Слой:** UI — экран/виджет (lists).


### `lib/features/lists/lists_view.dart`

EN:

- **What this is:** `lists_view.dart` on Lists tab (fourth bottom tab) — Lists/backlog coordinator + filter/bulk/inline/empty modules + card + export.
- **Why needed:** Users see `lists_view.dart` when using Lists tab (fourth bottom tab).
- **What it contains:** Primary symbols: `ListsPage`, `_ListsPageState`.
- **Key code names:** `ListsPage`, `_ListsPageState`
- **Responsibilities:** Lists/backlog coordinator + filter/bulk/inline/empty modules + card + export
- **When to open:** Lists tab: filters, done checkbox, bulk actions, export.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Lists tab (shell index 3); APP_STRUCTURE role: Lists/backlog coordinator + filter/bulk/inline/empty modules + card + export
- **Layer / owner:** UI code for the lists area of the app (what users see and tap).

RU:

- **Что это:** `lists_view.dart` на вкладка Lists (четвёртая снизу) — Отвечает за видимый UI, собранный в `lists_view.dart`..
- **Зачем:** Пользователь видит UI из `lists_view.dart` на вкладка Lists (четвёртая снизу).
- **Содержимое:** Компоновка экрана и state в `lists_view.dart`.
- **Обязанности:** Отвечает за видимый UI, собранный в `lists_view.dart`.
- **Когда открывать:** Вкладка Lists: фильтры, done, экспорт.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Lists (shell index 3)
- **Слой:** UI — экран/виджет (lists).


### `lib/features/planning/bulk_planning_edit_sheet.dart`

EN:

- **What this is:** `bulk_planning_edit_sheet.dart` on Plans tab (second bottom tab) — Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit.
- **Why needed:** Users see `bulk_planning_edit_sheet.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `BulkPlanningEditResult`, `BulkEditWallTimes`, `_BulkPlanningEditSheetBody`, `_BulkPlanningEditSheetBodyState`.
- **Key code names:** `BulkPlanningEditResult`, `BulkEditWallTimes`, `_BulkPlanningEditSheetBody`, `_BulkPlanningEditSheetBodyState`
- **Responsibilities:** Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `bulk_planning_edit_sheet.dart` на вкладка Plans (вторая снизу) — Пользователь открывает sheet/dialog из entry `bulk_planning_edit_sheet`..
- **Зачем:** Пользователь видит UI из `bulk_planning_edit_sheet.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Основные символы: `BulkPlanningEditResult`, `BulkEditWallTimes`, `_BulkPlanningEditSheetBody`, `_BulkPlanningEditSheetBodyState`.
- **Обязанности:** Пользователь открывает sheet/dialog из entry `bulk_planning_edit_sheet`.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/plan_time_gesture_contract.dart`

EN:

- **What this is:** `plan_time_gesture_contract.dart` on Plans tab (second bottom tab) — Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit.
- **Why needed:** Users see `plan_time_gesture_contract.dart` when using Plans tab (second bottom tab).
- **What it contains:** Dart module `plan_time_gesture_contract.dart` — open file for classes and helpers.
- **Responsibilities:** Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `plan_time_gesture_contract.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `plan_time_gesture_contract` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `plan_time_gesture_contract.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `plan_time_gesture_contract.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `plan_time_gesture_contract` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/plan_time_view_layout.dart`

EN:

- **What this is:** `plan_time_view_layout.dart` on Plans tab (second bottom tab) — Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit.
- **Why needed:** Users see `plan_time_view_layout.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `TimeViewYScale`, `PlanTimeViewDurationGrid`, `PlanTimeViewBlockLayout`, `_PlanTimeViewCardSlot`, `PlanTimeViewLayoutCalculator`.
- **Key code names:** `TimeViewYScale`, `PlanTimeViewDurationGrid`, `PlanTimeViewBlockLayout`, `_PlanTimeViewCardSlot`, `PlanTimeViewLayoutCalculator`
- **Responsibilities:** Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `plan_time_view_layout.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `plan_time_view_layout` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `plan_time_view_layout.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `plan_time_view_layout.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `plan_time_view_layout` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/planning_day_start_prefs.dart`

EN:

- **What this is:** `planning_day_start_prefs.dart` on Plans tab (second bottom tab) — Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit.
- **Why needed:** Users see `planning_day_start_prefs.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningSheetTimelinePrefs`.
- **Key code names:** `PlanningSheetTimelinePrefs`
- **Responsibilities:** Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `planning_day_start_prefs.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `planning_day_start_prefs` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `planning_day_start_prefs.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `planning_day_start_prefs.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `planning_day_start_prefs` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/planning_page.dart`

EN:

- **What this is:** `planning_page.dart` on Plans tab (second bottom tab) — PlanningPage.
- **Why needed:** Users see `planning_page.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningPage`, `_PlanningPageState`.
- **Key code names:** `PlanningPage`, `_PlanningPageState`
- **Responsibilities:** PlanningPage
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: `PlanningPage` + day body state (~2.4k lines
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `planning_page.dart` на вкладка Plans (вторая снизу) — Отвечает за видимый UI, собранный в `planning_page.dart`..
- **Зачем:** Пользователь видит UI из `planning_page.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Компоновка экрана и state в `planning_page.dart`.
- **Обязанности:** Отвечает за видимый UI, собранный в `planning_page.dart`.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/planning_page_shell.dart`

EN:

- **What this is:** `planning_page_shell.dart` on Plans tab (second bottom tab) — PlanningSwipeWrapper.
- **Why needed:** Users see `planning_page_shell.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningSwipeWrapper`, `_PlanningSwipeWrapperState`.
- **Key code names:** `PlanningSwipeWrapper`, `_PlanningSwipeWrapperState`
- **Responsibilities:** PlanningSwipeWrapper
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: `PlanningSwipeWrapper` date pager
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `planning_page_shell.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `planning_page_shell` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `planning_page_shell.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `planning_page_shell.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `planning_page_shell` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/planning_sort_mode.dart`

EN:

- **What this is:** `planning_sort_mode.dart` on Plans tab (second bottom tab) — PlanSortMode.
- **Why needed:** Users see `planning_sort_mode.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanSortMode`.
- **Key code names:** `PlanSortMode`
- **Responsibilities:** PlanSortMode
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: `PlanSortMode` + persist index helpers
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `planning_sort_mode.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `planning_sort_mode` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `planning_sort_mode.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `planning_sort_mode.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `planning_sort_mode` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/planning_view.dart`

EN:

- **What this is:** Planning feature barrel — re-exports `planning_page.dart`, `planning_page_shell.dart`, and `planning_sort_mode.dart`.
- **Why needed:** Shell and tests import one stable path instead of three planning entry files.
- **What it contains:** Three `export` lines only — no widgets in this file.
- **Responsibilities:** Public entry surface for the Plans tab modules.
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Barrel вкладки Plans — re-export `planning_page.dart`, `planning_page_shell.dart`, `planning_sort_mode.dart`.
- **Зачем:** Shell импортирует один путь вместо трёх entry-файлов planning.
- **Содержимое:** Только три строки `export` — виджетов здесь нет.
- **Обязанности:** Единая точка входа для модулей вкладки Plans.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/recurrence_scope_dialog.dart`

EN:

- **What this is:** `recurrence_scope_dialog.dart` on Plans tab (second bottom tab) — Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit.
- **Why needed:** Users see `recurrence_scope_dialog.dart` when using Plans tab (second bottom tab).
- **What it contains:** Modal UI widgets and controllers in `recurrence_scope_dialog.dart`.
- **Responsibilities:** Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `recurrence_scope_dialog.dart` на вкладка Plans (вторая снизу) — Пользователь открывает sheet/dialog из entry `recurrence_scope_dialog`..
- **Зачем:** Пользователь видит UI из `recurrence_scope_dialog.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Modal UI и controllers в `recurrence_scope_dialog.dart`.
- **Обязанности:** Пользователь открывает sheet/dialog из entry `recurrence_scope_dialog`.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/settings/default_plan_category_search.dart`

EN:

- **What this is:** `default_plan_category_search.dart` on Plans tab (second bottom tab) — Default plan category search delegate.
- **Why needed:** Users see `default_plan_category_search.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `DefaultPlanCategorySearchDelegate`.
- **Key code names:** `DefaultPlanCategorySearchDelegate`
- **Responsibilities:** Default plan category search delegate
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Default plan category search delegate
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `default_plan_category_search.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `default_plan_category_search` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `default_plan_category_search.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `default_plan_category_search.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `default_plan_category_search` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/settings/default_plan_timezone_search.dart`

EN:

- **What this is:** `default_plan_timezone_search.dart` on Plans tab (second bottom tab) — Default plan TZ search delegate.
- **Why needed:** Users see `default_plan_timezone_search.dart` when using Plans tab (second bottom tab).
- **What it contains:** Dart module `default_plan_timezone_search.dart` — open file for classes and helpers.
- **Responsibilities:** Default plan TZ search delegate
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Default plan TZ search delegate
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `default_plan_timezone_search.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `default_plan_timezone_search` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `default_plan_timezone_search.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `default_plan_timezone_search.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `default_plan_timezone_search` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/settings/plan_record_link_settings.dart`

EN:

- **What this is:** `plan_record_link_settings.dart` on Plans tab (second bottom tab) — Record→plan suggestion prefs.
- **Why needed:** Users see `plan_record_link_settings.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanRecordLinkSuggestionSettingsBlock`, `PlanRecordLinkSuggestionSettingsBlockState`.
- **Key code names:** `PlanRecordLinkSuggestionSettingsBlock`, `PlanRecordLinkSuggestionSettingsBlockState`
- **Responsibilities:** Record→plan suggestion prefs
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Record→plan suggestion prefs
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `plan_record_link_settings.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `plan_record_link_settings` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `plan_record_link_settings.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `plan_record_link_settings.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `plan_record_link_settings` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/settings/planning_no_tags_settings.dart`

EN:

- **What this is:** `planning_no_tags_settings.dart` on Plans tab (second bottom tab) — Synthetic “No Tags” chip prefs.
- **Why needed:** Users see `planning_no_tags_settings.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningNoTagsSettingsBlock`, `PlanningNoTagsSettingsBlockState`.
- **Key code names:** `PlanningNoTagsSettingsBlock`, `PlanningNoTagsSettingsBlockState`
- **Responsibilities:** Synthetic “No Tags” chip prefs
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Synthetic “No Tags” chip prefs
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `planning_no_tags_settings.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `planning_no_tags_settings` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `planning_no_tags_settings.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `planning_no_tags_settings.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `planning_no_tags_settings` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/settings/planning_timeline_bounds_sheet.dart`

EN:

- **What this is:** `planning_timeline_bounds_sheet.dart` on Plans tab (second bottom tab) — Visible hour range slider sheet.
- **Why needed:** Users see `planning_timeline_bounds_sheet.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningTimelineBoundsSheet`, `PlanningTimelineBoundsSheetState`.
- **Key code names:** `PlanningTimelineBoundsSheet`, `PlanningTimelineBoundsSheetState`
- **Responsibilities:** Visible hour range slider sheet
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Visible hour range slider sheet
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `planning_timeline_bounds_sheet.dart` на вкладка Plans (вторая снизу) — Пользователь открывает sheet/dialog из entry `planning_timeline_bounds_sheet`..
- **Зачем:** Пользователь видит UI из `planning_timeline_bounds_sheet.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Основные символы: `PlanningTimelineBoundsSheet`, `PlanningTimelineBoundsSheetState`.
- **Обязанности:** Пользователь открывает sheet/dialog из entry `planning_timeline_bounds_sheet`.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/smart_plan_sheet.dart`

EN:

- **What this is:** `smart_plan_sheet.dart` on Plans tab (second bottom tab) — Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit.
- **Why needed:** Users see `smart_plan_sheet.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `SmartPlanCommit`, `SmartPlanSheet`, `_SmartPlanSheetState`.
- **Key code names:** `SmartPlanCommit`, `SmartPlanSheet`, `_SmartPlanSheetState`
- **Responsibilities:** Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `smart_plan_sheet.dart` на вкладка Plans (вторая снизу) — Пользователь открывает sheet/dialog из entry `smart_plan_sheet`..
- **Зачем:** Пользователь видит UI из `smart_plan_sheet.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Основные символы: `SmartPlanCommit`, `SmartPlanSheet`, `_SmartPlanSheetState`.
- **Обязанности:** Пользователь открывает sheet/dialog из entry `smart_plan_sheet`.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/time_view/planning_time_view.dart`

EN:

- **What this is:** `planning_time_view.dart` on Plans tab (second bottom tab) — Time View composition, cascade, edge scroll.
- **Why needed:** Users see `planning_time_view.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningTimeViewPlanningTimeView`.
- **Key code names:** `PlanningTimeViewPlanningTimeView`
- **Responsibilities:** Time View composition, cascade, edge scroll
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Time View composition, cascade, edge scroll
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `planning_time_view.dart` на вкладка Plans (вторая снизу) — Отвечает за видимый UI, собранный в `planning_time_view.dart`..
- **Зачем:** Пользователь видит UI из `planning_time_view.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Компоновка экрана и state в `planning_time_view.dart`.
- **Обязанности:** Отвечает за видимый UI, собранный в `planning_time_view.dart`.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/time_view/planning_time_view_coordinator.dart`

EN:

- **What this is:** `planning_time_view_coordinator.dart` on Plans tab (second bottom tab) — Time View state fields.
- **Why needed:** Users see `planning_time_view_coordinator.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningTimeViewCoordinator`.
- **Key code names:** `PlanningTimeViewCoordinator`
- **Responsibilities:** Time View state fields
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Time View state fields
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `planning_time_view_coordinator.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `planning_time_view_coordinator` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `planning_time_view_coordinator.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `planning_time_view_coordinator.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `planning_time_view_coordinator` в этой feature-зоне.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/time_view/planning_time_view_host.dart`

EN:

- **What this is:** `planning_time_view_host.dart` on Plans tab (second bottom tab) — PlanningTimeViewHost.
- **Why needed:** Users see `planning_time_view_host.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningTimeViewHost`.
- **Key code names:** `PlanningTimeViewHost`
- **Responsibilities:** PlanningTimeViewHost
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: `PlanningTimeViewHost` callback surface
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `planning_time_view_host.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `planning_time_view_host` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `planning_time_view_host.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `planning_time_view_host.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `planning_time_view_host` в этой feature-зоне.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/time_view/time_view_canvas.dart`

EN:

- **What this is:** `time_view_canvas.dart` on Plans tab (second bottom tab) — Proportional day timeline canvas.
- **Why needed:** Users see `time_view_canvas.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningTimeViewTimeViewCanvas`.
- **Key code names:** `PlanningTimeViewTimeViewCanvas`
- **Responsibilities:** Proportional day timeline canvas
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Proportional day timeline canvas
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `time_view_canvas.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `time_view_canvas` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `time_view_canvas.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `time_view_canvas.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `time_view_canvas` в этой feature-зоне.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/time_view/time_view_card_layer.dart`

EN:

- **What this is:** `time_view_card_layer.dart` on Plans tab (second bottom tab) — Scheduled card stack layer.
- **Why needed:** Users see `time_view_card_layer.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningTimeViewTimeViewCardLayer`.
- **Key code names:** `PlanningTimeViewTimeViewCardLayer`
- **Responsibilities:** Scheduled card stack layer
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Scheduled card stack layer
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `time_view_card_layer.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `time_view_card_layer` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `time_view_card_layer.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `time_view_card_layer.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `time_view_card_layer` в этой feature-зоне.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/time_view/time_view_drag_controller.dart`

EN:

- **What this is:** `time_view_drag_controller.dart` on Plans tab (second bottom tab) — Vertical drag state/helpers.
- **Why needed:** Users see `time_view_drag_controller.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningTimeViewTimeViewDragController`.
- **Key code names:** `PlanningTimeViewTimeViewDragController`
- **Responsibilities:** Vertical drag state/helpers
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Vertical drag state/helpers
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `time_view_drag_controller.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `time_view_drag_controller` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `time_view_drag_controller.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `time_view_drag_controller.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `time_view_drag_controller` в этой feature-зоне.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/time_view/time_view_drag_state.dart`

EN:

- **What this is:** `time_view_drag_state.dart` on Plans tab (second bottom tab) — TimelineResizeEdge.
- **Why needed:** Users see `time_view_drag_state.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `TimelineResizeEdge`, `TimelinePointerGesturePhase`.
- **Key code names:** `TimelineResizeEdge`, `TimelinePointerGesturePhase`
- **Responsibilities:** TimelineResizeEdge
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: `TimelineResizeEdge`, gesture phase enums
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `time_view_drag_state.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `time_view_drag_state` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `time_view_drag_state.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `time_view_drag_state.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `time_view_drag_state` в этой feature-зоне.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/time_view/time_view_drop_preview.dart`

EN:

- **What this is:** `time_view_drop_preview.dart` on Plans tab (second bottom tab) — Drop intent / cascade preview.
- **Why needed:** Users see `time_view_drop_preview.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningTimeViewTimeViewDropPreview`.
- **Key code names:** `PlanningTimeViewTimeViewDropPreview`
- **Responsibilities:** Drop intent / cascade preview
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Drop intent / cascade preview
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `time_view_drop_preview.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `time_view_drop_preview` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `time_view_drop_preview.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `time_view_drop_preview.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `time_view_drop_preview` в этой feature-зоне.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/time_view/time_view_fixed_time_settings.dart`

EN:

- **What this is:** `time_view_fixed_time_settings.dart` on Plans tab (second bottom tab) — Fixed-time tag chip settings block.
- **Why needed:** Users see `time_view_fixed_time_settings.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `TimeViewFixedTagsSettingsBlock`, `TimeViewFixedTagsSettingsBlockState`.
- **Key code names:** `TimeViewFixedTagsSettingsBlock`, `TimeViewFixedTagsSettingsBlockState`
- **Responsibilities:** Fixed-time tag chip settings block
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Fixed-time tag chip settings block
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `time_view_fixed_time_settings.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `time_view_fixed_time_settings` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `time_view_fixed_time_settings.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `time_view_fixed_time_settings.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `time_view_fixed_time_settings` в этой feature-зоне.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/time_view/time_view_hour_grid.dart`

EN:

- **What this is:** `time_view_hour_grid.dart` on Plans tab (second bottom tab) — Hour grid + unscheduled strip.
- **Why needed:** Users see `time_view_hour_grid.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningTimeViewTimeViewHourGrid`.
- **Key code names:** `PlanningTimeViewTimeViewHourGrid`
- **Responsibilities:** Hour grid + unscheduled strip
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Hour grid + unscheduled strip
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `time_view_hour_grid.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `time_view_hour_grid` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `time_view_hour_grid.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `time_view_hour_grid.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `time_view_hour_grid` в этой feature-зоне.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/time_view/time_view_interaction_block.dart`

EN:

- **What this is:** `time_view_interaction_block.dart` on Plans tab (second bottom tab) — Time View card pointer/drag/resize zones.
- **Why needed:** Users see `time_view_interaction_block.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `TimelinePlanInteractionBlock`, `TimelinePlanInteractionBlockState`, `TimelineResizeEdgeHandle`, `TimelineResizeEdgeHandleState`.
- **Key code names:** `TimelinePlanInteractionBlock`, `TimelinePlanInteractionBlockState`, `TimelineResizeEdgeHandle`, `TimelineResizeEdgeHandleState`
- **Responsibilities:** Time View card pointer/drag/resize zones
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Time View card pointer/drag/resize zones
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `time_view_interaction_block.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `time_view_interaction_block` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `time_view_interaction_block.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `time_view_interaction_block.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `time_view_interaction_block` в этой feature-зоне.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/time_view/time_view_resize_controller.dart`

EN:

- **What this is:** `time_view_resize_controller.dart` on Plans tab (second bottom tab) — Edge resize state/helpers.
- **Why needed:** Users see `time_view_resize_controller.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningTimeViewTimeViewResizeController`.
- **Key code names:** `PlanningTimeViewTimeViewResizeController`
- **Responsibilities:** Edge resize state/helpers
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Edge resize state/helpers
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `time_view_resize_controller.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `time_view_resize_controller` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `time_view_resize_controller.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `time_view_resize_controller.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `time_view_resize_controller` в этой feature-зоне.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/time_view/time_view_search_delegate.dart`

EN:

- **What this is:** `time_view_search_delegate.dart` on Plans tab (second bottom tab) — Category default-time search UI.
- **Why needed:** Users see `time_view_search_delegate.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningTimeViewTimeViewSearchDelegate`.
- **Key code names:** `PlanningTimeViewTimeViewSearchDelegate`
- **Responsibilities:** Category default-time search UI
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Category default-time search UI
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `time_view_search_delegate.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `time_view_search_delegate` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `time_view_search_delegate.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `time_view_search_delegate.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `time_view_search_delegate` в этой feature-зоне.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/time_view/time_view_settings_sheet.dart`

EN:

- **What this is:** `time_view_settings_sheet.dart` on Plans tab (second bottom tab) — Time View settings + default plan times.
- **Why needed:** Users see `time_view_settings_sheet.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningTimeViewTimeViewSettingsSheet`.
- **Key code names:** `PlanningTimeViewTimeViewSettingsSheet`
- **Responsibilities:** Time View settings + default plan times
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Time View settings + default plan times
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `time_view_settings_sheet.dart` на вкладка Plans (вторая снизу) — Пользователь открывает sheet/dialog из entry `time_view_settings_sheet`..
- **Зачем:** Пользователь видит UI из `time_view_settings_sheet.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Основные символы: `PlanningTimeViewTimeViewSettingsSheet`.
- **Обязанности:** Пользователь открывает sheet/dialog из entry `time_view_settings_sheet`.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/widgets/plan_card_reorder_settle.dart`

EN:

- **What this is:** `plan_card_reorder_settle.dart` on Plans tab (second bottom tab) — Done-card reorder slide settle.
- **Why needed:** Users see `plan_card_reorder_settle.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanCardReorderSettle`, `PlanCardReorderSettleState`.
- **Key code names:** `PlanCardReorderSettle`, `PlanCardReorderSettleState`
- **Responsibilities:** Done-card reorder slide settle
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Done-card reorder slide settle
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `plan_card_reorder_settle.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `plan_card_reorder_settle` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `plan_card_reorder_settle.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `plan_card_reorder_settle.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `plan_card_reorder_settle` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/widgets/planning_bulk_bar.dart`

EN:

- **What this is:** `planning_bulk_bar.dart` on Plans tab (second bottom tab) — Bulk selection bottom bar.
- **Why needed:** Users see `planning_bulk_bar.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningBulkBottomBar`.
- **Key code names:** `PlanningBulkBottomBar`
- **Responsibilities:** Bulk selection bottom bar
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Bulk selection bottom bar
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `planning_bulk_bar.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `planning_bulk_bar` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `planning_bulk_bar.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `planning_bulk_bar.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `planning_bulk_bar` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/widgets/planning_day_card_list_keep_alive.dart`

EN:

- **What this is:** `planning_day_card_list_keep_alive.dart` on Plans tab (second bottom tab) — List keep-alive wrapper.
- **Why needed:** Users see `planning_day_card_list_keep_alive.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningDayCardListKeepAliveState`.
- **Key code names:** `PlanningDayCardListKeepAliveState`
- **Responsibilities:** List keep-alive wrapper
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: List keep-alive wrapper
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `planning_day_card_list_keep_alive.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `planning_day_card_list_keep_alive` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `planning_day_card_list_keep_alive.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `planning_day_card_list_keep_alive.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `planning_day_card_list_keep_alive` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/widgets/planning_empty_states.dart`

EN:

- **What this is:** `planning_empty_states.dart` on Plans tab (second bottom tab) — Planning empty-state widgets.
- **Why needed:** Users see `planning_empty_states.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningDayEmptyState`, `PlanningFrozenListEmptyState`.
- **Key code names:** `PlanningDayEmptyState`, `PlanningFrozenListEmptyState`
- **Responsibilities:** Planning empty-state widgets
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Planning empty-state widgets
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `planning_empty_states.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `planning_empty_states` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `planning_empty_states.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `planning_empty_states.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `planning_empty_states` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/widgets/planning_filter_controls.dart`

EN:

- **What this is:** `planning_filter_controls.dart` on Plans tab (second bottom tab) — Sort-mode segmented control.
- **Why needed:** Users see `planning_filter_controls.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningSortModeBar`.
- **Key code names:** `PlanningSortModeBar`
- **Responsibilities:** Sort-mode segmented control
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Sort-mode segmented control
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `planning_filter_controls.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `planning_filter_controls` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `planning_filter_controls.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `planning_filter_controls.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `planning_filter_controls` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/widgets/planning_list_helpers.dart`

EN:

- **What this is:** `planning_list_helpers.dart` on Plans tab (second bottom tab) — Reorder list proxy decorator.
- **Why needed:** Users see `planning_list_helpers.dart` when using Plans tab (second bottom tab).
- **What it contains:** Dart module `planning_list_helpers.dart` — open file for classes and helpers.
- **Responsibilities:** Reorder list proxy decorator
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Reorder list proxy decorator
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `planning_list_helpers.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `planning_list_helpers` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `planning_list_helpers.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `planning_list_helpers.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `planning_list_helpers` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/widgets/planning_menu_overlay.dart`

EN:

- **What this is:** `planning_menu_overlay.dart` on Plans tab (second bottom tab) — Semicircle plan card radial menu.
- **Why needed:** Users see `planning_menu_overlay.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `SemicirclePlanningMenuOverlay`, `SemicirclePlanningMenuOverlayState`.
- **Key code names:** `SemicirclePlanningMenuOverlay`, `SemicirclePlanningMenuOverlayState`
- **Responsibilities:** Semicircle plan card radial menu
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Semicircle plan card radial menu
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `planning_menu_overlay.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `planning_menu_overlay` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `planning_menu_overlay.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `planning_menu_overlay.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `planning_menu_overlay` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/planning/widgets/planning_quick_add_strip.dart`

EN:

- **What this is:** `planning_quick_add_strip.dart` on Plans tab (second bottom tab) — Quick-add tag strip above inline task field.
- **Why needed:** Users see `planning_quick_add_strip.dart` when using Plans tab (second bottom tab).
- **What it contains:** Primary symbols: `PlanningQuickAddTagStrip`.
- **Key code names:** `PlanningQuickAddTagStrip`
- **Responsibilities:** Quick-add tag strip above inline task field
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); APP_STRUCTURE role: Quick-add tag strip above inline task field
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** `planning_quick_add_strip.dart` на вкладка Plans (вторая снизу) — Поддерживает поведение `planning_quick_add_strip` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `planning_quick_add_strip.dart` на вкладка Plans (вторая снизу).
- **Содержимое:** Dart-модуль `planning_quick_add_strip.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `planning_quick_add_strip` в этой feature-зоне.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Plans (shell index 1)
- **Слой:** UI — экран/виджет (planning).


### `lib/features/profile/desktop_voice_attempt_dialog.dart`

EN:

- **What this is:** `desktop_voice_attempt_dialog.dart` on More → Profile and settings — Profile & tag settings, timezone, desktop voice settings (Windows).
- **Why needed:** Users see `desktop_voice_attempt_dialog.dart` when using More → Profile and settings.
- **What it contains:** Primary symbols: `DesktopVoiceAttemptCopyFn`, `DesktopVoiceAttemptDialogTestHooks`, `_DesktopVoiceAttemptDialog`, `_DesktopVoiceAttemptDialogState`, `_AttemptView`, `_StatusHeader`.
- **Key code names:** `DesktopVoiceAttemptCopyFn`, `DesktopVoiceAttemptDialogTestHooks`, `_DesktopVoiceAttemptDialog`, `_DesktopVoiceAttemptDialogState`, `_AttemptView`, `_StatusHeader`
- **Responsibilities:** Profile & tag settings, timezone, desktop voice settings (Windows)
- **When to open:** When behavior tied to `desktop_voice_attempt_dialog.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Profile & tag settings, timezone, desktop voice settings (Windows)
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** `desktop_voice_attempt_dialog.dart` на More → Profile и настройки — Пользователь открывает sheet/dialog из entry `desktop_voice_attempt_dialog`..
- **Зачем:** Пользователь видит UI из `desktop_voice_attempt_dialog.dart` на More → Profile и настройки.
- **Содержимое:** Основные символы: `DesktopVoiceAttemptCopyFn`, `DesktopVoiceAttemptDialogTestHooks`, `_DesktopVoiceAttemptDialog`, `_DesktopVoiceAttemptDialogState`, `_AttemptView`, `_StatusHeader`.
- **Обязанности:** Пользователь открывает sheet/dialog из entry `desktop_voice_attempt_dialog`.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_attempt_dialog.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/profile/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (profile).


### `lib/features/profile/desktop_voice_settings_desktop.dart`

EN:

- **What this is:** `desktop_voice_settings_desktop.dart` on More → Profile and settings — Profile & tag settings, timezone, desktop voice settings (Windows).
- **Why needed:** Users see `desktop_voice_settings_desktop.dart` when using More → Profile and settings.
- **What it contains:** Primary symbols: `DesktopVoiceSettingsDesktopGrid`, `_DesktopVoiceSettingsDesktopGridState`, `_HeroIconTile`.
- **Key code names:** `DesktopVoiceSettingsDesktopGrid`, `_DesktopVoiceSettingsDesktopGridState`, `_HeroIconTile`
- **Responsibilities:** Profile & tag settings, timezone, desktop voice settings (Windows)
- **When to open:** When behavior tied to `desktop_voice_settings_desktop.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Profile & tag settings, timezone, desktop voice settings (Windows)
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** `desktop_voice_settings_desktop.dart` на More → Profile и настройки — Поддерживает поведение `desktop_voice_settings_desktop` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `desktop_voice_settings_desktop.dart` на More → Profile и настройки.
- **Содержимое:** Dart-модуль `desktop_voice_settings_desktop.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `desktop_voice_settings_desktop` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_settings_desktop.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/profile/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (profile).


### `lib/features/profile/desktop_voice_settings_section.dart`

EN:

- **What this is:** `desktop_voice_settings_section.dart` on More → Profile and settings — Profile & tag settings, timezone, desktop voice settings (Windows).
- **Why needed:** Users see `desktop_voice_settings_section.dart` when using More → Profile and settings.
- **What it contains:** Primary symbols: `DesktopVoiceSettingsSection`, `_DesktopVoiceSettingsSectionState`, `HotkeyCaptureDialog`, `_HotkeyCaptureDialogState`.
- **Key code names:** `DesktopVoiceSettingsSection`, `_DesktopVoiceSettingsSectionState`, `HotkeyCaptureDialog`, `_HotkeyCaptureDialogState`
- **Responsibilities:** Profile & tag settings, timezone, desktop voice settings (Windows)
- **When to open:** When behavior tied to `desktop_voice_settings_section.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Profile & tag settings, timezone, desktop voice settings (Windows)
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** `desktop_voice_settings_section.dart` на More → Profile и настройки — Поддерживает поведение `desktop_voice_settings_section` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `desktop_voice_settings_section.dart` на More → Profile и настройки.
- **Содержимое:** Dart-модуль `desktop_voice_settings_section.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `desktop_voice_settings_section` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_settings_section.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/profile/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (profile).


### `lib/features/profile/profile_view.dart`

EN:

- **What this is:** `profile_view.dart` on More → Profile and settings — Profile & tag settings, timezone, desktop voice settings (Windows).
- **Why needed:** Users see `profile_view.dart` when using More → Profile and settings.
- **What it contains:** Primary symbols: `ProfilePage`, `_ProfilePageState`.
- **Key code names:** `ProfilePage`, `_ProfilePageState`
- **Responsibilities:** Profile & tag settings, timezone, desktop voice settings (Windows)
- **When to open:** When behavior tied to `profile_view.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Profile & tag settings, timezone, desktop voice settings (Windows)
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** `profile_view.dart` на More → Profile и настройки — Отвечает за видимый UI, собранный в `profile_view.dart`..
- **Зачем:** Пользователь видит UI из `profile_view.dart` на More → Profile и настройки.
- **Содержимое:** Компоновка экрана и state в `profile_view.dart`.
- **Обязанности:** Отвечает за видимый UI, собранный в `profile_view.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `profile_view.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/profile/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (profile).


### `lib/features/profile/settings/account_settings_section.dart`

EN:

- **What this is:** `account_settings_section.dart` on More → Profile and settings — Signed-in identity + logout row.
- **Why needed:** Users see `account_settings_section.dart` when using More → Profile and settings.
- **What it contains:** Primary symbols: `AccountSecuritySection`.
- **Key code names:** `AccountSecuritySection`
- **Responsibilities:** Signed-in identity + logout row
- **When to open:** When behavior tied to `account_settings_section.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Signed-in identity + logout row
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** `account_settings_section.dart` на More → Profile и настройки — Поддерживает поведение `account_settings_section` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `account_settings_section.dart` на More → Profile и настройки.
- **Содержимое:** Dart-модуль `account_settings_section.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `account_settings_section` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `account_settings_section.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/profile/settings/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (profile).


### `lib/features/profile/settings/notification_settings_section.dart`

EN:

- **What this is:** `notification_settings_section.dart` on More → Profile and settings — OS notification permission block.
- **Why needed:** Users see `notification_settings_section.dart` when using More → Profile and settings.
- **What it contains:** Primary symbols: `ProfileNotificationsSection`, `ProfileNotificationsSectionState`.
- **Key code names:** `ProfileNotificationsSection`, `ProfileNotificationsSectionState`
- **Responsibilities:** OS notification permission block
- **When to open:** When behavior tied to `notification_settings_section.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: OS notification permission block
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** `notification_settings_section.dart` на More → Profile и настройки — Поддерживает поведение `notification_settings_section` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `notification_settings_section.dart` на More → Profile и настройки.
- **Содержимое:** Dart-модуль `notification_settings_section.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `notification_settings_section` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `notification_settings_section.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/profile/settings/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (profile).


### `lib/features/profile/settings/security_settings_section.dart`

EN:

- **What this is:** `security_settings_section.dart` on More → Profile and settings — Password reset + biometric lock.
- **Why needed:** Users see `security_settings_section.dart` when using More → Profile and settings.
- **What it contains:** Primary symbols: `SecuritySection`, `SecuritySectionState`.
- **Key code names:** `SecuritySection`, `SecuritySectionState`
- **Responsibilities:** Password reset + biometric lock
- **When to open:** When behavior tied to `security_settings_section.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Password reset + biometric lock
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** `security_settings_section.dart` на More → Profile и настройки — Поддерживает поведение `security_settings_section` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `security_settings_section.dart` на More → Profile и настройки.
- **Содержимое:** Dart-модуль `security_settings_section.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `security_settings_section` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `security_settings_section.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/profile/settings/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (profile).


### `lib/features/profile/settings/settings_page.dart`

EN:

- **What this is:** Barrel `settings_page.dart` for More → Profile and settings — re-exports entry modules.
- **Why needed:** Users see `settings_page.dart` when using More → Profile and settings.
- **What it contains:** Barrel `export` lines: `settings_page.dart`.
- **Responsibilities:** Language/TZ settings page (shell route)
- **When to open:** When behavior tied to `settings_page.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Language/TZ settings page (shell route)
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** `settings_page.dart` на More → Profile и настройки — Отвечает за видимый UI, собранный в `settings_page.dart`..
- **Зачем:** Пользователь видит UI из `settings_page.dart` на More → Profile и настройки.
- **Содержимое:** Компоновка экрана и state в `settings_page.dart`.
- **Обязанности:** Отвечает за видимый UI, собранный в `settings_page.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `settings_page.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/profile/settings/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (profile).


### `lib/features/profile/tag_default_duration_settings_view.dart`

EN:

- **What this is:** `tag_default_duration_settings_view.dart` on More → Profile and settings — Profile & tag settings, timezone, desktop voice settings (Windows).
- **Why needed:** Users see `tag_default_duration_settings_view.dart` when using More → Profile and settings.
- **What it contains:** Primary symbols: `TagDefaultDurationSettingsView`, `_TagDefaultDurationSettingsViewState`.
- **Key code names:** `TagDefaultDurationSettingsView`, `_TagDefaultDurationSettingsViewState`
- **Responsibilities:** Profile & tag settings, timezone, desktop voice settings (Windows)
- **When to open:** When behavior tied to `tag_default_duration_settings_view.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Profile & tag settings, timezone, desktop voice settings (Windows)
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** `tag_default_duration_settings_view.dart` на More → Profile и настройки — Отвечает за видимый UI, собранный в `tag_default_duration_settings_view.dart`..
- **Зачем:** Пользователь видит UI из `tag_default_duration_settings_view.dart` на More → Profile и настройки.
- **Содержимое:** Компоновка экрана и state в `tag_default_duration_settings_view.dart`.
- **Обязанности:** Отвечает за видимый UI, собранный в `tag_default_duration_settings_view.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `tag_default_duration_settings_view.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/profile/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (profile).


### `lib/features/profile/tag_manager_page.dart`

EN:

- **What this is:** `tag_manager_page.dart` on More → Profile and settings — Profile & tag settings, timezone, desktop voice settings (Windows).
- **Why needed:** Users see `tag_manager_page.dart` when using More → Profile and settings.
- **What it contains:** Primary symbols: `TagManagerPage`, `_TagManagerPageState`.
- **Key code names:** `TagManagerPage`, `_TagManagerPageState`
- **Responsibilities:** Profile & tag settings, timezone, desktop voice settings (Windows)
- **When to open:** When behavior tied to `tag_manager_page.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Profile & tag settings, timezone, desktop voice settings (Windows)
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** `tag_manager_page.dart` на More → Profile и настройки — Отвечает за видимый UI, собранный в `tag_manager_page.dart`..
- **Зачем:** Пользователь видит UI из `tag_manager_page.dart` на More → Profile и настройки.
- **Содержимое:** Компоновка экрана и state в `tag_manager_page.dart`.
- **Обязанности:** Отвечает за видимый UI, собранный в `tag_manager_page.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `tag_manager_page.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/profile/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (profile).


### `lib/features/profile/tag_settings_hub.dart`

EN:

- **What this is:** `tag_settings_hub.dart` on More → Profile and settings — Profile & tag settings, timezone, desktop voice settings (Windows).
- **Why needed:** Users see `tag_settings_hub.dart` when using More → Profile and settings.
- **What it contains:** Primary symbols: `TagSettingsHub`, `_TagSettingsHubState`.
- **Key code names:** `TagSettingsHub`, `_TagSettingsHubState`
- **Responsibilities:** Profile & tag settings, timezone, desktop voice settings (Windows)
- **When to open:** When behavior tied to `tag_settings_hub.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Profile & tag settings, timezone, desktop voice settings (Windows)
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** `tag_settings_hub.dart` на More → Profile и настройки — Поддерживает поведение `tag_settings_hub` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `tag_settings_hub.dart` на More → Profile и настройки.
- **Содержимое:** Dart-модуль `tag_settings_hub.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `tag_settings_hub` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `tag_settings_hub.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/profile/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (profile).


### `lib/features/profile/tag_settings_view.dart`

EN:

- **What this is:** `tag_settings_view.dart` on More → Profile and settings — Profile & tag settings, timezone, desktop voice settings (Windows).
- **Why needed:** Users see `tag_settings_view.dart` when using More → Profile and settings.
- **What it contains:** Primary symbols: `TagSettingsView`, `_TagSettingsViewState`.
- **Key code names:** `TagSettingsView`, `_TagSettingsViewState`
- **Responsibilities:** Profile & tag settings, timezone, desktop voice settings (Windows)
- **When to open:** When behavior tied to `tag_settings_view.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Profile & tag settings, timezone, desktop voice settings (Windows)
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** `tag_settings_view.dart` на More → Profile и настройки — Отвечает за видимый UI, собранный в `tag_settings_view.dart`..
- **Зачем:** Пользователь видит UI из `tag_settings_view.dart` на More → Profile и настройки.
- **Содержимое:** Компоновка экрана и state в `tag_settings_view.dart`.
- **Обязанности:** Отвечает за видимый UI, собранный в `tag_settings_view.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `tag_settings_view.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/profile/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (profile).


### `lib/features/profile/timezone_settings.dart`

EN:

- **What this is:** `timezone_settings.dart` on More → Profile and settings — Profile & tag settings, timezone, desktop voice settings (Windows).
- **Why needed:** Users see `timezone_settings.dart` when using More → Profile and settings.
- **What it contains:** Primary symbols: `TimezoneOption`.
- **Key code names:** `TimezoneOption`
- **Responsibilities:** Profile & tag settings, timezone, desktop voice settings (Windows)
- **When to open:** When behavior tied to `timezone_settings.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Profile & tag settings, timezone, desktop voice settings (Windows)
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** `timezone_settings.dart` на More → Profile и настройки — Поддерживает поведение `timezone_settings` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `timezone_settings.dart` на More → Profile и настройки.
- **Содержимое:** Dart-модуль `timezone_settings.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `timezone_settings` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `timezone_settings.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/profile/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (profile).


### `lib/features/shared/activity_detail_sheet.dart`

EN:

- **What this is:** `activity_detail_sheet.dart` on edit sheets and voice UI on every tab — ActivityDetailKind.
- **Why needed:** Users see `activity_detail_sheet.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Primary symbols: `ActivityDetailKind`, `ActivityDetailSheet`.
- **Key code names:** `ActivityDetailKind`, `ActivityDetailSheet`
- **Responsibilities:** ActivityDetailKind
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: Edit sheet router (`ActivityDetailKind`)
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `activity_detail_sheet.dart` на edit sheets и voice UI на всех вкладках — Пользователь открывает sheet/dialog из entry `activity_detail_sheet`..
- **Зачем:** Пользователь видит UI из `activity_detail_sheet.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Основные символы: `ActivityDetailKind`, `ActivityDetailSheet`.
- **Обязанности:** Пользователь открывает sheet/dialog из entry `activity_detail_sheet`.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/desktop_voice_capsule.dart`

EN:

- **What this is:** `desktop_voice_capsule.dart` on edit sheets and voice UI on every tab — Activity edit sheets, Omni-Picker entry, offline sync banner, mobile/web voice sheet, desktop Price Reporter voice UI.
- **Why needed:** Users see `desktop_voice_capsule.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Primary symbols: `DesktopVoiceCapsule`, `_LeadingIcon`.
- **Key code names:** `DesktopVoiceCapsule`, `_LeadingIcon`
- **Responsibilities:** Activity edit sheets, Omni-Picker entry, offline sync banner, mobile/web voice sheet, desktop Price Reporter voice UI
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: Activity edit sheets, Omni-Picker entry, offline sync banner, mobile/web voice sheet, desktop Price Reporter voice UI
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `desktop_voice_capsule.dart` на edit sheets и voice UI на всех вкладках — Поддерживает поведение `desktop_voice_capsule` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `desktop_voice_capsule.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Dart-модуль `desktop_voice_capsule.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `desktop_voice_capsule` в этой feature-зоне.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/desktop_voice_command_panel.dart`

EN:

- **What this is:** `desktop_voice_command_panel.dart` on edit sheets and voice UI on every tab — Activity edit sheets, Omni-Picker entry, offline sync banner, mobile/web voice sheet, desktop Price Reporter voice UI.
- **Why needed:** Users see `desktop_voice_command_panel.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Primary symbols: `_DesktopVoicePanelPhase`, `DesktopVoiceCommandPanel`, `_DesktopVoiceCommandPanelState`.
- **Key code names:** `_DesktopVoicePanelPhase`, `DesktopVoiceCommandPanel`, `_DesktopVoiceCommandPanelState`
- **Responsibilities:** Activity edit sheets, Omni-Picker entry, offline sync banner, mobile/web voice sheet, desktop Price Reporter voice UI
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: Activity edit sheets, Omni-Picker entry, offline sync banner, mobile/web voice sheet, desktop Price Reporter voice UI
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `desktop_voice_command_panel.dart` на edit sheets и voice UI на всех вкладках — Поддерживает поведение `desktop_voice_command_panel` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `desktop_voice_command_panel.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Dart-модуль `desktop_voice_command_panel.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `desktop_voice_command_panel` в этой feature-зоне.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/desktop_voice_widget.dart`

EN:

- **What this is:** `desktop_voice_widget.dart` on edit sheets and voice UI on every tab — Activity edit sheets, Omni-Picker entry, offline sync banner, mobile/web voice sheet, desktop Price Reporter voice UI.
- **Why needed:** Users see `desktop_voice_widget.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Primary symbols: `DesktopVoiceOverlayPhase`, `DesktopVoiceOverlay`, `_DesktopVoiceOverlayState`.
- **Key code names:** `DesktopVoiceOverlayPhase`, `DesktopVoiceOverlay`, `_DesktopVoiceOverlayState`
- **Responsibilities:** Activity edit sheets, Omni-Picker entry, offline sync banner, mobile/web voice sheet, desktop Price Reporter voice UI
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: Activity edit sheets, Omni-Picker entry, offline sync banner, mobile/web voice sheet, desktop Price Reporter voice UI
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `desktop_voice_widget.dart` на edit sheets и voice UI на всех вкладках — Поддерживает поведение `desktop_voice_widget` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `desktop_voice_widget.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Dart-модуль `desktop_voice_widget.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `desktop_voice_widget` в этой feature-зоне.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/edit_sheet/checklist_helpers.dart`

EN:

- **What this is:** `checklist_helpers.dart` on edit sheets and voice UI on every tab — Checklist row sync/partition helpers.
- **Why needed:** Users see `checklist_helpers.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Dart module `checklist_helpers.dart` — open file for classes and helpers.
- **Responsibilities:** Checklist row sync/partition helpers
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: Checklist row sync/partition helpers
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `checklist_helpers.dart` на edit sheets и voice UI на всех вкладках — Поддерживает поведение `checklist_helpers` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `checklist_helpers.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Dart-модуль `checklist_helpers.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `checklist_helpers` в этой feature-зоне.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/edit_sheet/parallel_record_panels.dart`

EN:

- **What this is:** `parallel_record_panels.dart` on edit sheets and voice UI on every tab — Backlog sub-items + parallel child panels.
- **Why needed:** Users see `parallel_record_panels.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Primary symbols: `BacklogSubItemsPanel`, `BacklogSubItemsPanelState`, `ParallelActivitiesTab`, `ParallelActivitiesTabState`.
- **Key code names:** `BacklogSubItemsPanel`, `BacklogSubItemsPanelState`, `ParallelActivitiesTab`, `ParallelActivitiesTabState`
- **Responsibilities:** Backlog sub-items + parallel child panels
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: Backlog sub-items + parallel child panels
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `parallel_record_panels.dart` на edit sheets и voice UI на всех вкладках — Поддерживает поведение `parallel_record_panels` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `parallel_record_panels.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Dart-модуль `parallel_record_panels.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `parallel_record_panels` в этой feature-зоне.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/edit_sheet/plan_repeat_helpers.dart`

EN:

- **What this is:** `plan_repeat_helpers.dart` on edit sheets and voice UI on every tab — RRULE ↔ UI repeat preset helpers.
- **Why needed:** Users see `plan_repeat_helpers.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Dart module `plan_repeat_helpers.dart` — open file for classes and helpers.
- **Responsibilities:** RRULE ↔ UI repeat preset helpers
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: RRULE ↔ UI repeat preset helpers
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `plan_repeat_helpers.dart` на edit sheets и voice UI на всех вкладках — Поддерживает поведение `plan_repeat_helpers` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `plan_repeat_helpers.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Dart-модуль `plan_repeat_helpers.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `plan_repeat_helpers` в этой feature-зоне.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/edit_sheet/quill_link_launcher.dart`

EN:

- **What this is:** `quill_link_launcher.dart` on edit sheets and voice UI on every tab — Quill note external URL launcher.
- **Why needed:** Users see `quill_link_launcher.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Dart module `quill_link_launcher.dart` — open file for classes and helpers.
- **Responsibilities:** Quill note external URL launcher
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: Quill note external URL launcher
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `quill_link_launcher.dart` на edit sheets и voice UI на всех вкладках — Поддерживает поведение `quill_link_launcher` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `quill_link_launcher.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Dart-модуль `quill_link_launcher.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `quill_link_launcher` в этой feature-зоне.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/edit_sheet/quill_toolbar_config.dart`

EN:

- **What this is:** `quill_toolbar_config.dart` on edit sheets and voice UI on every tab — Planning edit Quill toolbar config.
- **Why needed:** Users see `quill_toolbar_config.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Dart module `quill_toolbar_config.dart` — open file for classes and helpers.
- **Responsibilities:** Planning edit Quill toolbar config
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: Planning edit Quill toolbar config
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `quill_toolbar_config.dart` на edit sheets и voice UI на всех вкладках — Поддерживает поведение `quill_toolbar_config` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `quill_toolbar_config.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Dart-модуль `quill_toolbar_config.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `quill_toolbar_config` в этой feature-зоне.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/edit_sheet/sheet_autosave_gate.dart`

EN:

- **What this is:** `sheet_autosave_gate.dart` on edit sheets and voice UI on every tab — Debounced edit-sheet autosave gate.
- **Why needed:** Users see `sheet_autosave_gate.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Primary symbols: `EditSheetAutosaveGate`.
- **Key code names:** `EditSheetAutosaveGate`
- **Responsibilities:** Debounced edit-sheet autosave gate
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: Debounced edit-sheet autosave gate
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `sheet_autosave_gate.dart` на edit sheets и voice UI на всех вкладках — Поддерживает поведение `sheet_autosave_gate` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `sheet_autosave_gate.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Dart-модуль `sheet_autosave_gate.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `sheet_autosave_gate` в этой feature-зоне.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/edit_sheet/sheet_time_helpers.dart`

EN:

- **What this is:** `sheet_time_helpers.dart` on edit sheets and voice UI on every tab — UTC/display time format helpers.
- **Why needed:** Users see `sheet_time_helpers.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Dart module `sheet_time_helpers.dart` — open file for classes and helpers.
- **Responsibilities:** UTC/display time format helpers
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: UTC/display time format helpers
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `sheet_time_helpers.dart` на edit sheets и voice UI на всех вкладках — Поддерживает поведение `sheet_time_helpers` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `sheet_time_helpers.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Dart-модуль `sheet_time_helpers.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `sheet_time_helpers` в этой feature-зоне.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/edit_sheet/sheet_time_picker.dart`

EN:

- **What this is:** `sheet_time_picker.dart` on edit sheets and voice UI on every tab — showAppDateTimePicker, AppEditSheetTimeButton.
- **Why needed:** Users see `sheet_time_picker.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Primary symbols: `AppEditSheetTimeButton`.
- **Key code names:** `AppEditSheetTimeButton`
- **Responsibilities:** showAppDateTimePicker, AppEditSheetTimeButton
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: `showAppDateTimePicker`, `AppEditSheetTimeButton`
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `sheet_time_picker.dart` на edit sheets и voice UI на всех вкладках — Поддерживает поведение `sheet_time_picker` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `sheet_time_picker.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Dart-модуль `sheet_time_picker.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `sheet_time_picker` в этой feature-зоне.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/empty_state_placeholder.dart`

EN:

- **What this is:** `empty_state_placeholder.dart` on edit sheets and voice UI on every tab — Shared empty-state placeholder.
- **Why needed:** Users see `empty_state_placeholder.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Dart module `empty_state_placeholder.dart` — open file for classes and helpers.
- **Responsibilities:** Shared empty-state placeholder
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: Shared empty-state placeholder
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `empty_state_placeholder.dart` на edit sheets и voice UI на всех вкладках — Поддерживает поведение `empty_state_placeholder` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `empty_state_placeholder.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Dart-модуль `empty_state_placeholder.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `empty_state_placeholder` в этой feature-зоне.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/offline_sync_status_bar.dart`

EN:

- **What this is:** `offline_sync_status_bar.dart` on edit sheets and voice UI on every tab — O1 offline/sync tap-to-retry banner.
- **Why needed:** Users see `offline_sync_status_bar.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Primary symbols: `OfflineSyncStatusBar`, `OfflineSyncStatusBarState`.
- **Key code names:** `OfflineSyncStatusBar`, `OfflineSyncStatusBarState`
- **Responsibilities:** O1 offline/sync tap-to-retry banner
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: O1 offline/sync tap-to-retry banner
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `offline_sync_status_bar.dart` на edit sheets и voice UI на всех вкладках — Поддерживает поведение `offline_sync_status_bar` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `offline_sync_status_bar.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Dart-модуль `offline_sync_status_bar.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `offline_sync_status_bar` в этой feature-зоне.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/planning_task_edit_sheet.dart`

EN:

- **What this is:** `planning_task_edit_sheet.dart` on edit sheets and voice UI on every tab — Plan/list task edit sheet.
- **Why needed:** Users see `planning_task_edit_sheet.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Primary symbols: `PlanningTaskEditSheetState`.
- **Key code names:** `PlanningTaskEditSheetState`
- **Responsibilities:** Plan/list task edit sheet
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: Plan/list task edit sheet
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `planning_task_edit_sheet.dart` на edit sheets и voice UI на всех вкладках — Пользователь открывает sheet/dialog из entry `planning_task_edit_sheet`..
- **Зачем:** Пользователь видит UI из `planning_task_edit_sheet.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Основные символы: `PlanningTaskEditSheetState`.
- **Обязанности:** Пользователь открывает sheet/dialog из entry `planning_task_edit_sheet`.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/profile_hydration_status_bar.dart`

EN:

- **What this is:** Barrel `profile_hydration_status_bar.dart` for edit sheets and voice UI on every tab — re-exports entry modules.
- **Why needed:** Users see `profile_hydration_status_bar.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Barrel `export` lines: `profile_hydration_status_bar.dart`.
- **Responsibilities:** Profile hydration error banner
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: Profile hydration error banner
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `profile_hydration_status_bar.dart` на edit sheets и voice UI на всех вкладках — Поддерживает поведение `profile_hydration_status_bar` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `profile_hydration_status_bar.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Dart-модуль `profile_hydration_status_bar.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `profile_hydration_status_bar` в этой feature-зоне.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/shared_widgets.dart`

EN:

- **What this is:** Barrel `shared_widgets.dart` for edit sheets and voice UI on every tab — re-exports entry modules.
- **Why needed:** Users see `shared_widgets.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Barrel `export` lines: `activity_detail_sheet.dart`, `empty_state_placeholder.dart`, `planning_task_edit_sheet.dart`, `timeline_record_edit_sheet.dart`, `checklist_helpers.dart`.
- **Responsibilities:** Activity edit sheets, Omni-Picker entry, offline sync banner, mobile/web voice sheet, desktop Price Reporter voice UI
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: Activity edit sheets, Omni-Picker entry, offline sync banner, mobile/web voice sheet, desktop Price Reporter voice UI
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `shared_widgets.dart` на edit sheets и voice UI на всех вкладках — Поддерживает поведение `shared_widgets` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `shared_widgets.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Dart-модуль `shared_widgets.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `shared_widgets` в этой feature-зоне.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/timeline_record_edit_sheet.dart`

EN:

- **What this is:** `timeline_record_edit_sheet.dart` on edit sheets and voice UI on every tab — Timeline record edit sheet.
- **Why needed:** Users see `timeline_record_edit_sheet.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Primary symbols: `TimelineRecordSheetContentState`.
- **Key code names:** `TimelineRecordSheetContentState`
- **Responsibilities:** Timeline record edit sheet
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: Timeline record edit sheet
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `timeline_record_edit_sheet.dart` на edit sheets и voice UI на всех вкладках — Пользователь открывает sheet/dialog из entry `timeline_record_edit_sheet`..
- **Зачем:** Пользователь видит UI из `timeline_record_edit_sheet.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Основные символы: `TimelineRecordSheetContentState`.
- **Обязанности:** Пользователь открывает sheet/dialog из entry `timeline_record_edit_sheet`.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/voice_capture_config.dart`

EN:

- **What this is:** `voice_capture_config.dart` on edit sheets and voice UI on every tab — Activity edit sheets, Omni-Picker entry, offline sync banner, mobile/web voice sheet, desktop Price Reporter voice UI.
- **Why needed:** Users see `voice_capture_config.dart` when using edit sheets and voice UI on every tab.
- **What it contains:** Primary symbols: `VoiceCaptureConfig`.
- **Key code names:** `VoiceCaptureConfig`
- **Responsibilities:** Activity edit sheets, Omni-Picker entry, offline sync banner, mobile/web voice sheet, desktop Price Reporter voice UI
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: Activity edit sheets, Omni-Picker entry, offline sync banner, mobile/web voice sheet, desktop Price Reporter voice UI
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** `voice_capture_config.dart` на edit sheets и voice UI на всех вкладках — Поддерживает поведение `voice_capture_config` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `voice_capture_config.dart` на edit sheets и voice UI на всех вкладках.
- **Содержимое:** Dart-модуль `voice_capture_config.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `voice_capture_config` в этой feature-зоне.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/shared/voice_input_sheet.dart`

EN:

- **What this is:** Mobile/web mic bottom sheet — speech-to-text capture routed by `VoiceCaptureConfig`.
- **Why needed:** Voice submit on Timeline, Plans, and Lists opens this sheet; must not block main thread.
- **What it contains:** `VoiceInputSheet`, `_VoiceInputSheetState`; STT engine handle, permission prompts.
- **Key code names:** `VoiceInputSheet`, `_VoiceInputSheetState`
- **Responsibilities:** Listen/transcribe user speech; return text to shell voice routing.
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Edit sheets and voice UI on every tab; APP_STRUCTURE role: Activity edit sheets, Omni-Picker entry, offline sync banner, mobile/web voice sheet, desktop Price Reporter voice UI
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Нижняя шторка микрофона (mobile/web) — speech-to-text по `VoiceCaptureConfig`.
- **Зачем:** Voice submit на Timeline, Plans и Lists открывает эту шторку; не блокирует main thread.
- **Содержимое:** `VoiceInputSheet`, `_VoiceInputSheetState`; STT handle, запрос permissions.
- **Обязанности:** Слушает/транскрибирует речь; отдаёт текст в shell voice routing.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Edit sheets и voice UI на всех вкладках
- **Слой:** UI — экран/виджет (shared).


### `lib/features/stats/plan_vs_fact_tab.dart`

EN:

- **What this is:** `plan_vs_fact_tab.dart` on stats panel inside Timeline — Productivity stats (embedded in Timeline).
- **Why needed:** Users see `plan_vs_fact_tab.dart` when using stats panel inside Timeline.
- **What it contains:** Primary symbols: `PlanVsFactTab`, `_PlanVsFactTabState`, `_PlanFactSummaryRow`, `_PlanFactOrphanCategoryRow`.
- **Key code names:** `PlanVsFactTab`, `_PlanVsFactTabState`, `_PlanFactSummaryRow`, `_PlanFactOrphanCategoryRow`
- **Responsibilities:** Productivity stats (embedded in Timeline)
- **When to open:** When behavior tied to `plan_vs_fact_tab.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Productivity stats (embedded in Timeline)
- **Layer / owner:** UI code for the stats area of the app (what users see and tap).

RU:

- **Что это:** `plan_vs_fact_tab.dart` на панель stats внутри Timeline — Поддерживает поведение `plan_vs_fact_tab` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `plan_vs_fact_tab.dart` на панель stats внутри Timeline.
- **Содержимое:** Dart-модуль `plan_vs_fact_tab.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `plan_vs_fact_tab` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_vs_fact_tab.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/stats/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (stats).


### `lib/features/stats/stats_view.dart`

EN:

- **What this is:** `stats_view.dart` on stats panel inside Timeline — Productivity stats (embedded in Timeline).
- **Why needed:** Users see `stats_view.dart` when using stats panel inside Timeline.
- **What it contains:** Primary symbols: `StatsView`, `_StatsViewState`.
- **Key code names:** `StatsView`, `_StatsViewState`
- **Responsibilities:** Productivity stats (embedded in Timeline)
- **When to open:** When behavior tied to `stats_view.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Productivity stats (embedded in Timeline)
- **Layer / owner:** UI code for the stats area of the app (what users see and tap).

RU:

- **Что это:** `stats_view.dart` на панель stats внутри Timeline — Отвечает за видимый UI, собранный в `stats_view.dart`..
- **Зачем:** Пользователь видит UI из `stats_view.dart` на панель stats внутри Timeline.
- **Содержимое:** Компоновка экрана и state в `stats_view.dart`.
- **Обязанности:** Отвечает за видимый UI, собранный в `stats_view.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `stats_view.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/stats/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (stats).


### `lib/features/timeline/timeline_day_page.dart`

EN:

- **What this is:** `timeline_day_page.dart` on Timeline tab (first bottom tab) — TimelineDayCardList.
- **Why needed:** Users see `timeline_day_page.dart` when using Timeline tab (first bottom tab).
- **What it contains:** Primary symbols: `TimelineDayCardList`, `TimelineDayCardListState`, `TimelineLazyRecordList`, `TimelineLazyRecordListState`.
- **Key code names:** `TimelineDayCardList`, `TimelineDayCardListState`, `TimelineLazyRecordList`, `TimelineLazyRecordListState`
- **Responsibilities:** TimelineDayCardList
- **When to open:** Timeline tab: day list, record cards, stats toggle, date swipe.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Timeline tab (shell index 0); APP_STRUCTURE role: `TimelineDayCardList`, lazy record list
- **Layer / owner:** UI code for the timeline area of the app (what users see and tap).

RU:

- **Что это:** `timeline_day_page.dart` на вкладка Timeline (первая снизу) — Отвечает за видимый UI, собранный в `timeline_day_page.dart`..
- **Зачем:** Пользователь видит UI из `timeline_day_page.dart` на вкладка Timeline (первая снизу).
- **Содержимое:** Компоновка экрана и state в `timeline_day_page.dart`.
- **Обязанности:** Отвечает за видимый UI, собранный в `timeline_day_page.dart`.
- **Когда открывать:** Вкладка Timeline: записи, день, stats.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Timeline (shell index 0)
- **Слой:** UI — экран/виджет (timeline).


### `lib/features/timeline/timeline_header_controls.dart`

EN:

- **What this is:** `timeline_header_controls.dart` on Timeline tab (first bottom tab) — List/stats segmented control + record input row.
- **Why needed:** Users see `timeline_header_controls.dart` when using Timeline tab (first bottom tab).
- **What it contains:** Primary symbols: `TimelineHeaderControls`.
- **Key code names:** `TimelineHeaderControls`
- **Responsibilities:** List/stats segmented control + record input row
- **When to open:** Timeline tab: day list, record cards, stats toggle, date swipe.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Timeline tab (shell index 0); APP_STRUCTURE role: List/stats segmented control + record input row
- **Layer / owner:** UI code for the timeline area of the app (what users see and tap).

RU:

- **Что это:** `timeline_header_controls.dart` на вкладка Timeline (первая снизу) — Поддерживает поведение `timeline_header_controls` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `timeline_header_controls.dart` на вкладка Timeline (первая снизу).
- **Содержимое:** Dart-модуль `timeline_header_controls.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `timeline_header_controls` в этой feature-зоне.
- **Когда открывать:** Вкладка Timeline: записи, день, stats.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Timeline (shell index 0)
- **Слой:** UI — экран/виджет (timeline).


### `lib/features/timeline/timeline_helpers.dart`

EN:

- **What this is:** `timeline_helpers.dart` on Timeline tab (first bottom tab) — Shared timeline time/duration helpers.
- **Why needed:** Users see `timeline_helpers.dart` when using Timeline tab (first bottom tab).
- **What it contains:** Dart module `timeline_helpers.dart` — open file for classes and helpers.
- **Responsibilities:** Shared timeline time/duration helpers
- **When to open:** Timeline tab: day list, record cards, stats toggle, date swipe.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Timeline tab (shell index 0); APP_STRUCTURE role: Shared timeline time/duration helpers
- **Layer / owner:** UI code for the timeline area of the app (what users see and tap).

RU:

- **Что это:** `timeline_helpers.dart` на вкладка Timeline (первая снизу) — Поддерживает поведение `timeline_helpers` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `timeline_helpers.dart` на вкладка Timeline (первая снизу).
- **Содержимое:** Dart-модуль `timeline_helpers.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `timeline_helpers` в этой feature-зоне.
- **Когда открывать:** Вкладка Timeline: записи, день, stats.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Timeline (shell index 0)
- **Слой:** UI — экран/виджет (timeline).


### `lib/features/timeline/timeline_record_card.dart`

EN:

- **What this is:** `timeline_record_card.dart` on Timeline tab (first bottom tab) — TimelineRecordCard.
- **Why needed:** Users see `timeline_record_card.dart` when using Timeline tab (first bottom tab).
- **What it contains:** Primary symbols: `TimelineRecordCard`, `TimelineRecordCardState`.
- **Key code names:** `TimelineRecordCard`, `TimelineRecordCardState`
- **Responsibilities:** TimelineRecordCard
- **When to open:** Timeline tab: day list, record cards, stats toggle, date swipe.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Timeline tab (shell index 0); APP_STRUCTURE role: `TimelineRecordCard`
- **Layer / owner:** UI code for the timeline area of the app (what users see and tap).

RU:

- **Что это:** `timeline_record_card.dart` на вкладка Timeline (первая снизу) — Поддерживает поведение `timeline_record_card` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `timeline_record_card.dart` на вкладка Timeline (первая снизу).
- **Содержимое:** Dart-модуль `timeline_record_card.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `timeline_record_card` в этой feature-зоне.
- **Когда открывать:** Вкладка Timeline: записи, день, stats.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Timeline (shell index 0)
- **Слой:** UI — экран/виджет (timeline).


### `lib/features/timeline/timeline_view.dart`

EN:

- **What this is:** Timeline tab root — `TimelineSwipeWrapper` day pager plus `TimelinePage` body (header, day list, record cards).
- **Why needed:** First bottom tab: swipe days, start/stop records, toggle stats — all wired from here.
- **What it contains:** `TimelineSwipeWrapper`, `_TimelineSwipeWrapperState`; imports day page, header controls, stats.
- **Key code names:** `TimelineSwipeWrapper`, `_TimelineSwipeWrapperState`
- **Responsibilities:** Compose Timeline UI; profile-timezone day keys; warm-window paging hooks.
- **When to open:** Timeline tab: day list, record cards, stats toggle, date swipe.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Timeline tab (shell index 0); APP_STRUCTURE role: `TimelineSwipeWrapper`, `TimelinePage`
- **Layer / owner:** UI code for the timeline area of the app (what users see and tap).

RU:

- **Что это:** Корень вкладки Timeline — day pager `TimelineSwipeWrapper` и тело `TimelinePage` (header, список дня, карточки записей).
- **Зачем:** Первая вкладка: свайп дней, старт/стоп записей, stats — собрано здесь.
- **Содержимое:** `TimelineSwipeWrapper`, `_TimelineSwipeWrapperState`; подключает day page, header controls, stats.
- **Обязанности:** Собирает UI Timeline; day keys по profile timezone; warm-window paging.
- **Когда открывать:** Вкладка Timeline: записи, день, stats.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Вкладка Timeline (shell index 0)
- **Слой:** UI — экран/виджет (timeline).


### `lib/features/wear/wear_main_wrapper.dart`

EN:

- **What this is:** `wear_main_wrapper.dart` on Wear OS watch companion — Wear OS companion.
- **Why needed:** Users see `wear_main_wrapper.dart` when using Wear OS watch companion.
- **What it contains:** Primary symbols: `WearMainWrapper`.
- **Key code names:** `WearMainWrapper`
- **Responsibilities:** Wear OS companion
- **When to open:** When behavior tied to `wear_main_wrapper.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Wear OS companion
- **Layer / owner:** UI code for the wear area of the app (what users see and tap).

RU:

- **Что это:** `wear_main_wrapper.dart` на Wear OS companion — Поддерживает поведение `wear_main_wrapper` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `wear_main_wrapper.dart` на Wear OS companion.
- **Содержимое:** Dart-модуль `wear_main_wrapper.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `wear_main_wrapper` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `wear_main_wrapper.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/wear/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (wear).


### `lib/features/wear/wear_platform.dart`

EN:

- **What this is:** `wear_platform.dart` on Wear OS watch companion — Wear OS companion.
- **Why needed:** Users see `wear_platform.dart` when using Wear OS watch companion.
- **What it contains:** Primary symbols: `WearPlatform`.
- **Key code names:** `WearPlatform`
- **Responsibilities:** Wear OS companion
- **When to open:** When behavior tied to `wear_platform.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Wear OS companion
- **Layer / owner:** UI code for the wear area of the app (what users see and tap).

RU:

- **Что это:** `wear_platform.dart` на Wear OS companion — Поддерживает поведение `wear_platform` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `wear_platform.dart` на Wear OS companion.
- **Содержимое:** Dart-модуль `wear_platform.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `wear_platform` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `wear_platform.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/wear/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (wear).


### `lib/features/wear/wear_runtime.dart`

EN:

- **What this is:** `wear_runtime.dart` on Wear OS watch companion — Wear OS companion.
- **Why needed:** Users see `wear_runtime.dart` when using Wear OS watch companion.
- **What it contains:** Dart module `wear_runtime.dart` — open file for classes and helpers.
- **Responsibilities:** Wear OS companion
- **When to open:** When behavior tied to `wear_runtime.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Wear OS companion
- **Layer / owner:** UI code for the wear area of the app (what users see and tap).

RU:

- **Что это:** `wear_runtime.dart` на Wear OS companion — Поддерживает поведение `wear_runtime` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `wear_runtime.dart` на Wear OS companion.
- **Содержимое:** Dart-модуль `wear_runtime.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `wear_runtime` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `wear_runtime.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/wear/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (wear).


### `lib/features/wear/wear_timer_screen.dart`

EN:

- **What this is:** `wear_timer_screen.dart` on Wear OS watch companion — Wear OS companion.
- **Why needed:** Users see `wear_timer_screen.dart` when using Wear OS watch companion.
- **What it contains:** Primary symbols: `WearTimerScreen`, `_WearTimerScreenState`.
- **Key code names:** `WearTimerScreen`, `_WearTimerScreenState`
- **Responsibilities:** Wear OS companion
- **When to open:** When behavior tied to `wear_timer_screen.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Wear OS companion
- **Layer / owner:** UI code for the wear area of the app (what users see and tap).

RU:

- **Что это:** `wear_timer_screen.dart` на Wear OS companion — Поддерживает поведение `wear_timer_screen` в этой feature-зоне..
- **Зачем:** Пользователь видит UI из `wear_timer_screen.dart` на Wear OS companion.
- **Содержимое:** Dart-модуль `wear_timer_screen.dart` — классы и helpers в исходнике.
- **Обязанности:** Поддерживает поведение `wear_timer_screen` в этой feature-зоне.
- **Когда открывать:** Когда ломается поведение, связанное с `wear_timer_screen.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/features/wear/`, `docs/APP_STRUCTURE.md`
- **Слой:** UI — экран/виджет (wear).


### `lib/l10n/app_locales.dart`

EN:

- **What this is:** Localization module `app_locales.dart` — реестр поддерживаемых локалей и fallback на English.
- **Why needed:** UI labels resolve through l10n maps instead of hard-coded strings in widgets.
- **What it contains:** Dart maps/keys in `app_locales.dart`.
- **Responsibilities:** Provide translated strings for `app_locales.dart`.
- **When to open:** When behavior tied to `app_locales.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Supported locale codes and labels
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Модуль локализации `app_locales.dart` — реестр поддерживаемых локалей и fallback на English.
- **Зачем:** Подписи UI берутся из l10n maps, а не из hard-coded строк в виджетах.
- **Содержимое:** Dart-карты ключей в `app_locales.dart`.
- **Обязанности:** Даёт переведённые строки для `app_locales.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `app_locales.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/l10n/`, `docs/APP_STRUCTURE.md`
- **Слой:** Локализация — строки UI.


### `lib/l10n/category_db_display.dart`

EN:

- **What this is:** Localization module `category_db_display.dart` — отображение названий категорий из brain в UI.
- **Why needed:** UI labels resolve through l10n maps instead of hard-coded strings in widgets.
- **What it contains:** Dart maps/keys in `category_db_display.dart`.
- **Responsibilities:** Provide translated strings for `category_db_display.dart`.
- **When to open:** When behavior tied to `category_db_display.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Localized category name display
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Модуль локализации `category_db_display.dart` — отображение названий категорий из brain в UI.
- **Зачем:** Подписи UI берутся из l10n maps, а не из hard-coded строк в виджетах.
- **Содержимое:** Dart-карты ключей в `category_db_display.dart`.
- **Обязанности:** Даёт переведённые строки для `category_db_display.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `category_db_display.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/l10n/`, `docs/APP_STRUCTURE.md`
- **Слой:** Локализация — строки UI.


### `lib/l10n/dictionary.dart`

EN:

- **What this is:** Localization module `dictionary.dart` — мастер-ключи UI-текста (SSOT для подписей).
- **Why needed:** UI labels resolve through l10n maps instead of hard-coded strings in widgets.
- **What it contains:** Dart maps/keys in `dictionary.dart`.
- **Responsibilities:** Provide translated strings for `dictionary.dart`.
- **When to open:** When behavior tied to `dictionary.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: Assembles locale maps
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Модуль локализации `dictionary.dart` — мастер-ключи UI-текста (SSOT для подписей).
- **Зачем:** Подписи UI берутся из l10n maps, а не из hard-coded строк в виджетах.
- **Содержимое:** Dart-карты ключей в `dictionary.dart`.
- **Обязанности:** Даёт переведённые строки для `dictionary.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `dictionary.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/l10n/`, `docs/APP_STRUCTURE.md`
- **Слой:** Локализация — строки UI.


### `lib/l10n/langs/HELP HOW TO UPDATE the languages`

EN:

- **What this is:** text file `HELP HOW TO UPDATE the languages` in `lib/l10n/langs` — repo tooling or config.
- **Why needed:** Tracked because `lib/l10n/langs` needs `HELP HOW TO UPDATE the languages` for build, CI, or maintenance.
- **What it contains:** Open `HELP HOW TO UPDATE the languages` when working on `lib/l10n/langs` (see folder section above).
- **Responsibilities:** Supports `lib/l10n/langs` workflow for `HELP HOW TO UPDATE the languages`.
- **When to open:** When build output or maintenance cites `HELP HOW TO UPDATE the languages`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Модуль локализации `HELP HOW TO UPDATE the languages` — строки локали `HELP HOW TO UPDATE the languages` (частичный перевод поверх English).
- **Зачем:** Подписи UI берутся из l10n maps, а не из hard-coded строк в виджетах.
- **Содержимое:** Dart-карты ключей в `HELP HOW TO UPDATE the languages`.
- **Обязанности:** Даёт переведённые строки для `HELP HOW TO UPDATE the languages`.
- **Когда открывать:** When результат сборки or maintenance cites `HELP HOW TO UPDATE the languages`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`.
- **Слой:** Локализация — строки UI.


### `lib/l10n/langs/ar.dart`

EN:

- **What this is:** Localization module `ar.dart` — строки локали `ar` (частичный перевод поверх English).
- **Why needed:** UI labels resolve through l10n maps instead of hard-coded strings in widgets.
- **What it contains:** Dart maps/keys in `ar.dart`.
- **Responsibilities:** Provide translated strings for `ar.dart`.
- **When to open:** When behavior tied to `ar.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: ar
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Модуль локализации `ar.dart` — строки локали `ar` (частичный перевод поверх English).
- **Зачем:** Подписи UI берутся из l10n maps, а не из hard-coded строк в виджетах.
- **Содержимое:** Dart-карты ключей в `ar.dart`.
- **Обязанности:** Даёт переведённые строки для `ar.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `ar.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`
- **Слой:** Локализация — строки UI.


### `lib/l10n/langs/de.dart`

EN:

- **What this is:** Localization module `de.dart` — строки локали `de` (частичный перевод поверх English).
- **Why needed:** UI labels resolve through l10n maps instead of hard-coded strings in widgets.
- **What it contains:** Dart maps/keys in `de.dart`.
- **Responsibilities:** Provide translated strings for `de.dart`.
- **When to open:** When behavior tied to `de.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: de
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Модуль локализации `de.dart` — строки локали `de` (частичный перевод поверх English).
- **Зачем:** Подписи UI берутся из l10n maps, а не из hard-coded строк в виджетах.
- **Содержимое:** Dart-карты ключей в `de.dart`.
- **Обязанности:** Даёт переведённые строки для `de.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `de.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`
- **Слой:** Локализация — строки UI.


### `lib/l10n/langs/en.dart`

EN:

- **What this is:** Localization module `en.dart` — строки локали `en` (частичный перевод поверх English).
- **Why needed:** UI labels resolve through l10n maps instead of hard-coded strings in widgets.
- **What it contains:** Dart maps/keys in `en.dart`.
- **Responsibilities:** Provide translated strings for `en.dart`.
- **When to open:** When behavior tied to `en.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: **Canonical English** (`kEnL10n`) — SSOT for EN keys
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Модуль локализации `en.dart` — строки локали `en` (частичный перевод поверх English).
- **Зачем:** Подписи UI берутся из l10n maps, а не из hard-coded строк в виджетах.
- **Содержимое:** Dart-карты ключей в `en.dart`.
- **Обязанности:** Даёт переведённые строки для `en.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `en.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`
- **Слой:** Локализация — строки UI.


### `lib/l10n/langs/es.dart`

EN:

- **What this is:** Localization module `es.dart` — строки локали `es` (частичный перевод поверх English).
- **Why needed:** UI labels resolve through l10n maps instead of hard-coded strings in widgets.
- **What it contains:** Dart maps/keys in `es.dart`.
- **Responsibilities:** Provide translated strings for `es.dart`.
- **When to open:** When behavior tied to `es.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: es
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Модуль локализации `es.dart` — строки локали `es` (частичный перевод поверх English).
- **Зачем:** Подписи UI берутся из l10n maps, а не из hard-coded строк в виджетах.
- **Содержимое:** Dart-карты ключей в `es.dart`.
- **Обязанности:** Даёт переведённые строки для `es.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `es.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`
- **Слой:** Локализация — строки UI.


### `lib/l10n/langs/fr.dart`

EN:

- **What this is:** Localization module `fr.dart` — строки локали `fr` (частичный перевод поверх English).
- **Why needed:** UI labels resolve through l10n maps instead of hard-coded strings in widgets.
- **What it contains:** Dart maps/keys in `fr.dart`.
- **Responsibilities:** Provide translated strings for `fr.dart`.
- **When to open:** When behavior tied to `fr.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: fr
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Модуль локализации `fr.dart` — строки локали `fr` (частичный перевод поверх English).
- **Зачем:** Подписи UI берутся из l10n maps, а не из hard-coded строк в виджетах.
- **Содержимое:** Dart-карты ключей в `fr.dart`.
- **Обязанности:** Даёт переведённые строки для `fr.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `fr.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`
- **Слой:** Локализация — строки UI.


### `lib/l10n/langs/it.dart`

EN:

- **What this is:** Localization module `it.dart` — строки локали `it` (частичный перевод поверх English).
- **Why needed:** UI labels resolve through l10n maps instead of hard-coded strings in widgets.
- **What it contains:** Dart maps/keys in `it.dart`.
- **Responsibilities:** Provide translated strings for `it.dart`.
- **When to open:** When behavior tied to `it.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: it
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Модуль локализации `it.dart` — строки локали `it` (частичный перевод поверх English).
- **Зачем:** Подписи UI берутся из l10n maps, а не из hard-coded строк в виджетах.
- **Содержимое:** Dart-карты ключей в `it.dart`.
- **Обязанности:** Даёт переведённые строки для `it.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `it.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`
- **Слой:** Локализация — строки UI.


### `lib/l10n/langs/ko.dart`

EN:

- **What this is:** Localization module `ko.dart` — строки локали `ko` (частичный перевод поверх English).
- **Why needed:** UI labels resolve through l10n maps instead of hard-coded strings in widgets.
- **What it contains:** Dart maps/keys in `ko.dart`.
- **Responsibilities:** Provide translated strings for `ko.dart`.
- **When to open:** When behavior tied to `ko.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: ko
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Модуль локализации `ko.dart` — строки локали `ko` (частичный перевод поверх English).
- **Зачем:** Подписи UI берутся из l10n maps, а не из hard-coded строк в виджетах.
- **Содержимое:** Dart-карты ключей в `ko.dart`.
- **Обязанности:** Даёт переведённые строки для `ko.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `ko.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`
- **Слой:** Локализация — строки UI.


### `lib/l10n/langs/ru.dart`

EN:

- **What this is:** Localization module `ru.dart` — строки локали `ru` (частичный перевод поверх English).
- **Why needed:** UI labels resolve through l10n maps instead of hard-coded strings in widgets.
- **What it contains:** Dart maps/keys in `ru.dart`.
- **Responsibilities:** Provide translated strings for `ru.dart`.
- **When to open:** When behavior tied to `ru.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: **Canonical Russian** (`kRuL10n`) — SSOT for RU keys
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Модуль локализации `ru.dart` — строки локали `ru` (частичный перевод поверх English).
- **Зачем:** Подписи UI берутся из l10n maps, а не из hard-coded строк в виджетах.
- **Содержимое:** Dart-карты ключей в `ru.dart`.
- **Обязанности:** Даёт переведённые строки для `ru.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `ru.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`
- **Слой:** Локализация — строки UI.


### `lib/l10n/langs/zh.dart`

EN:

- **What this is:** Localization module `zh.dart` — строки локали `zh` (частичный перевод поверх English).
- **Why needed:** UI labels resolve through l10n maps instead of hard-coded strings in widgets.
- **What it contains:** Dart maps/keys in `zh.dart`.
- **Responsibilities:** Provide translated strings for `zh.dart`.
- **When to open:** When behavior tied to `zh.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: zh
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Модуль локализации `zh.dart` — строки локали `zh` (частичный перевод поверх English).
- **Зачем:** Подписи UI берутся из l10n maps, а не из hard-coded строк в виджетах.
- **Содержимое:** Dart-карты ключей в `zh.dart`.
- **Обязанности:** Даёт переведённые строки для `zh.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `zh.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`
- **Слой:** Локализация — строки UI.


### `lib/main.dart`

EN:

- **What this is:** Flutter app entry — `main()` bootstraps auth gate, brain load, and dashboard.
- **Why needed:** OS launches this file first; it wires PocketBase session and initial data before tabs render.
- **What it contains:** `main()`, app widget tree, auth routing to dashboard or login.
- **Key code names:** `main`, `DateTimeTrackerApp`, `_DateTimeTrackerAppState`, `RootAuthWrapper`, `_RootAuthWrapperState`
- **Responsibilities:** Start Flutter binding; load settings; show loading until brain ready.
- **When to open:** When behavior tied to `main.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** APP_STRUCTURE role: `runApp`, PocketBase bootstrap, auth gate, Wear entry, locale init, shell injection
- **Layer / owner:** Repository support file.

RU:

- **Что это:** Точка входа Flutter — `main()` запускает auth gate, загрузку brain и dashboard.
- **Зачем:** ОС стартует приложение отсюда; до вкладок нужны session PocketBase и initial data.
- **Содержимое:** `main()`, дерево виджетов, routing login ↔ dashboard.
- **Обязанности:** Инициализация Flutter; loading до готовности brain.
- **Когда открывать:** Когда ломается поведение, связанное с `main.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/`, `docs/APP_STRUCTURE.md`
- **Слой:** Вспомогательный файл репозитория.


### `lib/services/notification_service.dart`

EN:

- **What this is:** Device-side service `notification_service.dart` — Local notifications and plan alarms.
- **Why needed:** OS APIs (notifications, voice, tray) cannot live in PocketBase brain code.
- **What it contains:** Platform service code in `notification_service.dart` (`_AlarmCandidate`, `NotificationService`).
- **Key code names:** `_AlarmCandidate`, `NotificationService`
- **Responsibilities:** Local notifications and plan alarms
- **When to open:** When behavior tied to `notification_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** `lib/data/plan_service.dart` alarm reschedule; APP_STRUCTURE role: Local notifications and plan alarms
- **Layer / owner:** Device service (notifications) — no PocketBase.

RU:

- **Что это:** Сервис устройства `notification_service.dart` — Local notifications and plan alarms.
- **Зачем:** OS API (уведомления, voice, tray) не могут жить в PocketBase brain.
- **Содержимое:** Platform-код сервиса в `notification_service.dart` (logic in `notification_service`).
- **Обязанности:** Реализует сервис: Local notifications and plan alarms.
- **Когда открывать:** Когда ломается поведение, связанное с `notification_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `lib/data/plan_service.dart` — reschedule alarm
- **Слой:** Сервис устройства (уведомления).


### `lib/shell/life_os_dashboard.dart`

EN:

- **What this is:** App shell wiring — Shell dashboard entry (see §3.1.1).
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ShellDashboardBase`, `LifeOSDashboard`, `ShellDashboardState`).
- **Key code names:** `ShellDashboardBase`, `LifeOSDashboard`, `ShellDashboardState`
- **Responsibilities:** Shell dashboard entry (see §3.1.1)
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; APP_STRUCTURE role: Shell dashboard entry (see §3.1.1)
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения (shell) — Shell dashboard entry (see §3.1.1).
- **Зачем:** Связывает вкладки, voice, edit sheets и offline banner.
- **Содержимое:** Shell mixin или виджет (logic in `life_os_dashboard`).
- **Обязанности:** Реализует в shell: Shell dashboard entry (see §3.1.1).
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Все main tabs, `app_shell.dart`
- **Слой:** Shell — навигация приложения.


### `lib/shell/profile_hydration_status_bar.dart`

EN:

- **What this is:** App shell wiring — Profile hydration failure banner.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ProfileHydrationStatusBar`).
- **Key code names:** `ProfileHydrationStatusBar`
- **Responsibilities:** Profile hydration failure banner
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; APP_STRUCTURE role: Profile hydration failure banner
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения (shell) — Profile hydration failure banner.
- **Зачем:** Связывает вкладки, voice, edit sheets и offline banner.
- **Содержимое:** Shell mixin или виджет (logic in `profile_hydration_status_bar`).
- **Обязанности:** Реализует в shell: Profile hydration failure banner.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Все main tabs, `app_shell.dart`
- **Слой:** Shell — навигация приложения.


### `lib/shell/settings_page.dart`

EN:

- **What this is:** App shell wiring — Language/TZ settings page (shell route).
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`SettingsPage`, `SettingsPageState`).
- **Key code names:** `SettingsPage`, `SettingsPageState`
- **Responsibilities:** Language/TZ settings page (shell route)
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; APP_STRUCTURE role: Language/TZ settings page (shell route)
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения (shell) — Language/TZ settings page (shell route).
- **Зачем:** Связывает вкладки, voice, edit sheets и offline banner.
- **Содержимое:** Shell mixin или виджет (logic in `settings_page`).
- **Обязанности:** Реализует в shell: Language/TZ settings page (shell route).
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Все main tabs, `app_shell.dart`
- **Слой:** Shell — навигация приложения.


### `lib/shell/shell_core.dart`

EN:

- **What this is:** App shell wiring — Shell core logic.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ShellCoreLogic`).
- **Key code names:** `ShellCoreLogic`
- **Responsibilities:** Shell core logic
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; APP_STRUCTURE role: Shell core logic
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения (shell) — Shell core logic.
- **Зачем:** Связывает вкладки, voice, edit sheets и offline banner.
- **Содержимое:** Shell mixin или виджет (logic in `shell_core`).
- **Обязанности:** Реализует в shell: Shell core logic.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Все main tabs, `app_shell.dart`
- **Слой:** Shell — навигация приложения.


### `lib/shell/shell_edit_hosts.dart`

EN:

- **What this is:** App shell wiring — Edit sheet hosts.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ShellEditHosts`).
- **Key code names:** `ShellEditHosts`
- **Responsibilities:** Edit sheet hosts
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; APP_STRUCTURE role: Edit sheet hosts
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения (shell) — Edit sheet hosts.
- **Зачем:** Связывает вкладки, voice, edit sheets и offline banner.
- **Содержимое:** Shell mixin или виджет (logic in `shell_edit_hosts`).
- **Обязанности:** Реализует в shell: Edit sheet hosts.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Все main tabs, `app_shell.dart`
- **Слой:** Shell — навигация приложения.


### `lib/shell/shell_more_menu.dart`

EN:

- **What this is:** App shell wiring — More menu.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ShellMoreMenu`).
- **Key code names:** `ShellMoreMenu`
- **Responsibilities:** More menu
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; APP_STRUCTURE role: More menu
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения (shell) — More menu.
- **Зачем:** Связывает вкладки, voice, edit sheets и offline banner.
- **Содержимое:** Shell mixin или виджет (logic in `shell_more_menu`).
- **Обязанности:** Реализует в shell: More menu.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Все main tabs, `app_shell.dart`
- **Слой:** Shell — навигация приложения.


### `lib/shell/shell_offline_banner.dart`

EN:

- **What this is:** App shell wiring — Offline banner slot.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ShellTopStatusBars`).
- **Key code names:** `ShellTopStatusBars`
- **Responsibilities:** Offline banner slot
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; APP_STRUCTURE role: Offline banner slot
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения (shell) — Offline banner slot.
- **Зачем:** Связывает вкладки, voice, edit sheets и offline banner.
- **Содержимое:** Shell mixin или виджет (logic in `shell_offline_banner`).
- **Обязанности:** Реализует в shell: Offline banner slot.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Все main tabs, `app_shell.dart`
- **Слой:** Shell — навигация приложения.


### `lib/shell/shell_shared.dart`

EN:

- **What this is:** App shell wiring — Shell shared helpers.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (logic in `shell_shared`).
- **Responsibilities:** Shell shared helpers
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; APP_STRUCTURE role: Shell shared helpers
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения (shell) — Shell shared helpers.
- **Зачем:** Связывает вкладки, voice, edit sheets и offline banner.
- **Содержимое:** Shell mixin или виджет (logic in `shell_shared`).
- **Обязанности:** Реализует в shell: Shell shared helpers.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Все main tabs, `app_shell.dart`
- **Слой:** Shell — навигация приложения.


### `lib/shell/shell_side_navigation.dart`

EN:

- **What this is:** App shell wiring — Desktop/web side navigation rail.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ShellSideNavigation`, `ShellSideNavItem`).
- **Key code names:** `ShellSideNavigation`, `ShellSideNavItem`
- **Responsibilities:** Desktop/web side navigation rail
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; APP_STRUCTURE role: Desktop/web side navigation rail
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения (shell) — Desktop/web side navigation rail.
- **Зачем:** Связывает вкладки, voice, edit sheets и offline banner.
- **Содержимое:** Shell mixin или виджет (logic in `shell_side_navigation`).
- **Обязанности:** Реализует в shell: Desktop/web side navigation rail.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Все main tabs, `app_shell.dart`
- **Слой:** Shell — навигация приложения.


### `lib/shell/shell_tab_host.dart`

EN:

- **What this is:** App shell wiring — Tab host builders.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ShellTabHost`).
- **Key code names:** `ShellTabHost`
- **Responsibilities:** Tab host builders
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; APP_STRUCTURE role: Tab host builders
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения (shell) — Tab host builders.
- **Зачем:** Связывает вкладки, voice, edit sheets и offline banner.
- **Содержимое:** Shell mixin или виджет (logic in `shell_tab_host`).
- **Обязанности:** Реализует в shell: Tab host builders.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Все main tabs, `app_shell.dart`
- **Слой:** Shell — навигация приложения.


### `lib/shell/shell_voice_routing.dart`

EN:

- **What this is:** App shell wiring — Voice routing.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ShellVoiceRouting`).
- **Key code names:** `ShellVoiceRouting`
- **Responsibilities:** Voice routing
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; APP_STRUCTURE role: Voice routing
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения (shell) — Voice routing.
- **Зачем:** Связывает вкладки, voice, edit sheets и offline banner.
- **Содержимое:** Shell mixin или виджет (logic in `shell_voice_routing`).
- **Обязанности:** Реализует в shell: Voice routing.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Все main tabs, `app_shell.dart`
- **Слой:** Shell — навигация приложения.


### `linux/.gitignore`

EN:

- **What this is:** Git ignore rules for `linux` — files not to commit.
- **Why needed:** Prevents build output and secrets from entering git history.
- **What it contains:** Ignore patterns for this folder scope.
- **Responsibilities:** Prevent accidental commit of generated files.
- **When to open:** When behavior tied to `.gitignore` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `linux` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Git ignore для `linux/` — не коммитить локальный build-мусор платформы.
- **Зачем:** Gradle/Xcode/CMake генерируют файлы в `linux/`, которые не должны попадать в git.
- **Содержимое:** Ignore patterns для build cache и IDE metadata в `linux/`.
- **Обязанности:** Держать `linux/` tree чистым от generated artifacts.
- **Когда открывать:** Случайно добавили результат сборки `linux/` в git.
- **Можно удалить?** Нет — без него не соберётся Linux desktop binary.
- **Связано с:** Flutter `linux` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `linux/CMakeLists.txt`

EN:

- **What this is:** CMake build script for `linux` — builds the Flutter `linux` native runner.
- **Why needed:** Native linux desktop compile links Flutter engine via this CMake file in `linux`.
- **What it contains:** CMake targets, source file list, Flutter embedder link rules.
- **Responsibilities:** Produce native binary pieces for `linux` embedder.
- **When to open:** When behavior tied to `CMakeLists.txt` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `linux` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Главный CMake-файл Linux desktop runner. Описывает native targets, source files и link rules, через которые Flutter engine собирается в linux binary.
- **Зачем:** Flutter linux build не соберёт runner без корневого CMake project.
- **Содержимое:** project(), add_subdirectory для `flutter/` и `runner/`, toolchain settings.
- **Обязанности:** Собрать native binary для `linux/` embedder через CMake.
- **Когда открывать:** linux desktop build падает на configure/link; installer не получит рабочий runner.
- **Можно удалить?** Нет — без него не соберётся Linux desktop binary.
- **Связано с:** Flutter `linux` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `linux/flutter/CMakeLists.txt`

EN:

- **What this is:** CMake build script for `linux/flutter` — builds the Flutter `linux` native runner.
- **Why needed:** Native linux desktop compile links Flutter engine via this CMake file in `linux/flutter`.
- **What it contains:** CMake targets, source file list, Flutter embedder link rules.
- **Responsibilities:** Produce native binary pieces for `linux/flutter` embedder.
- **When to open:** When behavior tied to `CMakeLists.txt` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `linux` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** сгенерированный Flutter CMake glue для linux — подключает engine и plugin build steps.
- **Зачем:** Flutter tool перезаписывает этот файл при build; связывает Dart AOT с native runner.
- **Содержимое:** Сгенерированные targets для `libflutter`, assets и plugin registrant.
- **Обязанности:** Встраивает Flutter engine и assets в linux desktop build.
- **Когда открывать:** Flutter upgrade изменил generated CMake; plugin link fail на linux.
- **Можно удалить?** Нет — без него не соберётся Linux desktop binary.
- **Связано с:** Flutter `linux` tooling.
- **Слой:** сгенерированный Flutter linux glue — не править вручную без причины.


### `linux/flutter/generated_plugin_registrant.cc`

EN:

- **What this is:** linux build file `generated_plugin_registrant.cc` in `linux/flutter` — required by Flutter/native toolchain.
- **Why needed:** Without `generated_plugin_registrant.cc`, linux compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `linux/flutter` (open file only when build errors cite it).
- **Responsibilities:** Support linux embedder build for `linux/flutter` — not Dart business logic.
- **When to open:** Build log mentions `generated_plugin_registrant.cc` or `linux/flutter`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `linux/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Generated registrant Flutter plugins (linux) — подключает native plugins embedder.
- **Зачем:** Flutter tooling генерирует этот файл; без него plugins не подключатся.
- **Содержимое:** Auto-generated код регистрации plugins.
- **Обязанности:** Подключить Flutter plugins к native runner.
- **Когда открывать:** Plugin missing после `flutter pub get` / clean build.
- **Можно удалить?** Нет — без него не соберётся Linux desktop binary.
- **Связано с:** `linux/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `linux/flutter/generated_plugin_registrant.h`

EN:

- **What this is:** linux build file `generated_plugin_registrant.h` in `linux/flutter` — required by Flutter/native toolchain.
- **Why needed:** Without `generated_plugin_registrant.h`, linux compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `linux/flutter` (open file only when build errors cite it).
- **Responsibilities:** Support linux embedder build for `linux/flutter` — not Dart business logic.
- **When to open:** Build log mentions `generated_plugin_registrant.h` or `linux/flutter`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `linux/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Generated registrant Flutter plugins (linux) — подключает native plugins embedder.
- **Зачем:** Flutter tooling генерирует этот файл; без него plugins не подключатся.
- **Содержимое:** Auto-generated код регистрации plugins.
- **Обязанности:** Подключить Flutter plugins к native runner.
- **Когда открывать:** Plugin missing после `flutter pub get` / clean build.
- **Можно удалить?** Нет — без него не соберётся Linux desktop binary.
- **Связано с:** `linux/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `linux/flutter/generated_plugins.cmake`

EN:

- **What this is:** linux build file `generated_plugins.cmake` in `linux/flutter` — required by Flutter/native toolchain.
- **Why needed:** Without `generated_plugins.cmake`, linux compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `linux/flutter` (open file only when build errors cite it).
- **Responsibilities:** Support linux embedder build for `linux/flutter` — not Dart business logic.
- **When to open:** Build log mentions `generated_plugins.cmake` or `linux/flutter`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `linux/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** CMake fragment `generated_plugins.cmake` — сгенерированный Flutter plugin build rules для linux desktop.
- **Зачем:** Flutter tool генерирует CMake glue, чтобы plugins линковались в desktop runner.
- **Содержимое:** add_subdirectory/target rules для plugins и registrant.
- **Обязанности:** Wire Flutter plugins into Linux desktop binary native build.
- **Когда открывать:** Plugin link fail на linux после `flutter pub get` или upgrade.
- **Можно удалить?** Нет — без него не соберётся Linux desktop binary.
- **Связано с:** `linux/CMakeLists.txt`, `pubspec.yaml` plugins.
- **Слой:** сгенерированный Flutter CMake linux.


### `linux/runner/CMakeLists.txt`

EN:

- **What this is:** CMake build script for `linux/runner` — builds the Flutter `linux` native runner.
- **Why needed:** Native linux desktop compile links Flutter engine via this CMake file in `linux/runner`.
- **What it contains:** CMake targets, source file list, Flutter embedder link rules.
- **Responsibilities:** Produce native binary pieces for `linux/runner` embedder.
- **When to open:** When behavior tied to `CMakeLists.txt` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `linux` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** CMake target `linux/runner` — собирает native host, который запускает Flutter engine.
- **Зачем:** Executable Counter на linux создаётся из runner sources и Flutter glue.
- **Содержимое:** Список runner sources, link libraries и install rules для desktop binary.
- **Обязанности:** Собрать linux host app и подключить Flutter plugins.
- **Когда открывать:** When behavior tied to `CMakeLists.txt` breaks or you need to change its documented role.
- **Можно удалить?** Нет — без него не соберётся Linux desktop binary.
- **Связано с:** Flutter `linux` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `linux/runner/main.cc`

EN:

- **What this is:** linux build file `main.cc` in `linux/runner` — required by Flutter/native toolchain.
- **Why needed:** Without `main.cc`, linux compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `linux/runner` (open file only when build errors cite it).
- **Responsibilities:** Support linux embedder build for `linux/runner` — not Dart business logic.
- **When to open:** Build log mentions `main.cc` or `linux/runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `linux/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Native C entry point Linux GTK runner — создаёт окно и запускает Flutter engine для desktop Counter.
- **Зачем:** Linux desktop binary стартует отсюда; без entry point Flutter UI не поднимется.
- **Содержимое:** `main()` и вызовы GTK/Flutter embedding bootstrap.
- **Обязанности:** Cold start Linux runner — GTK host + Flutter engine.
- **Когда открывать:** Linux desktop binary не стартует или crash до первого Flutter frame.
- **Можно удалить?** Нет — без него не соберётся Linux desktop binary.
- **Связано с:** `linux/runner/`, `linux/CMakeLists.txt`.
- **Слой:** Linux native entry — не Dart.


### `linux/runner/my_application.cc`

EN:

- **What this is:** linux build file `my_application.cc` in `linux/runner` — required by Flutter/native toolchain.
- **Why needed:** Without `my_application.cc`, linux compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `linux/runner` (open file only when build errors cite it).
- **Responsibilities:** Support linux embedder build for `linux/runner` — not Dart business logic.
- **When to open:** Build log mentions `my_application.cc` or `linux/runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `linux/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Native C++ source `my_application.cc` — часть CMake/GTK runner runner, собирающего Linux desktop binary.
- **Зачем:** CMake/MSBuild компилирует этот файл в native host, который держит Flutter engine.
- **Содержимое:** C++ implementation для linux/runner runner target.
- **Обязанности:** Native host behavior для Linux desktop binary (окно, plugins, utils).
- **Когда открывать:** Native compile/link error ссылается на `my_application.cc`.
- **Можно удалить?** Нет — без него не соберётся Linux desktop binary.
- **Связано с:** `linux/runner/CMakeLists.txt`, `linux/flutter/`.
- **Слой:** linux native runner source — не Dart.


### `linux/runner/my_application.h`

EN:

- **What this is:** linux build file `my_application.h` in `linux/runner` — required by Flutter/native toolchain.
- **Why needed:** Without `my_application.h`, linux compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `linux/runner` (open file only when build errors cite it).
- **Responsibilities:** Support linux embedder build for `linux/runner` — not Dart business logic.
- **When to open:** Build log mentions `my_application.h` or `linux/runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `linux/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Заголовок C/C++ `my_application.h` — объявления для native runner linux (CMake/GTK runner).
- **Зачем:** Компилятор CMake/GTK runner подключает header при сборке Linux desktop binary.
- **Содержимое:** Объявления и guards для `my_application.h` в `linux/runner`.
- **Обязанности:** Compile-time интерфейс native runner для Linux desktop binary.
- **Когда открывать:** Ошибка native compile ссылается на `my_application.h`.
- **Можно удалить?** Нет — без него не соберётся Linux desktop binary.
- **Связано с:** `linux/runner/`, `linux/flutter/`.
- **Слой:** linux native header — не Dart.


### `macos/.gitignore`

EN:

- **What this is:** Git ignore rules for `macos` — files not to commit.
- **Why needed:** Prevents build output and secrets from entering git history.
- **What it contains:** Ignore patterns for this folder scope.
- **Responsibilities:** Prevent accidental commit of generated files.
- **When to open:** When behavior tied to `.gitignore` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `macos` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Git ignore для `macos/` — не коммитить локальный build-мусор платформы.
- **Зачем:** Gradle/Xcode/CMake генерируют файлы в `macos/`, которые не должны попадать в git.
- **Содержимое:** Ignore patterns для build cache и IDE metadata в `macos/`.
- **Обязанности:** Держать `macos/` tree чистым от generated artifacts.
- **Когда открывать:** Случайно добавили результат сборки `macos/` в git.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** Flutter `macos` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `macos/Flutter/Flutter-Debug.xcconfig`

EN:

- **What this is:** Flutter macos `Debug.xcconfig` — passes Flutter/CocoaPods settings into Xcode build.
- **Why needed:** Xcode reads xcconfig when compiling Runner Debug; Flutter flags must flow into native build.
- **What it contains:** #include generated Flutter settings and Debug compiler flags.
- **Responsibilities:** Wire Flutter engine paths and flags into macos Debug compile.
- **When to open:** When behavior tied to `Flutter-Debug.xcconfig` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `macos` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Xcode build configuration (Debug) для Flutter macOS. Передаёт Flutter/CocoaPods/compiler settings в сборку.
- **Зачем:** Xcode подхватывает flags из xcconfig — без них macOS `.app` bundle может не собраться.
- **Содержимое:** `#include` generated Flutter settings и Debug compiler flags.
- **Обязанности:** Прокинуть Flutter/native build settings в Debug macos compile.
- **Когда открывать:** macos build или pod integration падает после Flutter/Xcode upgrade.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Podfile`, `macos/Flutter/`, Xcode Runner target.
- **Слой:** Xcode/macos build config — не Dart UI.


### `macos/Flutter/Flutter-Release.xcconfig`

EN:

- **What this is:** Flutter macos `Release.xcconfig` — passes Flutter/CocoaPods settings into Xcode build.
- **Why needed:** Xcode reads xcconfig when compiling Runner Release; Flutter flags must flow into native build.
- **What it contains:** #include generated Flutter settings and Release compiler flags.
- **Responsibilities:** Wire Flutter engine paths and flags into macos Release compile.
- **When to open:** When behavior tied to `Flutter-Release.xcconfig` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `macos` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Xcode build configuration (Release) для Flutter macOS. Передаёт Flutter/CocoaPods/compiler settings в сборку.
- **Зачем:** Xcode подхватывает flags из xcconfig — без них macOS `.app` bundle может не собраться.
- **Содержимое:** `#include` generated Flutter settings и Release compiler flags.
- **Обязанности:** Прокинуть Flutter/native build settings в Release macos compile.
- **Когда открывать:** macos build или pod integration падает после Flutter/Xcode upgrade.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Podfile`, `macos/Flutter/`, Xcode Runner target.
- **Слой:** Xcode/macos build config — не Dart UI.


### `macos/Flutter/GeneratedPluginRegistrant.swift`

EN:

- **What this is:** macos build file `GeneratedPluginRegistrant.swift` in `macos/Flutter` — required by Flutter/native toolchain.
- **Why needed:** Without `GeneratedPluginRegistrant.swift`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Flutter` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Flutter` — not Dart business logic.
- **When to open:** Build log mentions `GeneratedPluginRegistrant.swift` or `macos/Flutter`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Swift native glue (AppDelegate/Flutter glue) для macos Runner — старт Flutter engine и lifecycle hooks.
- **Зачем:** Apple runner target вызывает Swift glue до первого Dart frame в macOS `.app` bundle.
- **Содержимое:** Swift-классы embedding Flutter на macos.
- **Обязанности:** Native lifecycle/window hooks между Apple OS и Flutter engine на macos.
- **Когда открывать:** Build log mentions `GeneratedPluginRegistrant.swift` or `macos/Flutter`.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner/Info.plist`, Flutter embedder.
- **Слой:** macos Swift glue — не Dart UI.


### `macos/Runner.xcodeproj/project.pbxproj`

EN:

- **What this is:** Xcode project database for macOS Runner — targets, build phases, signing, resources.
- **Why needed:** Xcode opens and builds `.app` bundle through this `project.pbxproj`.
- **What it contains:** PBX targets, file references, build settings, code signing configuration.
- **Responsibilities:** Describe macOS Runner target and build pipeline for `.app` bundle.
- **When to open:** When behavior tied to `project.pbxproj` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `macos` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Главная project database Xcode для macOS Runner. Хранит targets, resources, entitlements, signing и build phases для `.app` bundle.
- **Зачем:** macOS desktop Counter собирается через этот Xcode-проект в `.app` bundle.
- **Содержимое:** PBX targets, entitlements refs, asset catalogs, macOS signing settings.
- **Обязанности:** Описать macOS Runner target и build pipeline для `.app`.
- **Когда открывать:** macOS Xcode build/sign errors; project corruption после merge.
- **Можно удалить?** Нет — без него macOS `.app` не соберётся в Xcode.
- **Связано с:** `macos/Runner/`, `macos/Flutter/`, entitlements plist.
- **Слой:** Xcode macOS project database — не Dart.


### `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`

EN:

- **What this is:** macos build file `IDEWorkspaceChecks.plist` in `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata` — required by Flutter/native toolchain.
- **Why needed:** Without `IDEWorkspaceChecks.plist`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata` — not Dart business logic.
- **When to open:** Build log mentions `IDEWorkspaceChecks.plist` or `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Plist `ideworkspacechecks.plist` — метаданные и конфиг Xcode для macOS `.app` bundle.
- **Зачем:** Xcode/Xcode читает plist при сборке или packaging macOS `.app` bundle.
- **Содержимое:** XML plist keys для `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata`.
- **Обязанности:** Конфигурация/IDE checks для macos build pipeline.
- **Когда открывать:** Build/packaging error ссылается на `ideworkspacechecks.plist`.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner.xcodeproj/`, Flutter embedder.
- **Слой:** macos plist config — не Dart.


### `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`

EN:

- **What this is:** macos build file `Runner.xcscheme` in `macos/Runner.xcodeproj/xcshareddata/xcschemes` — required by Flutter/native toolchain.
- **Why needed:** Without `Runner.xcscheme`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner.xcodeproj/xcshareddata/xcschemes` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner.xcodeproj/xcshareddata/xcschemes` — not Dart business logic.
- **When to open:** Build log mentions `Runner.xcscheme` or `macos/Runner.xcodeproj/xcshareddata/xcschemes`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Xcode scheme `runner.xcscheme` — какой target/configuration Xcode запускает для macos Runner.
- **Зачем:** Run/Archive/Test в Xcode используют scheme; без него team не соберёт {artifact}.
- **Содержимое:** Build/run/test actions, selected target Runner, configuration Debug/Release.
- **Обязанности:** Developer workflow: Run/Archive macOS `.app` bundle из Xcode.
- **Когда открывать:** Scheme missing в Xcode; Archive использует wrong configuration.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner.xcodeproj/`, `macos/Runner/`.
- **Слой:** Xcode scheme macos — developer workflow.


### `macos/Runner.xcworkspace/contents.xcworkspacedata`

EN:

- **What this is:** macos build file `contents.xcworkspacedata` in `macos/Runner.xcworkspace` — required by Flutter/native toolchain.
- **Why needed:** Without `contents.xcworkspacedata`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner.xcworkspace` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner.xcworkspace` — not Dart business logic.
- **When to open:** Build log mentions `contents.xcworkspacedata` or `macos/Runner.xcworkspace`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Xcode workspace metadata для macos — связывает Runner project и CocoaPods workspace.
- **Зачем:** Xcode открывает `.xcworkspace`, а не `.xcodeproj`, когда подключены Flutter pods.
- **Содержимое:** File references на Runner project и Pods.
- **Обязанности:** IDE workspace glue для Xcode + Flutter pods.
- **Когда открывать:** Xcode workspace не открывается; CocoaPods integration broken на macos.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner.xcodeproj/`, `macos/Podfile`.
- **Слой:** Xcode workspace macos — IDE metadata.


### `macos/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`

EN:

- **What this is:** macos build file `IDEWorkspaceChecks.plist` in `macos/Runner.xcworkspace/xcshareddata` — required by Flutter/native toolchain.
- **Why needed:** Without `IDEWorkspaceChecks.plist`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner.xcworkspace/xcshareddata` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner.xcworkspace/xcshareddata` — not Dart business logic.
- **When to open:** Build log mentions `IDEWorkspaceChecks.plist` or `macos/Runner.xcworkspace/xcshareddata`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Plist `ideworkspacechecks.plist` — метаданные и конфиг Xcode для macOS `.app` bundle.
- **Зачем:** Xcode/Xcode читает plist при сборке или packaging macOS `.app` bundle.
- **Содержимое:** XML plist keys для `macos/Runner.xcworkspace/xcshareddata`.
- **Обязанности:** Конфигурация/IDE checks для macos build pipeline.
- **Когда открывать:** Build/packaging error ссылается на `ideworkspacechecks.plist`.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner.xcodeproj/`, Flutter embedder.
- **Слой:** macos plist config — не Dart.


### `macos/Runner/AppDelegate.swift`

EN:

- **What this is:** macos build file `AppDelegate.swift` in `macos/Runner` — required by Flutter/native toolchain.
- **Why needed:** Without `AppDelegate.swift`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner` — not Dart business logic.
- **When to open:** Build log mentions `AppDelegate.swift` or `macos/Runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Swift native glue (AppDelegate/Flutter glue) для macos Runner — старт Flutter engine и lifecycle hooks.
- **Зачем:** Apple runner target вызывает Swift glue до первого Dart frame в macOS `.app` bundle.
- **Содержимое:** Swift-классы embedding Flutter на macos.
- **Обязанности:** Native lifecycle/window hooks между Apple OS и Flutter engine на macos.
- **Когда открывать:** Build log mentions `AppDelegate.swift` or `macos/Runner`.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner/Info.plist`, Flutter embedder.
- **Слой:** macos Swift glue — не Dart UI.


### `macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`

EN:

- **What this is:** macos build file `Contents.json` in `macos/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `Contents.json`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `Contents.json` or `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** JSON manifest `contents.json` в xcassets (AppIcon) — описывает набор PNG для macOS `.app` bundle.
- **Зачем:** Xcode читает `contents.json`, чтобы собрать AppIcon в macOS `.app` bundle.
- **Содержимое:** Список image scales/files для `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Связать PNG assets с AppIcon в Xcode catalog.
- **Когда открывать:** Missing/wrong AppIcon после сборки macos.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner.xcodeproj/`, Info.plist.
- **Слой:** macos asset catalog manifest.


### `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png`

EN:

- **What this is:** macos build file `app_icon_1024.png` in `macos/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `app_icon_1024.png`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `app_icon_1024.png` or `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG `app_icon_1024.png` в xcassets — raster app_icon_1024.png для macOS `.app` bundle.
- **Зачем:** Xcode упаковывает imageset PNG в macOS `.app` bundle bundle.
- **Содержимое:** Растровый PNG в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Launch/icon imagery на macos из asset catalog.
- **Когда открывать:** Wrong/missing launch/icon image для `app_icon_1024.png`.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner.xcodeproj/`, Info.plist.
- **Слой:** macos asset catalog PNG.


### `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png`

EN:

- **What this is:** macos build file `app_icon_128.png` in `macos/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `app_icon_128.png`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `app_icon_128.png` or `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG `app_icon_128.png` в xcassets — raster app_icon_128.png для macOS `.app` bundle.
- **Зачем:** Xcode упаковывает imageset PNG в macOS `.app` bundle bundle.
- **Содержимое:** Растровый PNG в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Launch/icon imagery на macos из asset catalog.
- **Когда открывать:** Wrong/missing launch/icon image для `app_icon_128.png`.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner.xcodeproj/`, Info.plist.
- **Слой:** macos asset catalog PNG.


### `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png`

EN:

- **What this is:** macos build file `app_icon_16.png` in `macos/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `app_icon_16.png`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `app_icon_16.png` or `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG `app_icon_16.png` в xcassets — raster app_icon_16.png для macOS `.app` bundle.
- **Зачем:** Xcode упаковывает imageset PNG в macOS `.app` bundle bundle.
- **Содержимое:** Растровый PNG в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Launch/icon imagery на macos из asset catalog.
- **Когда открывать:** Wrong/missing launch/icon image для `app_icon_16.png`.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner.xcodeproj/`, Info.plist.
- **Слой:** macos asset catalog PNG.


### `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png`

EN:

- **What this is:** macos build file `app_icon_256.png` in `macos/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `app_icon_256.png`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `app_icon_256.png` or `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG `app_icon_256.png` в xcassets — raster app_icon_256.png для macOS `.app` bundle.
- **Зачем:** Xcode упаковывает imageset PNG в macOS `.app` bundle bundle.
- **Содержимое:** Растровый PNG в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Launch/icon imagery на macos из asset catalog.
- **Когда открывать:** Wrong/missing launch/icon image для `app_icon_256.png`.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner.xcodeproj/`, Info.plist.
- **Слой:** macos asset catalog PNG.


### `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png`

EN:

- **What this is:** macos build file `app_icon_32.png` in `macos/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `app_icon_32.png`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `app_icon_32.png` or `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG `app_icon_32.png` в xcassets — raster app_icon_32.png для macOS `.app` bundle.
- **Зачем:** Xcode упаковывает imageset PNG в macOS `.app` bundle bundle.
- **Содержимое:** Растровый PNG в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Launch/icon imagery на macos из asset catalog.
- **Когда открывать:** Wrong/missing launch/icon image для `app_icon_32.png`.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner.xcodeproj/`, Info.plist.
- **Слой:** macos asset catalog PNG.


### `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png`

EN:

- **What this is:** macos build file `app_icon_512.png` in `macos/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `app_icon_512.png`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `app_icon_512.png` or `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG `app_icon_512.png` в xcassets — raster app_icon_512.png для macOS `.app` bundle.
- **Зачем:** Xcode упаковывает imageset PNG в macOS `.app` bundle bundle.
- **Содержимое:** Растровый PNG в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Launch/icon imagery на macos из asset catalog.
- **Когда открывать:** Wrong/missing launch/icon image для `app_icon_512.png`.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner.xcodeproj/`, Info.plist.
- **Слой:** macos asset catalog PNG.


### `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png`

EN:

- **What this is:** macos build file `app_icon_64.png` in `macos/Runner/Assets.xcassets/AppIcon.appiconset` — required by Flutter/native toolchain.
- **Why needed:** Without `app_icon_64.png`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner/Assets.xcassets/AppIcon.appiconset` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner/Assets.xcassets/AppIcon.appiconset` — not Dart business logic.
- **When to open:** Build log mentions `app_icon_64.png` or `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG `app_icon_64.png` в xcassets — raster app_icon_64.png для macOS `.app` bundle.
- **Зачем:** Xcode упаковывает imageset PNG в macOS `.app` bundle bundle.
- **Содержимое:** Растровый PNG в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Launch/icon imagery на macos из asset catalog.
- **Когда открывать:** Wrong/missing launch/icon image для `app_icon_64.png`.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner.xcodeproj/`, Info.plist.
- **Слой:** macos asset catalog PNG.


### `macos/Runner/Base.lproj/MainMenu.xib`

EN:

- **What this is:** macos build file `MainMenu.xib` in `macos/Runner/Base.lproj` — required by Flutter/native toolchain.
- **Why needed:** Without `MainMenu.xib`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner/Base.lproj` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner/Base.lproj` — not Dart business logic.
- **When to open:** Build log mentions `MainMenu.xib` or `macos/Runner/Base.lproj`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Launch UI storyboard/xib для macos Runner — native splash до первого Flutter frame.
- **Зачем:** Apple показывает launch screen из storyboard/xib пока Flutter engine грузит UI.
- **Содержимое:** Interface Builder layout launch screen для macos.
- **Обязанности:** Native launch appearance macos — не Dart widgets.
- **Когда открывать:** Launch flash/orientation wrong на macos; missing launch screen.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner/Info.plist`, asset catalogs.
- **Слой:** macos launch UI — native only.


### `macos/Runner/Configs/AppInfo.xcconfig`

EN:

- **What this is:** macos build file `AppInfo.xcconfig` in `macos/Runner/Configs` — required by Flutter/native toolchain.
- **Why needed:** Without `AppInfo.xcconfig`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner/Configs` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner/Configs` — not Dart business logic.
- **When to open:** Build log mentions `AppInfo.xcconfig` or `macos/Runner/Configs`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Xcode build configuration (Warnings/AppInfo) для Xcode macos Runner. Передаёт Flutter/CocoaPods/compiler settings в сборку.
- **Зачем:** Xcode подхватывает flags из xcconfig — без них macOS `.app` bundle может не собраться.
- **Содержимое:** `#include` generated Flutter settings и Warnings/AppInfo compiler flags.
- **Обязанности:** Прокинуть Flutter/native build settings в Warnings/AppInfo macos compile.
- **Когда открывать:** macos build или pod integration падает после Flutter/Xcode upgrade.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Podfile`, `macos/Flutter/`, Xcode Runner target.
- **Слой:** Xcode/macos build config — не Dart UI.


### `macos/Runner/Configs/Debug.xcconfig`

EN:

- **What this is:** macos build file `Debug.xcconfig` in `macos/Runner/Configs` — required by Flutter/native toolchain.
- **Why needed:** Without `Debug.xcconfig`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner/Configs` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner/Configs` — not Dart business logic.
- **When to open:** Build log mentions `Debug.xcconfig` or `macos/Runner/Configs`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Xcode build configuration (Debug) для Xcode macos Runner. Передаёт Flutter/CocoaPods/compiler settings в сборку.
- **Зачем:** Xcode подхватывает flags из xcconfig — без них macOS `.app` bundle может не собраться.
- **Содержимое:** `#include` generated Flutter settings и Debug compiler flags.
- **Обязанности:** Прокинуть Flutter/native build settings в Debug macos compile.
- **Когда открывать:** macos build или pod integration падает после Flutter/Xcode upgrade.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Podfile`, `macos/Flutter/`, Xcode Runner target.
- **Слой:** Xcode/macos build config — не Dart UI.


### `macos/Runner/Configs/Release.xcconfig`

EN:

- **What this is:** macos build file `Release.xcconfig` in `macos/Runner/Configs` — required by Flutter/native toolchain.
- **Why needed:** Without `Release.xcconfig`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner/Configs` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner/Configs` — not Dart business logic.
- **When to open:** Build log mentions `Release.xcconfig` or `macos/Runner/Configs`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Xcode build configuration (Release) для Xcode macos Runner. Передаёт Flutter/CocoaPods/compiler settings в сборку.
- **Зачем:** Xcode подхватывает flags из xcconfig — без них macOS `.app` bundle может не собраться.
- **Содержимое:** `#include` generated Flutter settings и Release compiler flags.
- **Обязанности:** Прокинуть Flutter/native build settings в Release macos compile.
- **Когда открывать:** macos build или pod integration падает после Flutter/Xcode upgrade.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Podfile`, `macos/Flutter/`, Xcode Runner target.
- **Слой:** Xcode/macos build config — не Dart UI.


### `macos/Runner/Configs/Warnings.xcconfig`

EN:

- **What this is:** macos build file `Warnings.xcconfig` in `macos/Runner/Configs` — required by Flutter/native toolchain.
- **Why needed:** Without `Warnings.xcconfig`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner/Configs` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner/Configs` — not Dart business logic.
- **When to open:** Build log mentions `Warnings.xcconfig` or `macos/Runner/Configs`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Xcode build configuration (Warnings/AppInfo) для Xcode macos Runner. Передаёт Flutter/CocoaPods/compiler settings в сборку.
- **Зачем:** Xcode подхватывает flags из xcconfig — без них macOS `.app` bundle может не собраться.
- **Содержимое:** `#include` generated Flutter settings и Warnings/AppInfo compiler flags.
- **Обязанности:** Прокинуть Flutter/native build settings в Warnings/AppInfo macos compile.
- **Когда открывать:** macos build или pod integration падает после Flutter/Xcode upgrade.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Podfile`, `macos/Flutter/`, Xcode Runner target.
- **Слой:** Xcode/macos build config — не Dart UI.


### `macos/Runner/DebugProfile.entitlements`

EN:

- **What this is:** macos build file `DebugProfile.entitlements` in `macos/Runner` — required by Flutter/native toolchain.
- **Why needed:** Without `DebugProfile.entitlements`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner` — not Dart business logic.
- **When to open:** Build log mentions `DebugProfile.entitlements` or `macos/Runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Entitlements plist macOS/iOS — sandbox, hardened runtime, keychain, mic permissions для signing.
- **Зачем:** Codesign embeds entitlements в macOS `.app` bundle; без них notarization/App Store reject.
- **Содержимое:** XML entitlement keys для sandbox, network, mic, etc.
- **Обязанности:** Declare OS capabilities allowed in signed macOS `.app` bundle.
- **Когда открывать:** Signing/notarization fail; capability missing at runtime на macos.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner.xcodeproj/`, signing settings.
- **Слой:** macos signing entitlements — не Dart.


### `macos/Runner/Info.plist`

EN:

- **What this is:** iOS/macOS bundle Info.plist — permissions, bundle id, display name.
- **Why needed:** Apple OS reads plist for app metadata and permission prompts.
- **What it contains:** CFBundle keys, usage descriptions (mic, etc.).
- **Responsibilities:** App identity and iOS permission strings.
- **When to open:** When behavior tied to `Info.plist` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `macos` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Файл Info.plist bundle macOS Runner — разрешения, bundle id и display name.
- **Зачем:** Apple OS читает plist для metadata приложения и permission prompts.
- **Содержимое:** Ключи CFBundle, usage descriptions (микрофон и др.).
- **Обязанности:** Идентичность app и permission strings на macOS.
- **Когда открывать:** Неверное имя app или permission prompt на macOS.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner/`, Xcode-проект.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `macos/Runner/MainFlutterWindow.swift`

EN:

- **What this is:** macos build file `MainFlutterWindow.swift` in `macos/Runner` — required by Flutter/native toolchain.
- **Why needed:** Without `MainFlutterWindow.swift`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner` — not Dart business logic.
- **When to open:** Build log mentions `MainFlutterWindow.swift` or `macos/Runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Swift native glue (macOS Flutter window host) для macos Runner — старт Flutter engine и lifecycle hooks.
- **Зачем:** Apple runner target вызывает Swift glue до первого Dart frame в macOS `.app` bundle.
- **Содержимое:** Swift-классы embedding Flutter на macos.
- **Обязанности:** Native lifecycle/window hooks между Apple OS и Flutter engine на macos.
- **Когда открывать:** Build log mentions `MainFlutterWindow.swift` or `macos/Runner`.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner/Info.plist`, Flutter embedder.
- **Слой:** macos Swift glue — не Dart UI.


### `macos/Runner/Release.entitlements`

EN:

- **What this is:** macos build file `Release.entitlements` in `macos/Runner` — required by Flutter/native toolchain.
- **Why needed:** Without `Release.entitlements`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner` — not Dart business logic.
- **When to open:** Build log mentions `Release.entitlements` or `macos/Runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Entitlements plist macOS/iOS — sandbox, hardened runtime, keychain, mic permissions для signing.
- **Зачем:** Codesign embeds entitlements в macOS `.app` bundle; без них notarization/App Store reject.
- **Содержимое:** XML entitlement keys для sandbox, network, mic, etc.
- **Обязанности:** Declare OS capabilities allowed in signed macOS `.app` bundle.
- **Когда открывать:** Signing/notarization fail; capability missing at runtime на macos.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner.xcodeproj/`, signing settings.
- **Слой:** macos signing entitlements — не Dart.


### `macos/RunnerTests/RunnerTests.swift`

EN:

- **What this is:** macos build file `RunnerTests.swift` in `macos/RunnerTests` — required by Flutter/native toolchain.
- **Why needed:** Without `RunnerTests.swift`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/RunnerTests` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/RunnerTests` — not Dart business logic.
- **When to open:** Build log mentions `RunnerTests.swift` or `macos/RunnerTests`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Swift native glue (XCTest smoke entry) для macos Runner — старт Flutter engine и lifecycle hooks.
- **Зачем:** Apple runner target вызывает Swift glue до первого Dart frame в macOS `.app` bundle.
- **Содержимое:** Swift-классы embedding Flutter на macos.
- **Обязанности:** Native lifecycle/window hooks между Apple OS и Flutter engine на macos.
- **Когда открывать:** Build log mentions `RunnerTests.swift` or `macos/RunnerTests`.
- **Можно удалить?** Нет — без него не соберётся macOS `.app` bundle.
- **Связано с:** `macos/Runner/Info.plist`, Flutter embedder.
- **Слой:** macos Swift glue — не Dart UI.


### `pb_hooks/auth.request_password_reset.pb.js`

EN:

- **What this is:** PocketBase server hook `auth.request_password_reset` — runs on VPS when specific API events fire.
- **Why needed:** Some rules (password reset email, overlapping records) must be enforced server-side.
- **What it contains:** JavaScript hook handler copied to PocketBase `pb_hooks/` on server.
- **Responsibilities:** Server-side logic for `auth.request_password_reset` (see `docs/POCKETBASE_MANIFEST.md`).
- **When to open:** Server behavior differs from app expectations for auth/records.
- **Can it be deleted?** No — production PocketBase deployment.
- **Connected to:** PocketBase Admin, Flutter auth/records client.
- **Layer / owner:** Server hook — not in app binary.

RU:

- **Что это:** PocketBase hook `auth.request_password_reset` — серверная логика при API-событиях на VPS.
- **Зачем:** Часть правил (reset пароля, overlap записей) должна выполняться на сервере, не в APK.
- **Содержимое:** JavaScript handler `auth.request_password_reset.pb.js` — копируется в PocketBase `pb_hooks/` на VPS.
- **Обязанности:** Серверная логика для `auth.request_password_reset` (см. `docs/POCKETBASE_MANIFEST.md`).
- **Когда открывать:** Поведение auth/records на сервере не совпадает с ожиданиями приложения.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** PocketBase Admin, Flutter auth/records client.
- **Слой:** Server hook — не в бинарнике приложения.


### `pb_hooks/records.interval_sanitize.pb.js`

EN:

- **What this is:** PocketBase server hook `records.interval_sanitize` — runs on VPS when specific API events fire.
- **Why needed:** Some rules (password reset email, overlapping records) must be enforced server-side.
- **What it contains:** JavaScript hook handler copied to PocketBase `pb_hooks/` on server.
- **Responsibilities:** Server-side logic for `records.interval_sanitize` (see `docs/POCKETBASE_MANIFEST.md`).
- **When to open:** Server behavior differs from app expectations for auth/records.
- **Can it be deleted?** No — production PocketBase deployment.
- **Connected to:** PocketBase Admin, Flutter auth/records client.
- **Layer / owner:** Server hook — not in app binary.

RU:

- **Что это:** PocketBase hook `records.interval_sanitize` — серверная логика при API-событиях на VPS.
- **Зачем:** Часть правил (reset пароля, overlap записей) должна выполняться на сервере, не в APK.
- **Содержимое:** JavaScript handler `records.interval_sanitize.pb.js` — копируется в PocketBase `pb_hooks/` на VPS.
- **Обязанности:** Серверная логика для `records.interval_sanitize` (см. `docs/POCKETBASE_MANIFEST.md`).
- **Когда открывать:** Поведение auth/records на сервере не совпадает с ожиданиями приложения.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** PocketBase Admin, Flutter auth/records client.
- **Слой:** Server hook — не в бинарнике приложения.


### `pubspec.lock`

EN:

- **What this is:** Dependency lockfile — exact resolved versions of every Dart/Flutter package.
- **Why needed:** Tomorrow's build must use the same library versions as today; prevents surprise breakages from upstream package updates.
- **What it contains:** Pinned versions for direct and transitive dependencies after `flutter pub get`.
- **Responsibilities:** Reproducible builds across machines and CI.
- **When to open:** After `flutter pub get` changes versions; investigating version-specific bugs.
- **Can it be deleted?** No — required for reproducible app builds.
- **Connected to:** `pubspec.yaml`, CI, all developer machines.
- **Layer / owner:** Dependency lock — commit to git.

RU:

- **Что это:** Lock-файл зависимостей. Фиксирует точные версии пакетов, которые реально были resolved.
- **Зачем:** Чтобы сборка завтра не взяла другие версии библиотек и не получила новый баг.
- **Содержимое:** Зафиксированные версии прямых и транзитивных зависимостей после `flutter pub get`.
- **Обязанности:** Одинаковые версии пакетов на всех машинах и в CI.
- **Когда открывать:** После изменения зависимостей; расследование бага конкретной версии пакета.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** `pubspec.yaml`, CI, все разработчики.
- **Слой:** Lock зависимостей — коммитится в git.


### `pubspec.yaml`

EN:

- **What this is:** Main Flutter app manifest — package name, SDK constraints, dependencies, assets, fonts.
- **Why needed:** Flutter cannot resolve packages or build without this file; every `package:counter/...` import depends on the name here.
- **What it contains:** Dependencies (PocketBase SDK, voice, notifications, calendar), asset lists, Flutter plugin config.
- **Responsibilities:** Declare app identity `counter`, version, and all third-party packages.
- **When to open:** Adding a Flutter package, bumping app version, registering new assets/fonts.
- **Can it be deleted?** No — Flutter cannot build without it.
- **Connected to:** `pubspec.lock`, `flutter pub get`, all Dart imports.
- **Layer / owner:** Build manifest — required for every platform build.

RU:

- **Что это:** Главный паспорт Flutter-приложения: имя package, версии SDK, зависимости, assets, fonts, flutter settings.
- **Зачем:** Без этого файла Flutter не соберёт приложение и не подтянет пакеты.
- **Содержимое:** Зависимости (PocketBase, voice, notifications и др.), assets, plugins.
- **Обязанности:** Объявить package `counter`, версию и все библиотеки.
- **Когда открывать:** Добавление пакета, смена версии приложения, новые assets.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** `pubspec.lock`, `flutter pub get`, все import в Dart.
- **Слой:** Манифест сборки — нужен на всех платформах.


### `scripts/audit/architecture_guard.ps1`

EN:

- **What this is:** Checks repo structure rules — forbidden imports, required docs, large-file warnings.
- **Why needed:** Prevents accidental architecture breaks during refactors.
- **What it contains:** PowerShell rules matching `docs/APP_STRUCTURE.md`.
- **Responsibilities:** Exit non-zero in `-Strict` mode on violations.
- **When to open:** Before merge; after moving files.
- **Can it be deleted?** No — required for audit workflow.
- **Connected to:** `docs/APP_STRUCTURE.md`, CI optional.
- **Layer / owner:** Audit script.

RU:

- **Что это:** Dev/CI скрипт `architecture_guard.ps1` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `architecture_guard.ps1`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `architecture_guard.ps1` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `docs/APP_STRUCTURE.md`, CI optional.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/check_no_preparing_ui.ps1`

EN:

- **What this is:** Developer script `check_no_preparing_ui.ps1` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `check_no_preparing_ui.ps1`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `check_no_preparing_ui.ps1` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `check_no_preparing_ui.ps1` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `check_no_preparing_ui.ps1`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `check_no_preparing_ui.ps1` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/export_price_reporter_timesheet.dart`

EN:

- **What this is:** Manual export of Price Reporter timeline records to CSV for owner billing/reporting.
- **Why needed:** Internal business reporting — not an in-app user feature.
- **What it contains:** Read-only PocketBase queries + CSV writer to `exports/`.
- **Key code names:** `_ExportRow`
- **Responsibilities:** Generate timesheet CSV for configured date range.
- **When to open:** Owner runs monthly Price Reporter billing export.
- **Can it be deleted?** Maybe — manual owner utility; keep unless export no longer used.
- **Connected to:** `docs/website/INTERNAL_NOTES_NOT_FOR_SITE.md`, `exports/` folder.
- **Layer / owner:** Manual owner script — not shipped in app.

RU:

- **Что это:** Dev/CI скрипт `export_price_reporter_timesheet.dart` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `export_price_reporter_timesheet.dart`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `export_price_reporter_timesheet.dart` по инструкции в repo docs.
- **Можно удалить?** Возможно — ручной экспорт для биллинга; удалять только если не используете.
- **Связано с:** `docs/website/INTERNAL_NOTES_NOT_FOR_SITE.md`, `exports/` folder.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/generate_app_structure_detailed.py`

EN:

- **What this is:** Builds this document (`APP_STRUCTURE_DETAILED.md`) from git file list + role map.
- **Why needed:** Maintains owner-readable structure guide in sync with repo after changes.
- **What it contains:** Python generator + curated folder/file descriptions.
- **Responsibilities:** Regenerate detailed structure encyclopedia.
- **When to open:** After adding/removing tracked files; after editing structure docs.
- **Can it be deleted?** No — required for structure doc generation.
- **Connected to:** `docs/APP_STRUCTURE.md`, `structure_guide_data.py`.
- **Layer / owner:** Doc generation script.

RU:

- **Что это:** Dev/CI скрипт `generate_app_structure_detailed.py` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `generate_app_structure_detailed.py`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `generate_app_structure_detailed.py` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `docs/APP_STRUCTURE.md`, `structure_guide_data.py`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/run_desktop_voice_acceptance.ps1`

EN:

- **What this is:** Developer script `run_desktop_voice_acceptance.ps1` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `run_desktop_voice_acceptance.ps1`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `run_desktop_voice_acceptance.ps1` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `run_desktop_voice_acceptance.ps1` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `run_desktop_voice_acceptance.ps1`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `run_desktop_voice_acceptance.ps1` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/smoke_desktop_hotkey.ps1`

EN:

- **What this is:** Developer script `smoke_desktop_hotkey.ps1` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `smoke_desktop_hotkey.ps1`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `smoke_desktop_hotkey.ps1` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `smoke_desktop_hotkey.ps1` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `smoke_desktop_hotkey.ps1`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `smoke_desktop_hotkey.ps1` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/smoke_desktop_voice_helper_failure.ps1`

EN:

- **What this is:** Developer script `smoke_desktop_voice_helper_failure.ps1` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `smoke_desktop_voice_helper_failure.ps1`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `smoke_desktop_voice_helper_failure.ps1` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `smoke_desktop_voice_helper_failure.ps1` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `smoke_desktop_voice_helper_failure.ps1`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `smoke_desktop_voice_helper_failure.ps1` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/smoke_desktop_voice_helper_selftest.ps1`

EN:

- **What this is:** Developer script `smoke_desktop_voice_helper_selftest.ps1` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `smoke_desktop_voice_helper_selftest.ps1`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `smoke_desktop_voice_helper_selftest.ps1` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `smoke_desktop_voice_helper_selftest.ps1` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `smoke_desktop_voice_helper_selftest.ps1`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `smoke_desktop_voice_helper_selftest.ps1` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/smoke_desktop_voice_recording_first.ps1`

EN:

- **What this is:** Developer script `smoke_desktop_voice_recording_first.ps1` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `smoke_desktop_voice_recording_first.ps1`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `smoke_desktop_voice_recording_first.ps1` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `smoke_desktop_voice_recording_first.ps1` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `smoke_desktop_voice_recording_first.ps1`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `smoke_desktop_voice_recording_first.ps1` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/structure_doc_file_guides.py`

EN:

- **What this is:** Developer script `structure_doc_file_guides.py` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `structure_doc_file_guides.py`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `structure_doc_file_guides.py` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `structure_doc_file_guides.py` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `structure_doc_file_guides.py`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `structure_doc_file_guides.py` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/structure_en_ru_adapt.py`

EN:

- **What this is:** Developer script `structure_en_ru_adapt.py` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `structure_en_ru_adapt.py`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `structure_en_ru_adapt.py` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `structure_en_ru_adapt.py` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `structure_en_ru_adapt.py`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `structure_en_ru_adapt.py` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/structure_file_ru_curated.py`

EN:

- **What this is:** Developer script `structure_file_ru_curated.py` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `structure_file_ru_curated.py`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `structure_file_ru_curated.py` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `structure_file_ru_curated.py` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `structure_file_ru_curated.py`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `structure_file_ru_curated.py` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/structure_folder_ru_curated.py`

EN:

- **What this is:** Developer script `structure_folder_ru_curated.py` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `structure_folder_ru_curated.py`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `structure_folder_ru_curated.py` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `structure_folder_ru_curated.py` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `structure_folder_ru_curated.py`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `structure_folder_ru_curated.py` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/structure_folder_ru_lib.py`

EN:

- **What this is:** Developer script `structure_folder_ru_lib.py` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `structure_folder_ru_lib.py`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `structure_folder_ru_lib.py` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `structure_folder_ru_lib.py` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `structure_folder_ru_lib.py`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `structure_folder_ru_lib.py` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/structure_guide_data.py`

EN:

- **What this is:** Developer script `structure_guide_data.py` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `structure_guide_data.py`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `structure_guide_data.py` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `structure_guide_data.py` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `structure_guide_data.py`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `structure_guide_data.py` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/structure_lib_file_guides.py`

EN:

- **What this is:** Developer script `structure_lib_file_guides.py` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `structure_lib_file_guides.py`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `structure_lib_file_guides.py` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `structure_lib_file_guides.py` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `structure_lib_file_guides.py`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `structure_lib_file_guides.py` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/structure_platform_file_guides.py`

EN:

- **What this is:** Developer script `structure_platform_file_guides.py` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `structure_platform_file_guides.py`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `structure_platform_file_guides.py` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `structure_platform_file_guides.py` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `structure_platform_file_guides.py`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `structure_platform_file_guides.py` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/structure_role_guides.py`

EN:

- **What this is:** Developer script `structure_role_guides.py` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `structure_role_guides.py`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `structure_role_guides.py` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `structure_role_guides.py` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `structure_role_guides.py`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `structure_role_guides.py` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/structure_root_guides.py`

EN:

- **What this is:** Developer script `structure_root_guides.py` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `structure_root_guides.py`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `structure_root_guides.py` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `structure_root_guides.py` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `structure_root_guides.py`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `structure_root_guides.py` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/structure_ru_class_adapters.py`

EN:

- **What this is:** Developer script `structure_ru_class_adapters.py` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `structure_ru_class_adapters.py`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `structure_ru_class_adapters.py` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `structure_ru_class_adapters.py` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `structure_ru_class_adapters.py`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `structure_ru_class_adapters.py` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/structure_ru_helpers.py`

EN:

- **What this is:** Developer script `structure_ru_helpers.py` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `structure_ru_helpers.py`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `structure_ru_helpers.py` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `structure_ru_helpers.py` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `structure_ru_helpers.py`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `structure_ru_helpers.py` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/structure_scan.ps1`

EN:

- **What this is:** Developer script `structure_scan.ps1` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `structure_scan.ps1`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `structure_scan.ps1` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `structure_scan.ps1` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `structure_scan.ps1`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `structure_scan.ps1` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/td`

EN:

- **What this is:** Developer script `td` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `td`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `td` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `td` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `td`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `td` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/td.ps1`

EN:

- **What this is:** Developer script `td.ps1` — run manually for maintenance, smoke test, or deploy helper.
- **Why needed:** Automates a repeatable task documented in repo notes or `DEPLOY.md`.
- **What it contains:** PowerShell, Python, or Dart commands for `td.ps1`.
- **Responsibilities:** See script header comments for exact behavior.
- **When to open:** When workflow documented for `td.ps1` is needed.
- **Can it be deleted?** No — part of documented dev workflow unless cleanup report removed it.
- **Connected to:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Layer / owner:** Developer script.

RU:

- **Что это:** Dev/CI скрипт `td.ps1` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `td.ps1`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `td.ps1` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/sync_locales.dart`

EN:

- **What this is:** Copies translation keys from English/Russian source files into other locale files.
- **Why needed:** Synchronizes `lib/l10n/langs/*.dart` when dictionary keys are added.
- **What it contains:** Dart script scanning dictionary keys.
- **Key code names:** `main`, `_MapRegion`
- **Responsibilities:** Run after editing `en.dart` / `ru.dart`.
- **When to open:** Missing translation key in non-EN/RU locale.
- **Can it be deleted?** No — locale SSOT workflow.
- **Connected to:** `lib/l10n/langs/HELP HOW TO UPDATE the languages`.
- **Layer / owner:** Locale maintenance script.

RU:

- **Что это:** Dev/CI скрипт `sync_locales.dart` — повторяемая команда из repo docs.
- **Зачем:** Автоматизирует deploy, audit или maintenance без ad-hoc notes.
- **Содержимое:** Команды PowerShell/Python/Dart в `sync_locales.dart`.
- **Обязанности:** Workflow, описанный в header или `docs/DEPLOY.md`.
- **Когда открывать:** Owner или CI запускает `sync_locales.dart` по инструкции в repo docs.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `lib/l10n/langs/HELP HOW TO UPDATE the languages`.
- **Слой:** Dev/CI script — не runtime приложения.


### `test/app_hotkey_keycaps_test.dart`

EN:

- **What this is:** Automated test `app_hotkey_keycaps_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `app_hotkey_keycaps_test` scenario.
- **When to open:** CI failure or changing code near `app_hotkey_keycaps`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `app_hotkey_keycaps` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `app_hotkey_keycaps`.
- **Обязанности:** Assert ожидаемого поведения `app_hotkey_keycaps`.
- **Когда открывать:** Падение CI или правка кода рядом с `app_hotkey_keycaps`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/app_timezone_icon_test.dart`

EN:

- **What this is:** Automated test `app_timezone_icon_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `app_timezone_icon_test` scenario.
- **When to open:** CI failure or changing code near `app_timezone_icon`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `app_timezone_icon` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `app_timezone_icon`.
- **Обязанности:** Assert ожидаемого поведения `app_timezone_icon`.
- **Когда открывать:** Падение CI или правка кода рядом с `app_timezone_icon`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/desktop_voice_attempt_dialog_test.dart`

EN:

- **What this is:** Automated test `desktop_voice_attempt_dialog_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `desktop_voice_attempt_dialog_test` scenario.
- **When to open:** CI failure or changing code near `desktop_voice_attempt_dialog`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `desktop_voice_attempt_dialog` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `desktop_voice_attempt_dialog`.
- **Обязанности:** Assert ожидаемого поведения `desktop_voice_attempt_dialog`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_attempt_dialog`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/desktop_voice_attempt_log_test.dart`

EN:

- **What this is:** Automated test `desktop_voice_attempt_log_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `desktop_voice_attempt_log_test` scenario.
- **When to open:** CI failure or changing code near `desktop_voice_attempt_log`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `desktop_voice_attempt_log` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `desktop_voice_attempt_log`.
- **Обязанности:** Assert ожидаемого поведения `desktop_voice_attempt_log`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_attempt_log`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/desktop_voice_command_acceptance_test.dart`

EN:

- **What this is:** Automated test `desktop_voice_command_acceptance_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `desktop_voice_command_acceptance_test` scenario.
- **When to open:** CI failure or changing code near `desktop_voice_command_acceptance`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `desktop_voice_command_acceptance` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `desktop_voice_command_acceptance`.
- **Обязанности:** Assert ожидаемого поведения `desktop_voice_command_acceptance`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_command_acceptance`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/desktop_voice_helper_failure_test.dart`

EN:

- **What this is:** Automated test `desktop_voice_helper_failure_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `desktop_voice_helper_failure_test` scenario.
- **When to open:** CI failure or changing code near `desktop_voice_helper_failure`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `desktop_voice_helper_failure` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `desktop_voice_helper_failure`.
- **Обязанности:** Assert ожидаемого поведения `desktop_voice_helper_failure`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_helper_failure`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/desktop_voice_hotkey_self_acceptance_test.dart`

EN:

- **What this is:** Automated test `desktop_voice_hotkey_self_acceptance_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `desktop_voice_hotkey_self_acceptance_test` scenario.
- **When to open:** CI failure or changing code near `desktop_voice_hotkey_self_acceptance`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `desktop_voice_hotkey_self_acceptance` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `desktop_voice_hotkey_self_acceptance`.
- **Обязанности:** Assert ожидаемого поведения `desktop_voice_hotkey_self_acceptance`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_hotkey_self_acceptance`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/desktop_voice_hotkey_state_machine_test.dart`

EN:

- **What this is:** Automated test `desktop_voice_hotkey_state_machine_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `desktop_voice_hotkey_state_machine_test` scenario.
- **When to open:** CI failure or changing code near `desktop_voice_hotkey_state_machine`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `desktop_voice_hotkey_state_machine` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `desktop_voice_hotkey_state_machine`.
- **Обязанности:** Assert ожидаемого поведения `desktop_voice_hotkey_state_machine`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_hotkey_state_machine`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/desktop_voice_laredo_multi_scope_test.dart`

EN:

- **What this is:** Automated test `desktop_voice_laredo_multi_scope_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `desktop_voice_laredo_multi_scope_test` scenario.
- **When to open:** CI failure or changing code near `desktop_voice_laredo_multi_scope`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `desktop_voice_laredo_multi_scope` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `desktop_voice_laredo_multi_scope`.
- **Обязанности:** Assert ожидаемого поведения `desktop_voice_laredo_multi_scope`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_laredo_multi_scope`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/desktop_voice_mic_peak_visibility_test.dart`

EN:

- **What this is:** Automated test `desktop_voice_mic_peak_visibility_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `desktop_voice_mic_peak_visibility_test` scenario.
- **When to open:** CI failure or changing code near `desktop_voice_mic_peak_visibility`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `desktop_voice_mic_peak_visibility` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `desktop_voice_mic_peak_visibility`.
- **Обязанности:** Assert ожидаемого поведения `desktop_voice_mic_peak_visibility`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_mic_peak_visibility`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/desktop_voice_no_preparing_ui_test.dart`

EN:

- **What this is:** Automated test `desktop_voice_no_preparing_ui_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `desktop_voice_no_preparing_ui_test` scenario.
- **When to open:** CI failure or changing code near `desktop_voice_no_preparing_ui`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `desktop_voice_no_preparing_ui` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `desktop_voice_no_preparing_ui`.
- **Обязанности:** Assert ожидаемого поведения `desktop_voice_no_preparing_ui`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_no_preparing_ui`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/desktop_voice_overlay_state_test.dart`

EN:

- **What this is:** Automated test `desktop_voice_overlay_state_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `desktop_voice_overlay_state_test` scenario.
- **When to open:** CI failure or changing code near `desktop_voice_overlay_state`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `desktop_voice_overlay_state` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `desktop_voice_overlay_state`.
- **Обязанности:** Assert ожидаемого поведения `desktop_voice_overlay_state`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_overlay_state`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/desktop_voice_production_submit_test.dart`

EN:

- **What this is:** Automated test `desktop_voice_production_submit_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `desktop_voice_production_submit_test` scenario.
- **When to open:** CI failure or changing code near `desktop_voice_production_submit`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `desktop_voice_production_submit` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `desktop_voice_production_submit`.
- **Обязанности:** Assert ожидаемого поведения `desktop_voice_production_submit`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_production_submit`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/desktop_voice_settings_mic_layout_test.dart`

EN:

- **What this is:** Automated test `desktop_voice_settings_mic_layout_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: _TestMicrophoneCard, main).
- **Key code names:** `_TestMicrophoneCard`, `main`
- **Responsibilities:** Assert expected behavior for `desktop_voice_settings_mic_layout_test` scenario.
- **When to open:** CI failure or changing code near `desktop_voice_settings_mic_layout`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `desktop_voice_settings_mic_layout` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `desktop_voice_settings_mic_layout`.
- **Обязанности:** Assert ожидаемого поведения `desktop_voice_settings_mic_layout`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_settings_mic_layout`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/desktop_voice_user_error_test.dart`

EN:

- **What this is:** Automated test `desktop_voice_user_error_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `desktop_voice_user_error_test` scenario.
- **When to open:** CI failure or changing code near `desktop_voice_user_error`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `desktop_voice_user_error` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `desktop_voice_user_error`.
- **Обязанности:** Assert ожидаемого поведения `desktop_voice_user_error`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_user_error`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/desktop_voice_widget_e2e_test.dart`

EN:

- **What this is:** Automated test `desktop_voice_widget_e2e_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: _E2EOutcome, main).
- **Key code names:** `_E2EOutcome`, `main`
- **Responsibilities:** Assert expected behavior for `desktop_voice_widget_e2e_test` scenario.
- **When to open:** CI failure or changing code near `desktop_voice_widget_e2e`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `desktop_voice_widget_e2e` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `desktop_voice_widget_e2e`.
- **Обязанности:** Assert ожидаемого поведения `desktop_voice_widget_e2e`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_widget_e2e`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/edit_sheet_autosave_test.dart`

EN:

- **What this is:** Automated test `edit_sheet_autosave_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `edit_sheet_autosave_test` scenario.
- **When to open:** CI failure or changing code near `edit_sheet_autosave`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `edit_sheet_autosave` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `edit_sheet_autosave`.
- **Обязанности:** Assert ожидаемого поведения `edit_sheet_autosave`.
- **Когда открывать:** Падение CI или правка кода рядом с `edit_sheet_autosave`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/outbox_coalesce_regression_test.dart`

EN:

- **What this is:** Automated test `outbox_coalesce_regression_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `outbox_coalesce_regression_test` scenario.
- **When to open:** CI failure or changing code near `outbox_coalesce_regression`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `outbox_coalesce_regression` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `outbox_coalesce_regression`.
- **Обязанности:** Assert ожидаемого поведения `outbox_coalesce_regression`.
- **Когда открывать:** Падение CI или правка кода рядом с `outbox_coalesce_regression`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/perf_date_swipe_diag_test.dart`

EN:

- **What this is:** Automated test `perf_date_swipe_diag_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `perf_date_swipe_diag_test` scenario.
- **When to open:** CI failure or changing code near `perf_date_swipe_diag`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `perf_date_swipe_diag` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `perf_date_swipe_diag`.
- **Обязанности:** Assert ожидаемого поведения `perf_date_swipe_diag`.
- **Когда открывать:** Падение CI или правка кода рядом с `perf_date_swipe_diag`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/perf_shell_date_settle_test.dart`

EN:

- **What this is:** Automated test `perf_shell_date_settle_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: _ShellDateHarness, _ShellDateHarnessState, main).
- **Key code names:** `_ShellDateHarness`, `_ShellDateHarnessState`, `main`
- **Responsibilities:** Assert expected behavior for `perf_shell_date_settle_test` scenario.
- **When to open:** CI failure or changing code near `perf_shell_date_settle`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `perf_shell_date_settle` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `perf_shell_date_settle`.
- **Обязанности:** Assert ожидаемого поведения `perf_shell_date_settle`.
- **Когда открывать:** Падение CI или правка кода рядом с `perf_shell_date_settle`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/plan_recurrence_scope_test.dart`

EN:

- **What this is:** Automated test `plan_recurrence_scope_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `plan_recurrence_scope_test` scenario.
- **When to open:** CI failure or changing code near `plan_recurrence_scope`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `plan_recurrence_scope` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `plan_recurrence_scope`.
- **Обязанности:** Assert ожидаемого поведения `plan_recurrence_scope`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_recurrence_scope`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/plan_time_bulk_drag_test.dart`

EN:

- **What this is:** Automated test `plan_time_bulk_drag_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `plan_time_bulk_drag_test` scenario.
- **When to open:** CI failure or changing code near `plan_time_bulk_drag`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `plan_time_bulk_drag` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `plan_time_bulk_drag`.
- **Обязанности:** Assert ожидаемого поведения `plan_time_bulk_drag`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_bulk_drag`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/plan_time_drag_gesture_contract_test.dart`

EN:

- **What this is:** Automated test `plan_time_drag_gesture_contract_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `plan_time_drag_gesture_contract_test` scenario.
- **When to open:** CI failure or changing code near `plan_time_drag_gesture_contract`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `plan_time_drag_gesture_contract` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `plan_time_drag_gesture_contract`.
- **Обязанности:** Assert ожидаемого поведения `plan_time_drag_gesture_contract`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_drag_gesture_contract`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/plan_time_duration_fidelity_test.dart`

EN:

- **What this is:** Automated test `plan_time_duration_fidelity_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `plan_time_duration_fidelity_test` scenario.
- **When to open:** CI failure or changing code near `plan_time_duration_fidelity`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `plan_time_duration_fidelity` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `plan_time_duration_fidelity`.
- **Обязанности:** Assert ожидаемого поведения `plan_time_duration_fidelity`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_duration_fidelity`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/plan_time_fixed_time_policy_test.dart`

EN:

- **What this is:** Automated test `plan_time_fixed_time_policy_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `plan_time_fixed_time_policy_test` scenario.
- **When to open:** CI failure or changing code near `plan_time_fixed_time_policy`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `plan_time_fixed_time_policy` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `plan_time_fixed_time_policy`.
- **Обязанности:** Assert ожидаемого поведения `plan_time_fixed_time_policy`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_fixed_time_policy`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/plan_time_sequential_cascade_test.dart`

EN:

- **What this is:** Automated test `plan_time_sequential_cascade_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `plan_time_sequential_cascade_test` scenario.
- **When to open:** CI failure or changing code near `plan_time_sequential_cascade`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `plan_time_sequential_cascade` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `plan_time_sequential_cascade`.
- **Обязанности:** Assert ожидаемого поведения `plan_time_sequential_cascade`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_sequential_cascade`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/plan_time_target_drop_test.dart`

EN:

- **What this is:** Automated test `plan_time_target_drop_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `plan_time_target_drop_test` scenario.
- **When to open:** CI failure or changing code near `plan_time_target_drop`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `plan_time_target_drop` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `plan_time_target_drop`.
- **Обязанности:** Assert ожидаемого поведения `plan_time_target_drop`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_target_drop`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/plan_time_timezone_projection_test.dart`

EN:

- **What this is:** Automated test `plan_time_timezone_projection_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `plan_time_timezone_projection_test` scenario.
- **When to open:** CI failure or changing code near `plan_time_timezone_projection`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `plan_time_timezone_projection` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `plan_time_timezone_projection`.
- **Обязанности:** Assert ожидаемого поведения `plan_time_timezone_projection`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_timezone_projection`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/plan_time_view_layout_test.dart`

EN:

- **What this is:** Automated test `plan_time_view_layout_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `plan_time_view_layout_test` scenario.
- **When to open:** CI failure or changing code near `plan_time_view_layout`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `plan_time_view_layout` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `plan_time_view_layout`.
- **Обязанности:** Assert ожидаемого поведения `plan_time_view_layout`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_view_layout`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/plan_time_visible_window_test.dart`

EN:

- **What this is:** Automated test `plan_time_visible_window_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `plan_time_visible_window_test` scenario.
- **When to open:** CI failure or changing code near `plan_time_visible_window`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `plan_time_visible_window` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `plan_time_visible_window`.
- **Обязанности:** Assert ожидаемого поведения `plan_time_visible_window`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_visible_window`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/planning_duplicate_plan_guard_test.dart`

EN:

- **What this is:** Automated test `planning_duplicate_plan_guard_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `planning_duplicate_plan_guard_test` scenario.
- **When to open:** CI failure or changing code near `planning_duplicate_plan_guard`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `planning_duplicate_plan_guard` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `planning_duplicate_plan_guard`.
- **Обязанности:** Assert ожидаемого поведения `planning_duplicate_plan_guard`.
- **Когда открывать:** Падение CI или правка кода рядом с `planning_duplicate_plan_guard`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/planning_realtime_stream_lifecycle_test.dart`

EN:

- **What this is:** Automated test `planning_realtime_stream_lifecycle_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `planning_realtime_stream_lifecycle_test` scenario.
- **When to open:** CI failure or changing code near `planning_realtime_stream_lifecycle`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `planning_realtime_stream_lifecycle` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `planning_realtime_stream_lifecycle`.
- **Обязанности:** Assert ожидаемого поведения `planning_realtime_stream_lifecycle`.
- **Когда открывать:** Падение CI или правка кода рядом с `planning_realtime_stream_lifecycle`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/profile_timezone_catalog_test.dart`

EN:

- **What this is:** Automated test `profile_timezone_catalog_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `profile_timezone_catalog_test` scenario.
- **When to open:** CI failure or changing code near `profile_timezone_catalog`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `profile_timezone_catalog` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `profile_timezone_catalog`.
- **Обязанности:** Assert ожидаемого поведения `profile_timezone_catalog`.
- **Когда открывать:** Падение CI или правка кода рядом с `profile_timezone_catalog`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/smart_input_parser_test.dart`

EN:

- **What this is:** Automated test `smart_input_parser_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `smart_input_parser_test` scenario.
- **When to open:** CI failure or changing code near `smart_input_parser`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `smart_input_parser` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `smart_input_parser`.
- **Обязанности:** Assert ожидаемого поведения `smart_input_parser`.
- **Когда открывать:** Падение CI или правка кода рядом с `smart_input_parser`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/timezone_quick_picker_test.dart`

EN:

- **What this is:** Automated test `timezone_quick_picker_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `timezone_quick_picker_test` scenario.
- **When to open:** CI failure or changing code near `timezone_quick_picker`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `timezone_quick_picker` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `timezone_quick_picker`.
- **Обязанности:** Assert ожидаемого поведения `timezone_quick_picker`.
- **Когда открывать:** Падение CI или правка кода рядом с `timezone_quick_picker`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/voice_command_parser_test.dart`

EN:

- **What this is:** Automated test `voice_command_parser_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `voice_command_parser_test` scenario.
- **When to open:** CI failure or changing code near `voice_command_parser`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `voice_command_parser` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `voice_command_parser`.
- **Обязанности:** Assert ожидаемого поведения `voice_command_parser`.
- **Когда открывать:** Падение CI или правка кода рядом с `voice_command_parser`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `test/widget_test.dart`

EN:

- **What this is:** Automated test `widget_test` — verifies behavior without manual tapping.
- **Why needed:** Prevents regressions when related production code changes.
- **What it contains:** Test cases (symbols: main).
- **Key code names:** `main`
- **Responsibilities:** Assert expected behavior for `widget_test` scenario.
- **When to open:** CI failure or changing code near `widget`.
- **Can it be deleted?** No — required for tests.
- **Connected to:** Matching files under `lib/` with similar name.
- **Layer / owner:** Test — not shipped to users.

RU:

- **Что это:** Автотест `widget` — проверяет поведение без ручного UI.
- **Зачем:** Ловит регрессии при изменении связанного production-кода.
- **Содержимое:** Test cases для сценария `widget`.
- **Обязанности:** Assert ожидаемого поведения `widget`.
- **Когда открывать:** Падение CI или правка кода рядом с `widget`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Production files под `lib/` с похожим именем.
- **Слой:** Автотест — не попадает пользователю в APK.


### `update.ps1`

EN:

- **What this is:** Root deploy shortcut — runs the full web publish pipeline via `scripts/manual/td.ps1`.
- **Why needed:** Owner publishes https://nkuchenov-hash.github.io/Counter/ without memorizing analyze + web build + git push steps.
- **What it contains:** Single line: invoke `td.ps1` (checks env, `flutter analyze`, `flutter build web` with base-href `/Counter/`, commit, push → GitHub Actions deploy).
- **Responsibilities:** Documented entry point for GitHub Pages deploy per `docs/DEPLOY.md`.
- **When to open:** Publishing website after verified code changes.
- **Can it be deleted?** No — documented deploy workflow.
- **Connected to:** `.github/workflows/deploy.yml`, `docs/DEPLOY.md`, `web/index.html`.
- **Layer / owner:** Deploy tooling — not app runtime.

RU:

- **Что это:** Главная команда публикации web-версии. Запускается из root; вызывает `scripts/manual/td.ps1`.
- **Зачем:** Проверяет env, запускает analyze, собирает Flutter web с `/Counter/`, коммитит изменения и пушит в GitHub — после push GitHub Actions публикует сайт.
- **Содержимое:** Одна строка вызова `td.ps1` с полным pipeline из `docs/DEPLOY.md`.
- **Обязанности:** Точка входа для деплоя сайта на GitHub Pages.
- **Когда открывать:** Нужно опубликовать сайт после проверенных изменений.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** `.github/workflows/deploy.yml`, `docs/DEPLOY.md`.
- **Слой:** Deploy tooling — не runtime приложения.


### `web/favicon.png`

EN:

- **What this is:** Small browser tab icon for the web build.
- **Why needed:** Shown in browser tab and bookmarks for `/Counter/` site.
- **What it contains:** PNG favicon asset.
- **Responsibilities:** Web branding in browser chrome.
- **When to open:** Web deploy blank page, icons, base href.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `web` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/Web — tab icon или PWA asset `favicon.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `favicon.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `favicon.png`.
- **Можно удалить?** Нет — без него не соберётся web deploy на GitHub Pages.
- **Связано с:** Flutter `web` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `web/icons/Icon-192.png`

EN:

- **What this is:** Web/PWA icon (192px) for add-to-home-screen.
- **Why needed:** Browsers pick closest icon size for install banner.
- **What it contains:** PNG at fixed square size.
- **Responsibilities:** Icon at 192px for PWA.
- **When to open:** Web deploy blank page, icons, base href.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `web` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/Web — tab icon или PWA asset `icon-192.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-192.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-192.png`.
- **Можно удалить?** Нет — без него не соберётся web deploy на GitHub Pages.
- **Связано с:** Flutter `web` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `web/icons/Icon-512.png`

EN:

- **What this is:** Web/PWA icon (512px) for add-to-home-screen.
- **Why needed:** Browsers pick closest icon size for install banner.
- **What it contains:** PNG at fixed square size.
- **Responsibilities:** Icon at 512px for PWA.
- **When to open:** Web deploy blank page, icons, base href.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `web` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/Web — tab icon или PWA asset `icon-512.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-512.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-512.png`.
- **Можно удалить?** Нет — без него не соберётся web deploy на GitHub Pages.
- **Связано с:** Flutter `web` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `web/icons/Icon-maskable-192.png`

EN:

- **What this is:** Web/PWA icon (maskable-192px) for add-to-home-screen.
- **Why needed:** Browsers pick closest icon size for install banner.
- **What it contains:** PNG at fixed square size.
- **Responsibilities:** Icon at maskable-192px for PWA.
- **When to open:** Web deploy blank page, icons, base href.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `web` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/Web — tab icon или PWA asset `icon-maskable-192.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-maskable-192.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-maskable-192.png`.
- **Можно удалить?** Нет — без него не соберётся web deploy на GitHub Pages.
- **Связано с:** Flutter `web` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `web/icons/Icon-maskable-512.png`

EN:

- **What this is:** Web/PWA icon (maskable-512px) for add-to-home-screen.
- **Why needed:** Browsers pick closest icon size for install banner.
- **What it contains:** PNG at fixed square size.
- **Responsibilities:** Icon at maskable-512px for PWA.
- **When to open:** Web deploy blank page, icons, base href.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `web` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** PNG-иконка web/Web — tab icon или PWA asset `icon-maskable-512.png`.
- **Зачем:** Браузер и manifest ссылаются на этот PNG после `flutter build web`.
- **Содержимое:** Растровый PNG `icon-maskable-512.png`.
- **Обязанности:** Показать иконку Counter в UI браузера/PWA.
- **Когда открывать:** Пропала иконка вкладки или PWA tile для `icon-maskable-512.png`.
- **Можно удалить?** Нет — без него не соберётся web deploy на GitHub Pages.
- **Связано с:** Flutter `web` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `web/index.html`

EN:

- **What this is:** Web page shell that loads the compiled Flutter web app.
- **Why needed:** Browser needs an HTML entry with base href for GitHub Pages `/Counter/`.
- **What it contains:** Script tags bootstrapping `flutter.js`, base href.
- **Responsibilities:** Start Flutter web engine in browser.
- **When to open:** Blank web page after deploy.
- **Can it be deleted?** No — required for web build.
- **Connected to:** `flutter build web`, `docs/DEPLOY.md`.
- **Layer / owner:** Web platform entry.

RU:

- **Что это:** HTML-оболочка web — загружает скомпилированный Flutter web app.
- **Зачем:** Браузеру нужен entry с base href `/Counter/` для GitHub Pages.
- **Содержимое:** Теги script для `flutter.js` и base href `/Counter/`.
- **Обязанности:** Запустить Flutter web engine в браузере.
- **Когда открывать:** Пустая страница после web deploy.
- **Можно удалить?** Нет — без него не соберётся web deploy на GitHub Pages.
- **Связано с:** `flutter build web`, `docs/DEPLOY.md`.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `web/manifest.json`

EN:

- **What this is:** Web app manifest — name, theme color, icon paths for PWA.
- **Why needed:** Browsers use manifest for install prompt and tab theming.
- **What it contains:** JSON with icons array and display mode.
- **Responsibilities:** PWA metadata for GitHub Pages site.
- **When to open:** Web deploy blank page, icons, base href.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `web` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Web app manifest — имя, theme color, пути иконок PWA.
- **Зачем:** Браузер использует manifest для install prompt и tab theming.
- **Содержимое:** JSON с массивом icons и режимом display для PWA.
- **Обязанности:** PWA metadata для GitHub Pages сайта.
- **Когда открывать:** PWA install prompt или theme color неверны на web.
- **Можно удалить?** Нет — без него не соберётся web deploy на GitHub Pages.
- **Связано с:** Flutter `web` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `windows/.gitignore`

EN:

- **What this is:** Git ignore rules for `windows` — files not to commit.
- **Why needed:** Prevents build output and secrets from entering git history.
- **What it contains:** Ignore patterns for this folder scope.
- **Responsibilities:** Prevent accidental commit of generated files.
- **When to open:** When behavior tied to `.gitignore` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `windows` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Git ignore для `windows/` — не коммитить локальный build-мусор платформы.
- **Зачем:** Gradle/Xcode/CMake генерируют файлы в `windows/`, которые не должны попадать в git.
- **Содержимое:** Ignore patterns для build cache и IDE metadata в `windows/`.
- **Обязанности:** Держать `windows/` tree чистым от generated artifacts.
- **Когда открывать:** Случайно добавили результат сборки `windows/` в git.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** Flutter `windows` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `windows/CMakeLists.txt`

EN:

- **What this is:** CMake build script for `windows` — builds the Flutter `windows` native runner.
- **Why needed:** Native windows desktop compile links Flutter engine via this CMake file in `windows`.
- **What it contains:** CMake targets, source file list, Flutter embedder link rules.
- **Responsibilities:** Produce native binary pieces for `windows` embedder.
- **When to open:** When behavior tied to `CMakeLists.txt` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `windows` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Главный CMake-файл Windows desktop runner. Описывает native targets, source files и link rules, через которые Flutter engine собирается в Windows `.exe`.
- **Зачем:** CMake configure/link связывает `runner/`, `flutter/` glue и plugin registrant в один desktop binary.
- **Содержимое:** project(), add_subdirectory для `flutter/` и `runner/`, toolchain settings.
- **Обязанности:** Собрать Counter Windows `.exe` из native runner + Flutter AOT.
- **Когда открывать:** windows desktop build падает на configure/link; installer не получит рабочий runner.
- **Можно удалить?** Нет — без него `flutter build windows` не соберёт `.exe`.
- **Связано с:** Flutter `windows` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `windows/flutter/CMakeLists.txt`

EN:

- **What this is:** CMake build script for `windows/flutter` — builds the Flutter `windows` native runner.
- **Why needed:** Native windows desktop compile links Flutter engine via this CMake file in `windows/flutter`.
- **What it contains:** CMake targets, source file list, Flutter embedder link rules.
- **Responsibilities:** Produce native binary pieces for `windows/flutter` embedder.
- **When to open:** When behavior tied to `CMakeLists.txt` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `windows` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** сгенерированный Flutter CMake glue для windows — подключает engine и plugin build steps.
- **Зачем:** Flutter tool перезаписывает этот файл при build; связывает Dart AOT с native runner.
- **Содержимое:** Сгенерированные targets для `libflutter`, assets и plugin registrant.
- **Обязанности:** Встраивает Flutter engine и assets в windows desktop build.
- **Когда открывать:** Flutter upgrade изменил generated CMake; plugin link fail на windows.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** Flutter `windows` tooling.
- **Слой:** сгенерированный Flutter windows glue — не править вручную без причины.


### `windows/flutter/generated_plugin_registrant.cc`

EN:

- **What this is:** windows build file `generated_plugin_registrant.cc` in `windows/flutter` — required by Flutter/native toolchain.
- **Why needed:** Without `generated_plugin_registrant.cc`, windows compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `windows/flutter` (open file only when build errors cite it).
- **Responsibilities:** Support windows embedder build for `windows/flutter` — not Dart business logic.
- **When to open:** Build log mentions `generated_plugin_registrant.cc` or `windows/flutter`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `windows/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Generated registrant Flutter plugins (windows) — подключает native plugins embedder.
- **Зачем:** Flutter tooling генерирует этот файл; без него plugins не подключатся.
- **Содержимое:** Auto-generated код регистрации plugins.
- **Обязанности:** Подключить Flutter plugins к native runner.
- **Когда открывать:** Plugin missing после `flutter pub get` / clean build.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** `windows/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `windows/flutter/generated_plugin_registrant.h`

EN:

- **What this is:** windows build file `generated_plugin_registrant.h` in `windows/flutter` — required by Flutter/native toolchain.
- **Why needed:** Without `generated_plugin_registrant.h`, windows compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `windows/flutter` (open file only when build errors cite it).
- **Responsibilities:** Support windows embedder build for `windows/flutter` — not Dart business logic.
- **When to open:** Build log mentions `generated_plugin_registrant.h` or `windows/flutter`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `windows/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Generated registrant Flutter plugins (windows) — подключает native plugins embedder.
- **Зачем:** Flutter tooling генерирует этот файл; без него plugins не подключатся.
- **Содержимое:** Auto-generated код регистрации plugins.
- **Обязанности:** Подключить Flutter plugins к native runner.
- **Когда открывать:** Plugin missing после `flutter pub get` / clean build.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** `windows/` platform folder, Flutter embedder.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `windows/flutter/generated_plugins.cmake`

EN:

- **What this is:** windows build file `generated_plugins.cmake` in `windows/flutter` — required by Flutter/native toolchain.
- **Why needed:** Without `generated_plugins.cmake`, windows compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `windows/flutter` (open file only when build errors cite it).
- **Responsibilities:** Support windows embedder build for `windows/flutter` — not Dart business logic.
- **When to open:** Build log mentions `generated_plugins.cmake` or `windows/flutter`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `windows/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** CMake fragment `generated_plugins.cmake` — сгенерированный Flutter plugin build rules для windows desktop.
- **Зачем:** Flutter tool генерирует CMake glue, чтобы plugins линковались в desktop runner.
- **Содержимое:** add_subdirectory/target rules для plugins и registrant.
- **Обязанности:** Wire Flutter plugins into Windows `.exe` native build.
- **Когда открывать:** Plugin link fail на windows после `flutter pub get` или upgrade.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** `windows/CMakeLists.txt`, `pubspec.yaml` plugins.
- **Слой:** сгенерированный Flutter CMake windows.


### `windows/runner/CMakeLists.txt`

EN:

- **What this is:** CMake build script for `windows/runner` — builds the Flutter `windows` native runner.
- **Why needed:** Native windows desktop compile links Flutter engine via this CMake file in `windows/runner`.
- **What it contains:** CMake targets, source file list, Flutter embedder link rules.
- **Responsibilities:** Produce native binary pieces for `windows/runner` embedder.
- **When to open:** When behavior tied to `CMakeLists.txt` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `windows` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** CMake target `windows/runner` — собирает native host, который запускает Flutter engine.
- **Зачем:** Executable Counter на windows создаётся из runner sources и Flutter glue.
- **Содержимое:** Список runner sources, link libraries и install rules для desktop binary.
- **Обязанности:** Собрать windows host app и подключить Flutter plugins.
- **Когда открывать:** When behavior tied to `CMakeLists.txt` breaks or you need to change its documented role.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** Flutter `windows` tooling.
- **Слой:** Платформенная обёртка Flutter — не Dart UI.


### `windows/runner/Runner.rc`

EN:

- **What this is:** windows build file `Runner.rc` in `windows/runner` — required by Flutter/native toolchain.
- **Why needed:** Without `Runner.rc`, windows compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `windows/runner` (open file only when build errors cite it).
- **Responsibilities:** Support windows embedder build for `windows/runner` — not Dart business logic.
- **When to open:** Build log mentions `Runner.rc` or `windows/runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `windows/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Win32 resource script — встраивает ICO, version info и manifest в Windows `.exe`.
- **Зачем:** Resource compiler читает `.rc`, чтобы `.exe` имел иконку и metadata в Explorer.
- **Содержимое:** Ссылки на `app_icon.ico`, VERSIONINFO, application manifest.
- **Обязанности:** Embed icons/version into Counter Windows binary.
- **Когда открывать:** Неверная иконка/version в Properties `.exe`; RC compile errors.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** `windows/runner/resources/app_icon.ico`, `windows/runner/CMakeLists.txt`.
- **Слой:** Windows resources — не Dart.


### `windows/runner/desktop_voice_native_overlay.cpp`

EN:

- **What this is:** windows build file `desktop_voice_native_overlay.cpp` in `windows/runner` — required by Flutter/native toolchain.
- **Why needed:** Without `desktop_voice_native_overlay.cpp`, windows compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `windows/runner` (open file only when build errors cite it).
- **Responsibilities:** Support windows embedder build for `windows/runner` — not Dart business logic.
- **When to open:** Build log mentions `desktop_voice_native_overlay.cpp` or `windows/runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `windows/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Native C++ source `desktop_voice_native_overlay.cpp` — часть CMake/Win32 runner runner, собирающего Windows `.exe`.
- **Зачем:** CMake/MSBuild компилирует этот файл в native host, который держит Flutter engine.
- **Содержимое:** C++ implementation для windows/runner runner target.
- **Обязанности:** Native host behavior для Windows `.exe` (окно, plugins, utils).
- **Когда открывать:** Native compile/link error ссылается на `desktop_voice_native_overlay.cpp`.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** `windows/runner/CMakeLists.txt`, `windows/flutter/`.
- **Слой:** windows native runner source — не Dart.


### `windows/runner/desktop_voice_native_overlay.h`

EN:

- **What this is:** windows build file `desktop_voice_native_overlay.h` in `windows/runner` — required by Flutter/native toolchain.
- **Why needed:** Without `desktop_voice_native_overlay.h`, windows compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `windows/runner` (open file only when build errors cite it).
- **Responsibilities:** Support windows embedder build for `windows/runner` — not Dart business logic.
- **When to open:** Build log mentions `desktop_voice_native_overlay.h` or `windows/runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `windows/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Заголовок C/C++ `desktop_voice_native_overlay.h` — объявления для native runner windows (CMake/Win32 runner).
- **Зачем:** Компилятор CMake/Win32 runner подключает header при сборке Windows `.exe`.
- **Содержимое:** Объявления и guards для `desktop_voice_native_overlay.h` в `windows/runner`.
- **Обязанности:** Compile-time интерфейс native runner для Windows `.exe`.
- **Когда открывать:** Ошибка native compile ссылается на `desktop_voice_native_overlay.h`.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** `windows/runner/`, `windows/flutter/`.
- **Слой:** windows native header — не Dart.


### `windows/runner/flutter_window.cpp`

EN:

- **What this is:** windows build file `flutter_window.cpp` in `windows/runner` — required by Flutter/native toolchain.
- **Why needed:** Without `flutter_window.cpp`, windows compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `windows/runner` (open file only when build errors cite it).
- **Responsibilities:** Support windows embedder build for `windows/runner` — not Dart business logic.
- **When to open:** Build log mentions `flutter_window.cpp` or `windows/runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `windows/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Native C++ Win32 window glue (`flutter_window.cpp`) — создаёт/обслуживает HWND, куда Flutter рисует UI.
- **Зачем:** Flutter engine на Windows нуждается в Win32 surface; этот файл держит message loop окна.
- **Содержимое:** Классы/функции создания окна, resize, DPI и Flutter view attach.
- **Обязанности:** Win32 window lifecycle для Counter desktop через `flutter_window.cpp`.
- **Когда открывать:** Окно не появляется, wrong DPI/resize, native crash в window code.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** `windows/runner/main.cpp`, `windows/runner/CMakeLists.txt`.
- **Слой:** Windows native window — не Dart.


### `windows/runner/flutter_window.h`

EN:

- **What this is:** windows build file `flutter_window.h` in `windows/runner` — required by Flutter/native toolchain.
- **Why needed:** Without `flutter_window.h`, windows compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `windows/runner` (open file only when build errors cite it).
- **Responsibilities:** Support windows embedder build for `windows/runner` — not Dart business logic.
- **When to open:** Build log mentions `flutter_window.h` or `windows/runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `windows/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Заголовок C/C++ `flutter_window.h` — объявления для native runner windows (CMake/Win32 runner).
- **Зачем:** Компилятор CMake/Win32 runner подключает header при сборке Windows `.exe`.
- **Содержимое:** Объявления и guards для `flutter_window.h` в `windows/runner`.
- **Обязанности:** Compile-time интерфейс native runner для Windows `.exe`.
- **Когда открывать:** Ошибка native compile ссылается на `flutter_window.h`.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** `windows/runner/`, `windows/flutter/`.
- **Слой:** windows native header — не Dart.


### `windows/runner/main.cpp`

EN:

- **What this is:** Native C++ entry point for the Windows desktop app — creates Win32 window and boots Flutter.
- **Why needed:** The Windows `.exe` starts here; without it Flutter desktop cannot show Counter UI.
- **What it contains:** `wWinMain`/`main`, window creation, `flutter::FlutterViewController` bootstrap.
- **Responsibilities:** Cold-start Windows runner — Win32 host + Flutter engine.
- **When to open:** When behavior tied to `main.cpp` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `windows` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Точка входа native C++ Windows-приложения. Создаёт Win32 window, инициализирует Flutter engine и запускает Dart UI.
- **Зачем:** Windows `.exe` стартует отсюда: без `main()` Flutter desktop не поднимет окно Counter.
- **Содержимое:** `wWinMain`/`main`, вызовы создания окна и `flutter::FlutterViewController`.
- **Обязанности:** Старт Windows runner: Win32 host и bootstrap Flutter engine.
- **Когда открывать:** Windows `.exe` не стартует, crash до первого кадра Flutter.
- **Можно удалить?** Нет — без него Windows `.exe` не запустится.
- **Связано с:** `windows/runner/flutter_window.cpp`, `windows/CMakeLists.txt`.
- **Слой:** Windows native entry — не Dart business logic.


### `windows/runner/resource.h`

EN:

- **What this is:** windows build file `resource.h` in `windows/runner` — required by Flutter/native toolchain.
- **Why needed:** Without `resource.h`, windows compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `windows/runner` (open file only when build errors cite it).
- **Responsibilities:** Support windows embedder build for `windows/runner` — not Dart business logic.
- **When to open:** Build log mentions `resource.h` or `windows/runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `windows/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Заголовок C `resource.h` — константы ID для Win32 `.rc` compiler.
- **Зачем:** Runner `.rc` и C++ sources подключают header для icon/version constants.
- **Содержимое:** #define IDs для resources в `windows/runner`.
- **Обязанности:** Связать Win32 resources с C++ runner compile.
- **Когда открывать:** RC compile error: unknown resource id в `resource.h`.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** `windows/runner/Runner.rc`, `windows/runner/CMakeLists.txt`.
- **Слой:** Windows native header — не Dart.


### `windows/runner/resources/app_icon.ico`

EN:

- **What this is:** Windows runner ICO icon embedded in `.exe` and installer.
- **Why needed:** Win32 resource compiler and Inno Setup use this for taskbar/Explorer/Start menu branding.
- **What it contains:** Multi-size ICO raster for Windows shell icons.
- **Responsibilities:** Counter icon in taskbar, Explorer, Start menu, and setup wizard.
- **When to open:** When behavior tied to `app_icon.ico` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** Flutter `windows` tooling.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** ICO-иконка Windows runner. Встраивается в native `.exe` и installer, чтобы Counter имел правильную иконку в taskbar, Explorer и Start menu.
- **Зачем:** Win32 resource compiler и Inno Setup берут этот ICO для branding установленного app.
- **Содержимое:** Multi-size ICO raster для Windows shell icons.
- **Обязанности:** Иконка Counter в taskbar, Explorer, Start menu и setup wizard.
- **Когда открывать:** Неверная или дефолтная Flutter иконка на Windows desktop/installer.
- **Можно удалить?** Нет — `.exe`/installer покажут дефолтную или пустую иконку.
- **Связано с:** `windows/runner/Runner.rc`, `installer/windows/counter.iss`.
- **Слой:** Windows icon asset — не Dart.


### `windows/runner/runner.exe.manifest`

EN:

- **What this is:** windows build file `runner.exe.manifest` in `windows/runner` — required by Flutter/native toolchain.
- **Why needed:** Without `runner.exe.manifest`, windows compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `windows/runner` (open file only when build errors cite it).
- **Responsibilities:** Support windows embedder build for `windows/runner` — not Dart business logic.
- **When to open:** Build log mentions `runner.exe.manifest` or `windows/runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `windows/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Win32 application manifest — DPI awareness и compatibility flags для Windows `.exe`.
- **Зачем:** Windows loader читает manifest для Per-Monitor DPI и UAC behavior.
- **Содержимое:** XML assembly manifest для runner executable.
- **Обязанности:** Метаданные DPI/compatibility, встроенные в `.exe`.
- **Когда открывать:** Build log mentions `runner.exe.manifest` or `windows/runner`.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** `windows/runner/Runner.rc`, CMake runner target.
- **Слой:** Windows manifest — не Dart.


### `windows/runner/utils.cpp`

EN:

- **What this is:** windows build file `utils.cpp` in `windows/runner` — required by Flutter/native toolchain.
- **Why needed:** Without `utils.cpp`, windows compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `windows/runner` (open file only when build errors cite it).
- **Responsibilities:** Support windows embedder build for `windows/runner` — not Dart business logic.
- **When to open:** Build log mentions `utils.cpp` or `windows/runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `windows/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Native C++ utilities Windows runner — UTF-8/Win32 helpers для desktop host.
- **Зачем:** Runner использует общие helpers при создании окна и консольных сообщениях сборки.
- **Содержимое:** Small Win32/UTF-8 helper functions linked в runner target.
- **Обязанности:** Support code для Win32 runner — не business logic Counter.
- **Когда открывать:** Compile/link errors ссылаются на `utils.cpp`.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** `windows/runner/main.cpp`, `windows/runner/CMakeLists.txt`.
- **Слой:** Windows native helper — не Dart.


### `windows/runner/utils.h`

EN:

- **What this is:** windows build file `utils.h` in `windows/runner` — required by Flutter/native toolchain.
- **Why needed:** Without `utils.h`, windows compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `windows/runner` (open file only when build errors cite it).
- **Responsibilities:** Support windows embedder build for `windows/runner` — not Dart business logic.
- **When to open:** Build log mentions `utils.h` or `windows/runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `windows/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Заголовок C/C++ `utils.h` — объявления для native runner windows (CMake/Win32 runner).
- **Зачем:** Компилятор CMake/Win32 runner подключает header при сборке Windows `.exe`.
- **Содержимое:** Объявления и guards для `utils.h` в `windows/runner`.
- **Обязанности:** Compile-time интерфейс native runner для Windows `.exe`.
- **Когда открывать:** Ошибка native compile ссылается на `utils.h`.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** `windows/runner/`, `windows/flutter/`.
- **Слой:** windows native header — не Dart.


### `windows/runner/win32_window.cpp`

EN:

- **What this is:** windows build file `win32_window.cpp` in `windows/runner` — required by Flutter/native toolchain.
- **Why needed:** Without `win32_window.cpp`, windows compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `windows/runner` (open file only when build errors cite it).
- **Responsibilities:** Support windows embedder build for `windows/runner` — not Dart business logic.
- **When to open:** Build log mentions `win32_window.cpp` or `windows/runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `windows/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Native C++ Win32 window glue (`win32_window.cpp`) — создаёт/обслуживает HWND, куда Flutter рисует UI.
- **Зачем:** Flutter engine на Windows нуждается в Win32 surface; этот файл держит message loop окна.
- **Содержимое:** Классы/функции создания окна, resize, DPI и Flutter view attach.
- **Обязанности:** Win32 window lifecycle для Counter desktop через `win32_window.cpp`.
- **Когда открывать:** Окно не появляется, wrong DPI/resize, native crash в window code.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** `windows/runner/main.cpp`, `windows/runner/CMakeLists.txt`.
- **Слой:** Windows native window — не Dart.


### `windows/runner/win32_window.h`

EN:

- **What this is:** windows build file `win32_window.h` in `windows/runner` — required by Flutter/native toolchain.
- **Why needed:** Without `win32_window.h`, windows compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `windows/runner` (open file only when build errors cite it).
- **Responsibilities:** Support windows embedder build for `windows/runner` — not Dart business logic.
- **When to open:** Build log mentions `win32_window.h` or `windows/runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `windows/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Заголовок C/C++ `win32_window.h` — объявления для native runner windows (CMake/Win32 runner).
- **Зачем:** Компилятор CMake/Win32 runner подключает header при сборке Windows `.exe`.
- **Содержимое:** Объявления и guards для `win32_window.h` в `windows/runner`.
- **Обязанности:** Compile-time интерфейс native runner для Windows `.exe`.
- **Когда открывать:** Ошибка native compile ссылается на `win32_window.h`.
- **Можно удалить?** Нет — без него не соберётся Windows `.exe`/runner.
- **Связано с:** `windows/runner/`, `windows/flutter/`.
- **Слой:** windows native header — не Dart.

