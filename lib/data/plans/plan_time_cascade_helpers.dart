part of '../database_service.dart';

/// Default plan block minutes when no tag duration applies.
const int kDefaultPlanDurationMinutes = 30;

/// Keep in sync with [PlanningSheetTimelinePrefs.timelineSnapMinutes].
const int kPlanScheduleSnapMinutes = 10;

const int kPlanDayOverloadTotalMinutes = 12 * 60;

const int kPlanCategoryOverloadMinutes = 8 * 60;

int? planningWallEstimateSeconds(PlanningTask task) {
  final a = task.startTime;
  final b = task.endDateTime;
  if (a == null || b == null) return null;
  final sec = b.difference(a).inSeconds;
  if (sec <= 0) return null;
  return sec;
}

extension PlanTimeCascadeExtension on DatabaseService {
  int? sanitizeTagDefaultPlanDurationMinutes(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) {
      if (raw < 1) return null;
      return raw.clamp(1, 24 * 60);
    }
    if (raw is double) {
      if (!raw.isFinite || raw < 1) return null;
      return raw.round().clamp(1, 24 * 60);
    }
    if (raw is num) {
      final n = raw.round();
      if (n < 1) return null;
      return n.clamp(1, 24 * 60);
    }
    final n = int.tryParse(raw.toString().trim());
    if (n == null || n < 1) return null;
    return n.clamp(1, 24 * 60);
  }

  /// First tag in [tags] list order with a configured duration wins.
  int? resolveExplicitPlanDurationMinutesFromTags(List<Tag> tags) {
    for (final tag in tags) {
      final d = tagDefaultPlanDurationMinutesOrNull(tag);
      if (d != null) return d;
    }
    return null;
  }

  int? tagDefaultPlanDurationMinutesOrNull(Tag tag) {
    final own = sanitizeTagDefaultPlanDurationMinutes(
      tag.defaultPlanDurationMinutes,
    );
    if (own != null) return own;
    final pid = tag.pbRecordId?.trim() ?? '';
    if (pid.isNotEmpty) {
      for (final t in _userTagsCatalogCache) {
        if (t.pbRecordId == pid) {
          return sanitizeTagDefaultPlanDurationMinutes(
            t.defaultPlanDurationMinutes,
          );
        }
      }
    }
    if (tag.tagId != 0) {
      for (final t in _userTagsCatalogCache) {
        if (t.tagId == tag.tagId && TagCatalogScope.plan.matchesTag(t)) {
          return sanitizeTagDefaultPlanDurationMinutes(
            t.defaultPlanDurationMinutes,
          );
        }
      }
    }
    return null;
  }

  int resolvePlanDurationMinutesFromTags(List<Tag> tags) {
    return resolveExplicitPlanDurationMinutesFromTags(tags) ??
        kDefaultPlanDurationMinutes;
  }

  DateTime _snapPlanWallDateTime(DateTime wall) {
    final snap = kPlanScheduleSnapMinutes;
    final totalMin = wall.hour * 60 + wall.minute;
    final snapped = ((totalMin / snap).round() * snap).clamp(0, 24 * 60 - 1);
    return DateTime(
      wall.year,
      wall.month,
      wall.day,
      snapped ~/ 60,
      snapped % 60,
    );
  }

  DateTime? _resolvedPlanWallEnd(PlanningTask task) {
    final st = task.startTime;
    if (st == null) return null;
    final en = task.endDateTime;
    if (en != null && !en.isBefore(st)) return en;
    return st.add(
      Duration(minutes: resolvePlanDurationMinutesFromTags(task.tags)),
    );
  }

  /// Nudge [startWall] forward when it overlaps an existing scheduled task.
  DateTime _avoidPlanWallScheduleCollisions({
    required DateTime startWall,
    required int durationMin,
    required List<PlanningTask> existingDayPlans,
  }) {
    var start = _snapPlanWallDateTime(startWall);
    for (var pass = 0; pass < existingDayPlans.length + 2; pass++) {
      final end = start.add(Duration(minutes: durationMin));
      DateTime? bumpTo;
      for (final p in existingDayPlans) {
        final pStart = p.startTime;
        if (pStart == null) continue;
        final pEnd = _resolvedPlanWallEnd(p);
        if (pEnd == null) continue;
        if (start.isBefore(pEnd) && pStart.isBefore(end)) {
          if (bumpTo == null || pEnd.isAfter(bumpTo)) bumpTo = pEnd;
        }
      }
      if (bumpTo == null) return start;
      start = _snapPlanWallDateTime(bumpTo);
    }
    return start;
  }

  /// Pure sequential Time View cascade (wall times, duration preserved).
  List<PlanningTask> normalizeSequentialPlanTimesForDay(
    List<PlanningTask> tasks,
  ) {
    return plan_time_seq.cascadeScheduledPlansForTimeViewDay(
      tasks,
      resolveDurationMinutes: resolvePlanDurationMinutesFromTags,
    );
  }

  /// Explicit-order target drop cascade (no start-time sort).
  plan_time_seq.TimeViewTargetInsertionResult applyTimeViewTargetInsertion(
    List<PlanningTask> scheduled,
    plan_time_seq.TimeViewInsertionIntent intent,
  ) {
    return plan_time_seq.applyTimeViewTargetInsertion(
      scheduled: scheduled,
      intent: intent,
      resolveDurationMinutes: resolvePlanDurationMinutesFromTags,
    );
  }

  /// Optimistic + background PATCH for any overlap on a day's scheduled plans.
  bool applySequentialTimeViewCascadeIfNeeded({
    required DateTime wallDay,
    List<PlanningTask>? scheduledSubset,
  }) {
    final dayKey =
        '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}';
    final dayTasks =
        scheduledSubset ??
        planningDayTasksSnapshot(
          wallDay,
        ).where((t) => t.startTime != null).toList();
    if (dayTasks.isEmpty) return false;
    final cascaded = normalizeSequentialPlanTimesForDay(dayTasks);
    final patches = plan_time_seq.diffSequentialCascadePatches(
      dayTasks,
      cascaded,
    );
    if (patches.isEmpty) return false;
    var applied = 0;
    final appliedPatches = <plan_time_seq.PlanTimeSequentialCascadePatch>[];
    for (final p in patches) {
      final overlay =
          _planningOptimisticByDateKey[dayKey]?[p.task.planRowIdForBackend];
      final cached = _findCachedPlanningTaskForEdit(
        p.task.planRowIdForBackend,
        planBusinessId: p.task.planRowId,
      );
      final baseline = overlay ?? cached ?? p.task;
      if (_wallScheduleMatches(baseline, p.task)) continue;
      applyOptimisticPlanningTask(p.task);
      appliedPatches.add(p);
      applied++;
    }
    if (applied == 0) return false;
    notifyPlanningRefresh(scheduleNetworkRefresh: false);
    for (final p in appliedPatches) {
      if (!_isJitVirtualPlanningTask(p.task)) {
        unawaited(_persistSequentialCascadePatch(p));
      }
    }
    _scrubJitVirtualRowsFromUserCache();
    return true;
  }

  Future<void> _persistSequentialCascadePatch(
    plan_time_seq.PlanTimeSequentialCascadePatch patch,
  ) async {
    await updatePlanningTask(
      patch.task.planRowIdForBackend,
      planBusinessId: patch.task.planRowId,
      startTimeDisplay: patch.afterStart,
      endDateTimeDisplay: patch.afterEnd,
      clearEnd: false,
      suppressAppSnack: true,
      recurrenceInstanceDateKey: patch.task.recurrenceInstanceDateKey,
    );
  }

  /// Auto start/end for a new plan on a day. Explicit parsed range always wins.
  /// When [startUtcInstant] is non-null, category default used a fixed/profile TZ
  /// for wall→UTC; callers should pass UTC to [PlanningTask] and let coalesce
  /// reproject display walls.
  ({
    DateTime startWall,
    DateTime endWall,
    DateTime? startUtcInstant,
    DateTime? endUtcInstant,
  })
  resolveAutoPlanSchedule({
    required DateTime wallDay,
    required int categoryId,
    required List<Tag> tags,
    required List<PlanningTask> existingDayPlans,
    DateTime? explicitStartWall,
    DateTime? explicitEndWall,
    bool hasExplicitTimeRange = false,
    int timelineDayStartHour = 0,
    int? explicitDurationMinutes,
  }) {
    if (hasExplicitTimeRange &&
        explicitStartWall != null &&
        explicitEndWall != null) {
      const probePlanId = '__auto_schedule_probe__';
      final dayKey =
          '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}';
      final probe = PlanningTask(
        id: 0,
        title: '',
        categoryId: categoryId,
        isDone: false,
        dateKey: dayKey,
        order: 999999,
        startTime: explicitStartWall,
        endDateTime: explicitEndWall,
        tags: tags,
        planRowId: probePlanId,
      );
      final cascadedProbe = normalizeSequentialPlanTimesForDay([
        ...existingDayPlans,
        probe,
      ]).firstWhere((t) => t.planRowId == probePlanId);
      return (
        startWall: cascadedProbe.startTime ?? explicitStartWall,
        endWall: cascadedProbe.endDateTime ?? explicitEndWall,
        startUtcInstant: null,
        endUtcInstant: null,
      );
    }

    final durationMin =
        explicitDurationMinutes != null && explicitDurationMinutes > 0
        ? explicitDurationMinutes.clamp(1, 24 * 60)
        : resolvePlanDurationMinutesFromTags(tags);

    String? categoryDefaultTimezoneIana;
    var usedCategoryDefault = false;
    late final DateTime startWall;
    if (explicitStartWall != null) {
      startWall = explicitStartWall;
    } else {
      DateTime? latestEnd;
      for (final p in existingDayPlans) {
        if (p.startTime == null) continue;
        final end = _resolvedPlanWallEnd(p);
        if (end == null) continue;
        if (latestEnd == null || end.isAfter(latestEnd)) latestEnd = end;
      }
      if (latestEnd != null) {
        startWall = _snapPlanWallDateTime(latestEnd);
      } else {
        final catSchedule = effectiveDefaultPlanScheduleForCategory(categoryId);
        if (catSchedule?.hhmm != null) {
          final h = int.tryParse(catSchedule!.hhmm!.substring(0, 2));
          final m = int.tryParse(catSchedule.hhmm!.substring(3, 5));
          if (h != null && m != null) {
            usedCategoryDefault = true;
            categoryDefaultTimezoneIana = catSchedule.timezoneIana;
            startWall = _snapPlanWallDateTime(
              DateTime(wallDay.year, wallDay.month, wallDay.day, h, m),
            );
          } else {
            startWall = _snapPlanWallDateTime(
              PlanTimeVisibleWindow.windowStartWall(
                wallDay,
                timelineDayStartHour,
              ),
            );
          }
        } else {
          startWall = _snapPlanWallDateTime(
            PlanTimeVisibleWindow.windowStartWall(
              wallDay,
              timelineDayStartHour,
            ),
          );
        }
      }
    }

    var resolvedStart = _avoidPlanWallScheduleCollisions(
      startWall: startWall,
      durationMin: durationMin,
      existingDayPlans: existingDayPlans,
    );

    var endWall =
        explicitEndWall != null &&
            explicitEndWall.isAfter(resolvedStart) &&
            hasExplicitTimeRange
        ? explicitEndWall
        : resolvedStart.add(Duration(minutes: durationMin));

    final dayKey =
        '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}';
    const probePlanId = '__auto_schedule_probe__';
    final probe = PlanningTask(
      id: 0,
      title: '',
      categoryId: categoryId,
      isDone: false,
      dateKey: dayKey,
      order: 999999,
      startTime: resolvedStart,
      endDateTime: endWall,
      tags: tags,
      planRowId: probePlanId,
    );
    final cascadedProbe = normalizeSequentialPlanTimesForDay([
      ...existingDayPlans,
      probe,
    ]).firstWhere((t) => t.planRowId == probePlanId);
    resolvedStart = cascadedProbe.startTime ?? resolvedStart;
    endWall = cascadedProbe.endDateTime ?? endWall;

    if (usedCategoryDefault) {
      final startUtc = wallUtcForCategoryDefaultWall(
        wallDay: wallDay,
        hour: resolvedStart.hour,
        minute: resolvedStart.minute,
        timezoneIana: categoryDefaultTimezoneIana,
      );
      final endUtc = startUtc.add(Duration(minutes: durationMin));
      return (
        startWall: resolvedStart,
        endWall: endWall,
        startUtcInstant: startUtc,
        endUtcInstant: endUtc,
      );
    }

    return (
      startWall: resolvedStart,
      endWall: endWall,
      startUtcInstant: null,
      endUtcInstant: null,
    );
  }

  ({DateTime startWall, DateTime endWall}) profileDisplayWallsFromAutoSchedule(
    ({
      DateTime startWall,
      DateTime endWall,
      DateTime? startUtcInstant,
      DateTime? endUtcInstant,
    })
    schedule,
  ) {
    if (schedule.startUtcInstant != null) {
      final sw = _profileWallFromUtc(schedule.startUtcInstant!);
      final ew = schedule.endUtcInstant != null
          ? _profileWallFromUtc(schedule.endUtcInstant!)
          : schedule.endWall;
      return (startWall: sw, endWall: ew);
    }
    return (startWall: schedule.startWall, endWall: schedule.endWall);
  }

  PlanningTask planningTaskWithAutoSchedule(
    PlanningTask task,
    ({
      DateTime startWall,
      DateTime endWall,
      DateTime? startUtcInstant,
      DateTime? endUtcInstant,
    })
    schedule,
  ) {
    if (schedule.startUtcInstant != null) {
      return task.copyWith(
        startUtcInstant: schedule.startUtcInstant,
        endUtcInstant: schedule.endUtcInstant,
        startTime: null,
        endDateTime: null,
      );
    }
    return task.copyWith(
      startTime: schedule.startWall,
      endDateTime: schedule.endWall,
    );
  }

  /// Non-blocking overload hints after scheduling plans on a day.
  PlanDayOverloadReport evaluatePlanDayScheduleOverload({
    required List<PlanningTask> dayPlans,
    required int timelineStartHour,
    required int timelineEndHour,
  }) {
    var totalMinutes = 0;
    final byCategory = <int, int>{};
    DateTime? latestEnd;

    for (final p in dayPlans) {
      final st = p.startTime;
      if (st == null) continue;
      final end = _resolvedPlanWallEnd(p);
      if (end == null) continue;
      final dur = end.difference(st).inMinutes.clamp(1, 24 * 60);
      totalMinutes += dur;
      byCategory[p.categoryId] = (byCategory[p.categoryId] ?? 0) + dur;
      if (latestEnd == null || end.isAfter(latestEnd)) latestEnd = end;
    }

    var exceedsVisibleDay = false;
    if (latestEnd != null) {
      DateTime? wallDay;
      for (final p in dayPlans) {
        final dk = p.dateKey.trim();
        if (dk.length >= 10) {
          final parts = dk.split('-');
          if (parts.length >= 3) {
            final y = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            final d = int.tryParse(parts[2]);
            if (y != null && m != null && d != null) {
              wallDay = DateTime(y, m, d);
              break;
            }
          }
        }
      }
      wallDay ??= DateTime(latestEnd.year, latestEnd.month, latestEnd.day);
      final windowStart = PlanTimeVisibleWindow.windowStartWall(
        wallDay,
        timelineStartHour,
      );
      final windowEnd = PlanTimeVisibleWindow.windowEndWall(
        wallDay,
        timelineEndHour,
      );
      exceedsVisibleDay =
          latestEnd.isAfter(windowEnd) || latestEnd.isBefore(windowStart);
    }

    final exceedsDailyTotal = totalMinutes > kPlanDayOverloadTotalMinutes;
    final hasCategoryOverload = byCategory.values.any(
      (m) => m > kPlanCategoryOverloadMinutes,
    );

    return PlanDayOverloadReport(
      exceedsVisibleDay: exceedsVisibleDay,
      exceedsDailyTotal: exceedsDailyTotal,
      hasCategoryOverload: hasCategoryOverload,
    );
  }
}
