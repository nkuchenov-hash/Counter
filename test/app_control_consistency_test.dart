import 'package:counter/core/app_control_tokens.dart';
import 'package:counter/core/theme.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/core/widgets/app_text_field.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
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

      // Check the REAL input and FilledButton bounds, not just the 48px
      // wrapper widgets (the original visual mismatch escaped that test).
      final paintedInput = find.descendant(
        of: entryField,
        matching: find.byType(TextField),
      );
      final paintedButton = find.descendant(
        of: actionButton,
        matching: find.byType(FilledButton),
      );
      expect(paintedInput, findsOneWidget);
      expect(paintedButton, findsOneWidget);
      final inputRect = tester.getRect(paintedInput);
      final buttonRect = tester.getRect(paintedButton);
      expect(inputRect.height, AppControlTokens.height);
      expect(buttonRect.height, AppControlTokens.height);
      expect(buttonRect.top, closeTo(inputRect.top, 0.1));
      expect(buttonRect.bottom, closeTo(inputRect.bottom, 0.1));
      expect(buttonRect.left - inputRect.right, AppControlTokens.horizontalGap);

      final inputDecoration = tester.widget<TextField>(paintedInput).decoration!;
      final border = inputDecoration.enabledBorder! as OutlineInputBorder;
      final buttonStyle = tester.widget<FilledButton>(paintedButton).style!;
      final shape = buttonStyle.shape!.resolve(<WidgetState>{})!
          as RoundedRectangleBorder;
      expect(border.borderRadius, BorderRadius.circular(AppControlTokens.radius));
      expect(shape.borderRadius, border.borderRadius);
    });
  }

  testWidgets('search, clear and ordinary text share one AppTextField',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: appLightTheme,
      home: Scaffold(body: AppTextField(
        controller: controller,
        variant: AppTextFieldVariant.search,
        hintText: 'Find a setting',
        clearable: true,
        clearTooltip: 'Clear search',
      )),
    ));
    expect(find.byType(AppTextField), findsOneWidget);
    expect(tester.getSize(find.byType(AppTextField)).height,
        AppControlTokens.height);
    expect(tester.widget<TextField>(find.byType(TextField))
        .decoration!.prefixIcon, isA<Icon>());
    controller.text = 'hello';
    await tester.pump();
    expect(find.byTooltip('Clear search'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(controller.text, isEmpty);
  });

  testWidgets('password, numeric, multiline and validated form are variants',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    Future<void> show(AppTextFieldVariant variant,
        {FormFieldValidator<String>? validator}) async {
      await tester.pumpWidget(MaterialApp(
        theme: appLightTheme,
        home: Scaffold(body: Form(child: AppTextField(
          controller: controller,
          variant: variant,
          validator: validator,
        ))),
      ));
    }
    await show(AppTextFieldVariant.password);
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    await show(AppTextFieldVariant.number);
    expect(tester.widget<TextField>(find.byType(TextField)).keyboardType,
        TextInputType.number);
    await show(AppTextFieldVariant.multiline);
    expect(tester.widget<TextField>(find.byType(TextField)).maxLines, 4);
    expect(tester.getSize(find.byType(AppTextField)).height,
        greaterThanOrEqualTo(AppControlTokens.height));
    await show(AppTextFieldVariant.text, validator: (value) =>
        (value ?? '').isEmpty ? 'Required' : null);
    expect(find.byType(TextFormField), findsOneWidget);
  });
}
