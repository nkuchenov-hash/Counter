import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Time View uses five-minute drag and resize snap', () {
    expect(PlanningSheetTimelinePrefs.timelineSnapMinutes, 5);
    expect(PlanningSheetTimelinePrefs.timelineMinDurationMinutes, 10);
  });
}
