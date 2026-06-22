import 'package:flutter/foundation.dart';

/// Debounced debug-only diagnostics for P0 date navigation (removed in release).
abstract final class P0DateNavDiag {
  static String? _lastLine;
  static int _lastMs = 0;

  static void log(String tag, String message) {
    if (!kDebugMode) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final line = '[$tag] $message';
    if (line == _lastLine && now - _lastMs < 450) return;
    _lastLine = line;
    _lastMs = now;
    debugPrint(line);
  }

  static void timelineDateNav(String message) =>
      log('P0_TIMELINE_DATE_NAV', message);

  static void timelineBuild(String message) => log('P0_TIMELINE_BUILD', message);

  static void plansDateNav(String message) => log('P0_PLANS_DATE_NAV', message);

  static void plansSwipe(String message) => log('P0_PLANS_SWIPE', message);

  static void crashGuard(String message) => log('P0_CRASH_GUARD', message);
}
