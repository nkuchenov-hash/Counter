import 'package:counter/core/services/desktop_voice_confirmation_timer.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice_command_parser.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the widget's pending-confirmation commit gate (timer → writeRecord).
class _PendingCommitSimulator {
  _PendingCommitSimulator();

  final timer = DesktopVoiceConfirmationTimer();
  int writeRecordCalls = 0;
  DateTime? lastExplicitStart;
  bool correctionOpen = false;
  bool sessionCancelled = false;

  void enterPending() {
    timer.onComplete = () {
      if (correctionOpen || sessionCancelled) return;
      commit();
    };
    timer.start();
  }

  void commit() {
    final captured = timer.intendedStartTime;
    timer.cancel();
    writeRecordCalls++;
    lastExplicitStart = captured;
  }

  void openCorrection() {
    correctionOpen = true;
    timer.pause();
  }

  void closeCorrectionCancelled() {
    correctionOpen = false;
    sessionCancelled = true;
    timer.cancel();
  }

  void confirmNowFromCorrection() {
    correctionOpen = false;
    commit();
  }
}

CategoryRule _planningTree() {
  return CategoryRule(
    id: 100,
    name: 'Price Reporter',
    backendRowId: 'prroot123456789',
    children: [
      CategoryRule(
        id: 102,
        name: 'Planning',
        backendRowId: 'planningcat1234',
      ),
    ],
  );
}

void main() {
  group('DesktopVoiceConfirmationTimer', () {
    test('captures intendedStartTime at start', () {
      fakeAsync((async) {
        final timer = DesktopVoiceConfirmationTimer();
        timer.start();
        expect(timer.intendedStartTime, isNotNull);
      });
    });

    test('does not complete before 3 seconds', () {
      fakeAsync((async) {
        final timer = DesktopVoiceConfirmationTimer();
        var completed = false;
        timer.onComplete = () => completed = true;
        timer.start();
        async.elapse(const Duration(seconds: 2, milliseconds: 900));
        expect(completed, isFalse);
        expect(timer.progress, lessThan(1.0));
      });
    });

    test('auto-completes after 3 seconds with progress reaching 1', () {
      fakeAsync((async) {
        final timer = DesktopVoiceConfirmationTimer();
        final progressSamples = <double>[];
        var completed = false;
        timer.onProgress = progressSamples.add;
        timer.onComplete = () => completed = true;
        timer.start();
        async.elapse(const Duration(seconds: 3, milliseconds: 50));
        expect(completed, isTrue);
        expect(progressSamples.isNotEmpty, isTrue);
        expect(progressSamples.last, 1.0);
      });
    });

    test('pause stops progress until resumed', () {
      fakeAsync((async) {
        final timer = DesktopVoiceConfirmationTimer();
        var completed = false;
        timer.onComplete = () => completed = true;
        timer.start();
        async.elapse(const Duration(seconds: 1));
        timer.pause();
        async.elapse(const Duration(seconds: 5));
        expect(completed, isFalse);
        timer.resume();
        async.elapse(const Duration(seconds: 2, milliseconds: 50));
        expect(completed, isTrue);
      });
    });

    test('cancel prevents completion', () {
      fakeAsync((async) {
        final timer = DesktopVoiceConfirmationTimer();
        var completed = false;
        timer.onComplete = () => completed = true;
        timer.start();
        timer.cancel();
        async.elapse(const Duration(seconds: 5));
        expect(completed, isFalse);
      });
    });

    test('confirmNow completes immediately', () {
      fakeAsync((async) {
        final timer = DesktopVoiceConfirmationTimer();
        var completed = false;
        timer.onComplete = () => completed = true;
        timer.start();
        async.elapse(const Duration(milliseconds: 200));
        timer.confirmNow();
        expect(completed, isTrue);
        async.elapse(const Duration(seconds: 5));
        expect(completed, isTrue);
      });
    });
  });

  group('Pending confirmation commit gate', () {
    test('writeRecord is not called before timer completes', () {
      fakeAsync((async) {
        final sim = _PendingCommitSimulator();
        sim.enterPending();
        async.elapse(const Duration(seconds: 2, milliseconds: 900));
        expect(sim.writeRecordCalls, 0);
      });
    });

    test('writeRecord is called after timer completes', () {
      fakeAsync((async) {
        final sim = _PendingCommitSimulator();
        sim.enterPending();
        async.elapse(const Duration(seconds: 3, milliseconds: 50));
        expect(sim.writeRecordCalls, 1);
        expect(sim.lastExplicitStart, isNotNull);
      });
    });

    test('click-to-correct pauses timer — no writeRecord until confirm', () {
      fakeAsync((async) {
        final sim = _PendingCommitSimulator();
        sim.enterPending();
        async.elapse(const Duration(seconds: 1));
        sim.openCorrection();
        async.elapse(const Duration(seconds: 5));
        expect(sim.writeRecordCalls, 0);
      });
    });

    test('cancel during correction prevents writeRecord', () {
      fakeAsync((async) {
        final sim = _PendingCommitSimulator();
        sim.enterPending();
        sim.openCorrection();
        sim.closeCorrectionCancelled();
        async.elapse(const Duration(seconds: 5));
        expect(sim.writeRecordCalls, 0);
      });
    });

    test('confirm now from correction commits immediately with captured start', () {
      fakeAsync((async) {
        final sim = _PendingCommitSimulator();
        sim.enterPending();
        final expectedStart = sim.timer.intendedStartTime;
        async.elapse(const Duration(milliseconds: 500));
        sim.confirmNowFromCorrection();
        expect(sim.writeRecordCalls, 1);
        expect(sim.lastExplicitStart, expectedStart);
      });
    });

    test('accepted command produces pending confirmation message', () {
      final parsed = parseVoiceCommand(
        rules: [_planningTree()],
        transcript: 'Price Reporter Planning',
      );
      expect(parsed.isSafeToStart, isTrue);
      expect(
        voiceCommandPendingConfirmationMessage(parsed, localeCode: 'ru'),
        'Запустить\nPrice Reporter\nPlanning',
      );
      expect(
        voiceCommandPendingConfirmationMessage(parsed, localeCode: 'en'),
        'Start\nPrice Reporter\nPlanning',
      );
    });
  });
}
