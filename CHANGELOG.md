# 📖 DEV_JOURNAL (Changelog)

> **WARNING FOR AI:** Read the latest entries to understand what features are ALREADY built and do not need to be recreated.

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
