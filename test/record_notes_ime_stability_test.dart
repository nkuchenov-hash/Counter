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
