// ---------------------------------------------------------------------------
// LISTS / BACKLOG — Undated plans ([PlanningTask.startTime] == null). UI_ISOLATION.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';

import 'package:counter/core/widgets/global_app_header.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_visibility_prefs.dart';
import 'package:counter/features/planning/smart_input_parser.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backlog screen: grouped headers by category path, Play + Done + Delete, inline add.
class ListsPage extends StatefulWidget {
  const ListsPage({
    super.key,
    this.selectedDate,
    this.onDateChanged,
  });

  /// Wall day for the unified global header (Lists content stays backlog / undated).
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDateChanged;

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
    });
    unawaited(_persistFilterCategoryId(id));
    unawaited(_reload());
  }

  Future<void> _openChipBarSettingsSheet() async {
    final loc = currentLocale.value;
    final db = DatabaseService.instance;
    var mode = _chipMode;
    final sel = Set<int>.from(_pinnedChipIds);
    final pairs = CategoryVisibilityPrefs.filterPairs(
      db.allCategoryIdPathPairs,
      (p) => p.id,
    );

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
                          children: [
                            for (final p in pairs)
                              Padding(
                                padding: EdgeInsets.only(
                                  left: _categoryTreeDepthFromPath(p.path) *
                                      16.0,
                                ),
                                child: CheckboxListTile(
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
                                  title: Text(_categoryRawName(p.id)),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  dense: true,
                                ),
                              ),
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
        return Scaffold(
      appBar: AppBar(
        title: GlobalAppHeader(
          selectedDate: headerDay,
          enabled: widget.onDateChanged != null,
          onDateSelected: (d) => widget.onDateChanged?.call(d),
        ),
        actions: [
          IconButton(
            tooltip: t(loc, 'lists_chip_bar_settings_tooltip'),
            onPressed: _openChipBarSettingsSheet,
            icon: const Icon(Icons.settings_outlined),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inlineController,
                    focusNode: _inlineFocus,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: t(loc, 'lists_inline_add_hint'),
                      border: const OutlineInputBorder(),
                      isDense: true,
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

/// Indent depth for tree-shaped checklists (0 = root category in path).
int _categoryTreeDepthFromPath(String path) {
  final parts = path
      .split(RegExp(r'\s*>\s*'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.length <= 1) return 0;
  return parts.length - 1;
}

Color _listsCategoryAccentColor(int categoryId) {
  final r = DatabaseService.instance.getCategoryRuleById(categoryId);
  return r?.colorOrDefault ?? Colors.grey;
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
    final pillLabel = _categoryRawName(task.categoryId);
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
