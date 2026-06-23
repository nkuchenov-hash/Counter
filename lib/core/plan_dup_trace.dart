import 'package:flutter/foundation.dart';

/// Debug-only planning duplicate tracing (not enabled in release).
void planDupTrace(String message) {
  if (kReleaseMode) return;
  debugPrint('[PLAN_DUP_TRACE] $message');
}
