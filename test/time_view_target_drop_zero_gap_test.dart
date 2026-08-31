import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('target-card drop after is exactly adjacent in scheduled time', () {
    final targetStart = DateTime(2026, 7, 6, 10, 0);
    final targetEnd = DateTime(2026, 7, 6, 10, 30);
    final result = computeTimeViewTargetDropSchedule(
      targetStartWall: targetStart,
      targetEndWall: targetEnd,
      draggedDurationMinutes: 45,
      insertBefore: false,
      draggedHadEnd: true,
    );

    expect(result.startWall, targetEnd);
    expect(result.endWall, DateTime(2026, 7, 6, 11, 15));
  });
}
