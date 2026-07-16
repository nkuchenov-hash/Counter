part of '../database_service.dart';

Timer? _planAlarmRescheduleDebounceTimer;

/// Coordinates debounced native reminder refreshes for scheduled plans.
extension PlanAlarmSchedulerExtension on DatabaseService {
  /// Immediately refreshes native plan reminders from the current warm cache.
  Future<void> reschedulePlanAlarmsNow() {
    _planAlarmRescheduleDebounceTimer?.cancel();
    _planAlarmRescheduleDebounceTimer = null;
    return _reschedulePlanAlarmsWork();
  }

  /// Debounced: reschedules OS plan reminders after timeline/plan cache refresh (no await on callers).
  void _requestPlanAlarmReschedule() {
    if (kIsWeb) return;
    _planAlarmRescheduleDebounceTimer?.cancel();
    _planAlarmRescheduleDebounceTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_reschedulePlanAlarmsWork());
    });
  }

  Future<void> _reschedulePlanAlarmsWork() async {
    if (kIsWeb) return;
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return;
    if (!_isPlansTableConfigured) return;
    try {
      await NotificationService.instance.ensureInitialized();
    } catch (_) {
      return;
    }
    try {
      await _ensureAllPlansUserCacheFresh();
      final all = _allPlansUserCache;
      if (all.isEmpty && _allPlansUserCacheFetchedAt == null) {
        return;
      }
      final today = getTimelineDeviceLocalToday();
      final todayWall = DateTime(today.year, today.month, today.day);
      final endWall = todayWall.add(const Duration(days: 6));
      final windowTasks = _collectPlanningTasksForWallRange(
        all,
        todayWall,
        endWall,
      );
      final result = await NotificationService.instance.syncAlarms(windowTasks);
      if (kDebugMode && (result.failed > 0 || result.cancelFailed > 0)) {
        debugPrint(
          '[PLAN_ALARM_SYNC] selected=${result.selected} '
          'scheduled=${result.scheduled} failed=${result.failed} '
          'cancelFailed=${result.cancelFailed}',
        );
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[PLAN_ALARM_SYNC] failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }
}
