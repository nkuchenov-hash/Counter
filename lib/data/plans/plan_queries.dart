part of '../database_service.dart';

extension PlanQueriesExtension on DatabaseService {
  /// Merges non-recurring day matches + JIT [expandRecurringPlans] for each wall day in [startWall]…[endWall] inclusive.
  List<PlanningTask> _collectPlanningTasksForWallRange(
    List<PlanningTask> allTemplates,
    DateTime startWall,
    DateTime endWall,
  ) {
    DateTime wallOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    var d = wallOnly(startWall);
    final last = wallOnly(endWall);
    if (last.isBefore(d)) return [];
    final out = <PlanningTask>[];
    while (!d.isAfter(last)) {
      final dk = '${d.year}-${_two(d.month)}-${_two(d.day)}';
      for (final t in allTemplates) {
        if (t.planRowIdForBackend.startsWith('optimistic-')) continue;
        if (t.rrule != null && t.rrule!.trim().isNotEmpty) continue;
        if (t.startTime == null) continue;
        final taskDk =
            '${t.startTime!.year}-${_two(t.startTime!.month)}-${_two(t.startTime!.day)}';
        if (taskDk != dk) continue;
        out.add(t);
      }
      out.addAll(expandRecurringPlans(allTemplates, d, d));
      d = d.add(const Duration(days: 1));
    }
    return out;
  }

  List<PlanningTask> _filterBacklogFromAll(
    List<PlanningTask> all, {
    int? categoryId,
    bool includeCompleted = false,
  }) {
    final out = <PlanningTask>[];
    for (final t in all) {
      final pid = t.planRowIdForBackend.trim();
      if (pid.startsWith('optimistic-') || pid.startsWith('virt-')) continue;
      if (!includeCompleted && t.isDone) continue;
      if (t.startTime != null) continue;
      if (t.rrule != null && t.rrule!.trim().isNotEmpty) continue;
      if (t.isBacklogChildItem) continue;
      final dk = t.dateKey.trim();
      if (dk.length >= 10) continue;
      if (categoryId != null && t.categoryId != categoryId) continue;
      out.add(t);
    }
    out.sort((a, b) {
      final o = a.order.compareTo(b.order);
      if (o != 0) return o;
      return a.title.compareTo(b.title);
    });
    return out;
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

  List<PlanningTask> _filterPlansForWallDay(
    List<PlanningTask> all,
    DateTime selectedDate,
  ) {
    final targetDayStr =
        '${selectedDate.year}-${_two(selectedDate.month)}-${_two(selectedDate.day)}';
    final plans = <PlanningTask>[];
    for (final t in all) {
      if (t.rrule != null && t.rrule!.trim().isNotEmpty) continue;
      final instants = _planUtcInstants(t);
      if (instants == null) continue;
      final startWall = _profileWallFromUtc(instants.startUtc);
      final endWall = instants.endUtc != null
          ? _profileWallFromUtc(instants.endUtc!)
          : null;
      final planDayStr = _dateKeyFromDate(startWall);
      final visible = planDayStr == targetDayStr;
      _logPlanTimeTzProjection(
        task: t,
        selectedDay: targetDayStr,
        visible: visible,
        startUtc: instants.startUtc,
        endUtc: instants.endUtc,
        wallStart: startWall,
        wallEnd: endWall,
      );
      if (!visible) continue;
      plans.add(_reprojectPlanningTaskWallTimes(t));
    }
    plans.addAll(expandRecurringPlans(all, selectedDate, selectedDate));
    plans.sort((a, b) {
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
    return dedupePlanningTasksForDisplay(
      plans,
      traceSource: 'cache',
      dayKey: targetDayStr,
    );
  }

  /// Group scheduled plans by wall `YYYY-MM-DD` for [startWall]…[endWall] from Brain cache.
  Map<String, List<PlanningTask>> planningTasksGroupedByWallDayForRange(
    DateTime startWall,
    DateTime endWall,
  ) {
    final collected = _collectPlanningTasksForWallRange(
      _allPlansUserCache,
      startWall,
      endWall,
    );
    final map = <String, List<PlanningTask>>{};
    for (final t in collected) {
      if (t.startTime == null) continue;
      final dk = planningWallScheduleDateKey(t);
      if (dk.length < 10) continue;
      map.putIfAbsent(dk, () => <PlanningTask>[]).add(t);
    }
    for (final list in map.values) {
      list.sort((a, b) {
        final as = a.startTime;
        final bs = b.startTime;
        if (as == null || bs == null) return 0;
        return as.compareTo(bs);
      });
    }
    return map;
  }

  /// Cache + optimistic overlay for one wall day (no network).
  List<PlanningTask> planningDayTasksSnapshot(DateTime wallDay) {
    final key = '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}';
    final base = _filterPlansForWallDay(_allPlansUserCache, wallDay);
    return _mergePlanningOptimistic(key, base);
  }

  /// Undated child rows for a backlog parent ([PlanningTask.parentPlanPocketId]).
  List<PlanningTask> backlogChildPlansForParent(String parentPocketPlanId) {
    final want = parentPocketPlanId.trim();
    if (want.isEmpty) return const [];
    final out = <PlanningTask>[];
    for (final t in _allPlansUserCache) {
      if (t.startTime != null) continue;
      if ((t.parentPlanPocketId ?? '').trim() != want) continue;
      out.add(t);
    }
    for (final m in _planningOptimisticByDateKey.values) {
      for (final t in m.values) {
        if (t.startTime != null) continue;
        if ((t.parentPlanPocketId ?? '').trim() != want) continue;
        if (!out.any((x) => x.planRowIdForBackend == t.planRowIdForBackend)) {
          out.add(t);
        }
      }
    }
    out.sort((a, b) {
      final o = a.order.compareTo(b.order);
      if (o != 0) return o;
      return a.title.compareTo(b.title);
    });
    return out;
  }
}
