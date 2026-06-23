import 'package:flutter/foundation.dart';

/// P0S: eager mounted day content strip diagnostics.
abstract final class P0SMountDiag {
  static void mountReady({
    required String screen,
    required String date,
    required bool mounted,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0S_MOUNT_READY] screen=$screen date=$date mounted=$mounted',
    );
  }

  static void firstSwipe({
    required String screen,
    required String targetDate,
    required bool mountedBeforeSwipe,
    required bool builtDuringSwipe,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0S_FIRST_SWIPE] screen=$screen targetDate=$targetDate '
      'mountedBeforeSwipe=$mountedBeforeSwipe builtDuringSwipe=$builtDuringSwipe',
    );
  }

  static void plansBootMountStart({
    required String center,
    required String from,
    required String to,
    required int count,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0S_PLANS_BOOT_MOUNT_START] center=$center from=$from to=$to count=$count',
    );
  }

  static void plansBodyMounted({
    required String date,
    required int cards,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0S_PLANS_BODY_MOUNTED] date=$date cards=$cards ms=$ms',
    );
  }

  static void plansBootMountDone({
    required int mounted,
    required int totalMs,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0S_PLANS_BOOT_MOUNT_DONE] mounted=$mounted totalMs=$totalMs',
    );
  }

  static void plansPageHit({required String date}) {
    if (kReleaseMode) return;
    debugPrint('[P0S_PLANS_PAGE_HIT] date=$date mounted=true');
  }

  static void plansPageMiss({
    required String date,
    required bool insideWindow,
    required String reason,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0S_PLANS_PAGE_MISS] date=$date insideWindow=$insideWindow reason=$reason',
    );
  }

  static void timelineBootMountStart({
    required String center,
    required String from,
    required String to,
    required int count,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0S_TIMELINE_BOOT_MOUNT_START] center=$center from=$from to=$to count=$count',
    );
  }

  static void timelineBodyMounted({
    required String date,
    required int records,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0S_TIMELINE_BODY_MOUNTED] date=$date records=$records ms=$ms',
    );
  }

  static void timelineBootMountDone({
    required int mounted,
    required int totalMs,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0S_TIMELINE_BOOT_MOUNT_DONE] mounted=$mounted totalMs=$totalMs',
    );
  }

  static void timelinePageHit({required String date}) {
    if (kReleaseMode) return;
    debugPrint('[P0S_TIMELINE_PAGE_HIT] date=$date mounted=true');
  }

  static void timelinePageMiss({
    required String date,
    required bool insideWindow,
    required String reason,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0S_TIMELINE_PAGE_MISS] date=$date insideWindow=$insideWindow reason=$reason',
    );
  }

  static void diskRestore({
    required String screen,
    required int snapshots,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0S_DISK_RESTORE] screen=$screen snapshots=$snapshots ms=$ms',
    );
  }

  static void diskSave({
    required String screen,
    required int snapshots,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0S_DISK_SAVE] screen=$screen snapshots=$snapshots ms=$ms',
    );
  }

  static void mountExtendStart({
    required String screen,
    required String direction,
    required String from,
    required String to,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0S_MOUNT_EXTEND_START] screen=$screen direction=$direction '
      'from=$from to=$to',
    );
  }

  static void mountExtendBody({
    required String screen,
    required String date,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0S_MOUNT_EXTEND_BODY] screen=$screen date=$date ms=$ms',
    );
  }

  static void mountExtendDone({
    required String screen,
    required int mounted,
    required int ms,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0S_MOUNT_EXTEND_DONE] screen=$screen mounted=$mounted ms=$ms',
    );
  }

  static void mountEvict({
    required String screen,
    required String date,
    required String reason,
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[P0S_MOUNT_EVICT] screen=$screen date=$date reason=$reason',
    );
  }

  static void memory({
    required String screen,
    required int mountedBodies,
    required int items,
    required int approxKb,
  }) {
    if (kReleaseMode) return;
    final label = screen == 'Timeline' ? 'records' : 'tasks';
    debugPrint(
      '[P0S_MEMORY] screen=$screen mountedBodies=$mountedBodies '
      '$label=$items approxKb=$approxKb',
    );
  }
}
