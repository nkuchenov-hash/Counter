import 'package:flutter/foundation.dart';

final ValueNotifier<bool> desktopVoiceShellSuppressed = ValueNotifier(false);

Future<void> activateDesktopVoiceOverlayHost() async {}

Future<void> deactivateDesktopVoiceOverlayHost() async {}

Future<bool> isDesktopMainWindowVisible() async => true;

Future<bool> canShowInAppVoiceOverlay() async => true;

Future<void> notifyTrayOverlayUnavailable() async {}
