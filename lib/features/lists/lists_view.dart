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
                  t(
                    loc,
                    'selected_count',
                  ).replaceFirst('%s', '${_selectedListKeys.length}'),
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
        return _ListsSemicircleMenuOverlay(
          anchorCenter: anchorCenter,
          onDismiss: dismiss,
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

  Future<void> _exportVisibleListAsText(List<PlanningTask> visible) async {
    final loc = currentLocale.value;
    if (visible.isEmpty) {
      AppSnack.show(t(loc, 'lists_export_empty'), error: true);
      return;
    }
    final lines = <String>[];
    for (var i = 0; i < visible.length; i++) {
      lines.add('${i + 1}. ${visible[i].title.trim()}');
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    AppSnack.show(t(loc, 'lists_export_copied'));
  }

  /// Manual chip picker: tree of [CategoryRule] — accordion (one branch open per level).
  Widget _buildManualCategoryTreeTile(
    CategoryRule r,
    Set<int> sel,
    Set<int> expandedIds,
    void Function(int id) onToggleExpand,
    void Function(void Function()) setModal, {
    int depth = 0,
  }) {
    if (CategoryVisibilityPrefs.isHiddenOrAncestor(r.id)) {
      return const SizedBox.shrink();
    }
    final rawKids = r.children ?? const <CategoryRule>[];
    final kids = rawKids
        .where((c) => !CategoryVisibilityPrefs.isHiddenOrAncestor(c.id))
        .toList();
    final titleName = _categoryRawName(r.id);
    final depthPad = EdgeInsetsDirectional.only(start: depth * 20.0);
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
      return Padding(
        padding: depthPad,
        child: CheckboxListTile(
          value: sel.contains(r.id),
          onChanged: toggleSel,
          title: Text(titleName),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        ),
      );
    }
    final expanded = expandedIds.contains(r.id);
    return Padding(
      padding: depthPad,
      child: ExpansionTile(
        key: ValueKey<int>(r.id),
        initiallyExpanded: expanded,
        onExpansionChanged: (open) {
          if (open) {
            onToggleExpand(r.id);
          } else {
            setModal(() => expandedIds.remove(r.id));
          }
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Row(
          children: [
            Checkbox(value: sel.contains(r.id), onChanged: toggleSel),
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
            _buildManualCategoryTreeTile(
              c,
              sel,
              expandedIds,
              onToggleExpand,
              setModal,
              depth: depth + 1,
            ),
        ],
      ),
    );
  }

  void _toggleManualTreeExpand(
    int id,
    void Function(void Function()) setModal,
    Set<int> expandedIds,
  ) {
    setModal(() {
      if (expandedIds.contains(id)) {
        expandedIds.remove(id);
        return;
      }
      final spine = DatabaseService.instance.categoryPathFromRootToLocalId(id);
      final ancestors = spine.length > 1
          ? spine.take(spine.length - 1).toSet()
          : <int>{};
      expandedIds
        ..clear()
        ..addAll({...ancestors, id});
    });
  }

  Widget _buildListTagFilterChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
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
                : color.withValues(alpha: 0.22),
            border: Border.all(
              color: selected ? scheme.primary : color,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? scheme.onPrimary : scheme.onSurface,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openChipBarSettingsSheet() async {
    final loc = currentLocale.value;
    final db = DatabaseService.instance;
    var mode = _chipMode;
    final sel = Set<int>.from(_pinnedChipIds);
    final expandedManualTreeIds = <int>{};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            var completionDraft = DatabaseService
                .instance
                .settings
                .listCompletionBehavior
                .trim()
                .toLowerCase();
            if (completionDraft != 'stay' &&
                completionDraft != 'bottom' &&
                completionDraft != 'hide' &&
                completionDraft != 'archive') {
              completionDraft = 'hide';
            }
            var showTagsDraft =
                DatabaseService.instance.settings.showListTagsOnCards;
            final manualListHeight = (MediaQuery.sizeOf(ctx).height * 0.45)
                .clamp(200.0, 520.0);
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
                              _buildManualCategoryTreeTile(
                                r,
                                sel,
                                expandedManualTreeIds,
                                (id) => _toggleManualTreeExpand(
                                  id,
                                  setModal,
                                  expandedManualTreeIds,
                                ),
                                setModal,
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonFormField<String>(
                        initialValue: completionDraft,
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
                    ListTile(
                      leading: const Icon(Icons.copy_rounded),
                      title: Text(t(loc, 'lists_export_text')),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        final flat = _listsApplyCompletionLayout(
                          _displayFlat,
                          completionDraft,
                        );
                        unawaited(_exportVisibleListAsText(flat));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.label_outline_rounded),
                      title: Text(t(loc, 'lists_manage_tags')),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        unawaited(
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (c) => Scaffold(
                                appBar: AppBar(
                                  title: Text(t(loc, 'lists_manage_tags')),
                                ),
                                body: const TagManagerPage(
                                  pocketTagDomain: 'list',
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          final nextPinned = _sanitizeIntCategoryIds(
                            sel.toList(),
                          );
                          setState(() {
                            _chipMode = mode;
                            if (mode == 'manual') {
                              _pinnedChipIds = nextPinned;
                            }
                          });
                          unawaited(_persistChipMode(mode));
                          unawaited(
                            DatabaseService.instance.persistShowListTagsOnCards(
                              showTagsDraft,
                            ),
                          );
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
    _tagsCatalogSub?.cancel();
    _chipBarScrollController.dispose();
    _tagFilterScrollController.dispose();
    _inlineController.dispose();
    _inlineFocus.dispose();
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
    return _BacklogPlanCard(
      task: task,
      locale: loc,
      showTagsStrip: showTagsStrip,
      selectionMode: _listsSelectMode,
      isSelected: _selectedListKeys.contains(key),
      onBodyTap: () {
        if (_listsSelectMode) {
          _toggleListKey(key);
        } else {
          widget.onEditTask?.call(task);
        }
      },
      onToggleDone: (done) => _onListToggleDone(task, done),
      onDelete: () => unawaited(_confirmAndDelete(task)),
      onOpenMenu: (anchorCtx) => _showListsRadialMenu(anchorCtx, task, key),
    );
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
    if (raw.isEmpty) return;
    final stripped = SmartInputParser.backlogTitleFromRaw(raw);
    final gt = DatabaseService.instance.getCleanTitleAndTags(stripped);
    final title = gt.title.trim();
    if (title.isEmpty) return;
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

    _inlineController.clear();
    setState(() {});
    unawaited(() async {
      final db = DatabaseService.instance;
      final ord = await db.nextBacklogPlanningOrder();
      final ok = await db.addPlanningTask(
        PlanningTask(
          id: 0,
          title: title,
          categoryId: cat,
          dateKey: '',
          order: ord,
          startTime: null,
          endDateTime: null,
          rrule: null,
        ),
      );
      if (!mounted) return;
      if (!ok) {
        AppSnack.failed();
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
            final flat = _displayFlat;
            final hasActiveTagFilter =
                (_filterTagPbId?.trim() ?? '').isNotEmpty;
            final forGrouping = listBeh == 'archive'
                ? (flat.where((t) => !t.isDone).toList()..sort(_sortTasks))
                : _listsApplyCompletionLayout(flat, listBeh);
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
                    if (_listsSelectMode) ...[
                      Material(
                        color: theme.colorScheme.surface,
                        elevation: 0,
                        surfaceTintColor: theme.colorScheme.surfaceTint,
                        child: SizedBox(
                          height: kGlobalCompactHeaderHeight,
                          child: Row(
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
                                      horizontal: 8,
                                    ),
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
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (filterId != null)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: t(loc, 'lists_export_text'),
                                onPressed: () => unawaited(
                                  _exportVisibleListAsText(forGrouping),
                                ),
                                icon: const Icon(Icons.copy_rounded),
                              ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: t(
                                loc,
                                'lists_chip_bar_settings_tooltip',
                              ),
                              onPressed: _openChipBarSettingsSheet,
                              icon: const Icon(Icons.settings_rounded),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 48,
                            child: _chipMode == 'manual' && chipIds.length > 1
                                ? ReorderableListView.builder(
                                    scrollController: _chipBarScrollController,
                                    scrollDirection: Axis.horizontal,
                                    buildDefaultDragHandles: false,
                                    shrinkWrap: true,
                                    physics: const ClampingScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    itemCount: chipIds.length,
                                    onReorder: (oldI, newI) =>
                                        _onManualChipReorder(
                                          chipIds,
                                          oldI,
                                          newI,
                                        ),
                                    itemBuilder: (ctx, idx) {
                                      final id = chipIds[idx];
                                      return ReorderableDelayedDragStartListener(
                                        key: ValueKey<int>(id),
                                        index: idx,
                                        child: Padding(
                                          padding:
                                              const EdgeInsetsDirectional.only(
                                                end: 8,
                                              ),
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
                                    controller: _chipBarScrollController,
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    children: [
                                      for (final id in chipIds)
                                        Padding(
                                          padding:
                                              const EdgeInsetsDirectional.only(
                                                end: 8,
                                              ),
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
                          if (filterId != null &&
                              _tagsForFilterBar().isNotEmpty)
                            SizedBox(
                              height: 44,
                              child: ListView(
                                controller: _tagFilterScrollController,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                children: [
                                  if (!hasActiveTagFilter)
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        end: 8,
                                      ),
                                      child: _buildListTagFilterChip(
                                        label: t(loc, 'lists_filter_tag_all'),
                                        selected: _filterTagPbId == null,
                                        color: theme.colorScheme.outline,
                                        onTap: () => _onTagFilterChanged(null),
                                      ),
                                    ),
                                  for (final tag in _tagsForFilterBar())
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        end: 8,
                                      ),
                                      child: _buildListTagFilterChip(
                                        label: tag.name.trim().isNotEmpty
                                            ? tag.name.trim()
                                            : '#${tag.tagId}',
                                        selected:
                                            (_filterTagPbId ?? '') ==
                                            (tag.pbRecordId ?? '').trim(),
                                        color:
                                            parseTagHexColor(tag.color) ??
                                            theme.colorScheme.primary,
                                        onTap: () {
                                          final id = (tag.pbRecordId ?? '')
                                              .trim();
                                          if (id.isEmpty) return;
                                          if (_filterTagPbId == id) {
                                            _onTagFilterChanged(null);
                                          } else {
                                            _onTagFilterChanged(id);
                                          }
                                        },
                                      ),
                                    ),
                                  if (hasActiveTagFilter)
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        end: 8,
                                      ),
                                      child: _buildListTagFilterChip(
                                        label: t(loc, 'lists_filter_tag_all'),
                                        selected: _filterTagPbId == null,
                                        color: theme.colorScheme.outline,
                                        onTap: () => _onTagFilterChanged(null),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          if (filterId != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _inlineController,
                                      focusNode: _inlineFocus,
                                      textInputAction: TextInputAction.done,
                                      decoration: InputDecoration(
                                        hintText: t(
                                          loc,
                                          'input_placeholder_list',
                                        ),
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
                                        height:
                                            MediaQuery.sizeOf(context).height *
                                            0.25,
                                      ),
                                      AppEmptyState(
                                        message: t(
                                          loc,
                                          'lists_no_category_chosen',
                                        ),
                                        icon: Icons.category_outlined,
                                      ),
                                    ],
                                  )
                                : _loading
                                ? const AppLoading()
                                : RefreshIndicator(
                                    onRefresh: _reload,
                                    child: listBodyEmpty
                                        ? ListView(
                                            physics:
                                                const AlwaysScrollableScrollPhysics(),
                                            children: [
                                              SizedBox(
                                                height:
                                                    MediaQuery.sizeOf(
                                                      context,
                                                    ).height *
                                                    0.25,
                                              ),
                                              AppEmptyState(
                                                message: t(loc, 'lists_empty'),
                                                icon: Icons.inbox_outlined,
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
                                              if (archiveSlice.isNotEmpty)
                                                SliverToBoxAdapter(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          16,
                                                          0,
                                                          16,
                                                          24,
                                                        ),
                                                    child: ExpansionTile(
                                                      initiallyExpanded:
                                                          _listsArchiveSectionExpanded,
                                                      onExpansionChanged: (x) {
                                                        setState(
                                                          () =>
                                                              _listsArchiveSectionExpanded =
                                                                  x,
                                                        );
                                                      },
                                                      title: Text(
                                                        t(
                                                          loc,
                                                          'lists_archive_section',
                                                        ).replaceFirst(
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
                                                                  bottom: 8,
                                                                ),
                                                            child: _listsBacklogCard(
                                                              t,
                                                              loc,
                                                              showTagsStrip:
                                                                  showListTagsOnCards,
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
                      color: selected ? scheme.onPrimary : scheme.onSurface,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
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
    required this.showTagsStrip,
    required this.selectionMode,
    required this.isSelected,
    required this.onBodyTap,
    required this.onToggleDone,
    required this.onDelete,
    required this.onOpenMenu,
  });

  final PlanningTask task;
  final String locale;
  final bool showTagsStrip;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onBodyTap;
  final void Function(bool toDone) onToggleDone;
  final VoidCallback onDelete;
  final void Function(BuildContext anchorContext) onOpenMenu;

  static Iterable<Tag> _listDomainTags(PlanningTask task) sync* {
    for (final tag in task.tags) {
      if (!tag.rendersAsChip) continue;
      if (TagCatalogScope.list.matchesTag(tag)) yield tag;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final listTags = _listDomainTags(task).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      color: isSelected
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      child: InkWell(
        onTap: onBodyTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              selectionMode
                  ? Checkbox(value: isSelected, onChanged: (_) => onBodyTap())
                  : Checkbox(
                      value: task.isDone,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged:
                          task.planRowIdForBackend.startsWith('optimistic-')
                          ? null
                          : (v) {
                              if (v == null) return;
                              onToggleDone(v);
                            },
                    ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: task.isDone
                            ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                              )
                            : null,
                      ),
                      if (showTagsStrip && listTags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: StreamBuilder<UserSettings>(
                            stream: DatabaseService.instance.userSettingsStream,
                            initialData: DatabaseService.instance.settings,
                            builder: (context, snap) {
                              final mode =
                                  snap.data?.tagDisplayMode ??
                                  CategoryDisplayMode.letterChip;
                              final sch = Theme.of(context).colorScheme;
                              return Wrap(
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.start,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  for (final tag in listTags)
                                    CategoryChip(
                                      mode: mode,
                                      label: tag.name.trim().isNotEmpty
                                          ? tag.name.trim()
                                          : '#${tag.tagId != 0 ? tag.tagId : tag.wrapperRowId}',
                                      color:
                                          parseTagHexColor(tag.color) ??
                                          sch.primary,
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
                Builder(
                  builder: (menuCtx) {
                    return IconButton(
                      tooltip: t(locale, 'plan_radial_menu_tip'),
                      style: IconButton.styleFrom(
                        splashFactory: NoSplash.splashFactory,
                        hoverColor: Colors.transparent,
                        backgroundColor: scheme.secondaryContainer.withValues(
                          alpha: 0.92,
                        ),
                        foregroundColor: scheme.onSecondaryContainer,
                        minimumSize: const Size(44, 44),
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(Icons.menu_open_rounded, size: 24),
                      onPressed: () => onOpenMenu(menuCtx),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Semi-circle satellite menu for list/backlog cards (no Start — lists are not time-bound).
class _ListsSemicircleMenuOverlay extends StatefulWidget {
  const _ListsSemicircleMenuOverlay({
    required this.anchorCenter,
    required this.onDismiss,
    required this.onEdit,
    required this.onSelect,
    required this.onDelete,
  });

  final Offset anchorCenter;
  final VoidCallback onDismiss;
  final VoidCallback onEdit;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  State<_ListsSemicircleMenuOverlay> createState() =>
      _ListsSemicircleMenuOverlayState();
}

class _ListsSemicircleMenuOverlayState
    extends State<_ListsSemicircleMenuOverlay>
    with SingleTickerProviderStateMixin {
  static const double _canvas = 300;
  static const double _hub = 44;
  static const double _orbit = 100;
  static const double _satellite = 60;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    unawaited(_controller.forward());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _orbitOffsetLeftArc(double radians) {
    return Offset(math.cos(radians) * _orbit, -math.sin(radians) * _orbit);
  }

  Widget _labeledAction({
    required int index,
    required Offset offsetFromHub,
    required IconData icon,
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final delayed = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        index * 0.09,
        0.62 + index * 0.1,
        curve: Curves.easeOutBack,
      ),
    );
    return Positioned(
      left: _canvas / 2 + offsetFromHub.dx - _satellite / 2,
      top: _canvas / 2 + offsetFromHub.dy - _satellite / 2 - 22,
      child: FadeTransition(
        opacity: delayed,
        child: ScaleTransition(
          scale: delayed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                elevation: 4,
                color: background,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: SizedBox(
                    width: _satellite,
                    height: _satellite,
                    child: Icon(icon, color: foreground, size: 30),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;

    final stackLeft = widget.anchorCenter.dx - _canvas / 2;
    final stackTop = widget.anchorCenter.dy - _canvas / 2;

    final hubAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.45, curve: Curves.easeOutCubic),
    );

    double angleForSatellite(int i) {
      return math.pi + i * (math.pi / 3);
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
              child: ColoredBox(color: scheme.scrim.withValues(alpha: 0.36)),
            ),
          ),
          Positioned(
            left: stackLeft,
            top: stackTop,
            width: _canvas,
            height: _canvas,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _labeledAction(
                  index: 0,
                  offsetFromHub: _orbitOffsetLeftArc(angleForSatellite(0)),
                  icon: Icons.edit_rounded,
                  label: t(loc, 'lists_menu_change'),
                  background: scheme.primaryContainer,
                  foreground: scheme.onPrimaryContainer,
                  onTap: widget.onEdit,
                ),
                _labeledAction(
                  index: 1,
                  offsetFromHub: _orbitOffsetLeftArc(angleForSatellite(1)),
                  icon: Icons.checklist_rounded,
                  label: t(loc, 'lists_menu_choose'),
                  background: scheme.secondaryContainer,
                  foreground: scheme.onSecondaryContainer,
                  onTap: widget.onSelect,
                ),
                _labeledAction(
                  index: 2,
                  offsetFromHub: _orbitOffsetLeftArc(angleForSatellite(2)),
                  icon: Icons.delete_outline_rounded,
                  label: t(loc, 'delete'),
                  background: scheme.errorContainer,
                  foreground: scheme.onErrorContainer,
                  onTap: widget.onDelete,
                ),
                Positioned(
                  left: _canvas / 2 - _hub / 2,
                  top: _canvas / 2 - _hub / 2,
                  child: FadeTransition(
                    opacity: hubAnim,
                    child: ScaleTransition(
                      scale: hubAnim,
                      child: Tooltip(
                        message: t(loc, 'plan_radial_close'),
                        child: Material(
                          elevation: 6,
                          color: scheme.primary,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: widget.onDismiss,
                            child: SizedBox(
                              width: _hub,
                              height: _hub,
                              child: Icon(
                                Icons.close_rounded,
                                color: scheme.onPrimary,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
