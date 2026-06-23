/// Internal perf bisect toggles (remove after culprit is confirmed).
///
/// **Performance Kill Switch Law (P0V):** Experimental performance paths must be
/// **default-off** until proven stable on **web and Android**. If any flag or
/// experiment regresses startup, swipe, or optimistic UI, disable it immediately
/// and restore the last known stable path. Release defaults choose **stability**
/// over theoretical preload. See `docs/ARCHITECTURE.md` § PERFORMANCE_KILL_SWITCH_LAW.
///
/// Bisect result (2026-06-21): lag introduced in `62020e8` + hidden-tab pager sync.
/// - [useLazyIndexedStack]: `LazyIndexedStack` + per-tab `RepaintBoundary` regressed feel vs `IndexedStack`.
/// - [syncHiddenTabDatePager]: when false, off-tab day `PageView`s use silent `jumpToPage` only.
abstract final class PerfFlags {
  /// `62020e8` added `LazyIndexedStack`; bisect → keep classic `IndexedStack`.
  static const bool useLazyIndexedStack = false;

  /// When false, Timeline/Planning wrappers skip `animateToPage` while shell tab inactive.
  static const bool syncHiddenTabDatePager = false;

  /// `62020e8` planning time canvas wrap — keep (helps paint isolation).
  static const bool enableTimelineRepaintBoundary = true;

  /// `62020e8` drag projection cache — keep (cheap win).
  static const bool enableTimelineProjectionCache = true;
}
