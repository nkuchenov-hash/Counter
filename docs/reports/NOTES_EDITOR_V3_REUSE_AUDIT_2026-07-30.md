# Notes Editor V3 — PR #24 / #25 reuse audit

Date: 2026-07-30
Branch: `feature/notes-v3-design-system`
Source of truth: `docs/specs/NOTES_EDITOR_V3_SPEC_2026-07-30.md`

## Scope

This audit identifies code from merged PR #24 (`Notes editor tools v2`) and PR #25 (`Fix Notes flicker and seamless document flow`) that can be reused for Notes Editor V3 without restoring rejected experimental UI.

The governing rule is shared responsive canonical Notes components for mobile and desktop. Desktop may change width, shell placement, and overlay anchoring only. The sole component exception remains an extended table size range, implemented as configuration of the same table component rather than a second desktop widget.

## Reuse from PR #24

### Keep as the data foundation

- `lifeos_notes_blocks_v2` versioned envelope in `plans.notes_delta`.
- Stable block IDs.
- `NoteTextRun` and `NoteInlineMarks` for selection-level bold, italic, underline, strike, highlight, and link metadata.
- `applyNoteTextEditToRuns` for preserving unaffected inline marks during text replacement.
- `NoteTableData` serialization and bounded row/column parsing.
- Existing image/drawing payload fields and payload limits.
- Explicit v1/legacy parsing and compatibility preservation.
- Existing Brain entry points: parse note document, local apply, debounced persistence, and current PocketBase schema.

These pieces already satisfy the V3 requirement to preserve blocks that the current UI cannot edit and avoid a schema rewrite.

### Reuse as behavior, not as production widgets

- Block conversion preserves text and supported inline marks.
- Insert/delete/reorder operate on stable IDs.
- Table cell edits emit immutable `NoteTableData` updates.
- Image and drawing data stay in the existing document payload.
- Selection formatting remains separate from document structure.

The V2 widgets are not restored wholesale. Their behavior is re-expressed through new canonical component APIs.

## Reuse from PR #25

### Keep as performance law

- Text edits update the local `NoteDocument` draft without rebuilding the complete editor page on every character.
- Rich runs are synchronized before `RenderEditable` receives a changed value, avoiding a one-frame plain-text flash.
- Collapsed caret movement does not trigger row `setState` on every keystroke.
- Autosave status changes do not rebuild the document.
- The editor remains one continuous sheet with zero screen-level block gap.
- Ordinary text, list, checklist, image, drawing, and table rows do not gain an extra outer block card solely because they are active.
- Numbered ordinals are derived from contiguous numbered blocks.
- Block actions reserve stable geometry and do not reflow text when activated.

These are P0 correctness constraints for the V3 controller and editor integration.

## Do not restore

The following PR #24/#25 UI is outside the V3 production scope or conflicts with the current specification:

- Callout, code block, collapsible, generic reference blocks, and standalone link-card insertion.
- Link as a first-level toolbar action.
- The monolithic V2 tools dock and its mixed formatting/insert/more panels.
- Whole-block formatting as the primary data model when a text selection exists.
- Hardcoded GLM light-only colors and white glass surfaces.
- Active fills around ordinary text blocks.
- A stray left active line for tables.
- Selection outlines that include image/drawing captions.
- Per-block screen wrappers used only to manufacture spacing.
- Any desktop-only Notes widget class.

Compatibility parsing for out-of-scope block types remains intact so opening and saving a note does not destroy stored data.

## Canonical component mapping

Public import: `lib/features/notes/widgets/notes_canonical_components.dart`.

| Figma / specification component | Flutter canonical component | Focused implementation part |
| :--- | :--- | :--- |
| `Notes/Block/Text` | `NotesTextBlock` | `notes_component_text_blocks.dart` |
| `Notes/Block/List` | `NotesListBlock` | `notes_component_text_blocks.dart` |
| `Notes/Block/Checklist` | `NotesChecklistBlock` | `notes_component_text_blocks.dart` |
| `Notes/Block/Quote` | `NotesQuoteBlock` | `notes_component_structural_blocks.dart` |
| `Notes/Block/Divider` | `NotesDividerBlock` | `notes_component_structural_blocks.dart` |
| `Notes/Block/Table` | `NotesTableBlock` | `notes_component_structural_blocks.dart` |
| `Notes/Table Size Picker` | `NotesTableSizePicker` | `notes_component_structural_blocks.dart`; compact/extended range is parameterized |
| `Notes/Block/Image` / `Drawing` | `NotesMediaBlock` | `notes_component_media_blocks.dart`; media child and kind are parameters |
| `Notes/Block/Audio` | `NotesAudioBlock` | `notes_component_media_blocks.dart`; state is a parameter |
| `Notes/Drawing Controls` | `NotesDrawingControls` | `notes_component_media_blocks.dart`; pen/highlighter/eraser/lasso, color, width, undo/redo |
| `Notes/Recorder Controls` | `NotesRecorderControls` | `notes_component_media_blocks.dart`; ready/recording/paused/permission-blocked states |
| `Notes/Transcript` | `NotesTranscriptSurface` | `notes_component_media_blocks.dart`; fixed header/actions and scrollable transcript body |
| `Notes/Toolbar/Button` | `NotesToolbarButton` | `notes_component_tools.dart` |
| `Notes/Toolbar` | `NotesEditorToolbar` | `notes_component_tools.dart` |
| `Notes/Menus/*` shell | `NotesFloatingMenuSurface` | `notes_component_tools.dart` |
| `Notes/Menus/Text Formatting` | `NotesTextFormattingMenu` | `notes_component_tools.dart` |
| `Notes/Menus/Heading Styles` | `NotesHeadingStylesMenu` | `notes_component_tools.dart` |
| Empty-line insert menu | `NotesInsertMenu` | `notes_component_tools.dart` |

## Implemented production behavior

- Empty notes open with H1; Enter creates Body.
- Text, heading, quote, list, checklist, divider, table, image, and drawing payload blocks use canonical shared components.
- Body/H1/H2/H3/Quote/List/Checklist conversions preserve text and inline runs.
- Bold, italic, underline, strikethrough, highlight, and inline link edits apply to the selected range.
- Block deletion keeps at least one editable block and does not remove unsupported legacy blocks.
- Table controls add/delete rows and columns within the existing 20 × 6 serialization bounds.
- Reorder works on visible production blocks while hidden compatibility blocks keep their stored position.
- Checklist, table cell, media caption, insert, conversion, formatting, delete, and reorder changes are local-first and use debounced Brain persistence.
- Existing image/drawing payloads render; media selection outlines only the frame.

## Remaining implementation scope

- Image source picker, replace/crop/copy/save options, and camera support where available.
- Dedicated drawing editor integration using the canonical V3 drawing controls.
- Audio recording service, playback, transcription persistence, transcript error recovery, and platform permissions.
- Component Lab mock scenarios.
- Focused Flutter test execution and mobile/desktop visual checks.

No PocketBase schema or Brain ownership change is required for the remaining work.
