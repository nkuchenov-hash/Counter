import 'package:counter/features/notes/widgets/notes_folder_pane.dart';
import 'package:flutter/gestures.dart';
import 'package:counter/features/notes/widgets/notes_library_production_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active Notes category never changes the saved tab order', () {
    final pinned = [31, 44, 18, 72];
    expect(notesStableTabIds(pinned, 18), [31, 44, 18, 72]);
    expect(notesStableTabIds(pinned, 31), [31, 44, 18, 72]);
    expect(notesStableTabIds(pinned, 72), [31, 44, 18, 72]);
    expect(notesStableTabIds(pinned, null), pinned);
    expect(pinned, [31, 44, 18, 72]);
    // Externally opened category joins the end, never displaces pinned tabs.
    expect(notesStableTabIds(pinned, 99), [31, 44, 18, 72, 99]);
  });

  test('folder spine has a sloping right edge, not pill geometry', () {
    const shape = NotesPhysicalFolderShape();
    final path = shape.getOuterPath(const Rect.fromLTWH(0, 0, 200, 50));
    expect(path.contains(const Offset(195, 3)), isFalse);
    expect(path.contains(const Offset(100, 30)), isTrue);
  });

  testWidgets('All and add stay fixed while category middle scrolls',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    int? selectedId = 1;
    var adds = 0;
    final folders = [
      for (var id = 1; id <= 7; id++)
        NotesFolderTabData(
          id: id,
          label: 'Category $id',
          icon: Icons.folder_outlined,
          paper: const Color(0xFFFFB533),
        ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 380,
            child: NotesFolderTabStrip(
              tabs: folders,
              selectedId: selectedId,
              scrollController: controller,
              allLabel: 'Все',
              allPaper: const Color(0xFFE3ECF8),
              onSelect: (id) => selectedId = id,
              onAdd: () => adds++,
            ),
          ),
        ),
      ),
    ));
    final all = find.byKey(const ValueKey('notes-tab-all'));
    final plus = find.byKey(const ValueKey('notes-tab-add'));
    final leftBefore = tester.getTopLeft(all);
    final rightBefore = tester.getTopLeft(plus);
    expect(controller.position.maxScrollExtent, greaterThan(0));
    expect(
      ScrollConfiguration.of(tester.element(
        find.byKey(const ValueKey('notes-category-scroller')),
      )).dragDevices,
      contains(PointerDeviceKind.mouse),
    );

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(tester.getTopLeft(all), leftBefore);
    expect(tester.getTopLeft(plus), rightBefore);
    expect(selectedId, 1);
    await tester.tap(plus);
    expect(adds, 1);
    expect(selectedId, 1);
  });

  testWidgets('vertical mouse wheel scrolls category rail only',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 340,
          child: NotesFolderTabStrip(
            tabs: [
              for (var id = 1; id <= 9; id++)
                NotesFolderTabData(
                  id: id,
                  label: 'Folder $id',
                  icon: Icons.folder_outlined,
                  paper: const Color(0xFFFFB533),
                ),
            ],
            selectedId: 4,
            scrollController: controller,
            allLabel: 'All',
            allPaper: const Color(0xFFE3ECF8),
            onSelect: (_) {},
            onAdd: () {},
          ),
        ),
      ),
    ));
    final allBefore = tester.getTopLeft(
      find.byKey(const ValueKey('notes-tab-all')),
    );
    final scroller = find.byKey(const ValueKey('notes-category-scroller'));
    final center = tester.getCenter(scroller);
    tester.binding.handlePointerEvent(PointerScrollEvent(
      position: center,
      scrollDelta: const Offset(0, 130),
    ));
    await tester.pump();
    expect(controller.offset, greaterThan(0));
    expect(tester.getTopLeft(
      find.byKey(const ValueKey('notes-tab-all')),
    ), allBefore);
  });

  testWidgets('folder paper animates and keeps an interior gap before notes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: SizedBox(
            height: 450,
            child: NotesFolderPane(
              categoryId: null,
              child: const Text('First note'),
            ),
          ),
        ),
      ),
    );

    final animated = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('notes-folder-paper')),
    );
    expect(animated.duration, const Duration(milliseconds: 260));
    expect(animated.padding, const EdgeInsets.fromLTRB(16, 18, 16, 16));
    final decoration = animated.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFE3ECF8));
    final rect = tester.getRect(find.byKey(const ValueKey('notes-folder-paper')));
    final card = tester.getRect(find.text('First note'));
    expect(card.top - rect.top, greaterThanOrEqualTo(18));
  });
}
