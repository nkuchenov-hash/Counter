import 'dart:io';

import 'package:counter/data/models.dart';
import 'package:counter/features/notes/widgets/notes_canonical_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    expect(record, contains('final notesEditing = _notesEditorFocused;'));
    expect(host, contains('return Padding('));
    expect(host, isNot(contains('return AnimatedPadding(')));
  });
}
