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
}
