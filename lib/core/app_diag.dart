import 'package:flutter/foundation.dart';

/// Debug-only diagnostics (TIME_*, PERF_*). Silent in release web/APK.
void appDebugDiag(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print(message);
  }
}
