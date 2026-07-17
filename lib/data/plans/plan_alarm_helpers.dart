part of '../database_service.dart';

DateTime? _planAlarmLastFailureAt;
String? _planAlarmLastFailureMsg;

/// Brain → OS plan-alarm bridge (@ARCHITECTURE — no await on UI hot paths).
extension PlanAlarmHelpersExtension on DatabaseService {
  /// Debounced: reschedules OS plan reminders after plan cache refresh.
  void _requestPlanAlarmReschedule() {
    if (kIsWeb) return;
    _planAlarmRescheduleDebounceTimer?.cancel();
    _planAlarmRescheduleDebounceTimer = Timer(const Duration(seconds: 2), () {
      unawaited(reconcilePlanNotifications());
    });
  }

  /// Public bounded reconcile: hydrated cache only, no network, idempotent.
  ///
  /// Safe after startup hydration, resume ([notifyPlanningRefresh]), login,
  /// timezone change, and pending-sync reconciliation. Failures do **not**
  /// roll back plan edits.
  Future<void> reconcilePlanNotifications() async {
    if (kIsWeb) return;
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return;
    if (!_isPlansTableConfigured) return;

    try {
      await NotificationService.instance.ensureInitialized();
    } catch (_) {
      return;
    }

    try {
      final specs = _buildPlanAlarmSpecsFromHydratedCache();
      await NotificationService.instance.reconcilePlanAlarms(specs);
    } catch (e) {
      _surfacePlanAlarmFailureOnce(e);
    }
  }

  List<PlanAlarmSpec> _buildPlanAlarmSpecsFromHydratedCache() {
    final all = List<PlanningTask>.from(_allPlansUserCache);
    final today = getTimelineDeviceLocalToday();
    final todayWall = DateTime(today.year, today.month, today.day);
    final endWall = todayWall.add(const Duration(days: 6));
    final windowTasks = _collectPlanningTasksForWallRange(
      all,
      todayWall,
      endWall,
    );

    final nowUtc = DateTime.now().toUtc();
    final offset = settings.timezoneOffsetHours;
    final tzLabel = settings.preferredTimeZone;
    final raw = <PlanAlarmSpec>[];
    var rejected = 0;

    for (final t in windowTasks) {
      final stable = t.recordIdForBackend.trim();
      final optimistic = stable.startsWith('optimistic-') ||
          t.planRowIdForBackend.startsWith('optimistic-');
      final wall = t.startTime;
      final dk = (t.dateKey.trim().length >= 10)
          ? t.dateKey.trim().substring(0, 10)
          : (wall != null
              ? '${wall.year}-${_two(wall.month)}-${_two(wall.day)}'
              : '');

      final built = tryBuildPlanAlarmSpec(
        stablePlanKey: stable,
        wallDateKey: dk,
        startWall: wall,
        startUtcInstant: t.startUtcInstant,
        reminderOffsetMinutes: t.reminderOffset,
        isDone: t.isDone,
        isDeletedOrOptimistic: optimistic,
        nowUtc: nowUtc,
        profileOffsetHours: offset,
        preferredTimezoneLabel: tzLabel,
        title: t.title,
      );
      final spec = built.spec;
      if (spec != null) {
        raw.add(spec);
      } else {
        rejected++;
      }
    }

    final finalized = finalizePlanAlarmSpecs(raw);
    if (kPlanAlarmDiag || kDebugMode) {
      assert(() {
        debugPrint(
          '[PLAN_ALARM] brain_build window=${windowTasks.length} '
          'raw=${raw.length} finalized=${finalized.length} '
          'rejected=$rejected',
        );
        return true;
      }());
    }
    return finalized;
  }

  /// Merges non-recurring day matches + JIT [expandRecurringPlans] for each
  /// wall day in [startWall]…[endWall] inclusive.
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

  void _surfacePlanAlarmFailureOnce(Object error) {
    final msg = 'Plan reminder scheduling failed';
    final now = DateTime.now();
    final prev = _planAlarmLastFailureAt;
    if (prev != null &&
        now.difference(prev) < const Duration(seconds: 60) &&
        _planAlarmLastFailureMsg == msg) {
      return;
    }
    _planAlarmLastFailureAt = now;
    _planAlarmLastFailureMsg = msg;
    if (kPlanAlarmDiag || kDebugMode) {
      debugPrint('[PLAN_ALARM] reconcile_failed $error');
    }
    if (!_notify.isClosed) {
      _notify.add(msg);
    }
  }
}
