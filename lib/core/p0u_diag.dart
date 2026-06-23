import 'package:flutter/foundation.dart';

/// P0U emergency recovery diagnostics.
///
/// Verbose `[P0U_*]` logs follow Performance Kill Switch Law (P0V): gated in
/// release where noted; no per-row/per-card spam in production web/APK.
abstract final class P0uDiag {
  static void p0tDisabled({required String platform, required bool enabled}) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0U_P0T_DISABLED] platform=$platform enabled=$enabled',
    );
  }

  static void pagerMode({
    required String screen,
    required String platform,
    required String mode,
  }) {
    debugPrint(
      '[P0U_PAGER_MODE] screen=$screen platform=$platform mode=$mode',
    );
  }

  static void firstSwipeStart({
    required String screen,
    required String current,
    required String target,
  }) {
    debugPrint(
      '[P0U_FIRST_SWIPE_START] screen=$screen current=$current target=$target',
    );
  }

  static void firstSwipeDone({
    required String screen,
    required String target,
    bool ok = true,
  }) {
    debugPrint(
      '[P0U_FIRST_SWIPE_DONE] screen=$screen target=$target ok=$ok',
    );
  }

  static void firstSwipeFail({
    required String screen,
    required String target,
    required Object exception,
  }) {
    debugPrint(
      '[P0U_FIRST_SWIPE_FAIL] screen=$screen target=$target exception=$exception',
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

  static void recordCreateStart({required String title, required String date}) {
    debugPrint(
      '[P0U_RECORD_CREATE_START] title=$title date=$date',
    );
  }

  static void recordOptimisticApplied({
    required String recordId,
    required String date,
    bool flatCacheUpdated = true,
    bool dayIndexUpdated = true,
    bool streamEmitted = true,
  }) {
    debugPrint(
      '[P0U_RECORD_OPTIMISTIC_APPLIED] recordId=$recordId date=$date '
      'flatCacheUpdated=$flatCacheUpdated dayIndexUpdated=$dayIndexUpdated '
      'streamEmitted=$streamEmitted',
    );
  }

  static void timelineActiveDayPatched({
    required String date,
    required int count,
  }) {
    debugPrint(
      '[P0U_TIMELINE_ACTIVE_DAY_PATCHED] date=$date count=$count',
    );
  }

  static void recordServerReconciled({
    required String recordId,
    required String pbId,
  }) {
    debugPrint(
      '[P0U_RECORD_SERVER_RECONCILED] recordId=$recordId pbId=$pbId',
    );
  }

  static void recordUiVisibleWithoutRefresh({bool ok = true}) {
    debugPrint('[P0U_RECORD_UI_VISIBLE_WITHOUT_REFRESH] ok=$ok');
  }

  static void activeSource({
    required String screen,
    required String date,
    required String source,
  }) {
    debugPrint(
      '[P0U_ACTIVE_SOURCE] screen=$screen date=$date source=$source',
    );
  }

  static void snapshotPatchedAfterMutation({
    required String screen,
    required String date,
  }) {
    debugPrint(
      '[P0U_SNAPSHOT_PATCHED_AFTER_MUTATION] screen=$screen date=$date',
    );
  }

  static void timeProjectBatch({
    required String selectedDay,
    required int candidates,
    required int projected,
    required int visible,
    required int cacheHits,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0U_TIME_PROJECT_BATCH] selectedDay=$selectedDay candidates=$candidates '
      'projected=$projected visible=$visible cacheHits=$cacheHits ms=$ms',
    );
  }

  static void timeProjectSkipped({
    required String reason,
    required int count,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0U_TIME_PROJECT_SKIPPED] reason=$reason count=$count',
    );
  }

  static void timeProjectStormFixed({bool ok = true}) {
    debugPrint('[P0U_TIME_PROJECT_STORM_FIXED] ok=$ok');
  }

  static void startupStage({required String name, required int ms}) {
    if (kReleaseMode) return;
    debugPrint('[P0U_STARTUP_STAGE] name=$name ms=$ms');
  }

  static void startupSlow({required String stage, required int ms}) {
    debugPrint('[P0U_STARTUP_SLOW] stage=$stage ms=$ms');
  }

  static void biometricGate({required bool enabled, required String reason}) {
    debugPrint('[P0U_BIOMETRIC_GATE] enabled=$enabled reason=$reason');
  }

  static void memory({
    required String screen,
    required int mountedBodies,
    required int snapshots,
    required int approxKb,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0U_MEMORY] screen=$screen mountedBodies=$mountedBodies '
      'snapshots=$snapshots approxKb=$approxKb',
    );
  }

  static void releaseLogGuard({bool ok = true}) {
    debugPrint('[P0U_RELEASE_LOG_GUARD] ok=$ok');
  }

  static void profileBootSource({
    required String source,
    required bool hasTimezone,
    required bool hasLanguage,
  }) {
    debugPrint(
      '[P0U_PROFILE_BOOT_SOURCE] source=$source '
      'hasTimezone=$hasTimezone hasLanguage=$hasLanguage',
    );
  }

  static void profileServerRefreshDone({
    required bool changed,
    required int ms,
  }) {
    debugPrint(
      '[P0U_PROFILE_SERVER_REFRESH_DONE] changed=$changed ms=$ms',
    );
  }

  static bool _timelineFirstBuildLogged = false;

  static void timelineFirstBuild({
    required String date,
    required int records,
    required int ms,
  }) {
    if (_timelineFirstBuildLogged) return;
    _timelineFirstBuildLogged = true;
    debugPrint(
      '[P0U_TIMELINE_FIRST_BUILD] date=$date records=$records ms=$ms',
    );
  }

  static bool _timelineFirstListBuildLogged = false;

  static void timelineFirstListBuild({
    required String date,
    required int rows,
    required int ms,
  }) {
    if (_timelineFirstListBuildLogged) return;
    _timelineFirstListBuildLogged = true;
    debugPrint(
      '[P0U_TIMELINE_FIRST_LIST_BUILD] date=$date rows=$rows ms=$ms',
    );
  }

  static bool _timelineFirstPaintLogged = false;

  static void timelineFirstPaintSource({
    required String source,
    required int records,
    required int ms,
  }) {
    if (_timelineFirstPaintLogged) return;
    _timelineFirstPaintLogged = true;
    debugPrint(
      '[P0U_TIMELINE_FIRST_PAINT_SOURCE] source=$source records=$records ms=$ms',
    );
  }

  static void timelinePostFramePatch({
    required int records,
    required int ms,
  }) {
    debugPrint(
      '[P0U_TIMELINE_POST_FRAME_PATCH] records=$records ms=$ms',
    );
  }
}
