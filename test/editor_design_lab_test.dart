import 'package:counter/app/design_lab/main.dart';
import 'package:counter/features/notes/widgets/notes_editor_screen.dart';
import 'package:counter/features/shared/edit_sheet/editor_v45_chrome.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    currentLocale.value = 'ru';
  });

  testWidgets('Lab selects real components and preserves bounded preview width', (tester) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EditorDesignLabApp());
    await tester.pump();
    expect(find.byType(EditorV45TimeCard), findsOneWidget);
    expect(find.byType(EditorV45Actions), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('v45-action-pill'))).width, lessThanOrEqualTo(342));
    await tester.tap(find.byKey(const ValueKey('lab-device-desktop')));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('v45-action-pill'))).width, 440);
    await tester.tap(find.byKey(const ValueKey('lab-theme')));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(EditorV45TimeCard))).brightness, Brightness.dark);
    await tester.tap(find.byKey(const ValueKey('lab-editor-note')));
    await tester.pumpAndSettle();
    expect(find.byType(NotesEditorScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lab-editor-plan')));
    await tester.pumpAndSettle();
    expect(find.byType(EditorV45TimeCard), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lab-mode-creating')));
    await tester.pumpAndSettle();
    expect(find.text('Создать план'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
