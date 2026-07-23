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

## [2026-07-21] - Shell: form-factor ownership split [engineering]

* **`lib/app/shell/`:** Phase 1 feature-first shell restructure — moved former `lib/shell/` into `app/shell/{shared,phone,tablet,desktop}`; root `lib/app_shell.dart` remains a thin compatibility re-export; tab order, breakpoints, and chrome behavior unchanged (tablet currently shares phone compact chrome below 900px). Wear shell stays in `features/wear/` (no dead placeholders).

## [2026-07-21] - Docs: include evidence index in file map [engineering]

* **`APP_STRUCTURE_DETAILED.md`:** Regenerated from current 724 tracked files (includes `structure_evidence_index.py`); header now says **Generated from input HEAD** (input SHA, not the commit that will contain the document); generator fails unless evidence/role/necessity/confidence/rendered counts all equal `len(git ls-files)`.

## [2026-07-21] - Docs: evidence-backed file map [engineering]

* **`APP_STRUCTURE_DETAILED.md`:** Generator now attaches deterministic evidence (Dart import/export/`part`, path refs, platform conventions, hygiene watchlist), repository role, necessity status, deletion consequence, and confidence for every tracked file; new helper `scripts/manual/structure_evidence_index.py`. Watchlist files are labeled `RETAINED_PRODUCT_WATCHLIST` / `COMPATIBILITY_LAYER` (not runtime-required). Deterministic regenerate verified.

## [2026-07-21] - Repo: hygiene audit cleanup [engineering]

* **Hygiene audit:** Removed nine tracked timestamped `real_helper_latency_2026-07-11T*.json` bench outputs (already `.gitignore`d; keep `real_helper_latency_latest.json`); dropped unused direct deps `table_calendar` and `cupertino_icons`. Report: `docs/reports/REPOSITORY_HYGIENE_AUDIT_2026-07-21.md`. No production UI/behavior change; LARGE_FILE remains **0**.

## [2026-07-21] - Plans: consolidate cache identity [engineering]

* **`plans/plan_cache_helpers.dart`:** Consolidated plan business/optimistic identity + in-memory cache mutation (`_planBusinessUuidFromTask`, `_isOptimisticPlanningTask`, `_purgeOptimisticPlanRowsFromUserCache`, `_upsertPlanInUserCache`, `_removePlanFromUserCache`, `_filterBacklogFromAll`) from `plan_service.dart` into `PlanCacheProjectionExtension` (**1877 → 1775** / **473 → 575** Measure-Object lines). Cache state fields stay in `plan_service`; fetch/CRUD/realtime untouched. Final justified `plan_service` decomposition pass. LARGE_FILE **1 → 0**.

## [2026-07-21] - Plans: consolidate recurrence mutations [engineering]

* **`plans/plan_recurrence_helpers.dart`:** Consolidated recurring identity, exception_dates mutation, virtual completion/edit materialization, and recurrence edit/delete scope (`_isJitVirtualPlanningTask`…`deletePlanningTaskWithRecurrenceScope`) from `plan_service.dart` into `PlanRecurrenceExtension` (**2585 → 1877** / **178 → 886** Measure-Object lines). Ordinary CRUD (`updatePlanningTask` / `deletePlanningTasksBulk` / …) left in `plan_service`; thisAndFuture still unsupported; exception rollback on failed materialize unchanged. LARGE_FILE remains **1**.

## [2026-07-21] - Plans: extract record linkage [engineering]

* **`plans/plan_record_link_helpers.dart`:** Extracted plan-to-record linkage + plan-vs-fact stats (`aggregateSourcePlanActualSecondsForWallCalendarDay`, `getBasicDayStats`, `suggestSourcePlanForFreeStart`, `resolveCurrentPlanCategoryForRecordStart`, category inheritance helpers) from `plan_service.dart` into `PlanRecordLinkExtension` (**2848 → 2585** / new part **267**). Actual-time bucketing, BasicDayStats fields, title-link threshold 0.42, and Brain-over-stale-UI category precedence unchanged; `plan_service` role narrowed to cache fetch/realtime and CRUD. LARGE_FILE remains **1**.

## [2026-07-21] - Plans: extract order sync [engineering]

* **`plans/plan_order_helpers.dart`:** Extracted Planning reorder state + sync (`_planOrderDebounce*`, baseline map, `persistPlanningTaskOrder`, `_persistPlanningTaskOrdersBulkNow`, rollback, `flushPlanningOrderSyncNow`) from `plan_service.dart` into `PlanOrderSyncExtension` (**3027 → 2848** / new part **204**). Optimistic-first UI, 2s debounce, diff-only `order` PATCH, virt hard-fail, and partial-success/rollback semantics unchanged; `plan_service` role no longer claims plan reorder. LARGE_FILE remains **1**.

## [2026-07-21] - Categories: extract order sync [engineering]

* **`categories/category_order_helpers.dart`:** Extracted category sibling optimistic reorder + debounced PocketBase order sync (`applyLocalCategorySiblingOrder`, `persistCategorySiblingOrder`, `flushCategoryOrderSyncNow`, bulk force/now PATCH) from `plan_service.dart` into `CategoryOrderSyncExtension` (**3182 → 3027** / new part **159**). 2s debounce, baseline diff-only PATCH, root/child tree updates unchanged; `plan_service` role narrowed to plan reorder. LARGE_FILE remains **1**.

## [2026-07-21] - Plans: consolidate auto scheduling [engineering]

* **`plans/plan_time_cascade_helpers.dart`:** Consolidated new-plan auto-scheduling + day/category overload evaluation (`resolveAutoPlanSchedule`, `profileDisplayWallsFromAutoSchedule`, `planningTaskWithAutoSchedule`, `evaluatePlanDayScheduleOverload`) from `plan_service.dart` into `PlanTimeCascadeExtension` (**3434 → 3182** / **196 → 448** Measure-Object lines). Explicit-range probe cascade, category-default UTC path, collision avoidance, and overload thresholds unchanged. `docs/APP_STRUCTURE.md` projection table row + `plan_service` role corrected. LARGE_FILE remains **1**.

## [2026-07-21] - Plans: consolidate timezone projection [engineering]

* **`plans/plan_projection_types.dart`:** Consolidated profile-timezone projection (`_profileTimezoneProjectionRevision`, wall/UTC coalesce + reproject, `reprojectAllPlansForProfileTimezone`, `plansProjectionCacheSignature`, `_filterPlansForWallDay`, `planningWallScheduleDateKey`) from `plan_service.dart` into `PlanProfileTimezoneProjectionExtension` (**3711 → 3434** / **101 → 381** Measure-Object lines). `TimeModeProjectedPlan` + `PlanTimeModeProjection` unchanged; TZ invalidation ordering and UTC-source-of-truth preserved. LARGE_FILE remains **1**.

## [2026-07-21] - Plans: extract optimistic overlay [engineering]

* **`plans/plan_optimistic_helpers.dart`:** Extracted dated/backlog optimistic overlay state + merge/apply/clear/rekey (`_planningOptimisticByDateKey`, `applyOptimisticPlanningTask`, `clearOptimisticPlanningForPlanRow`, `_mergePlanningOptimistic`, `getBacklogPlansSnapshot`) from `plan_service.dart` into `PlanOptimisticOverlayExtension` (**3866 → 3711** Measure-Object lines; new part **159**). Cross-day hiding, overlay-wins merge, confirmed-row preference, backlog routing, and outbox cancel-on-clear unchanged. LARGE_FILE remains **1**.

## [2026-07-20] - Plans: extract planning stream hubs [engineering]

* **`plans/plan_stream_helpers.dart`:** Extracted shared Planning day-stream hubs + refresh orchestration (`_PlanningDayStreamHub`, `planningStream`, `notifyPlanningRefresh`, refresh getters, poke-from-cache) from `plan_service.dart` into `PlanStreamRefreshExtension` (**4065 → 3866** Measure-Object lines; new part **203**). Hub ref-count, cache-first emit, 400ms network debounce ordering, and no-polling contract unchanged. LARGE_FILE remains **1**.

## [2026-07-20] - Plans: extract snapshot cache pipeline [engineering]

* **`plans/plan_snapshot_helpers.dart`:** Extracted Planning warm-snapshot / rendered-body / P0t render-snapshot pipeline (`planningDayTasksSnapshot` through `markPlansDayBodyRendered`) from `plan_service.dart` into `PlanSnapshotCacheExtension` (**4493 → 4065** Measure-Object lines; new part **431**). Warm-window gating, disk restore/persist JSON, bodyReady sources, and public APIs unchanged. LARGE_FILE remains **1**.

## [2026-07-20] - Plans: consolidate mutation network phase [engineering]

* **`plans/plan_outbox_helpers.dart`:** Moved immediate update/delete network phase (`_planMutationRetriableHttpCode`, `_patchPlanUpdateNetworkPhase`, `_deletePlanNetworkPhase`) from `plan_service.dart` into `PlanOutboxSyncExtension` (**4663 → 4493** / **591 → 762** Measure-Object lines). Flush/replay left undeduplicated; AppSnack, 404/401/403/retriable enqueue, and `(ok, queued)` delete semantics unchanged. LARGE_FILE remains **1**.

## [2026-07-20] - Plans: consolidate offline day cache [engineering]

* **`plans/plan_cache_helpers.dart`:** Moved offline Planning day-cache codec + SharedPreferences persist/load (`_planningTaskToDayCacheMap`, `_planningTaskFromOfflineDayMap`, `_persistPlanningTasksDayCache`, `_loadPlanningTasksDayCache`) from `plan_service.dart` into `PlanCacheProjectionExtension` (**4875 → 4663** / **260 → 473** Measure-Object lines). Key `cache_plans_day_v1_<dateKey>`, field aliases, scrub-before-persist/after-load, and wall-time reprojection unchanged. LARGE_FILE remains **1**.

## [2026-07-20] - Voice: extract helper process lifecycle [engineering]

* **`desktop_stt_helper_process_lifecycle.dart`:** Extracted helper process/install lifecycle (`helperPath`, `ensureStarted`, `_ensureHelperRunning`, `_restartHelper`, `_killHelperProcess`, stdout/stderr tails) from `desktop_stt_helper_service.dart` as `part of` (**1916 → 1715** Measure-Object lines; new part **206**). LARGE_FILE warnings **2 → 1** (`plan_service.dart` remains). HTTP readiness, transcribe, and diagnostics parts unchanged.

## [2026-07-20] - Voice: extract helper diagnostics assembly [engineering]

* **`desktop_stt_helper_diagnostics_builder.dart`:** Extracted diagnostics assembly (`_updateDiagnostics`, WAV duration resolvers, `fetchDiagnostics`, last-attempt write) from `desktop_stt_helper_service.dart` as `part of` (**2233 → 1916** Measure-Object lines; new part **322**). `_lastDiagnostics` ownership, public API, and helper/capture/transcribe orchestration unchanged.

## [2026-07-20] - Notes: extract editor block widgets [engineering]

* **`notes/widgets/note_editor_block_widgets.dart`:** Extracted block rendering + add-block chrome (`NoteEditorBlockRow`, `NoteEditorBlockPatch`, `NoteEditorAddBlockRow`) from `note_editor_page.dart` (**1837 → 1294** Measure-Object lines). Page keeps document/autosave/Brain orchestration; widgets receive data + callbacks only. LARGE_FILE warnings **3 → 2**.

## [2026-07-20] - Plans: extract quick-add tags controller [engineering]

* **`planning_quick_add_tags_controller.dart`:** Extracted quick-add tag strip state (catalog merge, “No Tags” prefs, creation selection, reorder persistence) from `planning_page.dart` (**1964 → 1794** Measure-Object lines). `PlanningPage` constructor / host contract / optimistic submit unchanged. LARGE_FILE warnings **4 → 3** (`planning_page.dart` cleared).

## [2026-07-20] - Structure: regenerate detailed app guide [engineering]

* **`APP_STRUCTURE_DETAILED.md`:** Regenerated from the current tracked tree after architecture-guard baseline cleanup (63 → 0). Generator mappings updated for Notes, Desktop Voice, plan alarms, final five modules, relocated Notes capture fixtures, and new test/installer folders. Quality OK; deterministic second run identical; structure scan + strict guard remain green. Documentation/generator-data only.

## [2026-07-20] - Architecture: document final production modules [engineering]

* **`APP_STRUCTURE.md`:** Added exact entries for the final 5 legitimate production modules (`radial_menu_viewport.dart`, `voice_domain_resolver.dart`, `create_category_from_picker.dart`, `record_edit_save_policy.dart`, `shell_bottom_navigation.dart`). Strict guard **5 → 0** (A=0, B=0). Architecture baseline cleanup complete; `APP_STRUCTURE_DETAILED` regeneration remains the only follow-up. Documentation-only.

## [2026-07-20] - Architecture: document production Notes modules [engineering]

* **`APP_STRUCTURE.md`:** Added exact entries for all 19 legitimate production Notes modules (`core/widgets/notes/*`, `models/note_document.dart`, `plans/notes_brain_helpers.dart`, `features/notes/*`, `shared/notes_editor/*`). Strict guard **24 → 5** (A=0, B=5). Documentation-only; no source changes. `APP_STRUCTURE_DETAILED` regeneration deferred.

## [2026-07-20] - Architecture: document Desktop Voice modules [engineering]

* **`APP_STRUCTURE.md`:** Added exact entries for all 32 legitimate Desktop Voice / STT production modules (`core/services/*` + `desktop_voice_correction_sheet.dart`). Strict guard **56 → 24** (A=0, B=24). Documentation-only; no source changes.

## [2026-07-20] - Notes: move capture fixtures out of production lib [engineering]

* **`test/notes/fixtures/` + `scripts/manual/capture_notes_glm_main.dart`:** Relocated four test-only GLM Notes capture/fixture files from `lib/features/notes/debug/`; updated parity test + `capture_notes_glm_parity.ps1`. Strict guard **60 → 56** (A=0, B=56). Production Notes code unchanged.

## [2026-07-20] - Voice: remove Core dependency on Brain [engineering]

* **`desktop_stt_cloud_backend.dart` + `DesktopSttCloudBackendHooks`:** Moved PocketBase readiness, auth token, `/api/ai/transcribe-command` POST, and 25s timeout into Brain; Core cloud STT maps HTTP results via main.dart injection (AppClock-style). Strict guard **61 → 60**.

## [2026-07-17] - Architecture guard baseline and first cluster [engineering]

* **`ARCHITECTURE_GUARD_BASELINE_2026-07-17.md` + `APP_STRUCTURE.md`:** Classified all 63 strict diagnostics (A=5, B=58); documented the two valid plan-alarm modules as the first safe cluster, reducing the expected strict count to 61 without changing guard severity or runtime code.

## [2026-07-17] - Plans: extract AI parse helpers [engineering]

* **`plans/plan_ai_parse_helpers.dart`:** Moved `parseTaskViaAiBackend` / `parsePlanningItemsViaAiBackend` (+ HH:mm / item normalization helpers) out of `plan_service.dart` into a focused Brain `part`; DatabaseService API unchanged.

## [2026-07-17] - Plan reminder alarms: canonical scheduler + Windows init fix [engineering]

* **Root cause:** `NotificationService.ensureInitialized` omitted `WindowsInitializationSettings` (and treated Linux as schedulable), so plugin init threw and every `syncAlarms` call no-oped; fire times used device `tz.local` instead of profile wall UTC; Android lacked boot receivers / `RECEIVE_BOOT_COMPLETED`.
* **`plan_alarm_schedule.dart` + `notification_service.dart`:** Canonical schedule/cancel/reconcile API; profile-timezone fire UTC; Windows init GUID/AUMID; gated `[PLAN_ALARM]` diags; `inexactAllowWhileIdle` (no exact-alarm privilege).
* **`plans/plan_alarm_helpers.dart`:** `reconcilePlanNotifications()` from hydrated `_allPlansUserCache` only (no network); debounced from planning refresh / hydrate / resume; removed alarm work from timeline record emits; sign-out cancels pending.
* **AndroidManifest + Profile notifications:** Boot receivers + vibrate; Profile button calls `requestPermissions()` (not one-shot `IfNeeded`).
* **`test/services/plan_alarm_schedule_test.dart`:** Occurrence id stability, past/done/deleted skip, same-id finalize without duplication.

## [2026-07-13] - Notes editor: faithful NoteEditor.tsx composition port [product]

* **`note_editor_page.dart`:** Mechanical TSX translation — 768px column, compact top bar (px-4/py-3), borderless title/metadata, inline glass category picker, 4px block rhythm, right-side active controls (no hover menu), add-block pills, exact toolbar order with popover color picker above toolbar.

## [2026-07-13] - GLM Notes library: production shell replacement [product]

* **`notes_library_production_shell.dart` + `lists_view.dart`:** Replaced the live Lists-tab widget tree with a full-bleed GLM gradient workspace, centered 1024px column, GLM search/pills/add row, and grid-first `NotesLibraryBody` (default grid on desktop).
* **`note_card.dart` + `notes_glm_surface.dart`:** Premium two-column glass grid cards; full-height library background; production capture fixtures updated.

## [2026-07-10] - GLM Notes v3: strict UI composition port [product]

* **`lib/features/notes/notes_glm_surface.dart` + `note_editor_page.dart`:** Rebuilt editor as centered 768px column (`NotesGlmEditorFrame`) with soft GLM gradient background, integrated bottom toolbar, subtle active-block wash, glass add-block pills, and stronger title/metadata hierarchy.
* **`lib/features/lists/lists_view.dart` + `note_card.dart` + `notes_library_body.dart`:** Library wrapped in `NotesGlmLibraryFrame` (1024px centered), glass list/grid cards, and parity harness + capture script (`test/fixtures/notes_glm_*_capture.png`).

## [2026-07-10] - P0 Desktop Voice: warm P95 useful-candidate latency proof [engineering]

* **`desktop_stt_helper_service.dart`:** 100ms session partial poll; session-scoped `_sessionBestPartialUseful`; zero-await cached useful candidate on stop (`DESKTOP_VOICE_IMMEDIATE_STOP_CANDIDATE`).
* **`desktop_voice_recognition_postprocess.dart`:** Client-first SCW/BLINK comma grammar no longer gets erroneous `Price Reporter` prefix (fixes `Submit` title).
* **`desktop_voice_real_helper_latency_benchmark.dart` + installed-helper harness:** 20 warm SCW runs against `counter_stt_helper.exe`; P95 `stop_to_useful_candidate_ms` = 0ms (strict `<500ms`); contamination/stale regression scenarios; artifact `benchmark_reports/real_helper_latency_latest.json`.

## [2026-07-10] - GLM Notes v3: visual fidelity pass [product]

* **`lib/features/notes/notes_visual_tokens.dart` + editor/library widgets:** GLM-matched spacing, typography, glass surfaces, pill add-block row, accent-filled toolbar buttons, calm top bar, and refined note cards (grid/list).

## [2026-07-10] - GLM Notes v3: block editor port [product]

* **`lib/data/models/note_document.dart` + `lib/data/plans/notes_brain_helpers.dart`:** Versioned `lifeos_notes_blocks_v1` envelope in `plans.notes_delta`; legacy Quill/plain/checklist migration; `notes_plain` + `checklist` mirrors; pin in `meta.pinned`; `createEmptyNote` backlog optimistic path.
* **`lib/features/notes/` + `lib/features/lists/lists_view.dart`:** GLM v3 Notes library (grid/list, checkbox modes, search, category chips, card previews); full-screen block editor with formatting toolbar, image pick, drawing canvas; card tap → editor; radial menu pin/done; inline add → empty paragraph + editor.
* **`test/note_document_test.dart`:** Serialization, legacy migration, projection, and malformed JSON coverage.

## [2026-07-10] - P0 Desktop Voice: session contamination + latency gate [engineering]

* **`desktop_voice_session.dart` + `desktop_stt_helper_service.dart`:** Immutable `voiceSessionId` per hotkey; `/transcribe/reset_session` clears helper `last_partial`; stale async results discarded; session-tagged partials.
* **`desktop_voice_contamination_gate.dart`:** Blocks multi-client / stale-fragment / duplicate-segment commands before pending and `writeRecord`; corrupted 67ea8eb title fixture archived.
* **`desktop_voice_transcript_merge.dart`:** Final replaces partial (no full-hypothesis concatenation); comma dedupe; `build_stt_helper_en.ps1` trims BLINK/Laredo from whisper initial_prompt.
* **Latency:** Useful candidate strict `<500ms`; contaminated/garbage partials not counted; early useful candidate can show pending before final inference.

## [2026-07-10] - P0 Desktop Voice: desktop shortcut for installed app [engineering]

* **`scripts/manual/desktop_voice_desktop_shortcut.ps1`:** Creates/updates `%USERPROFILE%\Desktop\Counter.lnk` → `%LOCALAPPDATA%\Programs\Counter\counter.exe` (working dir + icon); replaces stale dev/build targets.
* **`install_desktop_voice_release.ps1` / `smoke_desktop_voice_installed.ps1`:** Install ensures shortcut; smoke verifies `desktop_shortcut_*` fields and fails if not pointing at installed app.

## [2026-07-09] - P0 Desktop Voice: live UX fail — cue / overlay / correction [engineering]

* **`desktop_voice_ready_cue.dart` + native `PlayReadyCue`:** Replaced silent PowerShell `[console]::beep` with Win32 `PlaySound` WAV click; `ready_cue_played=yes` only when `output_ok`; installed smoke self-test.
* **`desktop_voice_native_overlay.cpp`:** `WS_EX_LAYERED` + `LWA_COLORKEY` so corners outside the pill are transparent (no black rectangular backdrop).
* **`desktop_voice_correction_flow.dart` + `desktop_voice_widget.dart`:** Single-instance correction; hide native overlay before sheet; reparse + write after confirm; cancel clears pending with no write; silent confirm no-op blocked.
* **Latency:** Useful-candidate &lt;500ms gate unchanged; live 592ms remains an honest blocker (not a pass).

## [2026-07-09] - P0 Desktop Voice: capture-ready cue + pre-roll start guard [engineering]

* **`desktop_voice_capture_ready_policy.dart` + `desktop_voice_ready_cue.dart`:** Short 45ms ready click after first audio callback (recording already started); cue not counted as speech/latency; STT leading pad + start-trim guard preserve first phonemes.
* **`desktop_voice_audio_capture.dart` / overlay / diagnostics:** Arm cue on first level frame; overlay switches to “Говорите” / Speak after cue; `last_attempt_diag` gains ready-cue and pre-roll timing fields.
* **Fixtures:** Archived `scw_delmod_submit_fefb502_live_quiet*.wav`; STT-only gain remains rejected (`NO_FAKE_GAIN_FIX`).

## [2026-07-09] - P0 Desktop Voice: install identity fix + smoke SHA guard [engineering]

* **`scripts/manual/install_desktop_voice_release.ps1`:** Stops counter+helper, builds with `GIT_COMMIT`/`BUILD_TIME`, robocopy full Release tree (app+helper), verifies `app.so` embeds current SHA — blocks mixed helper-only installs.
* **`scripts/manual/smoke_desktop_voice_installed.ps1` + `desktop_voice_install_smoke_policy.dart`:** Fails on SHA mismatch, missing endpoint id/role/volume, stale `df696fc`; requires `DESKTOP_VOICE_BUILD_SHA` in pipeline log.
* **`desktop_stt_diagnostics.dart`:** `selected_capture_endpoint`, `capture_mix_format` in `last_attempt_diag.txt`.

## [2026-07-09] - P0 Desktop Voice: Windows endpoint diagnostics + capture role selection [engineering]

* **`installer/windows/stt_helper_src/win_audio_endpoint.rs` + `capture.rs`:** MMDevice console/communications endpoint id, volume, mute, mix format; `/capture/device_diag`; auto endpoint role + cpal device match; capture gain experiment on STT copy only (`COUNTER_CAPTURE_GAIN_EXPERIMENT=1`).
* **`lib/core/services/desktop_voice_capture_endpoint.dart`:** Posts `endpoint_role: auto` on capture start; parses endpoint fields into diagnostics / `last_attempt_diag.txt`.
* **`docs/reports/DESKTOP_VOICE_HANDY_ENDPOINT_PARITY_2026-07-09.md`:** Handy vs Counter endpoint evidence; df696fc remains STT-unrecoverable.

## [2026-07-08] - P0 Desktop Voice: df696fc live quiet offline proof + capture diagnostics [engineering]

* **`test/fixtures/desktop_voice_wav/`:** Archived `scw_delmod_submit_df696fc_live_quiet*.wav` + `last_attempt_diag_df696fc_live_quiet.txt`; `golden_manifest.json` v4 documents offline whisper blocker (RMS gain variants do not recover "Southern").
* **`desktop_voice_stt_processing.dart` + `scripts/manual/benchmark_df696fc_quiet_whisper.ps1`:** STT-only variant bench on df696fc fixture — current/RMS055/040/030 all → `Computer Warehouse, DEL MOD, Submit.`; production gain stays OFF.
* **`desktop_voice_windows_audio_diagnostics.dart` + `desktop_voice_audio_capture.dart`:** Windows MMDevice endpoint volume logging; Counter vs Handy RMS ratio markers.
* **`voice_command_parser.dart` + `desktop_voice_widget.dart`:** `analyzeVoiceCommandReject` surfaces missing Southern / ambiguous Computer Warehouse in diag (no alias guess).
* **`desktop_stt_helper_service.dart`:** Useful-candidate latency blocker logged when `candidate_useful=no`; partial gate requires ≥1.5s + RMS≥0.012.

## [2026-07-08] - P0 Desktop Voice: intermittent mic no-signal classified separately [engineering]

* **`desktop_voice_audio_capture.dart`:** `noteCaptureStartFailed` vs `noteIntermittentListeningNoSignal` set distinct `no_signal_reason` values for `last_attempt_diag`; markers `DESKTOP_VOICE_CAPTURE_START_NO_SIGNAL` / `DESKTOP_VOICE_INTERMITTENT_MIC_NO_SIGNAL`.
* **`desktop_voice_widget.dart`:** Listening timeout calls intermittent classifier; capture-start failure calls start-failed classifier (not lumped with STT errors).

## [2026-07-08] - Timeline record category Save: immediate UI + new-category bind [shipped]

* Fixed Timeline record category Save: existing category changes now update local Timeline UI immediately, newly-created categories now bind to records, stale previous-category retention removed, and false success blocked.
* **`record_cache_helpers.dart`:** [shipped] `recordsStream` dedupe signature now includes category id/key so category-only edits emit a timeline refresh without page reload.
* **`record_crud.dart` + `record_optimistic.dart` + `record_timeline_vm.dart`:** [shipped] Optimistic apply updates flat cache and pending map, invalidates day view/index/lazy VM, returns `RecordOptimisticApplyResult`.
* **`timeline_record_edit_sheet.dart` + `record_edit_save_policy.dart`:** [shipped] Success toast gated on PB resolve + local apply + visible category + dual PATCH fields availability.
* **`test/record_category_edit_brain_test.dart`:** [shipped] Separate flows A–G: existing category B, create handoff category C, pending map, stream signature bust, PATCH dual fields, Plans control.

## [2026-07-08] - Timeline record newly-created category persistence [shipped]

* Fixed Timeline record newly-created category persistence by replacing stale previous-category retention with explicit selected-category apply, updating pending/flat record optimistic caches, invalidating Timeline read caches, and blocking false success when category apply fails.
* **`record_crud.dart` + `record_optimistic.dart`:** [shipped] `applyOptimisticRecordRowEdit` returns `RecordOptimisticApplyResult`; updates flat cache and `_optimisticPendingStartRecordMap`; fixed `_pendingStartRecordMatchesKey` tautology that matched any non-empty key.
* **`record_timeline_vm.dart`:** [shipped] `_invalidateTimelineReadCachesAfterRecordEdit` clears day view/index/lazy VM and refreshes warm snapshots on category-only edits.
* **`timeline_record_edit_sheet.dart` + `record_edit_save_policy.dart`:** [shipped] Success toast gated on `recordCategorySaveUiOutcomeAfterApply` (PB resolve + local apply + visible category match).
* **`test/record_category_edit_brain_test.dart`:** [shipped] Brain-path regression tests A–E (flat cache, pending map, PATCH dual fields, cache invalidation, Plans control).

## [2026-07-08] - Fixed record-specific newly-created category linking; Plans path was already working [shipped]

* **Root cause (post-d9f9fdc):** Timeline record PATCH re-normalized category with Life/default fallback, and `_upsertFlatRecordFromPbModel` restored the prior category whenever the server id differed from cache — so create→select→Save could toast success while the card stayed on Life. Plans never used that path.
* **`category_record_bridge.dart`:** [shipped] Record PATCH uses `allowFallback: false`; already-valid dual 15-char `category_id`/`category_link` are kept verbatim (no strip / Life rewrite).
* **`record_service.dart`:** [shipped] Upsert preserves prior category only when the server row cannot resolve a concrete local id — intentional category changes hydrate through.
* **`timeline_record_edit_sheet.dart` + `record_edit_save_policy.dart`:** [shipped] Fire-time draft ownership via `resolvePlanningEditDraftCategoryId`; Save passes that snapshot into optimistic + `updateRecord`; success toast still gated on PB relation resolve.
* **`test/timeline_record_edit_save_test.dart`:** [shipped] Separate Plans vs Records create→Save proofs (dual PATCH fields, upsert preserve rule, normalize verbatim keep).

## [2026-07-08] - P0 Desktop Voice: SCW comma parser, overlay layout, honest latency [engineering]

* **Parser:** Comma-segment leaf grammar accepts `Southern Computer Warehouse, DEL MOD, Submit.` without `Price Reporter` prefix; deepest safe path + `Submit` title; markers `DESKTOP_VOICE_EXACT_SCW_DELMOD_SUBMIT_PARSED`, `COMMA_SEGMENTS_PARSED`, `LEAF_CATEGORY_MATCH_WITHOUT_PARENT_PREFIX`.
* **Overlay:** Native pending/error cards 560px wide, 17pt title / 16pt body, multi-line word-wrap (no command ellipsis); pending lines: Запустить / path / title.
* **Latency:** `candidate_useful` gate — bad partials (e.g. `So then, compute theware.`) no longer count toward `<500ms` success; `stop_to_useful_candidate_ms` diagnostic added.
* **Capture:** `capture_stream_started`, `first_audio_frame_received`, `no_signal_detected` diagnostics; stream reset after no-signal; mic error does not call STT.

## [2026-07-08] - P0 Desktop Voice: whisper-tiny is command STT primary [engineering]

* **Offline engine bench (real WAVs):** On quiet CPAL `latest_command.wav`, Parakeet → `Tell them computer warehouse download submit.`; **whisper-tiny → `Southern Computer Warehouse, DEL MOD, Submit.`** Same whisper win on old Counter; Parakeet only matches Handy on the loud Handy WAV. Windows Speech unavailable (no en-US culture). Marker: `DESKTOP_VOICE_LOCAL_ENGINE_BENCHMARK_RUN`.
* **Policy:** `DesktopVoiceCommandSttPolicy` + `resolveProductionEngine()` default = **whisper-tiny**; Parakeet = fallback only (`DESKTOP_VOICE_WHISPER_TINY_PRIMARY_IF_BEST`, `DESKTOP_VOICE_PARAKEET_NOT_PRIMARY_IF_WORSE`).
* **Latency:** App/hotkey prewarm keeps whisper hot; CPAL mid-listen `/capture/partial_pcm` → `/transcribe/partial_audio` + `/transcribe/last_partial` for first candidate; full whisper final still ~1.3–1.5s hot — refinement may finish inside confirmation timer; no `writeRecord` before timer.
* **UI/safety:** Prior ≥16pt overlay + perceptual mic bars + safety gates unchanged.

## [2026-07-08] - P0 Desktop Voice: ≥16pt overlay, perceptual mic bars, latency trim, duration fix [engineering]

* **Overlay:** Native Win32 pill/cards DPI-scaled; min font **16pt**, title **19pt**, detail **16pt**; listening **340×68**, error/pending **480×136/124**, close hit **32×32**. Markers: `DESKTOP_VOICE_OVERLAY_MIN_FONT_16PT`, `*_CARD_LARGE_READABLE`, `NO_TINY_TEXT_ANYWHERE`.
* **Mic bars:** Perceptual/log display meter (not raw linear RMS); peak-hold + decay; visible for RMS ≈0.019. Markers: `MIC_BARS_PERCEPTUAL_SCALE`, `VISIBLE_FOR_LOW_RMS`, `NOT_RAW_LINEAR`.
* **STT gain:** Offline RMS-target (+7.9 dB, peak ceil 0.90) on live CPAL WAV → **identical** Parakeet transcript → **rejected** (`DESKTOP_VOICE_STT_GAIN_REJECTED_REASON`); no harmful peak-norm.
* **Latency:** Command silence trim (~690 ms on live take); latency markers `t_*` / `stop_to_first_candidate_ms`; Parakeet hot-path replay ≈200–270 ms (helper HTTP was the 2s wall when cold).
* **Diagnostics:** F32/stereo WAV duration via fmt-aware parse (`DESKTOP_VOICE_RAW_F32_WAV_DURATION_FIXED`); level/gain/overlay font fields in `last_attempt_diag`.
* **Offline note:** Whisper-tiny recovered `Southern Computer Warehouse, DEL MOD, Submit.` on the same quiet WAV where Parakeet stayed on `Tell them…`; capture still ~−10 dB vs Handy — device/volume instrumentation next, not aliases.

## [2026-07-08] - Newly-created category persists on running Timeline record Save [shipped]

* **Root cause:** After create→select on a running record, `_recordCategoryDualityForLocalId` often failed (biz-slug required + `_categoryPbRowIdKnownInRules` race). Optimistic apply then cleared category fields or wrote business slug into `records.category_id`, so breadcrumb fell back to “Life” while Save still showed success.
* **`category_record_bridge.dart` + `record_crud.dart`:** [shipped] Duality requires only a valid 15-char PB category row id; both `category_id` and `category_link` get that relation id; local cache keeps `categoryId` for display; unresolved explicit selection no longer strips the prior category.
* **`timeline_record_edit_sheet.dart` + `record_edit_save_policy.dart`:** [shipped] Success toast gated — no “saved” when a newly selected/created category cannot be patched; running Save still keeps `end_time` null.
* **`test/timeline_record_edit_save_test.dart`:** [shipped] Regression for create→select→running Save persistence, dual relation PATCH shape, and false-success guard.

## [2026-07-08] - Running Timeline record metadata/category Save no longer requires end_time [shipped]

* **Root cause:** Save used `isCreate = record.id.isEmpty`. Active/optimistic rows whose `id` was filtered as a hyphenated business UUID looked “empty”, so Save took the past-date create path and showed `edit_save_time_required` (“Укажите время начала и окончания…”) even when only category changed on a running record (`end_time` null).
* **`lib/features/shared/edit_sheet/record_edit_save_policy.dart` + `timeline_record_edit_sheet.dart`:** [shipped] Split Save modes (create / running metadata / stopped interval). Running metadata Save requires start only, keeps `end_time` null, does not stop the record. Updatable key accepts system id **or** business `record_id`.
* **`lib/data/records/record_crud.dart`:** [shipped] Category PATCH sends the same 15-char PB id to `records.category_id` and `records.category_link` (not business slug alone).
* **`test/timeline_record_edit_save_test.dart`:** [shipped] Regression: running category-only Save with null end succeeds; empty id+running no longer forces create time error; stopped interval validation intact.

## [2026-07-08] - Category picker create → Save persists new category [shipped]

* **Root cause (post-e5d8291):** create placeholder used local id `-1` (same as uncategorized). After create→select the sheet could show “RGH Products”, but Save’s `plans.category_id` PATCH was omitted (`_categoryRelationIdForPlanPatch` rejects `-1`), so PocketBase kept the original category (“Жизнь”).
* **`lib/data/categories/category_crud.dart`:** [shipped] Create uses a unique negative temp id (`newId()`), never `-1`; upgrade/remove/patch track that placeholder; handoff returns only after a concrete local id + PB row id are attached.
* **`lib/features/shared/planning_task_edit_sheet.dart` + `create_category_from_picker.dart`:** [shipped] Explicit Save flushes the fire-time draft snapshot (category included); draft ownership via `resolvePlanningEditDraftCategoryId` so picker/create overrides the original task category.
* **`test/category_picker_create_test.dart`:** [shipped] Regression: Жизнь → create nested RGH Products → Save draft/payload uses RGH, not Жизнь; `-1` handoff rejected; existing selection still persists.

## [2026-07-08] - P0 Desktop Voice: CPAL/WASAPI F32 capture replaces quiet MF 48k path [engineering; live-recapture pending]

* **Root cause of f69fb1b fail:** `record_windows` Media Foundation 48 kHz stereo PCM16 captured ~−10 dB quieter than Handy (and quieter than old 16 kHz mono). STT collapsed to `Computer warehouse subvailable submitted.`
* **`installer/windows/stt_helper_src/capture.rs` + `build_stt_helper_en.ps1`:** Helper now exposes `/capture/start|stop|level|cancel` via **cpal → WASAPI**, preferring **F32** at device-native rate/channels; writes raw+STT WAVs; no peak norm.
* **`desktop_voice_audio_capture.dart`:** Primary path = helper CPAL capture; **MF 48k stereo path disabled**; only safety fallback is old louder **16 kHz mono**. Diagnostics include `capture_backend` / `capture_api` / RMS/peak.
* Smoke: `capture_backend=cpal_wasapi`, `F32`, `48000×2` confirmed on device. Live SCW phrase still required before parity acceptance.

## [2026-07-08] - P0 Desktop Voice: readable overlay + last-attempt diag file [engineering]

* **`windows/runner/desktop_voice_native_overlay.cpp`:** Readable listening pill **260×52**; error expands to **380×96** card with title “Не удалось распознать” / “Could not recognize” (no tiny red one-liner); pending **380×92** with readable hint + visible progress; close hit **28×28**; title font **16px**.
* **`desktop_voice_last_attempt_store.dart`:** Persists `voice_samples/last_attempt_diag.txt` after each STT diag update so live captures can be pulled without reading overlay text.
* **Live WAV from installed 3c4abc1 (analyzed, not parity claim):** raw 48 kHz stereo + processed 16 kHz mono (~6820 ms); Parakeet `no_vad` → `So then computer warehouse Delmod Submit` (Handy still `Southern Computer Warehouse Del Mod, submit.`). User UX fail was unreadably tiny error text → fixed here.

## [2026-07-08] - P0 Desktop Voice: delayed transcribe after helper cold-start + Handy dark pill overlay [engineering; live-recapture pending]

* **`lib/core/services/desktop_voice_delayed_transcribe.dart` + `desktop_stt_helper_service.dart`:** [engineering] If recording stops while the STT helper is still loading, the saved WAV is queued as pending; post-stop wait extends to **45s cold-start**; once `final_transcribe_ready`, delayed `/transcribe/stop` runs on the saved PCM — no re-speak, no false “Recognizer unavailable” when helper becomes ready.
* **`desktop_stt_diagnostics.dart` + classifier:** [engineering] Diagnostics now include `pending_wav_after_stop`, `helper_ready_after_recording`, `delayed_transcribe_*`, raw+processed WAV paths/rates/channels, `overlay_renderer_active`, `failure_reason` / `final_text` / `final_transcript_source`.
* **`windows/runner/desktop_voice_native_overlay.cpp`:** [engineering] Replaced old light 340×72 gray panel with Handy-style compact dark pill (~180×40 listening: left mic, center bars, right close, no debug text).
* **Tests:** `desktop_voice_delayed_transcribe_test.dart` + overlay state contracts; full `flutter test` 361 pass. Live capture still required before parity claim.

## [2026-07-07] - P0 Desktop Voice capture/VAD parity with Handy [engineering; live-recapture + installer pending]

* **`lib/core/services/pcm_audio_utils.dart`:** [engineering] Added Handy-parity capture preprocessing as pure, unit-tested functions — `pcm16BytesToFloat`/`floatToPcm16Bytes`, `downmixInterleavedFloatToMono`, high-quality windowed-sinc (Hann, 16 zero-crossings) `resampleFloatHighQuality`, channel-aware `pcm16ToWavBytesFull`, and `processNativeCaptureForStt` (native PCM16 → float mono downmix → HQ resample to 16 kHz → PCM16, **no peak normalization**).
* **`lib/core/services/desktop_voice_audio_capture.dart`:** [engineering] Captures device-native **48 kHz stereo PCM16** (avoids Media Foundation forced 16 kHz downsample) with safe fallback to 16 kHz mono; saves `latest_command_raw.wav` (native) + processed `latest_command.wav` (16 kHz mono STT); full capture-parity diagnostics + markers (`DESKTOP_VOICE_NATIVE_RATE_CAPTURE`, `RAW_CAPTURE_WAV_SAVED`, `STT_READY_WAV_CREATED`, `HIGH_QUALITY_RESAMPLE_USED`, `NO_HARMFUL_PEAK_NORMALIZATION`).
* **`installer/windows/wav_stt_replay/src/main.rs` + `build_stt_helper_en.ps1`:** [engineering] Added `light_endpoint` VAD mode to the replay matrix; benchmark across Handy + old Counter WAVs selected **`no_vad`** for command-length audio (best DEL MOD, matches Handy app, no cut words) — production helper `trim_silence` patched to no-op.
* **`scripts/manual/compare_desktop_voice_vad_modes.ps1`:** [engineering] Full pipeline × fixture VAD comparison; `golden_manifest.json` + `desktop_voice_wav_stt_benchmark.dart` add Handy reference fixture + `captureParityReport()` (Handy vs old vs new Counter).
* **`test/desktop_voice_audio_pipeline_test.dart` + `desktop_voice_command_acceptance_test.dart`:** [engineering] Resampler/downmix/no-peak-norm/native-metadata + three-way benchmark tests; safety tests block raw garbage STT (`Solvan Computer Warehouse, Delmore, Submit.`) from creating a parent-only record. `flutter analyze` 0 errors; full `flutter test` 354 pass.
* **Pending (hard-blocked):** live re-capture of the SCW phrase through the new path (needs mic) and clean-tree helper/release/installer rebuild (`build_sha != dev`). Parity is **not** claimed until the new native-capture WAV is replayed vs Handy.

## [2026-07-07] - Category picker create → immediate attach [shipped]

* **`lib/features/shared/planning_task_edit_sheet.dart` + `lib/features/categories/create_category_from_picker.dart`:** [shipped] Newly created picker categories stay selected on the plan/list draft — removed `pairs.first` fallback that overwrote explicit handoff ids; `resolveEditFieldCategoryIdValues` preserves picker/create selection.
* **`lib/data/categories/category_crud.dart`:** [shipped] Post-create local id now matches `_buildCategoryTreeFromFlat` (biz slug hash, not PB row hash); skip immediate full category refetch after create so optimistic tree is not wiped before attach.
* **`test/category_picker_create_test.dart`:** [shipped] Regression tests for create→select→draft handoff without reopen/refetch.

## [2026-07-07] - P0 Desktop Voice GOLOS same-WAV parity verified [shipped]

* **`installer/windows/wav_stt_replay/`:** [shipped] Standalone same-WAV Parakeet replay — proves GOLOS-equivalent raw ceiling `Solvan Computer Warehouse, Delmore, Submit.` on SCW fixture; peak normalization harms output.
* **`lib/core/services/desktop_stt_helper_service.dart`:** [shipped] Removed STT peak normalization; Counter HTTP helper now matches GOLOS-equivalent transcript on same WAV.
* **`scripts/manual/compare_desktop_voice_wav_stt.ps1`:** [shipped] A/B Counter helper vs GOLOS-equivalent pipelines.
* **`scripts/manual/build_counter_installer.ps1`:** [shipped] ISCC discovery includes `%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe`.
* **`docs/reports/DESKTOP_VOICE_GOLOS_PARITY_AUDIT_2026-07-07.md`:** [shipped] Handy black-box baseline from log+WAV; same-model replay; glossary mechanism explicitly **unproven**.

## [2026-07-07] - P0 Desktop Voice raw STT GOLOS parity [shipped]

* **`lib/core/services/desktop_voice_audio_capture.dart`:** [shipped] GOLOS 180+30 ms post-roll before mic stop so trailing command phonemes are not clipped.
* **`installer/windows/build_stt_helper_en.ps1`:** [shipped] Patches backend-rs VAD to GOLOS parity (350 ms pad + 700 ms tail keep); rebuilds `counter_stt_helper.exe`.
* **`lib/core/services/desktop_stt_orchestrator.dart` + `desktop_stt_quality_evaluation.dart`:** [shipped] `stt_quality_mode=raw_transcript_evaluation` — raw Parakeet text is command source; postprocess logged only, not counted as STT quality.
* **`test/fixtures/desktop_voice_wav/` + `desktop_voice_wav_stt_benchmark.dart`:** [shipped] Real failing SCW WAV replay regression vs baseline `Solvent computer warehouse still model submit`.
* **`lib/core/services/desktop_voice_command_normalize.dart`:** [shipped] Blocks parent-only SCW records when DEL MOD/Submit tokens stay unresolved (`DESKTOP_VOICE_PARENT_ONLY_RECORD_BLOCKED_WITH_UNRESOLVED_TOKENS`).
* **`docs/reports/DESKTOP_VOICE_GOLOS_PARITY_AUDIT_2026-07-07.md`:** [shipped] GOLOS vs Counter pipeline diff audit.

## [2026-07-07] - P0 Desktop Voice STT quality upgrade [shipped]

* **`lib/core/services/desktop_stt_engine.dart`**, **`desktop_stt_orchestrator.dart`**, **`desktop_stt_cloud_service.dart`:** [feat] STT engine abstraction with Best Quality (cloud PB endpoint) → Fast Local (parakeet) → Offline Fallback ladder; no client-side API secrets.
* **`lib/core/services/desktop_voice_glossary.dart`**, **`desktop_voice_recognition_postprocess.dart`:** [feat] Live category glossary pack + glossary-biased postprocess (Sovent→Southern Computer Warehouse, they'll not→DEL MOD) before domain resolver.
* **`pb_hooks/ai.transcribe_command.pb.js`:** [feat] Secure `POST /api/ai/transcribe-command` backend route (OPENAI_API_KEY server env only).
* **`lib/core/services/desktop_stt_benchmark_harness.dart`**, **`scripts/manual/benchmark_desktop_voice_stt.ps1`**, **`test/desktop_voice_stt_quality_test.dart`:** [test] Golden phrase benchmark with ≥95% quality gate.
* **`installer/windows/build_stt_helper_en.ps1`:** [fix] Expanded Parakeet initial_prompt with GSA vocabulary.

## [2026-07-07] - P1 Desktop Voice compact overlay UX [shipped]

* **`lib/features/shared/desktop_voice_widget.dart`**, **`desktop_voice_capsule.dart`**, **`desktop_voice_overlay_service.dart`**, **`desktop_voice_confirmation_timer.dart`**, **`desktop_voice_correction_sheet.dart`:** [feat] GOLOS/Handy-style compact overlay with listening mic bars, processing, 3-second pending-confirmation progress fill, click-to-correct sheet, auto-commit with captured start time, and brief success auto-close; no debug UI in release.
* **`windows/runner/desktop_voice_native_overlay.cpp`:** [feat] Native pending state with progress bar and body-click correction hook.
* **`test/desktop_voice_confirmation_timer_test.dart`**, **`test/desktop_voice_overlay_state_test.dart`**, **`test/desktop_voice_widget_e2e_test.dart`:** [test] Timer gate, pending UI, and no writeRecord-before-commit coverage.

## [2026-07-07] - P0 Desktop Voice productization [shipped]

* **`backend-rs` / `counter_stt_helper.exe`:** [fix] `/transcribe/stop` always runs final WAV inference; partial returned only as `partial_hint` / `partial_fallback` with `final_transcript_source`, `used_partial_as_final`, `stop_return_reason`, `final_inference_latency_ms` diagnostics (no more fresh-partial shortcut).
* **`lib/data/voice_domain_resolver.dart`**, **`voice_command_parser.dart`:** [fix] Literal parser and domain resolver candidates compared on every command; deepest live category path wins over shallow exact parent matches (e.g. `Work > Price Reporter > Planning` not parent + wrong title); full-tree BLINK paths; parent rejection and top-5 candidate diagnostics.
* **`lib/core/services/desktop_stt_helper_service.dart`**, **`desktop_stt_diagnostics.dart`:** [fix] Surfaces `partial_text`, `final_text`, `final_transcript_source`, `used_partial_as_final`, `stop_return_reason`, `final_inference_latency_ms` from helper stop response.
* **`test/desktop_voice_domain_resolver_test.dart`**, **`test/desktop_voice_command_acceptance_test.dart`:** [fix] Work > Price Reporter > Planning child category, BLINK, and negative no-garbage-record coverage.

* **`backend-rs` / `counter_stt_helper.exe`:** [fix] `/status` exposes `final_transcribe_ready`, `model_loaded`, `warmup_done`, `streaming_ready`, `reason_if_not_ready`; `ready=true` only when weights are in memory; partial inference gated until loaded.
* **`lib/core/services/desktop_stt_helper_service.dart`:** [fix] Polls `final_transcribe_ready`, waits before transcribe, retries saved WAV on `parakeet not loaded`, Windows System.Speech fallback on saved WAV; WAV duration from file header when diagnostics showed 0ms.
* **`lib/core/services/desktop_voice_user_error.dart`:** [fix] Readiness race vs empty transcript vs recognizer unavailable classification markers.
* **`windows/runner/desktop_voice_native_overlay.cpp`:** [fix] Mic bars repositioned inside 72px listening overlay (bars were painted at y=82 and clipped invisible after compact overlay resize).
* **`lib/core/services/desktop_main_window.dart`:** [fix] Main window always maximizes on launch and tray restore (with retry after window_manager bounds restore).
* **`lib/data/voice_command_parser.dart`:** [fix] STT repairs `Porter Plenty` / `Importer plenty` → `Price Reporter Planning` before scope parse.
* **`lib/core/services/desktop_voice_user_error.dart`**, **`desktop_stt_helper_service.dart`**, **`desktop_voice_widget.dart`:** [fix] STT failures classified as mic no signal / recognizer unavailable / empty transcript / parser rejected / write failed; empty Heard no longer shows command-not-recognized; saved WAV sent to helper with full transcribe diagnostics markers.
* **`lib/shell/shell_more_menu.dart`**, **`lib/features/profile/desktop_voice_settings_desktop.dart`:** [fix] More menu voice diagnostics dev-gated only; release settings show collapsed technical diagnostics with copy/log/WAV/clear support buttons; dev simulate/acceptance buttons hidden in release.
* **`lib/core/services/desktop_voice_audio_capture.dart`**, **`desktop_voice_overlay_service.dart`:** [fix] Reactive peak-driven mic bars preserved with PCM/RMS/peak diagnostics and overlay level event markers.
* **`installer/windows/counter.iss`**, **`lib/core/services/desktop_main_window.dart`:** [fix] Installer force-closes `counter.exe` and `counter_stt_helper.exe`; main window defaults to maximized/full-height when saved bounds are tiny or overlay-contaminated.
* **`scripts/manual/smoke_desktop_voice_installed.ps1`**, **`test/desktop_voice_installed_identity_test.dart`:** [fix] Installed-app smoke and classification regression tests.

## [2026-07-06] - Category picker create selection handoff [shipped]

* **`lib/data/categories/category_crud.dart`:** [fix] `addNestedCategory` returns created local `CategoryRule.id` from placeholder upgrade (not `bool`); sibling duplicate returns existing id.
* **`lib/features/categories/create_category_from_picker.dart`:** [fix] Create submit uses Brain-returned id directly; `resolveEditFieldCategoryId` prefers `categoryExists` over stale `allCategoryIdPathPairs` fallback.
* **`lib/features/shared/planning_task_edit_sheet.dart`**, **`timeline_record_edit_sheet.dart`**, **`category_recursive_tree.dart`:** [fix] Edit draft/display/category field use resolved id so newly created categories apply immediately (Plans/Lists/Timeline including stopped/completed records).
* **`test/category_picker_create_test.dart`:** [fix] Selection-handoff and id-return regression tests.

## [2026-07-06] - Category picker parent-context fix [shipped]

* **`create_category_from_picker.dart`:** [fix] Explicit [CategoryPickerCreateTarget] for every create action; sibling-scoped id resolution only (removed global `classifyCategoryDisplayNameInput` / `findActiveLocalCategoryIdByDisplayName` fallback that could attach creates to the wrong parent, e.g. Work instead of Price Reporter); dialog title shows target parent.
* **`category_recursive_tree.dart`:** [fix] Row trailing `+` moved outside row `InkWell`; folder-scoped **Add category inside %s** after expanded children; root top/bottom rows labeled **Add root category**; parent passed from exact row/folder context only.
* **`test/category_picker_create_test.dart`:** [fix] Parent-id recording tests for Price Reporter vs Work, root create, and folder-scoped targets.

## [2026-07-06] - Category picker create UX fix [shipped]

* **`lib/features/categories/category_recursive_tree.dart`:** [fix] Picker sheet uses fixed height (~82% viewport), always-visible top **+ Add category** row, sticky bottom **+ Add category**, trailing **+** on every tree row (`AppIconButton` / `add_subcategory`), and search-miss **Create "name"** — fixes Plans/Timeline edit pickers where create was hidden below the fold.
* **`lib/features/categories/create_category_from_picker.dart`:** [fix] Resolve newly created child category local id via sibling lookup under parent.
* **`test/category_picker_create_test.dart`:** [fix] Regression tests for picker create chrome keys and list tiles.

## [2026-07-06] - Create category from picker [shipped]

* **`lib/features/categories/category_recursive_tree.dart`**, **`create_category_from_picker.dart`:** [shipped] Shared category tree picker sheet now includes search, “New category”, and contextual Create “name”; compact create dialog stacks above the picker without closing parent edit sheets; newly created category auto-selects via `CategoryTreeSheetPicked`.
* **`lib/features/planning/settings/default_plan_category_search.dart`**, **`lib/features/wear/wear_timer_screen.dart`:** [shipped] Planning default-time category search and Wear start picker reuse the same create-from-picker flow; offline disables create with one clear message.
* **`lib/features/shared/timeline_record_edit_sheet.dart`:** [shipped] Category field stays enabled when no categories exist so first category can be created from the record edit sheet.
* **`lib/l10n/langs/en.dart`**, **`lib/l10n/langs/ru.dart`**, **`test/category_picker_create_test.dart`:** [shipped] EN/RU picker strings + filter unit tests.

## [2026-07-06] - Planning quick-add test (B3 prerequisite) [shipped]

* **`test/planning_page_quick_add_test.dart`:** [shipped] Quick-add chrome (`PlanningQuickAddTagStrip`, field, Add button); empty submit no-op; typed submit + keyboard done no-throw without PocketBase; optimistic task list shell smoke.
* **`docs/reports/PLANNING_PAGE_SEAM_AUDIT_2026-07-06.md`:** [shipped] §7.3 item 4 complete — B3 extraction unblocked while planning_page_* tests stay green.
* **Verification:** `flutter test test/planning_page_*` 12 passed; full suite 260 passed.

## [2026-07-06] - Planning grouped list UI split (Stage B2) [shipped]

* **`lib/features/planning/planning_page.dart`:** [shipped] UI-only extract S2/S3 grouped list rendering (~2202→~2095 lines); reorder handlers and page state unchanged.
* **`lib/features/planning/widgets/planning_category_grouped_list.dart`:** [shipped] `PlanningCategoryGroupedList` — category-sort buckets + breadcrumb headers.
* **`lib/features/planning/widgets/planning_tag_grouped_list.dart`:** [shipped] `PlanningTagGroupedList` — tags-sort buckets in master-bar order.
* **`lib/features/planning/widgets/planning_group_section.dart`:** [shipped] Shared `PlanningGroupedReorderBucket`, `PlanningCategoryGroupHeader`, `PlanningGroupedPlanCardRowBuilder`.
* **`docs/APP_STRUCTURE.md`**, **`docs/APP_STRUCTURE_DETAILED.md`**, **`docs/reports/PLANNING_PAGE_SEAM_AUDIT_2026-07-06.md`:** [shipped] B2 complete; B3 quick-add next (tests deferred).
* **Verification:** B0 tests green; `flutter test` 255 passed; `architecture_guard.ps1 -Strict` 0 violations.

## [2026-07-06] - Planning page low-risk split (Stage B1) [shipped]

* **`lib/features/planning/planning_page.dart`:** [shipped] UI-only extract S1/S5/S6 (~2394→~2202 lines); orchestration, Time View host, card row, CRUD paths unchanged.
* **`lib/features/planning/widgets/planning_list_grouping.dart`:** [shipped] Pure category/tag sort helpers (`planningTaskSortCmp`, `groupPlanningTasksByCategoryPath`, `groupPlanningTasksByMasterBar`, `planningGroupIdsInMasterBarSequence`, `planningTagSortMasterBarOrder`).
* **`lib/features/planning/widgets/planning_frozen_day_list.dart`:** [shipped] Read-only offscreen/frozen day `PlanCard` list (`PlanningFrozenDayList`).
* **`lib/features/planning/widgets/planning_select_mode_header.dart`:** [shipped] Bulk selection mode chrome (`PlanningSelectModeHeader`).
* **`docs/APP_STRUCTURE.md`**, **`docs/APP_STRUCTURE_DETAILED.md`**, **`docs/reports/PLANNING_PAGE_SEAM_AUDIT_2026-07-06.md`:** [shipped] B1 complete; B2 grouped-list extraction next.
* **Verification:** B0 tests green; `flutter test` 255 passed; `architecture_guard.ps1 -Strict` 0 violations.

## [2026-07-06] - Planning page host test coverage (Stage B0) [shipped]

* **`test/planning_page_host_contract_test.dart`:** [shipped] `PlanningPage` pumps under `ShellLayoutScope`; empty-day `PlanningDayEmptyState`; Time sort + optimistic task → Time View scroll surface; barrel exports `PlanningPage` / `PlanningSwipeWrapper`; no PocketBase network; bounded pumps only.
* **`test/planning_page_list_modes_test.dart`:** [shipped] Empty day survives Category/Time/Tags/Custom sort taps; seeded optimistic task renders list shell per mode; `PlanSortMode` persistence indices stable.
* **`docs/reports/PLANNING_PAGE_SEAM_AUDIT_2026-07-06.md`:** [shipped] B0 complete — **B1 low-risk split allowed only while these tests stay green**; selection/quick-add tests (§7.3 items 3–4) still deferred.
* **Verification:** `flutter analyze --no-fatal-infos --no-fatal-warnings` OK; `flutter test` 255 passed; `architecture_guard.ps1 -Strict` 0 violations.

## [2026-07-06] - Planning page seam audit (Stage B report-only) [shipped]

* **`docs/reports/PLANNING_PAGE_SEAM_AUDIT_2026-07-06.md`:** [shipped] Seam map for `planning_page.dart` (2394 lines); verdict **NEEDS TESTS FIRST**; staged B0–B6 plan; Time View host no-touch boundaries; test gap analysis (no `PlanningPage` widget tests).
* **`scripts/manual/structure_doc_file_guides.py`:** [shipped] Guide entry for planning page seam audit report.

## [2026-07-06] - Category view decomposition (Stage A alternate) [shipped]

* **`lib/features/categories/`:** [shipped] UI-only split of `category_list_view.dart` (~1727→~330 lines) into `category_row_widget.dart`, `category_editor_sheet.dart`, `category_appearance_sheet.dart`, `category_tag_input_field.dart`, `category_helpers.dart`; `CategoriesPage` entrypoint unchanged; re-exports preserved; zero user-visible behavior change.
* **`docs/APP_STRUCTURE.md`**, **`docs/APP_STRUCTURE_DETAILED.md`:** [shipped] Categories folder file list updated; detailed guide regenerated.
* **Verification:** `flutter analyze --no-fatal-infos --no-fatal-warnings` OK; `flutter test` 248 passed; `architecture_guard.ps1 -Strict` 0 violations.

## [2026-07-06] - Calendar view decomposition (Stage A) [shipped]

* **`lib/features/calendar/`:** [shipped] UI-only split of `calendar_view.dart` (~1142→~276 lines) into `calendar_chrome_header.dart`, `calendar_month_grid.dart`, `calendar_week_grid.dart`, `calendar_day_panel.dart`, `calendar_day_events.dart`, `calendar_helpers.dart`; `CalendarView` entrypoint unchanged; zero user-visible behavior change.
* **`docs/APP_STRUCTURE.md`:** [shipped] Calendar folder file list updated for architecture guard.
* **Verification:** `flutter analyze --no-fatal-infos --no-fatal-warnings` OK; `flutter test` 248 passed; `architecture_guard.ps1 -Strict` 0 violations.

## [2026-07-06] - Large file decomposition plan (report-only) [shipped]

* **`docs/reports/LARGE_FILE_DECOMPOSITION_PLAN_2026-07-06.md`:** [shipped] Staged queue Stage A–E for 31 Dart files ≥600 lines; per-file responsibility maps for `plan_service`, `planning_page`, categories, edit sheets, lists, calendar; risk/test matrix; first prompt = Stage A calendar or category sheet extract.
* **`scripts/manual/structure_doc_file_guides.py`:** [shipped] Guide entries for decomposition plan; restored `what` on final audit report entry.

## [2026-07-06] - Final structure audit + Structure Growth Law [shipped]

* **`docs/reports/FINAL_STRUCTURE_AUDIT_2026-07-06.md`:** [shipped] Full repo inventory (538 tracked), boundary audit (guard 0 violations), long-file watchlist, duplicate-responsibility table, verdict **ACCEPTED WITH WATCHLIST**.
* **`docs/ARCHITECTURE.md` §11, `docs/APP_STRUCTURE.md` §7, `AGENTS.md`, `AGENT_NAVIGATION.md`:** [shipped] Permanent Structure Growth Law — integrate into existing layers, split mixed/large files early, new-feature checklist.
* **`scripts/manual/structure_doc_file_guides.py`:** [shipped] Guide entry for final audit report; fixed `FINAL_STRUCTURE_PARITY` `what` field.
* **`docs/APP_STRUCTURE_DETAILED.md`:** [shipped] Regenerated (538 files, quality gate OK).

## [2026-07-07] - Calendar mobile layout + date-tap Add plan UX [shipped]

* **Root cause:** `DateFormat.yMMMM` RU title («июль 2026 г.») wrapped in cramped `NavigationBar`-era header row; full-cell selection decoration in `CalendarMonthDayCell` stretched/clipped day numbers; no primary action after date tap (user had to switch to Plan tab).
* **`calendar_chrome_header.dart`:** [shipped] Stacked title row with bounded horizontal padding, `maxLines: 1`, `calendarMonthHeaderTitle()` without orphan «г.», 16px title on phone width.
* **`calendar_month_grid.dart`:** [shipped] Fixed 28×28 `_CalendarDayNumberBadge` for selection/today — grid row height stable, no full-cell border stretch.
* **`calendar_week_grid.dart`:** [shipped] Week compact strip uses same fixed badge selection pattern.
* **`calendar_day_panel.dart` + `calendar_view.dart`:** [shipped] Primary `AppButton` «Добавить план» / «Add plan» opens existing `openEditDialog` draft with selected date prefilled (09:00 wall); live planning stream shows new plan immediately.
* **`lib/l10n/langs/en.dart`**, **`ru.dart`:** [shipped] `calendar_add_plan`.
* **Scope:** bottom nav / PWA shell untouched.
* **Verification:** analyze + test (280) + web + APK green.

## [2026-07-07] - P0 iPhone bottom nav + radial menu viewport clamp [shipped]

* **Root cause:** Material `NavigationBar` with 5 labeled destinations wraps/clips on ~390px (worse on iOS web text scaling); `ListsSemicircleMenuOverlay` / `SemicirclePlanningMenuOverlay` used a fixed 300px canvas with `Clip.none`, so satellites overflowed when the card menu anchor was near the right edge.
* **`lib/shell/shell_bottom_navigation.dart`:** [shipped] `ShellCompactBottomNav` — equal-width columns, `maxLines: 1` labels, `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.0)`, compact l10n keys below 420px; replaces `NavigationBar` on phone shell (APK + mobile web).
* **`lib/core/widgets/radial_menu_viewport.dart`:** [shipped] `RadialMenuViewport.clampCanvasTopLeft()` shifts menu hub inside safe bounds using `MediaQuery.viewPadding`.
* **`lists_card.dart`**, **`planning_menu_overlay.dart`:** [shipped] viewport-clamped canvas position + `Clip.hardEdge`; action labels single-line.
* **`lib/l10n/langs/en.dart`**, **`ru.dart`:** [shipped] `tab_*_compact` / `tab_calendar_compact` short nav labels.
* **Verification:** analyze + test + web + APK green.

## [2026-07-06] - P0 mobile web / APK layout parity + iPhone PWA shell [shipped]

* **`web/index.html`:** [shipped] Added `viewport` (`width=device-width`, `viewport-fit=cover`), `apple-mobile-web-app-capable`, shell CSS (`#FAFAF8` full-bleed, no double safe-area padding), `theme-color` `#111111`, and `icons/Icon-180.png` apple-touch-icon — fixes mobile browser ~980px layout width (side nav at phone size) and iPhone PWA white bars.
* **`web/manifest.json`:** [shipped] Replaced default Flutter blue with app shell colors (`theme_color` `#111111`, `background_color` `#FAFAF8`); explicit `./` `start_url`/`scope` for GitHub Pages `/Counter/`.
* **`lib/core/shell_adaptive.dart`:** [shipped] `shellUsesCompactPhoneLayout(width)` — shared phone-width breakpoint (<900) instead of blanket `kIsWeb` for metrics/gestures.
* **`lib/features/planning/plan_time_gesture_contract.dart`**, **`time_view_interaction_block.dart`**, **`lib/core/picker_entry_modes.dart`:** [shipped] Phone-width web uses APK touch drag thresholds, long-press move, and calendar/dial pickers; wide web/desktop unchanged.
* **`lib/shell/life_os_dashboard.dart`:** [shipped] Bottom `NavigationBar` wrapped in `SafeArea(top: false)` for iPhone home-indicator padding.
* **Verification:** `flutter analyze`, `flutter test`, `flutter build web --base-href="/Counter/"`, `flutter build apk --target-platform android-arm64` green.

## [2026-07-03] - Ban generic doc file wrappers in APP_STRUCTURE_DETAILED [shipped]

* **`scripts/manual/structure_doc_file_guides.py`:** [shipped] Curated EN+RU for all `docs/*.md`, `docs/reports/*`, `docs/website/*` — ROADMAP, UX_CONTRACT, POCKETBASE_MANIFEST, PROJECT_KNOWLEDGE_PACK, APP_STRUCTURE_DETAILED, website matrix/wireframe/scope, etc.
* **`scripts/manual/generate_app_structure_detailed.py`:** [shipped] `build_guide()` routes `docs/` through doc guides first; quality gate bans `Markdown-документ`, doc generic triples, and listed EN leftovers in RU; `pick()` skips `has_semi_russian_or_english_leak`.
* **`scripts/manual/structure_ru_class_adapters.py`**, **`structure_ru_helpers.py`:** [shipped] `BANNED_GENERIC_DOC_WRAPPERS`; `_governing_doc_field` delegates to doc guides; `delete_en_to_ru()` tails for Cursor/env/widgets phrases.
* **`docs/APP_STRUCTURE_DETAILED.md`:** [shipped] Regenerated — 0 generic doc wrappers, 0 listed EN leftovers in RU blocks.

## [2026-07-03] - Ban generic platform file wrappers in APP_STRUCTURE_DETAILED [shipped]

* **`scripts/manual/structure_platform_file_guides.py`:** [shipped] New Tier C platform/installer guides — exact paths (main.cpp, CMakeLists, STT scripts, xcconfig, pbxproj, app_icon.ico) + extension heuristics; names Gradle/Xcode/CMake/Inno Setup tool + artifact + break-if-deleted.
* **`scripts/manual/generate_app_structure_detailed.py`:** [shipped] Removed generic RU from `platform_guide` fallback; `pick()` prefers adapted over stale existing; quality gate bans `Файл сборки`, embedder/config wrappers, generic what/why/resp triples; per-platform `delete_ru`.
* **`scripts/manual/structure_ru_class_adapters.py`**, **`structure_file_ru_curated.py`**, **`structure_ru_helpers.py`**, **`structure_guide_data.py`:** [shipped] `BANNED_GENERIC_PLATFORM_WRAPPERS`; route platform paths through `platform_file_ru_field`; richer EN for key platform files.
* **`docs/APP_STRUCTURE_DETAILED.md`:** [shipped] Regenerated — 0 generic platform wrappers in RU, quality gate OK.

## [2026-07-03] - APP_STRUCTURE_DETAILED lib guides + RU quality gate hardening [shipped]

* **`scripts/manual/structure_lib_file_guides.py`:** [shipped] New curated EN+RU for mandatory lib files (`planning_view.dart` barrel, `timeline_view.dart`, `voice_input_sheet.dart`, `app_build_info.dart`, `app_colors.dart`); `feature_file_guide()` + `describe_contains()` from symbols/exports (no `implementation details in the source file`).
* **`scripts/manual/generate_app_structure_detailed.py`:** [shipped] Quality gate fails on empty folder RU (`Зачем нужна`), `BANNED_EN_IN_RU` (`required for `, CocoaPods/macOS leftovers, `: ,` punctuation), and placeholder scan; `dart_exports()` + expanded `SYMBOL_RE`.
* **`scripts/manual/structure_role_guides.py`**, **`structure_folder_ru_curated.py`**, **`structure_guide_data.py`**, **`structure_ru_helpers.py`:** [shipped] Route `lib/features/*` through feature guides; profile folder RU; `delete_en_to_ru()` always applied in folder RU merge.
* **`docs/APP_STRUCTURE_DETAILED.md`:** [shipped] Regenerated — 0 empty RU fields, 0 `implementation details in the source file`, 0 EN leftovers in RU delete/desc fields, quality gate OK.

## [2026-07-03] - APP_STRUCTURE_DETAILED empty RU + EN-wrapper quality gate [shipped]

* **`scripts/manual/generate_app_structure_detailed.py`:** [shipped] `ru_line_value()` fixes empty-field detection (markdown `**` false positive); quality gate fails on empty required RU prefixes + `Fulfill`/`Source file`/`Role:`/`required for current app behavior`; platform paths before role lookup; no English APP_STRUCTURE role in RU `Связано с`.
* **`scripts/manual/structure_ru_class_adapters.py`:** [shipped] `.cursor/`, `pb_hooks/`, `env.dart.example`, `.pb.js` adapters; Cyrillic-heavy platform RU (Gradle, ProGuard, Info.plist, CMake, web assets); `_is_generic_en()` strips generic EN before RU merge.
* **`scripts/manual/structure_role_guides.py`:** [shipped] Per-file `UI-модуль` feature RU; `lib/services/`, `lib/app_shell.dart`, `lib/main.dart`, `lib/l10n/` humanize blocks.
* **`docs/APP_STRUCTURE_DETAILED.md`:** [shipped] Regenerated — 0 empty RU fields, 0 `NEEDS HUMAN DESCRIPTION`, 0 generic EN wrappers in RU, quality gate OK; header SHA stamped at generation (`fa4fcea` tree, commit `108065e`).

## [2026-07-03] - Ban generic RU wrappers in structure guide [shipped]

* **`scripts/manual/structure_ru_class_adapters.py`:** [shipped] `BANNED_GENERIC_RU_WRAPPERS`; removed `Подмодуль`/`Файл … в каталоге`/`См. также:` fallbacks; `_cmake_file_field`, `_platform_native_file_field`; `_dart_file_field` uses `humanize_guide` RU.
* **`scripts/manual/structure_folder_ru_lib.py`:** [shipped] App-specific curated RU for all remaining `lib/**` folders (`time_view`, `plan_time_task_card`, brain slices, platform subfolders).
* **`scripts/manual/structure_role_guides.py`**, **`structure_en_ru_adapt.py`**, **`structure_guide_data.py`:** [shipped] Stricter RU merge (no `NEEDS` in output); `ensure_folder_ru` always fills fields; quality gate fails on any `NEEDS HUMAN DESCRIPTION`.
* **`generate_app_structure_detailed.py`:** [shipped] `finalize_file_guide` prefers humanize RU; banned generic patterns in RU scan; duplicate empty-`what_ru` guard.
* **`docs/APP_STRUCTURE_DETAILED.md`:** [shipped] Regenerated — 0 old/new generic wrappers, 0 `NEEDS HUMAN DESCRIPTION`, quality gate OK.

## [2026-07-03] - Remove semi-Russian wrappers from structure guide [shipped]

* **`scripts/manual/structure_ru_class_adapters.py`:** [shipped] Class-based RU adapters (Android/iOS/platform/lib/docs/tests); `sanitize_ru_prose()`; banned semi-Russian wrapper quality gate; generic file fallback (no `Назначение файла:` / `Сегмент` prefixes).
* **`scripts/manual/structure_en_ru_adapt.py`:** [shipped] Removed EN wrapper fallbacks; routes through class adapters + `NEEDS HUMAN DESCRIPTION` only when no real RU.
* **`structure_folder_ru_curated.py`**, **`structure_file_ru_curated.py`:** [shipped] Expanded curated RU for mandatory platform/lib/docs entries (`android/app/`, `ios/Runner*`, `lib/core/*`, governing docs, Windows workflow).
* **`generate_app_structure_detailed.py`**, **`structure_guide_data.py`:** [shipped] Quality gate bans semi-Russian wrappers + English leakage in RU blocks; checks value text only (not `- **Слой:**` labels).
* **`docs/APP_STRUCTURE_DETAILED.md`:** [shipped] Regenerated — 0 banned wrapper phrases, 0 `NEEDS HUMAN DESCRIPTION`.

## [2026-07-03] - Replace RU filler with real structure explanations [shipped]

* **`scripts/manual/structure_en_ru_adapt.py`:** [shipped] EN→RU adaptation from guide meaning; `BANNED_MEANINGLESS_RU_FILLER` quality gate; fails on `NEEDS HUMAN DESCRIPTION`.
* **`scripts/manual/structure_folder_ru_curated.py`**, **`structure_file_ru_curated.py`:** [shipped] Curated meaningful RU for mandatory folders/files (`.github/`, `lib/*`, platform, `deploy.yml`, `MainActivity.kt`, `launch_background.xml`, `android.ps1`).
* **`generate_app_structure_detailed.py`**, **`structure_guide_data.py`:** [shipped] Removed path-template RU; semantic checks for banned filler, duplicate RU, NEEDS HUMAN markers.
* **`docs/APP_STRUCTURE_DETAILED.md`:** [shipped] Regenerated with owner-readable RU adapted from EN (not `Папка … Life OS` / `native-обёртка` filler).

## [2026-07-03] - Root/tooling structure guide humanization [shipped]

* **`scripts/manual/structure_ru_helpers.py`:** [shipped] New `complete_all_ru_fields()` + `delete_en_to_ru()` — always fills folder/file `*_ru` fields; removes EN→RU copy and `No —` in RU delete lines.
* **`scripts/manual/generate_app_structure_detailed.py`:** [shipped] `finalize_file_guide()` before render; no EN fallback in RU blocks; quality gate fails on SHA mismatch, RU=EN copy, English delete prefix.
* **`scripts/manual/structure_guide_data.py`**, **`structure_role_guides.py`:** [shipped] `ensure_folder_ru()` completes all RU keys even when `what_ru` exists; brain/UI `responsibilities_ru` wrappers.
* **`docs/APP_STRUCTURE_DETAILED.md`:** [shipped] Regenerated at git SHA `22b478c` (528 files); real RU for `lib/`, `.github/`, platform folders — not generic templates.
* **`AGENT_NAVIGATION.md`:** [shipped] Renamed from legacy `CLAUDE.md` (no hard tool dependency on filename); AI navigation map unchanged in role.
* **`scripts/manual/structure_root_guides.py`:** [shipped] Curated EN+RU root file dictionary (`.gitignore`, `.metadata`, `pubspec.*`, `update.ps1`, `android.ps1`, etc.).
* **`.cursorrules`:** [kept] Root pointer to `.cursor/rules/flutter_expert.mdc` (Cursor discovery convention).
* **`android.ps1`:** [kept] Documented APK build helper (`flutter build apk --split-per-abi` → `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`).
* **Production code:** [skipped] no Dart behavior changes; HTML structure map not regenerated.

## [2026-07-03] - Remove generic structure guide filler [shipped]

* **`docs/APP_STRUCTURE_DETAILED.md`:** [shipped] Removed remaining generic folder descriptions; curated entries for `lib/core/`, `lib/features/`, `lib/l10n/`, platform subfolders, installer STT paths.
* **`scripts/manual/generate_app_structure_detailed.py`**, **`structure_guide_data.py`:** [shipped] Quality gate now fails on banned folder filler phrases; removed generic folder fallback.
* **Production code:** [skipped] no Dart behavior changes; HTML structure map not regenerated.

## [2026-07-03] - Owner-readable structure encyclopedia [shipped]

* **`docs/APP_STRUCTURE_DETAILED.md`:** [shipped] Rebuilt as owner-readable unique folder/file guide (525 files, 119 folders; EN+RU per entry).
* **`scripts/manual/generate_app_structure_detailed.py`:** [shipped] Improved generator with curated folder/file dictionaries, role humanization, duplicate-quality gate.
* **`scripts/manual/structure_guide_data.py`**, **`scripts/manual/structure_role_guides.py`:** [shipped] New curated description data for brain/UI/platform paths.
* **Production code:** [skipped] no Dart behavior changes; HTML structure map not regenerated.

## [2026-07-03] - Full repo necessity cleanup [shipped]

* **`design/`:** [shipped] Removed 6 unused CardPlan PNG/SVG reference mockups (not in `pubspec` assets, no runtime load).
* **Perf captures:** [shipped] `git rm` tracked `shell_timeline_swipe_capture.txt`, `timeline_perf_capture.txt` (already `.gitignore`; test output only).
* **Legacy Firebase:** [shipped] Removed `firebase.json`, `.firebaserc`.
* **Obsolete scripts/tools:** [shipped] Removed `COMPLETE_INSTALL.ps1` (stale paths + credentials), migration/audit/repair one-offs, `tools/migrate_to_pb.dart` + sample CSVs, `p0b_build_apk.ps1`, `run_desktop_voice_test.bat`, `.claude/settings.local.json`, `pocketbase.service`.
* **`docs/reports/FULL_REPO_NECESSITY_CLEANUP_2026-07-03.md`:** [shipped] Deletion inventory + human-decision list.
* **`docs/APP_STRUCTURE.md`**, **`APP_STRUCTURE_DETAILED.md`:** [shipped] Regenerated; removed `design/`, `tools/`, stale root entries.
* **Production code:** [skipped] no Dart changes; `update.ps1` not run.

## [2026-07-03] - Project Knowledge pack cleanup [shipped]

* **`docs/PROJECT_KNOWLEDGE_PACK.md`:** [shipped] 14-doc upload checklist (≤25 limit); excluded repo-only docs listed.
* **Deleted:** [shipped] `AI_CONTEXT.md`, `APP_STRUCTURE_EXPLAINED_RU.md`, `DESKTOP_WINDOWS_ARTIFACT.md`, `WINDOWS_INSTALLER.md`, `AUDIT_NOTES.md`, `FILE_STRUCTURE_SCAN_2026-07-03.md`, `REPO_CLEANUP_NON_PROJECT_FILES_2026-07-03.md`.
* **Merged:** [shipped] Windows installer + artifact docs → `docs/DEPLOY.md` § Windows desktop release.
* **`AGENTS.md`**, **`CLAUDE.md`**, **`docs/ROADMAP.md`**, **`docs/APP_STRUCTURE.md`**, **`FINAL_STRUCTURE_PARITY` report:** [shipped] Broken links fixed; pack list updated.
* **`docs/APP_STRUCTURE_DETAILED.md`:** [shipped] Regenerated after doc deletions.
* **Production code:** [skipped] docs-only pass; `update.ps1` not run.

## [2026-07-03] - Remove external sync wording from docs [shipped]

* **`CLAUDE.md`:** [shipped] Doc sync reminder — removed external sync instructions; neutral repo-local wording only.

## [2026-07-03] - Final structure parity and doc cleanup [shipped]

* **`docs/reports/FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md`:** [shipped] Baseline `19d794a`; removed 20 superseded reports + 16 one-off extraction scripts; consolidated Pass 3–4D acceptance; parity checklist.
* **Deleted docs:** [shipped] Supabase/Firebase-era reports, lockdown/blueprint/intermediate decomposition reports, `docs/archive/*` scratch.
* **Deleted scripts:** [shipped] `scripts/pass3_*`, `scripts/extract_*`, `scripts/split_planning_page.py` — decomposition complete.
* **`docs/APP_STRUCTURE.md`**, **`AGENTS.md`**, **`CLAUDE.md`**, **`docs/ROADMAP.md`**, **`docs/AI_CONTEXT.md`**, **`DESIGN_SYSTEM_INVENTORY.md`:** [shipped] Broken links fixed; §7 script note updated.
* **`docs/APP_STRUCTURE_DETAILED.md`:** [shipped] Regenerated (553 tracked files).
* **Production code:** [skipped] docs/hygiene only; `update.ps1` not run.

## [2026-07-03] - Repo cleanup non-project files [shipped]

* **Local junk removed:** [shipped] `docs/reports/_*.tmp`, Android JVM `hs_err_`/`replay_` logs, `scripts/__pycache__/`, root `*_perf_capture.txt` captures (gitignored).
* **`exports/`:** [shipped] Removed 4 accidentally tracked Price Reporter audit CSV/XLSX artifacts; added `exports/` to `.gitignore` (script output stays local).
* **Production code:** [skipped] docs/hygiene only.

## [2026-07-03] - File structure scan and APP_STRUCTURE docs [shipped]

* **`docs/APP_STRUCTURE.md`:** [shipped] §0 current status (SHA `d7e7c12`, Pass 3B + 4A–4D complete), link to detailed guide, §7–§8 split guard + product priorities; fixed `planning_page.dart` line estimate.
* **`docs/APP_STRUCTURE_DETAILED.md`:** [shipped] New bilingual EN/RU file-by-file guide for all tracked `lib/**/*.dart`, tests, scripts, docs (generated via `scripts/manual/generate_app_structure_detailed.py`).
* **`docs/reports/FILE_STRUCTURE_SCAN_2026-07-03.md`:** [shipped] Full scan method, counts, compact tree, stale-doc fixes.
* **`scripts/manual/structure_scan.ps1`**, **`scripts/manual/generate_app_structure_detailed.py`:** [shipped] Documented regen helpers; ephemeral outputs gitignored (`docs/reports/_*.tmp`).
* **`AGENTS.md`**, **`docs/APP_STRUCTURE_EXPLAINED_RU.md`:** [shipped] Brain decomposition complete; pointer to detailed guide.
* **Production code:** [skipped] docs-only pass.

## [2026-07-03] - Structure refactor pass 4D profile service [shipped]

* **`lib/data/profile/`:** [shipped] Pass 4D safe Brain split: eight `part of database_service.dart` files — `profile_hydration.dart`, `profile_settings.dart`, `profile_timezone.dart`, `profile_cache_helpers.dart`, `profile_preferences.dart`, `profile_admin.dart`, `tag_catalog.dart`, `tag_display_settings.dart`; named extensions `ProfileHydrationExtension`, `ProfileSettingsExtension`, `ProfileTimezoneExtension`, `ProfileCacheExtension`, `ProfilePreferencesExtension`, `TagCatalogExtension`, `TagDisplaySettingsExtension`.
* **`lib/data/profile_service.dart`:** [shipped] Coordinator retained (`ProfileServiceExtension` shared Brain state + `resolveProfileDisplayLabelFor`); 1022→75 lines (−947).
* **Plan/record/category Brain:** [skipped] untouched.
* **Verification:** strict `architecture_guard` 0 violations; `flutter analyze` 0 errors; `flutter test` 248/248; web + APK green.

## [2026-07-03] - Structure refactor pass 4C category service [shipped]

* **`lib/data/categories/`:** [shipped] Pass 4C safe Brain split: seven `part of database_service.dart` files — `category_cache_helpers.dart`, `category_tree.dart`, `category_lookup.dart`, `category_crud.dart`, `category_stats.dart`, `category_record_bridge.dart`, `category_default_time.dart`; named extensions `CategoryCacheExtension`, `CategoryTreeExtension`, `CategoryLookupExtension`, `CategoryCrudExtension`, `CategoryStatsExtension`, `CategoryRecordBridgeExtension`, `CategoryDefaultTimeExtension`.
* **`lib/data/category_service.dart`:** [shipped] Coordinator retained (`CategoryServiceExtension` static bridge helpers: `_flattenNocoRecord`, `recordsTablePk`, `_parseDateTimeUtc`, stats duration statics, `_rowInt`); 3287→466 lines (−2821).
* **Plan/record/profile Brain:** [skipped] untouched.
* **Verification:** strict `architecture_guard` 0 violations; `flutter analyze` 0 errors; `flutter test` 248/248; web + APK green.

## [2026-07-03] - Structure refactor pass 4B record service [shipped]

* **`lib/data/records/`:** [shipped] Pass 4B safe Brain split: eight `part of database_service.dart` files — `record_crud.dart`, `record_optimistic.dart`, `record_realtime.dart`, `record_timeline_vm.dart`, `record_outbox_helpers.dart`, `record_overlap_helpers.dart`, `record_ghost_cleanup.dart`, `record_cache_helpers.dart`; named extensions `RecordCrudExtension`, `RecordOptimisticExtension`, `RecordRealtimeExtension`, `RecordTimelineVmExtension`, `RecordOutboxSyncExtension`, `RecordOverlapExtension`, `RecordGhostCleanupExtension`, `RecordCacheProjectionExtension`.
* **`lib/data/record_service.dart`:** [shipped] Coordinator retained (`RecordServiceExtension`, fetch/upsert, start entry wrappers, shared streams); 4423→901 lines (−3522).
* **Plan/category/profile Brain:** [skipped] untouched.
* **Verification:** strict `architecture_guard` 0 violations; `flutter analyze` 0 errors; `flutter test` 248/248; web + APK green.

## [2026-07-03] - Structure refactor pass 4A plan service [shipped]

* **`lib/data/plans/`:** [shipped] Pass 4A safe Brain split: six `part of database_service.dart` files — `plan_projection_types.dart`, `plan_recurrence_helpers.dart`, `plan_time_cascade_helpers.dart`, `plan_tags_helpers.dart`, `plan_cache_helpers.dart`, `plan_outbox_helpers.dart`; named extensions `PlanRecurrenceExtension`, `PlanTimeCascadeExtension`, `PlanTagsExtension`, `PlanCacheProjectionExtension`, `PlanOutboxSyncExtension`, `PlanTimeModeProjection`.
* **`lib/data/plan_service.dart`:** [shipped] Coordinator retained (`PlanServiceExtension`, streams, CRUD, shared wall-time helpers); 6457→5118 lines (−1339).
* **`lib/features/planning/planning_page.dart`:** [shipped] `PlanServiceExtension.planningWallEstimateSeconds` → top-level `planningWallEstimateSeconds`.
* **Failed tooling removed:** [shipped] deleted `scripts/pass4_brain_split.py`, `scripts/pass4_split_fast.py`.
* **Brain record/category/profile:** [skipped] untouched.
* **Verification:** strict `architecture_guard` 0 violations; `flutter analyze` 0 errors; `flutter test` 248/248; web + APK green.

## [2026-07-03] - Structure refactor pass 3B [shipped]

* **`lib/features/lists/`:** [shipped] Pass 3 follow-up: `lists_filters.dart`, `lists_bulk_actions.dart`, `lists_inline_add.dart`, `lists_empty_state.dart`; `lists_view.dart` 1685→1091; coordinator owns state only.
* **`lib/features/timeline/timeline_header_controls.dart`:** [shipped] List/stats segmented control + record input row extracted from `timeline_view.dart` (713→624).
* **`lib/core/widgets/plan_time_task_card/plan_card_tags.dart`:** [shipped] Time View tag row/stack/pill widgets moved out of `plan_card_layouts.dart`.
* **`lib/features/planning/widgets/planning_quick_add_strip.dart`:** [shipped] Quick-add tag strip extracted from `planning_page.dart` (2650→2632).
* **Brain services:** [skipped] unchanged.
* **Verification:** strict `architecture_guard` 0 violations; `flutter analyze` 0 errors; `flutter test` 248/248; web + APK green.

## [2026-07-03] - Structure refactor pass 3 [shipped]

* **`lib/features/planning/time_view/`:** [shipped] Time View extracted from `planning_page.dart` (5287→2650): `planning_time_view.dart`, `time_view_canvas.dart`, `time_view_hour_grid.dart`, `time_view_card_layer.dart`, drag/resize/drop/settings/search modules; `PlanningTimeViewHost` + `PlanningTimeViewCoordinator`; gesture/cascade unchanged.
* **`lib/shell/`:** [shipped] `app_shell.dart` → 2-line re-export; `life_os_dashboard.dart` + part mixins (`shell_core`, `shell_tab_host`, `shell_edit_hosts`, `shell_more_menu`, `shell_voice_routing`); side nav/profile bar/settings moved; tab order/voice/sync unchanged.
* **`lib/core/widgets/plan_time_task_card/`:** [shipped] Package normalized: widget 433 lines + `plan_card_layouts.dart`, `plan_card_progress.dart`, `plan_card_density.dart`; compatibility barrel at `plan_time_task_card.dart`.
* **`lib/features/timeline/`:** [shipped] `timeline_day_page.dart`, `timeline_record_card.dart`, `timeline_helpers.dart`, `timeline_header_controls.dart`; `timeline_view.dart` 1129→624 (Pass 3+3B).
* **`lib/features/lists/`:** [shipped] `lists_card.dart`, `lists_export.dart`, `lists_filters.dart`, `lists_bulk_actions.dart`, `lists_inline_add.dart`, `lists_empty_state.dart`; `lists_view.dart` 2036→1091 (Pass 3+3B).
* **Brain services:** [skipped] `plan_service`/`record_service`/`category_service`/`profile_service` untouched.
* **Verification:** strict `architecture_guard` 0 violations; `flutter analyze` 0 errors; `flutter test` 248/248; web + APK green.

## [2026-07-02] - Structure refactor pass 2 [shipped]

* **`lib/features/planning/`:** [shipped] `planning_view.dart` → barrel; `planning_page.dart` (~5543) + `planning_page_shell.dart` (~292); sort/bulk/filter/empty/list-helper widgets extracted; Time View gesture state unchanged.
* **`lib/core/widgets/plan_card/`:** [shipped] `plan_card_geometry.dart`, `plan_card_controls.dart`, `plan_card_sections.dart`; `plan_time_task_card.dart` 2559→2003 lines; public API unchanged.
* **`lib/app_shell.dart` / navigation:** [shipped] `shell_side_navigation.dart`, `profile_hydration_status_bar.dart`, `settings_page.dart`; shell 2646→2453 lines; nav/auth/voice/sync unchanged.
* **Brain `plan_service`/`record_service`:** [skipped] no safe pure-helper seams without PB/optimistic risk.

## [2026-07-02] - P0-SAFE structure decomposition pass acceptance [accepted]

* **Commits `54b9b54..5a30b33` (final `5a30b33`):** Manual smoke **accepted by user** — Plans→Time View opens; tap/edit basically OK; Time View drag/bulk mechanics acceptable for baseline; edit sheet works; Profile/settings not visibly broken.

## [2026-07-02] - P0-SAFE structure decomposition [shipped]

* **`lib/features/planning/`:** [shipped] Tail widgets extracted from `planning_view.dart` (7272→6022 lines): `time_view/time_view_interaction_block.dart`, `time_view_drag_state.dart`, `time_view_fixed_time_settings.dart`, `settings/*`, `widgets/*`; behavior unchanged; Time View tests green.
* **`lib/features/shared/`:** [shipped] `shared_widgets.dart` → 16-line barrel; `planning_task_edit_sheet.dart`, `timeline_record_edit_sheet.dart`, `activity_detail_sheet.dart`, `edit_sheet/*`, `empty_state_placeholder.dart`, `offline_sync_status_bar.dart`; autosave/recurrence scope preserved.
* **`lib/core/widgets/plan_card/`:** [shipped] `plan_card_metrics.dart`, `plan_time_card_density.dart` extracted from `plan_time_task_card.dart`; re-exported for existing imports.
* **`lib/features/profile/settings/`:** [shipped] Account, notification, security sections split from `profile_view.dart` (870→542 lines).
* **`docs/reports/STRUCTURE_DECOMPOSITION_AUDIT_2026-07-02.md`:** [shipped] Audit + stage map; Brain `plan_service`/`record_service` intentionally untouched.

## [2026-07-02] - P0 Time View interaction + duration fidelity [shipped]

* **`lib/features/planning/plan_time_view_layout.dart` / `lib/core/widgets/plan_card.dart`:** [shipped] Scheduled slot height = `duration × rubberPxPerMinute` (min 38px for 10m); card shell fills slot (`timelineFillHeight`); content density derived from slot height only.
* **`lib/features/planning/planning_view.dart` / `plan_time_gesture_contract.dart`:** [shipped] Pointer gesture state machine (tap opens edit / bulk toggle; drag after 8px desktop / 12px touch threshold); pointer-anchored preview; dragged ids excluded from collision layout during preview; bulk group drag with relative offsets.
* **`lib/data/plan_time_sequential_cascade.dart` / `time_view_fixed_time_policy.dart`:** [shipped] `computeTimeViewInsertionCascade` with fixed-time barriers; local prefs `time_view_fixed_tag_ids_v1` + Planning settings “Fixed-time tags” chips.
* **`test/plan_time_*`:** [shipped] Duration fidelity, gesture contract, fixed-time policy, bulk drag regression tests (empty-canvas + target-card group insert).
* **Follow-up:** bulk drag preview moves all selected cards together; fixed-barrier cascade test; `docs/APP_STRUCTURE.md` local-only fixed-tag schema gap note; target-card bulk group insert with preserved offsets + preview/commit parity.

## [2026-07-02] - P0 edit Save local-first reliability [shipped]

* **`lib/features/shared/shared_widgets.dart` — `EditSheetAutosaveGate` / `_commitSave` / `_save`:** [shipped] Explicit Save uses `flush(force: true)` with latest draft; empty title / missing times show localized warnings; stopped Timeline edits apply optimistic UI before overlap warning; recurrence scope dismiss no longer rolls back local state after Save.
* **`test/edit_sheet_autosave_test.dart`:** [shipped] Force-flush + latest-draft-at-fire-time coverage.

## [2026-07-02] - P0 planning recurrence scope + bounded Time View density [shipped]

* **`lib/data/recurrence_edit_scope.dart` / `lib/features/planning/recurrence_scope_dialog.dart`:** [shipped] `RecurrenceEditScope` (`singleOccurrence`, `thisAndFuture` disabled, `entireSeries`) + EN/RU scope dialog wired from `planning_view.dart` delete menu and `_PlanningTaskEditSheet` autosave in `shared_widgets.dart`.
* **`lib/data/plan_service.dart`:** [shipped] `updatePlanningTaskWithRecurrenceScope` / `deletePlanningTaskWithRecurrenceScope`; materialized exceptions set `parentPlanPocketId` + `recurrenceInstanceDateKey`; `_collectMaterializedRecurrenceSuppressionKeys` fixes virtual+materialized duplicate cards; release `print()` spam removed from materialize path.
* **`lib/core/widgets/plan_time_task_card.dart` / `lib/features/planning/plan_time_view_layout.dart`:** [shipped] Piecewise card heights (10→38, 30→75, 60→120 px), 10-minute min snap/duration, hour cap **248 px** (`kPlanTimeMaxHourHeightPx`).
* **`test/plan_recurrence_scope_test.dart` / `test/plan_time_view_layout_test.dart`:** [shipped] Recurrence dedupe/scope guards + bounded density anchors.

## [2026-07-02] - Stage E.0.5A structure guard green [shipped]
* **`lib/data/voice_command_parser.dart`:** [shipped] git-moved from `features/shared/` — Brain-owned deterministic voice command parse; all `lib/` + `test/` imports → `package:counter/data/voice_command_parser.dart`.
* **`lib/core/time/profile_timezone_actions.dart`:** [shipped] `ProfileTimezoneActions` injectable hooks (`shortLabel`, `settingsStream`, `currentSettings`, `saveTimezone`); wired in `main.dart` `_wireProfileTimezoneActions()` after Brain init.
* **`lib/core/widgets/timezone_quick_picker.dart`:** [shipped] `HeaderTimezoneQuickSwitcher` uses `ProfileTimezoneActions` instead of forbidden `core→database_service` import.
* **`lib/core/diagnostics/desktop_voice_log.dart`:** [shipped] renamed from `desktop_voice_diag.dart`; class `DesktopVoiceLog` (release quiet; debug markers only).
* **`docs/APP_STRUCTURE.md`:** [shipped] full manifest for desktop voice stack, timezone modules, `voice_command_parser`, navigation helper; fixed malformed features table; added `ProfileTimezoneActions` shell injection row.
* **`docs/APP_STRUCTURE_EXPLAINED_RU.md`**, **`CLAUDE.md`**, **`docs/ROADMAP.md`:** E.0.5A complete markers and navigation updates.
* **Verification:** `architecture_guard.ps1 -Strict` exit 0; `flutter analyze`, `flutter test` (223 passed), `flutter build web` green.
* **Checkpoint commit:** `77e4afd` — `chore(structure): finish desktop voice and timezone baseline before splits`.
* **APK:** `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (arm64 release).
* **Web deploy:** [shipped] `.\update.ps1` pushed `672a576`; live `https://nkuchenov-hash.github.io/Counter/` — console `APP_BUILD commit=9a64a84` (web build stamped before deploy commit).
* **Windows build:** [shipped] `flutter build windows --release --dart-define=DESKTOP_VOICE_COMMAND=true` green after stopping smoke processes (`build/windows/x64/runner/Release/counter.exe`).
* **HANDY comparison file:** not in repo; acceptance via existing desktop voice tests + CHANGELOG. Stage E1 not started.

## [2026-07-02] - Stage E.0 large-file split blueprint [shipped]
* **`docs/reports/LARGE_FILE_SPLIT_BLUEPRINT_2026-07-02.md`:** [shipped] Repo-specific split plan for all `lib/` files >800 lines — classifications, target module trees, E1–E8 ordering, risk matrix, tests, APP_STRUCTURE/guard deltas, rollback. Planning only; no production Dart changes.
* **Kill-switch note:** Strict guard fails (49 violations) on dirty desktop-voice/timezone tree — E1 implementation blocked until APP_STRUCTURE + guard green.

## [2026-07-02] - Solid timezone icon family and dynamic profile timezone picker [wip]
* **`lib/core/widgets/app_timezone_icon.dart` / `lib/core/app_icons.dart`:** [wip] Added the canonical solid, filled, monochrome `AppTimezoneIcon` family for UTC, London, Moscow, Dubai, and New York without raster/SVG assets or circular containers.
* **`lib/core/time/profile_timezone_catalog.dart` / `lib/core/time/wall_clock.dart`:** [wip] Profile timezone catalog now stores canonical values (`UTC`, `London`, `Moscow`, `Dubai`, `New York`), keeps UTC separate from London, uses IANA IDs for wall-clock math, and produces dynamic DST labels (`BST`/`GMT`, `EDT`/`EST`) with current UTC offsets.
* **`lib/core/widgets/timezone_quick_picker.dart`, `lib/features/profile/profile_view.dart`, `lib/app_shell.dart`:** [wip] Replaced static dropdown rows with the approved `[icon][timezone text][checkmark]` picker row and canonical save path.
* **`lib/features/dev/component_lab_view.dart`, `docs/DESIGN_SYSTEM.md`, `docs/DATA_MAP.md`:** [wip] Added the Component Lab icon review section and documented the canonical timezone icon/profile timezone API.
* **Verification:** [wip] Targeted timezone/icon tests pass; `flutter analyze --no-fatal-infos --no-fatal-warnings`, full `flutter test`, and release `flutter build web` pass. Deploy not run because unrelated dirty/untracked files remain in the worktree.

## [2026-06-15] - P0 edit sheet save/autosave repair [wip]
* **`lib/features/shared/shared_widgets.dart`:** [wip] `EditSheetAutosaveGate` — local-first plan/record edit drafts; optimistic Brain apply on field change; debounced `updatePlanningTask` / `updateRecord` (~650ms); explicit Save flushes pending draft; `AppSnack.changesSaved()` (`Изменения сохранены` / `Changes saved`) on successful local apply.
* **`lib/data/record_service.dart`:** [wip] `findFirstOverlappingRecordInCache` + `applyOptimisticRecordRowEdit` PB id resolution — stopped-record Save no longer blocks on network overlap before optimistic UI.
* **`lib/core/app_snackbar.dart`:** `AppSnack.changesSaved()`.
* **`lib/app_shell.dart`:** plan edit `onSaved` pop-only (persist handled in sheet); no duplicate toast/optimistic.
* **`test/edit_sheet_autosave_test.dart`:** debounce/flush gate tests.

## [2026-06-15] - Manual data repair: June 25 plan times MSK reinterpretation [wip]
* **`scripts/manual/repair_2026_06_25_plan_times_msk.dart`:** [wip] One-off PocketBase repair — reinterpreted 16 scheduled `plans` on 2026-06-25 from New York wall time to Moscow wall time (`start_time`/`end_time` only); explicit `--ids` + `--confirm REINTERPRET_NY_AS_MSK_2026_06_25` apply path; profile `xhjy54inue73piz`; all 16 PATCHes read-back verified; durations preserved.

## [2026-06-26] - P0 No Preparing UI — production overlay recording-first [shipped]
* **`lib/features/shared/desktop_voice_widget.dart`:** [shipped] `showDesktopVoiceWidget` opens native overlay with `showListening` + `FIRST_VISIBLE_STATE_LISTENING`; removed `showPreparing` entry path; processing uses `desktop_voice_transcribing`.
* **`lib/core/services/desktop_voice_overlay_service.dart`:** [shipped] `showPreparing` redirects to `showListening` + `FORBIDDEN_PREPARING_REDIRECTED_TO_LISTENING`; native primary = `desktop_voice_state_listening` («Слушаю…»/«Listening…»).
* **`lib/l10n`:** removed `desktop_voice_overlay_stt_warming` / `overlay_preparing`; added `desktop_voice_transcribing`.
* **`windows/runner/desktop_voice_native_overlay.cpp`:** mic bars visible immediately in listening state (min height baseline).
* **`scripts/manual/check_no_preparing_ui.ps1`**, **`scripts/manual/smoke_desktop_voice_recording_first.ps1`:** anti-regression checks.

## [2026-06-26] - P0 Desktop Voice helper failure isolation [shipped]
* **`lib/core/services/desktop_voice_user_error.dart`:** [shipped] `DesktopVoiceUserError.fromException` / `resolve` — maps `ClientException`/socket/HTTP/localhost/stack traces to EN/RU friendly overlay copy; markers `ERROR_MAPPED`, `RAW_EXCEPTION_SUPPRESSED`, `OVERLAY_FRIENDLY_ERROR_SHOWN`.
* **`lib/core/services/desktop_stt_helper_service.dart`:** [shipped] `startListening` capture-first (no `ensureStarted` before mic); `stopAndTranscribe` saves WAV then STT HTTP; hardened `_transcribePcm` timeouts + `http.ClientException`/`SocketException`/`HttpException`/`FormatException`; helper health/restart-once; smoke audio inject.
* **`lib/features/shared/desktop_voice_widget.dart`:** [shipped] recording-first `_beginSessionRecordingFirst`; `_failFriendly` never surfaces raw exceptions; retry skips Preparing UI.
* **`lib/core/services/desktop_voice_command_normalize.dart`:** [shipped] normalization gate before `writeRecord`; Plenty/plan aliases → Planning.
* **`lib/core/services/desktop_voice_hotkey.dart`:** [shipped] command-first — hotkey always `openOverlay` (removed `stopRunningRecord`).
* **`scripts/manual/smoke_desktop_voice_helper_failure.ps1`:** [shipped] kill `counter_stt_helper.exe` → Listening + capture + friendly STT error smoke.
* **`test/desktop_voice_user_error_test.dart`**, **`test/desktop_voice_helper_failure_test.dart`:** failure isolation unit tests.
* **`windows/runner/desktop_voice_native_overlay.cpp`:** fix `g_overlay_channel` unique_ptr assignment (Windows build).

## [2026-06-26] - P0 Desktop Voice command-first UX + hotkey smoke proof [shipped]
* **Hotkey smoke passes** with runtime-registered combo (`DESKTOP_VOICE_HOTKEY_REGISTERED_COMBO`); SendInput path proven; native file-hook fallback retained.
* **`lib/core/services/desktop_voice_hotkey_markers.dart`:** structured registration markers (`yes combo=… enabled=… command_define=…`).
* **`lib/core/services/desktop_voice_smoke_bridge.dart`:** production-handler file trigger; `HOTKEY_RECEIVED_FROM_NATIVE_TEST_HOOK`.
* **`scripts/manual/smoke_desktop_hotkey.ps1`:** no hardcoded combo; parses log; `-CommandFirstSmoke` verifies preserved-running.
* Command-first UX: hotkey listen-first; stop/switch only after recognition (prior session files).

## [2026-06-26] - P0 Desktop Voice acceptance fix (Plenty→Planning, mic, confirmation) [shipped]
* **`lib/features/shared/voice_command_parser.dart`:** [shipped] Price Reporter scope title aliases `plenty`/`planing`/`plan`→Planning.
* **`lib/core/services/desktop_voice_command_normalize.dart`:** final normalization gate before `writeRecord`; blocks wrong titles.
* **`lib/core/services/desktop_voice_confirmation.dart`:** mandatory native overlay start/stop confirmation + OS notification markers.
* **`windows/runner/desktop_voice_native_overlay.cpp`:** always-visible mic bars during Listening; `InvalidateRect` on level update.
* **`lib/core/services/desktop_voice_overlay_service.dart`:** `NATIVE_OVERLAY_LEVEL_UPDATE`; full confirmation line as primary.

## [2026-06-25] - P0 Recording-first Desktop Voice (no Preparing UI) [shipped]
* **`lib/core/services/desktop_stt_helper_service.dart`:** [shipped] `startListening` never awaits helper; `prewarmRecognizerInBackground()` + `DesktopRecognizerPrewarmState`; processing wait `kVoiceProcessingMaxWait` (10s) after capture only.
* **`lib/features/shared/desktop_voice_widget.dart`:** [shipped] hotkey → immediate Listening + mic capture; markers `RECORDING_STARTED_IMMEDIATELY`, `FIRST_VISIBLE_STATE_LISTENING`, `NO_PREPARING_UI`; removed preparing phase from production overlay.
* **`lib/core/services/desktop_voice_overlay_service.dart`:** `showPreparing` redirects to `showListening`; processing overlay uses «Распознаю…» / «Transcribing…».
* **`lib/l10n`:** overlay listening «Слушаю…»/«Listening…»; `desktop_voice_recognize_failed`.
* **`test/desktop_voice_overlay_state_test.dart`:** recording-first + no-preparing UI guard.
* **`scripts/manual/smoke_desktop_hotkey.ps1`:** `-NoPreparingUiSmoke` mode.

## [2026-06-25] - P0 Desktop Voice preparing hang fix [shipped]
* **`lib/core/services/desktop_stt_helper_service.dart`:** [shipped] deadline-based `ensureStarted(maxWait)` with 5s voice-overlay cap; HTTP/status timeouts; one helper restart; markers `HELPER_*`.
* **`lib/features/shared/desktop_voice_widget.dart`:** [shipped] 5s preparing watchdog; `_cancelSession`; pipeline markers `PREPARING_STARTED`/`STT_WARMUP_*`/`OVERLAY_ERROR_VISIBLE`; error `desktop_voice_recognizer_start_failed`.
* **`lib/core/services/desktop_voice_hotkey.dart`:** `cancelOverlay` action; preparing/processing hotkey cancels instead of no-op `finishListening`.
* **`lib/core/services/desktop_voice_overlay_bridge.dart`:** `isPreparing`/`isProcessing`/`requestCancel`.
* **`windows/runner/desktop_voice_native_overlay.cpp`:** [shipped] X close button + Escape → Dart `overlayCloseClicked`/`overlayEscapePressed`.
* **`test/desktop_voice_overlay_state_test.dart`:** preparing timeout + cancel bridge tests.
* **`scripts/manual/smoke_desktop_hotkey.ps1`:** `-PrepareTimeoutSmoke` mode for forced-timeout markers.

## [2026-06-25] - P0 Tray-hidden native Win32 voice overlay [shipped]
* **`windows/runner/desktop_voice_native_overlay.cpp`:** [shipped] separate topmost tool-window HWND (460×112) via MethodChannel `counter/desktop_voice_native_overlay`; never mutates main Flutter window.
* **`lib/core/services/desktop_voice_overlay_service.dart`:** unified overlay API (`showPreparing`/`showListening`/`showStarted`/`showStopped`/`hide`); markers `NATIVE_OVERLAY_*`, `NOTIFICATION_FALLBACK_USED` only on failure.
* **`lib/features/shared/desktop_voice_widget.dart`:** Windows uses native overlay for all states; Flutter `OverlayEntry` runs STT session logic only; tray-hidden no longer notification-only.
* **`scripts/manual/smoke_desktop_hotkey.ps1`:** requires `DESKTOP_VOICE_NATIVE_OVERLAY_SHOWN_WHILE_TRAY_HIDDEN`; 5× hotkey stress while hidden.

## [2026-06-25] - P0 Hotkey crash fix + Microphone card clip fix [shipped]
* **`lib/core/services/desktop_voice_overlay_host_io.dart`:** [shipped] removed unsafe main-window resize/frameless/skip-taskbar capsule path (crash root cause); host is no-op (`no_window_mutation`); tray-hidden → `notifyTrayOverlayUnavailable` notification fallback only.
* **`lib/app_shell.dart`:** hotkey handler wrapped in try/catch; markers `HOTKEY_ACTION_RESOLVED`, `HOTKEY_ERROR_CAUGHT`.
* **`lib/features/shared/desktop_voice_widget.dart`:** overlay insert guarded by window visibility; errors caught without terminating app.
* **`lib/features/profile/desktop_voice_settings_desktop.dart`:** removed fixed 208px mic card height + `Spacer()`; mic monitor button fully inside card; 24px gap before Tip card.
* **`lib/core/widgets/app_settings_layout.dart`:** `AppSettingsGridCard` uses `mainAxisSize: min`.
* **`test/desktop_voice_settings_mic_layout_test.dart`:** mic button visibility regression test.
* **`scripts/manual/smoke_desktop_hotkey.ps1`:** 10× hotkey stress (process must stay alive).
* **Installer:** `installer/windows/output/CounterSetup.exe` rebuilt.

## [2026-06-25] - P0 Desktop Voice UX Reset (Handy capsule + tray overlay host) [shipped]
* **`lib/core/services/desktop_voice_overlay_host_io.dart`:** [shipped] tray-hidden hotkey shows frameless bottom capsule via `window_manager` (no `showMainWindow`); `desktopVoiceShellSuppressed` hides full shell; `screen_retriever` work-area placement; marker `DESKTOP_VOICE_SHOW_MAIN_WINDOW_SKIPPED`.
* **`lib/features/shared/desktop_voice_capsule.dart`:** [shipped] Handy-style bottom capsule (360–480×72–120, rounded, mic/spinner/timer/cancel).
* **`lib/features/shared/desktop_voice_widget.dart`:** [shipped] removed large dialog flow; `OverlayEntry` capsule; insert-before-host-activate race fix; Escape cancel; auto-close respects `autoCloseAfterApply`.
* **`lib/core/widgets/app_settings_layout.dart`:** [shipped] restored full settings layout; `AppHotkeyKeycaps` fixed-width Row keycaps (Ctrl/Shift/P/Space).
* **`lib/features/shared/voice_command_parser.dart`:** `rice reporter` alias; stop confirmation title-only (`Остановлено: Planning`).
* **`scripts/manual/smoke_desktop_hotkey.ps1`:** asserts `DESKTOP_VOICE_SHOW_MAIN_WINDOW_SKIPPED` + `DESKTOP_VOICE_OVERLAY_OPENED`.
* **Build:** `flutter analyze` clean (no errors); acceptance 36+ tests pass; hotkey smoke pass; `installer/windows/output/CounterSetup.exe` (2026-06-25 ~09:33, ~506 MB).

## [2026-06-25] - P0 Desktop Voice UX contract (state machine + overlay-first) [shipped]
* **`lib/app_shell.dart`:** [shipped] documented hotkey state machine A–E; fixed overlay-open tracking (`isDesktopVoiceOverlayOpen`); State B finish-listening; State D stop via `stopRecordByDocId` + `DesktopVoiceConfirmation`; tray window show on overlay open.
* **`lib/features/shared/desktop_voice_widget.dart`:** overlay inserts before STT warmup; preparing UI shows timer/mic/cancel; pipeline markers `OVERLAY_OPEN_REQUESTED`, `RECORDING_FAILED`, `OVERLAY_ERROR_VISIBLE`.
* **`lib/core/services/desktop_voice_overlay_bridge.dart`:** hotkey ↔ overlay finish-listening bridge.
* **`lib/core/services/desktop_voice_confirmation.dart`:** mandatory AppSnack + OS notification markers (`FALLBACK_SNACK_SHOWN`, `OS_NOTIFICATION_*`).
* **`lib/core/diagnostics/desktop_voice_pipeline.dart`:** Windows pipeline log `%TEMP%\counter_desktop_voice_pipeline.log`.
* **`lib/features/shared/voice_command_parser.dart`:** `right reporter` + `play`→`Planning` STT aliases.
* **`lib/core/widgets/app_settings_layout.dart`:** `AppHotkeyKeycaps` horizontal Row (no stacked Wrap).
* **`scripts/manual/smoke_desktop_hotkey.ps1`:** physical hotkey smoke (parses registered combo, verifies markers).
* **Tests:** 36 pass in acceptance suite; installer rebuilt.

## [2026-06-25] - Desktop voice hotkey toggle stop [shipped]
* **`lib/app_shell.dart`:** [shipped] `_toggleDesktopVoiceWidget` — 1st hotkey opens overlay + STT; 2nd hotkey while running record calls `_desktopVoiceHotkeyStopRunning` (optimistic stop + snack/notification); overlay open → close on hotkey.
* **`lib/core/services/desktop_voice_hotkey.dart`:** `resolveDesktopVoiceHotkeyAction` + `DesktopVoiceHotkeyAction` enum.
* **`lib/features/shared/voice_command_parser.dart`:** `voiceCommandStopConfirmationMessage`.
* **`lib/services/notification_service.dart`:** `showDesktopVoiceRecordStopped`.
* **`test/desktop_voice_hotkey_self_acceptance_test.dart`:** toggle resolver + stop confirmation (29 tests total in acceptance suite).

## [2026-06-25] - P0 self-acceptance runner + production submit path [shipped]
* **`lib/core/services/desktop_voice_record_submit.dart`:** [shipped] shared production path `DesktopVoiceRecordSubmit.submitParsed/submitTranscript` → `writeRecord` seam + confirmation markers.
* **`scripts/manual/run_desktop_voice_acceptance.ps1`:** [shipped] runs parser + acceptance + production-submit + hotkey self-acceptance tests (25 pass).
* **`test/desktop_voice_production_submit_test.dart`:** Case A/B through production submit with mocked `writeRecord`.
* **`test/desktop_voice_hotkey_self_acceptance_test.dart`:** hotkey config validity + simulate-hotkey callback.
* **`lib/app_shell.dart`:** delegates to `DesktopVoiceRecordSubmit`; hotkey registration awaited; simulate-hotkey bridge.
* **Installer:** `installer/windows/output/CounterSetup.exe` 2026-06-25 06:34:38 (~506 MB).

## [2026-06-25] - P0 installed-app hotkey + settings layout fix [wip]
* **`lib/core/diagnostics/desktop_voice_pipeline.dart`:** [wip] release-safe step markers (`DESKTOP_VOICE_*`) for hotkey → overlay → writeRecord chain.
* **`lib/core/services/desktop_voice_acceptance_bridge.dart`:** [wip] deterministic acceptance commands (bypass STT) wired from collapsed Diagnostics.
* **`lib/app_shell.dart`:** [wip] await hotkey register; pipeline marks; acceptance bridge; timeline revision on voice start; overlay open failure traced.
* **`lib/features/profile/desktop_voice_settings_desktop.dart`:** [wip] mockup 2×2 grid (Hotkey+Behavior / Widget+Mic); removed misplaced Save footer; collapsed diagnostics only.
* **`lib/core/services/desktop_voice_hotkey.dart`:** `attachGlobal` returns `bool` for registration feedback.
* **No new installer** until installed-app acceptance passes.

## [2026-06-25] - P0 desktop voice acceptance grammar + auto-start [shipped code]
* **`lib/features/shared/voice_command_parser.dart`:** [shipped] Price Reporter command grammar — root-only title (`Planning`), child path + title (`AGE SOLUTIONS ADD MOD`), STT scope aliases (press/prize reporter, price rep, RU variants), child-only → display name as title; `voiceCommandStartConfirmationMessage`.
* **`lib/features/shared/desktop_voice_widget.dart`:** [shipped] exact/high-confidence commands auto-call `writeRecord` (no preview gate); overlay shows 2s confirmation.
* **`lib/app_shell.dart`:** [shipped] `_desktopVoiceSubmitParsed` → `AppSnack` + `NotificationService.showDesktopVoiceRecordStarted` after optimistic start.
* **`lib/core/services/desktop_voice_settings.dart`:** default enabled when `DESKTOP_VOICE_COMMAND=true`; preview-before-confirm default off.
* **`test/desktop_voice_command_acceptance_test.dart`:** Case A/B + alias near-misses + confirmation copy (19 tests pass with parser suite).
* **Installer:** fresh `CounterSetup.exe` not produced on this machine — `ISCC.exe` (Inno Setup 6) missing; Release folder rebuilt with parakeet STT payload.

## [2026-06-24] - P0 voice recognizer replacement + settings mockup [wip]
* **`lib/core/services/desktop_voice_audio_capture.dart`:** [wip] unified PCM16 16 kHz capture; RMS/peak levels; WAV save to `%LOCALAPPDATA%\Counter\voice_samples\`.
* **`lib/core/services/desktop_voice_benchmark_service.dart`:** [wip] `ENGINE_BENCHMARK` — same WAV through parakeet (GOLOS production), whisper-tiny (debug), Windows System.Speech (`win_speech_wav.ps1`); auto-selects winner.
* **`lib/core/services/desktop_stt_helper_service.dart`:** [wip] production default **parakeet** (not whisper-tiny); per-engine `/config`; no STT unless `audio_level_seen`; capture diagnostics (`sample_rate`, `rms_amplitude`, `audio_file`).
* **`installer/windows/prepare_stt_payload.ps1`:** bundles `models/parakeet` + `whisper-tiny` + `win_speech_wav.ps1`; `settings.json` `active_model: parakeet`.
* **`lib/features/profile/desktop_voice_settings_desktop.dart`:** [wip] mockup-aligned card grid — hero, hotkey keycaps, behavior, widget, mic selector + live meter, tip, benchmark/diag; Save footer.
* **`lib/core/widgets/app_settings_layout.dart`:** tab bar 56px, 40px content padding, 18px card radius, 48px keycaps, black accents.
* **`lib/core/shell_adaptive.dart`:** side nav width 272px.
* **Not shipped** — installed-app mic → benchmark → exact parse → `writeRecord` → Timeline still requires on-machine verification.

## [2026-06-24] - Desktop settings tabs + real mic/STT capture [wip]
* **`lib/features/profile/profile_view.dart`:** [wip] wide desktop + side nav → tabbed **Profile** layout (Account, Preferences, Desktop Voice, Notifications, Appearance, About); black/neutral accents via `settingsNeutralTheme`; mobile stays single-column.
* **`lib/features/profile/desktop_voice_settings_desktop.dart`:** [wip] card grid — hero toggle, hotkey keycaps, behavior, voice widget options, live mic monitor, tip, STT diag block.
* **`lib/core/widgets/app_settings_layout.dart`:** [wip] `AppSettingsCategoryTabs`, `AppHotkeyKeycaps`, `AppSettingsCardGrid`, `AppSettingsGridCard`.
* **`lib/core/widgets/app_mic_level_bars.dart`:** [wip] shared PCM-driven level bars (`pcm16RmsLevel`).
* **`lib/core/services/desktop_stt_helper_service.dart`:** [wip] RMS from PCM16 stream (not decorative `onAmplitudeChanged`); GOLOS `/transcribe/partial_audio` every 400ms; `/status` model-ready gate; `DesktopSttDiagnostics` / `STT_HELPER_CHECK` lines.
* **`installer/windows/build_stt_helper_en.ps1`:** [wip] builds English Whisper helper (`language=en`, Price Reporter prompt); `prepare_stt_payload.ps1` prefers `stt_helper_build/counter_stt_helper.exe`.
* **`lib/main.dart`:** Windows min window size 900×600 (maximize allowed; tray hide-on-close unchanged).
* **`lib/core/services/desktop_voice_settings.dart`:** desktop voice **disabled by default** until user enables; widget prefs (sound, auto-close, preview, undo).
* **Fresh installer:** `installer/windows/output/CounterSetup.exe` (2026-06-24 ~20:17, ~87.7 MB). **Not marked shipped** — mic/STT/record chain needs installed-app speech test.

## [2026-06-24] - Generic desktop voice overlay + mic feedback [wip]
* **`lib/features/shared/desktop_voice_widget.dart`:** [wip] generic **Voice command** overlay (not Price Reporter-branded); compact always-on-top card via `OverlayEntry` + `window_manager.setAlwaysOnTop`; immediate recording; timer + live mic level bars; preview-only path/title; Settings parser test field.
* **`lib/features/shared/voice_command_parser.dart`:** [wip] `parseVoiceCommand`, STT repair (`price report`→`Price Reporter`), flexible root token match, human-readable reason l10n keys.
* **`lib/core/services/desktop_stt_helper_service.dart`:** amplitude stream + byte/level tracking for overlay feedback.
* **`lib/core/services/desktop_voice_window_flags.dart`:** always-on-top toggle while overlay open.
* **Not verified on installed app** — do not mark shipped.

## [2026-06-24] - P0 Settings redesign + desktop voice fixes [wip]
* **`lib/core/widgets/app_settings_layout.dart`:** [wip] `AppSettingsPageBody` / `AppSettingsSectionCard` — centered max-width (~1040px) neutral settings shell.
* **`lib/features/profile/profile_view.dart`:** [wip] Profile/Settings rebuilt as section cards (Account & Security, Notifications, Desktop Voice, Appearance, Time & Locale, About); `AppButton` actions; page title **Settings**.
* **`lib/features/profile/desktop_voice_settings_section.dart`:** [wip] hotkey capture dialog with modifier validation, live preview, Save disabled until valid; registration rollback on failure; test-voice button; diag lines.
* **`lib/core/services/desktop_hotkey_codec.dart`:** [wip] normalize Ctrl/Shift/Alt/Win; reject modifier-only combos; human-readable labels.
* **`lib/core/diagnostics/desktop_voice_diag.dart`:** [wip] concise pipeline markers (hotkey → widget → STT → parser → writeRecord).
* **`lib/features/shared/desktop_voice_widget.dart`:** [wip] preview state + explicit **Start record**; diag hooks; status line on `DesktopVoiceSettings`.
* **`lib/l10n/langs/ru.dart`:** [wip] full RU strings for desktop voice + tray + settings sections (no raw keys in RU UI).
* **`lib/l10n/dictionary.dart`:** [wip] `t()` EN fallback before returning key.
* **`windows/runner/main.cpp`:** `SetQuitOnClose(false)` — close hides to tray via `window_manager`.
* **`lib/core/services/desktop_tray_service_io.dart`:** localized tray menu via `refreshDesktopTrayMenu`.
* **Not verified on installed `CounterSetup.exe` yet** — do not mark shipped until full hotkey → voice → writeRecord → Timeline chain passes.

## [2026-06-24] - Desktop voice widget reset (GOLOS local STT + tray) [shipped]
* **`lib/core/services/desktop_stt_helper_service.dart`:** [shipped] spawns bundled `stt_helper/counter_stt_helper.exe` (GOLOS `golos-backend` HTTP sidecar); PCM16 capture via `record` → `POST /transcribe/stop`; no cloud STT.
* **`lib/core/services/desktop_voice_recognizer*.dart`:** [shipped] desktop recognizer abstraction; production path = GOLOS helper; `speech_to_text` removed from desktop widget (legacy flag only).
* **`lib/features/shared/desktop_voice_widget.dart`:** [shipped] always-on-top command widget — listen/finish/process/preview/confirmed/error states; category path + title + action preview; 2s started confirmation + Undo/Stop.
* **`lib/core/services/desktop_tray_service*.dart`:** [shipped] `window_manager` + `tray_manager` — close hides to tray; tray menu Show/Voice/Stop/Settings/Exit; `--tray` hidden autostart.
* **`lib/core/services/desktop_voice_settings.dart`:** [shipped] local SharedPreferences — enable, hotkey, autostart, launch-hidden; Profile → Desktop Voice section.
* **`installer/windows/prepare_stt_payload.ps1`:** [shipped] copies `golos-backend.exe` + `whisper-tiny` model into Release `stt_helper/` before Inno compile.
* **`installer/windows/counter.iss`:** [shipped] optional autostart task (`--tray`); STT helper bundled via Release tree.

## [2026-06-24] - Windows CounterSetup.exe installer (Inno Setup) [shipped]
* **`installer/windows/counter.iss`:** [shipped] per-user Inno Setup 6 script — `{localappdata}\Programs\Counter`, Start Menu + Desktop shortcuts, HKCU Run autostart (removed on uninstall), post-install launch, full Release tree packaged.
* **`.github/workflows/windows-desktop-build.yml`:** [shipped] `choco install innosetup` + `ISCC.exe` compile; primary artifact **`CounterSetup`**; debug fallback **`counter-windows-release-debug-<run>`**.
* **`docs/WINDOWS_INSTALLER.md`:** [shipped] end-user install path; SmartScreen unsigned note; voice command test steps.

## [2026-06-24] - GitHub Actions Windows desktop artifact workflow [shipped]
* **`.github/workflows/windows-desktop-build.yml`:** [shipped] manual `workflow_dispatch` on `windows-latest`; Flutter 3.41.6; `flutter test test/voice_command_parser_test.dart`; `flutter build windows --release --dart-define=DESKTOP_VOICE_COMMAND=true`; uploads full `build/windows/x64/runner/Release/` via `actions/upload-artifact@v4`.
* **`docs/DESKTOP_WINDOWS_ARTIFACT.md`:** [shipped] download/run instructions — no local Visual Studio required to run the artifact; VS C++/ATL only for local `flutter build windows`.

## [2026-06-24] - Desktop Price Reporter structured voice command MVP [shipped]
* **`lib/features/shared/voice_command_parser.dart`:** [shipped] deterministic `parsePriceReporterVoiceCommand` — required `Price Reporter` root scope, existing child-category prefix match, task title extraction, exact/ambiguous/no_match states; reuses `price_reporter_client_match` generic-task token guard.
* **`lib/features/shared/desktop_voice_command_panel.dart`:** [shipped] desktop-only floating dialog — listening transcript, resolved path/title, visible error/ambiguity; never barrier-dismiss during capture.
* **`lib/core/services/desktop_voice_hotkey*.dart`:** [shipped] Ctrl+Shift+Space global (`hotkey_manager`) + in-app `Shortcuts` fallback; **`kDesktopVoiceCommandEnabled`** kill switch default **false** (`--dart-define=DESKTOP_VOICE_COMMAND=true`).
* **`lib/app_shell.dart`:** [shipped] `_toggleDesktopVoiceCommandPanel` / `_desktopVoiceSubmitParsed` → existing `DatabaseService.writeRecord` + timeline shadow path.
* **`test/voice_command_parser_test.dart`:** [shipped] exact, no-match, ambiguous, title-extraction tests.

## [2026-06-24] - Price Reporter read-only CSV timesheet export script [shipped]
* **`scripts/manual/export_price_reporter_timesheet.dart`:** [shipped] read-only PocketBase export for Price Reporter timeline records (2026-05-11 wall → now); profile wall-clock clamp/overlap; deterministic client extraction; main + audit CSV under `exports/`. Price Reporter timesheet export now classifies Client only into existing Price Reporter child categories using app category keyword rules.

## [2026-06-15] - Time View reproject on profile timezone change [wip]
* **`plan_service.dart`:** [wip] `reprojectAllPlansForProfileTimezone` re-keys optimistic overlay, bumps `profileTimezoneProjectionRevision`, invalidates plans body/P0T render caches, pokes all planning stream hubs; `plansProjectionCacheSignature` includes tz offset/label (not date-only length).
* **`planning_view.dart`:** [wip] timezone settings listener refreshes `_latestPlanningDayTasks` from snapshot, clears Time View layout/cascade keys, `ValueKey` on hour grid ListView forces repaint.
* **`test/plan_time_timezone_projection_test.dart`:** [wip] Moscow/NY wall projection, Y scale shift, wall-day filter, cache signature, layout invariants.

## [2026-06-15] - Header timezone quick switcher [wip]
* **`profile_timezone_catalog.dart`:** [wip] shared profile timezone catalog + picker labels (`Moscow · MSK · UTC+3`); used by Profile settings and header quick picker.
* **`timezone_quick_picker.dart`:** [wip] `HeaderTimezoneQuickSwitcher` — tap timezone label in `GlobalAppHeader`; adaptive sheet (mobile) / menu (desktop); search filter.
* **`global_app_header.dart`:** [wip] date row and timezone label are separate tap targets; timezone opens quick picker only.
* **`profile_service.dart`:** [wip] `updateTimeZone` — optimistic reproject before PATCH; rollback + reproject on profile save failure; no records/plans PATCH.
* **`profile_view.dart`:** [wip] timezone dropdown uses shared catalog labels.
* **`test/profile_timezone_catalog_test.dart`:** [wip] catalog labels, legacy GMT+3 match, filter, offset helper.

## [2026-06-15] - P0 Time View shared TimeViewYScale coordinate system [wip]
* **`plan_time_view_layout.dart`:** [wip] `TimeViewYScale` — single global `rubberPxPerMinute`; `yForMinute`/`minuteForY`/`hourLineY` shared by cards + hour rail/grid; adjacent 4px packing; packed-to-wall clearance formula; debug logs `[TIME_Y_SCALE]`, `[TIME_LAYOUT_CARD]`, `[TIME_LAYOUT_ASSERT]`, `[TIME_LAYOUT_ERROR]`, `[TIME_LAYOUT_PACK]`.
* **`planning_view.dart`:** [wip] hour labels at `grid.hourLineY(i)`; hour bands fixed `hourBandHeightPx` overlay (not per-bucket row separators).
* **`test/plan_time_view_layout_test.dart`:** [wip] tests A–F crossing cards, adjacent A/B/C chain, 45-min slot, real gap, no bucket-separator bug, uniform hour spacing.

## [2026-06-23] - Time View rubber minute scale + empty slot layout [wip]
* **`plan_time_view_layout.dart`:** [wip] rubber `pxPerMinute` per hour from `cardMinHeight/duration`; card height = `duration * rubber`; hour stretches only for adjacent packed chains (+4px gap); overlap-aware hour buckets; empty slot preserved for partial-hour cards (e.g. 12:00–12:45 leaves 12:45–13:00 visible).
* **`plan_time_task_card.dart`:** [wip] `kPlanTimeCardGapPx` 2→4 for adjacent card packing gap.
* **`test/plan_time_view_layout_test.dart`:** [wip] rubber scale tests A–G (45-min slot, adjacent 4px gap, real schedule gap, dense chain).
* **`test/plan_time_target_drop_test.dart`:** [wip] empty-slot drop test J (finger in 12:45–13:00 → emptyCanvas).

## [2026-06-23] - P0 Time View card-on-card drop finger resolver [wip]
* **`plan_time_sequential_cascade.dart`:** [wip] `TimeViewCardLayout`, `TimeViewDropIntent`, `resolveTimeViewDropIntent`, `buildTimeViewInsertionIntentFromDropIntent`, `assertTimeViewTargetCardNoRawY` — finger-position hit-test with absolute target-card priority; empty canvas only when finger outside all card rects.
* **`planning_view.dart`:** [wip] `_timelineFingerGrabOffsetCanvasPx` + pointer-down offset capture; preview and commit both call central resolver (no stored-intent / card-center / raw-Y fallback on card-on-card).
* **`test/plan_time_target_drop_test.dart`:** [wip] tests A–J for finger upper/lower half, preview-vs-commit parity, follower/predecessor cascade, empty canvas isolation.

## [2026-06-23] - Planning Time View: single Day length range slider [wip]
* **`plan_time_visible_window.dart`:** [wip] extended hour window math (−3..27), overlap filter, wall↔minutes mapping; shared by prefs, Brain, tests.
* **`planning_day_start_prefs.dart`:** [wip] `visibleDayStartHourExtended` / `visibleDayEndHourExtended` prefs + legacy migration (start=20/end=2 → 20→26).
* **`planning_view.dart`:** [wip] one `RangeSlider` “Day length / Длительность дня”; adjacent-day task merge for after-midnight window; extended hour rail markers.
* **`plan_service.dart`:** [wip] overload + auto-schedule use extended window start wall.
* **`test/plan_time_visible_window_test.dart`:** [wip] migration, overlap, y→time 25:30, now-line window cases.
* **`lib/l10n/langs/en.dart`**, **`ru.dart`:** [wip] `day_length_*` strings.

## [2026-06-23] - P0 Time View drag-over-card hard guard [wip]
* **`plan_time_sequential_cascade.dart`:** [wip] `TimeViewInsertionSource`, `validateTimeViewTargetInsertionIntent`, `refreshTimeViewInsertionIntentFromScheduled`, `isPlanTimelineVerticallyDraggable`, debounced `logTimeDropGuard` — target-card mode forbids raw-Y fallback.
* **`planning_view.dart`:** [wip] finger vs preview delta split (`_timelineFingerDragDeltaPx`); stored target-card intent preferred on commit; invalid/orphan target intent cancels without PATCH; empty canvas uses finger yToTime only.
* **`test/plan_time_target_drop_test.dart`**, **`test/plan_time_sequential_cascade_test.dart`:** [wip] before/after upper-lower card, raw-Y ignore, validation cancel, refresh-before-commit.

## [2026-06-23] - Final release repository structure cleanup [shipped]
* **`docs/APP_STRUCTURE.md`:** [shipped] Release-only manifest — no debt/quarantine language; all 126 `lib/` Dart files + layer import rules + folder-level platform/test/docs rules.
* **`docs/APP_STRUCTURE_EXPLAINED_RU.md`:** [shipped] Practical Russian “where to edit” guide for Nick.
* **`scripts/audit/architecture_guard.ps1`:** [shipped] `-Strict` enforces manifest, boundaries, no experiment filenames, no root barrels, no tracked build artifacts.
* **Deleted:** `Archive/` (30 files), `lib/data/base_database.dart`, `lib/core/subscription/app_tier.dart`, root barrels `lib/database_service.dart`, `lib/models.dart`, `lib/auth_screen.dart`, `lib/auth_service.dart`.
* **Renamed/migrated:** P0/perf files → `core/diagnostics/*`, `core/performance/rebuild_metrics.dart`, `core/performance/runtime_flags.dart`, `data/cache/*`; `smart_input_parser.dart` → `data/`; `wall_clock.dart` → `core/time/`; `chip_component.dart` + `tag_contrast.dart` → `core/`; `oauth_session.dart` in `features/auth/`.
* **Boundaries:** `AppClock`, `PlanCategoryLookup`, `TagDisplayModeScope`, `web_redirect.dart` shell injection; Brain no longer imports `features/`; core widgets no longer import `database_service.dart`.
* **`lib/l10n/`:** [shipped] Single EN/RU source — `langs/en.dart` + `langs/ru.dart`; `dictionary.dart` assembler only.

## [2026-06-23] - P0 Plans realtime 404: stream hub + sync banner stuck fix [wip]
* **`plan_service.dart`:** [wip] ref-counted `_PlanningDayStreamHub` (one hub per day/listen); plans realtime backoff + 404 session disable; safe subscribe catchError.
* **`db_core.dart`:** [wip] `_markRealtimeEndpointUnavailable` on `/api/realtime` 404; PB realtime onDisconnect guards.
* **`offline_sync_state.dart`:** [wip] `reconcileStuckSyncingBanner` when pending=0.
* **`planning_view.dart`:** [wip] stable `_planningStreamForCurrentDay`; no stream recreate on tz/move.
* **`main.dart`:** [wip] `runZonedGuarded` for uncaught async errors.
* **`test/planning_realtime_stream_lifecycle_test.dart`:** [wip] sync banner + lifecycle contract.

## [2026-06-23] - P0 diagnostic cleanup: delete dead lib/core trace/diag files [wip]
* **Deleted:** `p0_date_nav_diag`, `p0n_perf_diag`, `p0o_warm_diag`, `p0r_prebuild_diag`, `p0s_mount_diag`, `p0t_diag`, `p0p_content_diag`, `pre_white_swipe_restore`, `mounted_day_registry`, `app_diag`, `time_drop_trace` + all call sites.
* **Kept:** `p0u_feature_flags`, `p0u_diag`, `p0u_startup_diag` (defer queue), `perf_diag`/`perf_flags`, `plan_dup_trace`, `app_build_info`, `date_pager_settle_gate`.
* **Logging:** boot/frame-gap summary only in debug; release guard + APP_BUILD unchanged.

## [2026-06-23] - P0 Planning duplicate cards: warmWindow guard + cache/stream scrub [wip]
* **`p0u_feature_flags.dart`:** [wip] `kPlansWarmWindowEnabled=false` — P0 duplicate safety; no warm cache mutation before Plans opens.
* **`plan_service.dart`:** [wip] `scrubPlanningTasksForLocalCache` on restore/day cache/merge; idempotent `expandRecurringPlans`; mandatory stream dedupe in `_mergePlanningOptimistic`; virt blocked from `_allPlansUserCache`.
* **`planning_view.dart`:** [wip] initial/waiting tasks from `planningDayTasksSnapshot` + dedupe (not polluted warm disk).
* **`test/planning_duplicate_plan_guard_test.dart`:** [wip] scrub, expansion idempotency, distinct same-title plans.

## [2026-06-23] - P0U cleanup: remove temporary Timeline diagnostics after P0U.7 [wip]
* **Deleted:** `p0u_timeline_swipe_diag.dart`, `p0u_timeline_vm_build_diag.dart` — P0U.4–P0U.6D per-frame/swipe/VM trace helpers.
* **`p0u_diag.dart`:** [wip] trimmed to production-safe markers only (`releaseLogGuard`, `biometricGate`, `adjVmWarmDisabled`, errors).
* **`record_service.dart`:** [wip] removed VM build `Stopwatch` instrumentation; kept O(1) `_cachedCanonicalRunningBusinessId`; removed `timelineTargetDay*Probe` helpers.
* **`timeline_view.dart` / `planning_view.dart`:** [wip] removed first-swipe/target-state diagnostic wiring; stable PageView behavior unchanged.
* **`p0u_startup_diag.dart`:** [wip] verbose boot logs gated off in release; `[P0U_BOOT_SUMMARY]` / `[P0U_FRAME_GAP_SUMMARY]` remain debug-only.
* **Accepted P0U.5/P0U.7 metrics preserved:** VM build ~491ms → ~0–2ms; `TARGET_VM_READY` 0ms; canonical running id O(1); `kTimelineAdjacentRowVmWarmup=false`.

## [2026-06-23] - P0 Planning Tags duplicate cards after Time View cascade [wip]
* **`plan_service.dart`:** [wip] stop upserting `virt-*` rows into `_allPlansUserCache`; scrub on fetch; idempotent `applySequentialTimeViewCascadeIfNeeded`; `dedupePlanningTasksForDisplay` + `[PLAN_DUP_TRACE]`.
* **`planning_view.dart`:** [wip] remove cascade from Time View `build()` (one-shot post-frame per day); UI de-dupe in `_displayTasks`; scrub virt on page init.
* **`lib/core/plan_dup_trace.dart`:** [wip] gated duplicate diagnostics.
* **`test/planning_duplicate_plan_guard_test.dart`:** [wip] dedupe, cascade idempotency, virt+materialized guard.

## [2026-06-15] - P0U.7: O(1) canonical running business id for Timeline VM [accepted]
* **`database_service.dart` / `record_service.dart`:** [accepted] `_cachedCanonicalRunningBusinessId` + dirty flag; recompute on `timelineEmit`, boot restore, fetch; O(1) read in `_buildTimelineRowVmsForDate`.
* **`db_core.dart`:** [accepted] sync on prefs hydrate; reset on sign-out.

## [2026-06-15] - P0U.5: canonical running id once per Timeline day VM build [accepted]
* **`record_service.dart`:** [accepted] `resolveCanonicalPrimaryRunningBusinessId()` computed once in `_buildTimelineRowVmsForDate`; passed into row VM builders — removes N× `_cachedFlatRecords` scan per swipe.

## [2026-06-15] - P0U.7: O(1) canonical running business id for Timeline VM [wip]
* **`database_service.dart` / `record_service.dart`:** [wip] `_cachedCanonicalRunningBusinessId` + dirty flag; recompute on `timelineEmit`, boot restore, fetch; O(1) read in `_buildTimelineRowVmsForDate`.
* **`db_core.dart`:** [wip] sync on prefs hydrate; reset on sign-out.
* **Diagnostics:** [wip] `[P0U_RUNNING_BIZ_CACHE] event=dirtyRecompute|invalidate` (debug only, no per-row spam).

## [2026-06-15] - P0U.6D: first-drag frame diagnostics + TARGET_STATE source fix [wip]
* **`p0u_timeline_swipe_diag.dart`:** [wip] `DRAG_FRAME_BEGIN`, `TARGET_PAGE_STATE_BEFORE_DRAG`, `TARGET_PAGE_ATTACH`, `TARGET_CHILD_BUILD`, `TARGET_CHILD_LAYOUT_HINT`, `DRAG_FRAME_DONE` (culprit heuristic); `TARGET_STATE` now includes `source=`.
* **`timeline_view.dart`:** [wip] wires page/list lifecycle probes; `TARGET_STATE` records from `timelineTargetDayDataReadyProbe` (matches `TARGET_DATA_READY`).
* **`record_service.dart`:** [wip] `timelineTargetDayCacheSnapshot` adds `dayWidgetCached` for before-drag probe.

## [2026-06-15] - P0 Time View target drop v2: stored intent + explicit-order cascade [wip]
* **`plan_time_sequential_cascade.dart`:** [wip] `TimeViewInsertionIntent`, `buildExplicitOrderForTargetInsert`, `cascadeScheduledPlansForExplicitTimeViewOrder`, `applyTimeViewTargetInsertion` — target drop no longer sorts by start time.
* **`planning_view.dart`:** [wip] drag-over stores insertion intent; commit prefers stored intent over release hit-test; preview/commit share `applyTimeViewTargetInsertion`; empty canvas still uses yToTime.
* **`plan_service.dart`:** [wip] `applyTimeViewTargetInsertion` Brain wrapper.
* **`lib/core/time_drop_trace.dart`:** [wip] gated `[TIME_DROP_TRACE]` debug logs (debug builds only).
* **`test/plan_time_target_drop_test.dart`:** [wip] explicit order beats old start/raw Y, stored intent fallback, before-target, preview=commit.

## [2026-06-15] - P0U.5: canonical running id once per Timeline day VM build [wip]
* **`record_service.dart`:** [wip] `resolveCanonicalPrimaryRunningBusinessId()` computed once in `_buildTimelineRowVmsForDate`; passed into `_timelineRowVmFromMap` / subtitle — removes 11× `_cachedFlatRecords` scan.
* **`p0u_timeline_vm_build_diag.dart`:** [wip] `canonicalPrimaryRunningBiz_once` step; per-row `canonicalPrimaryRunningBiz_call` no longer on hot path.

## [2026-06-15] - P0 Time View target drop adjacent insertion + darker canvas [wip]
* **`plan_time_sequential_cascade.dart`:** [wip] `computeTimeViewTargetDropSchedule` — exact before/after target wall times, zero scheduled gap.
* **`planning_view.dart`:** [wip] target hit-test at commit; preview Y/label from target wall times not raw `yToTime`; free canvas still uses snap; canvas `surfaceContainerHigh`/`surfaceContainerHighest` blend darkened.
* **`test/plan_time_target_drop_test.dart`:** [wip] lower/upper half, yToTime ignored, preview=commit, cascade.

## [2026-06-15] - P0U.4R3: line-level Timeline VM diagnostics (microsecond accounting) [wip]
* **`p0u_timeline_vm_build_diag.dart`:** [wip] microsecond `Stopwatch` accounting; line-level `stepOrder`; `unmeasuredOtherMs` on DONE; nested subtitle steps; single `[P0U_TIMELINE_VM_SLOWEST_RECORD]` breakdown.
* **`record_service.dart`:** [wip] `_timelineRowVmFromMap` / `_timelineSubtitleForRecordMap` instrument `mapAccess_*`, `canonicalPrimaryRunningBiz_call`, `categoryDisplayPath_call`, `cachePut`, `loopOverhead`, etc.

## [2026-06-15] - P0U.4R2: deep per-record Timeline VM build diagnostics [wip]
* **`p0u_timeline_vm_build_diag.dart`:** [wip] `P0uTimelineVmRecordBuildSession` per-record steps; day `STEP_TOTAL` with `explainedMs`/`unexplainedMs`; single `[P0U_TIMELINE_VM_SLOWEST_RECORD]` breakdown.
* **`record_service.dart`:** [wip] `_timelineRowVmFromMap` / `_timelineSubtitleForRecordMap` instrument `recordForTimelineCard`, `timeProjection`, `timezoneFormat`, `categoryLookup`, `breadcrumbPath`, `checklistNotesFlags`, `progressDuration`, `subtitleBuild`, `colorConversion`, `objectCreate`, `unmeasuredOther`.

## [2026-06-15] - P0 Time View sequential cascade (no conflict layout) [wip]
* **`plan_time_sequential_cascade.dart`:** [wip] pure `cascadeScheduledPlansForTimeViewDay` / `diffSequentialCascadePatches` — overlap → shift down, preserve duration, cascade chain.
* **`plan_service.dart`:** [wip] `applySequentialTimeViewCascadeIfNeeded` optimistic + background PATCH; `resolveAutoPlanSchedule` probe cascade; `addPlanningTask` day normalize after create.
* **`planning_view.dart`:** [wip] day-load normalize before projections; drag cascade all scheduled rows; `timelineScheduleConflict: false`.
* **`plan_time_view_layout.dart`:** [wip] removed `hasScheduleConflict` detection loop.
* **`test/plan_time_sequential_cascade_test.dart`:** [wip] overlap, drag-after, chain, duration, quick-add, virt recurring.

## [2026-06-15] - P0U.4R: disable adjacent VM warmup + VM builder step diagnostics [wip]
* **`p0u_feature_flags.dart`:** [wip] `kTimelineAdjacentRowVmWarmup = false` (P0U.4 rollback).
* **`p0u_timeline_vm_build_diag.dart`:** [wip] `[P0U_TIMELINE_VM_BUILD_*]` step timings; `[P0U_TIMELINE_ADJ_VM_WARM_DISABLED]`.
* **`record_service.dart`:** [wip] Instrument `_timelineRowVmFromMap` / `_buildTimelineRowVmsForDate` per-step (no per-record spam).
* P0U.4D swipe diagnostics preserved; no VM optimization yet.

## [2026-06-15] - P0 Time View VerySmall/Small reference element sizes [wip]
* **`plan_time_task_card.dart`:** [wip] Remove scaled-down VerySmall path (26px controls, 7px micro tags, 28px menu); restore 32px checkbox/play, 33px menu, CardPlan title typography, vertical tag stack with standard compact pills; 38px density threshold unchanged.

## [2026-06-15] - P0U.4: Timeline adjacent row-VM warmup [wip]
* **`record_service.dart`:** [wip] Post-firstFrame chunked warmup for ±1 day row VMs (`_timelineDayVmCache` + lazy per-row cache); kill switch `kTimelineAdjacentRowVmWarmup`.
* **`timeline_view.dart`:** [wip] Schedule warmup when Timeline tab visible; re-warm after page settle.
* **`p0u_feature_flags.dart`:** [wip] `kTimelineAdjacentRowVmWarmup` flag.
* P0U.4D swipe diagnostics preserved.

## [2026-06-15] - P0 Time View CardPlan responsive visual fix [wip]
* **`plan_time_task_card.dart`:** [wip] Remove list-row minHeight on explicit Time View density path; `_TimeViewResponsiveShell` / `_TimeViewVerticalShell` anchors (fixed rail + expanding center + menu cluster); `_TimeViewTagsRow` shows all tags; density bodies match CardPlan refs at 38–95px+ without fixed card width.
* **`plan_card.dart`:** unchanged — still passes parent width + `timelineBlockHeightPx` only.

## [2026-06-15] - P0U.4D: Timeline first-swipe diagnostics only [wip]
* **`p0u_timeline_swipe_diag.dart`:** [wip] First-swipe target logging, cache state, step timings, frame jank summary.
* **`timeline_view.dart`:** [wip] Correct swipe target date; TARGET_* probes on first swipe only.
* **`record_service.dart`:** [wip] `timelineTargetDayCacheSnapshot` / data+VM probes (no full scans).
* **`p0u_startup_diag.dart` / `main.dart`:** [wip] First-frame marker armed/fired/delay + deferred-before-frame guard.
* Diagnostics only — no paging/warmup behavior changes.

## [2026-06-15] - P0 Time View CardPlan density visual fix [wip]
* **`plan_time_task_card.dart`:** [wip] Explicit Time View layouts per CardPlan band (VerySmall→Medium); tags always visible; removed `timelineFillHeight` tag suppression.
* **`plan_card.dart`:** [wip] Pass `timelineVisualDensity` + fixed height; `timelineFillHeight: false` for Time View blocks.

## [2026-06-15] - P0U.3: emergency rollback of P0U.2 first-frame regression [wip]
* **`p0u_feature_flags.dart`:** [wip] Kill switch — `kShellDeferHiddenTabsUntilFirstFrame = false` (P0U.2 regressed firstFrameMs 4668 vs P0U.1 1511).
* **`p0u_startup_diag.dart`:** [wip] `scheduleAfterFirstFrame` + `[P0U_BOOT_DEFERRED_CONFIRMED_AFTER_FRAME]` logs.
* **`db_core.dart`:** [wip] Deferred boot (warm windows, sync, realtime) queued until after first rendered frame.
* P0U.1 profile cache, diagnostics, liveOptimistic, stable PageView preserved.

## [2026-06-15] - P0 Time View bounded layout regression fix [wip]
* **`plan_time_view_layout.dart`:** [wip] Separate stable card height (`kPlanTimeStableBaseCardPxPerMinute`) from bounded hour stretch; sequential one-column placement; 480px hour cap.
* **`plan_time_task_card.dart`:** [wip] `planTimeCardRenderedHeightPxForDuration`, layout constants.
* **`plan_service.dart`:** [wip] `_avoidPlanWallScheduleCollisions` — sequential auto-schedule when slots collide.
* **`test/plan_time_view_layout_test.dart`:** [wip] Density, 5/10min, dense-hour, y/time tests.

## [2026-06-15] - P0U.2: shrink firstShellBuild→firstFrame gap [wip]
* **`p0u_startup_diag.dart`:** [wip] `[P0U_FRAME_GAP_*]` / `[P0U_SHELL_BUILD]` / `[P0U_TAB_BUILD]` / `[P0U_HIDDEN_TAB_*]` diagnostics.
* **`app_shell.dart`:** [wip] `kShellDeferHiddenTabsUntilFirstFrame` → `LazyIndexedStack` (active tab only on first paint); defer timeline tasks + shell sync bootstrap post-frame.
* **`lazy_indexed_stack.dart`:** [wip] Boot defer + tab activation logs.
* **`timeline_view.dart`:** [wip] First paint from `peekTimelineRecordsForDate` only; defer `recordsStream` until post-frame; remove hot-path `timelineBodyEntryForDate`.
* P0U recovery preserved.

## [2026-06-15] - P0U.1: startup timing diagnostics + boot hot-path cleanup [wip]
* **`p0u_startup_diag.dart`:** [wip] `[P0U_BOOT_STAGE]` / `[P0U_BOOT_DEFERRED]` / `[P0U_BOOT_SUMMARY]` stopwatch logger.
* **`main.dart`:** [wip] Boot stage timings; defer non-current `initializeDateFormatting` locales; first shell/first frame markers.
* **`db_core.dart`:** [wip] Critical path only (categories + prefs records + disk warm restore); `_runDeferredBootWorkAfterFirstShell` for network fetch, warm windows, realtime, sync.
* **`profile_service.dart`:** [wip] Device cache-first profile boot (`cacheThenServer`); background PB refresh; `[P0U_PROFILE_*]` logs.
* **`record_service.dart`:** [wip] `bootstrapTimelineRecordsCacheFromPrefsAtBoot(criticalOnly: true)` skips warm/prebuild on hot path.
* **`app_shell.dart`:** [wip] STT init deferred post-first-frame.
* P0U recovery preserved (`kUseP0tMountedStrip=false`, stable PageView, live optimistic sources).

## [2026-06-15] - P0V: Performance Kill Switch Law — speed/stability as sacred project law [wip]
* **`docs/ARCHITECTURE.md`:** [wip] New Iron Rule § **PERFORMANCE_KILL_SWITCH_LAW** — hard-stop conditions, emergency response, preload/snapshot/logging/hot-path rules.
* **`docs/UX_CONTRACT.md`:** [wip] § **Performance & Responsiveness Contract** — ~100ms feedback, no partial cards, performance regression = P0 correctness bug.
* **`docs/AI_CONTEXT.md` / `CLAUDE.md` / `docs/ROADMAP.md`:** [wip] AI emergency stabilization protocol; performance regressions outrank V3/V7; banned “cache exists” excuses.
* **`lib/core/perf_flags.dart` / `p0u_feature_flags.dart` / `app_build_info.dart`:** [wip] P0V law comments; experimental paths default-off; `p0vPerfKillSwitchMarker`.
* **Not shipped** until docs reviewed and team confirms law is in force.

## [2026-06-15] - P0U: emergency recovery — disable P0S/P0T, restore stable paging [wip]
* **`p0u_feature_flags.dart` / `p0u_diag.dart` / `p0u_platform.dart`:** [wip] Global kill switch `kUseP0tMountedStrip=false`; `[P0U_*]` diagnostics (pager mode, first swipe, record optimistic, release log guard).
* **`planning_view.dart` / `timeline_view.dart`:** [wip] Restored stable `PageView.builder` + `DatePagerSettleGate` + `FeatherDateSwipePhysics`; active day uses live planning stream / live optimistic records; P0S/P0T `EagerDayContentStrip` behind flag only.
* **`database_service.dart` / `record_service.dart`:** [wip] `_emitTimelineRefreshRaw` clears `_timelineDayViewCache`; `peekTimelineRecordsForDate` skips stale view cache when day index dirty; record create optimistic `[P0U_RECORD_*]` logs.
* **`plan_service.dart`:** [wip] `TIME_TZ_PROJECT` per-row logs gated behind `kVerbosePlanTimeTzProjectionLogs` + `!kReleaseMode`.
* **`db_core.dart`:** [wip] Boot skips P0T mounted/render window when flag false; light `ensurePlansWarmWindow` / `ensureTimelineWarmWindow` only.
* **`main.dart`:** [wip] Biometric gate stays off; `FlutterError.onError` + `PlatformDispatcher.onError` → `[P0U_WEB_ERROR]` / `[P0U_ANDROID_ERROR]`.
* **P0S / P0T:** marked failed/superseded as production default — not shipped until user confirms web + APK.

## [2026-06-23] - Repo structure lockdown: full manifest + architecture guard [shipped]
* **`docs/reports/REPO_STRUCTURE_LOCKDOWN_2026-06-23.md`:** [shipped] Full-repo inventory (351 paths); safe cleanup actions; quarantine notes for `Archive/`.
* **`docs/APP_STRUCTURE.md`:** [shipped] Expanded to full file contract (§4–14): lib/test/scripts/docs/platform/pb_hooks manifests; P0U perf debt documented.
* **`scripts/audit/architecture_guard.ps1`:** [shipped] Warning-mode guard: forbidden imports, undocumented lib files, deleted-file regression, large-file warnings.
* **Cleanup:** [shipped] Archived `build_error.txt`, `perf_chrome_log.txt` → `docs/archive/structure_cleanup_2026-06-23/`; `git rm android/build/reports/problems/problems-report.html`; `.gitignore` perf capture + `android/build/`.
* **Verify:** analyze green; test 57 pass / 3 runtime fail (known); web build green. `update.ps1` not run (docs/non-runtime only).

## [2026-06-22] - Stage A cleanup + A.1 compile baseline + Stage C doc sync [shipped]
* **Stage A [shipped]:** Deleted proven orphans/non-code — `p0b_logcat.txt`, `lib/notes` (archived to `docs/archive/lib_notes_scratch.txt`), `lib/deploy.ps1`, `lib/data/html_stub.dart`, `lib/features/more/more_view.dart`, `lib/features/timeline/timeline_widgets.dart`. No P0/perf/warm files touched; More menu stays inline in `app_shell.dart` `_openMoreMenu`; Timeline header stays inline in `timeline_view.dart`.
* **Stage A.1 [shipped]:** `planning_view.dart` — added `p0n_perf_diag.dart` import; restored `_PlanningDayCardListKeepAlive` keep-alive wrapper for offscreen PageView day bodies. `flutter analyze --no-fatal-infos --no-fatal-warnings` green.
* **Stage C [shipped]:** Doc sync — `docs/APP_STRUCTURE.md`, `CLAUDE.md`, `docs/ROADMAP.md`, `docs/reports/CODEBASE_CLEANUP_AUDIT_2026-06-22.md`, `docs/reports/DESIGN_SYSTEM_INVENTORY.md` (cleanup note only).
* **Tests:** `flutter test` loads/runs; 3 runtime failures remain in perf/widget harness — not compile blockers, unrelated to Stage A deletes.

## [2026-06-15] - P0T: emergency stabilize + atomic fully-rendered date pages [wip]
* **`p0t_render_snapshot.dart` / `p0t_diag.dart`:** [wip] `PlanCardRenderDto` / `PlansDayRenderSnapshot` + `TimelineDayRenderSnapshot`; FULL_READY checks; `[P0T_*]` diagnostics.
* **`plan_service.dart` / `record_service.dart` / `db_core.dart`:** [wip] Critical ±1 boot only; background full window warm; render snapshots built at body prep; startup no longer blocks on 21-body mount.
* **`mounted_day_window.dart`:** [wip] Mount radius ±3 (7 bodies) — P0S ±10 superseded for widget mount.
* **`eager_day_content_strip.dart`:** [wip] P0T reveal gate blocks not-ready dates; scroll index guards; controller attach fix.
* **`planning_view.dart`:** [wip] Atomic frozen cards (play/tags/category from render DTO); inactive Time mode uses same hour grid; reveal gate wired.
* **`timeline_view.dart`:** [wip] `FeatherDateSwipePhysics` (20% threshold); reveal gate; critical render ready at open.
* **`main.dart`:** [wip] Biometric gate disabled (`kP0tBiometricGateDisabled`); `FlutterError.onError` → `[P0T_CRASH_TRACE]`.
* **P0S:** marked failed/superseded — not shipped.

## [2026-06-15] - Time View: CardPlan density + stretchable hour scale [wip]
* **`plan_time_view_layout.dart`:** [wip] Pure layout calculator — per-hour variable height, sequential card reflow (min 38px + 2px gap), `PlanTimeViewDurationGrid` y↔time mapping shared by render/drag/resize/now line.
* **`plan_time_task_card.dart`:** [wip] `PlanTimeCardVisualDensity` bands (VerySmall 38 / Small 39–54 / MoreCompact 55–77 / Compact 78–94 / Medium 95+); progress/breadcrumb gates per band.
* **`planning_view.dart` / `plan_card.dart`:** [wip] Wire stretchable grid; darker Time View canvas (`surfaceContainerHighest` blend); density from final rendered height.
* **`test/plan_time_view_layout_test.dart`:** [wip] Layout invariants — 11×5min dense hour, density bands, mixed dense/normal hour.

## [2026-06-15] - P0S: eager mounted content pages ±10 [failed — superseded by P0T]
* **`eager_day_content_strip.dart` / `mounted_day_window.dart` / `p0s_mount_diag.dart`:** [wip] Row-based horizontal strip mounts all ±10 day bodies eagerly (not lazy `PageView.builder`); extend/evict at 41 max; `[P0S_*]` diagnostics.
* **`planning_view.dart` / `timeline_view.dart`:** [wip] Replaced date `PageView.builder` with `EagerDayContentStrip`; static chrome unchanged outside strip.
* **`plan_service.dart` / `record_service.dart`:** [wip] `preparePlansMountedWindowBoot` / `prepareTimelineMountedWindowBoot`; Timeline warm snapshots disk persist (`warm_timeline_snapshots_v1`).
* **`db_core.dart`:** [wip] Boot: disk restore → prepare mounted window data → persist snapshots; network after.

## [2026-06-15] - P0R: critical adjacent prebuild + persistent warm snapshots [wip]
* **`rendered_day_body_cache.dart` / `p0r_prebuild_diag.dart`:** [wip] `TimelineDayBodyEntry` / `PlansDayBodyEntry` with `bodyReady`; critical sync prebuild (±1) before first swipe; chunked ±10 window prebuild; `[P0R_*]` diagnostics.
* **`plan_service.dart`:** [wip] `restorePlansWarmSnapshotsFromDiskAtBoot` / `persistPlansWarmSnapshotsToDisk` (`warm_plans_snapshots_v1`); `plansBodyEntryForDate` sync cache hit path.
* **`record_service.dart`:** [wip] `timelineBodyEntryForDate`; `prebuildTimelineCriticalBodiesSync`; boot disk restore log for Timeline flat records.
* **`db_core.dart`:** [wip] Boot sequence: restore disk → network → critical prebuild → background ±10.
* **`planning_view.dart` / `timeline_view.dart`:** [wip] PageView reads body cache; first-swipe `[P0R_FIRST_SWIPE_TARGET]` logs; screen open re-prebuilds critical 3.
* **Preserved:** content-only PageView (P0P), `PageView.builder`, `DatePagerSettleGate`, no full pages in cache.

## [2026-06-15] - P0P: content-only date paging + rendered day-body warm window [wip]
* **`timeline_view.dart`:** [wip] Static chrome (list/stats toggle, input) mounted once in [TimelinePage]; [PageView] pages only `_TimelineDayCardList` with real `_TimelineLazyRecordList` cards + `AutomaticKeepAliveClientMixin`.
* **`planning_view.dart`:** [wip] Static chrome (sort tabs, tag strip, quick-add) mounted once; [PageView] inside `_buildPlanningMainColumn` pages only day card lists; tag loader removed from date pages (`SizedBox.shrink` until tags ready); `FeatherDateSwipePhysics` preserved.
* **`rendered_day_body_cache.dart` / `p0p_content_diag.dart`:** [wip] Render warm radius 3 / max 7 bodies; `[P0P_*]` diagnostics.
* **Preserved:** `PageView.builder`, `DatePagerSettleGate`, P0O data warm window (±10), shell `selectedDate`.

## [2026-06-15] - P0O: rolling warm day window for Plans/Timeline date paging [wip]
* **`warm_day_window.dart` / `p0o_warm_diag.dart`:** [wip] `TimelineDaySnapshot` / `PlansDaySnapshot` + `WarmSnapshotWindow` (radius 10, extend 10 @ threshold 3, max 41 LRU); `[WARM_*]` diagnostics.
* **`record_service.dart`:** [wip] `ensureTimelineWarmWindow` / `extendTimelineWarmWindowIfNeeded` / `timelineWarmSnapshotForDate`; boot hydrate builds ±10 snapshots from prefs day index; network merge keeps local + refreshes stale snapshots.
* **`plan_service.dart`:** [wip] `ensurePlansWarmWindow` / `extendPlansWarmWindowIfNeeded` / `plansWarmSnapshotForDate`; refresh on `notifyPlanningRefresh`.
* **`timeline_view.dart` / `planning_view.dart`:** [wip] PageView slots render from warm snapshots sync (no AppLoading/skeleton on swipe); active page seeds from snapshot then live stream patches; extend window on date commit.
* **Preserved:** `PageView.builder`, `DatePagerSettleGate`, shell `selectedDate` — no P0H–P0L pager experiments.

## [2026-06-15] - P0N: restored PageView performance pass [wip]
* **`record_service.dart` / `db_core.dart`:** [wip] `bootstrapTimelineRecordsCacheFromPrefsAtBoot()` before network fetch (incl. PB backoff path); day index from prefs; `fetchRecords` keeps local cache when network returns empty (`TIMELINE_CACHE_REFRESH_MERGE`); `peekTimelineRecordsForDate` sync lookup + P0N logs.
* **`timeline_view.dart`:** [wip] SWIPE GUARD comment; adjacent slots render cached day list via `peekTimelineRecordsForDate` (no stream/network); `RepaintBoundary` on PageView children; preload coalesced records in `initState`.
* **`planning_view.dart`:** [wip] SWIPE GUARD comment; `FeatherDateSwipePhysics` (20% commit) vs default `PageScrollPhysics`; adjacent days use `planningDayTasksSnapshot` + frozen `PlanCard` list; active-only stream/listeners; P0N swipe/render logs.
* **`p0n_perf_diag.dart`:** [wip] `[TIMELINE_*]` / `[PLANS_*]` debug diagnostics.
* **Preserved:** `PageView.builder`, `DatePagerSettleGate`, shell `selectedDate` ownership — no P0H–P0L pager experiments.

## [2026-06-22] - Emergency: restore pre-white-design PageView date swipe [wip]
* **Root cause:** uncommitted P0H–P0L replaced working `PageView.builder` swipe with `CanonicalDatePager`, hot UI windows, opacity gates, and day-content slot experiments — never landed in git; broke phone tests.
* **Known-good baseline:** commit `10bebe5` (HEAD) — `PageView` + `DatePagerSettleGate` in `planning_view.dart` / `timeline_view.dart`.
* **Restored from HEAD:** `planning_view.dart`, `timeline_view.dart`, `app_shell.dart`, `database_service.dart`, `db_core.dart`, `record_service.dart`, `plan_service.dart`, `global_app_header.dart`, `main.dart`.
* **Removed/disabled (untracked):** `canonical_date_pager.dart`, `canonical_date_physics.dart`, `hot_day_window_*`, `planning/timeline_day_*`, `p0b–p0l_date_diag.dart`, `VisualReadyPageSlot`.
* **`pre_white_swipe_restore.dart`:** [wip] `[PRE_WHITE_SWIPE_RESTORE]` start/commit/cancel logs on PageView path only.
* **White card visuals preserved:** `PlanCard` / `PlanTimeTaskCard` / Time mode geometry commits unchanged.
* **P0H/P0I/P0J/P0K/P0L:** superseded failed experiments — do not re-enable.

## [2026-06-15] - P0: Timeline Android crash guard + reliable date swipe [shipped]
* **`record_service.dart` / `database_service.dart`:** [shipped] Lazy per-row `timelineRowVmForRecordMapOrNull` + `_timelineLazyRowVmByDay`; safe skip/fallback for legacy rows (`P0_CRASH_GUARD`); deferred full day-index rebuild when flat cache >480 rows; `_scanSingleDayFromFlat` serves one day while index rebuilds; prefetch warms record maps only (not bulk VMs).
* **`timeline_view.dart`:** [shipped] `DatePagerSettleGate` — debounced shell date commit, drag blocks external pager sync; standard `PageScrollPhysics`; lazy VM in `ListView.builder`; cancel record stream when page inactive; keep last coalesced list (no blank on refresh).
* **`planning_view.dart`:** [shipped] Same settle gate + `PageScrollPhysics`; pending external date during drag/Time lock; `StreamBuilder` keeps `_latestPlanningDayTasks` when stream is `waiting`.
* **`date_pager_settle_gate.dart` / `p0_date_nav_diag.dart`:** [shipped] Shared pager settle coordinator + debounced debug-only `[P0_*]` logs.

## [2026-06-15] - P0 hotfix: restore Timeline cards + lock Planning pager during Time drag [shipped]
* **`timeline_view.dart`:** [shipped] Removed `_deferHeavyList`/blank `StreamBuilder` — list renders immediately from VM cache; restored visible card chrome (elevation, border, category stripe); stream via lightweight subscription.
* **`planning_view.dart`:** [shipped] `_datePagerLocked` — `NeverScrollableScrollPhysics` on date `PageView` while Time card drag/resize active; fixes gesture fights.
* **`date_swipe_physics.dart`:** [shipped] `getTargetPixels` `@override` restored; Planning `FeatherDateSwipePhysics` + `BouncingScrollPhysics`.

## [2026-06-15] - P0 Fix D: Timeline VM cache + virtualized rows + card layout [shipped]
* **`models/record.dart`:** [shipped] `TimelineRecordRowVm` — Brain-built render-ready row (title, subtitle, category, meta flags).
* **`record_service.dart`:** [shipped] `_timelineDayVmCache`, `peekTimelineRowVmsForDate`; prefetch window prev-2/current/next-1; stale prefetch cancel via center key.
* **`timeline_view.dart`:** [shipped] `_TimelineLazyRecordList` (`ListView.builder`, cacheExtent 320); post-frame `_deferHeavyList`; removed per-card `IntrinsicHeight`/nested Theme; active stream only when today/running; VM-driven `_TimelineRecordCard`.
* **`date_swipe_physics.dart`:** [shipped] `FeatherDateSwipePhysics` (20% drag) for Planning; Timeline `LightDateSwipePhysics` at 22%.
* **`perf_diag.dart`:** [shipped] `TIMELINE_VIEW_CACHE_*`, `TIMELINE_VISIBLE_BUILD`, `timelineHeavyDay` action metrics.

## [2026-06-15] - P0 Fix C: light date-swipe physics + Timeline day cache/prefetch [shipped]
* **`date_swipe_physics.dart`:** [shipped] `LightDateSwipePhysics` — ~25% viewport drag commits adjacent day; 12px motion threshold; shared by Timeline + Planning PageViews.
* **`record_service.dart` / `database_service.dart`:** [shipped] Date-keyed `_timelineRecordsDayIndex` + `_timelineDayViewCache`; `peekTimelineRecordsForDate` / `prefetchTimelineDayNeighbors`; `recordsStream` no longer `await`s broad fetch on subscribe; one O(n) index rebuild vs per-day full-history scan.
* **`timeline_view.dart`:** [shipped] Prefetch neighbors on settle; seed coalesced list from cache; `DATE_SWIPE_THRESHOLD` logs.
* **`perf_diag.dart`:** [shipped] `TIMELINE_CACHE_*`, `TIMELINE_PREFETCH_*`, `PB_TIMELINE_QUERY` diagnostics behind `PERF_DIAG`.

## [2026-06-15] - P0 Fix B: Timeline date-swipe shell isolation + visible-page gate [shipped]
* **`app_shell.dart`:** [shipped] Fix B — `_selectedDateListenable` + cached `ListenableBuilder` tab hosts; `_applySharedSelectedDate` avoids full-shell `setState` on Timeline swipe; `_loadTasksForDate` bumps `_timelineTasksRevision` instead of shell rebuild; header/FAB listen to date notifier.
* **`timeline_view.dart`:** [shipped] Inactive `TimelinePage` returns cheap placeholder (no stream/list build); stream `waiting` no longer flashes `AppLoading`; settle log `shellSetState=false`.

## [2026-06-15] - P0 Fix A: defer hidden date pager until tab activation [shipped]
* **`planning_view.dart` / `timeline_view.dart`:** [shipped] Fix A — inactive `PlanningSwipeWrapper`/`TimelineSwipeWrapper` store `_pendingExternalPage` (`deferHidden`) instead of `jumpToPage`/`animateToPage`; one `jumpToPage` on `shellTabActive` activation; `isActivePlanningDay`/`isActivePage` gated on `shellTabActive`.
* **`perf_diag.dart`:** [shipped] P0 swipe diagnostics behind `kPerfDiagnosisEnabled` (false for release); `test/perf_shell_date_settle_test.dart` proves hidden Planning no longer jump/fetch on Timeline swipe.
* **`android.ps1`:** [shipped] APK build passes `GIT_COMMIT`/`BUILD_TIME` dart-defines for `APP_BUILD` stamp.

## [2026-06-15] - P0 perf bisect: revert LazyIndexedStack + stop hidden tab pager animate [shipped]
* **Bisect:** [shipped] Lag source = `62020e8` `LazyIndexedStack` + hidden `PlanningSwipeWrapper.animateToPage` on every Timeline date swipe (shared `_selectedDate`); `PlanCard` extraction is render-identical to old `_PlanningTaskCard`.
* **`perf_flags.dart`:** [shipped] Bisect toggles (`useLazyIndexedStack`, `syncHiddenTabDatePager`, etc.); defaults restore `IndexedStack` + silent off-tab `jumpToPage`.
* **`app_shell.dart` / swipe wrappers:** [shipped] `shellTabActive`; quiet `_loadTasksForDate` (no loading flash); Timeline `_visiblePageIndex` for swipe frame.

## [2026-06-15] - P0 rollback: revert 73e87e7 date-swipe perf regression [rollback]
* **Git:** [rollback] `git revert 73e87e7` — removed `lib/core/date_swipe/`, `shellTabActive`, `DateSwipePerfMonitor`, wrapper `visiblePageIndex`/`allowImplicitScrolling`/per-page `RepaintBoundary` changes that caused ~10× worse swipe jank.
* **Preserved:** [shipped] `62020e8` LazyIndexedStack, PlanCard, mobile Time rail, tab contrast, profile hydration, `appDebugDiag`.
* **Docs:** [shipped] Date Swipe Law kept in `UX_CONTRACT.md`, `APP_STRUCTURE.md`, `AI_CONTEXT.md` (docs-only; no reintroduce 73e87e7 architecture).

## [2026-06-15] - P0 performance + mobile Time compactness + PlanCard canonical + Design Lab [shipped]
* **`lazy_indexed_stack.dart` / `app_shell.dart`:** [shipped] `LazyIndexedStack` — lazy tab build, `Offstage` + `TickerMode(false)` off-screen; replaces eager `IndexedStack` for smoother horizontal nav.
* **`app_diag.dart` / `planning_view.dart`:** [shipped] `appDebugDiag()` gates `TIME_*` logs to debug; drag layout cache (`_dragInsertLayoutsCache`); projection cache; `RepaintBoundary` on timeline canvas.
* **`planning_view.dart`:** [shipped] Mobile Time rail 28px + compact hour labels (`15` not `15:00`); list padding 4px when width &lt; 600.
* **`compact_nav_controls.dart`:** [shipped] Segmented selected text inherits `onPrimary` (fixes black-on-black active tabs).
* **`plan_card.dart` / `planning_view.dart` / `component_lab_cards_demo.dart`:** [shipped] Canonical `PlanCard` shared by Planning + Component Lab; removed fake `AppTaskCard` card demos.
* **`profile_service.dart`:** [shipped] `PROFILE_SAVE_*` / `PROFILE_HYDRATED` gated to debug; boot `PROFILE_FETCH_*` remains in release.

## [2026-06-15] - V3/V7 neutral-black design tokens (no green primary) [shipped]
* **`app_colors.dart` / `theme.dart`:** [shipped] Central tokens (`actionPrimary` #111111, `appBackground` #FAFAF8, `cardSurface` #FFFFFF); explicit `ColorScheme` + M3 component themes (buttons, FAB, nav, segmented tabs, cards, inputs).
* **Canonical widgets:** [shipped] `AppIconButton` selected = black fill; `LifeCard` white surfaces; `compact_nav_controls` black selected segments; timeline running cards white + black border; calendar today/selected neutral.
* **Outliers:** [shipped] `AppSnack` success uses `AppColors.success`; planning move snackbar uses `scheme.primary`; checkbox pulse uses `scheme.primary`.

## [2026-06-15] - P0 profile hydration diagnostics + hard PB fetch [shipped]
* **`app_build_info.dart` / `main.dart` / `profile_view.dart`:** [shipped] `APP_BUILD commit=… builtAt=… route=…` console log + Profile footer build stamp via `--dart-define`.
* **`profile_service.dart`:** [shipped] Auth-only `profiles.getOne(authStore.record.id)`; no silent empty-settings fallback; `PROFILE_FETCH_SUCCESS`/`PROFILE_UI_SETTINGS_APPLIED`/`PROFILE_SAVE_PATCH payload=…`; `accountName`/`profileEmail` hydration; `retryProfileHydration()`.
* **`db_core.dart`:** [shipped] Profile loads before backoff skip; timeout/sign-out no longer seeds empty `UserSettings`; boot fails loud when PB profile missing.
* **`main.dart`:** [shipped] `_ProfileHydrationErrorScreen` with retry (keeps session).
* **`app_shell.dart` / `web/index.html`:** [shipped] Profile hydration retry banner; SW unregister + `--pwa-strategy=none` cache bust.
* **`profile_view.dart`:** [shipped] Display name from PB (`display_name` → `name` → email), not legacy `AuthService`.

## [2026-06-15] - P0 profile settings persistence (lang/TZ/admin) [shipped]
* **`profile_service.dart`:** [shipped] PB-first hydration: always `getOne(auth.id)`; removed device-prefs override of timezone/theme on boot; field-diff PATCH in `saveSettings` (never `is_admin`); `PROFILE_*` diagnostic logs.
* **`app_shell.dart`:** [shipped] Legacy SettingsPage no longer auto-PATCHes `Local` timezone when stored TZ not in dropdown.
* **`db_core.dart`:** [shipped] Sign-out clears profile TZ/theme prefs cache keys.

## [2026-06-15] - P0 default plan times timezone context [shipped]
* **`categories.default_plan_timezone`:** [shipped] Optional IANA text field documented in `DATA_MAP.md` / `POCKETBASE_MANIFEST.md`; null/`profile` = active profile TZ; backward compatible when missing.
* **`category_service.dart`:** [shipped] `effectiveDefaultPlanScheduleForCategory`, `wallUtcForCategoryDefaultWall`, `updateCategoryDefaultPlanSchedule`, `formatDefaultPlanTimeWithTimezoneLabel`; PB field-missing error detection.
* **`plan_service.dart`:** [shipped] `resolveAutoPlanSchedule` returns UTC instants for category-default path; `planningTaskWithAutoSchedule` + `profileDisplayWallsFromAutoSchedule`.
* **`planning_view.dart`:** [shipped] Default plan times sheet shows profile TZ notice + `09:00 · NY` rows; edit sheet with profile/fixed timezone picker.
* **`wall_clock.dart` / `timezone_settings.dart`:** [shipped] `wallClockToUtcForIanaId`, `kCategoryDefaultTimezoneOptions`.

## [2026-06-15] - P0 Time mode TZ placement + sane hour scale + bottom footer [shipped]
* **`plan_service.dart`:** [shipped] `projectPlanForTimeMode()` requires `startUtcInstant` only (rejects stale `startTime`/`dateKey` wall fallback); offline cache persists/parses `start_time` ISO; `TIME_TZ_PROJECT` adds `startMin`/`endMin`.
* **`planning_view.dart`:** [shipped] Fixed hour height = `planTimeCardMeasureHeight() * 1.5` clamped 120–160px (removed shortest-task 40px floor + 560px cap); `TIME_DURATION_LAYOUT` logs `profileTz`/`wallStart`/`wallEnd`.
* **`plan_time_task_card.dart`:** [shipped] `timelineFillHeight` + `anchorFooterBottom` pins progress/breadcrumb/time to card bottom in duration blocks; `PlanCardSurface.timeline` for embedded blocks.

## [2026-06-15] - P0 Time mode duration-true layout + profile TZ projection [shipped]
* **`plan_service.dart`:** [shipped] `TimeModeProjectedPlan` adds `durationMinutes`, `planId`, profile wall aliases; `TIME_TZ_PROJECT` log; `logTimeTzProjectForTimeMode`.
* **`planning_view.dart`:** [shipped] Replaced rubber/fixed-height layout with `_TimelineDurationGrid` (linear `pxPerMinute`, height = duration); placement/labels/filter/resize/drag/now-line all use `TimeModeProjectedPlan`; now badge in left rail, line above cards in canvas; auto-scroll to now on profile-today.

## [2026-06-15] - Restore Time mode current-time line [shipped]
* **`planning_view.dart`:** [shipped] Profile-today gate via `getProjectedTodayDateKey()`; `_PlanningTimelineNowLineOverlay` renders above cards (outer Stack, `IgnorePointer`, green `scheme.primary`); minute tick + `timeUpdates`; y from `grid.yForMinutesFromRangeStart` (rubber scale).

## [2026-06-15] - P0 Time mode card clipping fix [shipped]
* **`plan_time_task_card.dart`:** [shipped] `planTimeCardMeasureHeight()` computes full intrinsic height (title row includes 33px menu slot → 106px); `planTimeCardTimelineAllocatedHeight()` +2px border allowance; explicit `titleRowHeight` SizedBox; footer right safe pad 6px.
* **`planning_view.dart`:** [shipped] Rubber grid + `Positioned` use `planTimeCardTimelineAllocatedHeight`; removed timeline `ClipRRect` anti-alias clip; debounced `TIME_CARD_CONSTRAINTS` / `TIME_HOUR_ROW_METRICS` logs.

## [2026-06-15] - Footer time safe area + clear recurring icon [shipped]
* **`plan_time_task_card.dart`:** [shipped] Footer time cluster `mainAxisSize: min`, no ellipsis on time, 4px right safe pad; breadcrumbs ellipsize first. Recurring → `Icons.autorenew_rounded` 15px after title (5px gap).

## [2026-06-15] - Larger play triangle + inline recurring glyph [shipped]
* **`plan_time_task_card.dart`:** [shipped] Play glyph 22×24px filled rounded triangle (4px corners) in 32px slot; `_PlanCardRecurringGlyph` circular dual-arc icon inline after title (5px gap).

## [2026-06-15] - CardPlan alignment, filled play, progress pill [shipped]
* **`plan_time_task_card.dart`:** [shipped] Completed cards keep geometry — removed persistent `Transform.scale`, reserved play slot when done; title top aligned with checkbox (`titleTopInset=0`, `TextHeightBehavior`); tighter shared spacing (90px ref); 3px pill progress track+fill; filled rounded-corner play triangle (`PaintingStyle.fill`).

## [2026-06-15] - Time mode CardPlan visual parity [shipped]
* **`plan_time_task_card.dart`:** [shipped] Timeline uses same list CardPlan path (`PlanCardSurface.list`); capsule progress bar (3px, rounded ends); play icon triangle with rounded vertices via stroke-join (no rounded outer button).
* **`planning_view.dart`:** [shipped] Timeline cards `left:0/right:0` + symmetric 8px inset + `ClipRRect` — identical horizontal alignment, no edge protrusion.

## [2026-06-15] - P0 final CardPlan geometry + Category reorder [shipped]
* **`plan_time_task_card.dart`:** [shipped] Figma CardPlan_Medium constants — 95px ref height, pad 12/10, 1px progress bar, fixed tags/progress slots (no data-dependent height); `tagsToProgressGap` ≈56px anchor.
* **`planning_view.dart`:** [shipped] Category mode per-bucket `ReorderableListView` + `_onCategoryBucketReorder` → `persistPlanningTaskOrder`.

## [2026-06-15] - Plan reorder persistence (Tags / Custom) [shipped]
* **`plan_service.dart`:** [shipped] `persistPlanningTaskOrder` applies optimistic cache first; `_persistPlanningTaskOrdersBulkNow` PATCHes `{order}` via `_patchPlanUpdateNetworkPhase` (15-char PB id, plan outbox on retriable failure); baseline diff uses `t.order` not list index; skips `virt-`/`optimistic-`; `PLAN_REORDER_*` logs + rollback on total failure.
* **`planning_view.dart`:** [shipped] `_commitPlanningReorder` / `_planCanReorderTask`; Tags + Custom drag wired to Brain persist path (no stale `_dragOrder`-only UI).

## [2026-06-15] - Plan card completion moment before reorder [shipped]
* **`planning_view.dart`:** [shipped] `_planCompletionHoldKeys` delays sort/reorder **250ms** after check while optimistic `isDone` updates immediately; `_sortTreatAsDone` + `_PlanCardReorderSettle` slide settle on release; rollback cancels hold.
* **`plan_time_task_card.dart`:** [shipped] Staged completion feel — checkbox pulse/scale, `AnimatedDefaultTextStyle` strike-through, card opacity/scale settle (~260ms).

## [2026-06-15] - P0 Plan card repair: one shared compact card + rubber Time grid [shipped]
* **`plan_time_task_card.dart`:** [shipped] Removed `_PlanCardVerticalSpacing.timeline`, `pinFooter`, and `heightPx` visual branches; single `_PlanCardVerticalSpacing.shared` (top 9, title→tags 5, tags empty 4, progress gap 6, bar 2px, footer gap 6, bottom 8); `refHeightMedium` 90; `planTimeCardMeasureHeight()` for layout; Time mode uses same medium CardPlan as list.
* **`planning_view.dart`:** [shipped] `_TimelineRubberGrid` — per-hour `max(80px, content)` with iterative card stack + cascade; drag/resize/now-line Y↔minutes via rubber map; interaction wrapper unchanged; cards sized by intrinsic measure not duration strips.

## [2026-06-15] - Time mode TZ placement + drag restore [shipped]
* **`plan_service.dart`:** [shipped] `TimeModeProjectedPlan` + `projectPlanForTimeMode()` — UTC→profile wall for labels/placement/filter; `_coalescePlanningTaskWallUtcFields` prefers `startUtcInstant`; offline day cache stores `start_utc`/`end_utc`; `TIME_MODE_PROJECT` logs.
* **`planning_view.dart`:** [shipped] Layout/filter/drag use projected wall times; `TIME_MODE_LAYOUT`/`TIME_MODE_RAIL` logs; pointer-based move zone + early scroll lock restores web drag.
* **`global_app_header.dart`:** [shipped] Profile timezone short label (NY/MSK/UTC±N) beside live clock.

## [2026-06-15] - Time mode card compact vertical rhythm [shipped]
* **`plan_time_task_card.dart`:** [shipped] `_PlanCardVerticalSpacing.timeline` — top 6 / bottom 8, title→tags 6, tags slot 22, progress slot 16, progress→footer 6; removed timeline `Spacer` that pinned footer to card bottom; content top-aligned in timeline blocks.
* **`planning_view.dart`:** [shipped] Min timeline visual card height **88px** (was 108).

## [2026-06-15] - P0 Plan card invariant layout (fixed slots) [shipped]
* **`plan_time_task_card.dart`:** [shipped] Medium/large Plan cards use `_PlanCardInvariantBody` with fixed slots (title, tags 28px, progress 19px, footer 6px gap); `_PlanCardProgressSlot` always renders neutral track + reserved actual-time row; removed data-driven `showFooterRow` / `showProgressTrack` / `_PlanCardFooterSeparator` branches; medium/large share `_PlanCardRailShell`.

## [2026-06-15] - P0 Time mode visual rebase: full Plan cards on timeline [shipped]
* **`plan_time_task_card.dart`:** [shipped] Removed `_TimelinePlanCardMicro` and `_TimelinePlanCardCompactTimeline` one-line strip layouts; timeline uses CardPlan medium/large only; `planTimeCardDensityForBlock` returns medium (&lt;130px / &lt;60min) or large; timeline always shows progress separator + footer; subtler selected border (1.25px); watermark hidden only on short medium blocks (&lt;130px).
* **`planning_view.dart`:** [shipped] Min visual card height **108px** (matches CardPlan_Medium); 4px cascade gap; fixed 80px/hour scale; sequential stack when min height exceeds time-proportional slot — 5-min snap/duration data unchanged.

## [2026-06-15] - Plan list card footer consistency + spacing [shipped]
* **`plan_time_task_card.dart`:** [shipped] List/calendar cards always use medium layout with footer row; removed fixed 71px inner height that clipped breadcrumbs/time; progress separator always shows for plan list cards; footer bottom pad 10px, separator gap 6px; planned time from wall fields when label empty.

## [2026-06-15] - Time mode: revert shortest-task zoom; micro layout at fixed scale [shipped]
* **`planning_view.dart`:** [shipped] Removed dynamic `hourHeight` from shortest visible plan (was up to 720px/h); fixed **80px/hour** scale; short blocks use **38px min layout height** + sequential visual push (duration unchanged).
* **`plan_time_task_card.dart`:** [shipped] Micro one-line row ~38–44px with full time label; desktop wide row adds inline tags/category chip; density thresholds 45/70/110px.

## [2026-06-15] - Governing docs sync (category relations, Time mode, tag duration) [shipped]
* **Docs-only:** Aligned `DATA_MAP.md`, `POCKETBASE_MANIFEST.md`, `ARCHITECTURE.md`, `UX_CONTRACT.md`, `DESIGN_SYSTEM.md`, `AI_CONTEXT.md`, `CLAUDE.md`, `ROADMAP.md`, `APP_STRUCTURE.md` with shipped fixes.
* **Record category law (final):** `records.category_id` and `records.category_link` are PB relations → `categories.id` (15-char); business slug only in `categories.category_id` / Brain cache — never in record API payloads.
* **Supersedes:** Earlier [wip] sync-banner / category-duality doc wording; real fix is relation-id normalization in `category_service.dart` / `record_service.dart` (see 2026-06-14 changelog).

## [2026-06-15] - Time mode UX: 5-min snap, micro cards, timeline scale, resize handles [shipped]
* **`planning_day_start_prefs.dart` / `plan_service.dart`:** [shipped] Timeline snap + min duration 5 minutes (`timelineSnapMinutes`, `kPlanScheduleSnapMinutes`).
* **`plan_time_task_card.dart`:** [shipped] Height-based density tiers (micro/compact/medium/large); `_TimelinePlanCardMicro` + `_TimelinePlanCardCompactTimeline` for short blocks; footer/progress/watermark suppressed on micro/compact timeline; medium hides tags when block &lt;104px.
* **`planning_view.dart`:** [shipped] Dynamic `hourHeight` zoom (shortest plan ≥52px desktop / 64px touch, max 720px/h); 16px resize hit zones; hover resize dots + `resizeUpDown`/`grab` cursors; floating time preview preserved.

## [2026-06-15] - Time mode now-line z-order above cards [shipped]
* **`planning_view.dart`:** [shipped] Current-time indicator moved after plan cards in timeline Stack + `IgnorePointer` so line renders above cards without blocking taps.

## [2026-06-15] - Tag default duration persistence fix [shipped]
* **`models/tag.dart` / `profile_service.dart` / `tag_default_duration_settings_view.dart`:** [shipped] Parse PB number as int/double; verify PATCH response; optimistic UI + rollback; `TAG_DURATION_*` logs; no success toast unless persisted; schema-missing error key.

## [2026-06-15] - Time mode now-line TZ + remove out-of-range bucket + wall-first create [shipped]
* **`planning_view.dart`:** [shipped] Now-line uses `applyUserOffset(getPlanetaryNow())` for position/label; `PLAN_TIME_NOW_LINE` log; removed “Другое время (вне видимого диапазона)” fallback section.
* **`plan_service.dart`:** [shipped] `_coalescePlanningTaskWallUtcFields` / `_buildPocketPlanCreateBody` / PATCH body derive UTC from profile wall (wall wins over stale `startUtcInstant`); fixed `startTime.toUtc()` on naive wall in patch fallback.

## [2026-06-15] - Time mode card footer regression fix [shipped]
* **`plan_time_task_card.dart`:** [shipped] Timeline blocks never use compact density (`planTimeCardDensityForBlock` → medium/large only); footer row + `alwaysShowTrack` progress separator restored for scheduled Time mode cards; category fallback `uncategorized`; planned time from task wall fields when label empty.

## [2026-06-15] - Plan create/edit wall-clock timezone fix [shipped]
* **`plan_service.dart` / `planning_view.dart` / `app_shell.dart`:** [shipped] Plan create paths pass profile **wall** `startTime`/`endDateTime` (not UTC); `_coalescePlanningTaskWallUtcFields` sets `startUtcInstant` once and reprojects cache; fixes 7:45 Moscow showing as 4:45; `PLAN_TIME_CREATE_WALL_TO_UTC` / `PLAN_TIME_EDIT_WALL_TO_UTC` / `PLAN_TIME_CACHE_PROJECTED` logs.

## [2026-06-15] - Plan card separator + category color + recurring time edit [shipped]
* **`plan_time_task_card.dart`:** [shipped] Removed duplicate `_PlanCardDividerLine`; progress track is sole content/footer separator; breadcrumbs/progress use `getCategoryColor` (not hardcoded blue `#609CE1`).
* **`plan_service.dart` / `app_shell.dart` / `planning_view.dart`:** [shipped] Virtual recurring occurrence edits materialize one-off row + `exception_dates` skip; series-row time PATCH preserved; `RECURRENCE_INSTANCE_*` logs.

## [2026-06-15] - Tag default plan durations + sequential auto-schedule [shipped]
* **`models/tag.dart` / `profile_service.dart` / `plan_service.dart` / `tag_default_duration_settings_view.dart` / `tag_settings_hub.dart` / `planning_view.dart`:** [shipped] `tags.default_plan_duration_minutes` per-tag settings (Durations tab); `resolveAutoPlanSchedule` sequential placement (append after last plan, snap 15m); duration rule: explicit range → tag order → 30m fallback; `evaluatePlanDayScheduleOverload` warning snack.

## [2026-06-15] - Plan card polish: hover, footer, actual time [shipped]
* **`plan_time_task_card.dart` / `planning_view.dart`:** [shipped] Full-card `MouseRegion` hover (border/shadow/tint) while controls stay independent; footer row `minHeight` 14 + pinned bottom pad/gaps fix breadcrumb/time clipping; removed legacy subtitle date/time row (`subtitleLabel`/`onSubtitleTap`); compact actual time right-aligned above progress via `_PlanCardMetricsBlock`; planned time only in `_PlanCardFooterRow`.

## [2026-06-16] - Time mode TZ projection + desktop side nav [shipped]
* **`plan_service.dart` / `models/planning.dart` / `profile_service.dart` / `planning_view.dart`:** [shipped] Plans store UTC instants (`startUtcInstant`/`endUtcInstant`); day filter + Time mode placement project via `_profileWallFromUtc` (fixes TZ switch misplacing blocks); `reprojectAllPlansForProfileTimezone` on profile TZ change; debounced `PLAN_TIME_TZ_PROJECT` logs.
* **`app_shell.dart`:** [shipped] Desktop/web side nav (≥900px) shows Timeline/Plan/Calendar/Lists/Categories/Profile directly; More (index 6) is secondary overflow (Dev Lab admin only); mobile bottom nav unchanged.

## [2026-06-16] - Plan Play button gesture + category fallback fix [shipped]
* **`plan_time_task_card.dart` / `planning_view.dart`:** [shipped] Play/checkbox/menu no longer blocked — body tap/drag limited to content column (`_PlanCardBodyTapShell`); timeline `_TimelinePlanInteractionBlock` move zone excludes control rail + menu via `planCardBodyGestureLeftInsetPx` / `planCardBodyGestureRightInsetPx`.
* **`category_service.dart`:** [shipped] `_resolveColdStartRecordCategoryId` falls back to default/leaf when plan UI category is concrete but missing PB relation id — Play no longer aborts before optimistic Highlander shadow.

## [2026-06-16] - Record outbox highlander_start category relation fix [shipped]
* **`category_service.dart` / `record_service.dart`:** [shipped] PocketBase records POST/PATCH now send 15-char `categories.id` in both `category_id` and `category_link` (was business slug → `validation_missing_rel_records` 400); `_normalizeRecordCategoryFieldsForPbApi` with cache/default/fallback repair + `RECORD_*` diagnostics; outbox replay pre-sanitizes/drops unmappable rows; `_lastRecordCreateFailureHttpCode` so `SYNC_FLUSH_FAIL` reports actual HTTP 400 not 500.

## [2026-06-16] - Sync banner empty-outbox invariant [wip]
* **`offline_sync_state.dart` / `app_shell.dart`:** [wip] Red sync banner requires `hasBlockingSyncError` (pendingCount>0 && lastError); stale lastError with empty outbox suppressed via `SYNC_STALE_ERROR_SUPPRESSED`; `ensureBannerInvariant()` on every banner build.

## [2026-06-16] - Sync banner diagnostics + stale state fix v2 [wip]
* **`offline_sync_state.dart` / `db_core.dart` / `app_shell.dart` / `main.dart`:** [wip] Root cause: `debugPrint` silent on release web + boot `unawaited(flush)` race; `print`-based `SYNC_BANNER_VISIBLE` / `TAP_RETRY` / `AFTER_RETRY` / `SYNC_BOOTSTRAP`; `bootstrapFromOutboxes()` clears stale in-memory `lastError` when both outboxes empty; await flush on `loadInitialData`; banner wired to canonical `DatabaseService.instance.offlineSync` only.

## [2026-06-16] - Sync error banner stabilization [wip]
* **`offline_sync_state.dart` / `db_core.dart` / `record_service.dart` / `plan_service.dart` / `app_shell.dart`:** [wip] Fix sticky red sync banner when outboxes drain but `lastError` lingered — `reconcileAfterDrain()` after flush + boot refresh; debounced `SYNC_FLUSH_FAIL` / `SYNC_BANNER_ERROR` console logs; stale outbox rows without cache drop safely; unresolved PB id logs `resolve_failed` without blocking unrelated sync.

## [2026-06-15] - Unified PlanTimeTaskCard across all Plan modes [shipped]
* **`plan_time_task_card.dart` / `planning_view.dart` / `calendar_view.dart`:** [shipped] One CardPlan visual system via `PlanCardSurface` (`list` / `timeline` / `calendar`) — Category/Tags/Custom/Time list rows + Calendar day list use `PlanTimeTaskCard`; list intrinsic min-heights (`planTimeCardDensityForList` / `planTimeCardListMinHeight`); preserved checkbox/play/menu/tap-edit/long-press/subtitle-date callbacks; web hover on card border/shadow + control buttons.

## [2026-06-15] - Plan tab list cards visibility regression [shipped]
* **`planning_view.dart` (`_buildListPlanningCard`):** [shipped] Fix zero-height plan rows in Category/Tags/Custom sort modes — superseded by unified `PlanTimeTaskCard` list surface.

## [2026-06-15] - CardPlan_Small/Medium/Large Figma geometry pass [wip]
* **`plan_time_task_card.dart`:** [wip] Rebuilt `PlanTimeTaskCard` from recalculated Figma MCP metadata (328×54/95/147) — Small inline checkbox+play (x=12/48, content x=84); Medium/Large vertical 32px rail (content x=56); 1px divider + footer span full content width; rounded-triangle play + thin menu icon (33×33); watermark at Figma positions with wide-card scale; density thresholds Small &lt;59 / Medium 59–120 / Large ≥121.

## [2026-06-15] - CardPlan visual redesign (Planning Time + Calendar rows) [wip]
* **`plan_time_task_card.dart` / `planning_view.dart` / `calendar_view.dart`:** [wip] Canonical `PlanTimeTaskCard` (Small/Medium/Large densities per `design/CardPlan *.png`) — white surface, soft border/shadow, left control rail, unified text column, repeat inline with title, circular menu top-right, category watermark (4–8% opacity); Planning Time timeline blocks and Calendar focused-day rows use shared card; timeline gestures/scale/cascade unchanged.

## [2026-06-16] - Calendar full-screen + desktop side nav [wip]
* **`calendar_view.dart` / `shell_adaptive.dart` / `app_shell.dart`:** [wip] Calendar browsing state fills content area (month grid + week planner columns with event pills); focused-day state condenses calendar and shows task list; collapse via close/up controls; desktop ≥900px uses 200px left nav rail (Timeline/Plan/Calendar/Lists/More), bottom nav hidden on wide web.

## [2026-06-15] - Planning Time layout + Calendar screen [wip]
* **`planning_view.dart`:** [wip] Time-mode gesture arbitration — short tap opens edit via `_TimelinePlanInteractionBlock.onBodyTap`; touch long-press move (desktop/web keeps immediate drag); tap suppressed after drag/resize; timeline cards omit select-mode long-press; dynamic `_timelineHourHeightPx` from shortest scheduled duration; proportional block heights; exact-time insert/cascade (no 15-min gap); minimal one-row card layout (checkbox + play + title + time + menu).
* **`calendar_view.dart` / `plan_service.dart` / `app_shell.dart`:** [wip] Calendar tab — month grid + compact week strip, month/week toggle, category task indicators (+N), selected-day scheduled task list via `planningStream`, stays on Calendar tab (no jump to Timeline); `planningTasksGroupedByWallDayForRange` + `planningRefreshEvents` for indicators.

## [2026-06-15] - Planning Time resize handles [wip]
* **`planning_view.dart` / `planning_day_start_prefs.dart`:** [wip] Time-mode scheduled non-recurring plan blocks expose subtle top/bottom resize edges (12px zones, hover grip) that preview start/end changes with live `09:00 – 10:30 · 1h 30m` labels, 15-minute snap/min duration (`timelineMinDurationMinutes`), day-bound clamps, scroll lock + edge auto-scroll; commit reuses `applyOptimisticPlanningTask` + async `updatePlanningTask`; whole-card move drag (handle + body) unchanged.

## [2026-06-15] - Planning Time timeline, parser UX, drag, auto-recat persistence [shipped]
* **`planning_view.dart` / `planning_day_start_prefs.dart`:** [shipped] Planning “Время / Time” mode is a proportional vertical day timeline (hour rail, duration-sized blocks, overlap lanes, current-time line, empty-slot quick-add); non-recurring scheduled cards drag vertically via left handle with 15-minute snap (`timelineSnapMinutes`), live time-range label, placeholder ghost, scroll lock, edge auto-scroll; drop preserves duration through `applyOptimisticPlanningTask` + async `updatePlanningTask`.
* **`smart_input_parser.dart` / `planning_view.dart` / `plan_service.dart` / `shared_widgets.dart`:** [shipped] Smart time parsing infers schedule metadata but preserves user-visible/saved title text (`preservedTitleFromRaw`); edit-sheet `onChanged` no longer mutates `TextEditingController` while typing.
* **`category_service.dart` / `record_service.dart` / `plan_service.dart`:** [shipped] Title-change auto-recategorization persistence: record PATCH/POST sends both `category_id` + `category_link`; Play/start-from-plan resolves freshest Brain plan category (`resolveCurrentPlanCategoryForRecordStart`) before record create.

## [2026-06-15] - V7H Card Foundation [wip]
* **`life_card.dart` / `component_lab_view.dart`:** [wip] Added canonical `LifeCard` + `AppTaskCard` card foundation with parameterized normal/selected/completed/disabled/active states, compact/regular density, task/backlog/timeline types, and mock-only Component Lab examples; production cards remain unmigrated.
* **`docs/DESIGN_SYSTEM.md` / `docs/reports/DESIGN_SYSTEM_INVENTORY.md`:** [wip] Documented Figma `Card` → Flutter `LifeCard` / `AppTaskCard` mapping, supported variants, metadata parameters, and the explicit V7H no-production-migration boundary.

## [2026-06-15] - Profile password reset action [shipped]
* **`profile_view.dart` / `auth_bridge.dart` / `dictionary.dart`:** [shipped] Profile now shows a Security section with a localized email-based password reset action that uses the active PocketBase auth email, calls `AuthBridge.requestPasswordReset`, disables while sending, handles missing emails, and surfaces success/failure through one snackbar.

## [2026-06-15] - Plan create duplicate reconciliation [shipped]
* **`plan_service.dart`:** [shipped] Plan create now reconciles optimistic and server rows by stable business `plan_id`: `_upsertPlanInUserCache` replaces matching optimistic cache entries, `_dedupePlanningTasksByBusinessId` guards `planningStream` emits, `clearOptimisticPlanningForPlanRow` purges overlay+cache by `optimistic-{plan_id}`, and plans realtime clears the optimistic overlay when the confirmed row arrives.
* **`planning_view.dart`:** [shipped] Removed redundant UI-layer optimistic plan rows on quick-add/Smart Plan inject (Brain optimistic stream is sole source); added `_planQuickAddInFlight` guard and `plan_id`-aware merge fallback.

## [2026-06-13] - Password reset lookup and messaging [shipped]
* **`auth_bridge.dart` / `auth_view.dart` / `dictionary.dart`:** [shipped] Forgot password now calls the app-owned reset endpoint, shows explicit sent/not-registered/mail-unavailable messages, and offers a Register action when the email is not found.
* **`pb_hooks/auth.request_password_reset.pb.js` / `pb_config.dart` / `docs/DEPLOY.md` / `docs/POCKETBASE_MANIFEST.md`:** [shipped] Added `POST /api/auth/request-password-reset` so PocketBase checks `profiles.email` server-side and sends reset mail without exposing profile search or private fields; documented SMTP/template/action URL diagnostics.

## [2026-06-12] - Mid-session auth repair + PocketBase readiness docs [shipped]
* **`main.dart` / `offline_sync_state.dart`:** [shipped] The root auth gate now listens for mid-session `offlineSync.authPaused` from 401/403 record/plan mutations, routes to the login/session repair screen, marks syncing inactive while auth is paused, keeps outbox mutations paused, and resumes through the shared post-auth bootstrap after login.
* **`AndroidManifest.xml` / `constants.dart` / `docs/DEPLOY.md`:** [shipped] Removed Supabase-era Android callback schemes/constants and documented PocketBase `profiles` OAuth provider discovery, `/api/oauth2-redirect` setup, Android real-device verification status, and password-reset SMTP/template requirements.

## [2026-06-12] - Plan-link suggestion toggle persistence [shipped]
* **`planning_view.dart`:** [shipped] `_PlanRecordLinkSuggestionSettingsBlock` owns record-link suggestion prefs inside the Planning settings sheet so the master switch and mode selector rebuild and persist via `plans_record_link_suggestions_enabled` / `plans_record_link_suggestion_mode` (fixes frozen modal header that blocked turning suggestions off).

## [2026-06-12] - Auth gate and account recovery [shipped]
* **`main.dart` / `auth_bridge.dart` / `profile_service.dart`:** [shipped] Cold start and post-login now share one PocketBase auth bootstrap path; invalid profile/session verification clears unsafe auth state and surfaces login/session repair instead of falling back to cached profile data.
* **`auth_view.dart` / `dictionary.dart`:** [shipped] Auth screen shows configured Google/Yandex fast-login before email fallback, handles OAuth cancellation calmly, and keeps neutral password-reset messaging.
* **`docs/DEPLOY.md`:** [shipped] Documented required PocketBase auth, OAuth, SMTP, reset, and verification admin setup.

## [2026-06-12] - Biometric app-lock + plan-link suggestions [shipped]
* **`auth_bridge.dart` / `main.dart` / `auth_view.dart` / `profile_view.dart`:** [shipped] Removed stored-password biometric quick login; biometrics are now a real Android/iOS app-lock only, hidden on web/unavailable devices, with a 7-day local inactivity threshold.
* **`app_shell.dart` / `planning_view.dart` / `dictionary.dart`:** [shipped] Record-to-plan suggestions are device-local, non-blocking after record creation, configurable from Planning settings, and can be turned off from the suggestion snackbar; manual edit-sheet link/unlink remains available.

## [2026-06-12] - Tag pill text vertical alignment [shipped]
* **`chip_component.dart`:** [shipped] Letter-chip pills use fixed height + horizontal-only padding with `height: 1.0`, `StrutStyle`, and `TextHeightBehavior` so label text is optically centered; selected/unselected inner content stays identical.

## [2026-06-12] - Selected tag ring shrink-wrap [shipped]
* **`chip_component.dart`:** [shipped] Pill-mode `CategoryChip` and `_TagSelectionRing` use `Row(mainAxisSize: min)` so selected ring shrink-wraps the visible pill instead of expanding to stretched parent width.

## [2026-06-12] - Design Lab copy + interactive tag selected state [shipped]
* **`component_lab_view.dart`:** [shipped] Design Lab labels/spec text are selectable/copyable with lab-only `SelectableText`; chip examples now show compact, interactive unselected, interactive selected, and overflow scroll strip states.
* **`chip_component.dart`:** [shipped] Interactive tag selected state is now normal chip border + 2px transparent gap + 2px brand border; base pill content stays centered and selected/unselected states do not shift inner text.
* **`shared_widgets.dart` / `planning_view.dart`:** [shipped] Tag strip rows fit the 31px base interactive pill plus visible selected ring without changing scroll behavior.

## [2026-06-12] - Edit sheet tag strip scroll hotfix [shipped]
* **`chip_component.dart`:** [shipped] `TagQuickPickStrip` horizontal scroll fix — removed `shrinkWrap`, added `ScrollController`, `_TagStripScrollBehavior` (mouse/trackpad/touch drag), wheel-to-horizontal `PointerScrollEvent`; interactive pills ~31px (was 40px); compact cards ~22px.
* **`shared_widgets.dart` / `planning_view.dart` / `component_lab_view.dart`:** [shipped] edit-sheet tag row uses finite strip height; lab overflow strip with 8 tags.

## [2026-06-12] - P0 startup sync + tag pill regressions [shipped]
* **`db_core.dart` / `plan_service.dart` / `record_service.dart`:** [shipped] P0 foreground/resume refresh via `refreshForegroundData()` force-fetches records + today's plans and pumps planning streams; debounced plan cache refresh now re-emits streams; duplicate primary running records reconcile to newest-only (optimistic stop + existing `stopRecordByDocId` for older rows).
* **`chip_component.dart` / `shared_widgets.dart` / `component_lab_view.dart` / `timeline_view.dart`:** [shipped] Tag pill regression fix: stadium compact card pills vs larger interactive picker pills, horizontal scroll strip restored, removed invisible outer selection padding; timeline running UI uses canonical primary id only.

## [2026-06-12] - V7G.1 canonical state views [shipped]
* **`lists_view.dart` / `tag_manager_page.dart` / `plan_vs_fact_tab.dart` / `planning_view.dart` / `calendar_view.dart`:** [shipped] V7G.1 safely migrated simple visual loading/empty/error surfaces to `AppLoading` / `AppEmptyState` / `AppErrorState` where applicable; auth, boot, sync, voice, sheet, profile-save, timer/timeline-adjacent, and richer CTA state views remain documented legacy.

## [2026-06-11] - F2C default plan times selector wiring [shipped]
* **`app_icon_button.dart` / `category_list_view.dart` / `DESIGN_SYSTEM_INVENTORY.md`:** [shipped] V7F.2 safely migrated the Categories AppBar layout-toggle and add-category icon actions to `AppIconButton`; planning, timeline, selection, voice, tree, and destructive icon controls remain documented legacy.
* **`app_icon_button.dart` / `component_lab_view.dart` / `DESIGN_SYSTEM.md` / `DESIGN_SYSTEM_INVENTORY.md`:** [shipped] V7F Icon Button foundation added `AppIconButton` for Figma `Icon Button`, labeled Component Lab examples, and raw `IconButton` audit docs; no production icon-button migration yet.
* **`component_lab_view.dart` / `DESIGN_SYSTEM.md`:** [shipped] Component Lab examples now render lab-only labels with Figma name, Flutter mapping, variant, size, and state metadata for review without changing production UI.
* **`app_button.dart` / `component_lab_view.dart` / `DESIGN_SYSTEM.md`:** [shipped] V7E Action Buttons started: `AppButton` remains canonical and now supports Button Primary/Secondary/Danger/Ghost/Outlined variants, S/M/L sizing, loading/disabled/icon/full-width states, with Component Lab acceptance examples and inventory guardrails.
* **`profile_service.dart` / `app_shell.dart` / `more_view.dart`:** [wip] Admin Component Lab gate now fetches a fresh `profiles` row before falling back to cached auth data and adds temporary `[ADMIN_FLAG]` diagnostics plus `Admin flag: true/false` More markers while verifying `profiles.is_admin`.
* **`UX_CONTRACT.md` / `DESIGN_SYSTEM.md` / `component_lab_view.dart`:** [wip] V3/V7 foundation started: behavior/design-system docs added, UI inventory report created, `profiles.is_admin` parsed read-only into settings, and admin-only Component Lab skeleton exposed from More with mock-only canonical component samples.
* **`planning_view.dart`:** [shipped] Default plan time category search now opens with all category options visible, keeps path/name filtering case-insensitive while typing, and restores the full option list when the query is cleared.
* **`planning_view.dart`:** [shipped] Confirmed Plans gear → `_showPlanningSettingsSheet` → `_showDefaultPlanTimesSheet` is the sole default-times entry; added temporary `F2C selector UI` sanity marker at sheet bottom for web/APK verification after push to `main`.

## [2026-06-10] - F2A Plans UI polish slice [shipped]
* **`planning_view.dart` / `dictionary.dart`:** [shipped] F2C default plan times UI now uses a compact category selector with searchable picker, selected-category own/inherited status, set/clear-own actions, and a small configured-categories list instead of rendering the full category tree by default.
* **`category_service.dart` / `plan_service.dart` / `planning_view.dart`:** [shipped] F2C category default plan times accepted: category rows read optional `default_plan_time` (`HH:mm`), Plans settings exposes per-category set/clear controls with parent inheritance, and new scheduled plans without explicit parsed time apply the effective category default.
* **`app_shell.dart` / `android/.../styles.xml` / `chip_component.dart` / `shared_widgets.dart`:** Emergency Android F2A UI fix: removed duplicate native `Life OS` title bar (`Theme.Black.NoTitleBar`), collapsed to one compact `AppBar` with `Life OS` + date/time, picker tag chips tap only the visible chip (no outer active frame), and Timeline/Planning edit sheets share `AppEditSheetTimeButton` with full start/end labels.
* **`app_shell.dart` / `compact_nav_controls.dart` / `chip_component.dart` / `planning_view.dart` / `shared_widgets.dart`:** Final Android F2A visual correction: shell owns one compact black `Life OS` + date/time header, compact tabs/segments center labels without scaling, picker tags use a large explicit chip variant with outer selection outline, recurring plan icons attach to the title text, and start/end time buttons restore full EN/RU labels.
* **`app_shell.dart` / `global_app_header.dart` / `planning_view.dart` / `shared_widgets.dart` / `chip_component.dart`:** Corrected Android F2A visual regressions after device review: restored a readable dark compact top header/status bar, kept plan-card tags to one horizontal row, moved picker selection outlines onto the visible chip, restored the fourth dated-plan edit tab with `Repeat` separate from `Parallel plans`, and made end-time buttons fixed-height.
* **`compact_nav_controls.dart` / `global_app_header.dart` / `planning_view.dart` / `shared_widgets.dart` / `chip_component.dart`:** Android F2A regression polish: fixed tab/segment height with one-line ellipsis (no per-tab font shrink), enlarged edit-sheet tag visuals, moved repeat status directly into the Planning card title row, relabeled dated-plan recurrence UI as `Repeat`, and collapsed main Timeline/Plans/Lists headers to compact date/time chrome.
* **`compact_nav_controls.dart` / `planning_view.dart` / `timeline_view.dart` / `shared_widgets.dart`:** Added compact 44px tab/segment styling, moved `_PlanningTaskCard` play into the leading action column (hidden when done/selecting), and added repeat icon metadata for non-empty `rrule` plans. `docs/ROADMAP.md` marks F2A only; F2 remains open.

## [2026-06-10] - Docs cleanup: DATA_MAP and roadmap status [shipped]
* **`docs/DATA_MAP.md` / `docs/ROADMAP.md`:** Removed accidental assistant wrapper text from `DATA_MAP.md` and synced roadmap wording so O1, V1, and F1 are shipped with F2 Plans next.

## [2026-06-10] - CLAUDE.md F1 status sync [shipped]
* **`CLAUDE.md`:** F1 status synced after Lists shipped — top velocity line now points to F2 Plans, and the F1 table marks list tags/export/active chip/alignment/no-play work as shipped.

## [2026-06-10] - Docs sync: O1 local sync architecture [shipped]
* **`docs/APP_STRUCTURE.md` / `docs/ARCHITECTURE.md`:** Synced governing docs with shipped O1 local mutation queues, sync state, drain triggers, auth-paused behavior, and `_OfflineSyncStatusBar` anchors.

## [2026-06-10] - F1 Lists feature completion [shipped]
* **`lists_view.dart`:** F1 audit preserved existing list-tag filter/export/no-play behavior; active list tag now renders before “All tags”, and manual category chip mode uses the same scroll-to-start controller as normal mode.
* **`plan_service.dart` / `profile_service.dart`:** Plan/list tag hydration now uses a combined plan+list tag catalog for plain `tags_link` cache/replay paths, preserving `domain: list` tags through offline create/update sync and cache merges.
* **`docs/ROADMAP.md`:** F1 marked shipped with all five checklist items completed.

## [2026-06-10] - V1 CLAUDE.md nav map (post-O1 local sync) [shipped]
* **`CLAUDE.md`:** New **Local sync & offline-first** section — `record_mutation_outbox.dart`, `plan_mutation_outbox.dart`, `offline_sync_state.dart`, `sync_manager.dart`; symbols `flushPendingLocalMutations`, `flushPendingRecordMutations`, `flushPendingPlanMutations`, `resumeAfterAuthIfNeeded`, `_OfflineSyncStatusBar`; O1 shipped / F1 unblocked noted; Iron Laws updated for enqueue-on-retriable-failure.
* **`docs/ROADMAP.md`:** V1 marked shipped in execution order.

## [2026-06-09] - O1.4 offline-first audit & polish [shipped]
* **`offline_sync_state.dart`:** Banner quiet only when fully synced; online-with-pending shows “%s pending sync”; `resumeAfterAuthIfNeeded()` unblocks flush after re-auth.
* **`db_core.dart`:** `flushPendingLocalMutations` resumes sync when `authStore.isValid`; boot + app-resume + backoff-init paths refresh pending count and attempt flush.
* **`app_shell.dart`:** Distinct auth-paused banner string; online/offline pending labels split.
* **`docs/ROADMAP.md`:** O1.1–O1.4 marked shipped; restart/optimistic limitations documented; **F1 unblocked**.

## [2026-06-09] - O1.3 offline-first: Planning + Lists CRUD outbox [shipped]
* **`plan_mutation_outbox.dart`:** Generic plan queue (`plan_create`, `plan_update`, `plan_delete`) with O1 schema, coalescing (delete drops pending create/update for same `plan_id`), and auto-migration from legacy `plan_create_outbox_v1`.
* **`plan_service.dart`:** `addPlanningTask`, `updatePlanningTask`, `deletePlanningTasksBulk` keep optimistic UI; retriable failures enqueue to prefs; `flushPendingPlanMutations` replays on reconnect; `clearOptimisticPlanningForPlanRow('optimistic-…')` cancels never-synced pending creates.
* **Done-toggle:** unchanged UI in `lists_view.dart` / `planning_view.dart` — `updatePlanningTask(isDone:)` now returns `true` when queued so optimistic toggle is not rolled back offline.

## [2026-06-09] - O1.2 offline-first: record edit/delete outbox [shipped]
* **`record_mutation_outbox.dart`:** Added `record_update` and `record_delete` kinds with `coalesceQueue` — delete drops prior pending ops for same `businessId`; updates merge payloads to avoid duplicate PATCHes.
* **`record_service.dart`:** `updateRecord` / `patchRecord` apply cache edit immediately then async `_patchRecordUpdateNetworkPhase`; retriable failures enqueue update and keep optimistic row. `deleteRecordByDocId` keeps optimistic tombstone on failure via `_deleteRecordNetworkPhase` + delete outbox; 404 on replay = successful purge.
* **Replay:** `flushPendingRecordMutations` resolves PB id from stored `pocketBaseId`, cache, or server lookup before PATCH/DELETE.

## [2026-06-09] - O1 offline-first slice: record start/stop outbox [shipped]
* **`lib/data/local_sync/record_mutation_outbox.dart`:** SharedPreferences queue with O1 schema (`operation_id`, `collection`, `operation_type`, `business_id`, `pocketBaseId`, `payload`, `created_at`, `retry_count`, `last_error`, `sync_status`) for Highlander **start** and **stop** mutations.
* **`lib/data/record_service.dart`:** Primary `writeRecord` Highlander path and `stopRecordByDocId` keep optimistic UI on network failure — enqueue instead of rollback; `flushPendingRecordMutations()` replays on reconnect via `_runHighlanderStartServerPhase` / PATCH stop.
* **`lib/data/local_sync/sync_manager.dart` + `db_core.dart`:** `flushPendingLocalMutations()` drains records + plans outboxes; connectivity probe updates `OfflineSyncController`.
* **`lib/app_shell.dart`:** Subtle global banner — offline pending, syncing, auth/sync error (tap to retry flush).
* **`docs/ROADMAP.md`:** O1 phase added as highest priority before F1.

## [2026-06-09] - Repo layout, docs hygiene, analyzer & deploy scripts [shipped]
* **Folder flatten:** Real app moved from nested `counter/counter/` to `C:\Users\nkuch\Development\Apps\counter`; old outer Flutter skeleton backed up to sibling `counter_WRAPPER_BACKUP` (not in git).
* **Root cleanup:** Reports → `docs/reports/`; prompt/archive docs → `docs/archive/`; temp zips/screenshots/logs → `Archive/root_cleanup_backup/`; manual scripts → `scripts/manual/`; dev `tool/` → `Archive/tool/`.
* **Docs:** `docs/ROADMAP.md` is the single canonical roadmap; `docs/AI_CONTEXT.md` deduplicated to a pointer; `docs/DEPLOY.md` updated for flat repo root and `update.ps1`.
* **Analyzer hygiene:** `flutter analyze` reduced from 49 to 11 info-only issues (0 errors, 0 warnings) — mechanical lint/dead-code pass; no intended behavior change.
* **Deploy:** `update.ps1` at repo root calls `scripts/manual/td.ps1`; analyze uses `--no-fatal-infos --no-fatal-warnings`; web build uses `--no-tree-shake-icons --no-wasm-dry-run` (dynamic `IconData` — proper fix tracked in `docs/ROADMAP.md` V6).

## [2026-05-01] - C1 Sync & Reactivity: tag stream gaps, category silent drop, optimistic list toggle [shipped]
* **`profile_service.dart`:** `createTagForCurrentUser` adds new tag to `_userTagsCatalogCache` and calls `notifyTagsCatalogChanged()`; `deleteTagByPocketRecordId` removes tag from cache by `pbRecordId` and notifies; `patchTagForCurrentUser` calls `notifyTagsCatalogChanged()` after server write. All three mutations now push to UI immediately without manual refresh (#16).
* **`category_service.dart`:** `_mapCategoryIdToLinkForPb` else-branch now emits `debugPrint('[CAT_MAP] category_id dropped from payload — no resolved PB row id …')` instead of silent `merged.remove('category_id')` — cold-start category drops are now visible in debug logs (#9).
* **`lists_view.dart`:** `_onListToggleDone` rewired for true optimistic UI — snapshots `_flat`, immediately replaces the toggled task in `setState`, then fires `updatePlanningTask` async; rolls back `_flat` to snapshot on PATCH failure. Removed `notifyPlanningRefresh()` call (was triggering non-optimistic network reload). Added `TextDecoration.lineThrough` style to task title `Text` when `task.isDone` (#11).
* **Confirmed clean:** `flutter analyze` 0 new errors (64 issues, all pre-existing).

## [2026-05-01] - Restored omni_date_time_picker_dialog.dart to last known good state (4676e273) — reverting all May 1 changes [shipped]

## [2026-05-01] - Fix: omni-picker _DateSectionState minimal rewrite, onPageChanged no setState [shipped]
* **Root cause (`omni_date_time_picker_dialog.dart`):** Previous `_DateSectionState` called `setState` inside `onPageChanged`, which triggered a `build()`. During that rebuild, `TableCalendar` received an updated `focusedDay` prop and internally called `_pageController.jumpToPage` — creating a feedback loop that caused the visible month jump. Additionally, the date text field's `TextFormField` rebuild inside `_DateSectionState.build()` added unnecessary subtree churn on every calendar interaction.
* **Fix:** Replaced `_DateSectionState` with a minimal implementation: `onPageChanged` writes `_focusedDay` directly without `setState` (no rebuild, no `didUpdateWidget` on `TableCalendar`, no jump). Removed date text field from `_DateSection` entirely — calendar is the only date input. Removed `_clampDay`, `_tryParseDateField`, `_formatDateField`, `_validateDateText`, and `_onDateTextChanged` from `_DateSectionState`. `_dateTextController` kept and updated in `onDaySelected` for state tracking. Reverted `_OmniDateTimePickerDialogState` to construct `_DateSection` / `_TimeSection` inline in `build()` (with `ValueKey`s) — the `late final Widget` field approach was unnecessary complexity. Confirmed `CupertinoDatePicker.mode: CupertinoDatePickerMode.time`, `minuteInterval: 1`.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-05-01] - Fix: omni-picker child widgets constructed once in initState [shipped]
* **Root cause (`omni_date_time_picker_dialog.dart`):** `_DateSection` and `_TimeSection` were constructed as local variables inside `_OmniDateTimePickerDialogState.build()`. Even with a `ValueKey`, Flutter rebuilds child widgets from the new widget object on every `build()` call. The key only prevents element/state teardown when the widget *type and key* match — but the state was still receiving new widget instances with potentially updated props, and `_DateSectionState.initState()` runs only once, so the stable element was correct. The real issue: `build()` creating new widget objects each frame caused prop diffing through `didUpdateWidget`, which TableCalendar uses internally to drive `_pageController.jumpToPage`. Any prop difference (even a re-created callback closure) could trigger a month jump.
* **Fix:** Promoted `_DateSection` and `_TimeSection` to `late final Widget` fields on `_OmniDateTimePickerDialogState`. Initialized once in `initState()` with stable references (no new closures or widget objects ever created after that). `build()` now reads `_dateSectionWidget` / `_timeSectionWidget` directly — Flutter sees the identical widget object every frame, so `didUpdateWidget` is never called on either child. Added `super.key` to `_TimeSection` constructor to accept the key param. Confirmed `CupertinoDatePicker.minuteInterval: 1` unchanged.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-05-01] - Fix: omni-picker _DateSection stability key + TableCalendar fixed row height [shipped]
* **Root cause (`omni_date_time_picker_dialog.dart`):** `_DateSection` was constructed inline in the parent `build()` without a key. On any parent `setState`, Flutter diffed it as a new widget and could reset `_DateSectionState` (losing `_selectedDay`, `_focusedDay`). Separately, `sixWeekMonthsEnforced: true` alone does not pin pixel height — `TableCalendarBase` still computes row height from `daysOfWeekHeight` defaults, causing subtle width/height shifts on month change.
* **Fix:** Added `key: const ValueKey('date_section')` to the `_DateSection(...)` call in `_OmniDateTimePickerDialogState.build()` — Flutter now preserves the existing element rather than recreating it. Added `rowHeight: 42.0` to `TableCalendar` alongside `sixWeekMonthsEnforced: true` to enforce a fixed pixel height for every row regardless of month. Removed the stale unused `theme` local variable from `_OmniDateTimePickerDialogState.build()`. Added `super.key` to `_DateSection` constructor to accept the key param.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-05-01] - Fix: omni-picker calendar → TableCalendar with isolated _focusedDay [shipped]
* **Root cause (`omni_date_time_picker_dialog.dart`):** `CalendarDatePicker` does not render neighboring-month dates — a Flutter framework limitation. The fix was to restore `TableCalendar` (already a project dependency) inside `_DateSectionState.build()`.
* **Fix:** Replaced `CalendarDatePicker` with `TableCalendar` inside `_DateSectionState` only. Added `late DateTime _focusedDay` to `_DateSectionState`, initialized to `_selectedDay` in `initState`. `_focusedDay` is updated exclusively by `onDaySelected` and `onPageChanged` — the text field path updates `_selectedDay` only, leaving the calendar's scroll position untouched. Because `_focusedDay` lives entirely inside `_DateSectionState`, time-wheel `setState` calls in `_TimeSectionState` cannot reach it (separate widget subtrees). Applied `sixWeekMonthsEnforced: true`, `outsideDaysVisible: true`, `outsideTextStyle` with dimmed alpha, `formatButtonVisible: false`, `titleCentered: true`. Public API unchanged.
* **Result:** `flutter analyze` full project: 0 errors (63 info/warnings, all pre-existing).

## [2026-05-01] - Refactor: omni-picker split into _DateSection + _TimeSection widgets [shipped]
* **Root cause (`omni_date_time_picker_dialog.dart`):** All state lived in one `_OmniDateTimePickerDialogState`. Time-wheel `setState` calls (`_applyTimeFromWheel`, `_syncWheelFromTypedTime`) rebuilt the entire dialog tree including the `CalendarDatePicker`, causing layout jank on every drum scroll tick. A `ValueKey` on `year-month` was force-recreating the `CalendarDatePicker` on every month navigation, destroying its internal state and causing neighboring dates to disappear. A `RepaintBoundary` was papering over the rebuild cost without fixing it.
* **Fix:** Extracted date section into `_DateSection` (`StatefulWidget`) owning `_selectedDay` and `_dateTextController`. Extracted time section into `_TimeSection` (`StatefulWidget`) owning `_hourController`, `_minuteController`, `_wheelTime`, focus nodes, and `_ignoreWheelCallback`. Parent `_OmniDateTimePickerDialogState` holds only `_selectedDay`, `_hour`, `_minute` for submit, updated via `ValueChanged<DateTime> onDateChanged` and `void Function(int, int) onTimeChanged` callbacks. Removed `ValueKey` and `RepaintBoundary` from `CalendarDatePicker`. No `_dateTextFromCalendar` flag needed — Flutter's `TextFormField.onChanged` does not fire on programmatic controller changes. `TextFormField` validators in child widgets remain part of the parent `Form` via Flutter's `InheritedWidget` mechanism, so `_formKey.currentState!.validate()` covers all fields. Public API (`showOmniDateTimePickerDialog`) unchanged.
* **Result:** `flutter analyze` full project: 0 errors (63 info/warnings, all pre-existing).

## [2026-04-30] - Bug fix: omni-picker TableCalendar → CalendarDatePicker [shipped]
* **Root cause (`omni_date_time_picker_dialog.dart`):** `TableCalendar` inside the dialog was unstable when co-hosted with `CupertinoDatePicker`. Every `setState` from the time wheel (via `_applyTimeFromWheel`) caused `TableCalendar.didUpdateWidget` to run — even with a separate `_calendarFocusedDay` guard — leading to unpredictable month jumps and layout thrash inside the dialog's `SingleChildScrollView`.
* **Fix:** Replaced `TableCalendar` with Flutter's native `CalendarDatePicker` (no external dependency). Wrapped in `RepaintBoundary` to isolate repaints from time-wheel `setState` calls. Keyed with `ValueKey<String>('year-month')` — stable within a month so day-selection doesn't recreate the widget, but correctly resets when a cross-month date is typed into the text field. Removed `_calendarFocusedDay` state entirely (was only needed for `TableCalendar`). Removed `table_calendar` import from this file (pubspec unchanged — used by `calendar_view.dart`). Simplified `_onCalendarDateChanged` back to single `DateTime` parameter.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-04-30] - Bug fix: omni-picker CupertinoDatePicker ValueKey removal [shipped]
* **Root cause (`omni_date_time_picker_dialog.dart`):** `CupertinoDatePicker` had `key: ValueKey<int>(_wheelTime.hour * 60 + _wheelTime.minute)`. The key value changes on every time-wheel tick, forcing Flutter to destroy and recreate the `CupertinoDatePicker` widget on each callback from `onDateTimeChanged`. This full widget recreation triggered a dialog-level rebuild on every drum scroll tick, which in turn caused `TableCalendar.didUpdateWidget` to run and risk a month jump.
* **Fix:** Removed the `key:` line entirely. `CupertinoDatePicker` manages its own internal scroll state via `initialDateTime`; no external key is needed. Rebuilds from `_applyTimeFromWheel → setState` now update `_wheelTime` (used only as stable reference for `_syncWheelFromTypedTime`) without recreating the drum widget.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-04-30] - Bug fix: omni-picker month jump / jank / outside-days [shipped]
* **Root cause (`omni_date_time_picker_dialog.dart`):** `CalendarDatePicker(initialDate: _selectedDay)` was used inside `_OmniDateTimePickerDialogState`. `TableCalendarBase.didUpdateWidget` (and Flutter's `CalendarDatePicker` equivalent) jump the displayed month whenever `initialDate`/`focusedDay` changes. The Cupertino time drum fires `_applyTimeFromWheel → setState` continuously while scrolling, rebuilding the calendar widget on every tick. Because `_selectedDay` is stable during time-wheel scrolling, the month wouldn't jump from THAT — but `CalendarDatePicker` also lacks `sixWeekMonthsEnforced`, producing variable-height rebuilds that cause layout jank on every time-wheel tick. Additionally, `CalendarDatePicker` had no external `focusedDay` tracking, so navigating months and then interacting with the time field could cause a jump back to `_selectedDay`'s month.
* **Fix:** Replaced `CalendarDatePicker` with `TableCalendar` (already a project dependency). Added `late DateTime _calendarFocusedDay` state to `_OmniDateTimePickerDialogState` (initialized in `initState`, updated only by `onDaySelected` and `onPageChanged`). Time-wheel rebuilds (`_applyTimeFromWheel`, `_syncWheelFromTypedTime`) do not touch `_calendarFocusedDay`, so `TableCalendar.didUpdateWidget` sees no `focusedDay` change and never jumps. `_onCalendarDateChanged` gains optional `focusedDay` parameter; `_onDateTextChanged` also updates `_calendarFocusedDay` so typing a date in a different month correctly jumps the calendar. Applied `sixWeekMonthsEnforced: true` (constant height, eliminates jank), `outsideDaysVisible: true`, `outsideTextStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.35))`.
* **ValueKey status:** Confirmed absent — was removed in the April 30 fix. Not re-introduced.
* **Call sites verified (all route through `showAppDateTimePicker` → `showOmniDateTimePickerDialog` on keyboard-friendly surfaces):** `shared_widgets.dart:1102`, `:1128`, `:1309`, `:1376`, `:2210`, `:2219`; `bulk_planning_edit_sheet.dart:141`, `:158`.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-04-30] - Bug fix: calendar month jump / jank / outside-days (round 2) [shipped]
* **Root cause confirmed (`calendar_view.dart`):** `table_calendar`'s `TableCalendarBase.didUpdateWidget` (v3.1.3, line 113) calls `_pageController.jumpToPage` / `animateToPage` whenever `_focusedDay != widget.focusedDay`. If `_CalendarViewState` is ever re-created (state disposed under memory pressure, or `IndexedStack` lifecycle edge), `initState` re-copies `widget.focusedDay` from the parent. On the next parent rebuild the parent's `_focusedDay` (stale value) differs from what `TableCalendarBase` last stored, triggering an immediate page jump.
* **Fix — Bug 1 (month jump):** Added `AutomaticKeepAliveClientMixin` to `_CalendarViewState` (`wantKeepAlive => true`, `super.build(context)` called first in `build()`). State is now aggressively kept alive; `initState` is guaranteed to run only once per session, so `widget.focusedDay` can never re-seed local `_focusedDay` after first paint. `_focusedDay` remains exclusively owned by `onPageChanged` + `onDaySelected`. No `didUpdateWidget` override — parent rebuilds do not touch local state.
* **Fix — Bug 2 (layout jank):** Added `sixWeekMonthsEnforced: true` to `TableCalendar`. `TableCalendarBase` previously calculated row count per month (4–6 rows), causing the calendar widget to resize on month transition and produce layout shifts. All months are now 6 rows, height is constant.
* **Fix — Bug 3 (adjacent month days hidden):** Added `calendarStyle: CalendarStyle(outsideDaysVisible: true, outsideTextStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.35)))`. Leading/trailing days from adjacent months are now visible with dimmed text.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-04-30] - Bug fix: calendar month jump + Omni-Picker Law audit [shipped]
* **BUG (calendar_view.dart):** `CalendarView` was a `StatelessWidget` with `focusedDay` sourced from the parent (`_focusedDay` in `app_shell.dart`). Any parent `setState` (frequent from stream events) rebuilt the widget with the same stale `focusedDay` because `TableCalendar.onPageChanged` was not wired — page navigation never updated the parent. `TableCalendar` then reset its displayed month to the parent's original value. Fix: converted to `StatefulWidget` (`_CalendarViewState`), owns `_focusedDay` locally via `initState`, wired `onPageChanged: (day) => setState(() => _focusedDay = day)` and updated `onDaySelected` to also call `setState(() => _focusedDay = focused)`. Parent `app_shell.dart` unchanged.
* **Omni-Picker Law audit (Bug 2):** Full grep across the codebase for `showDatePicker`, `showTimePicker`, `showCupertinoModalPopup`, and `CalendarDatePicker`. All remaining hits are date-only exempt: `global_app_header.dart:21` (date-only header nav, keyboard), `global_app_header.dart:40` (date-only header nav, mobile `CalendarDatePicker` in dialog — closes on select), `planning_view.dart:331` (date-only reschedule, preserves task's existing time). No new violations found after previous session's `bulk_planning_edit_sheet.dart` fix.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-04-30] - Bug fixes: omni picker month reset + bulk edit legacy pickers [shipped]
* **BUG (omni_date_time_picker_dialog.dart):** Removed `ValueKey<String>` from `CalendarDatePicker` (was keyed to `'${_selectedDay.year}-${_selectedDay.month}-${_selectedDay.day}'`). Key change on every day tap forced full widget rebuild, resetting the displayed month back to the newly selected day. Fix: remove key entirely so Flutter reuses the widget in-place.
* **BUG (bulk_planning_edit_sheet.dart):** Replaced `showDatePicker` + hand-rolled iOS `showCupertinoModalPopup` time picker + `showTimePicker` with `showAppDateTimePicker` in both `_pickDate` and `_pickTime`. Removed `picker_entry_modes.dart` and `cupertino.dart` imports; added `shared_widgets.dart` import. `_pickDate` extracts only the date component from the returned `DateTime`; `_pickTime` extracts only the `TimeOfDay`. State shape (`_date`, `_pickedTargetTime`) unchanged.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-04-30] - V5.5: extract db_core.dart from database_service.dart [shipped]
* **Extraction (lib/data/db_core.dart — new, ~418 lines):** Bootstrap and lifecycle domain moved to a `part of 'database_service.dart'` file using `extension DbCoreExtension on DatabaseService`. Contains: `ensurePocketBaseReady`, `_maybeVerifyPocketBaseReachable`, health/circuit helpers (`_registerPocketBaseUnreachable`, `_clearPocketBaseConnectivityBackoff`, `_isPbCircuitWorthyFailure`, `_maybeOpenPbCircuitFromListFailure`), realtime reconnect (`ensureRecordsRealtimeBridge`, `_scheduleRecordsRealtimeReconnectAfterFailure`, `_logRecordsRealtimeSubscribeQuiet`), `_hydrateRecordsCacheFromPrefsIfEmpty`, lifecycle observer register/unregister, `clearLocalStateOnSignOut`, `setDataRegion`, `loadInitialData`, `loadInitialDataWearLite`, `_loadInner`, `_loadInnerWearLite`.
* **Result:** `database_service.dart` 1,089 → 720 lines. `db_core.dart` 418 lines (new). God Object split complete across 5 part files. `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-04-29] - V5.4: extract category_service.dart from database_service.dart [shipped]
* **Extraction (lib/data/category_service.dart — new, ~3,158 lines):** Category domain moved to a `part of 'database_service.dart'` file using `extension CategoryServiceExtension on DatabaseService`. Contains: `fetchCategories`, `_loadRulesFromNoco`, category CRUD (`addNestedCategory`, `updateCategory`), `findCategoryByFuzzyMatch`, slug helpers, stats utilities (`statsRecordsSignature`, `recordDurationSecondsWithinDayFromTimestamps`, `startTimeFromRecord`, `endTimeFromRecord`), record-query helpers (`recordsTablePk`, `isRecordMapActuallyRunning`, `_rowInt`, `_parseDateTimeUtc`, `_isNocoRowActiveRunning`, `_isLikelyUuidOrLongPk`, `_isNocoRowSacredStopTarget`), and sacred-stale-open merge logic.
* **Qualification fixes in category_service.dart:** `_cacheCategoriesRawKey` / `_nocoSystemRowIdKey` / `_nocoEnvelopePkKey` / `_nocoCategoryRestSegmentKey` / `_sacredStaleOpenCap` / `_oneShotUntitledGhostCleanKey` qualified with `DatabaseService.` prefix (6 statics, all `replace_all`).
* **Cross-file call-site updates:** 11 statics now in `CategoryServiceExtension` re-routed from `DatabaseService.X()` → `CategoryServiceExtension.X()` across `record_service.dart`, `plan_service.dart`, `profile_service.dart`, `database_service.dart`, `stats_view.dart`, `timeline_view.dart`, `wear_timer_screen.dart`.
* **Result:** `database_service.dart` 4,238 → 1,089 lines. `category_service.dart` 3,158 lines (new). `flutter analyze` full project: 0 errors (57 info/warnings, all pre-existing).

## [2026-04-29] - V5.3: extract record_service.dart from database_service.dart [shipped]
* **Extraction (lib/data/record_service.dart — new, ~2,407 lines):** Record domain moved to a `part of 'database_service.dart'` file using `extension RecordServiceExtension on DatabaseService`. Contains: `writeRecord`, `stopRecordByDocId`, `updateRecord`, `deleteRecordByDocId`, optimistic shadow methods (`_startAtomicTaskSequenceApplyLocalPrimary`, `_applyOptimisticStopUiSnapshot`), realtime handler (`_onPbRecordsSubscriptionEvent`), record cache mutation (`_upsertFlatRecordFromPbModel`), ID resolution (`_resolveRecordIdForStopOrDelete`), singleton/stale-open detection, and all supporting record fetch/parse helpers.
* **Qualification fixes in record_service.dart:** `_appLifecycleObserver` / `_appLifecycleObserverRegistered` / `_kMinGapRecordsNetworkFetch` / `_cacheRecordsFlatKey` / `_nocoSystemRowIdKey` / `_isNocoRowActiveRunning` — all qualified with `DatabaseService.` prefix.
* **Result:** `database_service.dart` 6,634 → 4,238 lines. `record_service.dart` 2,407 lines (new). `flutter analyze` full project: 0 errors (57 info/warnings, all pre-existing).

## [2026-04-28] - V5.2: extract plan_service.dart from database_service.dart [shipped]
* **Extraction (lib/data/plan_service.dart — new, ~2,803 lines):** Plan domain moved to a `part of 'database_service.dart'` file using `extension PlanServiceExtension on DatabaseService`. Extracted: library-level state (`_planCreateOutboxFlushInFlight`, `_tasksController`, `_planningRefreshController`, `_planningOptimisticByDateKey`, `_tasksCache`, `_planOrderDebounce`, `_planOrderBulkChunkSize`, `_planOrderDebounceTimer`, `_pendingPlanOrderSyncList`, `_planReorderBaselineByPlanId`, `_planAlarmRescheduleDebounceTimer`, `_random`); library-level consts/getters (`_plansToTagsLinkColumnSystemId`, `_isPlansTableConfigured`); 75 methods/getters including all plan CRUD, rrule expansion, optimistic UI cache, alarm scheduling, order persistence, AI task parsing, plan prefs, and plan link scoring statics.
* **Qualification fixes in plan_service.dart:** `_log(` → `DatabaseService._log(`; `_levenshteinDistance(` / `_isLikelyPocketBaseRowId(` / `pocketRelationIdOrNull(` / `getPlanetaryNow(` / `_parseDateTimeUtc(` / `recordDurationSecondsWithinDayFromTimestamps(` / `_sanitizePkString(` / `newClientUuid(` / `_newClientRecordUuid(` / `_categoryOrderDebounce` / `_nocoEnvelopePkKey` — all qualified with `DatabaseService.` prefix (12 statics, all `replace_all`).
* **Call-site fix in planning_view.dart:1562:** `DatabaseService.planningWallEstimateSeconds` → `PlanServiceExtension.planningWallEstimateSeconds` (extension statics must be called via extension name, not type name).
* **`tool/apply_v52.dart` deleted** (22-anchor extraction script, served its purpose). `tool/transform_v52.dart` deleted (dry-run manifest only).
* **Result:** `database_service.dart` 9,415 → 6,634 lines. `plan_service.dart` 2,803 lines (new). `flutter analyze` full project: 0 errors (116 info/warnings, all pre-existing).

## [2026-04-27] - V5.1: extract profile_service.dart from database_service.dart [shipped]
* **Extraction (lib/data/profile_service.dart — new, 666 lines):** 19 block extraction via `transform_v51.dart` (deleted post-run). Profile/tag domain moved to a `part of 'database_service.dart'` file using `extension ProfileServiceExtension on DatabaseService`. Extracted: `_ProfileFetchFailedException` (top-level class); library-level state (`_profilePbRecordId`, `_dataRegion`, `_settings`, `_settingsController`, `_userTagsCatalogCache`, `_tagsCatalogRefreshController`); library-level consts (`_dataRegionKey`, `_profileTzLabelKey`, `_profileTzOffsetKey`, `_profileThemeModeKey`); top-level functions (`_normalizeTimezone`, `_fixedOffsetHoursFromLabel`, `utcRangeForDateInTimezone`, `utcRangeForWallClockDate`); extension methods: `settings`, `cachedUserTagsCatalog`, `tagsCatalogUpdated`, `notifyTagsCatalogChanged`, `dataRegion`, `reloadForDataRegionChange`, `getUserProfile`, `getCurrentUserProfileMap`, `saveSettings`, `updateTimeZone`, `updateUserTimezone`, `fetchTagsForCurrentUser` + tag CRUD, `getProjectedToday`, `applyUserOffset`, `getTimelineDeviceLocalToday`.
* **Pre-transform promotion:** `_two()` and `_dateKeyFromDate()` promoted from `static` class methods to top-level library functions in `database_service.dart` to avoid `unqualified_reference_to_static_member_of_extended_type` errors inside the extension.
* **Auth stubs deleted entirely:** `signInWithYandex`, `exchangeCodeForSession`, `signInWithOtp`, `verifyOtp` not included in profile_service.dart (already dead code — no callers).
* **Post-extract fixes:** `_log(` → `DatabaseService._log(` and `_rowInt(` → `DatabaseService._rowInt(` (replace_all in profile_service.dart — both are `static` on DatabaseService, not inherited by extension); extension renamed `_ProfileServiceExtension` → `ProfileServiceExtension` (private extension not visible to callers in other files).
* **Result:** `database_service.dart` 10,063 → 9,415 lines. `flutter analyze` full project: 0 errors (58 info/warnings, all pre-existing or isolated-scope false positives).

## [2026-04-27] - Phase 1 roadmap sync + timezone comment corrections [shipped]
* **Roadmap sync (commit a7f27d5):** Phase 1 bug `database_service.dart:3830` (mixed timezone sources in `_rowStartWallDayIsBeforeProjectedToday`) was already fixed in `393bb0f` (April 25) — `toLocal()` replaced with `_timelineDeviceLocalDayKeyFromUtc`; the ROADMAP was the stale artifact. Status updated to ✅ Fixed; Phase 1 now 3 of 5 done, 2 open: `models.dart:709` (HIGH) and category-drop on cold start (MEDIUM).
* **Doc comment corrections — `database_service.dart`:** `_rowStartWallDayIsProjectedToday` doc changed from "device-local calendar today" → "profile wall-clock today"; `_filterCachedRecordsForDate` inline comment changed from "device local Y-M-D only (no profile-offset wall)" → "profile wall-clock Y-M-D; callers must pass a profile wall-clock date". Comments had inverted the reality of the code, trapping future maintainers.
* **CLAUDE.md nav map:** Added row "Singleton / stale-open detection → `_rowStartWallDayIsBeforeProjectedToday` / `_mergeSacredStaleOpenCandidates`" to the Where things live table.

## [2026-04-27] - Round 4: avoid_print sweep [shipped]
* **Round 4a — app_shell.dart (commit e9611b0):** Converted 10 `print()` error-path calls to `debugPrint()`. Deleted 2 "Attempting to stop record" got-here traces from `_showEditRecordSheetForTimeline.onStop`; also dropped the now-dead `final ok =` capture and empty `if (!ok)` block — DatabaseService surfaces stop failures internally via `_brainSnackError` / `_snackStopHttpFailure`.
* **Round 4b — database_service.dart hot-path DELETEs (commit 1bdea90):** Deleted 16 `print()` calls: `SEARCHING PB FOR` trace (fires on every Stop/Delete ID resolution); two `ID TRANSLATION` prints inside plan/category `for` loops (tight loops); `_printAtomicCheckRunningCount` body; two `if (logSuccessLine)` blocks in `_upsertFlatRecordFromPbModel` (realtime hot path); `_logRecordsPatchDispatch` and `_logRecordsDeleteDispatch` bodies (every PATCH/DELETE); `_logIdMapTranslated` body (every successful PATCH); `[ABORT_REASON]` dead-letter PATCH skip (#31 — sync-storm risk); `[POST_PAYLOAD]` full payload dump before `records.create`; `[SMART_LINK]` category match trace (#35 — fires on every fuzzy-hit record write); `[SHADOW_EMIT]` optimistic shadow on Start; `DEBUG: Tag` in `_pbTagRecordIdsFromTags` tight loop; two `DEBUG: Sending to PB tags_link` verbose dumps.
* **Round 4c — database_service.dart debugPrint conversions (commit f724c69):** Converted 24 remaining `print()` calls to `debugPrint()` on genuine error/diagnostic paths: emergency fallback ID lookup + owner-mismatch conflict; `PB_ERROR_RESPONSE` on `fetchCategories` / `fetchAllCategories`; `ID TRANSLATION` cache-hit and server-hit in `_resolveRecordIdForStopOrDelete`; `[ABORT_REASON]` PATCH-failed catch; `PB_CREATE_ERROR_DETAILS` on records create; `[SERVER_ERROR_BODY]` + `[CATEGORY_RECOVERY]` in category creation; four `[CHILD_RECORD_PARSE]` parse-error prints (2 overloads × message + stack trace); 8 guard-clause and catch-block prints in `stopRecordByDocId`.
* **Round 4d — voice_audio_web + shared_widgets + planning_view (commit a99646b):** Added `import 'package:flutter/foundation.dart' show debugPrint;` to `voice_audio_web.dart` (only Flutter-free file in scope). Deleted 2 "Attempting to stop" got-here traces from `_stopChild` and `_stop` in `shared_widgets.dart`. Converted 5 remaining error-path prints to `debugPrint()` across `shared_widgets.dart` and `planning_view.dart` (`_toggleDone` catch).
* **Result: `flutter analyze` shows 0 `avoid_print` violations across all 6 in-scope lib files. One pre-existing violation in `tool/test_smart_parse.dart` is out of scope. Net reduction: 17 deleted, 45 converted to debugPrint, 3 left as LEAVE (already `// ignore: avoid_print` — boot-fail crash surfaces in `main.dart` and `database_service.dart`). Total prints touched: 65.**

## [2026-04-27] - Phase 1 cleanup: legacy backends + dead code [shipped]
* **Round 1+2 — Legacy backend deletion (commit 66e37e5):** Removed 11 files: `lib/data/yandex_ydb_auth_bridge.dart`, `lib/data/yandex_ydb_provider.dart`, `lib/data/ydb_api_client.dart`, top-level `lib/ydb_api_client.dart`, `lib/models/nocodb_response.dart` (+ empty `lib/models/` dir), top-level `lib/l10n.dart` (vestigial static class), and `lib/migration_data/` (5 CSVs not in pubspec assets). `auth_service.dart` and `auth_screen.dart` retained — still actively imported by `main.dart` and `profile_view.dart`; flagged for separate migration.
* **Round 3a — Trivial dead code (commit 0f49121):** Removed 3 unused imports from `lib/features/shared/shared_widgets.dart` (`category_color_palette.dart`, `category_db_display.dart`, `flutter/services.dart`); deleted dead widget class `_PlanningDatePickerDialog` (40 lines) from `lib/features/planning/planning_view.dart`; deleted unused `_uuidRe` constant from `tool/verify_migration.dart`.
* **Round 3b — NocoDB-era parsers (commit 09fff1f):** Removed `_parseNocoCategoryWrapperRowIdFromBody` and `_parseCategoryFieldsCategoryIdFromBody` from `lib/data/database_service.dart` (42 lines). Both were NocoDB response parsers with zero call sites post-PocketBase migration.
* **Round 3c — Legacy private helpers (commit 91b356b):** Removed 5 unused privates from `lib/data/database_service.dart` (47 lines): `_SignInRequiredException`, `_standardUuidRe` + `_looksLikeStandardUuid` (deleted as pair — regex orphaned without consumer), `_m2MlinkIntCount` (NocoDB M2M rollup parser), `_replaceCategoryNodeById` and `_updateCategoryTagInRules` (legacy in-memory category tree mutators by int id; pre-flight grep confirmed `_rules` mutation is alive elsewhere).
* **`flutter analyze`: 143 → 119 issues (−24, all info/warning, zero errors). Web release build clean with `--no-tree-shake-icons`.**
* **Backlog noted:** `auth_service.dart` migration (still wired alongside `AuthBridge`); icon tree-shaking failure (`category.dart:315`, `database_service.dart:5689` use non-constant `IconData`); 63× `avoid_print` sweep (Round 4); 2× `unused_field` in `database_service.dart` (`_cachedProfileUuid`, `_planOrderBulkChunkSize` — kept defensively, may be optimistic-cache plumbing).

## [2026-04-25] - Phase 1 bugs + Phase 3a/3b foundation + model split [shipped]
* **Phase 1 — Timezone (`lib/data/models/record.dart`, `lib/data/database_service.dart`):** Fixed three `toLocal()` violations: `_recordLocalCalendarDate` accepts `[int offsetHours = 0]`; `TimelineRecord.dateKey` uses new `timezoneOffsetHours` field (UTC + `Duration(hours:)`, no device TZ); `_rowStartWallDayIsBeforeProjectedToday` replaced device-local date compare with `_timelineDeviceLocalDayKeyFromUtc(stUtc).compareTo(getTimelineDeviceLocalTodayDateKey()) < 0`. Four `TimelineRecord.fromMap` callers in `database_service.dart` + one in `app_shell.dart` pass `timezoneOffsetHours: _settings.timezoneOffsetHours`.
* **Phase 1 — Category ID hash collision (`lib/data/models/category.dart`):** Replaced `rawId.hashCode` (Dart-VM-randomised, dart2js-variable) with `_stableStringHash(rawId)` — deterministic 31-bit polynomial hash, range [1, 0x7FFFFFFF], avoids sentinels -1 and 0. No migration: `CategoryRule.id` is session-local, never persisted.
* **Phase 3a — Kill `EditRecordSheet` (`lib/features/shared/shared_widgets.dart`, `lib/app_shell.dart`):** Deleted legacy NocoDB-era `EditRecordSheet`. All timeline record edit entry points now route exclusively to `_TimelineRecordSheetContent`.
* **Phase 3b — Component library (`lib/core/widgets/`):** Built 4 primitives: `AppLoading` (`app_loading.dart`), `showConfirmDialog` (`confirm_dialog.dart`), `AppButton` (`app_button.dart`), `AppErrorState` + `AppEmptyState` (`app_state_views.dart`). Migrated all 17 inline `CircularProgressIndicator` call sites to `AppLoading(size:)`.
* **Phase 4.2 — Split `lib/data/models.dart` into Dart part files (`lib/data/models/`):** `_shared.dart` (enums + JSON/ISO/ID helpers), `profile.dart`, `category.dart`, `record.dart`, `planning.dart`, `tag.dart`, `stats.dart`. Public API unchanged; import via `package:counter/data/models.dart` or barrel `package:counter/models.dart`.
* **`flutter analyze`: 143 pre-existing info/warnings, zero new issues introduced. Web release build verified locally. All committed.**

## [2026-04-20] - Strike 25: Shell layout isolation & ticker edge-scroll (victory)
* **Strike 25 (`lib/core/shell_layout_state.dart` `ShellLayoutController` / `ShellLayoutScope`, `lib/app_shell.dart`, `lib/features/planning/planning_view.dart`, `lib/features/lists/lists_view.dart`, `lib/data/database_service.dart`):** Enforced domain isolation by extracting UI layout state (`ShellLayoutController`) from the data layer. Replaced frame-dependent pointer events with a time-delta `Ticker` to guarantee hardware-agnostic, consistent velocity for timeline edge auto-scrolling.
* **Strike 25 — Lists / Backlog (`lib/features/lists/lists_view.dart`, `UserSettings.listCompletionBehavior`, `DatabaseService.persistPlanningTaskOrder`):** `CustomScrollView` + `SliverReorderableList` + `ReorderableDelayedDragStartListener` for long-press backlog reorder with optimistic `plans.order` + debounced bulk PATCH; per-card category path header; `list_completion_behavior`-driven done/archive/hide layouts; filter chip bar with horizontal manual reorder; optional tag chips on cards; mass-edit selection + bottom bar reporting FAB clearance through `ShellLayoutScope` (not the data layer).
* **Strike 25 — Planning day & tag fork (`lib/features/planning/planning_view.dart`, `lib/features/profile/tag_settings_hub.dart`, `lib/features/profile/tag_manager_page.dart`, `lib/features/shared/shared_widgets.dart` `_PlanningTaskEditSheet`):** Segmented sort surface (category / wall-time hour grid / tags / custom) with delayed-drag reorder in tag & custom buckets; hour-grid `LongPressDraggable` + slot `DragTarget` rescheduling; plan bulk-select bar wired to shell FAB reserve. `TagSettingsHub.tagCreateDomain` + `TagManagerPage.pocketTagDomain` enforce PocketBase `tags.domain` + `fetchTagsForCurrentUser(scope:)` so Ideas/backlog CRUD list-scoped tags without mixing the plan tag catalog.

## [2026-04-19] - Strike 24: UI purge & editor unification (victory)
* **Strike 24 (`lib/features/timeline/timeline_view.dart`, `lib/features/timeline/timeline_widgets.dart`, `lib/features/planning/planning_view.dart`, `lib/features/shared/shared_widgets.dart`, `lib/core/theme.dart`, `lib/l10n/dictionary.dart`):** Eliminated legacy spatial bloat by moving dates to a compact SafeArea strip. Unified the Plan and Record edit sheets into a mirrored, left-aligned Tab architecture (Start/End 50-50 row, Notes, Checklist, Parallel) and stabilized the Quill toolbar height, maintaining strict schema adherence for Record text persistence.

## [2026-04-17] - Strike 22: Idea vs Plan editor fork (rollback)
* **`_PlanningTaskEditSheet` (`lib/features/shared/shared_widgets.dart`, `_startedAsUndatedBacklog`, nullable `TabController`):** Resolved UI regression by explicitly branching `_PlanningTaskEditSheet` logic based on list-item state. Restored the optimized single-scroll layout for time-bound Plans (exposed Omni-Picker, visible Tags) while preserving the 3-tab GTD layout for Ideas, ensuring both modes safely integrate the new Quill editor schema.

## [2026-04-17] - Strike 19: Idea Editor (GTD layout + Markdown toolbar)
* **Idea Editor (`lib/features/shared/shared_widgets.dart` `_PlanningTaskEditSheet`, `lib/l10n/dictionary.dart` `notes_md_*`):** Overhauled the Idea Editor into a strict 3-tab GTD layout (Notes, Checklist, Schedule), completely purging the Tag UI for undated backlog items. Implemented a lightweight, schema-safe Markdown injection toolbar for the Notes field, avoiding heavy WYSIWYG dependencies while preserving the Optimistic UI speed.

## [2026-04-17] - Strike 17: Omni-Picker refinement
* **Platform / omni-picker (`lib/core/widgets/omni_date_time_picker_dialog.dart`, `showAppDateTimePicker` keyboard path in `shared_widgets.dart`):** Refined the Web/Desktop Omni-Picker into a hybrid UI, combining Flutter's native CalendarDatePicker for visual day selection with a custom-styled, large-format digital text input for time. Maintained the single-dialog Omni-Picker Law while drastically improving visual hierarchy and desktop input ergonomics. Replaced `InputDatePickerFormField` with `CalendarDatePicker` + `ValueKey` sync; soft rounded HH:mm fields, divider, ~350px content width; mobile/touch path unchanged (`omni_datetime_picker`).

## [2026-04-17] - Strike 16: Authentication gates
* **Auth / routing (`auth_bridge.dart`, `auth_view.dart`, `main.dart` `RootAuthWrapper`, `pb_config.dart` `PbCollections.profiles`):** Implemented secure authentication flow targeting the profiles collection with a unified AuthView UI (Sign In, Register, Password Reset, OAuth). Hardened checkSession() to strictly trust pb.authStore.isValid, removing stale local fallbacks, and wired the global routing gate to protect the AppShell. Added `loginWithPassword` / `register` / `requestPasswordReset` / `loginWithOAuth2` (`AuthBridgeException` / `AuthBridgeCancelled`); all PocketBase auth uses `profiles` only; `auth_screen.dart` re-exports `AuthView`.

## [2026-04-17] - Strike 15: Unified Omni-Picker
* **Platform / omni-picker (`ARCHITECTURE.md` §8.1, `lib/core/widgets/omni_date_time_picker_dialog.dart`, `shared_widgets.dart` `showAppDateTimePicker`, `picker_entry_modes.dart`):** Codified the Omni-Picker Law in ARCHITECTURE.md and implemented a unified, keyboard-first Date & Time AlertDialog for Web/Desktop, replacing the sequential picker flow to eliminate UX friction while preserving mobile touch flows. The `useKeyboardFriendlyMaterialPickers()` path now opens `showOmniDateTimePickerDialog` (`InputDatePickerFormField` + 24h hour/minute `TextFormField`s, single Save) instead of chained `showDatePicker`→`showTimePicker`; touch/mobile still uses `showOmniDateTimePicker` from `omni_datetime_picker`.

## [2026-04-17] - Strike 14: Inbox gating & UI polish
* **Lists / Timeline / Planning / shell (`lists_view.dart` `_filterCategoryId` gate, `timeline_view.dart` / `planning_view.dart` `kIsWeb` chevrons, `app_shell.dart`, `dictionary.dart` `input_placeholder_*`, `tag_contrast.dart` / `chip_component.dart`):** Enforced strict GTD Inbox gating with empty states. Purged redundant manual-add UI/dead code from app_shell, standardized inline placeholders, relocated 'No Tags' settings with dynamic B/W contrast, and implemented Web-only chevron date navigation.

## [2026-04-17] - Strike 13: Inbox paradigm & UI purge
* **Shell / Lists / task editor:** Purged redundant cloud sync UI. Overhauled Inbox/Lists paradigm: updated localized placeholders, implemented collapsible category tree in Lists settings, restyled cards (leading checkbox, no category pill), and added GTD 'graduate to plan' logic for dating backlog items. (`app_shell.dart` removed `_SyncStatusIcon` / connection overlay; `lists_view.dart` `ListsPage.onEditTask`, `_buildManualCategoryTreeTile` + `ExpansionTile`, underline + green inline add, `_BacklogPlanCard`; `timeline_view.dart` / `planning_view.dart` / `dictionary.dart` `input_placeholder_*`; `shared_widgets.dart` `_PlanningTaskEditSheet` `_startedAsUndatedBacklog` / `plan_graduate_*`.)

## [2026-04-17] - Strike 12: Web accelerator (keyboard-first pickers)
* **Platform / pickers:** Centralized platform-aware picker logic in picker_entry_modes.dart. Forced all showDatePicker and showTimePicker invocations across the app to default to input mode on Web/Desktop for rapid keyboard entry, while preserving calendar/dial modes for mobile. (`appDatePickerEntryMode` / `appTimePickerEntryMode`, `useKeyboardFriendlyMaterialPickers()`; `global_app_header.dart`, `shared_widgets.dart` `showAppDateTimePicker` + record date pickers, `planning_view.dart` `_changeSingleTaskDate` / `_openPlanningHeaderDatePicker`, `bulk_planning_edit_sheet.dart`.)

## [2026-04-17] - Strike 11: UI reclamation & six critical fixes
* **Lists / Planning / shell:** Standardized GlobalAppHeader (Day · Date · Time) and restored Lists inline-add UI. Enforced category colors on filter chips, implemented toggle-to-clear filtering to replace the 'All' chip, indented the Lists category settings tree, and added SharedPreferences persistence for customizable 'No Tags' visibility and color (including pure black/white). (`global_app_header.dart` removes `sectionTitle`; `lists_view.dart` `FilledButton.icon` inline add, `_ListsQuadraticChip` category tints, `_categoryTreeDepthFromPath` manual sheet; `timeline_view.dart` / `planning_view.dart` header call sites; `planning_view.dart` + `chip_component.dart` `TagQuickPickStrip.onTagLongPress` when non-reorder; prefs `no_tags_visible` / `no_tags_color`.)

## [2026-04-17] - Strike 8: Sortable pseudo-tag & UI purge
* **Planning / tags:** Purged redundant static tag filter UI. Injected a draggable, synthetic 'No Tags' pseudo-tag (ID -1) into the existing tag prioritization strip, persisting its custom sort order via SharedPreferences to dynamically route untagged tasks in the timeline view. (`planning_view.dart`, prefs key `planning_quick_bar_tag_ids_v1`, `_groupIdsInMasterBarSequence`.)

## [2026-04-17] - Strike 4: Backlog quarantine & Lists UX
* **Backlog / Lists:** Quarantined backlog data by bypassing the dateKey/startTime optimistic defaults in database_service.dart. Implemented horizontal quadratic category chips with SharedPreferences persistence and enforced leaf-node strictness for inline item creation.

## [2026-04-16] - Strike 2 & 2.5: Context-aware parser + STT locale
* **Parser / STT:** Upgraded smart_input_parser.dart with a leading-hour regex and an isBacklog bypass for dateless plans. Enforced strict EN/RU localeId binding (using en-US for Web) in the STT listener, fixing legacy locale hardcodes.

## [2026-04-16] - Strike 2: Context-aware parser & STT locale
* **Parser / STT:** Upgraded smart_input_parser.dart with a leading-hour regex (^([01]?\d|2[0-3])\s+) and an isBacklog bypass that forces startTime: null and strips scheduling junk. Enforced strict EN/RU localeId binding in the STT listener, removing legacy Web locale hardcodes.

## [2026-04-16] - Strike 1: Lists friction + optimistic tags
* **Lists / planning cache:** Fixed Optimistic UI cache for tags by removing the server-override branch in `_mergePlanningOptimistic`. Added inline quick-add with `_pendingInline` state and a delete button with confirmation dialog to the ListsView. (`database_service.dart` `applyOptimisticPlanningTask` dateKey fallback for short keys; `lists_view.dart` optimistic `optimistic-inline-*` rows + `addPlanningTask` / `deletePlanningTasksBulk`; l10n `lists_inline_add_hint` / `lists_delete_backlog_confirm`.)

## [2026-04-16] - Recurring: instance materialization (virt- complete)
* **Planning / recurrence:** Refactored virtual clone mutation in `database_service.dart`. Separated Delete (adds `exception_dates` to parent) from Complete (Instance Materialization: adds exception to parent AND creates a concrete `isDone: true` record). Added a strict rollback mechanism if the materialization POST fails. (`_parseVirtualPlanRowId`; delete path → `_patchRecurringTemplateExceptionDates` only; complete path → `_completeVirtualRecurringInstance` = parent PATCH + `_createPlanningTaskPocketStrict` / `_buildPocketPlanCreateBody`; rollback removes the exception; `updatePlanningTask` / `markPlanningTasksCompletedBulk` vs `deletePlanningTasksBulk`.)

## [2026-04-16] - Phase 4–5: Zero-Table Lists & More navigation
* **Backlog / shell:** Implemented 'Zero-Table' Lists using dateless PlanningTask rows in database_service.dart with 1-tap Play/Complete execution. Restructured App Shell navigation using IndexedStack, adding ListsView and collapsing Profile/Categories into a new MoreView. (Implementation: `fetchBacklogPlans` / `startRecordFromPlanTask` / `startTimerWithCategory` dateKey fallback; day-scoped plan fetches require `startTime`; `lists_view.dart`, `more_view.dart`, `app_shell.dart`.)

## [2026-04-16] - Phase 3: Scheduling Engine UI (recurrence + notifications)
* **Scheduling / notifications:** Wired UI bindings in _PlanningTaskEditSheet for rrule and reminderOffset. Upgraded DatabaseService PATCH payloads to correctly route recurrence edits. Added Notification OS permissions diagnostic to ProfileView. (`shared_widgets.dart` `_PlanRepeatUi` / reminder `DropdownButtonFormField`, `database_service.dart` `patchPlanAlarmRecurrence` + `_scalarPatchBodyForPlanningRow`, `app_shell.dart` `_persistPlanningEditFromSheet`, `profile_view.dart` `_ProfileNotificationsSection` + `FlutterLocalNotificationsPlugin.areNotificationsEnabled` on Android; `PlanningTask.copyWith` `clearReminderOffset` / `exceptionDates` with `clearRrule` in `models.dart`.)

## [2026-04-15] - Timeline & planning card metadata icons
* **Planning / Timeline cards:** Added synchronous boolean getters (hasNotes, hasChecklist, etc.) to Record and PlanningTask models in `models.dart`, and bound them to muted icon rows in UI cards. Strictly avoided N+1 database queries in the `build()` method; wiring uses `Record.forTimelineCard` + `_timelineRecordMetaIcons` in `timeline_view.dart` and `_planningTaskMetaIcons` in `planning_view.dart` (plus aligned getters on `TimelineRecord`).

## [2026-04-08] - Bilingual STT & Timeline Overlap Fix
* **Voice Input (STT):** Implemented strict `RU | EN` toggle on `VoiceInputSheet`. Preserves prefix on toggle. Web bypasses empty locales using explicit `ru-RU`. (DO NOT REBUILD).
* **Database (PocketBase):** Added `record.update:before` and `record.create:before` hooks to enforce the Singleton Timeline Law. Server now auto-truncates overlapping records.
* **Parser:** Implemented dependency-free Levenshtein fuzzy matching (0.9 threshold) for Category string matching in `smart_input_parser.dart`.

## [2026-04-05] - Timeline & Stats Foundation
* **UI:** Created `timeline_view.dart` and nested `stats_view.dart` inside the timeline feature module.
* **Logic:** Built initial `DatabaseService` logic for fetching records grouped by day using `timezone_offset`.

## [2026-04-03] - UI Performance & Shell Foundation
* **Architecture:** Enforced Optimistic UI and Zero-await policies. Visual updates trigger in <100ms. DB writes use `unawaited` fire-and-forget logic.
* **State Management:** Implemented strict Unidirectional Data Flow. `database_service.dart` acts as the God Object; UI modules (`features/`) are "dumb" and never mutate data directly.
* **Categories UI:** Implemented Dynamic Grid Math (3/4/5 tiles wide based on depth, 8pt gaps) and The Centering Law (Icon + Text tightly clustered in the absolute center).

## [2026-04-01] - PocketBase Setup & Realtime Sync
* **Database:** Mapped `profiles`, `categories`, `records`, `plans`, and `tags` collections adhering strictly to the Iron Laws (15-char System IDs for REST, UUIDs for metadata only).
* **Realtime:** Implemented `subscribe('*')` on the `records` collection so Web and Mobile share identical in-memory cache updates.
* **AI API Structure:** Established `POST /api/ai/parse-task` endpoint on the server for secure Groq LLM integration.
* **Time Engine:** Grouping logic fully relies on profile `timezone_offset` and `preferred_timezone`. Banned local `DateTime.now()` for persisted grid keys.

## [2026-03-29] - Anti-Spam & Network Guards
* **Circuit Breakers:** Implemented strict 15-second cooldowns for background fetches and a 3-strike/60-second block for failed requests.
* **Error Handling:** Enforced silent success logs and debounced errors (logged once) to protect VPS resources.
