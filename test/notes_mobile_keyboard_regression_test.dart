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
              for (var index = 0; index < 3; index++)
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

  void simulateTyping(TextEditingController body, String text) {
    body.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  testWidgets('short mobile web viewport keeps Notes typing visible', (
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
    expect(find.byKey(const ValueKey('body-field')), findsOneWidget);
    bodyFocus.requestFocus();
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(390, 430);
    await tester.pumpAndSettle();
    simulateTyping(
      body,
      'Body typing after keyboard resize\nsecond line\nthird line\nfourth line',
    );
    await tester.pumpAndSettle();

    final contentRect = tester.getRect(
      find.byKey(const ValueKey('notes-test-content')),
    );
    final fieldRect = tester.getRect(find.byKey(const ValueKey('body-field')));
    expect(contentRect.height, greaterThan(0));
    expect(fieldRect.top, lessThan(430));
    expect(fieldRect.bottom, lessThanOrEqualTo(430));
    expect(find.byKey(const ValueKey('notes-test-toolbar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large native keyboard keeps Notes typing visible', (
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
    expect(find.byKey(const ValueKey('body-field')), findsOneWidget);
    bodyFocus.requestFocus();
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 380);
    await tester.pumpAndSettle();
    simulateTyping(
      body,
      'Body typing with native keyboard\nsecond line\nthird line\nfourth line',
    );
    await tester.pumpAndSettle();

    final contentRect = tester.getRect(
      find.byKey(const ValueKey('notes-test-content')),
    );
    final fieldRect = tester.getRect(find.byKey(const ValueKey('body-field')));
    const visibleBottom = 844.0 - 380.0;
    expect(contentRect.height, greaterThan(0));
    expect(fieldRect.top, lessThan(visibleBottom));
    expect(fieldRect.bottom, lessThanOrEqualTo(visibleBottom));
    expect(find.byKey(const ValueKey('notes-test-toolbar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
