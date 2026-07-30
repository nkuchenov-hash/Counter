import 'package:counter/data/models.dart';
import 'package:counter/features/notes/widgets/notes_canonical_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'text block keeps dynamic active indicator on mobile and desktop',
    (tester) async {
      final controller = TextEditingController(
        text: 'A multiline heading that wraps naturally without a fixed height',
      );
      addTearDown(controller.dispose);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        _host(
          NotesTextBlock(
            controller: controller,
            style: NotesTextBlockStyle.h1,
            state: NotesBlockState.active,
          ),
        ),
      );

      expect(find.byKey(const ValueKey('notes-active-indicator')), findsOneWidget);
      expect(
        tester.getSize(
          find.byKey(const ValueKey('notes-active-indicator')),
        ).height,
        greaterThan(20),
      );
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1200, 900);
      await tester.pumpWidget(
        _host(
          Center(
            child: SizedBox(
              width: 768,
              child: NotesTextBlock(
                controller: controller,
                style: NotesTextBlockStyle.h1,
                state: NotesBlockState.active,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(NotesTextBlock), findsOneWidget);
      expect(find.byKey(const ValueKey('notes-active-indicator')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('list and checklist share the same leading text geometry', (
    tester,
  ) async {
    final listController = TextEditingController(
      text: 'A list item that wraps onto a second line on the mobile width',
    );
    final checklistController = TextEditingController(
      text: 'A checklist item that wraps onto a second line on the mobile width',
    );
    addTearDown(listController.dispose);
    addTearDown(checklistController.dispose);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NotesListBlock(
              controller: listController,
              listStyle: NotesListStyle.numbered,
              ordinal: 3,
              textFieldKey: const ValueKey('list-text-field'),
            ),
            NotesChecklistBlock(
              controller: checklistController,
              checked: false,
              onCheckedChanged: (_) {},
              textFieldKey: const ValueKey('checklist-text-field'),
            ),
          ],
        ),
      ),
    );

    final listOrigin = tester.getTopLeft(
      find.byKey(const ValueKey('list-text-field')),
    );
    final checklistOrigin = tester.getTopLeft(
      find.byKey(const ValueKey('checklist-text-field')),
    );
    expect((listOrigin.dx - checklistOrigin.dx).abs(), lessThan(0.1));
    expect(listOrigin.dx, closeTo(50, 0.1));
    expect(
      tester.getSize(find.byKey(const ValueKey('list-text-field'))).height,
      greaterThan(24),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shared toolbar and table picker handle compact and extended widths',
    (tester) async {
      var tablePressed = false;
      NoteTableData? selectedTable;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NotesEditorToolbar(
                actions: [
                  for (final tool in NotesToolbarTool.values)
                    NotesToolbarAction(
                      tool: tool,
                      icon: _iconFor(tool),
                      tooltip: tool.name,
                      selected: tool == NotesToolbarTool.text,
                      onPressed: () {
                        if (tool == NotesToolbarTool.table) {
                          tablePressed = true;
                        }
                      },
                    ),
                ],
              ),
              NotesTableSizePicker(
                onSelected: (table) => selectedTable = table,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('notes-toolbar-table')));
      expect(tablePressed, isTrue);
      await tester.tap(find.byKey(const ValueKey('notes-table-size-5-5')));
      expect(selectedTable?.rowCount, 5);
      expect(selectedTable?.columnCount, 5);
      expect(tester.takeException(), isNull);

      selectedTable = null;
      tester.view.physicalSize = const Size(1200, 900);
      await tester.pumpWidget(
        _host(
          Center(
            child: NotesTableSizePicker(
              maxRows: 8,
              maxColumns: 6,
              onSelected: (table) => selectedTable = table,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('notes-table-size-8-6')));
      expect(selectedTable?.rowCount, 8);
      expect(selectedTable?.columnCount, 6);
      expect(find.byType(NotesTableSizePicker), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
    home: Scaffold(body: child),
  );
}

IconData _iconFor(NotesToolbarTool tool) {
  return switch (tool) {
    NotesToolbarTool.heading => Icons.title_rounded,
    NotesToolbarTool.text => Icons.text_fields_rounded,
    NotesToolbarTool.quote => Icons.format_quote_rounded,
    NotesToolbarTool.list => Icons.format_list_bulleted_rounded,
    NotesToolbarTool.checklist => Icons.checklist_rounded,
    NotesToolbarTool.table => Icons.table_chart_rounded,
    NotesToolbarTool.drawing => Icons.draw_rounded,
    NotesToolbarTool.image => Icons.image_rounded,
    NotesToolbarTool.audio => Icons.mic_rounded,
  };
}
