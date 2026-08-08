import 'package:counter/features/notes/widgets/notes_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('web visual keyboard keeps Notes body rendered', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final title = TextEditingController(text: 'Title');
    final body = TextEditingController(text: 'Body');
    final bodyFocus = FocusNode();
    final browserInset = ValueNotifier<double>(0);
    addTearDown(title.dispose);
    addTearDown(body.dispose);
    addTearDown(bodyFocus.dispose);
    addTearDown(browserInset.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: NotesEditorScreen(
          titleController: title,
          onTitleChanged: (_) {},
          onDone: () {},
          pinned: false,
          onTogglePinned: () {},
          onDelete: () {},
          visualKeyboardInsetListenable: browserInset,
          content: ReorderableListView(
            onReorder: (_, __) {},
            children: [
              Padding(
                key: const ValueKey('body-item'),
                padding: const EdgeInsets.all(20),
                child: TextField(
                  key: const ValueKey('body-field'),
                  controller: body,
                  focusNode: bodyFocus,
                ),
              ),
            ],
          ),
          toolbar: const SizedBox(
            key: ValueKey('notes-test-toolbar'),
            height: 48,
          ),
        ),
      ),
    );

    bodyFocus.requestFocus();
    await tester.pump();
    browserInset.value = 300;
    await tester.pump();

    expect(
      find.byKey(const ValueKey('notes-editor-title-collapsed-for-keyboard')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('body-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('notes-test-toolbar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native keyboard inset keeps Notes body rendered', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final title = TextEditingController(text: 'Title');
    final body = TextEditingController(text: 'Body');
    final bodyFocus = FocusNode();
    final browserInset = ValueNotifier<double>(0);
    addTearDown(title.dispose);
    addTearDown(body.dispose);
    addTearDown(bodyFocus.dispose);
    addTearDown(browserInset.dispose);

    Widget app(EdgeInsets viewInsets) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          viewInsets: viewInsets,
        ),
        child: NotesEditorScreen(
          titleController: title,
          onTitleChanged: (_) {},
          onDone: () {},
          pinned: false,
          onTogglePinned: () {},
          onDelete: () {},
          visualKeyboardInsetListenable: browserInset,
          content: ReorderableListView(
            onReorder: (_, __) {},
            children: [
              Padding(
                key: const ValueKey('body-item'),
                padding: const EdgeInsets.all(20),
                child: TextField(
                  key: const ValueKey('body-field'),
                  controller: body,
                  focusNode: bodyFocus,
                ),
              ),
            ],
          ),
          toolbar: const SizedBox(
            key: ValueKey('notes-test-toolbar'),
            height: 48,
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(EdgeInsets.zero));
    bodyFocus.requestFocus();
    await tester.pump();
    await tester.pumpWidget(app(const EdgeInsets.only(bottom: 300)));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('notes-editor-title-collapsed-for-keyboard')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('body-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('notes-test-toolbar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
