// ---------------------------------------------------------------------------
// LISTS / BACKLOG — Undated plans ([PlanningTask.startTime] == null). UI_ISOLATION.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';

import 'package:counter/core/widgets/global_app_header.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_recursive_tree.dart';
import 'package:counter/features/categories/category_visibility_prefs.dart';
import 'package:counter/features/planning/smart_input_parser.dart';
import 'package:counter/features/shared/chip_component.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backlog screen: grouped headers by category path, Play + Done + Delete, inline add.
class ListsPage extends StatefulWidget {
  const ListsPage({
    super.key,
    this.selectedDate,
    this.onDateChanged,
    this.onEditTask,
  });

  /// Wall day for the unified global header (Lists content stays backlog / undated).
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDateChanged;
  /// Opens the shared planning task editor ([ActivityDetailSheet]).
  final ValueChanged<PlanningTask>? onEditTask;

  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const String _prefsKeyListsCategoryId = 'last_lists_category_id';
  static const String _prefsKeyChipMode = 'list_chip_mode';
  static const String _prefsKeyPinnedIds = 'list_pinned_ids';
  static const String _legacyPrefsKeyPinnedListChipIds = 'pinned_list_chip_ids';

  List<PlanningTask> _flat = [];
  /// Local-only rows until [fetchBacklogPlans] returns the server copy (inline add).
  final List<PlanningTask> _pendingInline = [];
  /// Full backlog snapshot for frequency-based chips (same rules as [fetchBacklogPlans] with no filter).
  List<PlanningTask> _allBacklogForFrequency = [];
  bool _loading = true;
  int? _filterCategoryId;
  /// `'manual'` = user-pinned IDs; `'frequent'` = top categories by local backlog counts.
  String _chipMode = 'frequent';
  /// Manual mode: category IDs persisted under [_prefsKeyPinnedIds].
  List<int> _pinnedChipIds = [];
  StreamSubscription<void>? _planRefreshSub;
  DateTime? _lastPlayDebounce;
  static const Duration _playDebounce = Duration(milliseconds: 500);
  late final TextEditingController _inlineController;
  final FocusNode _inlineFocus = FocusNode();

  bool _listsSelectMode = false;
  final Set<String> _selectedListKeys = <String>{};

  /// Stable key for backlog rows (matches Planning bulk selection).
  static String _listKey(PlanningTask t) {
    final p = t.planRowIdForBackend.trim();
    if (p.isNotEmpty) return p;
    return 'plan-fallback-${t.id}-${t.order}-${t.dateKey}-${t.categoryId}-${t.title}';
  }

  void _exitListsSelectMode() {
    setState(() {
      _listsSelectMode = false;
      _selectedListKeys.clear();
    });
  }

  void _toggleListKey(String key) {
    setState(() {
      if (_selectedListKeys.contains(key)) {
        _selectedListKeys.remove(key);
      } else {
        _selectedListKeys.add(key);
      }
    });
  }

  void _toggleSelectAllVisibleLists(List<PlanningTask> visible) {
    if (visible.isEmpty) return;
    setState(() {
      if (_allVisibleListsSelected(visible)) {
        for (final t in visible) {
          _selectedListKeys.remove(_listKey(t));
        }
      } else {
        for (final t in visible) {
          _selectedListKeys.add(_listKey(t));
        }
      }
    });
  }

  bool _allVisibleListsSelected(List<PlanningTask> visible) {
    if (visible.isEmpty) return false;
    for (final t in visible) {
      if (!_selectedListKeys.contains(_listKey(t))) return false;
    }
    return true;
  }

  List<PlanningTask> _tasksMatchingSelectedKeys(List<PlanningTask> display) {
    final out = <PlanningTask>[];
    for (final t in display) {
      if (_selectedListKeys.contains(_listKey(t))) out.add(t);
    }
    return out;
  }

  void _applyBulkCategoryToSelected(List<PlanningTask> display, int categoryId) {
    final tasks = _tasksMatchingSelectedKeys(display);
    if (tasks.isEmpty) return;
    for (final task in tasks) {
      if (task.planRowIdForBackend.startsWith('optimistic-inline-')) continue;
      final updated = task.copyWith(categoryId: categoryId);
      DatabaseService.instance.applyOptimisticPlanningTask(updated);
    }
    setState(() {});
    DatabaseService.instance.notifyPlanningRefresh();
    for (final task in tasks) {
      if (task.planRowIdForBackend.startsWith('optimistic-inline-')) continue;
      unawaited(
        DatabaseService.instance.updatePlanningTask(
          task.planRowIdForBackend,
          planBusinessId: task.planRowId,
          categoryId: categoryId,
          suppressAppSnack: true,
        ),
      );
    }
    _exitListsSelectMode();
  }

  void _applyBulkTagsToSelected(List<PlanningTask> display, List<Tag> tags) {
    final tasks = _tasksMatchingSelectedKeys(display);
    if (tasks.isEmpty) return;
    final tagList = List<Tag>.from(tags);
    for (final task in tasks) {
      if (task.planRowIdForBackend.startsWith('optimistic-inline-')) continue;
      final updated = task.copyWith(tags: tagList);
      DatabaseService.instance.applyOptimisticPlanningTask(updated);
    }
    setState(() {});
    DatabaseService.instance.notifyPlanningRefresh();
    for (final task in tasks) {
      if (task.planRowIdForBackend.startsWith('optimistic-inline-')) continue;
      unawaited(
        DatabaseService.instance.updatePlanningTask(
          task.planRowIdForBackend,
          planBusinessId: task.planRowId,
          tags: tagList,
          suppressAppSnack: true,
        ),
      );
    }
    _exitListsSelectMode();
  }

  Future<void> _openListsBulkCategorySheet(List<PlanningTask> display) async {
    final loc = currentLocale.value;
    final pairs = DatabaseService.instance.allCategoryIdPathPairs;
    if (pairs.isEmpty) return;
    var picked = pairs.first.id;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t(loc, 'select_category'),
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    CategoryTreeFormField(
                      value: pairs.any((p) => p.id == picked)
                          ? picked
                          : pairs.first.id,
                      decoration: InputDecoration(
                        labelText: t(loc, 'category_label'),
                      ),
                      onChanged: (id) =>
                          setModal(() => picked = id ?? picked),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        _applyBulkCategoryToSelected(display, picked);
                      },
                      child: Text(t(loc, 'save')),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openListsBulkTagsSheet(List<PlanningTask> display) async {
    final loc = currentLocale.value;
    final catalog = await DatabaseService.instance.fetchTagsForCurrentUser();
    if (!mounted) return;
    var selected = <Tag>[];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          t(loc, 'plan_sort_tags'),
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (catalog.isEmpty)
                          Text(t(loc, 'tags_empty_create_first'))
                        else
                          SizedBox(
                            height: 120,
                            child: TagQuickPickStrip(
                              tags: catalog,
                              selected: selected,
                              onToggle: (tag) {
                                setModal(() {
                                  final next = List<Tag>.from(selected);
                                  final i =
                                      next.indexWhere((x) => x.tagId == tag.tagId);
                                  if (i >= 0) {
                                    next.removeAt(i);
                                  } else {
                                    next.add(tag);
                                  }
                                  selected = next;
                                });
                              },
                            ),
                          ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(sheetCtx).pop();
                            _applyBulkTagsToSelected(display, selected);
                          },
                          child: Text(t(loc, 'save')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _listsBulkDelete(List<PlanningTask> display) async {
    final tasks = _tasksMatchingSelectedKeys(display);
    if (tasks.isEmpty) return;
    final ids = <String>[];
    for (final t in tasks) {
      if (t.planRowIdForBackend.startsWith('optimistic-inline-')) {
        setState(() {
          _pendingInline.removeWhere(
            (x) => x.planRowIdForBackend == t.planRowIdForBackend,
          );
        });
        continue;
      }
      final rid = t.recordIdForBackend.trim();
      if (rid.isNotEmpty) ids.add(rid);
    }
    if (ids.isEmpty) {
      _exitListsSelectMode();
      return;
    }
    setState(() {
      _flat = _flat
          .where(
            (x) => !tasks.any(
              (s) => s.planRowIdForBackend == x.planRowIdForBackend,
            ),
          )
          .toList();
    });
    await DatabaseService.instance.deletePlanningTasksBulk(ids);
    if (mounted) _exitListsSelectMode();
  }

  Widget? _listsBulkBottomBar(
    BuildContext context,
    ColorScheme scheme,
    List<PlanningTask> display,
  ) {
    if (_selectedListKeys.isEmpty) return null;
    final loc = currentLocale.value;
    return SafeArea(
      child: Material(
        elevation: 6,
        color: scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t(loc, 'selected_count')
                      .replaceFirst('%s', '${_selectedListKeys.length}'),
                  style: Theme.of(context).textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: _exitListsSelectMode,
                child: Text(t(loc, 'cancel')),
              ),
              IconButton(
                tooltip: t(loc, 'plan_sort_tags'),
                icon: const Icon(Icons.label_outline_rounded),
                onPressed: () => unawaited(_openListsBulkTagsSheet(display)),
              ),
              IconButton(
                tooltip: t(loc, 'category_label'),
                icon: const Icon(Icons.category_outlined),
                onPressed: () =>
                    unawaited(_openListsBulkCategorySheet(display)),
              ),
              IconButton(
                tooltip: t(loc, 'delete'),
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                onPressed: () => unawaited(_listsBulkDelete(display)),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
    await _loadChipModeAndPinnedIds();
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
    });
  }

  Future<void> _loadChipModeAndPinnedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final modeRaw = prefs.getString(_prefsKeyChipMode)?.trim().toLowerCase();
    final mode =
        (modeRaw == 'manual' || modeRaw == 'frequent') ? modeRaw! : 'frequent';

    var rawPinned = prefs.getString(_prefsKeyPinnedIds);
    if (rawPinned == null || rawPinned.isEmpty) {
      rawPinned = prefs.getString(_legacyPrefsKeyPinnedListChipIds);
      if (rawPinned != null && rawPinned.isNotEmpty) {
        await prefs.setString(_prefsKeyPinnedIds, rawPinned);
      }
    }

    final pinned = _decodePinnedIdsList(rawPinned);
    if (!mounted) return;
    setState(() {
      _chipMode = mode;
      _pinnedChipIds = pinned;
    });
  }

  List<int> _decodePinnedIdsList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return _sanitizeCategoryIdsForChips(decoded);
    } catch (_) {
      return [];
    }
  }

  List<int> _sanitizeCategoryIdsForChips(List<dynamic> decoded) {
    final ids = <int>[];
    for (final e in decoded) {
      final id = e is int ? e : int.tryParse(e.toString());
      if (id != null) ids.add(id);
    }
    return _sanitizeIntCategoryIds(ids);
  }

  List<int> _sanitizeIntCategoryIds(List<int> ids) {
    final db = DatabaseService.instance;
    final out = <int>[];
    for (final id in ids) {
      if (!db.categoryExists(id)) continue;
      if (CategoryVisibilityPrefs.isHiddenOrAncestor(id)) continue;
      out.add(id);
    }
    return out;
  }

  Future<void> _persistPinnedChipIds(List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyPinnedIds, jsonEncode(ids));
  }

  Future<void> _persistChipMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyChipMode, mode);
  }

  Future<void> _persistFilterCategoryId(int? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_prefsKeyListsCategoryId);
    } else {
      await prefs.setInt(_prefsKeyListsCategoryId, id);
    }
  }

  /// Default category when filter is "All" (any node, not leaf-only).
  int? _defaultCategoryWhenFilterAll() {
    final db = DatabaseService.instance;
    final d = db.defaultCategoryId;
    if (d != null && !CategoryVisibilityPrefs.isHiddenOrAncestor(d)) {
      return d;
    }
    final pairs = CategoryVisibilityPrefs.filterPairs(
      db.allCategoryIdPathPairs,
      (p) => p.id,
    );
    if (pairs.isEmpty) return null;
    return pairs.first.id;
  }

  /// New backlog row uses the active filter category, or [ _defaultCategoryWhenFilterAll ] when "All".
  int? _effectiveCategoryIdForNewTask() {
    final fid = _filterCategoryId;
    final db = DatabaseService.instance;
    if (fid != null &&
        db.categoryExists(fid) &&
        !CategoryVisibilityPrefs.isHiddenOrAncestor(fid)) {
      return fid;
    }
    return _defaultCategoryWhenFilterAll();
  }

  /// Counts [categoryId] on undated backlog tasks (server snapshot + optimistic inline rows).
  List<int> _computeTopFrequentCategoryIds({int maxN = 5}) {
    final counts = <int, int>{};
    for (final t in _allBacklogForFrequency) {
      counts[t.categoryId] = (counts[t.categoryId] ?? 0) + 1;
    }
    for (final t in _pendingInline) {
      if (t.startTime == null) {
        counts[t.categoryId] = (counts[t.categoryId] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    final db = DatabaseService.instance;
    final out = <int>[];
    for (final e in entries) {
      if (out.length >= maxN) break;
      if (!db.categoryExists(e.key)) continue;
      if (CategoryVisibilityPrefs.isHiddenOrAncestor(e.key)) continue;
      out.add(e.key);
    }
    return out;
  }

  List<int> _chipIdsForBar() {
    final List<int> raw;
    if (_chipMode == 'frequent') {
      raw = _computeTopFrequentCategoryIds(maxN: 5);
    } else {
      raw = [..._pinnedChipIds]..sort();
    }
    return raw
        .where((id) => !CategoryVisibilityPrefs.isHiddenOrAncestor(id))
        .toList();
  }

  void _onFilterChanged(int? id) {
    setState(() {
      _filterCategoryId = id;
      _loading = true;
      _listsSelectMode = false;
      _selectedListKeys.clear();
    });
    unawaited(_persistFilterCategoryId(id));
    unawaited(_reload());
  }

  /// Manual chip picker: tree of [CategoryRule] — parents collapsed by default.
  Widget _buildManualCategoryTreeTile(
    CategoryRule r,
    Set<int> sel,
    void Function(void Function()) setModal,
  ) {
    if (CategoryVisibilityPrefs.isHiddenOrAncestor(r.id)) {
      return const SizedBox.shrink();
    }
    final rawKids = r.children ?? const <CategoryRule>[];
    final kids = rawKids
        .where((c) => !CategoryVisibilityPrefs.isHiddenOrAncestor(c.id))
        .toList();
    final titleName = _categoryRawName(r.id);
    void toggleSel(bool? v) {
      setModal(() {
        if (v == true) {
          sel.add(r.id);
        } else {
          sel.remove(r.id);
        }
      });
    }
    if (kids.isEmpty) {
      return CheckboxListTile(
        value: sel.contains(r.id),
        onChanged: toggleSel,
        title: Text(titleName),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      );
    }
    return ExpansionTile(
      key: PageStorageKey<int>(r.id),
      initiallyExpanded: false,
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Row(
        children: [
          Checkbox(
            value: sel.contains(r.id),
            onChanged: toggleSel,
          ),
          Expanded(
            child: Text(
              titleName,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
      children: [
        for (final c in kids)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _buildManualCategoryTreeTile(c, sel, setModal),
          ),
      ],
    );
  }

  Future<void> _openChipBarSettingsSheet() async {
    final loc = currentLocale.value;
    final db = DatabaseService.instance;
    var mode = _chipMode;
    final sel = Set<int>.from(_pinnedChipIds);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final manualListHeight =
                (MediaQuery.sizeOf(ctx).height * 0.45).clamp(200.0, 520.0);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        t(loc, 'lists_chip_bar_sheet_title'),
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment<String>(
                            value: 'frequent',
                            label: Text(t(loc, 'lists_chip_mode_frequent')),
                          ),
                          ButtonSegment<String>(
                            value: 'manual',
                            label: Text(t(loc, 'lists_chip_mode_manual')),
                          ),
                        ],
                        emptySelectionAllowed: false,
                        showSelectedIcon: false,
                        selected: {mode},
                        onSelectionChanged: (Set<String> next) {
                          if (next.isEmpty) return;
                          setModal(() => mode = next.first);
                        },
                      ),
                    ),
                    if (mode == 'manual')
                      SizedBox(
                        height: manualListHeight,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          children: [
                            for (final r in db.rules)
                              _buildManualCategoryTreeTile(r, sel, setModal),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          final nextPinned =
                              _sanitizeIntCategoryIds(sel.toList());
                          setState(() {
                            _chipMode = mode;
                            if (mode == 'manual') {
                              _pinnedChipIds = nextPinned;
                            }
                          });
                          unawaited(_persistChipMode(mode));
                          if (mode == 'manual') {
                            unawaited(_persistPinnedChipIds(_pinnedChipIds));
                            final fid = _filterCategoryId;
                            if (fid != null && !_pinnedChipIds.contains(fid)) {
                              _onFilterChanged(null);
                            }
                          }
                          unawaited(_reload());
                        },
                        child: Text(t(loc, 'save')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
    final db = DatabaseService.instance;
    final results = await Future.wait<List<PlanningTask>>([
      db.fetchBacklogPlans(categoryId: _filterCategoryId),
      db.fetchBacklogPlans(categoryId: null),
    ]);
    final list = results[0];
    final allBacklog = results[1];
    if (!mounted) return;
    setState(() {
      _flat = list;
      _allBacklogForFrequency = allBacklog;
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
    final cat = _effectiveCategoryIdForNewTask();
    if (cat == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'lists_inline_add_no_category'))),
      );
      return;
    }

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
    final headerDay = widget.selectedDate ??
        DatabaseService.instance.getTimelineDeviceLocalToday();

    return ValueListenableBuilder<List<int>>(
      valueListenable: CategoryVisibilityPrefs.hiddenIds,
      builder: (context, _, _) {
        final chipIds = _chipIdsForBar();
        final display = _displayFlat;
        return Scaffold(
      appBar: AppBar(
        leading: _listsSelectMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitListsSelectMode,
                tooltip: t(loc, 'plan_exit_select'),
              )
            : null,
        title: _listsSelectMode
            ? Text(t(loc, 'plan_select_mode'))
            : GlobalAppHeader(
                selectedDate: headerDay,
                enabled: widget.onDateChanged != null,
                onDateSelected: (d) => widget.onDateChanged?.call(d),
              ),
        actions: [
          if (_listsSelectMode && filterId != null && display.isNotEmpty)
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () => _toggleSelectAllVisibleLists(display),
              child: Text(
                _allVisibleListsSelected(display)
                    ? t(loc, 'plan_deselect_visible')
                    : t(loc, 'plan_select_all'),
              ),
            ),
          if (!_listsSelectMode)
            IconButton(
              tooltip: t(loc, 'lists_chip_bar_settings_tooltip'),
              onPressed: _openChipBarSettingsSheet,
              icon: const Icon(Icons.settings_outlined),
            ),
          if (filterId != null && !_listsSelectMode)
            IconButton(
              tooltip: t(loc, 'plan_sheet_select'),
              icon: const Icon(Icons.checklist_rounded),
              onPressed: () => setState(() => _listsSelectMode = true),
            ),
        ],
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
                for (final id in chipIds)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: _ListsQuadraticChip(
                      label: _categoryRawName(id),
                      categoryColor: _listsCategoryAccentColor(id),
                      selected: filterId == id,
                      onTap: () {
                        if (filterId == id) {
                          _onFilterChanged(null);
                        } else {
                          _onFilterChanged(id);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: filterId == null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.25,
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            t(loc, 'lists_no_category_chosen'),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  )
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Builder(
                        builder: (context) {
                          final grouped = _groupByCategoryPath(display);
                          return RefreshIndicator(
                            onRefresh: _reload,
                            child: display.isEmpty
                                ? ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      SizedBox(
                                        height: MediaQuery.sizeOf(context)
                                                .height *
                                            0.25,
                                      ),
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24),
                                          child: Text(
                                            t(loc, 'lists_empty'),
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                              color: theme.colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 12, 16, 24),
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
          if (filterId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inlineController,
                      focusNode: _inlineFocus,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: t(loc, 'input_placeholder_list'),
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.45),
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _submitInline(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _submitInline,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(t(loc, 'add')),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: filterId != null && _selectedListKeys.isNotEmpty
          ? _listsBulkBottomBar(context, theme.colorScheme, display)
          : null,
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
        final key = _listKey(task);
        return _BacklogPlanCard(
          task: task,
          locale: loc,
          selectionMode: _listsSelectMode,
          isSelected: _selectedListKeys.contains(key),
          onBodyTap: () {
            if (_listsSelectMode) {
              _toggleListKey(key);
            } else {
              widget.onEditTask?.call(task);
            }
          },
          onLongPress: _listsSelectMode
              ? null
              : () {
                  setState(() {
                    _listsSelectMode = true;
                    _selectedListKeys.add(key);
                  });
                },
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
/// Fill and border use the category’s [categoryColor] (from [CategoryRule.colorValue]).
class _ListsQuadraticChip extends StatelessWidget {
  const _ListsQuadraticChip({
    required this.label,
    required this.categoryColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color categoryColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = categoryColor;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: base.withValues(alpha: selected ? 0.38 : 0.22),
            border: Border.all(
              color: base,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip bar: strict raw [CategoryRule.name] only (no breadcrumb path).
String _categoryRawName(int categoryId) {
  final r = DatabaseService.instance.getCategoryRuleById(categoryId);
  if (r == null) return '—';
  final n = r.name.trim();
  return n.isEmpty ? '—' : n;
}

Color _listsCategoryAccentColor(int categoryId) {
  final r = DatabaseService.instance.getCategoryRuleById(categoryId);
  return r?.colorOrDefault ?? Colors.grey;
}

class _BacklogPlanCard extends StatelessWidget {
  const _BacklogPlanCard({
    required this.task,
    required this.locale,
    required this.selectionMode,
    required this.isSelected,
    required this.onBodyTap,
    this.onLongPress,
    required this.onPlay,
    required this.onComplete,
    required this.onDelete,
  });

  final PlanningTask task;
  final String locale;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onBodyTap;
  final VoidCallback? onLongPress;
  final VoidCallback onPlay;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final err = scheme.error;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      color: isSelected
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      child: InkWell(
        onTap: onBodyTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: selectionMode
                    ? Checkbox(
                        value: isSelected,
                        onChanged: (_) => onBodyTap(),
                      )
                    : Checkbox(
                        value: false,
                        onChanged: (v) {
                          if (v == true) onComplete();
                        },
                      ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.only(top: 10, bottom: 10, right: 8),
                  child: Text(
                    task.title,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (!selectionMode)
                Row(
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
                      message: t(locale, 'delete'),
                      child: IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: err),
                        onPressed: onDelete,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
