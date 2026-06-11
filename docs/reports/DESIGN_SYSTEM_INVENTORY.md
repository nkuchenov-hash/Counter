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
