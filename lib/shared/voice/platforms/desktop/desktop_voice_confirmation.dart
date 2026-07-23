import 'package:counter/core/app_snackbar.dart';
import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_overlay_host.dart';
import 'package:counter/services/notification_service.dart';

/// Visible start/stop feedback — overlay confirmation mandatory; AppSnack only when main window visible.
abstract final class DesktopVoiceConfirmation {
  static Future<void> showRecordStarted(String message) async {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_CONFIRMATION_SHOWN');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OS_NOTIFICATION_REQUESTED');
    final ok = await NotificationService.instance.showDesktopVoiceRecordStarted(
      message: message,
    );
    if (!ok) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_OS_NOTIFICATION_FAILED');
    }
    final windowVisible = await DesktopVoiceOverlayHost.isMainWindowVisible();
    if (windowVisible && !DesktopVoiceOverlayHost.isShellSuppressed) {
      AppSnack.show(message);
      DesktopVoicePipeline.mark('DESKTOP_VOICE_FALLBACK_SNACK_SHOWN');
    }
  }

  static Future<void> showRecordStopped(String message) async {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_STOP_CONFIRMATION_SHOWN');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OS_NOTIFICATION_REQUESTED');
    final ok = await NotificationService.instance.showDesktopVoiceRecordStopped(
      message: message,
    );
    if (!ok) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_OS_NOTIFICATION_FAILED');
    }
    final windowVisible = await DesktopVoiceOverlayHost.isMainWindowVisible();
    if (windowVisible && !DesktopVoiceOverlayHost.isShellSuppressed) {
      AppSnack.show(message);
      DesktopVoicePipeline.mark('DESKTOP_VOICE_FALLBACK_SNACK_SHOWN');
    }
  }
}
