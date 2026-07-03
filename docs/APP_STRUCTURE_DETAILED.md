# APP_STRUCTURE_DETAILED

Owner-readable guide: every tracked folder and file in plain language (EN + RU).

**Generated at git SHA `373da25` on 2026-07-03.**

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
- **Можно удалить?** Нет — Cursor root discovery ожидает rules здесь.
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
- **Можно удалить?** Нет — governing documentation.
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
- **Можно удалить?** Нет — пока нужен Windows installer distribution.
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
- **Можно удалить?** Нет — если integration QA остаётся в pipeline.
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
- **Можно удалить?** Нет — удаление уничтожает приложение.
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
- **Можно удалить?** Нет — production PocketBase ожидает hooks по manifest.
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
- **Можно удалить?** Нет — deploy/audit/doc workflows в repo.
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
- **Можно удалить?** Нет — web deploy ломается.
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
- **Можно удалить?** Нет — основной rule pack Cursor.
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
- **Можно удалить?** Нет — если нужны GitHub Pages и Windows installer.
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
- **Можно удалить?** Нет — без app module нет Android APK.
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
- **Можно удалить?** Нет — без wrapper Gradle sync нестабилен.
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
- **Можно удалить?** Нет — история cleanup и audit.
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
- **Можно удалить?** Нет — repo-only marketing copy.
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
- **Можно удалить?** Нет — перегенерируется Flutter tool.
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
- **Можно удалить?** Нет — без Runner target нет iOS app.
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
- **Можно удалить?** Нет — без project Xcode не соберёт iOS.
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
- **Можно удалить?** Нет — стандартный CocoaPods workflow.
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
- **Можно удалить?** Возможно — Flutter CI использует `flutter test`; оставить для Xcode workflow.
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
- **Можно удалить?** Нет — features импортируют foundation повсюду.
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
- **Можно удалить?** Нет — UI не работает без мозга.
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
- **Можно удалить?** Нет — удаление убирает весь UI продукта.
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
- **Можно удалить?** Нет — без l10n сырые keys или crash.
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
- **Можно удалить?** Нет — plan alarms перестанут работать.
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
- **Можно удалить?** Нет — навигация приложения рушится.
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
- **Можно удалить?** Нет — перегенерируется Flutter tool.
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
- **Можно удалить?** Нет — перегенерируется Flutter tool.
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
- **Можно удалить?** Нет — если нужна поддержка macOS desktop.
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
- **Можно удалить?** Нет — без project Xcode не соберёт macOS.
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
- **Можно удалить?** Нет — стандартный CocoaPods workflow.
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
- **Можно удалить?** Возможно — Flutter CI использует `flutter test`; оставить для Xcode workflow.
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
- **Можно удалить?** Нет — задокументированный audit workflow.
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
- **Можно удалить?** Нет — задокументированные manual workflows.
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
- **Можно удалить?** Нет — перегенерируется Flutter tool.
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
- **Можно удалить?** Нет — если нужна поддержка Windows desktop.
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
- **Можно удалить?** Нет — Windows installer packaging ожидает scripts.
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
- **Можно удалить?** Нет — без exe STT bundle неполный.
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
- **Что здесь лежит:** Native/config файлы для `project.xcworkspace` — список ниже.
- **На что влияет в приложении:** Только открытие project в Xcode — не runtime приложения.
- **Когда открывать:** Повреждение Xcode-проект, смена scheme, настройки iOS signing.
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
- **Что здесь лежит:** Native/config файлы для `xcshareddata` — список ниже.
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
- **Можно удалить?** Нет — required for iOS CocoaPods workflow.
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
- **Что здесь лежит:** Native/config файлы для `Assets.xcassets` — список ниже.
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
- **Можно удалить?** Нет — используется в debug/profile builds.
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
- **Можно удалить?** Нет — документирует структуру env.dart.
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
- **Можно удалить?** Нет — сломаются desktop layout и overlays.
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
- **Можно удалить?** Нет — perf tests и diagnostics ссылаются на эти flags.
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

- **Что это за папка:** Сервисы устройства — speech-to-text, desktop voice, tray, hotkeys.
- **Зачем нужна:** Platform voice и tray не могут жить в PocketBase brain code.
- **Что здесь лежит:** Модули `desktop_voice_*.dart` и STT helper subprocess client.
- **На что влияет в приложении:** Поведение части приложения, связанной с `core/services`.
- **Когда открывать:** Баг или доработка в `core/services`.
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

- **Что это за папка:** Подмодуль `core/time` в Flutter-приложении Counter.
- **Зачем нужна:** Time bucketing по profile timezone law — не device local time — на всех вкладках.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/core/time/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `core/time`.
- **Когда открывать:** Баг или доработка в `core/time`.
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

- **Что это за папка:** Подмодуль `data/cache` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/data/cache/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/data/cache/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `data/cache`.
- **Когда открывать:** Баг или доработка в `data/cache`.
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

- **Что это за папка:** Подмодуль `data/categories` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/data/categories/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/data/categories/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `data/categories`.
- **Когда открывать:** Баг или доработка в `data/categories`.
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

- **Что это за папка:** Подмодуль `data/local_sync` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/data/local_sync/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/data/local_sync/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `data/local_sync`.
- **Когда открывать:** Баг или доработка в `data/local_sync`.
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

- **Что это за папка:** Подмодуль `data/models` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/data/models/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/data/models/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `data/models`.
- **Когда открывать:** Баг или доработка в `data/models`.
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
- **Можно удалить?** Нет — сломаются Plans и Lists.
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

- **Что это за папка:** Подмодуль `data/profile` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/data/profile/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/data/profile/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `data/profile`.
- **Когда открывать:** Баг или доработка в `data/profile`.
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
- **Можно удалить?** Нет — перестанет работать учёт времени.
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

- **Что это за папка:** Подмодуль `features/auth` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/features/auth/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/features/auth/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `features/auth`.
- **Когда открывать:** Баг или доработка в `features/auth`.
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

- **Что это за папка:** Подмодуль `features/calendar` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/features/calendar/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/features/calendar/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `features/calendar`.
- **Когда открывать:** Баг или доработка в `features/calendar`.
- **Можно удалить?** Возможно — if calendar tab removed from shell; keep while route exists.
- **Связанные пути:** `lib/features/planning/`, plan card widgets in `core/widgets/`.

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

- **Что это за папка:** Подмодуль `features/categories` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/features/categories/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/features/categories/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `features/categories`.
- **Когда открывать:** Баг или доработка в `features/categories`.
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

- **Что это за папка:** Подмодуль `features/dev` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/features/dev/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/features/dev/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `features/dev`.
- **Когда открывать:** Баг или доработка в `features/dev`.
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

- **Что это за папка:** Подмодуль `features/lists` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/features/lists/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/features/lists/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `features/lists`.
- **Когда открывать:** Баг или доработка в `features/lists`.
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
- **Можно удалить?** Нет — вкладка Plans исчезнет.
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

- **Что это за папка:** Подмодуль `features/profile` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/features/profile/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/features/profile/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `features/profile`.
- **Когда открывать:** Баг или доработка в `features/profile`.
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
- **Можно удалить?** Нет — edit flows сломаются на всех вкладках.
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

- **Что это за папка:** Подмодуль `features/stats` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/features/stats/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/features/stats/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `features/stats`.
- **Когда открывать:** Баг или доработка в `features/stats`.
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

- **Что это за папка:** Подмодуль `features/timeline` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/features/timeline/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/features/timeline/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `features/timeline`.
- **Когда открывать:** Баг или доработка в `features/timeline`.
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

- **Что это за папка:** Подмодуль `features/wear` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/features/wear/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/features/wear/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `features/wear`.
- **Когда открывать:** Баг или доработка в `features/wear`.
- **Можно удалить?** Нет — если нужен Wear OS companion.
- **Связанные пути:** `lib/data/db_core.dart` Wear lite load, `android/` Wear module if configured.

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

- **Что это за папка:** Подмодуль `l10n/langs` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/l10n/langs/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/l10n/langs/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `l10n/langs`.
- **Когда открывать:** Баг или доработка в `l10n/langs`.
- **Можно удалить?** Нет — required for localization.
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
- **Можно удалить?** Нет — required for macOS Xcode workflow.
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
- **Что здесь лежит:** Native/config файлы для `Assets.xcassets` — список ниже.
- **На что влияет в приложении:** Сборка Counter `.app` на macOS desktop.
- **Когда открывать:** Неверная или пропавшая app icon на iOS/macOS.
- **Можно удалить?** Нет — if macOS builds are kept.
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
- **Можно удалить?** Нет — if macOS builds are kept.
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
- **Что здесь лежит:** Native/config файлы для `Configs` — список ниже.
- **На что влияет в приложении:** Сборка Counter `.app` на macOS desktop.
- **Когда открывать:** Подпись macOS, sandbox, menu bar.
- **Можно удалить?** Нет — if macOS builds are kept.
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

- **Что это за папка:** Platform-путь `android/app/src/debug/` — native/embedder поддержка Android.
- **Зачем нужна:** Flutter Android build использует файлы под `android/`.
- **Что здесь лежит:** Native/config файлы для `debug` — список ниже.
- **На что влияет в приложении:** Только Android сборка/native chrome — не Dart UI.
- **Когда открывать:** Ошибка Android build, ссылающаяся на `debug`.
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

- **Что это за папка:** Platform-путь `android/app/src/profile/` — native/embedder поддержка Android.
- **Зачем нужна:** Flutter Android build использует файлы под `android/`.
- **Что здесь лежит:** Native/config файлы для `profile` — список ниже.
- **На что влияет в приложении:** Только Android сборка/native chrome — не Dart UI.
- **Когда открывать:** Ошибка Android build, ссылающаяся на `profile`.
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
- **Что здесь лежит:** Native/config файлы для `xcshareddata` — список ниже.
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
- **Что здесь лежит:** Native/config файлы для `xcschemes` — список ниже.
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
- **Что здесь лежит:** Native/config файлы для `AppIcon.appiconset` — список ниже.
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
- **Что здесь лежит:** Native/config файлы для `LaunchImage.imageset` — список ниже.
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

- **Что это за папка:** Подмодуль `core/widgets/plan_card` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/core/widgets/plan_card/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/core/widgets/plan_card/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `core/widgets/plan_card`.
- **Когда открывать:** Баг или доработка в `core/widgets/plan_card`.
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

- **Что это за папка:** Подмодуль `core/widgets/plan_time_task_card` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/core/widgets/plan_time_task_card/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/core/widgets/plan_time_task_card/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `core/widgets/plan_time_task_card`.
- **Когда открывать:** Баг или доработка в `core/widgets/plan_time_task_card`.
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

- **Что это за папка:** Подмодуль `features/planning/settings` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/features/planning/settings/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/features/planning/settings/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `features/planning/settings`.
- **Когда открывать:** Баг или доработка в `features/planning/settings`.
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

- **Что это за папка:** Подмодуль `features/planning/time_view` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/features/planning/time_view/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/features/planning/time_view/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `features/planning/time_view`.
- **Когда открывать:** Баг или доработка в `features/planning/time_view`.
- **Можно удалить?** Нет — Time View is a core Plans feature.
- **Связанные пути:** `planning_page.dart`, `PlanTimeTaskCard` widgets in `core/widgets/`.

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

- **Что это за папка:** Подмодуль `features/planning/widgets` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/features/planning/widgets/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/features/planning/widgets/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `features/planning/widgets`.
- **Когда открывать:** Баг или доработка в `features/planning/widgets`.
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

- **Что это за папка:** Подмодуль `features/profile/settings` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/features/profile/settings/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/features/profile/settings/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `features/profile/settings`.
- **Когда открывать:** Баг или доработка в `features/profile/settings`.
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

- **Что это за папка:** Подмодуль `features/shared/edit_sheet` в Flutter-приложении Counter.
- **Зачем нужна:** Код под `lib/features/shared/edit_sheet/` нужен для работы описанной в EN зоны ответственности.
- **Что здесь лежит:** Dart-файлы и подпапки `lib/features/shared/edit_sheet/` — список ниже.
- **На что влияет в приложении:** Поведение части приложения, связанной с `features/shared/edit_sheet`.
- **Когда открывать:** Баг или доработка в `features/shared/edit_sheet`.
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
- **Что здесь лежит:** Native/config файлы для `AppIcon.appiconset` — список ниже.
- **На что влияет в приложении:** Сборка Counter `.app` на macOS desktop.
- **Когда открывать:** Неверная или пропавшая app icon на iOS/macOS.
- **Можно удалить?** Нет — if macOS builds are kept.
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
- **Что здесь лежит:** Native/config файлы для `res` — список ниже.
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

- **Что это:** Файл `flutter_expert.mdc` в каталоге `.cursor/rules/`.
- **Зачем:** Поддерживает documented workflow каталога `.cursor/rules/`.
- **Содержимое:** Исходное содержимое `flutter_expert.mdc`.
- **Обязанности:** Зона ответственности `flutter_expert.mdc` в `.cursor/rules/`.
- **Когда открывать:** Build или maintenance ссылается на `flutter_expert.mdc`.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** См. также: Flutter `.cursor` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `.cursorrules` в каталоге `./`.
- **Зачем:** Поддерживает documented workflow каталога `./`.
- **Содержимое:** Исходное содержимое `.cursorrules`.
- **Обязанности:** Зона ответственности `.cursorrules` в `./`.
- **Когда открывать:** Build или maintenance ссылается на `.cursorrules`.
- **Можно удалить?** Нет — Cursor ищет rules в root.
- **Связано с:** См. также: `.cursor/rules/flutter_expert.mdc`, `docs/ARCHITECTURE.md`.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — нужен для audit/deploy workflow в репозитории.
- **Связано с:** См. также: Flutter `.github` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `.github/workflows/deploy.yml`

EN:

- **What this is:** Source file `deploy.yml` — CI web deploy.
- **Why needed:** Documented in `docs/APP_STRUCTURE.md`; required for current app behavior.
- **What it contains:** Source for `deploy.yml` (see source file).
- **Responsibilities:** CI web deploy
- **When to open:** When behavior tied to `deploy.yml` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/audit workflows documented in repo.
- **Connected to:** Role: CI web deploy
- **Layer / owner:** Build/deploy/server configuration.

RU:

- **Что это:** Workflow GitHub Actions для публикации web-версии. После push собирает Flutter web с base href `/Counter/` и выкладывает на GitHub Pages.
- **Зачем:** Автоматизирует deploy сайта без ручного `update.ps1` на CI runner.
- **Содержимое:** Шаги checkout, `flutter build web`, deploy в `gh-pages` branch.
- **Обязанности:** Собрать и опубликовать web build при push в main.
- **Когда открывать:** Сайт не обновился после merge; проверка CI deploy log.
- **Можно удалить?** Нет — нужен для audit/deploy workflow в репозитории.
- **Связано с:** `docs/APP_STRUCTURE.md`, связанные файлы в этой папке.
- **Слой:** CI deploy — не runtime приложения.


### `.github/workflows/windows-desktop-build.yml`

EN:

- **What this is:** Source file `windows-desktop-build.yml` — CI Windows installer.
- **Why needed:** Documented in `docs/APP_STRUCTURE.md`; required for current app behavior.
- **What it contains:** Source for `windows-desktop-build.yml` (see source file).
- **Responsibilities:** CI Windows installer
- **When to open:** When behavior tied to `windows-desktop-build.yml` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for build/deploy/audit workflows documented in repo.
- **Connected to:** Role: CI Windows installer
- **Layer / owner:** Build/deploy/server configuration.

RU:

- **Что это:** Workflow GitHub Actions для сборки Windows installer `CounterSetup.exe`.
- **Зачем:** Автоматизирует release Windows desktop build и упаковку installer artifact.
- **Содержимое:** Шаги `flutter build windows`, подготовка STT payload, Inno Setup.
- **Обязанности:** Собрать `.exe` installer и загрузить artifact в Actions.
- **Когда открывать:** Нет `CounterSetup.exe` в Actions artifacts после push.
- **Можно удалить?** Нет — нужен для audit/deploy workflow в репозитории.
- **Связано с:** `docs/APP_STRUCTURE.md`, связанные файлы в этой папке.
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

- **Что это:** Файл `.gitignore` в каталоге `./`.
- **Зачем:** Protects the repo from результат сборки, temp logs, local env secrets, Gradle junk, exports, and IDE cache accidentally landing in git.
- **Содержимое:** Исходное содержимое `.gitignore`.
- **Обязанности:** Зона ответственности `.gitignore` в `./`.
- **Когда открывать:** Build или maintenance ссылается на `.gitignore`.
- **Можно удалить?** Нет — гигиена и безопасность репозитория.
- **Связано с:** См. также: All developers, CI, `flutter build` output paths.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `.metadata` в каталоге `./`.
- **Зачем:** Поддерживает documented workflow каталога `./`.
- **Содержимое:** Исходное содержимое `.metadata`.
- **Обязанности:** Зона ответственности `.metadata` в `./`.
- **Когда открывать:** Build или maintenance ссылается на `.metadata`.
- **Можно удалить?** Нет — удалять только если Flutter пересоздаст и diff проверен.
- **Связано с:** См. также: Flutter CLI, `flutter pub get`, platform folders.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `agents.md` в каталоге `./`.
- **Зачем:** Поддерживает documented workflow каталога `./`.
- **Содержимое:** Исходное содержимое `agents.md`.
- **Обязанности:** Зона ответственности `agents.md` в `./`.
- **Когда открывать:** Build или maintenance ссылается на `agents.md`.
- **Можно удалить?** Нет — документ Project Knowledge pack #1.
- **Связано с:** См. также: `AGENT_NAVIGATION.md`, `docs/APP_STRUCTURE.md`, 14-doc pack.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `agent_navigation.md` в каталоге `./`.
- **Зачем:** Поддерживает documented workflow каталога `./`.
- **Содержимое:** Исходное содержимое `agent_navigation.md`.
- **Обязанности:** Зона ответственности `agent_navigation.md` в `./`.
- **Когда открывать:** Build или maintenance ссылается на `agent_navigation.md`.
- **Можно удалить?** Нет — документ Project Knowledge pack (formerly listed as `CLAUDE.md`).
- **Связано с:** См. также: `AGENTS.md`, `docs/ARCHITECTURE.md`, `CHANGELOG.md`, 14-doc pack.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `changelog.md` в каталоге `./`.
- **Зачем:** Поддерживает documented workflow каталога `./`.
- **Содержимое:** Исходное содержимое `changelog.md`.
- **Обязанности:** Зона ответственности `changelog.md` в `./`.
- **Когда открывать:** Build или maintenance ссылается на `changelog.md`.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** См. также: Every structure/deploy report, `docs/ROADMAP.md`.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `readme.md` в каталоге `./`.
- **Зачем:** Поддерживает documented workflow каталога `./`.
- **Содержимое:** Исходное содержимое `readme.md`.
- **Обязанности:** Зона ответственности `readme.md` в `./`.
- **Когда открывать:** Build или maintenance ссылается на `readme.md`.
- **Можно удалить?** Возможно — GitHub works without it, but keep for repo presentation.
- **Связано с:** См. также: GitHub repo home; governing specs live in `docs/`.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `analysis_options.yaml` в каталоге `./`.
- **Зачем:** Поддерживает documented workflow каталога `./`.
- **Содержимое:** Исходное содержимое `analysis_options.yaml`.
- **Обязанности:** Зона ответственности `analysis_options.yaml` в `./`.
- **Когда открывать:** Build или maintenance ссылается на `analysis_options.yaml`.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** См. также: `flutter analyze`, CI, all Dart files under `lib/` and `test/`.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Содержимое:** Исходное содержимое `android.ps1`.
- **Обязанности:** APK в `build/app/outputs/flutter-apk/` (`app-arm64-v8a-release.apk` для телефонов).
- **Когда открывать:** Тест release APK на физическом Android.
- **Можно удалить?** Нет — задокументированный путь локальной сборки Android in `docs/APP_STRUCTURE.md`.
- **Связано с:** См. также: `android/` Gradle project, `lib/core/app_build_info.dart`.
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

- **Что это:** Файл `.gitignore` в каталоге `android/`.
- **Зачем:** Prevents результат сборки and secrets from entering git history.
- **Содержимое:** Исходное содержимое `.gitignore`.
- **Обязанности:** Зона ответственности `.gitignore` в `android/`.
- **Когда открывать:** Build или maintenance ссылается на `.gitignore`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Содержимое:** Исходное содержимое `build.gradle.kts`.
- **Обязанности:** Настроить compile/target SDK, plugins Flutter, hooks подписи release.
- **Когда открывать:** Ошибка сборки app module, SDK version, signing config.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связано с:** См. также: Flutter tooling, `AndroidManifest.xml`.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `google-services.json` в каталоге `android/app/`.
- **Зачем:** Поддерживает documented workflow каталога `android/app/`.
- **Содержимое:** Исходное содержимое `google-services.json`.
- **Обязанности:** Зона ответственности `google-services.json` в `android/app/`.
- **Когда открывать:** Build или maintenance ссылается на `google-services.json`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `proguard-rules.pro` в каталоге `android/app/`.
- **Зачем:** Поддерживает documented workflow каталога `android/app/`.
- **Содержимое:** Исходное содержимое `proguard-rules.pro`.
- **Обязанности:** Зона ответственности `proguard-rules.pro` в `android/app/`.
- **Когда открывать:** Build или maintenance ссылается на `proguard-rules.pro`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Когда открывать:** Build или maintenance ссылается на `mainactivity.kt`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Содержимое:** Layer-list drawable с цветом или картинкой фона.
- **Обязанности:** Native splash на Android 5.0+ до первого Flutter frame.
- **Когда открывать:** Splash на новых Android отличается от старых или неверный цвет.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Содержимое:** Theme `LaunchTheme`, `NormalTheme`, ссылки на `@drawable/launch_background`.
- **Обязанности:** Внешний вид native chrome при launch Android.
- **Когда открывать:** Splash/status bar неверны только в тёмной теме ОС.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Содержимое:** Исходное содержимое `build.gradle.kts`.
- **Обязанности:** Общие настройки Gradle для root Android project.
- **Когда открывать:** Build или maintenance ссылается на `build.gradle.kts`.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связано с:** См. также: Flutter tooling, `AndroidManifest.xml`.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `gradle.properties` в каталоге `android/`.
- **Зачем:** Поддерживает documented workflow каталога `android/`.
- **Содержимое:** Исходное содержимое `gradle.properties`.
- **Обязанности:** Зона ответственности `gradle.properties` в `android/`.
- **Когда открывать:** Build или maintenance ссылается на `gradle.properties`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `android/gradle/wrapper/gradle-wrapper.properties`

EN:

- **What this is:** android build file `gradle-wrapper.properties` in `android/gradle/wrapper` — required by Flutter/native toolchain.
- **Why needed:** Without `gradle-wrapper.properties`, android compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `android/gradle/wrapper` (open file only when build errors cite it).
- **Responsibilities:** Support android embedder build for `android/gradle/wrapper` — not Dart business logic.
- **When to open:** Build log mentions `gradle-wrapper.properties` or `android/gradle/wrapper`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `android/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Файл `gradle-wrapper.properties` в каталоге `android/gradle/wrapper/`.
- **Зачем:** Поддерживает documented workflow каталога `android/gradle/wrapper/`.
- **Содержимое:** Исходное содержимое `gradle-wrapper.properties`.
- **Обязанности:** Зона ответственности `gradle-wrapper.properties` в `android/gradle/wrapper/`.
- **Когда открывать:** Build или maintenance ссылается на `gradle-wrapper.properties`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `android/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `android` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `docs/APP_STRUCTURE.md`

EN:

- **What this is:** Concise map of folders, layers, and import rules.
- **Why needed:** Quick answer to ‘where does X live?’ without reading the whole encyclopedia.
- **What it contains:** Tables of lib/data, features, scripts; guard commands.
- **Responsibilities:** Canonical structure contract for architecture guard.
- **When to open:** Finding module ownership; before moving files.
- **Can it be deleted?** No — Project Knowledge pack.
- **Connected to:** `APP_STRUCTURE_DETAILED.md`, `architecture_guard.ps1`.
- **Layer / owner:** Governing structure doc.

RU:

- **Что это:** Краткая карта структуры repo — папки, слои, import rules, команды guard.
- **Зачем:** Быстрый ответ «где живёт X» без чтения всей encyclopedia.
- **Содержимое:** Таблицы `lib/data`, features, scripts; команды architecture guard.
- **Обязанности:** Канонический structure contract для guard и AI.
- **Когда открывать:** Ищете ownership модуля; перед переносом файлов.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** См. также: `APP_STRUCTURE_DETAILED.md`, `architecture_guard.ps1`.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `docs/APP_STRUCTURE_DETAILED.md`

EN:

- **What this is:** Source file `APP_STRUCTURE_DETAILED.md` — Bilingual file-by-file guide (EN/RU).
- **Why needed:** Documented in `docs/APP_STRUCTURE.md`; required for current app behavior.
- **What it contains:** Source for `APP_STRUCTURE_DETAILED.md` (see source file).
- **Responsibilities:** Bilingual file-by-file guide (EN/RU)
- **When to open:** Understanding project rules, deploy steps, or structure — not runtime debugging.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** Role: Bilingual file-by-file guide (EN/RU)
- **Layer / owner:** Documentation — explains rules, not runtime code.

RU:

- **Что это:** Markdown-документ `app_structure_detailed.md` — правила и заметки по теме «app structure detailed».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `app structure detailed`.
- **Когда открывать:** Нужна written-инструкция по `app structure detailed`.
- **Можно удалить?** Нет — governing-документация проекта.
- **Связано с:** `docs/APP_STRUCTURE.md`, связанные файлы в этой папке.
- **Слой:** Документация — не runtime.


### `docs/ARCHITECTURE.md`

EN:

- **What this is:** Source file `ARCHITECTURE.md` — Data flow, iron laws, optimistic UI, performance.
- **Why needed:** Documented in `docs/APP_STRUCTURE.md`; required for current app behavior.
- **What it contains:** Source for `ARCHITECTURE.md` (see source file).
- **Responsibilities:** Data flow, iron laws, optimistic UI, performance
- **When to open:** Understanding project rules, deploy steps, or structure — not runtime debugging.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** Role: Data flow, iron laws, optimistic UI, performance
- **Layer / owner:** Documentation — explains rules, not runtime code.

RU:

- **Что это:** Железные законы проекта — optimistic UI, Brain/UI split, PocketBase, main-thread law.
- **Зачем:** Авторитетный технический контракт для owner и AI.
- **Содержимое:** Правила data flow, offline, singleton record, performance.
- **Обязанности:** Ответ на «как система обязана работать».
- **Когда открывать:** Спор об architecture; перед refactor Brain или UI.
- **Можно удалить?** Нет — governing-документация проекта.
- **Связано с:** `docs/APP_STRUCTURE.md`, связанные файлы в этой папке.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `docs/DATA_MAP.md`

EN:

- **What this is:** Source file `DATA_MAP.md` — PocketBase field names and business IDs.
- **Why needed:** Documented in `docs/APP_STRUCTURE.md`; required for current app behavior.
- **What it contains:** Source for `DATA_MAP.md` (see source file).
- **Responsibilities:** PocketBase field names and business IDs
- **When to open:** Understanding project rules, deploy steps, or structure — not runtime debugging.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** Role: PocketBase field names and business IDs
- **Layer / owner:** Documentation — explains rules, not runtime code.

RU:

- **Что это:** Словарь полей PocketBase — имена колонок, business IDs, relation fields.
- **Зачем:** Brain и UI должны использовать одни имена полей при POST/PATCH.
- **Содержимое:** Таблицы records, plans, categories, tags, profiles.
- **Обязанности:** SSOT имён полей — не выдумывать alternate names.
- **Когда открывать:** Ошибка parse поля PB; добавление нового поля в schema.
- **Можно удалить?** Нет — governing-документация проекта.
- **Связано с:** `docs/APP_STRUCTURE.md`, связанные файлы в этой папке.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `docs/DEPLOY.md`

EN:

- **What this is:** How to publish the website and set up PocketBase auth/admin on the server.
- **Why needed:** Deploy and OAuth are easy to get wrong without step-by-step VPS notes.
- **What it contains:** `update.ps1` flow, GitHub Pages, Windows installer section, OAuth admin checklist.
- **Responsibilities:** Deploy + production auth configuration guide.
- **When to open:** Site not updating, OAuth broken, building Windows installer.
- **Can it be deleted?** No — Project Knowledge pack.
- **Connected to:** `.github/workflows/`, `update.ps1`, `installer/`.
- **Layer / owner:** Deploy guide — Project Knowledge.

RU:

- **Что это:** Пошаговый deploy — GitHub Pages, PocketBase auth admin, Windows installer.
- **Зачем:** Deploy и OAuth легко сломать без VPS checklist.
- **Содержимое:** Исходное содержимое `deploy.md`.
- **Обязанности:** Инструкция публикации сайта и production auth.
- **Когда открывать:** Сайт не обновился; OAuth broken; сборка installer.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** См. также: `.github/workflows/`, `update.ps1`, `installer/`.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `docs/DESIGN_SYSTEM.md`

EN:

- **What this is:** Source file `DESIGN_SYSTEM.md` — Figma → Flutter canonical components.
- **Why needed:** Documented in `docs/APP_STRUCTURE.md`; required for current app behavior.
- **What it contains:** Source for `DESIGN_SYSTEM.md` (see source file).
- **Responsibilities:** Figma → Flutter canonical components
- **When to open:** Understanding project rules, deploy steps, or structure — not runtime debugging.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** Role: Figma → Flutter canonical components
- **Layer / owner:** Documentation — explains rules, not runtime code.

RU:

- **Что это:** Design system контракт — Figma → Flutter mapping, canonical components.
- **Зачем:** Запрещает локальные копии кнопок/карточек в feature screens.
- **Содержимое:** Исходное содержимое `design_system.md`.
- **Обязанности:** Правила V7 component migration и Component Lab acceptance.
- **Когда открывать:** Миграция UI на canonical widgets; pixel QA.
- **Можно удалить?** Нет — governing-документация проекта.
- **Связано с:** `docs/APP_STRUCTURE.md`, связанные файлы в этой папке.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `docs/POCKETBASE_MANIFEST.md`

EN:

- **What this is:** Source file `POCKETBASE_MANIFEST.md` — URLs, collections, server hooks.
- **Why needed:** Documented in `docs/APP_STRUCTURE.md`; required for current app behavior.
- **What it contains:** Source for `POCKETBASE_MANIFEST.md` (see source file).
- **Responsibilities:** URLs, collections, server hooks
- **When to open:** Understanding project rules, deploy steps, or structure — not runtime debugging.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** Role: URLs, collections, server hooks
- **Layer / owner:** Documentation — explains rules, not runtime code.

RU:

- **Что это:** Markdown-документ `pocketbase_manifest.md` — правила и заметки по теме «pocketbase manifest».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `pocketbase manifest`.
- **Когда открывать:** Нужна written-инструкция по `pocketbase manifest`.
- **Можно удалить?** Нет — governing-документация проекта.
- **Связано с:** `docs/APP_STRUCTURE.md`, связанные файлы в этой папке.
- **Слой:** Документация — не runtime.


### `docs/PROJECT_KNOWLEDGE_PACK.md`

EN:

- **What this is:** Checklist of exactly 14 docs to upload to Project Knowledge (not architecture law itself).
- **Why needed:** Owner limit of 25 uploaded docs — lists what to include/exclude.
- **What it contains:** Upload list, excluded repo-only docs, removed-doc log.
- **Responsibilities:** Upload manifest only.
- **When to open:** Refreshing AI project files.
- **Can it be deleted?** No — upload checklist.
- **Connected to:** 14-doc pack listed inside.
- **Layer / owner:** Meta checklist — repo-only.

RU:

- **Что это:** Markdown-документ `project_knowledge_pack.md` — правила и заметки по теме «project knowledge pack».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `project knowledge pack`.
- **Когда открывать:** Нужна written-инструкция по `project knowledge pack`.
- **Можно удалить?** Нет — актуальный отчёт или чеклист.
- **Связано с:** `docs/APP_STRUCTURE.md`, связанные файлы в этой папке.
- **Слой:** Документация — не runtime.


### `docs/ROADMAP.md`

EN:

- **What this is:** Source file `ROADMAP.md` — Current work plan.
- **Why needed:** Documented in `docs/APP_STRUCTURE.md`; required for current app behavior.
- **What it contains:** Source for `ROADMAP.md` (see source file).
- **Responsibilities:** Current work plan
- **When to open:** Understanding project rules, deploy steps, or structure — not runtime debugging.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** Role: Current work plan
- **Layer / owner:** Documentation — explains rules, not runtime code.

RU:

- **Что это:** Markdown-документ `roadmap.md` — правила и заметки по теме «roadmap».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `roadmap`.
- **Когда открывать:** Нужна written-инструкция по `roadmap`.
- **Можно удалить?** Нет — governing-документация проекта.
- **Связано с:** `docs/APP_STRUCTURE.md`, связанные файлы в этой папке.
- **Слой:** Документация — не runtime.


### `docs/UX_CONTRACT.md`

EN:

- **What this is:** Source file `UX_CONTRACT.md` — Tap/save/loading/offline behavior.
- **Why needed:** Documented in `docs/APP_STRUCTURE.md`; required for current app behavior.
- **What it contains:** Source for `UX_CONTRACT.md` (see source file).
- **Responsibilities:** Tap/save/loading/offline behavior
- **When to open:** Understanding project rules, deploy steps, or structure — not runtime debugging.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** Role: Tap/save/loading/offline behavior
- **Layer / owner:** Documentation — explains rules, not runtime code.

RU:

- **Что это:** Markdown-документ `ux_contract.md` — правила и заметки по теме «ux contract».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `ux contract`.
- **Когда открывать:** Нужна written-инструкция по `ux contract`.
- **Можно удалить?** Нет — governing-документация проекта.
- **Связано с:** `docs/APP_STRUCTURE.md`, связанные файлы в этой папке.
- **Слой:** Документация — не runtime.


### `docs/reports/DESIGN_SYSTEM_INVENTORY.md`

EN:

- **What this is:** Documentation file `DESIGN_SYSTEM_INVENTORY.md` — explains part of project rules, deploy, or reports.
- **Why needed:** Human/AI readable spec; not executed by the app.
- **What it contains:** Markdown sections for this topic.
- **Responsibilities:** Answer questions about `DESIGN SYSTEM INVENTORY`.
- **When to open:** Need written guidance for topic covered by `DESIGN_SYSTEM_INVENTORY.md`.
- **Can it be deleted?** No — governing/current documentation.
- **Connected to:** Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Documentation.

RU:

- **Что это:** Markdown-документ `design_system_inventory.md` — правила и заметки по теме «design system inventory».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `design system inventory`.
- **Когда открывать:** Нужна written-инструкция по `design system inventory`.
- **Можно удалить?** Нет — governing-документация проекта.
- **Связано с:** См. также: Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Слой:** Документация — не runtime.


### `docs/reports/FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md`

EN:

- **What this is:** Documentation file `FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md` — explains part of project rules, deploy, or reports.
- **Why needed:** Human/AI readable spec; not executed by the app.
- **What it contains:** Markdown sections for this topic.
- **Responsibilities:** Answer questions about `FINAL STRUCTURE PARITY AND DOC CLEANUP 2026-07-03`.
- **When to open:** Need written guidance for topic covered by `FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md`.
- **Can it be deleted?** No — current cleanup/structure report or upload checklist.
- **Connected to:** Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Documentation.

RU:

- **Что это:** Markdown-документ `final_structure_parity_and_doc_cleanup_2026-07-03.md` — правила и заметки по теме «final structure parity and doc cleanup 2026-07-03».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `final structure parity and doc cleanup 2026-07-03`.
- **Когда открывать:** Нужна written-инструкция по `final structure parity and doc cleanup 2026-07-03`.
- **Можно удалить?** Нет — актуальный отчёт или чеклист.
- **Связано с:** См. также: Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Слой:** Документация — не runtime.


### `docs/reports/FULL_REPO_NECESSITY_CLEANUP_2026-07-03.md`

EN:

- **What this is:** Documentation file `FULL_REPO_NECESSITY_CLEANUP_2026-07-03.md` — explains part of project rules, deploy, or reports.
- **Why needed:** Human/AI readable spec; not executed by the app.
- **What it contains:** Markdown sections for this topic.
- **Responsibilities:** Answer questions about `FULL REPO NECESSITY CLEANUP 2026-07-03`.
- **When to open:** Need written guidance for topic covered by `FULL_REPO_NECESSITY_CLEANUP_2026-07-03.md`.
- **Can it be deleted?** No — current cleanup/structure report or upload checklist.
- **Connected to:** Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Documentation.

RU:

- **Что это:** Markdown-документ `full_repo_necessity_cleanup_2026-07-03.md` — правила и заметки по теме «full repo necessity cleanup 2026-07-03».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `full repo necessity cleanup 2026-07-03`.
- **Когда открывать:** Нужна written-инструкция по `full repo necessity cleanup 2026-07-03`.
- **Можно удалить?** Нет — актуальный отчёт или чеклист.
- **Связано с:** См. также: Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Слой:** Документация — не runtime.


### `docs/website/CONTENT_LIBRARY.md`

EN:

- **What this is:** Documentation file `CONTENT_LIBRARY.md` — explains part of project rules, deploy, or reports.
- **Why needed:** Human/AI readable spec; not executed by the app.
- **What it contains:** Markdown sections for this topic.
- **Responsibilities:** Answer questions about `CONTENT LIBRARY`.
- **When to open:** Need written guidance for topic covered by `CONTENT_LIBRARY.md`.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Documentation.

RU:

- **Что это:** Markdown-документ `content_library.md` — правила и заметки по теме «content library».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `content library`.
- **Когда открывать:** Нужна written-инструкция по `content library`.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** См. также: Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Слой:** Документация — не runtime.


### `docs/website/FEATURE_MATRIX.md`

EN:

- **What this is:** Documentation file `FEATURE_MATRIX.md` — explains part of project rules, deploy, or reports.
- **Why needed:** Human/AI readable spec; not executed by the app.
- **What it contains:** Markdown sections for this topic.
- **Responsibilities:** Answer questions about `FEATURE MATRIX`.
- **When to open:** Need written guidance for topic covered by `FEATURE_MATRIX.md`.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Documentation.

RU:

- **Что это:** Markdown-документ `feature_matrix.md` — правила и заметки по теме «feature matrix».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `feature matrix`.
- **Когда открывать:** Нужна written-инструкция по `feature matrix`.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** См. также: Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Слой:** Документация — не runtime.


### `docs/website/HOMEPAGE_WIREFRAME_V1.md`

EN:

- **What this is:** Documentation file `HOMEPAGE_WIREFRAME_V1.md` — explains part of project rules, deploy, or reports.
- **Why needed:** Human/AI readable spec; not executed by the app.
- **What it contains:** Markdown sections for this topic.
- **Responsibilities:** Answer questions about `HOMEPAGE WIREFRAME V1`.
- **When to open:** Need written guidance for topic covered by `HOMEPAGE_WIREFRAME_V1.md`.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Documentation.

RU:

- **Что это:** Markdown-документ `homepage_wireframe_v1.md` — правила и заметки по теме «homepage wireframe v1».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `homepage wireframe v1`.
- **Когда открывать:** Нужна written-инструкция по `homepage wireframe v1`.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** См. также: Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Слой:** Документация — не runtime.


### `docs/website/INTERNAL_NOTES_NOT_FOR_SITE.md`

EN:

- **What this is:** Documentation file `INTERNAL_NOTES_NOT_FOR_SITE.md` — explains part of project rules, deploy, or reports.
- **Why needed:** Human/AI readable spec; not executed by the app.
- **What it contains:** Markdown sections for this topic.
- **Responsibilities:** Answer questions about `INTERNAL NOTES NOT FOR SITE`.
- **When to open:** Need written guidance for topic covered by `INTERNAL_NOTES_NOT_FOR_SITE.md`.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Documentation.

RU:

- **Что это:** Markdown-документ `internal_notes_not_for_site.md` — правила и заметки по теме «internal notes not for site».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `internal notes not for site`.
- **Когда открывать:** Нужна written-инструкция по `internal notes not for site`.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** См. также: Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Слой:** Документация — не runtime.


### `docs/website/POSITIONING_V1.md`

EN:

- **What this is:** Documentation file `POSITIONING_V1.md` — explains part of project rules, deploy, or reports.
- **Why needed:** Human/AI readable spec; not executed by the app.
- **What it contains:** Markdown sections for this topic.
- **Responsibilities:** Answer questions about `POSITIONING V1`.
- **When to open:** Need written guidance for topic covered by `POSITIONING_V1.md`.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Documentation.

RU:

- **Что это:** Markdown-документ `positioning_v1.md` — правила и заметки по теме «positioning v1».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `positioning v1`.
- **Когда открывать:** Нужна written-инструкция по `positioning v1`.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** См. также: Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Слой:** Документация — не runtime.


### `docs/website/PRODUCT_INVENTORY.md`

EN:

- **What this is:** Documentation file `PRODUCT_INVENTORY.md` — explains part of project rules, deploy, or reports.
- **Why needed:** Human/AI readable spec; not executed by the app.
- **What it contains:** Markdown sections for this topic.
- **Responsibilities:** Answer questions about `PRODUCT INVENTORY`.
- **When to open:** Need written guidance for topic covered by `PRODUCT_INVENTORY.md`.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Documentation.

RU:

- **Что это:** Markdown-документ `product_inventory.md` — правила и заметки по теме «product inventory».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `product inventory`.
- **Когда открывать:** Нужна written-инструкция по `product inventory`.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** См. также: Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Слой:** Документация — не runtime.


### `docs/website/PUBLIC_COPY_DRAFTS.md`

EN:

- **What this is:** Documentation file `PUBLIC_COPY_DRAFTS.md` — explains part of project rules, deploy, or reports.
- **Why needed:** Human/AI readable spec; not executed by the app.
- **What it contains:** Markdown sections for this topic.
- **Responsibilities:** Answer questions about `PUBLIC COPY DRAFTS`.
- **When to open:** Need written guidance for topic covered by `PUBLIC_COPY_DRAFTS.md`.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Documentation.

RU:

- **Что это:** Markdown-документ `public_copy_drafts.md` — правила и заметки по теме «public copy drafts».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `public copy drafts`.
- **Когда открывать:** Нужна written-инструкция по `public copy drafts`.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** См. также: Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Слой:** Документация — не runtime.


### `docs/website/SCREENSHOT_SHOTLIST.md`

EN:

- **What this is:** Documentation file `SCREENSHOT_SHOTLIST.md` — explains part of project rules, deploy, or reports.
- **Why needed:** Human/AI readable spec; not executed by the app.
- **What it contains:** Markdown sections for this topic.
- **Responsibilities:** Answer questions about `SCREENSHOT SHOTLIST`.
- **When to open:** Need written guidance for topic covered by `SCREENSHOT_SHOTLIST.md`.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Documentation.

RU:

- **Что это:** Markdown-документ `screenshot_shotlist.md` — правила и заметки по теме «screenshot shotlist».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `screenshot shotlist`.
- **Когда открывать:** Нужна written-инструкция по `screenshot shotlist`.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** См. также: Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Слой:** Документация — не runtime.


### `docs/website/WEBSITE_CLAIMS_REVIEW.md`

EN:

- **What this is:** Documentation file `WEBSITE_CLAIMS_REVIEW.md` — explains part of project rules, deploy, or reports.
- **Why needed:** Human/AI readable spec; not executed by the app.
- **What it contains:** Markdown sections for this topic.
- **Responsibilities:** Answer questions about `WEBSITE CLAIMS REVIEW`.
- **When to open:** Need written guidance for topic covered by `WEBSITE_CLAIMS_REVIEW.md`.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Documentation.

RU:

- **Что это:** Markdown-документ `website_claims_review.md` — правила и заметки по теме «website claims review».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `website claims review`.
- **Когда открывать:** Нужна written-инструкция по `website claims review`.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** См. также: Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Слой:** Документация — не runtime.


### `docs/website/WEBSITE_IMPLEMENTATION_OPTIONS.md`

EN:

- **What this is:** Documentation file `WEBSITE_IMPLEMENTATION_OPTIONS.md` — explains part of project rules, deploy, or reports.
- **Why needed:** Human/AI readable spec; not executed by the app.
- **What it contains:** Markdown sections for this topic.
- **Responsibilities:** Answer questions about `WEBSITE IMPLEMENTATION OPTIONS`.
- **When to open:** Need written guidance for topic covered by `WEBSITE_IMPLEMENTATION_OPTIONS.md`.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Documentation.

RU:

- **Что это:** Markdown-документ `website_implementation_options.md` — правила и заметки по теме «website implementation options».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `website implementation options`.
- **Когда открывать:** Нужна written-инструкция по `website implementation options`.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** См. также: Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Слой:** Документация — не runtime.


### `docs/website/WEBSITE_PAGE_STRUCTURE.md`

EN:

- **What this is:** Documentation file `WEBSITE_PAGE_STRUCTURE.md` — explains part of project rules, deploy, or reports.
- **Why needed:** Human/AI readable spec; not executed by the app.
- **What it contains:** Markdown sections for this topic.
- **Responsibilities:** Answer questions about `WEBSITE PAGE STRUCTURE`.
- **When to open:** Need written guidance for topic covered by `WEBSITE_PAGE_STRUCTURE.md`.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Documentation.

RU:

- **Что это:** Markdown-документ `website_page_structure.md` — правила и заметки по теме «website page structure».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `website page structure`.
- **Когда открывать:** Нужна written-инструкция по `website page structure`.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** См. также: Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Слой:** Документация — не runtime.


### `docs/website/WEBSITE_TZ.md`

EN:

- **What this is:** Documentation file `WEBSITE_TZ.md` — explains part of project rules, deploy, or reports.
- **Why needed:** Human/AI readable spec; not executed by the app.
- **What it contains:** Markdown sections for this topic.
- **Responsibilities:** Answer questions about `WEBSITE TZ`.
- **When to open:** Need written guidance for topic covered by `WEBSITE_TZ.md`.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Documentation.

RU:

- **Что это:** Markdown-документ `website_tz.md` — правила и заметки по теме «website tz».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `website tz`.
- **Когда открывать:** Нужна written-инструкция по `website tz`.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** См. также: Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Слой:** Документация — не runtime.


### `docs/website/WEBSITE_V1_SCOPE.md`

EN:

- **What this is:** Documentation file `WEBSITE_V1_SCOPE.md` — explains part of project rules, deploy, or reports.
- **Why needed:** Human/AI readable spec; not executed by the app.
- **What it contains:** Markdown sections for this topic.
- **Responsibilities:** Answer questions about `WEBSITE V1 SCOPE`.
- **When to open:** Need written guidance for topic covered by `WEBSITE_V1_SCOPE.md`.
- **Can it be deleted?** No — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Connected to:** Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Layer / owner:** Documentation.

RU:

- **Что это:** Markdown-документ `website_v1_scope.md` — правила и заметки по теме «website v1 scope».
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `website v1 scope`.
- **Когда открывать:** Нужна written-инструкция по `website v1 scope`.
- **Можно удалить?** Нет — маркетинговые тексты сайта.
- **Связано с:** См. также: Project Knowledge pack or repo-only per `PROJECT_KNOWLEDGE_PACK.md`.
- **Слой:** Документация — не runtime.


### `installer/windows/build_stt_helper_en.ps1`

EN:

- **What this is:** installer build file `build_stt_helper_en.ps1` in `installer/windows` — required by Flutter/native toolchain.
- **Why needed:** Without `build_stt_helper_en.ps1`, installer compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `installer/windows` (open file only when build errors cite it).
- **Responsibilities:** Support installer embedder build for `installer/windows` — not Dart business logic.
- **When to open:** Build log mentions `build_stt_helper_en.ps1` or `installer/windows`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `installer/` platform folder, Flutter embedder.
- **Layer / owner:** Build/deploy/server configuration.

RU:

- **Что это:** Файл `build_stt_helper_en.ps1` в каталоге `installer/windows/`.
- **Зачем:** Поддерживает documented workflow каталога `installer/windows/`.
- **Содержимое:** Исходное содержимое `build_stt_helper_en.ps1`.
- **Обязанности:** Зона ответственности `build_stt_helper_en.ps1` в `installer/windows/`.
- **Когда открывать:** Build или maintenance ссылается на `build_stt_helper_en.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `installer/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `counter.iss` в каталоге `installer/windows/`.
- **Зачем:** Поддерживает documented workflow каталога `installer/windows/`.
- **Содержимое:** Исходное содержимое `counter.iss`.
- **Обязанности:** Зона ответственности `counter.iss` в `installer/windows/`.
- **Когда открывать:** Build или maintenance ссылается на `counter.iss`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `prepare_stt_payload.ps1`, GitHub Actions workflow.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `installer/windows/install-cpp-atl.ps1`

EN:

- **What this is:** installer build file `install-cpp-atl.ps1` in `installer/windows` — required by Flutter/native toolchain.
- **Why needed:** Without `install-cpp-atl.ps1`, installer compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `installer/windows` (open file only when build errors cite it).
- **Responsibilities:** Support installer embedder build for `installer/windows` — not Dart business logic.
- **When to open:** Build log mentions `install-cpp-atl.ps1` or `installer/windows`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `installer/` platform folder, Flutter embedder.
- **Layer / owner:** Build/deploy/server configuration.

RU:

- **Что это:** Файл `install-cpp-atl.ps1` в каталоге `installer/windows/`.
- **Зачем:** Поддерживает documented workflow каталога `installer/windows/`.
- **Содержимое:** Исходное содержимое `install-cpp-atl.ps1`.
- **Обязанности:** Зона ответственности `install-cpp-atl.ps1` в `installer/windows/`.
- **Когда открывать:** Build или maintenance ссылается на `install-cpp-atl.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `installer/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `installer/windows/prepare_stt_payload.ps1`

EN:

- **What this is:** installer build file `prepare_stt_payload.ps1` in `installer/windows` — required by Flutter/native toolchain.
- **Why needed:** Without `prepare_stt_payload.ps1`, installer compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `installer/windows` (open file only when build errors cite it).
- **Responsibilities:** Support installer embedder build for `installer/windows` — not Dart business logic.
- **When to open:** Build log mentions `prepare_stt_payload.ps1` or `installer/windows`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `installer/` platform folder, Flutter embedder.
- **Layer / owner:** Build/deploy/server configuration.

RU:

- **Что это:** Файл `prepare_stt_payload.ps1` в каталоге `installer/windows/`.
- **Зачем:** Поддерживает documented workflow каталога `installer/windows/`.
- **Содержимое:** Исходное содержимое `prepare_stt_payload.ps1`.
- **Обязанности:** Зона ответственности `prepare_stt_payload.ps1` в `installer/windows/`.
- **Когда открывать:** Build или maintenance ссылается на `prepare_stt_payload.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `installer/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `installer/windows/scripts/win_speech_wav.ps1`

EN:

- **What this is:** installer build file `win_speech_wav.ps1` in `installer/windows/scripts` — required by Flutter/native toolchain.
- **Why needed:** Without `win_speech_wav.ps1`, installer compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `installer/windows/scripts` (open file only when build errors cite it).
- **Responsibilities:** Support installer embedder build for `installer/windows/scripts` — not Dart business logic.
- **When to open:** Build log mentions `win_speech_wav.ps1` or `installer/windows/scripts`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `installer/` platform folder, Flutter embedder.
- **Layer / owner:** Build/deploy/server configuration.

RU:

- **Что это:** Файл `win_speech_wav.ps1` в каталоге `installer/windows/scripts/`.
- **Зачем:** Поддерживает documented workflow каталога `installer/windows/scripts/`.
- **Содержимое:** Исходное содержимое `win_speech_wav.ps1`.
- **Обязанности:** Зона ответственности `win_speech_wav.ps1` в `installer/windows/scripts/`.
- **Когда открывать:** Build или maintenance ссылается на `win_speech_wav.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `installer/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `installer/windows/stt_helper_build/counter_stt_helper.exe`

EN:

- **What this is:** installer build file `counter_stt_helper.exe` in `installer/windows/stt_helper_build` — required by Flutter/native toolchain.
- **Why needed:** Without `counter_stt_helper.exe`, installer compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `installer/windows/stt_helper_build` (open file only when build errors cite it).
- **Responsibilities:** Support installer embedder build for `installer/windows/stt_helper_build` — not Dart business logic.
- **When to open:** Build log mentions `counter_stt_helper.exe` or `installer/windows/stt_helper_build`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `installer/` platform folder, Flutter embedder.
- **Layer / owner:** Build/deploy/server configuration.

RU:

- **Что это:** Файл `counter_stt_helper.exe` в каталоге `installer/windows/stt_helper_build/`.
- **Зачем:** Поддерживает documented workflow каталога `installer/windows/stt_helper_build/`.
- **Содержимое:** Исходное содержимое `counter_stt_helper.exe`.
- **Обязанности:** Зона ответственности `counter_stt_helper.exe` в `installer/windows/stt_helper_build/`.
- **Когда открывать:** Build или maintenance ссылается на `counter_stt_helper.exe`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `installer/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `.gitignore` в каталоге `ios/`.
- **Зачем:** Prevents результат сборки and secrets from entering git history.
- **Содержимое:** Исходное содержимое `.gitignore`.
- **Обязанности:** Зона ответственности `.gitignore` в `ios/`.
- **Когда открывать:** Build или maintenance ссылается на `.gitignore`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `ios` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `appframeworkinfo.plist` в каталоге `ios/Flutter/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Flutter/`.
- **Содержимое:** Исходное содержимое `appframeworkinfo.plist`.
- **Обязанности:** Зона ответственности `appframeworkinfo.plist` в `ios/Flutter/`.
- **Когда открывать:** Build или maintenance ссылается на `appframeworkinfo.plist`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `ios/Flutter/Debug.xcconfig`

EN:

- **What this is:** ios build file `Debug.xcconfig` in `ios/Flutter` — required by Flutter/native toolchain.
- **Why needed:** Without `Debug.xcconfig`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Flutter` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Flutter` — not Dart business logic.
- **When to open:** Build log mentions `Debug.xcconfig` or `ios/Flutter`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Файл `debug.xcconfig` в каталоге `ios/Flutter/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Flutter/`.
- **Содержимое:** Исходное содержимое `debug.xcconfig`.
- **Обязанности:** Зона ответственности `debug.xcconfig` в `ios/Flutter/`.
- **Когда открывать:** Build или maintenance ссылается на `debug.xcconfig`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `ios/Flutter/Release.xcconfig`

EN:

- **What this is:** ios build file `Release.xcconfig` in `ios/Flutter` — required by Flutter/native toolchain.
- **Why needed:** Without `Release.xcconfig`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Flutter` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Flutter` — not Dart business logic.
- **When to open:** Build log mentions `Release.xcconfig` or `ios/Flutter`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Файл `release.xcconfig` в каталоге `ios/Flutter/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Flutter/`.
- **Содержимое:** Исходное содержимое `release.xcconfig`.
- **Обязанности:** Зона ответственности `release.xcconfig` в `ios/Flutter/`.
- **Когда открывать:** Build или maintenance ссылается на `release.xcconfig`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `ios/Runner.xcodeproj/project.pbxproj`

EN:

- **What this is:** ios build file `project.pbxproj` in `ios/Runner.xcodeproj` — required by Flutter/native toolchain.
- **Why needed:** Without `project.pbxproj`, ios compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `ios/Runner.xcodeproj` (open file only when build errors cite it).
- **Responsibilities:** Support ios embedder build for `ios/Runner.xcodeproj` — not Dart business logic.
- **When to open:** Build log mentions `project.pbxproj` or `ios/Runner.xcodeproj`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `ios/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Файл `project.pbxproj` в каталоге `ios/Runner.xcodeproj/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner.xcodeproj/`.
- **Содержимое:** Исходное содержимое `project.pbxproj`.
- **Обязанности:** Зона ответственности `project.pbxproj` в `ios/Runner.xcodeproj/`.
- **Когда открывать:** Build или maintenance ссылается на `project.pbxproj`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `contents.xcworkspacedata` в каталоге `ios/Runner.xcodeproj/project.xcworkspace/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner.xcodeproj/project.xcworkspace/`.
- **Содержимое:** Исходное содержимое `contents.xcworkspacedata`.
- **Обязанности:** Зона ответственности `contents.xcworkspacedata` в `ios/Runner.xcodeproj/project.xcworkspace/`.
- **Когда открывать:** Build или maintenance ссылается на `contents.xcworkspacedata`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `ideworkspacechecks.plist` в каталоге `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/`.
- **Содержимое:** Исходное содержимое `ideworkspacechecks.plist`.
- **Обязанности:** Зона ответственности `ideworkspacechecks.plist` в `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/`.
- **Когда открывать:** Build или maintenance ссылается на `ideworkspacechecks.plist`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `workspacesettings.xcsettings` в каталоге `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/`.
- **Содержимое:** Исходное содержимое `workspacesettings.xcsettings`.
- **Обязанности:** Зона ответственности `workspacesettings.xcsettings` в `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/`.
- **Когда открывать:** Build или maintenance ссылается на `workspacesettings.xcsettings`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `runner.xcscheme` в каталоге `ios/Runner.xcodeproj/xcshareddata/xcschemes/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner.xcodeproj/xcshareddata/xcschemes/`.
- **Содержимое:** Исходное содержимое `runner.xcscheme`.
- **Обязанности:** Зона ответственности `runner.xcscheme` в `ios/Runner.xcodeproj/xcshareddata/xcschemes/`.
- **Когда открывать:** Build или maintenance ссылается на `runner.xcscheme`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `contents.xcworkspacedata` в каталоге `ios/Runner.xcworkspace/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner.xcworkspace/`.
- **Содержимое:** Исходное содержимое `contents.xcworkspacedata`.
- **Обязанности:** Зона ответственности `contents.xcworkspacedata` в `ios/Runner.xcworkspace/`.
- **Когда открывать:** Build или maintenance ссылается на `contents.xcworkspacedata`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `ideworkspacechecks.plist` в каталоге `ios/Runner.xcworkspace/xcshareddata/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner.xcworkspace/xcshareddata/`.
- **Содержимое:** Исходное содержимое `ideworkspacechecks.plist`.
- **Обязанности:** Зона ответственности `ideworkspacechecks.plist` в `ios/Runner.xcworkspace/xcshareddata/`.
- **Когда открывать:** Build или maintenance ссылается на `ideworkspacechecks.plist`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `workspacesettings.xcsettings` в каталоге `ios/Runner.xcworkspace/xcshareddata/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner.xcworkspace/xcshareddata/`.
- **Содержимое:** Исходное содержимое `workspacesettings.xcsettings`.
- **Обязанности:** Зона ответственности `workspacesettings.xcsettings` в `ios/Runner.xcworkspace/xcshareddata/`.
- **Когда открывать:** Build или maintenance ссылается на `workspacesettings.xcsettings`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `appdelegate.swift` в каталоге `ios/Runner/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/`.
- **Содержимое:** Исходное содержимое `appdelegate.swift`.
- **Обязанности:** Зона ответственности `appdelegate.swift` в `ios/Runner/`.
- **Когда открывать:** Build или maintenance ссылается на `appdelegate.swift`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `contents.json` в каталоге `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `contents.json`.
- **Обязанности:** Зона ответственности `contents.json` в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `contents.json`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-app-1024x1024@1x.png` в каталоге `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `icon-app-1024x1024@1x.png`.
- **Обязанности:** Зона ответственности `icon-app-1024x1024@1x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-app-1024x1024@1x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-app-20x20@1x.png` в каталоге `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `icon-app-20x20@1x.png`.
- **Обязанности:** Зона ответственности `icon-app-20x20@1x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-app-20x20@1x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-app-20x20@2x.png` в каталоге `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `icon-app-20x20@2x.png`.
- **Обязанности:** Зона ответственности `icon-app-20x20@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-app-20x20@2x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-app-20x20@3x.png` в каталоге `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `icon-app-20x20@3x.png`.
- **Обязанности:** Зона ответственности `icon-app-20x20@3x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-app-20x20@3x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-app-29x29@1x.png` в каталоге `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `icon-app-29x29@1x.png`.
- **Обязанности:** Зона ответственности `icon-app-29x29@1x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-app-29x29@1x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-app-29x29@2x.png` в каталоге `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `icon-app-29x29@2x.png`.
- **Обязанности:** Зона ответственности `icon-app-29x29@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-app-29x29@2x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-app-29x29@3x.png` в каталоге `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `icon-app-29x29@3x.png`.
- **Обязанности:** Зона ответственности `icon-app-29x29@3x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-app-29x29@3x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-app-40x40@1x.png` в каталоге `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `icon-app-40x40@1x.png`.
- **Обязанности:** Зона ответственности `icon-app-40x40@1x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-app-40x40@1x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-app-40x40@2x.png` в каталоге `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `icon-app-40x40@2x.png`.
- **Обязанности:** Зона ответственности `icon-app-40x40@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-app-40x40@2x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-app-40x40@3x.png` в каталоге `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `icon-app-40x40@3x.png`.
- **Обязанности:** Зона ответственности `icon-app-40x40@3x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-app-40x40@3x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-app-60x60@2x.png` в каталоге `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `icon-app-60x60@2x.png`.
- **Обязанности:** Зона ответственности `icon-app-60x60@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-app-60x60@2x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-app-60x60@3x.png` в каталоге `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `icon-app-60x60@3x.png`.
- **Обязанности:** Зона ответственности `icon-app-60x60@3x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-app-60x60@3x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-app-76x76@1x.png` в каталоге `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `icon-app-76x76@1x.png`.
- **Обязанности:** Зона ответственности `icon-app-76x76@1x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-app-76x76@1x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-app-76x76@2x.png` в каталоге `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `icon-app-76x76@2x.png`.
- **Обязанности:** Зона ответственности `icon-app-76x76@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-app-76x76@2x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-app-83.5x83.5@2x.png` в каталоге `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `icon-app-83.5x83.5@2x.png`.
- **Обязанности:** Зона ответственности `icon-app-83.5x83.5@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-app-83.5x83.5@2x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `contents.json` в каталоге `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **Содержимое:** Исходное содержимое `contents.json`.
- **Обязанности:** Зона ответственности `contents.json` в `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **Когда открывать:** Build или maintenance ссылается на `contents.json`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `launchimage.png` в каталоге `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **Содержимое:** Исходное содержимое `launchimage.png`.
- **Обязанности:** Зона ответственности `launchimage.png` в `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **Когда открывать:** Build или maintenance ссылается на `launchimage.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `launchimage@2x.png` в каталоге `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **Содержимое:** Исходное содержимое `launchimage@2x.png`.
- **Обязанности:** Зона ответственности `launchimage@2x.png` в `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **Когда открывать:** Build или maintenance ссылается на `launchimage@2x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `launchimage@3x.png` в каталоге `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **Содержимое:** Исходное содержимое `launchimage@3x.png`.
- **Обязанности:** Зона ответственности `launchimage@3x.png` в `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **Когда открывать:** Build или maintenance ссылается на `launchimage@3x.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `readme.md` в каталоге `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **Содержимое:** Исходное содержимое `readme.md`.
- **Обязанности:** Зона ответственности `readme.md` в `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **Когда открывать:** Build или maintenance ссылается на `readme.md`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `launchscreen.storyboard` в каталоге `ios/Runner/Base.lproj/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Base.lproj/`.
- **Содержимое:** Исходное содержимое `launchscreen.storyboard`.
- **Обязанности:** Зона ответственности `launchscreen.storyboard` в `ios/Runner/Base.lproj/`.
- **Когда открывать:** Build или maintenance ссылается на `launchscreen.storyboard`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `main.storyboard` в каталоге `ios/Runner/Base.lproj/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/Base.lproj/`.
- **Содержимое:** Исходное содержимое `main.storyboard`.
- **Обязанности:** Зона ответственности `main.storyboard` в `ios/Runner/Base.lproj/`.
- **Когда открывать:** Build или maintenance ссылается на `main.storyboard`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `info.plist` в каталоге `ios/Runner/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/`.
- **Содержимое:** Исходное содержимое `info.plist`.
- **Обязанности:** Зона ответственности `info.plist` в `ios/Runner/`.
- **Когда открывать:** Build или maintenance ссылается на `info.plist`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `ios` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `runner-bridging-header.h` в каталоге `ios/Runner/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/`.
- **Содержимое:** Исходное содержимое `runner-bridging-header.h`.
- **Обязанности:** Зона ответственности `runner-bridging-header.h` в `ios/Runner/`.
- **Когда открывать:** Build или maintenance ссылается на `runner-bridging-header.h`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `scenedelegate.swift` в каталоге `ios/Runner/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/Runner/`.
- **Содержимое:** Исходное содержимое `scenedelegate.swift`.
- **Обязанности:** Зона ответственности `scenedelegate.swift` в `ios/Runner/`.
- **Когда открывать:** Build или maintenance ссылается на `scenedelegate.swift`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `runnertests.swift` в каталоге `ios/RunnerTests/`.
- **Зачем:** Поддерживает documented workflow каталога `ios/RunnerTests/`.
- **Содержимое:** Исходное содержимое `runnertests.swift`.
- **Обязанности:** Зона ответственности `runnertests.swift` в `ios/RunnerTests/`.
- **Когда открывать:** Build или maintenance ссылается на `runnertests.swift`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `ios/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `lib/app_shell.dart`

EN:

- **What this is:** Source file `app_shell.dart` — Re-exports `shell/life_os_dashboard.dart` (thin entry).
- **Why needed:** Documented in `docs/APP_STRUCTURE.md`; required for current app behavior.
- **What it contains:** Source for `app_shell.dart` (see source file).
- **Responsibilities:** Re-exports `shell/life_os_dashboard.dart` (thin entry)
- **When to open:** When behavior tied to `app_shell.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Re-exports `shell/life_os_dashboard.dart` (thin entry)
- **Layer / owner:** Repository support file.

RU:

- **Что это:** Dart-файл `app_shell.dart` — Dart-код приложения: логика Counter на этом уровне `lib/`.
- **Зачем:** Модуль `lib/app_shell.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `app_shell.dart`.
- **Обязанности:** Реализует логика Counter на этом уровне `lib/` для пути `lib/app_shell.dart`.
- **Когда открывать:** Баг или доработка, связанная с `app_shell.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Dart-код приложения — не platform wrapper.


### `lib/core/app_build_info.dart`

EN:

- **What this is:** Foundation helper (core) — Build metadata.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Build metadata
- **When to open:** When behavior tied to `app_build_info.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Build metadata
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `app_build_info.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/app_build_info.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `app_build_info.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/app_build_info.dart`.
- **Когда открывать:** Баг или доработка, связанная с `app_build_info.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/app_colors.dart`

EN:

- **What this is:** Foundation helper (core) — Color tokens.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Color tokens
- **When to open:** When behavior tied to `app_colors.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Color tokens
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `app_colors.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/app_colors.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `app_colors.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/app_colors.dart`.
- **Когда открывать:** Баг или доработка, связанная с `app_colors.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/app_icons.dart`

EN:

- **What this is:** Foundation helper (core) — Canonical icon tokens (timezone family, shared glyphs).
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`AppTimezoneIconKey`).
- **Key code names:** `AppTimezoneIconKey`
- **Responsibilities:** Canonical icon tokens (timezone family, shared glyphs)
- **When to open:** When behavior tied to `app_icons.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Canonical icon tokens (timezone family, shared glyphs)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `app_icons.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/app_icons.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `app_icons.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/app_icons.dart`.
- **Когда открывать:** Баг или доработка, связанная с `app_icons.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/app_snackbar.dart`

EN:

- **What this is:** Foundation helper (core) — `AppSnack` toasts.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`AppSnack`).
- **Key code names:** `AppSnack`
- **Responsibilities:** `AppSnack` toasts
- **When to open:** When behavior tied to `app_snackbar.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: `AppSnack` toasts
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `app_snackbar.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/app_snackbar.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `app_snackbar.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/app_snackbar.dart`.
- **Когда открывать:** Баг или доработка, связанная с `app_snackbar.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/category_color_palette.dart`

EN:

- **What this is:** Foundation helper (core) — Category tile palette.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Category tile palette
- **When to open:** When behavior tied to `category_color_palette.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Category tile palette
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `category_color_palette.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/category_color_palette.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `category_color_palette.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/category_color_palette.dart`.
- **Когда открывать:** Баг или доработка, связанная с `category_color_palette.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/constants.dart`

EN:

- **What this is:** Foundation helper (core) — UI limits, global keys.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** UI limits, global keys
- **When to open:** When behavior tied to `constants.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: UI limits, global keys
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `constants.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/constants.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `constants.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/constants.dart`.
- **Когда открывать:** Баг или доработка, связанная с `constants.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/date_pager_settle_gate.dart`

EN:

- **What this is:** Foundation helper (core) — Shared date `PageView` settle coordinator.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Shared date `PageView` settle coordinator
- **When to open:** When behavior tied to `date_pager_settle_gate.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Shared date `PageView` settle coordinator
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `date_pager_settle_gate.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/date_pager_settle_gate.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `date_pager_settle_gate.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/date_pager_settle_gate.dart`.
- **Когда открывать:** Баг или доработка, связанная с `date_pager_settle_gate.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/date_swipe_physics.dart`

EN:

- **What this is:** Foundation helper (core) — Date swipe physics.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`LightDateSwipePhysics`, `FeatherDateSwipePhysics`).
- **Key code names:** `LightDateSwipePhysics`, `FeatherDateSwipePhysics`
- **Responsibilities:** Date swipe physics
- **When to open:** When behavior tied to `date_swipe_physics.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Date swipe physics
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `date_swipe_physics.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/date_swipe_physics.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `date_swipe_physics.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/date_swipe_physics.dart`.
- **Когда открывать:** Баг или доработка, связанная с `date_swipe_physics.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/diagnostics/desktop_voice_log.dart`

EN:

- **What this is:** Foundation helper (diagnostics) — `DesktopVoiceLog` — concise desktop-voice pipeline markers (debug/profile only.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`DesktopVoiceLog`).
- **Key code names:** `DesktopVoiceLog`
- **Responsibilities:** `DesktopVoiceLog` — concise desktop-voice pipeline markers (debug/profile only; release quiet)
- **When to open:** When behavior tied to `desktop_voice_log.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: `DesktopVoiceLog` — concise desktop-voice pipeline markers (debug/profile only; release quiet)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_log.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/diagnostics/desktop_voice_log.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_log.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/diagnostics/desktop_voice_log.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_log.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/diagnostics/desktop_voice_pipeline.dart`

EN:

- **What this is:** Foundation helper (diagnostics) — Desktop-voice pipeline step helpers built on `DesktopVoiceLog`.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Desktop-voice pipeline step helpers built on `DesktopVoiceLog`
- **When to open:** When behavior tied to `desktop_voice_pipeline.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Desktop-voice pipeline step helpers built on `DesktopVoiceLog`
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_pipeline.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/diagnostics/desktop_voice_pipeline.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_pipeline.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/diagnostics/desktop_voice_pipeline.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_pipeline.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/diagnostics/plan_duplicate_log.dart`

EN:

- **What this is:** Foundation helper (diagnostics) — Plan duplicate detection logs.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Plan duplicate detection logs
- **When to open:** When behavior tied to `plan_duplicate_log.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Plan duplicate detection logs
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `plan_duplicate_log.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/diagnostics/plan_duplicate_log.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_duplicate_log.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/diagnostics/plan_duplicate_log.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_duplicate_log.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/diagnostics/platform_log.dart`

EN:

- **What this is:** Foundation helper (diagnostics) — Platform-specific log sinks.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Platform-specific log sinks
- **When to open:** When behavior tied to `platform_log.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Platform-specific log sinks
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `platform_log.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/diagnostics/platform_log.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `platform_log.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/diagnostics/platform_log.dart`.
- **Когда открывать:** Баг или доработка, связанная с `platform_log.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/diagnostics/runtime_log.dart`

EN:

- **What this is:** Foundation helper (diagnostics) — Uncaught error logging.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Uncaught error logging
- **When to open:** When behavior tied to `runtime_log.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Uncaught error logging
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `runtime_log.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/diagnostics/runtime_log.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `runtime_log.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/diagnostics/runtime_log.dart`.
- **Когда открывать:** Баг или доработка, связанная с `runtime_log.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/diagnostics/startup_log.dart`

EN:

- **What this is:** Foundation helper (diagnostics) — Boot-phase structured logs.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Boot-phase structured logs
- **When to open:** When behavior tied to `startup_log.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Boot-phase structured logs
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `startup_log.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/diagnostics/startup_log.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `startup_log.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/diagnostics/startup_log.dart`.
- **Когда открывать:** Баг или доработка, связанная с `startup_log.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/env/env.dart.example`

EN:

- **What this is:** example file `env.dart.example` in `lib/core/env` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/core/env` needs `env.dart.example` for build, CI, or documented workflow.
- **What it contains:** Open `env.dart.example` when editing example file for `lib/core/env` (see folder section above).
- **Responsibilities:** Fulfill the documented role of `env.dart.example` under `lib/core/env`.
- **When to open:** When build output or maintenance cites `env.dart.example`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/core/env/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `env.dart.example` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/env/env.dart.example` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `env.dart.example`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/env/env.dart.example`.
- **Когда открывать:** Баг или доработка, связанная с `env.dart.example` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/link_scalar.dart`

EN:

- **What this is:** Foundation helper (core) — Plan link scalar helper.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Plan link scalar helper
- **When to open:** When behavior tied to `link_scalar.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Plan link scalar helper
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `link_scalar.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/link_scalar.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `link_scalar.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/link_scalar.dart`.
- **Когда открывать:** Баг или доработка, связанная с `link_scalar.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/navigation/app_navigator.dart`

EN:

- **What this is:** Foundation helper (navigation) — `appRootNavigatorKey` — root navigator for desktop overlays when main window is hidden.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** `appRootNavigatorKey` — root navigator for desktop overlays when main window is hidden
- **When to open:** When behavior tied to `app_navigator.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: `appRootNavigatorKey` — root navigator for desktop overlays when main window is hidden
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `app_navigator.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/navigation/app_navigator.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `app_navigator.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/navigation/app_navigator.dart`.
- **Когда открывать:** Баг или доработка, связанная с `app_navigator.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/navigation/shell_side_navigation.dart`

EN:

- **What this is:** Foundation helper (navigation) — Desktop/web side navigation rail.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Desktop/web side navigation rail
- **When to open:** When behavior tied to `shell_side_navigation.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Desktop/web side navigation rail
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `shell_side_navigation.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/navigation/shell_side_navigation.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `shell_side_navigation.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/navigation/shell_side_navigation.dart`.
- **Когда открывать:** Баг или доработка, связанная с `shell_side_navigation.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/performance/rebuild_metrics.dart`

EN:

- **What this is:** Foundation helper (performance) — Rebuild/frame metrics (`--dart-define=PERF_DIAG` gated).
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`RebuildMetrics`).
- **Key code names:** `RebuildMetrics`
- **Responsibilities:** Rebuild/frame metrics (`--dart-define=PERF_DIAG` gated)
- **When to open:** When behavior tied to `rebuild_metrics.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Rebuild/frame metrics (`--dart-define=PERF_DIAG` gated)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `rebuild_metrics.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/performance/rebuild_metrics.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `rebuild_metrics.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/performance/rebuild_metrics.dart`.
- **Когда открывать:** Баг или доработка, связанная с `rebuild_metrics.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/performance/runtime_flags.dart`

EN:

- **What this is:** Foundation helper (performance) — Feature kill switches (date strip, warm window, etc.).
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Feature kill switches (date strip, warm window, etc.)
- **When to open:** When behavior tied to `runtime_flags.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Feature kill switches (date strip, warm window, etc.)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `runtime_flags.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/performance/runtime_flags.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `runtime_flags.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/performance/runtime_flags.dart`.
- **Когда открывать:** Баг или доработка, связанная с `runtime_flags.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/performance/shell_flags.dart`

EN:

- **What this is:** Foundation helper (performance) — Shell tab stack behavior flags.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Shell tab stack behavior flags
- **When to open:** When behavior tied to `shell_flags.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Shell tab stack behavior flags
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `shell_flags.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/performance/shell_flags.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `shell_flags.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/performance/shell_flags.dart`.
- **Когда открывать:** Баг или доработка, связанная с `shell_flags.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/picker_entry_modes.dart`

EN:

- **What this is:** Foundation helper (core) — Platform-aware picker entry (keyboard vs touch).
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Platform-aware picker entry (keyboard vs touch)
- **When to open:** When behavior tied to `picker_entry_modes.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Platform-aware picker entry (keyboard vs touch)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `picker_entry_modes.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/picker_entry_modes.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `picker_entry_modes.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/picker_entry_modes.dart`.
- **Когда открывать:** Баг или доработка, связанная с `picker_entry_modes.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/plan_category_lookup.dart`

EN:

- **What this is:** Foundation helper (core) — Category presentation lookup (shell-injected).
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`PlanCategoryPresentation`).
- **Key code names:** `PlanCategoryPresentation`
- **Responsibilities:** Category presentation lookup (shell-injected)
- **When to open:** When behavior tied to `plan_category_lookup.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Category presentation lookup (shell-injected)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `plan_category_lookup.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/plan_category_lookup.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_category_lookup.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/plan_category_lookup.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_category_lookup.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_hotkey_codec.dart`

EN:

- **What this is:** Foundation helper (services) — Desktop hotkey string encode/decode.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Desktop hotkey string encode/decode
- **When to open:** When behavior tied to `desktop_hotkey_codec.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Desktop hotkey string encode/decode
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_hotkey_codec.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_hotkey_codec.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_hotkey_codec.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_hotkey_codec.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_hotkey_codec.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_stt_diagnostics.dart`

EN:

- **What this is:** Foundation helper (services) — STT helper diagnostics markers.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`DesktopSttDiagnostics`).
- **Key code names:** `DesktopSttDiagnostics`
- **Responsibilities:** STT helper diagnostics markers
- **When to open:** When behavior tied to `desktop_stt_diagnostics.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: STT helper diagnostics markers
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_stt_diagnostics.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_stt_diagnostics.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_stt_diagnostics.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_stt_diagnostics.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_stt_diagnostics.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_stt_helper_service.dart`

EN:

- **What this is:** Foundation helper (services) — Desktop GOLOS STT helper subprocess and HTTP transcribe.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`DesktopSttHelperService`).
- **Key code names:** `DesktopSttHelperService`
- **Responsibilities:** Desktop GOLOS STT helper subprocess and HTTP transcribe
- **When to open:** When behavior tied to `desktop_stt_helper_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Desktop GOLOS STT helper subprocess and HTTP transcribe
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_stt_helper_service.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_stt_helper_service.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_stt_helper_service.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_stt_helper_service.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_stt_helper_service.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_tray_service.dart`

EN:

- **What this is:** Foundation helper (services) — System tray entry (conditional export).
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** System tray entry (conditional export)
- **When to open:** When behavior tied to `desktop_tray_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: System tray entry (conditional export)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_tray_service.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_tray_service.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_tray_service.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_tray_service.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_tray_service.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_tray_service_io.dart`

EN:

- **What this is:** Foundation helper (services) — Windows tray implementation.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`_DesktopTrayListener`).
- **Key code names:** `_DesktopTrayListener`
- **Responsibilities:** Windows tray implementation
- **When to open:** When behavior tied to `desktop_tray_service_io.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Windows tray implementation
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_tray_service_io.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_tray_service_io.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_tray_service_io.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_tray_service_io.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_tray_service_io.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_tray_service_stub.dart`

EN:

- **What this is:** Foundation helper (services) — Non-desktop tray stub.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Non-desktop tray stub
- **When to open:** When behavior tied to `desktop_tray_service_stub.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Non-desktop tray stub
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_tray_service_stub.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_tray_service_stub.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_tray_service_stub.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_tray_service_stub.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_tray_service_stub.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_acceptance_bridge.dart`

EN:

- **What this is:** Foundation helper (services) — Acceptance-test hooks for desktop voice.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Acceptance-test hooks for desktop voice
- **When to open:** When behavior tied to `desktop_voice_acceptance_bridge.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Acceptance-test hooks for desktop voice
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_acceptance_bridge.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_acceptance_bridge.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_acceptance_bridge.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_acceptance_bridge.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_acceptance_bridge.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_attempt_log.dart`

EN:

- **What this is:** Foundation helper (services) — Persisted voice attempt history for profile UI.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`DesktopVoiceAttemptStatus`, `DesktopVoiceAttempt`, `DesktopVoiceAttemptLog`).
- **Key code names:** `DesktopVoiceAttemptStatus`, `DesktopVoiceAttempt`, `DesktopVoiceAttemptLog`
- **Responsibilities:** Persisted voice attempt history for profile UI
- **When to open:** When behavior tied to `desktop_voice_attempt_log.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Persisted voice attempt history for profile UI
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_attempt_log.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_attempt_log.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_attempt_log.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_attempt_log.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_attempt_log.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_audio_capture.dart`

EN:

- **What this is:** Foundation helper (services) — Mic capture for desktop voice.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`DesktopVoiceAudioCapture`).
- **Key code names:** `DesktopVoiceAudioCapture`
- **Responsibilities:** Mic capture for desktop voice
- **When to open:** When behavior tied to `desktop_voice_audio_capture.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Mic capture for desktop voice
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_audio_capture.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_audio_capture.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_audio_capture.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_audio_capture.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_audio_capture.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_benchmark_service.dart`

EN:

- **What this is:** Foundation helper (services) — Desktop voice benchmark harness.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`DesktopVoiceBenchmarkService`).
- **Key code names:** `DesktopVoiceBenchmarkService`
- **Responsibilities:** Desktop voice benchmark harness
- **When to open:** When behavior tied to `desktop_voice_benchmark_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Desktop voice benchmark harness
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_benchmark_service.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_benchmark_service.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_benchmark_service.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_benchmark_service.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_benchmark_service.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_command_normalize.dart`

EN:

- **What this is:** Foundation helper (services) — Transcript normalization before parse/submit.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`DesktopVoiceNormalizedCommand`).
- **Key code names:** `DesktopVoiceNormalizedCommand`
- **Responsibilities:** Transcript normalization before parse/submit
- **When to open:** When behavior tied to `desktop_voice_command_normalize.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Transcript normalization before parse/submit
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_command_normalize.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_command_normalize.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_command_normalize.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_command_normalize.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_command_normalize.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_confirmation.dart`

EN:

- **What this is:** Foundation helper (services) — Start/stop voice confirmation copy.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Start/stop voice confirmation copy
- **When to open:** When behavior tied to `desktop_voice_confirmation.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Start/stop voice confirmation copy
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_confirmation.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_confirmation.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_confirmation.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_confirmation.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_confirmation.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_engine.dart`

EN:

- **What this is:** Foundation helper (services) — Desktop voice engine lifecycle.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`DesktopVoiceEngineId`, `DesktopVoiceEngineBenchmark`).
- **Key code names:** `DesktopVoiceEngineId`, `DesktopVoiceEngineBenchmark`
- **Responsibilities:** Desktop voice engine lifecycle
- **When to open:** When behavior tied to `desktop_voice_engine.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Desktop voice engine lifecycle
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_engine.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_engine.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_engine.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_engine.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_engine.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_hotkey.dart`

EN:

- **What this is:** Foundation helper (services) — Global desktop voice hotkey coordinator.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`DesktopVoiceHotkeyAction`).
- **Key code names:** `DesktopVoiceHotkeyAction`
- **Responsibilities:** Global desktop voice hotkey coordinator
- **When to open:** When behavior tied to `desktop_voice_hotkey.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Global desktop voice hotkey coordinator
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_hotkey.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_hotkey.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_hotkey.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_hotkey.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_hotkey.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_hotkey_io.dart`

EN:

- **What this is:** Foundation helper (services) — Windows hotkey registration.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Windows hotkey registration
- **When to open:** When behavior tied to `desktop_voice_hotkey_io.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Windows hotkey registration
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_hotkey_io.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_hotkey_io.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_hotkey_io.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_hotkey_io.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_hotkey_io.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_hotkey_markers.dart`

EN:

- **What this is:** Foundation helper (services) — Hotkey self-test / acceptance markers.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Hotkey self-test / acceptance markers
- **When to open:** When behavior tied to `desktop_voice_hotkey_markers.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Hotkey self-test / acceptance markers
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_hotkey_markers.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_hotkey_markers.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_hotkey_markers.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_hotkey_markers.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_hotkey_markers.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_hotkey_stub.dart`

EN:

- **What this is:** Foundation helper (services) — Non-desktop hotkey stub.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Non-desktop hotkey stub
- **When to open:** When behavior tied to `desktop_voice_hotkey_stub.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Non-desktop hotkey stub
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_hotkey_stub.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_hotkey_stub.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_hotkey_stub.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_hotkey_stub.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_hotkey_stub.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_native_overlay.dart`

EN:

- **What this is:** Foundation helper (services) — Native overlay channel bridge.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Native overlay channel bridge
- **When to open:** When behavior tied to `desktop_voice_native_overlay.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Native overlay channel bridge
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_native_overlay.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_native_overlay.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_native_overlay.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_native_overlay.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_native_overlay.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_overlay_bridge.dart`

EN:

- **What this is:** Foundation helper (services) — Overlay ↔ Flutter bridge.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Overlay ↔ Flutter bridge
- **When to open:** When behavior tied to `desktop_voice_overlay_bridge.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Overlay ↔ Flutter bridge
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_overlay_bridge.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_overlay_bridge.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_overlay_bridge.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_overlay_bridge.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_overlay_bridge.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_overlay_host.dart`

EN:

- **What this is:** Foundation helper (services) — Overlay host conditional export.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Overlay host conditional export
- **When to open:** When behavior tied to `desktop_voice_overlay_host.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Overlay host conditional export
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_overlay_host.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_overlay_host.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_overlay_host.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_overlay_host.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_overlay_host.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_overlay_host_io.dart`

EN:

- **What this is:** Foundation helper (services) — Windows overlay host.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Windows overlay host
- **When to open:** When behavior tied to `desktop_voice_overlay_host_io.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Windows overlay host
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_overlay_host_io.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_overlay_host_io.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_overlay_host_io.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_overlay_host_io.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_overlay_host_io.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_overlay_host_stub.dart`

EN:

- **What this is:** Foundation helper (services) — Non-desktop overlay host stub.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Non-desktop overlay host stub
- **When to open:** When behavior tied to `desktop_voice_overlay_host_stub.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Non-desktop overlay host stub
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_overlay_host_stub.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_overlay_host_stub.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_overlay_host_stub.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_overlay_host_stub.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_overlay_host_stub.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_overlay_service.dart`

EN:

- **What this is:** Foundation helper (services) — Native overlay state machine.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Native overlay state machine
- **When to open:** When behavior tied to `desktop_voice_overlay_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Native overlay state machine
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_overlay_service.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_overlay_service.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_overlay_service.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_overlay_service.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_overlay_service.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_recognizer.dart`

EN:

- **What this is:** Foundation helper (services) — Desktop voice recognizer interface.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`DesktopVoiceRecognitionResult`).
- **Key code names:** `DesktopVoiceRecognitionResult`
- **Responsibilities:** Desktop voice recognizer interface
- **When to open:** When behavior tied to `desktop_voice_recognizer.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Desktop voice recognizer interface
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_recognizer.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_recognizer.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_recognizer.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_recognizer.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_recognizer.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_recognizer_factory.dart`

EN:

- **What this is:** Foundation helper (services) — Platform recognizer factory.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Platform recognizer factory
- **When to open:** When behavior tied to `desktop_voice_recognizer_factory.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Platform recognizer factory
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_recognizer_factory.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_recognizer_factory.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_recognizer_factory.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_recognizer_factory.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_recognizer_factory.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_recognizer_io.dart`

EN:

- **What this is:** Foundation helper (services) — Windows recognizer implementation.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`DesktopVoiceRecognizerGolosHelper`).
- **Key code names:** `DesktopVoiceRecognizerGolosHelper`
- **Responsibilities:** Windows recognizer implementation
- **When to open:** When behavior tied to `desktop_voice_recognizer_io.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Windows recognizer implementation
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_recognizer_io.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_recognizer_io.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_recognizer_io.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_recognizer_io.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_recognizer_io.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_recognizer_stub.dart`

EN:

- **What this is:** Foundation helper (services) — Non-desktop recognizer stub.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`_DesktopVoiceRecognizerUnsupported`).
- **Key code names:** `_DesktopVoiceRecognizerUnsupported`
- **Responsibilities:** Non-desktop recognizer stub
- **When to open:** When behavior tied to `desktop_voice_recognizer_stub.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Non-desktop recognizer stub
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_recognizer_stub.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_recognizer_stub.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_recognizer_stub.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_recognizer_stub.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_recognizer_stub.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_record_submit.dart`

EN:

- **What this is:** Foundation helper (services) — Parsed voice command → `writeRecord` bridge.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`DesktopVoiceWriteRecordRequest`, `DesktopVoiceWriteRecordFn`, `DesktopVoiceSubmitOutcome`).
- **Key code names:** `DesktopVoiceWriteRecordRequest`, `DesktopVoiceWriteRecordFn`, `DesktopVoiceSubmitOutcome`
- **Responsibilities:** Parsed voice command → `writeRecord` bridge
- **When to open:** When behavior tied to `desktop_voice_record_submit.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Parsed voice command → `writeRecord` bridge
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_record_submit.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_record_submit.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_record_submit.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_record_submit.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_record_submit.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_settings.dart`

EN:

- **What this is:** Foundation helper (services) — Local desktop voice prefs (SharedPreferences).
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`DesktopVoiceHotkeyConfig`, `DesktopVoiceSettings`).
- **Key code names:** `DesktopVoiceHotkeyConfig`, `DesktopVoiceSettings`
- **Responsibilities:** Local desktop voice prefs (SharedPreferences)
- **When to open:** When behavior tied to `desktop_voice_settings.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Local desktop voice prefs (SharedPreferences)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_settings.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_settings.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_settings.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_settings.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_settings.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_smoke_bridge.dart`

EN:

- **What this is:** Foundation helper (services) — Smoke-test hooks for desktop voice.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Smoke-test hooks for desktop voice
- **When to open:** When behavior tied to `desktop_voice_smoke_bridge.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Smoke-test hooks for desktop voice
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_smoke_bridge.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_smoke_bridge.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_smoke_bridge.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_smoke_bridge.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_smoke_bridge.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_user_error.dart`

EN:

- **What this is:** Foundation helper (services) — Friendly desktop voice error mapping.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`DesktopVoiceErrorStage`, `DesktopVoiceUserError`).
- **Key code names:** `DesktopVoiceErrorStage`, `DesktopVoiceUserError`
- **Responsibilities:** Friendly desktop voice error mapping
- **When to open:** When behavior tied to `desktop_voice_user_error.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Friendly desktop voice error mapping
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_user_error.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_user_error.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_user_error.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_user_error.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_user_error.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_voice_window_flags.dart`

EN:

- **What this is:** Foundation helper (services) — Desktop window visibility flags.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Desktop window visibility flags
- **When to open:** When behavior tied to `desktop_voice_window_flags.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Desktop window visibility flags
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_voice_window_flags.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_voice_window_flags.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_window_flags.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_voice_window_flags.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_window_flags.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/desktop_win_speech_service.dart`

EN:

- **What this is:** Foundation helper (services) — Windows speech platform adapter.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`DesktopWinSpeechService`).
- **Key code names:** `DesktopWinSpeechService`
- **Responsibilities:** Windows speech platform adapter
- **When to open:** When behavior tied to `desktop_win_speech_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Windows speech platform adapter
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `desktop_win_speech_service.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/desktop_win_speech_service.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_win_speech_service.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/desktop_win_speech_service.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_win_speech_service.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/pcm_audio_utils.dart`

EN:

- **What this is:** Foundation helper (services) — PCM/WAV audio helpers for desktop STT.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** PCM/WAV audio helpers for desktop STT
- **When to open:** When behavior tied to `pcm_audio_utils.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: PCM/WAV audio helpers for desktop STT
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `pcm_audio_utils.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/pcm_audio_utils.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `pcm_audio_utils.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/pcm_audio_utils.dart`.
- **Когда открывать:** Баг или доработка, связанная с `pcm_audio_utils.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/speech_engine_handle.dart`

EN:

- **What this is:** Foundation helper (services) — Speech-to-text engine lifecycle.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Speech-to-text engine lifecycle
- **When to open:** When behavior tied to `speech_engine_handle.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Speech-to-text engine lifecycle
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `speech_engine_handle.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/speech_engine_handle.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `speech_engine_handle.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/speech_engine_handle.dart`.
- **Когда открывать:** Баг или доработка, связанная с `speech_engine_handle.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/services/speech_listen_locale.dart`

EN:

- **What this is:** Foundation helper (services) — STT locale resolution.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** STT locale resolution
- **When to open:** When behavior tied to `speech_listen_locale.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: STT locale resolution
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `speech_listen_locale.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/services/speech_listen_locale.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `speech_listen_locale.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/services/speech_listen_locale.dart`.
- **Когда открывать:** Баг или доработка, связанная с `speech_listen_locale.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/shell_adaptive.dart`

EN:

- **What this is:** Foundation helper (core) — Side vs bottom navigation breakpoint.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Side vs bottom navigation breakpoint
- **When to open:** When behavior tied to `shell_adaptive.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Side vs bottom navigation breakpoint
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `shell_adaptive.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/shell_adaptive.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `shell_adaptive.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/shell_adaptive.dart`.
- **Когда открывать:** Баг или доработка, связанная с `shell_adaptive.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/shell_layout_state.dart`

EN:

- **What this is:** Foundation helper (core) — `ShellLayoutController` / FAB clearance.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`ShellLayoutController`, `ShellLayoutScope`).
- **Key code names:** `ShellLayoutController`, `ShellLayoutScope`
- **Responsibilities:** `ShellLayoutController` / FAB clearance
- **When to open:** When behavior tied to `shell_layout_state.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: `ShellLayoutController` / FAB clearance
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `shell_layout_state.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/shell_layout_state.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `shell_layout_state.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/shell_layout_state.dart`.
- **Когда открывать:** Баг или доработка, связанная с `shell_layout_state.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/tag_contrast.dart`

EN:

- **What this is:** Foundation helper (core) — Tag foreground/background contrast.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Tag foreground/background contrast
- **When to open:** When behavior tied to `tag_contrast.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Tag foreground/background contrast
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `tag_contrast.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/tag_contrast.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `tag_contrast.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/tag_contrast.dart`.
- **Когда открывать:** Баг или доработка, связанная с `tag_contrast.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/theme.dart`

EN:

- **What this is:** Foundation helper (core) — `ThemeData`, density, input decoration.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** `ThemeData`, density, input decoration
- **When to open:** When behavior tied to `theme.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: `ThemeData`, density, input decoration
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `theme.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/theme.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `theme.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/theme.dart`.
- **Когда открывать:** Баг или доработка, связанная с `theme.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/time/app_clock.dart`

EN:

- **What this is:** Foundation helper (time) — Injectable wall clock + timezone label.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`WallNowFn`, `AppClock`).
- **Key code names:** `WallNowFn`, `AppClock`
- **Responsibilities:** Injectable wall clock + timezone label
- **When to open:** When behavior tied to `app_clock.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Injectable wall clock + timezone label
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `app_clock.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/time/app_clock.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `app_clock.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/time/app_clock.dart`.
- **Когда открывать:** Баг или доработка, связанная с `app_clock.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/time/category_timezone_options.dart`

EN:

- **What this is:** Foundation helper (time) — Per-category timezone option list.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`CategoryDefaultTimezoneOption`).
- **Key code names:** `CategoryDefaultTimezoneOption`
- **Responsibilities:** Per-category timezone option list
- **When to open:** When behavior tied to `category_timezone_options.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Per-category timezone option list
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `category_timezone_options.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/time/category_timezone_options.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `category_timezone_options.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/time/category_timezone_options.dart`.
- **Когда открывать:** Баг или доработка, связанная с `category_timezone_options.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/time/plan_time_labels.dart`

EN:

- **What this is:** Foundation helper (time) — Plan time label formatting.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Plan time label formatting
- **When to open:** When behavior tied to `plan_time_labels.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Plan time label formatting
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `plan_time_labels.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/time/plan_time_labels.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_time_labels.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/time/plan_time_labels.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_time_labels.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/time/plan_time_visible_window.dart`

EN:

- **What this is:** Foundation helper (time) — Extended Time View day window math (−3..27 h).
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Extended Time View day window math (−3..27 h)
- **When to open:** When behavior tied to `plan_time_visible_window.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Extended Time View day window math (−3..27 h)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `plan_time_visible_window.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/time/plan_time_visible_window.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_time_visible_window.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/time/plan_time_visible_window.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_time_visible_window.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/time/profile_timezone_actions.dart`

EN:

- **What this is:** Foundation helper (time) — Injectable profile timezone read/write hooks (`ProfileTimezoneActions`).
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`ProfileTimezoneShortLabelFn`, `SaveProfileTimezoneFn`, `CurrentUserSettingsFn`, `ProfileTimezoneActions`).
- **Key code names:** `ProfileTimezoneShortLabelFn`, `SaveProfileTimezoneFn`, `CurrentUserSettingsFn`, `ProfileTimezoneActions`
- **Responsibilities:** Injectable profile timezone read/write hooks (`ProfileTimezoneActions`)
- **When to open:** When behavior tied to `profile_timezone_actions.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Injectable profile timezone read/write hooks (`ProfileTimezoneActions`)
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `profile_timezone_actions.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/time/profile_timezone_actions.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `profile_timezone_actions.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/time/profile_timezone_actions.dart`.
- **Когда открывать:** Баг или доработка, связанная с `profile_timezone_actions.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/time/profile_timezone_catalog.dart`

EN:

- **What this is:** Foundation helper (time) — Canonical profile timezone catalog, IANA IDs, DST labels.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (`ProfileTimezoneCatalogEntry`).
- **Key code names:** `ProfileTimezoneCatalogEntry`
- **Responsibilities:** Canonical profile timezone catalog, IANA IDs, DST labels
- **When to open:** When behavior tied to `profile_timezone_catalog.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Canonical profile timezone catalog, IANA IDs, DST labels
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `profile_timezone_catalog.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/time/profile_timezone_catalog.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `profile_timezone_catalog.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/time/profile_timezone_catalog.dart`.
- **Когда открывать:** Баг или доработка, связанная с `profile_timezone_catalog.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/time/wall_clock.dart`

EN:

- **What this is:** Foundation helper (time) — Wall-clock formatting helpers.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Wall-clock formatting helpers
- **When to open:** When behavior tied to `wall_clock.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Wall-clock formatting helpers
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `wall_clock.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/time/wall_clock.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `wall_clock.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/time/wall_clock.dart`.
- **Когда открывать:** Баг или доработка, связанная с `wall_clock.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/url_strategy_stub.dart`

EN:

- **What this is:** Foundation helper (core) — Web URL strategy conditional import.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Web URL strategy conditional import
- **When to open:** When behavior tied to `url_strategy_stub.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Web URL strategy conditional import
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `url_strategy_stub.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/url_strategy_stub.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `url_strategy_stub.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/url_strategy_stub.dart`.
- **Когда открывать:** Баг или доработка, связанная с `url_strategy_stub.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/web_redirect.dart`

EN:

- **What this is:** Foundation helper (core) — Production web OAuth redirect URI helper.
- **Why needed:** Shared non-screen code: theme, time, voice, diagnostics — not tied to one tab.
- **What it contains:** Dart utilities (implementation details in the source file).
- **Responsibilities:** Production web OAuth redirect URI helper
- **When to open:** When behavior tied to `web_redirect.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Production web OAuth redirect URI helper
- **Layer / owner:** Foundation code — theme, time, voice services, diagnostics (not a full screen).

RU:

- **Что это:** Dart-файл `web_redirect.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/web_redirect.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `web_redirect.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/web_redirect.dart`.
- **Когда открывать:** Баг или доработка, связанная с `web_redirect.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/app_bar_live_clock.dart`

EN:

- **What this is:** Shared design-system widget — Live clock chip.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppBarLiveClock`, `_AppBarLiveClockState`).
- **Key code names:** `AppBarLiveClock`, `_AppBarLiveClockState`
- **Responsibilities:** Live clock chip
- **When to open:** When behavior tied to `app_bar_live_clock.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Live clock chip
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `app_bar_live_clock.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/app_bar_live_clock.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `app_bar_live_clock.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/app_bar_live_clock.dart`.
- **Когда открывать:** Баг или доработка, связанная с `app_bar_live_clock.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/app_button.dart`

EN:

- **What this is:** Shared design-system widget — `AppButton`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppButtonVariant`, `AppButtonSize`, `AppButton`).
- **Key code names:** `AppButtonVariant`, `AppButtonSize`, `AppButton`
- **Responsibilities:** `AppButton`
- **When to open:** When behavior tied to `app_button.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: `AppButton`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `app_button.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/app_button.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `app_button.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/app_button.dart`.
- **Когда открывать:** Баг или доработка, связанная с `app_button.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/app_icon_button.dart`

EN:

- **What this is:** Shared design-system widget — `AppIconButton`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppIconButtonVariant`, `AppIconButtonSize`, `AppIconButton`).
- **Key code names:** `AppIconButtonVariant`, `AppIconButtonSize`, `AppIconButton`
- **Responsibilities:** `AppIconButton`
- **When to open:** When behavior tied to `app_icon_button.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: `AppIconButton`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `app_icon_button.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/app_icon_button.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `app_icon_button.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/app_icon_button.dart`.
- **Когда открывать:** Баг или доработка, связанная с `app_icon_button.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/app_loading.dart`

EN:

- **What this is:** Shared design-system widget — `AppLoading`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppLoadingSize`, `AppLoading`).
- **Key code names:** `AppLoadingSize`, `AppLoading`
- **Responsibilities:** `AppLoading`
- **When to open:** When behavior tied to `app_loading.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: `AppLoading`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `app_loading.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/app_loading.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `app_loading.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/app_loading.dart`.
- **Когда открывать:** Баг или доработка, связанная с `app_loading.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/app_mic_level_bars.dart`

EN:

- **What this is:** Shared design-system widget — Mic level visualization bars for voice UI.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppMicLevelBars`).
- **Key code names:** `AppMicLevelBars`
- **Responsibilities:** Mic level visualization bars for voice UI
- **When to open:** When behavior tied to `app_mic_level_bars.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Mic level visualization bars for voice UI
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `app_mic_level_bars.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/app_mic_level_bars.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `app_mic_level_bars.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/app_mic_level_bars.dart`.
- **Когда открывать:** Баг или доработка, связанная с `app_mic_level_bars.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/app_settings_layout.dart`

EN:

- **What this is:** Shared design-system widget — `AppSettingsPageBody`, `AppSettingsSectionCard`, settings row helpers.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppSettingsTab`, `AppSettingsCategoryTabs`, `AppHotkeyKeycaps`, `_Keycap`).
- **Key code names:** `AppSettingsTab`, `AppSettingsCategoryTabs`, `AppHotkeyKeycaps`, `_Keycap`
- **Responsibilities:** `AppSettingsPageBody`, `AppSettingsSectionCard`, settings row helpers
- **When to open:** When behavior tied to `app_settings_layout.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: `AppSettingsPageBody`, `AppSettingsSectionCard`, settings row helpers
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `app_settings_layout.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/app_settings_layout.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `app_settings_layout.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/app_settings_layout.dart`.
- **Когда открывать:** Баг или доработка, связанная с `app_settings_layout.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/app_state_views.dart`

EN:

- **What this is:** Shared design-system widget — `AppErrorState`, `AppEmptyState`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppErrorState`, `AppEmptyState`).
- **Key code names:** `AppErrorState`, `AppEmptyState`
- **Responsibilities:** `AppErrorState`, `AppEmptyState`
- **When to open:** When behavior tied to `app_state_views.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: `AppErrorState`, `AppEmptyState`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `app_state_views.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/app_state_views.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `app_state_views.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/app_state_views.dart`.
- **Когда открывать:** Баг или доработка, связанная с `app_state_views.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/app_timezone_icon.dart`

EN:

- **What this is:** Shared design-system widget — Canonical solid timezone icon family.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppTimezoneIcon`, `_AppTimezoneIconPainter`).
- **Key code names:** `AppTimezoneIcon`, `_AppTimezoneIconPainter`
- **Responsibilities:** Canonical solid timezone icon family
- **When to open:** When behavior tied to `app_timezone_icon.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Canonical solid timezone icon family
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `app_timezone_icon.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/app_timezone_icon.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `app_timezone_icon.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/app_timezone_icon.dart`.
- **Когда открывать:** Баг или доработка, связанная с `app_timezone_icon.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/chip_component.dart`

EN:

- **What this is:** Shared design-system widget — `TagChip`, `CategoryChip`, tag quick-pick strip.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`CategoryBreadcrumb`, `CategoryChipVariant`, `CategoryChip`).
- **Key code names:** `CategoryBreadcrumb`, `CategoryChipVariant`, `CategoryChip`
- **Responsibilities:** `TagChip`, `CategoryChip`, tag quick-pick strip
- **When to open:** When behavior tied to `chip_component.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: `TagChip`, `CategoryChip`, tag quick-pick strip
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `chip_component.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/chip_component.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `chip_component.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/chip_component.dart`.
- **Когда открывать:** Баг или доработка, связанная с `chip_component.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/compact_nav_controls.dart`

EN:

- **What this is:** Shared design-system widget — Compact segmented controls.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`AppCompactSegmentLabel`, `AppCompactTextTab`).
- **Key code names:** `AppCompactSegmentLabel`, `AppCompactTextTab`
- **Responsibilities:** Compact segmented controls
- **When to open:** When behavior tied to `compact_nav_controls.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Compact segmented controls
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `compact_nav_controls.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/compact_nav_controls.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `compact_nav_controls.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/compact_nav_controls.dart`.
- **Когда открывать:** Баг или доработка, связанная с `compact_nav_controls.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/confirm_dialog.dart`

EN:

- **What this is:** Shared design-system widget — `showConfirmDialog`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (implementation details in the source file).
- **Responsibilities:** `showConfirmDialog`
- **When to open:** When behavior tied to `confirm_dialog.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: `showConfirmDialog`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `confirm_dialog.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/confirm_dialog.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `confirm_dialog.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/confirm_dialog.dart`.
- **Когда открывать:** Баг или доработка, связанная с `confirm_dialog.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/day_content_strip.dart`

EN:

- **What this is:** Shared design-system widget — Day content pager strip.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`EagerDayItemBuilder`, `EagerDayContentStripController`, `EagerDayContentStrip`, `_EagerDayContentStripState`).
- **Key code names:** `EagerDayItemBuilder`, `EagerDayContentStripController`, `EagerDayContentStrip`, `_EagerDayContentStripState`
- **Responsibilities:** Day content pager strip
- **When to open:** When behavior tied to `day_content_strip.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Day content pager strip
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `day_content_strip.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/day_content_strip.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `day_content_strip.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/day_content_strip.dart`.
- **Когда открывать:** Баг или доработка, связанная с `day_content_strip.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/day_window.dart`

EN:

- **What this is:** Shared design-system widget — Mounted day window.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (implementation details in the source file).
- **Responsibilities:** Mounted day window
- **When to open:** When behavior tied to `day_window.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Mounted day window
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `day_window.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/day_window.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `day_window.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/day_window.dart`.
- **Когда открывать:** Баг или доработка, связанная с `day_window.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/global_app_header.dart`

EN:

- **What this is:** Shared design-system widget — Date/time header strip.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`GlobalAppHeader`).
- **Key code names:** `GlobalAppHeader`
- **Responsibilities:** Date/time header strip
- **When to open:** When behavior tied to `global_app_header.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Date/time header strip
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `global_app_header.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/global_app_header.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `global_app_header.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/global_app_header.dart`.
- **Когда открывать:** Баг или доработка, связанная с `global_app_header.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/lazy_indexed_stack.dart`

EN:

- **What this is:** Shared design-system widget — Optional lazy shell tab stack.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`LazyIndexedStack`, `_LazyIndexedStackState`).
- **Key code names:** `LazyIndexedStack`, `_LazyIndexedStackState`
- **Responsibilities:** Optional lazy shell tab stack
- **When to open:** When behavior tied to `lazy_indexed_stack.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Optional lazy shell tab stack
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `lazy_indexed_stack.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/lazy_indexed_stack.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `lazy_indexed_stack.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/lazy_indexed_stack.dart`.
- **Когда открывать:** Баг или доработка, связанная с `lazy_indexed_stack.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/life_card.dart`

EN:

- **What this is:** Shared design-system widget — Card foundation for Component Lab.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`LifeCardState`, `LifeCardDensity`, `AppTaskCardType`, `LifeCard`).
- **Key code names:** `LifeCardState`, `LifeCardDensity`, `AppTaskCardType`, `LifeCard`, `AppTaskCard`
- **Responsibilities:** Card foundation for Component Lab
- **When to open:** When behavior tied to `life_card.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Card foundation for Component Lab
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `life_card.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/life_card.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `life_card.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/life_card.dart`.
- **Когда открывать:** Баг или доработка, связанная с `life_card.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/mouse_drag_scroll_behavior.dart`

EN:

- **What this is:** Shared design-system widget — Desktop/web drag scroll.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`MouseDragScrollBehavior`).
- **Key code names:** `MouseDragScrollBehavior`
- **Responsibilities:** Desktop/web drag scroll
- **When to open:** When behavior tied to `mouse_drag_scroll_behavior.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Desktop/web drag scroll
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `mouse_drag_scroll_behavior.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/mouse_drag_scroll_behavior.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `mouse_drag_scroll_behavior.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/mouse_drag_scroll_behavior.dart`.
- **Когда открывать:** Баг или доработка, связанная с `mouse_drag_scroll_behavior.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/omni_date_time_picker_dialog.dart`

EN:

- **What this is:** Shared design-system widget — Unified date+time picker.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`_OmniDateTimePickerDialog`, `_OmniDateTimePickerDialogState`).
- **Key code names:** `_OmniDateTimePickerDialog`, `_OmniDateTimePickerDialogState`
- **Responsibilities:** Unified date+time picker
- **When to open:** When behavior tied to `omni_date_time_picker_dialog.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Unified date+time picker
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `omni_date_time_picker_dialog.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/omni_date_time_picker_dialog.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `omni_date_time_picker_dialog.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/omni_date_time_picker_dialog.dart`.
- **Когда открывать:** Баг или доработка, связанная с `omni_date_time_picker_dialog.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/plan_card.dart`

EN:

- **What this is:** Shared design-system widget — `PlanCard` wrapper.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`PlanCard`).
- **Key code names:** `PlanCard`
- **Responsibilities:** `PlanCard` wrapper
- **When to open:** When behavior tied to `plan_card.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: `PlanCard` wrapper
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `plan_card.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/plan_card.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_card.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/plan_card.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_card.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/plan_card/plan_card_controls.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_controls.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (implementation details in the source file).
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_controls.dart`
- **When to open:** When behavior tied to `plan_card_controls.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Re-export stub → `plan_time_task_card/plan_card_controls.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `plan_card_controls.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/plan_card/plan_card_controls.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_card_controls.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/plan_card/plan_card_controls.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_card_controls.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/plan_card/plan_card_geometry.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_geometry.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (implementation details in the source file).
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_geometry.dart`
- **When to open:** When behavior tied to `plan_card_geometry.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Re-export stub → `plan_time_task_card/plan_card_geometry.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `plan_card_geometry.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/plan_card/plan_card_geometry.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_card_geometry.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/plan_card/plan_card_geometry.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_card_geometry.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/plan_card/plan_card_metrics.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_metrics.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (implementation details in the source file).
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_metrics.dart`
- **When to open:** When behavior tied to `plan_card_metrics.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Re-export stub → `plan_time_task_card/plan_card_metrics.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `plan_card_metrics.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/plan_card/plan_card_metrics.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_card_metrics.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/plan_card/plan_card_metrics.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_card_metrics.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/plan_card/plan_card_sections.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_sections.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (implementation details in the source file).
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_sections.dart`
- **When to open:** When behavior tied to `plan_card_sections.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Re-export stub → `plan_time_task_card/plan_card_sections.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `plan_card_sections.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/plan_card/plan_card_sections.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_card_sections.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/plan_card/plan_card_sections.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_card_sections.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/plan_card/plan_time_card_density.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_density.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (implementation details in the source file).
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_density.dart`
- **When to open:** When behavior tied to `plan_time_card_density.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Re-export stub → `plan_time_task_card/plan_card_density.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `plan_time_card_density.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/plan_card/plan_time_card_density.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_time_card_density.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/plan_card/plan_time_card_density.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_time_card_density.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/plan_time_task_card.dart`

EN:

- **What this is:** Shared design-system widget — Public `PlanTimeTaskCard` widget.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (implementation details in the source file).
- **Responsibilities:** Public `PlanTimeTaskCard` widget
- **When to open:** When behavior tied to `plan_time_task_card.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Public `PlanTimeTaskCard` widget
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `plan_time_task_card.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/plan_time_task_card.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_time_task_card.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/plan_time_task_card.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_time_task_card.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/plan_time_task_card/plan_card_controls.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_controls.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`PlanCardCheckbox`, `PlanCardCheckboxState`, `PlanCardPlayButton`, `PlanCardPlayButtonState`).
- **Key code names:** `PlanCardCheckbox`, `PlanCardCheckboxState`, `PlanCardPlayButton`, `PlanCardPlayButtonState`, `PlanCardPlayIconPainter`
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_controls.dart`
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Re-export stub → `plan_time_task_card/plan_card_controls.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `plan_card_controls.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/plan_time_task_card/plan_card_controls.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_card_controls.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/plan_time_task_card/plan_card_controls.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_card_controls.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/plan_time_task_card/plan_card_density.dart`

EN:

- **What this is:** Shared design-system widget — Density bands + measure helpers.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`PlanTimeCardVisualDensity`).
- **Key code names:** `PlanTimeCardVisualDensity`
- **Responsibilities:** Density bands + measure helpers
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Density bands + measure helpers
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `plan_card_density.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/plan_time_task_card/plan_card_density.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_card_density.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/plan_time_task_card/plan_card_density.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_card_density.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/plan_time_task_card/plan_card_geometry.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_geometry.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (implementation details in the source file).
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_geometry.dart`
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Re-export stub → `plan_time_task_card/plan_card_geometry.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `plan_card_geometry.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/plan_time_task_card/plan_card_geometry.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_card_geometry.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/plan_time_task_card/plan_card_geometry.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_card_geometry.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/plan_time_task_card/plan_card_layouts.dart`

EN:

- **What this is:** Shared design-system widget — Time View CardPlan layout variants.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`TimeViewDensityBody`, `TimeViewCardCommon`, `TimeViewLeftControls`).
- **Key code names:** `TimeViewDensityBody`, `TimeViewCardCommon`, `TimeViewLeftControls`
- **Responsibilities:** Time View CardPlan layout variants
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Time View CardPlan layout variants
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `plan_card_layouts.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/plan_time_task_card/plan_card_layouts.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_card_layouts.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/plan_time_task_card/plan_card_layouts.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_card_layouts.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/plan_time_task_card/plan_card_metrics.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_metrics.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`PlanTimeTaskCardDensity`, `PlanCardSurface`).
- **Key code names:** `PlanTimeTaskCardDensity`, `PlanCardSurface`
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_metrics.dart`
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Re-export stub → `plan_time_task_card/plan_card_metrics.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `plan_card_metrics.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/plan_time_task_card/plan_card_metrics.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_card_metrics.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/plan_time_task_card/plan_card_metrics.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_card_metrics.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/plan_time_task_card/plan_card_progress.dart`

EN:

- **What this is:** Shared design-system widget — Progress/invariant card shells.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`PlanCardProgressSlot`, `PlanCardInvariantBody`).
- **Key code names:** `PlanCardProgressSlot`, `PlanCardInvariantBody`
- **Responsibilities:** Progress/invariant card shells
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Progress/invariant card shells
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `plan_card_progress.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/plan_time_task_card/plan_card_progress.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_card_progress.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/plan_time_task_card/plan_card_progress.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_card_progress.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/plan_time_task_card/plan_card_sections.dart`

EN:

- **What this is:** Shared design-system widget — Re-export stub → `plan_time_task_card/plan_card_sections.dart`.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`PlanCardTagsRow`, `PlanCardTimeText`, `PlanCardFooterRow`, `PlanCardWatermark`).
- **Key code names:** `PlanCardTagsRow`, `PlanCardTimeText`, `PlanCardFooterRow`, `PlanCardWatermark`
- **Responsibilities:** Re-export stub → `plan_time_task_card/plan_card_sections.dart`
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Re-export stub → `plan_time_task_card/plan_card_sections.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `plan_card_sections.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/plan_time_task_card/plan_card_sections.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_card_sections.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/plan_time_task_card/plan_card_sections.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_card_sections.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/plan_time_task_card/plan_card_tags.dart`

EN:

- **What this is:** Shared design-system widget — Time View tag row/stack/pill widgets.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`TimeViewTagsRow`, `TimeViewTagStack`, `TimeViewCompactTagPill`).
- **Key code names:** `TimeViewTagsRow`, `TimeViewTagStack`, `TimeViewCompactTagPill`
- **Responsibilities:** Time View tag row/stack/pill widgets
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Time View tag row/stack/pill widgets
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `plan_card_tags.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/plan_time_task_card/plan_card_tags.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_card_tags.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/plan_time_task_card/plan_card_tags.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_card_tags.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/plan_time_task_card/plan_time_task_card.dart`

EN:

- **What this is:** Shared design-system widget — Public `PlanTimeTaskCard` widget.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`PlanTimeTaskCard`, `_PlanTimeTaskCardState`).
- **Key code names:** `PlanTimeTaskCard`, `_PlanTimeTaskCardState`
- **Responsibilities:** Public `PlanTimeTaskCard` widget
- **When to open:** Plan card look/feel: height, tags, play button, Time View density.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Public `PlanTimeTaskCard` widget
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `plan_time_task_card.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/plan_time_task_card/plan_time_task_card.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_time_task_card.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/plan_time_task_card/plan_time_task_card.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_time_task_card.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/tag_display_mode_scope.dart`

EN:

- **What this is:** Shared design-system widget — Tag display mode inherited widget.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`TagDisplayModeScope`).
- **Key code names:** `TagDisplayModeScope`
- **Responsibilities:** Tag display mode inherited widget
- **When to open:** When behavior tied to `tag_display_mode_scope.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Tag display mode inherited widget
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `tag_display_mode_scope.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/tag_display_mode_scope.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `tag_display_mode_scope.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/tag_display_mode_scope.dart`.
- **Когда открывать:** Баг или доработка, связанная с `tag_display_mode_scope.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/core/widgets/timezone_quick_picker.dart`

EN:

- **What this is:** Shared design-system widget — `HeaderTimezoneQuickSwitcher`, profile timezone quick picker.
- **Why needed:** Plans, Timeline, and Lists reuse this instead of copying button/card styles.
- **What it contains:** Canonical Flutter widget (`HeaderTimezoneQuickSwitcher`, `TimezonePickerField`).
- **Key code names:** `HeaderTimezoneQuickSwitcher`, `TimezonePickerField`
- **Responsibilities:** `HeaderTimezoneQuickSwitcher`, profile timezone quick picker
- **When to open:** When behavior tied to `timezone_quick_picker.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: `HeaderTimezoneQuickSwitcher`, profile timezone quick picker
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Dart-файл `timezone_quick_picker.dart` — Foundation (базовый слой): общие widgets, theme, time helpers, voice.
- **Зачем:** Модуль `lib/core/widgets/timezone_quick_picker.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `timezone_quick_picker.dart`.
- **Обязанности:** Реализует общие widgets, theme, time helpers, voice для пути `lib/core/widgets/timezone_quick_picker.dart`.
- **Когда открывать:** Баг или доработка, связанная с `timezone_quick_picker.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Foundation (базовый слой) — не platform wrapper.


### `lib/data/auth_bridge.dart`

EN:

- **What this is:** Brain support file — Session check, OAuth routing.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`OAuthSignInResult`, `PasswordResetRequestResult`, `AuthBridgeException`, `AuthBridgeCancelled`).
- **Key code names:** `OAuthSignInResult`, `PasswordResetRequestResult`, `AuthBridgeException`, `AuthBridgeCancelled`, `AuthBridge`
- **Responsibilities:** Session check, OAuth routing
- **When to open:** When behavior tied to `auth_bridge.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Session check, OAuth routing
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `auth_bridge.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/auth_bridge.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `auth_bridge.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/auth_bridge.dart`.
- **Когда открывать:** Баг или доработка, связанная с `auth_bridge.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/cache/day_snapshot_window.dart`

EN:

- **What this is:** Brain support file — Rolling warm day snapshots for date paging.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`TimelineDaySnapshot`, `PlansDaySnapshot`, `WarmSnapshotWindow`).
- **Key code names:** `TimelineDaySnapshot`, `PlansDaySnapshot`, `WarmSnapshotWindow`
- **Responsibilities:** Rolling warm day snapshots for date paging
- **When to open:** When behavior tied to `day_snapshot_window.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Rolling warm day snapshots for date paging
- **Layer / owner:** Brain performance cache — faster date paging.

RU:

- **Что это:** Dart-файл `day_snapshot_window.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/cache/day_snapshot_window.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `day_snapshot_window.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/cache/day_snapshot_window.dart`.
- **Когда открывать:** Баг или доработка, связанная с `day_snapshot_window.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/cache/render_snapshot.dart`

EN:

- **What this is:** Brain support file — Render snapshot helpers for day strips.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`PlanCardRenderDto`, `PlansDayRenderSnapshot`, `TimelineCardRenderDto`, `TimelineDayRenderSnapshot`).
- **Key code names:** `PlanCardRenderDto`, `PlansDayRenderSnapshot`, `TimelineCardRenderDto`, `TimelineDayRenderSnapshot`
- **Responsibilities:** Render snapshot helpers for day strips
- **When to open:** When behavior tied to `render_snapshot.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Render snapshot helpers for day strips
- **Layer / owner:** Brain performance cache — faster date paging.

RU:

- **Что это:** Dart-файл `render_snapshot.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/cache/render_snapshot.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `render_snapshot.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/cache/render_snapshot.dart`.
- **Когда открывать:** Баг или доработка, связанная с `render_snapshot.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/cache/rendered_day_body_cache.dart`

EN:

- **What this is:** Brain support file — Rendered day-body LRU cache.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`TimelineDayBodyEntry`, `PlansDayBodyEntry`).
- **Key code names:** `TimelineDayBodyEntry`, `PlansDayBodyEntry`
- **Responsibilities:** Rendered day-body LRU cache
- **When to open:** When behavior tied to `rendered_day_body_cache.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Rendered day-body LRU cache
- **Layer / owner:** Brain performance cache — faster date paging.

RU:

- **Что это:** Dart-файл `rendered_day_body_cache.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/cache/rendered_day_body_cache.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `rendered_day_body_cache.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/cache/rendered_day_body_cache.dart`.
- **Когда открывать:** Баг или доработка, связанная с `rendered_day_body_cache.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


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

- **Что это:** Dart-файл `category_cache_helpers.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/categories/category_cache_helpers.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `category_cache_helpers.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/categories/category_cache_helpers.dart`.
- **Когда открывать:** Баг или доработка, связанная с `category_cache_helpers.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


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

- **Что это:** Dart-файл `category_crud.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/categories/category_crud.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `category_crud.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/categories/category_crud.dart`.
- **Когда открывать:** Баг или доработка, связанная с `category_crud.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


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

- **Что это:** Dart-файл `category_default_time.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/categories/category_default_time.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `category_default_time.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/categories/category_default_time.dart`.
- **Когда открывать:** Баг или доработка, связанная с `category_default_time.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


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

- **Что это:** Dart-файл `category_lookup.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/categories/category_lookup.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `category_lookup.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/categories/category_lookup.dart`.
- **Когда открывать:** Баг или доработка, связанная с `category_lookup.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


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

- **Что это:** Dart-файл `category_record_bridge.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/categories/category_record_bridge.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `category_record_bridge.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/categories/category_record_bridge.dart`.
- **Когда открывать:** Баг или доработка, связанная с `category_record_bridge.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


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

- **Что это:** Dart-файл `category_stats.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/categories/category_stats.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `category_stats.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/categories/category_stats.dart`.
- **Когда открывать:** Баг или доработка, связанная с `category_stats.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


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

- **Что это:** Dart-файл `category_tree.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/categories/category_tree.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `category_tree.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/categories/category_tree.dart`.
- **Когда открывать:** Баг или доработка, связанная с `category_tree.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/category_fuzzy_match.dart`

EN:

- **What this is:** Brain support file — Category name scoring.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (implementation details in the source file).
- **Responsibilities:** Category name scoring
- **When to open:** When behavior tied to `category_fuzzy_match.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Category name scoring
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `category_fuzzy_match.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/category_fuzzy_match.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `category_fuzzy_match.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/category_fuzzy_match.dart`.
- **Когда открывать:** Баг или доработка, связанная с `category_fuzzy_match.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/category_service.dart`

EN:

- **What this is:** Main coordinator for categories (tree, colors, matching) inside the brain.
- **Why needed:** UI calls one category entry point; this file delegates to focused modules in the subfolder.
- **What it contains:** Coordinator extensions plus links to `part` files under `categorys/` or `category/`.
- **Key code names:** `CategoryServiceExtension`
- **Responsibilities:** Category coordinator: flatten/PB bridge statics, stats duration helpers, local task prefs helpers
- **When to open:** When behavior tied to `category_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Category coordinator: flatten/PB bridge statics, stats duration helpers, local task prefs helpers
- **Layer / owner:** Brain coordinator — entry point for this domain inside `database_service.dart`.

RU:

- **Что это:** Dart-файл `category_service.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/category_service.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `category_service.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/category_service.dart`.
- **Когда открывать:** Баг или доработка, связанная с `category_service.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/database_service.dart`

EN:

- **What this is:** The single “brain” front door — one place all screens ask for data and saves.
- **Why needed:** Timeline, Plans, Lists, and Categories share one singleton so PocketBase rules stay consistent.
- **What it contains:** Shared streams, caches, and `part` declarations for records, plans, categories, profile.
- **Key code names:** `_BuildNode`, `_OptimisticEndPatch`, `LegacyIdResolutionException`, `AuthenticatedUserIdRequiredException`, `AiBackendException`, `_DatabaseServiceLifecycleObserver`
- **Responsibilities:** Host extensions; route work to `record_service`, `plan_service`, etc.
- **When to open:** When behavior tied to `database_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Singleton root: shared state, streams, static helpers; `part` coordinator
- **Layer / owner:** Brain coordinator — entry point for this domain inside `database_service.dart`.

RU:

- **Что это:** Dart-файл `database_service.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/database_service.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `database_service.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/database_service.dart`.
- **Когда открывать:** Баг или доработка, связанная с `database_service.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/db_core.dart`

EN:

- **What this is:** Brain support file — Bootstrap: `loadInitialData`, PocketBase health, lifecycle, flush outboxes.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`DbCoreExtension`).
- **Key code names:** `DbCoreExtension`
- **Responsibilities:** Bootstrap: `loadInitialData`, PocketBase health, lifecycle, flush outboxes
- **When to open:** When behavior tied to `db_core.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Bootstrap: `loadInitialData`, PocketBase health, lifecycle, flush outboxes
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `db_core.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/db_core.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `db_core.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/db_core.dart`.
- **Когда открывать:** Баг или доработка, связанная с `db_core.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/local_sync/offline_sync_state.dart`

EN:

- **What this is:** Tracks pending sync count and “auth paused” for the top banner.
- **Why needed:** Users see how many changes wait to upload; tap banner to retry.
- **What it contains:** `OfflineSyncController`: pendingCount, isSyncing, authPaused.
- **Key code names:** `OfflineSyncController`
- **Responsibilities:** Pending count, syncing, auth-paused UI state
- **When to open:** When behavior tied to `offline_sync_state.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Offline banner in shell, reconnect flush; Role: Pending count, syncing, auth-paused UI state
- **Layer / owner:** Brain offline queue / sync state.

RU:

- **Что это:** Dart-файл `offline_sync_state.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/local_sync/offline_sync_state.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `offline_sync_state.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/local_sync/offline_sync_state.dart`.
- **Когда открывать:** Баг или доработка, связанная с `offline_sync_state.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/local_sync/plan_create_outbox.dart`

EN:

- **What this is:** Legacy re-export file — points importers to `plan_mutation_outbox.dart`.
- **Why needed:** Older code imported this name; kept so imports do not break.
- **What it contains:** Single export line only — no logic.
- **Responsibilities:** Re-export of `plan_mutation_outbox.dart`
- **When to open:** When behavior tied to `plan_create_outbox.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Offline banner in shell, reconnect flush; Role: Re-export of `plan_mutation_outbox.dart`
- **Layer / owner:** Brain offline queue / sync state.

RU:

- **Что это:** Dart-файл `plan_create_outbox.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/local_sync/plan_create_outbox.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_create_outbox.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/local_sync/plan_create_outbox.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_create_outbox.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/local_sync/plan_mutation_outbox.dart`

EN:

- **What this is:** Remembers plan/list create/update/delete when offline.
- **Why needed:** List checkbox and plan edits queue here until reconnect.
- **What it contains:** SharedPreferences queue for plan mutations.
- **Responsibilities:** Offline queue: plan/list create/update/delete
- **When to open:** When behavior tied to `plan_mutation_outbox.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Offline banner in shell, reconnect flush; Role: Offline queue: plan/list create/update/delete
- **Layer / owner:** Brain offline queue / sync state.

RU:

- **Что это:** Dart-файл `plan_mutation_outbox.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/local_sync/plan_mutation_outbox.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_mutation_outbox.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/local_sync/plan_mutation_outbox.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_mutation_outbox.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/local_sync/record_mutation_outbox.dart`

EN:

- **What this is:** Remembers record start/stop/edit/delete when the network fails.
- **Why needed:** Offline-first law: tap must succeed locally even on airplane mode.
- **What it contains:** SharedPreferences queue for record mutations; coalesces duplicate ops.
- **Responsibilities:** Offline queue: record start/stop/update/delete
- **When to open:** When behavior tied to `record_mutation_outbox.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Offline banner in shell, reconnect flush; Role: Offline queue: record start/stop/update/delete
- **Layer / owner:** Brain offline queue / sync state.

RU:

- **Что это:** Dart-файл `record_mutation_outbox.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/local_sync/record_mutation_outbox.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `record_mutation_outbox.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/local_sync/record_mutation_outbox.dart`.
- **Когда открывать:** Баг или доработка, связанная с `record_mutation_outbox.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/local_sync/sync_manager.dart`

EN:

- **What this is:** Watches network connectivity and triggers queue flush on reconnect.
- **Why needed:** When Wi‑Fi returns, pending offline changes should upload automatically.
- **What it contains:** Connectivity listener → `flushPendingLocalMutations`.
- **Key code names:** `SyncManager`
- **Responsibilities:** Connectivity / resume → flush trigger
- **When to open:** When behavior tied to `sync_manager.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Offline banner in shell, reconnect flush; Role: Connectivity / resume → flush trigger
- **Layer / owner:** Brain offline queue / sync state.

RU:

- **Что это:** Dart-файл `sync_manager.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/local_sync/sync_manager.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `sync_manager.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/local_sync/sync_manager.dart`.
- **Когда открывать:** Баг или доработка, связанная с `sync_manager.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/models.dart`

EN:

- **What this is:** Barrel file that declares all data model `part` files in one place.
- **Why needed:** Other code imports `models.dart` once to get `TimelineRecord`, `PlanningTask`, etc.
- **What it contains:** `part` directives only — no logic.
- **Responsibilities:** Export surface for model types listed in `docs/DATA_MAP.md`.
- **When to open:** When behavior tied to `models.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: `part` declarations; export surface for all model types
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Dart-файл `models.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/models.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `models.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/models.dart`.
- **Когда открывать:** Баг или доработка, связанная с `models.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/models/_shared.dart`

EN:

- **What this is:** Shared helper functions used by multiple data model classes.
- **Why needed:** Avoids duplicating date/id parsing across record, plan, and category models.
- **What it contains:** Small pure helpers — no PocketBase calls.
- **Key code names:** `CategoryDisplayMode`, `CategoryDisplayModeWire`
- **Responsibilities:** Shared model helpers
- **When to open:** When behavior tied to `_shared.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Shared model helpers
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Dart-файл `_shared.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/models/_shared.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `_shared.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/models/_shared.dart`.
- **Когда открывать:** Баг или доработка, связанная с `_shared.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/models/category.dart`

EN:

- **What this is:** Defines `CategoryRule` — name, color, icon, parent, PocketBase ids.
- **Why needed:** Category picker and manager display this shape.
- **What it contains:** `CategoryRule` with stable hash for category business id.
- **Key code names:** `Category`, `CategoryNameInputKind`, `CategoryNameInputStatus`
- **Responsibilities:** `CategoryRule`
- **When to open:** When behavior tied to `category.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: `CategoryRule`
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Dart-файл `category.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/models/category.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `category.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/models/category.dart`.
- **Когда открывать:** Баг или доработка, связанная с `category.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/models/planning.dart`

EN:

- **What this is:** Defines `PlanningTask` — scheduled plans and backlog list rows.
- **Why needed:** Plans tab, Lists tab, and Time View cards use this shape.
- **What it contains:** Plan fields: time, done flag, recurrence, tags.
- **Key code names:** `AiParsedTaskHint`, `SourcePlanLinkSuggestion`, `PlanDayOverloadReport`, `PlanningTask`
- **Responsibilities:** `PlanningTask`
- **When to open:** When behavior tied to `planning.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: `PlanningTask`
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Dart-файл `planning.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/models/planning.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/models/planning.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/models/profile.dart`

EN:

- **What this is:** Defines the shape of user settings (`UserSettings`) — timezone, language, admin flag.
- **Why needed:** UI and brain must agree on field names from `docs/DATA_MAP.md`.
- **What it contains:** `UserSettings` class and profile field parsers.
- **Key code names:** `Profile`, `UserProfile`, `ProfileUpdate`, `TagCatalogScope`, `TagCatalogScopeMatch`, `UserSettings`
- **Responsibilities:** `UserSettings`, profile fields
- **When to open:** When behavior tied to `profile.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; Role: `UserSettings`, profile fields
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Dart-файл `profile.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/models/profile.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `profile.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/models/profile.dart`.
- **Когда открывать:** Баг или доработка, связанная с `profile.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/models/record.dart`

EN:

- **What this is:** Defines `TimelineRecord` — start/stop times, status, category, date key.
- **Why needed:** Every Timeline card is a `TimelineRecord` instance.
- **What it contains:** UTC storage, profile-timezone date key bucketing.
- **Key code names:** `Record`
- **Responsibilities:** `TimelineRecord`
- **When to open:** When behavior tied to `record.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: `TimelineRecord`
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Dart-файл `record.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/models/record.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `record.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/models/record.dart`.
- **Когда открывать:** Баг или доработка, связанная с `record.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/models/stats.dart`

EN:

- **What this is:** Defines aggregated stats numbers for Timeline stats tab.
- **Why needed:** Stats views sum records without re-parsing raw JSON each frame.
- **What it contains:** Stats aggregate structs.
- **Key code names:** `BasicDayStats`, `StatsTreeNode`, `SessionGroup`, `StatsNode`
- **Responsibilities:** Stats aggregates
- **When to open:** When behavior tied to `stats.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Stats aggregates
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Dart-файл `stats.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/models/stats.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `stats.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/models/stats.dart`.
- **Когда открывать:** Баг или доработка, связанная с `stats.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/models/tag.dart`

EN:

- **What this is:** Defines `Tag` and `TagCatalogScope` for plan vs list tag domains.
- **Why needed:** Tag manager and chip strips use these types.
- **What it contains:** Tag name, color, default duration minutes.
- **Key code names:** `Tag`
- **Responsibilities:** `Tag`, `TagCatalogScope`
- **When to open:** When behavior tied to `tag.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: `Tag`, `TagCatalogScope`
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Dart-файл `tag.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/models/tag.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `tag.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/models/tag.dart`.
- **Когда открывать:** Баг или доработка, связанная с `tag.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/pb_config.dart`

EN:

- **What this is:** Brain support file — PocketBase URL, collection names, expand constants.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (implementation details in the source file).
- **Responsibilities:** PocketBase URL, collection names, expand constants
- **When to open:** When behavior tied to `pb_config.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: PocketBase URL, collection names, expand constants
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `pb_config.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/pb_config.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `pb_config.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/pb_config.dart`.
- **Когда открывать:** Баг или доработка, связанная с `pb_config.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/plan_service.dart`

EN:

- **What this is:** Main coordinator for plans and backlog lists inside the brain.
- **Why needed:** UI calls one plan entry point; this file delegates to focused modules in the subfolder.
- **What it contains:** Coordinator extensions plus links to `part` files under `plans/` or `plan/`.
- **Key code names:** `PlanServiceExtension`
- **Responsibilities:** Plans/lists coordinator: CRUD, streams, wall-time projection, alarms, AI parse
- **When to open:** When behavior tied to `plan_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Plans/lists coordinator: CRUD, streams, wall-time projection, alarms, AI parse
- **Layer / owner:** Brain coordinator — entry point for this domain inside `database_service.dart`.

RU:

- **Что это:** Dart-файл `plan_service.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/plan_service.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_service.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/plan_service.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_service.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/plan_time_sequential_cascade.dart`

EN:

- **What this is:** Brain support file — Plan time sequential layout math + `computeTimeViewInsertionCascade`.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`PlanTimeSequentialCascadePatch`, `TimeViewTargetDropSchedule`, `TimeViewInsertPosition`, `TimeViewInsertionSource`).
- **Key code names:** `PlanTimeSequentialCascadePatch`, `TimeViewTargetDropSchedule`, `TimeViewInsertPosition`, `TimeViewInsertionSource`
- **Responsibilities:** Plan time sequential layout math + `computeTimeViewInsertionCascade`
- **When to open:** When behavior tied to `plan_time_sequential_cascade.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Plan time sequential layout math + `computeTimeViewInsertionCascade`
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `plan_time_sequential_cascade.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/plan_time_sequential_cascade.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_time_sequential_cascade.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/plan_time_sequential_cascade.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_time_sequential_cascade.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/plans/plan_cache_helpers.dart`

EN:

- **What this is:** Maintains the local plan list clean and scores title similarity for smart linking.
- **Why needed:** Duplicate plan rows or bad merges would break Planning and Lists tabs.
- **What it contains:** Plan dedupe/scrub, title link scoring heuristics.
- **Key code names:** `PlanCacheProjectionExtension`
- **Responsibilities:** Plan dedupe/scrub, title link scoring heuristics
- **When to open:** Plan/list save, Time View layout, recurrence, tags on plans, offline queue.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Plans tab, Lists tab, Time View; Role: Plan dedupe/scrub, title link scoring heuristics
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `plan_cache_helpers.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/plans/plan_cache_helpers.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_cache_helpers.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/plans/plan_cache_helpers.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_cache_helpers.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/plans/plan_outbox_helpers.dart`

EN:

- **What this is:** Queues plan/list edits when offline and flushes when connection returns.
- **Why needed:** Checking off a list item offline must stick and sync later.
- **What it contains:** Plan mutation outbox enqueue/flush/replay.
- **Key code names:** `PlanOutboxSyncExtension`
- **Responsibilities:** Plan mutation outbox enqueue/flush/replay
- **When to open:** Plan/list save, Time View layout, recurrence, tags on plans, offline queue.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Plans tab, Lists tab, Time View; Role: Plan mutation outbox enqueue/flush/replay
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `plan_outbox_helpers.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/plans/plan_outbox_helpers.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_outbox_helpers.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/plans/plan_outbox_helpers.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_outbox_helpers.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/plans/plan_projection_types.dart`

EN:

- **What this is:** Data shapes for how a plan looks on the clock in Time View.
- **Why needed:** Time View needs projected start/end times separate from raw PocketBase fields.
- **What it contains:** `TimeModeProjectedPlan`, timezone-aware projection types.
- **Key code names:** `TimeModeProjectedPlan`, `PlanTimeModeProjection`
- **Responsibilities:** `TimeModeProjectedPlan`, `PlanTimeModeProjection`
- **When to open:** Plan/list save, Time View layout, recurrence, tags on plans, offline queue.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Plans tab, Lists tab, Time View; Role: `TimeModeProjectedPlan`, `PlanTimeModeProjection`
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `plan_projection_types.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/plans/plan_projection_types.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_projection_types.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/plans/plan_projection_types.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_projection_types.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/plans/plan_recurrence_helpers.dart`

EN:

- **What this is:** Expands repeating plans (daily/weekly RRULE) into visible day rows.
- **Why needed:** A single recurring gym plan must appear on every matching calendar day.
- **What it contains:** RRULE JIT expansion, exception dates, virtual occurrence handling.
- **Key code names:** `PlanRecurrenceExtension`
- **Responsibilities:** RRULE JIT expansion, exception-date parse helpers
- **When to open:** Plan/list save, Time View layout, recurrence, tags on plans, offline queue.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Plans tab, Lists tab, Time View; Role: RRULE JIT expansion, exception-date parse helpers
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `plan_recurrence_helpers.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/plans/plan_recurrence_helpers.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_recurrence_helpers.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/plans/plan_recurrence_helpers.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_recurrence_helpers.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/plans/plan_tags_helpers.dart`

EN:

- **What this is:** Syncs tag chips on plan cards with PocketBase `tags_link` relations.
- **Why needed:** Plan tags must save to the server and show the same on Lists and Plans.
- **What it contains:** Tag catalog fetch, PB link sync for plans/lists.
- **Key code names:** `PlanTagsExtension`
- **Responsibilities:** Plan/list tag catalog fetch + PB `tags_link` sync
- **When to open:** Plan/list save, Time View layout, recurrence, tags on plans, offline queue.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Plans tab, Lists tab, Time View; Role: Plan/list tag catalog fetch + PB `tags_link` sync
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `plan_tags_helpers.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/plans/plan_tags_helpers.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_tags_helpers.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/plans/plan_tags_helpers.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_tags_helpers.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/plans/plan_time_cascade_helpers.dart`

EN:

- **What this is:** Calculates where plan blocks sit vertically in Time View when times overlap.
- **Why needed:** Without cascade math, overlapping plans would draw on top of each other.
- **What it contains:** Time View cascade layout, duration constants, wall-time estimates.
- **Key code names:** `PlanTimeCascadeExtension`
- **Responsibilities:** Time View cascade, duration consts, `planningWallEstimateSeconds`
- **When to open:** Plan/list save, Time View layout, recurrence, tags on plans, offline queue.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Plans tab, Lists tab, Time View; Role: Time View cascade, duration consts, `planningWallEstimateSeconds`
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `plan_time_cascade_helpers.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/plans/plan_time_cascade_helpers.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_time_cascade_helpers.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/plans/plan_time_cascade_helpers.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_time_cascade_helpers.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/price_reporter_client_match.dart`

EN:

- **What this is:** Brain support file — Price Reporter client-category token guard for voice parse.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`PriceReporterAliasEntry`, `PriceReporterClientMatchResult`, `PriceReporterCategoryNode`).
- **Key code names:** `PriceReporterAliasEntry`, `PriceReporterClientMatchResult`, `PriceReporterCategoryNode`
- **Responsibilities:** Price Reporter client-category token guard for voice parse
- **When to open:** When behavior tied to `price_reporter_client_match.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Price Reporter client-category token guard for voice parse
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `price_reporter_client_match.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/price_reporter_client_match.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `price_reporter_client_match.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/price_reporter_client_match.dart`.
- **Когда открывать:** Баг или доработка, связанная с `price_reporter_client_match.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/profile/profile_admin.dart`

EN:

- **What this is:** Reads whether your account is admin (Component Lab gate).
- **Why needed:** Only admins see More → Dev / Design Lab.
- **What it contains:** Parses `profiles.is_admin` during hydration — never written by normal UI.
- **Responsibilities:** Admin bool parse helper for hydration
- **When to open:** Profile settings, timezone, tags catalog, tag display prefs.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; Role: Admin bool parse helper for hydration
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `profile_admin.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/profile/profile_admin.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `profile_admin.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/profile/profile_admin.dart`.
- **Когда открывать:** Баг или доработка, связанная с `profile_admin.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/profile/profile_cache_helpers.dart`

EN:

- **What this is:** Mirrors profile settings to device storage for faster next launch.
- **Why needed:** Reduces flicker on cold start before PocketBase responds.
- **What it contains:** SharedPreferences mirror/hydrate for profile settings.
- **Key code names:** `ProfileCacheExtension`
- **Responsibilities:** Device prefs mirror/hydrate for profile settings
- **When to open:** Profile settings, timezone, tags catalog, tag display prefs.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; Role: Device prefs mirror/hydrate for profile settings
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `profile_cache_helpers.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/profile/profile_cache_helpers.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `profile_cache_helpers.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/profile/profile_cache_helpers.dart`.
- **Когда открывать:** Баг или доработка, связанная с `profile_cache_helpers.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/profile/profile_hydration.dart`

EN:

- **What this is:** Downloads your profile from PocketBase when the app starts or after login.
- **Why needed:** Timezone, language, and tag settings cannot render until profile loads.
- **What it contains:** Profile fetch lifecycle, PB map apply, retry on failure.
- **Key code names:** `ProfileHydrationExtension`
- **Responsibilities:** Profile fetch/hydration lifecycle, PB map apply, retry
- **When to open:** Profile settings, timezone, tags catalog, tag display prefs.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; Role: Profile fetch/hydration lifecycle, PB map apply, retry
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `profile_hydration.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/profile/profile_hydration.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `profile_hydration.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/profile/profile_hydration.dart`.
- **Когда открывать:** Баг или доработка, связанная с `profile_hydration.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/profile/profile_preferences.dart`

EN:

- **What this is:** Reloads data region when profile preferences change.
- **Why needed:** Some settings require refreshing cached lists after save.
- **What it contains:** Data region reload hook after preference change.
- **Key code names:** `ProfilePreferencesExtension`
- **Responsibilities:** Data region reload hook
- **When to open:** Profile settings, timezone, tags catalog, tag display prefs.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; Role: Data region reload hook
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `profile_preferences.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/profile/profile_preferences.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `profile_preferences.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/profile/profile_preferences.dart`.
- **Когда открывать:** Баг или доработка, связанная с `profile_preferences.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/profile/profile_settings.dart`

EN:

- **What this is:** Saves profile preference changes back to PocketBase.
- **Why needed:** Settings toggles in Profile must persist for the signed-in user only.
- **What it contains:** Profile PATCH, diff fields, locale sync after save.
- **Key code names:** `ProfileSettingsExtension`
- **Responsibilities:** Profile PATCH/save, diff fields, locale sync
- **When to open:** Profile settings, timezone, tags catalog, tag display prefs.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; Role: Profile PATCH/save, diff fields, locale sync
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `profile_settings.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/profile/profile_settings.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `profile_settings.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/profile/profile_settings.dart`.
- **Когда открывать:** Баг или доработка, связанная с `profile_settings.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/profile/profile_timezone.dart`

EN:

- **What this is:** Calculates “today” and wall-clock labels using your profile timezone.
- **Why needed:** Timeline day boundaries follow profile TZ, not phone local time.
- **What it contains:** Timezone normalize/offset, projected today, TZ writes.
- **Key code names:** `ProfileTimezoneExtension`
- **Responsibilities:** Timezone normalize/offset, projected today, TZ writes
- **When to open:** Profile settings, timezone, tags catalog, tag display prefs.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; Role: Timezone normalize/offset, projected today, TZ writes
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `profile_timezone.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/profile/profile_timezone.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `profile_timezone.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/profile/profile_timezone.dart`.
- **Когда открывать:** Баг или доработка, связанная с `profile_timezone.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/profile/tag_catalog.dart`

EN:

- **What this is:** Loads and edits the tag list (plan tags and list tags) in PocketBase.
- **Why needed:** Tag manager and tag chips on cards read from this catalog.
- **What it contains:** Tag CRUD, sort order, PocketBase `tags_link` id resolution.
- **Key code names:** `TagCatalogExtension`
- **Responsibilities:** Tag catalog fetch/CRUD, sort order, PB `tags_link` id resolution
- **When to open:** Profile settings, timezone, tags catalog, tag display prefs.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; Role: Tag catalog fetch/CRUD, sort order, PB `tags_link` id resolution
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `tag_catalog.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/profile/tag_catalog.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `tag_catalog.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/profile/tag_catalog.dart`.
- **Когда открывать:** Баг или доработка, связанная с `tag_catalog.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/profile/tag_display_settings.dart`

EN:

- **What this is:** Stores how tag chips appear on list cards (hidden, compact, etc.).
- **Why needed:** Tag display mode is a profile preference, not per-plan.
- **What it contains:** List tag strip visibility prefs, display-mode merge.
- **Key code names:** `TagDisplaySettingsExtension`
- **Responsibilities:** List tag strip visibility prefs, display-mode prefs merge
- **When to open:** Profile settings, timezone, tags catalog, tag display prefs.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; Role: List tag strip visibility prefs, display-mode prefs merge
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `tag_display_settings.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/profile/tag_display_settings.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `tag_display_settings.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/profile/tag_display_settings.dart`.
- **Когда открывать:** Баг или доработка, связанная с `tag_display_settings.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/profile_service.dart`

EN:

- **What this is:** Main coordinator for profile, timezone, and tags inside the brain.
- **Why needed:** UI calls one profile entry point; this file delegates to focused modules in the subfolder.
- **What it contains:** Coordinator extensions plus links to `part` files under `profiles/` or `profile/`.
- **Key code names:** `_ProfileFetchFailedException`, `ProfileServiceExtension`
- **Responsibilities:** Profile coordinator: shared Brain state, display label resolver
- **When to open:** When behavior tied to `profile_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; Role: Profile coordinator: shared Brain state, display label resolver
- **Layer / owner:** Brain coordinator — entry point for this domain inside `database_service.dart`.

RU:

- **Что это:** Dart-файл `profile_service.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/profile_service.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `profile_service.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/profile_service.dart`.
- **Когда открывать:** Баг или доработка, связанная с `profile_service.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/record_service.dart`

EN:

- **What this is:** Main coordinator for timeline records (timer start/stop) inside the brain.
- **Why needed:** UI calls one record entry point; this file delegates to focused modules in the subfolder.
- **What it contains:** Coordinator extensions plus links to `part` files under `records/` or `record/`.
- **Key code names:** `RecordServiceExtension`
- **Responsibilities:** Records coordinator: cache, fetch, upsert, start/stop entry, streams
- **When to open:** When behavior tied to `record_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Records coordinator: cache, fetch, upsert, start/stop entry, streams
- **Layer / owner:** Brain coordinator — entry point for this domain inside `database_service.dart`.

RU:

- **Что это:** Dart-файл `record_service.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/record_service.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `record_service.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/record_service.dart`.
- **Когда открывать:** Баг или доработка, связанная с `record_service.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/records/record_cache_helpers.dart`

EN:

- **What this is:** Filters and streams the in-memory record list for Timeline display.
- **Why needed:** Every Timeline day reads from this cache instead of hitting the network each swipe.
- **What it contains:** `recordsStream`, per-day filter, display-time helpers.
- **Key code names:** `RecordCacheProjectionExtension`
- **Responsibilities:** Per-day filter, `recordsStream`, display-time helpers
- **When to open:** Timeline timer, record edit, offline start/stop, duplicate running record.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; Role: Per-day filter, `recordsStream`, display-time helpers
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `record_cache_helpers.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/records/record_cache_helpers.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `record_cache_helpers.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/records/record_cache_helpers.dart`.
- **Когда открывать:** Баг или доработка, связанная с `record_cache_helpers.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/records/record_crud.dart`

EN:

- **What this is:** Sends timeline record start, stop, edit, and delete to PocketBase.
- **Why needed:** When you tap Start or Stop, this file builds the network request and updates the local record list.
- **What it contains:** POST/PATCH/DELETE for the `records` table; `writeRecord`, `stopRecord`, `updateRecord`.
- **Key code names:** `RecordCrudExtension`
- **Responsibilities:** Record CRUD, PATCH/DELETE network phases, `writeRecord` / `updateRecord` / `stopRecord`
- **When to open:** Timeline timer, record edit, offline start/stop, duplicate running record.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; Role: Record CRUD, PATCH/DELETE network phases, `writeRecord` / `updateRecord` / `stopRecord`
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `record_crud.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/records/record_crud.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `record_crud.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/records/record_crud.dart`.
- **Когда открывать:** Баг или доработка, связанная с `record_crud.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/records/record_ghost_cleanup.dart`

EN:

- **What this is:** Removes dead record rows from local cache after server 404.
- **Why needed:** Stale cache entries would show ghost timers that no longer exist on PocketBase.
- **What it contains:** 404 dead-letter prune against live cache.
- **Key code names:** `RecordGhostCleanupExtension`
- **Responsibilities:** 404 deadletter prune against live cache
- **When to open:** Timeline timer, record edit, offline start/stop, duplicate running record.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; Role: 404 deadletter prune against live cache
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `record_ghost_cleanup.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/records/record_ghost_cleanup.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `record_ghost_cleanup.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/records/record_ghost_cleanup.dart`.
- **Когда открывать:** Баг или доработка, связанная с `record_ghost_cleanup.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/records/record_optimistic.dart`

EN:

- **What this is:** Shows timer start/stop on screen immediately — before PocketBase confirms.
- **Why needed:** The 100ms rule: users must see the running timer without waiting on Wi‑Fi.
- **What it contains:** Shadow state maps, optimistic stop overlay, pending-start handoff.
- **Key code names:** `RecordOptimisticExtension`
- **Responsibilities:** Optimistic stop overlay, sacred handoff, pending-start map
- **When to open:** Timeline timer, record edit, offline start/stop, duplicate running record.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; Role: Optimistic stop overlay, sacred handoff, pending-start map
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `record_optimistic.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/records/record_optimistic.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `record_optimistic.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/records/record_optimistic.dart`.
- **Когда открывать:** Баг или доработка, связанная с `record_optimistic.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/records/record_outbox_helpers.dart`

EN:

- **What this is:** Queues record changes when offline and replays them when back online.
- **Why needed:** Start/stop on bad Wi‑Fi must not be lost — changes wait in SharedPreferences.
- **What it contains:** Record mutation outbox enqueue, flush, Highlander server sync phase.
- **Key code names:** `RecordOutboxSyncExtension`
- **Responsibilities:** Record mutation outbox enqueue/flush/replay, Highlander server phase
- **When to open:** Timeline timer, record edit, offline start/stop, duplicate running record.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; Role: Record mutation outbox enqueue/flush/replay, Highlander server phase
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `record_outbox_helpers.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/records/record_outbox_helpers.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `record_outbox_helpers.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/records/record_outbox_helpers.dart`.
- **Когда открывать:** Баг или доработка, связанная с `record_outbox_helpers.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/records/record_overlap_helpers.dart`

EN:

- **What this is:** Ensures only one running record at a time (Highlander rule).
- **Why needed:** Starting a new task must auto-stop the previous running timer.
- **What it contains:** Singleton reconcile, overlap probes, local apply before server.
- **Key code names:** `RecordOverlapExtension`
- **Responsibilities:** Highlander local apply, singleton reconcile, overlap probes
- **When to open:** Timeline timer, record edit, offline start/stop, duplicate running record.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; Role: Highlander local apply, singleton reconcile, overlap probes
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `record_overlap_helpers.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/records/record_overlap_helpers.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `record_overlap_helpers.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/records/record_overlap_helpers.dart`.
- **Когда открывать:** Баг или доработка, связанная с `record_overlap_helpers.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/records/record_realtime.dart`

EN:

- **What this is:** Listens for live record changes from PocketBase on the server.
- **Why needed:** If another device stops a record, Timeline should update without manual refresh.
- **What it contains:** Realtime subscription connect/disconnect, event merge into cache.
- **Key code names:** `RecordRealtimeExtension`
- **Responsibilities:** PocketBase records realtime subscribe/unsubscribe
- **When to open:** Timeline timer, record edit, offline start/stop, duplicate running record.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; Role: PocketBase records realtime subscribe/unsubscribe
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `record_realtime.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/records/record_realtime.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `record_realtime.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/records/record_realtime.dart`.
- **Когда открывать:** Баг или доработка, связанная с `record_realtime.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/records/record_timeline_vm.dart`

EN:

- **What this is:** Prepares which record rows appear on each Timeline day page.
- **Why needed:** Timeline swipe between days needs pre-built lists and warm-window paging.
- **What it contains:** Day index, warm window, row view-model builders for Timeline cards.
- **Key code names:** `RecordTimelineVmExtension`
- **Responsibilities:** Timeline day index, warm window, row VM builders
- **When to open:** Timeline timer, record edit, offline start/stop, duplicate running record.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; Role: Timeline day index, warm window, row VM builders
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `record_timeline_vm.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/records/record_timeline_vm.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `record_timeline_vm.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/records/record_timeline_vm.dart`.
- **Когда открывать:** Баг или доработка, связанная с `record_timeline_vm.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/recurrence_edit_scope.dart`

EN:

- **What this is:** Brain support file — `RecurrenceEditScope` enum for recurring plan edit/delete scope.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`RecurrenceEditScope`).
- **Key code names:** `RecurrenceEditScope`
- **Responsibilities:** `RecurrenceEditScope` enum for recurring plan edit/delete scope
- **When to open:** When behavior tied to `recurrence_edit_scope.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: `RecurrenceEditScope` enum for recurring plan edit/delete scope
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `recurrence_edit_scope.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/recurrence_edit_scope.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `recurrence_edit_scope.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/recurrence_edit_scope.dart`.
- **Когда открывать:** Баг или доработка, связанная с `recurrence_edit_scope.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/smart_input_parser.dart`

EN:

- **What this is:** Brain support file — Natural-language plan/list parse (client + AI backend hook).
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`SmartTimeParseResult`, `SmartTimeRangeParseResult`).
- **Key code names:** `SmartTimeParseResult`, `SmartTimeRangeParseResult`
- **Responsibilities:** Natural-language plan/list parse (client + AI backend hook)
- **When to open:** When behavior tied to `smart_input_parser.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Natural-language plan/list parse (client + AI backend hook)
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `smart_input_parser.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/smart_input_parser.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `smart_input_parser.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/smart_input_parser.dart`.
- **Когда открывать:** Баг или доработка, связанная с `smart_input_parser.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/time_view_fixed_time_policy.dart`

EN:

- **What this is:** Brain support file — Local prefs `time_view_fixed_tag_ids_v1`.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`TimeViewFixedTagPrefs`).
- **Key code names:** `TimeViewFixedTagPrefs`
- **Responsibilities:** Local prefs `time_view_fixed_tag_ids_v1`; `isPlanFixedInTimeView` (schema gap: no PB sync yet)
- **When to open:** When behavior tied to `time_view_fixed_time_policy.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Local prefs `time_view_fixed_tag_ids_v1`; `isPlanFixedInTimeView` (schema gap: no PB sync yet)
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `time_view_fixed_time_policy.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/time_view_fixed_time_policy.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `time_view_fixed_time_policy.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/time_view_fixed_time_policy.dart`.
- **Когда открывать:** Баг или доработка, связанная с `time_view_fixed_time_policy.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/voice_audio_stub.dart`

EN:

- **What this is:** Brain support file — Non-web voice audio stub.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (implementation details in the source file).
- **Responsibilities:** Non-web voice audio stub
- **When to open:** When behavior tied to `voice_audio_stub.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Non-web voice audio stub
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `voice_audio_stub.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/voice_audio_stub.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `voice_audio_stub.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/voice_audio_stub.dart`.
- **Когда открывать:** Баг или доработка, связанная с `voice_audio_stub.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/voice_audio_web.dart`

EN:

- **What this is:** Brain support file — Web voice audio implementation.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (implementation details in the source file).
- **Responsibilities:** Web voice audio implementation
- **When to open:** When behavior tied to `voice_audio_web.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Web voice audio implementation
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `voice_audio_web.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/voice_audio_web.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `voice_audio_web.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/voice_audio_web.dart`.
- **Когда открывать:** Баг или доработка, связанная с `voice_audio_web.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/voice_command_parser.dart`

EN:

- **What this is:** Brain support file — Deterministic desktop/mobile voice command parse (`parsePriceReporterVoiceCommand`, `VoiceCommandCategoryIndex`).
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (`VoiceCommandMatchConfidence`, `VoiceCommandParseResult`, `VoiceCommandCategoryCandidate`, `VoiceCommandCategoryIndex`).
- **Key code names:** `VoiceCommandMatchConfidence`, `VoiceCommandParseResult`, `VoiceCommandCategoryCandidate`, `VoiceCommandCategoryIndex`
- **Responsibilities:** Deterministic desktop/mobile voice command parse (`parsePriceReporterVoiceCommand`, `VoiceCommandCategoryIndex`)
- **When to open:** When behavior tied to `voice_command_parser.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Deterministic desktop/mobile voice command parse (`parsePriceReporterVoiceCommand`, `VoiceCommandCategoryIndex`)
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `voice_command_parser.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/voice_command_parser.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `voice_command_parser.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/voice_command_parser.dart`.
- **Когда открывать:** Баг или доработка, связанная с `voice_command_parser.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/web_history.dart`

EN:

- **What this is:** Brain support file — Web history API conditional export.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (implementation details in the source file).
- **Responsibilities:** Web history API conditional export
- **When to open:** When behavior tied to `web_history.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Web history API conditional export
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `web_history.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/web_history.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `web_history.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/web_history.dart`.
- **Когда открывать:** Баг или доработка, связанная с `web_history.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/web_history_stub.dart`

EN:

- **What this is:** Brain support file — Non-web history stub.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (implementation details in the source file).
- **Responsibilities:** Non-web history stub
- **When to open:** When behavior tied to `web_history_stub.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Non-web history stub
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `web_history_stub.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/web_history_stub.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `web_history_stub.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/web_history_stub.dart`.
- **Когда открывать:** Баг или доработка, связанная с `web_history_stub.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/data/web_history_web.dart`

EN:

- **What this is:** Brain support file — Web history implementation.
- **Why needed:** Shared PocketBase/auth/parse logic used by multiple tabs.
- **What it contains:** Dart code (implementation details in the source file).
- **Responsibilities:** Web history implementation
- **When to open:** When behavior tied to `web_history_web.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Web history implementation
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Dart-файл `web_history_web.dart` — Brain (мозг данных): логика PocketBase, кэш и optimistic UI.
- **Зачем:** Модуль `lib/data/web_history_web.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `web_history_web.dart`.
- **Обязанности:** Реализует логика PocketBase, кэш и optimistic UI для пути `lib/data/web_history_web.dart`.
- **Когда открывать:** Баг или доработка, связанная с `web_history_web.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Brain (мозг данных) — не platform wrapper.


### `lib/features/auth/auth_screen.dart`

EN:

- **What this is:** Dart source `auth_screen.dart` in `lib/features/auth` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/auth` needs `auth_screen.dart` for build, CI, or documented workflow.
- **What it contains:** Open `auth_screen.dart` when editing dart source for `lib/features/auth` (see folder section above).
- **Key code names:** `AuthScreen`
- **Responsibilities:** Fulfill the documented role of `auth_screen.dart` under `lib/features/auth`.
- **When to open:** When build output or maintenance cites `auth_screen.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/auth/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the auth area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `auth_screen.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/auth/auth_screen.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `auth_screen.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/auth/auth_screen.dart`.
- **Когда открывать:** Баг или доработка, связанная с `auth_screen.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/auth/auth_view.dart`

EN:

- **What this is:** Dart source `auth_view.dart` in `lib/features/auth` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/auth` needs `auth_view.dart` for build, CI, or documented workflow.
- **What it contains:** Open `auth_view.dart` when editing dart source for `lib/features/auth` (see folder section above).
- **Key code names:** `AuthView`, `_AuthViewState`
- **Responsibilities:** Fulfill the documented role of `auth_view.dart` under `lib/features/auth`.
- **When to open:** When build output or maintenance cites `auth_view.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/auth/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the auth area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `auth_view.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/auth/auth_view.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `auth_view.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/auth/auth_view.dart`.
- **Когда открывать:** Баг или доработка, связанная с `auth_view.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/auth/oauth_session.dart`

EN:

- **What this is:** Dart source `oauth_session.dart` in `lib/features/auth` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/auth` needs `oauth_session.dart` for build, CI, or documented workflow.
- **What it contains:** Open `oauth_session.dart` when editing dart source for `lib/features/auth` (see folder section above).
- **Key code names:** `OAuthUser`, `OAuthSession`
- **Responsibilities:** Fulfill the documented role of `oauth_session.dart` under `lib/features/auth`.
- **When to open:** When build output or maintenance cites `oauth_session.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/auth/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the auth area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `oauth_session.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/auth/oauth_session.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `oauth_session.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/auth/oauth_session.dart`.
- **Когда открывать:** Баг или доработка, связанная с `oauth_session.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/calendar/calendar_view.dart`

EN:

- **What this is:** Dart source `calendar_view.dart` in `lib/features/calendar` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/calendar` needs `calendar_view.dart` for build, CI, or documented workflow.
- **What it contains:** Open `calendar_view.dart` when editing dart source for `lib/features/calendar` (see folder section above).
- **Key code names:** `_CalendarViewMode`, `CalendarView`, `_CalendarViewState`
- **Responsibilities:** Fulfill the documented role of `calendar_view.dart` under `lib/features/calendar`.
- **When to open:** When build output or maintenance cites `calendar_view.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/calendar/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the calendar area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `calendar_view.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/calendar/calendar_view.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `calendar_view.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/calendar/calendar_view.dart`.
- **Когда открывать:** Баг или доработка, связанная с `calendar_view.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/categories/category_list_view.dart`

EN:

- **What this is:** Dart source `category_list_view.dart` in `lib/features/categories` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/categories` needs `category_list_view.dart` for build, CI, or documented workflow.
- **What it contains:** Open `category_list_view.dart` when editing dart source for `lib/features/categories` (see folder section above).
- **Key code names:** `_CategoryDepthLayout`, `CategoryBandLayout`, `CategoryRowWidget`
- **Responsibilities:** Fulfill the documented role of `category_list_view.dart` under `lib/features/categories`.
- **When to open:** When build output or maintenance cites `category_list_view.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/categories/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the categories area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `category_list_view.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/categories/category_list_view.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `category_list_view.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/categories/category_list_view.dart`.
- **Когда открывать:** Баг или доработка, связанная с `category_list_view.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/categories/category_recursive_tree.dart`

EN:

- **What this is:** Dart source `category_recursive_tree.dart` in `lib/features/categories` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/categories` needs `category_recursive_tree.dart` for build, CI, or documented workflow.
- **What it contains:** Open `category_recursive_tree.dart` when editing dart source for `lib/features/categories` (see folder section above).
- **Key code names:** `CategoryTreeSheetPicked`, `CategoryTreeSheetAll`, `CategoryFilterTreeField`
- **Responsibilities:** Fulfill the documented role of `category_recursive_tree.dart` under `lib/features/categories`.
- **When to open:** When build output or maintenance cites `category_recursive_tree.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/categories/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the categories area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `category_recursive_tree.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/categories/category_recursive_tree.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `category_recursive_tree.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/categories/category_recursive_tree.dart`.
- **Когда открывать:** Баг или доработка, связанная с `category_recursive_tree.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/categories/category_visibility_prefs.dart`

EN:

- **What this is:** Dart source `category_visibility_prefs.dart` in `lib/features/categories` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/categories` needs `category_visibility_prefs.dart` for build, CI, or documented workflow.
- **What it contains:** Open `category_visibility_prefs.dart` when editing dart source for `lib/features/categories` (see folder section above).
- **Key code names:** `CategoryVisibilityPrefs`
- **Responsibilities:** Fulfill the documented role of `category_visibility_prefs.dart` under `lib/features/categories`.
- **When to open:** When build output or maintenance cites `category_visibility_prefs.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/categories/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the categories area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `category_visibility_prefs.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/categories/category_visibility_prefs.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `category_visibility_prefs.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/categories/category_visibility_prefs.dart`.
- **Когда открывать:** Баг или доработка, связанная с `category_visibility_prefs.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/categories/create_category_dialog.dart`

EN:

- **What this is:** Dart source `create_category_dialog.dart` in `lib/features/categories` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/categories` needs `create_category_dialog.dart` for build, CI, or documented workflow.
- **What it contains:** Open `create_category_dialog.dart` when editing dart source for `lib/features/categories` (see folder section above).
- **Key code names:** `_CreateCategoryDialog`, `_CreateCategoryDialogState`
- **Responsibilities:** Fulfill the documented role of `create_category_dialog.dart` under `lib/features/categories`.
- **When to open:** When build output or maintenance cites `create_category_dialog.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/categories/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the categories area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `create_category_dialog.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/categories/create_category_dialog.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `create_category_dialog.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/categories/create_category_dialog.dart`.
- **Когда открывать:** Баг или доработка, связанная с `create_category_dialog.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/dev/component_lab_cards_demo.dart`

EN:

- **What this is:** Dart source `component_lab_cards_demo.dart` in `lib/features/dev` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/dev` needs `component_lab_cards_demo.dart` for build, CI, or documented workflow.
- **What it contains:** Open `component_lab_cards_demo.dart` when editing dart source for `lib/features/dev` (see folder section above).
- **Key code names:** `ComponentLabPlanCardsDemo`
- **Responsibilities:** Fulfill the documented role of `component_lab_cards_demo.dart` under `lib/features/dev`.
- **When to open:** When build output or maintenance cites `component_lab_cards_demo.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/dev/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the dev area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `component_lab_cards_demo.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/dev/component_lab_cards_demo.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `component_lab_cards_demo.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/dev/component_lab_cards_demo.dart`.
- **Когда открывать:** Баг или доработка, связанная с `component_lab_cards_demo.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/dev/component_lab_view.dart`

EN:

- **What this is:** Dart source `component_lab_view.dart` in `lib/features/dev` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/dev` needs `component_lab_view.dart` for build, CI, or documented workflow.
- **What it contains:** Open `component_lab_view.dart` when editing dart source for `lib/features/dev` (see folder section above).
- **Key code names:** `ComponentLabPage`, `_LabSection`, `_ButtonsDemo`
- **Responsibilities:** Fulfill the documented role of `component_lab_view.dart` under `lib/features/dev`.
- **When to open:** When build output or maintenance cites `component_lab_view.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/dev/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the dev area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `component_lab_view.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/dev/component_lab_view.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `component_lab_view.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/dev/component_lab_view.dart`.
- **Когда открывать:** Баг или доработка, связанная с `component_lab_view.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/lists/lists_bulk_actions.dart`

EN:

- **What this is:** UI code for Lists tab (fourth bottom tab): Select-mode header + bulk action bottom bar.
- **Why needed:** Users interact with this when using Lists tab (fourth bottom tab).
- **What it contains:** Flutter widgets (`ListsBulkSelectModeBar`, `ListsBulkBottomBar`) implementing the visible behavior.
- **Key code names:** `ListsBulkSelectModeBar`, `ListsBulkBottomBar`
- **Responsibilities:** Select-mode header + bulk action bottom bar
- **When to open:** Lists tab: filters, done checkbox, bulk actions, export.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Lists tab (shell index 3); Role: Select-mode header + bulk action bottom bar
- **Layer / owner:** UI code for the lists area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `lists_bulk_actions.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/lists/lists_bulk_actions.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `lists_bulk_actions.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/lists/lists_bulk_actions.dart`.
- **Когда открывать:** Баг или доработка, связанная с `lists_bulk_actions.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/lists/lists_card.dart`

EN:

- **What this is:** UI code for Lists tab (fourth bottom tab): , filter chips, semicircle menu.
- **Why needed:** Users interact with this when using Lists tab (fourth bottom tab).
- **What it contains:** Flutter widgets (`ListsQuadraticChip`, `BacklogPlanCard`) implementing the visible behavior.
- **Key code names:** `ListsQuadraticChip`, `BacklogPlanCard`
- **Responsibilities:** `BacklogPlanCard`, filter chips, semicircle menu
- **When to open:** Lists tab: filters, done checkbox, bulk actions, export.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Lists tab (shell index 3); Role: `BacklogPlanCard`, filter chips, semicircle menu
- **Layer / owner:** UI code for the lists area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `lists_card.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/lists/lists_card.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `lists_card.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/lists/lists_card.dart`.
- **Когда открывать:** Баг или доработка, связанная с `lists_card.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/lists/lists_empty_state.dart`

EN:

- **What this is:** UI code for Lists tab (fourth bottom tab): Loading / filtered / no-category empty panels.
- **Why needed:** Users interact with this when using Lists tab (fourth bottom tab).
- **What it contains:** Flutter widgets (`ListsNoCategoryEmptyPanel`, `ListsFilteredEmptyPanel`, `ListsLoadingPanel`) implementing the visible behavior.
- **Key code names:** `ListsNoCategoryEmptyPanel`, `ListsFilteredEmptyPanel`, `ListsLoadingPanel`
- **Responsibilities:** Loading / filtered / no-category empty panels
- **When to open:** Lists tab: filters, done checkbox, bulk actions, export.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Lists tab (shell index 3); Role: Loading / filtered / no-category empty panels
- **Layer / owner:** UI code for the lists area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `lists_empty_state.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/lists/lists_empty_state.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `lists_empty_state.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/lists/lists_empty_state.dart`.
- **Когда открывать:** Баг или доработка, связанная с `lists_empty_state.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/lists/lists_export.dart`

EN:

- **What this is:** UI code for Lists tab (fourth bottom tab): Export visible list as clipboard text.
- **Why needed:** Users interact with this when using Lists tab (fourth bottom tab).
- **What it contains:** Flutter widgets (implementation details in the source file) implementing the visible behavior.
- **Responsibilities:** Export visible list as clipboard text
- **When to open:** Lists tab: filters, done checkbox, bulk actions, export.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Lists tab (shell index 3); Role: Export visible list as clipboard text
- **Layer / owner:** UI code for the lists area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `lists_export.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/lists/lists_export.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `lists_export.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/lists/lists_export.dart`.
- **Когда открывать:** Баг или доработка, связанная с `lists_export.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/lists/lists_filters.dart`

EN:

- **What this is:** UI code for Lists tab (fourth bottom tab): Tag/category filter chips, chip bar, settings sheet.
- **Why needed:** Users interact with this when using Lists tab (fourth bottom tab).
- **What it contains:** Flutter widgets (`ListsTagFilterChip`, `ListsCategoryChipBar`, `ListsTagFilterBar`) implementing the visible behavior.
- **Key code names:** `ListsTagFilterChip`, `ListsCategoryChipBar`, `ListsTagFilterBar`
- **Responsibilities:** Tag/category filter chips, chip bar, settings sheet
- **When to open:** Lists tab: filters, done checkbox, bulk actions, export.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Lists tab (shell index 3); Role: Tag/category filter chips, chip bar, settings sheet
- **Layer / owner:** UI code for the lists area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `lists_filters.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/lists/lists_filters.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `lists_filters.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/lists/lists_filters.dart`.
- **Когда открывать:** Баг или доработка, связанная с `lists_filters.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/lists/lists_inline_add.dart`

EN:

- **What this is:** UI code for Lists tab (fourth bottom tab): Inline quick-add input row.
- **Why needed:** Users interact with this when using Lists tab (fourth bottom tab).
- **What it contains:** Flutter widgets (`ListsInlineAddRow`) implementing the visible behavior.
- **Key code names:** `ListsInlineAddRow`
- **Responsibilities:** Inline quick-add input row
- **When to open:** Lists tab: filters, done checkbox, bulk actions, export.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Lists tab (shell index 3); Role: Inline quick-add input row
- **Layer / owner:** UI code for the lists area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `lists_inline_add.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/lists/lists_inline_add.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `lists_inline_add.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/lists/lists_inline_add.dart`.
- **Когда открывать:** Баг или доработка, связанная с `lists_inline_add.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/lists/lists_view.dart`

EN:

- **What this is:** Dart source `lists_view.dart` in `lib/features/lists` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/lists` needs `lists_view.dart` for build, CI, or documented workflow.
- **What it contains:** Open `lists_view.dart` when editing dart source for `lib/features/lists` (see folder section above).
- **Key code names:** `ListsPage`, `_ListsPageState`
- **Responsibilities:** Fulfill the documented role of `lists_view.dart` under `lib/features/lists`.
- **When to open:** When build output or maintenance cites `lists_view.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/lists/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the lists area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `lists_view.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/lists/lists_view.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `lists_view.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/lists/lists_view.dart`.
- **Когда открывать:** Баг или доработка, связанная с `lists_view.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/bulk_planning_edit_sheet.dart`

EN:

- **What this is:** Dart source `bulk_planning_edit_sheet.dart` in `lib/features/planning` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/planning` needs `bulk_planning_edit_sheet.dart` for build, CI, or documented workflow.
- **What it contains:** Open `bulk_planning_edit_sheet.dart` when editing dart source for `lib/features/planning` (see folder section above).
- **Key code names:** `BulkPlanningEditResult`, `BulkEditWallTimes`, `_BulkPlanningEditSheetBody`, `_BulkPlanningEditSheetBodyState`
- **Responsibilities:** Fulfill the documented role of `bulk_planning_edit_sheet.dart` under `lib/features/planning`.
- **When to open:** When build output or maintenance cites `bulk_planning_edit_sheet.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/planning/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `bulk_planning_edit_sheet.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/bulk_planning_edit_sheet.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `bulk_planning_edit_sheet.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/bulk_planning_edit_sheet.dart`.
- **Когда открывать:** Баг или доработка, связанная с `bulk_planning_edit_sheet.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/plan_time_gesture_contract.dart`

EN:

- **What this is:** Dart source `plan_time_gesture_contract.dart` in `lib/features/planning` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/planning` needs `plan_time_gesture_contract.dart` for build, CI, or documented workflow.
- **What it contains:** Open `plan_time_gesture_contract.dart` when editing dart source for `lib/features/planning` (see folder section above).
- **Responsibilities:** Fulfill the documented role of `plan_time_gesture_contract.dart` under `lib/features/planning`.
- **When to open:** When build output or maintenance cites `plan_time_gesture_contract.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/planning/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `plan_time_gesture_contract.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/plan_time_gesture_contract.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_time_gesture_contract.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/plan_time_gesture_contract.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_time_gesture_contract.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/plan_time_view_layout.dart`

EN:

- **What this is:** Dart source `plan_time_view_layout.dart` in `lib/features/planning` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/planning` needs `plan_time_view_layout.dart` for build, CI, or documented workflow.
- **What it contains:** Open `plan_time_view_layout.dart` when editing dart source for `lib/features/planning` (see folder section above).
- **Key code names:** `TimeViewYScale`, `PlanTimeViewDurationGrid`, `PlanTimeViewBlockLayout`, `_PlanTimeViewCardSlot`
- **Responsibilities:** Fulfill the documented role of `plan_time_view_layout.dart` under `lib/features/planning`.
- **When to open:** When build output or maintenance cites `plan_time_view_layout.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/planning/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `plan_time_view_layout.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/plan_time_view_layout.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_time_view_layout.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/plan_time_view_layout.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_time_view_layout.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/planning_day_start_prefs.dart`

EN:

- **What this is:** Dart source `planning_day_start_prefs.dart` in `lib/features/planning` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/planning` needs `planning_day_start_prefs.dart` for build, CI, or documented workflow.
- **What it contains:** Open `planning_day_start_prefs.dart` when editing dart source for `lib/features/planning` (see folder section above).
- **Key code names:** `PlanningSheetTimelinePrefs`
- **Responsibilities:** Fulfill the documented role of `planning_day_start_prefs.dart` under `lib/features/planning`.
- **When to open:** When build output or maintenance cites `planning_day_start_prefs.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/planning/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_day_start_prefs.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/planning_day_start_prefs.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_day_start_prefs.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/planning_day_start_prefs.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_day_start_prefs.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/planning_page.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Time View state machine + day body.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningPage`) implementing the visible behavior.
- **Key code names:** `PlanningPage`
- **Responsibilities:** Time View state machine + day body; further split needs UX/product scope
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Time View state machine + day body; further split needs UX/product scope
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_page.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/planning_page.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_page.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/planning_page.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_page.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/planning_page_shell.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): date pager.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningSwipeWrapper`, `_PlanningSwipeWrapperState`) implementing the visible behavior.
- **Key code names:** `PlanningSwipeWrapper`, `_PlanningSwipeWrapperState`
- **Responsibilities:** `PlanningSwipeWrapper` date pager
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: `PlanningSwipeWrapper` date pager
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_page_shell.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/planning_page_shell.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_page_shell.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/planning_page_shell.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_page_shell.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/planning_sort_mode.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): + persist index helpers.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanSortMode`) implementing the visible behavior.
- **Key code names:** `PlanSortMode`
- **Responsibilities:** `PlanSortMode` + persist index helpers
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: `PlanSortMode` + persist index helpers
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_sort_mode.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/planning_sort_mode.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_sort_mode.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/planning_sort_mode.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_sort_mode.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/planning_view.dart`

EN:

- **What this is:** Dart source `planning_view.dart` in `lib/features/planning` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/planning` needs `planning_view.dart` for build, CI, or documented workflow.
- **What it contains:** Open `planning_view.dart` when editing dart source for `lib/features/planning` (see folder section above).
- **Responsibilities:** Fulfill the documented role of `planning_view.dart` under `lib/features/planning`.
- **When to open:** When build output or maintenance cites `planning_view.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/planning/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_view.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/planning_view.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_view.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/planning_view.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_view.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/recurrence_scope_dialog.dart`

EN:

- **What this is:** Dart source `recurrence_scope_dialog.dart` in `lib/features/planning` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/planning` needs `recurrence_scope_dialog.dart` for build, CI, or documented workflow.
- **What it contains:** Open `recurrence_scope_dialog.dart` when editing dart source for `lib/features/planning` (see folder section above).
- **Responsibilities:** Fulfill the documented role of `recurrence_scope_dialog.dart` under `lib/features/planning`.
- **When to open:** When build output or maintenance cites `recurrence_scope_dialog.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/planning/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `recurrence_scope_dialog.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/recurrence_scope_dialog.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `recurrence_scope_dialog.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/recurrence_scope_dialog.dart`.
- **Когда открывать:** Баг или доработка, связанная с `recurrence_scope_dialog.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/settings/default_plan_category_search.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Default plan category search delegate.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`DefaultPlanCategorySearchDelegate`) implementing the visible behavior.
- **Key code names:** `DefaultPlanCategorySearchDelegate`
- **Responsibilities:** Default plan category search delegate
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Default plan category search delegate
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `default_plan_category_search.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/settings/default_plan_category_search.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `default_plan_category_search.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/settings/default_plan_category_search.dart`.
- **Когда открывать:** Баг или доработка, связанная с `default_plan_category_search.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/settings/default_plan_timezone_search.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Default plan TZ search delegate.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (implementation details in the source file) implementing the visible behavior.
- **Responsibilities:** Default plan TZ search delegate
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Default plan TZ search delegate
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `default_plan_timezone_search.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/settings/default_plan_timezone_search.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `default_plan_timezone_search.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/settings/default_plan_timezone_search.dart`.
- **Когда открывать:** Баг или доработка, связанная с `default_plan_timezone_search.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/settings/plan_record_link_settings.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Record→plan suggestion prefs.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanRecordLinkSuggestionSettingsBlock`, `PlanRecordLinkSuggestionSettingsBlockState`) implementing the visible behavior.
- **Key code names:** `PlanRecordLinkSuggestionSettingsBlock`, `PlanRecordLinkSuggestionSettingsBlockState`
- **Responsibilities:** Record→plan suggestion prefs
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Record→plan suggestion prefs
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `plan_record_link_settings.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/settings/plan_record_link_settings.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_record_link_settings.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/settings/plan_record_link_settings.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_record_link_settings.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/settings/planning_no_tags_settings.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Synthetic “No Tags” chip prefs.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningNoTagsSettingsBlock`, `PlanningNoTagsSettingsBlockState`) implementing the visible behavior.
- **Key code names:** `PlanningNoTagsSettingsBlock`, `PlanningNoTagsSettingsBlockState`
- **Responsibilities:** Synthetic “No Tags” chip prefs
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Synthetic “No Tags” chip prefs
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_no_tags_settings.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/settings/planning_no_tags_settings.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_no_tags_settings.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/settings/planning_no_tags_settings.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_no_tags_settings.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/settings/planning_timeline_bounds_sheet.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Visible hour range slider sheet.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningTimelineBoundsSheet`, `PlanningTimelineBoundsSheetState`) implementing the visible behavior.
- **Key code names:** `PlanningTimelineBoundsSheet`, `PlanningTimelineBoundsSheetState`
- **Responsibilities:** Visible hour range slider sheet
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Visible hour range slider sheet
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_timeline_bounds_sheet.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/settings/planning_timeline_bounds_sheet.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_timeline_bounds_sheet.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/settings/planning_timeline_bounds_sheet.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_timeline_bounds_sheet.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/smart_plan_sheet.dart`

EN:

- **What this is:** Dart source `smart_plan_sheet.dart` in `lib/features/planning` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/planning` needs `smart_plan_sheet.dart` for build, CI, or documented workflow.
- **What it contains:** Open `smart_plan_sheet.dart` when editing dart source for `lib/features/planning` (see folder section above).
- **Key code names:** `SmartPlanCommit`, `SmartPlanSheet`, `_SmartPlanSheetState`
- **Responsibilities:** Fulfill the documented role of `smart_plan_sheet.dart` under `lib/features/planning`.
- **When to open:** When build output or maintenance cites `smart_plan_sheet.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/planning/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `smart_plan_sheet.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/smart_plan_sheet.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `smart_plan_sheet.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/smart_plan_sheet.dart`.
- **Когда открывать:** Баг или доработка, связанная с `smart_plan_sheet.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/time_view/planning_time_view.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Time View composition, cascade, edge scroll.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningTimeViewPlanningTimeView`) implementing the visible behavior.
- **Key code names:** `PlanningTimeViewPlanningTimeView`
- **Responsibilities:** Time View composition, cascade, edge scroll
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Time View composition, cascade, edge scroll
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_time_view.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/time_view/planning_time_view.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_time_view.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/time_view/planning_time_view.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_time_view.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/time_view/planning_time_view_coordinator.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Time View state fields.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningTimeViewCoordinator`) implementing the visible behavior.
- **Key code names:** `PlanningTimeViewCoordinator`
- **Responsibilities:** Time View state fields
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Time View state fields
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_time_view_coordinator.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/time_view/planning_time_view_coordinator.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_time_view_coordinator.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/time_view/planning_time_view_coordinator.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_time_view_coordinator.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/time_view/planning_time_view_host.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): callback surface.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (implementation details in the source file) implementing the visible behavior.
- **Responsibilities:** `PlanningTimeViewHost` callback surface
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: `PlanningTimeViewHost` callback surface
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_time_view_host.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/time_view/planning_time_view_host.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_time_view_host.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/time_view/planning_time_view_host.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_time_view_host.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/time_view/time_view_canvas.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Proportional day timeline canvas.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningTimeViewTimeViewCanvas`) implementing the visible behavior.
- **Key code names:** `PlanningTimeViewTimeViewCanvas`
- **Responsibilities:** Proportional day timeline canvas
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Proportional day timeline canvas
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `time_view_canvas.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/time_view/time_view_canvas.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `time_view_canvas.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/time_view/time_view_canvas.dart`.
- **Когда открывать:** Баг или доработка, связанная с `time_view_canvas.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/time_view/time_view_card_layer.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Scheduled card stack layer.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningTimeViewTimeViewCardLayer`) implementing the visible behavior.
- **Key code names:** `PlanningTimeViewTimeViewCardLayer`
- **Responsibilities:** Scheduled card stack layer
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Scheduled card stack layer
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `time_view_card_layer.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/time_view/time_view_card_layer.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `time_view_card_layer.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/time_view/time_view_card_layer.dart`.
- **Когда открывать:** Баг или доработка, связанная с `time_view_card_layer.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/time_view/time_view_drag_controller.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Vertical drag state/helpers.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningTimeViewTimeViewDragController`) implementing the visible behavior.
- **Key code names:** `PlanningTimeViewTimeViewDragController`
- **Responsibilities:** Vertical drag state/helpers
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Vertical drag state/helpers
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `time_view_drag_controller.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/time_view/time_view_drag_controller.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `time_view_drag_controller.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/time_view/time_view_drag_controller.dart`.
- **Когда открывать:** Баг или доработка, связанная с `time_view_drag_controller.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/time_view/time_view_drag_state.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): , gesture phase enums.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`TimelineResizeEdge`, `TimelinePointerGesturePhase`) implementing the visible behavior.
- **Key code names:** `TimelineResizeEdge`, `TimelinePointerGesturePhase`
- **Responsibilities:** `TimelineResizeEdge`, gesture phase enums
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: `TimelineResizeEdge`, gesture phase enums
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `time_view_drag_state.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/time_view/time_view_drag_state.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `time_view_drag_state.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/time_view/time_view_drag_state.dart`.
- **Когда открывать:** Баг или доработка, связанная с `time_view_drag_state.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/time_view/time_view_drop_preview.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Drop intent / cascade preview.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningTimeViewTimeViewDropPreview`) implementing the visible behavior.
- **Key code names:** `PlanningTimeViewTimeViewDropPreview`
- **Responsibilities:** Drop intent / cascade preview
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Drop intent / cascade preview
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `time_view_drop_preview.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/time_view/time_view_drop_preview.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `time_view_drop_preview.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/time_view/time_view_drop_preview.dart`.
- **Когда открывать:** Баг или доработка, связанная с `time_view_drop_preview.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/time_view/time_view_fixed_time_settings.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Fixed-time tag chip settings block.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`TimeViewFixedTagsSettingsBlock`, `TimeViewFixedTagsSettingsBlockState`) implementing the visible behavior.
- **Key code names:** `TimeViewFixedTagsSettingsBlock`, `TimeViewFixedTagsSettingsBlockState`
- **Responsibilities:** Fixed-time tag chip settings block
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Fixed-time tag chip settings block
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `time_view_fixed_time_settings.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/time_view/time_view_fixed_time_settings.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `time_view_fixed_time_settings.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/time_view/time_view_fixed_time_settings.dart`.
- **Когда открывать:** Баг или доработка, связанная с `time_view_fixed_time_settings.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/time_view/time_view_hour_grid.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Hour grid + unscheduled strip.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningTimeViewTimeViewHourGrid`) implementing the visible behavior.
- **Key code names:** `PlanningTimeViewTimeViewHourGrid`
- **Responsibilities:** Hour grid + unscheduled strip
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Hour grid + unscheduled strip
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `time_view_hour_grid.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/time_view/time_view_hour_grid.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `time_view_hour_grid.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/time_view/time_view_hour_grid.dart`.
- **Когда открывать:** Баг или доработка, связанная с `time_view_hour_grid.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/time_view/time_view_interaction_block.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Time View card pointer/drag/resize zones.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`TimelinePlanInteractionBlock`, `TimelinePlanInteractionBlockState`) implementing the visible behavior.
- **Key code names:** `TimelinePlanInteractionBlock`, `TimelinePlanInteractionBlockState`
- **Responsibilities:** Time View card pointer/drag/resize zones
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Time View card pointer/drag/resize zones
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `time_view_interaction_block.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/time_view/time_view_interaction_block.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `time_view_interaction_block.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/time_view/time_view_interaction_block.dart`.
- **Когда открывать:** Баг или доработка, связанная с `time_view_interaction_block.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/time_view/time_view_resize_controller.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Edge resize state/helpers.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningTimeViewTimeViewResizeController`) implementing the visible behavior.
- **Key code names:** `PlanningTimeViewTimeViewResizeController`
- **Responsibilities:** Edge resize state/helpers
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Edge resize state/helpers
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `time_view_resize_controller.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/time_view/time_view_resize_controller.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `time_view_resize_controller.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/time_view/time_view_resize_controller.dart`.
- **Когда открывать:** Баг или доработка, связанная с `time_view_resize_controller.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/time_view/time_view_search_delegate.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Category default-time search UI.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningTimeViewTimeViewSearchDelegate`) implementing the visible behavior.
- **Key code names:** `PlanningTimeViewTimeViewSearchDelegate`
- **Responsibilities:** Category default-time search UI
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Category default-time search UI
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `time_view_search_delegate.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/time_view/time_view_search_delegate.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `time_view_search_delegate.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/time_view/time_view_search_delegate.dart`.
- **Когда открывать:** Баг или доработка, связанная с `time_view_search_delegate.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/time_view/time_view_settings_sheet.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Time View settings + default plan times.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningTimeViewTimeViewSettingsSheet`) implementing the visible behavior.
- **Key code names:** `PlanningTimeViewTimeViewSettingsSheet`
- **Responsibilities:** Time View settings + default plan times
- **When to open:** Time View visual schedule: drag, resize, hour grid, card placement.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Time View settings + default plan times
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `time_view_settings_sheet.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/time_view/time_view_settings_sheet.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `time_view_settings_sheet.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/time_view/time_view_settings_sheet.dart`.
- **Когда открывать:** Баг или доработка, связанная с `time_view_settings_sheet.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/widgets/plan_card_reorder_settle.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Done-card reorder slide settle.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanCardReorderSettle`, `PlanCardReorderSettleState`) implementing the visible behavior.
- **Key code names:** `PlanCardReorderSettle`, `PlanCardReorderSettleState`
- **Responsibilities:** Done-card reorder slide settle
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Done-card reorder slide settle
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `plan_card_reorder_settle.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/widgets/plan_card_reorder_settle.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_card_reorder_settle.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/widgets/plan_card_reorder_settle.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_card_reorder_settle.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/widgets/planning_bulk_bar.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Bulk selection bottom bar.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningBulkBottomBar`) implementing the visible behavior.
- **Key code names:** `PlanningBulkBottomBar`
- **Responsibilities:** Bulk selection bottom bar
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Bulk selection bottom bar
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_bulk_bar.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/widgets/planning_bulk_bar.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_bulk_bar.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/widgets/planning_bulk_bar.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_bulk_bar.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/widgets/planning_day_card_list_keep_alive.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): List keep-alive wrapper.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningDayCardListKeepAliveState`) implementing the visible behavior.
- **Key code names:** `PlanningDayCardListKeepAliveState`
- **Responsibilities:** List keep-alive wrapper
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: List keep-alive wrapper
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_day_card_list_keep_alive.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/widgets/planning_day_card_list_keep_alive.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_day_card_list_keep_alive.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/widgets/planning_day_card_list_keep_alive.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_day_card_list_keep_alive.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/widgets/planning_empty_states.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Planning empty-state widgets.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningDayEmptyState`, `PlanningFrozenListEmptyState`) implementing the visible behavior.
- **Key code names:** `PlanningDayEmptyState`, `PlanningFrozenListEmptyState`
- **Responsibilities:** Planning empty-state widgets
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Planning empty-state widgets
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_empty_states.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/widgets/planning_empty_states.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_empty_states.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/widgets/planning_empty_states.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_empty_states.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/widgets/planning_filter_controls.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Sort-mode segmented control.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningSortModeBar`) implementing the visible behavior.
- **Key code names:** `PlanningSortModeBar`
- **Responsibilities:** Sort-mode segmented control
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Sort-mode segmented control
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_filter_controls.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/widgets/planning_filter_controls.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_filter_controls.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/widgets/planning_filter_controls.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_filter_controls.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/widgets/planning_list_helpers.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Reorder list proxy decorator.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (implementation details in the source file) implementing the visible behavior.
- **Responsibilities:** Reorder list proxy decorator
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Reorder list proxy decorator
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_list_helpers.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/widgets/planning_list_helpers.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_list_helpers.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/widgets/planning_list_helpers.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_list_helpers.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/widgets/planning_menu_overlay.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Semicircle plan card radial menu.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`SemicirclePlanningMenuOverlay`, `SemicirclePlanningMenuOverlayState`) implementing the visible behavior.
- **Key code names:** `SemicirclePlanningMenuOverlay`, `SemicirclePlanningMenuOverlayState`
- **Responsibilities:** Semicircle plan card radial menu
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Semicircle plan card radial menu
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_menu_overlay.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/widgets/planning_menu_overlay.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_menu_overlay.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/widgets/planning_menu_overlay.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_menu_overlay.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/planning/widgets/planning_quick_add_strip.dart`

EN:

- **What this is:** UI code for Plans tab (second bottom tab): Quick-add tag strip above inline task field.
- **Why needed:** Users interact with this when using Plans tab (second bottom tab).
- **What it contains:** Flutter widgets (`PlanningQuickAddTagStrip`) implementing the visible behavior.
- **Key code names:** `PlanningQuickAddTagStrip`
- **Responsibilities:** Quick-add tag strip above inline task field
- **When to open:** Plans tab: day swipe, plan cards, play/start plan, bulk edit.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Plans tab (shell index 1); Role: Quick-add tag strip above inline task field
- **Layer / owner:** UI code for the planning area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_quick_add_strip.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/planning/widgets/planning_quick_add_strip.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_quick_add_strip.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/planning/widgets/planning_quick_add_strip.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_quick_add_strip.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/profile/desktop_voice_attempt_dialog.dart`

EN:

- **What this is:** Dart source `desktop_voice_attempt_dialog.dart` in `lib/features/profile` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/profile` needs `desktop_voice_attempt_dialog.dart` for build, CI, or documented workflow.
- **What it contains:** Open `desktop_voice_attempt_dialog.dart` when editing dart source for `lib/features/profile` (see folder section above).
- **Key code names:** `DesktopVoiceAttemptCopyFn`, `DesktopVoiceAttemptDialogTestHooks`, `_DesktopVoiceAttemptDialog`, `_DesktopVoiceAttemptDialogState`, `_AttemptView`
- **Responsibilities:** Fulfill the documented role of `desktop_voice_attempt_dialog.dart` under `lib/features/profile`.
- **When to open:** When build output or maintenance cites `desktop_voice_attempt_dialog.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/profile/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `desktop_voice_attempt_dialog.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/profile/desktop_voice_attempt_dialog.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_attempt_dialog.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/profile/desktop_voice_attempt_dialog.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_attempt_dialog.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/profile/desktop_voice_settings_desktop.dart`

EN:

- **What this is:** Dart source `desktop_voice_settings_desktop.dart` in `lib/features/profile` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/profile` needs `desktop_voice_settings_desktop.dart` for build, CI, or documented workflow.
- **What it contains:** Open `desktop_voice_settings_desktop.dart` when editing dart source for `lib/features/profile` (see folder section above).
- **Key code names:** `DesktopVoiceSettingsDesktopGrid`, `_DesktopVoiceSettingsDesktopGridState`
- **Responsibilities:** Fulfill the documented role of `desktop_voice_settings_desktop.dart` under `lib/features/profile`.
- **When to open:** When build output or maintenance cites `desktop_voice_settings_desktop.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/profile/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `desktop_voice_settings_desktop.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/profile/desktop_voice_settings_desktop.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_settings_desktop.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/profile/desktop_voice_settings_desktop.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_settings_desktop.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/profile/desktop_voice_settings_section.dart`

EN:

- **What this is:** Dart source `desktop_voice_settings_section.dart` in `lib/features/profile` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/profile` needs `desktop_voice_settings_section.dart` for build, CI, or documented workflow.
- **What it contains:** Open `desktop_voice_settings_section.dart` when editing dart source for `lib/features/profile` (see folder section above).
- **Key code names:** `DesktopVoiceSettingsSection`, `_DesktopVoiceSettingsSectionState`
- **Responsibilities:** Fulfill the documented role of `desktop_voice_settings_section.dart` under `lib/features/profile`.
- **When to open:** When build output or maintenance cites `desktop_voice_settings_section.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/profile/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `desktop_voice_settings_section.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/profile/desktop_voice_settings_section.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_settings_section.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/profile/desktop_voice_settings_section.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_settings_section.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/profile/profile_view.dart`

EN:

- **What this is:** Dart source `profile_view.dart` in `lib/features/profile` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/profile` needs `profile_view.dart` for build, CI, or documented workflow.
- **What it contains:** Open `profile_view.dart` when editing dart source for `lib/features/profile` (see folder section above).
- **Key code names:** `ProfilePage`, `_ProfilePageState`
- **Responsibilities:** Fulfill the documented role of `profile_view.dart` under `lib/features/profile`.
- **When to open:** When build output or maintenance cites `profile_view.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/profile/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `profile_view.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/profile/profile_view.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `profile_view.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/profile/profile_view.dart`.
- **Когда открывать:** Баг или доработка, связанная с `profile_view.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/profile/settings/account_settings_section.dart`

EN:

- **What this is:** UI code for More → Profile and settings: Signed-in identity + logout row.
- **Why needed:** Users interact with this when using More → Profile and settings.
- **What it contains:** Flutter widgets (`AccountSecuritySection`) implementing the visible behavior.
- **Key code names:** `AccountSecuritySection`
- **Responsibilities:** Signed-in identity + logout row
- **When to open:** When behavior tied to `account_settings_section.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Signed-in identity + logout row
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `account_settings_section.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/profile/settings/account_settings_section.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `account_settings_section.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/profile/settings/account_settings_section.dart`.
- **Когда открывать:** Баг или доработка, связанная с `account_settings_section.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/profile/settings/notification_settings_section.dart`

EN:

- **What this is:** UI code for More → Profile and settings: OS notification permission block.
- **Why needed:** Users interact with this when using More → Profile and settings.
- **What it contains:** Flutter widgets (`ProfileNotificationsSection`, `ProfileNotificationsSectionState`) implementing the visible behavior.
- **Key code names:** `ProfileNotificationsSection`, `ProfileNotificationsSectionState`
- **Responsibilities:** OS notification permission block
- **When to open:** When behavior tied to `notification_settings_section.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: OS notification permission block
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `notification_settings_section.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/profile/settings/notification_settings_section.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `notification_settings_section.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/profile/settings/notification_settings_section.dart`.
- **Когда открывать:** Баг или доработка, связанная с `notification_settings_section.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/profile/settings/security_settings_section.dart`

EN:

- **What this is:** UI code for More → Profile and settings: Password reset + biometric lock.
- **Why needed:** Users interact with this when using More → Profile and settings.
- **What it contains:** Flutter widgets (`SecuritySection`, `SecuritySectionState`) implementing the visible behavior.
- **Key code names:** `SecuritySection`, `SecuritySectionState`
- **Responsibilities:** Password reset + biometric lock
- **When to open:** When behavior tied to `security_settings_section.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Password reset + biometric lock
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `security_settings_section.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/profile/settings/security_settings_section.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `security_settings_section.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/profile/settings/security_settings_section.dart`.
- **Когда открывать:** Баг или доработка, связанная с `security_settings_section.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/profile/settings/settings_page.dart`

EN:

- **What this is:** UI code for More → Profile and settings: Language/TZ settings page (shell route).
- **Why needed:** Users interact with this when using More → Profile and settings.
- **What it contains:** Flutter widgets (implementation details in the source file) implementing the visible behavior.
- **Responsibilities:** Language/TZ settings page (shell route)
- **When to open:** When behavior tied to `settings_page.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Language/TZ settings page (shell route)
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `settings_page.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/profile/settings/settings_page.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `settings_page.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/profile/settings/settings_page.dart`.
- **Когда открывать:** Баг или доработка, связанная с `settings_page.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/profile/tag_default_duration_settings_view.dart`

EN:

- **What this is:** Dart source `tag_default_duration_settings_view.dart` in `lib/features/profile` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/profile` needs `tag_default_duration_settings_view.dart` for build, CI, or documented workflow.
- **What it contains:** Open `tag_default_duration_settings_view.dart` when editing dart source for `lib/features/profile` (see folder section above).
- **Key code names:** `TagDefaultDurationSettingsView`, `_TagDefaultDurationSettingsViewState`
- **Responsibilities:** Fulfill the documented role of `tag_default_duration_settings_view.dart` under `lib/features/profile`.
- **When to open:** When build output or maintenance cites `tag_default_duration_settings_view.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/profile/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `tag_default_duration_settings_view.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/profile/tag_default_duration_settings_view.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `tag_default_duration_settings_view.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/profile/tag_default_duration_settings_view.dart`.
- **Когда открывать:** Баг или доработка, связанная с `tag_default_duration_settings_view.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/profile/tag_manager_page.dart`

EN:

- **What this is:** Dart source `tag_manager_page.dart` in `lib/features/profile` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/profile` needs `tag_manager_page.dart` for build, CI, or documented workflow.
- **What it contains:** Open `tag_manager_page.dart` when editing dart source for `lib/features/profile` (see folder section above).
- **Key code names:** `TagManagerPage`, `_TagManagerPageState`
- **Responsibilities:** Fulfill the documented role of `tag_manager_page.dart` under `lib/features/profile`.
- **When to open:** When build output or maintenance cites `tag_manager_page.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/profile/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `tag_manager_page.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/profile/tag_manager_page.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `tag_manager_page.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/profile/tag_manager_page.dart`.
- **Когда открывать:** Баг или доработка, связанная с `tag_manager_page.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/profile/tag_settings_hub.dart`

EN:

- **What this is:** Dart source `tag_settings_hub.dart` in `lib/features/profile` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/profile` needs `tag_settings_hub.dart` for build, CI, or documented workflow.
- **What it contains:** Open `tag_settings_hub.dart` when editing dart source for `lib/features/profile` (see folder section above).
- **Key code names:** `TagSettingsHub`, `_TagSettingsHubState`
- **Responsibilities:** Fulfill the documented role of `tag_settings_hub.dart` under `lib/features/profile`.
- **When to open:** When build output or maintenance cites `tag_settings_hub.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/profile/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `tag_settings_hub.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/profile/tag_settings_hub.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `tag_settings_hub.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/profile/tag_settings_hub.dart`.
- **Когда открывать:** Баг или доработка, связанная с `tag_settings_hub.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/profile/tag_settings_view.dart`

EN:

- **What this is:** Dart source `tag_settings_view.dart` in `lib/features/profile` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/profile` needs `tag_settings_view.dart` for build, CI, or documented workflow.
- **What it contains:** Open `tag_settings_view.dart` when editing dart source for `lib/features/profile` (see folder section above).
- **Key code names:** `TagSettingsView`, `_TagSettingsViewState`
- **Responsibilities:** Fulfill the documented role of `tag_settings_view.dart` under `lib/features/profile`.
- **When to open:** When build output or maintenance cites `tag_settings_view.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/profile/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `tag_settings_view.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/profile/tag_settings_view.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `tag_settings_view.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/profile/tag_settings_view.dart`.
- **Когда открывать:** Баг или доработка, связанная с `tag_settings_view.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/profile/timezone_settings.dart`

EN:

- **What this is:** Dart source `timezone_settings.dart` in `lib/features/profile` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/profile` needs `timezone_settings.dart` for build, CI, or documented workflow.
- **What it contains:** Open `timezone_settings.dart` when editing dart source for `lib/features/profile` (see folder section above).
- **Key code names:** `TimezoneOption`
- **Responsibilities:** Fulfill the documented role of `timezone_settings.dart` under `lib/features/profile`.
- **When to open:** When build output or maintenance cites `timezone_settings.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/profile/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the profile area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `timezone_settings.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/profile/timezone_settings.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `timezone_settings.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/profile/timezone_settings.dart`.
- **Когда открывать:** Баг или доработка, связанная с `timezone_settings.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/activity_detail_sheet.dart`

EN:

- **What this is:** UI code for edit sheets and voice UI on every tab: Edit sheet router (`ActivityDetailKind`).
- **Why needed:** Users interact with this when using edit sheets and voice UI on every tab.
- **What it contains:** Flutter widgets (`ActivityDetailKind`, `ActivityDetailSheet`) implementing the visible behavior.
- **Key code names:** `ActivityDetailKind`, `ActivityDetailSheet`
- **Responsibilities:** Edit sheet router (`ActivityDetailKind`)
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Edit sheet router (`ActivityDetailKind`)
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `activity_detail_sheet.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/activity_detail_sheet.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `activity_detail_sheet.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/activity_detail_sheet.dart`.
- **Когда открывать:** Баг или доработка, связанная с `activity_detail_sheet.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/desktop_voice_capsule.dart`

EN:

- **What this is:** Dart source `desktop_voice_capsule.dart` in `lib/features/shared` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/shared` needs `desktop_voice_capsule.dart` for build, CI, or documented workflow.
- **What it contains:** Open `desktop_voice_capsule.dart` when editing dart source for `lib/features/shared` (see folder section above).
- **Key code names:** `DesktopVoiceCapsule`, `_LeadingIcon`
- **Responsibilities:** Fulfill the documented role of `desktop_voice_capsule.dart` under `lib/features/shared`.
- **When to open:** When build output or maintenance cites `desktop_voice_capsule.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/shared/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `desktop_voice_capsule.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/desktop_voice_capsule.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_capsule.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/desktop_voice_capsule.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_capsule.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/desktop_voice_command_panel.dart`

EN:

- **What this is:** Dart source `desktop_voice_command_panel.dart` in `lib/features/shared` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/shared` needs `desktop_voice_command_panel.dart` for build, CI, or documented workflow.
- **What it contains:** Open `desktop_voice_command_panel.dart` when editing dart source for `lib/features/shared` (see folder section above).
- **Key code names:** `_DesktopVoicePanelPhase`, `DesktopVoiceCommandPanel`, `_DesktopVoiceCommandPanelState`
- **Responsibilities:** Fulfill the documented role of `desktop_voice_command_panel.dart` under `lib/features/shared`.
- **When to open:** When build output or maintenance cites `desktop_voice_command_panel.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/shared/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `desktop_voice_command_panel.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/desktop_voice_command_panel.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_command_panel.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/desktop_voice_command_panel.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_command_panel.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/desktop_voice_widget.dart`

EN:

- **What this is:** Dart source `desktop_voice_widget.dart` in `lib/features/shared` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/shared` needs `desktop_voice_widget.dart` for build, CI, or documented workflow.
- **What it contains:** Open `desktop_voice_widget.dart` when editing dart source for `lib/features/shared` (see folder section above).
- **Key code names:** `DesktopVoiceOverlayPhase`, `DesktopVoiceOverlay`, `_DesktopVoiceOverlayState`
- **Responsibilities:** Fulfill the documented role of `desktop_voice_widget.dart` under `lib/features/shared`.
- **When to open:** When build output or maintenance cites `desktop_voice_widget.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/shared/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `desktop_voice_widget.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/desktop_voice_widget.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `desktop_voice_widget.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/desktop_voice_widget.dart`.
- **Когда открывать:** Баг или доработка, связанная с `desktop_voice_widget.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/edit_sheet/checklist_helpers.dart`

EN:

- **What this is:** UI code for edit sheets and voice UI on every tab: Checklist row sync/partition helpers.
- **Why needed:** Users interact with this when using edit sheets and voice UI on every tab.
- **What it contains:** Flutter widgets (implementation details in the source file) implementing the visible behavior.
- **Responsibilities:** Checklist row sync/partition helpers
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Checklist row sync/partition helpers
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `checklist_helpers.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/edit_sheet/checklist_helpers.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `checklist_helpers.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/edit_sheet/checklist_helpers.dart`.
- **Когда открывать:** Баг или доработка, связанная с `checklist_helpers.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/edit_sheet/parallel_record_panels.dart`

EN:

- **What this is:** UI code for edit sheets and voice UI on every tab: Backlog sub-items + parallel child panels.
- **Why needed:** Users interact with this when using edit sheets and voice UI on every tab.
- **What it contains:** Flutter widgets (`BacklogSubItemsPanel`, `BacklogSubItemsPanelState`) implementing the visible behavior.
- **Key code names:** `BacklogSubItemsPanel`, `BacklogSubItemsPanelState`
- **Responsibilities:** Backlog sub-items + parallel child panels
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Backlog sub-items + parallel child panels
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `parallel_record_panels.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/edit_sheet/parallel_record_panels.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `parallel_record_panels.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/edit_sheet/parallel_record_panels.dart`.
- **Когда открывать:** Баг или доработка, связанная с `parallel_record_panels.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/edit_sheet/plan_repeat_helpers.dart`

EN:

- **What this is:** UI code for edit sheets and voice UI on every tab: RRULE ↔ UI repeat preset helpers.
- **Why needed:** Users interact with this when using edit sheets and voice UI on every tab.
- **What it contains:** Flutter widgets (implementation details in the source file) implementing the visible behavior.
- **Responsibilities:** RRULE ↔ UI repeat preset helpers
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: RRULE ↔ UI repeat preset helpers
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `plan_repeat_helpers.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/edit_sheet/plan_repeat_helpers.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_repeat_helpers.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/edit_sheet/plan_repeat_helpers.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_repeat_helpers.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/edit_sheet/quill_link_launcher.dart`

EN:

- **What this is:** UI code for edit sheets and voice UI on every tab: Quill note external URL launcher.
- **Why needed:** Users interact with this when using edit sheets and voice UI on every tab.
- **What it contains:** Flutter widgets (implementation details in the source file) implementing the visible behavior.
- **Responsibilities:** Quill note external URL launcher
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Quill note external URL launcher
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `quill_link_launcher.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/edit_sheet/quill_link_launcher.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `quill_link_launcher.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/edit_sheet/quill_link_launcher.dart`.
- **Когда открывать:** Баг или доработка, связанная с `quill_link_launcher.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/edit_sheet/quill_toolbar_config.dart`

EN:

- **What this is:** UI code for edit sheets and voice UI on every tab: Planning edit Quill toolbar config.
- **Why needed:** Users interact with this when using edit sheets and voice UI on every tab.
- **What it contains:** Flutter widgets (implementation details in the source file) implementing the visible behavior.
- **Responsibilities:** Planning edit Quill toolbar config
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Planning edit Quill toolbar config
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `quill_toolbar_config.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/edit_sheet/quill_toolbar_config.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `quill_toolbar_config.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/edit_sheet/quill_toolbar_config.dart`.
- **Когда открывать:** Баг или доработка, связанная с `quill_toolbar_config.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/edit_sheet/sheet_autosave_gate.dart`

EN:

- **What this is:** UI code for edit sheets and voice UI on every tab: Debounced edit-sheet autosave gate.
- **Why needed:** Users interact with this when using edit sheets and voice UI on every tab.
- **What it contains:** Flutter widgets (`EditSheetAutosaveGate`) implementing the visible behavior.
- **Key code names:** `EditSheetAutosaveGate`
- **Responsibilities:** Debounced edit-sheet autosave gate
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Debounced edit-sheet autosave gate
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `sheet_autosave_gate.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/edit_sheet/sheet_autosave_gate.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `sheet_autosave_gate.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/edit_sheet/sheet_autosave_gate.dart`.
- **Когда открывать:** Баг или доработка, связанная с `sheet_autosave_gate.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/edit_sheet/sheet_time_helpers.dart`

EN:

- **What this is:** UI code for edit sheets and voice UI on every tab: UTC/display time format helpers.
- **Why needed:** Users interact with this when using edit sheets and voice UI on every tab.
- **What it contains:** Flutter widgets (implementation details in the source file) implementing the visible behavior.
- **Responsibilities:** UTC/display time format helpers
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: UTC/display time format helpers
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `sheet_time_helpers.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/edit_sheet/sheet_time_helpers.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `sheet_time_helpers.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/edit_sheet/sheet_time_helpers.dart`.
- **Когда открывать:** Баг или доработка, связанная с `sheet_time_helpers.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/edit_sheet/sheet_time_picker.dart`

EN:

- **What this is:** UI code for edit sheets and voice UI on every tab: , `AppEditSheetTimeButton.
- **Why needed:** Users interact with this when using edit sheets and voice UI on every tab.
- **What it contains:** Flutter widgets (`AppEditSheetTimeButton`) implementing the visible behavior.
- **Key code names:** `AppEditSheetTimeButton`
- **Responsibilities:** `showAppDateTimePicker`, `AppEditSheetTimeButton`
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: `showAppDateTimePicker`, `AppEditSheetTimeButton`
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `sheet_time_picker.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/edit_sheet/sheet_time_picker.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `sheet_time_picker.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/edit_sheet/sheet_time_picker.dart`.
- **Когда открывать:** Баг или доработка, связанная с `sheet_time_picker.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/empty_state_placeholder.dart`

EN:

- **What this is:** UI code for edit sheets and voice UI on every tab: Shared empty-state placeholder.
- **Why needed:** Users interact with this when using edit sheets and voice UI on every tab.
- **What it contains:** Flutter widgets (implementation details in the source file) implementing the visible behavior.
- **Responsibilities:** Shared empty-state placeholder
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Shared empty-state placeholder
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `empty_state_placeholder.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/empty_state_placeholder.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `empty_state_placeholder.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/empty_state_placeholder.dart`.
- **Когда открывать:** Баг или доработка, связанная с `empty_state_placeholder.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/offline_sync_status_bar.dart`

EN:

- **What this is:** UI code for edit sheets and voice UI on every tab: O1 offline/sync tap-to-retry banner.
- **Why needed:** Users interact with this when using edit sheets and voice UI on every tab.
- **What it contains:** Flutter widgets (`OfflineSyncStatusBar`, `OfflineSyncStatusBarState`) implementing the visible behavior.
- **Key code names:** `OfflineSyncStatusBar`, `OfflineSyncStatusBarState`
- **Responsibilities:** O1 offline/sync tap-to-retry banner
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: O1 offline/sync tap-to-retry banner
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `offline_sync_status_bar.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/offline_sync_status_bar.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `offline_sync_status_bar.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/offline_sync_status_bar.dart`.
- **Когда открывать:** Баг или доработка, связанная с `offline_sync_status_bar.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/planning_task_edit_sheet.dart`

EN:

- **What this is:** UI code for edit sheets and voice UI on every tab: Plan/list task edit sheet.
- **Why needed:** Users interact with this when using edit sheets and voice UI on every tab.
- **What it contains:** Flutter widgets (`PlanningTaskEditSheetState`) implementing the visible behavior.
- **Key code names:** `PlanningTaskEditSheetState`
- **Responsibilities:** Plan/list task edit sheet
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Plan/list task edit sheet
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `planning_task_edit_sheet.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/planning_task_edit_sheet.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `planning_task_edit_sheet.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/planning_task_edit_sheet.dart`.
- **Когда открывать:** Баг или доработка, связанная с `planning_task_edit_sheet.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/profile_hydration_status_bar.dart`

EN:

- **What this is:** UI code for edit sheets and voice UI on every tab: Profile hydration error banner.
- **Why needed:** Users interact with this when using edit sheets and voice UI on every tab.
- **What it contains:** Flutter widgets (implementation details in the source file) implementing the visible behavior.
- **Responsibilities:** Profile hydration error banner
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Profile hydration error banner
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `profile_hydration_status_bar.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/profile_hydration_status_bar.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `profile_hydration_status_bar.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/profile_hydration_status_bar.dart`.
- **Когда открывать:** Баг или доработка, связанная с `profile_hydration_status_bar.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/shared_widgets.dart`

EN:

- **What this is:** Dart source `shared_widgets.dart` in `lib/features/shared` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/shared` needs `shared_widgets.dart` for build, CI, or documented workflow.
- **What it contains:** Open `shared_widgets.dart` when editing dart source for `lib/features/shared` (see folder section above).
- **Responsibilities:** Fulfill the documented role of `shared_widgets.dart` under `lib/features/shared`.
- **When to open:** When build output or maintenance cites `shared_widgets.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/shared/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `shared_widgets.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/shared_widgets.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `shared_widgets.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/shared_widgets.dart`.
- **Когда открывать:** Баг или доработка, связанная с `shared_widgets.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/timeline_record_edit_sheet.dart`

EN:

- **What this is:** UI code for edit sheets and voice UI on every tab: Timeline record edit sheet.
- **Why needed:** Users interact with this when using edit sheets and voice UI on every tab.
- **What it contains:** Flutter widgets (`TimelineRecordSheetContentState`) implementing the visible behavior.
- **Key code names:** `TimelineRecordSheetContentState`
- **Responsibilities:** Timeline record edit sheet
- **When to open:** Edit sheet, date/time picker, tags strip, voice sheet, offline banner UI.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Timeline record edit sheet
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `timeline_record_edit_sheet.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/timeline_record_edit_sheet.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `timeline_record_edit_sheet.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/timeline_record_edit_sheet.dart`.
- **Когда открывать:** Баг или доработка, связанная с `timeline_record_edit_sheet.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/voice_capture_config.dart`

EN:

- **What this is:** Dart source `voice_capture_config.dart` in `lib/features/shared` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/shared` needs `voice_capture_config.dart` for build, CI, or documented workflow.
- **What it contains:** Open `voice_capture_config.dart` when editing dart source for `lib/features/shared` (see folder section above).
- **Key code names:** `VoiceCaptureConfig`
- **Responsibilities:** Fulfill the documented role of `voice_capture_config.dart` under `lib/features/shared`.
- **When to open:** When build output or maintenance cites `voice_capture_config.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/shared/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `voice_capture_config.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/voice_capture_config.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `voice_capture_config.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/voice_capture_config.dart`.
- **Когда открывать:** Баг или доработка, связанная с `voice_capture_config.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/shared/voice_input_sheet.dart`

EN:

- **What this is:** Dart source `voice_input_sheet.dart` in `lib/features/shared` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/shared` needs `voice_input_sheet.dart` for build, CI, or documented workflow.
- **What it contains:** Open `voice_input_sheet.dart` when editing dart source for `lib/features/shared` (see folder section above).
- **Key code names:** `VoiceInputSheet`, `_VoiceInputSheetState`
- **Responsibilities:** Fulfill the documented role of `voice_input_sheet.dart` under `lib/features/shared`.
- **When to open:** When build output or maintenance cites `voice_input_sheet.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/shared/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the shared area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `voice_input_sheet.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/shared/voice_input_sheet.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `voice_input_sheet.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/shared/voice_input_sheet.dart`.
- **Когда открывать:** Баг или доработка, связанная с `voice_input_sheet.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/stats/plan_vs_fact_tab.dart`

EN:

- **What this is:** Dart source `plan_vs_fact_tab.dart` in `lib/features/stats` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/stats` needs `plan_vs_fact_tab.dart` for build, CI, or documented workflow.
- **What it contains:** Open `plan_vs_fact_tab.dart` when editing dart source for `lib/features/stats` (see folder section above).
- **Key code names:** `PlanVsFactTab`, `_PlanVsFactTabState`
- **Responsibilities:** Fulfill the documented role of `plan_vs_fact_tab.dart` under `lib/features/stats`.
- **When to open:** When build output or maintenance cites `plan_vs_fact_tab.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/stats/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the stats area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `plan_vs_fact_tab.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/stats/plan_vs_fact_tab.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `plan_vs_fact_tab.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/stats/plan_vs_fact_tab.dart`.
- **Когда открывать:** Баг или доработка, связанная с `plan_vs_fact_tab.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/stats/stats_view.dart`

EN:

- **What this is:** Dart source `stats_view.dart` in `lib/features/stats` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/stats` needs `stats_view.dart` for build, CI, or documented workflow.
- **What it contains:** Open `stats_view.dart` when editing dart source for `lib/features/stats` (see folder section above).
- **Key code names:** `StatsView`, `_StatsViewState`
- **Responsibilities:** Fulfill the documented role of `stats_view.dart` under `lib/features/stats`.
- **When to open:** When build output or maintenance cites `stats_view.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/stats/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the stats area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `stats_view.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/stats/stats_view.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `stats_view.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/stats/stats_view.dart`.
- **Когда открывать:** Баг или доработка, связанная с `stats_view.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/timeline/timeline_day_page.dart`

EN:

- **What this is:** UI code for Timeline tab (first bottom tab): , lazy record list.
- **Why needed:** Users interact with this when using Timeline tab (first bottom tab).
- **What it contains:** Flutter widgets (`TimelineDayCardList`, `TimelineDayCardListState`, `TimelineLazyRecordList`, `TimelineLazyRecordListState`) implementing the visible behavior.
- **Key code names:** `TimelineDayCardList`, `TimelineDayCardListState`, `TimelineLazyRecordList`, `TimelineLazyRecordListState`
- **Responsibilities:** `TimelineDayCardList`, lazy record list
- **When to open:** Timeline tab: day list, record cards, stats toggle, date swipe.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Timeline tab (shell index 0); Role: `TimelineDayCardList`, lazy record list
- **Layer / owner:** UI code for the timeline area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `timeline_day_page.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/timeline/timeline_day_page.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `timeline_day_page.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/timeline/timeline_day_page.dart`.
- **Когда открывать:** Баг или доработка, связанная с `timeline_day_page.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/timeline/timeline_header_controls.dart`

EN:

- **What this is:** UI code for Timeline tab (first bottom tab): List/stats segmented control + record input row.
- **Why needed:** Users interact with this when using Timeline tab (first bottom tab).
- **What it contains:** Flutter widgets (`TimelineHeaderControls`) implementing the visible behavior.
- **Key code names:** `TimelineHeaderControls`
- **Responsibilities:** List/stats segmented control + record input row
- **When to open:** Timeline tab: day list, record cards, stats toggle, date swipe.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Timeline tab (shell index 0); Role: List/stats segmented control + record input row
- **Layer / owner:** UI code for the timeline area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `timeline_header_controls.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/timeline/timeline_header_controls.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `timeline_header_controls.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/timeline/timeline_header_controls.dart`.
- **Когда открывать:** Баг или доработка, связанная с `timeline_header_controls.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/timeline/timeline_helpers.dart`

EN:

- **What this is:** UI code for Timeline tab (first bottom tab): Shared timeline time/duration helpers.
- **Why needed:** Users interact with this when using Timeline tab (first bottom tab).
- **What it contains:** Flutter widgets (implementation details in the source file) implementing the visible behavior.
- **Responsibilities:** Shared timeline time/duration helpers
- **When to open:** Timeline tab: day list, record cards, stats toggle, date swipe.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Timeline tab (shell index 0); Role: Shared timeline time/duration helpers
- **Layer / owner:** UI code for the timeline area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `timeline_helpers.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/timeline/timeline_helpers.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `timeline_helpers.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/timeline/timeline_helpers.dart`.
- **Когда открывать:** Баг или доработка, связанная с `timeline_helpers.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/timeline/timeline_record_card.dart`

EN:

- **What this is:** UI code for Timeline tab (first bottom tab): .
- **Why needed:** Users interact with this when using Timeline tab (first bottom tab).
- **What it contains:** Flutter widgets (`TimelineRecordCard`, `TimelineRecordCardState`) implementing the visible behavior.
- **Key code names:** `TimelineRecordCard`, `TimelineRecordCardState`
- **Responsibilities:** `TimelineRecordCard`
- **When to open:** Timeline tab: day list, record cards, stats toggle, date swipe.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Timeline tab (shell index 0); Role: `TimelineRecordCard`
- **Layer / owner:** UI code for the timeline area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `timeline_record_card.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/timeline/timeline_record_card.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `timeline_record_card.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/timeline/timeline_record_card.dart`.
- **Когда открывать:** Баг или доработка, связанная с `timeline_record_card.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/timeline/timeline_view.dart`

EN:

- **What this is:** Dart source `timeline_view.dart` in `lib/features/timeline` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/timeline` needs `timeline_view.dart` for build, CI, or documented workflow.
- **What it contains:** Open `timeline_view.dart` when editing dart source for `lib/features/timeline` (see folder section above).
- **Key code names:** `TimelineSwipeWrapper`, `_TimelineSwipeWrapperState`
- **Responsibilities:** Fulfill the documented role of `timeline_view.dart` under `lib/features/timeline`.
- **When to open:** When build output or maintenance cites `timeline_view.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/timeline/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the timeline area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `timeline_view.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/timeline/timeline_view.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `timeline_view.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/timeline/timeline_view.dart`.
- **Когда открывать:** Баг или доработка, связанная с `timeline_view.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/wear/wear_main_wrapper.dart`

EN:

- **What this is:** Dart source `wear_main_wrapper.dart` in `lib/features/wear` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/wear` needs `wear_main_wrapper.dart` for build, CI, or documented workflow.
- **What it contains:** Open `wear_main_wrapper.dart` when editing dart source for `lib/features/wear` (see folder section above).
- **Key code names:** `WearMainWrapper`
- **Responsibilities:** Fulfill the documented role of `wear_main_wrapper.dart` under `lib/features/wear`.
- **When to open:** When build output or maintenance cites `wear_main_wrapper.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/wear/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the wear area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `wear_main_wrapper.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/wear/wear_main_wrapper.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `wear_main_wrapper.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/wear/wear_main_wrapper.dart`.
- **Когда открывать:** Баг или доработка, связанная с `wear_main_wrapper.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/wear/wear_platform.dart`

EN:

- **What this is:** Dart source `wear_platform.dart` in `lib/features/wear` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/wear` needs `wear_platform.dart` for build, CI, or documented workflow.
- **What it contains:** Open `wear_platform.dart` when editing dart source for `lib/features/wear` (see folder section above).
- **Key code names:** `WearPlatform`
- **Responsibilities:** Fulfill the documented role of `wear_platform.dart` under `lib/features/wear`.
- **When to open:** When build output or maintenance cites `wear_platform.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/wear/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the wear area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `wear_platform.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/wear/wear_platform.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `wear_platform.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/wear/wear_platform.dart`.
- **Когда открывать:** Баг или доработка, связанная с `wear_platform.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/wear/wear_runtime.dart`

EN:

- **What this is:** Dart source `wear_runtime.dart` in `lib/features/wear` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/wear` needs `wear_runtime.dart` for build, CI, or documented workflow.
- **What it contains:** Open `wear_runtime.dart` when editing dart source for `lib/features/wear` (see folder section above).
- **Responsibilities:** Fulfill the documented role of `wear_runtime.dart` under `lib/features/wear`.
- **When to open:** When build output or maintenance cites `wear_runtime.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/wear/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the wear area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `wear_runtime.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/wear/wear_runtime.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `wear_runtime.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/wear/wear_runtime.dart`.
- **Когда открывать:** Баг или доработка, связанная с `wear_runtime.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/features/wear/wear_timer_screen.dart`

EN:

- **What this is:** Dart source `wear_timer_screen.dart` in `lib/features/wear` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/features/wear` needs `wear_timer_screen.dart` for build, CI, or documented workflow.
- **What it contains:** Open `wear_timer_screen.dart` when editing dart source for `lib/features/wear` (see folder section above).
- **Key code names:** `WearTimerScreen`, `_WearTimerScreenState`
- **Responsibilities:** Fulfill the documented role of `wear_timer_screen.dart` under `lib/features/wear`.
- **When to open:** When build output or maintenance cites `wear_timer_screen.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/features/wear/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** UI code for the wear area of the app (what users see and tap).

RU:

- **Что это:** Dart-файл `wear_timer_screen.dart` — UI (экраны): видимое поведение вкладок и sheets.
- **Зачем:** Модуль `lib/features/wear/wear_timer_screen.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `wear_timer_screen.dart`.
- **Обязанности:** Реализует видимое поведение вкладок и sheets для пути `lib/features/wear/wear_timer_screen.dart`.
- **Когда открывать:** Баг или доработка, связанная с `wear_timer_screen.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** UI (экраны) — не platform wrapper.


### `lib/l10n/app_locales.dart`

EN:

- **What this is:** Source file `app_locales.dart` — Supported locale codes and labels.
- **Why needed:** Documented in `docs/APP_STRUCTURE.md`; required for current app behavior.
- **What it contains:** Source for `app_locales.dart` (see source file).
- **Responsibilities:** Supported locale codes and labels
- **When to open:** When behavior tied to `app_locales.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Supported locale codes and labels
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Dart-файл `app_locales.dart` — Локализация: строки UI на всех языках.
- **Зачем:** Модуль `lib/l10n/app_locales.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `app_locales.dart`.
- **Обязанности:** Реализует строки UI на всех языках для пути `lib/l10n/app_locales.dart`.
- **Когда открывать:** Баг или доработка, связанная с `app_locales.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Локализация — не platform wrapper.


### `lib/l10n/category_db_display.dart`

EN:

- **What this is:** Source file `category_db_display.dart` — Localized category name display.
- **Why needed:** Documented in `docs/APP_STRUCTURE.md`; required for current app behavior.
- **What it contains:** Source for `category_db_display.dart` (see source file).
- **Responsibilities:** Localized category name display
- **When to open:** When behavior tied to `category_db_display.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Localized category name display
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Dart-файл `category_db_display.dart` — Локализация: строки UI на всех языках.
- **Зачем:** Модуль `lib/l10n/category_db_display.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `category_db_display.dart`.
- **Обязанности:** Реализует строки UI на всех языках для пути `lib/l10n/category_db_display.dart`.
- **Когда открывать:** Баг или доработка, связанная с `category_db_display.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Локализация — не platform wrapper.


### `lib/l10n/dictionary.dart`

EN:

- **What this is:** Source file `dictionary.dart` — Assembles locale maps.
- **Why needed:** Documented in `docs/APP_STRUCTURE.md`; required for current app behavior.
- **What it contains:** Source for `dictionary.dart` (see source file).
- **Responsibilities:** Assembles locale maps
- **When to open:** When behavior tied to `dictionary.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Assembles locale maps; exports `t()` and `currentLocale`
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Dart-файл `dictionary.dart` — Локализация: строки UI на всех языках.
- **Зачем:** Модуль `lib/l10n/dictionary.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `dictionary.dart`.
- **Обязанности:** Реализует строки UI на всех языках для пути `lib/l10n/dictionary.dart`.
- **Когда открывать:** Баг или доработка, связанная с `dictionary.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Локализация — не platform wrapper.


### `lib/l10n/langs/HELP HOW TO UPDATE the languages`

EN:

- **What this is:** text file `HELP HOW TO UPDATE the languages` in `lib/l10n/langs` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/l10n/langs` needs `HELP HOW TO UPDATE the languages` for build, CI, or documented workflow.
- **What it contains:** Open `HELP HOW TO UPDATE the languages` when editing text file for `lib/l10n/langs` (see folder section above).
- **Responsibilities:** Fulfill the documented role of `HELP HOW TO UPDATE the languages` under `lib/l10n/langs`.
- **When to open:** When build output or maintenance cites `HELP HOW TO UPDATE the languages`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Dart-файл `HELP HOW TO UPDATE the languages` — Локализация: строки UI на всех языках.
- **Зачем:** Модуль `lib/l10n/langs/HELP HOW TO UPDATE the languages` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `HELP HOW TO UPDATE the languages`.
- **Обязанности:** Реализует строки UI на всех языках для пути `lib/l10n/langs/HELP HOW TO UPDATE the languages`.
- **Когда открывать:** Баг или доработка, связанная с `HELP HOW TO UPDATE the languages` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Локализация — не platform wrapper.


### `lib/l10n/langs/ar.dart`

EN:

- **What this is:** Dart source `ar.dart` in `lib/l10n/langs` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/l10n/langs` needs `ar.dart` for build, CI, or documented workflow.
- **What it contains:** Open `ar.dart` when editing dart source for `lib/l10n/langs` (see folder section above).
- **Responsibilities:** Fulfill the documented role of `ar.dart` under `lib/l10n/langs`.
- **When to open:** When build output or maintenance cites `ar.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Dart-файл `ar.dart` — Локализация: строки UI на всех языках.
- **Зачем:** Модуль `lib/l10n/langs/ar.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `ar.dart`.
- **Обязанности:** Реализует строки UI на всех языках для пути `lib/l10n/langs/ar.dart`.
- **Когда открывать:** Баг или доработка, связанная с `ar.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Локализация — не platform wrapper.


### `lib/l10n/langs/de.dart`

EN:

- **What this is:** Dart source `de.dart` in `lib/l10n/langs` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/l10n/langs` needs `de.dart` for build, CI, or documented workflow.
- **What it contains:** Open `de.dart` when editing dart source for `lib/l10n/langs` (see folder section above).
- **Responsibilities:** Fulfill the documented role of `de.dart` under `lib/l10n/langs`.
- **When to open:** When build output or maintenance cites `de.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Dart-файл `de.dart` — Локализация: строки UI на всех языках.
- **Зачем:** Модуль `lib/l10n/langs/de.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `de.dart`.
- **Обязанности:** Реализует строки UI на всех языках для пути `lib/l10n/langs/de.dart`.
- **Когда открывать:** Баг или доработка, связанная с `de.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Локализация — не platform wrapper.


### `lib/l10n/langs/en.dart`

EN:

- **What this is:** English translation strings — master copy for all UI text keys.
- **Why needed:** Every label in the app resolves through keys defined here first.
- **What it contains:** `kEnL10n` map of key → English text.
- **Responsibilities:** Canonical English SSOT; edit here before running locale sync.
- **When to open:** When behavior tied to `en.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: **Canonical English** (`kEnL10n`) — SSOT for EN keys
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Dart-файл `en.dart` — Локализация: строки UI на всех языках.
- **Зачем:** Модуль `lib/l10n/langs/en.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `en.dart`.
- **Обязанности:** Реализует строки UI на всех языках для пути `lib/l10n/langs/en.dart`.
- **Когда открывать:** Баг или доработка, связанная с `en.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Локализация — не platform wrapper.


### `lib/l10n/langs/es.dart`

EN:

- **What this is:** Dart source `es.dart` in `lib/l10n/langs` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/l10n/langs` needs `es.dart` for build, CI, or documented workflow.
- **What it contains:** Open `es.dart` when editing dart source for `lib/l10n/langs` (see folder section above).
- **Responsibilities:** Fulfill the documented role of `es.dart` under `lib/l10n/langs`.
- **When to open:** When build output or maintenance cites `es.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Dart-файл `es.dart` — Локализация: строки UI на всех языках.
- **Зачем:** Модуль `lib/l10n/langs/es.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `es.dart`.
- **Обязанности:** Реализует строки UI на всех языках для пути `lib/l10n/langs/es.dart`.
- **Когда открывать:** Баг или доработка, связанная с `es.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Локализация — не platform wrapper.


### `lib/l10n/langs/fr.dart`

EN:

- **What this is:** Dart source `fr.dart` in `lib/l10n/langs` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/l10n/langs` needs `fr.dart` for build, CI, or documented workflow.
- **What it contains:** Open `fr.dart` when editing dart source for `lib/l10n/langs` (see folder section above).
- **Responsibilities:** Fulfill the documented role of `fr.dart` under `lib/l10n/langs`.
- **When to open:** When build output or maintenance cites `fr.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Dart-файл `fr.dart` — Локализация: строки UI на всех языках.
- **Зачем:** Модуль `lib/l10n/langs/fr.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `fr.dart`.
- **Обязанности:** Реализует строки UI на всех языках для пути `lib/l10n/langs/fr.dart`.
- **Когда открывать:** Баг или доработка, связанная с `fr.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Локализация — не platform wrapper.


### `lib/l10n/langs/it.dart`

EN:

- **What this is:** Dart source `it.dart` in `lib/l10n/langs` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/l10n/langs` needs `it.dart` for build, CI, or documented workflow.
- **What it contains:** Open `it.dart` when editing dart source for `lib/l10n/langs` (see folder section above).
- **Responsibilities:** Fulfill the documented role of `it.dart` under `lib/l10n/langs`.
- **When to open:** When build output or maintenance cites `it.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Dart-файл `it.dart` — Локализация: строки UI на всех языках.
- **Зачем:** Модуль `lib/l10n/langs/it.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `it.dart`.
- **Обязанности:** Реализует строки UI на всех языках для пути `lib/l10n/langs/it.dart`.
- **Когда открывать:** Баг или доработка, связанная с `it.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Локализация — не platform wrapper.


### `lib/l10n/langs/ko.dart`

EN:

- **What this is:** Dart source `ko.dart` in `lib/l10n/langs` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/l10n/langs` needs `ko.dart` for build, CI, or documented workflow.
- **What it contains:** Open `ko.dart` when editing dart source for `lib/l10n/langs` (see folder section above).
- **Responsibilities:** Fulfill the documented role of `ko.dart` under `lib/l10n/langs`.
- **When to open:** When build output or maintenance cites `ko.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Dart-файл `ko.dart` — Локализация: строки UI на всех языках.
- **Зачем:** Модуль `lib/l10n/langs/ko.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `ko.dart`.
- **Обязанности:** Реализует строки UI на всех языках для пути `lib/l10n/langs/ko.dart`.
- **Когда открывать:** Баг или доработка, связанная с `ko.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Локализация — не platform wrapper.


### `lib/l10n/langs/ru.dart`

EN:

- **What this is:** Russian translation strings for the UI.
- **Why needed:** Russian locale shows text from this map when user picks RU.
- **What it contains:** `kRuL10n` map of key → Russian text.
- **Responsibilities:** Canonical Russian SSOT alongside English.
- **When to open:** When behavior tied to `ru.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: **Canonical Russian** (`kRuL10n`) — SSOT for RU keys
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Dart-файл `ru.dart` — Локализация: строки UI на всех языках.
- **Зачем:** Модуль `lib/l10n/langs/ru.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `ru.dart`.
- **Обязанности:** Реализует строки UI на всех языках для пути `lib/l10n/langs/ru.dart`.
- **Когда открывать:** Баг или доработка, связанная с `ru.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Локализация — не platform wrapper.


### `lib/l10n/langs/zh.dart`

EN:

- **What this is:** Dart source `zh.dart` in `lib/l10n/langs` for the Life OS repository.
- **Why needed:** This path is tracked because `lib/l10n/langs` needs `zh.dart` for build, CI, or documented workflow.
- **What it contains:** Open `zh.dart` when editing dart source for `lib/l10n/langs` (see folder section above).
- **Responsibilities:** Fulfill the documented role of `zh.dart` under `lib/l10n/langs`.
- **When to open:** When build output or maintenance cites `zh.dart`.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Folder `lib/l10n/langs/`, `docs/APP_STRUCTURE.md`.
- **Layer / owner:** Translations and text keys.

RU:

- **Что это:** Dart-файл `zh.dart` — Локализация: строки UI на всех языках.
- **Зачем:** Модуль `lib/l10n/langs/zh.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `zh.dart`.
- **Обязанности:** Реализует строки UI на всех языках для пути `lib/l10n/langs/zh.dart`.
- **Когда открывать:** Баг или доработка, связанная с `zh.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Локализация — не platform wrapper.


### `lib/main.dart`

EN:

- **What this is:** Source file `main.dart` — `runApp`, PocketBase bootstrap, auth gate, Wear entry, locale init, shell injection.
- **Why needed:** Documented in `docs/APP_STRUCTURE.md`; required for current app behavior.
- **What it contains:** Source for `main.dart` (`main`).
- **Key code names:** `main`
- **Responsibilities:** `runApp`, PocketBase bootstrap, auth gate, Wear entry, locale init, shell injection
- **When to open:** When behavior tied to `main.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: `runApp`, PocketBase bootstrap, auth gate, Wear entry, locale init, shell injection
- **Layer / owner:** Repository support file.

RU:

- **Что это:** Dart-файл `main.dart` — Dart-код приложения: логика Counter на этом уровне `lib/`.
- **Зачем:** Модуль `lib/main.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `main.dart`.
- **Обязанности:** Реализует логика Counter на этом уровне `lib/` для пути `lib/main.dart`.
- **Когда открывать:** Баг или доработка, связанная с `main.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Dart-код приложения — не platform wrapper.


### `lib/services/notification_service.dart`

EN:

- **What this is:** Source file `notification_service.dart` — Local notifications and plan alarms.
- **Why needed:** Documented in `docs/APP_STRUCTURE.md`; required for current app behavior.
- **What it contains:** Source for `notification_service.dart` (`_AlarmCandidate`, `NotificationService`).
- **Key code names:** `_AlarmCandidate`, `NotificationService`
- **Responsibilities:** Local notifications and plan alarms
- **When to open:** When behavior tied to `notification_service.dart` breaks or you need to change its documented role.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** Role: Local notifications and plan alarms
- **Layer / owner:** Device service (notifications) — no PocketBase.

RU:

- **Что это:** Dart-файл `notification_service.dart` — Сервис устройства: уведомления ОС вне PocketBase.
- **Зачем:** Модуль `lib/services/notification_service.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `notification_service.dart`.
- **Обязанности:** Реализует уведомления ОС вне PocketBase для пути `lib/services/notification_service.dart`.
- **Когда открывать:** Баг или доработка, связанная с `notification_service.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Сервис устройства — не platform wrapper.


### `lib/shell/life_os_dashboard.dart`

EN:

- **What this is:** App shell wiring — Shell dashboard entry (see §3.1.1).
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ShellDashboardBase`).
- **Key code names:** `ShellDashboardBase`
- **Responsibilities:** Shell dashboard entry (see §3.1.1)
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; Role: Shell dashboard entry (see §3.1.1)
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Dart-файл `life_os_dashboard.dart` — Shell (оболочка): навигация, voice routing, edit modals.
- **Зачем:** Модуль `lib/shell/life_os_dashboard.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `life_os_dashboard.dart`.
- **Обязанности:** Реализует навигация, voice routing, edit modals для пути `lib/shell/life_os_dashboard.dart`.
- **Когда открывать:** Баг или доработка, связанная с `life_os_dashboard.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Shell (оболочка) — не platform wrapper.


### `lib/shell/profile_hydration_status_bar.dart`

EN:

- **What this is:** App shell wiring — Profile hydration failure banner.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ProfileHydrationStatusBar`).
- **Key code names:** `ProfileHydrationStatusBar`
- **Responsibilities:** Profile hydration failure banner
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; Role: Profile hydration failure banner
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Dart-файл `profile_hydration_status_bar.dart` — Shell (оболочка): навигация, voice routing, edit modals.
- **Зачем:** Модуль `lib/shell/profile_hydration_status_bar.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `profile_hydration_status_bar.dart`.
- **Обязанности:** Реализует навигация, voice routing, edit modals для пути `lib/shell/profile_hydration_status_bar.dart`.
- **Когда открывать:** Баг или доработка, связанная с `profile_hydration_status_bar.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Shell (оболочка) — не platform wrapper.


### `lib/shell/settings_page.dart`

EN:

- **What this is:** App shell wiring — Language/TZ settings page (shell route).
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`SettingsPage`, `SettingsPageState`).
- **Key code names:** `SettingsPage`, `SettingsPageState`
- **Responsibilities:** Language/TZ settings page (shell route)
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; Role: Language/TZ settings page (shell route)
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Dart-файл `settings_page.dart` — Shell (оболочка): навигация, voice routing, edit modals.
- **Зачем:** Модуль `lib/shell/settings_page.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `settings_page.dart`.
- **Обязанности:** Реализует навигация, voice routing, edit modals для пути `lib/shell/settings_page.dart`.
- **Когда открывать:** Баг или доработка, связанная с `settings_page.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Shell (оболочка) — не platform wrapper.


### `lib/shell/shell_core.dart`

EN:

- **What this is:** App shell wiring — Shell core logic.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ShellCoreLogic`).
- **Key code names:** `ShellCoreLogic`
- **Responsibilities:** Shell core logic
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; Role: Shell core logic
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Dart-файл `shell_core.dart` — Shell (оболочка): навигация, voice routing, edit modals.
- **Зачем:** Модуль `lib/shell/shell_core.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `shell_core.dart`.
- **Обязанности:** Реализует навигация, voice routing, edit modals для пути `lib/shell/shell_core.dart`.
- **Когда открывать:** Баг или доработка, связанная с `shell_core.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Shell (оболочка) — не platform wrapper.


### `lib/shell/shell_edit_hosts.dart`

EN:

- **What this is:** App shell wiring — Edit sheet hosts.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ShellEditHosts`).
- **Key code names:** `ShellEditHosts`
- **Responsibilities:** Edit sheet hosts
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; Role: Edit sheet hosts
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Dart-файл `shell_edit_hosts.dart` — Shell (оболочка): навигация, voice routing, edit modals.
- **Зачем:** Модуль `lib/shell/shell_edit_hosts.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `shell_edit_hosts.dart`.
- **Обязанности:** Реализует навигация, voice routing, edit modals для пути `lib/shell/shell_edit_hosts.dart`.
- **Когда открывать:** Баг или доработка, связанная с `shell_edit_hosts.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Shell (оболочка) — не platform wrapper.


### `lib/shell/shell_more_menu.dart`

EN:

- **What this is:** App shell wiring — More menu.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ShellMoreMenu`).
- **Key code names:** `ShellMoreMenu`
- **Responsibilities:** More menu
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; Role: More menu
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Dart-файл `shell_more_menu.dart` — Shell (оболочка): навигация, voice routing, edit modals.
- **Зачем:** Модуль `lib/shell/shell_more_menu.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `shell_more_menu.dart`.
- **Обязанности:** Реализует навигация, voice routing, edit modals для пути `lib/shell/shell_more_menu.dart`.
- **Когда открывать:** Баг или доработка, связанная с `shell_more_menu.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Shell (оболочка) — не platform wrapper.


### `lib/shell/shell_offline_banner.dart`

EN:

- **What this is:** App shell wiring — Offline banner slot.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ShellTopStatusBars`).
- **Key code names:** `ShellTopStatusBars`
- **Responsibilities:** Offline banner slot
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; Role: Offline banner slot
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Dart-файл `shell_offline_banner.dart` — Shell (оболочка): навигация, voice routing, edit modals.
- **Зачем:** Модуль `lib/shell/shell_offline_banner.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `shell_offline_banner.dart`.
- **Обязанности:** Реализует навигация, voice routing, edit modals для пути `lib/shell/shell_offline_banner.dart`.
- **Когда открывать:** Баг или доработка, связанная с `shell_offline_banner.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Shell (оболочка) — не platform wrapper.


### `lib/shell/shell_shared.dart`

EN:

- **What this is:** App shell wiring — Shell shared helpers.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (implementation details in the source file).
- **Responsibilities:** Shell shared helpers
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; Role: Shell shared helpers
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Dart-файл `shell_shared.dart` — Shell (оболочка): навигация, voice routing, edit modals.
- **Зачем:** Модуль `lib/shell/shell_shared.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `shell_shared.dart`.
- **Обязанности:** Реализует навигация, voice routing, edit modals для пути `lib/shell/shell_shared.dart`.
- **Когда открывать:** Баг или доработка, связанная с `shell_shared.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Shell (оболочка) — не platform wrapper.


### `lib/shell/shell_side_navigation.dart`

EN:

- **What this is:** App shell wiring — Desktop/web side navigation rail.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ShellSideNavigation`, `ShellSideNavItem`).
- **Key code names:** `ShellSideNavigation`, `ShellSideNavItem`
- **Responsibilities:** Desktop/web side navigation rail
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; Role: Desktop/web side navigation rail
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Dart-файл `shell_side_navigation.dart` — Shell (оболочка): навигация, voice routing, edit modals.
- **Зачем:** Модуль `lib/shell/shell_side_navigation.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `shell_side_navigation.dart`.
- **Обязанности:** Реализует навигация, voice routing, edit modals для пути `lib/shell/shell_side_navigation.dart`.
- **Когда открывать:** Баг или доработка, связанная с `shell_side_navigation.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Shell (оболочка) — не platform wrapper.


### `lib/shell/shell_tab_host.dart`

EN:

- **What this is:** App shell wiring — Tab host builders.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ShellTabHost`).
- **Key code names:** `ShellTabHost`
- **Responsibilities:** Tab host builders
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; Role: Tab host builders
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Dart-файл `shell_tab_host.dart` — Shell (оболочка): навигация, voice routing, edit modals.
- **Зачем:** Модуль `lib/shell/shell_tab_host.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `shell_tab_host.dart`.
- **Обязанности:** Реализует навигация, voice routing, edit modals для пути `lib/shell/shell_tab_host.dart`.
- **Когда открывать:** Баг или доработка, связанная с `shell_tab_host.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Shell (оболочка) — не platform wrapper.


### `lib/shell/shell_voice_routing.dart`

EN:

- **What this is:** App shell wiring — Voice routing.
- **Why needed:** Connects bottom tabs, voice, edit sheets, and offline banner across the whole app.
- **What it contains:** Shell mixin or widget (`ShellVoiceRouting`).
- **Key code names:** `ShellVoiceRouting`
- **Responsibilities:** Voice routing
- **When to open:** Bottom tabs, voice routing, edit modal host, offline banner slot.
- **Can it be deleted?** No — required for app runtime.
- **Connected to:** All main tabs, `app_shell.dart`; Role: Voice routing
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Dart-файл `shell_voice_routing.dart` — Shell (оболочка): навигация, voice routing, edit modals.
- **Зачем:** Модуль `lib/shell/shell_voice_routing.dart` участвует в каждой сборке Counter; правки здесь меняют поведение продукта.
- **Содержимое:** Исходный Dart-код и symbols в `shell_voice_routing.dart`.
- **Обязанности:** Реализует навигация, voice routing, edit modals для пути `lib/shell/shell_voice_routing.dart`.
- **Когда открывать:** Баг или доработка, связанная с `shell_voice_routing.dart` или его импортами.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** `docs/APP_STRUCTURE.md`, соседние файлы в той же feature/data папке.
- **Слой:** Shell (оболочка) — не platform wrapper.


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

- **Что это:** Файл `.gitignore` в каталоге `linux/`.
- **Зачем:** Prevents результат сборки and secrets from entering git history.
- **Содержимое:** Исходное содержимое `.gitignore`.
- **Обязанности:** Зона ответственности `.gitignore` в `linux/`.
- **Когда открывать:** Build или maintenance ссылается на `.gitignore`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `linux` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `cmakelists.txt` в каталоге `linux/`.
- **Зачем:** Поддерживает documented workflow каталога `linux/`.
- **Содержимое:** Исходное содержимое `cmakelists.txt`.
- **Обязанности:** Зона ответственности `cmakelists.txt` в `linux/`.
- **Когда открывать:** Build или maintenance ссылается на `cmakelists.txt`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `linux` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `cmakelists.txt` в каталоге `linux/flutter/`.
- **Зачем:** Поддерживает documented workflow каталога `linux/flutter/`.
- **Содержимое:** Исходное содержимое `cmakelists.txt`.
- **Обязанности:** Зона ответственности `cmakelists.txt` в `linux/flutter/`.
- **Когда открывать:** Build или maintenance ссылается на `cmakelists.txt`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `linux` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `linux/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `linux/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `generated_plugins.cmake` в каталоге `linux/flutter/`.
- **Зачем:** Поддерживает documented workflow каталога `linux/flutter/`.
- **Содержимое:** Исходное содержимое `generated_plugins.cmake`.
- **Обязанности:** Зона ответственности `generated_plugins.cmake` в `linux/flutter/`.
- **Когда открывать:** Build или maintenance ссылается на `generated_plugins.cmake`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `linux/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `cmakelists.txt` в каталоге `linux/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `linux/runner/`.
- **Содержимое:** Исходное содержимое `cmakelists.txt`.
- **Обязанности:** Зона ответственности `cmakelists.txt` в `linux/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `cmakelists.txt`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `linux` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `main.cc` в каталоге `linux/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `linux/runner/`.
- **Содержимое:** Исходное содержимое `main.cc`.
- **Обязанности:** Зона ответственности `main.cc` в `linux/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `main.cc`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `linux/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `my_application.cc` в каталоге `linux/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `linux/runner/`.
- **Содержимое:** Исходное содержимое `my_application.cc`.
- **Обязанности:** Зона ответственности `my_application.cc` в `linux/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `my_application.cc`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `linux/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `my_application.h` в каталоге `linux/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `linux/runner/`.
- **Содержимое:** Исходное содержимое `my_application.h`.
- **Обязанности:** Зона ответственности `my_application.h` в `linux/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `my_application.h`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `linux/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `.gitignore` в каталоге `macos/`.
- **Зачем:** Prevents результат сборки and secrets from entering git history.
- **Содержимое:** Исходное содержимое `.gitignore`.
- **Обязанности:** Зона ответственности `.gitignore` в `macos/`.
- **Когда открывать:** Build или maintenance ссылается на `.gitignore`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `macos` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `macos/Flutter/Flutter-Debug.xcconfig`

EN:

- **What this is:** macos build file `Flutter-Debug.xcconfig` in `macos/Flutter` — required by Flutter/native toolchain.
- **Why needed:** Without `Flutter-Debug.xcconfig`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Flutter` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Flutter` — not Dart business logic.
- **When to open:** Build log mentions `Flutter-Debug.xcconfig` or `macos/Flutter`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Файл `flutter-debug.xcconfig` в каталоге `macos/Flutter/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Flutter/`.
- **Содержимое:** Исходное содержимое `flutter-debug.xcconfig`.
- **Обязанности:** Зона ответственности `flutter-debug.xcconfig` в `macos/Flutter/`.
- **Когда открывать:** Build или maintenance ссылается на `flutter-debug.xcconfig`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `macos/Flutter/Flutter-Release.xcconfig`

EN:

- **What this is:** macos build file `Flutter-Release.xcconfig` in `macos/Flutter` — required by Flutter/native toolchain.
- **Why needed:** Without `Flutter-Release.xcconfig`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Flutter` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Flutter` — not Dart business logic.
- **When to open:** Build log mentions `Flutter-Release.xcconfig` or `macos/Flutter`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Файл `flutter-release.xcconfig` в каталоге `macos/Flutter/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Flutter/`.
- **Содержимое:** Исходное содержимое `flutter-release.xcconfig`.
- **Обязанности:** Зона ответственности `flutter-release.xcconfig` в `macos/Flutter/`.
- **Когда открывать:** Build или maintenance ссылается на `flutter-release.xcconfig`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `generatedpluginregistrant.swift` в каталоге `macos/Flutter/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Flutter/`.
- **Содержимое:** Исходное содержимое `generatedpluginregistrant.swift`.
- **Обязанности:** Зона ответственности `generatedpluginregistrant.swift` в `macos/Flutter/`.
- **Когда открывать:** Build или maintenance ссылается на `generatedpluginregistrant.swift`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `macos/Runner.xcodeproj/project.pbxproj`

EN:

- **What this is:** macos build file `project.pbxproj` in `macos/Runner.xcodeproj` — required by Flutter/native toolchain.
- **Why needed:** Without `project.pbxproj`, macos compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `macos/Runner.xcodeproj` (open file only when build errors cite it).
- **Responsibilities:** Support macos embedder build for `macos/Runner.xcodeproj` — not Dart business logic.
- **When to open:** Build log mentions `project.pbxproj` or `macos/Runner.xcodeproj`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `macos/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Файл `project.pbxproj` в каталоге `macos/Runner.xcodeproj/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner.xcodeproj/`.
- **Содержимое:** Исходное содержимое `project.pbxproj`.
- **Обязанности:** Зона ответственности `project.pbxproj` в `macos/Runner.xcodeproj/`.
- **Когда открывать:** Build или maintenance ссылается на `project.pbxproj`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `ideworkspacechecks.plist` в каталоге `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/`.
- **Содержимое:** Исходное содержимое `ideworkspacechecks.plist`.
- **Обязанности:** Зона ответственности `ideworkspacechecks.plist` в `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/`.
- **Когда открывать:** Build или maintenance ссылается на `ideworkspacechecks.plist`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `runner.xcscheme` в каталоге `macos/Runner.xcodeproj/xcshareddata/xcschemes/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner.xcodeproj/xcshareddata/xcschemes/`.
- **Содержимое:** Исходное содержимое `runner.xcscheme`.
- **Обязанности:** Зона ответственности `runner.xcscheme` в `macos/Runner.xcodeproj/xcshareddata/xcschemes/`.
- **Когда открывать:** Build или maintenance ссылается на `runner.xcscheme`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `contents.xcworkspacedata` в каталоге `macos/Runner.xcworkspace/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner.xcworkspace/`.
- **Содержимое:** Исходное содержимое `contents.xcworkspacedata`.
- **Обязанности:** Зона ответственности `contents.xcworkspacedata` в `macos/Runner.xcworkspace/`.
- **Когда открывать:** Build или maintenance ссылается на `contents.xcworkspacedata`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `ideworkspacechecks.plist` в каталоге `macos/Runner.xcworkspace/xcshareddata/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner.xcworkspace/xcshareddata/`.
- **Содержимое:** Исходное содержимое `ideworkspacechecks.plist`.
- **Обязанности:** Зона ответственности `ideworkspacechecks.plist` в `macos/Runner.xcworkspace/xcshareddata/`.
- **Когда открывать:** Build или maintenance ссылается на `ideworkspacechecks.plist`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `appdelegate.swift` в каталоге `macos/Runner/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/`.
- **Содержимое:** Исходное содержимое `appdelegate.swift`.
- **Обязанности:** Зона ответственности `appdelegate.swift` в `macos/Runner/`.
- **Когда открывать:** Build или maintenance ссылается на `appdelegate.swift`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `contents.json` в каталоге `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `contents.json`.
- **Обязанности:** Зона ответственности `contents.json` в `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `contents.json`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `app_icon_1024.png` в каталоге `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `app_icon_1024.png`.
- **Обязанности:** Зона ответственности `app_icon_1024.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `app_icon_1024.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `app_icon_128.png` в каталоге `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `app_icon_128.png`.
- **Обязанности:** Зона ответственности `app_icon_128.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `app_icon_128.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `app_icon_16.png` в каталоге `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `app_icon_16.png`.
- **Обязанности:** Зона ответственности `app_icon_16.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `app_icon_16.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `app_icon_256.png` в каталоге `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `app_icon_256.png`.
- **Обязанности:** Зона ответственности `app_icon_256.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `app_icon_256.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `app_icon_32.png` в каталоге `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `app_icon_32.png`.
- **Обязанности:** Зона ответственности `app_icon_32.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `app_icon_32.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `app_icon_512.png` в каталоге `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `app_icon_512.png`.
- **Обязанности:** Зона ответственности `app_icon_512.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `app_icon_512.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `app_icon_64.png` в каталоге `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Содержимое:** Исходное содержимое `app_icon_64.png`.
- **Обязанности:** Зона ответственности `app_icon_64.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Когда открывать:** Build или maintenance ссылается на `app_icon_64.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `mainmenu.xib` в каталоге `macos/Runner/Base.lproj/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/Base.lproj/`.
- **Содержимое:** Исходное содержимое `mainmenu.xib`.
- **Обязанности:** Зона ответственности `mainmenu.xib` в `macos/Runner/Base.lproj/`.
- **Когда открывать:** Build или maintenance ссылается на `mainmenu.xib`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `appinfo.xcconfig` в каталоге `macos/Runner/Configs/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/Configs/`.
- **Содержимое:** Исходное содержимое `appinfo.xcconfig`.
- **Обязанности:** Зона ответственности `appinfo.xcconfig` в `macos/Runner/Configs/`.
- **Когда открывать:** Build или maintenance ссылается на `appinfo.xcconfig`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `debug.xcconfig` в каталоге `macos/Runner/Configs/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/Configs/`.
- **Содержимое:** Исходное содержимое `debug.xcconfig`.
- **Обязанности:** Зона ответственности `debug.xcconfig` в `macos/Runner/Configs/`.
- **Когда открывать:** Build или maintenance ссылается на `debug.xcconfig`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `release.xcconfig` в каталоге `macos/Runner/Configs/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/Configs/`.
- **Содержимое:** Исходное содержимое `release.xcconfig`.
- **Обязанности:** Зона ответственности `release.xcconfig` в `macos/Runner/Configs/`.
- **Когда открывать:** Build или maintenance ссылается на `release.xcconfig`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `warnings.xcconfig` в каталоге `macos/Runner/Configs/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/Configs/`.
- **Содержимое:** Исходное содержимое `warnings.xcconfig`.
- **Обязанности:** Зона ответственности `warnings.xcconfig` в `macos/Runner/Configs/`.
- **Когда открывать:** Build или maintenance ссылается на `warnings.xcconfig`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `debugprofile.entitlements` в каталоге `macos/Runner/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/`.
- **Содержимое:** Исходное содержимое `debugprofile.entitlements`.
- **Обязанности:** Зона ответственности `debugprofile.entitlements` в `macos/Runner/`.
- **Когда открывать:** Build или maintenance ссылается на `debugprofile.entitlements`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `info.plist` в каталоге `macos/Runner/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/`.
- **Содержимое:** Исходное содержимое `info.plist`.
- **Обязанности:** Зона ответственности `info.plist` в `macos/Runner/`.
- **Когда открывать:** Build или maintenance ссылается на `info.plist`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `macos` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `mainflutterwindow.swift` в каталоге `macos/Runner/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/`.
- **Содержимое:** Исходное содержимое `mainflutterwindow.swift`.
- **Обязанности:** Зона ответственности `mainflutterwindow.swift` в `macos/Runner/`.
- **Когда открывать:** Build или maintenance ссылается на `mainflutterwindow.swift`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `release.entitlements` в каталоге `macos/Runner/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/Runner/`.
- **Содержимое:** Исходное содержимое `release.entitlements`.
- **Обязанности:** Зона ответственности `release.entitlements` в `macos/Runner/`.
- **Когда открывать:** Build или maintenance ссылается на `release.entitlements`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `runnertests.swift` в каталоге `macos/RunnerTests/`.
- **Зачем:** Поддерживает documented workflow каталога `macos/RunnerTests/`.
- **Содержимое:** Исходное содержимое `runnertests.swift`.
- **Обязанности:** Зона ответственности `runnertests.swift` в `macos/RunnerTests/`.
- **Когда открывать:** Build или maintenance ссылается на `runnertests.swift`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `macos/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** JS hook PocketBase `auth.request_password_reset` на VPS — серверное правило, не код в APK.
- **Зачем:** Server-side правила (auth reset, overlap records) нельзя доверить только клиенту.
- **Содержимое:** JavaScript handler для события `auth.request_password_reset`.
- **Обязанности:** Логика hook `auth.request_password_reset` по `docs/POCKETBASE_MANIFEST.md`.
- **Когда открывать:** Server behavior не совпадает с ожиданиями app для `auth.request_password_reset`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `docs/APP_STRUCTURE.md`, связанные файлы в этой папке.
- **Слой:** Server hook — не бинарник приложения.


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

- **Что это:** JS hook PocketBase `records.interval_sanitize` на VPS — серверное правило, не код в APK.
- **Зачем:** Server-side правила (auth reset, overlap records) нельзя доверить только клиенту.
- **Содержимое:** JavaScript handler для события `records.interval_sanitize`.
- **Обязанности:** Логика hook `records.interval_sanitize` по `docs/POCKETBASE_MANIFEST.md`.
- **Когда открывать:** Server behavior не совпадает с ожиданиями app для `records.interval_sanitize`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** `docs/APP_STRUCTURE.md`, связанные файлы в этой папке.
- **Слой:** Server hook — не бинарник приложения.


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

- **Что это:** Файл `pubspec.lock` в каталоге `./`.
- **Зачем:** Поддерживает documented workflow каталога `./`.
- **Содержимое:** Исходное содержимое `pubspec.lock`.
- **Обязанности:** Зона ответственности `pubspec.lock` в `./`.
- **Когда открывать:** Build или maintenance ссылается на `pubspec.lock`.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** См. также: `pubspec.yaml`, CI, all developer machines.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `pubspec.yaml` в каталоге `./`.
- **Зачем:** Поддерживает documented workflow каталога `./`.
- **Содержимое:** Исходное содержимое `pubspec.yaml`.
- **Обязанности:** Зона ответственности `pubspec.yaml` в `./`.
- **Когда открывать:** Build или maintenance ссылается на `pubspec.yaml`.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** См. также: `pubspec.lock`, `flutter pub get`, all Dart imports.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Когда открывать:** Запуск documented workflow для `architecture_guard.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `docs/APP_STRUCTURE.md`, CI optional.
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
- **Когда открывать:** Запуск documented workflow для `check_no_preparing_ui.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
- **Слой:** Dev/CI script — не runtime приложения.


### `scripts/manual/export_price_reporter_timesheet.dart`

EN:

- **What this is:** Manual export of Price Reporter timeline records to CSV for owner billing/reporting.
- **Why needed:** Internal business reporting — not an in-app user feature.
- **What it contains:** Read-only PocketBase queries + CSV writer to `exports/`.
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
- **Когда открывать:** Запуск documented workflow для `export_price_reporter_timesheet.dart`.
- **Можно удалить?** Возможно — manual owner utility; keep unless export no longer used.
- **Связано с:** См. также: `docs/website/INTERNAL_NOTES_NOT_FOR_SITE.md`, `exports/` folder.
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
- **Когда открывать:** Запуск documented workflow для `generate_app_structure_detailed.py`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `docs/APP_STRUCTURE.md`, `structure_guide_data.py`.
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
- **Когда открывать:** Запуск documented workflow для `run_desktop_voice_acceptance.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
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
- **Когда открывать:** Запуск documented workflow для `smoke_desktop_hotkey.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
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
- **Когда открывать:** Запуск documented workflow для `smoke_desktop_voice_helper_failure.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
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
- **Когда открывать:** Запуск documented workflow для `smoke_desktop_voice_helper_selftest.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
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
- **Когда открывать:** Запуск documented workflow для `smoke_desktop_voice_recording_first.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
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
- **Когда открывать:** Запуск documented workflow для `structure_en_ru_adapt.py`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
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
- **Когда открывать:** Запуск documented workflow для `structure_file_ru_curated.py`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
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
- **Когда открывать:** Запуск documented workflow для `structure_folder_ru_curated.py`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
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
- **Когда открывать:** Запуск documented workflow для `structure_guide_data.py`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
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
- **Когда открывать:** Запуск documented workflow для `structure_role_guides.py`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
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
- **Когда открывать:** Запуск documented workflow для `structure_root_guides.py`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
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
- **Когда открывать:** Запуск documented workflow для `structure_ru_class_adapters.py`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
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
- **Когда открывать:** Запуск documented workflow для `structure_ru_helpers.py`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
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
- **Когда открывать:** Запуск documented workflow для `structure_scan.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
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
- **Когда открывать:** Запуск documented workflow для `td`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
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
- **Когда открывать:** Запуск documented workflow для `td.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `scripts/manual/`, `docs/DEPLOY.md`.
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
- **Когда открывать:** Запуск documented workflow для `sync_locales.dart`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** См. также: `lib/l10n/langs/HELP HOW TO UPDATE the languages`.
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

- **Что это:** Файл `update.ps1` в каталоге `./`.
- **Зачем:** Поддерживает documented workflow каталога `./`.
- **Содержимое:** Исходное содержимое `update.ps1`.
- **Обязанности:** Зона ответственности `update.ps1` в `./`.
- **Когда открывать:** Build или maintenance ссылается на `update.ps1`.
- **Можно удалить?** Нет — задокументированный deploy workflow.
- **Связано с:** См. также: `.github/workflows/deploy.yml`, `docs/DEPLOY.md`, `web/index.html`.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `favicon.png` в каталоге `web/`.
- **Зачем:** Поддерживает documented workflow каталога `web/`.
- **Содержимое:** Исходное содержимое `favicon.png`.
- **Обязанности:** Зона ответственности `favicon.png` в `web/`.
- **Когда открывать:** Build или maintenance ссылается на `favicon.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `web` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-192.png` в каталоге `web/icons/`.
- **Зачем:** Поддерживает documented workflow каталога `web/icons/`.
- **Содержимое:** Исходное содержимое `icon-192.png`.
- **Обязанности:** Зона ответственности `icon-192.png` в `web/icons/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-192.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `web` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-512.png` в каталоге `web/icons/`.
- **Зачем:** Поддерживает documented workflow каталога `web/icons/`.
- **Содержимое:** Исходное содержимое `icon-512.png`.
- **Обязанности:** Зона ответственности `icon-512.png` в `web/icons/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-512.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `web` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-maskable-192.png` в каталоге `web/icons/`.
- **Зачем:** Поддерживает documented workflow каталога `web/icons/`.
- **Содержимое:** Исходное содержимое `icon-maskable-192.png`.
- **Обязанности:** Зона ответственности `icon-maskable-192.png` в `web/icons/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-maskable-192.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `web` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `icon-maskable-512.png` в каталоге `web/icons/`.
- **Зачем:** Поддерживает documented workflow каталога `web/icons/`.
- **Содержимое:** Исходное содержимое `icon-maskable-512.png`.
- **Обязанности:** Зона ответственности `icon-maskable-512.png` в `web/icons/`.
- **Когда открывать:** Build или maintenance ссылается на `icon-maskable-512.png`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `web` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `index.html` в каталоге `web/`.
- **Зачем:** Поддерживает documented workflow каталога `web/`.
- **Содержимое:** Исходное содержимое `index.html`.
- **Обязанности:** Зона ответственности `index.html` в `web/`.
- **Когда открывать:** Build или maintenance ссылается на `index.html`.
- **Можно удалить?** Нет — нужен для web-сборки.
- **Связано с:** См. также: `flutter build web`, `docs/DEPLOY.md`.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `manifest.json` в каталоге `web/`.
- **Зачем:** Поддерживает documented workflow каталога `web/`.
- **Содержимое:** Исходное содержимое `manifest.json`.
- **Обязанности:** Зона ответственности `manifest.json` в `web/`.
- **Когда открывать:** Build или maintenance ссылается на `manifest.json`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `web` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `.gitignore` в каталоге `windows/`.
- **Зачем:** Prevents результат сборки and secrets from entering git history.
- **Содержимое:** Исходное содержимое `.gitignore`.
- **Обязанности:** Зона ответственности `.gitignore` в `windows/`.
- **Когда открывать:** Build или maintenance ссылается на `.gitignore`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `windows` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `cmakelists.txt` в каталоге `windows/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/`.
- **Содержимое:** Исходное содержимое `cmakelists.txt`.
- **Обязанности:** Зона ответственности `cmakelists.txt` в `windows/`.
- **Когда открывать:** Build или maintenance ссылается на `cmakelists.txt`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `windows` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `cmakelists.txt` в каталоге `windows/flutter/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/flutter/`.
- **Содержимое:** Исходное содержимое `cmakelists.txt`.
- **Обязанности:** Зона ответственности `cmakelists.txt` в `windows/flutter/`.
- **Когда открывать:** Build или maintenance ссылается на `cmakelists.txt`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `windows` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `windows/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `windows/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `generated_plugins.cmake` в каталоге `windows/flutter/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/flutter/`.
- **Содержимое:** Исходное содержимое `generated_plugins.cmake`.
- **Обязанности:** Зона ответственности `generated_plugins.cmake` в `windows/flutter/`.
- **Когда открывать:** Build или maintenance ссылается на `generated_plugins.cmake`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `windows/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `cmakelists.txt` в каталоге `windows/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/runner/`.
- **Содержимое:** Исходное содержимое `cmakelists.txt`.
- **Обязанности:** Зона ответственности `cmakelists.txt` в `windows/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `cmakelists.txt`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: Flutter `windows` tooling.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `runner.rc` в каталоге `windows/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/runner/`.
- **Содержимое:** Исходное содержимое `runner.rc`.
- **Обязанности:** Зона ответственности `runner.rc` в `windows/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `runner.rc`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `windows/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `desktop_voice_native_overlay.cpp` в каталоге `windows/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/runner/`.
- **Содержимое:** Исходное содержимое `desktop_voice_native_overlay.cpp`.
- **Обязанности:** Зона ответственности `desktop_voice_native_overlay.cpp` в `windows/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `desktop_voice_native_overlay.cpp`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `windows/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `desktop_voice_native_overlay.h` в каталоге `windows/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/runner/`.
- **Содержимое:** Исходное содержимое `desktop_voice_native_overlay.h`.
- **Обязанности:** Зона ответственности `desktop_voice_native_overlay.h` в `windows/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `desktop_voice_native_overlay.h`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `windows/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `flutter_window.cpp` в каталоге `windows/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/runner/`.
- **Содержимое:** Исходное содержимое `flutter_window.cpp`.
- **Обязанности:** Зона ответственности `flutter_window.cpp` в `windows/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `flutter_window.cpp`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `windows/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `flutter_window.h` в каталоге `windows/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/runner/`.
- **Содержимое:** Исходное содержимое `flutter_window.h`.
- **Обязанности:** Зона ответственности `flutter_window.h` в `windows/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `flutter_window.h`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `windows/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `windows/runner/main.cpp`

EN:

- **What this is:** windows build file `main.cpp` in `windows/runner` — required by Flutter/native toolchain.
- **Why needed:** Without `main.cpp`, windows compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `windows/runner` (open file only when build errors cite it).
- **Responsibilities:** Support windows embedder build for `windows/runner` — not Dart business logic.
- **When to open:** Build log mentions `main.cpp` or `windows/runner`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `windows/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Файл `main.cpp` в каталоге `windows/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/runner/`.
- **Содержимое:** Исходное содержимое `main.cpp`.
- **Обязанности:** Зона ответственности `main.cpp` в `windows/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `main.cpp`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `windows/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `resource.h` в каталоге `windows/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/runner/`.
- **Содержимое:** Исходное содержимое `resource.h`.
- **Обязанности:** Зона ответственности `resource.h` в `windows/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `resource.h`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `windows/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


### `windows/runner/resources/app_icon.ico`

EN:

- **What this is:** windows build file `app_icon.ico` in `windows/runner/resources` — required by Flutter/native toolchain.
- **Why needed:** Without `app_icon.ico`, windows compile or packaging step for this folder may fail.
- **What it contains:** Native/config source for `windows/runner/resources` (open file only when build errors cite it).
- **Responsibilities:** Support windows embedder build for `windows/runner/resources` — not Dart business logic.
- **When to open:** Build log mentions `app_icon.ico` or `windows/runner/resources`.
- **Can it be deleted?** No — required for build/deploy/platform tooling.
- **Connected to:** `windows/` platform folder, Flutter embedder.
- **Layer / owner:** Platform wrapper — required for native/web builds.

RU:

- **Что это:** Файл `app_icon.ico` в каталоге `windows/runner/resources/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/runner/resources/`.
- **Содержимое:** Исходное содержимое `app_icon.ico`.
- **Обязанности:** Зона ответственности `app_icon.ico` в `windows/runner/resources/`.
- **Когда открывать:** Build или maintenance ссылается на `app_icon.ico`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `windows/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `runner.exe.manifest` в каталоге `windows/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/runner/`.
- **Содержимое:** Исходное содержимое `runner.exe.manifest`.
- **Обязанности:** Зона ответственности `runner.exe.manifest` в `windows/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `runner.exe.manifest`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `windows/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `utils.cpp` в каталоге `windows/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/runner/`.
- **Содержимое:** Исходное содержимое `utils.cpp`.
- **Обязанности:** Зона ответственности `utils.cpp` в `windows/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `utils.cpp`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `windows/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `utils.h` в каталоге `windows/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/runner/`.
- **Содержимое:** Исходное содержимое `utils.h`.
- **Обязанности:** Зона ответственности `utils.h` в `windows/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `utils.h`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `windows/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `win32_window.cpp` в каталоге `windows/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/runner/`.
- **Содержимое:** Исходное содержимое `win32_window.cpp`.
- **Обязанности:** Зона ответственности `win32_window.cpp` в `windows/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `win32_window.cpp`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `windows/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.


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

- **Что это:** Файл `win32_window.h` в каталоге `windows/runner/`.
- **Зачем:** Поддерживает documented workflow каталога `windows/runner/`.
- **Содержимое:** Исходное содержимое `win32_window.h`.
- **Обязанности:** Зона ответственности `win32_window.h` в `windows/runner/`.
- **Когда открывать:** Build или maintenance ссылается на `win32_window.h`.
- **Можно удалить?** Нет — нужен для сборки/деплоя платформы.
- **Связано с:** См. также: `windows/` platform folder, Flutter embedder.
- **Слой:** Сопровождение репозитория — не runtime приложения.

