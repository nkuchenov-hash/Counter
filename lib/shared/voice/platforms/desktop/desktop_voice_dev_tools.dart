import 'package:flutter/foundation.dart' show kDebugMode;

/// Release-safe gate for Desktop Voice developer / acceptance tooling.
abstract final class DesktopVoiceDevTools {
  static const bool devToolsDefine = bool.fromEnvironment(
    'DESKTOP_VOICE_DEV_TOOLS',
    defaultValue: false,
  );

  static bool get visible => kDebugMode || devToolsDefine;
}
