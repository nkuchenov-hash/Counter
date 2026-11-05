import 'dart:io';

import 'package:counter/core/app_colors.dart';
import 'package:counter/core/theme.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:counter/app/shell/shared/shell_form_factor.dart';
import 'package:counter/core/shell_adaptive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shellFormFactorForWidth', () {
    test('phone below calendar-pill compact band', () {
      expect(shellFormFactorForWidth(390), ShellFormFactor.phone);
      expect(shellFormFactorForWidth(kCalendarEventPillBreakpoint - 1),
          ShellFormFactor.phone);
    });

    test('tablet mid-width still uses compact chrome band', () {
      expect(shellFormFactorForWidth(kCalendarEventPillBreakpoint),
          ShellFormFactor.tablet);
      expect(shellFormFactorForWidth(800), ShellFormFactor.tablet);
      expect(shellFormFactorForWidth(kShellDesktopNavBreakpoint - 1),
          ShellFormFactor.tablet);
    });

    test('desktop at side-nav breakpoint', () {
      expect(shellFormFactorForWidth(kShellDesktopNavBreakpoint),
          ShellFormFactor.desktop);
      expect(shellFormFactorForWidth(1200), ShellFormFactor.desktop);
    });

    test('desktop selection matches shellUsesSideNavigation', () {
      for (final width in <double>[320, 599, 600, 899, 900, 1400]) {
        final factor = shellFormFactorForWidth(width);
        final sideNav = shellUsesSideNavigation(width);
        expect(factor == ShellFormFactor.desktop, sideNav,
            reason: 'width=$width');
      }
    });
  });

  group('single settings navigation', () {
    test('Menu uses one shared settings index without a second rail', () {
      final menu = File('lib/features/profile/menu/life_os_menu_page.dart')
          .readAsStringSync();
      expect(menu, contains('child: AppSettingsPageBody('));
      expect(menu, isNot(contains('_quickTile(')));
      expect(menu, isNot(contains('maxWidth: 680')));
      expect(menu, contains('onTap: () => _openSection(entry.id)'));
      expect(menu, contains('if (!desktop) ...['));
    });

    test('Profile never opens a parallel desktop settings hub', () {
      final profile =
          File('lib/features/profile/profile_view.dart').readAsStringSync();
      expect(profile, contains('ProfileSettingsDestination.account'));
      expect(profile, isNot(contains('_buildDesktopSettings(')));
      expect(profile, isNot(contains('_desktopSettingsTab')));
      expect(profile, isNot(contains('_buildMobileSettings(')));
    });

    test('specific settings use their own destinations', () {
      final routes =
          File('lib/app/shell/shared/shell_more_menu.dart').readAsStringSync();
      for (final destination in <String>[
        'notifications', 'morning', 'appearance', 'timeLocale',
      ]) {
        expect(
          routes,
          contains(
            '_openProfileDestination(ProfileSettingsDestination.$destination);',
          ),
        );
      }
    });

    test('People stays inside the main shell instead of hiding the sidebar', () {
      final chrome = File('lib/app/shell/shared/shell_chrome.dart')
          .readAsStringSync();
      final routes = File('lib/app/shell/shared/shell_more_menu.dart')
          .readAsStringSync();
      final sidebar = File('lib/app/shell/desktop/shell_side_navigation.dart')
          .readAsStringSync();
      expect(chrome, contains('PeopleSettingsPage('));
      expect(chrome, contains('activeTab: shellPageIndexListenable'));
      expect(routes, contains('peopleDestination = PeopleSettingsDestination.people;'));
      expect(routes, contains('peopleDestination = PeopleSettingsDestination.sources;'));
      expect(routes, contains('setShellPageIndex(8)'));
      expect(routes, isNot(contains('builder: (_) => const PeopleSettingsPage(')));
      expect(sidebar, contains('AppMenuIconRole.people'));
      expect(routes, contains('|| 8 => shellPageIndex'));
    });

    test('Menu uses the same persistent desktop header as People', () {
      final chrome = File('lib/app/shell/shared/shell_chrome.dart')
          .readAsStringSync();
      expect(chrome, contains('appBar: desktopShell ||'));
      expect(chrome, isNot(contains('desktopShell && shellPageIndex != 7')));
    });

    test('Embedded People screen has contextual Back without taking over the app', () {
      final people = File('lib/features/settings/people/people_settings_page_impl.dart')
          .readAsStringSync();
      expect(people, contains('final VoidCallback? onBackToMenu;'));
      expect(people, contains('appBar: embeddedInShell && desktop ? null : AppBar('));
      expect(people, contains('canPop: selectedTab != 8'));
      expect(people, contains('if (!didPop && selectedTab == 8)'));
    });

    testWidgets('settings use neutral gray not blue and clear white cards',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          final scheme = settingsNeutralTheme(context).colorScheme;
          expect(scheme.surface, const Color(0xFFF2F2F2));
          expect(scheme.surfaceContainerLowest, const Color(0xFFF2F2F2));
          expect(scheme.surfaceContainerHigh, AppColors.cardSurface);
          expect(scheme.surfaceContainer, const Color(0xFFF1F1F1));
          return const SizedBox.shrink();
        }),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('menu rows distinguish names from secondary captions',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: appLightTheme,
        home: Builder(builder: (context) => Theme(
          data: settingsNeutralTheme(context),
          child: Scaffold(body: AppSettingsNavigationRow(
            title: 'Notifications',
            subtitle: 'Quiet reminders and alerts',
            onTap: () {},
          )),
        )),
      ));
      final title = tester.widget<Text>(find.text('Notifications'));
      final subtitle = tester.widget<Text>(find.text('Quiet reminders and alerts'));
      expect(title.style?.fontWeight, FontWeight.w400);
      expect(subtitle.style?.fontWeight, FontWeight.w400);
      expect(subtitle.style?.color, const Color(0xFF818181));
      expect((title.style?.fontSize ?? 0) > (subtitle.style?.fontSize ?? 0), isTrue);
      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.hoverColor, const Color(0xFFF5F5F5));
      expect(tile.splashColor, Colors.transparent);
      expect(tester.takeException(), isNull);
    });

    test('global typography uses bundled Onest in both themes', () {
      expect(appLightTheme.textTheme.bodyLarge?.fontFamily, 'Onest');
      expect(appDarkTheme.textTheme.bodyLarge?.fontFamily, 'Onest');
    });

    test('desktop brand, sidebar and Profile stay in one shell', () {
      final chrome = File('lib/app/shell/shared/shell_chrome.dart')
          .readAsStringSync();
      final sidebar = File('lib/app/shell/desktop/shell_side_navigation.dart')
          .readAsStringSync();
      final routes = File('lib/app/shell/shared/shell_more_menu.dart')
          .readAsStringSync();
      expect(chrome, contains("desktopShell ? 'LIFE OS'"));
      expect(chrome, contains("initialSection: 'account'"));
      expect(chrome, contains('embeddedInShell: true'));
      expect(sidebar, contains('Color(0xFFECECEC)'));
      expect(sidebar, isNot(contains("'LIFE OS'")));
      expect(routes, contains('setShellPageIndex(9)'));
      expect(routes, contains('9 => 5,'));
    });

    test('menu items own their full-width hover, not the parent card', () {
      final layout = File('lib/core/widgets/app_settings_layout.dart')
          .readAsStringSync();
      expect(layout, contains('class AppSettingsNavigationGroup extends StatelessWidget'));
      expect(layout, contains('clipBehavior: Clip.antiAlias'));
      expect(layout, contains('borderRadius: BorderRadius.circular(20)'));
      expect(layout, contains('const Color(0xFFF5F5F5)'));
      expect(layout, contains('class _AppSettingsRowPosition extends InheritedWidget'));
      expect(layout, isNot(contains('onEnter: (_) => setState(() => _hovered = true)')));
      expect(layout, isNot(contains('Color(0xFFB6B6B6)')));
    });

    testWidgets('card has equal visual outer spacing, no strokes, soft dividers',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: appLightTheme,
        home: Builder(builder: (context) => Theme(
          data: settingsNeutralTheme(context),
          child: Scaffold(body: AppSettingsNavigationGroup(children: [
            AppSettingsNavigationRow(
              title: 'First item',
              leading: const AppSettingsMenuIcon(icon: Icons.alarm),
              onTap: () {},
            ),
            AppSettingsNavigationRow(
              title: 'Second item',
              leading: const AppSettingsMenuIcon(icon: Icons.person),
              onTap: () {},
            ),
          ])),
        )),
      ));
      final group = find.byType(AppSettingsNavigationGroup);
      final material = find.descendant(
          of: group, matching: find.byType(Material)).first;
      expect(tester.widget<Material>(material).color, Colors.white);
      expect(tester.widget<Material>(material).shape, isNull);
      final divider = tester.widget<Divider>(
          find.descendant(of: group, matching: find.byType(Divider)).first);
      expect(divider.color, const Color(0xFFE7E7E7));
      expect(divider.thickness, 0.8);

      final cardRect = tester.getRect(material);
      final iconRects = find.descendant(
          of: group, matching: find.byType(AppSettingsMenuIcon));
      final firstIcon = tester.getRect(iconRects.first);
      final lastIcon = tester.getRect(iconRects.last);
      final left = firstIcon.left - cardRect.left;
      final top = firstIcon.top - cardRect.top;
      final bottom = cardRect.bottom - lastIcon.bottom;
      expect(left, closeTo(24, 2));
      expect(top, closeTo(left, 5));
      expect(bottom, closeTo(left, 5));

      final tiles = find.descendant(of: group, matching: find.byType(ListTile));
      for (final tile in tester.widgetList<ListTile>(tiles)) {
        expect(tile.hoverColor, const Color(0xFFF5F5F5));
        expect(tile.shape, const RoundedRectangleBorder());
      }
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      await pointer.moveTo(tester.getCenter(find.text('Second item')));
      await tester.pump();
      // Hovering one item never paints the entire white card.
      expect(tester.widget<Material>(material).color, Colors.white);
      await pointer.removePointer();
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings stay within a readable desktop content column',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppSettingsPageBody(
              children: [Text('Settings column')],
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.text('Settings column'));
      expect(rect.left, greaterThan(160));
      expect(rect.right, lessThan(1440));
      expect(tester.takeException(), isNull);
    });
  });
}
