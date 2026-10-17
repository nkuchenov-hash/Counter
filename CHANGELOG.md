## 2026-10-17 — Viktor AI in-app chat [DRAFT; not deployed]

- Added a full-screen text/voice Viktor with session-only user provider key, OpenAI/Groq/Gemini/OpenRouter allowlist and guarded PocketBase proposal hook. Hosted mode disabled until metered paid accounts exist.
- Retired the old floating voice FAB and rewired header, More, Profile, Planning Smart and desktop tray/hotkey entry points to Viktor.
- Added vetted action proposals, ordering-first day schedule preview, fixed/recurring time guards, change confirmation, actual Brain writes with stale-preview check, unit and responsive widget tests.
- Still **not production ready**: detailed structure generator/CI, authenticated backend E2E, provider credentials, billing, transactional multi-write/undo and physical cleanup of all legacy voice modules require validation.

## 2026-10-17 — Calendar Week shares the Time View drag engine [fix]

- Replaced Calendar Week's independent Flutter Draggable implementation with the canonical TimelinePlanInteractionBlock pointer/hold gesture, including drag preview and automatic scroll/page gesture lock.
- Reused the existing Time View insertion cascade for drop-before/drop-after and 5-minute snapped empty slots, with fixed-time barriers, group offsets and canonical optimistic Brain persistence.
- Removed Calendar-only PocketBase ID eligibility rejection and added a pointer drag regression test covering gesture start/end and tap preservation.

## 2026-10-17 — Calendar adjacent dates, visible time and drag/drop [fix]

- Render dates and scheduled plan indicators for the preceding/following months in muted grey; keep them interactive.
- Preserve visible start times on compact Week cards and category groups. Month existing-plan taps open editing, empty cells create new plans.
- Add hold-to-drag of individual plans and grouped blocks to Week slots or Month dates, with duration/gap preservation and a fixed-time-aware, conflict-cascading backend update path.
- Add Calendar drag/reschedule regression tests and document the interaction contract.

## 2026-10-16 — Calendar click-to-create and week category groups [fix]

- Calendar date-cell and empty week time-slot taps now open a new plan draft with the clicked date/time, without changing the global header or Timeline/Plans day.
- Week-grid dense tasks form visual-only contiguous parent-category blocks with collision-safe lanes, hover summaries, and a tap-to-expand sheet with canonical interactive plan cards; independent PocketBase plans are unchanged.
- Added grouping/lane tests and updated the Calendar UX and structure contracts.

## 2026-10-16 — Bulk edit date/time sequential reschedule [fix]

- Fixed multi-select rescheduling: a picked 09:00 is the start of the selected block, not the start of every plan.
- Placed selected plans end-to-start in their visible order, preserving durations and writing the final actual start/end to PocketBase.
- Shift only conflicting destination-day plans to prevent new overlaps; abort rather than moving a nonpatchable virtual or optimistic target plan.
- Date-only bulk moves retain individual clock times. Added tests for Thursday-to-Monday rollover, gaps, fallback durations and collisions.

## 2026-10-16 — P0 resilient Timeline capture and idempotent retry [fix]

- Moved browser record-mutation outbox from quota-constrained SharedPreferences/localStorage to IndexedDB transactions. Existing queued records migrate before the old journal key is released.
- Timeline input drafts also persist in IndexedDB, with one-time legacy draft recovery.
- Retry preserves one stable business UUID and original start instant; duplicate capture queue rows and stale-title retries are prevented.
- The previous running timer is no longer stopped before the next recording has passed local durable staging.
- Added real Chrome IndexedDB regression coverage in CI. Keep server/network status separate from confirmed local acceptance.

## 2026-10-16 — P0 record capture without category-related data loss [fix]

- Removed the pre-outbox rejection when the category catalog has not hydrated; create requests now retain the selected local category ID and wait for valid PocketBase relations before replay.
- Added persistent Timeline quick-entry draft recovery, explicit submit journaling and serialized draft writes before clearing accepted input.
- Corrupt record mutation outboxes are no longer silently decoded as empty and overwritten. Added durability, unresolved-category and draft recovery regression contracts.
- User input remains recoverable during authentication or local persistence failures. Server-side receipt is still required before calling a pending record synchronized.

## 2026-10-16 — Seamless Notes toolbar bottom fade [ui/fix]

- Removed the opaque black-tinted blurred backplate behind the canonical floating Notes toolbar. The blur now feathers progressively into the editor at its bottom edge, with no rectangular boundary.
- Kept the toolbar outside the filtered layer and interactive, preserving Notes block tools on mobile, desktop and in embedded Planning edit sheets.
- Added the canonical fade regression to Android release CI. No data or sync schema changes.

## 2026-10-15 — Planning edit-sheet canonical three-tab layout [ui/fix]

- Restored Notes as the first dated-plan tab alongside Repeat and Parallel plans, using the existing block editor and floating formatting toolbar (no substitute rich-text UI).
- Placed start/end time and category tags immediately after the category picker, above the tabs. Fixed the action footer beneath the active content instead of splitting the modal into conflicting vertical sections.
- Replaced the old desktop 5:1 Notes/schedule allocation with a single tab-content viewport; covered ordering, responsive desktop/phone geometry, and tab switching in Flutter widget tests.

## 2026-10-15 — Auto-scheduled plan workday rollover [fix]

- Auto plan creation now checks that the full duration fits the visible/category working window; if full, it searches up to 14 days ahead rather than writing an invisible beyond-hours interval.
- Planning quick add, Smart Plan, voice-plan and direct dated add update the actual destination date, initial commitment day and postponed flag together. Manual explicit times are preserved.
- Shows scheduled destination or a clear no-slot warning and adds targeted overflow regression tests.
- PocketBase schema unchanged. Existing historically misplaced plans are not automatically mutated; CI and production verification required before merging.

## 2026-10-15 — Planning dated edit-sheet layout recovery [fix]

- Corrected desktop dated-plan edit-sheet pane allocation: Notes no longer takes five shares of the sheet while time, tags and recurrence are forced into one. The Notes pane now takes one share and schedule controls three, with existing mobile keyboard handling unchanged.
- Added a widget regression test to keep the schedule panel larger than the rich-text editor, plus CI coverage.

## 2026-10-15 — Record create write-ahead and rapid-input reliability [fix]

- Removed global previous-write gating from record creation so deliberately consecutive starts are not silently rejected during slow PocketBase requests.
- Primary/child/completed record creates now stage durable UUID-keyed outbox operations before any network POST; child stop+create handoff is staged as one FIFO batch.
- Serialized record outbox mutations and switched flush to per-operation acknowledgement; stale update acknowledgements no longer erase later edits or new creates.
- Added server UUID lookup before create retries to avoid duplicate records after a lost response, and rehydrated queued local create shadows on full refresh/restart.
- Preserved the quick-entry text until the local write is durably staged; genuinely failed record writes now display a specific localized error instead of a generic try-again toast.
- Added focused record write durability regression tests. Live PocketBase and cross-platform verification remain required before release.

## 2026-09-30 — Planning Time View date-swipe frame pacing [fix]
- Adjacent Time View dates now render frozen snapshot content ahead of the horizontal swipe instead of staying blank until page activation.
- Live Planning resources and shell date commits now switch only after the horizontal pager settles, removing recurrence/timezone/layout activation work from the swipe threshold without restoring the old multi-day mounted strip.
- Nested vertical Time View scroll notifications no longer drive the horizontal date-pager settle gate.

## 2026-09-29 — Planner no-hidden-cascade recovery [fix]
- Planning Time View: fixed stale UTC instants overriding manual/recurring wall-time moves, so dragged recurring plans and collision-resolved creates no longer snap back to their old time.
- Recurrence: single-occurrence edits of materialized recurring plans now await the PocketBase patch before optimistic state is released.

- New plans use an existing fitting gap or append after the last plan; creation never shifts existing plans to make room.
- Time View rendering no longer performs hidden post-frame schedule mutations.
- Recurring Time View drag/drop now resolves target insertion before applying occurrence/future recurrence scope.

## 2026-09-29 — Recurring edit scope only on Save [fix]

- Recurring plan edits now stay as local in-sheet drafts while typing/changing fields; autosave no longer opens the occurrence-scope dialog.
- The occurrence/future-series choice is requested only after explicit Save, with a regression contract test covering the trigger boundary.

## 2026-09-23 — Record midnight interval guard [fix]

- Prevented stopped-record autosave from writing temporary invalid start/end picker states across midnight or date edits.
- Added Brain-side guards so record time mutations with `end_time <= start_time` are rejected before optimistic cache or PocketBase writes.
- Timeline no longer prints negative durations for legacy invalid rows; the server interval-order hook remains the final persistence gate.

## 2026-09-23 — Recurring-plan immutable history [fix]

- Replaced recurring edit/delete scope with two user choices: one occurrence or this and all following occurrences; removed user-facing whole-series mutation.
- Implemented future scope as an RRULE series split so earlier recurrence history stays unchanged while future materialized exceptions move with the new future series.
- Fixed recurring occurrence editing to inherit the parent recurrence rule and aligned the recurrence scope dialog to one left edge.
- Added canonical `docs/FUNCTIONS.md` and `docs/USER_GUIDE.md` recurrence documentation.

## 2026-09-11 — Duration-responsive PlanCard redesign [ui]

- Reworked canonical Time View `PlanTimeTaskCard` layouts to match the approved duration-responsive card design: 12px checkbox→content spacing, larger title/tag rhythm, 2px progress separator, tighter progress/footer spacing, and bottom-pinned breadcrumbs.
- Every Time View Plan card now renders its category icon as the existing low-opacity category watermark; Play uses a larger 24×26 triangle with 8px rounded corners on a transparent default background while checkbox/Play/Options hover behavior and completed-card strikethrough/state behavior are preserved.
- Component Lab now includes 10/30/45/60/90-minute Time View examples plus a completed-state example.

## 2026-09-11 — Browser extension live current-record refresh [fix]


- Fixed stale active-record state: cached/open-tab snapshots are now render-only and can no longer suppress a canonical Brain/PocketBase refresh.
- Every popup open forces `bridge_sync`; while the popup stays open it refreshes every 15 seconds, with service-worker de-duplication so overlapping refreshes do not create parallel bridge tabs.
- Published browser companion v0.2.2.

## 2026-09-11 — Time View equal-duration card height [fix]

- Fixed a Time View geometry bug where the last task in an adjacent group could render slightly taller than the previous task with the same duration.
- Card height is now determined only by canonical duration/card metrics; adjacency only reserves the canonical 4px boundary gap by stretching the affected hour when needed.
- Added a focused regression test for two adjacent 10-minute cards where the second card ends the group.

## 2026-09-11 — Browser extension sync-state polish [fix]

- Fixed the Stop control appearing before an active record was confirmed.
- Removed the duplicate top-level Syncing label and stopped replacing the current-record card with Syncing on every popup open.
- Reused the last canonical running-record snapshot immediately, warmed it from open LIFE OS tabs, and refreshed it in the background so the popup opens as a usable mini-client instead of a blocking loading screen.

## 2026-09-11 — Browser extension record companion [fix]

- Replaced the Quick Add-only popup with a LIFE OS mini companion: canonical current active record, live elapsed timer, Stop, new running-record Start, and one-click web-app access.
- Routed record reads and Start/Stop actions through the authenticated LIFE OS web shell and existing Brain/Highlander paths; the extension still stores no PocketBase credentials and performs no direct PocketBase mutations.
- Rebuilt the popup from LIFE OS design tokens and card/button geometry, while preserving the approved Victor browser-extension icon.

## 2026-09-11 — Browser extension Quick Add [feature]


## [2026-09-11] - Victor app icon rollout [shipped]

* **Branding:** [shipped] Applied the approved Victor raven + clock-dial + checklist icon across Android/Wear, Web/PWA, iOS/iPadOS, macOS, Windows, browser extension, and LIFE OS website favicons; rebuilt the public extension ZIP.
* **Android:** [shipped] New ARM64 release APK is produced from the refreshed launcher icon.
* **Source:** [shipped] `branding/life_os_app_icon_master.png` is the canonical Victor icon master used to generate platform-specific icon sizes.

- Added a Manifest V3 LIFE OS browser companion with a compact Quick Add popup, `Alt+Shift+L` action shortcut, context-menu capture for selected text/current pages, and one-click access to the deployed web app.
- Added a web-shell handoff that consumes one-shot extension requests after first frame, dedupes request IDs in local preferences, and creates Plans/Lists through the existing Planning Brain path rather than direct PocketBase writes.

## 2026-09-11 — Planning Time left-edge alignment [fix]

- Kept Time View hour labels inside the shared left content boundary by widening the timeline rail and taking that space from the schedule canvas instead of allowing labels to protrude left.
- Moved the current-time badge back to the left side of the horizontal current-time line; timeline Y/time, drag/drop, resize and scheduling behavior are unchanged.

## 2026-09-11 — Planning Time hour-label clipping [fix]

- Fixed the enlarged Time View hour labels being clipped by the narrow rail: labels now use a fixed-width box anchored to the time axis with the intended gap, without moving the timeline axis/cards or changing scheduling geometry.

## 2026-09-11 — Planning Time rail and current-time marker [ui]

- Increased Time View hour-label size and label-to-axis spacing, with each hour dot vertically centered on its hour text.
- Restored the current-time marker as a thin high-contrast horizontal line with an attached current-time badge, without changing Time View scheduling or interaction geometry.

## 2026-09-10 — Planning Time exact adjacent spacing [fix]

- Corrected the Time View elastic-hour geometry so cards whose wall times directly follow each other render with exactly 4px between their visible rectangles, including mixed-duration sequences; card starts and hour lines remain on the same wall-time Y scale.

## 2026-09-10 — Planning Time precision and controls [fix]

- Kept Time View card starts on the same wall-time Y scale as hour grid lines with 5-minute interaction precision and the existing 4px minimum card gap.
- Restored pointer access to the trailing Play control without changing its existing hover design or card drag/resize behavior.
- Made running actual time above the progress bar fully visible and locally live to the second.

## 2026-08-27 — Stats visual overview [product]

- Replaced the experimental Overview / Day / Plan-Fact Stats surfaces with two focused modes: the original expandable time tree and a visual Charts view.
- Added a donut distribution by top-level category and an hourly waking-day timeline using only top-level category colors, icons, and labels.
- Removed the obsolete `day_stats_dashboard.dart` and `plan_vs_fact_tab.dart` modules; waking-day boundaries, timezone behavior, aggregation, and record semantics remain unchanged.

## 2026-08-18 — Durable Paths architecture [engineering]

- Replaced plan-backed Path runtime compatibility with dedicated PocketBase `paths` + immutable `path_revisions` and a versioned server migration that imports existing V2 roots.
- Added `path_models.dart`, DatabaseService-owned `path_service.dart`, append-only `PathRepository` revision publishing, and Planning-owned `path_planner_bridge.dart`.
- Removed the mixed project-specific `path_governance_service.dart`; Planner startup no longer performs Path cleanup/migration.
- Added hard Architecture Guard laws for Path ownership/marker leakage/project-specific runtime templates and a PocketBase schema parity guard.

## 2026-08-18 — Repository hygiene closure [engineering]

- Removed unreachable compatibility aliases, superseded Notes/desktop-voice UI, and two unreferenced raw voice fixtures; active runtime/design-system owners are unchanged.
- Resolved the retained-product watchlist: dead entries were deleted, while `LifeCard` and `showConfirmDialog` were proven production-reachable and reclassified as normal code.
- Added `repository_hygiene.py` to CI so orphan pure re-exports and new unapproved huge tracked binaries fail automatically.
- Kept the tracked `counter_stt_helper.exe` explicitly because desktop voice still requires that HTTP sidecar; removed developer-machine absolute paths from its build/payload scripts and documented the remaining external model/source inputs.

## 2026-08-18 — Final architecture/documentation parity [engineering]

- Restored the O1 offline/sync indicator under its correct shell-presentation owner and wired it into `ShellTopStatusBars`; Brain queue/retry semantics remain in `OfflineSyncController`.
- Removed stale structure rows and updated Shell, Voice, Planning, Profile, tag-picker, cache/performance, and navigation ownership references to current paths.
- Architecture Guard now checks `APP_STRUCTURE.md` in both directions; `documentation_parity.py` rejects live governing-doc references to missing repo paths.
- Repaired the detailed-structure generator fallback so generated RU folder descriptions cannot silently copy synthesized EN prose, then regenerated the full tree guide from tracked files.

## 2026-08-18 — Shell generic voice-input boundary [engineering]

- Split generic FAB/`VoiceInputSheet` submission into `shell_voice_input.dart`.
- `shell_voice_routing.dart` now stays focused on desktop hotkey/overlay command routing and confirmation.
- Shared failed record-start retry moved to `ShellTaskActions`, so desktop and generic voice siblings do not depend on each other.
- Timeline/Planning/Backlog persistence and retry semantics are unchanged.

## 2026-08-18 — Planning startup ownership [engineering]

- Added `PlannerStartupService` under `data/plans`; shell startup now delegates Planning baseline work there.
- Shell no longer imports Paths compatibility governance directly.
- Historical Path-generated-row cleanup is exposed as an explicit compatibility hook; daily routine and migration behavior are preserved and project governance is still not auto-scheduled at startup.

## 2026-08-18 — Profile hydration alias cleanup [engineering]

- `ShellTopStatusBars` now imports the Profile-owned hydration UI directly.
- Removed obsolete shell/shared and features/shared compatibility re-exports for `ProfileHydrationStatusBar`.
- No UI or hydration behavior changes.

## 2026-08-18 — Shell tab/edit-host dependency graph [engineering]

- Declared `ShellTabHost`'s dependency on `ShellEditHosts` explicitly.
- Reordered shell mixins so edit hosts are available before tab composition.
- Removed concrete `(this as ShellDashboardState)` casts from tab callbacks; behavior is unchanged.

## 2026-08-18 — Shell top status naming cleanup [engineering]

- Renamed obsolete `shell_offline_banner.dart` to `shell_top_status_bars.dart`; the widget is no longer an offline banner.
- Removed the unused `routeTab` parameter from `ShellTopStatusBars`.
- No UI or behavior changes.

## 2026-08-18 — Source-plan link policy ownership [engineering]

- Moved source-plan suggestion enable/mode/dismissal preferences and auto-link threshold policy from shell into Brain `plan_record_link_helpers.dart`.
- Brain now prepares/auto-applies source-plan suggestions and owns accepted/dismissed persistence.
- `shell_task_actions.dart` only hosts the user-facing suggestion prompt and forwards accept/skip/disable actions.

## 2026-08-18 — Shared STT engine lifecycle [engineering]

- Added `SpeechEngineController` under `shared/voice/recognition` as the owner of SpeechToText initialization, readiness/error state, hard reset and locale diagnostics.
- Removed SpeechToText engine state and initialization/reset methods from shell state and `shell_voice_routing.dart`.
- Shell now only prewarms/disposes the controller and hosts the voice sheet/submit routing.

## 2026-08-18 — Sleep foreground lifecycle ownership [engineering]

- `ShellTopStatusBars` is presentation-only again; Health Connect/cloud ingestion no longer starts from a UI widget.
- Added `SleepForegroundReconcileService` under `data/health` for device-first then cloud reconciliation on startup/resume.
- Shell lifecycle starts/stops the coordinator and starts unfilled-time tracking; sync semantics are unchanged.

## 2026-08-18 — Profile hydration UI ownership [engineering]

- Moved `ProfileHydrationStatusBar` implementation into `features/profile/`.
- Shell/shared and old `features/shared/` paths are compatibility re-exports only.
- Hydration error/retry behavior is unchanged; Profile now owns its own status UI.

## 2026-08-18 — Settings feature ownership [engineering]

- `features/profile/settings/settings_page.dart` now owns the real Settings UI.
- `app/shell/shared/settings_page.dart` is a compatibility re-export only.
- Language/timezone behavior and persistence are unchanged.

## 2026-08-18 — Timeline edit result ownership [engineering]

- `shell_edit_hosts.dart` no longer performs Timeline record DELETE/STOP mutations directly.
- Timeline delete/retry and stop follow-up actions now live in `features/shared/edit_sheet/timeline_edit_result_actions.dart`.
- Shell remains the edit-sheet host/router; persistence behavior is unchanged.

## 2026-08-18 — Shell desktop voice integration boundary [engineering]

- Split desktop tray/global-hotkey attach/reattach lifecycle from `shell_voice_routing.dart` into `shell_voice_integration.dart`.
- `ShellVoiceRouting` remains responsible for voice command/STT routing and submission; the integration mixin only connects desktop voice infrastructure to shell lifecycle/chrome.
- Voice behavior, hotkey semantics, tray actions, and recognition flow are unchanged.

## 2026-08-18 — Planning edit result ownership [engineering]

- `shell_edit_hosts.dart` now only hosts/routes the Planning sheet; persisted field edits remain owned by the editor autosave flow.
- New-draft create/collision handling and persisted delete/rollback/undo moved to `features/shared/edit_sheet/planning_edit_result_actions.dart`.
- Removed the Planning optimistic-delete sentinel and duplicated persistence orchestration from shell ownership.

## 2026-08-18 — Shell lifecycle/chrome/task-action recomposition [engineering]

- Reduced `lib/app/shell/app_shell.dart` to the dashboard composition root and shared state contract.
- Extracted dashboard initialization/disposal wiring to `shell_lifecycle.dart` and responsive scaffold/chrome to `shell_chrome.dart`.
- Extracted quick start/plan, record stop/delete, Planning→record start, and source-plan suggestion orchestration from `shell_core.dart` into `shell_task_actions.dart`; `shell_core.dart` is again limited to selected-day/task-loading coordination and shared shell sync UI.
- Moved Paths selected-index ownership fully into `shell_more_menu.dart` instead of a dashboard-state override.
- Registered concurrently added `timeline_sleep_details.dart` in the canonical structure manifest; sleep behavior itself is unchanged.
- No persistence schema, Planner semantics, Timeline semantics, or navigation behavior changed.

## 2026-08-18 — Shell / Paths ownership cleanup [engineering]

- Removed the retired embedded Paths V2/V3 UI/bootstrap stack from `shell_shared.dart` and `shell_more_menu.dart`; shell now only navigates to the first-class `PathsPage` destination.
- Moved marker-era Path → Planner compatibility/governance to `lib/data/paths/compatibility/` and daily-routine Planner bootstrap to `lib/data/plans/` without changing their scheduling/dedupe behavior or running them on Paths open.
- Updated canonical architecture/structure docs and the existing focused contract test to the new owners.

## 2026-08-08 — Notes block actions and drawing preview

- Active Notes blocks now expose a right-side delete action backed by the existing safe `deleteBlock()` document mutation; the action rail is reserved so activation does not reflow text.
- Desktop drawing blocks now decode and display their saved PNG `drawingData` inline instead of showing only the file-style media row.
- Repaired the stale Notes canonical-component test fixture for the required `editing` argument; analyzer and release web build pass.

## 2026-08-05 — Realtime activates on app open

- Cold start now arms PocketBase records/plans/catalog subscriptions immediately after profile hydration instead of depending on the post-frame maintenance queue.
- A transient startup PocketBase backoff now schedules one automatic retry after the cooldown; no user action and no periodic polling are required.
- App-open/resume sync uses one deduplicated push-first path followed by a single catch-up fetch for events missed while suspended.

# 📖 DEV_JOURNAL (Changelog)

## [2026-10-06] - Calendar view selector and swipe navigation [shipped]

* **Calendar mobile/desktop chrome:** removed persistent previous/next arrows; period navigation now uses horizontal swipe and a compact top action capsule.
* **Calendar modes:** added **Year / Month / Week / Events** selector, year overview, agenda-style Events view, visible-period search, and Today/Back actions in the overflow menu.
* **UX contract / l10n:** documented gesture-first calendar navigation and added RU/EN strings for the new modes and controls.


## [2026-10-06] - Canonical one-line input + Timeline mobile geometry

* **`lib/core/widgets/app_text_field.dart`:** added `AppTextField` as the single canonical standard one-line input surface (42px height, 18px radius, shared Notes-derived styling; search icon is a parameter).
* **Timeline:** mobile and desktop quick entry now use the same `AppQuickEntryRow`; the text field and Start/Plan/Add action render at the same 42px height instead of the mobile raw `TextField` / `FilledButton` fork.
* **Notes:** `NotesGlmLibraryInput` now delegates visual ownership to `AppTextField` so Notes and Timeline cannot drift.
* **Design system:** raw feature-local styling for standard one-line `TextField` / `TextFormField` inputs is forbidden; specialized rich/multiline editor internals remain explicit exceptions.


> **WARNING FOR AI:** Read the latest entries to understand what features are ALREADY built and do not need to be recreated.
>
> 🚀 **FOUNDER'S VICTORY PROMPT (COPY & PASTE INTO CURSOR CHAT WHEN A FEATURE IS TESTED AND WORKS):**
> ***
> **CONTEXT:** We just successfully tested and completed a feature.
> **TASK FOR CURSOR:** > 1. Analyze our recent conversation history to understand exactly what technical logic, UI, or architectural rule we just successfully implemented.
> 2. Write a concise, highly technical 1-2 sentence bullet point summarizing the achievement (mention specific file names, hooks, or logic rules).
> 3. Add this bullet point to the top of the `@CHANGELOG.md` file under today's date (create a new date header if today's date doesn't exist yet).
> 4. DO NOT delete or modify any existing entries.
> ***

## [2026-08-17] - Project Paths content width parity [shipped]

* **`lib/features/settings/categories/category_list_view.dart`:** Project Paths list and detail bodies now use the same centered 1440px content rail and responsive 24px desktop / 20px compact gutters as Lists; removed their extra local horizontal ListView padding so card edges align.

## [2026-08-05] - Push-first multi-device sync reliability [shipped]

* **Plans/Lists durability:** create and edit mutations now use a serialized local write-ahead outbox before PocketBase POST/PATCH; revision-specific acknowledgements prevent stale responses or concurrent flushes from deleting newer mobile edits, while auth/network failures keep one coalesced replay item.
* **PocketBase realtime:** plan events merge immediately without a tag-catalog HTTP round trip; records, plans, categories, tags, and profile subscriptions are re-armed before one-shot resume catch-up, with no periodic polling.
* **Mobile lifecycle:** dirty non-recurring plan drafts flush when the app becomes inactive/paused; realtime 404 no longer disables live sync silently for 30 minutes and retries the push channel after 30 seconds.
* **Verification:** focused `live_sync_contract_test.dart`, analyzer, release web build, and Android arm64 APK build.

## [2026-07-30] - P0 Planning selected-time stability and web editor load [shipped]

* **`planning_task_edit_sheet.dart`:** [shipped] Task-title typing no longer parses or overwrites the start time selected on the Time View grid; fuzzy category matching is debounced.
* **Planning edit hot path:** [shipped] New drafts no longer serialize rich notes/checklists on every keypress; persisted draft optimistic merge + global Planning refresh is coalesced behind the existing autosave debounce.
* **New scheduled plans:** [shipped] Creation now reuses Brain collision resolution, moves only the new task to the first free slot, preserves duration, and shows one localized adjustment notice.

## [2026-07-27] - Health Connect sleep sync [implemented]

* **Android Health Connect:** Added read-only `SLEEP_SESSION` permission flow and Mi Fitness-compatible sleep import.
* **Timeline Brain:** Imported sleep is authoritative: prior activity stops at sleep start, conflicting rows inside sleep are removed, and repeat sync updates instead of duplicating. Existing record/category optimistic and offline paths remain the only PocketBase write route.
* **Unfilled time:** Added generic Timeline gap detection, persistent fill prompt, and optional notification settings independent of sleep.
* **PocketBase schema:** No migration required; sleep sessions are reconciled against existing `Sleep` / `Сон` records by interval, while user notes remain untouched.
* **Verification:** Strict architecture guard, analyzer, and three focused policy tests run in the branch check.

## [2026-07-24] - Notes: contextual rich editor tools v2 [engineering]

* **`lib/features/notes/` + `lib/data/models/note_*`:** Added backward-compatible `lifeos_notes_blocks_v2`, inline text marks, contextual `Aa`/Insert/selection tools, slash commands, lists, quote, callout, divider, code, collapsible, link-card and editable table blocks; legacy Notes migration, autosave, PocketBase schema, optimistic/offline paths, and existing library/editor shell remain compatible.
* **Verification:** strict architecture guard, analyzer, two focused Notes tests, production web release build, and real Chrome runtime capture passed; final capture is `test/fixtures/notes_v2_tools_capture.png`.

## [2026-07-23] - Structure: final repository completeness audit [engineering]

* **Phase 2G:** Final completeness audit after Phases 1–2F — 9 large Dart files reviewed (LARGE_FILE 0), 14 zero-ref candidates classified (KEEP/DEFER/tooling; none deleted), no architecture drift, no accidental tracked artifacts. Docs-only closure; ordinary repository cleanup formally complete with deferred feature scopes. Report: `docs/reports/FINAL_REPOSITORY_COMPLETENESS_AUDIT_2026-07-23.md`.

## [2026-07-23] - Structure: close Stage B drift audit [engineering]

* **Phase 2F:** Audited Roadmap Stage B (root barrels, `Archive/`, duplicate l10n). Only `lib/main.dart` + `lib/app_shell.dart` at root; `Archive/` already gone (guard enforced); l10n remains single `dictionary.dart` + `langs/` SSOT. No production Dart changes. Report: `docs/reports/STAGE_B_STRUCTURE_DRIFT_AUDIT_2026-07-23.md`.

## [2026-07-23] - CI: enforce strict architecture guard [engineering]

* **Phase 2E:** Added `.github/workflows/architecture-guard.yml` (`Architecture Guard` / `strict-structure`) for PRs to `main`; wired `scripts/audit/architecture_guard.ps1 -Strict` after checkout in `deploy.yml` and `windows-desktop-build.yml` before Flutter. No production Dart or app behavior changes.
* **Phase 2E correction:** Architecture Guard checkout uses `fetch-depth: 0`; `git diff --check` runs against the PR base…HEAD range (or `origin/main...HEAD` on `workflow_dispatch`) so committed whitespace errors are caught.
* **Phase 2E correction:** `architecture_guard.ps1` path resolution is cross-platform (no Windows-only `..\..` / `lib\…` literals); forbidden-import scans use PowerShell `Select-String` so Ubuntu Actions does not need `rg`.

## [2026-07-23] - Categories: assign code to real owners [engineering]

* **Phase 2D:** Moved category manager UI to `lib/features/settings/categories/`; reusable presentation/tree/picker/visibility to `lib/shared/categories/` with `CategoryTreeSource` / `CategoryPickerActions` wired from `main.dart`; Lists owns `category_filter_tree_field.dart`; plan/record draft helpers to `features/shared/edit_sheet/category_edit_draft.dart`. Brain `lib/data/categories/` and `CategoryRule` in models unchanged. No intentional category UX, schema, save, or `hidden_category_ids_json` changes.

## [2026-07-22] - Voice: keep command execution in Brain [engineering]

* **Phase 2C correction:** Moved `desktop_voice_record_submit.dart` to `lib/data/voice/`; desktop Flutter Voice UI to `lib/features/voice/`; parser-tied evaluator/benchmarks to Brain. Shared Voice must not import `data/voice/`. Glossary pack data stays shared; live builder + postprocess wired from `main.dart`.

## [2026-07-22] - Voice: unify ownership across platforms [engineering]

* **Phase 2C:** One Voice system — moved production Voice/STT out of `lib/core/services/`, `lib/features/shared/`, and `lib/features/profile/` into `lib/shared/voice/` (commands/recognition/routing/ui/platforms/diagnostics), Brain `lib/data/voice/`, and `lib/features/settings/voice/`. Shell keeps `shell_voice_routing`. Tray/main-window stay in `core/services/`. No intentional Voice UX, parser, preference-key, or flag-default changes.

## [2026-07-22] - Diagnostics: assign ownership to real owners [engineering]

* **Phase 2B:** Moved former `lib/core/diagnostics/` + `lib/core/performance/` into `lib/shared/diagnostics/` (runtime logs + kill switches), `lib/data/plans/diagnostics/` (plan duplicate log — Brain), and `lib/shared/voice/diagnostics/` (desktop voice pipeline). No behavior change.
* **Phase 2B correction:** `plan_duplicate_log` ownership corrected to `lib/data/plans/diagnostics/` so Brain does not import `features/`; empty `lib/features/planning/diagnostics` must stay gone.

## [2026-07-21] - Time: assign ownership to shared/feature paths [engineering]

* **`lib/shared/time/`:** Phase 2A — moved former `lib/core/time/` multi-consumer wall-clock, timezone catalog, app clock hooks, plan window/labels, and category TZ options out of `core/`; settings-only helpers → `lib/features/settings/timezone_settings.dart`. No UTC/DST/projection behavior change.
