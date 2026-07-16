part of '../database_service.dart';

/// Pure auto-scheduling calculations and overload evaluation.
extension PlanAutoScheduleExtension on DatabaseService {
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
