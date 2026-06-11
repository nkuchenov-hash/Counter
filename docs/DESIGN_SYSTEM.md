# Design System

The Life OS design system makes Figma the visual source of truth and Flutter canonical components the executable source of truth. Feature screens must compose shared components, not recreate local copies.

## Goal

- One visual decision changes everywhere.
- Figma components map to named Flutter components.
- Canonical Flutter components live in `lib/core/widgets/` unless they are intentionally feature-shared in `lib/features/shared/`.
- Variations are parameters, not copied widgets.
- Component Lab shows the current executable component state for admin review.

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
- Future direction: keep/upgrade as `AppActionButton` only if a rename is worth the migration.
- Raw `FilledButton`, `OutlinedButton`, `ElevatedButton`, and `TextButton` should not be duplicated in feature screens once the needed canonical variant exists.

### Cards

- Future canonical: `LifeCard` / `AppTaskCard` family.
- Existing local task cards are legacy until V7 migration.

### Chips / Tags

- Current shared feature components: `CategoryChip`, `TagQuickPickStrip`, `CategoryBreadcrumb`.
- Future canonical split: `AppTagChip`, `AppCategoryChip`, `AppBreadcrumbChip`.
- Tag/category visual variations should be parameters.

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
