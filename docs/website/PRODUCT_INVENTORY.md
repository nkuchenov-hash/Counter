# Life OS / Counter — Product Inventory

**Purpose:** Authoritative inventory of real product capabilities for website planning.  
**Audit date:** 2026-06-24  
**Sources:** `docs/APP_STRUCTURE.md`, `docs/ROADMAP.md`, `docs/UX_CONTRACT.md`, `docs/DATA_MAP.md`, `docs/POCKETBASE_MANIFEST.md`, `CHANGELOG.md`, `lib/features/*`, `lib/app/shell/app_shell.dart`.

**Status legend**

| Status | Meaning for website |
| :--- | :--- |
| **public-ready** | Safe to describe and screenshot as shipped |
| **wip** | Exists in app; mention only as beta/upcoming or with caveats |
| **internal-only** | Do not market; dev/admin/diagnostics |
| **do-not-market-yet** | Unstable, gated, niche, or unverified on target platforms |

---

## 1. Timeline / time tracking

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Day-based activity timeline. Start/stop timed records with title + category. Swipe horizontally to change calendar day. Running timer shows active state. Edit/delete records via unified activity sheet. Optional checklist and notes on records. Category auto-match from title (whole-word). Stats sub-view on same tab. |
| **Proof (files/symbols)** | `lib/features/timeline/timeline_view.dart` — `TimelineSwipeWrapper`, `TimelinePage`; `lib/data/record_service.dart` — `writeRecord`, `stopRecordByDocId`, optimistic shadow; `lib/features/shared/shared_widgets.dart` — `ActivityDetailSheet`, `_TimelineRecordSheetContent`; `lib/app/shell/app_shell.dart` — `_startVoiceInput`, `_voiceSubmitTimeline` |
| **User value** | Honest log of how time was spent; instant start/stop without waiting on server; traveler-safe day bucketing via profile timezone |
| **Status** | **public-ready** |
| **Risks / caveats** | Server enforces non-overlapping intervals (singleton law). Stale-open record handling is complex — do not promise “unlimited parallel timers” for primary timeline rows. |
| **Website angle** | “Start tracking in one tap. Your day, your timezone, no lag.” |

---

## 2. Planning (list mode)

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Daily plan list with cards: checkbox done, play-to-track, tags, category, time, recurring icon, rich notes, checklist. Swipe between days. Bulk selection/edit. Plan reminders (local notifications). Link records to plans (plan vs fact). *(Smart Plan / AI batch add exists in app — **exclude from v1 website**; see §21.)* |
| **Proof** | `lib/features/planning/planning_view.dart` — `PlanningPage`, `PlanningSwipeWrapper`; `lib/features/planning/smart_plan_sheet.dart`; `lib/features/planning/bulk_planning_edit_sheet.dart`; `lib/data/plan_service.dart` — CRUD, rrule expansion, alarms |
| **User value** | Plan the day as real cards, then turn intent into tracked time with play |
| **Status** | **public-ready** (F2A/F2C accepted per roadmap) |
| **Risks / caveats** | Notes require explicit Save today (F3 auto-save paused). Full recurring *series* edit-scope dialog not shipped — virtual occurrence edit materializes one-off + `exception_dates`. F2B category filter deferred. |
| **Website angle** | “Plans that look like your day — not a spreadsheet.” |

---

## 3. Planning — Time View

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Scheduled plan blocks on a vertical time canvas. Drag, resize, 5-minute snap. Density-aware cards (micro → large). “Now” line in profile timezone. Configurable visible day length (extended hours, including after midnight). Sequential cascade when blocks overlap. |
| **Proof** | `lib/features/planning/plan_time_view_layout.dart` — `TimeViewYScale`; `lib/core/widgets/plan_time_task_card.dart` — `PlanTimeTaskCard`; `lib/shared/time/plan_time_visible_window.dart`; `lib/data/plan_time_sequential_cascade.dart`; `docs/UX_CONTRACT.md` § Planning Time Mode |
| **User value** | See plan vs clock at a glance; block scheduling that respects real wall time |
| **Status** | **public-ready** with **wip** polish (CHANGELOG: many P0 Time View entries still `[wip]`) |
| **Risks / caveats** | Drag/drop/target-insert behavior actively refined — screenshots should use stable, simple schedules. Do not overclaim pixel-perfect Google Calendar parity. |
| **Website angle** | “Time View: your plan as a real schedule, not a todo dump.” |

---

## 4. Lists / backlog (Inbox)

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Backlog/list items (plans with list domain). Category + list-tag filters. Done toggle with configurable behavior (stay / bottom / hide / archive). Export visible list as numbered text to clipboard. No play on list cards (start stays in Planning). |
| **Proof** | `lib/features/lists/lists_view.dart` — `ListsPage`; `lib/data/plan_service.dart` — `fetchBacklogPlans`; `docs/ROADMAP.md` F1 ✅ |
| **User value** | Capture ideas and errands separately from the calendar plan; tag and filter without starting a timer |
| **Status** | **public-ready** |
| **Risks / caveats** | **Pin important items** not shipped — needs `plans.is_pinned` in PocketBase (`lists_pin_item_todo` in l10n). |
| **Website angle** | “Lists for everything you’re not scheduling yet.” |

---

## 5. Calendar

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Month and week calendar browsing. Day indicators for planned tasks. Focused-day task list. Open edit sheet; start record from task. |
| **Proof** | `lib/features/calendar/calendar_view.dart` — `CalendarView`, `_CalendarViewMode.month/week` |
| **User value** | Month-at-a-glance planning without leaving the app shell |
| **Status** | **public-ready** |
| **Risks / caveats** | Adjacent-month overflow days (#19) deferred — cosmetic only. |
| **Website angle** | “Calendar that reads your plan, not a separate product.” |

---

## 6. Stats

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Hierarchical project/category time statistics for the selected waking day inside Timeline. Expand categories into grouped tasks and individual tracked sessions. |
| **Proof** | `lib/features/stats/stats_view.dart` — `StatsView`; `lib/features/stats/stats_detail_tree.dart` — `StatsDetailTree`; `lib/data/category_service.dart` — stats aggregation/duration helpers |
| **User value** | See where tracked time actually went across projects and categories |
| **Status** | **public-ready** |
| **Risks / caveats** | Stats respect profile timezone and wake-to-bed boundaries; this is intentionally a focused time breakdown, not a reporting/export dashboard. |
| **Website angle** | “See where your time went.” |

---

## 7. Categories

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Nested category tree. Custom color, icon, order. Archive. Per-category default plan start time and optional timezone. Visibility prefs. Fuzzy title match when starting records. Breadcrumb display on cards. |
| **Proof** | `lib/features/settings/categories/category_list_view.dart`, `create_category_dialog.dart`; `lib/shared/categories/picker/category_tree_picker.dart`; `lib/data/category_service.dart`; `categories.default_plan_time` in `docs/DATA_MAP.md` |
| **User value** | Structure life/work projects; consistent color language across timeline and plans |
| **Status** | **public-ready** |
| **Risks / caveats** | Category hash collision bug fixed — no need to mention. Cold-start category map drops are logged, not user-facing. |
| **Website angle** | “Your categories, nested the way you think.” |

---

## 8. Tags

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Separate tag catalogs for **plan** vs **list** domains. Tag manager, colors/icons, sort order. Display modes (chip, letter, icon, etc.). Per-tag default plan duration. Filter strips on Planning and Lists. |
| **Proof** | `lib/features/profile/tag_manager_page.dart`, `tag_settings_hub.dart`, `tag_default_duration_settings_view.dart`; `lib/data/profile_service.dart`; `lib/core/widgets/chip_component.dart` |
| **User value** | Fast filtering and metadata without rebuilding categories |
| **Status** | **public-ready** |
| **Risks / caveats** | Legacy empty `domain` rows treated as `plan`. |
| **Website angle** | “Tags for plan tasks and list items — kept separate on purpose.” |

---

## 9. Profile, timezone & settings

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Display name, email, theme (light/dark/system), primary language. Timezone + offset (drives all wall-clock views). Biometric app lock and biometric sign-in (mobile). Notification permission for plan reminders. List completion behavior. Tag display preferences. |
| **Proof** | `lib/features/profile/profile_view.dart`, `timezone_settings.dart`; `lib/data/profile_service.dart` — `getProjectedToday`, `updateTimeZone`, `saveSettings`; `lib/core/widgets/global_app_header.dart` + `timezone_quick_picker.dart` |
| **User value** | One profile timezone for travelers; settings that affect planning and stats consistently |
| **Status** | **public-ready** (header timezone quick switcher marked `[wip]` in CHANGELOG but present in code — **needs human review** for marketing copy) |
| **Risks / caveats** | `tier` (`free`/`pro`) exists — AI parse may be server-gated; do not promise Pro features without product decision. |
| **Website angle** | “Built for people who cross timezones — not device local time.” |

---

## 10. Voice input (mobile / web FAB)

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Mic FAB opens speech-to-text sheet. Routes by active tab: timeline record, planning task, or list item. Bilingual STT toggle (app language ↔ English). Transcript editable before submit. |
| **Proof** | `lib/shared/voice/ui/voice_input_sheet.dart`; `lib/app/shell/shared/shell_voice_input.dart`; `docs/ARCHITECTURE.md` § Voice Input Protocol |
| **User value** | Capture tasks and time entries hands-free |
| **Status** | **public-ready** |
| **Risks / caveats** | Web STT depends on browser speech APIs; permissions required on mobile. |
| **Website angle** | “Talk to your day — voice becomes a plan or a time entry.” |

---

## 11. Desktop structured voice command (Price Reporter)

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Desktop-only panel: parse “Price Reporter / {client} / {task}” into a timeline record. Global hotkey Ctrl+Shift+Space when enabled. |
| **Proof** | `lib/data/voice/voice_command_parser.dart`, `lib/features/voice/desktop_voice_widget.dart`; `lib/shared/voice/platforms/desktop/desktop_voice_hotkey.dart`; `kDesktopVoiceCommandEnabled` default **false** |
| **User value** | Power-user billing/time entry for one workflow |
| **Status** | **do-not-market-yet** (kill switch off by default; niche; June 2026 MVP) |
| **Risks / caveats** | Requires `--dart-define=DESKTOP_VOICE_COMMAND=true`. Not general-audience. |
| **Website angle** | Exclude from public site unless product opens desktop pro niche. |

---

## 12. Offline-first & sync banner

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Start/stop/edit/delete records offline. Create/update/delete/toggle plans and lists offline. Pending mutations queue locally; flush on reconnect, boot, resume, tap banner. States: offline pending, syncing, auth paused. |
| **Proof** | `lib/data/local_sync/*`; `lib/app/shell/shared/offline_sync_status_bar.dart`; `docs/ROADMAP.md` O1 ✅ |
| **User value** | App stays usable on bad connectivity; actions feel instant |
| **Status** | **public-ready** |
| **Risks / caveats** | Outbox is device-global (single-user-per-device assumption). Virtual recurring edits need network. Bulk plan ops not fully offline. Optimistic overlays lost on process death until replay. |
| **Website angle** | “Offline-first: your tap counts even when the network doesn’t.” |

---

## 13. Auth & account security

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Email/password sign-in and registration. OAuth Google and Yandex when configured on server. Password reset (custom PB hook + fallback). Session restore. Auth-paused sync routes to login. |
| **Proof** | `lib/features/auth/auth_view.dart`; `lib/data/auth_bridge.dart`; `pb_hooks/auth.request_password_reset.pb.js`; `docs/DEPLOY.md` |
| **User value** | Standard account with OAuth option; no vendor lock-in narrative needed |
| **Status** | **public-ready** |
| **Risks / caveats** | Android OAuth on real devices needs verification per DEPLOY.md. OTP login not implemented. Do not publish PocketBase host URL or OAuth secrets. |
| **Website angle** | “Sign in on web or phone — your data syncs through your account.” |

---

## 14. Biometrics

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Optional biometric unlock on launch; optional “sign in with biometrics” after email login. Toggle in Profile when device supports it. |
| **Proof** | `lib/features/profile/profile_view.dart`; `AuthBridge.canUseBiometricAuth`; `profiles.biometric_enabled` in DATA_MAP |
| **User value** | Faster return to tracking on personal devices |
| **Status** | **public-ready** (mobile; not web) |
| **Risks / caveats** | Hidden when biometrics unavailable. |
| **Website angle** | Mention under Security — mobile only. |

---

## 15. Wear OS companion

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Watch UI: view active record, elapsed time, category headline; start with category picker; stop. Wear-lite bootstrap on watch. |
| **Proof** | `lib/features/wear/wear_timer_screen.dart`, `wear_main_wrapper.dart`; `lib/data/db_core.dart` — `loadInitialDataWearLite` |
| **User value** | Start/stop without pulling out phone |
| **Status** | **needs human review** — code exists; marketing should confirm Play Store / device QA status |
| **Risks / caveats** | Phone↔watch bridge via platform channel; not full Planning UI on watch. |
| **Website angle** | Optional “Works with Wear OS” if QA confirms. |

---

## 16. Component Lab / design system

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Admin-only screen showing canonical `AppButton`, `AppIconButton`, `LifeCard`/`AppTaskCard` demos. Gated by `profiles.is_admin`. |
| **Proof** | `lib/features/dev/component_lab_view.dart`; `docs/DESIGN_SYSTEM.md` |
| **User value** | Internal design QA only |
| **Status** | **internal-only** |
| **Website angle** | Do not show. May reference “consistent design system” without lab. |

---

## 17. PocketBase backend (user-relevant behavior)

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Self-hosted sync backend. Multi-device realtime on records (when online). Server prevents overlapping time intervals. Per-user data isolation. Plan–record linking for analytics. |
| **Proof** | `docs/POCKETBASE_MANIFEST.md`; `pb_hooks/records.interval_sanitize.pb.js`; `lib/data/record_service.dart` realtime |
| **User value** | Data ownership narrative; reliable timeline integrity across devices |
| **Status** | **public-ready** at behavior level — **do not** expose infra URLs, VPS IP, or admin paths |
| **Risks / caveats** | Not a consumer “PocketBase” product — frame as “secure sync” or “your account.” |
| **Website angle** | “Syncs securely. Your timeline stays consistent across devices.” |

---

## 18. Platforms & distribution

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | **Web:** live PWA-style app at GitHub Pages (`/Counter/`). **Build targets:** Android, iOS, Windows, macOS, Linux, Wear OS per `docs/ROADMAP.md`. |
| **Proof** | `docs/DEPLOY.md`; `pubspec.yaml` dependencies; `lib/core/shell_adaptive.dart` |
| **User value** | Use in browser immediately; native shells for mobile/desktop |
| **Status** | **public-ready** for web; **needs human review** for APK/App Store availability and download CTAs |
| **Risks / caveats** | Web build uses `--no-tree-shake-icons` workaround. No public APK link verified in repo docs. |
| **Website angle** | Primary CTA: “Open web app.” Secondary: waitlist or store links when ready. |

---

## 19. Localization

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Full EN + RU UI strings. Partial AR, DE, ES, FR, IT, KO, ZH layered on English. Category localized names. STT bilingual toggle. |
| **Proof** | `lib/l10n/langs/en.dart`, `ru.dart`; `lib/l10n/app_locales.dart` |
| **User value** | Russian/English primary audiences; growing locale coverage |
| **Status** | **public-ready** for EN/RU; partial locales **wip** |
| **Website angle** | “English and Russian today — more languages in the app.” |

---

## 20. Plan reminders & notifications

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Per-plan `reminder_offset` schedules local OS notifications (up to 50 in 7-day window). Permission prompt in profile flow. |
| **Proof** | `lib/services/notification_service.dart`; `plans.reminder_offset` in DATA_MAP |
| **User value** | Nudge before scheduled blocks |
| **Status** | **public-ready** |
| **Risks / caveats** | Local notifications only — not push from server. |
| **Website angle** | “Reminders before planned blocks — on your device.” |

---

## 21. AI-assisted planning input (Smart Plan)

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Smart Plan sheet calls `POST /api/ai/parse-task` (`parsePlanningItemsViaAiBackend`) for batch plan items from natural language. |
| **Proof** | `lib/features/planning/smart_plan_sheet.dart`; `lib/data/plan_service.dart` — `parsePlanningItemsViaAiBackend` |
| **User value** | Faster bulk plan entry for power users |
| **Status** | **do-not-market-yet** on v1 — `profiles.tier` in DATA_MAP but **not parsed in client**; `pro_badge_*` l10n unused; server tier rules not verified in repo |
| **Risks / caveats** | Requires live AI route; failure modes silent/null in some paths |
| **Website angle** | **Exclude** from v1. Revisit after owner defines Pro story (`WEBSITE_CLAIMS_REVIEW.md`). |

---

## 22. Rich notes & checklists

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Quill rich notes on plans (`notes_delta`). Checklists on plans and records. Plan list link metadata in notes. |
| **Proof** | `lib/features/shared/shared_widgets.dart` — `_PlanningTaskEditSheet`; `flutter_quill` in pubspec |
| **User value** | Ideas and sub-steps live on the card |
| **Status** | **public-ready** with caveat: notes may require Save (F3 auto-save not shipped) |
| **Website angle** | “Notes and checklists on the same card as the task.” |

---

## 23. Recurring plans

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | RFC 5545 `rrule` on plan rows; client expands virtual occurrences; exception dates; repeat icon on cards; edit one occurrence materializes exception. |
| **Proof** | `lib/data/plan_service.dart` — `expandRecurringPlans`; DATA_MAP `rrule`, `exception_dates` |
| **User value** | Weekly/daily habits without duplicate rows |
| **Status** | **public-ready** (partial — no full series edit dialog) |
| **Risks / caveats** | Virtual occurrence flows need network for some edits. |
| **Website angle** | “Repeating plans — one series, many days.” |

---

## 24. Performance & responsiveness (product promise)

| Field | Detail |
| :--- | :--- |
| **User-facing capability** | Optimistic UI: start/stop/create/update reflect in &lt;100ms. No full-screen reload on small edits. Date swipe on Timeline/Planning. |
| **Proof** | `docs/UX_CONTRACT.md`; `docs/ARCHITECTURE.md` § PERFORMANCE_KILL_SWITCH_LAW |
| **User value** | Feels instant — core differentiator |
| **Status** | **public-ready** as design promise; internal kill switches are **internal-only** |
| **Website angle** | Lead strength: “Fast local UI first — sync catches up quietly.” |

---

## Summary counts

| Status | Areas |
| :--- | :--- |
| **public-ready** | Timeline, Planning list, Time View*, Lists, Calendar, Stats, Plan vs Fact, Categories, Tags, Profile/TZ, Voice FAB, Offline sync, Auth, Biometrics, Notifications, Recurring*, Rich notes, Platforms (web), EN/RU l10n, Performance promise |
| **wip** | Time View drag polish, header TZ quick picker, partial locales, recurring series dialog |
| **needs human review** | Wear OS marketing, AI/tier gating, download/APK CTAs, header TZ picker ship status |
| **internal-only** | Component Lab, P0/P0U diagnostics, kill switches, admin flags |
| **do-not-market-yet** | Desktop Price Reporter voice, export scripts, multi-account outbox gap |

\*Ship with caveats in copy.
