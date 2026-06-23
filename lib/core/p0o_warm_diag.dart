import 'package:flutter/foundation.dart';

/// P0O: rolling warm day window diagnostics (profile/debug only).
abstract final class P0OWarmDiag {
  static void bootTimelineCache({
    required int flatRecords,
    required int days,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[WARM_BOOT_TIMELINE_CACHE] flatRecords=$flatRecords days=$days ms=$ms',
    );
  }

  static void timelineIndexReady({
    required int days,
    required int records,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[WARM_TIMELINE_INDEX_READY] days=$days records=$records ms=$ms',
    );
  }

  static void timelineSnapshot({
    required String date,
    required String state,
    required int count,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[WARM_TIMELINE_SNAPSHOT] date=$date state=$state count=$count ms=$ms',
    );
  }

  static void timelineWindow({
    required String center,
    required String from,
    required String to,
    required int cachedDays,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[WARM_TIMELINE_WINDOW] center=$center from=$from to=$to '
      'cachedDays=$cachedDays',
    );
  }

  static void timelineExtend({
    required String direction,
    required String from,
    required String to,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[WARM_TIMELINE_EXTEND] direction=$direction from=$from to=$to ms=$ms',
    );
  }

  static void timelineRefreshMerge({
    required int before,
    required int after,
    required bool keptLocal,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[WARM_TIMELINE_REFRESH_MERGE] before=$before after=$after '
      'keptLocal=$keptLocal',
    );
  }

  static void plansSnapshot({
    required String date,
    required String state,
    required int count,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[WARM_PLANS_SNAPSHOT] date=$date state=$state count=$count ms=$ms',
    );
  }

  static void plansWindow({
    required String center,
    required String from,
    required String to,
    required int cachedDays,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[WARM_PLANS_WINDOW] center=$center from=$from to=$to cachedDays=$cachedDays',
    );
  }

  static void plansExtend({
    required String direction,
    required String from,
    required String to,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[WARM_PLANS_EXTEND] direction=$direction from=$from to=$to ms=$ms',
    );
  }

  static void memory({
    required String screen,
    required int cachedDays,
    required int items,
    required int approxKb,
  }) {
    if (kReleaseMode) return;
    final label = screen == 'Timeline' ? 'records' : 'tasks';
    debugPrint(
      '[WARM_MEMORY] screen=$screen cachedDays=$cachedDays $label=$items '
      'approxKb=$approxKb',
    );
  }
}
