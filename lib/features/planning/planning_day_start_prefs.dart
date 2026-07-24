import 'package:counter/shared/time/plan_time_visible_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only visible day window for the Planning Time View (-3..27 extended hours).
/// Not synced to PocketBase.
class PlanningSheetTimelinePrefs {
  PlanningSheetTimelinePrefs._();

  static const String _keyStartExtended = 'visibleDayStartHourExtended';
  static const String _keyEndExtended = 'visibleDayEndHourExtended';
  static const String _legacyKeyStart = 'planning_day_start_hour';
  static const String _legacyKeyEnd = 'planning_day_end_hour';

  static const int extendedMin = PlanTimeVisibleWindow.extendedMin;
  static const int extendedMax = PlanTimeVisibleWindow.extendedMax;
  static const int defaultStartExtended = PlanTimeVisibleWindow.defaultStartExtended;
  static const int defaultEndExtended = PlanTimeVisibleWindow.defaultEndExtended;
  static const int rangeSliderDivisions = 30;

  /// Shared drag and resize snap for Planning Time timeline (minutes).
  static const int timelineSnapMinutes = 5;

  /// Minimum scheduled block duration when resizing (minutes).
  static const int timelineMinDurationMinutes = 10;

  static int clampStartExtended(int? value) =>
      PlanTimeVisibleWindow.clampStartExtended(value);

  static int clampEndExtended(int? value, int startExtended) =>
      PlanTimeVisibleWindow.clampEndExtended(value, startExtended);

  static ({int start, int end}) normalizeExtendedRange(int start, int end) =>
      PlanTimeVisibleWindow.normalizeExtendedRange(start, end);

  static ({int start, int end}) migrateLegacyRange({
    int? legacyStart,
    int? legacyEnd,
  }) =>
      PlanTimeVisibleWindow.migrateLegacyRange(
        legacyStart: legacyStart,
        legacyEnd: legacyEnd,
      );

  static Future<({int start, int end})> loadVisibleDayRange() async {
    final p = await SharedPreferences.getInstance();
    if (p.containsKey(_keyStartExtended) && p.containsKey(_keyEndExtended)) {
      return normalizeExtendedRange(
        p.getInt(_keyStartExtended) ?? defaultStartExtended,
        p.getInt(_keyEndExtended) ?? defaultEndExtended,
      );
    }
    return migrateLegacyRange(
      legacyStart: p.getInt(_legacyKeyStart),
      legacyEnd: p.containsKey(_legacyKeyEnd) ? p.getInt(_legacyKeyEnd) : null,
    );
  }

  static Future<void> saveVisibleDayRange(int start, int end) async {
    final range = normalizeExtendedRange(start, end);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyStartExtended, range.start);
    await p.setInt(_keyEndExtended, range.end);
    await p.setInt(_legacyKeyStart, range.start.clamp(0, 23));
    await p.setInt(
      _legacyKeyEnd,
      range.end > 23 ? range.end - 24 : range.end.clamp(0, 23),
    );
  }

  @Deprecated('Use loadVisibleDayRange')
  static Future<int> loadStart() async {
    final range = await loadVisibleDayRange();
    return range.start;
  }

  @Deprecated('Use loadVisibleDayRange')
  static Future<int> loadEnd() async {
    final range = await loadVisibleDayRange();
    return range.end;
  }

  @Deprecated('Use saveVisibleDayRange')
  static Future<void> saveStartEnd(int start, int end) async {
    await saveVisibleDayRange(start, end);
  }

  static List<int> visibleExtendedHoursOrdered(int startExtended, int endExtended) =>
      PlanTimeVisibleWindow.visibleExtendedHoursOrdered(startExtended, endExtended);

  @Deprecated('Use visibleExtendedHoursOrdered')
  static List<int> visibleHoursOrdered(int start, int end) =>
      visibleExtendedHoursOrdered(start, end);

  static int visibleDurationHours(int startExtended, int endExtended) =>
      PlanTimeVisibleWindow.visibleDurationHours(startExtended, endExtended);

  static DateTime windowStartWall(DateTime day, int startExtended) =>
      PlanTimeVisibleWindow.windowStartWall(day, startExtended);

  static DateTime windowEndWall(DateTime day, int endExtended) =>
      PlanTimeVisibleWindow.windowEndWall(day, endExtended);

  static int displayHourMod24(int extendedHour) =>
      PlanTimeVisibleWindow.displayHourMod24(extendedHour);

  static String formatExtendedHourClock(int extendedHour) =>
      PlanTimeVisibleWindow.formatExtendedHourClock(extendedHour);

  static double minutesFromWindowStart(
    DateTime wall,
    DateTime day,
    int startExtended,
  ) =>
      PlanTimeVisibleWindow.minutesFromWindowStart(wall, day, startExtended);

  static DateTime wallFromWindowMinutes(
    DateTime day,
    int startExtended,
    double minutesFromWindowStart,
  ) =>
      PlanTimeVisibleWindow.wallFromWindowMinutes(
        day,
        startExtended,
        minutesFromWindowStart,
      );

  static bool wallInstantInsideVisibleWindow(
    DateTime wall,
    DateTime day,
    int startExtended,
    int endExtended,
  ) =>
      PlanTimeVisibleWindow.wallInstantInsideVisibleWindow(
        wall,
        day,
        startExtended,
        endExtended,
      );

  static bool projectedPlanOverlapsVisibleWindow({
    required DateTime wallStart,
    required DateTime? wallEnd,
    required int durationMinutes,
    required DateTime selectedDay,
    required int startExtended,
    required int endExtended,
  }) =>
      PlanTimeVisibleWindow.projectedPlanOverlapsVisibleWindow(
        wallStart: wallStart,
        wallEnd: wallEnd,
        durationMinutes: durationMinutes,
        selectedDay: selectedDay,
        startExtended: startExtended,
        endExtended: endExtended,
      );

  static bool needsNextDayTasks(int endExtended) =>
      PlanTimeVisibleWindow.needsNextDayTasks(endExtended);

  static bool needsPreviousDayTasks(int startExtended) =>
      PlanTimeVisibleWindow.needsPreviousDayTasks(startExtended);
}
