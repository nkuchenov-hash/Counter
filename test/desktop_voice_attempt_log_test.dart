// In-app Desktop Voice diagnostics — attempt log lifecycle + plain-text copy.
// Exercises the same `DesktopVoiceAttemptLog` API the live widget updates.

import 'package:counter/core/services/desktop_voice_attempt_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DesktopVoiceAttemptLog log;

  setUp(() {
    log = DesktopVoiceAttemptLog.instance;
    // Reset to no attempt.
    log.begin();
  });

  tearDown(() {
    log.begin(); // leave a fresh state so the next test starts clean
  });

  group('DesktopVoiceAttemptLog lifecycle', () {
    test('begin() seeds an in-progress attempt with hotkeyReceived=true', () {
      final a = log.current!;
      expect(a.status, DesktopVoiceAttemptStatus.inProgress);
      expect(a.hotkeyReceived, isTrue);
      expect(a.recordingStarted, isFalse);
      expect(a.micInputDetected, isFalse);
      expect(a.transcript, '');
      expect(a.writeRecordResult, 'not called');
    });

    test('markRecordingStarted(true) keeps inProgress, (false) -> micError', () {
      log.markRecordingStarted(true);
      expect(log.current!.recordingStarted, isTrue);
      expect(log.current!.status, DesktopVoiceAttemptStatus.inProgress);

      log.begin();
      log.markRecordingStarted(false, error: 'Microphone permission denied');
      expect(log.current!.recordingStarted, isFalse);
      expect(log.current!.status, DesktopVoiceAttemptStatus.micError);
      expect(log.current!.statusDetail, contains('Microphone permission'));
    });

    test('markMicHeard + recordTranscript + recordParser reflect intermediate state', () {
      log.markRecordingStarted(true);
      log.markMicHeard();
      log.recordTranscript('Laredo TS scene');
      log.recordParser(
        confidence: 'exact',
        matchedScope: 'Laredo Technical Services > Laredo TS',
        taskTitle: 'SIN',
      );
      final a = log.current!;
      expect(a.micInputDetected, isTrue);
      expect(a.transcript, 'Laredo TS scene');
      expect(a.parserConfidence, 'exact');
      expect(a.matchedScope, 'Laredo Technical Services > Laredo TS');
      expect(a.taskTitle, 'SIN');
      expect(a.writeRecordResult, 'not called');
    });

    test('markSubmission(ok) -> taskCreated + confirmation status detail', () {
      log.markRecordingStarted(true);
      log.recordTranscript('Price Reporter Planning');
      log.recordParser(
        confidence: 'exact',
        matchedScope: 'Price Reporter',
        taskTitle: 'Planning',
      );
      log.markSubmission(serverId: 'pbrec0000000001');
      final a = log.current!;
      expect(a.writeRecordResult, 'ok');
      expect(a.status, DesktopVoiceAttemptStatus.taskCreated);
      expect(a.statusDetail, contains('Price Reporter'));
      expect(a.statusDetail, contains('Planning'));
    });

    test('markSubmission(null) -> saveError with friendly detail', () {
      log.markSubmission(serverId: null, error: 'network down');
      final a = log.current!;
      expect(a.writeRecordResult, 'failed');
      expect(a.status, DesktopVoiceAttemptStatus.saveError);
      expect(a.statusDetail, contains('network down'));
    });

    test('markSttError -> sttError with friendly detail', () {
      log.markSttError('Recognizer is unavailable');
      expect(log.current!.status, DesktopVoiceAttemptStatus.sttError);
      expect(log.current!.statusDetail, contains('Recognizer is unavailable'));
    });

    test('markNotRecognized after a transcript includes the heard text', () {
      log.recordTranscript('Laredo Technical Services and Sim.');
      log.markNotRecognized();
      final a = log.current!;
      expect(a.status, DesktopVoiceAttemptStatus.notRecognized);
      expect(a.statusDetail, contains('Laredo Technical Services and Sim.'));
      expect(a.statusDetail.toLowerCase(), contains('could not match'));
    });

    test('markCancelled only applies when in progress', () {
      log.recordTranscript('something');
      log.markCancelled();
      expect(log.current!.status, DesktopVoiceAttemptStatus.cancelled);

      // A subsequent successful submission is treated as a NEW state — the
      // registry is single-attempt, so once writeRecord succeeds the status
      // reflects that success (not the prior cancellation).
      log.markSubmission(serverId: 'id1');
      expect(log.current!.status, DesktopVoiceAttemptStatus.taskCreated);
    });

    test('markCancelled leaves the status detail unchanged on terminal states',
        () {
      // Force a terminal saveError, then try to cancel: nothing should change.
      log.markSubmission(serverId: null, error: 'network down');
      final before = log.current!.status;
      final detailBefore = log.current!.statusDetail;
      log.markCancelled();
      expect(log.current!.status, before);
      expect(log.current!.statusDetail, detailBefore);
    });
  });

  group('toPlainText — clipboard-safe copy', () {
    test('full happy-path attempt renders all expected labels', () {
      log.begin();
      log.markRecordingStarted(true);
      log.markMicHeard();
      log.recordTranscript('Laredo TS scene');
      log.recordParser(
        confidence: 'exact',
        matchedScope: 'Laredo Technical Services > Laredo TS',
        taskTitle: 'SIN',
      );
      log.markSubmission(serverId: 'pblaredo000001');

      final text = log.current!.toPlainText();
      expect(text, contains('Hotkey received: yes'));
      expect(text, contains('Recording started: yes'));
      expect(text, contains('Microphone input detected: yes'));
      expect(text, contains('Heard: "Laredo TS scene"'));
      expect(text, contains('Parser: exact'));
      expect(text, contains('Matched scope: Laredo Technical Services > Laredo TS'));
      expect(text, contains('Task title: SIN'));
      expect(text, contains('Save result: ok'));
      expect(text, contains('Final: task created'));
    });

    test('does not leak PocketBase IDs or internal codes', () {
      log.markSubmission(serverId: 'secretid0123456');
      final text = log.current!.toPlainText();
      expect(text, isNot(contains('secretid0123456')));
      // Save result should be 'ok' not the raw id.
      expect(text, contains('Save result: ok'));
    });
  });
}
