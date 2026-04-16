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

## [2026-04-21] - Strike 2 & 2.5: Context-aware parser + STT locale
* **Parser / STT:** Upgraded smart_input_parser.dart with a leading-hour regex and an isBacklog bypass for dateless plans. Enforced strict EN/RU localeId binding (using en-US for Web) in the STT listener, fixing legacy locale hardcodes.

## [2026-04-20] - Strike 2: Context-aware parser & STT locale
* **Parser / STT:** Upgraded smart_input_parser.dart with a leading-hour regex (^([01]?\d|2[0-3])\s+) and an isBacklog bypass that forces startTime: null and strips scheduling junk. Enforced strict EN/RU localeId binding in the STT listener, removing legacy Web locale hardcodes.

## [2026-04-19] - Strike 1: Lists friction + optimistic tags
* **Lists / planning cache:** Fixed Optimistic UI cache for tags by removing the server-override branch in `_mergePlanningOptimistic`. Added inline quick-add with `_pendingInline` state and a delete button with confirmation dialog to the ListsView. (`database_service.dart` `applyOptimisticPlanningTask` dateKey fallback for short keys; `lists_view.dart` optimistic `optimistic-inline-*` rows + `addPlanningTask` / `deletePlanningTasksBulk`; l10n `lists_inline_add_hint` / `lists_delete_backlog_confirm`.)

## [2026-04-18] - Recurring: instance materialization (virt- complete)
* **Planning / recurrence:** Refactored virtual clone mutation in `database_service.dart`. Separated Delete (adds `exception_dates` to parent) from Complete (Instance Materialization: adds exception to parent AND creates a concrete `isDone: true` record). Added a strict rollback mechanism if the materialization POST fails. (`_parseVirtualPlanRowId`; delete path → `_patchRecurringTemplateExceptionDates` only; complete path → `_completeVirtualRecurringInstance` = parent PATCH + `_createPlanningTaskPocketStrict` / `_buildPocketPlanCreateBody`; rollback removes the exception; `updatePlanningTask` / `markPlanningTasksCompletedBulk` vs `deletePlanningTasksBulk`.)

## [2026-04-17] - Phase 4–5: Zero-Table Lists & More navigation
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