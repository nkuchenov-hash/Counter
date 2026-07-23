import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_settings.dart';

/// Structured hotkey registration markers for smoke scripts.
abstract final class DesktopVoiceHotkeyMarkers {
  static void logRegistration({required bool ok, String? error}) {
    final combo = DesktopVoiceSettings.instance.hotkey.displayLabel;
    if (ok) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_HOTKEY_REGISTERED',
        'yes combo=$combo',
      );
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HOTKEY_REGISTERED_COMBO', combo);
    } else {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_HOTKEY_REGISTER_FAILED',
        error ?? combo,
      );
    }
  }
}
