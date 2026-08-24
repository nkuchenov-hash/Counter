part of '../database_service.dart';

/// Profile-timezone projection: UTC/profile-wall conversion, wall-day filter, Time Mode DTO.

int _profileTimezoneProjectionRevision = 0;
String? _lastAppliedProfileTimezoneProjectionSignature;

String? _lastPlanTimeTzLogKey;
DateTime? _lastPlanTimeTzLogAt;
const Duration _planTimeTzLogDebounce = Duration(seconds: 8);

/// Profile-timezone projection for Time mode (labels, placement, drag, filter).
class TimeModeProjectedPlan {
  const TimeModeProjectedPlan({
    required this.task,
    required this.startUtc,
    required this.wallStart,
    required this.wallDateKey,
    required this.plannedTimeLabel,
    this.endUtc,
    this.wallEnd,
  });

  final PlanningTask task;
  final DateTime startUtc;
  final DateTime? endUtc;
  final DateTime wallStart;
  final DateTime? wallEnd;
  final String wallDateKey;
  final String plannedTimeLabel;

  String get planId => task.planRowIdForBackend.trim();

  DateTime get profileWallStart => wallStart;

  DateTime? get profileWallEnd => wallEnd;

  String get profileWallDateKey => wallDateKey;

  int get startMinuteOfDay => wallStart.hour * 60 + wallStart.minute;

  int? get endMinuteOfDay =>
      wallEnd != null ? wallEnd!.hour * 60 + wallEnd!.minute : null;

  int get durationMinutes {
    if (wallEnd != null) {
      final mins = wallEnd!.difference(wallStart).inMinutes;
      if (mins > 0) return mins.clamp(5, 24 * 60);
    }
    return 30;
  }

  PlanningTask get projectedTask => task.copyWith(
    startUtcInstant: startUtc,
    endUtcInstant: endUtc,
    startTime: wallStart,
    endDateTime: wallEnd,
    dateKey: wallDateKey,
    endDateKey: wallEnd != null
        ? '${wallEnd!.year.toString().padLeft(4, '0')}-'
              '${wallEnd!.month.toString().padLeft(2, '0')}-'
              '${wallEnd!.day.toString().padLeft(2, '0')}'
        : wallDateKey,
    date: DateTime.utc(wallStart.year, wallStart.month, wallStart.day),
  );
}

extension PlanTimeModeProjection on DatabaseService {
  /// Profile-wall projection for Time mode — **UTC instant only** (never stale
  /// [PlanningTask.startTime] / [PlanningTask.dateKey] without [startUtcInstant]).
  TimeModeProjectedPlan? projectPlanForTimeMode(PlanningTask task) {
    if (task.startUtcInstant == null) return null;
    final normalized = _reprojectPlanningTaskWallTimes(task);
    final startUtc = normalized.startUtcInstant!.toUtc();
    final endUtc = normalized.endUtcInstant?.toUtc();
    final wallStart = _profileWallFromUtc(startUtc);
    final wallEnd = endUtc != null ? _profileWallFromUtc(endUtc) : null;
    final dk =
        '${wallStart.year.toString().padLeft(4, '0')}-'
        '${wallStart.month.toString().padLeft(2, '0')}-'
        '${wallStart.day.toString().padLeft(2, '0')}';
    final startLabel =
        '${wallStart.hour.toString().padLeft(2, '0')}:${wallStart.minute.toString().padLeft(2, '0')}';
    final plannedTimeLabel = wallEnd != null
        ? '$startLabel – ${wallEnd.hour.toString().padLeft(2, '0')}:${wallEnd.minute.toString().padLeft(2, '0')}'
        : startLabel;
    return TimeModeProjectedPlan(
      task: normalized,
      startUtc: startUtc,
      endUtc: endUtc,
      wallStart: wallStart,
      wallEnd: wallEnd,
      wallDateKey: dk,
      plannedTimeLabel: plannedTimeLabel,
    );
  }

  /// Log profile projection for Time mode placement audit (debounced).
  void logTimeTzProjectForTimeMode(
    TimeModeProjectedPlan proj, {
    required String selectedDay,
    required bool visible,
  }) {
    _logPlanTimeTzProjection(
      task: proj.task,
      selectedDay: selectedDay,
      visible: visible,
      startUtc: proj.startUtc,
      endUtc: proj.endUtc,
      wallStart: proj.wallStart,
      wallEnd: proj.wallEnd,
    );
  }

  String profileTimezoneShortLabel() {
    final label = settings.preferredTimeZone.trim();
    final entry = catalogEntryForStoredTimezone(label);
    if (entry != null) return entry.code;
    final off = settings.timezoneOffsetHours;
    if (off == 0) return 'UTC';
    return off > 0 ? 'UTC+$off' : 'UTC$off';
  }
}

extension PlanProfileTimezoneProjectionExtension on DatabaseService {
  void _logPlanTimeTzProjection({
    required PlanningTask task,
    required String selectedDay,
    required bool visible,
    DateTime? startUtc,
    DateTime? endUtc,
    DateTime? wallStart,
    DateTime? wallEnd,
  }) {
    final planId = task.planRowIdForBackend.trim();
    final lineKey =
        '$planId|$selectedDay|${task.startUtcInstant?.toIso8601String()}|visible=$visible';
    final now = DateTime.now();
    if (_lastPlanTimeTzLogKey == lineKey &&
        _lastPlanTimeTzLogAt != null &&
        now.difference(_lastPlanTimeTzLogAt!) < _planTimeTzLogDebounce) {
      return;
    }
    _lastPlanTimeTzLogKey = lineKey;
    _lastPlanTimeTzLogAt = now;
    if (!kVerbosePlanTimeTzProjectionLogs || kReleaseMode) return;
    // ignore: avoid_print
    final startMin = wallStart != null
        ? wallStart.hour * 60 + wallStart.minute
        : null;
    final endMin = wallEnd != null ? wallEnd.hour * 60 + wallEnd.minute : null;
    print(
      'TIME_TZ_PROJECT planId=${planId.isEmpty ? '-' : planId} '
      'profileTz=${_settings.preferredTimeZone.trim().isEmpty ? 'offset:${_settings.timezoneOffsetHours}' : _settings.preferredTimeZone.trim()} '
      'startUtc=${startUtc?.toUtc().toIso8601String() ?? '-'} '
      'endUtc=${endUtc?.toUtc().toIso8601String() ?? '-'} '
      'wallStart=${wallStart != null ? _planLogWallIso(wallStart) : '-'} '
      'wallEnd=${wallEnd != null ? _planLogWallIso(wallEnd) : '-'} '
      'startMin=${startMin ?? '-'} endMin=${endMin ?? '-'} '
      'wallDateKey=${wallStart != null ? _dateKeyFromDate(wallStart) : '-'} '
      'selectedDay=$selectedDay visible=$visible',
    );
  }

  ({DateTime startUtc, DateTime? endUtc})? _planUtcInstants(PlanningTask t) {
    if (t.startUtcInstant != null) {
      return (
        startUtc: t.startUtcInstant!.toUtc(),
        endUtc: t.endUtcInstant?.toUtc(),
      );
    }
    final st = t.startTime;
    if (st == null) return null;
    return (
      startUtc: _profileUtcFromWall(st).toUtc(),
      endUtc: t.endDateTime != null
          ? _profileUtcFromWall(t.endDateTime!).toUtc()
          : null,
    );
  }

  String _planLogWallIso(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}T'
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _logPlanTimeCreateWallToUtc({
    required String title,
    required DateTime inputWall,
    required DateTime storedUtc,
    required DateTime projectedWall,
  }) {
    print(
      'PLAN_TIME_CREATE_WALL_TO_UTC title=$title '
      'inputWall=${_planLogWallIso(inputWall)} '
      'profileOffset=${_settings.timezoneOffsetHours} '
      'storedUtc=${storedUtc.toUtc().toIso8601String()} '
      'projectedWall=${_planLogWallIso(projectedWall)}',
    );
  }

  void _logPlanTimeEditWallToUtc({
    required String planId,
    DateTime? oldWall,
    DateTime? newWall,
    required DateTime storedUtc,
    required DateTime projectedWall,
  }) {
    print(
      'PLAN_TIME_EDIT_WALL_TO_UTC planId=$planId '
      'oldWall=${oldWall != null ? _planLogWallIso(oldWall) : '-'} '
      'newWall=${newWall != null ? _planLogWallIso(newWall) : '-'} '
      'storedUtc=${storedUtc.toUtc().toIso8601String()} '
      'projectedWall=${_planLogWallIso(projectedWall)}',
    );
  }

  void _logPlanTimeCacheProjected(PlanningTask task) {
    final instants = _planUtcInstants(task);
    if (instants == null || task.startTime == null) return;
    final planId = (task.planRowId ?? task.pocketRecordId ?? '').trim();
    print(
      'PLAN_TIME_CACHE_PROJECTED planId=${planId.isEmpty ? '-' : planId} '
      'startUtc=${instants.startUtc.toUtc().toIso8601String()} '
      'wallStart=${_planLogWallIso(task.startTime!)} '
      'dateKey=${task.dateKey}',
    );
  }

  /// Canonical create guard: dated plans without an explicit time must still
  /// honor the effective category default (own value or nearest parent).
  /// [titleForLog] is supplied by [addPlanningTask], so cache/read projection
  /// paths do not retroactively schedule existing unscheduled rows.
  PlanningTask _applyCategoryDefaultPlanScheduleForCreate(
    PlanningTask task, {
    required String titleForLog,
  }) {
    if (task.startTime != null || task.startUtcInstant != null) return task;
    final dateKey = task.dateKey.trim();
    if (dateKey.length < 10) return task;
    final effectiveDefault = effectiveDefaultPlanScheduleForCategory(
      task.categoryId,
    );
    if (effectiveDefault?.hhmm == null) return task;

    final parsedDay = DateTime.tryParse(dateKey.substring(0, 10));
    if (parsedDay == null) return task;
    final wallDay = DateTime(parsedDay.year, parsedDay.month, parsedDay.day);
    final existingDayPlans = planningDayTasksSnapshot(wallDay);
    final schedule = resolveAutoPlanSchedule(
      wallDay: wallDay,
      categoryId: task.categoryId,
      tags: task.tags,
      existingDayPlans: existingDayPlans,
      timelineDayStartHour: 0,
    );
    final scheduled = planningTaskWithAutoSchedule(task, schedule);
    if (kDebugMode) {
      debugPrint(
        'PLAN_DEFAULT_TIME_APPLIED title=$titleForLog '
        'category=${task.categoryId} default=${effectiveDefault!.hhmm} '
        'tz=${effectiveDefault.timezoneIana ?? 'profile'}',
      );
    }
    return scheduled;
  }

  /// Ensures [PlanningTask.startTime]/[PlanningTask.endDateTime] are profile wall-clock
  /// and [PlanningTask.startUtcInstant]/[PlanningTask.endUtcInstant] hold UTC source of truth.
  PlanningTask _coalescePlanningTaskWallUtcFields(
    PlanningTask task, {
    bool logCreate = false,
    String? titleForLog,
  }) {
    var input = task;
    if (titleForLog != null &&
        input.startTime == null &&
        input.startUtcInstant == null) {
      input = _applyCategoryDefaultPlanScheduleForCreate(
        input,
        titleForLog: titleForLog,
      );
    }
    if (input.startTime == null && input.startUtcInstant == null) return input;
    // UTC instant from PocketBase/cache is source of truth; wall fields are projected.
    if (input.startUtcInstant != null) {
      return _reprojectPlanningTaskWallTimes(input);
    }
    if (input.startTime != null) {
      final inputWall = input.startTime;
      final projected = _reprojectPlanningTaskWallTimesFromWallInput(input);
      if (logCreate && inputWall != null && projected.startTime != null) {
        final instants = _planUtcInstants(projected);
        if (instants != null) {
          _logPlanTimeCreateWallToUtc(
            title: titleForLog ?? input.title,
            inputWall: inputWall,
            storedUtc: instants.startUtc,
            projectedWall: projected.startTime!,
          );
        }
      }
      return projected;
    }
    return input;
  }

  /// Derive UTC instants from profile wall fields only (create/edit path).
  ({DateTime startUtc, DateTime? endUtc})? _planUtcInstantsFromWall(
    PlanningTask t,
  ) {
    final st = t.startTime;
    if (st == null) return null;
    return (
      startUtc: _profileUtcFromWall(st).toUtc(),
      endUtc: t.endDateTime != null
          ? _profileUtcFromWall(t.endDateTime!).toUtc()
          : null,
    );
  }

  PlanningTask _reprojectPlanningTaskWallTimesFromWallInput(PlanningTask t) {
    final instants = _planUtcInstantsFromWall(t);
    if (instants == null) return t;
    final startWall = _profileWallFromUtc(instants.startUtc);
    final endWall = instants.endUtc != null
        ? _profileWallFromUtc(instants.endUtc!)
        : null;
    final dk = _dateKeyFromDate(startWall);
    final edk = endWall != null ? _dateKeyFromDate(endWall) : dk;
    return t.copyWith(
      startUtcInstant: instants.startUtc,
      endUtcInstant: instants.endUtc,
      startTime: startWall,
      endDateTime: endWall,
      dateKey: dk,
      endDateKey: edk,
      date: DateTime.utc(startWall.year, startWall.month, startWall.day),
    );
  }

  PlanningTask _reprojectPlanningTaskWallTimes(PlanningTask t) {
    final instants = _planUtcInstants(t);
    if (instants == null) return t;
    final startWall = _profileWallFromUtc(instants.startUtc);
    final endWall = instants.endUtc != null
        ? _profileWallFromUtc(instants.endUtc!)
        : null;
    final dk = _dateKeyFromDate(startWall);
    final edk = endWall != null ? _dateKeyFromDate(endWall) : dk;
    return t.copyWith(
      startUtcInstant: instants.startUtc,
      endUtcInstant: instants.endUtc,
      startTime: startWall,
      endDateTime: endWall,
      dateKey: dk,
      endDateKey: edk,
      date: DateTime.utc(startWall.year, startWall.month, startWall.day),
    );
  }

  /// Recompute profile wall-clock fields after timezone change (UTC instants unchanged).
  void reprojectAllPlansForProfileTimezone() {
    final signature =
        '${_settings.timezoneOffsetHours}|${_settings.preferredTimeZone.trim()}';
    if (_lastAppliedProfileTimezoneProjectionSignature == signature) return;

    _allPlansUserCache = [
      for (final t in _allPlansUserCache) _reprojectPlanningTaskWallTimes(t),
    ];
    _rekeyPlanningOptimisticByProfileTimezone();
    _profileTimezoneProjectionRevision++;
    plansDayBodyCache.invalidateAll();
    P0tRenderSnapshotCache.instance.clearPlans();
    _refreshPlansWarmSnapshotsAfterCacheMutation(force: true);
    _pokeAllPlanningStreamHubsFromCache();
    _lastAppliedProfileTimezoneProjectionSignature = signature;
  }

  int get profileTimezoneProjectionRevision =>
      _profileTimezoneProjectionRevision;

  int plansProjectionCacheSignature() => Object.hash(
    _allPlansUserCache.length,
    _settings.timezoneOffsetHours,
    _settings.preferredTimeZone.trim(),
    _profileTimezoneProjectionRevision,
  );

  /// Profile wall minute-of-day for a stored UTC instant (Time View / filter tests).
  int profileWallMinuteOfDayFromUtc(DateTime utc) {
    final wall = _profileWallFromUtc(utc.toUtc());
    return wall.hour * 60 + wall.minute;
  }

  /// Whether [startUtc] falls on [wallDay] in the active profile timezone.
  bool planUtcInstantOnProfileWallDay({
    required DateTime startUtc,
    required DateTime wallDay,
  }) {
    final startWall = _profileWallFromUtc(startUtc.toUtc());
    final targetDayStr =
        '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}';
    return _dateKeyFromDate(startWall) == targetDayStr;
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

  /// Wall `YYYY-MM-DD` where the plan is currently scheduled (profile TZ projection).
  String planningWallScheduleDateKey(PlanningTask t) {
    final instants = _planUtcInstants(t);
    if (instants != null) {
      final wall = _profileWallFromUtc(instants.startUtc);
      return _dateKeyFromDate(wall);
    }
    final dk = t.dateKey.trim();
    if (dk.length >= 10) return dk.substring(0, 10);
    return '';
  }
}
