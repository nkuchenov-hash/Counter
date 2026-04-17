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

## [2026-04-17] - Strike 17: Omni-Picker refinement
* **Platform / omni-picker (`lib/core/widgets/omni_date_time_picker_dialog.dart`, `showAppDateTimePicker` keyboard path in `shared_widgets.dart`):** Refined the Web/Desktop Omni-Picker into a hybrid UI, combining Flutter's native CalendarDatePicker for visual day selection with a custom-styled, large-format digital text input for time. Maintained the single-dialog Omni-Picker Law while drastically improving visual hierarchy and desktop input ergonomics. Replaced `InputDatePickerFormField` with `CalendarDatePicker` + `ValueKey` sync; soft rounded HH:mm fields, divider, ~350px content width; mobile/touch path unchanged (`omni_datetime_picker`).

## [2026-04-17] - Strike 16: Authentication gates
* **Auth / routing (`auth_bridge.dart`, `auth_view.dart`, `main.dart` `RootAuthWrapper`, `pb_config.dart` `PbCollections.profiles`):** Implemented secure authentication flow targeting the profiles collection with a unified AuthView UI (Sign In, Register, Password Reset, OAuth). Hardened checkSession() to strictly trust pb.authStore.isValid, removing stale local fallbacks, and wired the global routing gate to protect the AppShell. Added `loginWithPassword` / `register` / `requestPasswordReset` / `loginWithOAuth2` (`AuthBridgeException` / `AuthBridgeCancelled`); all PocketBase auth uses `profiles` only; `auth_screen.dart` re-exports `AuthView`.

## [2026-04-17] - Strike 15: Unified Omni-Picker
* **Platform / omni-picker (`ARCHITECTURE.md` §8.1, `lib/core/widgets/omni_date_time_picker_dialog.dart`, `shared_widgets.dart` `showAppDateTimePicker`, `picker_entry_modes.dart`):** Codified the Omni-Picker Law in ARCHITECTURE.md and implemented a unified, keyboard-first Date & Time AlertDialog for Web/Desktop, replacing the sequential picker flow to eliminate UX friction while preserving mobile touch flows. The `useKeyboardFriendlyMaterialPickers()` path now opens `showOmniDateTimePickerDialog` (`InputDatePickerFormField` + 24h hour/minute `TextFormField`s, single Save) instead of chained `showDatePicker`→`showTimePicker`; touch/mobile still uses `showOmniDateTimePicker` from `omni_datetime_picker`.

## [2026-04-06] - Strike 14: Inbox gating & UI polish
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