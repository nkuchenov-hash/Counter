// ---------------------------------------------------------------------------
// LISTS / BACKLOG — Undated plans ([PlanningTask.startTime] == null). UI_ISOLATION.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';

import 'package:counter/core/shell_layout_state.dart';
import 'package:counter/core/widgets/global_app_header.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_visibility_prefs.dart';
import 'package:counter/features/planning/smart_input_parser.dart';
import 'package:counter/features/profile/tag_manager_page.dart';
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
  static const String _prefsKeyShowListTags = 'lists_show_tags_on_cards';

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

  static const double _kShellBulkBarReservePx = 56;
  late final TextEditingController _inlineController;
  final FocusNode _inlineFocus = FocusNode();

  bool _listsSelectMode = false;
  final Set<String> _selectedListKeys = <String>{};
  bool _listsArchiveSectionExpanded = true;
  bool _showListTagsOnCards = true;

  /// Stable key for backlog rows (matches Planning bulk selection).
  static String _listKey(PlanningTask t) {
    final p = t.planRowIdForBackend.trim();
    if (p.isNotEmpty) return p;
    return 'plan-fallback-${t.id}-${t.order}-${t.dateKey}-${t.categoryId}-${t.title}';
  }

  void _syncListsShellFabBulkReserve() {
    if (!mounted) {
      return;
    }
    final shell = ShellLayoutScope.read(context, listen: false);
    if (shell.primaryTabIndex != 3) {
      return;
    }
    final show =
        _filterCategoryId != null && _selectedListKeys.isNotEmpty;
    final next = show ? _kShellBulkBarReservePx : 0.0;
    shell.setFabBottomReservePx(next);
  }

  void _exitListsSelectMode() {
    setState(() {
      _listsSelectMode = false;
      _selectedListKeys.clear();
    });
    _syncListsShellFabBulkReserve();
  }

  void _toggleListKey(String key) {
    setState(() {
      if (_selectedListKeys.contains(key)) {
        _selectedListKeys.remove(key);
      } else {
        _selectedListKeys.add(key);
      }
    });
    _syncListsShellFabBulkReserve();
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
    _syncListsShellFabBulkReserve();
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
              IconButton(
                tooltip: t(loc, 'edit'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _openListsBulkEditFirst(display),
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
    await _loadShowListTagsPref();
    if (!mounted) return;
    await _reload();
  }

  Future<void> _loadShowListTagsPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showListTagsOnCards = prefs.getBool(_prefsKeyShowListTags) ?? true;
    });
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
      raw = List<int>.from(_pinnedChipIds);
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
            var completionDraft = DatabaseService
                .instance.settings.listCompletionBehavior
                .trim()
                .toLowerCase();
            if (completionDraft != 'stay' &&
                completionDraft != 'bottom' &&
                completionDraft != 'hide' &&
                completionDraft != 'archive') {
              completionDraft = 'hide';
            }
            var showTagsDraft = _showListTagsOnCards;
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonFormField<String>(
                        value: completionDraft,
                        decoration: InputDecoration(
                          labelText: t(loc, 'lists_completion_title'),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'stay',
                            child: Text(t(loc, 'lists_completion_stay')),
                          ),
                          DropdownMenuItem(
                            value: 'bottom',
                            child: Text(t(loc, 'lists_completion_bottom')),
                          ),
                          DropdownMenuItem(
                            value: 'hide',
                            child: Text(t(loc, 'lists_completion_hide')),
                          ),
                          DropdownMenuItem(
                            value: 'archive',
                            child: Text(t(loc, 'lists_completion_archive')),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setModal(() => completionDraft = v);
                        },
                      ),
                    ),
                    SwitchListTile(
                      title: Text(t(loc, 'lists_show_list_tags')),
                      value: showTagsDraft,
                      onChanged: (v) => setModal(() => showTagsDraft = v),
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
                            _showListTagsOnCards = showTagsDraft;
                          });
                          unawaited(_persistChipMode(mode));
                          unawaited(() async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(
                              _prefsKeyShowListTags,
                              showTagsDraft,
                            );
                          }());
                          unawaited(
                            DatabaseService.instance.saveSettings(
                              DatabaseService.instance.settings.copyWith(
                                listCompletionBehavior: completionDraft,
                              ),
                            ),
                          );
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
      db.fetchBacklogPlans(
        categoryId: _filterCategoryId,
        includeCompleted: true,
      ),
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

  List<PlanningTask> _listsApplyCompletionLayout(
    List<PlanningTask> raw,
    String behNorm,
  ) {
    switch (behNorm) {
      case 'hide':
        return raw.where((t) => !t.isDone).toList();
      case 'bottom':
        final o = List<PlanningTask>.from(raw);
        o.sort((a, b) {
          if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
          return _sortTasks(a, b);
        });
        return o;
      case 'archive':
      case 'stay':
      default:
        final o = List<PlanningTask>.from(raw)..sort(_sortTasks);
        return o;
    }
  }

  List<PlanningTask> _listsArchiveDoneSlice(List<PlanningTask> flat) {
    final o = flat.where((t) => t.isDone).toList()..sort(_sortTasks);
    return o;
  }

  List<({PlanningTask task, String path})> _listsFlattenGrouped(
    Map<String, List<PlanningTask>> grouped,
  ) {
    final out = <({PlanningTask task, String path})>[];
    for (final e in grouped.entries) {
      for (final t in e.value) {
        out.add((task: t, path: e.key));
      }
    }
    return out;
  }

  void _onListsReorder(int oldIndex, int newIndex, String listBehNorm) {
    final flat = _displayFlat;
    final forGrouping = listBehNorm == 'archive'
        ? (flat.where((t) => !t.isDone).toList()..sort(_sortTasks))
        : _listsApplyCompletionLayout(flat, listBehNorm);
    final grouped = _groupByCategoryPath(forGrouping);
    final snap = _listsFlattenGrouped(grouped);
    if (oldIndex < 0 || oldIndex >= snap.length) return;
    var ni = newIndex;
    if (ni > oldIndex) ni--;
    if (ni < 0 || ni >= snap.length) return;
    final row = snap[oldIndex].task;
    if (row.planRowIdForBackend.startsWith('optimistic-')) return;
    final orderedBefore = [for (final r in snap) r.task];
    final next = List<PlanningTask>.from(orderedBefore);
    next.removeAt(oldIndex);
    next.insert(ni, row);
    final withOrders = <PlanningTask>[
      for (var i = 0; i < next.length; i++) next[i].copyWith(order: i),
    ];
    setState(() {
      final byId = {for (final t in _flat) t.planRowIdForBackend: t};
      for (final t in withOrders) {
        final id = t.planRowIdForBackend;
        if (byId.containsKey(id)) {
          byId[id] = t;
        }
      }
      _flat = byId.values.toList()..sort(_sortTasks);
    });
    unawaited(
      DatabaseService.instance.persistPlanningTaskOrder(
        withOrders,
        baselineBeforeReorder: orderedBefore,
      ),
    );
  }

  Widget _listsBacklogCard(
    PlanningTask task,
    String loc, {
    String? categoryPathHeader,
  }) {
    final key = _listKey(task);
    return _BacklogPlanCard(
      task: task,
      locale: loc,
      categoryPathHeader: categoryPathHeader,
      showTagsStrip: _showListTagsOnCards,
      selectionMode: _listsSelectMode,
      isSelected: _selectedListKeys.contains(key),
      onBodyTap: () {
        if (_listsSelectMode) {
          _toggleListKey(key);
        } else {
          widget.onEditTask?.call(task);
        }
      },
      onLongPress: null,
      onPlay: () => _onPlay(task),
      onToggleDone: (done) => _onListToggleDone(task, done),
      onDelete: () => unawaited(_confirmAndDelete(task)),
      onMenuEdit: () => widget.onEditTask?.call(task),
      onMenuSelect: () {
        setState(() {
          _listsSelectMode = true;
          _selectedListKeys.add(key);
        });
      },
    );
  }

  void _onListToggleDone(PlanningTask task, bool toDone) {
    if (task.planRowIdForBackend.startsWith('optimistic-')) return;
    if (task.isDone == toDone) return;
    final updated = task.copyWith(isDone: toDone);
    DatabaseService.instance.applyOptimisticPlanningTask(updated);
    setState(() {});
    DatabaseService.instance.notifyPlanningRefresh();
    unawaited(
      DatabaseService.instance.updatePlanningTask(
        task.planRowIdForBackend,
        planBusinessId: task.planRowId,
        isDone: toDone,
        suppressAppSnack: true,
      ),
    );
  }

  void _openListsBulkEditFirst(List<PlanningTask> display) {
    final tasks = _tasksMatchingSelectedKeys(display);
    if (tasks.isEmpty) return;
    widget.onEditTask?.call(tasks.first);
  }

  void _onManualChipReorder(List<int> chipIds, int oldIndex, int newIndex) {
    if (_chipMode != 'manual' || chipIds.length < 2) return;
    var ni = newIndex;
    if (ni > oldIndex) ni -= 1;
    if (oldIndex < 0 || oldIndex >= chipIds.length) return;
    if (ni < 0 || ni >= chipIds.length) return;
    final next = List<int>.from(chipIds);
    final row = next.removeAt(oldIndex);
    next.insert(ni, row);
    setState(() => _pinnedChipIds = _sanitizeIntCategoryIds(next));
    unawaited(_persistPinnedChipIds(_pinnedChipIds));
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

    return StreamBuilder<UserSettings>(
      stream: DatabaseService.instance.userSettingsStream,
      initialData: DatabaseService.instance.settings,
      builder: (context, settingsSnap) {
        final listBeh = (settingsSnap.data ?? DatabaseService.instance.settings)
            .listCompletionBehavior
            .trim()
            .toLowerCase();
        return ValueListenableBuilder<List<int>>(
          valueListenable: CategoryVisibilityPrefs.hiddenIds,
          builder: (context, _, __) {
            final chipIds = _chipIdsForBar();
            final flat = _displayFlat;
            final forGrouping = listBeh == 'archive'
                ? (flat.where((t) => !t.isDone).toList()..sort(_sortTasks))
                : _listsApplyCompletionLayout(flat, listBeh);
            final archiveSlice = listBeh == 'archive'
                ? _listsArchiveDoneSlice(flat)
                : const <PlanningTask>[];
            final grouped = _groupByCategoryPath(forGrouping);
            final flatRows = _listsFlattenGrouped(grouped);
            final listBodyEmpty =
                forGrouping.isEmpty && archiveSlice.isEmpty;
            _syncListsShellFabBulkReserve();
            return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: theme.colorScheme.surface,
                  elevation: 0,
                  surfaceTintColor: theme.colorScheme.surfaceTint,
                  child: SizedBox(
                    height: kToolbarHeight,
                    child: _listsSelectMode
                        ? Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: _exitListsSelectMode,
                                tooltip: t(loc, 'plan_exit_select'),
                              ),
                              Expanded(
                                child: Text(
                                  t(loc, 'plan_select_mode'),
                                  style: theme.textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (filterId != null && flat.isNotEmpty)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                  ),
                                  onPressed: () =>
                                      _toggleSelectAllVisibleLists(flat),
                                  child: Text(
                                    _allVisibleListsSelected(flat)
                                        ? t(loc, 'plan_deselect_visible')
                                        : t(loc, 'plan_select_all'),
                                  ),
                                ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: GlobalAppHeader(
                                  selectedDate: headerDay,
                                  enabled: widget.onDateChanged != null,
                                  onDateSelected: (d) =>
                                      widget.onDateChanged?.call(d),
                                ),
                              ),
                              IconButton(
                                tooltip: t(loc, 'lists_chip_bar_settings_tooltip'),
                                onPressed: _openChipBarSettingsSheet,
                                icon: const Icon(Icons.settings_rounded),
                              ),
                            ],
                          ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 48,
                        child: _chipMode == 'manual' && chipIds.length > 1
                            ? ReorderableListView.builder(
                                scrollDirection: Axis.horizontal,
                                buildDefaultDragHandles: false,
                                shrinkWrap: true,
                                physics: const ClampingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                itemCount: chipIds.length,
                                onReorder: (oldI, newI) =>
                                    _onManualChipReorder(chipIds, oldI, newI),
                                itemBuilder: (ctx, idx) {
                                  final id = chipIds[idx];
                                  return ReorderableDelayedDragStartListener(
                                    key: ValueKey<int>(id),
                                    index: idx,
                                    child: Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                          end: 8),
                                      child: _ListsQuadraticChip(
                                        label: _categoryRawName(id),
                                        categoryColor:
                                            _listsCategoryAccentColor(id),
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
                                  );
                                },
                              )
                            : ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                children: [
                                  for (final id in chipIds)
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                          end: 8),
                                      child: _ListsQuadraticChip(
                                        label: _categoryRawName(id),
                                        categoryColor:
                                            _listsCategoryAccentColor(id),
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
                      if (filterId != null)
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
                      Expanded(
                        child: filterId == null
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
                                        t(loc, 'lists_no_category_chosen'),
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
                            : _loading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : RefreshIndicator(
                                    onRefresh: _reload,
                                    child: listBodyEmpty
                                        ? ListView(
                                            physics:
                                                const AlwaysScrollableScrollPhysics(),
                                            children: [
                                              SizedBox(
                                                height: MediaQuery.sizeOf(
                                                            context)
                                                        .height *
                                                    0.25,
                                              ),
                                              Center(
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 24),
                                                  child: Text(
                                                    t(loc, 'lists_empty'),
                                                    style: theme.textTheme
                                                        .bodyLarge
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
                                        : CustomScrollView(
                                            physics:
                                                const AlwaysScrollableScrollPhysics(),
                                            slivers: [
                                              SliverPadding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        16, 8, 16, 8),
                                                sliver: SliverReorderableList(
                                                  itemCount: flatRows.length,
                                                  onReorder: (oldI, newI) =>
                                                      _onListsReorder(
                                                    oldI,
                                                    newI,
                                                    listBeh,
                                                  ),
                                                  itemBuilder:
                                                      (context, index) {
                                                    final row = flatRows[index];
                                                    final t = row.task;
                                                    final pathLabel =
                                                        row.path.trim();
                                                    return ReorderableDelayedDragStartListener(
                                                      key: ValueKey<String>(
                                                          _listKey(t)),
                                                      index: index,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                                bottom: 8),
                                                        child: _listsBacklogCard(
                                                          t,
                                                          loc,
                                                          categoryPathHeader:
                                                              pathLabel.isEmpty ||
                                                                      pathLabel ==
                                                                          '—'
                                                                  ? null
                                                                  : pathLabel,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              if (archiveSlice.isNotEmpty)
                                                SliverToBoxAdapter(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                            16, 0, 16, 24),
                                                    child: ExpansionTile(
                                                      initiallyExpanded:
                                                          _listsArchiveSectionExpanded,
                                                      onExpansionChanged: (x) {
                                                        setState(() =>
                                                            _listsArchiveSectionExpanded =
                                                                x);
                                                      },
                                                      title: Text(
                                                        t(
                                                                loc,
                                                                'lists_archive_section')
                                                            .replaceFirst(
                                                          '%s',
                                                          '${archiveSlice.length}',
                                                        ),
                                                      ),
                                                      children: [
                                                        for (final t
                                                            in archiveSlice)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                    bottom: 8),
                                                            child:
                                                                _listsBacklogCard(
                                                              t,
                                                              loc,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                  ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: filterId != null && _selectedListKeys.isNotEmpty
              ? _listsBulkBottomBar(context, theme.colorScheme, flat)
              : null,
        );
          },
        );
      },
    );
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
            color: selected
                ? scheme.primary.withValues(alpha: 0.42)
                : base.withValues(alpha: 0.22),
            border: Border.all(
              color: selected ? scheme.primary : base,
              width: selected ? 3 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SizedBox(
            height: 40,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected
                              ? scheme.onPrimary
                              : scheme.onSurface,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500,
                        ),
                  ),
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
    this.categoryPathHeader,
    required this.showTagsStrip,
    required this.selectionMode,
    required this.isSelected,
    required this.onBodyTap,
    this.onLongPress,
    required this.onPlay,
    required this.onToggleDone,
    required this.onDelete,
    required this.onMenuEdit,
    required this.onMenuSelect,
  });

  final PlanningTask task;
  final String locale;
  final String? categoryPathHeader;
  final bool showTagsStrip;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onBodyTap;
  final VoidCallback? onLongPress;
  final VoidCallback onPlay;
  final void Function(bool toDone) onToggleDone;
  final VoidCallback onDelete;
  final VoidCallback onMenuEdit;
  final VoidCallback onMenuSelect;

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: selectionMode
                    ? Checkbox(
                        value: isSelected,
                        onChanged: (_) => onBodyTap(),
                      )
                    : Checkbox(
                        value: task.isDone,
                        onChanged: task.planRowIdForBackend
                                .startsWith('optimistic-')
                            ? null
                            : (v) {
                                if (v == null) return;
                                onToggleDone(v);
                              },
                      ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.only(top: 10, bottom: 10, right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (categoryPathHeader != null &&
                          categoryPathHeader!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            categoryPathHeader!.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Text(
                        task.title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showTagsStrip &&
                          task.tags.any((tag) => tag.rendersAsChip))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: StreamBuilder<UserSettings>(
                            stream: DatabaseService.instance.userSettingsStream,
                            initialData: DatabaseService.instance.settings,
                            builder: (context, snap) {
                              final mode = snap.data?.tagDisplayMode ??
                                  CategoryDisplayMode.letterChip;
                              final scheme =
                                  Theme.of(context).colorScheme;
                              return Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  for (final tag in task.tags)
                                    if (tag.rendersAsChip)
                                      CategoryChip(
                                        mode: mode,
                                        label: tag.name.trim().isNotEmpty
                                            ? tag.name.trim()
                                            : '#${tag.tagId != 0 ? tag.tagId : tag.wrapperRowId}',
                                        color: parseTagHexColor(tag.color) ??
                                            scheme.primary,
                                        icon: iconForTagKey(tag.icon),
                                        compactGlyphLayout: true,
                                        syntheticNoTagsMonochrome:
                                            tag.tagId == -1,
                                      ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!selectionMode)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onMenuEdit();
                        break;
                      case 'select':
                        onMenuSelect();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                      case 'start':
                        onPlay();
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(t(locale, 'lists_menu_change')),
                    ),
                    PopupMenuItem(
                      value: 'select',
                      child: Text(t(locale, 'lists_menu_choose')),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        t(locale, 'delete'),
                        style: TextStyle(color: err),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'start',
                      child: Text(t(locale, 'start')),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
