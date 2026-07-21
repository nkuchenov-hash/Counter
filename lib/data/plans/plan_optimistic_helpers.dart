part of '../database_service.dart';

/// Dated/backlog optimistic overlay state for Planning + Lists instant UI.

/// Wall **dateKey** → (**planRowIdForBackend** → task) merged on top of server list until PATCH lands.
/// Dateless backlog rows use [_kBacklogOptimisticDayKey], not a calendar day.
final Map<String, Map<String, PlanningTask>> _planningOptimisticByDateKey = {};

const String _kBacklogOptimisticDayKey = '__backlog__';

extension PlanOptimisticOverlayExtension on DatabaseService {
  String _planOptimisticDayKeyFor(PlanningTask task) {
    var dk = task.dateKey.trim();
    if (dk.length >= 10) return dk.substring(0, 10);
    if (task.startTime != null) {
      final st = task.startTime!;
      return '${st.year}-${_two(st.month)}-${_two(st.day)}';
    }
    return _kBacklogOptimisticDayKey;
  }

  void _rekeyPlanningOptimisticByProfileTimezone() {
    final merged = <String, PlanningTask>{};
    for (final dayMap in _planningOptimisticByDateKey.values) {
      merged.addAll(dayMap);
    }
    _planningOptimisticByDateKey.clear();
    for (final t in merged.values) {
      final projected = _reprojectPlanningTaskWallTimes(t);
      final dk = _planOptimisticDayKeyFor(projected);
      _planningOptimisticByDateKey.putIfAbsent(
        dk,
        () => {},
      )[projected.planRowIdForBackend] = projected;
    }
    for (final m in _planningOptimisticByDateKey.values) {
      for (final k in m.keys.toList()) {
        final v = m[k];
        if (v != null) {
          m[k] = _reprojectPlanningTaskWallTimes(v);
        }
      }
    }
  }

  /// Apply client-side plan row for instant list updates; cleared when server PATCH succeeds.
  void applyOptimisticPlanningTask(PlanningTask task) {
    final pid = task.planRowIdForBackend.trim();
    if (pid.isEmpty || pid == '0') return;
    for (final m in _planningOptimisticByDateKey.values) {
      m.remove(pid);
    }
    final dk = _planOptimisticDayKeyFor(task);
    final projected = _coalescePlanningTaskWallUtcFields(task);
    _logPlanTimeCacheProjected(projected);
    _planningOptimisticByDateKey.putIfAbsent(dk, () => {})[pid] = projected;
    _upsertPlanInUserCache(projected);
  }

  void clearOptimisticPlanningForPlanRow(String planRowIdForBackend) {
    final p = planRowIdForBackend.trim();
    if (p.isEmpty) return;
    final keysToRemove = <String>{p};
    if (p.startsWith('optimistic-')) {
      final biz = p.substring('optimistic-'.length).trim();
      if (biz.isNotEmpty) keysToRemove.add(biz);
    }
    for (final m in _planningOptimisticByDateKey.values) {
      for (final key in keysToRemove) {
        m.remove(key);
      }
      m.removeWhere((key, task) {
        if (keysToRemove.contains(key)) return true;
        final biz = _planBusinessUuidFromTask(task);
        return biz != null && keysToRemove.contains(biz);
      });
    }
    if (p.startsWith('optimistic-')) {
      final clientPlanId = p.substring('optimistic-'.length).trim();
      if (clientPlanId.isNotEmpty) {
        _purgeOptimisticPlanRowsFromUserCache(clientPlanId);
        unawaited(_cancelPendingPlanMutationsForBusinessId(clientPlanId));
      }
    }
  }

  List<PlanningTask> _mergePlanningOptimistic(
    String targetDayStr,
    List<PlanningTask> serverPlans,
  ) {
    final hiddenOnThisDay = <String>{};
    for (final e in _planningOptimisticByDateKey.entries) {
      if (e.key == targetDayStr) continue;
      hiddenOnThisDay.addAll(e.value.keys);
    }
    final filtered = serverPlans
        .where((t) => !hiddenOnThisDay.contains(t.planRowIdForBackend))
        .toList();
    final overlay = _planningOptimisticByDateKey[targetDayStr];
    if (overlay == null || overlay.isEmpty) {
      return dedupePlanningTasksForDisplay(
        filtered,
        traceSource: 'stream',
        dayKey: targetDayStr,
      );
    }
    final byId = <String, PlanningTask>{
      for (final t in filtered) t.planRowIdForBackend: t,
    };
    // Overlay wins for any row id present (tags/title edits until PATCH clears the overlay).
    for (final e in overlay.entries) {
      byId[e.key] = e.value;
    }
    final merged = dedupePlanningTasksForDisplay(
      _dedupePlanningTasksByBusinessId(byId.values.toList()),
      traceSource: 'stream',
      dayKey: targetDayStr,
    );
    merged.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      final o = a.order.compareTo(b.order);
      if (o != 0) return o;
      final at = a.startTime;
      final bt = b.startTime;
      if (at != bt) {
        if (at == null) return 1;
        if (bt == null) return -1;
        return at.compareTo(bt);
      }
      return a.title.compareTo(b.title);
    });
    return merged;
  }

  List<PlanningTask> _mergeBacklogOptimistic(List<PlanningTask> server) {
    final overlay = _planningOptimisticByDateKey[_kBacklogOptimisticDayKey];
    if (overlay == null || overlay.isEmpty) return server;
    final byId = <String, PlanningTask>{
      for (final t in server) t.planRowIdForBackend: t,
    };
    for (final e in overlay.entries) {
      final t = e.value;
      if (t.startTime != null) continue;
      final dk = t.dateKey.trim();
      if (dk.length >= 10) continue;
      byId[e.key] = t;
    }
    final merged = byId.values.toList();
    merged.sort((a, b) {
      final o = a.order.compareTo(b.order);
      if (o != 0) return o;
      return a.title.compareTo(b.title);
    });
    return merged;
  }

  /// Instant backlog snapshot (cache + optimistic overlay) — no network.
  List<PlanningTask> getBacklogPlansSnapshot({
    int? categoryId,
    bool includeCompleted = false,
  }) {
    final base = _filterBacklogFromAll(
      _allPlansUserCache,
      categoryId: categoryId,
      includeCompleted: includeCompleted,
    );
    return _mergeBacklogOptimistic(base);
  }
}
