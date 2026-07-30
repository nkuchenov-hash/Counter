import 'dart:convert';
import 'dart:typed_data';

import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_editor_document_controller.dart';
import 'package:counter/features/notes/notes_image_tools.dart';
import 'package:counter/features/notes/widgets/notes_canonical_components.dart';
import 'package:counter/features/notes/widgets/notes_editor_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v1 note migration round-trips rich and unsupported blocks', () {
    final source = jsonEncode({
      'format': kLifeOsNotesBlocksV1Format,
      'version': 1,
      'blocks': [
        {
          'id': 'rich',
          'type': 'paragraph',
          'runs': [
            {
              'text': 'Keep bold',
              'marks': {'bold': true},
            },
          ],
        },
        {
          'id': 'legacy-callout',
          'type': 'callout',
          'text': 'Preserve me',
          'callout': {'type': 'info'},
        },
      ],
    });

    final migrated = NoteDocument.tryParse(notesDeltaJson: source);
    expect(migrated.format, kLifeOsNotesBlocksFormat);
    expect(migrated.version, kLifeOsNotesBlocksVersion);
    expect(migrated.blocks.first.effectiveRuns.single.marks.bold, isTrue);

    final roundTrip = NoteDocument.tryParse(notesDeltaJson: migrated.encode());
    expect(roundTrip.blocks.map((block) => block.id).toList(), [
      'rich',
      'legacy-callout',
    ]);
    expect(roundTrip.blocks.last.type, NoteBlockType.callout);
    expect(roundTrip.blocks.last.effectiveText, 'Preserve me');
  });

  test(
    'editor core handles H1 enter, formatting, table edits, delete, and preservation',
    () {
      expect(
        decodeNotesImageDataUrl('data:image/png;base64,AQID'),
        Uint8List.fromList([1, 2, 3]),
      );
      expect(notesImageMimeType('photo.webp'), 'image/webp');

      final legacy = NoteBlock(
        id: 'legacy-reference',
        type: NoteBlockType.noteReference,
        reference: const NoteReferenceData(targetId: 'note-42'),
      );
      final editor = NotesEditorDocumentController(
        NoteDocument(blocks: [legacy]),
      );
      final first = editor.visibleBlocks.single;
      expect(first.type, NoteBlockType.heading);
      expect(first.level, 1);

      editor.applyTextInput(
        first.id,
        'Heading',
        const TextSelection.collapsed(offset: 7),
      );
      final formatted = editor.applyInlineFormat(
        first.id,
        const TextSelection(baseOffset: 0, extentOffset: 7),
        NotesInlineFormat.bold,
      );
      expect(formatted.changed, isTrue);
      expect(
        editor.blockById(first.id)!.effectiveRuns.single.marks.bold,
        isTrue,
      );

      final enter = editor.handleEnter(
        first.id,
        const TextSelection.collapsed(offset: 7),
      );
      expect(enter.changed, isTrue);
      expect(editor.visibleBlocks.map((block) => block.type).toList(), [
        NoteBlockType.heading,
        NoteBlockType.paragraph,
      ]);

      final bodyId = editor.visibleBlocks.last.id;
      editor.insertAfter(
        bodyId,
        NoteBlockType.table,
        table: NoteTableData.empty(rows: 2, columns: 3),
      );
      final table = editor.visibleBlocks.singleWhere(
        (block) => block.type == NoteBlockType.table,
      );
      editor.editTable(
        table.id,
        NotesTableEditCommand.addRowBelow,
        row: 0,
        column: 0,
      );
      editor.editTable(
        table.id,
        NotesTableEditCommand.addColumnRight,
        row: 0,
        column: 0,
      );
      expect(editor.blockById(table.id)!.table?.rowCount, 3);
      expect(editor.blockById(table.id)!.table?.columnCount, 4);

      final tableIndex = editor.visibleBlocks.indexWhere(
        (block) => block.id == table.id,
      );
      editor.reorderVisible(tableIndex, 0);
      expect(editor.visibleBlocks.first.type, NoteBlockType.table);

      const audio = NoteAudioData(
        dataUrl: 'data:audio/wav;base64,UklGRg==',
        durationMs: 1250,
        transcript: 'Recorded thought',
        transcriptStatus: NoteAudioTranscriptStatus.ready,
      );
      editor.insertAfter(
        editor.visibleBlocks.last.id,
        NoteBlockType.audio,
        audio: audio,
      );
      final audioBlock = editor.visibleBlocks.singleWhere(
        (block) => block.type == NoteBlockType.audio,
      );
      expect(audioBlock.audio?.durationMs, 1250);

      final deleted = editor.deleteBlock(bodyId);

      expect(deleted.changed, isTrue);
      expect(editor.visibleBlocks.any((block) => block.id == bodyId), isFalse);

      final saved = NoteDocument.tryParse(
        notesDeltaJson: editor.document.encode(),
      );
      expect(
        saved.blocks
            .singleWhere((block) => block.type == NoteBlockType.audio)
            .audio
            ?.transcript,
        'Recorded thought',
      );
      expect(
        saved.blocks
            .singleWhere((block) => block.id == legacy.id)
            .reference
            ?.targetId,
        'note-42',
      );
    },
  );

  testWidgets(
    'canonical editor components stay aligned and responsive at both widths',
    (tester) async {
      final headingController = TextEditingController(
        text: 'A multiline heading that wraps without a fixed height',
      );
      final listController = TextEditingController(
        text: 'A list item that wraps onto another line on mobile',
      );
      final checklistController = TextEditingController(
        text: 'A checklist item that wraps onto another line on mobile',
      );
      addTearDown(headingController.dispose);
      addTearDown(listController.dispose);
      addTearDown(checklistController.dispose);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var tablePressed = false;
      NoteTableData? selectedTable;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        _host(
          _responsiveHarness(
            headingController: headingController,
            listController: listController,
            checklistController: checklistController,
            maxRows: 5,
            maxColumns: 5,
            onTablePressed: () => tablePressed = true,
            onTableSelected: (table) => selectedTable = table,
          ),
        ),
      );

      final listOrigin = tester.getTopLeft(
        find.byKey(const ValueKey('list-text-field')),
      );
      final checklistOrigin = tester.getTopLeft(
        find.byKey(const ValueKey('checklist-text-field')),
      );
      expect(listOrigin.dx, closeTo(50, 0.1));
      expect((listOrigin.dx - checklistOrigin.dx).abs(), lessThan(0.1));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('notes-active-indicator')))
            .height,
        greaterThan(20),
      );
      await tester.tap(find.byKey(const ValueKey('notes-toolbar-table')));
      expect(tablePressed, isTrue);
      final compactCell = find.byKey(const ValueKey('notes-table-size-5-5'));
      await tester.ensureVisible(compactCell);
      await tester.tap(compactCell);
      expect(selectedTable?.rowCount, 5);
      expect(selectedTable?.columnCount, 5);
      expect(tester.takeException(), isNull);

      selectedTable = null;
      tester.view.physicalSize = const Size(1200, 900);
      await tester.pumpWidget(
        _host(
          Center(
            child: SizedBox(
              width: 768,
              child: _responsiveHarness(
                headingController: headingController,
                listController: listController,
                checklistController: checklistController,
                maxRows: 8,
                maxColumns: 6,
                onTablePressed: () {},
                onTableSelected: (table) => selectedTable = table,
              ),
            ),
          ),
        ),
      );
      final extendedCell = find.byKey(const ValueKey('notes-table-size-8-6'));
      await tester.ensureVisible(extendedCell);
      await tester.tap(extendedCell);
      expect(selectedTable?.rowCount, 8);
      expect(selectedTable?.columnCount, 6);
      expect(find.byType(NotesTableSizePicker), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _responsiveHarness({
  required TextEditingController headingController,
  required TextEditingController listController,
  required TextEditingController checklistController,
  required int maxRows,
  required int maxColumns,
  required VoidCallback onTablePressed,
  required ValueChanged<NoteTableData> onTableSelected,
}) {
  return SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NotesTextBlock(
          controller: headingController,
          style: NotesTextBlockStyle.h1,
          state: NotesBlockState.active,
        ),
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
        NotesEditorToolbar(
          actions: [
            for (final tool in NotesToolbarTool.values)
              NotesToolbarAction(
                tool: tool,
                icon: _iconFor(tool),
                tooltip: tool.name,
                selected: tool == NotesToolbarTool.text,
                onPressed: tool == NotesToolbarTool.table
                    ? onTablePressed
                    : () {},
              ),
          ],
        ),
        NotesTableSizePicker(
          maxRows: maxRows,
          maxColumns: maxColumns,
          onSelected: onTableSelected,
        ),
      ],
    ),
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
