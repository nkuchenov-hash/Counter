// ---------------------------------------------------------------------------
// Shell adaptive layout — breakpoint for desktop side nav vs mobile bottom nav.
// UI-only; not part of DatabaseService.
// ---------------------------------------------------------------------------

/// Width at which the shell shows left navigation instead of bottom navigation.
const double kShellDesktopNavBreakpoint = 900;

/// Expanded side navigation width (icons + labels).
const double kShellSideNavWidth = 272;

bool shellUsesSideNavigation(double width) =>
    width >= kShellDesktopNavBreakpoint;

/// Phone-width shell (bottom nav, APK-equivalent metrics). Used instead of
/// blanket [kIsWeb] when choosing touch vs pointer affordances.
bool shellUsesCompactPhoneLayout(double width) =>
    width < kShellDesktopNavBreakpoint;

/// Use shorter bottom-nav labels below this width (iPhone 14 class).
const double kShellCompactNavLabelBreakpoint = 420;

/// Calendar day cells use event pills when the viewport is wide enough.
const double kCalendarEventPillBreakpoint = 600;

bool calendarShowsEventPills(double width) =>
    width >= kCalendarEventPillBreakpoint;
