from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, got {count}")
    return text.replace(old, new, 1)


path = Path('lib/features/paths/paths_page.dart')
text = path.read_text()

text = replace_once(
    text,
    "import 'package:counter/core/widgets/plan_time_task_card/plan_card_controls.dart';\n",
    "import 'package:counter/features/paths/widgets/path_stage_card.dart';\n",
    'replace stage UI import',
)

text = replace_once(
    text,
    """          if (breadcrumb.contains(' › '))
            Text(
              breadcrumb,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Row(children: [
""",
    """          if (breadcrumb.contains(' › ')) ...[
            Text(
              breadcrumb,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(children: [
""",
    'breadcrumb spacing',
)

text = replace_once(
    text,
    """          const SizedBox(height: 6),
          Text.rich(TextSpan(style: Theme.of(context).textTheme.bodyLarge, children: [
""",
    """          const SizedBox(height: 8),
          Text.rich(TextSpan(style: Theme.of(context).textTheme.bodyLarge, children: [
""",
    'goal spacing',
)

old_builder = """      itemBuilder: (context, index, dragHandle) =>
          _stageCard(path, index, index == currentIndex, dragHandle),
    );
  }

  Widget _stageCard(ProjectPathSnapshot path, int index, bool current, Widget dragHandle) {
"""
new_builder = """      itemBuilder: (context, index, dragHandle) => PathStageCard(
        pathId: path.pathId,
        stage: path.stages[index],
        index: index,
        current: index == currentIndex,
        ru: _ru,
        stageDragHandle: dragHandle,
        onAddAction: () => unawaited(_addAction(path, index)),
        onToggleAction: (actionIndex, done) =>
            _toggleAction(path, index, actionIndex, done),
        onReorderAction: (oldIndex, newIndex) =>
            _reorderActions(path, index, oldIndex, newIndex),
      ),
    );
  }

  Widget _stageCard(ProjectPathSnapshot path, int index, bool current, Widget dragHandle) {
"""
text = replace_once(text, old_builder, new_builder, 'stage card builder')

start = text.index('  Widget _stageCard(')
end = text.rfind('\n}')
if start < 0 or end <= start:
    raise SystemExit('could not find old local stage card block')
text = text[:start] + text[end:]

path.write_text(text)

docs = Path('docs/APP_STRUCTURE.md')
doc = docs.read_text()
doc = replace_once(
    doc,
    "| `paths/` | `paths_page.dart` | First-class Paths destination: project list/detail, goal/stage/action progress, generic structure audit; opening the page is read-only |",
    "| `paths/` | `paths_page.dart`, `widgets/path_stage_card.dart` | First-class Paths destination: project list/detail, compact goal header, Variant-2 structured stage/action cards, nested stage/action reorder, progress and completion controls |",
    'APP_STRUCTURE paths row',
)
docs.write_text(doc)
