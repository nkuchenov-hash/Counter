# Paths stage card — approved Variant 2

The approved HTML mockup is the visual source of truth for the Path detail screen. Flutter must port that layout literally rather than reinterpret it or restyle an older card anatomy.

## Page hierarchy

1. Category breadcrumb.
2. Compact Path heading; do not promote it to an oversized feature-local heading.
3. Goal line with the `Цель:` / `Goal:` label emphasized in bold.
4. Ordered stage cards.
5. Add-stage action.

The former executable-structure status chip is not part of the page.

## Literal stage anatomy

The approved HTML order is:

- 4px state rail on the far left of the whole card;
- soft header zone;
- main header block = 34px number badge + 12px gap + title/criteria block;
- right header controls = progress pill + 6px gap + Options control + 6px gap + chevron;
- bottom divider;
- white action body;
- add-item footer.

Keep the Options control in the right-side header controls between progress and chevron. It replaces the visible drag glyph without changing the approved card geometry.

## Literal light-theme metrics

- card radius: 14px;
- card border: `#DDE1E6`;
- card shadow: `0 3px 12px rgba(20,24,28,.07)`;
- card-to-card gap: 12px;
- stage header padding: `12px 12px 12px 18px`;
- header main/side gap: 14px;
- number badge: 34×34px;
- title-to-criteria gap: 5px;
- stage title: 16px, 800, line-height 1.25;
- criteria: 14px, line-height 1.4;
- progress pill: 30px high, 11px horizontal padding, 13px/800 text;
- stage Options target: 36×36px; it is an editing control only;
- chevron box: 28×28px;
- action row padding: `14px 16px 14px 22px`;
- completion checkbox: canonical 32px `PlanCardCheckbox`;
- checkbox/text gap: 14px;
- action text: 16px, 400, line-height 1.35;
- result text: 14px, line-height 1.35, 4px below action text;
- minutes: 13px, 4px top alignment;
- action divider: `#E9ECEF`;
- add-item footer padding: `8px 20px 10px`.

Nested action reordering is an added behavior requirement. It must not redesign the approved row; keep the Options control as the quiet trailing editing control beside time. Holding the action row itself invokes reorder.

## State colors

Use the HTML state system in light theme:

- completed: `#2E9F58` green;
- current: `#D89614` amber;
- later pending: `#8C949E` neutral.

State color is an accent only. Completed/current header tints remain subtle; the whole card must never become a saturated state block.

## Behavior

Pending stages are expanded by default. Completed stages collapse by default. Reopening an action reopens its stage.

Both levels remain reorderable:

- stages reorder in the outer `AppReorderableList`;
- actions reorder in the nested `AppReorderableList`.

Both use stable domain keys, canonical drag mechanics, immediate local reordering, and asynchronous Path revision persistence.

## Options control, hold-to-move, and detailed editing

The visible drag glyph is replaced by an **Options** control for every stage and every stage item. A normal click/tap opens editing. **Options never owns movement.** Paths uses the same surface hold-to-move model as Plans and Notes: hold the stage header for roughly 300 ms to move that stage; hold an action row for roughly 300 ms to move that action. The stage listener is scoped to the header so it does not compete with the nested action reorder surface.

Stage editing changes the stage wording and completion criterion. Item editing owns four content levels: formulation, final expected result, optional description/context, and an optional mini-checklist. The Path heading is a first-class editable name, separate from the Path goal; both are revisioned with the rest of Path content.

The detailed Path item sheet is the single item editor for these fields; do not create a second parallel editor contract.
