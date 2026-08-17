import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

const String _kLifeOsPathMarker = 'LIFEOS_PATH::V1';

class _PathCopy {
  const _PathCopy(this.locale);

  final String locale;

  bool get _ru => locale.toLowerCase().startsWith('ru');

  String get pathsTitle => _ru ? 'Пути проектов' : 'Project paths';
  String get pathsSubtitle => _ru
      ? 'Живые последовательности от цели к следующим действиям'
      : 'Living sequences from goals to next actions';
  String get path => _ru ? 'Путь' : 'Path';
  String get goal => _ru ? 'Цель' : 'Goal';
  String get goalHint => _ru
      ? 'К чему должен прийти этот проект?'
      : 'What should this project become?';
  String get createPath => _ru ? 'Создать путь' : 'Create path';
  String get editGoal => _ru ? 'Изменить цель' : 'Edit goal';
  String get currentStage => _ru ? 'Сейчас' : 'Current stage';
  String get future => _ru ? 'Дальше' : 'Next';
  String get completed => _ru ? 'Сделано' : 'Completed';
  String get addStage => _ru ? 'Добавить этап' : 'Add stage';
  String get stageHint => _ru
      ? 'Что должно произойти дальше?'
      : 'What should happen next?';
  String get editStage => _ru ? 'Изменить этап' : 'Edit stage';
  String get deleteStage => _ru ? 'Удалить этап?' : 'Delete stage?';
  String get deleteStageBody => _ru
      ? 'Этап будет удалён из будущей последовательности.'
      : 'This stage will be removed from the future sequence.';
  String get noPath => _ru ? 'Путь ещё не задан' : 'Path not set yet';
  String get noStages => _ru
      ? 'Добавьте первый этап. Даты не обязательны — важна последовательность.'
      : 'Add the first stage. Dates are optional — the sequence is what matters.';
  String get allCompleted => _ru
      ? 'Все текущие этапы выполнены. Добавьте следующий этап, если проект продолжается.'
      : 'All current stages are completed. Add the next stage if the project continues.';
  String get goalRequired => _ru
      ? 'Сначала сформулируйте цель проекта.'
      : 'Define the project goal first.';
  String get stageRequired =>
      _ru ? 'Введите название этапа.' : 'Enter a stage name.';
  String get saveFailed => _ru
      ? 'Не удалось сохранить изменения.'
      : 'Could not save changes.';
  String stepsCount(int count) =>
      _ru ? '$count этапов' : '$count ${count == 1 ? 'stage' : 'stages'}';
}

class _PathStage {
  const _PathStage({
    required this.id,
    required this.text,
    required this.isDone,
  });

  final String id;
  final String text;
  final bool isDone;

  _PathStage copyWith({String? text, bool? isDone}) => _PathStage(
    id: id,
    text: text ?? this.text,
    isDone: isDone ?? this.isDone,
  );

  Map<String, dynamic> toChecklistMap() => <String, dynamic>{
    'id': id,
    'text': text,
    'isDone': isDone,
  };

  static _PathStage fromChecklistMap(Map<String, dynamic> map, int index) {
    final text = (map['text'] ?? '').toString().trim();
    final rawId = (map['id'] ?? '').toString().trim();
    return _PathStage(
      id: rawId.isNotEmpty ? rawId : 'legacy-$index-${text.hashCode}',
      text: text,
      isDone: map['isDone'] == true,
    );
  }
}

bool _isPathRoot(PlanningTask task) =>
    (task.notesPlain ?? '').trim() == _kLifeOsPathMarker;

List<_PathStage> _pathStagesFromTask(PlanningTask task) {
  final out = <_PathStage>[];
  for (var i = 0; i < task.checklist.length; i++) {
    final stage = _PathStage.fromChecklistMap(task.checklist[i], i);
    if (stage.text.isNotEmpty) out.add(stage);
  }
  return out;
}

/// Portfolio-level entry point. Categories remain the canonical project
/// entities; this page only shows the optional living Path attached to each.
class CategoryPathsPage extends StatefulWidget {
  const CategoryPathsPage({super.key});

  @override
  State<CategoryPathsPage> createState() => _CategoryPathsPageState();
}

class _CategoryPathsPageState extends State<CategoryPathsPage> {
  bool _loading = true;
  Map<int, PlanningTask> _rootsByCategory = const <int, PlanningTask>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final all = await DatabaseService.instance.fetchBacklogPlans(
        includeCompleted: true,
      );
      final roots = <int, PlanningTask>{};
      for (final task in all) {
        if (!_isPathRoot(task)) continue;
        roots.putIfAbsent(task.categoryId, () => task);
      }
      if (!mounted) return;
      setState(() {
        _rootsByCategory = roots;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openPath(CategoryRule category, String pathLabel) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CategoryPathPage(
          category: category,
          categoryPathLabel: pathLabel,
        ),
      ),
    );
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final copy = _PathCopy(currentLocale.value);
    final db = DatabaseService.instance;
    final pairs = db.allCategoryIdPathPairs.toList()
      ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: Text(copy.pathsTitle)),
      body: _loading
          ? const Center(child: AppLoading())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
                    child: Text(
                      copy.pathsSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final pair in pairs)
                    if (db.getCategoryRuleById(pair.id) case final category?)
                      _ProjectPathTile(
                        category: category,
                        pathLabel: pair.path,
                        root: _rootsByCategory[pair.id],
                        copy: copy,
                        onTap: () => unawaited(
                          _openPath(category, pair.path),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

class _ProjectPathTile extends StatelessWidget {
  const _ProjectPathTile({
    required this.category,
    required this.pathLabel,
    required this.root,
    required this.copy,
    required this.onTap,
  });

  final CategoryRule category;
  final String pathLabel;
  final PlanningTask? root;
  final _PathCopy copy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pathRoot = root;
    final stages = pathRoot == null
        ? const <_PathStage>[]
        : _pathStagesFromTask(pathRoot);
    _PathStage? current;
    for (final stage in stages) {
      if (!stage.isDone) {
        current = stage;
        break;
      }
    }
    final subtitle = pathRoot == null
        ? copy.noPath
        : current != null
        ? '${copy.currentStage}: ${current.text}'
        : stages.isEmpty
        ? pathRoot.title
        : copy.allCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: category.colorOrDefault.withValues(alpha: 0.14),
          foregroundColor: category.colorOrDefault,
          child: Icon(category.iconOrDefault),
        ),
        title: Text(pathLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pathRoot != null)
              Text(
                copy.stepsCount(stages.length),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Living, date-free sequence for one category/project. A single hidden
/// completed backlog Plan stores the goal in [PlanningTask.title] and the
/// ordered stages in [PlanningTask.checklist]. Keeping the root completed
/// prevents it from entering the normal active Lists/Daily Planning flow.
class CategoryPathPage extends StatefulWidget {
  const CategoryPathPage({
    super.key,
    required this.category,
    required this.categoryPathLabel,
  });

  final CategoryRule category;
  final String categoryPathLabel;

  @override
  State<CategoryPathPage> createState() => _CategoryPathPageState();
}

class _CategoryPathPageState extends State<CategoryPathPage> {
  bool _loading = true;
  bool _creating = false;
  PlanningTask? _root;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final plans = await DatabaseService.instance.fetchBacklogPlans(
        categoryId: widget.category.id,
        includeCompleted: true,
      );
      PlanningTask? found;
      for (final task in plans) {
        if (_isPathRoot(task)) {
          found = task;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _root = found;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<String?> _askForText({
    required String title,
    required String hint,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (_) {
            final text = controller.text.trim();
            if (text.isNotEmpty) Navigator.of(ctx).pop(text);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t(currentLocale.value, 'cancel')),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.of(ctx).pop(text);
            },
            child: Text(t(currentLocale.value, 'save')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.trim();
  }

  Future<void> _createPath() async {
    if (_creating) return;
    final copy = _PathCopy(currentLocale.value);
    final goal = await _askForText(title: copy.goal, hint: copy.goalHint);
    if (goal == null || goal.isEmpty) return;
    setState(() => _creating = true);
    final order = await DatabaseService.instance.nextBacklogPlanningOrder();
    final ok = await DatabaseService.instance.addPlanningTask(
      PlanningTask(
        id: 0,
        title: goal,
        categoryId: widget.category.id,
        isDone: true,
        dateKey: '',
        order: order,
        startTime: null,
        endDateTime: null,
        checklist: const <Map<String, dynamic>>[],
        notesPlain: _kLifeOsPathMarker,
        isSynced: false,
      ),
    );
    if (!mounted) return;
    setState(() => _creating = false);
    if (!ok) {
      _showMessage(copy.saveFailed);
      return;
    }
    await _load();
  }

  Future<void> _persist({
    String? goal,
    List<_PathStage>? stages,
  }) async {
    final root = _root;
    if (root == null) return;
    final next = root.copyWith(
      title: goal ?? root.title,
      isDone: true,
      notesPlain: _kLifeOsPathMarker,
      checklist: stages
          ?.map((stage) => stage.toChecklistMap())
          .toList(growable: false),
    );
    setState(() => _root = next);
    final ok = await DatabaseService.instance.updatePlanningTask(
      root.planRowIdForBackend,
      planBusinessId: root.planRowId,
      title: next.title,
      categoryId: widget.category.id,
      isDone: true,
      notesPlain: _kLifeOsPathMarker,
      checklist: next.checklist,
      suppressAppSnack: true,
    );
    if (!ok) {
      if (!mounted) return;
      setState(() => _root = root);
      _showMessage(_PathCopy(currentLocale.value).saveFailed);
    }
  }

  Future<void> _editGoal() async {
    final root = _root;
    if (root == null) return;
    final copy = _PathCopy(currentLocale.value);
    final goal = await _askForText(
      title: copy.editGoal,
      hint: copy.goalHint,
      initial: root.title,
    );
    if (goal == null || goal.isEmpty || goal == root.title) return;
    await _persist(goal: goal);
  }

  Future<void> _addStage() async {
    final root = _root;
    if (root == null) return;
    final copy = _PathCopy(currentLocale.value);
    final text = await _askForText(title: copy.addStage, hint: copy.stageHint);
    if (text == null || text.isEmpty) return;
    final stages = _pathStagesFromTask(root)
      ..add(
        _PathStage(
          id: 'path-${DateTime.now().microsecondsSinceEpoch}',
          text: text,
          isDone: false,
        ),
      );
    await _persist(stages: stages);
  }

  Future<void> _editStage(int index) async {
    final root = _root;
    if (root == null) return;
    final stages = _pathStagesFromTask(root);
    if (index < 0 || index >= stages.length) return;
    final copy = _PathCopy(currentLocale.value);
    final text = await _askForText(
      title: copy.editStage,
      hint: copy.stageHint,
      initial: stages[index].text,
    );
    if (text == null || text.isEmpty || text == stages[index].text) return;
    stages[index] = stages[index].copyWith(text: text);
    await _persist(stages: stages);
  }

  Future<void> _deleteStage(int index) async {
    final root = _root;
    if (root == null) return;
    final stages = _pathStagesFromTask(root);
    if (index < 0 || index >= stages.length) return;
    final copy = _PathCopy(currentLocale.value);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(copy.deleteStage),
        content: Text(copy.deleteStageBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t(currentLocale.value, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t(currentLocale.value, 'delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    stages.removeAt(index);
    await _persist(stages: stages);
  }

  Future<void> _toggleStage(int index, bool value) async {
    final root = _root;
    if (root == null) return;
    final stages = _pathStagesFromTask(root);
    if (index < 0 || index >= stages.length) return;
    stages[index] = stages[index].copyWith(isDone: value);
    await _persist(stages: stages);
  }

  Future<void> _reorderStages(int oldIndex, int newIndex) async {
    final root = _root;
    if (root == null) return;
    final stages = _pathStagesFromTask(root);
    if (oldIndex < 0 || oldIndex >= stages.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0 || target >= stages.length) return;
    final moved = stages.removeAt(oldIndex);
    stages.insert(target, moved);
    await _persist(stages: stages);
  }

  @override
  Widget build(BuildContext context) {
    final copy = _PathCopy(currentLocale.value);
    final root = _root;

    return Scaffold(
      appBar: AppBar(
        title: Text('${copy.path}: ${widget.categoryPathLabel}'),
      ),
      body: _loading && root == null
          ? const Center(child: AppLoading())
          : root == null
          ? _EmptyPath(
              copy: copy,
              creating: _creating,
              onCreate: () => unawaited(_createPath()),
            )
          : _buildPath(context, root, copy),
    );
  }

  Widget _buildPath(
    BuildContext context,
    PlanningTask root,
    _PathCopy copy,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final stages = _pathStagesFromTask(root);
    var currentIndex = -1;
    for (var i = 0; i < stages.length; i++) {
      if (!stages[i].isDone) {
        currentIndex = i;
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        copy.goal,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: copy.editGoal,
                      onPressed: () => unawaited(_editGoal()),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                Text(root.title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (currentIndex >= 0)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.32)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.my_location_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.currentStage,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stages[currentIndex].text,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else if (stages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              copy.allCompleted,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (stages.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              copy.noStages,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: stages.length,
            onReorder: (oldIndex, newIndex) =>
                unawaited(_reorderStages(oldIndex, newIndex)),
            itemBuilder: (context, index) {
              final stage = stages[index];
              final isCurrent = index == currentIndex;
              return _PathStageRow(
                key: ValueKey(stage.id),
                stage: stage,
                index: index,
                isCurrent: isCurrent,
                copy: copy,
                onChanged: (v) => unawaited(_toggleStage(index, v)),
                onEdit: () => unawaited(_editStage(index)),
                onDelete: () => unawaited(_deleteStage(index)),
              );
            },
          ),
        const SizedBox(height: 12),
        AppButton.secondary(
          label: copy.addStage,
          icon: Icons.add_rounded,
          fullWidth: true,
          onPressed: () => unawaited(_addStage()),
        ),
      ],
    );
  }
}

class _EmptyPath extends StatelessWidget {
  const _EmptyPath({
    required this.copy,
    required this.creating,
    required this.onCreate,
  });

  final _PathCopy copy;
  final bool creating;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.alt_route_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                copy.noPath,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                copy.noStages,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              AppButton.primary(
                label: copy.createPath,
                icon: Icons.add_road_rounded,
                loading: creating,
                onPressed: creating ? null : onCreate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PathStageRow extends StatelessWidget {
  const _PathStageRow({
    super.key,
    required this.stage,
    required this.index,
    required this.isCurrent,
    required this.copy,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final _PathStage stage;
  final int index;
  final bool isCurrent;
  final _PathCopy copy;
  final ValueChanged<bool> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stateColor = stage.isDone
        ? scheme.tertiary
        : isCurrent
        ? scheme.primary
        : scheme.outline;
    final stateIcon = stage.isDone
        ? Icons.check_circle_rounded
        : isCurrent
        ? Icons.radio_button_checked_rounded
        : Icons.radio_button_unchecked_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isCurrent
            ? scheme.primaryContainer.withValues(alpha: 0.22)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Checkbox(
              value: stage.isDone,
              onChanged: (value) => onChanged(value ?? false),
            ),
            Icon(stateIcon, size: 20, color: stateColor),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    stage.text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      decoration: stage.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      color: stage.isDone
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: t(currentLocale.value, 'edit'),
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Text(t(currentLocale.value, 'edit')),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text(t(currentLocale.value, 'delete')),
                ),
              ],
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(8, 14, 14, 14),
                child: Icon(Icons.drag_handle_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
