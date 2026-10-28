## [2026-10-28] — Shared plans using existing People (candidate, unmerged)

- Added **on-demand** selected-day plan sharing into a server-owned shared draft; the existing People section now provides recipient selection and a Shared-plans invitation entry point. No second Contacts domain. Shared-day views in Planning and focused Calendar reflect the server-owned accepted projection; comments and task title/time proposals use profile timezone. Owner can revoke, member can leave.
- New closed `shared_objects` / `shared_members` / `shared_messages` schema and authenticated `/api/shares` hooks isolate each owner's records, require invite acceptance, and support discussion and versioned task-title proposals with owner approval.
- Added deterministic route authorization tests and the collaboration implementation contract (`docs/SHARING_COLLABORATION.md`). **Not deployed / not production-ready.** Accepted suggestions update the shared draft only; participant Planner/Calendar sync, offline queues, and real-account E2E remain outstanding.

## [2026-10-28] — Viktor composable record tools, architecture foundation

- Added owner-scoped `read_day_records` and `create_completed_records` primitives. AI can inspect actual Timeline entries and propose 1–12 explicit UTC completed-record intervals, without a hardcoded "between X and Y" command.
- Multi-read observations combine owned Records with other read tools before a separate confirmed write. Brain checks profile day, interval validity, collisions and duplicates, and preserves the existing durable Record outbox.
- Added strict contract/provider/regression tests and the Android release gate. The older specialized backfill remains as compatibility until real-account testing proves generic coverage. Other LIFE OS domains have not yet been generalized.

## [2026-10-28] — Viktor past Records vs Plans refusal fix

- Fixed date-only `create_plan` rejecting an irrelevant timezone field; the authenticated action validator now safely discards timezone when no clock is supplied.
- Added `create_completed_records_between`: Timeline record backfill between actual existing record anchors, safe chronological draft, overlap check, explicit confirmation, and durable Brain writes.
- Added deterministic follow-up routing for the reported 'Между просыпанием и Atozed Clients ... Добавь эти записи тоже' case, avoiding model's previous mistaken Plan creation. YandexGPT also receives the scoped completed-record tool and instruction to distinguish past Records from future Plans.
- Added action-contract, intent, interval, and regression tests; physical account acceptance still requires authenticated user data and confirmation.

## [2026-10-26] — PocketBase instant cross-device reconciliation hardening

- Preserved realtime plan/record create, update and delete events that arrive during an older full-list REST refresh. The full snapshot replays those newer deltas, so a late HTTP response cannot visibly revert a newer SSE change.
- Serialized PocketBase reconnect catch-up; if reconnect happens while the foreground refresh is running, a second authoritative pull now follows the in-flight refresh, and new gaps during reconciliation get another bounded retry.
- Retained push-first SSE and existing optimistic local writes. No periodic polling, schema changes or new manual sync button.
- Added regression contract tests; real-device latency still depends on connectivity and is not guaranteed to be zero.

## [2026-10-26] — Viktor bounded voice recognition

- Changed Yandex SpeechKit operation polling from 40 requests with individual 20-second timeouts to an elapsed-time budget of 45 seconds including upload, server processing and retries. Fast initial polling now checks every 600 ms and backs off to 1100 ms.
- The chat composer shows upload and elapsed recognition progress; a slow SpeechKit operation now ends with a bounded error instead of an indefinite spinner.
- Added deterministic polling-budget regressions. Live SpeechKit latency and physical-device voice quality still require an authenticated production check.

## [2026-10-24] — Viktor independent date-only creation

- Fixed a standalone 'add plan' request after an old itinerary being misrouted into draft revision and repeated time-zone checks.
- Relative days are resolved from profile today, never the selected tab or a previous draft. October 24 plus two weeks means November 7.
- Date-only plan actions omit start and duration; a simple independent request bypasses YandexGPT and uses typed Brain-backed validation, duplicate checks and receipts.
- Provider context now includes a live clock and actual user/assistant dialogue roles, retaining separate app state.
- Added regression tests for these cases. Flutter and Android CI are required before production acceptance.

## [2026-10-24] — Viktor user-context timezone rules

- Replaced city-specific conversational matching with explicit IANA timezone handling and contextual Russian phrases, including Perm `Asia/Yekaterinburg`. No universal Moscow override.
- Kept profile timezone as daily default and passed OS timezone as a separate, non-geolocating hint rather than substituting it for the user's home location. Named event location and explicit dialogue zone are distinct from account defaults.
- Updated server prompt to forbid IP-derived residence and invented geographic timezones; validated server responses for user profile Perm despite device Moscow.
- Added Flutter and PocketBase regression tests for explicit Perm/Moscow, non-timezone mentions of cities, and non-persistence of dialogue zone changes.

## [2026-10-23] — Viktor saved-plan clocks in requested timezone

- Projected saved UTC plan instants into the dialogue's explicitly chosen IANA timezone, collecting neighboring profile days to avoid losing events near midnight. Model context distinguishes the projected plan clock from the persistent profile clock; unknown-source instants are flagged as uncertain.
- Verified 13:00 New York = 20:00 Moscow on October 24, 2026, and overnight day rollover without changing saved plans.

## [2026-10-23] — Viktor complete itinerary, sticky timezone and read loop

- Raised provider reply limit from 1000 to 8000 characters and preserved up to 6000 characters of detailed previous assistant drafts and up to 3000 of substantive user briefs; pinned the original weekend request, latest timed draft and explicit timezone selection through repeated failed turns.
- Carried forward the last explicitly chosen user timezone (e.g. Moscow) even when the profile is New York. Rejected responses that attach a conflicting timezone label to timed rows.
- Resolved the explicit itinerary date independent of the open calendar tab so the correct saved-day plans are fetched; follow-up draft edits inherit the original day, not the next-day sleep date.
- Draft critiques and edits skip unnecessary read-tool loops and require a full read-only revised timetable, with one bounded model correction and no unintended writes.
- Added regression tests for Moscow versus New York, long plans, original errands, follow-up critique, date scopes and server reply lengths.

## [2026-10-23] — Viktor send visibility, inline errors, safe draft revisions

- Increased send disc to 42px within a 48px hit target, maintaining equal 10px optical gaps from the capsule top, right and bottom.
- Moved retry action from a floating composer banner into the failed assistant message; replaced raw internal action errors with clearer explanations.
- Corrections to unconfirmed schedules, including a later wake-up time, now request a complete read-only replacement draft and reject accidental mutation actions and status-only answers before any writes.
- Added layout and draft intent regression tests.

## [2026-10-23] — Viktor send circle optical inset

- Corrected oversized Send control: previous filled circular wrapper painted the entire canonical icon button's padded touch surface and nearly met the top/right/bottom capsule edges.
- Replaced the nested filled action wrapper with a 34px circular surface inside a separate 44px tappable/accessible InkWell. Matched capsule padding and optical spacing: 15px painted margins on three sides at idle.
- Added widget regressions for exact circle and tap dimensions, vertical centering and optical margins across desktop/mobile widths. No AI or persistence changes.

## [2026-10-23] — Viktor dialogue completion and composer geometry

- Fixed repetitive timezone-correction conversations: an explicit Moscow correction of a past uncommitted timetable restores the full assistant draft and corrects its erroneous New York zone label without converting intended wall-clock hours or saving any plans.
- Provider status-only replies such as "Сейчас проверю" are never displayed as finished itineraries: bounded repair or an explicit failure instead of a conversation loop. Relevant past detailed drafts remain within bounded conversation context after repeated incomplete turns.
- Standardized a shared 840px message/composer grid with 16px matching column insets, a symmetric inner control row and 14px visible right inset for the Send circle.
- Added unit and widget regression tests; no PocketBase schema, permission or automatic plan write changes.

## [2026-10-23] — Viktor composer contrast and alignment

- Aligned the chat input with the full 760px conversation column instead of the previous 660px limit, with matched message gutters.
- Added elevated contrast, a visible soft shadow, and a subtle outline while keeping the TextField transparent (no rectangular inset).
- Vertically centered text and microphone/send controls in the idle row. Added a high-contrast circular send action (including a visible neutral disabled state) using the canonical app icon button.
- Extended tests for width, vertical baseline, shadow and circular action. No changes to AI action execution, voice, persistence or timezone behavior.

## [2026-10-23] — Viktor chat inset and scrollbar visual parity

- Removed white rectangular background inherited by the composer TextField from the app-wide InputDecorationTheme; the rounded chat capsule is now the only painted input surface.
- Moved message scrolling to a full-window viewport, keeping conversation messages centered at 760px and the thin, auto-hidden 3px scrollbar at the far right edge of the window. Disabled duplicate Viktor-local automatic desktop scrollbars while preserving standard wheel/touchpad/touch scrolling. Added Windows-theme and full-width viewport regression tests with a deliberately white global input background.
- No changes to PocketBase, assistant reasoning, voice recording or plan actions.

## [2026-10-23] — Viktor compact ChatGPT-style composer

- Refined `lib/features/viktor/viktor_composer.dart` after direct screenshot comparison: replaced the always-two-row, wide input with a centered compact inline editor + mic + send surface, width capped at 660 logical px. Multiline content still grows and scrolls without changing Viktor's voice or command processing.
- Strengthened `test/viktor_chat_layout_test.dart` with compactness, inline alignment and responsive width regression tests for phone/desktop plus long pasted messages. No changes to PocketBase, AI logic, or plan writes.

## [2026-10-23] — Viktor natural-language timezone and itinerary follow-ups

- Removed example-city bias from AI prompts; a user-named timezone takes precedence over the profile setting and local event times stay wall-clock unless a real conversion is requested.
- Correcting an earlier itinerary uses the full earlier draft from conversation history, preserves fixed events, and puts after-midnight events on the following calendar day.
- If an AI provider repeats an already-completed read instead of answering, Viktor makes one bounded model correction using the observations and existing dialogue. Any write proposed during this recovery requires explicit approval.
- Added provider-contract regressions for timezone override and existing-conversation continuity. No PocketBase schema changes.

## [2026-10-23] — Viktor history persistence and replay regression

- Fixed chat history becoming inaccessible when web encrypted local storage is unavailable or full: previously protected outbox writes blocked even healthy PocketBase remote writes. Now remote persistence is attempted in that case, while unsynced in-memory turns show an explicit durability warning.
- Fixed history reload deadlock: when the local pending queue is empty but initial history fetch failed, Viktor retries reading the actual server history, not just resending pending rows. The reconciliation retains on-screen unsent turns without duplicating matching history.
- Fixed "Повторить последнюю команду" being sent to the model as literal user intent. Retry resolves the last actual earlier user instruction, or clearly reports that the previous instruction cannot be recovered; no action is run from a missing instruction.
- Added store/UI contract and Flutter regression tests. No PocketBase migration or destructive changes.

## [2026-10-23] — Viktor Saturday itinerary and dialogue retry safety

- Prevent planning an entire Saturday from failing with an internal mixed-schedule/timer error: YandexGPT and other providers now present multi-activity itineraries as conversational drafts with no writes.
- Even if a model returns multiple `create_plan` actions or improperly mixes a plan with a record timer, show a dated, chronological read-only draft with overlap warnings; never perform partial database writes or start/stop records.
- Pending conversation turns automatically retry owner-scoped encrypted PocketBase synchronization every 20 seconds while Viktor is open, without duplicate concurrent flushes, and cancel retries on exit or success.
- Failed dictated requests can be resent from the conversation without repeating the recording; stale 'executing' voice status is cleared when requests finish.
- Bulk creation of several new plans in one transaction remains outside this fix; drafts cannot be mistaken for saved plans.

## [2026-10-23] — PocketBase migration outage repair and deployment safeguards

- Fixed `1792710000_viktor_turns.js`: explicitly declare `created` as an auto-date field before SQL indexes use it; matches the emergency on-server repair that restored LIFE OS.
- Strengthened `viktor_turns_migration_test.cjs`: verify every indexed column exists, including a negative reproduction of the missing-`created` failure.
- Added an isolated SQLite snapshot + `pocketbase migrate up` preflight **before** any production deployment write or service restart; fail closed on migration errors or insufficient disk space.
- Added scheduled HTTPS PocketBase health checks with deduplicated GitHub incident issues and automatic closure after recovery. Preserve the scheduled workflow in the default `gh-pages` branch.
- Verified GitHub Pages excludes `.github` during artifact sync; installed the watch directly on `gh-pages` and added an explicit default-branch Git sync step to keep its schedule updated.
- No Flutter, Android, PocketBase schema data or personal records edited by this patch.

## [2026-10-23] — Viktor V2 release integration (candidate; not deployed)

- Integrated the current `main` Notes folder fixes without discarding Viktor's model/dialogue changes.
- Restored generated source-document parity for the newly added encrypted conversation outbox contract test.
- Release candidate requires completed GitHub CI and real-account functional validation before a production merge.

## [2026-10-23] — Viktor dialogue retry after transient sync failure (PR #337; not released)

- Keep unsent chat turns in an owner-scoped encrypted local outbox, restore them after reopening the app and retry them in order; avoid disabling all subsequent writes after a transient failure.
- Use stable owner-scoped `client_turn_id` values and read-back verification after ambiguous server/network errors to avoid duplicate history entries.
- Show pending sync status separately from the AI dialogue so technical alerts never pollute model conversation history. Limit long turn content to the PocketBase field size. Offer an explicit «Повторить» sync control without inserting a new chat turn. Full restart/device tests, and end-to-end release acceptance remain outstanding.
- Four JS contract suites passed in a V8 harness, including the new encrypted outbox source invariant checks; CI now invokes them. Flutter compilation and web/Android release builds were not run, and the PR remains unmerged.

## [2026-10-22] — Viktor guarded schedule commit correctness (PR #337; not released)

- Reject duplicate PocketBase plan IDs before atomic schedule commit; `Set.add()` does not return a success boolean, so the old duplicate guard was ineffective.
- Require exact millisecond `updated` revision match on commit, rejecting another device's edit even within one second of preview approval; preserve existing timestamp comparison tolerance for schedule fields.
- Expand `viktor_atomic_schedule_hook_test.cjs` with duplicate-ID, malformed-ID and subsecond stale-approval rollback regressions; JavaScript handler test passed locally, but GitHub CI and authenticated production tests remain blocked/pending.

## [2026-10-22] — Viktor V2 agent groundwork (PR #337 — unmerged, NOT released)

- Add owner-scoped, append-only `viktor_turns` for cross-session/cross-device conversation history. Client restores recent messages and persists turns without overwriting a second device's changes; provider receives at most 12 recent bounded turns, not credentials.
- Add `search_notes`, `read_note`, `search_record_notes` and `read_record_note` so Viktor can locate dated historic texts in Notes **and** Records and quote exact numbered lines after reading a source.
- Add `edit_note_line` with exact old-text checks, rich formatting/media preservation and normal Brain preview, freshness and consent. Editing text inside historic Record notes is not yet available.
- Guard exact-line questions against prematurely stopping on search snippets, test owner isolation/schema and multi-turn context, document acceptance gates in `docs/VIKTOR_AGENT_V2.md`.
- Bulk moves now use an owner-scoped all-or-none PocketBase transaction with server-side stale-row and collision guards, category/tag/title/keep selectors and priority ordering. Client independently rechecks saved times.
- **NOT finished:** semantic memory beyond the chat history, durable weekend draft alternatives with new event creation, and authenticated real-account multi-day acceptance tests. No production release or full-readiness claim.

## [2026-10-23] — Categories manager UX (PR #341; validation in progress)

- Replace Categories tile bands with a responsive tree manager: desktop side-by-side inspector, mobile compact list and bounded edit surface.
- Reuse the canonical 300 ms AppHoldToReorderListener/AppReorderableList without drag buttons; sibling reorder and cross-parent placement through existing category Brain paths, with Undo.
- Compact the editor with primary fields, color/icon selection and sticky Save. Keep translation, keywords, default and delete options in Advanced.
- Prevent cyclic parent changes before optimistic or PocketBase mutation. No collection schema changes.

## [2026-10-22] — Viktor bulk move clock/read contract (pending production verification)

- Accept explicitly stated clock variations (9, 9.00, 9 утра, 09:00 NY, 9 часов по Нью-Йорку) in a bulk move, normalize to HH:mm and refuse ambiguous times.
- Strip redundant `list_day_plans` observations from a single `bulk_replan` proposal, even if the read inspected another date; never discard unrelated write actions.
- Preserve fresh Brain preview, conflict detection and confirmation before any schedule mutation. Real-account move has not yet been verified.

## [2026-10-22] — Viktor bulk clock and redundant read repair (pending deployment)

- Fix status-filtered `bulk_replan` proposals rejected for unambiguous `start_time` spellings such as `9:00`, `9 утра`, `09:00:00`, or `09:00 NY`. Normalize to strict `HH:mm` and an explicit New York timezone where present; reject ambiguous, missing, conflicting or invalid times.
- When the model accidentally emits `list_day_plans` for only the source/target days together with exactly one `bulk_replan`, normalize to the protected single bulk action. Do not silently drop unrelated reads or additional writes.
- Strengthen Yandex instructions to emit a single bulk action with canonical clock/timezone fields. Preserve Brain fresh-state loading, conflict rejection and explicit approval before writes.
- Add contract tests for exact 21-to-22 October user scenario, negative cases and serialization. No live user's plans have been changed or tested.
- A trailing explicit `отмена` / `cancel` (including repeated dictation) cancels the entire pending command locally, before any model or write action.

## [2026-10-22] — Viktor read-to-write bulk handoff (pending production verification)

- Fix provider `continue:true` with a valid mutation: the app no longer rejects it as an invalid read-only observation. Final `bulk_replan` proceeds to Brain's independent two-day preview and confirmation.
- Yandex compact and general AI instructions explicitly restrict `continue:true` to reads. Bulk status-based replanning uses fresh Brain state without unnecessary read tool loops.
- Do not silently return a list as if a requested edit succeeded when the model repeats a read without proposing changes.
- When the model sends `continue:true` with no tools, request one bounded schema correction; never treat it as a read result or silently execute a write.
- Added read/write transition unit regression and PocketBase instruction checks. Live account preview, user consent and actual schedule result are still not verified.

## [2026-10-22] — Viktor bulk status and SpeechKit backend diagnostics (proposed, not deployed)

- Normalize explicit `bulk_replan` completion status synonyms from AI output to the canonical `complete`/`incomplete`/`all` contract, while rejecting ambiguous statuses and preserving Brain-controlled, consent-gated edits.
- Fix generic PocketBase/HTTP speech error diagnostics: retain real HTTP status and submit/poll stage without disclosing server response content or credentials.
- Confirmed live failure: both Yandex PocketBase routes answered anonymous requests with HTTP 400 `{data,message,status}` instead of the hook's expected HTTP 401, while the non-Yandex transcription route correctly returned 401.
- Root cause: PocketBase route callbacks run in isolated JavaScript contexts; top-level `viktorYandexSpeechAuth`/`viktorYandexSpeechFrames` were invisible inside callbacks. Extracted pure helpers to CommonJS and `require` them inside each route callback.
- The Yandex hook test now rehydrates each route in its own clean VM; production post-deploy smoke verifies both routes return HTTP 401 unauthenticated. Prior pre-deploy PR smoke exposed the defect but cannot be an acceptance gate before deployment.
- Root-cause acceptance requires BOTH isolated-handler tests and authenticated on-account microphone transcription. HTTP 401 endpoint smoke alone does not establish functioning Yandex STT.
- This patch does not claim a live authenticated SpeechKit transcription or user-schedule success. Await CI and on-account verification.

## [2026-10-22] — P0: fast warm reload and recoverable web startup

- Made the external Google API script asynchronous; a slow or unreachable `apis.google.com` can no longer stop HTML parsing and Flutter bootstrap.
- Enabled `--no-web-resources-cdn` and **explicitly override the generated Flutter loader** to use `canvasKitBaseUrl:"canvaskit/"`. Inspection of the previous deployed bootstrap showed that merely bundling CanvasKit did not stop fallback to `gstatic.com`. CI now checks the deployed bootstrap itself and the local CanvasKit JavaScript/WASM assets.
- Removed redundant pre-`runApp` browser PocketBase initialization and secure session restore, and skipped repeated web secure-storage writes during valid cached-session checks. Kept native initialization unchanged.
- When device settings are absent, hydrate from the locally persisted, valid signed-in PocketBase profile record before background server reconciliation; first-time logins without trusted local profile data still require server settings.
- Added an 8-second recoverable Flutter startup screen and a 12-second HTML entrypoint failure state with retry; neither signs the user out or purges local data.
- Added CI startup contract guards so these specific blocking startup patterns cannot silently re-enter the release.
- Synchronized release and PocketBase prerequisite workflow definitions onto GitHub's actual default branch (`gh-pages`), not merely `main`; previous deploys loaded the stale default-branch workflow and overwrote the local CanvasKit configuration. This commit retriggers the corrected release pipeline.
- Source and deployment validation is required; live warm/cold-start timing on the user's actual connection remains unmeasured.

## [2026-10-21] — Viktor repeated read-loop and SpeechKit response repair (pending CI)

- Read-only plan queries now return their first Brain-validated observation; repeated tool calls reuse observations rather than surfacing `Виктор повторно запросил те же данные`.
- Exact-title matches are highlighted from the returned plan list for "show my plan..." queries without any hard-coded AGE Solutions business logic.
- SpeechKit REST v3 parser handles adjacent JSON response frames without newline delimiters, as documented by Yandex; unit coverage includes refined/final text without duplication.
- Improve missing-error-code SpeechKit diagnostics, while avoiding disclosure of raw response content.
- Live user's SpeechKit and production read-query validation still pending; simulated CI tests alone cannot establish end-to-end success.

## [2026-10-21] — Viktor duplicate-safe plan entry, NY timezone and voice correction (pending CI)

- Check existing same-day plan titles before announcing collisions or creating a duplicate. Present exact conflicting intervals for genuinely new meetings; never silently override existing tasks.
- Interpret `create_plan.timezone` with DST-aware shared timezone catalog, including NY/New York, and translate to the profile-wall calendar.
- Fix Yandex SpeechKit v3 `finalRefinement.normalizedText` recognition parsing, deduplicate refined/final chunks, and allow mixed Russian/English command speech.
- Replace anonymous voice failure with capture-stage or recognition-stage diagnostics. Added regression tests for AGE Solutions/FALCON duplicate, NY conversion, mixed voice output and error handling.
- Remote authenticated E2E with this user's specific plans and microphone still required before claiming verified production behavior.

## [2026-10-21] — Viktor plan category and creation receipt parity (pending CI)

- Agent-created plans now use the existing `identifyCategory(title)` keyword/subcategory resolver from ordinary Planning quick-add. It rejects archived/invalid matches and falls back to an active configured category rather than always using the default.
- Plan preview shows the chosen category, exact date and duration from validated tool arguments. Model prose no longer claims writes or durations before Brain execution.
- Added `addPlanningTaskWithReceipt` to distinguish remote-acknowledged writes from locally accepted pending synchronization; Viktor displays an explicit queued/synced result rather than treating them equally.
- Dedicated category keyword and fallback regressions added to release tests. Actual user's RCC category data and PocketBase live BYOK end-to-end remain to be verified.

## [2026-10-21] — Viktor Yandex refusal diagnostics and prompt reduction (pending CI)

- Split Yandex upstream `content_filter` from explicit model `refusal`, with precise Russian-language diagnostics. Neither is silently retried or circumvented.
- Reduce the model-facing Yandex system prompt to a concise universal catalog of the same allowed LIFE OS tools; keep all actual authorization and data validation in Brain.
- Add JS regression cases for distinct refusal markers, valid null refusal and compact agent instructions. A real authenticated provider response is still required to determine whether Yandex actually filters the reported benign event request.

## [2026-10-21] — Restore original Time View drag with isolated cursor lock

- Restored the exact pre-regression Time View pointer handler, collision/drop resolver, scroll ticker, and positioned-card animation. All unrelated interaction rules retain their original behavior.
- Corrected edge-scroll cursor drift by rendering only the lifted card with an additional unconsumed scroll-offset transform. No global day/cascade recomputation occurs on stationary cursor scroll; drop resolves against the latest scroll offset on release.
- Kept the requested compact time indicator and semi-transparent (74%) card. No extra aesthetic changes.
- Cursor lock tests cover stationary scroll, reverse scroll, and the visual correction between pointer events. Runtime browser verification is pending.

## [2026-10-21] — Viktor malformed Yandex response recovery (pending CI)

- Classify upstream model response failures and retry a malformed YandexGPT proposal once with supported `json_object` mode instead of failing immediately with `invalid_model_response`.
- Support common structured text content variants while refusing truncated output, missing actions, and safety refusals; never infer tool actions from ordinary prose.
- Show bounded, private, Russian-language error reasons. Added Node regression cases for truncated/invalid/refused and safely recovered model output; no user-data writes.
- Requires CI, production PocketBase->Flutter Web deployment and authenticated YandexGPT test before claiming full end-to-end success.

## [2026-10-21] — Tactile drag restoration and cache-first warm reload

- **Superseded:** Earlier drag-controller alteration caused regressions and has been reverted. Original gesture recognizer, animation, collision resolver and positioning are restored.
- Drag card opacity reverted to the requested 74%; compact time chip remains.
- Removed unconditional browser cache deletion and service worker unregistration on each reload. Flutter assets remain revisioned by release SHA.
- Warm startup initializes PocketBase without a blocking health probe, uses the local cached session, hydrates the category tree from scoped local storage, and starts server auth/catalog refresh in the background.
- Regression coverage retains pointer/scroll geometry and the scroll-only lifted-card compensation.

## [2026-10-21] — Viktor typed tool contract repair (pending CI)

- Exposed actionable schema errors: action index, tool name, rejected field names, and allowed names, without exposing parameter values. The existing one-turn model retry can now correct the actual validation error instead of repeating a generic `Unexpected Viktor action field`.
- Enabled YandexGPT `response_format=json_schema` for a constrained proposal/action envelope. Server-side tool name allowlist intersects the client's advertised capabilities; the local Brain-backed typed contract remains the only authority for execution.
- Added generic `create_plan` example for ordinary dated events, and Node/Dart regression tests verifying schema, safety and repair context. No user data changed by development; live BYOK account test remains a release gate.

## [2026-10-21] — Time View cursor anchor and compact time feedback

- **Superseded:** The heavy per-scroll-frame drag resolver has been removed. Original drag and drop solver is preserved; only the lifted visual compensates for viewport scroll between pointer events.
- Drag card remains at 74% opacity; the full-width dark time stripe stays replaced by a compact neutral time chip with a 16px label.
- Added scroll-offset/pointer anchoring regressions in `test/plan_time_drag_gesture_contract_test.dart`. Web deployment and real-device drag interactions remain verification gates.

## [2026-10-21] — Viktor same-day priority insertion (pending CI)

- Added `create_plan.conflict_policy = shift|reject`: reusable deterministic planner inserts priority blocks and cascades flexible saved plans preserving each duration/order; blocks completed/fixed/recurring/virtual/unsynced tasks and day overflow.
- Consequential priority insertion requires consent, same-day fingerprint revalidation and canonical Brain bulk updates followed by plan creation. Creation failure attempts rollback of shifted plans; non-atomic errors are surfaced.
- Updated provider prompt to distinguish creating a priority plan from `bulk_replan` and propose a clearly disclosed default duration when unspecified. Gateway retries one rejected typed model proposal with validation feedback before failing closed.
- Added dedicated regression tests and Android CI gate. No user plans were changed by development; authenticated provider E2E required before claiming complete coverage.

## [2026-10-21] — P0 Planning quick-add: first-frame local feedback

- Planning quick-add now places the scheduled task in `_optimisticTasks` and clears the text field synchronously. The PocketBase create starts in a post-frame callback, so a slow server cannot delay first paint or block the next entry.
- Planning stream now subscribes before its first cache emit (previously lost on a broadcast hub) and offers an immediate-local refresh bypass for new plans while keeping network/alarm/disk effects debounced.
- Optimistic tasks are reconciled by client plan ID instead of title/date, so identical new task titles cannot hide pending cards.
- Added a regression test for a cache-first Planning stream. Cross-platform build and live timing verification remain release gates.

## [2026-10-21] — Viktor cross-day agent scheduling (pending CI)

- Removed the UI-selected-day restriction for schedule actions. Added reusable `ViktorDateScope` to resolve explicit plan/tool dates, multi-day bulk source/target, and date validation.
- `bulk_replan` now loads real user-owned plans for the specified source/target dates regardless of the open screen; `list_day_plans` fetches requested day; create and position/swap previews use their intent date.
- Profile-timezone today/yesterday/tomorrow supplied to model separately from selected calendar day. Updated model-neutral tool prompt; added cross-day regression with status filtering and 09:00 New York placement.
- Source/target collisions, immutable recurrence and fixed time safeguards, freshness preview and approval remain enforced. Requires live credential-backed verification; not complete UI action parity.

## [2026-10-21] — Bulk Planning date/time editing: unified picker and schedule-diff guard

- Replaced separate date/time controls in `bulk_planning_edit_sheet.dart` with a unified **Start of sequence** Omni-Picker and an explicit date-only mode. Choosing a date and 20:00 now retains both values.
- Updated `planning_bulk_edit_actions.dart` to compare final task wall schedules instead of treating "same day" as "no changes"; unchanged plans are not PATCHed. Preserves ordered, gap-free starts and task durations.
- Corrected RU/EN sheet labels, explanatory hints, and canonical `AppButton` action. Added regression tests in `test/plan_time_bulk_drag_test.dart`.
- Web release and live account verification are required before declaring a production fix.

## [2026-10-21] — Viktor list tools and bounded agent observations (PR; pending CI)

- Added owner-scoped backlog item discovery, complete/reopen and rename tools, routed through existing Brain `fetchBacklogPlans` and `updatePlanningTask`; checks old title/status and rejects Notes, scheduled items and recurrence.
- Viktor can make up to four distinct read-only observation passes with stable request ID and labeled results; repeated identical requests or a mixed read/write observation fail closed. The provider remains replaceable.
- Single reversible actions skip redundant confirmation while retaining fresh preview validation. Consequential edits and multi-action batches still require explicit approval.
- Updated agent contract tests, prompts and UX contract. Not full interface parity; Flutter/Android/Web CI and credential-backed E2E remain release gates.

## [2026-10-21] — Viktor general application-agent foundation (in validation)

- Added a model-neutral capability catalog and validated tool proposals for Notes, Paths, Categories, Tags, safe Profile settings and existing plan/record operations.
- Brain-owned domain executor provides authenticated reads, note text creation/editing, category/tag CRUD, creation of versioned Paths and allowlisted settings changes. Mutation proposals require an explicit dry-run preview; multi-domain requests warn that cross-service writes are not atomic.
- Yandex/OpenAI/Gemini/Groq/GigaChat proposals now receive safe user-scoped category/tag/note/Path metadata when relevant. Prompts list supported tools and prohibit code/database access or imaginary execution.
- Added contract tests for cross-domain input, multiline Notes, Paths staging, scope and forbidden settings. Full parity with every LIFE OS UI action, autonomous iterative tool-calling and real-user E2E remain open; do not advertise as complete.

## 2026-10-21 — Viktor cloud save quota and dialog width [fix]

- Fix false red `QuotaExceededError` after successfully saving BYOK credentials to PocketBase: web uses authenticated cloud metadata as the source of truth and skips redundant SharedPreferences/localStorage writes; native optional preferences fail gracefully.
- Bound Viktor model-settings dialog to 560 logical pixels on desktop (responsive 16 px screen inset), and place errors in the scrollable body instead of the action bar to prevent full-screen horizontal expansion.
- Add deterministic test for cloud/browser preference-write policy. No browser cache/IndexedDB data is cleared.

## 2026-10-21 — Morning prompt browser persistence repair [fix]

- Use existing browser IndexedDB storage for the morning check-in switch instead of SharedPreferences/localStorage, whose browser quota/invalid cached settings can reject even small saves.
- Keep native device settings in SharedPreferences; migrate old browser OFF state best-effort. Do not block switching when old localStorage cannot be read.
- Add Chrome browser persistence regression covering OFF across reload, bad legacy values and ON/OFF transitions.

## 2026-10-21 — Morning toggle web save error hotfix [fix]

- Remove the extra SharedPreferences reload after setting the morning check-in switch. Await the real write and read the updated cache directly, avoiding a web-only error/false rollback.
- Make legacy preference migration ignore unrelated or malformed non-boolean keys; add a UI regression that switches the toggle OFF, unmounts Settings, and verifies it remains OFF when Settings remounts.

## 2026-10-21 — Morning check-in toggle survives web refresh [fix]

- Store the optional morning prompt toggle under a stable local key instead of a profile id captured during login hydration, and verify persistent readback before reporting success.
- Migrate existing disabled profile-scoped preferences (including the former local fallback). The setting remains device-local and independent from sleep records/synchronization.
- Render a loading indicator rather than briefly showing ON until persisted data has loaded; test reload, late profile hydration and migrations.

## 2026-10-20 — Viktor Russian model candidates + two-card voice swap [PR, not deployed]

- Add Sber GigaChat and YandexGPT AI Studio BYOK model adapters and an explicit account-scope/folder-ID UI; provider URLs and scope values are allowlisted.
- Add validated two-card swap proposal with chronological reflow, fixed/recurrence guards and tests.
- Ground voice instructions in selected planning cards or both spoken card titles. After STT, send recognized command automatically; allow simple unambiguous swap without a second modal.
- Keep existing independent STT providers for Giga/Yandex text models. True Yandex live Realtime voice remains follow-up. Require CI, live credential testing and release before claiming complete.

## 2026-10-20 — Viktor recorded speech fallback (staging branch)

- Replaced unreliable Yandex/Chrome Web Speech browser dictation with actual PCM16 WAV capture, visible mic level and timer and provider-funded server transcription.
- Transcript is displayed in the chat input for review, not automatically sent; errors are inline and informative.
- BYOK OpenAI/Groq/Gemini speech providers supported, separate voice key for OpenRouter. Added authenticated server-side speech hook and contract tests.
- Not shipped until live CI, PocketBase endpoint deployment and web publish are verified.

## 2026-10-20 — Prevent Time View cards covering one another [fix]

- Time View now assigns separate horizontal visual lanes within overlapping scheduled intervals (including fixed meetings) while preserving actual start/end times and hour alignment.
- Unrelated and merely adjacent cards remain full width; overlapping clusters reclaim full width when the conflict ends.
- Added regression cases for 14:00–15:00 webinar / 14:30–15:15 task, transitive 3-way overlaps and touching boundaries.

## 2026-10-20 — Prevent false fixed-time barrier on Time View drag [fix]

- Limit target-card insertion, empty-slot drops, and multi-plan cascades to the moved plans and their collision-connected chain.
- Preserve unrelated fixed meetings and pre-existing conflicts elsewhere on the day. Genuine fixed-time collisions still reject the move.
- Cover a 19:00–19:45 free-slot move, unrelated fixed overlap, and real fixed collision with regression tests.

## 2026-10-20 — Viktor BYOK beta integration (draft, not deployed)

- Unified in-app Viktor chat and dictation; removed separate floating microphone and Smart Plan voice sheets. Provider options OpenAI/Gemini/Groq/OpenRouter with session-only BYOK.
- Authenticated BYOK for Free and Pro, hosted disabled pending billing and metering.
- Strict action proposals, schedule preview, recurrence guards, overlapping new-plan check, stale-preview rejection, and Brain writes.
- Beta release checklist: `docs/VIKTOR_BETA_RELEASE_CHECKLIST.md`.

## 2026-10-19 — Optional Timeline morning check-in [feature]

- Added Settings → Preferences → Start of day (mobile Settings also) to disable or re-enable the automatic "Start the day" sleep check-in.
- The default remains enabled. The per-profile device preference survives restart; the gate skips suppressed prompts without modifying sleep imports, stored sleep records, or per-day completed check-ins.
- Added preference isolation/persistence tests; no PocketBase schema changes.

## 2026-10-19 — Restore real Notes folder paper, spacing and fixed tab positions [fix]

- Correct regression in Lists where merely selecting a pinned category removed/reinserted it at the front, wrote altered preference order and scrolled tabs to start. Selection now preserves position and scroll offset.
- Revived the approved early-October real folder-tab silhouette and its seamless content-paper connection without nested frames. Animated folder background (260ms) follows selected category in light/dark mode with 18px interior card separation.
- Added regression tests for stable selected-category tab ordering and animated folder paper inset.

## 2026-10-19 — Notes restored folder tabs and explicit category + [fix]

- Restored colored folder-edge tabs on mobile and desktop Notes, including category color as the tab paper and legible 16px labels.
- Kept + permanently visible beside the scrollable categories and added explicit choose-existing and create-new options using the shared category tree/creation flow.
- Pinned tab choices synchronize with Lists state immediately and persist as manual chips. Added action-sheet regression coverage.

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

## [2026-10-19] - Notes physical folder tabs and usable category scrolling [in review]\n\n* **Notes:** Curved diagonal folder spines with overlap (reference: physical colored index folders); active category paper matches the tab with a 260ms animated change.\n* **Folder navigation:** `All` pinned left, `+` pinned right, categories horizontally scroll between; mouse wheel, mouse drag and touch supported. Selecting a category no longer reorders tabs.\n* **Regression:** Widget tests for folder silhouette, fixed controls and scroll, while preserving the 18px interior card gap.\n\n

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
