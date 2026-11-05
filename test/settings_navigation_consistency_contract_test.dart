import 'dart:io';

import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Menu owns the settings index without a second desktop navigation rail', () {
    final menu = File('lib/features/profile/menu/life_os_menu_page.dart')
        .readAsStringSync();
    expect(menu, contains('child: AppSettingsPageBody('));
    expect(menu, isNot(contains('_quickTile(')));
    expect(menu, isNot(contains('maxWidth: 680')));
    expect(menu, contains('onTap: () => _openSection(entry.id)'));
    expect(menu, contains('if (!desktop) ...['));
  });

  test('Profile does not reintroduce a parallel settings hub or desktop tabs', () {
    final profile =
        File('lib/features/profile/profile_view.dart').readAsStringSync();
    expect(profile, contains('ProfileSettingsDestination.account'));
    expect(profile, isNot(contains('_buildDesktopSettings(')));
    expect(profile, isNot(contains('_desktopSettingsTab')));
    expect(profile, isNot(contains('_buildMobileSettings(')));
  });

  test('Menu actions open distinct single-purpose settings destinations', () {
    final routes =
        File('lib/app/shell/shared/shell_more_menu.dart').readAsStringSync();
    expect(routes,
        contains('_openProfileDestination(ProfileSettingsDestination.notifications);'));
    expect(routes,
        contains('_openProfileDestination(ProfileSettingsDestination.morning);'));
    expect(routes,
        contains('_openProfileDestination(ProfileSettingsDestination.appearance);'));
    expect(routes,
        contains('_openProfileDestination(ProfileSettingsDestination.timeLocale);'));
  });

  testWidgets('shared settings page remains a readable column on desktop',
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

    final textRect = tester.getRect(find.text('Settings column'));
    expect(textRect.left, greaterThan(160));
    expect(textRect.right, lessThan(1440));
    expect(tester.takeException(), isNull);
  });
}
