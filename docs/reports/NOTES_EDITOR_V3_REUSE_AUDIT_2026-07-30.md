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
- Ordinary text, list, checklist, image, drawing, and table blocks do not gain independent decorative card backgrounds.
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

| Figma / specification component | Flutter canonical component | Ownership |
| :--- | :--- | :--- |
| `Notes/Block/Text` | `NotesTextBlock` | `lib/features/notes/widgets/notes_canonical_components.dart` |
| `Notes/Block/List` | `NotesListBlock` | same file |
| `Notes/Block/Checklist` | `NotesChecklistBlock` | same file |
| `Notes/Block/Quote` | `NotesQuoteBlock` | same file |
| `Notes/Block/Divider` | `NotesDividerBlock` | same file |
| `Notes/Block/Table` | `NotesTableBlock` | same file |
| `Notes/Table Size Picker` | `NotesTableSizePicker` | same file; compact/extended range is parameterized |
| `Notes/Block/Image` / `Drawing` | `NotesMediaBlock` | same file; media child and kind are parameters |
| `Notes/Block/Audio` | `NotesAudioBlock` | same file; state is a parameter |
| `Notes/Toolbar/Button` | `NotesToolbarButton` | same file |
| `Notes/Toolbar` | `NotesEditorToolbar` | same file |
| `Notes/Menus/*` shell | `NotesFloatingMenuSurface` | same file |
| `Notes/Menus/Text Formatting` | `NotesTextFormattingMenu` | same file |
| `Notes/Menus/Heading Styles` | `NotesHeadingStylesMenu` | same file |
| Empty-line insert menu | `NotesInsertMenu` | same file |

## Component rules established by the first implementation slice

- One widget class per concept is used at every width.
- Width is supplied by normal Flutter constraints; no platform branch changes component identity.
- Text-like blocks stay transparent in default and active states.
- Active text/list/checklist state uses a dynamic-height indicator in the left gutter.
- Body, list, and checklist visible text share the specification geometry.
- Quote and table own card surfaces and active outlines.
- Media selection outlines only the media frame; caption remains outside.
- Toolbar selected state uses a dark semantic surface with a contrasting icon.
- The toolbar tool enum intentionally has no Link member.
- The table size picker defaults to 5 × 5 and accepts a larger configured range without introducing a desktop class.
- All colors are derived from `ColorScheme`.

## Deferred to the next implementation slice

- Production editor orchestration and document controller.
- H1 → Body Enter behavior and list/checklist Enter/Backspace rules.
- Native selection integration and formatting application to selected ranges.
- Reorder controller and autosave integration.
- Component Lab wiring.
- Image picker/options, drawing editor integration, recorder service, transcript persistence, and platform permissions.

No PocketBase schema or Brain ownership change is required for this component slice.
