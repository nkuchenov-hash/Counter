from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, got {count}")
    return text.replace(old, new, 1)


# Shared delayed hold-to-reorder primitive, matching Plans/Notes behavior.
p = Path('lib/core/widgets/mouse_drag_scroll_behavior.dart')
s = p.read_text()
anchor = """typedef AppReorderHandleBuilder =
    Widget Function(BuildContext context, int index);

"""
insert = """typedef AppReorderHandleBuilder =
    Widget Function(BuildContext context, int index);

const Duration kAppHoldToReorderDelay = Duration(milliseconds: 300);

/// Arms reorder only after a short hold on the item surface.
///
/// This matches the interaction used by Plan cards and Notes blocks: a normal
/// tap/click remains available to the feature, while holding the surface for
/// roughly 300 ms starts movement without requiring a visible drag handle.
class AppHoldToReorderListener extends ReorderableDragStartListener {
  const AppHoldToReorderListener({
    super.key,
    required super.index,
    required super.child,
    this.delay = kAppHoldToReorderDelay,
  });

  final Duration delay;

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(delay: delay, debugOwner: this);
  }
}

"""
s = replace_once(s, anchor, insert, 'shared hold reorder primitive')
p.write_text(s)

# Options is editing only; movement belongs to the surface itself.
p = Path('lib/features/paths/widgets/path_edit_sheet.dart')
s = p.read_text()
start = s.index('/// Options is the visible affordance.')
end = s.index('Future<PathEditDraft?> showPathEditSheet', start)
new_block = """/// Visible Options affordance for a Path stage/item.
///
/// Movement is intentionally not attached to this button. Paths follows the
/// same hold-to-move interaction as Plans and Notes: holding the stage header
/// or item row starts reorder, while Options remains a normal editing menu.
class PathOptionsButton extends StatelessWidget {
  const PathOptionsButton({
    super.key,
    required this.ru,
    required this.onEdit,
    this.tooltip,
  });

  final bool ru;
  final VoidCallback onEdit;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final label = tooltip ?? (ru ? 'Опции' : 'Options');
    return PopupMenuButton<_PathOptionAction>(
      tooltip: label,
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == _PathOptionAction.edit) onEdit();
      },
      itemBuilder: (context) => [
        PopupMenuItem<_PathOptionAction>(
          value: _PathOptionAction.edit,
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 19),
              const SizedBox(width: 10),
              Text(ru ? 'Изменить' : 'Edit'),
            ],
          ),
        ),
      ],
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox.square(
          dimension: 36,
          child: Icon(Icons.more_horiz_rounded, size: 21, color: color),
        ),
      ),
    );
  }
}

"""
s = s[:start] + new_block + s[end:]
p.write_text(s)

# Outer stage list keeps Options in its approved slot; stage header itself owns hold-to-move.
p = Path('lib/features/paths/paths_page.dart')
s = p.read_text()
old = """      dragHandleBuilder: (context, index) => PathOptionsReorderButton(
        index: index,
        ru: _ru,
        tooltip: _ru ? 'Опции этапа' : 'Stage options',
        onEdit: () => unawaited(_editStage(path, index)),
      ),
"""
new = """      dragHandleBuilder: (context, index) => PathOptionsButton(
        ru: _ru,
        tooltip: _ru ? 'Опции этапа' : 'Stage options',
        onEdit: () => unawaited(_editStage(path, index)),
      ),
"""
s = replace_once(s, old, new, 'stage options control')
p.write_text(s)

# Stage header hold moves the stage; action-row hold moves the action. This avoids
# nested gesture competition by not wrapping the action body in the outer stage listener.
p = Path('lib/features/paths/widgets/path_stage_card.dart')
s = p.read_text()
s = replace_once(
    s,
    """                _header(theme, stateColor, doneCount),
                if (_expanded) _body(theme),
""",
    """                AppHoldToReorderListener(
                  index: widget.index,
                  child: _header(theme, stateColor, doneCount),
                ),
                if (_expanded) _body(theme),
""",
    'stage header hold reorder',
)
s = replace_once(
    s,
    """        dragHandleBuilder: (context, actionIndex) => PathOptionsReorderButton(
          index: actionIndex,
          ru: widget.ru,
          tooltip: widget.ru ? 'Опции пункта' : 'Item options',
          onEdit: () => widget.onEditAction(actionIndex),
        ),
""",
    """        dragHandleBuilder: (context, actionIndex) => PathOptionsButton(
          ru: widget.ru,
          tooltip: widget.ru ? 'Опции пункта' : 'Item options',
          onEdit: () => widget.onEditAction(actionIndex),
        ),
""",
    'action options control',
)
old = """        itemBuilder: (context, actionIndex, actionDragHandle) => _PathActionRow(
          action: widget.stage.actions[actionIndex],
          ru: widget.ru,
          dragHandle: actionDragHandle,
          textColor: _text(theme),
          mutedColor: _muted(theme),
          dividerColor: _outlineSoft(theme),
          onToggle: (done) => widget.onToggleAction(actionIndex, done),
          onEdit: () => widget.onEditAction(actionIndex),
        ),
"""
new = """        itemBuilder: (context, actionIndex, actionDragHandle) =>
            AppHoldToReorderListener(
              index: actionIndex,
              child: _PathActionRow(
                action: widget.stage.actions[actionIndex],
                ru: widget.ru,
                dragHandle: actionDragHandle,
                textColor: _text(theme),
                mutedColor: _muted(theme),
                dividerColor: _outlineSoft(theme),
                onToggle: (done) => widget.onToggleAction(actionIndex, done),
                onEdit: () => widget.onEditAction(actionIndex),
              ),
            ),
"""
s = replace_once(s, old, new, 'action row hold reorder')
p.write_text(s)

# Approved Variant 2 behavior documentation.
p = Path('docs/PATHS_STAGE_CARD_VARIANT_2.md')
s = p.read_text()
s = s.replace(
    '- stage Options target: 36×36px; press-and-hold starts the canonical reorder gesture;',
    '- stage Options target: 36×36px; it is an editing control only;',
)
s = s.replace(
    'Nested action reordering is an added behavior requirement. It must not redesign the approved row; use the same Options control as the quiet trailing control beside time, with press-and-hold invoking reorder.',
    'Nested action reordering is an added behavior requirement. It must not redesign the approved row; keep the Options control as the quiet trailing editing control beside time. Holding the action row itself invokes reorder.',
)
old = """## Options control and detailed editing

The visible drag glyph is replaced by an **Options** control for every stage and every stage item. A normal click/tap opens editing. Holding the same control starts the canonical reorder gesture, so ordering remains available without a separate drag icon.

Stage editing changes the stage wording and completion criterion. Item editing owns four content levels: formulation, final expected result, optional description/context, and an optional mini-checklist. The Path heading is a first-class editable name, separate from the Path goal; both are revisioned with the rest of Path content.
"""
new = """## Options control, hold-to-move, and detailed editing

The visible drag glyph is replaced by an **Options** control for every stage and every stage item. A normal click/tap opens editing. **Options never owns movement.** Paths uses the same surface hold-to-move model as Plans and Notes: hold the stage header for roughly 300 ms to move that stage; hold an action row for roughly 300 ms to move that action. The stage listener is scoped to the header so it does not compete with the nested action reorder surface.

Stage editing changes the stage wording and completion criterion. Item editing owns four content levels: formulation, final expected result, optional description/context, and an optional mini-checklist. The Path heading is a first-class editable name, separate from the Path goal; both are revisioned with the rest of Path content.
"""
s = replace_once(s, old, new, 'variant2 hold-to-move docs')
p.write_text(s)

# Design-system contract: hold-to-move is canonical, Options is not a drag handle.
p = Path('docs/DESIGN_SYSTEM.md')
s = p.read_text()
s = s.replace(
    '| `Reorder` | `AppReorderableList` + `AppReorderHandle` |',
    '| `Reorder` | `AppReorderableList` + `AppReorderHandle` / `AppHoldToReorderListener` |',
)
old = """### Drag / Reorder

- Current canonical: `AppReorderableList` + `AppReorderHandle` in `lib/core/widgets/mouse_drag_scroll_behavior.dart`.
- Figma `Reorder` maps to this shared Flutter mechanism; feature screens own their item/card surface but must not recreate reorder gesture plumbing.
- The handle is explicit and discoverable (`drag_indicator`), with tooltip/semantics and a 36px interaction box.
- Reorderable items use stable domain keys; visual position is updated locally as soon as Flutter emits `onReorder`.
- Persistence is asynchronous and must not block drag motion. Failed persistence restores/reconciles the last confirmed order without duplicating items.
- Use `buildDefaultDragHandles: false`; the canonical handle owns the drag start so desktop/web/mobile behavior is consistent.
- Nested ordered groups use the same `AppReorderableList`, not feature-local drag code. Set `shrinkWrap: true`, `primary: false`, and non-scrolling physics when the nested list lives inside another scroll/reorder surface; keep stable domain keys at both levels.
"""
new = """### Drag / Reorder

- Current canonical: `AppReorderableList`, `AppReorderHandle`, and `AppHoldToReorderListener` in `lib/core/widgets/mouse_drag_scroll_behavior.dart`.
- Figma `Reorder` maps to this shared Flutter mechanism; feature screens own their item/card surface but must not recreate reorder gesture plumbing.
- Use `AppReorderHandle` when an explicit discoverable drag handle is required. Use `AppHoldToReorderListener` when the product interaction is hold-the-surface-to-move, as in Plan cards, Notes blocks, and Paths.
- Canonical surface hold delay is about 300 ms. Normal tap/click behavior remains available until the hold arms movement.
- Reorderable items use stable domain keys; visual position is updated locally as soon as Flutter emits `onReorder`.
- Persistence is asynchronous and must not block drag motion. Failed persistence restores/reconciles the last confirmed order without duplicating items.
- Use `buildDefaultDragHandles: false`; the app-owned explicit handle or delayed surface listener owns drag start so desktop/web/mobile behavior is consistent.
- Nested ordered groups use the same `AppReorderableList`, not feature-local drag code. Set `shrinkWrap: true`, `primary: false`, and non-scrolling physics when the nested list lives inside another scroll/reorder surface; keep stable domain keys at both levels.
- For nested hold-to-reorder surfaces, do not wrap a parent listener around the child reorder region. Scope the parent hold listener to its own header/surface so parent and child delayed recognizers cannot compete for the same hold.
"""
s = replace_once(s, old, new, 'design system reorder contract')
old = """### Paths: Options-as-reorder control

For ordered Path stages/items, show `more_horiz` as the visible Options affordance. Tap/click opens Edit; press-and-hold on the same control invokes the canonical reorder listener. Do not show a second drag glyph beside Options. Path item detail editing uses a sheet with formulation, final result, optional description/context, optional mini-checklist, and time estimate.
"""
new = """### Paths: Options + hold-to-move

For ordered Path stages/items, show `more_horiz` as the visible Options affordance. Tap/click opens Edit; Options does **not** start movement. Hold the stage header to move the stage, and hold the action row to move the action, using `AppHoldToReorderListener`. Do not show a second drag glyph beside Options. Path item detail editing uses a sheet with formulation, final result, optional description/context, optional mini-checklist, and time estimate.
"""
s = replace_once(s, old, new, 'paths options design-system contract')
p.write_text(s)
