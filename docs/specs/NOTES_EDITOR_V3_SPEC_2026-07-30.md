# Notes Editor V3 — Product and Engineering Specification

Status: implementation source of truth  
Date: 2026-07-30  
Repository: `nkuchenov-hash/Counter`  
Implementation branch: `feature/notes-v3-design-system`

## 1. Source of truth

This specification restores and consolidates the Notes requirements agreed in the Notes design discussion.

Primary visual source:

- Figma file: `APP-Design`
- Notes design-system page: https://www.figma.com/design/tDy0Dj1GpxqPf29rTK0SiW/APP-Design?node-id=43-3744
- Notes desktop screens section: https://www.figma.com/design/tDy0Dj1GpxqPf29rTK0SiW/APP-Design?node-id=737-3756

Product behavior in this document takes precedence over older experimental Notes implementations.

The existing repository architecture, `docs/ARCHITECTURE.md`, `docs/DESIGN_SYSTEM.md`, `docs/UX_CONTRACT.md`, `docs/DATA_MAP.md`, and `docs/POCKETBASE_MANIFEST.md` remain governing documents.

## 2. Product goal

Notes is a first-class Life OS feature, not a plain text field and not an isolated web editor.

The editor must support structured notes on Android, Windows, Web, and the other Flutter targets while preserving:

- offline-first editing;
- local-first visible updates;
- background persistence through the existing Brain architecture;
- the existing Notes library and PocketBase storage contract;
- mobile and desktop parity;
- responsive shared components rather than platform-specific duplicates.

## 3. Non-negotiable architecture rules

### 3.1 Shared components

Mobile and desktop use the same canonical Notes components.

Desktop changes only:

- available width;
- screen shell layout;
- placement of floating menus and modal surfaces.

Do not create desktop-only Notes components.

The only permitted exception is an extended table variant when desktop needs more rows or columns than the compact mobile table picker.

### 3.2 Screen composition

A Notes screen may contain layout containers, overlays, scrims, and positioned menus, but every visible editor control or block must be an instance of a canonical component.

Do not reproduce component appearance with local `Container`, `DecoratedBox`, or ad-hoc widget copies inside desktop screens.

### 3.3 Existing app design system

Use canonical app components and tokens where they cover the requirement:

- `AppButton`;
- `AppIconButton`;
- app loading, empty, and error states;
- existing semantic colors, borders, radii, shadows, and typography;
- shared category and tag components.

Notes-specific controls may be implemented as canonical Notes components under the Notes feature or approved shared layer.

### 3.4 No broad architecture rewrite

Do not move Brain ownership, change PocketBase schema, or reorganize unrelated files.

## 4. Existing repository state

The repository previously contained a backward-compatible rich Notes v2 document model and editor tooling. A later change reduced the production editor to a title and continuous plain-text body while preserving non-text payloads as compatibility data.

Implementation must reuse compatible existing model and migration work where safe, but the production UI must be rebuilt against this specification and current Figma design.

Do not restore rejected experimental UI wholesale.

## 5. Note document structure

A note contains:

1. note header;
2. ordered block list;
3. metadata required by the existing plan/note row.

Every block has a stable ID. Reorder, focus, autosave, selection, and block conversion must not depend on list index as identity.

Supported production block types:

- Body text;
- H1;
- H2;
- H3;
- bulleted list item;
- numbered list item;
- checklist item;
- quote;
- divider;
- table;
- image;
- drawing;
- audio recording with transcript state.

Not included in this scope:

- callout;
- code block;
- collapsible block;
- generic advanced block family;
- standalone link-card block.

Links are inline text formatting, not a first-level insert tool.

## 6. Note header

### 6.1 Title

- The note title is editable.
- Its visual style is fixed and cannot be converted to Body/H1/H2/H3.
- The title grows vertically when multiline.
- The title does not behave as a reorderable content block.

### 6.2 Category and tags

- Category and tags are visible in the header.
- Category uses the existing category system.
- Tags are display badges in the title/header surface, not action buttons masquerading as tags.
- Editing category/tags must use the existing app flows and persistence contracts.

### 6.3 Header-to-content spacing

There is no external gap between the Note Header component and the first content block.

Vertical rhythm is owned by component padding. Screen-level `SizedBox` or list spacing must not duplicate it.

## 7. New note behavior

- A newly created note opens with a first H1 block.
- Pressing Enter at the end of that first H1 creates a Body block immediately after it.
- Subsequent Enter behavior follows the active block type.
- Empty text lines are represented as transparent empty spacer blocks where needed by the block model.
- The user can begin typing without opening a separate formatting mode.

## 8. Text block component

### 8.1 Variants

Canonical text block variants:

- `Style=Body, State=Default`;
- `Style=Body, State=Active`;
- `Style=H1, State=Default`;
- `Style=H1, State=Active`;
- `Style=H2, State=Default`;
- `Style=H2, State=Active`;
- `Style=H3, State=Default`;
- `Style=H3, State=Active`.

Do not multiply variants for every inline formatting combination.

### 8.2 Inline formatting properties

Text formatting must expose:

- text;
- bold;
- italic;
- underline;
- strikethrough;
- highlight;
- link.

Formatting may be applied to a selection. Data representation should preserve inline runs rather than forcing whole-block formatting.

### 8.3 Typography

Menu previews must show the real result, not generic labels:

- H1 row uses H1 typography;
- H2 row uses H2 typography;
- H3 row uses H3 typography;
- Bold is visibly bold;
- Italic is visibly italic;
- Underline is visibly underlined;
- Strikethrough is visibly crossed;
- Highlight has the actual highlight treatment;
- Link has the actual link treatment.

### 8.4 Dynamic height

- Text blocks use content-driven height.
- Multiline changes push following blocks through Auto Layout / Flutter layout naturally.
- No clipping or fixed one-line height.

## 9. Block spacing and alignment

### 9.1 Vertical rhythm

- Screen block spacing is `0`.
- Text blocks own `12 px` top and bottom padding.
- Card-like blocks own `12 px` top and bottom outer inset.
- Do not add duplicate screen wrappers solely to create block padding.

### 9.2 Horizontal alignment

All visible content follows one content line.

Mobile reference:

- screen width: 390;
- text block width: 390;
- text internal horizontal padding: 20;
- card surface width: 350;
- card surface begins at x=20.

Desktop behavior:

- centered responsive editor shell;
- shared components use `Fill container`;
- the visible text line, list text, checklist text, and card edges align;
- do not use repeated per-block inset wrappers.

### 9.3 Lists and checklists

List and checklist rows use the same leading geometry:

- leading gutter: 20;
- marker or checkbox: 20;
- gap to text: 10;
- text begins at x=50 on the 390 px reference width;
- both rows fill available width;
- multiline text remains aligned after wrapping.

## 10. Active and selected states

### 10.1 Text-like blocks

- Default block is transparent.
- Active block remains transparent.
- Active state is shown by a subtle grey vertical indicator in the left gutter.
- Indicator height tracks the real block height.
- H1 indicator is optically shifted down because H1 has more space above its glyphs; it keeps a top inset while stretching with multiline content.

### 10.2 Quote

- Quote is a distinct card.
- Active quote uses an outline around the quote card.
- Quote height hugs content.
- Quote must not have a fixed empty lower area.

### 10.3 Table

- Active table uses an outline around the complete table surface.
- Do not use a stray left active line for tables.

### 10.4 Image and drawing

- Active selection outlines only the image or drawing frame.
- Caption is not included in the selection outline.
- Caption remains ordinary text below the media frame.

### 10.5 Dragging

- Dragging block has no fill, stroke, shadow, card background, or decorative handle added by the state.
- Content remains readable and visually transparent while moving.

## 11. Text selection

Use native platform text selection behavior where possible.

Primary selection menu:

- Cut;
- Copy;
- More.

The primary menu has equal action zones, symmetric spacing, and adequate edge padding.

Secondary Notes formatting menu:

- Bold;
- Italic;
- Underline;
- Strikethrough;
- Highlight;
- Add/Edit Link.

Mobile may show native touch selection handles. Desktop must not display oversized mobile touch handles.

## 12. Formatting and heading menus

Canonical shared Notes menus:

- `Notes/Menus/Text Formatting`;
- `Notes/Menus/Heading Styles`.

Both mobile and desktop use the same components.

Their visual shell follows the Notes selection menu family:

- glass/elevated surface;
- shared stroke;
- shared shadow/blur;
- shared corner radius;
- 16 px edge padding.

They are floating overlays, not content blocks in the document flow.

## 13. Main editor toolbar

The toolbar is one canonical component containing instances of one canonical toolbar button.

Toolbar button states:

- Default;
- Selected.

Toolbar button exposes an icon instance-swap property.

Selected state:

- black background;
- white icon;
- no white square or text-glyph fallback.

Toolbar tools:

- Heading;
- Text;
- Quote;
- List;
- Checklist;
- Table;
- Drawing;
- Image;
- Audio Record.

Link is not a first-level toolbar action.

Toolbar behavior:

- pinned/anchored so it remains available while editing;
- does not cover content without reserved bottom space;
- mobile and desktop use the same component;
- desktop changes placement only.

## 14. Empty line insertion

Long press on an empty line opens a vertical insert menu.

Insert menu entries use icons and labels:

- Heading;
- Text;
- Drawing;
- Image;
- Quote;
- List;
- Checklist;
- Table;
- Audio Record;
- Divider.

The insert menu is a floating overlay and must not become a child in the document Auto Layout flow.

## 15. Block conversion

Compatible transformations are available through the active toolbar/menu:

- Body ↔ H1/H2/H3;
- Body ↔ Quote;
- Body ↔ Bulleted List;
- Body ↔ Numbered List;
- Body ↔ Checklist.

A conversion preserves text and inline marks where the target type supports them.

Incompatible actions use the block options menu rather than silently destroying unsupported data.

## 16. Reorder

- Long press starts block reorder.
- Reorder is available for content blocks, not the note title/header.
- Reorder updates local order immediately.
- Persistence is debounced/batched and never blocks drag motion.
- Failure reconciles without duplication.
- The dragged block remains transparent with no extra state decoration.

## 17. Quote

Quote contains:

- quote text;
- optional attribution.

Quote:

- hugs content;
- uses card width aligned with text content line;
- owns its padding;
- supports Default and Active states.

## 18. Lists

Supported:

- bulleted;
- numbered.

Behavior:

- Enter creates the next list item;
- Enter on an empty item exits the list to Body;
- Backspace at the start follows standard list outdent/convert behavior;
- wrapped lines align with list text, not with the marker.

## 19. Checklist

Checklist contains:

- checkbox;
- editable text.

Behavior:

- checking updates local state immediately;
- checked content preserves text and formatting;
- checkbox and text are vertically centered;
- multiline text remains aligned;
- Enter creates another checklist item;
- Enter on empty item exits to Body.

## 20. Divider

- Divider is a lightweight structural block.
- It has no editable text.
- It participates in reorder.
- It does not introduce a card background.

## 21. Tables

### 21.1 Insert

- Table insert opens a compact size picker.
- Mobile supports small tables; the current design reference includes up to 5 × 5 selection.
- Desktop may expose a larger table variant if required.

### 21.2 Editing

Table editing menu supports:

- Add row above;
- Add row below;
- Add column left;
- Add column right;
- Delete row;
- Delete column;
- Delete table.

### 21.3 Layout

- Table fills the card content width.
- Cells distribute width consistently.
- Text uses content-aware height where implemented safely.
- Active outline covers the entire table.
- Table data must remain serializable in the versioned note document.

## 22. Images

### 22.1 Source picker

Open a source picker using sources supported by the current platform, including gallery/files and camera where available.

The picker uses icons and labels.

### 22.2 Image block

- Image frame fills card width.
- Optional caption appears below.
- Image and caption reflow with the document.
- Active outline surrounds the image frame only.

### 22.3 Image options

- Replace image;
- Crop;
- Add or edit caption;
- Copy;
- Save to device;
- Delete.

### 22.4 Storage

Respect existing payload limits and storage architecture. Do not introduce unbounded base64 payloads or a new PocketBase schema without explicit approval.

## 23. Drawing

Drawing mode supports:

- Pen;
- Highlighter;
- Eraser;
- Lasso;
- color selection;
- stroke width;
- Undo;
- Redo.

Drawing opens in a dedicated editing surface and saves back into a drawing block.

The same drawing block component is used on mobile and desktop. Only available canvas size changes.

## 24. Audio recording and transcript

### 24.1 Recorder states

- Ready;
- Recording;
- Paused where supported;
- Permission Blocked.

### 24.2 Recording actions

- Start;
- Pause/Resume where supported;
- Stop;
- Discard/Cancel;
- Open Settings when permission is blocked.

### 24.3 Audio block states

- Ready;
- Playing;
- Transcribing;
- Transcript Error.

Audio remains playable even when transcription fails.

### 24.4 Transcript

Transcript opens in a dedicated modal/surface with:

- fixed header;
- playback context;
- scrollable transcript body;
- Copy transcript;
- Done/Close.

The canonical recorder and transcript components must be responsive and shared between mobile and desktop. Do not create desktop copies.

### 24.5 Persistence and background behavior

Recording and transcript persistence must use the existing local-first architecture. Long-running recording/transcription must not block note editing or UI response.

Platform background recording support must be implemented only through the approved platform service architecture and permissions, not through widget lifecycle hacks.

## 25. Autosave and persistence

### 25.1 Local first

- Typing updates local editor state immediately.
- Block insertion, deletion, conversion, reorder, checklist toggle, and formatting update local state immediately.
- Network is background.

### 25.2 Autosave

- Autosave is debounced.
- Closing the editor flushes the latest draft.
- Autosave reads the latest editor state at execution time.
- Rebuilds must not reset controllers or selection.

### 25.3 Offline

- Editing remains available offline.
- Retriable failures preserve optimistic state and use existing outbox/sync paths where supported.
- Non-retriable validation/schema errors show one concise error and reconcile safely.

### 25.4 Compatibility

Opening and saving a note must not destroy blocks that the current UI cannot edit.

Migrations must be explicit, versioned, and tested.

## 26. Mobile layout

Reference behavior:

- full-screen editor;
- minimum text size 16 pt;
- no horizontal clipping;
- content width follows device width;
- text blocks span screen width and own 20 px horizontal inset;
- card surfaces align to the same visible content line;
- toolbar remains reachable above keyboard/safe area;
- floating menus remain inside viewport.

## 27. Desktop layout

- Centered editor surface.
- Responsive maximum width based on the current Figma and app token.
- Same shared components as mobile.
- Content stack uses one Auto Layout/Flutter column with zero external item gap.
- Floating menus anchor to the selected block or selection.
- Modal scrim covers the full editor surface.
- No mobile touch handles.
- No repeated per-block wrapper frames/widgets.

## 28. Dark mode

All Notes components use semantic theme tokens and work in Light and Dark modes.

Do not hardcode white cards, black text, or fixed grey backgrounds when a semantic token exists.

## 29. Accessibility and keyboard

- Icon buttons have tooltip/semantic labels.
- Keyboard focus order follows document order.
- Desktop shortcuts should use platform conventions where available.
- Text selection remains native where practical.
- Controls have clear focused, selected, disabled, and permission-blocked states.
- Touch targets meet app minimums.

## 30. Performance contract

- Visible response within approximately 100 ms for typing, selection, formatting, block insert, checklist toggle, and reorder start.
- No network wait before local updates.
- Do not serialize the full document synchronously on every keystroke if it causes typing lag.
- Avoid rebuilding every block for a local edit.
- Avoid full note/library refetch after small edits.
- Existing loaded content must not be replaced by a blank loader during background sync.

Any typing lag, selection lag, editor freeze, or content loss is a P0 correctness failure.

## 31. Implementation boundaries

Expected ownership:

- `lib/data/models/`: pure versioned document and inline mark value objects;
- `lib/data/`: parsing, migration, local cache apply, persistence, offline/outbox integration;
- `lib/features/notes/`: editor orchestration and Notes-specific components;
- `lib/core/widgets/`: only genuinely cross-feature canonical primitives;
- locale strings: canonical EN/RU files.

Do not import feature UI into `lib/data/`.

## 32. Delivery phases

### Phase A — specification and audit

- commit this specification;
- audit current main after the text-only rollback;
- inventory reusable v2 model/code from merged history;
- map Figma components to Flutter components;
- identify schema gaps without changing schema.

### Phase B — canonical Notes component library

Implement shared responsive Flutter components for:

- text blocks;
- list/checklist;
- quote/divider;
- table;
- media;
- audio;
- toolbar button and toolbar;
- selection/format/heading/insert menus;
- recorder/transcript;
- drawing controls.

Add them to the admin-only Component Lab with mock data.

### Phase C — editor core

- versioned document controller;
- focus and selection controller;
- block insert/delete/convert;
- Enter/Backspace behavior;
- reorder;
- autosave integration;
- legacy migration and preservation.

### Phase D — media, drawing, audio

- image picker and image options;
- drawing editor;
- recording and audio block;
- transcription states and transcript surface.

### Phase E — desktop parity and production hardening

- responsive desktop layout using the same components;
- keyboard and mouse behavior;
- dark mode;
- accessibility;
- focused performance checks;
- release integration.

## 33. Minimal verification policy

Do not create hundreds of tests.

Initial minimum automated suite:

1. document/model migration and round-trip test;
2. editor behavior test covering H1 → Body, block insert/reorder, and autosave preservation;
3. responsive component/editor test covering mobile and desktop without overflow.

Add another focused test only for a concrete regression or high-risk platform service.

Required manual/visual checks:

- one populated mobile note;
- one populated desktop note;
- text selection and formatting;
- table editing;
- image selected state;
- recorder and transcript;
- dark mode;
- offline edit and reopen.

## 34. Acceptance criteria

The feature is accepted when:

- Notes is no longer text-only;
- all production block types in this specification can be created and edited;
- mobile and desktop use the same canonical components;
- no desktop-only Notes component exists except an approved extended table variant;
- title/category/tags behave as specified;
- H1 → Body Enter behavior works;
- text formatting and native selection work;
- list and checklist text align with Body text;
- active states track dynamic block height;
- tables, images, drawings, and audio reflow correctly;
- selected image outlines only the image frame;
- autosave is local-first and preserves all blocks;
- offline editing does not lose changes;
- no PocketBase schema change was introduced without explicit approval;
- focused tests pass;
- mobile and desktop visual checks match the Figma source closely.
