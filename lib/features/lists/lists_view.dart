// ---------------------------------------------------------------------------
// LISTS / BACKLOG — Undated plans ([PlanningTask.startTime] == null). UI_ISOLATION.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_recursive_tree.dart';
import 'package:counter/features/categories/category_visibility_prefs.dart';
import 'package:counter/features/planning/smart_input_parser.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backlog screen: grouped headers by category path, Play + Done + Delete, inline add.
class ListsPage extends StatefulWidget {
  const ListsPage({super.key});

  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const String _prefsKeyListsCategoryId = 'last_lists_category_id';
  static const String _prefsKeyPinnedListChipIds = 'pinned_list_chip_ids';

  List<PlanningTask> _flat = [];
  /// Local-only rows until [fetchBacklogPlans] returns the server copy (inline add).
  final List<PlanningTask> _pendingInline = [];
  bool _loading = true;
  int? _filterCategoryId;
  /// Leaf category IDs shown as chips (besides All); persisted as JSON in [_prefsKeyPinnedListChipIds].
  List<int> _pinnedChipIds = [];
  int? _inlineAddCategoryId;
  StreamSubscription<void>? _planRefreshSub;
  DateTime? _lastPlayDebounce;
  static const Duration _playDebounce = Duration(milliseconds: 500);
  late final TextEditingController _inlineController;
  final FocusNode _inlineFocus = FocusNode();

  void _listsVisibilityListener() {
    if (!mounted) return;
    final id = _filterCategoryId;
    if (id != null && CategoryVisibilityPrefs.isHiddenOrAncestor(id)) {
      setState(() => _filterCategoryId = null);
      unawaited(_persistFilterCategoryId(null));
      unawaited(_reload());
    }
  }

  @override
  void initState() {
    super.initState();
    _inlineController = TextEditingController();
    CategoryVisibilityPrefs.hiddenIds.addListener(_listsVisibilityListener);
    _planRefreshSub =
        DatabaseService.instance.planningRefreshNotifications.listen((_) {
      if (mounted) unawaited(_reload());
    });
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await CategoryVisibilityPrefs.ensureLoaded();
    await _loadPersistedFilter();
    await _loadPinnedChipIds();
    if (!mounted) return;
    await _reload();
  }

  Future<void> _loadPersistedFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_prefsKeyListsCategoryId);
    if (!mounted) return;
    setState(() {
      if (raw != null &&
          raw >= 0 &&
          DatabaseService.instance.categoryExists(raw)) {
        _filterCategoryId = raw;
      }
      _syncInlinePickerToFilter();
    });
  }

  void _syncInlinePickerToFilter() {
    final fid = _filterCategoryId;
    if (fid != null && _isLeafCategory(fid)) {
      _inlineAddCategoryId = fid;
    } else {
      _inlineAddCategoryId = _defaultLeafCategoryIdForAll();
    }
  }

  Future<void> _loadPinnedChipIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKeyPinnedListChipIds);
    if (!mounted) return;
    if (raw == null || raw.isEmpty) {
      setState(() => _pinnedChipIds = []);
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        setState(() => _pinnedChipIds = []);
        return;
      }
      final db = DatabaseService.instance;
      final cleaned = <int>[];
      for (final e in decoded) {
        final id = e is int ? e : int.tryParse(e.toString());
        if (id == null) continue;
        if (!db.categoryExists(id)) continue;
        if (!_isLeafCategory(id)) continue;
        if (CategoryVisibilityPrefs.isHiddenOrAncestor(id)) continue;
        cleaned.add(id);
      }
      setState(() => _pinnedChipIds = cleaned);
    } catch (_) {
      setState(() => _pinnedChipIds = []);
    }
  }

  Future<void> _persistPinnedChipIds(List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyPinnedListChipIds, jsonEncode(ids));
  }

  Future<void> _persistFilterCategoryId(int? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_prefsKeyListsCategoryId);
    } else {
      await prefs.setInt(_prefsKeyListsCategoryId, id);
    }
  }

  bool _isLeafCategory(int categoryId) =>
      DatabaseService.instance.getChildrenOf(categoryId).isEmpty;

  int? _defaultLeafCategoryIdForAll() {
    final db = DatabaseService.instance;
    final d = db.defaultCategoryId;
    if (d != null &&
        _isLeafCategory(d) &&
        !CategoryVisibilityPrefs.isHiddenOrAncestor(d)) {
      return d;
    }
    final pairs = CategoryVisibilityPrefs.filterPairs(
      db.allCategoryIdPathPairs,
      (p) => p.id,
    );
    for (final p in pairs) {
      if (_isLeafCategory(p.id)) return p.id;
    }
    return null;
  }

  void _onFilterChanged(int? id) {
    setState(() {
      _filterCategoryId = id;
      _loading = true;
      _syncInlinePickerToFilter();
    });
    unawaited(_persistFilterCategoryId(id));
    unawaited(_reload());
  }

  void _applyPinnedChipIds(List<int> next) {
    final sorted = [...next]..sort();
    setState(() => _pinnedChipIds = sorted);
    unawaited(_persistPinnedChipIds(sorted));
    final fid = _filterCategoryId;
    if (fid != null && !sorted.contains(fid)) {
      _onFilterChanged(null);
    }
  }

  Future<void> _openChipPinSettings() async {
    final loc = currentLocale.value;
    final pairs = CategoryVisibilityPrefs.filterPairs(
      DatabaseService.instance.allCategoryIdPathPairs,
      (p) => p.id,
    );
    final leaves = pairs.where((p) => _isLeafCategory(p.id)).toList();
    leaves.sort((a, b) => a.path.compareTo(b.path));
    final sel = Set<int>.from(_pinnedChipIds);

    final result = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return AlertDialog(
              title: Text(t(loc, 'lists_pin_chips_title')),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t(loc, 'lists_pin_chips_subtitle'),
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    for (final p in leaves)
                      CheckboxListTile(
                        value: sel.contains(p.id),
                        onChanged: (v) {
                          setModal(() {
                            if (v == true) {
                              sel.add(p.id);
                            } else {
                              sel.remove(p.id);
                            }
                          });
                        },
                        title: Text(_leafCategoryLabel(p.id)),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(t(loc, 'cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(sel),
                  child: Text(t(loc, 'confirm')),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;
    _applyPinnedChipIds(result.toList());
  }

  @override
  void dispose() {
    CategoryVisibilityPrefs.hiddenIds.removeListener(_listsVisibilityListener);
    _planRefreshSub?.cancel();
    _inlineController.dispose();
    _inlineFocus.dispose();
    super.dispose();
  }

  List<PlanningTask> get _displayFlat {
    final seen = <String>{};
    final out = <PlanningTask>[];
    for (final t in _pendingInline) {
      final k = t.planRowIdForBackend.trim();
      if (k.isEmpty) continue;
      if (seen.add(k)) out.add(t);
    }
    for (final t in _flat) {
      final k = t.planRowIdForBackend.trim();
      if (k.isEmpty) continue;
      if (seen.add(k)) out.add(t);
    }
    return out;
  }

  Future<void> _reload() async {
    final list = await DatabaseService.instance
        .fetchBacklogPlans(categoryId: _filterCategoryId);
    if (!mounted) return;
    setState(() {
      _flat = list;
      _pendingInline.removeWhere((p) {
        if (!p.planRowIdForBackend.startsWith('optimistic-inline-')) {
          return false;
        }
        return list.any(
          (s) =>
              s.title == p.title &&
              s.categoryId == p.categoryId &&
              s.startTime == null &&
              !s.planRowIdForBackend.startsWith('optimistic-'),
        );
      });
      _loading = false;
    });
  }

  int _sortTasks(PlanningTask a, PlanningTask b) {
    final o = a.order.compareTo(b.order);
    if (o != 0) return o;
    return a.title.compareTo(b.title);
  }

  Map<String, List<PlanningTask>> _groupByCategoryPath(
    List<PlanningTask> tasks,
  ) {
    final map = <String, List<PlanningTask>>{};
    for (final t in tasks) {
      final path =
          DatabaseService.instance.getCategoryPath(t.categoryId).trim();
      final key = path.isEmpty ? '—' : path;
      map.putIfAbsent(key, () => []).add(t);
    }
    for (final e in map.entries) {
      e.value.sort(_sortTasks);
    }
    final keys = map.keys.toList()..sort((a, b) => a.compareTo(b));
    return {for (final k in keys) k: map[k]!};
  }

  void _submitInline() {
    final raw = _inlineController.text.trim();
    if (raw.isEmpty) return;
    final stripped = SmartInputParser.backlogTitleFromRaw(raw);
    final gt = DatabaseService.instance.getCleanTitleAndTags(stripped);
    final title = gt.title.trim();
    if (title.isEmpty) return;
    final cat = _inlineAddCategoryId;
    if (cat == null) return;
    if (!_isLeafCategory(cat)) return;

    final optId =
        'optimistic-inline-${DateTime.now().microsecondsSinceEpoch}';
    final pending = PlanningTask(
      id: 0,
      planRowId: optId,
      title: title,
      categoryId: cat,
      dateKey: '',
      order: 0,
      startTime: null,
      endDateTime: null,
      rrule: null,
    );
    setState(() {
      _pendingInline.insert(0, pending);
      _inlineController.clear();
    });
    unawaited(_persistInlineAdd(pending));
  }

  Future<void> _persistInlineAdd(PlanningTask optimistic) async {
    final ord = await DatabaseService.instance.nextBacklogPlanningOrder();
    final ok = await DatabaseService.instance.addPlanningTask(
      PlanningTask(
        id: 0,
        title: optimistic.title.trim(),
        categoryId: optimistic.categoryId,
        dateKey: '',
        order: ord,
        startTime: null,
        endDateTime: null,
        rrule: null,
      ),
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _pendingInline.removeWhere(
          (t) => t.planRowIdForBackend == optimistic.planRowIdForBackend,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
      );
      return;
    }
    unawaited(_reload());
  }

  void _onPlay(PlanningTask task) {
    if (task.planRowIdForBackend.startsWith('optimistic-inline-')) return;
    final tick = DateTime.now();
    if (_lastPlayDebounce != null &&
        tick.difference(_lastPlayDebounce!) < _playDebounce) {
      return;
    }
    _lastPlayDebounce = tick;
    final loc = currentLocale.value;
    unawaited(() async {
      final id = await DatabaseService.instance.startRecordFromPlanTask(task);
      if (!mounted) return;
      if (id == null || id.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(loc, 'plan_save_failed'))),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(loc, 'record_started_message').replaceFirst('%s', task.title),
          ),
        ),
      );
    }());
  }

  void _onComplete(PlanningTask task) {
    if (task.planRowIdForBackend.startsWith('optimistic-')) return;
    final backup = task;
    setState(() {
      _flat = _flat
          .where((x) => x.planRowIdForBackend != task.planRowIdForBackend)
          .toList();
    });
    unawaited(() async {
      final ok = await DatabaseService.instance.updatePlanningTask(
        task.planRowIdForBackend,
        planBusinessId: task.planRowId,
        isDone: true,
      );
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _flat = [..._flat, backup]..sort(_sortTasks);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    }());
  }

  Future<void> _confirmAndDelete(PlanningTask task) async {
    final loc = currentLocale.value;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(loc, 'delete')),
        content: Text(t(loc, 'lists_delete_backlog_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t(loc, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t(loc, 'delete')),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    _onDelete(task);
  }

  void _onDelete(PlanningTask task) {
    final id = task.planRowIdForBackend.trim();
    if (id.startsWith('optimistic-inline-')) {
      setState(() {
        _pendingInline.removeWhere((t) => t.planRowIdForBackend == id);
      });
      return;
    }

    final backup = task;
    setState(() {
      _flat = _flat.where((x) => x.planRowIdForBackend != id).toList();
    });
    unawaited(() async {
      final ok =
          await DatabaseService.instance.deletePlanningTasksBulk([id]);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _flat = [..._flat, backup]..sort(_sortTasks);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = currentLocale.value;
    final theme = Theme.of(context);
    final filterId = _filterCategoryId;
    final parentSelected =
        filterId != null && !_isLeafCategory(filterId);
    final leafTarget = _effectiveCategoryIdForNewTask();
    final canInlineAdd = leafTarget != null && !parentSelected;

    return ValueListenableBuilder<List<int>>(
      valueListenable: CategoryVisibilityPrefs.hiddenIds,
      builder: (context, _, __) {
        final pairs = CategoryVisibilityPrefs.filterPairs(
          DatabaseService.instance.allCategoryIdPathPairs,
          (p) => p.id,
        );
        return Scaffold(
      appBar: AppBar(
        title: Text(t(loc, 'lists_title')),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: _ListsQuadraticChip(
                    label: t(loc, 'lists_filter_all'),
                    selected: filterId == null,
                    onTap: () => _onFilterChanged(null),
                  ),
                ),
                for (final p in pairs)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: _ListsQuadraticChip(
                      label: p.path,
                      selected: filterId == p.id,
                      onTap: () => _onFilterChanged(p.id),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: _inlineController,
              focusNode: _inlineFocus,
              enabled: canInlineAdd,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: parentSelected
                    ? t(loc, 'lists_select_leaf_hint')
                    : t(loc, 'lists_inline_add_hint'),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  tooltip: t(loc, 'add'),
                  onPressed: canInlineAdd ? _submitInline : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
              onSubmitted: (_) {
                if (canInlineAdd) _submitInline();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Builder(
                    builder: (context) {
                      final display = _displayFlat;
                      final grouped = _groupByCategoryPath(display);
                      return RefreshIndicator(
                        onRefresh: _reload,
                        child: display.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height:
                                        MediaQuery.sizeOf(context).height * 0.25,
                                  ),
                                  Center(
                                    child: Text(
                                      t(loc, 'lists_empty'),
                                      style:
                                          theme.textTheme.bodyLarge?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                itemCount: _itemCountForGrouped(grouped),
                                itemBuilder: (context, index) {
                                  return _buildGroupedItem(
                                    context,
                                    index,
                                    grouped,
                                    loc,
                                  );
                                },
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
      },
    );
  }

  int _itemCountForGrouped(Map<String, List<PlanningTask>> grouped) {
    var n = 0;
    for (final e in grouped.entries) {
      n += 1 + e.value.length;
    }
    return n;
  }

  Widget _buildGroupedItem(
    BuildContext context,
    int index,
    Map<String, List<PlanningTask>> grouped,
    String loc,
  ) {
    var i = index;
    for (final e in grouped.entries) {
      if (i == 0) {
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            e.key,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        );
      }
      i--;
      if (i < e.value.length) {
        final task = e.value[i];
        return _BacklogPlanCard(
          task: task,
          locale: loc,
          onPlay: () => _onPlay(task),
          onComplete: () => _onComplete(task),
          onDelete: () {
            unawaited(_confirmAndDelete(task));
          },
        );
      }
      i -= e.value.length;
    }
    return const SizedBox.shrink();
  }
}

/// Fast filter chip: rounded rect (~8px), horizontal scroll row.
class _ListsQuadraticChip extends StatelessWidget {
  const _ListsQuadraticChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

String _leafCategoryLabel(int categoryId) {
  final path = DatabaseService.instance.getCategoryPath(categoryId).trim();
  if (path.isEmpty) return '—';
  final parts = path.split(' > ').where((s) => s.isNotEmpty).toList();
  return parts.isNotEmpty ? parts.last : path;
}

class _CategorySubcategoryPill extends StatelessWidget {
  const _CategorySubcategoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _BacklogPlanCard extends StatelessWidget {
  const _BacklogPlanCard({
    required this.task,
    required this.locale,
    required this.onPlay,
    required this.onComplete,
    required this.onDelete,
  });

  final PlanningTask task;
  final String locale;
  final VoidCallback onPlay;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final err = theme.colorScheme.error;
    final pillLabel = _leafCategoryLabel(task.categoryId);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: _CategorySubcategoryPill(label: pillLabel),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: t(locale, 'start'),
              child: IconButton(
                icon: const Icon(Icons.play_arrow_rounded),
                onPressed: onPlay,
              ),
            ),
            Tooltip(
              message: t(locale, 'mark_done'),
              child: IconButton(
                icon: const Icon(Icons.check_rounded),
                onPressed: onComplete,
              ),
            ),
            Tooltip(
              message: t(locale, 'delete'),
              child: IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: err),
                onPressed: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
