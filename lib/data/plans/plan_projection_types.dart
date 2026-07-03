part of '../database_service.dart';

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
