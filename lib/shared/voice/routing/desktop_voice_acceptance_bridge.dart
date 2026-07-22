/// Installed-app deterministic command acceptance (bypasses STT; same writeRecord path).
abstract final class DesktopVoiceAcceptanceBridge {
  /// Returns true when a running record was started successfully.
  static Future<bool> Function(String transcript)? runCommand;

  /// Invokes the same handler as the global desktop voice hotkey.
  static void Function()? simulateHotkeyToggle;
}
