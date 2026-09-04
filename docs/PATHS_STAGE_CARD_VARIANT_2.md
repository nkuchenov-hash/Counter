# Paths stage card — approved Variant 2

The Path detail screen uses the approved Variant 2 stage anatomy. This is a structural contract, not a color-only treatment of the previous `ExpansionTile`. The production card must use the explicit anatomy below; wrapping the old `ExpansionTile` in new colors is not an acceptable implementation of this variant.

The canonical implementation is `lib/features/paths/widgets/path_stage_card.dart`; `lib/features/paths/paths_page.dart` composes it and owns Path-level actions and persistence.

## Page hierarchy

1. Category breadcrumb.
2. Compact Path heading; the feature must not promote it above the restrained `titleLarge` hierarchy.
3. Goal line with the `Цель:` / `Goal:` label emphasized.
4. Ordered stage cards.
5. Add-stage action.

The former executable-structure status chip is not part of the page.

## Stage anatomy

Each stage card has:

- a subtle rounded surface and 4px state accent rail on the far left;
- a separate soft header zone with a bottom divider;
- the canonical stage drag handle at the far left of the header;
- a numbered circular badge followed by the stage title;
- completion criteria directly below the title, aligned with the title text rather than the drag handle;
- progress pill plus expand/collapse chevron at the right;
- a quieter white body containing ordered actions;
- action rows with canonical completion checkbox, regular-weight action text, muted result text, time, and canonical action drag handle;
- `Добавить пункт` / `Add item` at the bottom of the body.

Pending stages are expanded by default so the Path can be read as one structured document. Completed stages collapse by default. Reopening an action reopens its stage.

## State color

- completed stage: green;
- current stage: amber;
- later pending stage: theme primary/brand accent.

State color is an accent. It must not turn the whole card into a saturated block.

## Typography

Stage titles use the restrained theme `titleMedium` hierarchy. Action text uses normal body weight. The stage card must not introduce oversized feature-local headings.

## Reorder behavior

Both levels are reorderable:

- stages reorder in the outer `AppReorderableList`;
- actions reorder in a nested `AppReorderableList`.

Both use stable domain keys, canonical `AppReorderHandle`, immediate local order updates, and asynchronous Path revision persistence.
