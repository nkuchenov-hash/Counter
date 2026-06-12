# Design System Inventory

Snapshot date: 2026-06-11.

Purpose: identify current raw/local UI so V7 can migrate screens toward canonical Flutter components without redesigning product flows during inventory work.

## Classification Legend

- **Allowed inside canonical component:** Material primitive used to implement a shared component in `lib/core/widgets/` or approved shared UI.
- **Forbidden in feature screen:** New feature code should not add this directly when a canonical component already exists.
- **Legacy allowed temporarily:** Existing feature-local UI may remain until a scoped V7 migration.
- **Needs migration:** Existing UI should be moved behind a canonical component.

## V7E Action Button Migration Pass

Date: 2026-06-11.

### What Changed

- `AppButton` remains the canonical Flutter component name for Figma `Button`.
- `AppButton` now supports primary, secondary, danger/destructive, ghost, and outlined variants.
- `AppButton` now supports `AppButtonSize.s`, `AppButtonSize.m`, and `AppButtonSize.l`.
- `AppButton` now supports icon + label, loading, disabled, content-width, and `fullWidth: true`.
- Backwards compatibility preserved for existing `AppButton.primary`, `secondary`, `outlined`, `destructive`, and `expand`.

### Files Migrated

| File | Migration |
| :--- | :--- |
| `lib/core/widgets/app_state_views.dart` | `AppErrorState` retry action now uses `AppButton.secondary`. |
| `lib/core/widgets/confirm_dialog.dart` | Standard confirm/cancel actions now use `AppButton` variants. |
| `lib/features/planning/planning_view.dart` | Safe F2C default-time sheet Set/Clear actions now use `AppButton.secondary` / `AppButton.ghost`; risky icon-only and long-label picker controls were left alone. |

### Component Lab Examples Added

`lib/features/dev/component_lab_view.dart` now shows:

- Primary enabled, disabled, loading.
- Secondary enabled, disabled, loading.
- Danger/destructive enabled, disabled, loading.
- Ghost button.
- Outlined button.
- Icon + label button.
- Small, medium, large sizes.
- Content-width and full-width examples.

### V7E.1 Component Lab Labels

- Component Lab examples are now labeled for review with Figma/design-system name, Flutter mapping, variant, size, and state metadata where applicable.
- Labeling lives only in the lab/demo wrapper and does not change production UI.

### Raw Button Audit After Migration

Search target: `ElevatedButton`, `FilledButton`, `OutlinedButton`, `TextButton`, `IconButton`.

| Category | Remaining examples | Status |
| :--- | :--- | :--- |
| Allowed inside canonical component | `lib/core/widgets/app_button.dart`; `omni_date_time_picker_dialog.dart` date/time picker actions | Allowed inside canonical component / native Material surface. |
| Allowed icon-only navigation/control | `IconButton` in app bars, menus, search delegates, timeline/planning controls, category tree controls | Allowed until an `AppIconButton` exists. |
| Legacy allowed temporarily | Auth/profile buttons, inline dialog buttons, sheet actions, category create/edit actions, voice input actions, Wear controls | Leave for focused follow-up passes. |
| Still needs migration later | Feature-screen raw `FilledButton`, `OutlinedButton`, `TextButton` for non-timer app actions | Migrate incrementally to `AppButton`. |

No `ElevatedButton` usages were found.

### Intentionally Left For Later

- Timer Start/Stop controls.
- Plan play/start controls.
- Timeline active record controls.
- Complex gesture controls.
- Icon-only navigation/control buttons.
- Date/time picker buttons with native Material behavior.
- Tabs, segmented controls, chips/tags, and cards.
- Auth and biometric flows.
- Complex sheet save/delete/cancel flows that need UX contract review before migration.

### Next Recommended Migration Pass

V7F should introduce or define `AppIconButton` before touching icon-heavy navigation/control surfaces, or migrate confirm dialogs broadly to `showConfirmDialog` if the next goal is low-risk action cleanup.

## V7F Icon Button Foundation

Date: 2026-06-11.

### What Changed

- `AppIconButton` was created in `lib/core/widgets/app_icon_button.dart` as the canonical Flutter component for Figma `Icon Button`.
- `AppIconButton` supports standard, subtle, filled, and danger variants.
- `AppIconButton` supports `AppIconButtonSize.s`, `AppIconButtonSize.m`, and `AppIconButtonSize.l`.
- `AppIconButton` supports required tooltip/accessibility label, selected state, disabled state, and a simple loading state.
- No production `IconButton` migration was done in V7F.

### Component Lab Examples Added

`lib/features/dev/component_lab_view.dart` now shows labeled `AppIconButton` examples for:

- Standard enabled and disabled.
- Subtle enabled.
- Filled enabled.
- Danger enabled and disabled.
- Selected state.
- Loading state.
- Small, medium, and large sizes.
- Navigation/control, inline action, and destructive action examples.

### Raw IconButton Audit

Search target: `IconButton(`.

| Category | Representative files | Approx. count | Status |
| :--- | :--- | :--- | :--- |
| Allowed inside canonical component | `lib/core/widgets/app_icon_button.dart` | 1 | Allowed implementation detail. |
| App bars / navigation | `category_list_view.dart`, search delegate controls in `planning_view.dart`, `timeline_widgets.dart` | ~8 | Legacy allowed temporarily. |
| Inline controls | `shared_widgets.dart`, `lists_view.dart`, `tag_manager_page.dart`, `smart_plan_sheet.dart` | ~13 | Future safe migration candidates after visual review. |
| Timeline controls | `timeline_view.dart`, `timeline_widgets.dart`, timeline edit areas in `shared_widgets.dart` | ~4 | Intentionally risky; preserve until timer/timeline control pass. |
| Planning controls | `planning_view.dart`, `smart_plan_sheet.dart` | ~14 | Intentionally risky around plan play/start, search, selection, and row controls. |
| Category tree / category management controls | `category_recursive_tree.dart`, `category_list_view.dart` | ~8 | Candidate for a focused category UI pass. |
| Sheet actions | `shared_widgets.dart`, `voice_input_sheet.dart` | ~6 | Legacy until sheet chrome/controls are migrated together. |
| Destructive actions | `lists_view.dart`, `planning_view.dart`, category management files | mixed into counts above | Must keep existing confirm/destructive behavior until reviewed. |

Production raw `IconButton(` usage is approximately 41 call sites. This count excludes the single raw `IconButton` used inside `AppIconButton`.

### Intentionally Left For Later

- Timer Start/Stop controls.
- Plan play/start controls.
- Active timeline controls.
- Search delegate leading/clear buttons.
- Selection mode controls.
- Category tree expand/edit/visibility controls.
- Sheet-local controls and voice input controls.
- Auth field suffix icon controls.

### Next Recommended Migration Pass

V7G can migrate a small low-risk icon-action surface, such as admin-only/dev surfaces or non-timer settings/navigation icon actions, after visual acceptance of `AppIconButton` in Component Lab.

## V7F.2 Safe Icon Button Migration

Date: 2026-06-11.

### Files Migrated

| File | Icon actions migrated | Notes |
| :--- | :--- | :--- |
| `lib/features/categories/category_list_view.dart` | Categories AppBar layout toggle and Add Category actions | Both were simple non-destructive category/settings helper actions. Existing icons, tooltips, callbacks, and enabled behavior were preserved. |

### Candidate Decisions

| Area | Decision | Reason |
| :--- | :--- | :--- |
| Categories AppBar layout toggle | Migrated | Simple local UI toggle, not timer/planning/timeline/search/selection/voice. |
| Categories AppBar add category | Migrated | Simple category helper action with existing `unawaited(_addRule())` callback. |
| Category tile gear/visibility controls | Skipped | Compact tile layout uses custom hit target and shrink-wrap styling. |
| Category recursive tree controls | Skipped | Category tree expand/add/appearance/settings controls are interaction-dense. |
| Lists selection/export/menu controls | Skipped | Selection mode, destructive, or list-card controls. |
| Planning controls | Skipped | Planning/search/selection/play-adjacent surfaces are risky. |
| Shared sheet, timeline, voice, auth, and tag manager controls | Skipped | Sheet/timeline/voice/auth/destructive inline areas need focused passes. |

### Raw IconButton Count After Migration

- Raw `IconButton(` inside `AppIconButton`: 1 allowed implementation detail.
- Production raw `IconButton(` usage after V7F.2: approximately 39 call sites.
- Migration is not complete; remaining raw icon actions are legacy allowed temporarily.

### Intentionally Left For Later

- Timer Start/Stop controls.
- Plan play/start controls.
- Active timeline controls.
- Search delegate leading/clear buttons.
- Selection mode controls.
- Voice controls.
- Date/time picker controls.
- Gesture-heavy or compact custom-hit-target controls.
- Destructive inline actions until their confirm/recovery behavior is reviewed.

## Edit Sheet Tag Strip Scroll Hotfix

Date: 2026-06-12.

| File | Fix | Notes |
| :--- | :--- | :--- |
| `lib/features/shared/chip_component.dart` | `TagQuickPickStrip` scroll | Removed `shrinkWrap` (root cause of clipped unscrollable row); `ScrollController` + mouse drag + wheel horizontal scroll. |
| `lib/features/shared/chip_component.dart` | Pill sizes | Compact card ~22px; edit-sheet interactive ~31px (not 40px). |
| `lib/features/shared/shared_widgets.dart` | `_PlanningTaskEditSheet` tag row | Finite height; same `TagQuickPickStrip`. |
| `lib/features/planning/planning_view.dart` | Quick-add tag strip | Same shared strip. |

## Design Lab Copy + Interactive Tag Selected State Hotfix

Date: 2026-06-12.

| File | Fix | Notes |
| :--- | :--- | :--- |
| `lib/features/dev/component_lab_view.dart` | Selectable lab labels/specs | Lab-only `SelectableText` for section titles, metadata, labels, and placeholder copy. Production UI remains unchanged. |
| `lib/features/dev/component_lab_view.dart` | Chip examples | Added separate interactive selected/unselected examples and selected-state rule copy. |
| `lib/features/shared/chip_component.dart` | Interactive tag selected state | Normal chip fill/text/border remains unchanged; selected adds visible 2px transparent gap + 2px brand border outside the normal chip. |
| `lib/features/shared/chip_component.dart` | Interactive tag alignment | Tag content stays centered; selected ring does not move inner text. |
| `lib/features/shared/shared_widgets.dart` / `lib/features/planning/planning_view.dart` | Tag strip height | 40px row to fit 31px base pill + 39px selected total height without clipping. |

## P0 Startup Sync + Tag Pill Regression Fix

Date: 2026-06-12.

### Sync / Runtime Fixes

| File | Fix | Notes |
| :--- | :--- | :--- |
| `lib/data/db_core.dart` | `refreshForegroundData()` on app resume + post-boot plan cache notify | Force network records + plans for today; no user input required to refresh UI. |
| `lib/data/plan_service.dart` | `notifyPlanningRefresh(pumpNetworkNow:)` + debounced fetch re-ping | Planning streams no longer stall on 30s TTL stale cache after server updates. |
| `lib/data/record_service.dart` | `_reconcileDuplicatePrimaryRunningRecords()` + canonical primary picker | Sacred singleton: newest running primary wins; older open primaries stopped via existing stop path. |
| `lib/features/timeline/timeline_view.dart` | Running card state gated by `canonicalPrimaryRunningBusinessId` | Prevents duplicate running visuals when cache briefly has multiple open primaries. |

### Tag UI Fixes

| File | Fix | Notes |
| :--- | :--- | :--- |
| `lib/features/shared/chip_component.dart` | `CategoryChipVariant.compactCard` vs `largePicker` stadium pills | Compact cards smaller; edit-sheet/menu/picker pills larger; parent owns spacing; no outer invisible pill margin. |
| `lib/features/shared/chip_component.dart` | `TagQuickPickStrip` horizontal `ListView` scroll | Edit-sheet tag rows scroll horizontally again (web + touch). |
| `lib/features/shared/shared_widgets.dart` | Edit sheet tag row height tuned for interactive pills | Visual only. |
| `lib/features/dev/component_lab_view.dart` | Lab examples for compact vs interactive tag pills + scroll strip | Lab-only labels. |

## V7G.1 Canonical State Views Migration

Date: 2026-06-12.

### Files Migrated

| File | State views migrated | Notes |
| :--- | :--- | :--- |
| `lib/features/lists/lists_view.dart` | `lists_no_category_chosen` and `lists_empty` local text blocks → `AppEmptyState` | Static Lists informational/empty states only; loading, filtering, refresh, and list behavior unchanged. |
| `lib/features/profile/tag_manager_page.dart` | `tag_manager_empty` local text block → `AppEmptyState` | Static empty tag catalog state only; tag CRUD and reorder behavior unchanged. |
| `lib/features/stats/plan_vs_fact_tab.dart` | `no_data_found` fallback → `AppErrorState`; no-plan/no-fact state → `AppEmptyState` | Non-critical stats surface only; stats load/reload behavior unchanged. |
| `lib/features/planning/planning_view.dart` | simple `no_data_found` fallback blocks → `AppErrorState` | Fallback display only; planning stream, task rendering, quick-add, and empty planning CTA unchanged. |
| `lib/features/calendar/calendar_view.dart` | simple `no_data_found` fallback block → `AppErrorState` | Calendar catch fallback display only; date selection behavior unchanged. |

### State Views Migrated

- Loading: no new production loading migrations were needed; existing safe page loaders already used `AppLoading`.
- Empty: Lists no-category, Lists empty-list, Tag Manager empty catalog, and Plan vs Fact no-data day.
- Error: Planning simple fallback errors, Calendar simple fallback error, and Plan vs Fact null-data fallback.

### Legacy State Categories Remaining

- `EmptyStatePlaceholder` remains for richer title/subtitle/action states in timeline, planning, and category management because `AppEmptyState` currently accepts one message plus optional action and would flatten existing UX copy.
- Raw `CircularProgressIndicator` / `LinearProgressIndicator` remains in canonical component internals, app boot/auth, profile setting save affordances, voice/recording, complex sheet flows, and planning inline progress areas.
- Timeline error text remains legacy because the timeline surface is timer-adjacent and should be reviewed with active-record controls.

### Risky Areas Intentionally Skipped

- App boot / auth gate loading.
- Login/register/auth screens.
- Profile refresh/save/admin diagnostics.
- Timer active state and active timeline controls.
- Voice/recording flows.
- Date/time picker and complex modal/sheet flows.
- Inline planning parse/save progress where loading participates in row/sheet layout.

### Approximate Remaining Raw State Count

- Raw `CircularProgressIndicator` / `LinearProgressIndicator` search hits after V7G.1: approximately 10 outside docs/comments, including canonical internals and skipped risky areas.
- Remaining local simple `no_data_found` text blocks found in feature screens: 2, both in `lib/features/timeline/timeline_view.dart` and intentionally skipped.
- Migration is not complete; remaining raw/local states are legacy allowed temporarily until scoped follow-up passes.

## Raw Widget Usage Summary

Representative search targets: `ElevatedButton`, `FilledButton`, `OutlinedButton`, `TextButton`, `IconButton`, `Card`, `RawChip`, `Chip`, `FilterChip`, `ChoiceChip`, `TabBar`, `SegmentedButton`.

| Area | Representative files | Classification | Notes |
| :--- | :--- | :--- | :--- |
| Canonical buttons | `lib/core/widgets/app_button.dart` | Allowed inside canonical component | `AppButton` wraps `FilledButton`, `FilledButton.tonal`, and `OutlinedButton`. |
| Canonical state views | `lib/core/widgets/app_state_views.dart`, `lib/core/widgets/app_loading.dart` | Allowed inside canonical component | `AppErrorState`, `AppEmptyState`, `AppLoading` are current canonical state surfaces. |
| Canonical compact labels | `lib/core/widgets/compact_nav_controls.dart` | Allowed inside canonical component | Current compact tab/segment labels; future `AppSegmentedTabs` should absorb broader behavior. |
| Shared chips | `lib/features/shared/chip_component.dart` | Legacy allowed temporarily | `CategoryChip`, `TagQuickPickStrip`, `CategoryBreadcrumb` are shared but live in `features/shared/`; future V7 may promote canonical chip APIs. |
| Feature buttons | `planning_view.dart`, `shared_widgets.dart`, `lists_view.dart`, `category_list_view.dart`, `profile_view.dart`, `auth_view.dart`, `tag_manager_page.dart` | Needs migration | Raw Material buttons exist in feature screens. Do not add new raw duplicates when `AppButton` can express the action. |
| Canonical icon buttons | `lib/core/widgets/app_icon_button.dart` | Allowed inside canonical component | `AppIconButton` wraps one raw `IconButton` and owns variants, size, selected, disabled, loading, tooltip, and danger state. |
| Feature icon actions | Most feature screens | Legacy allowed temporarily | Raw `IconButton` is widely used for app bars, menus, inline actions. Future V7 passes should migrate scoped low-risk surfaces to `AppIconButton`. |
| Feature cards | `timeline_view.dart`, `planning_view.dart`, `lists_view.dart`, `category_list_view.dart` | Needs migration | Cards are heavily domain-shaped; migrate through `LifeCard` / `AppTaskCard` rather than one-off replacements. |
| Feature chips / filters | `lists_view.dart`, `planning_view.dart`, `category_recursive_tree.dart`, `tag_manager_page.dart` | Needs migration | Filter/category/tag controls should converge on canonical chip APIs. |
| Tabs / segmented controls | `planning_view.dart`, `shared_widgets.dart`, `compact_nav_controls.dart` | Needs migration | Compact labels exist; segment containers still need canonical ownership. |
| Loading / empty / error | `planning_view.dart`, `shared_widgets.dart`, `profile_view.dart`, `auth_view.dart`, `timeline_view.dart`, `lists_view.dart` | Needs migration | Several surfaces still use raw `CircularProgressIndicator` or local empty/error text. |

## Custom Local Classes Found

| Current local UI | File | Classification | Future canonical component |
| :--- | :--- | :--- | :--- |
| `_PlanningTaskCard` | `lib/features/planning/planning_view.dart` | Needs migration | `AppTaskCard` or `LifeCard.task` |
| `_BacklogPlanCard` | `lib/features/lists/lists_view.dart` | Needs migration | `AppTaskCard` or `LifeCard.task` |
| `_TimelineRecordCard` | `lib/features/timeline/timeline_view.dart` | Needs migration | `AppTimelineCard` or `LifeCard.timeline` |
| `_ListsQuadraticChip` | `lib/features/lists/lists_view.dart` | Needs migration | `AppCategoryChip` / `AppFilterChip` |
| `CategoryChip` | `lib/features/shared/chip_component.dart` | Legacy allowed temporarily | `AppCategoryChip` |
| `TagQuickPickStrip` | `lib/features/shared/chip_component.dart` | Legacy allowed temporarily | `AppTagPickerStrip` |
| `CategoryBreadcrumb` | `lib/features/shared/chip_component.dart` | Legacy allowed temporarily | `AppBreadcrumbChip` |
| `AppCompactSegmentLabel` | `lib/core/widgets/compact_nav_controls.dart` | Allowed inside canonical component | Keep or fold into `AppSegmentedTabs` |
| `AppCompactTextTab` | `lib/core/widgets/compact_nav_controls.dart` | Allowed inside canonical component | Keep or fold into `AppSegmentedTabs` |
| `_ParallelActivitiesTab` | `lib/features/shared/shared_widgets.dart` | Legacy allowed temporarily | Domain tab content; chrome should migrate to `AppSegmentedTabs` / canonical sheets |

## Proposed Mapping

| Current local UI | Future canonical component |
| :--- | :--- |
| `AppButton` | Keep and upgrade as `AppButton`, or rename to `AppActionButton` only with a planned migration |
| Raw `FilledButton` / `OutlinedButton` / `ElevatedButton` / `TextButton` in feature screens | `AppButton` variants |
| Raw `IconButton` in feature screens | `AppIconButton` variants |
| Raw danger buttons with `scheme.error` | `AppButton.destructive` |
| `_PlanningTaskCard` / `_BacklogPlanCard` | `AppTaskCard` or `LifeCard.task` |
| `_TimelineRecordCard` | `AppTimelineCard` or `LifeCard.timeline` |
| Raw `Card` wrappers for repeated domain cards | `LifeCard` |
| `TagChip` / `CategoryChip` variants / `TagQuickPickStrip` | `AppTagChip`, `AppCategoryChip`, `AppTagPickerStrip` |
| `_ListsQuadraticChip` and filter chips | `AppFilterChip` / `AppCategoryChip` |
| Custom segment controls and tab labels | `AppSegmentedTabs` |
| `GlobalAppHeader` variants | `AppShellHeader` or upgraded `GlobalAppHeader` variants |
| Raw `CircularProgressIndicator` in feature screens | `AppLoading` |
| Local empty/error blocks | `AppEmptyState` / `AppErrorState` |
| Sheet header/footer chrome in feature sheets | `AppSheetScaffold` |
| Search/time/text field copies | `AppTextField`, `AppSearchField`, Omni-Picker-backed time/date inputs |

## Safe Now

- `AppButton`, `AppIconButton`, `AppLoading`, `AppEmptyState`, `AppErrorState`, and `GlobalAppHeader` are safe canonical starting points.
- `CategoryChip` / `TagQuickPickStrip` are safe shared legacy components for current tag/category UI.
- `ComponentLabPage` uses mock-only data and may render these components for admin review.

## Needs Migration Later

- Feature-local task/timeline/list cards.
- Feature-local filter chips and category chips that bypass shared chip components.
- Raw Material buttons in feature screens when `AppButton` covers the action.
- Raw `IconButton` in feature screens when `AppIconButton` covers the action.
- Raw loading/empty/error placeholders.
- Tab/segment container implementations outside the compact label helpers.

## Guardrail

Do not mass-replace these findings opportunistically. Migrate one component family at a time under V7, with visual review in Component Lab before touching feature screens.
