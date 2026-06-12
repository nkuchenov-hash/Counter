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
| `Card` | `AppTaskCard` or `AppCard` |
| `Chip` | `AppTagChip` / `AppCategoryChip` |
| `Tabs` | `AppSegmentedTabs` |
| `Sheet` | `AppSheet` |
| `Header` | `AppShellHeader` |

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

### Cards

- Future canonical: `LifeCard` / `AppTaskCard` family.
- Existing local task cards are legacy until V7 migration.

### Chips / Tags

- Current shared feature components: `CategoryChip`, `TagQuickPickStrip`, `CategoryBreadcrumb`.
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

### Tabs / Segmented Controls

- Current shared component: `CompactSegmentedControl` / compact nav controls.
- Future canonical: `AppSegmentedTabs`.
- Raw tab/segment copies in feature screens need migration.

### Headers

- Current canonical: `GlobalAppHeader` for main shell date/time header.
- Future canonical: `AppShellHeader` with explicit variants for shell, secondary route, and compact surfaces.

### Sheets

- Future canonical sheet scaffolds should define padding, handle, max height, header, footer, and close/save behavior.
- Feature sheets may keep domain content but should share shell chrome.

### Inputs

- Future canonical input components should cover text fields, search fields, time/date entry, pickers, and inline editors.
- Date+time selection must follow the Omni-Picker law.

### Loading / Empty / Error States

- Current canonical: `AppLoading`, `AppEmptyState`, `AppErrorState`.
- Feature-local loading/empty/error placeholders should migrate to these.

## Forbidden Local UI Rule

Feature screens must not directly create raw duplicates of buttons, cards, chips, tabs, headers, loading states, empty states, or error states when a canonical component exists.

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
