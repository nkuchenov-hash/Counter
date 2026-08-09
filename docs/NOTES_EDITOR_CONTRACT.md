# Notes Editor Stability Contract

This document is the permanent stability contract for the production Notes editor. Read it before changing `lib/features/notes/note_editor_page.dart`, `lib/features/notes/widgets/notes_editor_screen.dart`, Notes block widgets, mobile keyboard handling, or the Notes editor scroll structure.

## Scope

The production Notes body is built by `NoteEditorPage` and rendered through a `ReorderableListView.builder` inside `NotesEditorScreen`. The editor must remain usable on desktop, Android, and mobile web, including iPhone Safari with the software keyboard open.

Correctness and editor visibility outrank layout refactors. If a change produces a gray Notes work area, missing body, hidden caret, or keyboard-covered input, treat it as a P0 regression and restore the last stable structure before adding more layout machinery.

## Non-negotiable invariants

### 1. `ReorderableListView` remains the single vertical owner of the Notes body

`NoteEditorPage` currently owns the body scroll through the existing `ReorderableListView.builder`.

Do not wrap the Notes body in another vertical `Scrollable`, `NestedScrollView`, `SingleChildScrollView`, or equivalent container to solve keyboard visibility or title movement. Competing vertical scroll owners previously produced an unusable/gray editor.

The title/header may collapse or move out of the visible viewport when the mobile keyboard leaves little space, but this must not be implemented by adding a second vertical scroll hierarchy around the body.

### 2. Every top-level reorderable child must keep a stable block key

Every widget returned by the `ReorderableListView.builder` `itemBuilder` must have a stable key derived from the note block id, normally:

```dart
ValueKey<String>(block.id)
```

The key must be on the **top-level widget actually returned by `_buildBlock()`**.

A key on `NotesEditorBlockItem` is not sufficient if that widget is later wrapped in `Padding`, `Stack`, `Column`, `DecoratedBox`, or another widget. If a wrapper becomes the returned child, that wrapper must carry the stable block key.

This rule applies to active and inactive blocks and to any future media/drawing/action wrappers.

### 3. Do not remove the key when adding block chrome

The gray-screen regression fixed by commit `93148e382cc764bc2a31446ab454717b1d62fc12` was caused by adding block action/drawing wrappers around `NotesEditorBlockItem` while leaving the `ValueKey` on the inner widget. The resulting top-level `Padding`/`Stack` had no key, violating `ReorderableListView` requirements.

In Flutter web release mode this can present as a large gray `ErrorWidget` occupying the Notes body while the surrounding editor shell remains visible.

When adding delete buttons, drag affordances, media previews, selection chrome, context actions, or layout wrappers, preserve the key on the returned root child.

### 4. Mobile keyboard handling must not traverse or manipulate the editor tree globally

Do not reintroduce the previous global-focus/manual-caret approach:

- no body `GlobalKey` used to walk the editor tree for keyboard correction;
- no global `FocusManager` listener that drives editor layout;
- no manual traversal to `EditableTextState` followed by `bringIntoView`;
- no repeated/polling keyboard correction loop.

That approach previously caused another gray/unusable Notes editor.

Use the existing local mechanisms instead:

- `TextField.scrollPadding` on editable Notes fields;
- the current `NotesEditorScreen` keyboard/viewport handling;
- local focus ownership where a specific field genuinely needs it;
- title/header collapse on narrow keyboard-open phone viewports without changing body scroll ownership.

### 5. The currently typed text/caret must remain above the software keyboard

On mobile web and native mobile, the active text field must remain visible while typing. This includes devices where browser viewport resizing differs from Flutter `viewInsets` behavior and iPhone keyboard/accessory UI reduces usable height.

The title may move/collapse when body editing requires the available space. The body and active caret take priority over keeping title metadata on screen.

Do not solve this by shrinking the body to zero height, adding another scroll owner, or reserving the same keyboard inset twice.

### 6. Avoid global web viewport changes for a Notes-only bug

Do not change `web/index.html`, global `html/body` overflow behavior, global viewport CSS, or app-wide layout policy solely to fix Notes keyboard behavior unless the failure has first been proven to originate outside the Notes editor.

A Notes-only regression should be fixed inside the Notes feature whenever possible.

## Known bad patterns

The following approaches are specifically known to have broken the production Notes editor and should not be repeated:

1. Wrapping the existing Notes body `ReorderableListView` in a `NestedScrollView` or another vertical scroll container.
2. Using a global focus listener plus a body `GlobalKey` and manual `EditableTextState.bringIntoView` traversal.
3. Returning an unkeyed `Padding`, `Stack`, `Column`, or other wrapper from the `ReorderableListView.builder` while the stable block key remains only on an inner child.

If a future implementation appears to require one of these patterns, stop and redesign the change around the existing scroll/key contract.

## Gray Notes body triage

If the header/toolbars remain visible but the Notes work area becomes gray or blank after a change, inspect these before changing keyboard or viewport logic again:

1. Does every top-level child returned by `_buildBlock()` have a stable `ValueKey(block.id)`?
2. Did a new wrapper become the root child and accidentally hide the inner key from `ReorderableListView`?
3. Was a second vertical scroll owner introduced?
4. Was global focus/caret traversal added?
5. Does the actual production `NoteEditorPage` reproduce the issue, rather than only a simplified `NotesEditorScreen` test fixture?

The surrounding shell remaining healthy while only the body is gray strongly suggests a widget/runtime error inside the body subtree rather than a generic page background problem.

## Verification contract

Keep verification proportional. Do not add a large Notes test suite for this contract.

For mobile keyboard changes, preserve the focused regression coverage in:

`test/notes_mobile_keyboard_regression_test.dart`

But a simplified `NotesEditorScreen` fixture is not sufficient for changes to `_buildBlock()` or reorderable wrappers. Any change to the production block root structure must also verify the real `NoteEditorPage` path or otherwise explicitly confirm that every `itemBuilder` result is keyed.

For web-impacting Notes changes, a release web build must still succeed before calling the work complete.

## Stable reference

The production gray-body fix was committed as:

`93148e382cc764bc2a31446ab454717b1d62fc12` — `Fix Notes reorderable block keys`

The successful production deploy from that source was published to `gh-pages` as:

`3d344c2453a0bcd0c88544d998ca5f750fbe12f4`

This contract records the architecture lesson from that regression so future Notes work preserves the stable editor structure rather than rediscovering it through production failures.
