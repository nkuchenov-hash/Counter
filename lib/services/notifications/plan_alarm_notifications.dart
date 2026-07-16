part of '../notification_service.dart';

const String _kPrefsScheduledPlanAlarmIds =
    'notification_scheduled_plan_alarm_ids_v1';

extension PlanAlarmNotifications on NotificationService {
  /// Removes only Counter's persisted plan reminders.
  ///
  /// Failed cancellations stay persisted so a later sync can retry them.
  Future<int> clearPlanAlarms() async {
    if (!_supportsPlanAlarmScheduling) return 0;
    try {
      await ensureInitialized();
      final result = await _cancelPersistedPlanAlarms();
      return result.failed;
    } catch (error, stackTrace) {
      _recordError('clear-plan-alarms', error, stackTrace);
      return 1;
    }
  }

  /// Replaces only Counter's plan-reminder queue. Other notification domains
  /// (for example desktop voice) are never removed by this operation.
  Future<PlanAlarmSyncResult> syncAlarms(List<PlanningTask> tasks) async {
    if (!_supportsPlanAlarmScheduling) {
      return const PlanAlarmSyncResult.unsupported();
    }
    try {
      await ensureInitialized();
    } catch (_) {
      return const PlanAlarmSyncResult(
        selected: 0,
        scheduled: 0,
        failed: 1,
        cancelFailed: 0,
      );
    }

    final candidates = buildPlanAlarmCandidates(
      tasks: tasks,
      location: tz.local,
      now: tz.TZDateTime.now(tz.local),
    );
    final cancellation = await _cancelPersistedPlanAlarms();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'plan_alarms',
        'Plan reminders',
        channelDescription: 'Reminders before scheduled plan start times',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(threadIdentifier: 'plan_alarms'),
      macOS: DarwinNotificationDetails(threadIdentifier: 'plan_alarms'),
      windows: WindowsNotificationDetails(),
    );
    final scheduledIds = <String>{...cancellation.remainingIds};
    var failed = 0;
    for (final candidate in candidates) {
      final body = candidate.reminderMinutes == 1
          ? 'Starting in 1 minute'
          : 'Starting in ${candidate.reminderMinutes} minutes';
      try {
        await _plugin.zonedSchedule(
          id: candidate.id,
          scheduledDate: candidate.when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: candidate.title,
          body: body,
          payload: 'plan:${candidate.stableKey}',
        );
        scheduledIds.add(candidate.id.toString());
      } catch (error, stackTrace) {
        failed++;
        _recordError('schedule-plan-alarm', error, stackTrace);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kPrefsScheduledPlanAlarmIds,
      scheduledIds.toList(growable: false),
    );

    return PlanAlarmSyncResult(
      selected: candidates.length,
      scheduled: candidates.length - failed,
      failed: failed,
      cancelFailed: cancellation.failed,
    );
  }

  Future<({int failed, Set<String> remainingIds})>
  _cancelPersistedPlanAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final priorIds = prefs
        .getStringList(_kPrefsScheduledPlanAlarmIds)
        ?.map(int.tryParse)
        .whereType<int>()
        .toSet() ??
        const <int>{};
    final remainingIds = <String>{};
    var failed = 0;
    for (final id in priorIds) {
      try {
        await _plugin.cancel(id: id);
      } catch (error, stackTrace) {
        failed++;
        remainingIds.add(id.toString());
        _recordError('cancel-plan-alarm', error, stackTrace);
      }
    }
    await prefs.setStringList(
      _kPrefsScheduledPlanAlarmIds,
      remainingIds.toList(growable: false),
    );
    return (failed: failed, remainingIds: remainingIds);
  }

  bool get _supportsPlanAlarmScheduling {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      TargetPlatform.fuchsia || TargetPlatform.linux => false,
    };
  }
}
