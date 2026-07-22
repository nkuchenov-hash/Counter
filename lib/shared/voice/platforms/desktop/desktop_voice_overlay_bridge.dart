import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';

/// Hotkey ↔ desktop voice overlay bridge (finish-listening + cancel).
abstract final class DesktopVoiceOverlayBridge {
  static bool Function()? _isListening;
  static bool Function()? _isPreparing;
  static bool Function()? _isProcessing;
  static void Function()? _finishListening;
  static void Function()? _cancelSession;
  static void Function()? _onOverlayClosed;

  static bool get isOpen => _isOpen;
  static bool _isOpen = false;

  static bool get isListening => _isListening?.call() ?? false;
  static bool get isPreparing => _isPreparing?.call() ?? false;
  static bool get isProcessing => _isProcessing?.call() ?? false;

  static void bindSession({
    required bool Function() isListening,
    required bool Function() isPreparing,
    required bool Function() isProcessing,
    required void Function() finishListening,
    required void Function() cancelSession,
    void Function()? onOverlayClosed,
  }) {
    _isListening = isListening;
    _isPreparing = isPreparing;
    _isProcessing = isProcessing;
    _finishListening = finishListening;
    _cancelSession = cancelSession;
    _onOverlayClosed = onOverlayClosed;
    _isOpen = true;
  }

  static void clearSession() {
    _isListening = null;
    _isPreparing = null;
    _isProcessing = null;
    _finishListening = null;
    _cancelSession = null;
    _onOverlayClosed = null;
    _isOpen = false;
  }

  static void notifyOverlayClosed() {
    _onOverlayClosed?.call();
    clearSession();
  }

  /// State B: second hotkey while listening → finish capture and parse.
  static bool requestFinishListening() {
    if (!isOpen || !isListening) return false;
    _finishListening?.call();
    return true;
  }

  /// Cancel overlay from X / Escape / hotkey during preparing or error.
  static bool requestCancel() {
    if (!isOpen) return false;
    DesktopVoicePipeline.mark('DESKTOP_VOICE_CANCEL_REQUESTED');
    _cancelSession?.call();
    return true;
  }
}
