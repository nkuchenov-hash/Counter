# LIFE OS — Unified Menu System (implementation contract)

Status: design and migration contract; **not** evidence that Flutter screens or external calendar integrations have shipped.

## Scope
All navigation menus, settings, nested settings, contextual menus, category/tag pickers, sheets, and modal actions on Android and Web. Adapt reference screenshots' organization and spacing, **not** TECNO branding, orange accent, or literal widgets.

## Existing source of truth
Follow `DESIGN_SYSTEM.md`, `UX_CONTRACT.md`, and `ARCHITECTURE.md`. Figma is visual source; canonical Flutter widgets are executable source. Reuse `AppButton`, `AppIconButton`, `AppCard`, `AppSheet`, `AppShellHeader` and existing tokens. Never fork local menu widgets per feature.

## Visual and interaction rules
- Light mode: neutral near-white page background and white grouped surfaces; dark mode uses semantic theme surfaces.
- One primary page title; compact back control; avoid duplicate app bars/headings.
- Group related rows into a shared rounded surface with subtle inset dividers. Avoid one-card-per-row clutter.
- Each row: optional leading icon, clear title, optional muted one-line status/subtitle, trailing chevron **or** switch/value (not redundant controls).
- Standardize section spacing, row heights, internal padding, corner radii, typography and icon sizes via shared tokens; minimum readable body text 16sp where feasible.
- Distinguish enabled, selected, disabled, loading, error and offline states; preserve accessibility semantics and tap targets.
- Use one canonical settings section/row component, one selection row, and one toggle row; variants are parameters.
- Context menus and bottom sheets share the same action ordering, destructive-action treatment and dismiss behavior.
- Feedback to user action within ~100ms; never silently discard changes; preserve optimistic/offline-first semantics.

## Information architecture
- Account: identity and sign-in.
- Calendars & integrations: Google Calendar, Yandex Calendar, Microsoft 365 / Outlook / Teams; account connection state, selected calendars, sync direction, last success, actionable error.
- Planning: schedule policies, timeline display, recurring plans.
- Records: categories and recording behavior.
- Notifications: reminders and delivery preferences.
- Appearance: light/dark/system, presentation.
- Data & sync: PocketBase, pending outbox, offline and manual retry.
- About: version, release notes, diagnostics.

## Calendar integrity
- Do **not** show a connected state unless provider authorization succeeds.
- Teams calendar meetings are sourced from the associated Microsoft 365/Exchange calendar through Microsoft Graph where permitted.
- Default work Microsoft account to import-only; no changes to invitations or messages to attendees.
- Preserve source event IDs, recurrence, timezones, cancellation state and meeting URLs; deduplicate events.
- Keep provider credentials server-side; request least-privilege scopes. Handle admin consent requirements explicitly.
- External calendar sync is a separate backend feature and must not be represented by static toggles as if functional.

## Migration order
1. Inventory existing menu surfaces and local widget duplicates; map to canonical components.
2. Implement and visually test shared settings primitives and theme tokens.
3. Migrate Settings landing page and nested pages without removing functionality.
4. Migrate navigation, context menus, category/tag pickers and sheets.
5. Add provider connection flows and server-side calendar synchronization separately.
6. Verify Android/Web, light/dark, text scaling, keyboard, offline states, and existing behaviors.

## Acceptance checks
- No feature-local duplicate settings row, group or toggle widgets.
- Consistent spacing, hierarchy, surfaces and states across all migrated screens.
- All prior settings remain reachable; no accidental changes to planning or record logic.
- Calendar integration statuses reflect real auth/sync results.
- Flutter analyze/tests and Android/Web builds pass; screenshots reviewed at mobile and desktop widths.
