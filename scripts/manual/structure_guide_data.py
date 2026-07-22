"""Curated owner-readable folder and special-file guides for APP_STRUCTURE_DETAILED."""

from __future__ import annotations

from pathlib import Path, PurePosixPath

from structure_en_ru_adapt import (
    adapt_folder_guide_ru,
    has_banned_filler,
    ru_field_ok,
)
from structure_ru_class_adapters import BANNED_ENGLISH_IN_RU, BANNED_GENERIC_RU_WRAPPERS, BANNED_SEMI_RUSSIAN_WRAPPERS

# Side effect: registers curated folder RU blocks.
import structure_folder_ru_curated  # noqa: F401

# Each folder entry: what, why, inside, affects, when, delete, related
FOLDERS: dict[str, dict[str, str]] = {
    "lib": {
        "what": "The Flutter application itself — screens, navigation, cards, buttons, data brain, PocketBase sync, offline queue, localization, shared UI.",
        "why": "Everything users see and everything that saves data lives here; without `lib/` there is no app.",
        "inside": "`lib/data/` brain · `lib/features/` screens · `lib/core/` design system · `lib/app/shell/` navigation · `lib/l10n/` texts · `lib/services/` device notifications.",
        "affects": "The entire product on Android, iOS, web, Windows, Wear.",
        "when": "Almost any product bug, UI change, or PocketBase behavior fix.",
        "delete": "No — deleting `lib/` removes the application.",
        "related": "`pubspec.yaml`, `main.dart`, platform folders.",
        "what_ru": "Это само Flutter-приложение. Здесь живут экраны, навигация, карточки, кнопки, мозг данных, PocketBase-синхронизация, offline queue, локализация и общие UI-компоненты.",
        "why_ru": "Если удалить `lib`, приложения больше нет — весь продукт собран из этой папки.",
        "inside_ru": "`lib/data/` — мозг (PocketBase, cache, optimistic UI, offline). `lib/features/` — экраны Timeline, Plans, Lists, Calendar, Profile, Categories. `lib/core/` — design system, тема, time, desktop voice. `lib/app/shell/` — вкладки по форм-фактору, More, edit sheets, offline banner. `lib/l10n/` — тексты UI. `lib/services/` — уведомления устройства.",
        "affects_ru": "Весь продукт на всех платформах.",
        "when_ru": "Любой баг UI, сохранение данных, offline, локализация.",
        "delete_ru": "Нет — удаление уничтожает приложение.",
        "related_ru": "`pubspec.yaml`, `main.dart`, platform-папки.",
    },
    "lib/data": {
        "what": "The app “brain” — everything that talks to PocketBase, holds cached data, and applies changes before the server confirms.",
        "why": "Single place for save/load rules so Timeline, Plans, Lists, and Categories stay consistent and offline-safe.",
        "inside": "Coordinator files (`*_service.dart`, `database_service.dart`) and focused `part` modules in subfolders.",
        "affects": "Timeline records, plans, lists, categories, tags, profile settings, offline queue.",
        "when": "Wrong data, failed save, optimistic UI rollback, offline banner, or PocketBase field errors.",
        "delete": "No — the UI cannot work without the brain.",
        "related": "`docs/DATA_MAP.md`, `docs/POCKETBASE_MANIFEST.md`, `lib/features/`.",
    },
    "lib/data/categories": {
        "what": "Category-management slice of the brain — tree, colors, matching names, and linking records to categories.",
        "why": "Categories organize timeline time, plans, stats, and voice commands like “Price Reporter …”.",
        "inside": "Seven focused `part` files; each handles one category job (see file entries below).",
        "affects": "Category picker, category manager screen, record category on start/stop, plan category chips, stats by category.",
        "when": "Categories missing, wrong color/icon, fuzzy match picks wrong client, records saved without category.",
        "delete": "No — category features stop working.",
        "related": "`lib/data/category_service.dart`, `lib/features/categories/`.",
    },
    "lib/data/records": {
        "what": "Timeline record slice of the brain — start/stop timer, edit history, realtime updates, offline queue.",
        "why": "Timeline is the core time tracker; this folder splits record logic into readable modules.",
        "inside": "CRUD, optimistic UI, realtime subscription, timeline list builders, overlap/Highlander rules, outbox.",
        "affects": "Timeline tab, record edit sheet, Wear lite timer, voice “start record”.",
        "when": "Timer won’t start/stop, wrong day bucket, duplicate running records, offline start fails.",
        "delete": "No — timeline tracking breaks.",
        "related": "`lib/data/record_service.dart`, `lib/features/timeline/`.",
    },
    "lib/data/plans": {
        "what": "Plans and lists slice of the brain — scheduled tasks, backlog items, recurrence, tags on plans.",
        "why": "Planning tab, Lists tab, and calendar rows all read/write the same `plans` table through these modules.",
        "inside": "Projection for Time View, RRULE expansion, tag sync, plan cache, offline plan outbox, `diagnostics/`.",
        "affects": "Plans tab, Time View layout, Lists tab, plan edit sheets, plan alarms.",
        "when": "Plans don’t save, recurrence wrong, Time View cards misplaced, list toggle offline.",
        "delete": "No — planning and lists break.",
        "related": "`lib/data/plan_service.dart`, `lib/features/planning/`, `lib/features/lists/`.",
    },
    "lib/data/plans/diagnostics": {
        "what": "Planning-domain diagnostics inside the Brain (duplicate plan / stream lifecycle markers).",
        "why": "Brain plan helpers emit these logs; must not live under feature UI or create data→features imports.",
        "inside": "`plan_duplicate_log.dart`.",
        "affects": "Plan duplicate / stream diagnostic markers only.",
        "when": "Investigating duplicate plan rows or plan stream spam.",
        "delete": "No — Brain plan helpers emit these markers.",
        "related": "`lib/shared/diagnostics/performance/runtime_flags.dart` for `kPlanStreamLifecycleDiag` only.",
    },
    "lib/data/profile": {
        "what": "User profile and tags slice of the brain — timezone, settings, tag catalog, admin flag.",
        "why": "Wall-clock “today”, language, tag chips, and tag manager all depend on profile + tag rows in PocketBase.",
        "inside": "Profile hydration, settings PATCH, timezone math, tag CRUD, tag display prefs.",
        "affects": "Profile screen, tag settings, timezone header, Component Lab admin gate.",
        "when": "Wrong “today” line, timezone not sticking, tags missing on cards, settings won’t save.",
        "delete": "No — profile and tags break.",
        "related": "`lib/data/profile_service.dart`, `lib/features/profile/`.",
    },
    "lib/data/local_sync": {
        "what": "Offline queue — remembers record/plan changes when the network or login fails, then retries later.",
        "why": "Life OS promises tap-first UX; users must not lose starts/stops/edits on bad Wi‑Fi.",
        "inside": "SharedPreferences outboxes, pending-count state, connectivity listener to flush queues.",
        "affects": "Top offline/sync banner, background retry on reconnect, auth-paused state.",
        "when": "“Pending sync” stuck, changes lost offline, banner tap does nothing.",
        "delete": "No — offline-first behavior is shipped product law.",
        "related": "`lib/app_shell.dart` offline banner, `docs/UX_CONTRACT.md`.",
    },
    "lib/data/models": {
        "what": "Plain data shapes (records, plans, categories, tags, profile) — no network code.",
        "why": "Same field names everywhere; aligns with `docs/DATA_MAP.md` so UI and brain agree on what a “record” is.",
        "inside": "Dart classes like `TimelineRecord`, `PlanningTask`, `CategoryRule`, `Tag`.",
        "affects": "Every screen that displays or edits user data.",
        "when": "Wrong date on timeline, parsing errors after PocketBase schema change.",
        "delete": "No — types are required across the app.",
        "related": "`lib/data/models.dart` barrel, `docs/DATA_MAP.md`.",
    },
    "lib/features/planning": {
        "what": "Plans tab UI — day pager, plan list, Time View canvas, plan settings, bulk edit.",
        "why": "This is what users see on the second bottom tab (Plans).",
        "inside": "Large `planning_page.dart` plus `time_view/`, `settings/`, `widgets/` subfolders.",
        "affects": "Plans tab only (plus calendar rows that reuse plan cards).",
        "when": "Plan cards wrong, Time View drag broken, day swipe on Plans tab, play/start plan.",
        "delete": "No — Plans tab disappears.",
        "related": "`lib/app/shell/` tab host, `lib/data/plan_service.dart`.",
    },
    "lib/features/planning/time_view": {
        "what": "Planning “Time View” — proportional day timeline with draggable plan blocks.",
        "why": "Visual schedule mode: plans positioned by clock time, resize/drag, hour grid.",
        "inside": "Canvas, card layer, drag/resize controllers, settings sheet, search for default times.",
        "affects": "Time View sub-mode inside Plans tab.",
        "when": "Cards overlap wrong, drag/resize jank, hour scale, fixed-time tags.",
        "delete": "No — Time View is a core Plans feature.",
        "related": "`planning_page.dart`, `PlanTimeTaskCard` widgets in `core/widgets/`.",
    },
    "lib/features/timeline": {
        "what": "Timeline tab UI — day pager, running/stopped record cards, stats entry.",
        "why": "Primary time-tracking screen (first bottom tab).",
        "inside": "Swipe wrapper, day list, record cards, header controls (stats toggle, input).",
        "affects": "Timeline tab and embedded stats view.",
        "when": "Records on wrong day, now-line, swipe between days, record card tap/edit.",
        "delete": "No — Timeline tab disappears.",
        "related": "`lib/data/record_service.dart`, `ActivityDetailSheet`.",
    },
    "lib/features/lists": {
        "what": "Lists tab UI — backlog/checklist tasks with filters, bulk select, export.",
        "why": "Third productivity tab for non-scheduled list items (same `plans` table, backlog mode).",
        "inside": "Filters, cards, inline add, bulk bar, clipboard export.",
        "affects": "Lists tab (bottom nav index 3).",
        "when": "List filters, checkbox done, bulk delete, export visible list as text.",
        "delete": "No — Lists tab disappears.",
        "related": "`lib/data/plan_service.dart`.",
    },
    "lib/features/notes": {
        "what": "Notes feature UI — GLM library, full-screen block editor, drawing canvas, note cards.",
        "why": "Lists-tab Notes experience and standalone Notes routes compose here; Brain owns PocketBase I/O.",
        "inside": "Library page, block editor, drawing canvas, GLM surfaces/tokens, widget cards/body/shell.",
        "affects": "Lists Notes view, full-screen note editor, drawing blocks on notes.",
        "when": "Notes library layout, editor toolbar, drawing insert, card preview wrong.",
        "delete": "No — Notes product UI breaks.",
        "related": "`lib/core/widgets/notes/`, `lib/data/plans/notes_brain_helpers.dart`, `lib/features/lists/`.",
    },
    "lib/features/notes/widgets": {
        "what": "Notes library widgets — grid/list cards, production GLM shell, library body.",
        "why": "Lists tab embeds these widgets instead of duplicating card/shell layout in `lists_view.dart`.",
        "inside": "`note_card.dart`, `notes_library_body.dart`, `notes_library_production_shell.dart`.",
        "affects": "Notes library grid/list rendering inside Lists.",
        "when": "Note card badges, grid vs list, GLM library shell chrome.",
        "delete": "No — Notes library UI breaks.",
        "related": "`lib/features/notes/`, `lib/features/lists/lists_view.dart`.",
    },
    "lib/features/shared/notes_editor": {
        "what": "Shared Notes editor launch + Quill sheet — full-screen route over Brain autosave.",
        "why": "Lists/Plans open the same Notes editor without embedding Quill wiring in each tab.",
        "inside": "`notes_editor_launcher.dart`, `notes_editor_sheet.dart`.",
        "affects": "Full-screen Notes editor opened from Lists/shared edit flows.",
        "when": "Notes editor route, Quill autosave, More → Edit details handoff.",
        "delete": "No — shared Notes editor entry breaks.",
        "related": "`lib/core/widgets/notes/`, `lib/features/shared/edit_sheet/`.",
    },
    "lib/core/widgets/notes": {
        "what": "Canonical reusable Notes UI — editor surface, toolbar, save status, preview card.",
        "why": "Feature Notes screens compose pure widgets; Core must not import Brain or features.",
        "inside": "Barrel `notes.dart`, context row, editor surface, markdown helpers, toolbar, preview card.",
        "affects": "Any Notes editor/library that imports `package:counter/core/widgets/notes/`.",
        "when": "Invisible web toolbar, save-status chip, Quill↔Markdown copy/paste.",
        "delete": "No — Notes canonical widgets disappear.",
        "related": "`lib/features/notes/`, `lib/features/shared/notes_editor/`.",
    },
    "lib/features/shared": {
        "what": "Shared edit sheets and voice UI used by Timeline, Plans, and Lists.",
        "why": "One edit experience for plans and records — Omni date/time picker, tags, checklist, offline banner.",
        "inside": "Activity detail router, planning/record edit sheets, edit_sheet/* helpers, voice widgets.",
        "affects": "Any tap-to-edit on plans/records; mobile voice sheet; desktop voice panel.",
        "when": "Edit sheet save, date picker, tags on plan, voice input sheet.",
        "delete": "No — edit flows break on all tabs.",
        "related": "`lib/app/shell/shared/shell_edit_hosts.dart`, `docs/UX_CONTRACT.md`.",
    },
    "lib/features/profile": {
        "what": "Profile and tag settings screens from the More menu.",
        "why": "Account, timezone, language, tag manager, desktop voice settings (Windows).",
        "inside": "Profile view, settings sections, tag manager pages.",
        "affects": "More → Profile, tag settings routes, desktop voice card.",
        "when": "Login profile, change timezone, manage tags, desktop hotkey settings.",
        "delete": "No — profile/settings unavailable.",
        "related": "`lib/data/profile/`, `lib/features/dev/` (admin only).",
    },
    "lib/features/categories": {
        "what": "Category manager UI — tree, create/edit, visibility preferences.",
        "why": "Users organize work/personal/client categories from More → Categories.",
        "inside": "List view, recursive tree picker, create dialog, visibility prefs.",
        "affects": "More → Categories; category pickers elsewhere call into these widgets.",
        "when": "Create category, reorder, archive, pick category in tree dialog.",
        "delete": "No — category management UI gone.",
        "related": "`lib/data/categories/`.",
    },
    "lib/features/dev": {
        "what": "Admin-only Component Lab — design-system preview, not shown to normal users.",
        "why": "Validates buttons/cards/chips against `docs/DESIGN_SYSTEM.md` before production migration.",
        "inside": "Component lab page and card demos.",
        "affects": "More menu only when `profiles.is_admin` is true.",
        "when": "Design-system QA, V7 component acceptance.",
        "delete": "Maybe — safe for product runtime, but V7 work uses it; keep for admins.",
        "related": "`docs/DESIGN_SYSTEM.md`, `docs/reports/DESIGN_SYSTEM_INVENTORY.md`.",
    },
    "lib/app/shell": {
        "what": "App shell by form factor — phone bottom nav, tablet compact chrome, desktop side nav, shared tab/voice/edit hosts.",
        "why": "Connects `main.dart` to feature pages; separates shell chrome ownership without redesigning features.",
        "inside": "`app_shell.dart`, `shared/`, `phone/`, `tablet/`, `desktop/`; Wear chrome still in `features/wear/`.",
        "affects": "Navigation, global header, cross-tab voice commands.",
        "when": "Wrong tab, voice command routes to wrong screen, edit sheet host, offline banner, phone vs desktop chrome.",
        "delete": "No — app navigation collapses.",
        "related": "`lib/app_shell.dart`, all `lib/features/*` tabs.",
    },
    "lib/app/shell/shared": {
        "what": "Form-factor-neutral shell state — tabs, edit hosts, voice routing, offline banner, settings.",
        "why": "Shared shell behavior must not live inside phone-only or desktop-only layout files.",
        "inside": "Part mixins, offline banner, form-factor resolve, profile hydration bar, settings page.",
        "affects": "All form factors.",
        "when": "Tab persistence, More menu logic, voice routing, sync banner.",
        "delete": "No.",
        "related": "`lib/app/shell/app_shell.dart`.",
    },
    "lib/app/shell/phone": {
        "what": "Phone shell chrome — compact bottom navigation and phone content frame.",
        "why": "Narrow viewports keep touch-first bottom tabs.",
        "inside": "`shell_bottom_navigation.dart`, `phone_shell_frame.dart`.",
        "affects": "APK and narrow web/phone widths.",
        "when": "Bottom nav layout, compact labels.",
        "delete": "No — phone navigation breaks.",
        "related": "`lib/core/shell_adaptive.dart`.",
    },
    "lib/app/shell/tablet": {
        "what": "Tablet shell frame — currently same compact chrome as phone below desktop breakpoint.",
        "why": "Explicit tablet ownership without inventing a new tablet redesign.",
        "inside": "`tablet_shell_frame.dart`.",
        "affects": "Mid-width compact viewports.",
        "when": "Tablet chrome diverges from phone later.",
        "delete": "Maybe — only after phone frame covers tablet call sites.",
        "related": "`lib/app/shell/phone/`.",
    },
    "lib/app/shell/desktop": {
        "what": "Desktop/web shell chrome — side navigation and wide content frame.",
        "why": "Wide viewports replace bottom nav with side nav.",
        "inside": "`shell_side_navigation.dart`, `desktop_shell_frame.dart`.",
        "affects": "Desktop, web, and wide tablet landscape at/above 900px.",
        "when": "Side nav labels, wide shell layout.",
        "delete": "No — desktop navigation breaks.",
        "related": "`lib/core/shell_adaptive.dart`.",
    },
    "lib/core/widgets": {
        "what": "Reusable UI building blocks (buttons, cards, headers, pickers) — the design system in code.",
        "why": "One canonical button/card so Plans, Timeline, and Lists look consistent.",
        "inside": "`AppButton`, `PlanTimeTaskCard`, date header, timezone picker, chips.",
        "affects": "Every main tab and most sheets.",
        "when": "Button style migration, plan card layout, date/time picker, loading/empty states.",
        "delete": "No — features depend on these widgets.",
        "related": "`docs/DESIGN_SYSTEM.md`, `lib/features/dev/component_lab_view.dart`.",
    },
    "lib/core/widgets/plan_time_task_card": {
        "what": "Plan task card visuals — list rows, Time View blocks, calendar rows (CardPlan design).",
        "why": "Plans look the same in list mode, Time View, and calendar; play/checkbox/menu shared.",
        "inside": "Split modules: density, geometry, layouts, tags, progress, controls.",
        "affects": "Planning cards, Time View blocks, calendar plan rows.",
        "when": "Card height, tag pills, play button, Time View density bands.",
        "delete": "No — plan UI breaks everywhere.",
        "related": "`lib/features/planning/`, `plan_card_layouts.dart`.",
    },
    "android": {
        "what": "Android wrapper — tells Android how to build the APK, permissions, icons, Google services file.",
        "why": "Flutter needs native Android project files to produce installable APK/AAB.",
        "inside": "Gradle scripts, `AndroidManifest.xml`, Kotlin/Java plugin registrant.",
        "affects": "Android phone/tablet/Wear builds only.",
        "when": "APK build fails, permission denied, package name, Gradle errors.",
        "delete": "No — if Android APK support is required.",
        "related": "`android.ps1`, `.github/workflows/`.",
    },
    "ios": {
        "what": "iOS wrapper — Xcode project for iPhone/iPad builds.",
        "why": "Apple requires this structure for App Store or TestFlight builds.",
        "inside": "Xcode project, Info.plist, asset catalogs, Flutter iOS embedder.",
        "affects": "iOS builds only.",
        "when": "iOS compile/signing issues, permissions, icons.",
        "delete": "No — if iOS builds are required.",
        "related": "`lib/`, Flutter tooling.",
    },
    "web": {
        "what": "Web shell — `index.html`, PWA manifest, icons for GitHub Pages site.",
        "why": "Browser version loads Flutter web build; base href `/Counter/` for GitHub Pages.",
        "inside": "HTML entry, favicon, web icons.",
        "affects": "https://nkuchenov-hash.github.io/Counter/",
        "when": "Web deploy blank page, wrong base href, missing icons.",
        "delete": "No — web deploy breaks.",
        "related": "`docs/DEPLOY.md`, `.github/workflows/deploy.yml`.",
    },
    "windows": {
        "what": "Windows desktop runner — native `.exe` host for Flutter on Windows.",
        "why": "Desktop voice, tray, hotkey, and installer packaging need Windows embedder.",
        "inside": "CMake project, runner main, plugin registration.",
        "affects": "Windows desktop app and `CounterSetup.exe` contents.",
        "when": "Windows build fails, desktop voice/tray issues at OS level.",
        "delete": "No — if Windows desktop is supported.",
        "related": "`installer/windows/`, `docs/DEPLOY.md` Windows section.",
    },
    "installer": {
        "what": "Windows installer packaging — builds `CounterSetup.exe` users can run to install the app.",
        "why": "Flutter build alone is a folder of files; installer bundles app + STT helper + icons.",
        "inside": "Inno Setup script (`counter.iss`), STT payload prep scripts, optional helper build.",
        "affects": "Windows distribution via GitHub Actions artifact.",
        "when": "Installer missing files, STT helper not bundled, SmartScreen packaging.",
        "delete": "No — while Windows installer distribution is needed.",
        "related": "`.github/workflows/windows-desktop-build.yml`, `docs/DEPLOY.md`.",
    },
    "installer/windows": {
        "what": "Scripts and Inno Setup rules for the Windows setup `.exe`.",
        "why": "Automates copying Release build, speech helper, and whisper model into install package.",
        "inside": "`counter.iss`, `prepare_stt_payload.ps1`, helper build scripts.",
        "affects": "CI `CounterSetup` artifact and local installer builds.",
        "when": "Installer build broken, missing STT on installed app.",
        "delete": "No — required for Windows installer.",
        "related": "`flutter build windows`, GitHub Actions workflow.",
    },
    "pb_hooks": {
        "what": "JavaScript hooks copied to the PocketBase server — rules that run on the VPS, not in the phone app.",
        "why": "Server enforces password-reset flow and prevents overlapping running records.",
        "inside": "Two hook files (auth reset, record interval sanitize).",
        "affects": "Forgot-password email flow; server-side record overlap cleanup.",
        "when": "Password reset fails server-side; duplicate running records on server.",
        "delete": "No — production PocketBase expects these hooks per manifest.",
        "related": "`docs/POCKETBASE_MANIFEST.md`, `docs/DEPLOY.md` auth admin section.",
    },
    "scripts": {
        "what": "Developer and CI scripts — deploy, audits, locale sync, structure docs, desktop voice smoke tests.",
        "why": "Repeatable commands so builds and doc checks don’t rely on memory.",
        "inside": "`audit/`, `manual/`, `sync_locales.dart`.",
        "affects": "Deploy pipeline, architecture guard, this detailed structure doc regeneration.",
        "when": "Deploy web site, run strict guard, regenerate structure map, voice smoke on Windows.",
        "delete": "No — required for deploy/audit/doc workflows documented in repo.",
        "related": "`update.ps1`, `docs/DEPLOY.md`, `docs/APP_STRUCTURE.md` §6.",
    },
    "docs": {
        "what": "Written project law — architecture, data fields, design system, roadmap, deploy steps.",
        "why": "Owner and AI assistants need one place for “how the app must behave” beyond code.",
        "inside": "Governing specs, Project Knowledge pack, reports, website copy (`docs/website/`).",
        "affects": "Development decisions, AI context, website planning — not runtime binary.",
        "when": "Any structural or behavior question; upload list in `PROJECT_KNOWLEDGE_PACK.md`.",
        "delete": "No — governing/current documentation.",
        "related": "14-doc Project Knowledge pack, `CHANGELOG.md`.",
    },
    "test": {
        "what": "Automated tests run by `flutter test` — guards regressions without manual clicking.",
        "why": "Catches broken voice parse, timezone, plan cards, perf contracts before release.",
        "inside": "Widget tests, domain unit tests, perf diagnostic tests.",
        "affects": "CI quality gate; not shipped to users.",
        "when": "Adding/changing behavior that must stay stable; CI failures.",
        "delete": "No — required for tests.",
        "related": "Production files with matching names under `lib/`.",
    },
    ".github": {
        "what": "GitHub automation folder — CI workflows that publish the web site and build the Windows installer.",
        "why": "Robots run here after git push: one workflow deploys GitHub Pages, another builds `CounterSetup.exe`.",
        "inside": "`workflows/deploy.yml`, `workflows/windows-desktop-build.yml`, `copilot-instructions.md`.",
        "affects": "Live site at GitHub Pages and Windows installer artifact — not in-app screens.",
        "when": "CI deploy failed, site not updating, Windows installer artifact missing.",
        "delete": "No — if GitHub Pages deploy and Windows installer artifacts are required.",
        "related": "`update.ps1`, `docs/DEPLOY.md`.",
        "what_ru": "Папка автоматизации GitHub. Здесь workflow-файлы: один публикует web build на GitHub Pages после push, другой собирает Windows installer artifact.",
        "why_ru": "Это не экран приложения, а роботы сборки и публикации.",
        "inside_ru": "Workflow-файлы: `deploy.yml`, `windows-desktop-build.yml`, `copilot-instructions.md`.",
        "affects_ru": "Живой сайт и артефакт Windows installer.",
        "when_ru": "CI deploy упал, сайт не обновился, нет CounterSetup.exe в Actions.",
        "delete_ru": "Нет — если нужны GitHub Pages и Windows installer.",
        "related_ru": "`update.ps1`, `docs/DEPLOY.md`.",
    },
    "lib/core": {
        "what": "Foundation layer — theme colors, shared widgets, desktop voice services.",
        "why": "Feature screens must not duplicate buttons, date headers, or voice plumbing; this is the design-system and utility base.",
        "inside": "`theme.dart`, `core/widgets/` (AppButton, plan cards), `core/services/` (tray + main window).",
        "affects": "Look and feel on every tab; desktop voice/tray; header chrome widgets.",
        "when": "Button/card migration, desktop voice broken, theme token change.",
        "delete": "No — features import foundation code everywhere.",
        "related": "`docs/DESIGN_SYSTEM.md`, `lib/features/`, `lib/shared/`, `lib/data/models.dart` (types only).",
    },
    "lib/features": {
        "what": "All user-facing screens — Timeline, Plans, Lists, Profile, Categories, auth, Wear, shared edit sheets.",
        "why": "Separates what users see and tap from the PocketBase brain in `lib/data/`.",
        "inside": "One folder per tab or flow: `timeline/`, `planning/`, `lists/`, `shared/`, `profile/`, etc.",
        "affects": "Every visible part of the app except raw platform wrappers.",
        "when": "UI bug on a specific tab, new screen, edit sheet behavior, voice sheet layout.",
        "delete": "No — deleting this removes the entire product UI.",
        "related": "`lib/app/shell/` (navigation host), `lib/data/` (saves/loads).",
    },
    "lib/l10n": {
        "what": "Translations — every button label, error message, and menu title the app shows.",
        "why": "Users switch language in settings; all text must resolve through one dictionary.",
        "inside": "`dictionary.dart` (`t()` lookup), `langs/en.dart` + `langs/ru.dart` (canonical), partial other locales.",
        "affects": "All visible strings in every locale.",
        "when": "Missing translation key, wrong language text, adding a new UI label.",
        "delete": "No — app shows raw keys or crashes without l10n.",
        "related": "`scripts/sync_locales.dart`, `lib/l10n/langs/HELP HOW TO UPDATE the languages`.",
    },
    "lib/services": {
        "what": "Device-only services that are not PocketBase — currently plan alarm notifications.",
        "why": "OS notification scheduling lives outside the brain; keeps `lib/data/` free of platform notification APIs.",
        "inside": "`notification_service.dart` — local notifications and plan alarm reschedule hooks.",
        "affects": "Plan reminder notifications on phone/desktop.",
        "when": "Plan alarm not firing, notification permission issues.",
        "delete": "No — plan alarms stop working.",
        "related": "`lib/data/plan_service.dart` alarm reschedule requests.",
    },
    "lib/core/env": {
        "what": "Compile-time environment template — copy to gitignored `env.dart` for local secrets/constants.",
        "why": "Some build-time values must not be committed; example file documents the required shape.",
        "inside": "`env.dart.example` only in git; real `env.dart` is local.",
        "affects": "Developer local builds only if env constants are referenced.",
        "when": "Setting up a new dev machine; adding compile-time constant.",
        "delete": "No — documents required env.dart structure.",
        "related": "`.gitignore` entry for `lib/core/env/env.dart`.",
    },
    "lib/core/navigation": {
        "what": "Root navigator key and desktop side-rail navigation helpers.",
        "why": "Desktop voice overlay and hidden main window need a global navigator; side rail replaces bottom tabs on wide screens.",
        "inside": "`app_navigator.dart` (`appRootNavigatorKey`), `shell_side_navigation.dart`.",
        "affects": "Desktop/web layout (side nav) and overlay routing above tabs.",
        "when": "Desktop overlay cannot push routes; side navigation breakpoint wrong.",
        "delete": "No — desktop layout and overlays break.",
        "related": "`lib/app/shell/desktop/shell_side_navigation.dart`, `lib/core/shell_adaptive.dart`.",
    },
    "lib/shared/diagnostics/performance": {
        "what": "Runtime feature flags and optional perf metrics — date strip, warm window, rebuild counters.",
        "why": "Lets developers toggle expensive features or capture frame metrics without shipping debug code to all users. Kill-switch registry stays intact (no split).",
        "inside": "`runtime_flags.dart`, `shell_flags.dart`, `rebuild_metrics.dart` (`PERF_DIAG` gated).",
        "affects": "Perf-sensitive paths: date paging, shell tab stack, Planning Time View canvas bisect, diagnostic builds.",
        "when": "Investigating jank, toggling warm-window kill switch, perf capture tests.",
        "delete": "No — perf tests and diagnostics reference these flags.",
        "related": "`test/perf_*`, `lib/data/cache/`, `lib/shared/diagnostics/`.",
    },
    "lib/shared": {
        "what": "Cross-cutting shared code with multiple independent consumers — time, diagnostics, Voice system.",
        "why": "Avoid dumping single-feature helpers here; only multi-consumer ownership belongs under shared.",
        "inside": "`time/` — wall-clock and timezone; `diagnostics/` — runtime logs + kill switches; `voice/` — one Voice system (commands/recognition/routing/ui/platforms/diagnostics).",
        "affects": "Header clock, Brain projection, Plans Time View, settings timezone labels, kill switches, Voice activation across platforms.",
        "when": "Moving multi-consumer time/diagnostics/voice, wrong today, DST labels, kill-switch toggles, Voice pipeline tracing.",
        "delete": "No — Brain and UI need shared time, diagnostics, and Voice.",
        "related": "`lib/shared/time/`, `lib/shared/diagnostics/`, `lib/shared/voice/`, `docs/APP_STRUCTURE.md`.",
    },
    "lib/shared/diagnostics": {
        "what": "General runtime logs and the shared kill-switch / metrics registry.",
        "why": "Brain, shell, core, and features need one place for release-safe markers and compile-time performance toggles.",
        "inside": "`runtime_log.dart`, `platform_log.dart`, `startup_log.dart`, `performance/` (flags + rebuild metrics).",
        "affects": "Boot timing logs, kill switches, rebuild metrics — not product UI chrome.",
        "when": "Startup timing, kill-switch bisect, release-safe runtime markers.",
        "delete": "No — Brain and shell import these paths.",
        "related": "`lib/shared/diagnostics/performance/`, `docs/ARCHITECTURE.md` PERFORMANCE_KILL_SWITCH_LAW.",
    },
    "lib/shared/voice": {
        "what": "One Voice system — commands, recognition, routing, UI, platform adapters, diagnostics.",
        "why": "Phone mic, desktop hotkey, web mic, and Wear adapters must share one command interpretation path.",
        "inside": "`commands/`, `recognition/`, `routing/`, `ui/`, `platforms/desktop/`, `platforms/mobile/`, `diagnostics/`.",
        "affects": "All Voice activation, STT, overlays, and shared mic UI — not PocketBase writes.",
        "when": "Voice ownership moves, import-boundary violations, or activation-path drift across platforms.",
        "delete": "No — Voice product feature.",
        "related": "`lib/data/voice/`, `lib/features/settings/voice/`, `lib/app/shell/shared/shell_voice_routing.dart`.",
    },
    "lib/shared/voice/diagnostics": {
        "what": "Voice pipeline markers — concise log + step helpers.",
        "why": "Desktop STT/voice services and Brain voice parsing share one quiet release / verbose debug-profile sink.",
        "inside": "`desktop_voice_log.dart`, `desktop_voice_pipeline.dart`.",
        "affects": "Developer diagnostics for Voice only.",
        "when": "Tracing Voice capture, STT, overlay, or submit steps.",
        "delete": "No — used by debug/profile Voice builds.",
        "related": "`lib/shared/voice/platforms/desktop/`, `lib/shared/diagnostics/`.",
    },
    "lib/shared/voice/commands": {
        "what": "Platform-neutral Voice command / policy contracts (merge, quality, engine IDs, correction flow).",
        "why": "Command semantics must not fork per activation method (phone vs desktop vs web).",
        "inside": "Transcript merge, delayed transcribe, capture-ready policy, engine/STT types, quality evaluation, STT policy, correction flow, install smoke policy.",
        "affects": "Shared Voice interpretation rules used by desktop runtime and Brain-adjacent gates.",
        "when": "Changing merge/quality/policy rules without platform-specific UX redesign.",
        "delete": "No — shared Voice contracts break.",
        "related": "`lib/shared/voice/platforms/desktop/`, `lib/data/voice/`.",
    },
    "lib/shared/voice/recognition": {
        "what": "Platform-neutral recognition contracts — engine handle, locale, recognizer interface, user errors.",
        "why": "Recognition adapters differ by platform; contracts stay shared.",
        "inside": "`speech_engine_handle.dart`, `speech_listen_locale.dart`, recognizer factory/stub, user error taxonomy.",
        "affects": "Mobile/web sheet STT and desktop recognizer wiring.",
        "when": "Recognizer selection, locale resolution, error mapping.",
        "delete": "No — recognition contracts break.",
        "related": "`lib/shared/voice/ui/`, `lib/shared/voice/platforms/desktop/`.",
    },
    "lib/shared/voice/routing": {
        "what": "Voice acceptance-test callback bridge only (no command execution).",
        "why": "Shell owns active section; Brain owns parse/normalize/writeRecord.",
        "inside": "`desktop_voice_acceptance_bridge.dart`.",
        "affects": "Acceptance hooks only.",
        "when": "Acceptance-test wiring changes.",
        "delete": "No — acceptance bridge breaks.",
        "related": "`lib/data/voice/desktop_voice_record_submit.dart`, `lib/app/shell/shared/shell_voice_routing.dart`.",
    },
    "lib/shared/voice/ui": {
        "what": "Reusable Voice UI — mic sheet, capture config, level bars.",
        "why": "Mic activation UI is shared across tabs; not product-section UI.",
        "inside": "`voice_input_sheet.dart`, `voice_capture_config.dart`, `app_mic_level_bars.dart`.",
        "affects": "Phone/web mic sheet and shared level visualization.",
        "when": "Mic sheet routing, listening UI, level meters.",
        "delete": "No — shared Voice UI breaks.",
        "related": "`lib/app/shell/shared/shell_voice_routing.dart`.",
    },
    "lib/shared/voice/platforms": {
        "what": "Platform Voice adapters — desktop runtime and mobile/web audio helpers.",
        "why": "Activation and recognition differ by OS; command semantics stay shared.",
        "inside": "`desktop/`, `mobile/`.",
        "affects": "Desktop hotkey/overlay/STT and web/mobile audio adapters.",
        "when": "Platform-specific Voice activation or recognition changes.",
        "delete": "No — platform Voice adapters break.",
        "related": "`lib/shared/voice/commands/`, `lib/data/voice/`, `lib/features/voice/`.",
    },
    "lib/shared/voice/platforms/desktop": {
        "what": "Desktop Voice / STT runtime — hotkey, helper process, overlay, capture, prefs.",
        "why": "Windows desktop activation is an implementation of the shared Voice system, not a separate product.",
        "inside": "STT helper + orchestrator, hotkey, overlay, capture, settings, diagnostics.",
        "affects": "Windows Voice hotkey, overlay, GOLOS STT, desktop prefs.",
        "when": "Desktop Voice not recording, hotkey dead, overlay latency, STT helper failures.",
        "delete": "No — desktop Voice feature.",
        "related": "`lib/features/voice/`, `lib/core/services/desktop_tray_service.dart`.",
    },
    "lib/shared/voice/platforms/mobile": {
        "what": "Mobile/web Voice audio adapters used by the shared mic sheet.",
        "why": "Web Audio vs stub differs by platform; keep adapters next to Voice ownership.",
        "inside": "`voice_audio_web.dart`, `voice_audio_stub.dart`.",
        "affects": "Voice sheet tone / audio helpers on web vs non-web.",
        "when": "Web Voice audio stub mismatches.",
        "delete": "No — conditional Voice audio import breaks.",
        "related": "`lib/shared/voice/ui/voice_input_sheet.dart`.",
    },
    "lib/data/voice": {
        "what": "Brain Voice — parser, domain resolver, normalize, record-submit, glossary builder, contamination/postprocess, cloud STT, parser-tied benchmarks.",
        "why": "Live category index, PocketBase writes, and command execution belong in Brain, not shared Voice.",
        "inside": "`voice_command_parser.dart`, domain resolver part, glossary, normalize, contamination, postprocess, record-submit, useful-speech evaluator, cloud backend, benchmarks, Price Reporter client match.",
        "affects": "Voice command → category/record interpretation, writeRecord, and cloud STT auth transport.",
        "when": "Parser/domain match wrong, cloud STT auth, glossary postprocess, command execution.",
        "delete": "No — Voice command execution breaks.",
        "related": "`lib/shared/voice/`, `lib/features/voice/`, `lib/data/database_service.dart`.",
    },
    "lib/features/voice": {
        "what": "Desktop Flutter Voice overlay UI — widget, capsule, correction sheet, command panel.",
        "why": "Desktop Voice chrome is feature UI; shared Voice stays Brain-free.",
        "inside": "`desktop_voice_widget.dart`, capsule, correction sheet, command panel.",
        "affects": "Desktop Voice overlay UI only.",
        "when": "Desktop Voice capsule/overlay UI regressions.",
        "delete": "No — desktop Voice UI breaks.",
        "related": "`lib/shared/voice/platforms/desktop/`, `lib/data/voice/`, `lib/app/shell/shared/shell_voice_routing.dart`.",
    },
    "lib/features/settings/voice": {
        "what": "User-facing Voice settings UI — hotkey, mic, recognizer, attempt diagnostics.",
        "why": "Voice settings are settings ownership, not profile chrome.",
        "inside": "`desktop_voice_settings_section.dart`, `desktop_voice_settings_desktop.dart`, `desktop_voice_attempt_dialog.dart`.",
        "affects": "Profile/settings Voice controls on desktop.",
        "when": "Hotkey prefs UI, attempt dialog, developer Voice gates.",
        "delete": "No — Voice settings UI unavailable.",
        "related": "`lib/shared/voice/platforms/desktop/desktop_voice_settings.dart`, `lib/features/profile/profile_view.dart`.",
    },
    "lib/shared/time": {
        "what": "Shared wall-clock and timezone math used by Brain, shell header, Plans, and settings.",
        "why": "Time bucketing must follow profile timezone law — not device local time — across multiple product sections.",
        "inside": "`app_clock.dart`, `profile_timezone_catalog.dart`, `wall_clock.dart`, `plan_time_visible_window.dart`, plan labels, category TZ options.",
        "affects": "Global header clock, Time View hour window (−3..27 h), timezone picker labels, plan wall projection.",
        "when": "Wrong ‘today’, header TZ label, Time View visible hours, DST label wrong.",
        "delete": "No — timeline and planning time display breaks.",
        "related": "`lib/data/profile/profile_timezone.dart`, `lib/core/widgets/global_app_header.dart`, `lib/features/settings/`.",
    },
    "lib/features/settings": {
        "what": "Settings-owned helpers — timezone labels plus Voice settings UI.",
        "why": "Profile timezone option lists and Voice settings belong to settings, not core or profile-only chrome.",
        "inside": "`timezone_settings.dart`, `voice/` (desktop Voice settings section/desktop/attempt dialog).",
        "affects": "Profile timezone selection labels and desktop Voice settings controls.",
        "when": "Timezone option list, Voice hotkey/mic settings UI.",
        "delete": "No — settings timezone/Voice helpers break.",
        "related": "`lib/shared/time/`, `lib/shared/voice/`, `lib/features/profile/profile_view.dart`.",
    },
    "lib/data/cache": {
        "what": "Performance caches for fast date paging — warm day snapshots and rendered list bodies.",
        "why": "Swiping Timeline/Plans days must stay smooth with large record/plan histories.",
        "inside": "`day_snapshot_window.dart`, `rendered_day_body_cache.dart`, `render_snapshot.dart`.",
        "affects": "Day swipe smoothness on Timeline and Planning; not user-visible data correctness.",
        "when": "Jank swiping days, stale day content after edit, perf regression.",
        "delete": "No — paging becomes slow or glitchy.",
        "related": "`lib/data/records/record_timeline_vm.dart`, `lib/shared/diagnostics/performance/runtime_flags.dart`.",
    },
    "lib/features/auth": {
        "what": "Sign-in, registration, OAuth, and password-reset screens before the main app loads.",
        "why": "Users must authenticate to PocketBase before Timeline/Plans data is available.",
        "inside": "`auth_view.dart`, `auth_screen.dart`, `oauth_session.dart`.",
        "affects": "Login gate shown from `main.dart` when session invalid.",
        "when": "OAuth redirect broken, login form, register flow, password reset UI.",
        "delete": "No — users cannot sign in.",
        "related": "`lib/data/auth_bridge.dart`, `docs/DEPLOY.md` OAuth admin section.",
    },
    "lib/features/calendar": {
        "what": "Calendar tab UI — month view of plans (when enabled in navigation).",
        "why": "Alternative plan browsing by calendar month alongside Plans tab list/Time View.",
        "inside": "`calendar_view.dart`.",
        "affects": "Calendar tab in bottom/side navigation (when present in shell).",
        "when": "Calendar month layout, plan dots on dates, calendar navigation.",
        "delete": "Maybe — if calendar tab removed from shell; keep while route exists.",
        "related": "`lib/features/planning/`, plan card widgets in `core/widgets/`.",
    },
    "lib/features/stats": {
        "what": "Productivity stats views embedded inside Timeline — hours by category, plan vs fact.",
        "why": "Stats toggle on Timeline header switches list mode to analytics without a separate app area.",
        "inside": "`stats_view.dart`, `plan_vs_fact_tab.dart`.",
        "affects": "Timeline tab when user taps Stats segmented control.",
        "when": "Stats totals wrong, plan-vs-fact chart, stats tab toggle.",
        "delete": "No — Timeline stats mode disappears.",
        "related": "`lib/data/categories/category_stats.dart`, `lib/features/timeline/timeline_header_controls.dart`.",
    },
    "lib/features/wear": {
        "what": "Wear OS watch companion — simplified timer screen on Android watches.",
        "why": "Watch form factor needs a lite UI and `loadInitialDataWearLite` brain path.",
        "inside": "`wear_timer_screen.dart`, `wear_main_wrapper.dart`, platform channel shims.",
        "affects": "Wear OS APK companion only — not phone Timeline UI.",
        "when": "Watch timer sync, Wear build entry, companion crashes on watch.",
        "delete": "No — if Wear OS companion is a supported target.",
        "related": "`lib/data/db_core.dart` Wear lite load, `android/` Wear module if configured.",
    },
    "linux": {
        "what": "Linux desktop Flutter embedder — CMake project to build Counter on Linux.",
        "why": "Flutter requires native runner sources for Linux desktop target.",
        "inside": "Top-level `CMakeLists.txt`, `flutter/` generated glue, `runner/` GTK entry.",
        "affects": "Linux desktop builds only — not Android/iOS/web.",
        "when": "Linux desktop compile fails, GTK runner errors.",
        "delete": "No — if Linux desktop support is kept.",
        "related": "`windows/`, `macos/` sibling desktop folders.",
    },
    "macos": {
        "what": "macOS desktop Flutter/Xcode project — builds Counter `.app` on Apple Silicon/Intel Mac.",
        "why": "Apple desktop builds need Xcode target, entitlements, and Flutter macOS embedder.",
        "inside": "`Runner/`, `Flutter/` generated configs, `Runner.xcodeproj`.",
        "affects": "macOS desktop distribution only.",
        "when": "macOS signing, sandbox entitlements, menu bar, desktop build errors.",
        "delete": "No — if macOS desktop support is kept.",
        "related": "`ios/` (mobile Apple) vs this desktop target.",
    },
    "installer/windows/scripts": {
        "what": "Helper PowerShell scripts bundled into or used by the Windows installer pipeline.",
        "why": "Windows speech and installer prep need small scripts copied beside the setup `.exe`.",
        "inside": "`win_speech_wav.ps1` — WAV capture helper for Windows speech path.",
        "affects": "Installed Windows app speech helper behavior post-install.",
        "when": "Installer missing speech helper script, Windows voice WAV path broken.",
        "delete": "No — Windows installer packaging expects these scripts.",
        "related": "`installer/windows/prepare_stt_payload.ps1`, `counter.iss`.",
    },
    "installer/windows/stt_helper_build": {
        "what": "Built speech-to-text helper binary folder — `counter_stt_helper.exe` copied into installer.",
        "why": "Desktop voice on Windows uses a GOLOS STT helper subprocess; installer must ship the compiled exe.",
        "inside": "Pre-built or CI-built `counter_stt_helper.exe` (tracked artifact for packaging).",
        "affects": "Windows desktop voice transcription after install.",
        "when": "Voice works in dev but not in installed app; rebuild STT helper for installer.",
        "delete": "No — Windows installer STT bundle incomplete without it.",
        "related": "`installer/windows/build_stt_helper_en.ps1`, `lib/shared/voice/platforms/desktop/desktop_stt_helper_service.dart`.",
    },
    "installer/windows/stt_helper_src": {
        "what": "Source and build inputs for the Windows STT helper (`counter_stt_helper`) shipped with the installer.",
        "why": "Desktop voice needs a native helper binary; this tree holds the code rebuilt into `stt_helper_build/`.",
        "inside": "STT helper source, build scripts, and model wiring used by `build_stt_helper_en.ps1`.",
        "affects": "Quality of installed Windows desktop voice transcription.",
        "when": "Changing whisper/GOLOS helper behavior or rebuilding the helper for packaging.",
        "delete": "No — cannot rebuild the Windows STT helper without it.",
        "related": "`installer/windows/stt_helper_build/`, `lib/shared/voice/platforms/desktop/desktop_stt_helper_service.dart`.",
    },
    "installer/windows/wav_stt_replay": {
        "what": "Windows WAV replay tooling for offline STT quality checks against real capture fixtures.",
        "why": "Desktop voice regressions are validated by replaying known WAVs through the STT helper.",
        "inside": "Replay scripts and helpers used with `test/fixtures/desktop_voice_wav/`.",
        "affects": "Desktop voice STT QA and benchmark workflows — not end-user screens.",
        "when": "Comparing STT transcripts, latency benchmarks, or quiet-whisper regressions.",
        "delete": "No — required for documented Windows STT replay/benchmark scripts.",
        "related": "`test/fixtures/desktop_voice_wav/`, `scripts/manual/benchmark_desktop_voice_stt.ps1`.",
    },
    "test/fixtures": {
        "what": "Shared Flutter test fixtures — WAV captures, golden manifests, and static inputs for regression tests.",
        "why": "Desktop voice and other suites need stable binary/JSON fixtures instead of live mic recording in CI.",
        "inside": "`desktop_voice_wav/` and other fixture assets referenced by `flutter test`.",
        "affects": "CI/test quality only — not shipped in user APK/web builds.",
        "when": "Voice STT golden failures, missing WAV fixtures, benchmark harness input updates.",
        "delete": "No — tests that depend on these fixtures would fail.",
        "related": "`test/desktop_voice_*_test.dart`, `scripts/manual/benchmark_desktop_voice_stt.ps1`.",
    },
    "test/fixtures/desktop_voice_wav": {
        "what": "Desktop voice WAV golden captures and manifests used by STT quality tests.",
        "why": "CI must replay known speech samples instead of live microphone input.",
        "inside": "WAV files, golden_manifest.json, and related capture metadata.",
        "affects": "Desktop voice STT/unit tests and benchmark scripts only.",
        "when": "STT golden mismatch, adding a new quiet/submit WAV fixture.",
        "delete": "No — desktop voice tests depend on these WAVs.",
        "related": "`test/desktop_voice_*_test.dart`, `scripts/manual/benchmark_desktop_voice_stt.ps1`.",
    },
    "test/fixtures/desktop_voice_wav/benchmark_reports": {
        "what": "JSON reports written by desktop voice STT latency/quality benchmark harnesses.",
        "why": "Stores latest P95/stop-to-useful metrics for acceptance without re-running every review.",
        "inside": "`real_helper_latency_latest.json` and related benchmark output files.",
        "affects": "Benchmark review artifacts — not app runtime.",
        "when": "Checking latest real-helper latency numbers after STT changes.",
        "delete": "Maybe — regenerate via benchmark scripts; keep if CI/docs reference latest.json.",
        "related": "`scripts/manual/run_desktop_voice_real_helper_latency_benchmark.ps1`.",
    },
    "installer/windows/wav_stt_replay/src": {
        "what": "Rust/source tree for the Windows `wav_stt_replay` offline STT replay tool.",
        "why": "Builds the replay executable used to score fixture WAVs through the STT helper.",
        "inside": "Source modules compiled into `wav_stt_replay.exe` under target/release.",
        "affects": "Desktop voice replay/compare scripts only.",
        "when": "Changing replay CLI behavior or rebuilding wav_stt_replay.",
        "delete": "No — cannot rebuild the replay tool without this source.",
        "related": "`installer/windows/wav_stt_replay/`, `scripts/manual/compare_desktop_voice_wav_stt.ps1`.",
    },
    "test/notes": {
        "what": "Flutter tests and fixtures for Notes editor/library parity and document serialization.",
        "why": "GLM Notes UI and `NoteDocument` migration must stay covered after editor ports.",
        "inside": "`fixtures/` capture helpers plus Notes-related `*_test.dart` files.",
        "affects": "CI Notes regression gate — not shipped to users.",
        "when": "Notes editor parity failures, document parse regressions, library capture updates.",
        "delete": "No — Notes regression coverage lives here.",
        "related": "`lib/features/notes/`, `lib/data/models/note_document.dart`, `scripts/manual/capture_notes_glm_parity.ps1`.",
    },
    "test/notes/fixtures": {
        "what": "Reusable Notes GLM parity/capture fixtures — production-widget harnesses for visual regression.",
        "why": "Moved out of `lib/features/notes/debug/` so test-only capture code is not treated as production UI.",
        "inside": "`notes_glm_parity_fixture.dart`, `notes_glm_library_parity_fixture.dart`, `notes_production_library_capture.dart`.",
        "affects": "Notes parity widget tests and manual capture entrypoint — not production `lib/`.",
        "when": "Updating Notes GLM capture screenshots or parity harness layout.",
        "delete": "No — Notes visual parity tests import these fixtures.",
        "related": "`scripts/manual/capture_notes_glm_main.dart`, `test/notes_glm_editor_parity_test.dart`.",
    },
    "test/services": {
        "what": "Unit tests for device services — plan alarm schedule and other UI-free service policies.",
        "why": "Notification/alarm scheduling must be verified without launching full Flutter UI.",
        "inside": "`plan_alarm_schedule_test.dart` and related service-focused tests.",
        "affects": "CI service correctness — not shipped to users.",
        "when": "Plan reminder schedule regressions or service policy changes.",
        "delete": "No — service unit coverage lives here.",
        "related": "`lib/services/plan_alarm_schedule.dart`, `lib/data/plans/plan_alarm_helpers.dart`.",
    },
}

BAD_PHRASES = (
    "Project file.",
    "Supporting source or config.",
    "See path prefix for ownership.",
    "Logic file",
    "Core utility",
    "Contains helpers",
    "Brain logic",
    "Feature UI file",
    "Platform file",
    "Symbols: (library)",
    "Symbols: library",
    "Platform or tooling file",
    "Repository file",
    "holding related project files",
    "This file handles:",
    "Splits huge brain logic",
)

# Prefix → folder guide when not in FOLDERS (deepest match wins in infer_folder_guide)
FOLDER_INFERENCE: list[tuple[str, dict[str, str]]] = [
    (
        "android/app/src/main/res/mipmap",
        {
            "what": "Android launcher icon PNGs at different screen densities.",
            "why": "Home screen icon must look sharp on phones and tablets.",
            "inside": "`ic_launcher.png` per density folder (hdpi, xhdpi, …).",
            "affects": "App icon on Android home screen and app drawer.",
            "when": "Wrong or blurry launcher icon on Android.",
            "delete": "No — required for Android build.",
            "related": "`android/app/src/main/AndroidManifest.xml`.",
        },
    ),
    (
        "android/app/src/main/res",
        {
            "what": "Android visual resources — splash background, themes, launcher icons.",
            "why": "Android packages drawables and styles separately from Dart code.",
            "inside": "XML styles, splash drawable, mipmap icons.",
            "affects": "Splash screen and Android-native chrome only.",
            "when": "Splash flash, theme colors on Android launch.",
            "delete": "No — required for Android build.",
            "related": "`android/app/`.",
        },
    ),
    (
        "android/app/src/main/kotlin",
        {
            "what": "Kotlin entry point where Flutter attaches to Android.",
            "why": "Android OS launches `MainActivity` which boots the Flutter engine.",
            "inside": "`MainActivity.kt` — minimal Flutter embedding.",
            "affects": "Android app startup only.",
            "when": "Android crash on launch, deep link handling at native layer.",
            "delete": "No — required for Android build.",
            "related": "`AndroidManifest.xml`.",
        },
    ),
    (
        "android/app/src",
        {
            "what": "Android app module source — manifest, resources, Kotlin entry.",
            "why": "Gradle compiles this tree into the installable APK.",
            "inside": "Manifest, res/, kotlin/.",
            "affects": "Android APK contents and permissions.",
            "when": "Permission denied, wrong app label, manifest merge errors.",
            "delete": "No — required for Android build.",
            "related": "`android/app/build.gradle`.",
        },
    ),
    (
        "android/app",
        {
            "what": "Android application module — the actual Counter APK target.",
            "why": "Separates app config from root Gradle project settings.",
            "inside": "build.gradle, src/, google-services if present.",
            "affects": "Android build output APK/AAB.",
            "when": "Gradle app module errors, package name, signing.",
            "delete": "No — required for Android build.",
            "related": "`android/` root Gradle.",
        },
    ),
    (
        "android/gradle",
        {
            "what": "Gradle wrapper and version catalog for Android builds.",
            "why": "Pins Gradle version so builds are reproducible on CI and your PC.",
            "inside": "Wrapper jar/properties, plugin versions.",
            "affects": "Android build toolchain only.",
            "when": "Gradle version mismatch errors.",
            "delete": "No — required for Android build.",
            "related": "`android/settings.gradle`.",
        },
    ),
    (
        "ios/Runner",
        {
            "what": "iOS app target — icons, storyboards, Info.plist for iPhone/iPad.",
            "why": "Xcode builds the Flutter iOS app from this target.",
            "inside": "Assets, launch screen, native Swift/ObjC glue.",
            "affects": "iOS App Store / TestFlight builds.",
            "when": "iOS permissions, icons, launch screen.",
            "delete": "No — required for iOS build.",
            "related": "`ios/Flutter/`.",
        },
    ),
    (
        "ios/Flutter",
        {
            "what": "Generated Flutter iOS embedding files.",
            "why": "Flutter tool writes pod helpers and xcconfig here on build.",
            "inside": "Generated xcconfig, pod setup.",
            "affects": "iOS Flutter integration.",
            "when": "Pod install / Flutter iOS build failures.",
            "delete": "No — required for iOS build.",
            "related": "`ios/Podfile`.",
        },
    ),
    (
        "web/icons",
        {
            "what": "PWA / browser tab icons for the web version.",
            "why": "Browser tab and “Add to Home Screen” need sized PNG icons.",
            "inside": "Multiple PNG sizes referenced from manifest.",
            "affects": "Web app icon in browser.",
            "when": "Missing favicon after web deploy.",
            "delete": "No — required for web build.",
            "related": "`web/manifest.json`, `web/index.html`.",
        },
    ),
    (
        "windows/runner",
        {
            "what": "Native Windows host that launches the Flutter desktop window.",
            "why": "Windows needs a C++ runner exe that embeds Flutter engine.",
            "inside": "main.cpp, window creation, plugin registrant.",
            "affects": "Windows desktop `.exe` and installer contents.",
            "when": "Windows desktop won’t start, window title wrong.",
            "delete": "No — required for Windows desktop build.",
            "related": "`installer/windows/`.",
        },
    ),
    (
        "linux/runner",
        {
            "what": "Native Linux host for Flutter desktop on Linux.",
            "why": "Linux desktop build needs GTK runner entry point.",
            "inside": "CMake runner sources.",
            "affects": "Linux desktop builds only.",
            "when": "Linux desktop compile errors.",
            "delete": "No — if Linux desktop support is kept.",
            "related": "`linux/CMakeLists.txt`.",
        },
    ),
    (
        "macos/Runner",
        {
            "what": "macOS app bundle target — menus, icons, entitlements.",
            "why": "Apple requires Xcode target for macOS Flutter apps.",
            "inside": "Swift runner, assets, entitlements plist.",
            "affects": "macOS desktop builds.",
            "when": "macOS signing, sandbox, menu bar.",
            "delete": "No — if macOS builds are kept.",
            "related": "`macos/Flutter/`.",
        },
    ),
    (
        "macos/Flutter",
        {
            "what": "Generated Flutter macOS embedding configuration.",
            "why": "Flutter writes pod/xcconfig glue for macOS builds.",
            "inside": "Generated configs.",
            "affects": "macOS Flutter integration.",
            "when": "macOS Flutter build failures.",
            "delete": "No — required for macOS build.",
            "related": "`macos/Runner/`.",
        },
    ),
    (
        ".cursor",
        {
            "what": "Cursor IDE project rules for AI assistants in this repo.",
            "why": "Ensures Cursor agents follow Flutter/PocketBase iron laws.",
            "inside": "`.cursor/rules/flutter_expert.mdc`.",
            "affects": "AI coding sessions in Cursor only — not app runtime.",
            "when": "Cursor agent ignores architecture rules.",
            "delete": "Maybe — safe for app; keep for Cursor workflow.",
            "related": "`.cursorrules` pointer at repo root.",
        },
    ),
    (
        ".github/workflows",
        {
            "what": "GitHub Actions job definitions — web deploy and Windows installer CI.",
            "why": "Automates publishing site and building `CounterSetup.exe` without manual steps.",
            "inside": "`deploy.yml`, `windows-desktop-build.yml`.",
            "affects": "Live GitHub Pages site and release artifacts.",
            "when": "CI deploy failed, installer artifact missing.",
            "delete": "No — required for CI/deploy.",
            "related": "`docs/DEPLOY.md`, `update.ps1`.",
        },
    ),
    (
        "integration_test",
        {
            "what": "On-device integration tests — full app flows on emulator/phone.",
            "why": "Catches issues unit tests miss (navigation, real widgets).",
            "inside": "Dart integration test entry files.",
            "affects": "Quality gate only — not shipped to users.",
            "when": "Adding end-to-end test before release.",
            "delete": "No — required for integration testing.",
            "related": "`test/` unit tests.",
        },
    ),
    (
        "scripts/audit",
        {
            "what": "Architecture guard scripts — verify repo follows structure law.",
            "why": "Prevents forbidden imports and doc drift before merge.",
            "inside": "`architecture_guard.ps1`.",
            "affects": "Developer/CI checks only.",
            "when": "Before merge; after moving files under `lib/`.",
            "delete": "No — required for audit workflow.",
            "related": "`docs/APP_STRUCTURE.md`.",
        },
    ),
    (
        "scripts/manual",
        {
            "what": "Manual maintainer scripts — deploy, structure doc generation, exports.",
            "why": "Repeatable owner/developer tasks without memorizing commands.",
            "inside": "Python/PowerShell/Dart one-offs including this generator.",
            "affects": "Deploy, docs, optional billing export.",
            "when": "Regenerate structure map, run deploy, Price Reporter CSV export.",
            "delete": "No — documented workflows depend on these.",
            "related": "`update.ps1`, `docs/DEPLOY.md`.",
        },
    ),
    (
        "docs/reports",
        {
            "what": "Point-in-time audit and cleanup reports (not governing law).",
            "why": "Records why files were deleted or docs reorganized.",
            "inside": "Structure parity, design inventory, necessity cleanup reports.",
            "affects": "Historical context for owner/AI — not runtime.",
            "when": "Understanding past cleanup decisions.",
            "delete": "No — current reports referenced from CHANGELOG.",
            "related": "`CHANGELOG.md`, governing docs in `docs/`.",
        },
    ),
    (
        "docs/website",
        {
            "what": "Marketing and internal website copy — not loaded by the Flutter app.",
            "why": "Planning public site text separately from app strings.",
            "inside": "Markdown notes for future site pages.",
            "affects": "Website planning only.",
            "when": "Updating public site messaging.",
            "delete": "No — intentionally maintained repo-only copy.",
            "related": "`docs/DEPLOY.md` GitHub Pages.",
        },
    ),
    (
        "lib/l10n/langs",
        {
            "what": "Per-language string maps for UI labels.",
            "why": "Each locale file supplies translated text for dictionary keys.",
            "inside": "en.dart and ru.dart are canonical; others partial.",
            "affects": "All visible UI text when user switches language.",
            "when": "Missing translation key, wrong language string.",
            "delete": "No — required for localization.",
            "related": "`lib/l10n/dictionary.dart`, `scripts/sync_locales.dart`.",
        },
    ),
    (
        "lib/shared/diagnostics",
        {
            "what": "General runtime logs and the shared kill-switch / metrics registry.",
            "why": "Brain, shell, core, and features need one place for release-safe markers and compile-time performance toggles.",
            "inside": "`runtime_log.dart`, `platform_log.dart`, `startup_log.dart`, `performance/`.",
            "affects": "Developer diagnostics and kill switches only.",
            "when": "Tracing startup timing or toggling perf kill switches.",
            "delete": "No — used by Brain, shell, and diagnostic builds.",
            "related": "`lib/shared/diagnostics/performance/`.",
        },
    ),
    (
        "lib/shared/diagnostics/performance",
        {
            "what": "Kill-switch registry and optional rebuild metrics.",
            "why": "Compile-time toggles for date paging, shell stack, and Planning Time View canvas bisect.",
            "inside": "`runtime_flags.dart`, `shell_flags.dart`, `rebuild_metrics.dart`.",
            "affects": "Perf-sensitive paths and diagnostic builds.",
            "when": "Investigating jank or toggling warm-window kill switch.",
            "delete": "No — perf tests and diagnostics reference these flags.",
            "related": "`lib/shared/diagnostics/`, `test/perf_*`.",
        },
    ),
    (
        "lib/shared/voice/diagnostics",
        {
            "what": "Desktop voice pipeline markers — log + step helpers.",
            "why": "Structured logs for desktop voice without spamming release builds.",
            "inside": "`desktop_voice_log.dart`, `desktop_voice_pipeline.dart`.",
            "affects": "Developer diagnostics only.",
            "when": "Tracing desktop voice steps.",
            "delete": "No — used by debug/profile builds.",
            "related": "`lib/core/services/`, `lib/shared/diagnostics/`.",
        },
    ),
    (
        "lib/data/plans/diagnostics",
        {
            "what": "Planning-domain diagnostics inside the Brain (duplicate plan / stream lifecycle markers).",
            "why": "Brain plan helpers emit these logs; must not live under feature UI or create data→features imports.",
            "inside": "`plan_duplicate_log.dart`.",
            "affects": "Plan duplicate / stream diagnostic markers only.",
            "when": "Investigating duplicate plan rows or plan stream spam.",
            "delete": "No — Brain plan helpers emit these markers.",
            "related": "`lib/shared/diagnostics/performance/runtime_flags.dart` for `kPlanStreamLifecycleDiag` only.",
        },
    ),
    (
        "lib/core/services",
        {
            "what": "Desktop window/tray infrastructure (not Voice ownership).",
            "why": "Main window and tray are general desktop shell infra; Voice lives under `lib/shared/voice/`.",
            "inside": "`desktop_tray_service*.dart`, `desktop_main_window.dart`.",
            "affects": "Windows tray icon and main window sizing.",
            "when": "Tray missing, main window hide/show broken.",
            "delete": "No — desktop tray/window infra.",
            "related": "`lib/shared/voice/platforms/desktop/`, `lib/app/shell/`.",
            "what_ru": "Инфраструктура окна и трея на компьютере (не владение голосовым вводом).",
            "why_ru": "Главное окно и трей — общая desktop-оболочка; голосовой ввод живёт в `lib/shared/voice/`.",
            "inside_ru": "`desktop_tray_service*.dart`, `desktop_main_window.dart`.",
            "affects_ru": "Иконка трея Windows и размер главного окна.",
            "when_ru": "Пропал трей, сломаны hide/show главного окна.",
            "delete_ru": "Нет — инфраструктура трея и окна на компьютере.",
            "related_ru": "`lib/shared/voice/platforms/desktop/`, `lib/app/shell/`.",
        },
    ),
    (
        "lib/features/planning/widgets",
        {
            "what": "Smaller Planning tab widgets — filters, bulk bar, empty states, menus.",
            "why": "Split from giant planning page for readability and guard compliance.",
            "inside": "Bulk selection bar, filter controls, quick-add strip, card menus.",
            "affects": "Plans tab list mode UI pieces.",
            "when": "Bulk edit bar, plan card menu, empty state wrong.",
            "delete": "No — Plans tab UI breaks.",
            "related": "`planning_page.dart`.",
        },
    ),
    (
        "lib/features/planning/settings",
        {
            "what": "Planning settings sheets — visible hours, default category/timezone search.",
            "why": "Time View and plan defaults need dedicated settings UI.",
            "inside": "Bounds slider, record→plan link prefs, no-tags chip settings.",
            "affects": "Plans → settings routes and Time View configuration.",
            "when": "Visible hour range, default plan category/timezone search.",
            "delete": "No — plan settings unavailable.",
            "related": "`time_view/time_view_settings_sheet.dart`.",
        },
    ),
    (
        "lib/features/shared/edit_sheet",
        {
            "what": "Helpers inside plan/record edit bottom sheets.",
            "why": "Autosave, time picker, checklist, repeat rules shared between plan and record sheets.",
            "inside": "Omni picker entry, debounced autosave, RRULE helpers, Quill toolbar.",
            "affects": "Any edit sheet save, date/time change, checklist rows.",
            "when": "Edit sheet autosave, date picker, repeat preset wrong.",
            "delete": "No — edit sheets break.",
            "related": "`activity_detail_sheet.dart`.",
        },
    ),
    (
        "lib/features/profile/settings",
        {
            "what": "Profile settings sections — account, notifications, security.",
            "why": "Split settings page into focused sections for More → Settings.",
            "inside": "Logout row, notification permission, password reset, biometric lock.",
            "affects": "Settings routes from shell and profile.",
            "when": "Logout, notification permission, password reset UI.",
            "delete": "No — settings sections missing.",
            "related": "`lib/app/shell/shared/settings_page.dart`.",
        },
    ),
    (
        "lib/core/widgets/plan_card",
        {
            "what": "Compatibility re-exports pointing to `plan_time_task_card/` canonical files.",
            "why": "Older imports used `plan_card/` path during design-system migration.",
            "inside": "Thin export stubs only.",
            "affects": "Legacy import paths still resolving.",
            "when": "Removing migration stubs after all imports updated.",
            "delete": "Maybe — after confirming no imports use `plan_card/` path.",
            "related": "`lib/core/widgets/plan_time_task_card/`.",
        },
    ),
    (
        "wear",
        {
            "what": "Wear OS companion module — watch timer UI.",
            "why": "Android watches run a slim Flutter entry with lite brain load.",
            "inside": "Wear wrapper, timer screen, platform channel.",
            "affects": "Wear OS watch app only.",
            "when": "Watch timer sync or Wear build issues.",
            "delete": "No — if Wear OS support is required.",
            "related": "`lib/features/wear/`, `loadInitialDataWearLite`.",
        },
    ),
    (
        "linux/flutter",
        {
            "what": "Flutter-generated Linux embedder glue — plugin registrant and CMake hooks.",
            "why": "Flutter tool regenerates these when `pubspec.yaml` plugins change.",
            "inside": "`generated_plugin_registrant.*`, `generated_plugins.cmake`, child `CMakeLists.txt`.",
            "affects": "Linux desktop plugin registration at runtime.",
            "when": "Linux build fails after adding/removing Flutter plugin.",
            "delete": "No — regenerated by Flutter; required for Linux build.",
            "related": "`linux/CMakeLists.txt`, `flutter pub get`.",
        },
    ),
    (
        "windows/flutter",
        {
            "what": "Flutter-generated Windows embedder glue — plugin registrant and CMake hooks.",
            "why": "Native Windows plugins (tray, hotkey, voice overlay) register through this generated code.",
            "inside": "`generated_plugin_registrant.*`, `generated_plugins.cmake`.",
            "affects": "Windows desktop plugin registration — desktop voice/tray depend on it.",
            "when": "Windows build fails after plugin change; desktop voice plugin missing.",
            "delete": "No — required for Windows desktop build.",
            "related": "`windows/runner/`, `windows/CMakeLists.txt`.",
        },
    ),
    (
        "ios/Runner.xcodeproj",
        {
            "what": "Xcode project file bundle for the iOS Counter app target.",
            "why": "Xcode opens this project to compile, sign, and archive the iOS IPA.",
            "inside": "`project.pbxproj`, shared schemes, workspace metadata.",
            "affects": "iOS App Store / TestFlight builds only.",
            "when": "Xcode project corruption, scheme changes, iOS signing settings.",
            "delete": "No — required for iOS build.",
            "related": "`ios/Runner/`, `ios/Flutter/`.",
        },
    ),
    (
        "ios/Runner.xcworkspace",
        {
            "what": "Xcode workspace wrapping the iOS Runner project and CocoaPods.",
            "why": "Developers open `.xcworkspace` (not `.xcodeproj` alone) after `pod install`.",
            "inside": "Workspace data linking Runner + Pods.",
            "affects": "Local iOS development and CI iOS builds using CocoaPods.",
            "when": "Xcode says open workspace; Pod integration broken.",
            "delete": "No — required for iOS CocoaPods workflow.",
            "related": "`ios/Podfile`, `ios/Runner.xcodeproj`.",
        },
    ),
    (
        "ios/RunnerTests",
        {
            "what": "Xcode unit test target for iOS Runner smoke tests.",
            "why": "Apple project template includes a test target for native/iOS integration checks.",
            "inside": "`RunnerTests.swift` — minimal XCTest entry.",
            "affects": "iOS test target in Xcode — not the main Flutter `test/` suite.",
            "when": "iOS native test failures in Xcode.",
            "delete": "Maybe — Flutter CI uses `flutter test`; keep for Xcode workflow.",
            "related": "`test/` Flutter tests, `ios/Runner/`.",
        },
    ),
    (
        "macos/Runner.xcodeproj",
        {
            "what": "Xcode project for macOS desktop Counter `.app` target.",
            "why": "macOS desktop builds compile through this Xcode project.",
            "inside": "`project.pbxproj`, shared schemes for macOS Runner.",
            "affects": "macOS desktop distribution builds.",
            "when": "macOS Xcode build/sign errors.",
            "delete": "No — required for macOS desktop build.",
            "related": "`macos/Runner/`, `macos/Flutter/`.",
        },
    ),
    (
        "macos/Runner.xcworkspace",
        {
            "what": "Xcode workspace for macOS Counter desktop app.",
            "why": "Opens Runner + Flutter macOS pods together in Xcode.",
            "inside": "Workspace contents and shared IDE checks.",
            "affects": "macOS desktop development in Xcode.",
            "when": "Workspace won't open; CocoaPods integration on macOS.",
            "delete": "No — required for macOS Xcode workflow.",
            "related": "`macos/Runner.xcodeproj`.",
        },
    ),
    (
        "macos/RunnerTests",
        {
            "what": "Xcode test target for macOS Runner.",
            "why": "Template XCTest target for macOS native smoke checks.",
            "inside": "`RunnerTests.swift`.",
            "affects": "macOS Xcode test runs only.",
            "when": "macOS native unit test failures.",
            "delete": "Maybe — primary QA is `flutter test`.",
            "related": "`macos/Runner/`.",
        },
    ),
    (
        "android/app/src/debug",
        {
            "what": "Android debug build variant manifest overrides.",
            "why": "Debug APK may enable extra logging or different application id suffix.",
            "inside": "Debug `AndroidManifest.xml` merged into debug builds.",
            "affects": "Debug Android installs only — not release APK.",
            "when": "Debug-only permission or manifest merge issue.",
            "delete": "No — required for Android debug builds.",
            "related": "`android/app/src/main/AndroidManifest.xml`.",
        },
    ),
    (
        "android/app/src/profile",
        {
            "what": "Android profile build variant manifest (performance profiling).",
            "why": "Profile mode uses separate manifest merge for Flutter profile builds.",
            "inside": "Profile `AndroidManifest.xml`.",
            "affects": "Profile APK used for performance measurement.",
            "when": "Profile build manifest merge errors.",
            "delete": "No — required for Flutter profile Android builds.",
            "related": "`android/app/src/main/`.",
        },
    ),
]


BANNED_FOLDER_PHRASES: tuple[str, ...] = (
    "Files grouped under",
    "Keeps ",
    "files together so builds and edits stay organized",
    "Whatever features depend on files in",
    "Build, config, or content work scoped to",
    "See individual file sections below",
    "ship or configure part of the repo",
)

BANNED_EN_PHRASES: tuple[str, ...] = BANNED_FOLDER_PHRASES + (
    "service part of repository",
    "supporting repository file",
    "part of this structure branch",
    "this area",
    "this zone",
    "cannot judge only by filename",
    "file belongs to tooling",
    "open this path when problem is in this zone",
    "part of repository tooling or config",
    "Repository support file",
    "kept in `.` for the Life OS repo",
    "Tracked in git because",
    "Serve its role inside",
    "text file `.metadata`",
)

BANNED_RU_PHRASES: tuple[str, ...] = (
    "см. EN",
    "service part",
    "generic",
    "эта зона",
    "эта область",
    "ветка структуры",
    "нельзя оценивать только по названию",
    "служебная часть репозитория",
    "частью области",
    "часть этой ветки структуры",
    "относится к области",
    "открывать этот путь надо не",
    "когда проблема относится именно к этой зоне",
    "В git, потому что нужен для",
    "Роль внутри",
    "Вспомогательный файл репозитория",
    # Meaningless path-based filler (see structure_en_ru_adapt.BANNED_MEANINGLESS_RU_FILLER)
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
) + BANNED_SEMI_RUSSIAN_WRAPPERS + BANNED_ENGLISH_IN_RU + BANNED_GENERIC_RU_WRAPPERS


def synthesize_folder_guide(key: str) -> dict[str, str]:
    """Last-resort folder guide — must never use BANNED_FOLDER_PHRASES."""
    k = key.replace("\\", "/").strip("/")
    parts = k.split("/") if k else []
    top = parts[0] if parts else ""
    leaf = parts[-1] if parts else k
    parent = "/".join(parts[:-1]) if len(parts) > 1 else ""

    if k.endswith(".xcassets") or leaf == "AppIcon.appiconset":
        plat = top if top in ("ios", "macos") else "platform"
        return {
            "what": f"App icon and image asset catalog for {plat} — `{k}`.",
            "why": "Apple builds bundle PNG icons from asset catalogs into the `.app` bundle.",
            "inside": "PNG icons at required sizes, `Contents.json` manifest.",
            "affects": f"{plat} app icon and launch imagery on device/home screen.",
            "when": "Wrong or missing app icon on Apple platform build.",
            "delete": "No — required for Apple platform branding.",
            "related": f"`{top}/Runner/Info.plist` if {top} else parent Runner target.",
        }
    if leaf == "Base.lproj" or leaf.endswith(".storyboard") or k.endswith("Base.lproj"):
        return {
            "what": f"Apple launch/storyboard resources under `{k}`.",
            "why": "iOS/macOS show native launch screen before first Flutter frame.",
            "inside": "Storyboard or xib launch UI files.",
            "affects": "Splash/launch appearance on Apple platforms.",
            "when": "Launch screen flash or wrong orientation on iOS/macOS.",
            "delete": "No — required for Apple runner launch UX.",
            "related": f"`{top}/Runner/` main target.",
        }
    if leaf == "Configs" and "macos/Runner" in k:
        return {
            "what": "macOS Runner build configuration xcconfig files.",
            "why": "Xcode reads Debug/Release xcconfig for bundle id, version, warning flags.",
            "inside": "`AppInfo.xcconfig`, `Debug.xcconfig`, `Release.xcconfig`, `Warnings.xcconfig`.",
            "affects": "macOS app bundle metadata and compile settings.",
            "when": "Wrong macOS app name/version in built `.app`.",
            "delete": "No — required for macOS Xcode build.",
            "related": "`macos/Runner.xcodeproj`.",
        }
    if leaf in ("xcshareddata", "xcschemes") or "xcshareddata" in k:
        return {
            "what": f"Shared Xcode IDE/scheme metadata for `{parent or k}`.",
            "why": "Xcode stores workspace checks and build schemes here for team consistency.",
            "inside": "Plist scheme files, IDE workspace checks.",
            "affects": "Which Xcode scheme builds Runner — developer workflow only.",
            "when": "Xcode scheme missing or workspace check warnings.",
            "delete": "No — part of Xcode project structure.",
            "related": f"`{parent}` Xcode project.",
        }
    if leaf == "resources" and "windows/runner" in k:
        return {
            "what": "Windows runner embedded resources — app icon for the `.exe`.",
            "why": "Windows executable shows icon from `.ico` resource compiled into runner.",
            "inside": "`app_icon.ico` and related RC resources.",
            "affects": "Counter `.exe` icon on Windows taskbar and desktop shortcut.",
            "when": "Wrong Windows app icon after desktop build.",
            "delete": "No — required for Windows desktop branding.",
            "related": "`windows/runner/Runner.rc`.",
        }
    if top == "android" and "kotlin" in k:
        pkg = k.split("kotlin/")[-1] if "kotlin/" in k else k
        return {
            "what": f"Kotlin/Java package `{pkg}` — путь к Flutter Activity на Android.",
            "why": "Структура папок повторяет Java package name для Gradle.",
            "inside": "Папки package, ведущие к `MainActivity.kt`.",
            "affects": "Только расположение entry class Android.",
            "when": "Переименование package или перенос Activity.",
            "delete": "Нет — нужен пока MainActivity в этом package.",
            "related": "`android/app/src/main/kotlin/.../MainActivity.kt`.",
        }
    if top in ("android", "ios", "web", "windows", "linux", "macos"):
        label = {
            "android": "Android",
            "ios": "iOS",
            "web": "Web",
            "windows": "Windows desktop",
            "linux": "Linux desktop",
            "macos": "macOS desktop",
        }[top]
        return {
            "what": f"{label} platform path `{k}/` — native/build support for Flutter {label} target.",
            "why": f"Flutter {label} builds compile native runner and assets from paths under `{top}/`.",
            "inside": "Native config, generated embedder files, or assets for this path segment.",
            "affects": f"{label} build output only — not Dart UI logic in `lib/`.",
            "when": f"{label} build error referencing `{leaf}` or `{k}`.",
            "delete": f"No — required for {label} build/deploy/platform tooling.",
            "related": f"`{top}/` root platform folder, `docs/APP_STRUCTURE.md` §4.",
        }
    if k.startswith("docs/"):
        topic = leaf.replace("_", " ").replace(".md", "")
        return {
            "what": f"Documentation topic folder `{k}/` — {topic} notes.",
            "why": "Groups related markdown specs so owners find written guidance by topic.",
            "inside": "Markdown files listed in file sections below.",
            "affects": "Development and AI context — not app runtime.",
            "when": f"Reading or editing docs about {topic}.",
            "delete": "No — governing or report documentation.",
            "related": "`docs/PROJECT_KNOWLEDGE_PACK.md`, `CHANGELOG.md`.",
        }
    if k.startswith("scripts/"):
        return {
            "what": f"Automation scripts under `{k}/` — developer/CI maintenance commands.",
            "why": "Repeatable audits, deploy helpers, and doc generation live here instead of ad-hoc notes.",
            "inside": "PowerShell, Python, or Dart scripts (see files below).",
            "affects": "Build, deploy, audit, and doc workflows — not end-user app screens.",
            "when": f"Running documented workflow that uses `{leaf or k}`.",
            "delete": "No — required for documented repo workflows.",
            "related": "`docs/DEPLOY.md`, `docs/APP_STRUCTURE.md` §6.",
        }
    if k.startswith("test/"):
        return {
            "what": f"Flutter test files under `{k}/` — automated regression checks.",
            "why": "Each test file guards a specific behavior (voice, timezone, plan cards, perf).",
            "inside": "Dart `*_test.dart` files run by `flutter test`.",
            "affects": "CI quality gate — not shipped in user APK/web build.",
            "when": "CI failure or changing code covered by tests in this folder.",
            "delete": "No — required for tests.",
            "related": "Matching production files under `lib/`.",
        }
    if k.startswith("lib/"):
        area = "/".join(parts[1:]) if len(parts) > 1 else "lib root"
        return {
            "what": f"Dart source subtree `{k}/` — part of app code for {area}.",
            "why": "Code under `lib/` ships in every platform build; this folder groups related Dart modules.",
            "inside": "Dart modules listed in file entries below.",
            "affects": "App behavior for the feature or layer named in the path.",
            "when": f"Bug or feature work in `{area}`.",
            "delete": "No — required for app runtime unless explicitly deprecated in ROADMAP.",
            "related": "`docs/APP_STRUCTURE.md`, parent `lib/` folders.",
        }
    return {
        "what": f"Repository path `{k}/` — tracked config, assets, or tooling for Life OS.",
        "why": f"Git tracks `{k}` because release, CI, or maintenance workflow depends on these files.",
        "inside": "Tracked files listed below with individual explanations.",
        "affects": "Repo workflow or platform build tied to this path — see child file entries.",
        "when": f"Maintenance or build work involving `{k}`.",
        "delete": "No — part of repository tooling or config unless cleanup report says otherwise.",
        "related": "`docs/APP_STRUCTURE.md`, `CHANGELOG.md`.",
    }


def _folder_ru_auto(key: str, en: dict[str, str]) -> dict[str, str]:
    """Generate Russian folder fields from English guide when no curated RU exists."""
    k = key.replace("\\", "/").strip("/")
    top = k.split("/")[0] if k else ""
    plat_ru = {
        "android": "Android",
        "ios": "iOS",
        "web": "Web",
        "windows": "Windows",
        "linux": "Linux",
        "macos": "macOS",
    }.get(top, "")
    if plat_ru:
        return {
            "what_ru": f"Платформенная папка {plat_ru}: `{k}/` — native-обёртка и конфиги Flutter для этой платформы.",
            "why_ru": f"Flutter собирает {plat_ru}-версию из файлов под `{top}/`; это не Dart-код экранов.",
            "inside_ru": f"Native-конфиги и generated-файлы embedder в `{k}/`.",
            "affects_ru": f"Только сборка и native-поведение {plat_ru} — не экраны в `lib/`.",
            "when_ru": f"Ошибка сборки {plat_ru} или native-проблема в `{k}/`.",
            "delete_ru": "Нет — нужна для сборки платформы.",
            "related_ru": f"`{top}/`, `docs/APP_STRUCTURE.md`.",
        }
    if k.startswith("lib/"):
        sub = k[4:] if k.startswith("lib/") else k
        return {
            "what_ru": f"Dart-модули `{k}/` — UI, Brain или shared код Counter.",
            "why_ru": "Всё под `lib/` попадает в APK/web/desktop build и задаёт поведение продукта.",
            "inside_ru": f"Файлы и подпапки `{k}/` — список ниже.",
            "affects_ru": f"Экраны и data-flow, связанные с `{sub}`.",
            "when_ru": f"Правки или баги в `{sub}`.",
            "delete_ru": "Нет — нужен для работы приложения.",
            "related_ru": "`lib/`, `docs/APP_STRUCTURE.md`.",
        }
    if k.startswith("docs/"):
        return {
            "what_ru": f"Документация в `{k}/` — written specs, не runtime-код.",
            "why_ru": "Текстовые правила и отчёты для owner и AI; приложение их не исполняет.",
            "inside_ru": "Markdown-файлы с правилами и отчётами — список ниже.",
            "affects_ru": "Решения при разработке — не бинарник приложения.",
            "when_ru": "Нужно прочитать или обновить документацию по теме папки.",
            "delete_ru": "Нет — governing или report документация.",
            "related_ru": "`docs/PROJECT_KNOWLEDGE_PACK.md`.",
        }
    if k.startswith("scripts/") or k.startswith("test/"):
        kind = "скрипты" if k.startswith("scripts") else "автотесты"
        return {
            "what_ru": f"Папка {kind}: `{k}/`.",
            "why_ru": "Поддержка CI, deploy, audit или регрессионных проверок.",
            "inside_ru": "Файлы перечислены ниже по одному.",
            "affects_ru": "Качество и workflow — не экраны приложения.",
            "when_ru": "Запуск workflow или падение CI.",
            "delete_ru": "Нет — задокументированный workflow.",
            "related_ru": "`docs/APP_STRUCTURE.md`.",
        }
    return {
        "what_ru": f"Служебная папка `{k}/` в репозитории Counter.",
        "why_ru": "Поддерживает сборку, CI или сопровождение проекта.",
        "inside_ru": "Файлы этой папки перечислены ниже.",
        "affects_ru": "Workflow или tooling, связанный с этим путём.",
        "when_ru": f"Сборка или maintenance затрагивает `{k}/`.",
        "delete_ru": "Нет — часть репозитория.",
        "related_ru": "`docs/APP_STRUCTURE.md`.",
    }


def ensure_folder_ru(key: str, data: dict[str, str]) -> dict[str, str]:
    """Merge curated + inline RU; fill gaps by adapting EN meaning (never path templates)."""
    from structure_en_ru_adapt import EXACT_FOLDER_RU

    k = key.replace("\\", "/").strip("/")
    merged = dict(data)
    if k in EXACT_FOLDER_RU:
        for fk, fv in EXACT_FOLDER_RU[k].items():
            if fv and not has_banned_filler(fv):
                merged[fk] = fv
    for suffix in (
        "what_ru",
        "why_ru",
        "inside_ru",
        "affects_ru",
        "when_ru",
        "delete_ru",
        "related_ru",
    ):
        inline = data.get(suffix, "")
        if inline and not has_banned_filler(inline) and not inline.startswith("NEEDS HUMAN"):
            merged[suffix] = inline
    adapted = adapt_folder_guide_ru(k, merged)
    for fk, fv in adapted.items():
        cur = merged.get(fk, "")
        if fv and not fv.startswith("NEEDS HUMAN") and (
            not cur or has_banned_filler(cur) or cur.startswith("NEEDS HUMAN")
        ):
            merged[fk] = fv
        elif (not cur or cur.startswith("NEEDS HUMAN")) and not fv:
            en_key = fk.replace("_ru", "")
            en_val = data.get(en_key, merged.get(en_key, ""))
            if en_val and fk != "related_ru":
                from structure_en_ru_adapt import _phrase_translate
                from structure_ru_class_adapters import sanitize_ru_prose

                tr = sanitize_ru_prose(_phrase_translate(en_val))
                if tr and not has_banned_filler(tr):
                    merged[fk] = tr
    for suffix in (
        "what_ru",
        "why_ru",
        "inside_ru",
        "affects_ru",
        "when_ru",
        "delete_ru",
        "related_ru",
    ):
        if merged.get(suffix):
            continue
        en_key = suffix.replace("_ru", "")
        en_val = merged.get(en_key, data.get(en_key, ""))
        if not en_val:
            continue
        if suffix == "delete_ru":
            from structure_ru_helpers import delete_en_to_ru

            merged[suffix] = delete_en_to_ru(en_val)
        elif suffix == "related_ru":
            merged[suffix] = en_val
        else:
            from structure_en_ru_adapt import _phrase_translate
            from structure_ru_class_adapters import sanitize_ru_prose

            tr = sanitize_ru_prose(_phrase_translate(en_val))
            if tr and not has_banned_filler(tr):
                merged[suffix] = tr
    for suffix in (
        "what_ru",
        "why_ru",
        "inside_ru",
        "affects_ru",
        "when_ru",
        "delete_ru",
        "related_ru",
    ):
        if suffix not in merged:
            merged[suffix] = ""
    en_delete = merged.get("delete", data.get("delete", ""))
    if en_delete:
        from structure_ru_helpers import delete_en_to_ru

        merged["delete_ru"] = delete_en_to_ru(en_delete)
    return merged


def infer_folder_guide(key: str) -> dict[str, str]:
    """Return folder guide dict for path prefix; always returns specific text."""
    k = key.replace("\\", "/").strip("/")
    best: dict[str, str] | None = None
    best_len = -1
    for prefix, data in FOLDER_INFERENCE:
        if k == prefix or k.startswith(prefix + "/"):
            if len(prefix) > best_len:
                best = data
                best_len = len(prefix)
    if best:
        return ensure_folder_ru(k, best)
    if k in FOLDERS:
        return ensure_folder_ru(k, FOLDERS[k])
    return ensure_folder_ru(k, synthesize_folder_guide(k))


def platform_file_description(path: str) -> dict[str, str] | None:
    """Return {what, why, contains, responsibilities} for platform/config files."""
    p = path.replace("\\", "/")
    name = Path(p).name
    lower = name.lower()
    parent = PurePosixPath(p).parent.as_posix()
    ext = Path(p).suffix.lower()

    if lower == "androidmanifest.xml":
        variant = "debug/profile" if "debug" in p or "profile" in p else "release/main"
        return {
            "what": f"Android manifest ({variant}) — declares permissions, app label, and Flutter activity.",
            "why": "Android reads XML at install/run to grant mic, notifications, and launch the app.",
            "contains": "`<uses-permission>`, application name, intent filters.",
            "responsibilities": "Gate OS permissions and deep links for this build variant.",
        }
    if lower == "mainactivity.kt":
        return {
            "what": "Kotlin activity that starts the Flutter engine on Android.",
            "why": "Android OS entry point — without it the APK cannot show the Flutter UI.",
            "contains": "Minimal `FlutterActivity` subclass.",
            "responsibilities": "Boot Flutter when user taps the app icon.",
        }
    if lower == "ic_launcher.png":
        density = parent.split("-")[-1] if "mipmap" in parent else "default"
        return {
            "what": f"Launcher icon PNG for Android density `{density}`.",
            "why": "Home screen icon must match pixel density of the device screen.",
            "contains": "Raster PNG icon asset.",
            "responsibilities": f"Display sharp icon on {density} devices.",
        }
    if lower == "launch_background.xml":
        return {
            "what": "Drawable behind Flutter splash while engine loads on Android.",
            "why": "Avoids white flash before first Flutter frame.",
            "contains": "Layer-list XML referencing background color/image.",
            "responsibilities": "Splash appearance on cold start.",
        }
    if lower == "styles.xml":
        theme = "night" if "night" in parent else "default"
        return {
            "what": f"Android `{theme}` theme styles for launch window and normal UI chrome.",
            "why": "Native Android window uses XML themes before Flutter draws.",
            "contains": "Theme items for LaunchTheme and NormalTheme.",
            "responsibilities": "Status bar and splash styling on Android.",
        }
    if lower == "google-services.json":
        return {
            "what": "Firebase/Google services config placeholder for Android Gradle plugin.",
            "why": "Some Gradle setups expect this file even if Firebase features are unused.",
            "contains": "JSON project ids (no secrets in repo copy).",
            "responsibilities": "Satisfy Android Gradle google-services plugin if enabled.",
        }
    if lower == "proguard-rules.pro":
        return {
            "what": "ProGuard keep rules for Android release minification.",
            "why": "R8/ProGuard must not strip Flutter/plugin classes needed at runtime.",
            "contains": "Keep rules for Flutter embedding.",
            "responsibilities": "Prevent release APK crashes from over-shrinking.",
        }
    if lower == "generatedpluginregistrant.java":
        return {
            "what": "Auto-generated list of Flutter plugins registered on Android.",
            "why": "Flutter tool regenerates this when plugins change in `pubspec.yaml`.",
            "contains": "Java registrant calling each plugin's register method.",
            "responsibilities": "Wire native plugins into Android engine.",
        }
    if lower == "gradle.properties" or lower == "local.properties":
        return {
            "what": f"Gradle `{name}` — JVM/ AndroidX flags or local SDK path.",
            "why": "Gradle reads properties to locate Android SDK and tune build.",
            "contains": "Key=value lines (local SDK path often gitignored).",
            "responsibilities": "Configure Gradle daemon and SDK location.",
        }
    if lower == "settings.gradle" or lower == "settings.gradle.kts":
        return {
            "what": "Gradle settings — declares included modules (`:app`).",
            "why": "Root Gradle project must list app module to compile APK.",
            "contains": "Module includes, plugin management.",
            "responsibilities": "Wire Gradle multi-module Android project.",
        }
    if lower == "gradle-wrapper.properties":
        return {
            "what": "Gradle Wrapper properties — pins Gradle distribution URL and version for Android builds.",
            "why": "CI and local machines must run the same Gradle version when building APK/AAB.",
            "contains": "`distributionUrl`, `distributionSha256Sum` for the wrapper.",
            "responsibilities": "Pin Gradle distribution for the entire `android/` tree.",
        }
    if lower == "main.cpp" and p.startswith("windows/runner"):
        return {
            "what": "Native C++ entry point for the Windows desktop app — creates Win32 window and boots Flutter.",
            "why": "The Windows `.exe` starts here; without it Flutter desktop cannot show Counter UI.",
            "contains": "`wWinMain`/`main`, window creation, `flutter::FlutterViewController` bootstrap.",
            "responsibilities": "Cold-start Windows runner — Win32 host + Flutter engine.",
        }
    if lower == "project.pbxproj":
        plat = "iOS" if p.startswith("ios/") else "macOS"
        artifact = "IPA" if p.startswith("ios/") else "`.app` bundle"
        return {
            "what": f"Xcode project database for {plat} Runner — targets, build phases, signing, resources.",
            "why": f"Xcode opens and builds {artifact} through this `project.pbxproj`.",
            "contains": "PBX targets, file references, build settings, code signing configuration.",
            "responsibilities": f"Describe {plat} Runner target and build pipeline for {artifact}.",
        }
    if lower.endswith(".xcconfig") and "/flutter/" in p.lower():
        variant = "Debug" if "debug" in lower else "Release"
        plat = p.split("/")[0]
        return {
            "what": f"Flutter {plat} `{variant}.xcconfig` — passes Flutter/CocoaPods settings into Xcode build.",
            "why": f"Xcode reads xcconfig when compiling Runner {variant}; Flutter flags must flow into native build.",
            "contains": f"#include generated Flutter settings and {variant} compiler flags.",
            "responsibilities": f"Wire Flutter engine paths and flags into {plat} {variant} compile.",
        }
    if lower == "app_icon.ico":
        return {
            "what": "Windows runner ICO icon embedded in `.exe` and installer.",
            "why": "Win32 resource compiler and Inno Setup use this for taskbar/Explorer/Start menu branding.",
            "contains": "Multi-size ICO raster for Windows shell icons.",
            "responsibilities": "Counter icon in taskbar, Explorer, Start menu, and setup wizard.",
        }
    if lower == "prepare_stt_payload.ps1":
        return {
            "what": "PowerShell script preparing STT payload before Windows installer build.",
            "why": "Inno Setup expects helper exe, models, and runtime files copied into installer layout.",
            "contains": "Steps copying/checking `counter_stt_helper.exe` and STT runtime payload.",
            "responsibilities": "Prepare STT bundle for `counter.iss` before building setup.",
        }
    if lower == "build_stt_helper_en.ps1":
        return {
            "what": "PowerShell build script for English STT helper shipped in Windows installer.",
            "why": "Desktop voice needs `counter_stt_helper.exe` in the setup package after install.",
            "contains": "Commands building/copying STT helper into `stt_helper_build/`.",
            "responsibilities": "Produce/update STT helper binary for installer payload.",
        }
    if lower == "counter_stt_helper.exe":
        return {
            "what": "Built STT helper binary bundled beside the installed Windows app.",
            "why": "Desktop voice invokes this subprocess for transcription after setup install.",
            "contains": "Compiled GOLOS STT helper executable (English).",
            "responsibilities": "Speech transcription subprocess for installed desktop voice.",
        }
    if lower == "cmakelists.txt":
        plat = p.split("/")[0]
        return {
            "what": f"CMake build script for `{parent}` — builds the Flutter `{plat}` native runner.",
            "why": f"Native {plat} desktop compile links Flutter engine via this CMake file in `{parent}`.",
            "contains": "CMake targets, source file list, Flutter embedder link rules.",
            "responsibilities": f"Produce native binary pieces for `{parent}` embedder.",
        }
    if lower == "info.plist":
        return {
            "what": "iOS/macOS bundle Info.plist — permissions, bundle id, display name.",
            "why": "Apple OS reads plist for app metadata and permission prompts.",
            "contains": "CFBundle keys, usage descriptions (mic, etc.).",
            "responsibilities": "App identity and iOS permission strings.",
        }
    if lower == "podfile":
        return {
            "what": "CocoaPods recipe for iOS/macOS Flutter plugins.",
            "why": "Native iOS plugins install via CocoaPods during `pod install`.",
            "contains": "Platform version, Flutter pod helper hook.",
            "responsibilities": "Resolve iOS native dependencies for plugins.",
        }
    if lower == "manifest.json" and parent.startswith("web"):
        return {
            "what": "Web app manifest — name, theme color, icon paths for PWA.",
            "why": "Browsers use manifest for install prompt and tab theming.",
            "contains": "JSON with icons array and display mode.",
            "responsibilities": "PWA metadata for GitHub Pages site.",
        }
    if lower == "favicon.png":
        return {
            "what": "Small browser tab icon for the web build.",
            "why": "Shown in browser tab and bookmarks for `/Counter/` site.",
            "contains": "PNG favicon asset.",
            "responsibilities": "Web branding in browser chrome.",
        }
    if ext == ".png" and "web/icons" in p:
        size = name.replace("Icon-", "").replace(".png", "")
        return {
            "what": f"Web/PWA icon ({size}px) for add-to-home-screen.",
            "why": "Browsers pick closest icon size for install banner.",
            "contains": "PNG at fixed square size.",
            "responsibilities": f"Icon at {size}px for PWA.",
        }
    if lower == "copilot-instructions.md":
        return {
            "what": "GitHub Copilot guidance — points to governing docs and iron laws.",
            "why": "Copilot reads this file for repo-specific coding rules.",
            "contains": "Short priority doc list and architecture reminders.",
            "responsibilities": "Steer Copilot away from forbidden patterns.",
        }
    if lower.endswith(".yml") and ".github/workflows" in p:
        job = "web deploy" if "deploy" in lower else "Windows installer build"
        return {
            "what": f"GitHub Actions workflow YAML for {job}.",
            "why": "CI runs these steps on push or manual dispatch.",
            "contains": "Jobs, checkout, flutter build, artifact upload.",
            "responsibilities": f"Automate {job} per `docs/DEPLOY.md`.",
        }
    if lower == ".gitignore":
        scope = parent if parent != "." else "repository root"
        return {
            "what": f"Git ignore rules for `{scope}` — files not to commit.",
            "why": "Prevents build output and secrets from entering git history.",
            "contains": "Ignore patterns for this folder scope.",
            "responsibilities": "Prevent accidental commit of generated files.",
        }
    if lower == "analysis_options.yaml":
        return {
            "what": "Dart analyzer lint rules for the whole project.",
            "why": "`flutter analyze` uses this to flag style and error patterns.",
            "contains": "include: flutter_lints, rule toggles.",
            "responsibilities": "Static analysis policy for CI and IDE.",
        }
    if lower == ".metadata":
        return {
            "what": "Flutter tool metadata — tracks project type and revision.",
            "why": "Flutter CLI uses this to know which platforms are enabled.",
            "contains": "YAML with project revision and channel.",
            "responsibilities": "Flutter tooling identity — do not hand-edit casually.",
        }
    if lower == "readme.md" and parent == ".":
        return {
            "what": "Repository front page — quick intro and links for humans on GitHub.",
            "why": "First document visitors see; not part of Project Knowledge pack law.",
            "contains": "Project summary, build hints.",
            "responsibilities": "Orient new contributors — not runtime config.",
        }
    if lower == "flutter_expert.mdc":
        return {
            "what": "Authoritative Cursor AI rules — architecture iron laws for this repo.",
            "why": "Cursor agents must follow PocketBase, optimistic UI, and structure rules.",
            "contains": "Long-form expert rules referenced from `.cursorrules`.",
            "responsibilities": "Bind AI edits to governing architecture.",
        }
    if lower == "env.dart.example":
        return {
            "what": "Template for compile-time secrets — copy to `env.dart` (gitignored).",
            "why": "Developers need local env constants without committing secrets.",
            "contains": "Example keys with placeholder values.",
            "responsibilities": "Document required env.dart shape.",
        }
    if "help how to update the languages" in lower:
        return {
            "what": "Owner note — how to add translation keys and run locale sync.",
            "why": "Prevents editing non-canonical locale files incorrectly.",
            "contains": "Step list for en/ru SSOT then `sync_locales.dart`.",
            "responsibilities": "Human procedure for l10n updates.",
        }
    return None
