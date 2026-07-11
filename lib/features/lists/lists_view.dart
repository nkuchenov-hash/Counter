// ---------------------------------------------------------------------------
// LISTS / BACKLOG — Undated plans ([PlanningTask.startTime] == null). UI_ISOLATION.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/shell_layout_state.dart';
import 'package:counter/core/widgets/global_app_header.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_visibility_prefs.dart';
import 'package:counter/data/smart_input_parser.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:counter/features/profile/tag_manager_page.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/features/lists/lists_card.dart';
import 'package:counter/features/lists/lists_export.dart';
import 'package:counter/features/lists/lists_bulk_actions.dart';
import 'package:counter/features/lists/lists_empty_state.dart';
import 'package:counter/features/lists/lists_filters.dart';
import 'package:counter/features/lists/lists_inline_add.dart';
import 'package:counter/features/notes/note_editor_page.dart';
import 'package:counter/features/notes/widgets/note_card.dart';
import 'package:counter/features/notes/widgets/notes_library_body.dart';

/// Backlog screen: grouped headers by category path, Done + Delete, inline add.
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

  /// Full backlog snapshot for frequency-based chips (same rules as [fetchBacklogPlans] with no filter).
  List<PlanningTask> _allBacklogForFrequency = [];
  bool _loading = true;
  int? _filterCategoryId;
  String? _filterTagPbId;
  List<Tag> _listTagsForFilter = const [];

  /// `'manual'` = user-pinned IDs; `'frequent'` = top categories by local backlog counts.
  String _chipMode = 'frequent';

  /// Manual mode: category IDs persisted under [_prefsKeyPinnedIds].
  List<int> _pinnedChipIds = [];
  StreamSubscription<void>? _planRefreshSub;
  StreamSubscription<void>? _tagsCatalogSub;
  final ScrollController _chipBarScrollController = ScrollController();
  final ScrollController _tagFilterScrollController = ScrollController();

  static const double _kShellBulkBarReservePx = 56;
  static const String _kOptimisticPurgeDateKey = '2099-12-31';
  late final TextEditingController _inlineController;
  final FocusNode _inlineFocus = FocusNode();

  bool _listsSelectMode = false;
  final Set<String> _selectedListKeys = <String>{};
  bool _listsArchiveSectionExpanded = true;

  // Notes library search (local, in-memory; filters the displayed snapshot).
  String _notesSearchQuery = '';
  final TextEditingController _notesSearchController = TextEditingController();
  final FocusNode _notesSearchFocus = FocusNode();

  // GLM Notes v3 library view preferences.
  static const String _kPrefNotesView = 'lifeos.notes.view';
  static const String _kPrefNotesCheckboxMode = 'lifeos.notes.checkboxMode';
  NotesLibraryView _notesView = NotesLibraryView.list;
  bool _notesCheckboxesOn = false;

  /// Stable key for backlog rows (matches Planning bulk selection).
  static String _listKey(PlanningTask t) {
    final p = t.planRowIdForBackend.trim();
    if (p.isNotEmpty) return p;
    return 'plan-fallback-${t.id}-${t.order}-${t.dateKey}-${t.categoryId}-${t.title}';
  }

  /// Brain SSOT + optional list-tag filter (Phase 1 overlay).
  List<PlanningTask> get _displayFlat {
    final db = DatabaseService.instance;
    var out = db.getBacklogPlansSnapshot(
      categoryId: _filterCategoryId,
      includeCompleted: true,
    );
    final tagId = _filterTagPbId?.trim() ?? '';
    if (tagId.isNotEmpty) {
      out = [
        for (final t in out)
          if (t.tags.any((tag) => (tag.pbRecordId ?? '').trim() == tagId)) t,
      ];
    }
    return out;
  }

  /// [Notes Library] local search over the current snapshot. Matches title +
  /// notes_plain. Empty query returns the input unchanged.
  List<PlanningTask> _applyNotesSearch(List<PlanningTask> in_) {
    final q = _notesSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return in_;
    final db = DatabaseService.instance;
    return [
      for (final t in in_)
        if (t.title.toLowerCase().contains(q) ||
            (t.notesPlain ?? '').toLowerCase().contains(q) ||
            db.parseNoteDocument(t).blocks.any(
              (b) => b.hasText && b.text.toLowerCase().contains(q),
            ) ||
            t.tags.any((tag) => tag.name.toLowerCase().contains(q)))
          t,
    ];
  }

  Future<void> _loadNotesLibraryPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_kPrefNotesView);
      final c = prefs.getBool(_kPrefNotesCheckboxMode);
      if (!mounted) return;
      setState(() {
        if (v == 'grid') _notesView = NotesLibraryView.grid;
        if (c == true) _notesCheckboxesOn = true;
      });
    } catch (_) {}
  }

  Future<void> _persistNotesView(NotesLibraryView v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kPrefNotesView,
        v == NotesLibraryView.grid ? 'grid' : 'list',
      );
    } catch (_) {}
  }

  Future<void> _persistNotesCheckboxMode(bool on) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefNotesCheckboxMode, on);
    } catch (_) {}
  }

  /// GLM v3 sort: unfinished first, pinned first, updated desc, stable fallback.
  void _notesLibrarySort(List<PlanningTask> list) {
    final db = DatabaseService.instance;
    list.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      final ap = db.isNotePinned(a);
      final bp = db.isNotePinned(b);
      if (ap != bp) return ap ? -1 : 1;
      final au = a.updatedAt ?? a.createdAt;
      final bu = b.updatedAt ?? b.createdAt;
      if (au != null && bu != null) return bu.compareTo(au);
      if (au != null) return -1;
      if (bu != null) return 1;
      return _sortTasks(a, b);
    });
  }

  void _openNoteEditor(PlanningTask task) {
    unawaited(
      showNoteEditorPage(
        context: context,
        task: task,
        onClosed: _applyBacklogFromBrainSnapshot,
      ),
    );
  }

  void _syncListsShellFabBulkReserve() {
    if (!mounted) {
      return;
    }
    final shell = ShellLayoutScope.read(context, listen: false);
    if (shell.primaryTabIndex != 3) {
      return;
    }
    final show = _filterCategoryId != null && _selectedListKeys.isNotEmpty;
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
    final db = DatabaseService.instance;
    final backups = <PlanningTask>[];
    for (final t in tasks) {
      if (t.planRowIdForBackend.startsWith('optimistic-')) {
        db.clearOptimisticPlanningForPlanRow(t.planRowIdForBackend);
        continue;
      }
      final pid = t.planRowIdForBackend.trim();
      if (pid.isNotEmpty) ids.add(pid);
      backups.add(t);
      db.applyOptimisticPlanningTask(
        t.copyWith(dateKey: _kOptimisticPurgeDateKey),
      );
    }
    if (ids.isEmpty) {
      db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
      setState(() {});
      _exitListsSelectMode();
      return;
    }
    db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
    setState(() {});
    final ok = await db.deletePlanningTasksBulk(ids);
    if (!ok && mounted) {
      for (final t in backups) {
        db.applyOptimisticPlanningTask(t);
      }
      db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
      setState(() {});
      AppSnack.failed();
    }
    if (mounted) _exitListsSelectMode();
  }

  Widget? _listsBulkBottomBar(
    BuildContext context,
    ColorScheme scheme,
    List<PlanningTask> display,
  ) {
    if (_selectedListKeys.isEmpty) return null;
    return ListsBulkBottomBar(
      locale: currentLocale.value,
      selectedCount: _selectedListKeys.length,
      onEdit: () => _openListsBulkEditFirst(display),
      onDelete: () => unawaited(_listsBulkDelete(display)),
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
    final db = DatabaseService.instance;
    _planRefreshSub = db.planningRefreshNotifications.listen((_) {
      if (!mounted) return;
      _applyBacklogFromBrainSnapshot();
      unawaited(_reloadFromNetwork());
    });
    _tagsCatalogSub = db.tagsCatalogUpdated.listen((_) {
      if (!mounted) return;
      unawaited(_loadListTagsForFilter());
    });
    unawaited(_bootstrap());
  }

  Future<void> _loadListTagsForFilter() async {
    final tags = await DatabaseService.instance.fetchTagsForCurrentUser(
      scope: TagCatalogScope.list,
    );
    if (!mounted) return;
    setState(() => _listTagsForFilter = tags);
  }

  void _applyBacklogFromBrainSnapshot() {
    final db = DatabaseService.instance;
    setState(() {
      _allBacklogForFrequency = db.getBacklogPlansSnapshot(
        categoryId: null,
        includeCompleted: true,
      );
      _loading = false;
    });
  }

  Future<void> _bootstrap() async {
    await CategoryVisibilityPrefs.ensureLoaded();
    await _loadPersistedFilter();
    await _loadChipModeAndPinnedIds();
    await _loadNotesLibraryPrefs();
    await _maybeMigrateListTagsPrefToUserScope();
    await _loadListTagsForFilter();
    if (!mounted) return;
    await _reload();
  }

  /// One-time: legacy global prefs key → auth-scoped prefs via [DatabaseService.persistShowListTagsOnCards].
  Future<void> _maybeMigrateListTagsPrefToUserScope() async {
    final prefs = await SharedPreferences.getInstance();
    const legacyGlobal = 'lists_show_tags_on_cards';
    final legacyVal = prefs.getBool(legacyGlobal);
    if (legacyVal == null) return;
    try {
      await DatabaseService.instance.persistShowListTagsOnCards(legacyVal);
      await prefs.remove(legacyGlobal);
    } catch (_) {
      // Auth not ready yet; retry on next Lists open.
    }
  }

  void _showListsRadialMenu(
    BuildContext anchorContext,
    PlanningTask task,
    String listKey,
  ) {
    final overlay = Overlay.maybeOf(anchorContext);
    if (overlay == null) return;
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final anchorCenter = rect.center;

    late OverlayEntry entry;
    void dismiss() {
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (ctx) {
        return ListsSemicircleMenuOverlay(
          anchorCenter: anchorCenter,
          onDismiss: dismiss,
          isPinned: DatabaseService.instance.isNotePinned(task),
          isDone: task.isDone,
          onTogglePin: () {
            dismiss();
            DatabaseService.instance.toggleNotePin(task.planRowIdForBackend);
            setState(() {});
          },
          onToggleDone: () {
            dismiss();
            DatabaseService.instance.toggleNoteDone(task.planRowIdForBackend);
            setState(() {});
          },
          onEdit: () {
            dismiss();
            widget.onEditTask?.call(task);
          },
          onSelect: () {
            dismiss();
            setState(() {
              _listsSelectMode = true;
              _selectedListKeys.add(listKey);
            });
            _syncListsShellFabBulkReserve();
          },
          onDelete: () {
            dismiss();
            unawaited(_confirmAndDelete(task));
          },
        );
      },
    );
    overlay.insert(entry);
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
    final mode = (modeRaw == 'manual' || modeRaw == 'frequent')
        ? modeRaw!
        : 'frequent';

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
    final visible = raw
        .where((id) => !CategoryVisibilityPrefs.isHiddenOrAncestor(id))
        .toList();
    final active = _filterCategoryId;
    if (active != null && visible.contains(active)) {
      return [active, ...visible.where((x) => x != active)];
    }
    return visible;
  }

  List<Tag> _tagsForFilterBar() {
    final tags = [
      for (final t in _listTagsForFilter)
        if (TagCatalogScope.list.matchesTag(t)) t,
    ];
    final active = _filterTagPbId?.trim() ?? '';
    if (active.isEmpty) return tags;
    final idx = tags.indexWhere((t) => (t.pbRecordId ?? '').trim() == active);
    if (idx <= 0) return tags;
    final picked = tags[idx];
    return [picked, ...tags.where((t) => t != picked)];
  }

  void _scrollChipBarToStart() {
    for (final c in [_chipBarScrollController, _tagFilterScrollController]) {
      if (!c.hasClients) continue;
      unawaited(
        c.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _onFilterChanged(int? id) {
    if (id != null && _chipMode == 'manual') {
      final next = List<int>.from(_pinnedChipIds)..remove(id);
      next.insert(0, id);
      _pinnedChipIds = _sanitizeIntCategoryIds(next);
      unawaited(_persistPinnedChipIds(_pinnedChipIds));
    }
    setState(() {
      _filterCategoryId = id;
      _listsSelectMode = false;
      _selectedListKeys.clear();
    });
    unawaited(_persistFilterCategoryId(id));
    _scrollChipBarToStart();
  }

  void _onTagFilterChanged(String? tagPbId) {
    final next = tagPbId?.trim();
    setState(() {
      _filterTagPbId = (next == null || next.isEmpty) ? null : next;
      _listsSelectMode = false;
      _selectedListKeys.clear();
    });
    _scrollChipBarToStart();
  }

  Future<void> _openChipBarSettingsSheet() async {
    await showListsChipBarSettingsSheet(
      context: context,
      locale: currentLocale.value,
      initialChipMode: _chipMode,
      initialPinnedChipIds: _pinnedChipIds,
      filterCategoryId: _filterCategoryId,
      displayFlat: _displayFlat,
      applyCompletionLayout: _listsApplyCompletionLayout,
      sanitizeCategoryIds: _sanitizeIntCategoryIds,
      persistChipMode: _persistChipMode,
      persistPinnedChipIds: _persistPinnedChipIds,
      onSaved: (mode, pinned) {
        setState(() {
          _chipMode = mode;
          if (mode == 'manual') {
            _pinnedChipIds = pinned;
          }
        });
      },
      reload: _reload,
      onFilterChanged: _onFilterChanged,
    );
  }

  @override
  void dispose() {
    CategoryVisibilityPrefs.hiddenIds.removeListener(_listsVisibilityListener);
    _planRefreshSub?.cancel();
    _tagsCatalogSub?.cancel();
    _chipBarScrollController.dispose();
    _tagFilterScrollController.dispose();
    _inlineController.dispose();
    _inlineFocus.dispose();
    _notesSearchController.dispose();
    _notesSearchFocus.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _applyBacklogFromBrainSnapshot();
    await _reloadFromNetwork();
  }

  Future<void> _reloadFromNetwork() async {
    final db = DatabaseService.instance;
    final results = await Future.wait<List<PlanningTask>>([
      db.fetchBacklogPlans(
        categoryId: _filterCategoryId,
        includeCompleted: true,
      ),
      db.fetchBacklogPlans(categoryId: null),
    ]);
    final allBacklog = results[1];
    if (!mounted) return;
    setState(() {
      _allBacklogForFrequency = allBacklog;
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
    final db = DatabaseService.instance;
    for (final t in withOrders) {
      db.applyOptimisticPlanningTask(t);
    }
    db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
    setState(() {});
    unawaited(
      db.persistPlanningTaskOrder(
        withOrders,
        baselineBeforeReorder: orderedBefore,
      ),
    );
  }

  Widget _listsBacklogCard(
    PlanningTask task,
    String loc, {
    required bool showTagsStrip,
  }) {
    final key = _listKey(task);
    final isOptimistic =
        task.planRowIdForBackend.startsWith('optimistic-');
    if (_listsSelectMode) {
      return BacklogPlanCard(
        task: task,
        locale: loc,
        showTagsStrip: showTagsStrip,
        selectionMode: true,
        isSelected: _selectedListKeys.contains(key),
        onBodyTap: () => _toggleListKey(key),
        onToggleDone: (done) => _onListToggleDone(task, done),
        onDelete: () => unawaited(_confirmAndDelete(task)),
        onOpenMenu: (anchorCtx) => _showListsRadialMenu(anchorCtx, task, key),
      );
    }
    if (isOptimistic) {
      return BacklogPlanCard(
        task: task,
        locale: loc,
        showTagsStrip: showTagsStrip,
        selectionMode: false,
        isSelected: false,
        onBodyTap: () => widget.onEditTask?.call(task),
        onToggleDone: (done) => _onListToggleDone(task, done),
        onDelete: () => unawaited(_confirmAndDelete(task)),
        onOpenMenu: (anchorCtx) => _showListsRadialMenu(anchorCtx, task, key),
      );
    }
    // Persisted notes use the GLM v3 library body at the list level — this
    // path is only reached in bulk-select mode (handled above).
    return const SizedBox.shrink();
  }

  void _onListToggleDone(PlanningTask task, bool toDone) {
    if (task.planRowIdForBackend.startsWith('optimistic-')) return;
    if (task.isDone == toDone) return;
    final updated = task.copyWith(isDone: toDone);
    final db = DatabaseService.instance;
    db.applyOptimisticPlanningTask(updated);
    db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
    setState(() {});
    unawaited(
      db
          .updatePlanningTask(
            task.planRowIdForBackend,
            planBusinessId: task.planRowId,
            isDone: toDone,
            suppressAppSnack: true,
          )
          .then((ok) {
            if (!ok && mounted) {
              db.applyOptimisticPlanningTask(task);
              db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
              setState(() {});
              AppSnack.failed();
            }
          }),
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
      final path = DatabaseService.instance
          .getCategoryPath(t.categoryId)
          .trim();
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
    final cat = _effectiveCategoryIdForNewTask();
    if (cat == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(currentLocale.value, 'lists_inline_add_no_category')),
        ),
      );
      return;
    }

    var title = '';
    if (raw.isNotEmpty) {
      final stripped = SmartInputParser.backlogTitleFromRaw(raw);
      final gt = DatabaseService.instance.getCleanTitleAndTags(stripped);
      title = gt.title.trim();
    }

    _inlineController.clear();
    setState(() {});
    unawaited(() async {
      final db = DatabaseService.instance;
      final rowId = await db.createEmptyNote(categoryId: cat, title: title);
      if (!mounted) return;
      if (rowId == null) {
        AppSnack.failed();
        return;
      }
      final task = db.getCachedPlanningTaskForEdit(rowId);
      if (task != null) {
        _openNoteEditor(task);
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
    final db = DatabaseService.instance;
    if (id.startsWith('optimistic-')) {
      db.clearOptimisticPlanningForPlanRow(id);
      db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
      setState(() {});
      return;
    }

    final backup = task;
    db.applyOptimisticPlanningTask(
      task.copyWith(dateKey: _kOptimisticPurgeDateKey),
    );
    db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
    setState(() {});
    unawaited(() async {
      final ok = await db.deletePlanningTasksBulk([id]);
      if (!mounted) return;
      if (!ok) {
        db.applyOptimisticPlanningTask(backup);
        db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
        setState(() {});
        AppSnack.failed();
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = currentLocale.value;
    final theme = Theme.of(context);
    final filterId = _filterCategoryId;

    return StreamBuilder<UserSettings>(
      stream: DatabaseService.instance.userSettingsStream,
      initialData: DatabaseService.instance.settings,
      builder: (context, settingsSnap) {
        final listBeh = (settingsSnap.data ?? DatabaseService.instance.settings)
            .listCompletionBehavior
            .trim()
            .toLowerCase();
        final showListTagsOnCards =
            (settingsSnap.data ?? DatabaseService.instance.settings)
                .showListTagsOnCards;
        return ValueListenableBuilder<List<int>>(
          valueListenable: CategoryVisibilityPrefs.hiddenIds,
          builder: (context, _, _) {
            final chipIds = _chipIdsForBar();
            final flat = _applyNotesSearch(_displayFlat);
            final hasActiveTagFilter =
                (_filterTagPbId?.trim() ?? '').isNotEmpty;
            final forGrouping = listBeh == 'archive'
                ? () {
                    final o = flat.where((t) => !t.isDone).toList();
                    _notesLibrarySort(o);
                    return o;
                  }()
                : () {
                    final o = _listsApplyCompletionLayout(flat, listBeh);
                    _notesLibrarySort(o);
                    return o;
                  }();
            final archiveSlice = listBeh == 'archive'
                ? _listsArchiveDoneSlice(flat)
                : const <PlanningTask>[];
            final grouped = _groupByCategoryPath(forGrouping);
            final flatRows = _listsFlattenGrouped(grouped);
            final listBodyEmpty = forGrouping.isEmpty && archiveSlice.isEmpty;
            _syncListsShellFabBulkReserve();
            return Scaffold(
              body: SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_listsSelectMode)
                      ListsBulkSelectModeBar(
                        locale: loc,
                        filterCategoryId: filterId,
                        visibleFlat: flat,
                        allVisibleSelected: _allVisibleListsSelected(flat),
                        onExitSelectMode: _exitListsSelectMode,
                        onToggleSelectAllVisible: () =>
                            _toggleSelectAllVisibleLists(flat),
                      )
                    else ...[
                      _NotesLibraryHeader(
                        locale: loc,
                        notesCount: forGrouping.length,
                        searchController: _notesSearchController,
                        searchFocus: _notesSearchFocus,
                        searchQuery: _notesSearchQuery,
                        onSearchChanged: (v) =>
                            setState(() => _notesSearchQuery = v),
                        onClearSearch: () {
                          _notesSearchController.clear();
                          setState(() => _notesSearchQuery = '');
                        },
                        onOpenSettings: _openChipBarSettingsSheet,
                        showExport: filterId != null,
                        onExport: () => unawaited(
                          exportVisibleListAsText(
                            context: context,
                            locale: loc,
                            visible: forGrouping,
                          ),
                        ),
                        notesView: _notesView,
                        checkboxesOn: _notesCheckboxesOn,
                        onViewChanged: (v) {
                          setState(() => _notesView = v);
                          unawaited(_persistNotesView(v));
                        },
                        onCheckboxModeChanged: (on) {
                          setState(() => _notesCheckboxesOn = on);
                          unawaited(_persistNotesCheckboxMode(on));
                        },
                      ),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 48,
                            child: ListsCategoryChipBar(
                              chipIds: chipIds,
                              chipMode: _chipMode,
                              filterCategoryId: filterId,
                              scrollController: _chipBarScrollController,
                              onFilterChanged: _onFilterChanged,
                              onManualChipReorder: (oldI, newI) =>
                                  _onManualChipReorder(chipIds, oldI, newI),
                            ),
                          ),
                          if (filterId != null &&
                              _tagsForFilterBar().isNotEmpty)
                            ListsTagFilterBar(
                              locale: loc,
                              tags: _tagsForFilterBar(),
                              filterTagPbId: _filterTagPbId,
                              hasActiveTagFilter: hasActiveTagFilter,
                              scrollController: _tagFilterScrollController,
                              onTagFilterChanged: _onTagFilterChanged,
                            ),
                          if (filterId != null)
                            ListsInlineAddRow(
                              locale: loc,
                              controller: _inlineController,
                              focusNode: _inlineFocus,
                              onSubmit: _submitInline,
                            ),
                          Expanded(
                            child: filterId == null
                                ? ListsNoCategoryEmptyPanel(locale: loc)
                                : _loading
                                ? const ListsLoadingPanel()
                                : listBodyEmpty
                                ? (_notesSearchQuery.trim().isNotEmpty
                                    ? _NotesLibraryEmptyState(
                                        locale: loc,
                                        noResults: true,
                                      )
                                    : ListsFilteredEmptyPanel(
                                        locale: loc,
                                      ))
                                : _listsSelectMode
                                ? RefreshIndicator(
                                    onRefresh: _reload,
                                    child: CustomScrollView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      slivers: [
                                        SliverPadding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            8,
                                            16,
                                            8,
                                          ),
                                          sliver: SliverReorderableList(
                                            itemCount: flatRows.length,
                                            onReorder: (oldI, newI) =>
                                                _onListsReorder(
                                                  oldI,
                                                  newI,
                                                  listBeh,
                                                ),
                                            itemBuilder: (context, index) {
                                              final row = flatRows[index];
                                              final t = row.task;
                                              return ReorderableDelayedDragStartListener(
                                                key: ValueKey<String>(
                                                  _listKey(t),
                                                ),
                                                index: index,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 8,
                                                      ),
                                                  child: _listsBacklogCard(
                                                    t,
                                                    loc,
                                                    showTagsStrip:
                                                        showListTagsOnCards,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : NotesLibraryBody(
                                    tasks: [
                                      ...forGrouping,
                                      ...archiveSlice,
                                    ],
                                    view: _notesView,
                                    checkboxesOn: _notesCheckboxesOn,
                                    onTap: _openNoteEditor,
                                    onLongPress: (t) => _showListsRadialMenu(
                                      context,
                                      t,
                                      _listKey(t),
                                    ),
                                    onRefresh: _reload,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar:
                  filterId != null && _selectedListKeys.isNotEmpty
                  ? _listsBulkBottomBar(context, theme.colorScheme, flat)
                  : null,
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Notes Library header + empty state — product visual pass for the Lists tab.
// Pure presentational widgets composed by [_ListsPageState]. No Brain imports
// beyond what the page already owns.
// ---------------------------------------------------------------------------

class _NotesLibraryHeader extends StatelessWidget {
  const _NotesLibraryHeader({
    required this.locale,
    required this.notesCount,
    required this.searchController,
    required this.searchFocus,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onOpenSettings,
    required this.showExport,
    required this.onExport,
    required this.notesView,
    required this.checkboxesOn,
    required this.onViewChanged,
    required this.onCheckboxModeChanged,
  });

  final String locale;
  final int notesCount;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onOpenSettings;
  final bool showExport;
  final VoidCallback onExport;
  final NotesLibraryView notesView;
  final bool checkboxesOn;
  final ValueChanged<NotesLibraryView> onViewChanged;
  final ValueChanged<bool> onCheckboxModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(locale, 'notes_v3_subtitle'),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      t(locale, 'notes_v3_title'),
                      style: (theme.textTheme.headlineSmall ??
                              const TextStyle())
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: checkboxesOn
                    ? t(locale, 'notes_v3_checkbox_mode_off')
                    : t(locale, 'notes_v3_checkbox_mode_on'),
                onPressed: () => onCheckboxModeChanged(!checkboxesOn),
                icon: Icon(
                  checkboxesOn
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 20,
                  color: checkboxesOn ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _HeaderSegBtn(
                      icon: Icons.grid_view_rounded,
                      selected: notesView == NotesLibraryView.grid,
                      onTap: () => onViewChanged(NotesLibraryView.grid),
                      tooltip: t(locale, 'notes_v3_view_grid'),
                    ),
                    _HeaderSegBtn(
                      icon: Icons.view_list_rounded,
                      selected: notesView == NotesLibraryView.list,
                      onTap: () => onViewChanged(NotesLibraryView.list),
                      tooltip: t(locale, 'notes_v3_view_list'),
                    ),
                  ],
                ),
              ),
              if (showExport)
                IconButton(
                  tooltip: t(locale, 'lists_export_text'),
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  color: scheme.onSurfaceVariant,
                  onPressed: onExport,
                ),
              IconButton(
                tooltip: t(locale, 'notes_editor_more_tooltip'),
                icon: const Icon(Icons.tune_rounded, size: 20),
                visualDensity: VisualDensity.compact,
                color: scheme.onSurfaceVariant,
                onPressed: onOpenSettings,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: searchController,
            focusNode: searchFocus,
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.sentences,
            onChanged: onSearchChanged,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: t(locale, 'notes_v3_search_hint'),
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              suffixIcon: searchQuery.trim().isNotEmpty
                  ? IconButton(
                      tooltip: t(locale, 'cancel'),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      splashRadius: 16,
                      onPressed: onClearSearch,
                    )
                  : null,
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: scheme.primary.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          if (notesCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child: Text(
                t(locale, 'notes_v3_count').replaceAll('{n}', '$notesCount'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderSegBtn extends StatelessWidget {
  const _HeaderSegBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _NotesLibraryEmptyState extends StatelessWidget {
  const _NotesLibraryEmptyState({required this.locale, this.noResults = false});

  final String locale;
  final bool noResults;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = noResults
        ? t(locale, 'notes_library_no_results')
        : t(locale, 'notes_library_empty');
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
      children: [
        Icon(
          noResults
              ? Icons.search_off_rounded
              : Icons.note_add_outlined,
          size: 56,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (!noResults) ...[
          const SizedBox(height: 6),
          Text(
            t(locale, 'notes_library_empty_sub'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

