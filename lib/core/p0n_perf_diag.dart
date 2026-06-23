import 'package:flutter/foundation.dart';

/// P0N: minimal performance diagnostics (profile/debug APK only).
abstract final class P0NPerfDiag {
  static void timelineCacheRestore({
    required int flatRecords,
    required int ms,
    required String source,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[TIMELINE_CACHE_RESTORE] flatRecords=$flatRecords ms=$ms source=$source',
    );
  }

  static void timelineDayIndexReady({
    required int days,
    required int records,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[TIMELINE_DAY_INDEX_READY] days=$days records=$records ms=$ms',
    );
  }

  static void timelineDayLookup({
    required String date,
    required String state,
    required int count,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[TIMELINE_DAY_LOOKUP] date=$date state=$state count=$count ms=$ms',
    );
    if (ms > 100) {
      debugPrint(
        '[TIMELINE_DAY_LOOKUP_SLOW] date=$date ms=$ms reason=lookup',
      );
    }
  }

  static void timelineCacheRefreshMerge({
    required int before,
    required int after,
    required bool keptLocal,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[TIMELINE_CACHE_REFRESH_MERGE] before=$before after=$after '
      'keptLocal=$keptLocal',
    );
  }

  static void plansSwipePhysics({
    required String using,
    required String oldThreshold,
    required String newThreshold,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[PLANS_SWIPE_PHYSICS] using=$using oldThreshold=$oldThreshold '
      'newThreshold=$newThreshold',
    );
  }

  static void plansSwipeDistance({
    required double dx,
    required double vx,
    required bool commit,
    required String threshold,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[PLANS_SWIPE_DISTANCE] dx=$dx vx=$vx commit=$commit threshold=$threshold',
    );
  }

  static void plansSwipeCommit({
    required String direction,
    required String date,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[PLANS_SWIPE_COMMIT] direction=$direction date=$date',
    );
  }

  static void plansRenderBudget({
    required String date,
    required int tasks,
    required int buildMs,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[PLANS_RENDER_BUDGET] date=$date tasks=$tasks buildMs=$buildMs',
    );
    if (buildMs > 16) {
      debugPrint(
        '[PLANS_RENDER_SLOW] date=$date reason=adjacentBody ms=$buildMs',
      );
    }
  }
}
