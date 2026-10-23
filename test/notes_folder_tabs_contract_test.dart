import 'package:counter/features/notes/widgets/notes_folder_pane.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/gestures.dart';
import 'package:counter/features/notes/widgets/notes_library_production_shell.dart';
import 'package:counter/features/notes/widgets/note_card.dart';
import 'notes/fixtures/notes_glm_library_parity_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    expect(NotesFolderTabStrip.height, 38);
    expect(
      NotesFolderTabStrip.tabWidth('Folder'),
      lessThan(NotesFolderTabStrip.tabWidth('Правители России')),
    );
    // No more 186px hard cap: legible labels take their measured width.
    expect(NotesFolderTabStrip.tabWidth('Правители России'), greaterThan(140));
    expect(
      NotesFolderTabStrip.tabWidth('Образовательный дневник'),
      greaterThan(186),
    );
    expect(
      NotesFolderTabStrip.tabWidth('An extremely long category label that is wider than the screen'),
      lessThanOrEqualTo(460),
    );
  });

  testWidgets('real folder names remain complete rather than ellipsized',
      (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    const labels = [
      'Правители России',
      'Образовательный дневник',
      'Price Reporter',
      'Atozed Website',
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 630,
          child: NotesFolderTabStrip(
            tabs: [
              for (var i = 0; i < labels.length; i++)
                NotesFolderTabData(
                  id: i + 1,
                  label: labels[i],
                  icon: Icons.folder_outlined,
                  paper: const Color(0xFFE9EDF3),
                ),
            ],
            selectedId: 2,
            scrollController: scroll,
            allLabel: 'Все',
            allPaper: const Color(0xFFF2F4F7),
            onSelect: (_) {},
            onAdd: () {},
          ),
        ),
      ),
    ));

    for (var i = 0; i < labels.length; i++) {
      final tab = find.byKey(ValueKey('notes-tab-${i + 1}'));
      final label = find.descendant(
        of: tab,
        matching: find.text(labels[i]),
      );
      expect(label, findsOneWidget);
      final textWidget = tester.widget<Text>(label);
      expect(textWidget.style!.fontSize, 14);
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect(paragraph.didExceedMaxLines, isFalse,
          reason: 'Folder name ${labels[i]} must not be clipped.');
      expect(tester.getSize(tab).width,
          NotesFolderTabStrip.tabWidth(labels[i]));
    }
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
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

  testWidgets('folder tabs keep the muted paper edge and compact header',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    const paper = Color(0xFFEEF2F7);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 460,
          child: NotesFolderTabStrip(
            tabs: const [
              NotesFolderTabData(
                id: 1,
                label: 'Notes',
                icon: Icons.folder,
                paper: paper,
                accent: Color(0xFF5486BA),
              ),
            ],
            selectedId: 1,
            scrollController: controller,
            allLabel: 'Все',
            allPaper: const Color(0xFFF2F4F7),
            onSelect: (_) {},
            onAdd: () {},
          ),
        ),
      ),
    ));
    final selected = find.byKey(const ValueKey('notes-tab-1'));
    final animated = tester.widget<AnimatedContainer>(
      find.descendant(of: selected, matching: find.byType(AnimatedContainer)),
    );
    final decoration = animated.decoration! as BoxDecoration;
    final colors = (decoration.gradient! as LinearGradient).colors;
    expect(colors.last, paper); // physical seam == page paper
    expect(colors.first, isNot(colors.last)); // subtle top bevel
    expect(tester.getSize(selected).height, 38);
    expect(tester.getSize(find.byKey(const ValueKey('notes-tab-add'))).height, 35);
  });

  testWidgets('active folder spine paints above its neighbors with subtle elevation',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 480,
          child: NotesFolderTabStrip(
            tabs: const [
              NotesFolderTabData(id: 1, label: 'First',
                  icon: Icons.folder, paper: Color(0xFFE3EAF2)),
              NotesFolderTabData(id: 2, label: 'Second',
                  icon: Icons.folder, paper: Color(0xFFF6E7DA)),
            ],
            selectedId: 2,
            scrollController: controller,
            allLabel: 'Все', allPaper: const Color(0xFFF2F4F7),
            onSelect: (_) {}, onAdd: () {},
          ),
        ),
      ),
    ));
    Material tabMaterial(int id) => tester.widget<Material>(
      find.descendant(
        of: find.byKey(ValueKey('notes-tab-$id')),
        matching: find.byType(Material),
      ).first,
    );
    // Low lift + painted contact seam. Old deep elevations were the source
    // of the black upper-right hooks visible in the screenshot.
    expect(tabMaterial(1).elevation, lessThan(0.5));
    expect(tabMaterial(2).elevation, lessThan(0.5));
    expect(tabMaterial(1).shadowColor!.a, lessThan(0.10));
    // Keep saved tab indices, but always paint the selected folder LAST.
    // It must be hit-tested and drawn above the adjacent shoulder.
    final stack = tester.widget<Stack>(
      find.byKey(const ValueKey('notes-layered-tab-stack')),
    );
    expect(
      stack.children.map((child) => (child as Positioned).child.key).toList(),
      [const ValueKey('notes-tab-1'), const ValueKey('notes-tab-2')],
    );
    final addTab = find.byKey(const ValueKey('notes-tab-add'));
    final addMaterial = tester.widget<Material>(
      find.descendant(of: addTab, matching: find.byType(Material)).first,
    );
    expect(addMaterial.elevation, lessThan(0.5));
    final addPaint = tester.widget<AnimatedContainer>(
      find.descendant(of: addTab, matching: find.byType(AnimatedContainer)),
    );
    final gradient = (addPaint.decoration! as BoxDecoration).gradient!
        as LinearGradient;
    expect(gradient.colors.last, const Color(0xFF111827));
    expect(tester.getRect(addTab).right, 480);
  });

  testWidgets('one-line title does not reserve three text rows before body',
      (tester) async {
    const doc = NoteDocument(blocks: [
      NoteBlock(id: 'one', type: NoteBlockType.numberedList,
          text: 'Отпуск - PM (предварительно посмотреть кто не занят)'),
      NoteBlock(id: 'two', type: NoteBlockType.numberedList, text: 'AI tools'),
      NoteBlock(id: 'three', type: NoteBlockType.numberedList,
          text: 'SDVOSB - Solution One IndustriED'),
    ]);
    final data = NoteCardData(
      task: PlanningTask(
        id: 1001, title: 'Mike call 11/09',
        categoryId: 1, dateKey: '', createdAt: DateTime(2026, 9, 8),
      ),
      doc: doc,
      stats: doc.computeStats(),
      categoryName: 'Price Reporter',
      categoryColor: const Color(0xFF6A93CA),
      categoryIconCodePoint: Icons.folder.codePoint,
      pinned: false,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 280, height: 290,
          child: NoteCard(
            data: data, view: NotesLibraryView.grid,
            checkboxesOn: false, onOpen: () {},
            onTogglePin: () {}, onToggleDone: () {},
            onLongPress: () {}, onOpenMenu: (_) {},
          ),
        ),
      ),
    ));
    final title = find.text('Mike call 11/09');
    final body = find.textContaining('1. Отпуск');
    expect(title, findsOneWidget);
    expect(body, findsOneWidget);
    final gap = tester.getTopLeft(body).dy - tester.getBottomLeft(title).dy;
    expect(gap, inInclusiveRange(0, 18),
        reason: 'A single-line title must not reserve unused maxLines rows');
    expect(find.text('08.09.2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fixed black add tab visually crosses the scrolling rail', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 370,
          child: NotesFolderTabStrip(
            tabs: [
              for (var id = 1; id <= 9; id++)
                NotesFolderTabData(
                  id: id, label: 'Category $id',
                  icon: Icons.folder,
                  paper: const Color(0xFFE5EEF6),
                ),
            ],
            selectedId: 7, scrollController: controller,
            allLabel: 'Все',
            allPaper: const Color(0xFFF2F4F7),
            onSelect: (_) {}, onAdd: () {},
          ),
        ),
      ),
    ));
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    final add = tester.getRect(find.byKey(const ValueKey('notes-tab-add')));
    final scroller = tester.getRect(find.byKey(
      const ValueKey('notes-category-scroller')));
    expect(add.left, lessThan(scroller.right));
    expect(add.right, 370);
    expect(tester.takeException(), isNull);
  });

  testWidgets('note preview begins just under title, not halfway down card',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 280,
          height: 290,
          child: NoteCard(
            data: NotesGlmLibraryParityFixture.sampleCard,
            view: NotesLibraryView.grid,
            checkboxesOn: false,
            onOpen: () {},
            onTogglePin: () {},
            onToggleDone: () {},
            onLongPress: () {},
            onOpenMenu: (_) {},
          ),
        ),
      ),
    ));
    final title = find.text('Broken links on the website');
    final preview = find.textContaining('☑ Homepage CTA');
    expect(title, findsOneWidget);
    expect(preview, findsOneWidget);
    final spacing = tester.getTopLeft(preview).dy - tester.getBottomLeft(title).dy;
    expect(spacing, inInclusiveRange(0, 22));
  });

  test('card preview reveals real checklist state and structural list markers', () {
    final doc = NoteDocument(blocks: [
      const NoteBlock(id: 'p', type: NoteBlockType.paragraph, text: 'Introduction'),
      const NoteBlock(id: 'c1', type: NoteBlockType.checklist, text: 'First task', checked: true),
      const NoteBlock(id: 'c2', type: NoteBlockType.checklist, text: 'Second task'),
      const NoteBlock(id: 'c3', type: NoteBlockType.checklist, text: 'Third task'),
    ]);
    expect(noteCardPreview(doc), '☑ First task\n☐ Second task\n☐ Third task');
    expect(
      noteCardPreview(const NoteDocument(blocks: [
        NoteBlock(id: 'b', type: NoteBlockType.bulletedList, text: 'Bullet'),
        NoteBlock(id: 'n', type: NoteBlockType.numberedList, text: 'Number'),
      ])),
      '• Bullet\n1. Number',
    );
  });

  testWidgets('note card displays creation date and checklist progress together',
      (tester) async {
    final doc = NoteDocument(blocks: const [
      NoteBlock(id: 'c1', type: NoteBlockType.checklist,
          text: 'Review', checked: true),
      NoteBlock(id: 'c2', type: NoteBlockType.checklist, text: 'Approve'),
    ]);
    final task = PlanningTask(
      id: 101,
      title: 'Date and progress',
      categoryId: 1,
      dateKey: '',
      createdAt: DateTime(2026, 10, 17),
      updatedAt: DateTime(2026, 10, 23),
    );
    final card = NoteCardData(
      task: task,
      doc: doc,
      stats: doc.computeStats(),
      categoryName: 'Tasks',
      categoryColor: const Color(0xFF668CC0),
      categoryIconCodePoint: Icons.folder.codePoint,
      pinned: false,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 285,
          height: 290,
          child: NoteCard(
            data: card,
            view: NotesLibraryView.grid,
            checkboxesOn: false,
            onOpen: () {},
            onTogglePin: () {},
            onToggleDone: () {},
            onLongPress: () {},
            onOpenMenu: (_) {},
          ),
        ),
      ),
    ));
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('17.10.2026'), findsOneWidget);
    expect(find.textContaining('☑ Review'), findsOneWidget);
    final title = find.text('Date and progress');
    final preview = find.textContaining('☑ Review');
    final gap = tester.getTopLeft(preview).dy - tester.getBottomLeft(title).dy;
    expect(gap, inInclusiveRange(0, 17));
    expect(tester.takeException(), isNull);
  });

  testWidgets('notes without checklist show actual creation date', (tester) async {
    final doc = NoteDocument(blocks: const [
      NoteBlock(id: 'p1', type: NoteBlockType.paragraph, text: 'Plain text'),
    ]);
    final data = NoteCardData(
      task: PlanningTask(
        id: 201, title: 'Ordinary note', categoryId: 1, dateKey: '',
        createdAt: DateTime(2026, 8, 5),
      ),
      doc: doc, stats: doc.computeStats(), categoryName: 'Tasks',
      categoryColor: const Color(0xFF668CC0),
      categoryIconCodePoint: Icons.folder.codePoint, pinned: false,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 285, height: 285,
          child: NoteCard(
            data: data, view: NotesLibraryView.grid,
            checkboxesOn: false, onOpen: () {}, onTogglePin: () {},
            onToggleDone: () {}, onLongPress: () {}, onOpenMenu: (_) {},
          ),
        ),
      ),
    ));
    expect(find.text('05.08.2026'), findsOneWidget);
    expect(find.text('1/2'), findsNothing);
    expect(tester.takeException(), isNull);
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
    expect(decoration.color, const Color(0xFFF2F4F7));
    final rect = tester.getRect(find.byKey(const ValueKey('notes-folder-paper')));
    final card = tester.getRect(find.text('First note'));
    expect(card.top - rect.top, greaterThanOrEqualTo(18));
  });
}
