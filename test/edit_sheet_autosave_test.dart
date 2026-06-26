import 'package:counter/features/shared/shared_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EditSheetAutosaveGate', () {
    test('schedule debounces flush until timer fires', () async {
      final gate = EditSheetAutosaveGate(debounce: const Duration(milliseconds: 40));
      var runs = 0;
      gate.schedule(() => runs++);
      expect(runs, 0);
      expect(gate.isDirty, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 55));
      expect(runs, 1);
      gate.dispose();
    });

    test('flush runs immediately and clears dirty', () {
      final gate = EditSheetAutosaveGate();
      var runs = 0;
      gate.markDirty();
      gate.flush(() => runs++);
      expect(runs, 1);
      expect(gate.isDirty, isFalse);
      gate.dispose();
    });

    test('schedule coalesces rapid edits into one flush', () async {
      final gate = EditSheetAutosaveGate(debounce: const Duration(milliseconds: 50));
      var runs = 0;
      gate.schedule(() => runs++);
      gate.schedule(() => runs++);
      gate.schedule(() => runs++);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(runs, 1);
      gate.dispose();
    });

    test('flush cancels pending debounced schedule', () async {
      final gate = EditSheetAutosaveGate(debounce: const Duration(milliseconds: 80));
      var runs = 0;
      gate.schedule(() => runs++);
      gate.flush(() => runs++);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(runs, 1);
      gate.dispose();
    });

    test('markClean prevents redundant flush', () {
      final gate = EditSheetAutosaveGate();
      var runs = 0;
      gate.markDirty();
      gate.markClean();
      gate.flush(() => runs++);
      expect(runs, 0);
      gate.dispose();
    });
  });
}
