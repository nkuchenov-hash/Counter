import 'package:counter/features/notes/widgets/notes_canonical_components.dart';
import 'package:counter/features/notes/widgets/notes_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget editor({
    required TextEditingController title,
    required TextEditingController body,
    required FocusNode bodyFocus,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: NotesEditorScreen(
        titleController: title,
        onTitleChanged: (_) {},
        onDone: () {},
        pinned: false,
        onTogglePinned: () {},
        onDelete: () {},
        content: SelectionArea(
          child: ReorderableListView(
            key: const ValueKey('notes-test-content'),
            padding: EdgeInsets.zero,
            buildDefaultDragHandles: false,
            onReorder: (_, __) {},
            children: [
              for (var index = 0; index < 7; index++)
                SizedBox(
                  key: ValueKey('spacer-$index'),
                  height: 72,
                ),
              NotesTextBlock(
                key: const ValueKey('body-item'),
                controller: body,
                focusNode: bodyFocus,
                state: NotesBlockState.active,
                textFieldKey: const ValueKey('body-field'),
              ),
            ],
          ),
        ),
        toolbar: const SizedBox(
          key: ValueKey('notes-test-toolbar'),
          height: 48,
        ),
      ),
    );
  }

  testWidgets('mobile web typing keeps Notes content rendered and visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final title = TextEditingController(text: 'Title');
    final body = TextEditingController(text: 'Body');
    final bodyFocus = FocusNode();
    addTearDown(title.dispose);
    addTearDown(body.dispose);
    addTearDown(bodyFocus.dispose);

    await tester.pumpWidget(
      editor(title: title, body: body, bodyFocus: bodyFocus),
    );
    bodyFocus.requestFocus();
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(390, 520);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('body-field')),
      'Body typing after keyboard resize',
    );
    await tester.pumpAndSettle();

    final contentRect = tester.getRect(
      find.byKey(const ValueKey('notes-test-content')),
    );
    final fieldRect = tester.getRect(find.byKey(const ValueKey('body-field')));
    expect(contentRect.height, greaterThan(0));
    expect(fieldRect.top, lessThan(520));
    expect(fieldRect.bottom, lessThanOrEqualTo(520));
    expect(find.byKey(const ValueKey('notes-test-toolbar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native keyboard typing keeps Notes content rendered and visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    final title = TextEditingController(text: 'Title');
    final body = TextEditingController(text: 'Body');
    final bodyFocus = FocusNode();
    addTearDown(title.dispose);
    addTearDown(body.dispose);
    addTearDown(bodyFocus.dispose);

    await tester.pumpWidget(
      editor(title: title, body: body, bodyFocus: bodyFocus),
    );
    bodyFocus.requestFocus();
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('body-field')),
      'Body typing with native keyboard',
    );
    await tester.pumpAndSettle();

    final contentRect = tester.getRect(
      find.byKey(const ValueKey('notes-test-content')),
    );
    final fieldRect = tester.getRect(find.byKey(const ValueKey('body-field')));
    const visibleBottom = 844.0 - 300.0;
    expect(contentRect.height, greaterThan(0));
    expect(fieldRect.top, lessThan(visibleBottom));
    expect(fieldRect.bottom, lessThanOrEqualTo(visibleBottom));
    expect(find.byKey(const ValueKey('notes-test-toolbar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
