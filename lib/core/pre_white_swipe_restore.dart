import 'package:flutter/foundation.dart';

/// Minimal date-swipe diagnostics after pre-white-design PageView restore.
abstract final class PreWhiteSwipeRestoreDiag {
  static void log({
    required String screen,
    required String event,
    required String date,
  }) {
    if (!kReleaseMode) {
      debugPrint(
        '[PRE_WHITE_SWIPE_RESTORE] screen=$screen event=$event date=$date',
      );
    }
  }
}
