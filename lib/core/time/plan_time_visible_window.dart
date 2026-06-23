/// Pure extended-hour visible window math for Planning Time View.
abstract final class PlanTimeVisibleWindow {
  static const int extendedMin = -3;
  static const int extendedMax = 27;
  static const int defaultStartExtended = 7;
  static const int defaultEndExtended = 23;

  static int clampStartExtended(int? value) {
    if (value == null) return defaultStartExtended;
    if (value < extendedMin) return extendedMin;
    if (value > 23) return 23;
    return value;
  }

  static int clampEndExtended(int? value, int startExtended) {
    final start = clampStartExtended(startExtended);
    final minEnd = start + 1;
    var end = value ?? defaultEndExtended;
    if (end < minEnd) end = minEnd;
    if (end > extendedMax) end = extendedMax;
    return end;
  }

  static ({int start, int end}) normalizeExtendedRange(int start, int end) {
    final s = clampStartExtended(start);
    final e = clampEndExtended(end, s);
    return (start: s, end: e);
  }

  static ({int start, int end}) migrateLegacyRange({
    int? legacyStart,
    int? legacyEnd,
  }) {
    final s = (legacyStart ?? defaultStartExtended).clamp(0, 23);
    final e = (legacyEnd ?? defaultEndExtended).clamp(0, 23);
    if (s <= e) {
      return normalizeExtendedRange(s, e);
    }
    return normalizeExtendedRange(s, e + 24);
  }

  static List<int> visibleExtendedHoursOrdered(int startExtended, int endExtended) {
    final range = normalizeExtendedRange(startExtended, endExtended);
    return List<int>.generate(range.end - range.start, (i) => range.start + i);
  }

  static int visibleDurationHours(int startExtended, int endExtended) {
    final range = normalizeExtendedRange(startExtended, endExtended);
    return range.end - range.start;
  }

  static DateTime dayMidnight(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  static DateTime windowStartWall(DateTime day, int startExtended) =>
      dayMidnight(day).add(Duration(hours: clampStartExtended(startExtended)));

  static DateTime windowEndWall(DateTime day, int endExtended) {
    final e = endExtended.clamp(extendedMin + 1, extendedMax);
    return dayMidnight(day).add(Duration(hours: e));
  }

  static int displayHourMod24(int extendedHour) =>
      ((extendedHour % 24) + 24) % 24;

  static String formatExtendedHourClock(int extendedHour) {
    final h = displayHourMod24(extendedHour);
    return '${h.toString().padLeft(2, '0')}:00';
  }

  static double minutesFromWindowStart(
    DateTime wall,
    DateTime day,
    int startExtended,
  ) {
    return wall
        .difference(windowStartWall(day, startExtended))
        .inMinutes
        .toDouble();
  }

  static DateTime wallFromWindowMinutes(
    DateTime day,
    int startExtended,
    double minutesFromWindowStart,
  ) {
    return windowStartWall(day, startExtended).add(
      Duration(minutes: minutesFromWindowStart.round()),
    );
  }

  static bool wallInstantInsideVisibleWindow(
    DateTime wall,
    DateTime day,
    int startExtended,
    int endExtended,
  ) {
    final range = normalizeExtendedRange(startExtended, endExtended);
    final start = windowStartWall(day, range.start);
    final end = windowEndWall(day, range.end);
    return !wall.isBefore(start) && wall.isBefore(end);
  }

  static bool projectedPlanOverlapsVisibleWindow({
    required DateTime wallStart,
    required DateTime? wallEnd,
    required int durationMinutes,
    required DateTime selectedDay,
    required int startExtended,
    required int endExtended,
  }) {
    final range = normalizeExtendedRange(startExtended, endExtended);
    final windowStart = windowStartWall(selectedDay, range.start);
    final windowEnd = windowEndWall(selectedDay, range.end);
    final taskEnd = wallEnd ??
        wallStart.add(Duration(minutes: durationMinutes.clamp(1, 24 * 60)));
    return wallStart.isBefore(windowEnd) && taskEnd.isAfter(windowStart);
  }

  static bool needsNextDayTasks(int endExtended) =>
      clampEndExtended(endExtended, defaultStartExtended) > 24;

  static bool needsPreviousDayTasks(int startExtended) =>
      clampStartExtended(startExtended) < 0;
}
