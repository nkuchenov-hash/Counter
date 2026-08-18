import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/data/paths/path_repository.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// First-class Paths destination.
///
/// Opening this page only reads Path data. It does not run migrations,
/// bootstrap project-specific content, create Planner tasks, or mutate rows.
class PathsPage extends StatefulWidget {
  const PathsPage({super.key});

  @override
  State<PathsPage> createState() => _PathsPageState();
}

class _PathsPageState extends State<PathsPage> {
  final PathRepository _repository = PathRepository();

  bool _loading = true;
  String? _error;
  PathCatalogSnapshot _catalog = const PathCatalogSnapshot(
    paths: <ProjectPathSnapshot>[],
  );
  int? _selectedCategoryId;
  final Map<String, ProjectPathSnapshot> _confirmedPaths =
      <String, ProjectPathSnapshot>{};
  final Map<String, int> _saveGenerationByPath = <String, int>{};

  bool get _ru => currentLocale.value.toLowerCase().startsWith('ru');

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final catalog = await _repository.loadActivePaths();
      if (!mounted) return;
      final selectedStillExists = catalog.paths.any(
        (path) => path.category.id == _selectedCategoryId,
      );
      _confirmedPaths
        ..clear()
        ..addEntries(catalog.paths.map((path) => MapEntry(path.pathId, path)));
      setState(() {
        _catalog = catalog;
        _selectedCategoryId = selectedStillExists
            ? _selectedCategoryId
            : (catalog.paths.isEmpty ? null : catalog.paths.first.category.id);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  ProjectPathSnapshot? get _selectedPath {
    final id = _selectedCategoryId;
    if (id == null) return null;
    for (final path in _catalog.paths) {
      if (path.category.id == id) return path;
    }
    return null;
  }

  PathStageSnapshot? _firstPendingStage(ProjectPathSnapshot path) {
    for (final stage in path.stages) {
      if (!stage.isDone) return stage;
    }
    return null;
  }

  PathActionSnapshot? _firstPendingAction(PathStageSnapshot stage) {
    for (final action in stage.actions) {
      if (!action.isDone) return action;
    }
    return null;
  }

  void _replaceLocal(ProjectPathSnapshot updated) {
    final next = <ProjectPathSnapshot>[
      for (final path in _catalog.paths)
        if (path.category.id == updated.category.id) updated else path,
    ];
    setState(() => _catalog = PathCatalogSnapshot(paths: next));
  }

  Future<void> _saveOptimistic(
    ProjectPathSnapshot before,
    ProjectPathSnapshot after,
  ) async {
    final generation = (_saveGenerationByPath[after.pathId] ?? 0) + 1;
    _saveGenerationByPath[after.pathId] = generation;
    _confirmedPaths.putIfAbsent(after.pathId, () => before);
    _replaceLocal(after);

    final saved = await _repository.saveActivePath(after);
    if (!mounted) return;
    if (saved != null) {
      _confirmedPaths[after.pathId] = saved;
      if (_saveGenerationByPath[after.pathId] == generation) {
        _replaceLocal(saved);
      }
      return;
    }

    // A newer optimistic edit owns the visible state and its queued save. Only
    // the latest failed save rolls UI back to the last server-confirmed revision.
    if (_saveGenerationByPath[after.pathId] != generation) return;
    _replaceLocal(_confirmedPaths[after.pathId] ?? before);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _ru
                ? 'Не удалось сохранить изменение пути.'
                : 'Could not save the Path change.',
          ),
        ),
      );
  }

  Future<void> _editGoal(ProjectPathSnapshot path) async {
    final controller = TextEditingController(text: path.goal);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ru ? 'Цель пути' : 'Path goal'),
        content: SizedBox(
          width: 620,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: _ru
                  ? 'Конечное состояние проекта'
                  : 'Project end state',
            ),
          ),
        ),
        actions: [
          AppButton.ghost(
            label: _ru ? 'Отмена' : 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AppButton.primary(
            label: _ru ? 'Сохранить' : 'Save',
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(dialogContext).pop(value);
              }
            },
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null || result == path.goal) return;
    unawaited(_saveOptimistic(path, path.copyWith(goal: result)));
  }

  void _toggleStage(ProjectPathSnapshot path, int stageIndex, bool done) {
    if (stageIndex < 0 || stageIndex >= path.stages.length) return;
    final stages = List<PathStageSnapshot>.from(path.stages);
    stages[stageIndex] = stages[stageIndex].copyWith(isDone: done);
    unawaited(_saveOptimistic(path, path.copyWith(stages: stages)));
  }

  void _toggleAction(
    ProjectPathSnapshot path,
    int stageIndex,
    int actionIndex,
    bool done,
  ) {
    if (stageIndex < 0 || stageIndex >= path.stages.length) return;
    final stages = List<PathStageSnapshot>.from(path.stages);
    final stage = stages[stageIndex];
    if (actionIndex < 0 || actionIndex >= stage.actions.length) return;

    final actions = List<PathActionSnapshot>.from(stage.actions);
    actions[actionIndex] = actions[actionIndex].copyWith(isDone: done);
    stages[stageIndex] = stage.copyWith(actions: actions);
    unawaited(_saveOptimistic(path, path.copyWith(stages: stages)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            const Divider(height: 1),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
      child: Row(
        children: [
          Icon(Icons.alt_route_rounded, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ru ? 'Пути' : 'Paths',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  _ru
                      ? 'Цель → этапы → конкретные действия. Planner использует только активный путь.'
                      : 'Goal → stages → concrete actions. Planner consumes only the active Path.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AppIconButton(
            icon: Icons.refresh_rounded,
            tooltip: _ru ? 'Обновить' : 'Refresh',
            onPressed: _loading ? null : () => unawaited(_load()),
            loading: _loading,
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const AppLoading(size: AppLoadingSize.large);
    }
    if (_error != null) {
      return AppErrorState(
        message: _ru ? 'Не удалось загрузить пути.' : 'Could not load Paths.',
        retryLabel: _ru ? 'Повторить' : 'Retry',
        onRetry: () => unawaited(_load()),
      );
    }
    if (_catalog.paths.isEmpty) {
      return AppEmptyState(
        icon: Icons.alt_route_rounded,
        message: _ru
            ? 'Активных путей пока нет. Открытие этого экрана не создаёт и не мигрирует данные автоматически.'
            : 'There are no active Paths yet. Opening this screen does not auto-create or migrate Path data.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final selected = _selectedPath;
        if (selected == null) {
          return AppEmptyState(
            message: _ru ? 'Путь не выбран.' : 'No Path selected.',
            icon: Icons.alt_route_rounded,
          );
        }

        if (constraints.maxWidth >= 900) {
          return Row(
            children: [
              SizedBox(width: 320, child: _pathList()),
              const VerticalDivider(width: 1),
              Expanded(child: _pathDetail(selected)),
            ],
          );
        }

        return Column(
          children: [
            _mobileSelector(selected),
            const Divider(height: 1),
            Expanded(child: _pathDetail(selected)),
          ],
        );
      },
    );
  }

  Widget _pathList() {
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _catalog.paths.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final path = _catalog.paths[index];
        final selected = path.category.id == _selectedCategoryId;
        final nextStage = _firstPendingStage(path);

        return Material(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.55)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            selected: selected,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: CircleAvatar(
              backgroundColor: path.category.colorOrDefault.withValues(
                alpha: 0.14,
              ),
              foregroundColor: path.category.colorOrDefault,
              child: Icon(path.category.iconOrDefault, size: 20),
            ),
            title: Text(
              path.category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              nextStage == null
                  ? (_ru ? 'Все этапы отмечены' : 'All stages marked')
                  : nextStage.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => setState(() => _selectedCategoryId = path.category.id),
          ),
        );
      },
    );
  }

  Widget _mobileSelector(ProjectPathSnapshot selected) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DropdownButtonFormField<int>(
        initialValue: selected.category.id,
        decoration: InputDecoration(
          labelText: _ru ? 'Проект' : 'Project',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          for (final path in _catalog.paths)
            DropdownMenuItem<int>(
              value: path.category.id,
              child: Text(path.category.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedCategoryId = value);
          }
        },
      ),
    );
  }

  Widget _pathDetail(ProjectPathSnapshot path) {
    final audit = _repository.audit(path);
    final currentStageIndex = path.stages.indexWhere((stage) => !stage.isDone);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        path.category.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      _statusChip(path),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(path.goal, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
            AppIconButton(
              icon: Icons.edit_outlined,
              tooltip: _ru ? 'Изменить цель' : 'Edit goal',
              onPressed: () => unawaited(_editGoal(path)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _auditCard(audit),
        if (currentStageIndex >= 0) ...[
          const SizedBox(height: 14),
          _currentStageCard(path.stages[currentStageIndex]),
        ],
        const SizedBox(height: 16),
        for (var stageIndex = 0; stageIndex < path.stages.length; stageIndex++)
          _stageCard(path, stageIndex, stageIndex == currentStageIndex),
      ],
    );
  }

  Widget _statusChip(ProjectPathSnapshot path) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${_ru ? 'Активный' : 'Active'} · v${path.version}',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _auditCard(PathStructureAudit audit) {
    final scheme = Theme.of(context).colorScheme;
    final ok = audit.isValid;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok
            ? scheme.secondaryContainer.withValues(alpha: 0.35)
            : scheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.verified_outlined : Icons.rule_folder_outlined,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ok
                      ? (_ru
                            ? 'Структура пути исполнима'
                            : 'Path structure is executable')
                      : (_ru
                            ? 'Нужно исправить структуру'
                            : 'Structure needs attention'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (!ok)
            for (final problem in audit.problems.take(8))
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text('• $problem'),
              ),
        ],
      ),
    );
  }

  Widget _currentStageCard(PathStageSnapshot stage) {
    final scheme = Theme.of(context).colorScheme;
    final next = _firstPendingAction(stage);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _ru ? 'Сейчас' : 'Now',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            stage.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (next != null) ...[
            const SizedBox(height: 7),
            Text(
              '${_ru ? 'Следующее действие' : 'Next action'}: '
              '${next.text} · ${next.minutes} ${_ru ? 'мин' : 'min'}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _stageCard(ProjectPathSnapshot path, int stageIndex, bool current) {
    final scheme = Theme.of(context).colorScheme;
    final stage = path.stages[stageIndex];
    final doneActions = stage.actions.where((action) => action.isDone).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: current
              ? scheme.primary.withValues(alpha: 0.5)
              : scheme.outlineVariant,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: current,
        leading: Checkbox(
          value: stage.isDone,
          onChanged: (value) => _toggleStage(path, stageIndex, value ?? false),
        ),
        title: Text(
          '${stageIndex + 1}. ${stage.title}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            decoration: stage.isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${_ru ? 'Готово, когда' : 'Done when'}: '
            '${stage.completionCriteria.isEmpty ? '—' : stage.completionCriteria}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Text('$doneActions/${stage.actions.length}'),
        children: [
          for (
            var actionIndex = 0;
            actionIndex < stage.actions.length;
            actionIndex++
          )
            _actionRow(path, stageIndex, actionIndex),
        ],
      ),
    );
  }

  Widget _actionRow(ProjectPathSnapshot path, int stageIndex, int actionIndex) {
    final scheme = Theme.of(context).colorScheme;
    final action = path.stages[stageIndex].actions[actionIndex];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: action.isDone,
            onChanged: (value) =>
                _toggleAction(path, stageIndex, actionIndex, value ?? false),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.text,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: action.isDone
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (action.expectedResult.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_ru ? 'Результат' : 'Output'}: '
                      '${action.expectedResult}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '${action.minutes} ${_ru ? 'мин' : 'min'}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
