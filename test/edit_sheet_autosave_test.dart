import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/features/shared/edit_sheet/record_edit_save_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EditSheetAutosaveGate', () {
    test('schedule debounces flush until timer fires', () async {
      final gate = EditSheetAutosaveGate(
        debounce: const Duration(milliseconds: 40),
      );
      var runs = 0;
      gate.schedule(() => runs++);
      expect(runs, 0);
      expect(gate.isDirty, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 55));
      expect(runs, 1);
      expect(gate.isDirty, isFalse);
      gate.dispose();
    });

    test('flush runs immediately when dirty and clears dirty', () {
      final gate = EditSheetAutosaveGate();
      var runs = 0;
      gate.markDirty();
      gate.flush(() => runs++);
      expect(runs, 1);
      expect(gate.isDirty, isFalse);
      gate.dispose();
    });

    test('force flush runs even when clean (explicit Save)', () {
      final gate = EditSheetAutosaveGate();
      var runs = 0;
      gate.markClean();
      gate.flush(() => runs++, force: true);
      expect(runs, 1);
      expect(gate.isDirty, isFalse);
      gate.dispose();
    });

    test('non-force flush skips when clean', () {
      final gate = EditSheetAutosaveGate();
      var runs = 0;
      gate.markClean();
      gate.flush(() => runs++);
      expect(runs, 0);
      gate.dispose();
    });

    test('schedule coalesces rapid edits into one flush', () async {
      final gate = EditSheetAutosaveGate(
        debounce: const Duration(milliseconds: 50),
      );
      var runs = 0;
      gate.schedule(() => runs++);
      gate.schedule(() => runs++);
      gate.schedule(() => runs++);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(runs, 1);
      expect(gate.isDirty, isFalse);
      gate.dispose();
    });

    test('a new edit stays dirty after an earlier dispatch', () async {
      final gate = EditSheetAutosaveGate(
        debounce: const Duration(milliseconds: 35),
      );
      var runs = 0;
      gate.schedule(() => runs++);
      await Future<void>.delayed(const Duration(milliseconds: 45));
      expect(runs, 1);
      expect(gate.isDirty, isFalse);

      gate.schedule(() => runs++);
      expect(gate.isDirty, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 45));
      expect(runs, 2);
      expect(gate.isDirty, isFalse);
      gate.dispose();
    });

    test('flush cancels pending debounced schedule', () async {
      final gate = EditSheetAutosaveGate(
        debounce: const Duration(milliseconds: 80),
      );
      var runs = 0;
      gate.schedule(() => runs++);
      gate.flush(() => runs++, force: true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(runs, 1);
      gate.dispose();
    });

    test('flush with force supersedes pending debounced callback', () async {
      final gate = EditSheetAutosaveGate(
        debounce: const Duration(milliseconds: 80),
      );
      var scheduledRuns = 0;
      var flushRuns = 0;
      gate.schedule(() => scheduledRuns++);
      gate.flush(() => flushRuns++, force: true);
      expect(flushRuns, 1);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(scheduledRuns, 0);
      gate.dispose();
    });
  });

  group('Embedded record Notes autosave time safety', () {
    DateTime sameUtc(DateTime value) => value.toUtc();

    final start = DateTime.utc(2026, 11, 14, 10, 26);
    final end = DateTime.utc(2026, 11, 14, 10, 27);

    test('unchanged running record does not reassert running status', () {
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

    test('unchanged stopped interval is not patched during notes edit', () {
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

    test('edited stopped interval writes both endpoints', () {
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

    test('invalid stopped interval is never autosaved', () {
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
  });
}
