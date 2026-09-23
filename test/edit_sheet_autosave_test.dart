import 'package:counter/features/shared/shared_widgets.dart';
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

    test('older save completion cannot cancel a newer rename', () async {
      final gate = EditSheetAutosaveGate(
        debounce: const Duration(milliseconds: 40),
      );
      var oldSaveRuns = 0;
      var newRenameRuns = 0;

      gate.schedule(() => oldSaveRuns++);
      await Future<void>.delayed(const Duration(milliseconds: 55));
      expect(oldSaveRuns, 1);

      // A second edit is now waiting for its debounce window while the first
      // request is conceptually still in flight.
      gate.schedule(() => newRenameRuns++);
      expect(gate.isDirty, isTrue);

      // Simulate the older request completing after the new local rename.
      gate.markClean();
      expect(
        gate.isDirty,
        isTrue,
        reason: 'older save completion must not clear newer unsent user intent',
      );

      await Future<void>.delayed(const Duration(milliseconds: 55));
      expect(
        newRenameRuns,
        1,
        reason: 'newer rename must still be sent without another user action',
      );
      gate.dispose();
    });
  });
}
