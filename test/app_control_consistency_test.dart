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
    });
  }
}
