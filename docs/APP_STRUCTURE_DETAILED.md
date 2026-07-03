# APP_STRUCTURE_DETAILED

Owner-readable guide: every tracked folder and file in plain language (EN + RU).

**Generated at git SHA `4164311` on 2026-07-03.**

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

- **Что это за папка:** Папка `.cursor/` репозитория Life OS.
- **Зачем нужна:** Файлы здесь нужны для сборки, CI или сопровождения проекта.
- **Что здесь лежит:** Tracked-файлы перечислены ниже.
- **На что влияет в приложении:** Workflow или сборка, связанная с этим путём.
- **Когда открывать:** Сопровождение или сборка, связанная с `.cursor/`.
- **Можно удалить?** Нет — часть репозитория.
- **Связанные пути:** `.cursorrules` pointer at repo root.

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
- **Что здесь лежит:** Tracked-файлы в `.github/` — описаны ниже по одному.
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

- **Что это за папка:** Платформенная папка Android: `android/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Папка `docs/` репозитория Life OS.
- **Зачем нужна:** Файлы здесь нужны для сборки, CI или сопровождения проекта.
- **Что здесь лежит:** Tracked-файлы перечислены ниже.
- **На что влияет в приложении:** Workflow или сборка, связанная с этим путём.
- **Когда открывать:** Сопровождение или сборка, связанная с `docs/`.
- **Можно удалить?** Нет — часть репозитория.
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

- **Что это за папка:** Папка `installer/` репозитория Life OS.
- **Зачем нужна:** Файлы здесь нужны для сборки, CI или сопровождения проекта.
- **Что здесь лежит:** Tracked-файлы перечислены ниже.
- **На что влияет в приложении:** Workflow или сборка, связанная с этим путём.
- **Когда открывать:** Сопровождение или сборка, связанная с `installer/`.
- **Можно удалить?** Нет — часть репозитория.
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

- **Что это за папка:** Папка `integration_test/` репозитория Life OS.
- **Зачем нужна:** Файлы здесь нужны для сборки, CI или сопровождения проекта.
- **Что здесь лежит:** Tracked-файлы перечислены ниже.
- **На что влияет в приложении:** Workflow или сборка, связанная с этим путём.
- **Когда открывать:** Сопровождение или сборка, связанная с `integration_test/`.
- **Можно удалить?** Нет — часть репозитория.
- **Связанные пути:** `test/` unit tests.

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

- **Что это за папка:** Платформенная папка iOS: `ios/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает iOS-версию из файлов под `ios/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `ios/`.
- **На что влияет в приложении:** Только сборка и native-поведение iOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки iOS или native-проблема в `ios/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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
- **Связанные пути:** `pubspec.yaml`, `main.dart`, platform folders.

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

- **Что это за папка:** Платформенная папка Linux: `linux/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Linux-версию из файлов под `linux/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `linux/`.
- **На что влияет в приложении:** Только сборка и native-поведение Linux — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Linux или native-проблема в `linux/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
- **Связанные пути:** `windows/`, `macos/` sibling desktop folders.

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

- **Что это за папка:** Платформенная папка macOS: `macos/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает macOS-версию из файлов под `macos/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `macos/`.
- **На что влияет в приложении:** Только сборка и native-поведение macOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки macOS или native-проблема в `macos/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
- **Связанные пути:** `ios/` (mobile Apple) vs this desktop target.

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

- **Что это за папка:** Папка `pb_hooks/` репозитория Life OS.
- **Зачем нужна:** Файлы здесь нужны для сборки, CI или сопровождения проекта.
- **Что здесь лежит:** Tracked-файлы перечислены ниже.
- **На что влияет в приложении:** Workflow или сборка, связанная с этим путём.
- **Когда открывать:** Сопровождение или сборка, связанная с `pb_hooks/`.
- **Можно удалить?** Нет — часть репозитория.
- **Связанные пути:** `docs/POCKETBASE_MANIFEST.md`, `docs/DEPLOY.md` auth admin section.

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

- **Что это за папка:** Папка `scripts/` репозитория Life OS.
- **Зачем нужна:** Файлы здесь нужны для сборки, CI или сопровождения проекта.
- **Что здесь лежит:** Tracked-файлы перечислены ниже.
- **На что влияет в приложении:** Workflow или сборка, связанная с этим путём.
- **Когда открывать:** Сопровождение или сборка, связанная с `scripts/`.
- **Можно удалить?** Нет — часть репозитория.
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

- **Что это за папка:** Папка `test/` репозитория Life OS.
- **Зачем нужна:** Файлы здесь нужны для сборки, CI или сопровождения проекта.
- **Что здесь лежит:** Tracked-файлы перечислены ниже.
- **На что влияет в приложении:** Workflow или сборка, связанная с этим путём.
- **Когда открывать:** Сопровождение или сборка, связанная с `test/`.
- **Можно удалить?** Нет — часть репозитория.
- **Связанные пути:** Production files with matching names under `lib/`.

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

- **Что это за папка:** Платформенная папка Web: `web/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Web-версию из файлов под `web/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `web/`.
- **На что влияет в приложении:** Только сборка и native-поведение Web — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Web или native-проблема в `web/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Windows: `windows/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Windows-версию из файлов под `windows/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `windows/`.
- **На что влияет в приложении:** Только сборка и native-поведение Windows — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Windows или native-проблема в `windows/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
- **Связанные пути:** `installer/windows/`, `docs/DEPLOY.md` Windows section.

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

- **Что это за папка:** Папка `.cursor/rules/` репозитория Life OS.
- **Зачем нужна:** Файлы здесь нужны для сборки, CI или сопровождения проекта.
- **Что здесь лежит:** Tracked-файлы перечислены ниже.
- **На что влияет в приложении:** Workflow или сборка, связанная с этим путём.
- **Когда открывать:** Сопровождение или сборка, связанная с `.cursor/rules/`.
- **Можно удалить?** Нет — часть репозитория.
- **Связанные пути:** `.cursorrules` pointer at repo root.

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

- **Что это за папка:** Папка `.github/workflows/` репозитория Life OS.
- **Зачем нужна:** Файлы здесь нужны для сборки, CI или сопровождения проекта.
- **Что здесь лежит:** Tracked-файлы перечислены ниже.
- **На что влияет в приложении:** Workflow или сборка, связанная с этим путём.
- **Когда открывать:** Сопровождение или сборка, связанная с `.github/workflows/`.
- **Можно удалить?** Нет — часть репозитория.
- **Связанные пути:** `docs/DEPLOY.md`, `update.ps1`.

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

- **Что это за папка:** Платформенная папка Android: `android/app/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
- **Связанные пути:** `android/` root Gradle.

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

- **Что это за папка:** Платформенная папка Android: `android/gradle/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/gradle/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/gradle/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
- **Связанные пути:** `android/settings.gradle`.

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

- **Что это за папка:** Документация в `docs/reports/` — written specs, не runtime-код.
- **Зачем нужна:** Текстовые правила и отчёты для owner и AI; приложение их не исполняет.
- **Что здесь лежит:** Markdown-файлы с правилами и отчётами — список ниже.
- **На что влияет в приложении:** Решения при разработке — не бинарник приложения.
- **Когда открывать:** Нужно прочитать или обновить документацию по теме папки.
- **Можно удалить?** Нет — governing или report документация.
- **Связанные пути:** `CHANGELOG.md`, governing docs in `docs/`.

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

- **Что это за папка:** Документация в `docs/website/` — written specs, не runtime-код.
- **Зачем нужна:** Текстовые правила и отчёты для owner и AI; приложение их не исполняет.
- **Что здесь лежит:** Markdown-файлы с правилами и отчётами — список ниже.
- **На что влияет в приложении:** Решения при разработке — не бинарник приложения.
- **Когда открывать:** Нужно прочитать или обновить документацию по теме папки.
- **Можно удалить?** Нет — governing или report документация.
- **Связанные пути:** `docs/DEPLOY.md` GitHub Pages.

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

- **Что это за папка:** Папка `installer/windows/` репозитория Life OS.
- **Зачем нужна:** Файлы здесь нужны для сборки, CI или сопровождения проекта.
- **Что здесь лежит:** Tracked-файлы перечислены ниже.
- **На что влияет в приложении:** Workflow или сборка, связанная с этим путём.
- **Когда открывать:** Сопровождение или сборка, связанная с `installer/windows/`.
- **Можно удалить?** Нет — часть репозитория.
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

- **Что это за папка:** Платформенная папка iOS: `ios/Flutter/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает iOS-версию из файлов под `ios/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `ios/Flutter/`.
- **На что влияет в приложении:** Только сборка и native-поведение iOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки iOS или native-проблема в `ios/Flutter/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
- **Связанные пути:** `ios/Podfile`.

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

- **Что это за папка:** Платформенная папка iOS: `ios/Runner/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает iOS-версию из файлов под `ios/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `ios/Runner/`.
- **На что влияет в приложении:** Только сборка и native-поведение iOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки iOS или native-проблема в `ios/Runner/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
- **Связанные пути:** `ios/Flutter/`.

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

- **Что это за папка:** Платформенная папка iOS: `ios/Runner.xcodeproj/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает iOS-версию из файлов под `ios/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `ios/Runner.xcodeproj/`.
- **На что влияет в приложении:** Только сборка и native-поведение iOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки iOS или native-проблема в `ios/Runner.xcodeproj/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
- **Связанные пути:** `ios/Runner/`, `ios/Flutter/`.

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

- **Что это за папка:** Платформенная папка iOS: `ios/Runner.xcworkspace/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает iOS-версию из файлов под `ios/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `ios/Runner.xcworkspace/`.
- **На что влияет в приложении:** Только сборка и native-поведение iOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки iOS или native-проблема в `ios/Runner.xcworkspace/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка iOS: `ios/RunnerTests/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает iOS-версию из файлов под `ios/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `ios/RunnerTests/`.
- **На что влияет в приложении:** Только сборка и native-поведение iOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки iOS или native-проблема в `ios/RunnerTests/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Код приложения в `lib/core/` — часть Flutter-приложения (core).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/core/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `core`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связанные пути:** `docs/DESIGN_SYSTEM.md`, `lib/features/`, `lib/data/models.dart` (types only).

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

- **Что это за папка:** Код приложения в `lib/data/` — часть Flutter-приложения (data).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/data/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `data`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/features/` — часть Flutter-приложения (features).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связанные пути:** `lib/shell/` (navigation host), `lib/data/` (saves/loads).

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

- **Что это за папка:** Код приложения в `lib/l10n/` — часть Flutter-приложения (l10n).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/l10n/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `l10n`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связанные пути:** `scripts/sync_locales.dart`, `lib/l10n/langs/HELP HOW TO UPDATE the languages`.

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

- **Что это за папка:** Код приложения в `lib/services/` — часть Flutter-приложения (services).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/services/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `services`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связанные пути:** `lib/data/plan_service.dart` alarm reschedule requests.

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

- **Что это за папка:** Код приложения в `lib/shell/` — часть Flutter-приложения (shell).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/shell/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `shell`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связанные пути:** `lib/app_shell.dart`, all `lib/features/*` tabs.

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

- **Что это за папка:** Платформенная папка Linux: `linux/flutter/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Linux-версию из файлов под `linux/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `linux/flutter/`.
- **На что влияет в приложении:** Только сборка и native-поведение Linux — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Linux или native-проблема в `linux/flutter/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
- **Связанные пути:** `linux/CMakeLists.txt`, `flutter pub get`.

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

- **Что это за папка:** Платформенная папка Linux: `linux/runner/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Linux-версию из файлов под `linux/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `linux/runner/`.
- **На что влияет в приложении:** Только сборка и native-поведение Linux — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Linux или native-проблема в `linux/runner/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
- **Связанные пути:** `linux/CMakeLists.txt`.

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

- **Что это за папка:** Платформенная папка macOS: `macos/Flutter/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает macOS-версию из файлов под `macos/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `macos/Flutter/`.
- **На что влияет в приложении:** Только сборка и native-поведение macOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки macOS или native-проблема в `macos/Flutter/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
- **Связанные пути:** `macos/Runner/`.

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

- **Что это за папка:** Платформенная папка macOS: `macos/Runner/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает macOS-версию из файлов под `macos/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `macos/Runner/`.
- **На что влияет в приложении:** Только сборка и native-поведение macOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки macOS или native-проблема в `macos/Runner/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
- **Связанные пути:** `macos/Flutter/`.

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

- **Что это за папка:** Платформенная папка macOS: `macos/Runner.xcodeproj/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает macOS-версию из файлов под `macos/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `macos/Runner.xcodeproj/`.
- **На что влияет в приложении:** Только сборка и native-поведение macOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки macOS или native-проблема в `macos/Runner.xcodeproj/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка macOS: `macos/Runner.xcworkspace/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает macOS-версию из файлов под `macos/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `macos/Runner.xcworkspace/`.
- **На что влияет в приложении:** Только сборка и native-поведение macOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки macOS или native-проблема в `macos/Runner.xcworkspace/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка macOS: `macos/RunnerTests/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает macOS-версию из файлов под `macos/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `macos/RunnerTests/`.
- **На что влияет в приложении:** Только сборка и native-поведение macOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки macOS или native-проблема в `macos/RunnerTests/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
- **Связанные пути:** `macos/Runner/`.

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

- **Что это за папка:** Папка скрипты: `scripts/audit/`.
- **Зачем нужна:** Поддержка CI, deploy, audit или регрессионных проверок.
- **Что здесь лежит:** Файлы перечислены ниже по одному.
- **На что влияет в приложении:** Качество и workflow — не экраны приложения.
- **Когда открывать:** Запуск workflow или падение CI.
- **Можно удалить?** Нет — задокументированный workflow.
- **Связанные пути:** `docs/APP_STRUCTURE.md`.

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

- **Что это за папка:** Папка скрипты: `scripts/manual/`.
- **Зачем нужна:** Поддержка CI, deploy, audit или регрессионных проверок.
- **Что здесь лежит:** Файлы перечислены ниже по одному.
- **На что влияет в приложении:** Качество и workflow — не экраны приложения.
- **Когда открывать:** Запуск workflow или падение CI.
- **Можно удалить?** Нет — задокументированный workflow.
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

- **Что это за папка:** Платформенная папка Web: `web/icons/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Web-версию из файлов под `web/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `web/icons/`.
- **На что влияет в приложении:** Только сборка и native-поведение Web — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Web или native-проблема в `web/icons/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Windows: `windows/flutter/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Windows-версию из файлов под `windows/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `windows/flutter/`.
- **На что влияет в приложении:** Только сборка и native-поведение Windows — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Windows или native-проблема в `windows/flutter/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Windows: `windows/runner/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Windows-версию из файлов под `windows/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `windows/runner/`.
- **На что влияет в приложении:** Только сборка и native-поведение Windows — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Windows или native-проблема в `windows/runner/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
- **Связанные пути:** `installer/windows/`.

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

- **Что это за папка:** Платформенная папка Android: `android/app/src/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/gradle/wrapper/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/gradle/wrapper/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/gradle/wrapper/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Папка `installer/windows/scripts/` репозитория Life OS.
- **Зачем нужна:** Файлы здесь нужны для сборки, CI или сопровождения проекта.
- **Что здесь лежит:** Tracked-файлы перечислены ниже.
- **На что влияет в приложении:** Workflow или сборка, связанная с этим путём.
- **Когда открывать:** Сопровождение или сборка, связанная с `installer/windows/scripts/`.
- **Можно удалить?** Нет — часть репозитория.
- **Связанные пути:** `installer/windows/prepare_stt_payload.ps1`, `counter.iss`.

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

- **Что это за папка:** Папка `installer/windows/stt_helper_build/` репозитория Life OS.
- **Зачем нужна:** Файлы здесь нужны для сборки, CI или сопровождения проекта.
- **Что здесь лежит:** Tracked-файлы перечислены ниже.
- **На что влияет в приложении:** Workflow или сборка, связанная с этим путём.
- **Когда открывать:** Сопровождение или сборка, связанная с `installer/windows/stt_helper_build/`.
- **Можно удалить?** Нет — часть репозитория.
- **Связанные пути:** `installer/windows/build_stt_helper_en.ps1`, `lib/core/services/desktop_stt_helper_service.dart`.

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

- **Что это за папка:** Платформенная папка iOS: `ios/Runner.xcodeproj/project.xcworkspace/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает iOS-версию из файлов под `ios/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `ios/Runner.xcodeproj/project.xcworkspace/`.
- **На что влияет в приложении:** Только сборка и native-поведение iOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки iOS или native-проблема в `ios/Runner.xcodeproj/project.xcworkspace/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка iOS: `ios/Runner.xcodeproj/xcshareddata/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает iOS-версию из файлов под `ios/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `ios/Runner.xcodeproj/xcshareddata/`.
- **На что влияет в приложении:** Только сборка и native-поведение iOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки iOS или native-проблема в `ios/Runner.xcodeproj/xcshareddata/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка iOS: `ios/Runner.xcworkspace/xcshareddata/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает iOS-версию из файлов под `ios/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `ios/Runner.xcworkspace/xcshareddata/`.
- **На что влияет в приложении:** Только сборка и native-поведение iOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки iOS или native-проблема в `ios/Runner.xcworkspace/xcshareddata/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка iOS: `ios/Runner/Assets.xcassets/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает iOS-версию из файлов под `ios/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `ios/Runner/Assets.xcassets/`.
- **На что влияет в приложении:** Только сборка и native-поведение iOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки iOS или native-проблема в `ios/Runner/Assets.xcassets/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка iOS: `ios/Runner/Base.lproj/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает iOS-версию из файлов под `ios/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `ios/Runner/Base.lproj/`.
- **На что влияет в приложении:** Только сборка и native-поведение iOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки iOS или native-проблема в `ios/Runner/Base.lproj/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Код приложения в `lib/core/diagnostics/` — часть Flutter-приложения (core/diagnostics).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/core/diagnostics/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `core/diagnostics`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/core/env/` — часть Flutter-приложения (core/env).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/core/env/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `core/env`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связанные пути:** `.gitignore` entry for `lib/core/env/env.dart`.

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

- **Что это за папка:** Код приложения в `lib/core/navigation/` — часть Flutter-приложения (core/navigation).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/core/navigation/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `core/navigation`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/core/performance/` — часть Flutter-приложения (core/performance).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/core/performance/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `core/performance`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/core/services/` — часть Flutter-приложения (core/services).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/core/services/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `core/services`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/core/time/` — часть Flutter-приложения (core/time).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/core/time/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `core/time`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/core/widgets/` — часть Flutter-приложения (core/widgets).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/core/widgets/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `core/widgets`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связанные пути:** `docs/DESIGN_SYSTEM.md`, `lib/features/dev/component_lab_view.dart`.

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

- **Что это за папка:** Код приложения в `lib/data/cache/` — часть Flutter-приложения (data/cache).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/data/cache/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `data/cache`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/data/categories/` — часть Flutter-приложения (data/categories).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/data/categories/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `data/categories`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/data/local_sync/` — часть Flutter-приложения (data/local_sync).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/data/local_sync/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `data/local_sync`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/data/models/` — часть Flutter-приложения (data/models).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/data/models/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `data/models`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/data/plans/` — часть Flutter-приложения (data/plans).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/data/plans/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `data/plans`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связанные пути:** `lib/data/plan_service.dart`, `lib/features/planning/`, `lib/features/lists/`.

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

- **Что это за папка:** Код приложения в `lib/data/profile/` — часть Flutter-приложения (data/profile).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/data/profile/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `data/profile`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/data/records/` — часть Flutter-приложения (data/records).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/data/records/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `data/records`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/features/auth/` — часть Flutter-приложения (features/auth).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/auth/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features/auth`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/features/calendar/` — часть Flutter-приложения (features/calendar).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/calendar/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features/calendar`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/features/categories/` — часть Flutter-приложения (features/categories).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/categories/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features/categories`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/features/dev/` — часть Flutter-приложения (features/dev).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/dev/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features/dev`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/features/lists/` — часть Flutter-приложения (features/lists).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/lists/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features/lists`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/features/planning/` — часть Flutter-приложения (features/planning).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/planning/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features/planning`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связанные пути:** `lib/shell/` tab host, `lib/data/plan_service.dart`.

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

- **Что это за папка:** Код приложения в `lib/features/profile/` — часть Flutter-приложения (features/profile).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/profile/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features/profile`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/features/shared/` — часть Flutter-приложения (features/shared).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/shared/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features/shared`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/features/stats/` — часть Flutter-приложения (features/stats).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/stats/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features/stats`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/features/timeline/` — часть Flutter-приложения (features/timeline).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/timeline/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features/timeline`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/features/wear/` — часть Flutter-приложения (features/wear).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/wear/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features/wear`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/l10n/langs/` — часть Flutter-приложения (l10n/langs).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/l10n/langs/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `l10n/langs`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Платформенная папка macOS: `macos/Runner.xcodeproj/project.xcworkspace/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает macOS-версию из файлов под `macos/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `macos/Runner.xcodeproj/project.xcworkspace/`.
- **На что влияет в приложении:** Только сборка и native-поведение macOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки macOS или native-проблема в `macos/Runner.xcodeproj/project.xcworkspace/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка macOS: `macos/Runner.xcodeproj/xcshareddata/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает macOS-версию из файлов под `macos/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `macos/Runner.xcodeproj/xcshareddata/`.
- **На что влияет в приложении:** Только сборка и native-поведение macOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки macOS или native-проблема в `macos/Runner.xcodeproj/xcshareddata/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка macOS: `macos/Runner.xcworkspace/xcshareddata/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает macOS-версию из файлов под `macos/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `macos/Runner.xcworkspace/xcshareddata/`.
- **На что влияет в приложении:** Только сборка и native-поведение macOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки macOS или native-проблема в `macos/Runner.xcworkspace/xcshareddata/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка macOS: `macos/Runner/Assets.xcassets/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает macOS-версию из файлов под `macos/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `macos/Runner/Assets.xcassets/`.
- **На что влияет в приложении:** Только сборка и native-поведение macOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки macOS или native-проблема в `macos/Runner/Assets.xcassets/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка macOS: `macos/Runner/Base.lproj/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает macOS-версию из файлов под `macos/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `macos/Runner/Base.lproj/`.
- **На что влияет в приложении:** Только сборка и native-поведение macOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки macOS или native-проблема в `macos/Runner/Base.lproj/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка macOS: `macos/Runner/Configs/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает macOS-версию из файлов под `macos/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `macos/Runner/Configs/`.
- **На что влияет в приложении:** Только сборка и native-поведение macOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки macOS или native-проблема в `macos/Runner/Configs/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Windows: `windows/runner/resources/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Windows-версию из файлов под `windows/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `windows/runner/resources/`.
- **На что влияет в приложении:** Только сборка и native-поведение Windows — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Windows или native-проблема в `windows/runner/resources/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/debug/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/debug/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/debug/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/main/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/main/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/main/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/profile/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/profile/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/profile/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка iOS: `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает iOS-версию из файлов под `ios/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/`.
- **На что влияет в приложении:** Только сборка и native-поведение iOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки iOS или native-проблема в `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка iOS: `ios/Runner.xcodeproj/xcshareddata/xcschemes/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает iOS-версию из файлов под `ios/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `ios/Runner.xcodeproj/xcshareddata/xcschemes/`.
- **На что влияет в приложении:** Только сборка и native-поведение iOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки iOS или native-проблема в `ios/Runner.xcodeproj/xcshareddata/xcschemes/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает iOS-версию из файлов под `ios/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **На что влияет в приложении:** Только сборка и native-поведение iOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки iOS или native-проблема в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка iOS: `ios/Runner/Assets.xcassets/LaunchImage.imageset/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает iOS-версию из файлов под `ios/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **На что влияет в приложении:** Только сборка и native-поведение iOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки iOS или native-проблема в `ios/Runner/Assets.xcassets/LaunchImage.imageset/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Код приложения в `lib/core/widgets/plan_card/` — часть Flutter-приложения (core/widgets/plan_card).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/core/widgets/plan_card/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `core/widgets/plan_card`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/core/widgets/plan_time_task_card/` — часть Flutter-приложения (core/widgets/plan_time_task_card).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/core/widgets/plan_time_task_card/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `core/widgets/plan_time_task_card`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/features/planning/settings/` — часть Flutter-приложения (features/planning/settings).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/planning/settings/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features/planning/settings`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/features/planning/time_view/` — часть Flutter-приложения (features/planning/time_view).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/planning/time_view/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features/planning/time_view`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/features/planning/widgets/` — часть Flutter-приложения (features/planning/widgets).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/planning/widgets/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features/planning/widgets`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/features/profile/settings/` — часть Flutter-приложения (features/profile/settings).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/profile/settings/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features/profile/settings`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Код приложения в `lib/features/shared/edit_sheet/` — часть Flutter-приложения (features/shared/edit_sheet).
- **Зачем нужна:** Всё под `lib/` попадает в APK/web/desktop build и определяет поведение продукта.
- **Что здесь лежит:** Dart-модули в `lib/features/shared/edit_sheet/` — перечень файлов ниже.
- **На что влияет в приложении:** Поведение и UI модуля, названного в пути папки.
- **Когда открывать:** Правки или баги в `features/shared/edit_sheet`.
- **Можно удалить?** Нет — нужен для работы приложения.
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

- **Что это за папка:** Платформенная папка macOS: `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает macOS-версию из файлов под `macos/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/`.
- **На что влияет в приложении:** Только сборка и native-поведение macOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки macOS или native-проблема в `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка macOS: `macos/Runner.xcodeproj/xcshareddata/xcschemes/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает macOS-версию из файлов под `macos/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `macos/Runner.xcodeproj/xcshareddata/xcschemes/`.
- **На что влияет в приложении:** Только сборка и native-поведение macOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки macOS или native-проблема в `macos/Runner.xcodeproj/xcshareddata/xcschemes/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка macOS: `macos/Runner/Assets.xcassets/AppIcon.appiconset/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает macOS-версию из файлов под `macos/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **На что влияет в приложении:** Только сборка и native-поведение macOS — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки macOS или native-проблема в `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/main/kotlin/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/main/kotlin/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/main/kotlin/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/main/res/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/main/res/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/main/res/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/main/kotlin/com/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/main/kotlin/com/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/main/kotlin/com/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/main/res/drawable/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/main/res/drawable/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/main/res/drawable/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/main/res/drawable-v21/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/main/res/drawable-v21/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/main/res/drawable-v21/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/main/res/mipmap-hdpi/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/main/res/mipmap-hdpi/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/main/res/mipmap-hdpi/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/main/res/mipmap-mdpi/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/main/res/mipmap-mdpi/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/main/res/mipmap-mdpi/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/main/res/mipmap-xhdpi/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/main/res/mipmap-xhdpi/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/main/res/mipmap-xhdpi/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/main/res/mipmap-xxhdpi/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/main/res/mipmap-xxhdpi/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/main/res/mipmap-xxhdpi/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/main/res/mipmap-xxxhdpi/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/main/res/mipmap-xxxhdpi/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/main/res/mipmap-xxxhdpi/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/main/res/values/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/main/res/values/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/main/res/values/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/main/res/values-night/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/main/res/values-night/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/main/res/values-night/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/main/kotlin/com/example/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/main/kotlin/com/example/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/main/kotlin/com/example/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это за папка:** Платформенная папка Android: `android/app/src/main/kotlin/com/example/counter/` — native-обёртка и конфиги Flutter для этой платформы.
- **Зачем нужна:** Flutter собирает Android-версию из файлов под `android/`; это не Dart-код экранов.
- **Что здесь лежит:** Native-конфиги и generated-файлы embedder в `android/app/src/main/kotlin/com/example/counter/`.
- **На что влияет в приложении:** Только сборка и native-поведение Android — не экраны в `lib/`.
- **Когда открывать:** Ошибка сборки Android или native-проблема в `android/app/src/main/kotlin/com/example/counter/`.
- **Можно удалить?** Нет — нужна для сборки платформы.
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

- **Что это:** Файл `flutter_expert.mdc` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `flutter_expert.mdc`.
- **Содержимое:** Содержимое `flutter_expert.mdc` — открыть файл при правках.
- **Обязанности:** Роль `flutter_expert.mdc` в модуле `.cursor/rules`.
- **Когда открывать:** Когда ломается поведение, связанное с `flutter_expert.mdc`.
- **Можно удалить?** Нет — конфигурация/инструмент репозитория.
- **Связано с:** Связи файла `flutter_expert.mdc` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Вспомогательный файл репозитория.


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
- **Можно удалить?** Нет — Cursor ожидает rules в root или `.cursor/rules/`.
- **Связано с:** Связи файла `.cursorrules` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Настройка IDE-агента — не приложение.


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

- **Что это:** Файл `copilot-instructions.md` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `copilot-instructions.md`.
- **Содержимое:** Содержимое `copilot-instructions.md` — открыть файл при правках.
- **Обязанности:** Роль `copilot-instructions.md` в модуле `.github`.
- **Когда открывать:** Когда ломается поведение, связанное с `copilot-instructions.md`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** Связи файла `copilot-instructions.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Сборка/деплой/сервер.


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

- **Что это:** Файл `deploy.yml` — platform/config файл.
- **Зачем:** Описан в APP_STRUCTURE.md; нужен для текущего поведения.
- **Содержимое:** Исходник `deploy.yml`.
- **Обязанности:** Роль `deploy.yml` в модуле `.github/workflows`.
- **Когда открывать:** Когда ломается поведение, связанное с `deploy.yml`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** Связи файла `deploy.yml` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Сборка/деплой/сервер.


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

- **Что это:** Файл `windows-desktop-build.yml` — platform/config файл.
- **Зачем:** Описан в APP_STRUCTURE.md; нужен для текущего поведения.
- **Содержимое:** Исходник `windows-desktop-build.yml`.
- **Обязанности:** Роль `windows-desktop-build.yml` в модуле `.github/workflows`.
- **Когда открывать:** Когда ломается поведение, связанное с `windows-desktop-build.yml`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** Связи файла `windows-desktop-build.yml` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Сборка/деплой/сервер.


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

- **Что это:** Список того, что Git не должен коммитить: build output, временные логи, локальные env-файлы, Android/Gradle мусор, exports, IDE/cache.
- **Зачем:** Защищает репозиторий от случайного мусора и секретов в истории git.
- **Содержимое:** Паттерны для `build/`, `.dart_tool/`, `lib/core/env/env.dart`, perf captures, `exports/`, `.gradle`.
- **Обязанности:** Не допускать commit build-артефактов и секретов.
- **Когда открывать:** Появилась новая локальная папка, которую нельзя коммитить; случайно добавили build в git.
- **Можно удалить?** Нет — гигиена и безопасность репозитория.
- **Связано с:** Все разработчики, CI, вывод `flutter build`.
- **Слой:** Гигиена репозитория — не runtime приложения.


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
- **Можно удалить?** Нет — удалять только если Flutter пересоздаст файл и diff проверен.
- **Связано с:** Связи файла `.metadata` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Метаданные Flutter — не код приложения.


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
- **Можно удалить?** Нет — документ #1 Project Knowledge pack.
- **Связано с:** Связи файла `AGENTS.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Можно удалить?** Нет — документ Project Knowledge pack.
- **Связано с:** Связи файла `AGENT_NAVIGATION.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Можно удалить?** Нет — история Project Knowledge pack.
- **Связано с:** Связи файла `CHANGELOG.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Можно удалить?** Возможно — GitHub работает и без README, но лучше оставить.
- **Связано с:** GitHub; законы проекта — в `docs/`.
- **Слой:** Презентация репо — не приложение.


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
- **Можно удалить?** Нет — CI и IDE зависят от него.
- **Связано с:** Связи файла `analysis_options.yaml` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Конфиг analyzer — не runtime.


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

- **Что это:** Локальная сборка Android release APK — отдельный APK на каждый CPU (split per ABI) со штампом git commit в приложении.
- **Зачем:** Короче, чем вручную писать `flutter build apk`; подставляет `GIT_COMMIT` и `BUILD_TIME` для экрана About.
- **Содержимое:** `flutter pub get` → `flutter build apk --release --split-per-abi` с dart-defines; при ошибке icon tree-shake — повтор с `--no-tree-shake-icons`; выводит размеры APK.
- **Обязанности:** Собрать APK в `build/app/outputs/flutter-apk/` (для современных телефонов: `app-arm64-v8a-release.apk`).
- **Когда открывать:** Тест release APK на Android-устройстве.
- **Можно удалить?** Нет — задокументированный путь локальной сборки Android.
- **Связано с:** Связи файла `android.ps1` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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

- **Что это:** Platform-файл android: `.gitignore` — platform/config файл.
- **Зачем:** Нужен для сборки `android` на платформе android.
- **Содержимое:** Native/config-содержимое `.gitignore` в `android`.
- **Обязанности:** Поддержка embedder-сборки для `android`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `.gitignore` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл android: `build.gradle.kts` — Gradle-скрипт Android-сборки.
- **Зачем:** Нужен для сборки `android/app` на платформе android.
- **Содержимое:** Native/config-содержимое `build.gradle.kts` в `android/app`.
- **Обязанности:** Поддержка embedder-сборки для `android/app`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связано с:** Связи файла `build.gradle.kts` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Android build config.


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

- **Что это:** Platform-файл android: `google-services.json` — Gradle-скрипт Android-сборки.
- **Зачем:** Нужен для сборки `android/app` на платформе android.
- **Содержимое:** Native/config-содержимое `google-services.json` в `android/app`.
- **Обязанности:** Поддержка embedder-сборки для `android/app`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `google-services.json` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл android: `proguard-rules.pro` — platform/config файл.
- **Зачем:** Нужен для сборки `android/app` на платформе android.
- **Содержимое:** Native/config-содержимое `proguard-rules.pro` в `android/app`.
- **Обязанности:** Поддержка embedder-сборки для `android/app`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `proguard-rules.pro` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Манифест Android (debug/profile) — разрешения ОС, имя приложения и activity Flutter.
- **Зачем:** Android читает XML при установке: mic, notifications, запуск приложения.
- **Содержимое:** Теги `<uses-permission>`, имя приложения, intent filters.
- **Обязанности:** Permissions ОС и deep links для этой build variant.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `AndroidManifest.xml` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Манифест Android (release/main) — разрешения ОС, имя приложения и activity Flutter.
- **Зачем:** Android читает XML при установке: mic, notifications, запуск приложения.
- **Содержимое:** Теги `<uses-permission>`, имя приложения, intent filters.
- **Обязанности:** Permissions ОС и deep links для этой build variant.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `AndroidManifest.xml` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл android: `MainActivity.kt` — Kotlin-точка входа Flutter на Android.
- **Зачем:** Нужен для сборки `android/app/src/main/kotlin/com/example/counter` на платформе android.
- **Содержимое:** Native/config-содержимое `MainActivity.kt` в `android/app/src/main/kotlin/com/example/counter`.
- **Обязанности:** Поддержка embedder-сборки для `android/app/src/main/kotlin/com/example/counter`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `MainActivity.kt` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл android: `launch_background.xml` — platform/config файл.
- **Зачем:** Нужен для сборки `android/app/src/main/res/drawable-v21` на платформе android.
- **Содержимое:** Native/config-содержимое `launch_background.xml` в `android/app/src/main/res/drawable-v21`.
- **Обязанности:** Поддержка embedder-сборки для `android/app/src/main/res/drawable-v21`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `launch_background.xml` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл android: `launch_background.xml` — platform/config файл.
- **Зачем:** Нужен для сборки `android/app/src/main/res/drawable` на платформе android.
- **Содержимое:** Native/config-содержимое `launch_background.xml` в `android/app/src/main/res/drawable`.
- **Обязанности:** Поддержка embedder-сборки для `android/app/src/main/res/drawable`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `launch_background.xml` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл android: `ic_launcher.png` — иконка приложения на home screen.
- **Зачем:** Нужен для сборки `android/app/src/main/res/mipmap-hdpi` на платформе android.
- **Содержимое:** Native/config-содержимое `ic_launcher.png` в `android/app/src/main/res/mipmap-hdpi`.
- **Обязанности:** Поддержка embedder-сборки для `android/app/src/main/res/mipmap-hdpi`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `ic_launcher.png` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл android: `ic_launcher.png` — иконка приложения на home screen.
- **Зачем:** Нужен для сборки `android/app/src/main/res/mipmap-mdpi` на платформе android.
- **Содержимое:** Native/config-содержимое `ic_launcher.png` в `android/app/src/main/res/mipmap-mdpi`.
- **Обязанности:** Поддержка embedder-сборки для `android/app/src/main/res/mipmap-mdpi`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `ic_launcher.png` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл android: `ic_launcher.png` — иконка приложения на home screen.
- **Зачем:** Нужен для сборки `android/app/src/main/res/mipmap-xhdpi` на платформе android.
- **Содержимое:** Native/config-содержимое `ic_launcher.png` в `android/app/src/main/res/mipmap-xhdpi`.
- **Обязанности:** Поддержка embedder-сборки для `android/app/src/main/res/mipmap-xhdpi`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `ic_launcher.png` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл android: `ic_launcher.png` — иконка приложения на home screen.
- **Зачем:** Нужен для сборки `android/app/src/main/res/mipmap-xxhdpi` на платформе android.
- **Содержимое:** Native/config-содержимое `ic_launcher.png` в `android/app/src/main/res/mipmap-xxhdpi`.
- **Обязанности:** Поддержка embedder-сборки для `android/app/src/main/res/mipmap-xxhdpi`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `ic_launcher.png` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл android: `ic_launcher.png` — иконка приложения на home screen.
- **Зачем:** Нужен для сборки `android/app/src/main/res/mipmap-xxxhdpi` на платформе android.
- **Содержимое:** Native/config-содержимое `ic_launcher.png` в `android/app/src/main/res/mipmap-xxxhdpi`.
- **Обязанности:** Поддержка embedder-сборки для `android/app/src/main/res/mipmap-xxxhdpi`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `ic_launcher.png` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл android: `styles.xml` — XML-стили Android.
- **Зачем:** Нужен для сборки `android/app/src/main/res/values-night` на платформе android.
- **Содержимое:** Native/config-содержимое `styles.xml` в `android/app/src/main/res/values-night`.
- **Обязанности:** Поддержка embedder-сборки для `android/app/src/main/res/values-night`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `styles.xml` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл android: `styles.xml` — XML-стили Android.
- **Зачем:** Нужен для сборки `android/app/src/main/res/values` на платформе android.
- **Содержимое:** Native/config-содержимое `styles.xml` в `android/app/src/main/res/values`.
- **Обязанности:** Поддержка embedder-сборки для `android/app/src/main/res/values`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `styles.xml` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Манифест Android (debug/profile) — разрешения ОС, имя приложения и activity Flutter.
- **Зачем:** Android читает XML при установке: mic, notifications, запуск приложения.
- **Содержимое:** Теги `<uses-permission>`, имя приложения, intent filters.
- **Обязанности:** Permissions ОС и deep links для этой build variant.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `AndroidManifest.xml` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл android: `build.gradle.kts` — Gradle-скрипт Android-сборки.
- **Зачем:** Нужен для сборки `android` на платформе android.
- **Содержимое:** Native/config-содержимое `build.gradle.kts` в `android`.
- **Обязанности:** Поддержка embedder-сборки для `android`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки Android.
- **Связано с:** Связи файла `build.gradle.kts` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Android build config.


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

- **Что это:** Platform-файл android: `gradle.properties` — Gradle-скрипт Android-сборки.
- **Зачем:** Нужен для сборки `android` на платформе android.
- **Содержимое:** Native/config-содержимое `gradle.properties` в `android`.
- **Обязанности:** Поддержка embedder-сборки для `android`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `gradle.properties` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки android: `gradle-wrapper.properties` в `android/gradle/wrapper`.
- **Зачем:** Нужен для сборки android; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `gradle-wrapper.properties` в `android/gradle/wrapper`.
- **Обязанности:** Поддержка embedder android.
- **Когда открывать:** Ошибка сборки с `gradle-wrapper.properties`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `android/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл android: `settings.gradle.kts` — Gradle-скрипт Android-сборки.
- **Зачем:** Нужен для сборки `android` на платформе android.
- **Содержимое:** Native/config-содержимое `settings.gradle.kts` в `android`.
- **Обязанности:** Поддержка embedder-сборки для `android`.
- **Когда открывать:** Ошибка Gradle/Android-сборки или permission на устройстве.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `settings.gradle.kts` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Документ `APP_STRUCTURE.md` — правила и заметки по теме: APP STRUCTURE.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `APP STRUCTURE`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — Project Knowledge pack.
- **Связано с:** Связи файла `APP_STRUCTURE.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Governing structure doc.


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

- **Что это:** Документ `APP_STRUCTURE_DETAILED.md` — правила и заметки по теме: APP STRUCTURE DETAILED.
- **Зачем:** Описан в APP_STRUCTURE.md; нужен для текущего поведения.
- **Содержимое:** Исходник `APP_STRUCTURE_DETAILED.md`.
- **Обязанности:** Ответы на вопросы по `APP STRUCTURE DETAILED`.
- **Когда открывать:** Правила проекта и деплой — не runtime.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** Связи файла `APP_STRUCTURE_DETAILED.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `ARCHITECTURE.md` — правила и заметки по теме: ARCHITECTURE.
- **Зачем:** Описан в APP_STRUCTURE.md; нужен для текущего поведения.
- **Содержимое:** Исходник `ARCHITECTURE.md`.
- **Обязанности:** Ответы на вопросы по `ARCHITECTURE`.
- **Когда открывать:** Правила проекта и деплой — не runtime.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** Связи файла `ARCHITECTURE.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `DATA_MAP.md` — правила и заметки по теме: DATA MAP.
- **Зачем:** Описан в APP_STRUCTURE.md; нужен для текущего поведения.
- **Содержимое:** Исходник `DATA_MAP.md`.
- **Обязанности:** Ответы на вопросы по `DATA MAP`.
- **Когда открывать:** Правила проекта и деплой — не runtime.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** Связи файла `DATA_MAP.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `DEPLOY.md` — правила и заметки по теме: DEPLOY.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `DEPLOY`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — Project Knowledge pack.
- **Связано с:** Связи файла `DEPLOY.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Deploy guide — Project Knowledge.


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

- **Что это:** Документ `DESIGN_SYSTEM.md` — правила и заметки по теме: DESIGN SYSTEM.
- **Зачем:** Описан в APP_STRUCTURE.md; нужен для текущего поведения.
- **Содержимое:** Исходник `DESIGN_SYSTEM.md`.
- **Обязанности:** Ответы на вопросы по `DESIGN SYSTEM`.
- **Когда открывать:** Правила проекта и деплой — не runtime.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** Связи файла `DESIGN_SYSTEM.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `POCKETBASE_MANIFEST.md` — правила и заметки по теме: POCKETBASE MANIFEST.
- **Зачем:** Описан в APP_STRUCTURE.md; нужен для текущего поведения.
- **Содержимое:** Исходник `POCKETBASE_MANIFEST.md`.
- **Обязанности:** Ответы на вопросы по `POCKETBASE MANIFEST`.
- **Когда открывать:** Правила проекта и деплой — не runtime.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** Связи файла `POCKETBASE_MANIFEST.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `PROJECT_KNOWLEDGE_PACK.md` — правила и заметки по теме: PROJECT KNOWLEDGE PACK.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `PROJECT KNOWLEDGE PACK`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — upload checklist.
- **Связано с:** Связи файла `PROJECT_KNOWLEDGE_PACK.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Meta checklist — repo-only.


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

- **Что это:** Документ `ROADMAP.md` — правила и заметки по теме: ROADMAP.
- **Зачем:** Описан в APP_STRUCTURE.md; нужен для текущего поведения.
- **Содержимое:** Исходник `ROADMAP.md`.
- **Обязанности:** Ответы на вопросы по `ROADMAP`.
- **Когда открывать:** Правила проекта и деплой — не runtime.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** Связи файла `ROADMAP.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `UX_CONTRACT.md` — правила и заметки по теме: UX CONTRACT.
- **Зачем:** Описан в APP_STRUCTURE.md; нужен для текущего поведения.
- **Содержимое:** Исходник `UX_CONTRACT.md`.
- **Обязанности:** Ответы на вопросы по `UX CONTRACT`.
- **Когда открывать:** Правила проекта и деплой — не runtime.
- **Можно удалить?** Нет — governing документация.
- **Связано с:** Связи файла `UX_CONTRACT.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `DESIGN_SYSTEM_INVENTORY.md` — правила и заметки по теме: DESIGN SYSTEM INVENTORY.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `DESIGN SYSTEM INVENTORY`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — governing-документация проекта.
- **Связано с:** Связи файла `DESIGN_SYSTEM_INVENTORY.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md` — правила и заметки по теме: FINAL STRUCTURE PARITY AND DOC CLEANUP 2026-07-03.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `FINAL STRUCTURE PARITY AND DOC CLEANUP 2026-07-03`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — current cleanup/structure report or upload checklist.
- **Связано с:** Связи файла `FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `FULL_REPO_NECESSITY_CLEANUP_2026-07-03.md` — правила и заметки по теме: FULL REPO NECESSITY CLEANUP 2026-07-03.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `FULL REPO NECESSITY CLEANUP 2026-07-03`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — current cleanup/structure report or upload checklist.
- **Связано с:** Связи файла `FULL_REPO_NECESSITY_CLEANUP_2026-07-03.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `CONTENT_LIBRARY.md` — правила и заметки по теме: CONTENT LIBRARY.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `CONTENT LIBRARY`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Связано с:** Связи файла `CONTENT_LIBRARY.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `FEATURE_MATRIX.md` — правила и заметки по теме: FEATURE MATRIX.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `FEATURE MATRIX`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Связано с:** Связи файла `FEATURE_MATRIX.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `HOMEPAGE_WIREFRAME_V1.md` — правила и заметки по теме: HOMEPAGE WIREFRAME V1.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `HOMEPAGE WIREFRAME V1`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Связано с:** Связи файла `HOMEPAGE_WIREFRAME_V1.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `INTERNAL_NOTES_NOT_FOR_SITE.md` — правила и заметки по теме: INTERNAL NOTES NOT FOR SITE.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `INTERNAL NOTES NOT FOR SITE`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Связано с:** Связи файла `INTERNAL_NOTES_NOT_FOR_SITE.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `POSITIONING_V1.md` — правила и заметки по теме: POSITIONING V1.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `POSITIONING V1`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Связано с:** Связи файла `POSITIONING_V1.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `PRODUCT_INVENTORY.md` — правила и заметки по теме: PRODUCT INVENTORY.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `PRODUCT INVENTORY`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Связано с:** Связи файла `PRODUCT_INVENTORY.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `PUBLIC_COPY_DRAFTS.md` — правила и заметки по теме: PUBLIC COPY DRAFTS.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `PUBLIC COPY DRAFTS`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Связано с:** Связи файла `PUBLIC_COPY_DRAFTS.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `SCREENSHOT_SHOTLIST.md` — правила и заметки по теме: SCREENSHOT SHOTLIST.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `SCREENSHOT SHOTLIST`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Связано с:** Связи файла `SCREENSHOT_SHOTLIST.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `WEBSITE_CLAIMS_REVIEW.md` — правила и заметки по теме: WEBSITE CLAIMS REVIEW.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `WEBSITE CLAIMS REVIEW`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Связано с:** Связи файла `WEBSITE_CLAIMS_REVIEW.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `WEBSITE_IMPLEMENTATION_OPTIONS.md` — правила и заметки по теме: WEBSITE IMPLEMENTATION OPTIONS.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `WEBSITE IMPLEMENTATION OPTIONS`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Связано с:** Связи файла `WEBSITE_IMPLEMENTATION_OPTIONS.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `WEBSITE_PAGE_STRUCTURE.md` — правила и заметки по теме: WEBSITE PAGE STRUCTURE.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `WEBSITE PAGE STRUCTURE`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Связано с:** Связи файла `WEBSITE_PAGE_STRUCTURE.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `WEBSITE_TZ.md` — правила и заметки по теме: WEBSITE TZ.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `WEBSITE TZ`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Связано с:** Связи файла `WEBSITE_TZ.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Документ `WEBSITE_V1_SCOPE.md` — правила и заметки по теме: WEBSITE V1 SCOPE.
- **Зачем:** Читается owner и AI; не исполняется приложением.
- **Содержимое:** Markdown-секции по этой теме.
- **Обязанности:** Ответы на вопросы по `WEBSITE V1 SCOPE`.
- **Когда открывать:** Нужна written-инструкция по теме файла.
- **Можно удалить?** Нет — intentionally maintained marketing copy (repo-only, not Project Knowledge pack).
- **Связано с:** Связи файла `WEBSITE_V1_SCOPE.md` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Документация.


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

- **Что это:** Файл сборки installer: `build_stt_helper_en.ps1` в `installer/windows`.
- **Зачем:** Нужен для сборки installer; без него возможны ошибки compile.
- **Содержимое:** Содержимое `build_stt_helper_en.ps1` — открыть файл при правках.
- **Обязанности:** Поддержка embedder installer.
- **Когда открывать:** Ошибка сборки с `build_stt_helper_en.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** Папка `installer/`.
- **Слой:** Сборка/деплой/сервер.


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

- **Что это:** Файл `counter.iss` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `counter.iss`.
- **Содержимое:** Содержимое `counter.iss` — открыть файл при правках.
- **Обязанности:** Роль `counter.iss` в модуле `installer/windows`.
- **Когда открывать:** Когда build или maintenance ссылается на `counter.iss`.
- **Можно удалить?** Нет — required for Windows installer.
- **Связано с:** Связи файла `counter.iss` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Windows installer config.


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

- **Что это:** Файл сборки installer: `install-cpp-atl.ps1` в `installer/windows`.
- **Зачем:** Нужен для сборки installer; без него возможны ошибки compile.
- **Содержимое:** Содержимое `install-cpp-atl.ps1` — открыть файл при правках.
- **Обязанности:** Поддержка embedder installer.
- **Когда открывать:** Ошибка сборки с `install-cpp-atl.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** Папка `installer/`.
- **Слой:** Сборка/деплой/сервер.


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

- **Что это:** Файл сборки installer: `prepare_stt_payload.ps1` в `installer/windows`.
- **Зачем:** Нужен для сборки installer; без него возможны ошибки compile.
- **Содержимое:** Содержимое `prepare_stt_payload.ps1` — открыть файл при правках.
- **Обязанности:** Поддержка embedder installer.
- **Когда открывать:** Ошибка сборки с `prepare_stt_payload.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** Папка `installer/`.
- **Слой:** Сборка/деплой/сервер.


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

- **Что это:** Файл сборки installer: `win_speech_wav.ps1` в `installer/windows/scripts`.
- **Зачем:** Нужен для сборки installer; без него возможны ошибки compile.
- **Содержимое:** Содержимое `win_speech_wav.ps1` — открыть файл при правках.
- **Обязанности:** Поддержка embedder installer.
- **Когда открывать:** Ошибка сборки с `win_speech_wav.ps1`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** Папка `installer/`.
- **Слой:** Сборка/деплой/сервер.


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

- **Что это:** Файл сборки installer: `counter_stt_helper.exe` в `installer/windows/stt_helper_build`.
- **Зачем:** Нужен для сборки installer; без него возможны ошибки compile.
- **Содержимое:** Содержимое `counter_stt_helper.exe` — открыть файл при правках.
- **Обязанности:** Поддержка embedder installer.
- **Когда открывать:** Ошибка сборки с `counter_stt_helper.exe`.
- **Можно удалить?** Нет — нужен для сборки/деплоя/аудита.
- **Связано с:** Папка `installer/`.
- **Слой:** Сборка/деплой/сервер.


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

- **Что это:** Файл `perf_date_swipe_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `perf_date_swipe_test.dart`.
- **Содержимое:** Содержимое `perf_date_swipe_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `perf_date_swipe_test.dart` в модуле `integration_test`.
- **Когда открывать:** Когда build или maintenance ссылается на `perf_date_swipe_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `perf_date_swipe_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Platform-файл ios: `.gitignore` — platform/config файл.
- **Зачем:** Нужен для сборки `ios` на платформе ios.
- **Содержимое:** Native/config-содержимое `.gitignore` в `ios`.
- **Обязанности:** Поддержка embedder-сборки для `ios`.
- **Когда открывать:** Когда ломается поведение, связанное с `.gitignore`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `.gitignore` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `AppFrameworkInfo.plist` в `ios/Flutter`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `AppFrameworkInfo.plist` в `ios/Flutter`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `AppFrameworkInfo.plist`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Debug.xcconfig` в `ios/Flutter`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Debug.xcconfig` в `ios/Flutter`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Debug.xcconfig`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Release.xcconfig` в `ios/Flutter`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Release.xcconfig` в `ios/Flutter`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Release.xcconfig`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `project.pbxproj` в `ios/Runner.xcodeproj`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `project.pbxproj` в `ios/Runner.xcodeproj`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `project.pbxproj`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `contents.xcworkspacedata` в `ios/Runner.xcodeproj/project.xcworkspace`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `contents.xcworkspacedata` в `ios/Runner.xcodeproj/project.xcworkspace`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `contents.xcworkspacedata`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `IDEWorkspaceChecks.plist` в `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `IDEWorkspaceChecks.plist` в `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `IDEWorkspaceChecks.plist`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `WorkspaceSettings.xcsettings` в `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `WorkspaceSettings.xcsettings` в `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `WorkspaceSettings.xcsettings`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Runner.xcscheme` в `ios/Runner.xcodeproj/xcshareddata/xcschemes`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Runner.xcscheme` в `ios/Runner.xcodeproj/xcshareddata/xcschemes`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Runner.xcscheme`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `contents.xcworkspacedata` в `ios/Runner.xcworkspace`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `contents.xcworkspacedata` в `ios/Runner.xcworkspace`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `contents.xcworkspacedata`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `IDEWorkspaceChecks.plist` в `ios/Runner.xcworkspace/xcshareddata`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `IDEWorkspaceChecks.plist` в `ios/Runner.xcworkspace/xcshareddata`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `IDEWorkspaceChecks.plist`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `WorkspaceSettings.xcsettings` в `ios/Runner.xcworkspace/xcshareddata`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `WorkspaceSettings.xcsettings` в `ios/Runner.xcworkspace/xcshareddata`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `WorkspaceSettings.xcsettings`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `AppDelegate.swift` в `ios/Runner`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `AppDelegate.swift` в `ios/Runner`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `AppDelegate.swift`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Contents.json` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Contents.json` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Contents.json`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Icon-App-1024x1024@1x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Icon-App-1024x1024@1x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Icon-App-1024x1024@1x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Icon-App-20x20@1x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Icon-App-20x20@1x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Icon-App-20x20@1x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Icon-App-20x20@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Icon-App-20x20@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Icon-App-20x20@2x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Icon-App-20x20@3x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Icon-App-20x20@3x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Icon-App-20x20@3x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Icon-App-29x29@1x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Icon-App-29x29@1x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Icon-App-29x29@1x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Icon-App-29x29@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Icon-App-29x29@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Icon-App-29x29@2x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Icon-App-29x29@3x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Icon-App-29x29@3x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Icon-App-29x29@3x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Icon-App-40x40@1x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Icon-App-40x40@1x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Icon-App-40x40@1x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Icon-App-40x40@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Icon-App-40x40@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Icon-App-40x40@2x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Icon-App-40x40@3x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Icon-App-40x40@3x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Icon-App-40x40@3x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Icon-App-60x60@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Icon-App-60x60@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Icon-App-60x60@2x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Icon-App-60x60@3x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Icon-App-60x60@3x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Icon-App-60x60@3x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Icon-App-76x76@1x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Icon-App-76x76@1x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Icon-App-76x76@1x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Icon-App-76x76@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Icon-App-76x76@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Icon-App-76x76@2x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Icon-App-83.5x83.5@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Icon-App-83.5x83.5@2x.png` в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Icon-App-83.5x83.5@2x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Contents.json` в `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Contents.json` в `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Contents.json`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `LaunchImage.png` в `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `LaunchImage.png` в `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `LaunchImage.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `LaunchImage@2x.png` в `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `LaunchImage@2x.png` в `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `LaunchImage@2x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `LaunchImage@3x.png` в `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `LaunchImage@3x.png` в `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `LaunchImage@3x.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `README.md` в `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `README.md` в `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `README.md`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `LaunchScreen.storyboard` в `ios/Runner/Base.lproj`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `LaunchScreen.storyboard` в `ios/Runner/Base.lproj`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `LaunchScreen.storyboard`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Main.storyboard` в `ios/Runner/Base.lproj`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Main.storyboard` в `ios/Runner/Base.lproj`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Main.storyboard`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл ios: `Info.plist` — platform/config файл.
- **Зачем:** Нужен для сборки `ios/Runner` на платформе ios.
- **Содержимое:** Native/config-содержимое `Info.plist` в `ios/Runner`.
- **Обязанности:** Поддержка embedder-сборки для `ios/Runner`.
- **Когда открывать:** Когда ломается поведение, связанное с `Info.plist`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `Info.plist` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `Runner-Bridging-Header.h` в `ios/Runner`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Runner-Bridging-Header.h` в `ios/Runner`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `Runner-Bridging-Header.h`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `SceneDelegate.swift` в `ios/Runner`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `SceneDelegate.swift` в `ios/Runner`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `SceneDelegate.swift`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки ios: `RunnerTests.swift` в `ios/RunnerTests`.
- **Зачем:** Нужен для сборки ios; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `RunnerTests.swift` в `ios/RunnerTests`.
- **Обязанности:** Поддержка embedder ios.
- **Когда открывать:** Ошибка сборки с `RunnerTests.swift`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `ios/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл `app_shell.dart` — platform/config файл.
- **Зачем:** Описан в APP_STRUCTURE.md; нужен для текущего поведения.
- **Содержимое:** Исходник `app_shell.dart`.
- **Обязанности:** Роль `app_shell.dart` в модуле `lib`.
- **Когда открывать:** Когда ломается поведение, связанное с `app_shell.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `app_shell.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Вспомогательный файл репозитория.


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

- **Что это:** Foundation-код `app_build_info.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `app_build_info.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Build metadata.
- **Когда открывать:** Когда ломается поведение, связанное с `app_build_info.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `app_build_info.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `app_colors.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `app_colors.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Color tokens.
- **Когда открывать:** Когда ломается поведение, связанное с `app_colors.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `app_colors.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `app_icons.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `app_icons.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Canonical icon tokens (timezone family, shared glyphs).
- **Когда открывать:** Когда ломается поведение, связанное с `app_icons.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `app_icons.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `app_snackbar.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Утилиты (`AppSnack`).
- **Обязанности:** Общая инфраструктура приложения: `AppSnack` toasts.
- **Когда открывать:** Когда ломается поведение, связанное с `app_snackbar.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `app_snackbar.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `category_color_palette.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `category_color_palette.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Category tile palette.
- **Когда открывать:** Когда ломается поведение, связанное с `category_color_palette.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `category_color_palette.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `constants.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `constants.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: UI limits, global keys.
- **Когда открывать:** Когда ломается поведение, связанное с `constants.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `constants.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `date_pager_settle_gate.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `date_pager_settle_gate.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Shared date `PageView` settle coordinator.
- **Когда открывать:** Когда ломается поведение, связанное с `date_pager_settle_gate.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `date_pager_settle_gate.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `date_swipe_physics.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `date_swipe_physics.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Date swipe physics.
- **Когда открывать:** Когда ломается поведение, связанное с `date_swipe_physics.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `date_swipe_physics.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_log.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Утилиты (`DesktopVoiceLog`).
- **Обязанности:** Общая инфраструктура приложения: `DesktopVoiceLog` — concise desktop-voice pipeline markers (debug/profile only; release quiet).
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_log.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_log.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_pipeline.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_pipeline.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Desktop-voice pipeline step helpers built on `DesktopVoiceLog`.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_pipeline.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_pipeline.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `plan_duplicate_log.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `plan_duplicate_log.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Plan duplicate detection logs.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_duplicate_log.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_duplicate_log.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `platform_log.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `platform_log.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Platform-specific log sinks.
- **Когда открывать:** Когда ломается поведение, связанное с `platform_log.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `platform_log.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `runtime_log.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `runtime_log.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Uncaught error logging.
- **Когда открывать:** Когда ломается поведение, связанное с `runtime_log.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `runtime_log.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `startup_log.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `startup_log.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Boot-phase structured logs.
- **Когда открывать:** Когда ломается поведение, связанное с `startup_log.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `startup_log.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** example file `env.dart.example` в `lib/core/env` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/core/env` использует `env.dart.example` в сборке или workflow.
- **Содержимое:** Открывать `env.dart.example` при правках в `lib/core/env`.
- **Обязанности:** Роль `env.dart.example` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `env.dart.example`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `env.dart.example` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `link_scalar.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `link_scalar.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Plan link scalar helper.
- **Когда открывать:** Когда ломается поведение, связанное с `link_scalar.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `link_scalar.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `app_navigator.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `app_navigator.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: `appRootNavigatorKey` — root navigator for desktop overlays when main window is hidden.
- **Когда открывать:** Когда ломается поведение, связанное с `app_navigator.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `app_navigator.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `shell_side_navigation.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `shell_side_navigation.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Desktop/web side navigation rail.
- **Когда открывать:** Когда ломается поведение, связанное с `shell_side_navigation.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `shell_side_navigation.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `rebuild_metrics.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Утилиты (`RebuildMetrics`).
- **Обязанности:** Общая инфраструктура приложения: Rebuild/frame metrics (`--dart-define=PERF_DIAG` gated).
- **Когда открывать:** Когда ломается поведение, связанное с `rebuild_metrics.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `rebuild_metrics.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `runtime_flags.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `runtime_flags.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Feature kill switches (date strip, warm window, etc.).
- **Когда открывать:** Когда ломается поведение, связанное с `runtime_flags.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `runtime_flags.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `shell_flags.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `shell_flags.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Shell tab stack behavior flags.
- **Когда открывать:** Когда ломается поведение, связанное с `shell_flags.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `shell_flags.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `picker_entry_modes.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `picker_entry_modes.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Platform-aware picker entry (keyboard vs touch).
- **Когда открывать:** Когда ломается поведение, связанное с `picker_entry_modes.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `picker_entry_modes.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `plan_category_lookup.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `plan_category_lookup.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Category presentation lookup (shell-injected).
- **Когда открывать:** Когда ломается поведение, связанное с `plan_category_lookup.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_category_lookup.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_hotkey_codec.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_hotkey_codec.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Desktop hotkey string encode/decode.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_hotkey_codec.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_hotkey_codec.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_stt_diagnostics.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_stt_diagnostics.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: STT helper diagnostics markers.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_stt_diagnostics.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_stt_diagnostics.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_stt_helper_service.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_stt_helper_service.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Desktop GOLOS STT helper subprocess and HTTP transcribe.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_stt_helper_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_stt_helper_service.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_tray_service.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_tray_service.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: System tray entry (conditional export).
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_tray_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_tray_service.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_tray_service_io.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_tray_service_io.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Windows tray implementation.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_tray_service_io.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_tray_service_io.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_tray_service_stub.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_tray_service_stub.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Non-desktop tray stub.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_tray_service_stub.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_tray_service_stub.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_acceptance_bridge.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_acceptance_bridge.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Acceptance-test hooks for desktop voice.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_acceptance_bridge.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_acceptance_bridge.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_attempt_log.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_attempt_log.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Persisted voice attempt history for profile UI.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_attempt_log.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_attempt_log.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_audio_capture.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_audio_capture.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Mic capture for desktop voice.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_audio_capture.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_audio_capture.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_benchmark_service.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_benchmark_service.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Desktop voice benchmark harness.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_benchmark_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_benchmark_service.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_command_normalize.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_command_normalize.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Transcript normalization before parse/submit.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_command_normalize.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_command_normalize.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_confirmation.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_confirmation.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Start/stop voice confirmation copy.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_confirmation.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_confirmation.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_engine.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_engine.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Desktop voice engine lifecycle.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_engine.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_engine.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_hotkey.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_hotkey.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Global desktop voice hotkey coordinator.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_hotkey.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_hotkey.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_hotkey_io.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_hotkey_io.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Windows hotkey registration.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_hotkey_io.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_hotkey_io.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_hotkey_markers.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_hotkey_markers.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Hotkey self-test / acceptance markers.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_hotkey_markers.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_hotkey_markers.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_hotkey_stub.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_hotkey_stub.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Non-desktop hotkey stub.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_hotkey_stub.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_hotkey_stub.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_native_overlay.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_native_overlay.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Native overlay channel bridge.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_native_overlay.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_native_overlay.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_overlay_bridge.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_overlay_bridge.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Overlay ↔ Flutter bridge.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_overlay_bridge.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_overlay_bridge.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_overlay_host.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_overlay_host.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Overlay host conditional export.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_overlay_host.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_overlay_host.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_overlay_host_io.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_overlay_host_io.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Windows overlay host.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_overlay_host_io.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_overlay_host_io.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_overlay_host_stub.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_overlay_host_stub.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Non-desktop overlay host stub.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_overlay_host_stub.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_overlay_host_stub.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_overlay_service.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_overlay_service.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Native overlay state machine.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_overlay_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_overlay_service.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_recognizer.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_recognizer.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Desktop voice recognizer interface.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_recognizer.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_recognizer.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_recognizer_factory.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_recognizer_factory.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Platform recognizer factory.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_recognizer_factory.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_recognizer_factory.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_recognizer_io.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_recognizer_io.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Windows recognizer implementation.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_recognizer_io.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_recognizer_io.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_recognizer_stub.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_recognizer_stub.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Non-desktop recognizer stub.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_recognizer_stub.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_recognizer_stub.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_record_submit.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_record_submit.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Parsed voice command → `writeRecord` bridge.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_record_submit.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_record_submit.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_settings.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_settings.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Local desktop voice prefs (SharedPreferences).
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_settings.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_settings.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_smoke_bridge.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_smoke_bridge.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Smoke-test hooks for desktop voice.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_smoke_bridge.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_smoke_bridge.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_user_error.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_user_error.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Friendly desktop voice error mapping.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_user_error.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_user_error.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_voice_window_flags.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_voice_window_flags.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Desktop window visibility flags.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_window_flags.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_window_flags.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `desktop_win_speech_service.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `desktop_win_speech_service.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Windows speech platform adapter.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_win_speech_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_win_speech_service.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `pcm_audio_utils.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `pcm_audio_utils.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: PCM/WAV audio helpers for desktop STT.
- **Когда открывать:** Когда ломается поведение, связанное с `pcm_audio_utils.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `pcm_audio_utils.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `speech_engine_handle.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `speech_engine_handle.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Speech-to-text engine lifecycle.
- **Когда открывать:** Когда ломается поведение, связанное с `speech_engine_handle.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `speech_engine_handle.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `speech_listen_locale.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `speech_listen_locale.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: STT locale resolution.
- **Когда открывать:** Когда ломается поведение, связанное с `speech_listen_locale.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `speech_listen_locale.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `shell_adaptive.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `shell_adaptive.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Side vs bottom navigation breakpoint.
- **Когда открывать:** Когда ломается поведение, связанное с `shell_adaptive.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `shell_adaptive.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `shell_layout_state.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `shell_layout_state.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: `ShellLayoutController` / FAB clearance.
- **Когда открывать:** Когда ломается поведение, связанное с `shell_layout_state.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `shell_layout_state.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `tag_contrast.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `tag_contrast.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Tag foreground/background contrast.
- **Когда открывать:** Когда ломается поведение, связанное с `tag_contrast.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `tag_contrast.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `theme.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `theme.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: `ThemeData`, density, input decoration.
- **Когда открывать:** Когда ломается поведение, связанное с `theme.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `theme.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `app_clock.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `app_clock.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Injectable wall clock + timezone label.
- **Когда открывать:** Когда ломается поведение, связанное с `app_clock.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `app_clock.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `category_timezone_options.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `category_timezone_options.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Per-category timezone option list.
- **Когда открывать:** Когда ломается поведение, связанное с `category_timezone_options.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `category_timezone_options.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `plan_time_labels.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `plan_time_labels.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Plan time label formatting.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_time_labels.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_time_labels.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `plan_time_visible_window.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `plan_time_visible_window.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Extended Time View day window math (−3..27 h).
- **Когда открывать:** Когда ломается поведение, связанное с `plan_time_visible_window.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_time_visible_window.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `profile_timezone_actions.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `profile_timezone_actions.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Injectable profile timezone read/write hooks (`ProfileTimezoneActions`).
- **Когда открывать:** Когда ломается поведение, связанное с `profile_timezone_actions.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `profile_timezone_actions.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `profile_timezone_catalog.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `profile_timezone_catalog.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Canonical profile timezone catalog, IANA IDs, DST labels.
- **Когда открывать:** Когда ломается поведение, связанное с `profile_timezone_catalog.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `profile_timezone_catalog.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `wall_clock.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `wall_clock.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Wall-clock formatting helpers.
- **Когда открывать:** Когда ломается поведение, связанное с `wall_clock.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `wall_clock.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `url_strategy_stub.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `url_strategy_stub.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Web URL strategy conditional import.
- **Когда открывать:** Когда ломается поведение, связанное с `url_strategy_stub.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `url_strategy_stub.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Foundation — тема, время, voice, диагностика.


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

- **Что это:** Foundation-код `web_redirect.dart` — тема, время, voice или диагностика.
- **Зачем:** Общий код: тема, время, voice — не один экран.
- **Содержимое:** Содержимое `web_redirect.dart` — открыть файл при правках.
- **Обязанности:** Общая инфраструктура приложения: Production web OAuth redirect URI helper.
- **Когда открывать:** Когда ломается поведение, связанное с `web_redirect.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `web_redirect.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: Live clock chip
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Live clock chip.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `app_bar_live_clock.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Live clock chip.
- **Когда открывать:** Когда ломается поведение, связанное с `app_bar_live_clock.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `app_bar_live_clock.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: `AppButton`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — `AppButton`.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `app_button.dart` — открыть файл при правках.
- **Обязанности:** UI-логика: `AppButton`.
- **Когда открывать:** Когда ломается поведение, связанное с `app_button.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Роль: `AppButton`
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
- **Connected to:** Role: `AppIconButton`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — `AppIconButton`.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `app_icon_button.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: `AppIconButton`.
- **Когда открывать:** Когда ломается поведение, связанное с `app_icon_button.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `app_icon_button.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: `AppLoading`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — `AppLoading`.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `app_loading.dart` — открыть файл при правках.
- **Обязанности:** UI-логика: `AppLoading`.
- **Когда открывать:** Когда ломается поведение, связанное с `app_loading.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `app_loading.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: Mic level visualization bars for voice UI
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Mic level visualization bars for voice UI.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `app_mic_level_bars.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Mic level visualization bars for voice UI.
- **Когда открывать:** Когда ломается поведение, связанное с `app_mic_level_bars.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `app_mic_level_bars.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Общий виджет design system — `AppSettingsPageBody`, `AppSettingsSectionCard`, settings row helpers.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `app_settings_layout.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: `AppSettingsPageBody`, `AppSettingsSectionCard`, settings row helpers.
- **Когда открывать:** Когда ломается поведение, связанное с `app_settings_layout.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `app_settings_layout.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: `AppErrorState`, `AppEmptyState`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — `AppErrorState`, `AppEmptyState`.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `app_state_views.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: `AppErrorState`, `AppEmptyState`.
- **Когда открывать:** Когда ломается поведение, связанное с `app_state_views.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `app_state_views.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: Canonical solid timezone icon family
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Canonical solid timezone icon family.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `app_timezone_icon.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Canonical solid timezone icon family.
- **Когда открывать:** Когда ломается поведение, связанное с `app_timezone_icon.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `app_timezone_icon.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: `TagChip`, `CategoryChip`, tag quick-pick strip
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — `TagChip`, `CategoryChip`, tag quick-pick strip.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `chip_component.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: `TagChip`, `CategoryChip`, tag quick-pick strip.
- **Когда открывать:** Когда ломается поведение, связанное с `chip_component.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `chip_component.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: Compact segmented controls
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Compact segmented controls.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `compact_nav_controls.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Compact segmented controls.
- **Когда открывать:** Когда ломается поведение, связанное с `compact_nav_controls.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `compact_nav_controls.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Общий виджет design system — `showConfirmDialog`.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `confirm_dialog.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: `showConfirmDialog`.
- **Когда открывать:** Когда ломается поведение, связанное с `confirm_dialog.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `confirm_dialog.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Общий виджет design system — Day content pager strip.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `day_content_strip.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Day content pager strip.
- **Когда открывать:** Когда ломается поведение, связанное с `day_content_strip.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `day_content_strip.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Общий виджет design system — Mounted day window.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `day_window.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Mounted day window.
- **Когда открывать:** Когда ломается поведение, связанное с `day_window.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `day_window.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: Date/time header strip
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Date/time header strip.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `global_app_header.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Date/time header strip.
- **Когда открывать:** Когда ломается поведение, связанное с `global_app_header.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `global_app_header.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: Optional lazy shell tab stack
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Optional lazy shell tab stack.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `lazy_indexed_stack.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Optional lazy shell tab stack.
- **Когда открывать:** Когда ломается поведение, связанное с `lazy_indexed_stack.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `lazy_indexed_stack.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Общий виджет design system — Card foundation for Component Lab.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `life_card.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Card foundation for Component Lab.
- **Когда открывать:** Когда ломается поведение, связанное с `life_card.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `life_card.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: Desktop/web drag scroll
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Desktop/web drag scroll.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `mouse_drag_scroll_behavior.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Desktop/web drag scroll.
- **Когда открывать:** Когда ломается поведение, связанное с `mouse_drag_scroll_behavior.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `mouse_drag_scroll_behavior.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: Unified date+time picker
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Unified date+time picker.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `omni_date_time_picker_dialog.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Unified date+time picker.
- **Когда открывать:** Когда ломается поведение, связанное с `omni_date_time_picker_dialog.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `omni_date_time_picker_dialog.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: `PlanCard` wrapper
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — `PlanCard` wrapper.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Виджет (`PlanCard`).
- **Обязанности:** Общий UI-компонент: `PlanCard` wrapper.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_card.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_card.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_controls.dart`.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `plan_card_controls.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Re-export stub → `plan_time_task_card/plan_card_controls.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_card_controls.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_card_controls.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_geometry.dart`.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `plan_card_geometry.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Re-export stub → `plan_time_task_card/plan_card_geometry.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_card_geometry.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_card_geometry.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_metrics.dart`.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `plan_card_metrics.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Re-export stub → `plan_time_task_card/plan_card_metrics.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_card_metrics.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_card_metrics.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_sections.dart`.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `plan_card_sections.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Re-export stub → `plan_time_task_card/plan_card_sections.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_card_sections.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_card_sections.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_density.dart`.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `plan_time_card_density.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Re-export stub → `plan_time_task_card/plan_card_density.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_time_card_density.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_time_card_density.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Общий виджет design system — Public `PlanTimeTaskCard` widget.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `plan_time_task_card.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Public `PlanTimeTaskCard` widget.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_time_task_card.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_time_task_card.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_controls.dart`.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `plan_card_controls.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Re-export stub → `plan_time_task_card/plan_card_controls.dart`.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_card_controls.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: Density bands + measure helpers
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Density bands + measure helpers.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `plan_card_density.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Density bands + measure helpers.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_card_density.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_geometry.dart`.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `plan_card_geometry.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Re-export stub → `plan_time_task_card/plan_card_geometry.dart`.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_card_geometry.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Общий виджет design system — Time View CardPlan layout variants.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `plan_card_layouts.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Time View CardPlan layout variants.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_card_layouts.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: Re-export stub → `plan_time_task_card/plan_card_metrics.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_metrics.dart`.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `plan_card_metrics.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Re-export stub → `plan_time_task_card/plan_card_metrics.dart`.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_card_metrics.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Общий виджет design system — Progress/invariant card shells.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `plan_card_progress.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Progress/invariant card shells.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_card_progress.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: Re-export stub → `plan_time_task_card/plan_card_sections.dart`
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Re-export stub → `plan_time_task_card/plan_card_sections.dart`.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `plan_card_sections.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Re-export stub → `plan_time_task_card/plan_card_sections.dart`.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_card_sections.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: Time View tag row/stack/pill widgets
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Time View tag row/stack/pill widgets.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `plan_card_tags.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Time View tag row/stack/pill widgets.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_card_tags.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: Public `PlanTimeTaskCard` widget
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Public `PlanTimeTaskCard` widget.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `plan_time_task_card.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Public `PlanTimeTaskCard` widget.
- **Когда открывать:** Внешний вид карточки плана.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_time_task_card.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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
- **Connected to:** Role: Tag display mode inherited widget
- **Layer / owner:** Shared visual widget — reused on multiple tabs.

RU:

- **Что это:** Общий виджет design system — Tag display mode inherited widget.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `tag_display_mode_scope.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: Tag display mode inherited widget.
- **Когда открывать:** Когда ломается поведение, связанное с `tag_display_mode_scope.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `tag_display_mode_scope.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Общий виджет design system — `HeaderTimezoneQuickSwitcher`, profile timezone quick picker.
- **Зачем:** Один стиль кнопок/карточек на всех вкладках.
- **Содержимое:** Содержимое `timezone_quick_picker.dart` — открыть файл при правках.
- **Обязанности:** Общий UI-компонент: `HeaderTimezoneQuickSwitcher`, profile timezone quick picker.
- **Когда открывать:** Когда ломается поведение, связанное с `timezone_quick_picker.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `timezone_quick_picker.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Общий UI-виджет design system.


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

- **Что это:** Brain-модуль `auth_bridge.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `auth_bridge.dart`.
- **Обязанности:** Зона ответственности brain: Session check, OAuth routing.
- **Когда открывать:** Когда ломается поведение, связанное с `auth_bridge.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Session check, OAuth routing
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `day_snapshot_window.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `day_snapshot_window.dart`.
- **Обязанности:** Зона ответственности brain: Rolling warm day snapshots for date paging.
- **Когда открывать:** Когда ломается поведение, связанное с `day_snapshot_window.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Rolling warm day snapshots for date paging
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
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Render snapshot helpers for day strips
- **Layer / owner:** Brain performance cache — faster date paging.

RU:

- **Что это:** Brain-модуль `render_snapshot.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `render_snapshot.dart`.
- **Обязанности:** Зона ответственности brain: Render snapshot helpers for day strips.
- **Когда открывать:** Когда ломается поведение, связанное с `render_snapshot.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Render snapshot helpers for day strips
- **Слой:** Brain — кэш производительности.


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

- **Что это:** Brain-модуль `rendered_day_body_cache.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `rendered_day_body_cache.dart`.
- **Обязанности:** Зона ответственности brain: Rendered day-body LRU cache.
- **Когда открывать:** Когда ломается поведение, связанное с `rendered_day_body_cache.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Rendered day-body LRU cache
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

- **Что это:** Загружает список категорий из PocketBase и обновляет дерево категорий в памяти.
- **Зачем:** Без актуального списка не работают picker, цвета и привязка записей к категориям.
- **Содержимое:** HTTP-загрузка категорий и пересборка локальных правил.
- **Обязанности:** Скачать категории пользователя; обновить кэш после изменений.
- **Когда открывать:** Категории не появляются или не обновляются после правок.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Экран категорий, старт записи, карточки планов.
- **Слой:** Brain — `part` of `database_service.dart` (cache/load).


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

- **Что это:** Создаёт и редактирует категории на сервере.
- **Зачем:** Экран категорий должен сохранять изменения в PocketBase.
- **Содержимое:** POST/PATCH для коллекции categories.
- **Обязанности:** CRUD, архив, порядок sibling.
- **Когда открывать:** Категория не сохраняется или не архивируется.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI категорий.
- **Слой:** Brain — `part` of `database_service.dart` (network writes).


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

- **Что это:** Задаёт время по умолчанию для планов в категории (например Gym → 19:00).
- **Зачем:** Новые планы должны получать разумное время автоматически.
- **Содержимое:** Валидация времени и timezone для категории.
- **Обязанности:** Чтение/запись default_plan_time.
- **Когда открывать:** Время по умолчанию не подставляется в новый план.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Создание/редактирование планов, Time View.
- **Слой:** Brain — `part` of `database_service.dart` (category schedule defaults).


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

- **Что это:** Ищет категорию по названию, пути или голосовой фразе.
- **Зачем:** Нужен для голоса и умного ввода без дубликатов категорий.
- **Содержимое:** Fuzzy-match, scoring, сопоставление id.
- **Обязанности:** Выбрать лучшую категорию по тексту.
- **Когда открывать:** Голос или автоподбор выбрал не ту категорию.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `category_lookup.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Brain — `part` of `database_service.dart` (search/match).


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

- **Что это:** Связывает записи Timeline с правильной строкой категории в PocketBase.
- **Зачем:** Без этого записи сохраняются без категории или с неверным id.
- **Содержимое:** Разрешение REST id, починка relation полей.
- **Обязанности:** Правильный category id при PATCH записи.
- **Когда открывать:** Запись без категории или ошибка stop/delete по id.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Timeline, edit sheet, hooks на сервере.
- **Слой:** Brain — `part` of `database_service.dart` (record↔category bridge).


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

- **Что это:** Считает длительность записей по категории и поддереву.
- **Зачем:** Нужен для вкладки статистики.
- **Содержимое:** Суммирование секунд по id поддерева.
- **Обязанности:** Длительность за день/период по ветке категории.
- **Когда открывать:** Неверные часы в статистике по категории.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `category_stats.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Brain — `part` of `database_service.dart` (read-only aggregation).


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

- **Что это:** Строит дерево категорий «родитель → дочерние».
- **Зачем:** Нужен для вложенных категорий и хлебных крошек.
- **Содержимое:** Обход дерева, сортировка, поиск узла по id.
- **Обязанности:** Путь от корня; список id поддерева для статистики.
- **Когда открывать:** Неверный порядок или путь категории в UI.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Picker категорий, статистика.
- **Слой:** Brain — `part` of `database_service.dart` (tree structure).


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

- **Что это:** Brain-модуль `category_fuzzy_match.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `category_fuzzy_match.dart`.
- **Обязанности:** Зона ответственности brain: Category name scoring.
- **Когда открывать:** Когда ломается поведение, связанное с `category_fuzzy_match.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Category name scoring
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Главный координатор для categories (tree, colors, matching).
- **Зачем:** UI вызывает один вход; детали — в модулях subfolder.
- **Содержимое:** Extensions + `part` файлы для category.
- **Обязанности:** Координатор домена: Category coordinator: flatten/PB bridge statics, stats duration helpers, local task prefs helpers.
- **Когда открывать:** Когда ломается поведение, связанное с `category_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Category coordinator: flatten/PB bridge statics, stats duration helpers, local task prefs helpers
- **Слой:** Brain — координатор домена.


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

- **Что это:** Единая «мозговая» точка входа — все экраны обращаются сюда за данными.
- **Зачем:** Один singleton держит правила PocketBase для всех вкладок.
- **Содержимое:** Потоки, кэш, объявления `part` для records/plans/categories/profile.
- **Обязанности:** Маршрутизация к domain-файлам brain.
- **Когда открывать:** Когда ломается поведение, связанное с `database_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Singleton root: shared state, streams, static helpers; `part` coordinator
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
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Bootstrap: `loadInitialData`, PocketBase health, lifecycle, flush outboxes
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Brain-модуль `db_core.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `db_core.dart`.
- **Обязанности:** Зона ответственности brain: Bootstrap: `loadInitialData`, PocketBase health, lifecycle, flush outboxes.
- **Когда открывать:** Когда ломается поведение, связанное с `db_core.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Bootstrap: `loadInitialData`, PocketBase health, lifecycle, flush outboxes
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `offline_sync_state.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для offline sync и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `offline_sync_state.dart`.
- **Обязанности:** Зона ответственности: Pending count, syncing, auth-paused UI state.
- **Когда открывать:** Когда ломается поведение, связанное с `offline_sync_state.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; offline-баннер in shell, reconnect flush; Роль: Pending count, syncing, auth-paused UI state
- **Слой:** Brain — офлайн-очередь.


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

- **Что это:** Brain-модуль `plan_create_outbox.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для offline sync и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `plan_create_outbox.dart`.
- **Обязанности:** Зона ответственности: Re-export of `plan_mutation_outbox.dart`.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_create_outbox.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; offline-баннер in shell, reconnect flush; Роль: Re-export of `plan_mutation_outbox.dart`
- **Слой:** Brain — офлайн-очередь.


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

- **Что это:** Brain-модуль `plan_mutation_outbox.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для offline sync и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `plan_mutation_outbox.dart`.
- **Обязанности:** Зона ответственности: Offline queue: plan/list create/update/delete.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_mutation_outbox.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; offline-баннер in shell, reconnect flush; Роль: Offline queue: plan/list create/update/delete
- **Слой:** Brain — офлайн-очередь.


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

- **Что это:** Brain-модуль `record_mutation_outbox.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для offline sync и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `record_mutation_outbox.dart`.
- **Обязанности:** Зона ответственности: Offline queue: record start/stop/update/delete.
- **Когда открывать:** Когда ломается поведение, связанное с `record_mutation_outbox.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; offline-баннер in shell, reconnect flush; Роль: Offline queue: record start/stop/update/delete
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
- **Connected to:** UI calls via `DatabaseService.instance`; Offline banner in shell, reconnect flush; Role: Connectivity / resume → flush trigger
- **Layer / owner:** Brain offline queue / sync state.

RU:

- **Что это:** Brain-модуль `sync_manager.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для offline sync и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `sync_manager.dart`.
- **Обязанности:** Зона ответственности: Connectivity / resume → flush trigger.
- **Когда открывать:** Когда ломается поведение, связанное с `sync_manager.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; offline-баннер in shell, reconnect flush; Роль: Connectivity / resume → flush trigger
- **Слой:** Brain — офлайн-очередь.


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

- **Что это:** Собирает все model `part` в одном import.
- **Зачем:** Один import для всех типов данных.
- **Содержимое:** Только `part` директивы.
- **Обязанности:** Экспорт моделей.
- **Когда открывать:** Когда ломается поведение, связанное с `models.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: `part` declarations; export surface for all model types
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
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Shared model helpers
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Brain-модуль `_shared.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для data models и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `_shared.dart`.
- **Обязанности:** Зона ответственности: Shared model helpers.
- **Когда открывать:** Когда ломается поведение, связанное с `_shared.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Shared model helpers
- **Слой:** Модели данных — без HTTP.


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

- **Что это:** Brain-модуль `category.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для data models и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `category.dart`.
- **Обязанности:** Зона ответственности: `CategoryRule`.
- **Когда открывать:** Когда ломается поведение, связанное с `category.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: `CategoryRule`
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
- **Connected to:** UI calls via `DatabaseService.instance`; Role: `PlanningTask`
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Brain-модуль `planning.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для data models и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `planning.dart`.
- **Обязанности:** Зона ответственности: `PlanningTask`.
- **Когда открывать:** Когда ломается поведение, связанное с `planning.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: `PlanningTask`
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
- **Connected to:** UI calls via `DatabaseService.instance`; Profile, tag manager, header timezone; Role: `UserSettings`, profile fields
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Brain-модуль `profile.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для data models и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `profile.dart`.
- **Обязанности:** Зона ответственности: `UserSettings`, profile fields.
- **Когда открывать:** Когда ломается поведение, связанное с `profile.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Profile, tag manager, header timezone; Роль: `UserSettings`, profile fields
- **Слой:** Модели данных — без HTTP.


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

- **Что это:** Brain-модуль `record.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для data models и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `record.dart`.
- **Обязанности:** Зона ответственности: `TimelineRecord`.
- **Когда открывать:** Когда ломается поведение, связанное с `record.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: `TimelineRecord`
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
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Stats aggregates
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Brain-модуль `stats.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для data models и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `stats.dart`.
- **Обязанности:** Зона ответственности: Stats aggregates.
- **Когда открывать:** Когда ломается поведение, связанное с `stats.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Stats aggregates
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
- **Connected to:** UI calls via `DatabaseService.instance`; Role: `Tag`, `TagCatalogScope`
- **Layer / owner:** Data shape only — no network.

RU:

- **Что это:** Brain-модуль `tag.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для data models и PocketBase.
- **Содержимое:** Dart-код (`Tag`).
- **Обязанности:** Зона ответственности: `Tag`, `TagCatalogScope`.
- **Когда открывать:** Когда ломается поведение, связанное с `tag.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: `Tag`, `TagCatalogScope`
- **Слой:** Модели данных — без HTTP.


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

- **Что это:** Brain-модуль `pb_config.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `pb_config.dart`.
- **Обязанности:** Зона ответственности brain: PocketBase URL, collection names, expand constants.
- **Когда открывать:** Когда ломается поведение, связанное с `pb_config.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: PocketBase URL, collection names, expand constants
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Главный координатор для plans and backlog lists.
- **Зачем:** UI вызывает один вход; детали — в модулях subfolder.
- **Содержимое:** Extensions + `part` файлы для plan.
- **Обязанности:** Координатор домена: Plans/lists coordinator: CRUD, streams, wall-time projection, alarms, AI parse.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Plans/lists coordinator: CRUD, streams, wall-time projection, alarms, AI parse
- **Слой:** Brain — координатор домена.


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

- **Что это:** Brain-модуль `plan_time_sequential_cascade.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `plan_time_sequential_cascade.dart`.
- **Обязанности:** Зона ответственности brain: Plan time sequential layout math + `computeTimeViewInsertionCascade`.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_time_sequential_cascade.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Plan time sequential layout math + `computeTimeViewInsertionCascade`
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `plan_cache_helpers.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для plans and lists и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `plan_cache_helpers.dart`.
- **Обязанности:** Зона ответственности: Plan dedupe/scrub, title link scoring heuristics.
- **Когда открывать:** Планы/списки: сохранение, Time View, повтор, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; вкладка Plans, вкладка Lists, Time View; Роль: Plan dedupe/scrub, title link scoring heuristics
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `plan_outbox_helpers.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для plans and lists и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `plan_outbox_helpers.dart`.
- **Обязанности:** Зона ответственности: Plan mutation outbox enqueue/flush/replay.
- **Когда открывать:** Планы/списки: сохранение, Time View, повтор, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; вкладка Plans, вкладка Lists, Time View; Роль: Plan mutation outbox enqueue/flush/replay
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `plan_projection_types.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для plans and lists и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `plan_projection_types.dart`.
- **Обязанности:** Зона ответственности: `TimeModeProjectedPlan`, `PlanTimeModeProjection`.
- **Когда открывать:** Планы/списки: сохранение, Time View, повтор, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; вкладка Plans, вкладка Lists, Time View; Роль: `TimeModeProjectedPlan`, `PlanTimeModeProjection`
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `plan_recurrence_helpers.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для plans and lists и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `plan_recurrence_helpers.dart`.
- **Обязанности:** Зона ответственности: RRULE JIT expansion, exception-date parse helpers.
- **Когда открывать:** Планы/списки: сохранение, Time View, повтор, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; вкладка Plans, вкладка Lists, Time View; Роль: RRULE JIT expansion, exception-date parse helpers
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `plan_tags_helpers.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для plans and lists и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `plan_tags_helpers.dart`.
- **Обязанности:** Зона ответственности: Plan/list tag catalog fetch + PB `tags_link` sync.
- **Когда открывать:** Планы/списки: сохранение, Time View, повтор, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; вкладка Plans, вкладка Lists, Time View; Роль: Plan/list tag catalog fetch + PB `tags_link` sync
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `plan_time_cascade_helpers.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для plans and lists и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `plan_time_cascade_helpers.dart`.
- **Обязанности:** Зона ответственности: Time View cascade, duration consts, `planningWallEstimateSeconds`.
- **Когда открывать:** Планы/списки: сохранение, Time View, повтор, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; вкладка Plans, вкладка Lists, Time View; Роль: Time View cascade, duration consts, `planningWallEstimateSeconds`
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `price_reporter_client_match.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `price_reporter_client_match.dart`.
- **Обязанности:** Зона ответственности brain: Price Reporter client-category token guard for voice parse.
- **Когда открывать:** Когда ломается поведение, связанное с `price_reporter_client_match.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Price Reporter client-category token guard for voice parse
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `profile_admin.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для profile and tags и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `profile_admin.dart`.
- **Обязанности:** Зона ответственности: Admin bool parse helper for hydration.
- **Когда открывать:** Профиль, timezone, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Profile, tag manager, header timezone; Роль: Admin bool parse helper for hydration
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `profile_cache_helpers.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для profile and tags и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `profile_cache_helpers.dart`.
- **Обязанности:** Зона ответственности: Device prefs mirror/hydrate for profile settings.
- **Когда открывать:** Профиль, timezone, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Profile, tag manager, header timezone; Роль: Device prefs mirror/hydrate for profile settings
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `profile_hydration.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для profile and tags и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `profile_hydration.dart`.
- **Обязанности:** Зона ответственности: Profile fetch/hydration lifecycle, PB map apply, retry.
- **Когда открывать:** Профиль, timezone, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Profile, tag manager, header timezone; Роль: Profile fetch/hydration lifecycle, PB map apply, retry
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `profile_preferences.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для profile and tags и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `profile_preferences.dart`.
- **Обязанности:** Зона ответственности: Data region reload hook.
- **Когда открывать:** Профиль, timezone, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Profile, tag manager, header timezone; Роль: Data region reload hook
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `profile_settings.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для profile and tags и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `profile_settings.dart`.
- **Обязанности:** Зона ответственности: Profile PATCH/save, diff fields, locale sync.
- **Когда открывать:** Профиль, timezone, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Profile, tag manager, header timezone; Роль: Profile PATCH/save, diff fields, locale sync
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `profile_timezone.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для profile and tags и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `profile_timezone.dart`.
- **Обязанности:** Зона ответственности: Timezone normalize/offset, projected today, TZ writes.
- **Когда открывать:** Профиль, timezone, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Profile, tag manager, header timezone; Роль: Timezone normalize/offset, projected today, TZ writes
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `tag_catalog.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для profile and tags и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `tag_catalog.dart`.
- **Обязанности:** Зона ответственности: Tag catalog fetch/CRUD, sort order, PB `tags_link` id resolution.
- **Когда открывать:** Профиль, timezone, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Profile, tag manager, header timezone; Роль: Tag catalog fetch/CRUD, sort order, PB `tags_link` id resolution
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `tag_display_settings.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для profile and tags и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `tag_display_settings.dart`.
- **Обязанности:** Зона ответственности: List tag strip visibility prefs, display-mode prefs merge.
- **Когда открывать:** Профиль, timezone, теги.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Profile, tag manager, header timezone; Роль: List tag strip visibility prefs, display-mode prefs merge
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Главный координатор для profile, timezone, and tags.
- **Зачем:** UI вызывает один вход; детали — в модулях subfolder.
- **Содержимое:** Extensions + `part` файлы для profile.
- **Обязанности:** Координатор домена: Profile coordinator: shared Brain state, display label resolver.
- **Когда открывать:** Когда ломается поведение, связанное с `profile_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Profile, tag manager, header timezone; Роль: Profile coordinator: shared Brain state, display label resolver
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
- **Connected to:** UI calls via `DatabaseService.instance`; Role: Records coordinator: cache, fetch, upsert, start/stop entry, streams
- **Layer / owner:** Brain coordinator — entry point for this domain inside `database_service.dart`.

RU:

- **Что это:** Главный координатор для timeline records (timer start/stop).
- **Зачем:** UI вызывает один вход; детали — в модулях subfolder.
- **Содержимое:** Extensions + `part` файлы для record.
- **Обязанности:** Координатор домена: Records coordinator: cache, fetch, upsert, start/stop entry, streams.
- **Когда открывать:** Когда ломается поведение, связанное с `record_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Records coordinator: cache, fetch, upsert, start/stop entry, streams
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
- **Connected to:** UI calls via `DatabaseService.instance`; Timeline tab, edit sheet, Wear; Role: Per-day filter, `recordsStream`, display-time helpers
- **Layer / owner:** Brain module — `part` file merged into `database_service.dart`.

RU:

- **Что это:** Brain-модуль `record_cache_helpers.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для timeline records и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `record_cache_helpers.dart`.
- **Обязанности:** Зона ответственности: Per-day filter, `recordsStream`, display-time helpers.
- **Когда открывать:** Timeline: старт/стоп, правка, офлайн, дубликат running.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; вкладка Timeline, edit sheet, Wear; Роль: Per-day filter, `recordsStream`, display-time helpers
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `record_crud.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для timeline records и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `record_crud.dart`.
- **Обязанности:** Зона ответственности: Record CRUD, PATCH/DELETE network phases, `writeRecord` / `updateRecord` / `stopRecord`.
- **Когда открывать:** Timeline: старт/стоп, правка, офлайн, дубликат running.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; вкладка Timeline, edit sheet, Wear; Роль: Record CRUD, PATCH/DELETE network phases, `writeRecord` / `updateRecord` / `stopRecord`
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `record_ghost_cleanup.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для timeline records и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `record_ghost_cleanup.dart`.
- **Обязанности:** Зона ответственности: 404 deadletter prune against live cache.
- **Когда открывать:** Timeline: старт/стоп, правка, офлайн, дубликат running.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; вкладка Timeline, edit sheet, Wear; Роль: 404 deadletter prune against live cache
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `record_optimistic.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для timeline records и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `record_optimistic.dart`.
- **Обязанности:** Зона ответственности: Optimistic stop overlay, sacred handoff, pending-start map.
- **Когда открывать:** Timeline: старт/стоп, правка, офлайн, дубликат running.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; вкладка Timeline, edit sheet, Wear; Роль: Optimistic stop overlay, sacred handoff, pending-start map
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `record_outbox_helpers.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для timeline records и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `record_outbox_helpers.dart`.
- **Обязанности:** Зона ответственности: Record mutation outbox enqueue/flush/replay, Highlander server phase.
- **Когда открывать:** Timeline: старт/стоп, правка, офлайн, дубликат running.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; вкладка Timeline, edit sheet, Wear; Роль: Record mutation outbox enqueue/flush/replay, Highlander server phase
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `record_overlap_helpers.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для timeline records и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `record_overlap_helpers.dart`.
- **Обязанности:** Зона ответственности: Highlander local apply, singleton reconcile, overlap probes.
- **Когда открывать:** Timeline: старт/стоп, правка, офлайн, дубликат running.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; вкладка Timeline, edit sheet, Wear; Роль: Highlander local apply, singleton reconcile, overlap probes
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `record_realtime.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для timeline records и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `record_realtime.dart`.
- **Обязанности:** Зона ответственности: PocketBase records realtime subscribe/unsubscribe.
- **Когда открывать:** Timeline: старт/стоп, правка, офлайн, дубликат running.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; вкладка Timeline, edit sheet, Wear; Роль: PocketBase records realtime subscribe/unsubscribe
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `record_timeline_vm.dart` — PocketBase и локальный кэш.
- **Зачем:** Часть brain для timeline records и PocketBase.
- **Содержимое:** Dart-код: классы, extensions и helpers в `record_timeline_vm.dart`.
- **Обязанности:** Зона ответственности: Timeline day index, warm window, row VM builders.
- **Когда открывать:** Timeline: старт/стоп, правка, офлайн, дубликат running.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; вкладка Timeline, edit sheet, Wear; Роль: Timeline day index, warm window, row VM builders
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `recurrence_edit_scope.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `recurrence_edit_scope.dart`.
- **Обязанности:** Зона ответственности brain: `RecurrenceEditScope` enum for recurring plan edit/delete scope.
- **Когда открывать:** Когда ломается поведение, связанное с `recurrence_edit_scope.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: `RecurrenceEditScope` enum for recurring plan edit/delete scope
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `smart_input_parser.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `smart_input_parser.dart`.
- **Обязанности:** Зона ответственности brain: Natural-language plan/list parse (client + AI backend hook).
- **Когда открывать:** Когда ломается поведение, связанное с `smart_input_parser.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Natural-language plan/list parse (client + AI backend hook)
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `time_view_fixed_time_policy.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `time_view_fixed_time_policy.dart`.
- **Обязанности:** Зона ответственности brain: Local prefs `time_view_fixed_tag_ids_v1`; `isPlanFixedInTimeView` (schema gap: no PB sync yet).
- **Когда открывать:** Когда ломается поведение, связанное с `time_view_fixed_time_policy.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Local prefs `time_view_fixed_tag_ids_v1`; `isPlanFixedInTimeView` (schema gap: no PB sync yet)
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `voice_audio_stub.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `voice_audio_stub.dart`.
- **Обязанности:** Зона ответственности brain: Non-web voice audio stub.
- **Когда открывать:** Когда ломается поведение, связанное с `voice_audio_stub.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Non-web voice audio stub
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `voice_audio_web.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `voice_audio_web.dart`.
- **Обязанности:** Зона ответственности brain: Web voice audio implementation.
- **Когда открывать:** Когда ломается поведение, связанное с `voice_audio_web.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Web voice audio implementation
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `voice_command_parser.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `voice_command_parser.dart`.
- **Обязанности:** Зона ответственности brain: Deterministic desktop/mobile voice command parse (`parsePriceReporterVoiceCommand`, `VoiceCommandCategoryIndex`).
- **Когда открывать:** Когда ломается поведение, связанное с `voice_command_parser.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Deterministic desktop/mobile voice command parse (`parsePriceReporterVoiceCommand`, `VoiceCommandCategoryIndex`)
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `web_history.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `web_history.dart`.
- **Обязанности:** Зона ответственности brain: Web history API conditional export.
- **Когда открывать:** Когда ломается поведение, связанное с `web_history.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Web history API conditional export
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `web_history_stub.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `web_history_stub.dart`.
- **Обязанности:** Зона ответственности brain: Non-web history stub.
- **Когда открывать:** Когда ломается поведение, связанное с `web_history_stub.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Non-web history stub
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Brain-модуль `web_history_web.dart` — PocketBase и локальный кэш.
- **Зачем:** Общая логика PocketBase для нескольких вкладок.
- **Содержимое:** Dart-код: классы, extensions и helpers в `web_history_web.dart`.
- **Обязанности:** Зона ответственности brain: Web history implementation.
- **Когда открывать:** Когда ломается поведение, связанное с `web_history_web.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** UI вызывает через `DatabaseService.instance`; Роль: Web history implementation
- **Слой:** Brain module — `part` file merged into `database_service.dart`.


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

- **Что это:** Dart source `auth_screen.dart` в `lib/features/auth` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/auth` использует `auth_screen.dart` в сборке или workflow.
- **Содержимое:** Открывать `auth_screen.dart` при правках в `lib/features/auth`.
- **Обязанности:** Роль `auth_screen.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `auth_screen.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `auth_screen.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (auth).


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

- **Что это:** Dart source `auth_view.dart` в `lib/features/auth` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/auth` использует `auth_view.dart` в сборке или workflow.
- **Содержимое:** Открывать `auth_view.dart` при правках в `lib/features/auth`.
- **Обязанности:** Роль `auth_view.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `auth_view.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `auth_view.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (auth).


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

- **Что это:** Dart source `oauth_session.dart` в `lib/features/auth` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/auth` использует `oauth_session.dart` в сборке или workflow.
- **Содержимое:** Открывать `oauth_session.dart` при правках в `lib/features/auth`.
- **Обязанности:** Роль `oauth_session.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `oauth_session.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `oauth_session.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (auth).


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

- **Что это:** Dart source `calendar_view.dart` в `lib/features/calendar` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/calendar` использует `calendar_view.dart` в сборке или workflow.
- **Содержимое:** Открывать `calendar_view.dart` при правках в `lib/features/calendar`.
- **Обязанности:** Роль `calendar_view.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `calendar_view.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `calendar_view.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (calendar).


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

- **Что это:** Dart source `category_list_view.dart` в `lib/features/categories` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/categories` использует `category_list_view.dart` в сборке или workflow.
- **Содержимое:** Открывать `category_list_view.dart` при правках в `lib/features/categories`.
- **Обязанности:** Роль `category_list_view.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `category_list_view.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `category_list_view.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (categories).


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

- **Что это:** Dart source `category_recursive_tree.dart` в `lib/features/categories` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/categories` использует `category_recursive_tree.dart` в сборке или workflow.
- **Содержимое:** Открывать `category_recursive_tree.dart` при правках в `lib/features/categories`.
- **Обязанности:** Роль `category_recursive_tree.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `category_recursive_tree.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `category_recursive_tree.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (categories).


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

- **Что это:** Dart source `category_visibility_prefs.dart` в `lib/features/categories` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/categories` использует `category_visibility_prefs.dart` в сборке или workflow.
- **Содержимое:** Открывать `category_visibility_prefs.dart` при правках в `lib/features/categories`.
- **Обязанности:** Роль `category_visibility_prefs.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `category_visibility_prefs.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `category_visibility_prefs.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (categories).


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

- **Что это:** Dart source `create_category_dialog.dart` в `lib/features/categories` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/categories` использует `create_category_dialog.dart` в сборке или workflow.
- **Содержимое:** Открывать `create_category_dialog.dart` при правках в `lib/features/categories`.
- **Обязанности:** Роль `create_category_dialog.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `create_category_dialog.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `create_category_dialog.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (categories).


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

- **Что это:** Dart source `component_lab_cards_demo.dart` в `lib/features/dev` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/dev` использует `component_lab_cards_demo.dart` в сборке или workflow.
- **Содержимое:** Открывать `component_lab_cards_demo.dart` при правках в `lib/features/dev`.
- **Обязанности:** Роль `component_lab_cards_demo.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `component_lab_cards_demo.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `component_lab_cards_demo.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (dev).


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

- **Что это:** Dart source `component_lab_view.dart` в `lib/features/dev` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/dev` использует `component_lab_view.dart` в сборке или workflow.
- **Содержимое:** Открывать `component_lab_view.dart` при правках в `lib/features/dev`.
- **Обязанности:** Роль `component_lab_view.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `component_lab_view.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `component_lab_view.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (dev).


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

- **Что это:** Файл `lists_bulk_actions.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Lists tab (fourth bottom tab).
- **Содержимое:** Содержимое `lists_bulk_actions.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Select-mode header + bulk action bottom bar.
- **Когда открывать:** Вкладка Lists: фильтры, done, экспорт.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Lists (shell index 3); Роль: Select-mode header + bulk action bottom bar
- **Слой:** UI — экран/виджет (lists).


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

- **Что это:** Файл `lists_card.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Lists tab (fourth bottom tab).
- **Содержимое:** Содержимое `lists_card.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: `BacklogPlanCard`, filter chips, semicircle menu.
- **Когда открывать:** Вкладка Lists: фильтры, done, экспорт.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Lists (shell index 3); Роль: `BacklogPlanCard`, filter chips, semicircle menu
- **Слой:** UI — экран/виджет (lists).


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

- **Что это:** Файл `lists_empty_state.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Lists tab (fourth bottom tab).
- **Содержимое:** Содержимое `lists_empty_state.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Loading / filtered / no-category empty panels.
- **Когда открывать:** Вкладка Lists: фильтры, done, экспорт.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Lists (shell index 3); Роль: Loading / filtered / no-category empty panels
- **Слой:** UI — экран/виджет (lists).


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

- **Что это:** Файл `lists_export.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Lists tab (fourth bottom tab).
- **Содержимое:** Содержимое `lists_export.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Export visible list as clipboard text.
- **Когда открывать:** Вкладка Lists: фильтры, done, экспорт.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Lists (shell index 3); Роль: Export visible list as clipboard text
- **Слой:** UI — экран/виджет (lists).


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

- **Что это:** Файл `lists_filters.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Lists tab (fourth bottom tab).
- **Содержимое:** Содержимое `lists_filters.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Tag/category filter chips, chip bar, settings sheet.
- **Когда открывать:** Вкладка Lists: фильтры, done, экспорт.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Lists (shell index 3); Роль: Tag/category filter chips, chip bar, settings sheet
- **Слой:** UI — экран/виджет (lists).


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

- **Что это:** Файл `lists_inline_add.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Lists tab (fourth bottom tab).
- **Содержимое:** Содержимое `lists_inline_add.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Inline quick-add input row.
- **Когда открывать:** Вкладка Lists: фильтры, done, экспорт.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Lists (shell index 3); Роль: Inline quick-add input row
- **Слой:** UI — экран/виджет (lists).


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

- **Что это:** Dart source `lists_view.dart` в `lib/features/lists` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/lists` использует `lists_view.dart` в сборке или workflow.
- **Содержимое:** Открывать `lists_view.dart` при правках в `lib/features/lists`.
- **Обязанности:** Роль `lists_view.dart` описана в секции папки выше.
- **Когда открывать:** Вкладка Lists: фильтры, done, экспорт.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `lists_view.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (lists).


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

- **Что это:** Dart source `bulk_planning_edit_sheet.dart` в `lib/features/planning` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/planning` использует `bulk_planning_edit_sheet.dart` в сборке или workflow.
- **Содержимое:** Открывать `bulk_planning_edit_sheet.dart` при правках в `lib/features/planning`.
- **Обязанности:** Роль `bulk_planning_edit_sheet.dart` описана в секции папки выше.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `bulk_planning_edit_sheet.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Dart source `plan_time_gesture_contract.dart` в `lib/features/planning` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/planning` использует `plan_time_gesture_contract.dart` в сборке или workflow.
- **Содержимое:** Открывать `plan_time_gesture_contract.dart` при правках в `lib/features/planning`.
- **Обязанности:** Роль `plan_time_gesture_contract.dart` описана в секции папки выше.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_time_gesture_contract.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Dart source `plan_time_view_layout.dart` в `lib/features/planning` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/planning` использует `plan_time_view_layout.dart` в сборке или workflow.
- **Содержимое:** Открывать `plan_time_view_layout.dart` при правках в `lib/features/planning`.
- **Обязанности:** Роль `plan_time_view_layout.dart` описана в секции папки выше.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_time_view_layout.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Dart source `planning_day_start_prefs.dart` в `lib/features/planning` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/planning` использует `planning_day_start_prefs.dart` в сборке или workflow.
- **Содержимое:** Открывать `planning_day_start_prefs.dart` при правках в `lib/features/planning`.
- **Обязанности:** Роль `planning_day_start_prefs.dart` описана в секции папки выше.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `planning_day_start_prefs.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `planning_page.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `planning_page.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Time View state machine + day body; further split needs UX/product scope.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Time View state machine + day body; further split needs UX/product scope
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `planning_page_shell.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `planning_page_shell.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: `PlanningSwipeWrapper` date pager.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: `PlanningSwipeWrapper` date pager
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `planning_sort_mode.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `planning_sort_mode.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: `PlanSortMode` + persist index helpers.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: `PlanSortMode` + persist index helpers
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Dart source `planning_view.dart` в `lib/features/planning` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/planning` использует `planning_view.dart` в сборке или workflow.
- **Содержимое:** Открывать `planning_view.dart` при правках в `lib/features/planning`.
- **Обязанности:** Роль `planning_view.dart` описана в секции папки выше.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `planning_view.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Dart source `recurrence_scope_dialog.dart` в `lib/features/planning` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/planning` использует `recurrence_scope_dialog.dart` в сборке или workflow.
- **Содержимое:** Открывать `recurrence_scope_dialog.dart` при правках в `lib/features/planning`.
- **Обязанности:** Роль `recurrence_scope_dialog.dart` описана в секции папки выше.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `recurrence_scope_dialog.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `default_plan_category_search.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `default_plan_category_search.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Default plan category search delegate.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Default plan category search delegate
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `default_plan_timezone_search.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `default_plan_timezone_search.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Default plan TZ search delegate.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Default plan TZ search delegate
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `plan_record_link_settings.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `plan_record_link_settings.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Record→plan suggestion prefs.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Record→plan suggestion prefs
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `planning_no_tags_settings.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `planning_no_tags_settings.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Synthetic “No Tags” chip prefs.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Synthetic “No Tags” chip prefs
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `planning_timeline_bounds_sheet.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `planning_timeline_bounds_sheet.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Visible hour range slider sheet.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Visible hour range slider sheet
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Dart source `smart_plan_sheet.dart` в `lib/features/planning` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/planning` использует `smart_plan_sheet.dart` в сборке или workflow.
- **Содержимое:** Открывать `smart_plan_sheet.dart` при правках в `lib/features/planning`.
- **Обязанности:** Роль `smart_plan_sheet.dart` описана в секции папки выше.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `smart_plan_sheet.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `planning_time_view.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `planning_time_view.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Time View composition, cascade, edge scroll.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Time View composition, cascade, edge scroll
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `planning_time_view_coordinator.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `planning_time_view_coordinator.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Time View state fields.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Time View state fields
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `planning_time_view_host.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `planning_time_view_host.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: `PlanningTimeViewHost` callback surface.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: `PlanningTimeViewHost` callback surface
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `time_view_canvas.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `time_view_canvas.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Proportional day timeline canvas.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Proportional day timeline canvas
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `time_view_card_layer.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `time_view_card_layer.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Scheduled card stack layer.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Scheduled card stack layer
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `time_view_drag_controller.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `time_view_drag_controller.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Vertical drag state/helpers.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Vertical drag state/helpers
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `time_view_drag_state.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `time_view_drag_state.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: `TimelineResizeEdge`, gesture phase enums.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: `TimelineResizeEdge`, gesture phase enums
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `time_view_drop_preview.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `time_view_drop_preview.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Drop intent / cascade preview.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Drop intent / cascade preview
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `time_view_fixed_time_settings.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `time_view_fixed_time_settings.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Fixed-time tag chip settings block.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Fixed-time tag chip settings block
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `time_view_hour_grid.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `time_view_hour_grid.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Hour grid + unscheduled strip.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Hour grid + unscheduled strip
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `time_view_interaction_block.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `time_view_interaction_block.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Time View card pointer/drag/resize zones.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Time View card pointer/drag/resize zones
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `time_view_resize_controller.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `time_view_resize_controller.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Edge resize state/helpers.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Edge resize state/helpers
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `time_view_search_delegate.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `time_view_search_delegate.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Category default-time search UI.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Category default-time search UI
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `time_view_settings_sheet.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `time_view_settings_sheet.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Time View settings + default plan times.
- **Когда открывать:** Time View: перетаскивание, сетка часов, карточки.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Time View settings + default plan times
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `plan_card_reorder_settle.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `plan_card_reorder_settle.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Done-card reorder slide settle.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Done-card reorder slide settle
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `planning_bulk_bar.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `planning_bulk_bar.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Bulk selection bottom bar.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Bulk selection bottom bar
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `planning_day_card_list_keep_alive.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `planning_day_card_list_keep_alive.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: List keep-alive wrapper.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: List keep-alive wrapper
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `planning_empty_states.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `planning_empty_states.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Planning empty-state widgets.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Planning empty-state widgets
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `planning_filter_controls.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `planning_filter_controls.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Sort-mode segmented control.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Sort-mode segmented control
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `planning_list_helpers.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `planning_list_helpers.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Reorder list proxy decorator.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Reorder list proxy decorator
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `planning_menu_overlay.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `planning_menu_overlay.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Semicircle plan card radial menu.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Semicircle plan card radial menu
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Файл `planning_quick_add_strip.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Plans tab (second bottom tab).
- **Содержимое:** Содержимое `planning_quick_add_strip.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Quick-add tag strip above inline task field.
- **Когда открывать:** Вкладка Plans: день, карточки, play.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Plans (shell index 1); Роль: Quick-add tag strip above inline task field
- **Слой:** UI — экран/виджет (planning).


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

- **Что это:** Dart source `desktop_voice_attempt_dialog.dart` в `lib/features/profile` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/profile` использует `desktop_voice_attempt_dialog.dart` в сборке или workflow.
- **Содержимое:** Открывать `desktop_voice_attempt_dialog.dart` при правках в `lib/features/profile`.
- **Обязанности:** Роль `desktop_voice_attempt_dialog.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_attempt_dialog.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_attempt_dialog.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (profile).


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

- **Что это:** Dart source `desktop_voice_settings_desktop.dart` в `lib/features/profile` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/profile` использует `desktop_voice_settings_desktop.dart` в сборке или workflow.
- **Содержимое:** Открывать `desktop_voice_settings_desktop.dart` при правках в `lib/features/profile`.
- **Обязанности:** Роль `desktop_voice_settings_desktop.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_settings_desktop.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_settings_desktop.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (profile).


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

- **Что это:** Dart source `desktop_voice_settings_section.dart` в `lib/features/profile` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/profile` использует `desktop_voice_settings_section.dart` в сборке или workflow.
- **Содержимое:** Открывать `desktop_voice_settings_section.dart` при правках в `lib/features/profile`.
- **Обязанности:** Роль `desktop_voice_settings_section.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `desktop_voice_settings_section.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_settings_section.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (profile).


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

- **Что это:** Dart source `profile_view.dart` в `lib/features/profile` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/profile` использует `profile_view.dart` в сборке или workflow.
- **Содержимое:** Открывать `profile_view.dart` при правках в `lib/features/profile`.
- **Обязанности:** Роль `profile_view.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `profile_view.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `profile_view.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (profile).


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

- **Что это:** Файл `account_settings_section.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на More → Profile and settings.
- **Содержимое:** Содержимое `account_settings_section.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Signed-in identity + logout row.
- **Когда открывать:** Когда ломается поведение, связанное с `account_settings_section.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `account_settings_section.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (profile).


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

- **Что это:** Файл `notification_settings_section.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на More → Profile and settings.
- **Содержимое:** Содержимое `notification_settings_section.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: OS notification permission block.
- **Когда открывать:** Когда ломается поведение, связанное с `notification_settings_section.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `notification_settings_section.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (profile).


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

- **Что это:** Файл `security_settings_section.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на More → Profile and settings.
- **Содержимое:** Содержимое `security_settings_section.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Password reset + biometric lock.
- **Когда открывать:** Когда ломается поведение, связанное с `security_settings_section.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `security_settings_section.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (profile).


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

- **Что это:** Файл `settings_page.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на More → Profile and settings.
- **Содержимое:** Содержимое `settings_page.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Language/TZ settings page (shell route).
- **Когда открывать:** Когда ломается поведение, связанное с `settings_page.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `settings_page.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (profile).


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

- **Что это:** Dart source `tag_default_duration_settings_view.dart` в `lib/features/profile` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/profile` использует `tag_default_duration_settings_view.dart` в сборке или workflow.
- **Содержимое:** Открывать `tag_default_duration_settings_view.dart` при правках в `lib/features/profile`.
- **Обязанности:** Роль `tag_default_duration_settings_view.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `tag_default_duration_settings_view.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `tag_default_duration_settings_view.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (profile).


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

- **Что это:** Dart source `tag_manager_page.dart` в `lib/features/profile` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/profile` использует `tag_manager_page.dart` в сборке или workflow.
- **Содержимое:** Открывать `tag_manager_page.dart` при правках в `lib/features/profile`.
- **Обязанности:** Роль `tag_manager_page.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `tag_manager_page.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `tag_manager_page.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (profile).


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

- **Что это:** Dart source `tag_settings_hub.dart` в `lib/features/profile` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/profile` использует `tag_settings_hub.dart` в сборке или workflow.
- **Содержимое:** Открывать `tag_settings_hub.dart` при правках в `lib/features/profile`.
- **Обязанности:** Роль `tag_settings_hub.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `tag_settings_hub.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `tag_settings_hub.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (profile).


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

- **Что это:** Dart source `tag_settings_view.dart` в `lib/features/profile` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/profile` использует `tag_settings_view.dart` в сборке или workflow.
- **Содержимое:** Открывать `tag_settings_view.dart` при правках в `lib/features/profile`.
- **Обязанности:** Роль `tag_settings_view.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `tag_settings_view.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `tag_settings_view.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (profile).


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

- **Что это:** Dart source `timezone_settings.dart` в `lib/features/profile` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/profile` использует `timezone_settings.dart` в сборке или workflow.
- **Содержимое:** Открывать `timezone_settings.dart` при правках в `lib/features/profile`.
- **Обязанности:** Роль `timezone_settings.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `timezone_settings.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `timezone_settings.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (profile).


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

- **Что это:** Файл `activity_detail_sheet.dart` — Kotlin-точка входа Flutter на Android.
- **Зачем:** Пользователь видит это на edit sheets and voice UI on every tab.
- **Содержимое:** Содержимое `activity_detail_sheet.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Edit sheet router (`ActivityDetailKind`).
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `activity_detail_sheet.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Dart source `desktop_voice_capsule.dart` в `lib/features/shared` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/shared` использует `desktop_voice_capsule.dart` в сборке или workflow.
- **Содержимое:** Открывать `desktop_voice_capsule.dart` при правках в `lib/features/shared`.
- **Обязанности:** Роль `desktop_voice_capsule.dart` описана в секции папки выше.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_capsule.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Dart source `desktop_voice_command_panel.dart` в `lib/features/shared` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/shared` использует `desktop_voice_command_panel.dart` в сборке или workflow.
- **Содержимое:** Открывать `desktop_voice_command_panel.dart` при правках в `lib/features/shared`.
- **Обязанности:** Роль `desktop_voice_command_panel.dart` описана в секции папки выше.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_command_panel.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Dart source `desktop_voice_widget.dart` в `lib/features/shared` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/shared` использует `desktop_voice_widget.dart` в сборке или workflow.
- **Содержимое:** Открывать `desktop_voice_widget.dart` при правках в `lib/features/shared`.
- **Обязанности:** Роль `desktop_voice_widget.dart` описана в секции папки выше.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `desktop_voice_widget.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Файл `checklist_helpers.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на edit sheets and voice UI on every tab.
- **Содержимое:** Содержимое `checklist_helpers.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Checklist row sync/partition helpers.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `checklist_helpers.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Файл `parallel_record_panels.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на edit sheets and voice UI on every tab.
- **Содержимое:** Содержимое `parallel_record_panels.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Backlog sub-items + parallel child panels.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `parallel_record_panels.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Файл `plan_repeat_helpers.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на edit sheets and voice UI on every tab.
- **Содержимое:** Содержимое `plan_repeat_helpers.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: RRULE ↔ UI repeat preset helpers.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_repeat_helpers.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Файл `quill_link_launcher.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на edit sheets and voice UI on every tab.
- **Содержимое:** Содержимое `quill_link_launcher.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Quill note external URL launcher.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `quill_link_launcher.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Файл `quill_toolbar_config.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на edit sheets and voice UI on every tab.
- **Содержимое:** Содержимое `quill_toolbar_config.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Planning edit Quill toolbar config.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `quill_toolbar_config.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Файл `sheet_autosave_gate.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на edit sheets and voice UI on every tab.
- **Содержимое:** Содержимое `sheet_autosave_gate.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Debounced edit-sheet autosave gate.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `sheet_autosave_gate.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Файл `sheet_time_helpers.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на edit sheets and voice UI on every tab.
- **Содержимое:** Содержимое `sheet_time_helpers.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: UTC/display time format helpers.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `sheet_time_helpers.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Файл `sheet_time_picker.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на edit sheets and voice UI on every tab.
- **Содержимое:** Содержимое `sheet_time_picker.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: `showAppDateTimePicker`, `AppEditSheetTimeButton`.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `sheet_time_picker.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Файл `empty_state_placeholder.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на edit sheets and voice UI on every tab.
- **Содержимое:** Содержимое `empty_state_placeholder.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Shared empty-state placeholder.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `empty_state_placeholder.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Файл `offline_sync_status_bar.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на edit sheets and voice UI on every tab.
- **Содержимое:** Содержимое `offline_sync_status_bar.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: O1 offline/sync tap-to-retry banner.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `offline_sync_status_bar.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Файл `planning_task_edit_sheet.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на edit sheets and voice UI on every tab.
- **Содержимое:** Содержимое `planning_task_edit_sheet.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Plan/list task edit sheet.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `planning_task_edit_sheet.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Файл `profile_hydration_status_bar.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на edit sheets and voice UI on every tab.
- **Содержимое:** Содержимое `profile_hydration_status_bar.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Profile hydration error banner.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `profile_hydration_status_bar.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Dart source `shared_widgets.dart` в `lib/features/shared` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/shared` использует `shared_widgets.dart` в сборке или workflow.
- **Содержимое:** Открывать `shared_widgets.dart` при правках в `lib/features/shared`.
- **Обязанности:** Роль `shared_widgets.dart` описана в секции папки выше.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `shared_widgets.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Файл `timeline_record_edit_sheet.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на edit sheets and voice UI on every tab.
- **Содержимое:** Содержимое `timeline_record_edit_sheet.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Timeline record edit sheet.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `timeline_record_edit_sheet.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Dart source `voice_capture_config.dart` в `lib/features/shared` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/shared` использует `voice_capture_config.dart` в сборке или workflow.
- **Содержимое:** Открывать `voice_capture_config.dart` при правках в `lib/features/shared`.
- **Обязанности:** Роль `voice_capture_config.dart` описана в секции папки выше.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `voice_capture_config.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Dart source `voice_input_sheet.dart` в `lib/features/shared` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/shared` использует `voice_input_sheet.dart` в сборке или workflow.
- **Содержимое:** Открывать `voice_input_sheet.dart` при правках в `lib/features/shared`.
- **Обязанности:** Роль `voice_input_sheet.dart` описана в секции папки выше.
- **Когда открывать:** Шторка редактирования, picker, voice, offline banner.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `voice_input_sheet.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (shared).


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

- **Что это:** Dart source `plan_vs_fact_tab.dart` в `lib/features/stats` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/stats` использует `plan_vs_fact_tab.dart` в сборке или workflow.
- **Содержимое:** Открывать `plan_vs_fact_tab.dart` при правках в `lib/features/stats`.
- **Обязанности:** Роль `plan_vs_fact_tab.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `plan_vs_fact_tab.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `plan_vs_fact_tab.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (stats).


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

- **Что это:** Dart source `stats_view.dart` в `lib/features/stats` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/stats` использует `stats_view.dart` в сборке или workflow.
- **Содержимое:** Открывать `stats_view.dart` при правках в `lib/features/stats`.
- **Обязанности:** Роль `stats_view.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `stats_view.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `stats_view.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (stats).


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

- **Что это:** Файл `timeline_day_page.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Timeline tab (first bottom tab).
- **Содержимое:** Содержимое `timeline_day_page.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: `TimelineDayCardList`, lazy record list.
- **Когда открывать:** Вкладка Timeline: записи, день, stats.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Timeline (shell index 0); Роль: `TimelineDayCardList`, lazy record list
- **Слой:** UI — экран/виджет (timeline).


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

- **Что это:** Файл `timeline_header_controls.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Timeline tab (first bottom tab).
- **Содержимое:** Содержимое `timeline_header_controls.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: List/stats segmented control + record input row.
- **Когда открывать:** Вкладка Timeline: записи, день, stats.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Timeline (shell index 0); Роль: List/stats segmented control + record input row
- **Слой:** UI — экран/виджет (timeline).


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

- **Что это:** Файл `timeline_helpers.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Timeline tab (first bottom tab).
- **Содержимое:** Содержимое `timeline_helpers.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: Shared timeline time/duration helpers.
- **Когда открывать:** Вкладка Timeline: записи, день, stats.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Timeline (shell index 0); Роль: Shared timeline time/duration helpers
- **Слой:** UI — экран/виджет (timeline).


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

- **Что это:** Файл `timeline_record_card.dart` — platform/config файл.
- **Зачем:** Пользователь видит это на Timeline tab (first bottom tab).
- **Содержимое:** Содержимое `timeline_record_card.dart` — открыть файл при правках.
- **Обязанности:** UI-логика экрана: `TimelineRecordCard`.
- **Когда открывать:** Вкладка Timeline: записи, день, stats.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** вкладка Timeline (shell index 0); Роль: `TimelineRecordCard`
- **Слой:** UI — экран/виджет (timeline).


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

- **Что это:** Dart source `timeline_view.dart` в `lib/features/timeline` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/timeline` использует `timeline_view.dart` в сборке или workflow.
- **Содержимое:** Открывать `timeline_view.dart` при правках в `lib/features/timeline`.
- **Обязанности:** Роль `timeline_view.dart` описана в секции папки выше.
- **Когда открывать:** Вкладка Timeline: записи, день, stats.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `timeline_view.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (timeline).


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

- **Что это:** Dart source `wear_main_wrapper.dart` в `lib/features/wear` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/wear` использует `wear_main_wrapper.dart` в сборке или workflow.
- **Содержимое:** Открывать `wear_main_wrapper.dart` при правках в `lib/features/wear`.
- **Обязанности:** Роль `wear_main_wrapper.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `wear_main_wrapper.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `wear_main_wrapper.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (wear).


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

- **Что это:** Dart source `wear_platform.dart` в `lib/features/wear` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/wear` использует `wear_platform.dart` в сборке или workflow.
- **Содержимое:** Открывать `wear_platform.dart` при правках в `lib/features/wear`.
- **Обязанности:** Роль `wear_platform.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `wear_platform.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `wear_platform.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (wear).


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

- **Что это:** Dart source `wear_runtime.dart` в `lib/features/wear` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/wear` использует `wear_runtime.dart` в сборке или workflow.
- **Содержимое:** Открывать `wear_runtime.dart` при правках в `lib/features/wear`.
- **Обязанности:** Роль `wear_runtime.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `wear_runtime.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `wear_runtime.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (wear).


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

- **Что это:** Dart source `wear_timer_screen.dart` в `lib/features/wear` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/features/wear` использует `wear_timer_screen.dart` в сборке или workflow.
- **Содержимое:** Открывать `wear_timer_screen.dart` при правках в `lib/features/wear`.
- **Обязанности:** Роль `wear_timer_screen.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `wear_timer_screen.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `wear_timer_screen.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** UI — экран/виджет (wear).


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

- **Что это:** Файл `app_locales.dart` — platform/config файл.
- **Зачем:** Описан в APP_STRUCTURE.md; нужен для текущего поведения.
- **Содержимое:** Исходник `app_locales.dart`.
- **Обязанности:** Роль `app_locales.dart` в модуле `lib/l10n`.
- **Когда открывать:** Когда ломается поведение, связанное с `app_locales.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `app_locales.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Локализация — строки UI.


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

- **Что это:** Файл `category_db_display.dart` — platform/config файл.
- **Зачем:** Описан в APP_STRUCTURE.md; нужен для текущего поведения.
- **Содержимое:** Исходник `category_db_display.dart`.
- **Обязанности:** Роль `category_db_display.dart` в модуле `lib/l10n`.
- **Когда открывать:** Когда ломается поведение, связанное с `category_db_display.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `category_db_display.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Локализация — строки UI.


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

- **Что это:** Файл `dictionary.dart` — platform/config файл.
- **Зачем:** Описан в APP_STRUCTURE.md; нужен для текущего поведения.
- **Содержимое:** Исходник `dictionary.dart`.
- **Обязанности:** Роль `dictionary.dart` в модуле `lib/l10n`.
- **Когда открывать:** Когда ломается поведение, связанное с `dictionary.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `dictionary.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Локализация — строки UI.


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

- **Что это:** text file `HELP HOW TO UPDATE the languages` в `lib/l10n/langs` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/l10n/langs` использует `HELP HOW TO UPDATE the languages` в сборке или workflow.
- **Содержимое:** Открывать `HELP HOW TO UPDATE the languages` при правках в `lib/l10n/langs`.
- **Обязанности:** Роль `HELP HOW TO UPDATE the languages` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `HELP HOW TO UPDATE the languages`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `HELP HOW TO UPDATE the languages` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Локализация — строки UI.


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

- **Что это:** Dart source `ar.dart` в `lib/l10n/langs` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/l10n/langs` использует `ar.dart` в сборке или workflow.
- **Содержимое:** Открывать `ar.dart` при правках в `lib/l10n/langs`.
- **Обязанности:** Роль `ar.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `ar.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `ar.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Локализация — строки UI.


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

- **Что это:** Dart source `de.dart` в `lib/l10n/langs` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/l10n/langs` использует `de.dart` в сборке или workflow.
- **Содержимое:** Открывать `de.dart` при правках в `lib/l10n/langs`.
- **Обязанности:** Роль `de.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `de.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `de.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Локализация — строки UI.


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

- **Что это:** Английские строки UI — мастер-копия ключей.
- **Зачем:** Все подписи начинаются с ключей здесь.
- **Содержимое:** Содержимое `en.dart` — открыть файл при правках.
- **Обязанности:** Канонический EN; править перед sync_locales.
- **Когда открывать:** Когда ломается поведение, связанное с `en.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `en.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Локализация — строки UI.


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

- **Что это:** Dart source `es.dart` в `lib/l10n/langs` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/l10n/langs` использует `es.dart` в сборке или workflow.
- **Содержимое:** Открывать `es.dart` при правках в `lib/l10n/langs`.
- **Обязанности:** Роль `es.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `es.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `es.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Локализация — строки UI.


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

- **Что это:** Dart source `fr.dart` в `lib/l10n/langs` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/l10n/langs` использует `fr.dart` в сборке или workflow.
- **Содержимое:** Открывать `fr.dart` при правках в `lib/l10n/langs`.
- **Обязанности:** Роль `fr.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `fr.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `fr.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Локализация — строки UI.


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

- **Что это:** Dart source `it.dart` в `lib/l10n/langs` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/l10n/langs` использует `it.dart` в сборке или workflow.
- **Содержимое:** Открывать `it.dart` при правках в `lib/l10n/langs`.
- **Обязанности:** Роль `it.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `it.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `it.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Локализация — строки UI.


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

- **Что это:** Dart source `ko.dart` в `lib/l10n/langs` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/l10n/langs` использует `ko.dart` в сборке или workflow.
- **Содержимое:** Открывать `ko.dart` при правках в `lib/l10n/langs`.
- **Обязанности:** Роль `ko.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `ko.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `ko.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Локализация — строки UI.


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

- **Что это:** Русские строки интерфейса.
- **Зачем:** RU локаль берёт текст отсюда.
- **Содержимое:** Содержимое `ru.dart` — открыть файл при правках.
- **Обязанности:** Канонический RU.
- **Когда открывать:** Когда ломается поведение, связанное с `ru.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `ru.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Локализация — строки UI.


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

- **Что это:** Dart source `zh.dart` в `lib/l10n/langs` репозитория Life OS.
- **Зачем:** Файл в git, потому что `lib/l10n/langs` использует `zh.dart` в сборке или workflow.
- **Содержимое:** Открывать `zh.dart` при правках в `lib/l10n/langs`.
- **Обязанности:** Роль `zh.dart` описана в секции папки выше.
- **Когда открывать:** Когда ломается поведение, связанное с `zh.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `zh.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Локализация — строки UI.


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

- **Что это:** Файл `main.dart` — platform/config файл.
- **Зачем:** Описан в APP_STRUCTURE.md; нужен для текущего поведения.
- **Содержимое:** Исходник `main.dart`.
- **Обязанности:** Роль `main.dart` в модуле `lib`.
- **Когда открывать:** Когда ломается поведение, связанное с `main.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `main.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Вспомогательный файл репозитория.


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

- **Что это:** Файл `notification_service.dart` — platform/config файл.
- **Зачем:** Описан в APP_STRUCTURE.md; нужен для текущего поведения.
- **Содержимое:** Исходник `notification_service.dart`.
- **Обязанности:** Роль `notification_service.dart` в модуле `lib/services`.
- **Когда открывать:** Когда ломается поведение, связанное с `notification_service.dart`.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** Связи файла `notification_service.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Сервис устройства (уведомления).


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

- **Что это:** Оболочка приложения — Shell dashboard entry (see §3.1.1).
- **Зачем:** Связывает вкладки, voice, edit sheets, offline banner.
- **Содержимое:** Содержимое `life_os_dashboard.dart` — открыть файл при правках.
- **Обязанности:** Роль `life_os_dashboard.dart` в модуле `lib/shell`.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** все основные вкладки, `app_shell.dart`; Роль: Shell dashboard entry (see §3.1.1)
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
- **Connected to:** All main tabs, `app_shell.dart`; Role: Profile hydration failure banner
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения — Profile hydration failure banner.
- **Зачем:** Связывает вкладки, voice, edit sheets, offline banner.
- **Содержимое:** Содержимое `profile_hydration_status_bar.dart` — открыть файл при правках.
- **Обязанности:** Роль `profile_hydration_status_bar.dart` в модуле `lib/shell`.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** все основные вкладки, `app_shell.dart`; Роль: Profile hydration failure banner
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
- **Connected to:** All main tabs, `app_shell.dart`; Role: Language/TZ settings page (shell route)
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения — Language/TZ settings page (shell route).
- **Зачем:** Связывает вкладки, voice, edit sheets, offline banner.
- **Содержимое:** Содержимое `settings_page.dart` — открыть файл при правках.
- **Обязанности:** Роль `settings_page.dart` в модуле `lib/shell`.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** все основные вкладки, `app_shell.dart`; Роль: Language/TZ settings page (shell route)
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
- **Connected to:** All main tabs, `app_shell.dart`; Role: Shell core logic
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения — Shell core logic.
- **Зачем:** Связывает вкладки, voice, edit sheets, offline banner.
- **Содержимое:** Содержимое `shell_core.dart` — открыть файл при правках.
- **Обязанности:** Роль `shell_core.dart` в модуле `lib/shell`.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** все основные вкладки, `app_shell.dart`; Роль: Shell core logic
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
- **Connected to:** All main tabs, `app_shell.dart`; Role: Edit sheet hosts
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения — Edit sheet hosts.
- **Зачем:** Связывает вкладки, voice, edit sheets, offline banner.
- **Содержимое:** Содержимое `shell_edit_hosts.dart` — открыть файл при правках.
- **Обязанности:** Роль `shell_edit_hosts.dart` в модуле `lib/shell`.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** все основные вкладки, `app_shell.dart`; Роль: Edit sheet hosts
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
- **Connected to:** All main tabs, `app_shell.dart`; Role: More menu
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения — More menu.
- **Зачем:** Связывает вкладки, voice, edit sheets, offline banner.
- **Содержимое:** Содержимое `shell_more_menu.dart` — открыть файл при правках.
- **Обязанности:** UI-логика: More menu.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** все основные вкладки, `app_shell.dart`; Роль: More menu
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
- **Connected to:** All main tabs, `app_shell.dart`; Role: Offline banner slot
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения — Offline banner slot.
- **Зачем:** Связывает вкладки, voice, edit sheets, offline banner.
- **Содержимое:** Содержимое `shell_offline_banner.dart` — открыть файл при правках.
- **Обязанности:** Роль `shell_offline_banner.dart` в модуле `lib/shell`.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** все основные вкладки, `app_shell.dart`; Роль: offline-баннер slot
- **Слой:** Shell — навигация приложения.


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

- **Что это:** Оболочка приложения — Shell shared helpers.
- **Зачем:** Связывает вкладки, voice, edit sheets, offline banner.
- **Содержимое:** Содержимое `shell_shared.dart` — открыть файл при правках.
- **Обязанности:** Роль `shell_shared.dart` в модуле `lib/shell`.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** все основные вкладки, `app_shell.dart`; Роль: Shell shared helpers
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
- **Connected to:** All main tabs, `app_shell.dart`; Role: Desktop/web side navigation rail
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения — Desktop/web side navigation rail.
- **Зачем:** Связывает вкладки, voice, edit sheets, offline banner.
- **Содержимое:** Содержимое `shell_side_navigation.dart` — открыть файл при правках.
- **Обязанности:** Роль `shell_side_navigation.dart` в модуле `lib/shell`.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** все основные вкладки, `app_shell.dart`; Роль: Desktop/web side navigation rail
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
- **Connected to:** All main tabs, `app_shell.dart`; Role: Tab host builders
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения — Tab host builders.
- **Зачем:** Связывает вкладки, voice, edit sheets, offline banner.
- **Содержимое:** Содержимое `shell_tab_host.dart` — открыть файл при правках.
- **Обязанности:** Роль `shell_tab_host.dart` в модуле `lib/shell`.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** все основные вкладки, `app_shell.dart`; Роль: Tab host builders
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
- **Connected to:** All main tabs, `app_shell.dart`; Role: Voice routing
- **Layer / owner:** App shell — navigation and global wiring.

RU:

- **Что это:** Оболочка приложения — Voice routing.
- **Зачем:** Связывает вкладки, voice, edit sheets, offline banner.
- **Содержимое:** Содержимое `shell_voice_routing.dart` — открыть файл при правках.
- **Обязанности:** UI-логика: Voice routing.
- **Когда открывать:** Навигация, voice, edit host.
- **Можно удалить?** Нет — нужен для работы приложения.
- **Связано с:** все основные вкладки, `app_shell.dart`; Роль: Voice routing
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

- **Что это:** Platform-файл linux: `.gitignore` — platform/config файл.
- **Зачем:** Нужен для сборки `linux` на платформе linux.
- **Содержимое:** Native/config-содержимое `.gitignore` в `linux`.
- **Обязанности:** Поддержка embedder-сборки для `linux`.
- **Когда открывать:** Когда ломается поведение, связанное с `.gitignore`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `.gitignore` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл linux: `CMakeLists.txt` — platform/config файл.
- **Зачем:** Нужен для сборки `linux` на платформе linux.
- **Содержимое:** Native/config-содержимое `CMakeLists.txt` в `linux`.
- **Обязанности:** Поддержка embedder-сборки для `linux`.
- **Когда открывать:** Когда ломается поведение, связанное с `CMakeLists.txt`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `CMakeLists.txt` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл linux: `CMakeLists.txt` — platform/config файл.
- **Зачем:** Нужен для сборки `linux/flutter` на платформе linux.
- **Содержимое:** Native/config-содержимое `CMakeLists.txt` в `linux/flutter`.
- **Обязанности:** Поддержка embedder-сборки для `linux/flutter`.
- **Когда открывать:** Когда ломается поведение, связанное с `CMakeLists.txt`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `CMakeLists.txt` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки linux: `generated_plugin_registrant.cc` в `linux/flutter`.
- **Зачем:** Нужен для сборки linux; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `generated_plugin_registrant.cc` в `linux/flutter`.
- **Обязанности:** Поддержка embedder linux.
- **Когда открывать:** Ошибка сборки с `generated_plugin_registrant.cc`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `linux/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки linux: `generated_plugin_registrant.h` в `linux/flutter`.
- **Зачем:** Нужен для сборки linux; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `generated_plugin_registrant.h` в `linux/flutter`.
- **Обязанности:** Поддержка embedder linux.
- **Когда открывать:** Ошибка сборки с `generated_plugin_registrant.h`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `linux/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки linux: `generated_plugins.cmake` в `linux/flutter`.
- **Зачем:** Нужен для сборки linux; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `generated_plugins.cmake` в `linux/flutter`.
- **Обязанности:** Поддержка embedder linux.
- **Когда открывать:** Ошибка сборки с `generated_plugins.cmake`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `linux/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл linux: `CMakeLists.txt` — platform/config файл.
- **Зачем:** Нужен для сборки `linux/runner` на платформе linux.
- **Содержимое:** Native/config-содержимое `CMakeLists.txt` в `linux/runner`.
- **Обязанности:** Поддержка embedder-сборки для `linux/runner`.
- **Когда открывать:** Когда ломается поведение, связанное с `CMakeLists.txt`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `CMakeLists.txt` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки linux: `main.cc` в `linux/runner`.
- **Зачем:** Нужен для сборки linux; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `main.cc` в `linux/runner`.
- **Обязанности:** Поддержка embedder linux.
- **Когда открывать:** Ошибка сборки с `main.cc`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `linux/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки linux: `my_application.cc` в `linux/runner`.
- **Зачем:** Нужен для сборки linux; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `my_application.cc` в `linux/runner`.
- **Обязанности:** Поддержка embedder linux.
- **Когда открывать:** Ошибка сборки с `my_application.cc`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `linux/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки linux: `my_application.h` в `linux/runner`.
- **Зачем:** Нужен для сборки linux; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `my_application.h` в `linux/runner`.
- **Обязанности:** Поддержка embedder linux.
- **Когда открывать:** Ошибка сборки с `my_application.h`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `linux/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл macos: `.gitignore` — platform/config файл.
- **Зачем:** Нужен для сборки `macos` на платформе macos.
- **Содержимое:** Native/config-содержимое `.gitignore` в `macos`.
- **Обязанности:** Поддержка embedder-сборки для `macos`.
- **Когда открывать:** Когда ломается поведение, связанное с `.gitignore`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `.gitignore` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `Flutter-Debug.xcconfig` в `macos/Flutter`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Flutter-Debug.xcconfig` в `macos/Flutter`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `Flutter-Debug.xcconfig`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `Flutter-Release.xcconfig` в `macos/Flutter`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Flutter-Release.xcconfig` в `macos/Flutter`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `Flutter-Release.xcconfig`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `GeneratedPluginRegistrant.swift` в `macos/Flutter`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `GeneratedPluginRegistrant.swift` в `macos/Flutter`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `GeneratedPluginRegistrant.swift`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `project.pbxproj` в `macos/Runner.xcodeproj`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `project.pbxproj` в `macos/Runner.xcodeproj`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `project.pbxproj`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `IDEWorkspaceChecks.plist` в `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `IDEWorkspaceChecks.plist` в `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `IDEWorkspaceChecks.plist`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `Runner.xcscheme` в `macos/Runner.xcodeproj/xcshareddata/xcschemes`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Runner.xcscheme` в `macos/Runner.xcodeproj/xcshareddata/xcschemes`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `Runner.xcscheme`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `contents.xcworkspacedata` в `macos/Runner.xcworkspace`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `contents.xcworkspacedata` в `macos/Runner.xcworkspace`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `contents.xcworkspacedata`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `IDEWorkspaceChecks.plist` в `macos/Runner.xcworkspace/xcshareddata`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `IDEWorkspaceChecks.plist` в `macos/Runner.xcworkspace/xcshareddata`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `IDEWorkspaceChecks.plist`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `AppDelegate.swift` в `macos/Runner`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `AppDelegate.swift` в `macos/Runner`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `AppDelegate.swift`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `Contents.json` в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Contents.json` в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `Contents.json`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `app_icon_1024.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `app_icon_1024.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `app_icon_1024.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `app_icon_128.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `app_icon_128.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `app_icon_128.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `app_icon_16.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `app_icon_16.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `app_icon_16.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `app_icon_256.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `app_icon_256.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `app_icon_256.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `app_icon_32.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `app_icon_32.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `app_icon_32.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `app_icon_512.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `app_icon_512.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `app_icon_512.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `app_icon_64.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `app_icon_64.png` в `macos/Runner/Assets.xcassets/AppIcon.appiconset`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `app_icon_64.png`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `MainMenu.xib` в `macos/Runner/Base.lproj`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `MainMenu.xib` в `macos/Runner/Base.lproj`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `MainMenu.xib`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `AppInfo.xcconfig` в `macos/Runner/Configs`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `AppInfo.xcconfig` в `macos/Runner/Configs`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `AppInfo.xcconfig`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `Debug.xcconfig` в `macos/Runner/Configs`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Debug.xcconfig` в `macos/Runner/Configs`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `Debug.xcconfig`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `Release.xcconfig` в `macos/Runner/Configs`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Release.xcconfig` в `macos/Runner/Configs`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `Release.xcconfig`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `Warnings.xcconfig` в `macos/Runner/Configs`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Warnings.xcconfig` в `macos/Runner/Configs`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `Warnings.xcconfig`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `DebugProfile.entitlements` в `macos/Runner`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `DebugProfile.entitlements` в `macos/Runner`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `DebugProfile.entitlements`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл macos: `Info.plist` — platform/config файл.
- **Зачем:** Нужен для сборки `macos/Runner` на платформе macos.
- **Содержимое:** Native/config-содержимое `Info.plist` в `macos/Runner`.
- **Обязанности:** Поддержка embedder-сборки для `macos/Runner`.
- **Когда открывать:** Когда ломается поведение, связанное с `Info.plist`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `Info.plist` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `MainFlutterWindow.swift` в `macos/Runner`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `MainFlutterWindow.swift` в `macos/Runner`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `MainFlutterWindow.swift`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `Release.entitlements` в `macos/Runner`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Release.entitlements` в `macos/Runner`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `Release.entitlements`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки macos: `RunnerTests.swift` в `macos/RunnerTests`.
- **Зачем:** Нужен для сборки macos; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `RunnerTests.swift` в `macos/RunnerTests`.
- **Обязанности:** Поддержка embedder macos.
- **Когда открывать:** Ошибка сборки с `RunnerTests.swift`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `macos/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл `auth.request_password_reset.pb.js` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `auth.request_password_reset.pb.js`.
- **Содержимое:** Содержимое `auth.request_password_reset.pb.js` — открыть файл при правках.
- **Обязанности:** Роль `auth.request_password_reset.pb.js` в модуле `pb_hooks`.
- **Когда открывать:** Когда build или maintenance ссылается на `auth.request_password_reset.pb.js`.
- **Можно удалить?** Нет — production PocketBase deployment.
- **Связано с:** Связи файла `auth.request_password_reset.pb.js` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Server hook — not in app binary.


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

- **Что это:** Файл `records.interval_sanitize.pb.js` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `records.interval_sanitize.pb.js`.
- **Содержимое:** Содержимое `records.interval_sanitize.pb.js` — открыть файл при правках.
- **Обязанности:** Роль `records.interval_sanitize.pb.js` в модуле `pb_hooks`.
- **Когда открывать:** Когда build или maintenance ссылается на `records.interval_sanitize.pb.js`.
- **Можно удалить?** Нет — production PocketBase deployment.
- **Связано с:** Связи файла `records.interval_sanitize.pb.js` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Server hook — not in app binary.


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
- **Можно удалить?** Нет — нужен для воспроизводимых сборок.
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
- **Можно удалить?** Нет — без него сборка невозможна.
- **Связано с:** Связи файла `pubspec.yaml` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
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

- **Что это:** Файл `architecture_guard.ps1` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `architecture_guard.ps1`.
- **Содержимое:** Содержимое `architecture_guard.ps1` — открыть файл при правках.
- **Обязанности:** Роль `architecture_guard.ps1` в модуле `scripts/audit`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Нет — required for audit workflow.
- **Связано с:** Связи файла `architecture_guard.ps1` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Audit script.


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

- **Что это:** Файл `check_no_preparing_ui.ps1` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `check_no_preparing_ui.ps1`.
- **Содержимое:** Содержимое `check_no_preparing_ui.ps1` — открыть файл при правках.
- **Обязанности:** Роль `check_no_preparing_ui.ps1` в модуле `scripts/manual`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Нет — part of documented dev workflow unless cleanup report removed it.
- **Связано с:** Связи файла `check_no_preparing_ui.ps1` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Developer script.


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

- **Что это:** Файл `export_price_reporter_timesheet.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `export_price_reporter_timesheet.dart`.
- **Содержимое:** Содержимое `export_price_reporter_timesheet.dart` — открыть файл при правках.
- **Обязанности:** Роль `export_price_reporter_timesheet.dart` в модуле `scripts/manual`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Возможно — manual owner utility; keep unless export no longer used.
- **Связано с:** Связи файла `export_price_reporter_timesheet.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Manual owner script — not shipped in app.


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

- **Что это:** Файл `generate_app_structure_detailed.py` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `generate_app_structure_detailed.py`.
- **Содержимое:** Содержимое `generate_app_structure_detailed.py` — открыть файл при правках.
- **Обязанности:** Роль `generate_app_structure_detailed.py` в модуле `scripts/manual`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Нет — required for structure doc generation.
- **Связано с:** Связи файла `generate_app_structure_detailed.py` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Doc generation script.


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

- **Что это:** Файл `run_desktop_voice_acceptance.ps1` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `run_desktop_voice_acceptance.ps1`.
- **Содержимое:** Содержимое `run_desktop_voice_acceptance.ps1` — открыть файл при правках.
- **Обязанности:** Роль `run_desktop_voice_acceptance.ps1` в модуле `scripts/manual`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Нет — part of documented dev workflow unless cleanup report removed it.
- **Связано с:** Связи файла `run_desktop_voice_acceptance.ps1` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Developer script.


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

- **Что это:** Файл `smoke_desktop_hotkey.ps1` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `smoke_desktop_hotkey.ps1`.
- **Содержимое:** Содержимое `smoke_desktop_hotkey.ps1` — открыть файл при правках.
- **Обязанности:** Роль `smoke_desktop_hotkey.ps1` в модуле `scripts/manual`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Нет — part of documented dev workflow unless cleanup report removed it.
- **Связано с:** Связи файла `smoke_desktop_hotkey.ps1` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Developer script.


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

- **Что это:** Файл `smoke_desktop_voice_helper_failure.ps1` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `smoke_desktop_voice_helper_failure.ps1`.
- **Содержимое:** Содержимое `smoke_desktop_voice_helper_failure.ps1` — открыть файл при правках.
- **Обязанности:** Роль `smoke_desktop_voice_helper_failure.ps1` в модуле `scripts/manual`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Нет — part of documented dev workflow unless cleanup report removed it.
- **Связано с:** Связи файла `smoke_desktop_voice_helper_failure.ps1` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Developer script.


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

- **Что это:** Файл `smoke_desktop_voice_helper_selftest.ps1` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `smoke_desktop_voice_helper_selftest.ps1`.
- **Содержимое:** Содержимое `smoke_desktop_voice_helper_selftest.ps1` — открыть файл при правках.
- **Обязанности:** Роль `smoke_desktop_voice_helper_selftest.ps1` в модуле `scripts/manual`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Нет — part of documented dev workflow unless cleanup report removed it.
- **Связано с:** Связи файла `smoke_desktop_voice_helper_selftest.ps1` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Developer script.


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

- **Что это:** Файл `smoke_desktop_voice_recording_first.ps1` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `smoke_desktop_voice_recording_first.ps1`.
- **Содержимое:** Содержимое `smoke_desktop_voice_recording_first.ps1` — открыть файл при правках.
- **Обязанности:** Роль `smoke_desktop_voice_recording_first.ps1` в модуле `scripts/manual`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Нет — part of documented dev workflow unless cleanup report removed it.
- **Связано с:** Связи файла `smoke_desktop_voice_recording_first.ps1` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Developer script.


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

- **Что это:** Файл `structure_guide_data.py` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `structure_guide_data.py`.
- **Содержимое:** Содержимое `structure_guide_data.py` — открыть файл при правках.
- **Обязанности:** Роль `structure_guide_data.py` в модуле `scripts/manual`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Нет — part of documented dev workflow unless cleanup report removed it.
- **Связано с:** Связи файла `structure_guide_data.py` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Developer script.


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

- **Что это:** Файл `structure_role_guides.py` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `structure_role_guides.py`.
- **Содержимое:** Содержимое `structure_role_guides.py` — открыть файл при правках.
- **Обязанности:** Роль `structure_role_guides.py` в модуле `scripts/manual`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Нет — part of documented dev workflow unless cleanup report removed it.
- **Связано с:** Связи файла `structure_role_guides.py` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Developer script.


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

- **Что это:** Файл `structure_root_guides.py` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `structure_root_guides.py`.
- **Содержимое:** Содержимое `structure_root_guides.py` — открыть файл при правках.
- **Обязанности:** Роль `structure_root_guides.py` в модуле `scripts/manual`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Нет — part of documented dev workflow unless cleanup report removed it.
- **Связано с:** Связи файла `structure_root_guides.py` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Developer script.


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

- **Что это:** Файл `structure_ru_helpers.py` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `structure_ru_helpers.py`.
- **Содержимое:** Содержимое `structure_ru_helpers.py` — открыть файл при правках.
- **Обязанности:** Роль `structure_ru_helpers.py` в модуле `scripts/manual`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Нет — part of documented dev workflow unless cleanup report removed it.
- **Связано с:** Связи файла `structure_ru_helpers.py` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Developer script.


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

- **Что это:** Файл `structure_scan.ps1` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `structure_scan.ps1`.
- **Содержимое:** Содержимое `structure_scan.ps1` — открыть файл при правках.
- **Обязанности:** Роль `structure_scan.ps1` в модуле `scripts/manual`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Нет — part of documented dev workflow unless cleanup report removed it.
- **Связано с:** Связи файла `structure_scan.ps1` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Developer script.


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

- **Что это:** Файл `td` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `td`.
- **Содержимое:** Содержимое `td` — открыть файл при правках.
- **Обязанности:** Роль `td` в модуле `scripts/manual`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Нет — part of documented dev workflow unless cleanup report removed it.
- **Связано с:** Связи файла `td` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Developer script.


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

- **Что это:** Файл `td.ps1` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `td.ps1`.
- **Содержимое:** Содержимое `td.ps1` — открыть файл при правках.
- **Обязанности:** Роль `td.ps1` в модуле `scripts/manual`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Нет — part of documented dev workflow unless cleanup report removed it.
- **Связано с:** Связи файла `td.ps1` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Developer script.


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

- **Что это:** Файл `sync_locales.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `sync_locales.dart`.
- **Содержимое:** Содержимое `sync_locales.dart` — открыть файл при правках.
- **Обязанности:** Роль `sync_locales.dart` в модуле `scripts`.
- **Когда открывать:** Запуск workflow из `docs/DEPLOY.md` или audit перед merge.
- **Можно удалить?** Нет — locale SSOT workflow.
- **Связано с:** Связи файла `sync_locales.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Locale maintenance script.


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

- **Что это:** Файл `app_hotkey_keycaps_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `app_hotkey_keycaps_test.dart`.
- **Содержимое:** Содержимое `app_hotkey_keycaps_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `app_hotkey_keycaps_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `app_hotkey_keycaps_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `app_hotkey_keycaps_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `app_timezone_icon_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `app_timezone_icon_test.dart`.
- **Содержимое:** Содержимое `app_timezone_icon_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `app_timezone_icon_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `app_timezone_icon_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `app_timezone_icon_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `desktop_voice_attempt_dialog_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `desktop_voice_attempt_dialog_test.dart`.
- **Содержимое:** Содержимое `desktop_voice_attempt_dialog_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `desktop_voice_attempt_dialog_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_attempt_dialog_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `desktop_voice_attempt_dialog_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `desktop_voice_attempt_log_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `desktop_voice_attempt_log_test.dart`.
- **Содержимое:** Содержимое `desktop_voice_attempt_log_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `desktop_voice_attempt_log_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_attempt_log_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `desktop_voice_attempt_log_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `desktop_voice_command_acceptance_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `desktop_voice_command_acceptance_test.dart`.
- **Содержимое:** Содержимое `desktop_voice_command_acceptance_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `desktop_voice_command_acceptance_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_command_acceptance_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `desktop_voice_command_acceptance_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `desktop_voice_helper_failure_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `desktop_voice_helper_failure_test.dart`.
- **Содержимое:** Содержимое `desktop_voice_helper_failure_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `desktop_voice_helper_failure_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_helper_failure_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `desktop_voice_helper_failure_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `desktop_voice_hotkey_self_acceptance_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `desktop_voice_hotkey_self_acceptance_test.dart`.
- **Содержимое:** Содержимое `desktop_voice_hotkey_self_acceptance_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `desktop_voice_hotkey_self_acceptance_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_hotkey_self_acceptance_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `desktop_voice_hotkey_self_acceptance_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `desktop_voice_hotkey_state_machine_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `desktop_voice_hotkey_state_machine_test.dart`.
- **Содержимое:** Содержимое `desktop_voice_hotkey_state_machine_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `desktop_voice_hotkey_state_machine_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_hotkey_state_machine_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `desktop_voice_hotkey_state_machine_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `desktop_voice_laredo_multi_scope_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `desktop_voice_laredo_multi_scope_test.dart`.
- **Содержимое:** Содержимое `desktop_voice_laredo_multi_scope_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `desktop_voice_laredo_multi_scope_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_laredo_multi_scope_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `desktop_voice_laredo_multi_scope_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `desktop_voice_mic_peak_visibility_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `desktop_voice_mic_peak_visibility_test.dart`.
- **Содержимое:** Содержимое `desktop_voice_mic_peak_visibility_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `desktop_voice_mic_peak_visibility_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_mic_peak_visibility_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `desktop_voice_mic_peak_visibility_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `desktop_voice_no_preparing_ui_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `desktop_voice_no_preparing_ui_test.dart`.
- **Содержимое:** Содержимое `desktop_voice_no_preparing_ui_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `desktop_voice_no_preparing_ui_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_no_preparing_ui_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `desktop_voice_no_preparing_ui_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `desktop_voice_overlay_state_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `desktop_voice_overlay_state_test.dart`.
- **Содержимое:** Содержимое `desktop_voice_overlay_state_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `desktop_voice_overlay_state_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_overlay_state_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `desktop_voice_overlay_state_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `desktop_voice_production_submit_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `desktop_voice_production_submit_test.dart`.
- **Содержимое:** Содержимое `desktop_voice_production_submit_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `desktop_voice_production_submit_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_production_submit_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `desktop_voice_production_submit_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `desktop_voice_settings_mic_layout_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `desktop_voice_settings_mic_layout_test.dart`.
- **Содержимое:** Содержимое `desktop_voice_settings_mic_layout_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `desktop_voice_settings_mic_layout_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_settings_mic_layout_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `desktop_voice_settings_mic_layout_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `desktop_voice_user_error_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `desktop_voice_user_error_test.dart`.
- **Содержимое:** Содержимое `desktop_voice_user_error_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `desktop_voice_user_error_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_user_error_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `desktop_voice_user_error_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `desktop_voice_widget_e2e_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `desktop_voice_widget_e2e_test.dart`.
- **Содержимое:** Содержимое `desktop_voice_widget_e2e_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `desktop_voice_widget_e2e_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `desktop_voice_widget_e2e_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `desktop_voice_widget_e2e_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `edit_sheet_autosave_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `edit_sheet_autosave_test.dart`.
- **Содержимое:** Содержимое `edit_sheet_autosave_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `edit_sheet_autosave_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `edit_sheet_autosave_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `edit_sheet_autosave_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `outbox_coalesce_regression_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `outbox_coalesce_regression_test.dart`.
- **Содержимое:** Содержимое `outbox_coalesce_regression_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `outbox_coalesce_regression_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `outbox_coalesce_regression_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `outbox_coalesce_regression_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `perf_date_swipe_diag_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `perf_date_swipe_diag_test.dart`.
- **Содержимое:** Содержимое `perf_date_swipe_diag_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `perf_date_swipe_diag_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `perf_date_swipe_diag_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `perf_date_swipe_diag_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `perf_shell_date_settle_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `perf_shell_date_settle_test.dart`.
- **Содержимое:** Содержимое `perf_shell_date_settle_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `perf_shell_date_settle_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `perf_shell_date_settle_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `perf_shell_date_settle_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `plan_recurrence_scope_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `plan_recurrence_scope_test.dart`.
- **Содержимое:** Содержимое `plan_recurrence_scope_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `plan_recurrence_scope_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_recurrence_scope_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `plan_recurrence_scope_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `plan_time_bulk_drag_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `plan_time_bulk_drag_test.dart`.
- **Содержимое:** Содержимое `plan_time_bulk_drag_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `plan_time_bulk_drag_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_bulk_drag_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `plan_time_bulk_drag_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `plan_time_drag_gesture_contract_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `plan_time_drag_gesture_contract_test.dart`.
- **Содержимое:** Содержимое `plan_time_drag_gesture_contract_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `plan_time_drag_gesture_contract_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_drag_gesture_contract_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `plan_time_drag_gesture_contract_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `plan_time_duration_fidelity_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `plan_time_duration_fidelity_test.dart`.
- **Содержимое:** Содержимое `plan_time_duration_fidelity_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `plan_time_duration_fidelity_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_duration_fidelity_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `plan_time_duration_fidelity_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `plan_time_fixed_time_policy_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `plan_time_fixed_time_policy_test.dart`.
- **Содержимое:** Содержимое `plan_time_fixed_time_policy_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `plan_time_fixed_time_policy_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_fixed_time_policy_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `plan_time_fixed_time_policy_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `plan_time_sequential_cascade_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `plan_time_sequential_cascade_test.dart`.
- **Содержимое:** Содержимое `plan_time_sequential_cascade_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `plan_time_sequential_cascade_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_sequential_cascade_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `plan_time_sequential_cascade_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `plan_time_target_drop_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `plan_time_target_drop_test.dart`.
- **Содержимое:** Содержимое `plan_time_target_drop_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `plan_time_target_drop_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_target_drop_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `plan_time_target_drop_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `plan_time_timezone_projection_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `plan_time_timezone_projection_test.dart`.
- **Содержимое:** Содержимое `plan_time_timezone_projection_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `plan_time_timezone_projection_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_timezone_projection_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `plan_time_timezone_projection_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `plan_time_view_layout_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `plan_time_view_layout_test.dart`.
- **Содержимое:** Содержимое `plan_time_view_layout_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `plan_time_view_layout_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_view_layout_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `plan_time_view_layout_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `plan_time_visible_window_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `plan_time_visible_window_test.dart`.
- **Содержимое:** Содержимое `plan_time_visible_window_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `plan_time_visible_window_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `plan_time_visible_window_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `plan_time_visible_window_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `planning_duplicate_plan_guard_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `planning_duplicate_plan_guard_test.dart`.
- **Содержимое:** Содержимое `planning_duplicate_plan_guard_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `planning_duplicate_plan_guard_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `planning_duplicate_plan_guard_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `planning_duplicate_plan_guard_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `planning_realtime_stream_lifecycle_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `planning_realtime_stream_lifecycle_test.dart`.
- **Содержимое:** Содержимое `planning_realtime_stream_lifecycle_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `planning_realtime_stream_lifecycle_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `planning_realtime_stream_lifecycle_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `planning_realtime_stream_lifecycle_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `profile_timezone_catalog_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `profile_timezone_catalog_test.dart`.
- **Содержимое:** Содержимое `profile_timezone_catalog_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `profile_timezone_catalog_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `profile_timezone_catalog_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `profile_timezone_catalog_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `smart_input_parser_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `smart_input_parser_test.dart`.
- **Содержимое:** Содержимое `smart_input_parser_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `smart_input_parser_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `smart_input_parser_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `smart_input_parser_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `timezone_quick_picker_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `timezone_quick_picker_test.dart`.
- **Содержимое:** Содержимое `timezone_quick_picker_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `timezone_quick_picker_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `timezone_quick_picker_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `timezone_quick_picker_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `voice_command_parser_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `voice_command_parser_test.dart`.
- **Содержимое:** Содержимое `voice_command_parser_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `voice_command_parser_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `voice_command_parser_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `voice_command_parser_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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

- **Что это:** Файл `widget_test.dart` — platform/config файл.
- **Зачем:** Нужен для workflow или сборки, связанной с `widget_test.dart`.
- **Содержимое:** Содержимое `widget_test.dart` — открыть файл при правках.
- **Обязанности:** Роль `widget_test.dart` в модуле `test`.
- **Когда открывать:** Падение CI или правка кода рядом с `widget_test.dart`.
- **Можно удалить?** Нет — нужен для тестов.
- **Связано с:** Связи файла `widget_test.dart` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Автотест — не в APK пользователю.


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
- **Можно удалить?** Нет — задокументированный deploy workflow.
- **Связано с:** Связи файла `update.ps1` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Deploy-скрипт — не runtime приложения.


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

- **Что это:** Platform-файл web: `favicon.png` — platform/config файл.
- **Зачем:** Нужен для сборки `web` на платформе web.
- **Содержимое:** Native/config-содержимое `favicon.png` в `web`.
- **Обязанности:** Поддержка embedder-сборки для `web`.
- **Когда открывать:** Пустая web-страница после deploy или неверный base href.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `favicon.png` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл web: `Icon-192.png` — platform/config файл.
- **Зачем:** Нужен для сборки `web/icons` на платформе web.
- **Содержимое:** Native/config-содержимое `Icon-192.png` в `web/icons`.
- **Обязанности:** Поддержка embedder-сборки для `web/icons`.
- **Когда открывать:** Пустая web-страница после deploy или неверный base href.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `Icon-192.png` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл web: `Icon-512.png` — platform/config файл.
- **Зачем:** Нужен для сборки `web/icons` на платформе web.
- **Содержимое:** Native/config-содержимое `Icon-512.png` в `web/icons`.
- **Обязанности:** Поддержка embedder-сборки для `web/icons`.
- **Когда открывать:** Пустая web-страница после deploy или неверный base href.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `Icon-512.png` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл web: `Icon-maskable-192.png` — platform/config файл.
- **Зачем:** Нужен для сборки `web/icons` на платформе web.
- **Содержимое:** Native/config-содержимое `Icon-maskable-192.png` в `web/icons`.
- **Обязанности:** Поддержка embedder-сборки для `web/icons`.
- **Когда открывать:** Пустая web-страница после deploy или неверный base href.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `Icon-maskable-192.png` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл web: `Icon-maskable-512.png` — platform/config файл.
- **Зачем:** Нужен для сборки `web/icons` на платформе web.
- **Содержимое:** Native/config-содержимое `Icon-maskable-512.png` в `web/icons`.
- **Обязанности:** Поддержка embedder-сборки для `web/icons`.
- **Когда открывать:** Пустая web-страница после deploy или неверный base href.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `Icon-maskable-512.png` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл web: `index.html` — platform/config файл.
- **Зачем:** Нужен для сборки `web` на платформе web.
- **Содержимое:** Native/config-содержимое `index.html` в `web`.
- **Обязанности:** Поддержка embedder-сборки для `web`.
- **Когда открывать:** Пустая web-страница после deploy или неверный base href.
- **Можно удалить?** Нет — нужен для web-сборки.
- **Связано с:** Связи файла `index.html` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Web platform entry.


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

- **Что это:** Web app manifest — имя, theme color и иконки PWA.
- **Зачем:** Браузер использует manifest для install prompt и темы вкладки.
- **Содержимое:** JSON с icons и display mode.
- **Обязанности:** PWA-метаданные для GitHub Pages.
- **Когда открывать:** Пустая web-страница после deploy или неверный base href.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `manifest.json` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл windows: `.gitignore` — platform/config файл.
- **Зачем:** Нужен для сборки `windows` на платформе windows.
- **Содержимое:** Native/config-содержимое `.gitignore` в `windows`.
- **Обязанности:** Поддержка embedder-сборки для `windows`.
- **Когда открывать:** Когда ломается поведение, связанное с `.gitignore`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `.gitignore` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл windows: `CMakeLists.txt` — platform/config файл.
- **Зачем:** Нужен для сборки `windows` на платформе windows.
- **Содержимое:** Native/config-содержимое `CMakeLists.txt` в `windows`.
- **Обязанности:** Поддержка embedder-сборки для `windows`.
- **Когда открывать:** Когда ломается поведение, связанное с `CMakeLists.txt`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `CMakeLists.txt` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл windows: `CMakeLists.txt` — platform/config файл.
- **Зачем:** Нужен для сборки `windows/flutter` на платформе windows.
- **Содержимое:** Native/config-содержимое `CMakeLists.txt` в `windows/flutter`.
- **Обязанности:** Поддержка embedder-сборки для `windows/flutter`.
- **Когда открывать:** Когда ломается поведение, связанное с `CMakeLists.txt`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `CMakeLists.txt` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки windows: `generated_plugin_registrant.cc` в `windows/flutter`.
- **Зачем:** Нужен для сборки windows; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `generated_plugin_registrant.cc` в `windows/flutter`.
- **Обязанности:** Поддержка embedder windows.
- **Когда открывать:** Ошибка сборки с `generated_plugin_registrant.cc`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `windows/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки windows: `generated_plugin_registrant.h` в `windows/flutter`.
- **Зачем:** Нужен для сборки windows; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `generated_plugin_registrant.h` в `windows/flutter`.
- **Обязанности:** Поддержка embedder windows.
- **Когда открывать:** Ошибка сборки с `generated_plugin_registrant.h`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `windows/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки windows: `generated_plugins.cmake` в `windows/flutter`.
- **Зачем:** Нужен для сборки windows; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `generated_plugins.cmake` в `windows/flutter`.
- **Обязанности:** Поддержка embedder windows.
- **Когда открывать:** Ошибка сборки с `generated_plugins.cmake`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `windows/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Platform-файл windows: `CMakeLists.txt` — platform/config файл.
- **Зачем:** Нужен для сборки `windows/runner` на платформе windows.
- **Содержимое:** Native/config-содержимое `CMakeLists.txt` в `windows/runner`.
- **Обязанности:** Поддержка embedder-сборки для `windows/runner`.
- **Когда открывать:** Когда ломается поведение, связанное с `CMakeLists.txt`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Связи файла `CMakeLists.txt` с другими модулями — см. EN-блок и `docs/APP_STRUCTURE.md`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки windows: `Runner.rc` в `windows/runner`.
- **Зачем:** Нужен для сборки windows; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `Runner.rc` в `windows/runner`.
- **Обязанности:** Поддержка embedder windows.
- **Когда открывать:** Ошибка сборки с `Runner.rc`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `windows/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки windows: `desktop_voice_native_overlay.cpp` в `windows/runner`.
- **Зачем:** Нужен для сборки windows; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `desktop_voice_native_overlay.cpp` в `windows/runner`.
- **Обязанности:** Поддержка embedder windows.
- **Когда открывать:** Ошибка сборки с `desktop_voice_native_overlay.cpp`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `windows/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки windows: `desktop_voice_native_overlay.h` в `windows/runner`.
- **Зачем:** Нужен для сборки windows; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `desktop_voice_native_overlay.h` в `windows/runner`.
- **Обязанности:** Поддержка embedder windows.
- **Когда открывать:** Ошибка сборки с `desktop_voice_native_overlay.h`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `windows/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки windows: `flutter_window.cpp` в `windows/runner`.
- **Зачем:** Нужен для сборки windows; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `flutter_window.cpp` в `windows/runner`.
- **Обязанности:** Поддержка embedder windows.
- **Когда открывать:** Ошибка сборки с `flutter_window.cpp`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `windows/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки windows: `flutter_window.h` в `windows/runner`.
- **Зачем:** Нужен для сборки windows; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `flutter_window.h` в `windows/runner`.
- **Обязанности:** Поддержка embedder windows.
- **Когда открывать:** Ошибка сборки с `flutter_window.h`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `windows/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки windows: `main.cpp` в `windows/runner`.
- **Зачем:** Нужен для сборки windows; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `main.cpp` в `windows/runner`.
- **Обязанности:** Поддержка embedder windows.
- **Когда открывать:** Ошибка сборки с `main.cpp`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `windows/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки windows: `resource.h` в `windows/runner`.
- **Зачем:** Нужен для сборки windows; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `resource.h` в `windows/runner`.
- **Обязанности:** Поддержка embedder windows.
- **Когда открывать:** Ошибка сборки с `resource.h`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `windows/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки windows: `app_icon.ico` в `windows/runner/resources`.
- **Зачем:** Нужен для сборки windows; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `app_icon.ico` в `windows/runner/resources`.
- **Обязанности:** Поддержка embedder windows.
- **Когда открывать:** Ошибка сборки с `app_icon.ico`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `windows/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки windows: `runner.exe.manifest` в `windows/runner`.
- **Зачем:** Нужен для сборки windows; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `runner.exe.manifest` в `windows/runner`.
- **Обязанности:** Поддержка embedder windows.
- **Когда открывать:** Ошибка сборки с `runner.exe.manifest`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `windows/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки windows: `utils.cpp` в `windows/runner`.
- **Зачем:** Нужен для сборки windows; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `utils.cpp` в `windows/runner`.
- **Обязанности:** Поддержка embedder windows.
- **Когда открывать:** Ошибка сборки с `utils.cpp`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `windows/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки windows: `utils.h` в `windows/runner`.
- **Зачем:** Нужен для сборки windows; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `utils.h` в `windows/runner`.
- **Обязанности:** Поддержка embedder windows.
- **Когда открывать:** Ошибка сборки с `utils.h`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `windows/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки windows: `win32_window.cpp` в `windows/runner`.
- **Зачем:** Нужен для сборки windows; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `win32_window.cpp` в `windows/runner`.
- **Обязанности:** Поддержка embedder windows.
- **Когда открывать:** Ошибка сборки с `win32_window.cpp`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `windows/`.
- **Слой:** Платформенная обёртка Flutter.


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

- **Что это:** Файл сборки windows: `win32_window.h` в `windows/runner`.
- **Зачем:** Нужен для сборки windows; без него возможны ошибки compile.
- **Содержимое:** Native/config-содержимое `win32_window.h` в `windows/runner`.
- **Обязанности:** Поддержка embedder windows.
- **Когда открывать:** Ошибка сборки с `win32_window.h`.
- **Можно удалить?** Нет — нужен для сборки платформы.
- **Связано с:** Папка `windows/`.
- **Слой:** Платформенная обёртка Flutter.

