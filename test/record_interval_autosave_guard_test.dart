import 'package:counter/features/shared/edit_sheet/record_edit_save_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime identity(DateTime value) => value;

  test(
    'stopped autosave drops reversed one-day interval instead of persisting it',
    () {
      final patch = buildRecordAutosaveTimePatch(
        recordIsRunning: false,
        draftStartDisplay: DateTime.utc(2026, 9, 24, 0, 26),
        draftEndDisplay: DateTime.utc(2026, 9, 23, 3, 11),
        displayToUtc: identity,
      );

      expect(patch.startUtc, isNull);
      expect(patch.endUtc, isNull);
    },
  );

  test('valid cross-midnight stopped interval autosaves both endpoints', () {
    final start = DateTime.utc(2026, 9, 23, 23, 30);
    final end = DateTime.utc(2026, 9, 24, 0, 30);
    final patch = buildRecordAutosaveTimePatch(
      recordIsRunning: false,
      draftStartDisplay: start,
      draftEndDisplay: end,
      displayToUtc: identity,
    );

    expect(patch.startUtc, start);
    expect(patch.endUtc, end);
  });

  test('running autosave may patch start but never manufactures an end', () {
    final start = DateTime.utc(2026, 9, 24, 0, 26);
    final patch = buildRecordAutosaveTimePatch(
      recordIsRunning: true,
      draftStartDisplay: start,
      draftEndDisplay: DateTime.utc(2026, 9, 23, 3, 11),
      displayToUtc: identity,
    );

    expect(patch.startUtc, start);
    expect(patch.endUtc, isNull);
  });
}
