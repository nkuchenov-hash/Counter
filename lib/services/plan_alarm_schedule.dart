import 'package:counter/shared/time/wall_clock.dart' as wall_clock;

/// Max OS-scheduled plan reminders per reconcile (7-day window).
const int kPlanAlarmNotificationLimit = 50;

/// Why a plan occurrence was not scheduled.
enum PlanAlarmRejectReason {
  done,
  deletedOrOptimistic,
  noReminder,
  noStart,
  past,
  invalidKey,
}

/// Opaque schedule request for [NotificationService] (no PocketBase / UI).
class PlanAlarmSpec {
  const PlanAlarmSpec({
    required this.notificationId,
    required this.occurrenceKey,
    required this.fireUtc,
    required this.title,
    required this.reminderMinutes,
  });

  final int notificationId;
  final String occurrenceKey;
  final DateTime fireUtc;
  final String title;
  final int reminderMinutes;
}

/// Result of building one occurrence alarm (spec or reject reason).
class PlanAlarmBuildResult {
  const PlanAlarmBuildResult.spec(this.spec) : rejectReason = null;
  const PlanAlarmBuildResult.reject(this.rejectReason) : spec = null;

  final PlanAlarmSpec? spec;
  final PlanAlarmRejectReason? rejectReason;

  bool get isScheduled => spec != null;
}

/// 32-bit FNV-1a over UTF-16 code units, masked to a **positive 31-bit** int.
///
/// Stable across app restarts. [stableKey] must be occurrence-specific
/// (see [planAlarmOccurrenceKey]).
int planAlarmNotificationIdFromStableKey(String stableKey) {
  var hash = 0x811c9dc5;
  for (final u in stableKey.codeUnits) {
    hash = hash ^ u;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// Deterministic occurrence key for notification id hashing.
///
/// Virtual recurrence rows already embed the wall day (`virt-…-YYYY-MM-DD`).
/// Non-recurring plans append `|YYYY-MM-DD` so id stays occurrence-specific.
String planAlarmOccurrenceKey({
  required String stablePlanKey,
  required String wallDateKey,
}) {
  final sk = stablePlanKey.trim();
  final dk = wallDateKey.trim();
  if (sk.isEmpty) return '';
  if (sk.startsWith('virt-')) return sk;
  if (dk.length >= 10) return '$sk|${dk.substring(0, 10)}';
  return sk;
}

/// Builds one future plan reminder in **profile wall time** (UTC storage law).
///
/// Prefers [startUtcInstant] when present; otherwise converts profile-wall
/// [startWall] via [wall_clock.wallClockToUtcForLabel]. Never uses device-local.
PlanAlarmBuildResult tryBuildPlanAlarmSpec({
  required String stablePlanKey,
  required String wallDateKey,
  required DateTime? startWall,
  required DateTime? startUtcInstant,
  required int? reminderOffsetMinutes,
  required bool isDone,
  required bool isDeletedOrOptimistic,
  required DateTime nowUtc,
  required int profileOffsetHours,
  required String preferredTimezoneLabel,
  required String title,
}) {
  if (isDeletedOrOptimistic) {
    return const PlanAlarmBuildResult.reject(
      PlanAlarmRejectReason.deletedOrOptimistic,
    );
  }
  if (isDone) {
    return const PlanAlarmBuildResult.reject(PlanAlarmRejectReason.done);
  }
  final off = reminderOffsetMinutes;
  if (off == null || off < 0) {
    return const PlanAlarmBuildResult.reject(PlanAlarmRejectReason.noReminder);
  }

  final occurrenceKey = planAlarmOccurrenceKey(
    stablePlanKey: stablePlanKey,
    wallDateKey: wallDateKey,
  );
  if (occurrenceKey.isEmpty) {
    return const PlanAlarmBuildResult.reject(PlanAlarmRejectReason.invalidKey);
  }

  DateTime? startUtc;
  final instant = startUtcInstant;
  if (instant != null) {
    startUtc = instant.toUtc();
  } else if (startWall != null) {
    startUtc = wall_clock.wallClockToUtcForLabel(
      startWall,
      profileOffsetHours,
      preferredTimezoneLabel,
    );
  }
  if (startUtc == null) {
    return const PlanAlarmBuildResult.reject(PlanAlarmRejectReason.noStart);
  }

  final fireUtc = startUtc.subtract(Duration(minutes: off));
  final now = nowUtc.toUtc();
  if (!fireUtc.isAfter(now)) {
    return const PlanAlarmBuildResult.reject(PlanAlarmRejectReason.past);
  }

  final trimmed = title.trim();
  return PlanAlarmBuildResult.spec(
    PlanAlarmSpec(
      notificationId: planAlarmNotificationIdFromStableKey(occurrenceKey),
      occurrenceKey: occurrenceKey,
      fireUtc: fireUtc,
      title: trimmed.isEmpty ? 'Plan' : trimmed,
      reminderMinutes: off,
    ),
  );
}

/// Deduplicate by notification id (first / earliest wins after sort), cap limit.
List<PlanAlarmSpec> finalizePlanAlarmSpecs(
  List<PlanAlarmSpec> raw, {
  int limit = kPlanAlarmNotificationLimit,
}) {
  final sorted = List<PlanAlarmSpec>.from(raw)
    ..sort((a, b) => a.fireUtc.compareTo(b.fireUtc));
  final seen = <int>{};
  final out = <PlanAlarmSpec>[];
  for (final s in sorted) {
    if (!seen.add(s.notificationId)) continue;
    out.add(s);
    if (out.length >= limit) break;
  }
  return out;
}
