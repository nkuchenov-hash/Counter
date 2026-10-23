# UX Contract

This document defines how Life OS behaves when people interact with it. It is the behavioral source of truth that sits beside `ARCHITECTURE.md`; app code and feature screens must follow it before adding new UI patterns.

## P0 web startup must never block on external services (2026-10-22)

- Flutter must render its initial frame without awaiting Google OAuth scripts, a PocketBase health probe, an auth-refresh round trip, or unnecessary secure-storage writes.
- The web build must bundle CanvasKit and validate its local JavaScript/WASM files. Runtime rendering must not require access to `www.gstatic.com` or other Google CDNs.
- A valid user-scoped cached profile and category/planning snapshots open first, while server verification, realtime bridges and synchronization run after the shell; a revoked session must still close on confirmed server rejection.
- A stalled Dart profile/data restore must show a recoverable, data-preserving screen within 8 seconds rather than an indefinite spinner. If the Flutter entrypoint fails to mount within 12 seconds, HTML presents retry and removes that panel when Flutter becomes available.
- Browser cache data is never cleared automatically on reload. Build assets remain revisioned; test ordinary reload, restricted Google networks, offline cached startup and delayed PocketBase independently.
- The deployment pipeline rejects synchronous Google API scripts, pre-frame network/auth checks on web, CDN-only CanvasKit, and removal of recovery affordances. An inaccessible hosting origin itself still requires hosting/network mitigation.

## Viktor status-filtered bulk proposal robustness (2026-10-22)

- A single bulk schedule mutation owns the fresh source and target-day reads; any attached `list_day_plans` proposal actions are redundant and are removed before preview, even if the model examined another day. Other mutation actions must remain intact and must never be applied as part of the bulk operation.
- Only explicit, unambiguous clock notations may be normalized to HH:mm (including morning phrasing and optional New York annotation); unsafe or ambiguous times must remain rejected. Do not guess a time from unrelated context.
- All bulk changes require preview, user consent, fresh-state revalidation and conflict/protected-plan safeguards.

## Viktor bulk clock and read-only observation normalization (2026-10-22)

- Speech/model clocks for `bulk_replan` may be canonically normalized only when unambiguous, e.g. `9:00` to `09:00`, `9 утра` to `09:00`, or `09:00 NY` into `09:00` + `America/New_York`. Missing, conflicting, nonsensical times are errors; never infer absent clocks.
- A validated batch with exactly one `bulk_replan` plus `list_day_plans` reads restricted to the operation's source/target dates is semantically one bulk operation because the Brain reloads those dates itself. Do not drop unrelated reads or a second mutation. Multi-operation `bulk_replan.operations` inside ONE action remains supported and consent-gated.
- Recompute and verify target-day collisions and protected category rules; show the full preview; require explicit confirmation before saving. A model's narrative never authorizes a write.
- A dictated explicit cancellation at the end of a request overrides preceding move instructions; report no changes and do not call the model.

## Viktor read-to-write handoff (2026-10-22)

- Treat a model's `continue:true` as an instruction for **read-only observations only**. If a validated mutation is already proposed, skip the read loop and proceed through the ordinary Brain fresh-state preview, explicit bulk confirmation and conflict checks. Never execute a mutation as a read operation or silently drop a write because the model set `continue:true`.
- `bulk_replan` uses Brain-owned fresh source/destination data; do not require `list_day_plans` before a status-filtered bulk mutation. Keep source/target day, completion status, requested IANA timezone and existing task durations grounded in the user's intent.
- A duplicate read is an acceptable final response to a genuine read-only query; for a mutation request, say that no change was proposed or applied rather than presenting a read result as a successful edit.
- `continue:true` with zero actions permits one bounded proposal repair, not a new user-facing failure or unlimited AI retry.
- Regression coverage must exercise both `continue:true` + list/read (continue) and `continue:true` + validated mutation (final preview), including a status-filtered previous-day-to-today move. Actual user data is never mutated by a smoke test.

## Viktor bulk status and SpeechKit route diagnostics (2026-10-22)

- Model-emitted completion synonyms may normalize to exactly `complete`, `incomplete`, or `all` only when unequivocal. Ambiguous status remains a validation error; Brain previews the affected owned rows and retains confirmation and no-duplicate/no-conflict guards.
- Voice transport must report its real HTTP status and whether submit or poll failed when a proxy or PocketBase returns JSON without `error`. Do not confuse generic server failures with SpeechKit provider decisions or expose upstream body, transcript or keys.
- Production server deploy must smoke-test both unauthenticated Yandex start and poll endpoints for HTTP 401; no synthetic hook tests or server startup smoke alone prove authenticated audio works.
- PocketBase JS route callbacks run in isolated contexts. Any shared Yandex SpeechKit auth/stream-frame helper must load through `require(`\${__hooks}/...`)` **inside** its callback. Tests must execute route functions in separate VM contexts rather than sharing script-global declarations.

## Viktor read observations and streaming speech response (2026-10-21)

- Read-only queries (e.g. "Покажи мой план AGE Solutions – ADD SIN на пятницу") must return the Brain-verified first list-day result directly, with an exact-title match when available. A repeated model request for the same tool and parameters is not a user-facing error: reuse the previously validated observation instead of throwing or repeatedly invoking the model.
- Requests that also mutate state must continue the normal bounded read / proposal / fresh-preview / apply workflow. Never skip conflict checks for writes.
- SpeechKit REST v3 `GetRecognition` produces **adjacent JSON frames even when no newline separates them**. Decode bounded complete JSON frames, preserving quoted strings and nested objects. Prefer `finalRefinement` when present and deduplicate by final index; reject malformed frames safely without exposing raw model/provider speech, keys or audio.
- Distinguish provider errors without structured error codes from microphone/capture errors. No claims about the user's actual microphone or cloud account are warranted until real authenticated validation.

## Viktor plan idempotency, timezone and SpeechKit v3 voice (2026-10-21)

- Prior to evaluating any ordinary or priority `create_plan` collision, look up plans on the intended **profile-wall** calendar day. If a saved or pending same-day plan has the same normalized meaningful title, report that it already exists; never create a duplicate or reject it because a different plan occupies the requested slot. Check again before any write.
- Explicit user clock zones such as NY/New York use the canonical catalog `America/New_York` and DST-aware conversion to the profile-wall planner clock. Omitted zones use the profile timezone. Never treat a named NY time as the device or profile's local clock automatically.
- For genuinely new plans, retain strict interval collision checks. On conflict, include both requested profile-wall interval and existing plan's profile-wall interval, not only the conflicting title.
- SpeechKit REST v3 results can include `final.alternatives` and separate `finalRefinement.normalizedText.alternatives`. Use the refined text for a matching `finalIndex`, never duplicate the same utterance. Dictation supports mixed RU/EN titles independently of UI locale.
- Voice failure text distinguishes microphone/capture from recognition/server errors. No original provider exception text, audio or credentials should be exposed in UI or log.
- Regression tests must cover an already existing AGE Solutions call even when FALCON has an overlapping interval, NY 12:00 DST conversion, provider streaming refinements, and capture-vs-provider failure categories.

## Viktor category parity and plan-create receipt (2026-10-21)

- Viktor `create_plan` and priority insertion must use the **same title/keyword matcher** `DatabaseService.identifyCategory` that Planning's ordinary quick-add uses. Do not assign a default category first or introduce hard-coded RCC/product-specific mappings. Prefer the deepest active matched category; fall back to a validated configured category only when no valid match exists.
- The preview for agent plan creation must show the validated date, time, duration and resolved category; the model's freeform prose is not an authoritative saved-state assertion. For mutation replies, show actual tool preview and receipt, not an unverified model statement about duration or success.
- `addPlanningTask` returns true for a synchronously acknowledged PocketBase POST **or** a locally queued create. The agent must use the Brain's status-aware create receipt and explicitly distinguish `confirmed` from `pendingSync`. A queued plan must not be reported as remotely persisted. Tell the user not to repeat it, to avoid duplicates.

## Viktor provider refusal handling and compact agent tools (2026-10-21)

- Separate the Yandex `finish_reason: content_filter` upstream-content-filter signal from a nonempty `message.refusal` model refusal. Do not retry either refusal or bypass them with modified prompts. Return only a fixed reason code, never provider response text or confidential data.
- For Yandex, use a short, model-specific formulation of the **same** approved tool catalog, rather than the older lengthy and repetitive general-agent instructions. This changes prompting only; permitted operations, date semantics, model independence, Brain authorization, freshness and confirmation are unchanged.
- A refusal in a benign user scenario is a provider outcome unless an actual authenticated test demonstrates an application parsing error. The frontend should show which of the two independent refusal mechanisms occurred rather than misleadingly treating them as identical.

## Viktor provider response recovery (2026-10-21)

- Provider-success HTTP 200 does not guarantee a usable proposal. The PocketBase provider adapter classifies missing choices/messages, refusal, length-truncated completions, empty content, invalid JSON and invalid action-envelope shape without logging user context, model text or credentials.
- For YandexGPT only, a malformed proposed response (except refusal) triggers **at most one** retry using `response_format: json_object` rather than `json_schema`. Both requests are proposal-only; no Brain mutation occurs before validated client-side action execution. Keep the complete provider time budget below the Flutter HTTP timeout.
- Decode strict JSON, an optional whole-response Markdown code fence, a JSON-string-wrapped JSON object and provider text-content arrays. Never attempt fuzzy JSON extraction from arbitrary natural language; never turn a refusal or truncated output into a write.
- On failure, return a short allowlisted `reason` code, not model text or secrets; Flutter translates the reason into a useful Russian error. A failed proposal MUST NOT mutate user data.

## Viktor model/tool contract and validation repair (2026-10-21)

- Model prose is not an executable command. YandexGPT Chat Completions must request schema-governed JSON proposals with exactly `message`, `actions`, `continue` at the envelope, and each action has only `name` and `arguments`. Tool names are constrained by a server-side allowlist intersected with the client-advertised capabilities.
- Executable tool authority remains in the typed Flutter contract and authenticated Brain, **not** in a model schema, prompt, or client-advertised tool list. Each tool argument map is validated again before any preview or write. Provider implementations without structured JSON still rely on typed validation.
- On a rejected argument field the validator returns action index, tool name, offending **field name only**, and allowed names. Argument values (including note content and credentials) must never enter validation diagnostics. The model gets one bounded correction turn with this precise feedback; the corrected action is validated anew. Never silently remove unknown arguments or execute an unvalidated proposal.
- The model should resolve requested weekdays against profile-date context and propose a normal `create_plan` for new events. An omitted duration may use the explicitly disclosed default proposal, not an undisclosed mutation.

## Viktor conflict-aware plan creation (2026-10-21)

- A priority meeting that should displace other same-day plans uses the generic `create_plan` action with `conflict_policy: 'shift'`. The agent must never misuse `bulk_replan` (which moves existing items) to create new plans. `conflict_policy: 'reject'` remains the safe default.
- Brain-backed placement calculates a single deterministic proposed insertion and the resulting cascade, preserving existing flexible-plan durations and chronological order. It must refuse shifting completed, pinned, recurring, virtual or unsynced tasks and reject shifts that run beyond midnight. Other, non-overlapping plans remain unchanged.
- Because the shift may alter several saved plans, `create_plan + shift` always shows the exact requested meeting start/end and displaced plans for explicit confirmation. After approval, the executor reloads the day and compares its full schedule fingerprint before any mutation. The multi-row update is not atomic; partial failures must be disclosed and creation failures attempt compensating reversal.
- If the LLM proposes an invalid typed action, the model gateway may request **at most one** corrected proposal using the validation failure as feedback; the client must still validate the corrected proposal locally. A second invalid proposal fails safely.

## Viktor intent-based date scope (2026-10-21)

- The active Planning/Calendar tab day is contextual only; it MUST NOT block tools addressed to other days. Agent data reads and schedule mutations execute against the explicit tool date, with fresh data loaded for that date through the Brain.
- Relative **today/yesterday/tomorrow** are resolved from `DatabaseService.getProjectedToday()` using the signed-in profile timezone, not the device timezone or selected UI date. This profile-relative date context is sent to the provider independent of the displayed day.
- `list_day_plans` fetches its requested `wall_day`. `bulk_replan` obtains its source/target days from validated `operations`, reads each real day, previews affected rows, checks recurrences/fixed-time guards/collisions, and compares a fresh source+destination snapshot immediately before writing.
- For safety, one `bulk_replan` batch targets a single source day and at most one destination day. Multiple independent sources require separate approved operations; do not silently use the currently displayed day.
- An explicit time zone for a bulk move is converted through the existing profile wall-time projection. If the requested time is invalid or intersects a protected task, reject before writing.

## Viktor agent tool execution (2026-10-21)

- Viktor is an application agent, not an editor of source code. User voice or text is mapped to allowlisted tool proposals that call the exact same Brain/repository functions used by the UI. Model providers are interchangeable and cannot write arbitrary PocketBase rows or change code.
- Canonical supported agent domains must have an inventory/tool contract, owner-scoped read operations, typed validation, and a dry-run preview for consequential mutations. The first expanded capabilities include notes, tags, categories, Paths and selected profile settings; this is not yet complete UI-action parity.
- The agent must never guess PocketBase IDs. Catalogs are read from the signed-in user's Brain. Invalid, recurring, stale or ambiguous changes must fail safely. Preview and apply refresh the state before executing; a failed multi-domain write may have left earlier writes applied and must report partial success risk rather than claim atomicity.
- Destructive actions, credential changes, admin fields, unrestricted API/SQL, file access and source-code modification are explicitly outside the public tool registry. Adding UI parity requires a reviewed handler with tests, not prompt-only permission.
- Long/complex requests can be decomposed into several proposed tool operations, but unresolved dependencies (such as referencing IDs of items not yet created) must not be silently invented. User must see what will be changed.
- Agent follow-up observations are read-only, bounded to four steps per user request, deduplicated by tool/argument signature, and labelled as untrusted application data. A proposal containing writes while requesting more context must fail without making changes. All steps share the same request ID.
- A single *reversible* operation directly requested by the user may run without a redundant confirmation dialog, but always performs the usual Brain-backed state preview and freshness checks. Consequential changes and multi-action batches require approval. Destructive operations remain unavailable without a dedicated explicit-consent handler.
- Backlog list tools now support reading, completion toggles and renaming **ordinary** unscheduled items through `updatePlanningTask`, with old-title/old-state checks. They must never silently modify a rich Note, recurring series or scheduled plan.

## Core Rules

**P0 — Optimistic UI first:** Every valid user action immediately changes the active visible UI; PocketBase, outbox persistence, refresh, and animations are secondary operations. Visual feedback target is **≤100 ms**, including create, edit, delete, start/stop, toggle, reorder, and bulk actions in Records, Plans, and Lists. A visible local acknowledgment must never be confused with confirmed remote synchronization. See `ARCHITECTURE.md` § `OPTIMISTIC_UI_FIRST`.

- Every user action must produce visible feedback within ~100ms.
- User intent updates local UI first, then syncs in the background when the action writes data.
- Errors are visible, specific enough to act on, and never spammed.
- Loading, empty, disabled, and offline states are first-class states, not afterthought text.
- Feature screens compose canonical components from `lib/core/widgets/` and approved shared feature widgets.

## Viktor voice commands (Yandex BYOK)

- Viktor's account-wide BYOK connection is stored in a **server-only AES-256-GCM encrypted vault**, keyed by authenticated `profiles.id` and provider. The browser/mobile/desktop app receives only connection metadata, not the plaintext API key. Saving the same connection on one device enables model/STT usage on the others. Old transient keys work if the vault is temporarily unavailable; no plaintext secrets are written to SharedPreferences or PocketBase user-facing rows. Disconnect explicitly removes server-stored credentials. The encryption key must live outside the DB and repository; missing keys block vault access, rather than silently saving unencrypted data.
- The YandexGPT model and Yandex SpeechKit transcription use one AI Studio service-account API key, plus its folder ID. The key must be permitted for text generation and STT. Other model providers retain their existing BYOK flows.
- Tapping the microphone begins genuine audio capture with visible amplitude/byte count. A detected end-of-utterance automatically transcribes and submits the command; Stop remains available if silence detection fails. This is not full-duplex audio chat or voiced AI replies.
- **Viktor bulk planning:** one user request may include status-filtered `move` and `compact` operations. The model receives `is_done`, source and destination day context, and the profile timezone, but selects only filters, not individual PocketBase IDs. The Brain resolves owned rows, preserves each duration and chronological order, converts requested IANA timezone wall times via the profile projection, checks fixed/recurring plans and destination collisions, previews all affected rows, compares both-day snapshots on approval, and uses the canonical `bulkUpdatePlans` write. A failed batch must report the possibility of partial server writes; never claim all updates were committed. Never silently make unrelated plans overlap or change status.\n- A recognized two-card swap runs only when the plan IDs are unambiguous. For «поменяй местами последние два плана», Flutter resolves the last two **scheduled chronologically** before querying an LLM; PocketBase row order and model guesses are not positional authority. Overlapping or tied last starts fail closed. Executor and Brain enforce ownership, recurrence/fixed-time guards, stale-state rejection, and existing schedule rules. No speech service ever writes PocketBase rows.
- Mic access/auth/permission/recognition failures must show actionable errors (including a sanitized Yandex upstream HTTP status for permission/quota/format failures, not a blanket generic message). Raw audio is transient. BYOK keys are encrypted at rest only after explicit user Save in the server vault; client plaintext keys are transient. Never block the main thread/startup or optimistic timeline/planner feedback on speech requests.

## Morning Start prompt (Timeline)

- The existing "Start the day" sleep check-in is enabled by default. Settings → Preferences → Start of day provides an explicit on/off switch (also available on mobile Settings).
- On web, the morning check-in switch persists in the app's existing IndexedDB journal (separate from SharedPreferences/localStorage, which can be full of cached app data); Android/Windows use device-local SharedPreferences. Use one stable device key, independent of profile hydration. The setting survives browser reloads and restarts, applies to that device only, and does not synchronize across devices. Migrate legacy disabled values from old SharedPreferences keys when readable, without making IndexedDB persistence depend on their availability. The UI must not display a default ON switch before loading.
- When disabled, Timeline's morning gate must never open the check-in automatically. Enabling it restores the existing one-per-day, wake-window and done/dismissed rules.
- This visibility preference does not disable sleep synchronization, delete sleep records, or alter the existing first-activity start flow.

## Tap Feedback

- Tappable controls must have an obvious pressed/selected/disabled state.
- Icon-only actions require tooltips where practical.
- A tap that opens a sheet, menu, route, picker, or mode must respond immediately.
- Debounce repeated destructive or sync-heavy actions at the handler boundary.

## Lossless record capture

- Web record create/update/stop/delete mutations persist to a transactional IndexedDB journal, not the small browser settings localStorage; migrate legacy queued writes atomically, then release old storage.
- Retry of one capture must reuse the same business UUID and original start time; a stale retry cannot submit a title once the input changed.
- A new recording must not stop a running recording until the new capture is durably accepted.
- Browser web tests must prove migration, persistence after reinitialization, draft recovery, and retry deduplication.


- A record's title, requested category and start-time intent must enter durable
  device storage before the entry field is cleared or a server request is made.
- A temporarily missing category catalog must **never** reject a new record
  before local outbox staging. Keep the explicit category identity for replay;
  do not silently remap it to an unrelated category.
- Network downtime, auth refresh and PocketBase validation delay delivery, not
  local acceptance. Pending records remain visible and survive reload.
- Keep the draft recoverable if even the local write-ahead handoff fails. Never
  display a false success if device storage cannot persist the input.
- Corrupt record outbox bytes must be surfaced and preserved; never interpret
  an unreadable queue as empty and overwrite its pending user data.

## Save Behavior

- Saves that affect records, plans, lists, Paths, categories, tags, or profile settings update the active local state before remote sync. Where a feature lacks a safe optimistic mutation path, implement the path rather than waiting for PocketBase; never bypass required validation, authorization, or local lossless-capture safeguards.
- Retriable network failures keep the optimistic state and enqueue where an outbox exists.
- For records, successful local staging means the input is accepted even when PocketBase is slow/offline; rapid consecutive creates are distinct and never rejected because an earlier request is in flight.
- A staged record remains visible across a full refresh or app restart until confirmed on the server; an uncertain POST retries against the same business ID without duplicating it.
- Failed record create validation retains the original queued payload and shows a sync error rather than falsely showing server success. If device storage cannot persist the input, do not report it as accepted.
- Other non-retriable validation/schema failures roll back and show one concise error.
- Silent success is preferred; no success log spam for background sync.

## Edit Behavior

- Edit sheets must show the current value immediately and keep unsaved user input stable while network work runs.
- Field controls must not reset on rebuild unless the source record changed.
- Expensive parsing or list refreshes must not block text entry, tap response, or sheet opening.

## Delete Behavior

- Destructive actions require either an explicit confirmation or a clearly reversible affordance.
- After confirmation, the deleted item disappears from the active UI immediately (≤100 ms), and deletion acknowledgment reflects local acceptance rather than delayed PocketBase success. If persistence or a non-retriable error prevents deletion, restore/reconcile the item and explain the failure once.
- Failed non-retriable deletes restore the item or show a clear recovery path.
- Background delete retries must not produce repeated identical errors.

## Loading States

- Use `AppLoading` for canonical loading indicators.
- Full-page loading should center the indicator with enough padding.
- Inline loading should preserve layout size where possible.
- Do not replace already loaded content with a full blank loader for a small background refresh.

## Empty States

- Use `AppEmptyState` when a surface loads successfully but has no items.
- Empty states must explain what is empty and, when useful, offer the next safe action.
- Do not show empty states while data is still loading.

## Error States

- Use `AppErrorState` for blocking surface-level failures.
- Use snackbars for action failures where the existing surface can stay rendered.
- Error messages must avoid exposing backend internals unless they are needed for debugging.
- Repeated background errors must be debounced.

## Offline / Pending Sync States

- Offline actions should remain usable when the relevant outbox supports them.
- Pending sync should be visible through the global sync/offline banner, not per-row noise.
- Auth-paused sync must clearly indicate that sign-in/session repair is needed.
- Manual retry should call the existing outbox flush path.

## Disabled States

- Disabled controls must remain visible when they explain unavailable capability.
- Use disabled state for missing prerequisites, not hidden UI, unless the feature is admin-only or permission-only.
- Disabled controls should preserve layout to avoid jumpy screens.

## Sheet Close Behavior

- Closing a sheet must not discard committed state.
- If a sheet contains unsaved local edits, it must either autosave/flush pending edits or ask for confirmation.
- Sheets that perform background writes must remain closeable unless closing would corrupt state.

## Picker / Taxonomy Creation

- Category pickers opened from edit sheets or category-selection controls must expose **visible create actions immediately** when the picker opens — not only at the end of a long scrollable list.
- Layout: sheet header → search (optional) → **always-visible top “+ Add root category” row** → scrollable tree → **sticky bottom “+ Add root category” row** (root level only in nested tree pickers).
- Every category row in the picker tree must show a trailing **“+”** (`add_subcategory`) that creates a **child under that exact row**; row tap still selects the category; the trailing **“+”** must be a separate tap target outside the row selection hit area.
- Each **expanded folder** must show a folder-scoped **“Add category inside <folder>”** row after its visible children.
- Create actions must pass an **explicit parent** to the Brain create path — never infer parent from selected category, expanded folder, search UI, or global name lookup.
- When search/filter text does not match an existing category, show a contextual **Create “<name>”** action near the empty-result area.
- Category creation requires network connection; do not invent client-only temporary categories or fake ids.
- After successful creation, refresh the in-memory category cache via the Brain path, close only the create dialog, auto-select the new category through the **same selection callback** as tapping an existing row (`CategoryTreeSheetPicked` → edit-sheet draft → autosave), then close the picker and return to the edit sheet. The parent edit sheet must stay open; category field and entity draft must update immediately without reopening the picker.

## Paths

- **One destination:** desktop side navigation and phone/tablet More → Paths open the same shell-owned Paths destination. Do not push a second shell or a separate desktop frame.
- **Opening is read-only:** entering Paths may load category/Path data, but must not create, migrate, retire, canonicalize, publish, generate Planner tasks, or apply AI proposals.
- **Project-independent structure:** generic Path UI and validation operate from stored Path data. Do not hard-code KADR, GOLOS, Igropoisk, Price Reporter, or any other project’s required topics into the feature.
- **Local-first explicit edits:** goal/stage/action completion edits reflect immediately. A rejected save restores the prior local state once and shows one concise error.
- **Duplicate roots are not silently deleted:** when transition storage contains more than one active root for a project, surface the condition and repair it only through an explicit idempotent repair/migration action.
- **Draft/review/active separation:** future AI or user restructuring happens on a draft/review revision. Planner consumes only the explicitly active/published Path revision.
- **AI proposal safety:** AI suggestions remain proposals until validated/applied through app-owned tools. Publish, delete, and bulk schedule changes must remain auditable and reversible.

## Planning bulk schedule edit (2026-10-21)

- For scheduled Planning selection, one **Start of sequence** Omni-Picker sets the complete profile-wall **date and time**. The feature must never discard the time when opened through a date-related control.
- **Move date only** is a separate, explicitly selected mode with a date-only picker. It preserves each selected task's original clock time and duration.
- A chosen start time means the **first** selected task begins at that time. Remaining tasks follow in visible/source order, sequentially without gaps; preserve each task duration (or existing tag-duration fallback), including rollover after midnight.
- Compare each final wall date/start/end against the original plan. Do not infer "no changes" from matching calendar days, and do not patch tasks whose schedule is unchanged.
- Existing destination plans are displaced only on actual conflicts. Use the established Brain optimistic state and profile-timezone → UTC persistence path; never interpret these edits in the browser/phone timezone.
- Applying is unavailable until the user makes an explicit picker choice. Invalid/non-persisted selections must not silently produce a partial write.

## Selection / Bulk Mode

- Bulk mode must have a clear entry and exit.
- Selected rows/cards must have a persistent selected state.
- Bulk action bars must not cover critical row controls without providing enough bottom padding.
- Exiting bulk mode should clear selection predictably.

## Drag / Reorder Behavior

- Drag handles or long-press affordances must be discoverable.
- Reorder should update local order immediately.
- Persisted order sync should be batched or debounced and must not block drag motion.
- Failed reorder sync should restore or reconcile order without duplicating rows.

## Optimistic UI Expectations

- **Priority 1:** Records and Planning/Lists CRUD follow the Iron Laws: visible local shadow and immediate local acknowledgment first, durable outbox handoff second, PocketBase sync third. No success toast waits for a forced refetch or remote acknowledgment; a server-confirmed claim requires real server acknowledgment.
- The UI must not wait for PocketBase writes before reflecting a user action.
- Rollback is reserved for non-retriable failures; ordinary offline/network failures use queues where available.
- Do not introduce full refetch fan-out after a small mutation unless unavoidable.

## Immediate web startup on cached sessions (2026-10-21)

- A warm reload MUST reuse versioned web assets and the last-known per-profile local state; never clear browser caches or unregister workers on each visit.
- An unexpired, scoped local auth record can open the cached shell without a blocking health check or token refresh. Foreground synchronization MUST still validate the server token and end the session on confirmed 4xx revocation.
- Existing categories and plans are restored from user-scoped local caches before network reconciliation. Failed/empty catalog reads must never erase a known-good category tree.
- Time View ordinary pointer drag retains its original gesture recognizer, collision logic, animations and card positioning. When the timeline scrolls under a stationary pointer, only the lifted card compensates for the scroll offset; drop placement uses the final cursor position.

## Time View pointer-locked drag (2026-10-21)

- A grabbed scheduled card maintains the exact initial pointer-to-card offset throughout drag, regardless of pointer direction, canvas scroll offset, auto-scrolling, proximity to other cards, or drop-grid snapping. Drop targets may snap; the card itself must not snap or hit an invisible collision wall while held.
- Normal drag geometry is unchanged. During auto-scroll, the dragged card receives the scroll offset that has not yet been applied by the last pointer event; only its transform updates on scroll. The final drop recalculates against the true cursor position at release.
- The dragged scheduled card uses the requested 0.74 opacity; the original position remains an understated placeholder. A new-time indicator is a compact theme-aware neutral chip near the card, not a full-width black overlay; it must not intercept pointer input.
- The drag ending snaps/persists the final intended position only after release, maintaining the established fixed-time and cascade safeguards. Rules apply equally to browser, Android and desktop.

## P0: immediate Planning create across Web, Android and desktop (2026-10-21)

- Submitting a valid new plan synchronously stages a locally identified task in the visible Planning page before any awaited work, PocketBase request, network refresh, outbox storage or heavy projection. It must appear on the Time graph/list on the first subsequent Flutter frame.
- Clear the entry field on local commit, so a second new plan can be entered without waiting for the first POST. Non-retriable failures must visibly restore/remove the optimistic card without silently losing the action; retriable network failures are retained in the outbox.
- A new Planning stream subscriber receives the current cache+optimistic overlay **as its first event**, not after a network response. Attach a listener before synchronous hub emissions.
- Local create notifications must not be delayed by a trailing debounce that can be extended by repeated refreshes; expensive network, alarm, snapshot and disk work remains background/debounced.
- Pending creates reconcile by stable client business ID. Identical titles/date do not mean identical plans. This rule applies to all supported platforms and to existing loaded screens.

## Performance & Responsiveness Contract

Performance, responsiveness, and stability are **P0 correctness**, not polish. See `docs/ARCHITECTURE.md` § **PERFORMANCE_KILL_SWITCH_LAW**.

- Every user action must produce **visible feedback within ~100ms**.
- Local/optimistic UI must update **before** network I/O for record/plan mutations.
- Already loaded content must **not** be replaced by blank/loading state for a background refresh.
- UI must **never** show partial/incomplete card states as an intentional loading phase.
- If content is not ready, do not reveal broken/partial UI — but readiness gates must **not** break live updates or freeze navigation.
- Any perceived performance regression (lag, freeze, missing instant update, “impossible to work”) is a **P0 correctness bug** and outranks feature/design/preload work.
- No feature, design, preload, cache, animation, or architecture idea may remain active if it hurts app speed or stability.

## Notes library folder tabs

- Notes categories appear as color-filled physical folder-edge tabs on both desktop and mobile, not translucent pill chips or mobile drawer-only navigation. Folder tab names use a dedicated compact 14px type size (exception to regular 16px content typography) with actual glyph-based width measurement and an upper safety cap of 460px, not fixed-width ellipsis for ordinary names. Exceptionally long labels expose their full name on hover or hold.
- The folder spine silhouette uses a curved diagonal right edge with partially overlapping neighboring tabs; it must never degrade to rounded-rectangle/pill chips. “All” is fixed at the start and “+” fixed at the end; only category spines between them scroll, via touch swipe, mouse drag, horizontal trackpad or ordinary vertical mouse wheel. The active spine keeps its natural position and paints above neighbors.
- The + action remains fixed beside the horizontal scrolling tabs and explicitly separates selecting existing categories from creating a new category with the canonical Brain-backed dialog; created categories are pinned immediately.
- Pinned category order is stable: selecting an existing tab must never move it to slot 0, persist reordered IDs, or forcibly scroll the tab rail. An externally selected unpinned category may be appended after pinned tabs without disturbing them. Manual pinned categories persist across navigation/restart. No duplicate category store.
- The tabs are compact (38px high, label-fitted width, 460px safety cap), with short rounded diagonal shoulders, modest overlap, delicate top-edge shading and no thick trapezoids or saturated solid fills. Keep category identity through restrained pastel tint; body paper must remain near-neutral with a subtle related hue (including dark theme). The selected folder tab must graduate to the exact body color at its lower seam, with a 260ms transition. The first note card is inset at least 18px below the tab/paper seam. Do not introduce nested frames around the Notes grid. Use the approved October 5 physical folder-tab shape as a silhouette reference, not its strong palette. In grid cards, preview text stays directly under the title; no variable blank vertical region between header and body.

## Notes embedded editor and floating formatting dock

- The white Notes editing canvas in the desktop master/detail layout is a distinct 20px-rounded paper surface on **all four corners**, with category-tinted folder paper visible at its perimeter. Do not place a full-width opaque white wrapper behind it.
- The top editor navigation row has at least 20px internal top spacing in embedded mode. Back, undo and overflow are ghost controls: transparent at rest, readable icons, and a soft circular hover/tap highlight only.
- The formatting controls float inside **one compact, genuinely translucent frosted-glass pill** (350×48px, 24px corners): surface alpha graduates from ~84% to ~72% in light mode (~82% to ~69% dark), local 24px backdrop blur, hairline border and restrained shadow. Blurred content may be seen through the capsule, but icons stay legible. The *full-width lower dock* has no opaque rectangular backplate. Selected buttons retain their own active highlight; others remain transparent inside the pill.
- Scrolling blocks continue beneath the bottom dock. The full-width overlay feathers in both 18px backdrop blur **and the actual editor paper color**, reaching near-white at the bottom of light-mode notes (matching the dark paper in dark mode). The upper edge must be fully invisible; opacity increases gradually downward, without a solid strip or sharp boundary. Keep this full-width fade behind the independent translucent pill, not inside it. Never reserve a separate empty horizontal band beneath the document.
- The document scroll view provides its own end padding so the final block can still be read and edited above the floating tools. The same components apply on mobile, wide embedded editor and inline note editing without changing persistence or text selection behavior.

## Calendar navigation and view modes

- Calendar period navigation is gesture-first: horizontal swipe moves to the previous/next year, month, week, day-focus date, or Events month. Do not add persistent previous/next arrow buttons to the calendar header.
- The calendar header mode button opens one menu with exactly four primary views: **Year, Month, Week, Events**.
- Year view shows all 12 months; month header enters the selected month and clicking a day cell starts new-plan creation. Month day cells and empty Week time slots start new-plan creation with the chosen wall date/time; tapping an existing task opens editing, and tapping a grouped week block opens full interactive task cards. Events is an agenda-style upcoming list beginning at the selected day.
- Calendar browsing and cell taps never change the global header date or Timeline/Plans day selection. Calendar owns its own focused day. New plans use the standard shared editor and the existing local-first plan pipeline.
- Month cells show grey dates from adjacent months and their actual scheduled plans rather than missing cells. Tapping a plan edits that plan; tapping an empty cell creates a plan for that date. Neither affects the shared top-header date.
- Start time remains visible on compact Week cards and grouped blocks. Calendar Week uses the exact Time View `TimelinePlanInteractionBlock` pointer/hold gesture contract: immediate pointer drag on wide screens, hold to drag on touch, and frozen vertical scrolling/horizontal paging while dragging. Drop targets use Time View's 5-minute wall-time snap and shared `computeTimeViewInsertionCascade` (before/after target card or empty slot). Category group member gaps/durations remain intact; fixed-time barriers and persistence use the existing Brain planning path. Month day drops retain original wall clock.
- Week view collapses consecutive/overlapping plans under their shared category branch into a visual-only block. Different branches and gaps above 10 minutes do not merge. Independent plan records, exact times, and collision lanes remain intact; hover previews details, click opens canonical task cards.
- Calendar mode changes and swipes are local UI actions and must respond immediately; data refresh stays in the existing planning cache/stream path and must not block the gesture.

## Multi-select bulk plan scheduling

- Selecting several plans and setting a destination date + start time means
  that time is the **first plan's** start, not the start for every plan.
- Place plans consecutively, in visible source order, with each plan retaining
  its original duration (or its tag/default duration when no end exists).
- Date-only bulk moves retain the original separate clock times.
- Preserve the original audit anchor and postponed flag, persist each target
  date and end-date correctly, and optimistically move the batch as one unit.
- Never overlap destination plans. Cascade affected pre-existing destination
  plans forward; leave unrelated plans outside the insertion unchanged.
- Abort the batch before any optimistic change when a collision would require
  a patch to an unsaved or virtual recurring instance.

## Automatic plan workday rollover

- Automatically placed (no user-specified clock time) dated plans must fit their **full duration** into the selected working window, never be persisted past visible hours and silently disappear from Time View.
- If the requested day is full, search subsequent days using Brain cache and optimistic overlays. A category's inherited default start is the working-day start; the existing 8-hour category limit defines its auto-placement day unless a narrower Time View bound applies.
- Preserve existing task positions, task duration, category, tags and original `initial_date_key`. Persist the actual destination wall date with the new start/end, and set `is_postponed` when moved later.
- Explicit user clock-time input is not automatically moved to a different day. If no fitting auto-placement slot exists in the 14-day search horizon, display a specific error rather than creating a hidden plan.
- An automatic move shows the destination date/time. No PocketBase reads or heavy full-history scans on the tap hot path.

## Planning Time Mode

- **Selected-time stability:** typing or editing a task title, notes, checklist, category, or tags must not change a start time selected on the Time View grid. Start/end changes require an explicit time control or drag/resize gesture.
- **Create anti-overlap:** a newly created scheduled task that intersects another task moves forward to the first free slot, preserves duration, treats touching boundaries as valid, and shows one concise adjustment notice. Existing tasks are not moved by this create correction.
- **Editor hot-path:** text and rich-note typing must not rebuild the full Planning surface or emit global planning refreshes per keystroke; expensive draft merge/sync work is debounced.
- **Timezone / storage:** Plan and record instants are stored as **UTC ISO**. Time mode projects them into the **profile timezone** for day filter, block placement, labels, and drag/resize math. User-entered wall time at create/edit belongs to the **current profile timezone**.
- **Current-time line:** Uses profile-projected “now”; renders **above** plan cards (`IgnorePointer`); must not sit behind blocks.
- **Visible range:** No “outside visible range” / out-of-hours fallback bucket. Scheduled cards outside the selected wall day or visible hour range are **not shown**.
- **Fixed-time drag barriers:** A move cascades only the moved plan(s) and their connected overlap chain. Untouched time slots and fixed meetings outside that chain must remain unchanged; pre-existing unrelated overlaps must not veto a valid move. A fixed plan blocks only if the current cascade would actually move it.
- **Snap / duration:** Time mode supports **10-minute** minimum duration and **5-minute** snap for move and top/bottom resize (`timelineSnapMinutes`, `kPlanScheduleSnapMinutes`, `kPlanTimeMinDurationMinutes`). Card top positions are exact wall-time projections on the same Y scale as the timeline grid: an hour-boundary start aligns exactly with that hour line, and no post-layout packing may shift the card top.
- **Overlapping cards:** Time View always renders overlapping planned intervals in disjoint horizontal lanes, preserving each card's full scheduled time, absolute Y position and ability to open/drag. Connected overlap groups share stable lane widths; cards outside those groups fill the row. Rendering must never conceal a card beneath another; the lane arrangement never silently changes stored plan times.
- **Dense hour cap:** One wall-clock hour visually stretches to at most **248 px** (six 10-minute cards at 38 px + 4 px gaps). Card heights use piecewise anchors (10→38, 30→75, 60→120 px), not unbounded proportional stretch.
- **Card density:** Short blocks use **micro** / **compact** layouts (essential controls only). **Medium** / **large** blocks show progress separator + category breadcrumb + planned time footer (`PlanTimeTaskCard`).
- **Interactions:** Checkbox, play, menu, body tap, drag, and resize keep independent hit zones; Time View body drag/tap overlays must not cover trailing Play/Menu controls; optimistic schedule updates follow the Iron Laws.

## Planning edit-sheet geometry

- Dated-plan edit sheets on desktop/web and mobile use one stable hierarchy: title → category → start/end times → tag strip → three tabs (**Notes**, **Repeat**, **Parallel plans**) → active tab content → fixed Delete/Cancel/Save footer. Do not place schedule controls below the Notes editor or divide the sheet into permanently competing Notes/schedule flex panes.
- **Notes is the initial first tab**, rendered using the canonical `NoteEditorPage(inlineBodyOnly: true)` with its existing block canvas, floating Notes toolbar, and single scroll owner. Do not replace it with a text box or create a second toolbar. Repeat owns reminder/recurrence controls, Parallel plans owns linked plans.
- Content area uses the remaining height; the footer stays visible without overlapping tabs or the editor. When the mobile keyboard is open, preserve the existing notes-focused compact mode. Keep the accepted category/time/tags ordering on both desktop and phone.

## Edit sheet Save (local-first)

- **Save is a local commit button**, not a network gate. Valid Save applies optimistic Brain/cache/UI **immediately**, shows **Changes saved** (or a specific validation error), and closes the sheet without waiting for PocketBase.
- **Explicit Save beats autosave:** `EditSheetAutosaveGate.flush(force: true)` always runs the latest draft sync and cancels pending debounce; autosave debounce must read the latest controller state at fire time, not a stale captured draft.
- **Network is background:** PocketBase PATCH runs after local apply; retriable failures keep optimistic UI and enqueue outbox; non-retriable failures roll back once with one error snack.
- **Validation feedback:** Empty title or missing required times show an immediate localized warning — never a silent no-op tap.

## Recurring plan edit/delete scope

- **One stored row per series:** Client expands `plans.rrule` into virtual `virt-{seriesPb}-{YYYY-MM-DD}` rows for the visible window; `exception_dates` omits instances; materialized one-offs link to the series via `parent_plan_id` + `recurrence_instance_date_key`.
- **Historical immutability:** A recurring edit/delete must never rewrite earlier occurrences. Past recurrence history remains attached to the old series definition.
- **Scope dialog (EN/RU):** Editing a recurring/virtual/materialized occurrence stays as an in-sheet draft while fields change; the two-choice scope dialog opens only after explicit **Save**, never from autosave while typing/changing fields. Deleting opens the same scope dialog only after the explicit delete action. Choices:
  - **This event** — single occurrence only (`exception_dates` + materialized one-off on edit; exception only on delete for virtual rows).
  - **This and all following events** — split at the selected occurrence. The historical series gets an `UNTIL` boundary immediately before that day; edits create a new future series from the selected occurrence, while delete stops the series at that boundary. Existing materialized future exceptions move with the future series.
- **No “all series” mutation:** There is no user action that retroactively changes/deletes earlier occurrences. Legacy `entireSeries` callers canonicalize to the future-safe split behavior.
- **Dedupe:** Materialized occurrence for `{seriesPb, instanceDate}` suppresses the matching virtual card. Virtual rows must never enter persistent caches or REST PATCH/DELETE paths.

## Gesture Ownership / Date Swipe Law

- **Horizontal swipe inside Timeline and Planning changes the calendar day** (previous/next date). This is **required** product behavior — do not remove it, disable it globally, or replace it with tap-only navigation.
- **This is not main-tab navigation.** Bottom/side nav switches app sections; horizontal swipe within Timeline/Planning is **date** navigation.
- **Code:** `TimelineSwipeWrapper` (`lib/features/timeline/timeline_view.dart`), `PlanningSwipeWrapper` (`lib/features/planning/planning_view.dart`) — infinite day `PageView.builder`.
- **During Planning Time-mode card drag/resize only:** horizontal date paging may be temporarily locked while the card owns the gesture; restore date swipe when the interaction ends.
- **Vertical scroll** stays vertical; tap opens edit; long press starts drag where supported. Gesture conflicts are P0 bugs.
- **Performance work** must not stack experiments on a regressing build. If swipe/startup/optimistic UI regresses, **stop** and apply the Performance Kill Switch Law (`ARCHITECTURE.md` § PERFORMANCE_KILL_SWITCH_LAW) — disable the risky path, restore stable paging, restore live optimistic sources, then re-measure. Profile-mode/DevTools proof is required **before** re-enabling any experimental preload layer; “the cache exists” / “snapshot is ready” / “body cache exists” is **not** sufficient if the user sees lag, loading, or crash.

## People / source hygiene contract

- Entry point: Settings → Account → People; People is not a primary app tab.
- Sections: People, Circles, Sources.
- Person supports photo, email, phone, relationship, optional-year birthday, reminders, multiple Circles and notes.
- Sources are a hidden review index, never the visible People list.
- Explicit source actions: Add, Link, Ignore, Block. Ignore/Block survives later source syncs.
- Device contacts sync only after user action and OS permission; no startup address-book scan.
- Plan reminder reconciliation must not cancel People birthday reminders.


## Browser extension companion

- The browser extension is a compact LIFE OS companion, not a second backend client.
- Popup order is fixed: **Current record** → **New record** → **Open LIFE OS**.
- **Current record** shows the canonical primary running record, its category path, category-color accent, and a locally ticking elapsed timer derived from the Brain-owned start time. If nothing is running, show an explicit empty state.
- **Stop** ends the current primary record through the existing Brain stop path.
- **New record** starts an actual running Timeline record through the existing Brain `startTimer` / Highlander path. Category inference, singleton-running enforcement, optimistic state, offline behavior, timezone rules, and PocketBase ownership remain canonical.
- **Open LIFE OS** is always a visible one-click action.
- The popup follows LIFE OS design tokens and canonical geometry: app/card surfaces from `AppColors`, 18px card radius, 12px control radius, monochrome primary actions, semantic error color for Stop, and data-driven category color only as the running-card accent.
- The extension never stores PocketBase credentials and never calls PocketBase directly. When needed it opens an inactive authenticated LIFE OS web bridge tab; the web shell executes the command after normal auth/profile bootstrap and publishes only a bounded running-record snapshot back to browser-local storage.
- Browser requests carry unique IDs and successful requests are deduped. A temporary bridge tab must stay alive until the canonical primary-record network chain has completed and the resulting running state is confirmed.
- Browser-local snapshots are **render-only cache**. Opening the popup must always trigger a fresh `bridge_sync` through the authenticated web app; an open LIFE OS tab's stored snapshot must never suppress that canonical refresh. While the popup remains open, it refreshes the canonical current-record state periodically and applies pushed snapshots without blocking the local elapsed timer.
- Bridge setup and request consumption run after the first frame and must not block normal LIFE OS startup.


## Viktor AI and voice entry (2026-10-20 beta)

Shell header, More, Planning Smart and Profile open the same Viktor chat; no overlapping floating voice FAB or competing Smart Plan sheet. Dictation remains inside the safe-area chat composer, resized for the keyboard. Changes have actual-time preview before approval; remote schedule changes invalidate approval. Recurring/fixed plans cannot be shifted implicitly. Small screens require 320/390 px no-overflow widget tests and real-device checks. See `docs/VIKTOR_BETA_RELEASE_CHECKLIST.md`.


## Viktor BYOK settings dialog and browser quota (2026-10-21)

- On desktop, Viktor's model settings dialog has a bounded maximum width of 560 logical pixels; it must never stretch horizontally in response to a long server/storage error. On mobile it fits available screen width with 16 px side insets. Validation errors appear in its scrollable content, not the actions row, and never cause width changes.
- After an authenticated encrypted PocketBase connection POST **and subsequent GET/readback** succeed, the BYOK connection is saved. Web clients must **not** subsequently write redundant Viktor preference keys into SharedPreferences/localStorage: the user's cloud connection metadata is the source of truth and localStorage can be full. Native optional preferences are best-effort and cannot downgrade a confirmed cloud connection to failure.
- Never clear all localStorage/IndexedDB to free quota automatically, because it may contain unsynced offline app data. A browser quota error in unrelated settings must be diagnosed separately.

## Viktor recorded dictation and feedback (2026-10-20)

The web microphone MUST capture actual audio through `record`, not browser `SpeechRecognition`. On start, show record duration, current sampled volume and captured byte count; microphone stays a stop control. After stop, show a transcription progress indicator, then place recognized words as **editable** text in the existing composer; do not automatically submit or execute model actions. A silent/too-short recording, no microphone permission, rejected provider key or unavailable service MUST show a visible inline error, not produce a fake listening/success state or repeated chat bubbles. Audio (up to 60 seconds) is sent to the selected transcription provider via authenticated PocketBase, using BYOK; never store credentials or recordings. On Android and Windows the same capture/submit UX replaces silent speech service behavior.

## Category manager (desktop and mobile)

- Desktop Categories uses a two-pane tree/inline editor; mobile uses a single tree and a bounded near-full-screen editor with a sticky Save action.
- Category tree drag uses the canonical `AppReorderableList` + `AppHoldToReorderListener` (300 ms), matching Plans and Notes. No feature-specific drag handles or buttons.
- Drag between visible sibling groups changes the parent through `updateCategoryParent`; within a group it calls `applyLocalCategorySiblingOrder` and debounced `persistCategorySiblingOrder`. Invalid self/descendant moves are rejected *before* the optimistic mutation.
- Expanded branches reveal drop locations in child sibling groups. For a collapsed/empty parent, use the editor's explicit Parent category selector.
- Reorder/move updates the local category tree immediately, offers Undo, and reports failed server persistence. Search expands only matching paths without rewriting data.
- Editor shows name, parent, color and icon first; translations, keywords, default-category and destructive actions are in Advanced. Scroll content is bounded by the viewport and Save remains accessible.

---
