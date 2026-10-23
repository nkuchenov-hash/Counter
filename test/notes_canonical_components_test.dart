import 'dart:convert';
import 'dart:typed_data';

import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_editor_document_controller.dart';
import 'package:counter/features/notes/notes_figma_tokens.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/features/notes/notes_image_tools.dart';
import 'package:counter/features/notes/widgets/notes_canonical_components.dart';
import 'package:counter/features/notes/widgets/note_editor_block_widgets.dart';
import 'package:counter/features/notes/widgets/notes_editor_tools.dart';
import 'package:counter/features/notes/widgets/notes_editor_screen.dart';
import 'package:counter/features/notes/widgets/notes_library_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('embedded Notes sheet is rounded with breathing room for ghost actions', (tester) async {
    final title = TextEditingController(text: 'Test note');
    addTearDown(title.dispose);
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 960,
          height: 610,
          child: NotesEmbeddedEditorScope(
            onClose: () {},
            child: NotesEditorScreen(
              titleController: title,
              onTitleChanged: (_) {},
              onDone: () {},
              pinned: false,
              onTogglePinned: () {},
              onDelete: () {},
              content: ListView(children: const [Text('Block one')]),
              toolbar: const SizedBox(width: 300, height: 48),
            ),
          ),
        ),
      ),
    );

    const surfaceKey = ValueKey('notes-embedded-editor-rounded-surface');
    final clip = tester.widget<ClipRRect>(find.byKey(surfaceKey));
    expect(clip.borderRadius, BorderRadius.circular(20));
    final back = find.byIcon(Icons.arrow_back_rounded);
    final bounds = tester.getRect(find.byKey(surfaceKey));
    expect(tester.getTopLeft(back).dy - bounds.top, greaterThan(20));
    final backMaterial = find.ancestor(
      of: back,
      matching: find.byType(Material),
    );
    expect(
      tester.widgetList<Material>(backMaterial).any(
        (material) => material.color == Colors.transparent &&
            material.shape is CircleBorder,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Notes document scrolls behind bottom feather without reserving a strip', (tester) async {
    const contentKey = ValueKey('notes-scroll-through-content');
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 450,
          height: 310,
          child: NotesEditorBody(
            content: ColoredBox(
              key: contentKey,
              color: Colors.white,
              child: SizedBox.expand(),
            ),
            toolbar: SizedBox(width: 260, height: 48),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(contentKey)).height, 310);
    final fade = find.byKey(const ValueKey('notes-feathered-bottom-fade'));
    expect(fade, findsOneWidget);
    final gradientBox = find.byKey(const ValueKey('notes-bottom-paper-gradient'));
    expect(gradientBox, findsOneWidget);
    final decoration =
        tester.widget<DecoratedBox>(gradientBox).decoration as BoxDecoration;
    final colors = (decoration.gradient! as LinearGradient).colors;
    expect(colors.first.a, 0);
    expect(colors.last.a, greaterThan(0.95));
    expect(colors.last, isNot(Colors.transparent));
    // Only the scroll content fades. The toolbar remains outside the mask.
    expect(
      find.ancestor(
        of: gradientBox,
        matching: find.byType(BackdropFilter),
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Notes toolbar is a readable capsule, not a full-width dock', (tester) async {
    await tester.pumpWidget(
      _host(
        NotesEditorToolbar(
          actions: [
            NotesToolbarAction(
              tool: NotesToolbarTool.heading,
              icon: Icons.title,
              tooltip: 'Heading',
              onPressed: () {},
            ),
            NotesToolbarAction(
              tool: NotesToolbarTool.text,
              icon: Icons.format_bold,
              tooltip: 'Bold',
              selected: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    final toolbar = find.byKey(const ValueKey('notes-floating-glass-toolbar'));
    final pill = find.byKey(const ValueKey('notes-floating-glass-pill'));
    expect(toolbar, findsOneWidget);
    expect(pill, findsOneWidget);
    expect(tester.getSize(toolbar), const Size(350, 48));
    expect(
      find.descendant(of: toolbar, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );

    final surface = tester.widget<DecoratedBox>(pill).decoration as BoxDecoration;
    expect(surface.borderRadius, BorderRadius.circular(24));
    expect(surface.color, isNull);
    final glassColors = (surface.gradient! as LinearGradient).colors;
    expect(glassColors.first.a, inInclusiveRange(0.80, 0.86));
    expect(glassColors.last.a, inInclusiveRange(0.68, 0.76));
    expect(glassColors.first.a, greaterThan(glassColors.last.a));
    expect(surface.border, isNotNull);
    expect(
      find.ancestor(of: pill, matching: find.byType(ClipRRect)),
      findsWidgets,
    );

    // The shadow belongs to the floating pill, never a stretching footer.
    final outer = find.ancestor(
      of: pill,
      matching: find.byType(DecoratedBox),
    );
    expect(
      tester.widgetList<DecoratedBox>(outer).any(
        (box) => (box.decoration as BoxDecoration).boxShadow?.isNotEmpty == true,
      ),
      isTrue,
    );
    expect(find.byKey(const ValueKey('notes-toolbar-heading')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark Notes editor preserves an opaque-enough glass pill', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: NotesEditorToolbar(
            actions: [
              NotesToolbarAction(
                tool: NotesToolbarTool.text,
                icon: Icons.text_fields,
                tooltip: 'Text',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final pill = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('notes-floating-glass-pill')),
    );
    final decoration = pill.decoration as BoxDecoration;
    final glassColors = (decoration.gradient! as LinearGradient).colors;
    expect(glassColors.first.a, inInclusiveRange(0.79, 0.85));
    expect(glassColors.last.a, inInclusiveRange(0.66, 0.73));
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Notes footer blur feathers in without a toolbar backplate', (
    tester,
  ) async {
    const toolbarKey = ValueKey('floating-notes-toolbar');
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 430,
          height: 250,
          child: NotesBottomGlassFade(
            height: 86,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                key: toolbarKey,
                width: 350,
                height: 48,
              ),
            ),
          ),
        ),
      ),
    );

    final mask = find.byKey(const ValueKey('notes-feathered-bottom-fade'));
    final toolbar = find.byKey(toolbarKey);
    expect(mask, findsOneWidget);
    expect(find.descendant(of: mask, matching: find.byType(BackdropFilter)), findsOneWidget);
    expect(
      tester.widget<ShaderMask>(mask).blendMode,
      BlendMode.dstIn,
    );
    expect(find.ancestor(of: toolbar, matching: find.byType(ShaderMask)), findsNothing);
    expect(find.ancestor(of: toolbar, matching: find.byType(BackdropFilter)), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
      expect(notesUsesEmbeddedWorkspace(1024), isFalse);
      expect(notesUsesEmbeddedWorkspace(1200), isTrue);

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
      expect(
        tester.getSize(find.byType(NotesEditorToolbar)),
        const Size(
          NotesFigmaTokens.toolbarWidth,
          NotesFigmaTokens.toolbarHeight,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('notes-toolbar-table')));
      expect(tablePressed, isTrue);
      final compactCell = find.byKey(const ValueKey('notes-table-size-5-5'));
      await tester.ensureVisible(compactCell);
      await tester.tap(compactCell);
      expect(selectedTable?.rowCount, 5);
      expect(selectedTable?.columnCount, 5);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _host(
          NotesEditorScreen(
            titleController: headingController,
            onTitleChanged: (_) {},
            onDone: () {},
            pinned: false,
            onTogglePinned: () {},
            onDelete: () {},
            categoryLabel: 'Work',
            tags: const [NotesEditorMetadataTag(label: 'planning')],
            content: const Align(
              alignment: Alignment.topLeft,
              child: Text(
                'Visible note content',
                key: ValueKey('notes-production-visible-content'),
              ),
            ),
            toolbar: NotesEditorToolbar(
              actions: [
                for (final tool in NotesToolbarTool.values)
                  NotesToolbarAction(
                    tool: tool,
                    icon: _iconFor(tool),
                    tooltip: tool.name,
                    onPressed: () {},
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final visibleContent = find.byKey(
        const ValueKey('notes-production-visible-content'),
      );
      final productionToolbar = find.byType(NotesEditorToolbar);
      expect(visibleContent, findsOneWidget);
      expect(
        tester.getSize(productionToolbar),
        const Size(
          NotesFigmaTokens.toolbarWidth,
          NotesFigmaTokens.toolbarHeight,
        ),
      );
      expect(
        tester.getTopLeft(visibleContent).dy,
        lessThan(tester.getTopLeft(productionToolbar).dy),
      );
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1400, 900);
      await tester.pumpWidget(
        _host(
          NotesEmbeddedEditorScope(
            onClose: () {},
            child: NotesEditorScreen(
              titleController: headingController,
              onTitleChanged: (_) {},
              onDone: () {},
              pinned: false,
              onTogglePinned: () {},
              onDelete: () {},
              categoryLabel: 'Work',
              content: const SizedBox.shrink(),
              toolbar: NotesEditorToolbar(
                actions: [
                  for (final tool in NotesToolbarTool.values)
                    NotesToolbarAction(
                      tool: tool,
                      icon: _iconFor(tool),
                      tooltip: tool.name,
                      onPressed: () {},
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('notes-editor-content-rail')))
            .width,
        NotesFigmaTokens.editorContentMaxWidth,
      );

      await tester.pumpWidget(
        _host(
          NotesEmbeddedEditorScope(
            onClose: () {},
            child: NotesEditorScreen(
              titleController: headingController,
              onTitleChanged: (_) {},
              onDone: () {},
              pinned: false,
              onTogglePinned: () {},
              onDelete: () {},
              categoryLabel: 'Work',
              content: ReorderableListView(
                buildDefaultDragHandles: false,
                onReorder: (_, __) {},
                children: [
                  NotesEditorBlockItem(
                    key: const ValueKey('desktop-media-block-item'),
                    block: const NoteBlock(
                      id: 'desktop-media',
                      type: NoteBlockType.image,
                      imageData: 'not-base64',
                    ),
                    index: 0,
                    numberedOrdinal: 1,
                    active: false,
                    editing: false,
                    onTap: () {},
                    onKeyEvent: (_) => KeyEventResult.ignored,
                  ),
                ],
              ),
              toolbar: NotesEditorToolbar(
                actions: [
                  for (final tool in NotesToolbarTool.values)
                    NotesToolbarAction(
                      tool: tool,
                      icon: _iconFor(tool),
                      tooltip: tool.name,
                      onPressed: () {},
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final desktopMediaRow = find.byKey(
        const ValueKey('notes-desktop-media-file-row'),
      );
      final embeddedToolbar = find.byType(NotesEditorToolbar);
      expect(desktopMediaRow, findsOneWidget);
      expect(tester.getSize(desktopMediaRow).height, 72);
      expect(find.byKey(const ValueKey('notes-media-frame')), findsNothing);
      expect(
        tester.getTopLeft(desktopMediaRow).dy,
        lessThan(tester.getTopLeft(embeddedToolbar).dy),
      );
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
