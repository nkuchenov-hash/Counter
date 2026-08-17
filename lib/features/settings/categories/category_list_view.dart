import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/settings/categories/category_appearance_sheet.dart';
import 'package:counter/features/settings/categories/category_editor_sheet.dart';
import 'package:counter/features/settings/categories/category_row_widget.dart';
import 'package:counter/features/settings/categories/create_category_dialog.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

export 'package:counter/features/settings/categories/category_editor_sheet.dart'
    show CategoryEditorSheet;
export 'package:counter/features/settings/categories/category_row_widget.dart'
    show CategoryBandLayout, CategoryRowWidget;
export 'package:counter/features/settings/categories/category_tag_input_field.dart'
    show TagInputField;

// ---------------------------------------------------------------------------
// CATEGORIES FEATURE — UI_ISOLATION (§7). All strings via t() from dictionary.
// No hardcoded UI text. No direct DB writes (use DatabaseService).
// ---------------------------------------------------------------------------

/// Categories tab: folder / band layout (drill-down rows) + CategoryEditorSheet.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({
    super.key,
    required this.rules,
    required this.onChanged,
  });

  final List<CategoryRule> rules;
  final Future<void> Function() onChanged;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final List<int?> _selectedPath = [null, null, null, null];
  bool _categoryEditMode = false;
  bool _useHorizontalScrollLayout = false;
  static const int _maxDepth = 4;

  @override
  void dispose() {
    unawaited(DatabaseService.instance.flushCategoryOrderSyncNow());
    super.dispose();
  }

  void _onCategoryBandReorder(int depth, int oldIndex, int newIndex) {
    if (!_categoryEditMode) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final parentId = depth == 0 ? null : _selectedPath[depth - 1];
    final baselineBefore = List<CategoryRule>.from(_getItemsForDepth(depth));
    if (oldIndex < 0 ||
        oldIndex >= baselineBefore.length ||
        newIndex < 0 ||
        newIndex > baselineBefore.length) {
      return;
    }
    final items = List<CategoryRule>.from(baselineBefore);
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    setState(() {
      DatabaseService.instance.applyLocalCategorySiblingOrder(parentId, items);
    });
    final after = List<CategoryRule>.from(
      DatabaseService.instance.getChildrenOf(parentId),
    );
    unawaited(
      DatabaseService.instance.persistCategorySiblingOrder(
        parentId,
        after,
        baselineBeforeReorder: baselineBefore,
      ),
    );
  }

  Future<void> _notifyChanged() async {
    if (!mounted) return;
    setState(() {});
    widget.onChanged();
  }

  List<CategoryRule> _getItemsForDepth(int depth) {
    if (depth == 0) {
      return DatabaseService.instance.getChildrenOf(null);
    }
    final parentId = _selectedPath[depth - 1];
    if (parentId == null) return [];
    return DatabaseService.instance.getChildrenOf(parentId);
  }

  void _selectAtDepth(int depth, int? id) {
    setState(() {
      _selectedPath[depth] = id;
      for (var i = depth + 1; i < _maxDepth; i++) {
        _selectedPath[i] = null;
      }
    });
  }

  void _navigateToCategoryPath(List<int> path) {
    setState(() {
      for (var d = 0; d < _maxDepth; d++) {
        _selectedPath[d] = d < path.length ? path[d] : null;
      }
    });
  }

  Future<void> _showAddCategoryDialog({required int? parentId}) async {
    await showCreateCategoryDialog(
      context: context,
      parentId: parentId,
      onGoToActiveCategory: (localId) {
        final path = DatabaseService.instance.categoryPathFromRootToLocalId(
          localId,
        );
        if (path.isEmpty) return;
        _navigateToCategoryPath(path);
      },
      onDone: _notifyChanged,
    );
  }

  void _clearSelectionIfDeleted(int deletedId) {
    for (var i = 0; i < _maxDepth; i++) {
      if (_selectedPath[i] == deletedId) {
        setState(() {
          for (var j = i; j < _maxDepth; j++) {
            _selectedPath[j] = null;
          }
        });
        return;
      }
    }
  }

  void _showCategoryEditorSheet(BuildContext context, CategoryRule r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => CategoryEditorSheet(
        category: r,
        onSaved: () => unawaited(_notifyChanged()),
        onCategoryDeleted: () => _clearSelectionIfDeleted(r.id),
      ),
    );
  }

  void _showCategoryAppearanceSheet(BuildContext context, CategoryRule r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => CategoryAppearanceSheet(
        category: r,
        onSaved: () => unawaited(_notifyChanged()),
      ),
    );
  }

  Future<void> _addRule() async {
    await _showAddCategoryDialog(parentId: null);
  }

  Future<void> _addSubcategoryAtDepth(int depth) async {
    final parentId = depth == 0 ? null : _selectedPath[depth - 1];
    await _showAddCategoryDialog(parentId: parentId);
  }

  Widget buildTabRow(
    BuildContext context,
    int depth,
    List<CategoryRule> items,
  ) {
    final selectedId = depth < _maxDepth ? _selectedPath[depth] : null;
    final canAddAtThisLevel =
        depth < _maxDepth && (depth == 0 || _selectedPath[depth - 1] != null);

    final band = CategoryRowWidget(
      depth: depth,
      items: items,
      immediateParentId: depth == 0 ? null : _selectedPath[depth - 1],
      selectedId: selectedId,
      onSelect: (id) => _selectAtDepth(depth, id),
      onFullSettingsTap: (r) => _showCategoryEditorSheet(context, r),
      onAppearanceTap: (r) => _showCategoryAppearanceSheet(context, r),
      onLongPressOpenEditor: (r) => _showCategoryEditorSheet(context, r),
      onReorder: _categoryEditMode
          ? (oldI, newI) => _onCategoryBandReorder(depth, oldI, newI)
          : null,
      layout: _useHorizontalScrollLayout
          ? CategoryBandLayout.horizontalPeek
          : CategoryBandLayout.wrapGrid,
      showAdd: canAddAtThisLevel,
      onAddTap: () => unawaited(_addSubcategoryAtDepth(depth)),
      editMode: _categoryEditMode,
    );

    final hasSelection = depth < _maxDepth && selectedId != null;
    final nextItems = hasSelection
        ? _getItemsForDepth(depth + 1)
        : <CategoryRule>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        band,
        if (hasSelection && depth + 1 < _maxDepth)
          buildTabRow(context, depth + 1, nextItems),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final loc = currentLocale.value;
    final roots = _getItemsForDepth(0);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(t(loc, 'categories_title')),
        actions: [
          AppIconButton(
            icon: _useHorizontalScrollLayout
                ? Icons.grid_view_rounded
                : Icons.view_week_rounded,
            tooltip: _useHorizontalScrollLayout
                ? t(loc, 'switch_to_wrap')
                : t(loc, 'switch_to_scrollable'),
            onPressed: () => setState(
              () => _useHorizontalScrollLayout = !_useHorizontalScrollLayout,
            ),
          ),
          AppIconButton(
            tooltip: t(loc, 'add_category'),
            onPressed: () => unawaited(_addRule()),
            icon: Icons.add_rounded,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 0,
              ),
              title: Text(
                t(loc, 'category_edit_mode'),
                style: textTheme.titleSmall,
              ),
              subtitle: Text(
                t(loc, 'category_edit_mode_subtitle'),
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              value: _categoryEditMode,
              onChanged: (v) => setState(() => _categoryEditMode = v),
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            Expanded(
              child: roots.isEmpty
                  ? EmptyStatePlaceholder(
                      icon: Icons.folder_outlined,
                      titleL10nKey: 'empty_categories_title',
                      subtitleL10nKey: 'empty_categories_subtitle',
                      actionLabelL10nKey: 'add_category',
                      onAction: () => unawaited(_addRule()),
                      useFilledAction: true,
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: buildTabRow(context, 0, roots),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CATEGORY PATHS — living date-free sequence from a project goal to next steps.
// Categories stay the project SSOT. One completed undated Plan row per category
// stores the Path so it remains outside active Lists / Daily Planning.
// ---------------------------------------------------------------------------

const String _kLifeOsPathMarker = 'LIFEOS_PATH::V1';

class _PathText {
  const _PathText(String locale) : ru = locale == 'ru';
  final bool ru;

  String get title => ru ? 'Пути проектов' : 'Project paths';
  String get subtitle => ru
      ? 'Живая последовательность от цели к следующим действиям'
      : 'A living sequence from the goal to next actions';
  String get path => ru ? 'Путь' : 'Path';
  String get goal => ru ? 'Цель' : 'Goal';
  String get goalHint => ru
      ? 'К чему должен прийти этот проект?'
      : 'What should this project become?';
  String get current => ru ? 'Сейчас' : 'Current';
  String get notSet => ru ? 'Путь ещё не задан' : 'Path not set yet';
  String get create => ru ? 'Создать путь' : 'Create path';
  String get addStage => ru ? 'Добавить этап' : 'Add stage';
  String get editGoal => ru ? 'Изменить цель' : 'Edit goal';
  String get editStage => ru ? 'Изменить этап' : 'Edit stage';
  String get stageHint => ru
      ? 'Что должно произойти дальше?'
      : 'What should happen next?';
  String get noStages => ru
      ? 'Добавьте первый этап. Здесь важна последовательность, а не дата.'
      : 'Add the first stage. The sequence matters here, not the date.';
  String get allDone => ru
      ? 'Все этапы выполнены. Добавьте следующий, если проект продолжается.'
      : 'All stages are complete. Add the next one if the project continues.';
  String get deleteTitle => ru ? 'Удалить этап?' : 'Delete stage?';
  String get deleteBody => ru
      ? 'Этап будет удалён из будущей последовательности.'
      : 'The stage will be removed from the future sequence.';
  String get saveFailed => ru
      ? 'Не удалось сохранить изменение.'
      : 'Could not save the change.';
  String count(int n) => ru ? '$n этапов' : '$n ${n == 1 ? 'stage' : 'stages'}';
}

class _LivingPathStage {
  const _LivingPathStage({
    required this.id,
    required this.text,
    required this.done,
  });

  final String id;
  final String text;
  final bool done;

  _LivingPathStage copyWith({String? text, bool? done}) => _LivingPathStage(
    id: id,
    text: text ?? this.text,
    done: done ?? this.done,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'text': text,
    'isDone': done,
  };
}

bool _isLivingPathRoot(PlanningTask task) =>
    (task.notesPlain ?? '').trim() == _kLifeOsPathMarker;

List<_LivingPathStage> _livingPathStages(PlanningTask task) {
  final result = <_LivingPathStage>[];
  for (var i = 0; i < task.checklist.length; i++) {
    final row = task.checklist[i];
    final text = (row['text'] ?? '').toString().trim();
    if (text.isEmpty) continue;
    final rawId = (row['id'] ?? '').toString().trim();
    result.add(
      _LivingPathStage(
        id: rawId.isEmpty ? 'legacy-$i-${text.hashCode}' : rawId,
        text: text,
        done: row['isDone'] == true,
      ),
    );
  }
  return result;
}

/// Shows every existing category/project and whether it already has a Path.
class CategoryPathsPage extends StatefulWidget {
  const CategoryPathsPage({super.key});

  @override
  State<CategoryPathsPage> createState() => _CategoryPathsPageState();
}

class _CategoryPathsPageState extends State<CategoryPathsPage> {
  bool _loading = true;
  Map<int, PlanningTask> _roots = const <int, PlanningTask>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final tasks = await DatabaseService.instance.fetchBacklogPlans(
      includeCompleted: true,
    );
    final roots = <int, PlanningTask>{};
    for (final task in tasks) {
      if (_isLivingPathRoot(task)) {
        roots.putIfAbsent(task.categoryId, () => task);
      }
    }
    if (!mounted) return;
    setState(() {
      _roots = roots;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = _PathText(currentLocale.value);
    final db = DatabaseService.instance;
    final pairs = db.allCategoryIdPathPairs.toList()
      ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: Text(copy.title)),
      body: _loading
          ? const AppLoading()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                    child: Text(
                      copy.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final pair in pairs)
                    _buildProjectTile(context, pair.id, pair.path, copy),
                ],
              ),
            ),
    );
  }

  Widget _buildProjectTile(
    BuildContext context,
    int categoryId,
    String pathLabel,
    _PathText copy,
  ) {
    final category = DatabaseService.instance.getCategoryRuleById(categoryId);
    if (category == null) return const SizedBox.shrink();
    final root = _roots[categoryId];
    final stages = root == null
        ? const <_LivingPathStage>[]
        : _livingPathStages(root);
    _LivingPathStage? current;
    for (final stage in stages) {
      if (!stage.done) {
        current = stage;
        break;
      }
    }
    final subtitle = root == null
        ? copy.notSet
        : current != null
        ? '${copy.current}: ${current.text}'
        : stages.isEmpty
        ? root.title
        : copy.allDone;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: category.colorOrDefault.withValues(alpha: 0.14),
          foregroundColor: category.colorOrDefault,
          child: Icon(category.iconOrDefault),
        ),
        title: Text(pathLabel),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (root != null)
              Text(
                copy.count(stages.length),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => CategoryPathPage(
                category: category,
                categoryPathLabel: pathLabel,
              ),
            ),
          );
          if (mounted) unawaited(_load());
        },
      ),
    );
  }
}

/// One project's living Path. Goal + ordered stages are deliberately date-free;
/// the existing Daily Planner remains the execution layer below this screen.
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
    final tasks = await DatabaseService.instance.fetchBacklogPlans(
      categoryId: widget.category.id,
      includeCompleted: true,
    );
    PlanningTask? root;
    for (final task in tasks) {
      if (_isLivingPathRoot(task)) {
        root = task;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _root = root;
      _loading = false;
    });
  }

  Future<String?> _prompt({
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t(currentLocale.value, 'cancel')),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(ctx).pop(value);
            },
            child: Text(t(currentLocale.value, 'save')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.trim();
  }

  void _error() {
    if (!mounted) return;
    final copy = _PathText(currentLocale.value);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(copy.saveFailed)));
  }

  Future<void> _createPath() async {
    if (_creating) return;
    final copy = _PathText(currentLocale.value);
    final goal = await _prompt(title: copy.goal, hint: copy.goalHint);
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
        checklist: const <Map<String, dynamic>>[],
        notesPlain: _kLifeOsPathMarker,
        isSynced: false,
      ),
    );
    if (!mounted) return;
    setState(() => _creating = false);
    if (!ok) {
      _error();
      return;
    }
    await _load();
  }

  Future<void> _save({String? goal, List<_LivingPathStage>? stages}) async {
    final before = _root;
    if (before == null) return;
    final next = before.copyWith(
      title: goal ?? before.title,
      isDone: true,
      notesPlain: _kLifeOsPathMarker,
      checklist: stages?.map((e) => e.toJson()).toList(growable: false),
    );
    setState(() => _root = next);
    final ok = await DatabaseService.instance.updatePlanningTask(
      before.planRowIdForBackend,
      planBusinessId: before.planRowId,
      title: next.title,
      categoryId: widget.category.id,
      isDone: true,
      notesPlain: _kLifeOsPathMarker,
      checklist: next.checklist,
      suppressAppSnack: true,
    );
    if (!ok && mounted) {
      setState(() => _root = before);
      _error();
    }
  }

  Future<void> _editGoal() async {
    final root = _root;
    if (root == null) return;
    final copy = _PathText(currentLocale.value);
    final value = await _prompt(
      title: copy.editGoal,
      hint: copy.goalHint,
      initial: root.title,
    );
    if (value != null && value.isNotEmpty && value != root.title) {
      await _save(goal: value);
    }
  }

  Future<void> _addStage() async {
    final root = _root;
    if (root == null) return;
    final copy = _PathText(currentLocale.value);
    final value = await _prompt(title: copy.addStage, hint: copy.stageHint);
    if (value == null || value.isEmpty) return;
    final stages = _livingPathStages(root)
      ..add(
        _LivingPathStage(
          id: 'path-${DateTime.now().microsecondsSinceEpoch}',
          text: value,
          done: false,
        ),
      );
    await _save(stages: stages);
  }

  Future<void> _editStage(int index) async {
    final root = _root;
    if (root == null) return;
    final stages = _livingPathStages(root);
    if (index < 0 || index >= stages.length) return;
    final copy = _PathText(currentLocale.value);
    final value = await _prompt(
      title: copy.editStage,
      hint: copy.stageHint,
      initial: stages[index].text,
    );
    if (value == null || value.isEmpty || value == stages[index].text) return;
    stages[index] = stages[index].copyWith(text: value);
    await _save(stages: stages);
  }

  Future<void> _deleteStage(int index) async {
    final root = _root;
    if (root == null) return;
    final stages = _livingPathStages(root);
    if (index < 0 || index >= stages.length) return;
    final copy = _PathText(currentLocale.value);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(copy.deleteTitle),
        content: Text(copy.deleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t(currentLocale.value, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t(currentLocale.value, 'delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    stages.removeAt(index);
    await _save(stages: stages);
  }

  Future<void> _toggleStage(int index, bool done) async {
    final root = _root;
    if (root == null) return;
    final stages = _livingPathStages(root);
    if (index < 0 || index >= stages.length) return;
    stages[index] = stages[index].copyWith(done: done);
    await _save(stages: stages);
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final root = _root;
    if (root == null) return;
    final stages = _livingPathStages(root);
    if (oldIndex < 0 || oldIndex >= stages.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0 || target >= stages.length) return;
    final row = stages.removeAt(oldIndex);
    stages.insert(target, row);
    await _save(stages: stages);
  }

  @override
  Widget build(BuildContext context) {
    final copy = _PathText(currentLocale.value);
    final root = _root;
    return Scaffold(
      appBar: AppBar(title: Text('${copy.path}: ${widget.categoryPathLabel}')),
      body: _loading && root == null
          ? const AppLoading()
          : root == null
          ? _empty(copy)
          : _pathBody(root, copy),
    );
  }

  Widget _empty(_PathText copy) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.alt_route_rounded, size: 56),
            const SizedBox(height: 12),
            Text(copy.notSet, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(copy.noStages, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            AppButton.primary(
              label: copy.create,
              icon: Icons.add_road_rounded,
              loading: _creating,
              onPressed: _creating ? null : () => unawaited(_createPath()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pathBody(PlanningTask root, _PathText copy) {
    final scheme = Theme.of(context).colorScheme;
    final stages = _livingPathStages(root);
    var currentIndex = -1;
    for (var i = 0; i < stages.length; i++) {
      if (!stages[i].done) {
        currentIndex = i;
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Card(
          child: ListTile(
            title: Text(copy.goal),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                root.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            trailing: AppIconButton(
              icon: Icons.edit_outlined,
              tooltip: copy.editGoal,
              onPressed: () => unawaited(_editGoal()),
            ),
          ),
        ),
        if (currentIndex >= 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.my_location_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(copy.current, style: Theme.of(context).textTheme.labelLarge),
                      Text(stages[currentIndex].text),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else if (stages.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(copy.allDone),
        ],
        const SizedBox(height: 16),
        if (stages.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(copy.noStages),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: stages.length,
            onReorder: (oldIndex, newIndex) =>
                unawaited(_reorder(oldIndex, newIndex)),
            itemBuilder: (context, index) {
              final stage = stages[index];
              final isCurrent = index == currentIndex;
              return Card(
                key: ValueKey(stage.id),
                margin: const EdgeInsets.only(bottom: 8),
                color: isCurrent
                    ? scheme.primaryContainer.withValues(alpha: 0.20)
                    : null,
                child: Row(
                  children: [
                    Checkbox(
                      value: stage.done,
                      onChanged: (v) =>
                          unawaited(_toggleStage(index, v ?? false)),
                    ),
                    Icon(
                      stage.done
                          ? Icons.check_circle_rounded
                          : isCurrent
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: stage.done
                          ? scheme.tertiary
                          : isCurrent
                          ? scheme.primary
                          : scheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => unawaited(_editStage(index)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            stage.text,
                            style: TextStyle(
                              decoration:
                                  stage.done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: t(currentLocale.value, 'delete'),
                      onPressed: () => unawaited(_deleteStage(index)),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.drag_handle_rounded),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 8),
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
