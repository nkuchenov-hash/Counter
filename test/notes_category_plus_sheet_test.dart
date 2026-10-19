import 'dart:async';

import 'package:counter/features/notes/widgets/notes_category_plus_sheet.dart';
import 'package:counter/shared/categories/picker/create_category_from_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => categoryCreateFromPickerAllowedOverride = () => true);
  tearDown(() => categoryCreateFromPickerAllowedOverride = null);
  testWidgets('Notes plus offers selecting existing or creating new category', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(showNotesAddFolderSheet(
              context,
              currentCategoryIds: <int>{},
            )),
            child: const Text('Open categories'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open categories'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notes_add_existing_category')), findsOneWidget);
    expect(find.byKey(const ValueKey('notes_create_new_category')), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
  });
}
