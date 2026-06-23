/// P0U emergency recovery — global kill switches for P0S/P0T mounted strip.
///
/// **Performance Kill Switch Law (P0V):** These flags default **false** on all
/// platforms (web, Android, iOS, desktop). Do not enable in release. Do not
/// enable by default config. Any path that regresses startup, swipe, optimistic
/// UI, or stability must be killed immediately — restore stable `PageView.builder`
/// + live optimistic sources before continuing feature work.
///
/// See `docs/ARCHITECTURE.md` § PERFORMANCE_KILL_SWITCH_LAW.
const bool kUseP0tMountedStrip = false;

/// Verbose plan time-zone projection logs (debug/profile only).
/// Release web/APK must never flood console with per-row TIME_TZ_PROJECT spam.
const bool kVerbosePlanTimeTzProjectionLogs = false;

/// Shell: build only the active tab until user visits others (P0U.2).
/// **KILL SWITCH (P0U.3):** Disabled — regressed firstFrameMs (4668 vs P0U.1 1511).
/// Uses [LazyIndexedStack] when true.
const bool kShellDeferHiddenTabsUntilFirstFrame = false;

/// P0U.4 — post-firstFrame adjacent Timeline row-VM warmup (±1 day, local cache only).
/// **KILL SWITCH:** Set false if startup regresses or post-frame freeze appears.
const bool kTimelineAdjacentRowVmWarmup = true;
