import 'dart:io';

import 'package:counter/features/notes/debug/notes_glm_library_parity_fixture.dart';
import 'package:counter/features/notes/debug/notes_glm_parity_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notes GLM visual parity fixtures', () {
    testWidgets('editor fixture renders at 1156x821', (tester) async {
      tester.view.physicalSize = kNotesGlmParityViewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: NotesGlmParityFixture()),
      );
      await tester.pump();
      expect(find.byKey(kNotesGlmParityCaptureKey), findsOneWidget);
      expect(find.text('Weekly intentions'), findsOneWidget);
    });

    testWidgets('library fixture renders at 1156x821', (tester) async {
      tester.view.physicalSize = kNotesGlmParityViewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: NotesGlmLibraryParityFixture()),
      );
      await tester.pump();
      expect(find.byKey(kNotesGlmLibraryParityCaptureKey), findsOneWidget);
      expect(find.text('Broken links on the website'), findsOneWidget);
    });

    test('production PNG artifacts exist (run capture_notes_glm_main.dart)', () {
      expect(
        File('test/fixtures/notes_glm_production_editor_capture.png').existsSync(),
        isTrue,
        reason:
            'Run: flutter run -d windows -t lib/features/notes/debug/capture_notes_glm_main.dart',
      );
      expect(
        File('test/fixtures/notes_glm_production_library_capture.png')
            .existsSync(),
        isTrue,
        reason:
            'Run: flutter run -d windows -t lib/features/notes/debug/capture_notes_glm_main.dart',
      );
    });
  });
}
