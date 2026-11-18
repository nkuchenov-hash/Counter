#!/usr/bin/env python3
"""P0 invariant: one canonical mobile nav and no overlapping action layer."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[2]
def read(name):
    return (root / name).read_text(encoding="utf-8")

shell = read("lib/app/shell/shared/shell_chrome.dart")
nav = read("lib/app/shell/phone/shell_bottom_navigation.dart")
phone = read("lib/app/shell/phone/phone_shell_frame.dart")
settings = read("lib/features/profile/menu/life_os_settings_tabs_page.dart")
glass = read("lib/core/widgets/app_glass_edge_fade.dart")
issues = []
def require(condition, message):
    if not condition:
        issues.append(message)

primary = [p for p in (root / "lib").rglob("*.dart")
           if "class ShellCompactBottomNav" in p.read_text(encoding="utf-8")]
require(len(primary) == 1 and primary[0].as_posix().endswith(
    "/app/shell/phone/shell_bottom_navigation.dart"),
    "CANONICAL_NAV_OWNER: exactly one ShellCompactBottomNav owner")
require(shell.count("bottomNavigationBar: LayoutBuilder(") == 1,
        "SHELL_NAV_SINGLE_INSTANCE")
require(shell.count("PhoneShellBottomNavigation(") == 1,
        "SHELL_NAV_SINGLE_CONSTRUCTOR")
require(phone.count("ShellCompactBottomNav(") == 1,
        "PHONE_NAV_MUST_DELEGATE_TO_CANONICAL_COMPONENT")
require("extendBody: !desktopShell" in shell and
        "extendBody: false" not in shell,
        "FROSTED_DOCK_MUST_SAMPLE_SCROLLING_BODY_UNDERNEATH")
require("AppGlassEdgeFade(" not in shell and
        "AppGlassEdge.bottom" not in shell and
        "extendBody: !desktopShell" in shell,
        "SHELL_MUST_NOT_BUILD_DUPLICATE_NAV_BACKDROP")
require(nav.count("AppGlassEdgeFade(") == 1 and
        nav.count("AppFrostedNavigationPanel(") == 1 and
        nav.count("Positioned(") == 1 and
        "AppGlassEdge.bottom" in nav and
        "height: 176" in nav and "blurSigma: 14" in nav and
        "top: -46" not in nav,
        "ONE_CANONICAL_NAV_OWNS_BACKDROP_AND_CAPSULE")
require("AppGlassEdgeFade(" in settings and
        "AppGlassEdge.top" in settings,
        "TOP_HEADER_MUST_USE_CANONICAL_EDGE_FADE")
require(glass.count("class AppGlassEdgeFade") == 1 and
        glass.count("class AppFrostedNavigationPanel") == 1 and
        "ClipRRect(" in glass and "BackdropFilter(" in glass,
        "GLASS_COMPONENTS_MUST_BE_CENTRALIZED_AND_CLIPPED")
require("seamlessGlass ?" in nav and
        "surfaceContainerLowest" in nav and
        "Clip.none" in nav and
        "IgnorePointer(" in glass,
        "ONLY_CANVAS_COLOR_MAY_VARY_WITH_THEME_NOT_DOCK_DESIGN")
# Feature pages cannot reimplement the root navigation or its full-width fade.
for feature in ("timeline", "lists", "planning", "calendar"):
    for file in (root / "lib/features" / feature).rglob("*.dart"):
        content = file.read_text(encoding="utf-8")
        if "ShellCompactBottomNav(" in content or "PhoneShellBottomNavigation(" in content:
            issues.append("DUPLICATE_FEATURE_NAV: " + str(file.relative_to(root)))
require("List<Widget> get _stableShellPages" in shell and
        "..._stableShellPages" in shell and
        "_stableLocale == locale" in shell,
        "SWITCHING_MUST_REUSE_STABLE_PRIMARY_SCREENS")
# No second root-nav widget may be silently added to a shell fragment.
for file in (root / "lib/app/shell").rglob("*.dart"):
    if file.name == "shell_bottom_navigation.dart":
        continue
    content = file.read_text(encoding="utf-8")
    if re.search(r"\b(?:BottomNavigationBar|NavigationBar)\s*\(", content):
        issues.append("DUPLICATE_ROOT_NAV: " + str(file.relative_to(root)))

if issues:
    print("canonical_navigation_law: FAIL")
    for issue in issues:
        print("  - " + issue)
    sys.exit(1)
print("canonical_navigation_law: PASS")
