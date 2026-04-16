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