import 'package:counter/core/p0u_feature_flags.dart';
import 'package:flutter/foundation.dart';

/// P0U production-safe markers only (release guard, errors, kill-switch notices).
///
/// **Do not re-add** per-frame/swipe/vm-build spam here. Boot timing lives in
/// [P0uStartupDiag]. Feature kill switches live in [p0u_feature_flags.dart].
abstract final class P0uDiag {
  static bool _adjVmWarmDisabledLogged = false;

  /// Once per session when adjacent row-VM warmup kill switch is off.
  static void logAdjVmWarmDisabledIfNeeded() {
    if (kTimelineAdjacentRowVmWarmup || _adjVmWarmDisabledLogged) return;
    _adjVmWarmDisabledLogged = true;
    debugPrint('[P0U_TIMELINE_ADJ_VM_WARM_DISABLED] reason=killSwitch');
  }

  static void p0tDisabled({required String platform, required bool enabled}) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0U_P0T_DISABLED] platform=$platform enabled=$enabled',
    );
  }

  static void webError({required Object exception, String? stackTop}) {
    debugPrint(
      '[P0U_WEB_ERROR] exception=$exception stackTop=${stackTop ?? '—'}',
    );
  }

  static void androidError({required Object exception, String? stackTop}) {
    debugPrint(
      '[P0U_ANDROID_ERROR] exception=$exception stackTop=${stackTop ?? '—'}',
    );
  }

  static void releaseLogGuard({bool ok = true}) {
    debugPrint('[P0U_RELEASE_LOG_GUARD] ok=$ok');
  }

  static void biometricGate({required bool enabled, required String reason}) {
    debugPrint('[P0U_BIOMETRIC_GATE] enabled=$enabled reason=$reason');
  }
}
