import 'package:counter/features/shared/edit_sheet/record_edit_save_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime sameUtc(DateTime value) => value.toUtc();

  final start = DateTime.utc(2026, 11, 14, 10, 26);
  final end = DateTime.utc(2026, 11, 14, 10, 27);

  test('notes autosave does not reassert running on an unchanged start', () {
    final patch = buildRecordAutosaveTimePatch(
      recordIsRunning: true,
      draftStartDisplay: start,
      draftEndDisplay: null,
      originalStartTimeUtc: start,
      displayToUtc: sameUtc,
    );
    expect(patch.startUtc, isNull);
    expect(patch.endUtc, isNull);
  });

  test('notes autosave does not rewrite an unchanged stopped interval', () {
    final patch = buildRecordAutosaveTimePatch(
      recordIsRunning: false,
      draftStartDisplay: start,
      draftEndDisplay: end,
      originalStartTimeUtc: start,
      originalEndTimeUtc: end,
      displayToUtc: sameUtc,
    );
    expect(patch.startUtc, isNull);
    expect(patch.endUtc, isNull);
  });

  test('changing a stopped interval always sends both endpoints', () {
    final changedEnd = end.add(const Duration(minutes: 10));
    final patch = buildRecordAutosaveTimePatch(
      recordIsRunning: false,
      draftStartDisplay: start,
      draftEndDisplay: changedEnd,
      originalStartTimeUtc: start,
      originalEndTimeUtc: end,
      displayToUtc: sameUtc,
    );
    expect(patch.startUtc, start);
    expect(patch.endUtc, changedEnd);
  });

  test('invalid stopped interval cannot be written by notes autosave', () {
    final patch = buildRecordAutosaveTimePatch(
      recordIsRunning: false,
      draftStartDisplay: end,
      draftEndDisplay: start,
      originalStartTimeUtc: start,
      originalEndTimeUtc: end,
      displayToUtc: sameUtc,
    );
    expect(patch.startUtc, isNull);
    expect(patch.endUtc, isNull);
  });

  test('changed running start is still persisted', () {
    final newStart = start.add(const Duration(minutes: 1));
    final patch = buildRecordAutosaveTimePatch(
      recordIsRunning: true,
      draftStartDisplay: newStart,
      draftEndDisplay: null,
      originalStartTimeUtc: start,
      displayToUtc: sameUtc,
    );
    expect(patch.startUtc, newStart);
    expect(patch.endUtc, isNull);
  });
}
