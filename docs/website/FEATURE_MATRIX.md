# Life OS / Counter — Feature Matrix

**Audit date:** 2026-06-24  
**Rule:** No invented features. WIP/deferred items marked explicitly.  
**v1 site:** Filter rows using tiers in `WEBSITE_V1_SCOPE.md` — not every row gets a page.

| Feature | Screen/Area | Source files | User value | Status | Website section | Screenshot | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Day timeline list | Timeline tab | `timeline_view.dart`, `record_service.dart` | See and edit what you did each day | public-ready | Time tracking | must-have | Swipe changes day |
| Running timer / active record | Timeline | `timeline_view.dart`, `record_service.dart` | One-glance “what’s running now” | public-ready | Time tracking | must-have | Singleton stop law |
| Start/stop record (optimistic) | Timeline FAB / cards | `record_service.dart`, `app_shell.dart` | Instant feedback | public-ready | Time tracking / Offline | must-have | Core differentiator |
| Record edit sheet | Timeline / shell | `shared_widgets.dart` | Edit title, time, category, checklist, notes | public-ready | Time tracking | must-have | Unified `ActivityDetailSheet` |
| Delete record | Edit sheet | `record_service.dart` | Remove mistakes | public-ready | Time tracking | nice-to-have | Confirm dialog |
| Category auto-match on title | Start record | `category_service.dart` | Less manual categorization | public-ready | Categories | nice-to-have | Whole-word match |
| Timeline ↔ Stats toggle | Timeline tab | `timeline_view.dart`, `stats_view.dart` | Same day, two lenses | public-ready | Stats | must-have | `SegmentedButton` |
| Stats category tree | Timeline → Stats | `stats_view.dart`, `models/stats.dart` | Duration by category | public-ready | Stats | must-have | Profile TZ day scope |
| Plan vs Fact tab | Timeline → Stats | `plan_vs_fact_tab.dart` | Planned vs actual | public-ready | Stats | must-have | Basic comparison |
| Planning list cards | Plans tab | `planning_view.dart` | Daily task cards | public-ready | Planning | must-have | F2A accepted |
| Play plan → start record | Plans | `planning_view.dart`, `app_shell.dart` | Intent → tracked time | public-ready | Planning | must-have | |
| Plan done checkbox | Plans | `planning_view.dart` | Complete tasks | public-ready | Planning | nice-to-have | |
| Plan swipe by day | Plans | `planning_view.dart` | Navigate days | public-ready | Planning | nice-to-have | Required UX law |
| Time View schedule | Plans → Time mode | `plan_time_view_layout.dart`, `plan_time_task_card.dart` | Visual day schedule | public-ready (wip polish) | Planning / Time View | must-have | CHANGELOG wip drag items |
| Time View drag/resize | Plans Time mode | `planning_view.dart`, `plan_time_sequential_cascade.dart` | Move blocks | wip | Planning | nice-to-have | Market as scheduling, not “perfect DnD” |
| 5-minute snap | Time View | `UX_CONTRACT.md`, planning prefs | Practical scheduling | public-ready | Time View | nice-to-have | |
| Now line | Time View | `planning_view.dart` | Context for “right now” | public-ready | Time View | must-have | Above cards |
| Day length range slider | Plans settings | `planning_day_start_prefs.dart` | Night owl / early bird window | wip | Time View | nice-to-have | Extended −3..27h |
| Recurring plans (rrule) | Plans | `plan_service.dart` | Repeating habits | public-ready (partial) | Planning | must-have | Virtual expansion |
| Recurring series edit dialog | Plans edit | — | Edit all future instances | deferred | — | no | Not shipped |
| Virtual occurrence edit | Plans | `plan_service.dart` | Edit one day of series | public-ready | Planning | nice-to-have | Materializes + exception |
| Bulk plan edit | Plans | `bulk_planning_edit_sheet.dart` | Move many tasks | public-ready | Planning | nice-to-have | |
| Smart Plan / AI parse | Plans | `smart_plan_sheet.dart`, `plan_service.dart` | Bulk natural-language add | do-not-market-yet (v1) | — | no | Client tier not parsed; exclude v1 |
| Plan reminders | Plans / OS | `notification_service.dart` | Local nudges | public-ready | Planning | nice-to-have | Max 50 / 7 days |
| Category default plan time | Plans settings | `category_service.dart`, DATA_MAP | Faster scheduling | public-ready | Categories / Planning | nice-to-have | F2C shipped |
| Plan category filter hide | Plans | — (F2B deferred) | Hide categories from list | deferred | — | no | SharedPreferences design only |
| Lists / backlog | Lists tab | `lists_view.dart` | Inbox without calendar | public-ready | Lists | must-have | F1 shipped |
| List-domain tags | Lists | `lists_view.dart`, `profile_service.dart` | Filter backlog by tag | public-ready | Lists / Tags | must-have | |
| List done behavior | Profile | `profile_view.dart`, DATA_MAP | stay/bottom/hide/archive | public-ready | Lists | nice-to-have | |
| Export list as text | Lists menu | `lists_view.dart` | Copy list to clipboard | public-ready | Lists | nice-to-have | Not file export |
| Pin list item | Lists | — | Pin important backlog | do-not-market-yet | — | no | Needs `plans.is_pinned` |
| Calendar month view | Calendar tab | `calendar_view.dart` | Month overview | public-ready | Calendar | must-have | |
| Calendar week view | Calendar | `calendar_view.dart` | Week overview | public-ready | Calendar | nice-to-have | |
| Start from calendar task | Calendar | `calendar_view.dart`, `app_shell.dart` | Track from plan | public-ready | Calendar | nice-to-have | |
| Nested categories | More → Categories | `category_list_view.dart`, `category_recursive_tree.dart` | Life/work structure | public-ready | Categories | must-have | |
| Category create/edit/archive | Categories | `create_category_dialog.dart` | Manage taxonomy | public-ready | Categories | must-have | |
| Category visibility prefs | Categories | `category_visibility_prefs.dart` | Hide unused | public-ready | Categories | nice-to-have | |
| Tag manager (plan/list) | Profile | `tag_manager_page.dart` | CRUD tags | public-ready | Tags | must-have | |
| Tag display modes | Profile | `tag_settings_view.dart` | Visual preference | public-ready | Tags | nice-to-have | |
| Tag default duration | Profile | `tag_default_duration_settings_view.dart` | Auto block length | public-ready | Tags | nice-to-have | |
| Profile timezone | Profile | `timezone_settings.dart`, `profile_service.dart` | Correct wall days | public-ready | Security / TZ | must-have | |
| Header timezone quick switch | Global header | `timezone_quick_picker.dart`, `global_app_header.dart` | Fast TZ change | wip | Profile | nice-to-have | CHANGELOG [wip] |
| Theme + language | Profile | `profile_view.dart` | Personalization | public-ready | — | nice-to-have | |
| Biometric lock | Profile | `profile_view.dart`, `auth_bridge.dart` | App security | public-ready | Security | nice-to-have | Mobile only |
| Voice input sheet | FAB all tabs | `lib/shared/voice/ui/voice_input_sheet.dart`, `shell_voice_routing.dart` | Hands-free capture | public-ready | Voice | must-have | Tab-routed |
| Bilingual STT toggle | Voice sheet | `voice_input_sheet.dart`, ARCHITECTURE §9 | EN ↔ app language | public-ready | Voice | nice-to-have | |
| Desktop Price Reporter voice | Desktop only | `desktop_voice_command_panel.dart` (under `shared/voice/platforms/desktop/ui/`), `runtime_flags.dart` | Niche billing entry | do-not-market-yet | — | no | Kill switch default off |
| Offline record mutations | Global | `record_mutation_outbox.dart` | Works offline | public-ready | Offline | must-have | O1 |
| Offline plan/list mutations | Global | `plan_mutation_outbox.dart` | Works offline | public-ready | Offline | must-have | O1 |
| Sync / offline banner | Shell top | `app_shell.dart`, `offline_sync_state.dart` | Pending visibility | public-ready | Offline | must-have | Tap to retry |
| Auth email/password | Auth gate | `auth_view.dart`, `auth_bridge.dart` | Account access | public-ready | Security | nice-to-have | |
| OAuth Google/Yandex | Auth | `auth_view.dart`, DEPLOY.md | Quick sign-in | public-ready | Security | nice-to-have | Server-configured |
| Password reset | Auth | `auth_view.dart`, `pb_hooks/auth.*` | Account recovery | public-ready | Security | no | No screenshot of email |
| Wear OS timer | Wear app | `wear_timer_screen.dart` | Watch start/stop | needs human review | — | nice-to-have | QA status unclear |
| Web app (GitHub Pages) | Browser | DEPLOY.md, `web/` | No install | public-ready | Download | must-have | Live URL public |
| Android/iOS/desktop builds | Platforms | `android/`, `ios/`, desktop runners | Native apps | needs human review | Download | nice-to-have | No store link in repo |
| Component Lab | More (admin) | `component_lab_view.dart` | Design QA | internal-only | — | no | `is_admin` |
| Omni date+time picker | Edit sheets | `omni_date_time_picker_dialog.dart` | One-step datetime | public-ready | — | no | UX detail |
| Rich notes (Quill) | Plan edit | `shared_widgets.dart` | Long-form ideas | public-ready | Planning | nice-to-have | Save required (F3 paused) |
| Checklists | Plan/record edit | `shared_widgets.dart` | Sub-steps | public-ready | Planning | nice-to-have | |
| Record ↔ plan link | Record/plan edit | `plan_service.dart`, DATA_MAP | Plan vs fact | public-ready | Stats | nice-to-have | `source_plan_id` |
| Server overlap sanitize | Backend | `pb_hooks/records.interval_sanitize.pb.js` | Timeline integrity | public-ready (behavior) | Security | no | Don’t expose hook file |
| Realtime record sync | Background | `record_service.dart` | Multi-device | public-ready | Offline | no | When online |
| EN + RU full UI | Global | `l10n/langs/en.dart`, `ru.dart` | Localization | public-ready | — | no | |
| Partial locales (AR,DE,…) | Global | `l10n/langs/*.dart` | More languages | wip | — | no | Layered on EN |
| Pro tier badge | Profile | `profile_view.dart`, DATA_MAP | Monetization | needs human review | — | no | Policy not public |
| Attachments / files | — | ROADMAP #17 | — | out of scope | — | no | Separate project |
| F3 auto-save notes | Edit sheets | ROADMAP F3 | No lost notes | deferred | — | no | Paused |
| P0 perf experiments | Core | `runtime_flags.dart`, `shell_flags.dart` | Stability | internal-only | — | no | Kill switches |
