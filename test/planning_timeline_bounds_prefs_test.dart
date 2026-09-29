import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('old 23:00 timeline end migrates once to 03:00 next day', () async {
    SharedPreferences.setMockInitialValues({
      'visibleDayStartHourExtended': 7,
      'visibleDayEndHourExtended': 23,
    });

    final range = await PlanningSheetTimelinePrefs.loadVisibleDayRange();
    expect(range.start, 7);
    expect(range.end, 27);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('visibleDayEndHourExtended'), 27);
  });

  test(
    'explicit 23:00 end is preserved after migration marker exists',
    () async {
      SharedPreferences.setMockInitialValues({
        'visibleDayStartHourExtended': 7,
        'visibleDayEndHourExtended': 23,
        'visible_day_end_27_v1_migrated': true,
      });

      final range = await PlanningSheetTimelinePrefs.loadVisibleDayRange();
      expect(range.start, 7);
      expect(range.end, 23);
    },
  );
}
