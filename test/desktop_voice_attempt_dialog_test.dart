// In-app Desktop Voice diagnostics dialog — renders an existing attempt and
// exposes a Copy button that writes the plain-text summary to the clipboard.
//
// The Copy handler is verified via the `DesktopVoiceAttemptDialogTestHooks`
// injection point so the test never touches the flutter/platform method
// channel (which has no default handler on the test binding and would hang).

import 'package:counter/shared/voice/platforms/desktop/desktop_voice_attempt_log.dart';
import 'package:counter/features/settings/voice/desktop_voice_attempt_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? copied;

  setUp(() {
    copied = null;
    DesktopVoiceAttemptLog.instance.begin();
    DesktopVoiceAttemptDialogTestHooks.copyOverride = (text) async {
      copied = text;
    };
  });

  tearDown(() {
    DesktopVoiceAttemptDialogTestHooks.copyOverride = null;
    DesktopVoiceAttemptLog.instance.begin();
  });

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDesktopVoiceAttemptDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the latest attempt fields and status detail',
      (tester) async {
    DesktopVoiceAttemptLog.instance
      ..markRecordingStarted(true)
      ..markMicHeard()
      ..recordTranscript('Laredo TS scene')
      ..recordParser(
        confidence: 'exact',
        matchedScope: 'Laredo Technical Services > Laredo TS',
        taskTitle: 'SIN',
      )
      ..markSubmission(serverId: 'pblaredo000001');

    await pumpDialog(tester);

    expect(find.text('Voice command'), findsOneWidget);
    expect(find.text('Task created'), findsOneWidget);
    expect(find.textContaining('Started:'), findsOneWidget);
    expect(find.text('Heard'), findsOneWidget);
    expect(find.text('"Laredo TS scene"'), findsOneWidget);
    expect(find.text('Laredo Technical Services > Laredo TS'), findsOneWidget);
    expect(find.text('SIN'), findsOneWidget);
  });

  testWidgets('Copy button writes the plain-text summary', (tester) async {
    DesktopVoiceAttemptLog.instance
      ..markRecordingStarted(true)
      ..recordTranscript('Price Reporter Planning')
      ..recordParser(
        confidence: 'exact',
        matchedScope: 'Price Reporter',
        taskTitle: 'Planning',
      )
      ..markSubmission(serverId: 'pbrec0000000001');

    await pumpDialog(tester);

    await tester.tap(find.textContaining('Copy voice diagnostics'));
    await tester.pumpAndSettle();

    expect(find.text('Copied'), findsOneWidget,
        reason: 'label must flip to "Copied" after the write completes');

    expect(copied, isNotNull);
    expect(copied!, contains('Hotkey received: yes'));
    expect(copied!, contains('Heard: "Price Reporter Planning"'));
    expect(copied!, contains('Matched scope: Price Reporter'));
    expect(copied!, contains('Task title: Planning'));
    expect(copied!, contains('Save result: ok'));
    expect(copied!, contains('Final: task created'));
    // Confidential: must NOT leak the raw PocketBase id into the copied text.
    expect(copied, isNot(contains('pbrec0000000001')));
  });
}
