import 'package:counter/features/notes/widgets/notes_folder_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('All folder tab is compact and has no icon', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: NotesFolderTabStrip.height,
            child: NotesFolderTabStrip(
              tabs: const <NotesFolderTabData>[],
              selectedId: null,
              scrollController: controller,
              allLabel: 'Все',
              allPaper: const Color(0xFFF2F4F7),
              onSelect: (_) {},
              onAdd: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('notes-tab-all'))).width,
        68);
    expect(find.text('Все'), findsOneWidget);
    expect(find.byIcon(Icons.format_list_bulleted_rounded), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('Mobile folder has one inset and no surrounding card radius',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NotesFolderPane(
            categoryId: null,
            edgeToEdge: true,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    final pane = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('notes-folder-paper')),
    );
    expect(pane.padding, const EdgeInsets.fromLTRB(12, 12, 12, 12));
    expect((pane.decoration! as BoxDecoration).borderRadius,
        BorderRadius.zero);
  });
}
