import 'package:counter/core/shell_adaptive.dart';

/// Form-factor ownership for app shell chrome.
///
/// Production chrome is still binary (bottom nav vs side nav) at
/// [kShellDesktopNavBreakpoint]. [tablet] shares phone chrome today; the
/// label exists so mid-width compact viewports have an explicit owner folder
/// without inventing new layout.
enum ShellFormFactor { phone, tablet, desktop }

/// Resolves shell form factor from viewport width using existing breakpoints.
///
/// - [ShellFormFactor.desktop]: side navigation (`width >= 900`)
/// - [ShellFormFactor.tablet]: compact chrome on wider compact widths
///   (`600 <= width < 900`) — same widgets as phone today
/// - [ShellFormFactor.phone]: compact chrome on narrow widths (`width < 600`)
ShellFormFactor shellFormFactorForWidth(double width) {
  if (shellUsesSideNavigation(width)) return ShellFormFactor.desktop;
  if (width >= kCalendarEventPillBreakpoint) return ShellFormFactor.tablet;
  return ShellFormFactor.phone;
}
