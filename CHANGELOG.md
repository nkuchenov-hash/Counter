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
