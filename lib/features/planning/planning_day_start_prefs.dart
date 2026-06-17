import 'package:shared_preferences/shared_preferences.dart';

/// Local-only start/end clock hours for the Planning time grid (0–23 inclusive).
/// Not synced to NocoDB.
class PlanningSheetTimelinePrefs {
  PlanningSheetTimelinePrefs._();

  static const String _keyStart = 'planning_day_start_hour';
  static const String _keyEnd = 'planning_day_end_hour';

  static int clampHour(int? v) {
    if (v == null) return 0;
    if (v < 0) return 0;
    if (v > 23) return 23;
    return v;
  }

  static Future<int> loadStart() async {
    final p = await SharedPreferences.getInstance();
    // Legacy: value may have been stored when range was 0–12; still valid 0–23.
    return clampHour(p.getInt(_keyStart));
  }

  /// Defaults to end of day when missing (migration from start-only prefs).
  static Future<int> loadEnd() async {
    final p = await SharedPreferences.getInstance();
    if (!p.containsKey(_keyEnd)) return 23;
    return clampHour(p.getInt(_keyEnd));
  }

  static Future<void> saveStart(int hour) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyStart, clampHour(hour));
  }

  static Future<void> saveEnd(int hour) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyEnd, clampHour(hour));
  }

  static Future<void> saveStartEnd(int start, int end) async {
    await saveStart(start);
    await saveEnd(end);
  }

  /// Inclusive wall-clock hour rows for the grid. If [start] <= [end], range is
  /// that contiguous block; if [start] > [end], range spans midnight (overnight).
  static List<int> visibleHoursOrdered(int start, int end) {
    final s = clampHour(start);
    final e = clampHour(end);
    if (s <= e) {
      return List<int>.generate(e - s + 1, (i) => s + i);
    }
    return <int>[
      ...List<int>.generate(24 - s, (i) => s + i),
      ...List<int>.generate(e + 1, (i) => i),
    ];
  }

  /// Default vertical drag snap for Planning Time timeline (minutes).
  static const int timelineSnapMinutes = 5;

  /// Minimum scheduled block duration when resizing (minutes).
  static const int timelineMinDurationMinutes = 5;
}
