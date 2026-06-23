import 'package:counter/core/performance/runtime_flags.dart';
import 'package:flutter/foundation.dart';

/// Debug-only planning duplicate tracing ([wip] P0 dedupe guards).
///
/// **Runtime:** no effect in release. Used by [dedupePlanningTasksForDisplay] when
/// technical duplicates are collapsed — not user-facing behavior.
void planDupTrace(String message) {
  if (kReleaseMode) return;
  debugPrint('[PLAN_DUP_TRACE] $message');
}

/// Throttled planning stream / realtime lifecycle log ([kPlanStreamLifecycleDiag]).
void planStreamLifecycleLog(String message) {
  if (!kPlanStreamLifecycleDiag) return;
  // ignore: avoid_print
  print('[PLAN_STREAM_LIFECYCLE] $message');
}
