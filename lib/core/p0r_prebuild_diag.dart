import 'package:flutter/foundation.dart';

/// P0R: critical adjacent prebuild + persistent warm snapshot diagnostics.
abstract final class P0RPrebuildDiag {
  static void bootAdjacentReady({
    required String screen,
    required String date,
    required bool dataReady,
    required bool bodyReady,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0R_BOOT_ADJACENT_READY] screen=$screen date=$date '
      'dataReady=$dataReady bodyReady=$bodyReady',
    );
  }

  static void firstSwipeTarget({
    required String screen,
    required String targetDate,
    required bool dataReady,
    required bool bodyReady,
    required bool cacheHit,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0R_FIRST_SWIPE_TARGET] screen=$screen targetDate=$targetDate '
      'dataReady=$dataReady bodyReady=$bodyReady cacheHit=$cacheHit',
    );
  }

  static void criticalStart({
    required String screen,
    required String dates,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0R_PREBUILD_CRITICAL_START] screen=$screen dates=$dates',
    );
  }

  static void criticalDone({
    required String screen,
    required int count,
    required int totalMs,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0R_PREBUILD_CRITICAL_DONE] screen=$screen count=$count totalMs=$totalMs',
    );
  }

  static void windowStart({
    required String screen,
    required String center,
    required int radius,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0R_PREBUILD_WINDOW_START] screen=$screen center=$center radius=$radius',
    );
  }

  static void prebuildBody({
    required String screen,
    required String date,
    required int priority,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0R_PREBUILD_BODY] screen=$screen date=$date priority=$priority ms=$ms',
    );
  }

  static void windowProgress({
    required String screen,
    required int ready,
    required int total,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0R_PREBUILD_WINDOW_PROGRESS] screen=$screen ready=$ready/$total',
    );
  }

  static void windowDone({
    required String screen,
    required int ready,
    required int totalMs,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0R_PREBUILD_WINDOW_DONE] screen=$screen ready=$ready totalMs=$totalMs',
    );
  }

  static void bodyCacheHit({
    required String screen,
    required String date,
    required String source,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0R_BODY_CACHE_HIT] screen=$screen date=$date source=$source',
    );
  }

  static void bodyCacheMiss({
    required String screen,
    required String date,
    required bool insideWarmRange,
    required String reason,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0R_BODY_CACHE_MISS] screen=$screen date=$date '
      'insideWarmRange=$insideWarmRange reason=$reason',
    );
  }

  static void emergencySyncBuild({
    required String screen,
    required String date,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0R_EMERGENCY_SYNC_BUILD] screen=$screen date=$date ms=$ms',
    );
  }

  static void diskRestore({
    required String screen,
    required int snapshots,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0R_DISK_RESTORE] screen=$screen snapshots=$snapshots ms=$ms',
    );
  }

  static void diskSave({
    required String screen,
    required int snapshots,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0R_DISK_SAVE] screen=$screen snapshots=$snapshots ms=$ms',
    );
  }

  static void renderExtendStart({
    required String screen,
    required String direction,
    required String from,
    required String to,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0R_RENDER_EXTEND_START] screen=$screen direction=$direction '
      'from=$from to=$to',
    );
  }

  static void renderExtendDone({
    required String screen,
    required int ready,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0R_RENDER_EXTEND_DONE] screen=$screen ready=$ready ms=$ms',
    );
  }

  static void plansMetadataReady({
    required int tags,
    required int categories,
    required String source,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0R_PLANS_METADATA_READY] tags=$tags categories=$categories '
      'source=$source',
    );
  }

  static void plansNoPageLoaders() {
    if (kReleaseMode) return;
    debugPrint('[P0R_PLANS_NO_PAGE_LOADERS] ok=true');
  }

  static void memory({
    required String screen,
    required int renderedBodies,
    required int snapshots,
    required int items,
    required int approxKb,
  }) {
    if (kReleaseMode) return;
    final label = screen == 'Timeline' ? 'records' : 'tasks';
    debugPrint(
      '[P0R_MEMORY] screen=$screen renderedBodies=$renderedBodies '
      'snapshots=$snapshots $label=$items approxKb=$approxKb',
    );
  }
}
