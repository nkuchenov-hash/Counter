import 'package:flutter/foundation.dart';

/// P0P: content-only date paging diagnostics (profile/debug only).
abstract final class P0PContentDiag {
  static void plansChromeStatic() {
    if (kReleaseMode) return;
    debugPrint('[P0P_PLANS_CHROME_STATIC] ok=true');
  }

  static void plansDateBody({
    required String date,
    required int cards,
    required String snapshot,
    required int buildMs,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0P_PLANS_DATE_BODY] date=$date cards=$cards snapshot=$snapshot '
      'buildMs=$buildMs',
    );
  }

  static void plansNoTagLoaderInPage() {
    if (kReleaseMode) return;
    debugPrint('[P0P_PLANS_NO_TAG_LOADER_IN_PAGE] ok=true');
  }

  static void timelineChromeStatic() {
    if (kReleaseMode) return;
    debugPrint('[P0P_TIMELINE_CHROME_STATIC] ok=true');
  }

  static void timelineDateBody({
    required String date,
    required int records,
    required String snapshot,
    required int buildMs,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0P_TIMELINE_DATE_BODY] date=$date records=$records snapshot=$snapshot '
      'buildMs=$buildMs',
    );
  }

  static void timelineRealCards() {
    if (kReleaseMode) return;
    debugPrint('[P0P_TIMELINE_REAL_CARDS] ok=true');
  }

  static void renderWarm({
    required String screen,
    required String date,
    required String state,
    required int buildMs,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0P_RENDER_WARM] screen=$screen date=$date state=$state buildMs=$buildMs',
    );
  }

  static void renderWindow({
    required String screen,
    required String center,
    required int renderedDays,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0P_RENDER_WINDOW] screen=$screen center=$center '
      'renderedDays=$renderedDays',
    );
  }

  static void renderMemory({
    required String screen,
    required int renderedDays,
    required int approxKb,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0P_RENDER_MEMORY] screen=$screen renderedDays=$renderedDays '
      'approxKb=$approxKb',
    );
  }
}
