import 'package:flutter/foundation.dart';

/// Debug-only Time View drop tracing (not enabled in release).
void timeDropTrace(String message) {
  if (kReleaseMode) return;
  debugPrint('[TIME_DROP_TRACE] $message');
}
