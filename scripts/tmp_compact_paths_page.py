from pathlib import Path

p = Path('lib/features/paths/paths_page.dart')
s = p.read_text()

def one(old, new, label):
    global s
    n = s.count(old)
    if n != 1:
        raise SystemExit(f'{label}: expected 1 match, got {n}')
    s = s.replace(old, new, 1)

one("""  void _reorderActions(
    ProjectPathSnapshot path,
    int stageIndex,
    int oldIndex,
    int newIndex,
  ) {
    final current = _localPathById(path.pathId) ?? path;
    final stages = List<PathStageSnapshot>.from(current.stages);
    if (stageIndex < 0 || stageIndex >= stages.length) return;
    final stage = stages[stageIndex];
    final actions = List<PathActionSnapshot>.from(stage.actions);
    if (oldIndex < 0 || oldIndex >= actions.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= actions.length || newIndex == oldIndex) return;
    final moved = actions.removeAt(oldIndex);
    actions.insert(newIndex, moved);
    stages[stageIndex] = stage.copyWith(actions: actions);
    unawaited(_saveOptimistic(current, current.copyWith(stages: stages)));
  }
""", """  void _reorderActions(ProjectPathSnapshot path, int stageIndex, int oldIndex, int newIndex) {
    final current = _localPathById(path.pathId) ?? path;
    final stages = List<PathStageSnapshot>.from(current.stages);
    if (stageIndex < 0 || stageIndex >= stages.length) return;
    final stage = stages[stageIndex];
    final actions = List<PathActionSnapshot>.from(stage.actions);
    if (oldIndex < 0 || oldIndex >= actions.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= actions.length || newIndex == oldIndex) return;
    actions.insert(newIndex, actions.removeAt(oldIndex));
    stages[stageIndex] = stage.copyWith(actions: actions);
    unawaited(_saveOptimistic(current, current.copyWith(stages: stages)));
  }
""", 'compact reorder actions')

one("""          Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.bodyLarge,
              children: [
                TextSpan(
                  text: _ru ? 'Цель: ' : 'Goal: ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: path.goal),
              ],
            ),
          ),
""", """          Text.rich(TextSpan(style: Theme.of(context).textTheme.bodyLarge, children: [
            TextSpan(text: _ru ? 'Цель: ' : 'Goal: ',
              style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: path.goal),
          ])),
""", 'compact goal row')

start = s.index('  Widget _actionRow(\n')
end = s.index('\n  }\n}', start) + len('\n  }')
old = s[start:end]
new = """  Widget _actionRow(ProjectPathSnapshot path, int stageIndex, int actionIndex, Widget dragHandle) {
    final action = path.stages[stageIndex].actions[actionIndex];
    final theme = Theme.of(context), scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 16, 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: .55)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: PlanCardCheckbox(
          selectMode: false, isSelected: false, displayIsDone: action.isDone,
          toggleDoneEnabled: true, onToggleDone: () =>
            _toggleAction(path, stageIndex, actionIndex, !action.isDone))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(action.text, style: theme.textTheme.bodyLarge?.copyWith(
            color: action.isDone ? scheme.onSurfaceVariant : scheme.onSurface,
            decoration: action.isDone ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w400)),
          if (action.expectedResult.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${_ru ? 'Результат' : 'Output'}: ${action.expectedResult}',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ])),
        const SizedBox(width: 12),
        Padding(padding: const EdgeInsets.only(top: 2), child: Row(
          mainAxisSize: MainAxisSize.min, children: [
            Text('${action.minutes} ${_ru ? 'мин' : 'min'}',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(width: 4), dragHandle,
          ])),
      ]),
    );
  }"""
s = s[:start] + new + s[end:]

p.write_text(s)
