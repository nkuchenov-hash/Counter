import 'dart:io';

import 'package:counter/shared/voice/platforms/desktop/desktop_voice_dev_tools.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Desktop voice release UI gating', () {
    test('dev tools hidden unless debug or dart-define', () {
      expect(DesktopVoiceDevTools.visible, kDebugMode);
    });

    test('more menu diagnostics source gates dev entry', () {
      final src = File('lib/app/shell/shared/shell_more_menu.dart').readAsStringSync();
      expect(src.contains('DESKTOP_VOICE_MORE_MENU_DIAGNOSTICS_REMOVED'), isTrue);
      expect(src.contains('_desktopVoiceDevDiagnosticsVisible'), isTrue);
      expect(src.contains('DESKTOP_VOICE_DEV_ENTRY_GATED'), isTrue);
    });

    test('settings desktop gates simulate/test buttons', () {
      final src = File('lib/features/settings/voice/desktop_voice_settings_desktop.dart')
          .readAsStringSync();
      expect(src.contains('DesktopVoiceDevTools.visible'), isTrue);
      expect(src.contains('DESKTOP_VOICE_RELEASE_DEV_BUTTONS_HIDDEN'), isTrue);
      expect(src.contains('desktop_voice_copy_diagnostics'), isTrue);
      expect(src.contains('if (devButtonsVisible)'), isTrue);
    });
  });
}
