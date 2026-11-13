import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phone settings header covers Android status bar with one feathered surface', () {
    final main = File('lib/main.dart').readAsStringSync();
    final shell = File('lib/app/shell/shared/shell_chrome.dart')
        .readAsStringSync();
    final settings = File(
      'lib/features/profile/menu/life_os_settings_tabs_page.dart',
    ).readAsStringSync();

    expect(main, contains('SystemUiMode.edgeToEdge'));
    expect(shell, contains('statusBarColor: AppNeutralTones.transparent'));
    expect(shell, contains('systemStatusBarContrastEnforced: false'));
    expect(shell, isNot(contains('SafeArea(top: true, bottom: false, child: mainColumn)')));
    expect(settings, contains('height: topInset + 114'));
    expect(settings, contains('topInset + 12'));
    expect(settings, contains('100 + MediaQuery.viewPaddingOf(context).top'));
    expect(settings, contains('fadeClear'));
    expect(settings, contains('158 + bottomInset'));
  });
}
