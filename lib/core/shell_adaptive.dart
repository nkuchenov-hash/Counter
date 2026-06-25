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

/// Calendar day cells use event pills when the viewport is wide enough.
const double kCalendarEventPillBreakpoint = 600;

bool calendarShowsEventPills(double width) =>
    width >= kCalendarEventPillBreakpoint;
