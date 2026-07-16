import 'package:counter/data/models.dart';
import 'package:timezone/timezone.dart' as tz;

/// OS plan reminders: keep below the iOS pending-notification ceiling.
const int kPlanAlarmNotificationLimit = 50;

final class PlanAlarmCandidate {
  const PlanAlarmCandidate({
    required this.id,
    required this.stableKey,
    required this.when,
    required this.title,
    required this.reminderMinutes,
  });

  final int id;
  final String stableKey;
  final tz.TZDateTime when;
  final String title;
  final int reminderMinutes;
}

/// 32-bit FNV-1a over UTF-16 code units, masked to a positive 31-bit int.
///
/// Stable across app restarts, unlike VM object hash codes. [stableKey] must
/// be [PlanningTask.recordIdForBackend] (PocketBase row id or `virt-…`).
int planAlarmNotificationIdFromStableKey(String stableKey) {
  var hash = 0x811c9dc5;
  for (final unit in stableKey.codeUnits) {
    hash = hash ^ unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// Pure reminder policy: validates, orders, and caps future plan alarms.
///
/// Stored UTC is preferred so a profile timezone that differs from the device
/// timezone still fires at the correct instant. Legacy rows without UTC fall
/// back to their wall-clock [PlanningTask.startTime].
List<PlanAlarmCandidate> buildPlanAlarmCandidates({
  required Iterable<PlanningTask> tasks,
  required tz.Location location,
  required tz.TZDateTime now,
  int limit = kPlanAlarmNotificationLimit,
}) {
  final candidates = <PlanAlarmCandidate>[];
  for (final task in tasks) {
    if (task.isDone) continue;
    final reminderMinutes = task.reminderOffset;
    if (reminderMinutes == null || reminderMinutes < 0) continue;
    final stableKey = task.recordIdForBackend.trim();
    if (stableKey.isEmpty) continue;

    final startUtc = task.startUtcInstant;
    final startWall = task.startTime;
    if (startUtc == null && startWall == null) continue;
    final start = startUtc != null
        ? tz.TZDateTime.from(startUtc.toUtc(), location)
        : tz.TZDateTime(
            location,
            startWall!.year,
            startWall.month,
            startWall.day,
            startWall.hour,
            startWall.minute,
            startWall.second,
          );
    final fire = start.subtract(Duration(minutes: reminderMinutes));
    if (!fire.isAfter(now)) continue;

    candidates.add(
      PlanAlarmCandidate(
        id: planAlarmNotificationIdFromStableKey(stableKey),
        stableKey: stableKey,
        when: fire,
        title: task.title.trim().isEmpty ? 'Plan' : task.title.trim(),
        reminderMinutes: reminderMinutes,
      ),
    );
  }

  candidates.sort((a, b) => a.when.compareTo(b.when));
  return candidates.take(limit < 0 ? 0 : limit).toList(growable: false);
}
