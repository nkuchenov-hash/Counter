import 'package:counter/features/notes/widgets/notes_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile Notes editor scrolls title and shrinks for keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    final titleController = TextEditingController(text: 'Mobile note');
    addTearDown(titleController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: NotesEditorScreen(
          titleController: titleController,
          onTitleChanged: (_) {},
          onDone: () {},
          pinned: false,
          onTogglePinned: () {},
          onDelete: () {},
          content: ListView(
            children: const [
              SizedBox(height: 900),
              TextField(key: ValueKey('notes-test-bottom-field')),
            ],
          ),
          toolbar: const SizedBox(height: 48),
        ),
      ),
    );
    await tester.pump();

    final mobileScroll = find.byKey(
      const ValueKey('notes-editor-mobile-scroll'),
    );
    expect(mobileScroll, findsOneWidget);
    expect(
      find.byKey(const ValueKey('notes-editor-scrollable-title')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('notes-editor-title')), findsOneWidget);

    final openHeight = tester.getSize(mobileScroll).height;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    final keyboardHeight = tester.getSize(mobileScroll).height;

    expect(keyboardHeight, lessThan(openHeight));
    expect(openHeight - keyboardHeight, greaterThanOrEqualTo(250));
  });

  testWidgets('wide Notes editor keeps desktop title layout unchanged', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final titleController = TextEditingController(text: 'Desktop note');
    addTearDown(titleController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: NotesEditorScreen(
          titleController: titleController,
          onTitleChanged: (_) {},
          onDone: () {},
          pinned: false,
          onTogglePinned: () {},
          onDelete: () {},
          content: const SizedBox.expand(),
          toolbar: const SizedBox(height: 48),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('notes-editor-mobile-scroll')), findsNothing);
    expect(
      find.byKey(const ValueKey('notes-editor-scrollable-title')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('notes-editor-title')), findsOneWidget);
  });
}
