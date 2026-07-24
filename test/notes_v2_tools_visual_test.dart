import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notes/fixtures/notes_v2_tools_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the production Notes v2 tools system', (tester) async {
    tester.view.physicalSize = kNotesV2ToolsViewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
        ),
        home: const Scaffold(body: NotesV2ToolsFixture()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(kNotesV2ToolsCaptureKey), findsOneWidget);
    expect(find.text('Aa · text and block formatting'), findsOneWidget);
    expect(find.text('+ · insert blocks'), findsOneWidget);
    expect(find.text('Active table · contextual editing'), findsOneWidget);

    await expectLater(
      find.byKey(kNotesV2ToolsCaptureKey),
      matchesGoldenFile('fixtures/notes_v2_tools_capture.png'),
    );
  });
}
