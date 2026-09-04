# Design System

The Life OS design system makes Figma the visual source of truth and Flutter canonical components the executable source of truth. Feature screens must compose shared components, not recreate local copies.

## Goal

- One visual decision changes everywhere.
- Figma components map to named Flutter components.
- Canonical Flutter components live in `lib/core/widgets/` unless they are intentionally feature-shared in `lib/features/shared/`.
- Variations are parameters, not copied widgets.
- Component Lab shows the current executable component state for admin review.

## Naming Contract

Figma component names should stay clean and designer-facing. Flutter component names should stay app-namespaced and code-owned.

| Figma name | Flutter name |
| :--- | :--- |
| `Button` | `AppButton` |
| `Icon Button` | `AppIconButton` |
| `Completion Checkbox` | `PlanCardCheckbox` |
| `Card` | `AppTaskCard` or `AppCard` |
| `Chip` | `AppTagChip` / `AppCategoryChip` |
| `Tabs` | `AppSegmentedTabs` |
| `Sheet / Edit` | `showAppEditSheet` + `AppEditSheetSurface` |
| `Header` | `AppShellHeader` |
| `Reorder` | `AppReorderableList` + `AppReorderHandle` / `AppHoldToReorderListener` |

For buttons specifically:

| Figma component | Flutter component |
| :--- | :--- |
| `Button / Primary / M` | `AppButton.primary(size: AppButtonSize.m)` |
| `Button / Secondary / M` | `AppButton.secondary(size: AppButtonSize.m)` |
| `Button / Danger / M` | `AppButton.danger(size: AppButtonSize.m)` |
| `Button / Ghost / S` | `AppButton.ghost(size: AppButtonSize.s)` |
| `Button / Outlined / M` | `AppButton.outlined(size: AppButtonSize.m)` |

Do not rename the Flutter class to `Button`; keep `AppButton` as the executable source of truth.

For icon buttons specifically:

| Figma component | Flutter component |
| :--- | :--- |
| `Icon Button / Standard / M` | `AppIconButton(variant: AppIconButtonVariant.standard, size: AppIconButtonSize.m)` |
| `Icon Button / Danger / M` | `AppIconButton(variant: AppIconButtonVariant.danger, size: AppIconButtonSize.m)` |
| `Icon Button / Selected / M` | `AppIconButton(selected: true, size: AppIconButtonSize.m)` |

For cards specifically:

| Figma component | Flutter component |
| :--- | :--- |
| `Card / Task / Default` | `AppTaskCard(type: AppTaskCardType.task, state: LifeCardState.normal)` |
| `Card / Task / Done` | `AppTaskCard(type: AppTaskCardType.task, state: LifeCardState.completed)` |
| `Card / Task / Selected` | `AppTaskCard(type: AppTaskCardType.task, state: LifeCardState.selected)` |
| `Card / List / Backlog` | `AppTaskCard(type: AppTaskCardType.backlog, density: LifeCardDensity.compact)` |
| `Card / Timeline / Running` | `AppTaskCard(type: AppTaskCardType.timeline, state: LifeCardState.active)` |
| `Card / Task / Metadata` | `AppTaskCard(tags: ..., checklistCount: ..., notes: ..., repeats: true)` |

## Figma → Flutter Mapping Format

Use this mapping for every canonical component:

| Figma component | Flutter component | File | Variants / parameters | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `Component / Variant` | `AppComponentName` | `lib/core/widgets/...` | `variant`, `size`, `state`, `icon`, etc. | Behavior and migration notes |

Each mapping must answer:

- What is the Figma source component?
- What Flutter widget is the single executable source?
- Which variants are parameters?
- Where is it allowed to be used?
- Which legacy local copies should migrate to it?

## Token Categories

### Colors

- Semantic colors: primary, secondary, surface, error, outline, success/warning when introduced.
- Component colors must use theme/color tokens, not hardcoded feature-local palettes, except for data-driven colors such as category/tag colors.

### Typography

- Use theme text styles first.
- Component-specific typography should be centralized in the canonical component.
- Avoid feature-local font-size overrides unless the canonical component exposes a parameter.

### Spacing

- Standard spacing scale should be represented as reusable constants before broad migration.
- Feature screens may compose layout spacing, but component inner padding belongs to the component.

### Radius

- Radius tokens should distinguish pills, cards, sheets, inputs, and icon containers.
- Do not hardcode new local radii for duplicate component types.

### Elevation / Shadow

- Elevation should communicate interactivity and layering.
- Card/sheet shadows belong to canonical card/sheet components.

### Motion

- Motion should be short, predictable, and tied to state changes.
- Drag/reorder and sheet animations must not block input.
- Reorder updates local order before persistence; network or PocketBase revision writes never own drag motion.

## Canonical Component Categories

### Action Buttons

- Current canonical: `AppButton` in `lib/core/widgets/app_button.dart`.
- Figma `Button` maps to Flutter `AppButton`.
- Current variants: primary, secondary, danger/destructive, ghost, outlined.
- Current sizes: `AppButtonSize.s`, `AppButtonSize.m`, `AppButtonSize.l`.
- Width behavior: content-width by default, full-width with `fullWidth: true`.
- Raw `FilledButton`, `OutlinedButton`, `ElevatedButton`, and `TextButton` are forbidden in feature screens for app actions unless listed as temporary legacy in `docs/reports/DESIGN_SYSTEM_INVENTORY.md`.

### Icon Buttons / Icon Actions

- Current canonical: `AppIconButton` in `lib/core/widgets/app_icon_button.dart`.
- Figma `Icon Button` maps to Flutter `AppIconButton`.
- Current variants: standard, subtle, filled, danger.
- Current sizes: `AppIconButtonSize.s`, `AppIconButtonSize.m`, `AppIconButtonSize.l`.
- App icon-only actions should use `AppIconButton` once migration begins.
- Raw `IconButton` remains legacy allowed temporarily until migrated.
- New feature-screen icon actions should not introduce fresh raw `IconButton` unless documented as temporary legacy.
- Icon-only actions require a tooltip or semantic label where practical.

### Completion Checkbox

- Current canonical: `PlanCardCheckbox` in `lib/core/widgets/plan_time_task_card/plan_card_controls.dart`.
- Figma `Completion Checkbox` maps to this same executable widget on Plan cards and Path action rows.
- Path stages themselves do **not** have a completion checkbox. Their completed state is derived from their child actions; when all actions are done, the stage becomes completed, and reopening any action makes the stage pending again.
- Default control size is **32px** through `PlanCardGeom.controlSize`; completion surfaces must not shrink it to a feature-local compact checkbox.
- Hover, checked-state animation, border/radius, shadow, semantics, and hit target belong to `PlanCardCheckbox`; feature screens must not recreate them with raw Flutter `Checkbox`.
- Row/layout owners align the checkbox with the first line of primary text. Secondary text below the title must not vertically re-center the checkbox.
- Selection-mode behavior and completion-mode behavior are parameters of the same component. Any future size/state variants must be added to the canonical component rather than copied locally.

### Drag / Reorder

- Current canonical: `AppReorderableList`, `AppReorderHandle`, and `AppHoldToReorderListener` in `lib/core/widgets/mouse_drag_scroll_behavior.dart`.
- Figma `Reorder` maps to this shared Flutter mechanism; feature screens own their item/card surface but must not recreate reorder gesture plumbing.
- Use `AppReorderHandle` when an explicit discoverable drag handle is required. Use `AppHoldToReorderListener` when the product interaction is hold-the-surface-to-move, as in Plan cards, Notes blocks, and Paths.
- Canonical surface hold delay is about 300 ms. Normal tap/click behavior remains available until the hold arms movement.
- Reorderable items use stable domain keys; visual position is updated locally as soon as Flutter emits `onReorder`.
- Persistence is asynchronous and must not block drag motion. Failed persistence restores/reconciles the last confirmed order without duplicating items.
- Use `buildDefaultDragHandles: false`; the app-owned explicit handle or delayed surface listener owns drag start so desktop/web/mobile behavior is consistent.
- Nested ordered groups use the same `AppReorderableList`, not feature-local drag code. Set `shrinkWrap: true`, `primary: false`, and non-scrolling physics when the nested list lives inside another scroll/reorder surface; keep stable domain keys at both levels.
- For nested hold-to-reorder surfaces, do not wrap a parent listener around the child reorder region. Scope the parent hold listener to its own header/surface so parent and child delayed recognizers cannot compete for the same hold.

### Timezone Icons

- Current canonical: `AppTimezoneIcon` in `lib/core/widgets/app_timezone_icon.dart`.
- Figma `Icon / Timezone / UTC|London|Moscow|Dubai|New York` maps to `AppTimezoneIcon(timezoneKey: AppTimezoneIconKey...)`.
- The approved style is solid / filled monochrome silhouettes with no circular container, gradients, shadows, mixed line/filled treatment, raster assets, SVG assets, downloaded icon packs, or generated-preview production files.
- Timezone option UI must consume `AppTimezoneIcon`; feature screens must not draw timezone landmarks or access painter internals directly.
- Component Lab must show each timezone icon at 24px, 32px, and 40px for visual review.

### Cards

- Current canonical foundation: `LifeCard` and `AppTaskCard` in `lib/core/widgets/life_card.dart`.
- Figma `Card` maps to the `LifeCard` surface and task/list/timeline rows map to `AppTaskCard`.
- Current states: `LifeCardState.normal`, `selected`, `completed`, `disabled`, `active`.
- Current densities: `LifeCardDensity.regular`, `compact`.
- Current task types: `AppTaskCardType.task`, `backlog`, `timeline`.
- Metadata is parameterized: `tags`, `checklistCount`, `notes`, `repeats`, `timeLabel`, and `activeLabel`.
- V7H is a foundation pass only: `_PlanningTaskCard`, `_BacklogPlanCard`, and `_TimelineRecordCard` remain legacy production cards until scoped migration passes.

### PlanTimeTaskCard (Time mode scheduled plans)

Canonical widget: `PlanTimeTaskCard` in `lib/core/widgets/plan_time_task_card.dart` (`_PlanningTaskCard` in Time mode).

| Rule | Detail |
| :--- | :--- |
| **Separator** | Progress bar is the **only** separator between content and footer. **No** duplicate divider line. |
| **Footer** | Category breadcrumbs **left**, planned time **right** (medium/large only). |
| **Category color** | Breadcrumb/path and watermark use the **category color**, not link blue. Watermark = low-opacity category icon. |
| **Density tiers** | **micro** (<56px), **compact** (56–90px), **medium** (90–130px), **large** (≥130px) — chosen by **rendered block height**, not duration label alone. |
| **Micro / compact** | Checkbox, play, title, duration/time, menu only. **Do not** force full footer, tag row, or large watermark on 5–15 minute / short blocks. |
| **Hover** | Full-card hover surface; checkbox, play, and menu keep **independent** hit targets. |
| **Resize affordance** | Top/bottom 16px hit zones; hover shows subtle handle; floating time preview during drag/resize. |

### Chips / Tags

- Current shared chip implementation: `CategoryChip`, `TagChip`, `TagQuickPickStrip`, and `CategoryBreadcrumb` in `lib/core/widgets/chip_component.dart`.
- Future canonical split: `AppTagChip`, `AppCategoryChip`, `AppBreadcrumbChip`.
- Tag/category visual variations should be parameters.
- **Tag pill variants (enforced):**
  - `CategoryChipVariant.compactCard` — task/list card tags; ~22px stadium pills.
  - `CategoryChipVariant.largePicker` — edit sheets, menus, pickers; ~31px base stadium pills for grip; selected total visible height is ~39px because the selected ring is outside the base pill.
  - `TagQuickPickStrip` — horizontal `ListView` (no shrinkWrap); mouse drag + wheel scroll on web.
  - Parent row owns spacing (`ListView.separated` / `SizedBox`); individual pills must not add invisible outer margin/padding.
  - Pills use full stadium radius (`BorderRadius.circular(100)`).
  - Interactive selected tag pills keep the normal chip fill, normal chip text, and normal chip border; selected adds a visible 2px transparent gap plus a 2px brand border outside the normal chip.
  - Selected and unselected interactive tags must not shift inner text/content alignment; no invisible outer margin/padding outside the visible pill or selected ring.
  - Selected ring must shrink-wrap the visible pill only; it must not expand to parent row/card width.
  - Tag pill label text must be optically centered vertically and horizontally inside the base pill using normalized text metrics (`height: 1.0`, strut/leading control); selected state must not change inner text position.

### Tabs / Segmented Controls

- Current shared component: `CompactSegmentedControl` / compact nav controls.
- Future canonical: `AppSegmentedTabs`.
- Raw tab/segment copies in feature screens need migration.

### Headers

- Current canonical: `GlobalAppHeader` for main shell date/time header.
- Future canonical: `AppShellHeader` with explicit variants for shell, secondary route, and compact surfaces.

### Sheets

- Current canonical primary edit-sheet host: `showAppEditSheet` in `lib/features/shared/activity_detail_sheet.dart`.
- Current canonical primary edit-sheet surface/tokens: `AppEditSheetSurface` and `AppEditSheetTokens` in the same file.
- The host owns modal transparency, keyboard inset, `DraggableScrollableSheet`, and the standard 0.88 / 0.42 / 0.95 height behavior. Feature code must not copy those values.
- `ActivityDetailSheet` remains the single domain router: record content → `TimelineRecordSheetContent`; plan/list content → `PlanningTaskEditSheet`.
- Record and plan/list editors are legitimate domain variants, not separate sheet systems. Their save/autosave/recurrence/record-specific content stays separate while shared sheet chrome belongs in `AppEditSheet` components.
- New primary record/plan/list edit entry points must call `showAppEditSheet`; do not add another local `showModalBottomSheet + DraggableScrollableSheet` copy.
- Generic non-edit sheets may still use their own Material surface until a broader canonical `AppSheet` is introduced.

### Inputs

- Future canonical input components should cover text fields, search fields, time/date entry, pickers, and inline editors.
- Date+time selection must follow the Omni-Picker law.

### Loading / Empty / Error States

- Current canonical: `AppLoading`, `AppEmptyState`, `AppErrorState`.
- Feature-local loading/empty/error placeholders should migrate to these.

## Forbidden Local UI Rule

Feature screens must not directly create raw duplicates of buttons, cards, chips, tabs, headers, completion checkboxes, loading states, empty states, error states, or the primary edit-sheet host when a canonical component exists.

Allowed exceptions:

- Tiny one-off layout glue around a canonical component.
- Material primitives inside the canonical component implementation itself.
- Legacy local UI marked for migration in `docs/reports/DESIGN_SYSTEM_INVENTORY.md`.
- Domain-specific feature content that has no canonical component yet.

## Component Lab

- Location: `lib/features/dev/component_lab_view.dart`.
- Access: admin-only via `profiles.is_admin`.
- Data: sample/mock visual data only.
- Safety: no database writes, no destructive actions, no production user data.
- Every Component Lab example must be labeled with Figma name, Flutter mapping, variant, size, and state where applicable.
- Labels belong to the lab/demo wrapper, not to production components.
- Lab label/spec text is selectable/copyable for design review; this is lab-only and must not make production UI text selectable by default.

### Paths: Options + hold-to-move

For ordered Path stages/items, show `more_horiz` as the visible Options affordance. Tap/click opens Edit; Options does **not** start movement. Hold the stage header to move the stage, and hold the action row to move the action, using `AppHoldToReorderListener`. Do not show a second drag glyph beside Options. Path item detail editing uses a sheet with formulation, final result, optional description/context, optional mini-checklist, and time estimate.
