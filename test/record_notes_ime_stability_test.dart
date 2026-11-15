import 'dart:io';

import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_editor_document_controller.dart';
import 'package:counter/features/notes/note_editor_page.dart';
import 'package:counter/features/notes/widgets/note_editor_block_widgets.dart';
import 'package:counter/features/notes/notes_figma_tokens.dart';
import 'package:counter/features/shared/edit_sheet/record_edit_save_policy.dart';
import 'package:counter/features/notes/widgets/notes_canonical_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Embedded Record Notes Android IME geometry', () {
    test('preserves compact sheet while Gboard still owns the keyboard', () {
      expect(
        recordNotesShouldUseCompactChrome(
          notesFocused: false,
          notesImeSessionActive: true,
          keyboardInset: 370,
        ),
        isTrue,
      );
    });

    test('restores record fields after focus and keyboard are both gone', () {
      expect(
        recordNotesShouldUseCompactChrome(
          notesFocused: false,
          notesImeSessionActive: true,
          keyboardInset: 0,
        ),
        isFalse,
      );
    });

    test('does not hide record fields for an unrelated keyboard', () {
      expect(
        recordNotesShouldUseCompactChrome(
          notesFocused: false,
          notesImeSessionActive: false,
          keyboardInset: 370,
        ),
        isFalse,
      );
    });

    test('editing without a visible keyboard also keeps compact mode', () {
      expect(
        recordNotesShouldUseCompactChrome(
          notesFocused: true,
          notesImeSessionActive: false,
          keyboardInset: 0,
        ),
        isTrue,
      );
    });
  });

  test('three Android Notes lines keep one mounted editing block', () {
    const id = 'active-record-notes-block';
    final editor = NotesEditorDocumentController(
      const NoteDocument(blocks: [
        NoteBlock(id: id, type: NoteBlockType.paragraph),
      ]),
    );
    final lines = <String>[
      'Первая строка',
      'Первая строка\nВторая строка',
      'Первая строка\nВторая строка\nТретья строка',
      'Первая строка\nВторая строка\nТретья строка\nЧетвёртая',
    ];
    for (final text in lines) {
      final mutation = editor.applyTextInput(
        id,
        text,
        TextSelection.collapsed(offset: text.length),
        preserveLineBreaks: true,
      );
      expect(mutation.changed, isTrue);
      expect(mutation.requiresRebuild, isFalse);
      expect(mutation.focusBlockId, isNull);
      expect(editor.visibleBlocks, hasLength(1));
      expect(editor.visibleBlocks.single.id, id);
      expect(editor.visibleBlocks.single.effectiveText, text);
      expect(editor.activeBlockId, id);
    }
  });

  testWidgets('active marker never stretches to the third text line', (tester) async {
    final controller = TextEditingController(text: 'One\nTwo\nThree');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: NotesTextBlock(
              controller: controller,
              state: NotesBlockState.active,
            ),
          ),
        ),
      ),
    );
    final marker = find.byKey(const ValueKey('notes-active-indicator'));
    expect(marker, findsOneWidget);
    expect(tester.getSize(marker).height, NotesFigmaTokens.bodySize);
    expect(tester.getSize(find.byType(NotesTextBlock)).height,
        greaterThan(NotesFigmaTokens.bodyLineHeight * 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('real embedded Notes field survives 4 lines without losing EditableText', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const blockId = 'android-record-ime-field';
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: SizedBox(
            height: 650,
            child: NoteEditorPage(
              task: PlanningTask(
                id: 0,
                planRowId: 'record-typing-regression',
                title: 'Record',
                categoryId: CategoryRule.uncategorizedSyntheticId,
                dateKey: '2026-11-14',
              ),
              parityPreview: true,
              inlineBodyOnly: true,
              initialDocument: const NoteDocument(blocks: [
                NoteBlock(id: blockId, type: NoteBlockType.paragraph, text: 'Начало'),
              ]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(NotesEditorBlockItem).first);
    await tester.pump();

    final field = find.byKey(const ValueKey('notes-block-field-$blockId'));
    expect(field, findsOneWidget);
    final editable = find.descendant(of: field, matching: find.byType(EditableText));
    final originalEditable = tester.state<EditableTextState>(editable);
    for (final text in [
      'Первая строка',
      'Первая строка\nВторая',
      'Первая строка\nВторая\nТретья',
      'Первая строка\nВторая\nТретья\nЧетвёртая',
    ]) {
      await tester.enterText(field, text);
      await tester.pump();
      expect(field, findsOneWidget);
      expect(tester.state<EditableTextState>(editable), same(originalEditable));
      expect(tester.widget<TextField>(field).controller!.text, text);
      expect(tester.takeException(), isNull);
    }
  });

  test('heading Enter creates independent Body, preserving H1 formatting', () {
    const headingId = 'heading-before-enter';
    final editor = NotesEditorDocumentController(
      const NoteDocument(blocks: [
        NoteBlock(
          id: headingId,
          type: NoteBlockType.heading,
          level: 1,
          text: 'Заголовок',
        ),
      ]),
    );
    final text = 'Заголовок\n';
    editor.applyTextInput(
      headingId,
      text,
      TextSelection.collapsed(offset: text.length),
      preserveLineBreaks: true,
    );
    final split = editor.splitEmbeddedLineBreak(
      headingId,
      TextSelection.collapsed(offset: text.length),
    );
    expect(split.changed, isTrue);
    expect(split.focusBlockId, isNot(headingId));
    expect(editor.visibleBlocks, hasLength(2));
    expect(editor.visibleBlocks.first.id, headingId);
    expect(editor.visibleBlocks.first.type, NoteBlockType.heading);
    expect(editor.visibleBlocks.first.level, 1);
    expect(editor.visibleBlocks.first.effectiveText, 'Заголовок');
    final body = editor.visibleBlocks.last;
    expect(body.type, NoteBlockType.paragraph);
    expect(body.effectiveText, isEmpty);

    // Styling the new line must never change its preceding heading.
    editor.convertBlock(body.id, NotesBlockConversion.h2);
    expect(editor.visibleBlocks.first.type, NoteBlockType.heading);
    expect(editor.visibleBlocks.first.level, 1);
    editor.convertBlock(body.id, NotesBlockConversion.body);
    expect(editor.visibleBlocks.first.level, 1);
    expect(editor.visibleBlocks.last.type, NoteBlockType.paragraph);
  });

  testWidgets('embedded Android heading Enter focuses separate Body after one tap',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const headingId = 'record-heading-single-tap';
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: Scaffold(
        body: SizedBox(
          height: 650,
          child: NoteEditorPage(
            task: PlanningTask(
              id: 0,
              planRowId: 'heading-single-tap-test',
              title: 'Record',
              categoryId: CategoryRule.uncategorizedSyntheticId,
              dateKey: '2026-11-15',
            ),
            parityPreview: true,
            inlineBodyOnly: true,
            initialDocument: const NoteDocument(blocks: [
              NoteBlock(
                id: headingId,
                type: NoteBlockType.heading,
                level: 1,
                text: 'Заголовок',
              ),
            ]),
          ),
        ),
      ),
    ));
    await tester.pump();
    final headingField =
        find.byKey(const ValueKey('notes-block-field-$headingId'));
    // Before the first tap the block must ALREADY be a native TextField.
    expect(headingField, findsOneWidget);
    await tester.tap(headingField);
    await tester.pump();
    expect(tester.widget<TextField>(headingField).focusNode!.hasFocus, isTrue);
    await tester.enterText(headingField, 'Заголовок\n');
    await tester.pump();
    await tester.pump();
    final blocks = tester.widgetList<NotesEditorBlockItem>(
      find.byType(NotesEditorBlockItem),
    ).toList();
    expect(blocks, hasLength(2));
    expect(blocks.first.block.type, NoteBlockType.heading);
    expect(blocks.first.block.effectiveText, 'Заголовок');
    expect(blocks.last.block.type, NoteBlockType.paragraph);
    expect(blocks.last.block.id, isNot(headingId));
    final newBodyField =
        find.byKey(ValueKey('notes-block-field-${blocks.last.block.id}'));
    expect(newBodyField, findsOneWidget);
    expect(tester.widget<TextField>(newBodyField).focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('Android note line split clamps stale Gboard caret after Enter', () {
    final controller = NotesTextEditingController(text: 'Заголовок\\n');
    addTearDown(controller.dispose);
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
    controller.syncDocument(
      text: 'Заголовок',
      runs: const <NoteTextRun>[],
      selection: controller.selection,
    );
    expect(controller.text, 'Заголовок');
    expect(controller.selection.isValid, isTrue);
    expect(controller.selection.extentOffset, controller.text.length);
    expect(controller.value.composing, TextRange.empty);
  });

  test('Enter continues bullet, number and checklist as independent items', () {
    for (final style in [
      NoteBlockType.bulletedList,
      NoteBlockType.numberedList,
      NoteBlockType.checklist,
    ]) {
      final editor = NotesEditorDocumentController(
        NoteDocument(blocks: [
          NoteBlock(id: 'first-item', type: style, text: 'Первый'),
        ]),
      );
      final firstInput = 'Первый\\n';
      editor.applyTextInput(
        'first-item',
        firstInput,
        TextSelection.collapsed(offset: firstInput.length),
        preserveLineBreaks: true,
      );
      final split = editor.splitEmbeddedLineBreak(
        'first-item',
        TextSelection.collapsed(offset: firstInput.length),
      );
      expect(split.changed, isTrue, reason: style.name);
      expect(editor.visibleBlocks, hasLength(2), reason: style.name);
      expect(editor.visibleBlocks.first.id, 'first-item');
      expect(editor.visibleBlocks.first.type, style);
      expect(editor.visibleBlocks.first.effectiveText, 'Первый');
      final second = editor.visibleBlocks.last;
      expect(second.type, style, reason: style.name);
      expect(second.id, isNot('first-item'));
      expect(split.focusBlockId, second.id);

      editor.applyTextInput(
        second.id,
        'Второй',
        const TextSelection.collapsed(offset: 6),
        preserveLineBreaks: true,
      );
      expect(editor.visibleBlocks.last.effectiveText, 'Второй');
      // Changing only the second item cannot change the first item.
      editor.convertBlock(second.id, NotesBlockConversion.body);
      expect(editor.visibleBlocks.first.type, style);
      expect(editor.visibleBlocks.last.type, NoteBlockType.paragraph);
    }
  });

  test('Enter on an empty list item ends list and produces Body', () {
    for (final style in [
      NoteBlockType.bulletedList,
      NoteBlockType.numberedList,
      NoteBlockType.checklist,
    ]) {
      final editor = NotesEditorDocumentController(
        NoteDocument(blocks: [
          NoteBlock(id: 'first', type: style, text: 'Первый'),
          NoteBlock(id: 'empty', type: style),
        ]),
      );
      editor.applyTextInput(
        'empty',
        '\\n',
        const TextSelection.collapsed(offset: 1),
        preserveLineBreaks: true,
      );
      final mutation = editor.splitEmbeddedLineBreak(
        'empty',
        const TextSelection.collapsed(offset: 1),
      );
      expect(mutation.changed, isTrue, reason: style.name);
      expect(editor.visibleBlocks, hasLength(2));
      expect(editor.visibleBlocks.first.type, style);
      expect(editor.visibleBlocks.last.id, 'empty');
      expect(editor.visibleBlocks.last.type, NoteBlockType.paragraph);
      expect(editor.visibleBlocks.last.effectiveText, isEmpty);
      expect(mutation.focusBlockId, 'empty');
    }
  });

  testWidgets('embedded Android list Enter creates focused next list item',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const listId = 'android-list-enter';
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: Scaffold(
        body: SizedBox(
          height: 650,
          child: NoteEditorPage(
            task: PlanningTask(
              id: 0,
              planRowId: 'record-list-enter-regression',
              title: 'Record',
              categoryId: CategoryRule.uncategorizedSyntheticId,
              dateKey: '2026-11-15',
            ),
            parityPreview: true,
            inlineBodyOnly: true,
            initialDocument: const NoteDocument(blocks: [
              NoteBlock(
                id: listId,
                type: NoteBlockType.bulletedList,
                text: 'Первый',
              ),
            ]),
          ),
        ),
      ),
    ));
    await tester.pump();
    final first = find.byKey(const ValueKey('notes-block-field-$listId'));
    expect(first, findsOneWidget);
    await tester.tap(first);
    await tester.pump();
    await tester.enterText(first, 'Первый\\n');
    await tester.pump();
    await tester.pump();
    final items = tester.widgetList<NotesEditorBlockItem>(
      find.byType(NotesEditorBlockItem),
    ).toList();
    expect(items, hasLength(2));
    expect(items.first.block.type, NoteBlockType.bulletedList);
    expect(items.last.block.type, NoteBlockType.bulletedList);
    expect(items.last.block.id, isNot(listId));
    final nextField = find.byKey(
      ValueKey('notes-block-field-${items.last.block.id}'),
    );
    expect(nextField, findsOneWidget);
    expect(tester.widget<TextField>(nextField).focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('Android IME typing keeps composing range without duplicate events', () {
    final controller = NotesTextEditingController(text: 'Привет');
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    const composing = TextRange(start: 0, end: 7);
    controller.value = const TextEditingValue(
      text: 'Привет!',
      selection: TextSelection.collapsed(offset: 7),
      composing: composing,
    );
    expect(notifications, 1);

    // Updating formatting for the same key event must not notify the IME
    // again or discard the active composing region.
    controller.setRuns(
      const [NoteTextRun(text: 'Привет!')],
      notify: false,
    );
    expect(notifications, 1);
    expect(controller.text, 'Привет!');
    expect(controller.value.composing, composing);
    final editedRuns = applyNoteTextEditToRuns(
      oldText: 'Привет',
      oldRuns: const [NoteTextRun(
        text: 'Привет', marks: NoteInlineMarks(bold: true))],
      newText: controller.text,
    );
    expect(editedRuns, hasLength(1));
    expect(editedRuns.single.text, 'Привет!');
    expect(editedRuns.single.marks.bold, isTrue);

    // Explicit formatting changes still repaint once.
    controller.setRuns(
      const [
        NoteTextRun(
          text: 'Привет!',
          marks: NoteInlineMarks(bold: true),
        ),
      ],
    );
    expect(notifications, 2);
  });

  test('Record notes do not scroll their modal ancestors or chase the IME', () {
    final editor = File(
      'lib/features/notes/note_editor_page.dart',
    ).readAsStringSync();
    final record = File(
      'lib/features/shared/timeline_record_edit_sheet.dart',
    ).readAsStringSync();
    final host = File(
      'lib/features/shared/activity_detail_sheet.dart',
    ).readAsStringSync();

    expect(
      editor,
      contains('_blockScrollController.position.ensureVisible('),
    );
    expect(editor, isNot(contains('\n        Scrollable.ensureVisible(')));
    expect(editor, isNot(contains('Future<void>.delayed(const Duration(milliseconds: 180)')));
    expect(record, contains('_handleNotesEditorFocusChanged'));
    expect(record, contains('_notesScopeFocusNode.hasFocus'));
    // Gboard focus interruptions must not expand/collapse Record chrome while
    // the Notes keyboard is present; keep the native EditableText in charge.
    expect(record, contains('recordNotesShouldUseCompactChrome('));
    expect(record, contains('_notesImeSessionActive'));
    expect(editor, contains('Theme.of(context).platform == TargetPlatform.android'));
    expect(editor, contains('preserveLineBreaks: widget.inlineBodyOnly &&'));
    expect(editor, contains('return KeyEventResult.ignored;'));
    expect(editor, contains('_ensureBlockVisible(block.id);'));
    expect(record, contains('final notesEditing = recordNotesShouldUseCompactChrome('));
    // Nested TextFields preserve native Android selection/IME; the expensive
    // document-wide SelectionArea is only needed by standalone Notes.
    expect(editor, contains('child: _blockSelectionMode || (widget.inlineBodyOnly &&'));
    expect(editor, contains('Theme.of(context).platform == TargetPlatform.android'));
    expect(editor, contains('child: SelectionArea('));
    // Record document notifications are debounced rather than dispatched
    // synchronously for every Android keypress. Last edit is flushed on exit.
    expect(editor, contains('_gate.schedule(_syncToBrain);'));
    expect(editor, contains('const Duration(milliseconds: 180)'));
    expect(editor, isNot(contains('      _syncToBrain();')));
    expect(editor, contains('_gate.flush(_syncToBrain, force: true);'));
    expect(record, contains('debounce: const Duration(milliseconds: 1500)'));
    final planning = File(
      'lib/features/shared/planning_task_edit_sheet.dart',
    ).readAsStringSync();
    expect(planning, contains('debounce: const Duration(milliseconds: 1500)'));
    expect(host, contains('return Padding('));
    expect(host, isNot(contains('return AnimatedPadding(')));
  });
}
