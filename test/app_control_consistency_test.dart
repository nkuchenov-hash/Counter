import 'package:counter/core/app_control_tokens.dart';
import 'package:counter/core/theme.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/core/widgets/app_text_field.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/features/settings/categories/category_tag_input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all standard control components use one geometry source', () {
    expect(AppTextField.height, AppControlTokens.height);
    expect(AppTextField.radius, AppControlTokens.radius);
    expect(kAppQuickEntryControlHeight, AppControlTokens.height);
    expect(AppControlTokens.height, 48);
    expect(AppControlTokens.fontSize, 16);
  });

  for (final dark in <bool>[false, true]) {
    testWidgets('quick-entry field, search and neighboring buttons align in '
        '${dark ? 'dark' : 'light'} mode', (tester) async {
      final entry = TextEditingController();
      final search = TextEditingController();
      final entryFocus = FocusNode();
      final searchFocus = FocusNode();
      addTearDown(() {
        entry.dispose();
        search.dispose();
        entryFocus.dispose();
        searchFocus.dispose();
      });

      await tester.pumpWidget(MaterialApp(
        theme: dark ? appDarkTheme : appLightTheme,
        home: Scaffold(
          body: SizedBox(
            width: 650,
            child: Column(
              children: [
                AppQuickEntryRow(
                  controller: entry,
                  focusNode: entryFocus,
                  hintText: 'Add a record',
                  actionLabel: 'Start',
                  actionIcon: Icons.play_arrow,
                  onAction: () {},
                ),
                Row(children: [
                  Expanded(child: AppTextField(
                    controller: search,
                    focusNode: searchFocus,
                    hintText: 'Search categories',
                    showSearchIcon: true,
                    textInputAction: TextInputAction.search,
                  )),
                  const SizedBox(width: AppControlTokens.horizontalGap),
                  AppIconButton(
                    tooltip: 'Expand',
                    icon: Icons.unfold_more,
                    onPressed: () {},
                  ),
                ]),
              ],
            ),
          ),
        ),
      ));

      final entryField = find.descendant(
        of: find.byType(AppQuickEntryRow),
        matching: find.byType(AppTextField),
      );
      final actionButton = find.descendant(
        of: find.byType(AppQuickEntryRow),
        matching: find.byType(AppButton),
      );
      expect(tester.getSize(entryField).height, AppControlTokens.height);
      expect(tester.getSize(actionButton).height, AppControlTokens.height);
      expect(tester.getSize(find.byType(AppTextField).last).height,
          AppControlTokens.height);
      expect(tester.getSize(find.byType(AppIconButton)).height,
          AppControlTokens.height);

      // Compare the actual visual controls, not just their sized wrappers.
      final paintedField = find.descendant(
        of: entryField,
        matching: find.byType(InputDecorator),
      );
      final paintedButton = find.descendant(
        of: actionButton,
        matching: find.byType(FilledButton),
      );
      final fieldRect = tester.getRect(paintedField);
      final buttonRect = tester.getRect(paintedButton);
      expect(fieldRect.height, AppControlTokens.height);
      expect(buttonRect.height, AppControlTokens.height);
      expect(buttonRect.top, fieldRect.top);
      expect(buttonRect.bottom, fieldRect.bottom);
      final outline = tester.widget<InputDecorator>(paintedField)
          .decoration.border as OutlineInputBorder;
      expect(outline.borderRadius, BorderRadius.circular(AppControlTokens.radius));
      final filled = tester.widget<FilledButton>(paintedButton);
      final shape = filled.style?.shape?.resolve({});
      expect(filled.style?.maximumSize?.resolve({})?.height, AppControlTokens.height);
      expect(shape, isA<RoundedRectangleBorder>());
      expect((shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(AppControlTokens.radius));
    });
  }

  testWidgets('tag input and its adjacent Add button share painted geometry',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: appLightTheme,
      home: const Scaffold(body: SizedBox(
        width: 390,
        child: TagInputField(tags: [], onChanged: _noopTagChanged),
      )),
    ));
    final field = find.descendant(
      of: find.byType(TagInputField),
      matching: find.byType(AppTextField),
    );
    final button = find.descendant(
      of: find.byType(TagInputField),
      matching: find.byType(AppButton),
    );
    final fieldRect = tester.getRect(find.descendant(
      of: field, matching: find.byType(InputDecorator)));
    final buttonRect = tester.getRect(find.descendant(
      of: button, matching: find.byType(FilledButton)));
    expect(fieldRect.height, AppControlTokens.height);
    expect(buttonRect.height, AppControlTokens.height);
    expect(fieldRect.top, buttonRect.top);
    expect(fieldRect.bottom, buttonRect.bottom);
    expect(tester.takeException(), isNull);
  });

  testWidgets('email, password, numeric, search, multiline and validation '
      'use the same canonical field', (tester) async {
    final controllers = List.generate(6, (_) => TextEditingController());
    addTearDown(() {
      for (final c in controllers) {
        c.dispose();
      }
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          child: SingleChildScrollView(
            child: Column(children: [
              AppTextField(controller: controllers[0],
                  variant: AppTextFieldVariant.email,
                  labelText: 'Email', hintText: 'mail@example.com'),
              AppTextField(controller: controllers[1],
                  variant: AppTextFieldVariant.password),
              AppTextField(controller: controllers[2],
                  variant: AppTextFieldVariant.number),
              AppTextField(controller: controllers[3],
                  variant: AppTextFieldVariant.search),
              AppTextField(controller: controllers[4],
                  variant: AppTextFieldVariant.multiline),
              AppTextField(controller: controllers[5],
                  validator: (value) => value!.isEmpty ? 'Required' : null),
            ]),
          ),
        ),
      ),
    ));
    expect(find.byType(AppTextField), findsNWidgets(6));
    expect(find.byType(TextFormField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).at(1)).obscureText, isTrue);
    expect(tester.widget<TextField>(find.byType(TextField).at(2)).keyboardType,
        TextInputType.number);
    expect(tester.widget<TextField>(find.byType(TextField).at(0)).keyboardType,
        TextInputType.emailAddress);
    expect(tester.widget<TextField>(find.byType(TextField).at(4)).maxLines, 6);
    expect(tester.takeException(), isNull);
  });
}

void _noopTagChanged(List<String> tags) {}
