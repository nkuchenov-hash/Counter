part of '../database_service.dart';

Timer? _planAlarmRescheduleDebounceTimer;

/// Coordinates debounced native reminder refreshes for scheduled plans.
extension PlanAlarmSchedulerExtension on DatabaseService {
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
      final all = await _fetchAllPlanningTasksForCurrentUser();
      final today = getTimelineDeviceLocalToday();
      final todayWall = DateTime(today.year, today.month, today.day);
      final endWall = todayWall.add(const Duration(days: 6));
      final windowTasks = _collectPlanningTasksForWallRange(
        all,
        todayWall,
        endWall,
      );
      await NotificationService.instance.syncAlarms(windowTasks);
    } catch (_) {}
  }
}
