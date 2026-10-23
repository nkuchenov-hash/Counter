import 'dart:async';

import 'package:counter/features/notes/widgets/notes_category_plus_sheet.dart';
import 'package:counter/shared/categories/picker/category_tree_picker.dart';
import 'package:counter/shared/categories/picker/create_category_from_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => categoryCreateFromPickerAllowedOverride = () => true);
  tearDown(() => categoryCreateFromPickerAllowedOverride = null);
  testWidgets('Notes plus opens category tree directly with creation controls', (tester) async {
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

    // No preliminary choice of existing vs create: the tree is immediately
    // visible with root/child creation chrome in the same modal.
    expect(find.byKey(const ValueKey('notes_add_existing_category')), findsNothing);
    expect(find.byKey(const ValueKey('notes_create_new_category')), findsNothing);
    expect(find.byKey(categoryPickerTopAddKey), findsOneWidget);
    expect(find.byKey(categoryPickerBottomAddKey), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
  });
}
