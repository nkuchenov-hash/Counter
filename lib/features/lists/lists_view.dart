// ---------------------------------------------------------------------------
// LISTS / BACKLOG — Undated plans ([PlanningTask.startTime] == null). UI_ISOLATION.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_recursive_tree.dart';
import 'package:counter/features/planning/smart_input_parser.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

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

  List<PlanningTask> _flat = [];
  /// Local-only rows until [fetchBacklogPlans] returns the server copy (inline add).
  final List<PlanningTask> _pendingInline = [];
  bool _loading = true;
  int? _filterCategoryId;
  StreamSubscription<void>? _planRefreshSub;
  DateTime? _lastPlayDebounce;
  static const Duration _playDebounce = Duration(milliseconds: 500);
  late final TextEditingController _inlineController;
  final FocusNode _inlineFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _inlineController = TextEditingController();
    _planRefreshSub =
        DatabaseService.instance.planningRefreshNotifications.listen((_) {
      if (mounted) unawaited(_reload());
    });
    unawaited(_reload());
  }

  @override
  void dispose() {
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

  int? _effectiveCategoryIdForNewTask(List<({int id, String path})> pairs) {
    if (_filterCategoryId != null) return _filterCategoryId;
    final d = DatabaseService.instance.defaultCategoryId;
    if (d != null && pairs.any((p) => p.id == d)) return d;
    if (pairs.isNotEmpty) return pairs.first.id;
    return null;
  }

  void _submitInline() {
    final raw = _inlineController.text.trim();
    if (raw.isEmpty) return;
    final stripped = SmartInputParser.backlogTitleFromRaw(raw);
    final gt = DatabaseService.instance.getCleanTitleAndTags(stripped);
    final title = gt.title.trim();
    if (title.isEmpty) return;
    final pairs = DatabaseService.instance.allCategoryIdPathPairs;
    final match = DatabaseService.instance.identifyCategory(title);
    final cat = match?.id ?? _effectiveCategoryIdForNewTask(pairs);
    if (cat == null) return;

    final optId =
        'optimistic-inline-${DateTime.now().microsecondsSinceEpoch}';
    final pending = PlanningTask(
      id: 0,
      planRowId: optId,
      title: title,
      categoryId: cat,
      dateKey: DatabaseService.instance.getTimelineDeviceLocalTodayDateKey(),
      order: 0,
      startTime: null,
    );
    setState(() {
      _pendingInline.insert(0, pending);
      _inlineController.clear();
    });
    unawaited(_persistInlineAdd(pending));
  }

  Future<void> _persistInlineAdd(PlanningTask optimistic) async {
    final wall = DatabaseService.instance.getTimelineDeviceLocalToday();
    final ord = await DatabaseService.instance.nextPlanningOrderForDate(wall);
    final ok = await DatabaseService.instance.addPlanningTask(
      PlanningTask(
        id: 0,
        title: optimistic.title.trim(),
        categoryId: optimistic.categoryId,
        dateKey:
            DatabaseService.instance.getTimelineDeviceLocalTodayDateKey(),
        order: ord,
        startTime: null,
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
    final pairs = DatabaseService.instance.allCategoryIdPathPairs;
    final canInlineAdd = pairs.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(t(loc, 'lists_title')),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CategoryFilterTreeField(
              value: _filterCategoryId,
              decoration: InputDecoration(
                labelText: t(loc, 'lists_filter_category'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                setState(() {
                  _filterCategoryId = v;
                  _loading = true;
                });
                unawaited(_reload());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _inlineController,
              focusNode: _inlineFocus,
              enabled: canInlineAdd,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: t(loc, 'lists_inline_add_hint'),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          DatabaseService.instance.getCategoryPath(task.categoryId),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
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
