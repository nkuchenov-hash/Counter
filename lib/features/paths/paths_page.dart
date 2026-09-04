import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/core/widgets/mouse_drag_scroll_behavior.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_controls.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/paths/path_repository.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/categories/picker/category_picker_contracts.dart';
import 'package:counter/shared/categories/tree/category_tree_body.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PathFolderChoice {
  const _PathFolderChoice(this.rootKeys);
  final Set<String>? rootKeys;
}
class PathsPage extends StatefulWidget {
  const PathsPage({super.key});

  @override
  State<PathsPage> createState() => _PathsPageState();
}
class _PathsPageState extends State<PathsPage> {
  static const _visibilityPrefsKey = 'category_visibility_paths_roots_v1';
  final PathRepository _repository = PathRepository();
  bool _loading = true;
  String? _error;
  PathCatalogSnapshot _catalog =
      const PathCatalogSnapshot(paths: <ProjectPathSnapshot>[]);
  String? _selectedPathId;
  Set<String>? _visibleCategoryRootKeys;
  final Map<String, ProjectPathSnapshot> _confirmedPaths = {};
  final Map<String, int> _saveGenerationByPath = {};

  bool get _ru => currentLocale.value.toLowerCase().startsWith('ru');
  List<CategoryRule> get _categoryRoots => CategoryTreeSource.childrenOf(null)
      .where((category) => !category.isArchived)
      .toList(growable: false);
  PathCategoryProjection get _projection => buildPathCategoryProjection(
        categoryRoots: _categoryRoots,
        paths: _catalog.paths,
        selectedRootKeys: _visibleCategoryRootKeys,
      );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<Set<String>?> _loadVisibilityPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_visibilityPrefsKey)) return null;
    return (prefs.getStringList(_visibilityPrefsKey) ?? const <String>[])
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  Future<void> _saveVisibilityPrefs(Set<String>? keys) async {
    final prefs = await SharedPreferences.getInstance();
    if (keys == null) {
      await prefs.remove(_visibilityPrefsKey);
      return;
    }
    final values = keys.where((value) => value.trim().isNotEmpty).toList()
      ..sort();
    await prefs.setStringList(_visibilityPrefsKey, values);
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final prefsFuture = _loadVisibilityPrefs();
      final catalog = await _repository.loadActivePaths();
      final prefs = await prefsFuture;
      if (!mounted) return;
      final visible = buildPathCategoryProjection(
        categoryRoots: _categoryRoots,
        paths: catalog.paths,
        selectedRootKeys: prefs,
      ).visiblePaths;
      final keep = visible.any((path) => path.pathId == _selectedPathId);
      _confirmedPaths
        ..clear()
        ..addEntries(catalog.paths.map((path) => MapEntry(path.pathId, path)));
      setState(() {
        _catalog = catalog;
        _visibleCategoryRootKeys = prefs;
        _selectedPathId =
            keep ? _selectedPathId : (visible.isEmpty ? null : visible.first.pathId);
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
    final id = _selectedPathId;
    if (id == null) return null;
    for (final path in _projection.visiblePaths) {
      if (path.pathId == id) return path;
    }
    return null;
  }

  ProjectPathSnapshot? _localPathById(String pathId) {
    for (final path in _catalog.paths) {
      if (path.pathId == pathId) return path;
    }
    return null;
  }

  PathStageSnapshot? _firstPendingStage(ProjectPathSnapshot path) {
    for (final stage in path.stages) {
      if (!stage.isDone) return stage;
    }
    return null;
  }

  String _categoryName(CategoryRule category) {
    if (category.id == CategoryRule.uncategorizedSyntheticId) {
      return _ru ? 'Без категории' : 'Uncategorized';
    }
    final localized =
        category.localizedNames?[_ru ? 'ru' : 'en']?.trim() ?? '';
    return localized.isNotEmpty ? localized : category.name.trim();
  }

  String _breadcrumb(ProjectPathSnapshot path) =>
      path.category.id == CategoryRule.uncategorizedSyntheticId
          ? _categoryName(path.category)
          : _repository.categoryBreadcrumb(path.category);

  List<CategoryRule> _pruneSelectorRoots(
    List<CategoryRule> roots,
    Set<int> relevantIds,
  ) {
    CategoryRule? prune(CategoryRule node) {
      final children = <CategoryRule>[];
      for (final child in node.children ?? const <CategoryRule>[]) {
        final kept = prune(child);
        if (kept != null) children.add(kept);
      }
      if (!relevantIds.contains(node.id) && children.isEmpty) return null;
      return node.copyWith(children: children);
    }

    return [for (final root in roots) if (prune(root) case final kept?) kept];
  }

  Future<void> _openFolderSelector() async {
    if (_loading || _catalog.paths.isEmpty) return;
    final roots = _categoryRoots;
    final relevantIds = relevantPathCategoryIds(
      categoryRoots: roots,
      paths: _catalog.paths,
    );
    final visibleRoots = _pruneSelectorRoots(roots, relevantIds);
    var allMode = _visibleCategoryRootKeys == null;
    var selectedIds = allMode
        ? visibleRoots.map((root) => root.id).toSet()
        : pathCategoryRootIdsForKeys(
            categoryRoots: roots,
            rootKeys: _visibleCategoryRootKeys!,
          ).where(relevantIds.contains).toSet();

    final choice = await showDialog<_PathFolderChoice>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final checkedIds = effectivePathCategoryIdsForRoots(
            categoryRoots: visibleRoots,
            selectedRootIds: selectedIds,
          );
          void toggle(int id, bool checked) {
            if (pathCategoryIsCoveredBySelectedAncestor(
              categoryRoots: visibleRoots,
              selectedRootIds: selectedIds,
              categoryId: id,
            )) return;
            final next = Set<int>.from(selectedIds);
            checked ? next.add(id) : next.remove(id);
            final keys = pathCategoryKeysForRootIds(
              categoryRoots: roots,
              rootIds: next,
            );
            setDialogState(() {
              allMode = false;
              selectedIds = pathCategoryRootIdsForKeys(
                categoryRoots: roots,
                rootKeys: keys,
              ).where(relevantIds.contains).toSet();
            });
          }

          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
              child: SizedBox(
                height: (MediaQuery.sizeOf(context).height * 0.78)
                    .clamp(420.0, 760.0)
                    .toDouble(),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _ru ? 'Папки в Путях' : 'Folders in Paths',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _ru
                                  ? 'Родитель включает всё его поддерево.'
                                  : 'A parent includes its whole subtree.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      AppIconButton(
                        icon: Icons.close_rounded,
                        tooltip: _ru ? 'Закрыть' : 'Close',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ]),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(10),
                      child: CategoryTreeBody(
                        roots: visibleRoots,
                        selectedCategoryId: null,
                        checkedCategoryIds: checkedIds,
                        onCheckedChanged: toggle,
                        expandAll: true,
                        onSelect: (id) => toggle(id, !checkedIds.contains(id)),
                        showEditChrome: false,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      AppButton.ghost(
                        label: _ru ? 'Показать всё' : 'Show all',
                        onPressed: () => Navigator.of(dialogContext)
                            .pop(const _PathFolderChoice(null)),
                      ),
                      const Spacer(),
                      AppButton.primary(
                        label: _ru ? 'Готово' : 'Done',
                        onPressed: () => Navigator.of(dialogContext).pop(
                          _PathFolderChoice(
                            allMode
                                ? null
                                : pathCategoryKeysForRootIds(
                                    categoryRoots: roots,
                                    rootIds: selectedIds,
                                  ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
    if (!mounted || choice == null) return;
    final visible = buildPathCategoryProjection(
      categoryRoots: roots,
      paths: _catalog.paths,
      selectedRootKeys: choice.rootKeys,
    ).visiblePaths;
    final keep = visible.any((path) => path.pathId == _selectedPathId);
    setState(() {
      _visibleCategoryRootKeys = choice.rootKeys;
      _selectedPathId =
          keep ? _selectedPathId : (visible.isEmpty ? null : visible.first.pathId);
    });
    unawaited(_saveVisibilityPrefs(choice.rootKeys));
  }

  Future<void> _deletePath(ProjectPathSnapshot path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ru ? 'Удалить путь?' : 'Delete Path?'),
        content: Text(
          _ru
              ? 'Путь будет удалён. История ревизий останется как аудит.'
              : 'The Path will be deleted. Revision history remains as audit.',
        ),
        actions: [
          AppButton.ghost(
            label: _ru ? 'Отмена' : 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton.destructive(
            label: _ru ? 'Удалить' : 'Delete',
            icon: Icons.delete_outline_rounded,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!await _repository.deletePath(path)) {
      if (mounted) {
        _snack(_ru ? 'Не удалось удалить путь.' : 'Could not delete Path.');
      }
      return;
    }
    _confirmedPaths.remove(path.pathId);
    _saveGenerationByPath.remove(path.pathId);
    await _load();
    if (mounted) _snack(_ru ? 'Путь удалён.' : 'Path deleted.');
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _replaceLocal(ProjectPathSnapshot updated) {
    setState(() {
      _catalog = PathCatalogSnapshot(paths: [
        for (final path in _catalog.paths)
          if (path.pathId == updated.pathId) updated else path,
      ]);
    });
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
      if (_saveGenerationByPath[after.pathId] == generation) _replaceLocal(saved);
      return;
    }
    if (_saveGenerationByPath[after.pathId] != generation) return;
    _replaceLocal(_confirmedPaths[after.pathId] ?? before);
    _snack(_ru ? 'Не удалось сохранить изменение.' : 'Could not save change.');
  }

  Future<void> _editGoal(ProjectPathSnapshot path) async {
    final controller = TextEditingController(text: path.goal);
    final value = await showDialog<String>(
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
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.of(dialogContext).pop(text);
            },
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value != path.goal) {
      unawaited(_saveOptimistic(path, path.copyWith(goal: value)));
    }
  }

  String? _requiredField(String? value) =>
      value == null || value.trim().isEmpty
          ? (_ru ? 'Обязательное поле' : 'Required field')
          : null;

  String? _minutesField(String? value) {
    final minutes = int.tryParse(value?.trim() ?? '');
    if (minutes == null || minutes < 1 || minutes > 30) {
      return _ru ? 'От 1 до 30 минут' : 'Enter 1–30 minutes';
    }
    return null;
  }

  String _manualElementId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  Future<Map<String, String>?> _actionDraft() => showAppFormDialog(
        context: context,
        title: _ru ? 'Добавить пункт этапа' : 'Add stage item',
        cancelLabel: _ru ? 'Отмена' : 'Cancel',
        submitLabel: _ru ? 'Добавить' : 'Add',
        fields: [
          AppFormDialogField(
            keyName: 'action',
            label: _ru ? 'Пункт этапа' : 'Stage item',
            autofocus: true,
            validator: _requiredField,
          ),
          AppFormDialogField(
            keyName: 'result',
            label: _ru ? 'Ожидаемый результат' : 'Expected result',
            validator: _requiredField,
          ),
          AppFormDialogField(
            keyName: 'minutes',
            label: _ru ? 'Минуты' : 'Minutes',
            initialValue: '15',
            keyboardType: TextInputType.number,
            validator: _minutesField,
          ),
        ],
      );

  Future<Map<String, String>?> _stageDraft() => showAppFormDialog(
        context: context,
        title: _ru ? 'Добавить этап' : 'Add stage',
        cancelLabel: _ru ? 'Отмена' : 'Cancel',
        submitLabel: _ru ? 'Добавить этап' : 'Add stage',
        fields: [
          AppFormDialogField(
            keyName: 'title',
            label: _ru ? 'Название этапа' : 'Stage title',
            autofocus: true,
            validator: _requiredField,
          ),
          AppFormDialogField(
            keyName: 'criteria',
            label: _ru ? 'Готово, когда' : 'Done when',
            validator: _requiredField,
          ),
          AppFormDialogField(
            keyName: 'action',
            label: _ru ? 'Первый пункт' : 'First item',
            validator: _requiredField,
          ),
          AppFormDialogField(
            keyName: 'result',
            label: _ru ? 'Ожидаемый результат' : 'Expected result',
            validator: _requiredField,
          ),
          AppFormDialogField(
            keyName: 'minutes',
            label: _ru ? 'Минуты' : 'Minutes',
            initialValue: '15',
            keyboardType: TextInputType.number,
            validator: _minutesField,
          ),
        ],
      );

  Future<void> _addAction(ProjectPathSnapshot path, int stageIndex) async {
    final draft = await _actionDraft();
    if (!mounted || draft == null) return;
    final current = _localPathById(path.pathId) ?? path;
    if (stageIndex < 0 || stageIndex >= current.stages.length) return;
    final stages = List<PathStageSnapshot>.from(current.stages);
    final stage = stages[stageIndex];
    final actions = List<PathActionSnapshot>.from(stage.actions)
      ..add(PathActionSnapshot(
        id: _manualElementId('manual-action'),
        text: draft['action']!,
        expectedResult: draft['result']!,
        minutes: int.parse(draft['minutes']!),
        track: 'execution',
        isDone: false,
      ));
    stages[stageIndex] = stage.copyWith(actions: actions);
    unawaited(_saveOptimistic(current, current.copyWith(stages: stages)));
  }

  Future<void> _addStage(ProjectPathSnapshot path) async {
    final draft = await _stageDraft();
    if (!mounted || draft == null) return;
    final current = _localPathById(path.pathId) ?? path;
    final stages = List<PathStageSnapshot>.from(current.stages)
      ..add(PathStageSnapshot(
        id: _manualElementId('manual-stage'),
        title: draft['title']!,
        completionCriteria: draft['criteria']!,
        isDone: false,
        actions: [
          PathActionSnapshot(
            id: _manualElementId('manual-action'),
            text: draft['action']!,
            expectedResult: draft['result']!,
            minutes: int.parse(draft['minutes']!),
            track: 'execution',
            isDone: false,
          ),
        ],
      ));
    unawaited(_saveOptimistic(current, current.copyWith(stages: stages)));
  }

  void _reorderStages(
    ProjectPathSnapshot path,
    int oldIndex,
    int newIndex,
  ) {
    final current = _localPathById(path.pathId) ?? path;
    final stages = List<PathStageSnapshot>.from(current.stages);
    if (oldIndex < 0 || oldIndex >= stages.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= stages.length || newIndex == oldIndex) return;
    final moved = stages.removeAt(oldIndex);
    stages.insert(newIndex, moved);
    unawaited(_saveOptimistic(current, current.copyWith(stages: stages)));
  }

  void _toggleStage(ProjectPathSnapshot path, int index, bool done) {
    final current = _localPathById(path.pathId) ?? path;
    final stages = List<PathStageSnapshot>.from(current.stages);
    if (index < 0 || index >= stages.length) return;
    stages[index] = stages[index].copyWith(isDone: done);
    unawaited(_saveOptimistic(current, current.copyWith(stages: stages)));
  }

  void _toggleAction(
    ProjectPathSnapshot path,
    int stageIndex,
    int actionIndex,
    bool done,
  ) {
    final current = _localPathById(path.pathId) ?? path;
    final stages = List<PathStageSnapshot>.from(current.stages);
    if (stageIndex < 0 || stageIndex >= stages.length) return;
    final stage = stages[stageIndex];
    if (actionIndex < 0 || actionIndex >= stage.actions.length) return;
    final actions = List<PathActionSnapshot>.from(stage.actions);
    actions[actionIndex] = actions[actionIndex].copyWith(isDone: done);
    stages[stageIndex] = stage.copyWith(actions: actions);
    unawaited(_saveOptimistic(current, current.copyWith(stages: stages)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          _header(),
          const Divider(height: 1),
          Expanded(child: _body()),
        ]),
      ),
    );
  }

  Widget _header() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
      child: Row(children: [
        Icon(Icons.alt_route_rounded, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _ru ? 'Пути' : 'Paths',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                _ru
                    ? 'Цель → этапы → действия.'
                    : 'Goal → stages → actions.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        AppIconButton(
          icon: Icons.account_tree_outlined,
          tooltip: _ru ? 'Папки в Путях' : 'Folders in Paths',
          onPressed: _loading ? null : () => unawaited(_openFolderSelector()),
        ),
        AppIconButton(
          icon: Icons.refresh_rounded,
          tooltip: _ru ? 'Обновить' : 'Refresh',
          onPressed: _loading ? null : () => unawaited(_load()),
          loading: _loading,
        ),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return const AppLoading(size: AppLoadingSize.large);
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
        message: _ru ? 'Активных путей пока нет.' : 'There are no active Paths.',
      );
    }
    final projection = _projection;
    final visible = projection.visiblePaths;
    if (visible.isEmpty) {
      return Center(
        child: AppButton.secondary(
          label: _ru ? 'Выбрать папки' : 'Choose folders',
          icon: Icons.account_tree_outlined,
          onPressed: () => unawaited(_openFolderSelector()),
        ),
      );
    }
    final selected = _selectedPath ?? visible.first;
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 900
          ? Row(children: [
              SizedBox(width: 320, child: _pathList(projection)),
              const VerticalDivider(width: 1),
              Expanded(child: _pathDetail(selected)),
            ])
          : Column(children: [
              _mobileSelector(selected, visible),
              const Divider(height: 1),
              Expanded(child: _pathDetail(selected)),
            ]),
    );
  }

  Widget _pathList(PathCategoryProjection projection) {
    final widgets = <Widget>[];
    for (final root in projection.roots) {
      _appendCategoryNode(widgets, root, 0);
    }
    if (projection.uncategorizedPaths.isNotEmpty) {
      widgets.add(_folderRow(_ru ? 'Без категории' : 'Uncategorized', null, 0));
      for (final path in projection.uncategorizedPaths) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: _pathTile(path, path.goal),
        ));
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: widgets,
    );
  }

  void _appendCategoryNode(List<Widget> out, PathCategoryNode node, int depth) {
    final name = _categoryName(node.category);
    if (node.paths.length == 1) {
      out.add(Padding(
        padding: EdgeInsets.only(left: depth * 16.0, bottom: 4),
        child: _pathTile(node.paths.single, name),
      ));
    } else {
      out.add(_folderRow(name, node.category, depth));
      for (final path in node.paths) {
        out.add(Padding(
          padding: EdgeInsets.only(left: (depth + 1) * 16.0, bottom: 4),
          child: _pathTile(path, path.goal),
        ));
      }
    }
    for (final child in node.children) {
      _appendCategoryNode(out, child, depth + 1);
    }
  }

  Widget _folderRow(String title, CategoryRule? category, int depth) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(8 + depth * 16.0, 8, 8, 4),
      child: Row(children: [
        Icon(
          category?.iconOrDefault ?? Icons.folder_off_outlined,
          size: 19,
          color: category?.colorOrDefault ?? scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }

  Widget _pathTile(ProjectPathSnapshot path, String title) {
    final scheme = Theme.of(context).colorScheme;
    final selected = path.pathId == _selectedPathId;
    final nextStage = _firstPendingStage(path);
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        dense: true,
        selected: selected,
        leading: Icon(path.category.iconOrDefault, color: path.category.colorOrDefault),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          nextStage?.title ?? (_ru ? 'Все этапы отмечены' : 'All stages marked'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => setState(() => _selectedPathId = path.pathId),
      ),
    );
  }

  Widget _mobileSelector(
    ProjectPathSnapshot selected,
    List<ProjectPathSnapshot> paths,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: DropdownButtonFormField<String>(
        initialValue: selected.pathId,
        decoration: InputDecoration(
          labelText: _ru ? 'Путь' : 'Path',
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final path in paths)
            DropdownMenuItem<String>(
              value: path.pathId,
              child: Text(_breadcrumb(path), overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (id) {
          if (id != null) setState(() => _selectedPathId = id);
        },
      ),
    );
  }

  Widget _pathDetail(ProjectPathSnapshot path) {
    final audit = _repository.audit(path);
    final currentIndex = path.stages.indexWhere((stage) => !stage.isDone);
    final breadcrumb = _breadcrumb(path);
    return AppReorderableList(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      itemCount: path.stages.length,
      itemKeyBuilder: (index) =>
          ValueKey('path-stage-${path.pathId}-${path.stages[index].id}'),
      dragLabelBuilder: (index) => _ru
          ? 'Перетащить этап ${index + 1}'
          : 'Reorder stage ${index + 1}',
      onReorder: (oldIndex, newIndex) =>
          _reorderStages(path, oldIndex, newIndex),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (breadcrumb.contains(' › '))
            Text(
              breadcrumb,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Row(children: [
            Expanded(
              child: Text(
                _categoryName(path.category),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            AppIconButton(
              icon: Icons.edit_outlined,
              tooltip: _ru ? 'Изменить цель' : 'Edit goal',
              onPressed: () => unawaited(_editGoal(path)),
            ),
            AppIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: _ru ? 'Удалить путь' : 'Delete Path',
              onPressed: () => unawaited(_deletePath(path)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(path.goal, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          _auditCard(audit),
          const SizedBox(height: 14),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AppButton.secondary(
            label: _ru ? 'Добавить этап' : 'Add stage',
            icon: Icons.add_rounded,
            size: AppButtonSize.s,
            onPressed: () => unawaited(_addStage(path)),
          ),
        ),
      ),
      itemBuilder: (context, index, dragHandle) =>
          _stageCard(path, index, index == currentIndex, dragHandle),
    );
  }

  Widget _auditCard(PathStructureAudit audit) {
    final scheme = Theme.of(context).colorScheme;
    final ok = audit.isValid;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (ok ? scheme.secondaryContainer : scheme.errorContainer)
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ok
                ? (_ru ? 'Структура пути исполнима' : 'Path structure is executable')
                : (_ru ? 'Нужно исправить структуру' : 'Structure needs attention'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (!ok)
            for (final problem in audit.problems.take(8)) Text('• $problem'),
        ],
      ),
    );
  }

  Widget _stageCard(ProjectPathSnapshot path, int index, bool current, Widget dragHandle) {
    final stage = path.stages[index];
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final completed = Colors.green.shade600, active = Colors.amber.shade700;
    final accent = stage.isDone ? completed : (current ? active : scheme.outline);
    final headerBase = stage.isDone ? completed : (current ? active : scheme.surfaceContainerHighest);
    final headerColor = headerBase.withValues(
      alpha: stage.isDone ? (dark ? .18 : .08) : current ? (dark ? .16 : .07) : (dark ? .30 : .48),
    );
    final doneCount = stage.actions.where((action) => action.isDone).length;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(14)),
      child: Stack(children: [
        ExpansionTile(
          initiallyExpanded: current, backgroundColor: headerColor, collapsedBackgroundColor: headerColor,
          tilePadding: const EdgeInsets.fromLTRB(18, 12, 10, 12), shape: const Border(), collapsedShape: const Border(),
          leading: PlanCardCheckbox(
            selectMode: false, isSelected: false, displayIsDone: stage.isDone, toggleDoneEnabled: true,
            onToggleDone: () => _toggleStage(path, index, !stage.isDone),
          ),
          title: Row(children: [
            Container(
              width: 34, height: 34, alignment: Alignment.center,
              decoration: BoxDecoration(color: accent.withValues(alpha: dark ? .24 : .12), shape: BoxShape.circle),
              child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(stage.title, style: theme.textTheme.titleLarge?.copyWith(
              color: stage.isDone ? completed : null, fontWeight: FontWeight.w800,
            ))),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(color: accent.withValues(alpha: dark ? .24 : .12), borderRadius: BorderRadius.circular(999)),
              child: Text('${stage.isDone ? '✓ ' : ''}$doneCount/${stage.actions.length}',
                style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 6), dragHandle,
          ]),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text('${_ru ? 'Критерий завершения' : 'Completion criteria'}: ${stage.completionCriteria}',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          children: [Container(color: scheme.surface, child: Column(children: [
            const Divider(height: 1),
            for (var i = 0; i < stage.actions.length; i++) _actionRow(path, index, i),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Align(alignment: Alignment.centerLeft, child: AppButton.ghost(
                label: _ru ? 'Добавить пункт' : 'Add item', icon: Icons.add_rounded, size: AppButtonSize.s,
                onPressed: () => unawaited(_addAction(path, index)),
              )),
            ),
          ]))],
        ),
        Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 4, color: accent)),
      ]),
    );
  }

  Widget _actionRow(ProjectPathSnapshot path, int stageIndex, int actionIndex) {
    final action = path.stages[stageIndex].actions[actionIndex];
    final theme = Theme.of(context), scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 16, 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: PlanCardCheckbox(
          selectMode: false, isSelected: false, displayIsDone: action.isDone, toggleDoneEnabled: true,
          onToggleDone: () => _toggleAction(path, stageIndex, actionIndex, !action.isDone),
        )),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(action.text, style: theme.textTheme.bodyLarge?.copyWith(
            color: action.isDone ? scheme.onSurfaceVariant : scheme.onSurface,
            decoration: action.isDone ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w400,
          )),
          if (action.expectedResult.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${_ru ? 'Результат' : 'Output'}: ${action.expectedResult}',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ])),
        const SizedBox(width: 12),
        Padding(padding: const EdgeInsets.only(top: 4), child: Text('${action.minutes} ${_ru ? 'мин' : 'min'}',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
      ]),
    );
  }
}
