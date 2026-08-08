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
        content: ReorderableListView(
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
            Padding(
              key: const ValueKey('body-item'),
              padding: const EdgeInsets.all(20),
              child: TextField(
                key: const ValueKey('body-field'),
                controller: body,
                focusNode: bodyFocus,
                minLines: 1,
                maxLines: null,
                scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              ),
            ),
          ],
        ),
        toolbar: const SizedBox(
          key: ValueKey('notes-test-toolbar'),
          height: 48,
        ),
      ),
    );
  }

  testWidgets('mobile web viewport resize keeps focused Notes body visible', (
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

  testWidgets('native keyboard inset keeps focused Notes body visible', (
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
