import 'package:counter/data/records/unfilled_time_gap_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds internal and trailing gaps without a leading gap', () {
    final gaps = findUnfilledTimeGaps(
      records: <Map<String, dynamic>>[
        <String, dynamic>{
          'start_time': DateTime.utc(2026, 7, 27, 7).toIso8601String(),
          'end_time': DateTime.utc(2026, 7, 27, 8).toIso8601String(),
        },
        <String, dynamic>{
          'start_time': DateTime.utc(2026, 7, 27, 8, 30).toIso8601String(),
          'end_time': DateTime.utc(2026, 7, 27, 9).toIso8601String(),
        },
      ],
      windowStartUtc: DateTime.utc(2026, 7, 27, 6),
      windowEndUtc: DateTime.utc(2026, 7, 27, 10),
      minimumDuration: const Duration(minutes: 10),
    );

    expect(gaps, hasLength(2));
    expect(gaps[0].startUtc, DateTime.utc(2026, 7, 27, 8));
    expect(gaps[0].endUtc, DateTime.utc(2026, 7, 27, 8, 30));
    expect(gaps[1].startUtc, DateTime.utc(2026, 7, 27, 9));
    expect(gaps[1].endUtc, DateTime.utc(2026, 7, 27, 10));
  });

  test('merges overlaps and treats an open record as covering until now', () {
    final gaps = findUnfilledTimeGaps(
      records: <Map<String, dynamic>>[
        <String, dynamic>{
          'start_time': DateTime.utc(2026, 7, 27, 7).toIso8601String(),
          'end_time': DateTime.utc(2026, 7, 27, 8).toIso8601String(),
        },
        <String, dynamic>{
          'start_time': DateTime.utc(2026, 7, 27, 7, 30).toIso8601String(),
          'end_time': DateTime.utc(2026, 7, 27, 9).toIso8601String(),
        },
        <String, dynamic>{
          'start_time': DateTime.utc(2026, 7, 27, 9, 30).toIso8601String(),
          'end_time': null,
        },
      ],
      windowStartUtc: DateTime.utc(2026, 7, 27, 6),
      windowEndUtc: DateTime.utc(2026, 7, 27, 10),
      minimumDuration: const Duration(minutes: 10),
    );

    expect(gaps, hasLength(1));
    expect(gaps.single.startUtc, DateTime.utc(2026, 7, 27, 9));
    expect(gaps.single.endUtc, DateTime.utc(2026, 7, 27, 9, 30));
  });
}
