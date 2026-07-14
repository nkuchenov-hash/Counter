part of '../database_service.dart';

int _profileTimezoneProjectionRevision = 0;

extension PlanWallTimeExtension on DatabaseService {
  static String? _lastPlanTimeTzLogKey;
  static DateTime? _lastPlanTimeTzLogAt;
  static const Duration _planTimeTzLogDebounce = Duration(seconds: 8);

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

  /// Ensures [PlanningTask.startTime]/[PlanningTask.endDateTime] are profile wall-clock
  /// and [PlanningTask.startUtcInstant]/[PlanningTask.endUtcInstant] hold UTC source of truth.
  PlanningTask _coalescePlanningTaskWallUtcFields(
    PlanningTask task, {
    bool logCreate = false,
    String? titleForLog,
  }) {
    if (task.startTime == null && task.startUtcInstant == null) return task;
    // UTC instant from PocketBase/cache is source of truth; wall fields are projected.
    if (task.startUtcInstant != null) {
      return _reprojectPlanningTaskWallTimes(task);
    }
    if (task.startTime != null) {
      final inputWall = task.startTime;
      final projected = _reprojectPlanningTaskWallTimesFromWallInput(task);
      if (logCreate && inputWall != null && projected.startTime != null) {
        final instants = _planUtcInstants(projected);
        if (instants != null) {
          _logPlanTimeCreateWallToUtc(
            title: titleForLog ?? task.title,
            inputWall: inputWall,
            storedUtc: instants.startUtc,
            projectedWall: projected.startTime!,
          );
        }
      }
      return projected;
    }
    return task;
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
    _allPlansUserCache = [
      for (final t in _allPlansUserCache) _reprojectPlanningTaskWallTimes(t),
    ];
    _rekeyPlanningOptimisticByProfileTimezone();
    _profileTimezoneProjectionRevision++;
    plansDayBodyCache.invalidateAll();
    P0tRenderSnapshotCache.instance.clearPlans();
    _refreshPlansWarmSnapshotsAfterCacheMutation(force: true);
    _pokeAllPlanningStreamHubsFromCache();
  }

  int get profileTimezoneProjectionRevision =>
      _profileTimezoneProjectionRevision;

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

  /// ISO UTC for start of a calendar [dateKey] (`YYYY-MM-DD`) in profile wall-clock, then stored as UTC.
  String? _planStartUtcIsoFromDateKey(String dateKey) {
    try {
      if (dateKey.length < 10) return null;
      final y = int.parse(dateKey.substring(0, 4));
      final m = int.parse(dateKey.substring(5, 7));
      final d = int.parse(dateKey.substring(8, 10));
      final startWall = DateTime(y, m, d, 0, 0, 0);
      return wall_clock
          .wallClockToUtcForLabel(
            startWall,
            _settings.timezoneOffsetHours,
            _settings.preferredTimeZone,
          )
          .toIso8601String();
    } catch (_) {
      return null;
    }
  }
}
