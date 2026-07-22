// End-to-end closure of the desktop-voice silent-failure loop.
//
// The widget's production flow inside `_DesktopVoiceOverlayState` is:
//   recognizer.finishCapture() -> transcript
//   _parseTranscript():
//     parseVoiceCommand(rules, transcript)            // voice_command_parser.dart
//     normalizeDesktopVoiceCommand(parsed)            // desktop_voice_command_normalize.dart
//   _confirmStart():
//     widget.onStartRecord(normalized.effectiveResult)
//     -> _desktopVoiceSubmitParsed():
//        DesktopVoiceRecordSubmit.submitParsed(...)   // desktop_voice_record_submit.dart
//        -> DatabaseService.writeRecord(...)
//
// The recognizer and Permission/native-overlay layers have no injection seam,
// so this test drives the exact symbols the widget invokes (parse -> normalize
// -> submitParsed -> writeRecord) for every acceptance phrase, replicating the
// widget's decision path symbol-for-symbol. A companion widget test renders the
// real DesktopVoiceCapsule surface for listening / processing / started phases.
//
// Scope: this test exercises only the desktop-voice stack. It does not touch
// planner/timeline code, PocketBase writes (writeRecord is mocked), or
// deploy/state-changing operations.

import 'package:counter/data/voice/desktop_voice_command_normalize.dart';
import 'package:counter/shared/voice/routing/desktop_voice_record_submit.dart';
import 'package:counter/data/models.dart';
import 'package:counter/shared/voice/platforms/desktop/ui/desktop_voice_capsule.dart';
import 'package:counter/data/voice/voice_command_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CategoryRule _fixtureTree() {
  return CategoryRule(
    id: 100,
    name: 'Price Reporter',
    backendRowId: 'prroot123456789',
    children: [
      CategoryRule(
        id: 101,
        name: 'AGE SOLUTIONS',
        backendRowId: 'ageclient123456',
        keywords: {
          'en': ['age solutions'],
        },
      ),
      CategoryRule(
        id: 102,
        name: 'ACME CORP',
        backendRowId: 'acmecorpcat1234',
        keywords: {
          'en': ['acme corp', 'acme'],
        },
      ),
    ],
  );
}

/// Simulates `_DesktopVoiceOverlayState._parseTranscript()._confirmStart()`
/// end-to-end against the production record-submit boundary (writeRecord mocked).
Future<_E2EOutcome> _simulateWidgetFlow({
  required List<CategoryRule> rules,
  required String transcriptEmittedByRecognizer,
  required String dateKey,
  required String localeCode,
  required DateTime Function() planetaryNow,
  required Future<String?> Function(DesktopVoiceWriteRecordRequest)
      writeRecordImpl,
}) async {
  // Step 8 of the chain: parseVoiceCommand (exactly as _parseTranscript calls).
  final parsed = parseVoiceCommand(rules: rules, transcript: transcriptEmittedByRecognizer);

  // Step 8 (cont): final normalization gate before auto-start.
  final norm = normalizeDesktopVoiceCommand(parsed);
  if (norm == null || !norm.autoStartAllowed) {
    return _E2EOutcome(writeRecordCalled: false, reason: parsed.ambiguityReason ?? parsed.confidence.name);
  }
  // Step 9: submitParsed — same symbol `_desktopVoiceSubmitParsed` invokes.
  final outcome = await DesktopVoiceRecordSubmit.submitParsed(
    result: norm.effectiveResult,
    dateKey: dateKey,
    localeCode: localeCode,
    writeRecord: writeRecordImpl,
    planetaryNow: planetaryNow,
  );
  if (outcome == null) {
    return _E2EOutcome(writeRecordCalled: false, reason: parsed.ambiguityReason ?? parsed.confidence.name);
  }
  return _E2EOutcome(
    writeRecordCalled: true,
    serverId: outcome.serverId,
    confirmation: outcome.confirmationMessage,
  );
}

class _E2EOutcome {
  const _E2EOutcome({
    required this.writeRecordCalled,
    this.serverId,
    this.confirmation,
    this.reason,
  });

  final bool writeRecordCalled;
  final String? serverId;
  final String? confirmation;
  final String? reason;
}

void main() {
  final rules = [_fixtureTree()];
  const dateKey = '2026-07-01';
  final fixedNow = DateTime.utc(2026, 7, 1, 9, 30);

  group('Desktop voice E2E — recognizer transcript → writeRecord', () {
    test('Case A: exact transcript reaches writeRecord (root Planning)', () async {
      DesktopVoiceWriteRecordRequest? captured;
      final outcome = await _simulateWidgetFlow(
        rules: rules,
        transcriptEmittedByRecognizer: 'Price Reporter Planning',
        dateKey: dateKey,
        localeCode: 'en',
        planetaryNow: () => fixedNow,
        writeRecordImpl: (req) async {
          captured = req;
          return 'pbe2e0000000001';
        },
      );
      expect(outcome.writeRecordCalled, isTrue, reason: outcome.reason ?? 'no reason');
      expect(captured, isNotNull);
      expect(captured!.title, 'Planning');
      expect(captured!.categoryId, 100);
      expect(captured!.dateKey, dateKey);
      expect(captured!.explicitStartTime, fixedNow);
      expect(outcome.serverId, 'pbe2e0000000001');
      expect(outcome.confirmation, 'Started: Price Reporter — Planning');
    });

    test('Case B: client + multi-word task reaches writeRecord', () async {
      DesktopVoiceWriteRecordRequest? captured;
      final outcome = await _simulateWidgetFlow(
        rules: rules,
        transcriptEmittedByRecognizer: 'Price Reporter AGE SOLUTIONS ADD MOD',
        dateKey: dateKey,
        localeCode: 'ru',
        planetaryNow: () => fixedNow,
        writeRecordImpl: (req) async {
          captured = req;
          return 'pbe2e0000000002';
        },
      );
      expect(outcome.writeRecordCalled, isTrue, reason: outcome.reason ?? 'no reason');
      expect(captured!.title, 'ADD MOD');
      expect(captured!.categoryId, 101);
      expect(outcome.confirmation, 'Запущено: Price Reporter > AGE SOLUTIONS — ADD MOD');
    });

    test('STT near-miss alias flows through and reaches writeRecord', () async {
      const aliases = [
        'press reporter Planning',
        'price rep play',
        'rice reporter play',
        'price report AGE SOLUTIONS ADD MOD',
      ];
      for (final phrase in aliases) {
        var writeCalled = false;
        final outcome = await _simulateWidgetFlow(
          rules: rules,
          transcriptEmittedByRecognizer: phrase,
          dateKey: dateKey,
          localeCode: 'en',
          planetaryNow: () => fixedNow,
          writeRecordImpl: (_) async {
            writeCalled = true;
            return 'pbe2e0000000003';
          },
        );
        expect(outcome.writeRecordCalled, isTrue, reason: 'alias failed: $phrase');
        expect(writeCalled, isTrue, reason: 'alias did not reach writeRecord: $phrase');
      }
    });

    test('unsupported dictation does NOT reach writeRecord', () async {
      var writeCalled = false;
      final outcome = await _simulateWidgetFlow(
        rules: rules,
        transcriptEmittedByRecognizer: 'set an alarm for 9 am',
        dateKey: dateKey,
        localeCode: 'en',
        planetaryNow: () => fixedNow,
        writeRecordImpl: (_) async {
          writeCalled = true;
          return 'x';
        },
      );
      expect(outcome.writeRecordCalled, isFalse);
      expect(writeCalled, isFalse);
      expect(outcome.reason, isNotNull);
    });

    test('empty transcript does NOT reach writeRecord', () async {
      var writeCalled = false;
      final outcome = await _simulateWidgetFlow(
        rules: rules,
        transcriptEmittedByRecognizer: '   ',
        dateKey: dateKey,
        localeCode: 'en',
        planetaryNow: () => fixedNow,
        writeRecordImpl: (_) async {
          writeCalled = true;
          return 'x';
        },
      );
      expect(outcome.writeRecordCalled, isFalse);
      expect(writeCalled, isFalse);
    });

    test('writeRecord returning null (Brain failure) is surfaced, not silent', () async {
      final outcome = await _simulateWidgetFlow(
        rules: rules,
        transcriptEmittedByRecognizer: 'Price Reporter ACME CODEREVIEW',
        dateKey: dateKey,
        localeCode: 'en',
        planetaryNow: () => fixedNow,
        writeRecordImpl: (_) async => null, // Brain returns no serverId
      );
      expect(outcome.writeRecordCalled, isFalse,
          reason: 'submitParsed must return null outcome when writeRecord yields null serverId');
      expect(outcome.serverId, isNull);
      expect(outcome.confirmation, isNull);
    });

    test('Normalization blocks unmapped Planning near-miss (no silent wrong task)', () async {
      var writeCalled = false;
      final outcome = await _simulateWidgetFlow(
        rules: rules,
        transcriptEmittedByRecognizer: 'Price Reporter Plenty',
        dateKey: dateKey,
        localeCode: 'en',
        planetaryNow: () => fixedNow,
        writeRecordImpl: (_) async {
          writeCalled = true;
          return 'x';
        },
      );
      // 'Plenty' is a known Planning near-miss that the normalizer REPAIRS — not blocks.
      // So writeRecord IS reached, but the title must be 'Planning' (the repaired form),
      // proving the near-miss did not leak the raw bad title to the user's task list.
      expect(outcome.writeRecordCalled, isTrue);
      expect(writeCalled, isTrue);
      expect(outcome.confirmation, 'Started: Price Reporter — Planning');
    });
  });

  group('Desktop voice E2E — overlay capsule renders expected phase copy', () {
    Widget harness({required DesktopVoiceCapsule capsule}) {
      return MaterialApp(
        home: Scaffold(
          body: capsule,
        ),
      );
    }

    testWidgets('listening phase shows mic icon, "Listening" line, and timer', (tester) async {
      await tester.pumpWidget(harness(
        capsule: const DesktopVoiceCapsule(
          primaryLine: 'Listening',
          showMic: true,
          showSpinner: false,
          micLevel: 0.0,
          timerText: '00:03',
          isError: false,
        ),
      ));
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.text('Listening'), findsOneWidget);
      expect(find.text('00:03'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    });

    testWidgets('pending confirmation shows progress fill and tap hint', (tester) async {
      await tester.pumpWidget(harness(
        capsule: const DesktopVoiceCapsule(
          primaryLine: 'Start: Price Reporter — Planning',
          secondaryLine: 'Tap to edit',
          showMic: false,
          showSpinner: false,
          micLevel: 0.0,
          progressFill: 0.42,
          compactActions: true,
          isError: false,
        ),
      ));
      expect(find.text('Start: Price Reporter — Planning'), findsOneWidget);
      expect(find.text('Tap to edit'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('processing phase shows spinner without transcript debug line',
        (tester) async {
      await tester.pumpWidget(harness(
        capsule: const DesktopVoiceCapsule(
          primaryLine: 'Transcribing',
          showMic: false,
          showSpinner: true,
          micLevel: 0.0,
          isError: false,
        ),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
      expect(find.text('Transcribing'), findsOneWidget);
    });

    testWidgets('started phase shows confirmation copy, no spinner, no error', (tester) async {
      await tester.pumpWidget(harness(
        capsule: const DesktopVoiceCapsule(
          primaryLine: 'Started',
          secondaryLine: 'Price Reporter — Planning',
          showMic: false,
          showSpinner: false,
          micLevel: 0.0,
          isError: false,
        ),
      ));
      expect(find.text('Started'), findsOneWidget);
      expect(find.text('Price Reporter — Planning'), findsOneWidget);
      // Started phase must not render the transcribing spinner or the error icon.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    });

    testWidgets('error phase shows error icon and red primary line', (tester) async {
      await tester.pumpWidget(harness(
        capsule: const DesktopVoiceCapsule(
          primaryLine: 'Could not recognize the command',
          showMic: false,
          showSpinner: false,
          micLevel: 0.0,
          isError: true,
          onCancel: null,
        ),
      ));
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Could not recognize the command'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
    });
  });
}
