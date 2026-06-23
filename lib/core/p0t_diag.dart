import 'package:flutter/foundation.dart';

/// P0T emergency stabilization diagnostics.
abstract final class P0tDiag {
  static void crashTrace({
    required String screen,
    required Object exception,
    String? topFrame,
  }) {
    debugPrint(
      '[P0T_CRASH_TRACE] screen=$screen exception=$exception '
      'topFrame=${topFrame ?? '—'}',
    );
  }

  static void crashRootCause(String cause) {
    debugPrint('[P0T_CRASH_ROOT_CAUSE] cause=$cause');
  }

  static void crashFixed({bool ok = true}) {
    debugPrint('[P0T_CRASH_FIXED] ok=$ok');
  }

  static void biometricGate({
    required bool enabled,
    String? reason,
    int? lastUnlockDays,
    bool? supported,
    bool? enrolled,
    bool? shown,
  }) {
    debugPrint(
      '[P0T_BIOMETRIC_GATE] enabled=$enabled '
      'reason=${reason ?? '—'} '
      'lastUnlockDays=${lastUnlockDays ?? '—'} '
      'supported=${supported ?? '—'} '
      'enrolled=${enrolled ?? '—'} '
      'shown=${shown ?? '—'}',
    );
  }

  static void readyCheck({
    required String screen,
    required String date,
    required bool ready,
    int? cards,
    String missing = 'none',
  }) {
    debugPrint(
      '[P0T_READY_CHECK] screen=$screen date=$date ready=$ready '
      'cards=${cards ?? '—'} missing=$missing',
    );
  }

  static void pageRevealAllowed({
    required String screen,
    required String date,
    required bool ready,
    required bool mounted,
  }) {
    debugPrint(
      '[P0T_PAGE_REVEAL_ALLOWED] screen=$screen date=$date '
      'ready=$ready mounted=$mounted',
    );
  }

  static void pageRevealBlocked({
    required String screen,
    required String date,
    required String reason,
    String missing = '—',
  }) {
    debugPrint(
      '[P0T_PAGE_REVEAL_BLOCKED] screen=$screen date=$date '
      'reason=$reason missing=$missing',
    );
  }

  static void criticalReadyStart({
    required String screen,
    required String dates,
  }) {
    debugPrint('[P0T_CRITICAL_READY_START] screen=$screen dates=$dates');
  }

  static void criticalReadyDone({
    required String screen,
    required int ready,
    required int total,
    required int ms,
  }) {
    debugPrint(
      '[P0T_CRITICAL_READY_DONE] screen=$screen ready=$ready/$total ms=$ms',
    );
  }

  static void plansCardAtomic({
    required String date,
    required String card,
    required bool hasPlay,
    required bool tagsReady,
    required bool categoryReady,
  }) {
    debugPrint(
      '[P0T_PLANS_CARD_ATOMIC] date=$date card=$card '
      'hasPlay=$hasPlay tagsReady=$tagsReady categoryReady=$categoryReady',
    );
  }

  static void plansDoubleLoadRemoved({bool ok = true}) {
    debugPrint('[P0T_PLANS_DOUBLE_LOAD_REMOVED] ok=$ok');
  }

  static void diskRestore({
    required String screen,
    required int renderSnapshots,
    required int metadata,
    required int ms,
  }) {
    debugPrint(
      '[P0T_DISK_RESTORE] screen=$screen renderSnapshots=$renderSnapshots '
      'metadata=$metadata ms=$ms',
    );
  }

  static void diskSave({
    required String screen,
    required int renderSnapshots,
    required int ms,
  }) {
    debugPrint(
      '[P0T_DISK_SAVE] screen=$screen renderSnapshots=$renderSnapshots ms=$ms',
    );
  }

  static void startupStage({required String name, required int ms}) {
    debugPrint('[P0T_STARTUP_STAGE] name=$name ms=$ms');
  }

  static void startupSlow({required String stage, required int ms}) {
    debugPrint('[P0T_STARTUP_SLOW] stage=$stage ms=$ms');
  }

  static void timelineSwipePhysics({
    required String threshold,
    required String velocity,
  }) {
    debugPrint(
      '[P0T_TIMELINE_SWIPE_PHYSICS] threshold=$threshold velocity=$velocity',
    );
  }

  static void timelineSwipeCommit({
    required String direction,
    required String date,
  }) {
    debugPrint(
      '[P0T_TIMELINE_SWIPE_COMMIT] direction=$direction date=$date',
    );
  }

  static void memory({
    required String screen,
    required int mountedBodies,
    required int renderSnapshots,
    required int approxKb,
  }) {
    debugPrint(
      '[P0T_MEMORY] screen=$screen mountedBodies=$mountedBodies '
      'renderSnapshots=$renderSnapshots approxKb=$approxKb',
    );
  }

  static void p0sSuperseded({required String reason}) {
    debugPrint('[P0T_P0S_SUPERSEDED] reason=$reason');
  }
}
