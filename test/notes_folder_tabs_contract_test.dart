import 'package:counter/features/notes/widgets/notes_folder_pane.dart';
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
