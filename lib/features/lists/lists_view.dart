// ---------------------------------------------------------------------------
// LISTS / BACKLOG — Undated plans ([PlanningTask.startTime] == null). UI_ISOLATION.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Backlog screen: grouped headers by category path, Play + Done actions (optimistic Done).
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
  bool _loading = true;
  int? _filterCategoryId;
  StreamSubscription<void>? _planRefreshSub;
  DateTime? _lastPlayDebounce;
  static const Duration _playDebounce = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _planRefreshSub =
        DatabaseService.instance.planningRefreshNotifications.listen((_) {
      if (mounted) unawaited(_reload());
    });
    unawaited(_reload());
  }

  @override
  void dispose() {
    _planRefreshSub?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final list = await DatabaseService.instance
        .fetchBacklogPlans(categoryId: _filterCategoryId);
    if (!mounted) return;
    setState(() {
      _flat = list;
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

  void _onPlay(PlanningTask task) {
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = currentLocale.value;
    final theme = Theme.of(context);
    final pairs = DatabaseService.instance.allCategoryIdPathPairs;

    return Scaffold(
      appBar: AppBar(
        title: Text(t(loc, 'lists_title')),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DropdownButtonFormField<int?>(
              initialValue: _filterCategoryId,
              decoration: InputDecoration(
                labelText: t(loc, 'lists_filter_category'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(t(loc, 'lists_filter_all')),
                ),
                for (final p in pairs)
                  DropdownMenuItem<int?>(
                    value: p.id,
                    child: Text(p.path),
                  ),
              ],
              onChanged: (v) {
                setState(() {
                  _filterCategoryId = v;
                  _loading = true;
                });
                unawaited(_reload());
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Builder(
                    builder: (context) {
                      final grouped = _groupByCategoryPath(_flat);
                      return RefreshIndicator(
                        onRefresh: _reload,
                        child: _flat.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height:
                                        MediaQuery.sizeOf(context).height * 0.3,
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
  });

  final PlanningTask task;
  final String locale;
  final VoidCallback onPlay;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          ],
        ),
      ),
    );
  }
}
