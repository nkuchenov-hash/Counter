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
require("extendBody: false" in shell and
        "extendBody: !desktopShell" not in shell,
        "SHELL_NAV_ACTION_OVERLAP_FORBIDDEN")
require("clipBehavior: Clip.none" in nav and
        "top: -46" in nav and
        "Positioned(" in nav,
        "NAV_GLASS_FEATHER_MUST_EXTEND_ABOVE_RESERVED_ACTIONS")
require("AppGlassEdgeFade(" in nav and
        "AppGlassEdge.bottom" in nav and
        "AppGlassEdgeFade(" in settings and
        "AppGlassEdge.top" in settings,
        "TOP_BOTTOM_MUST_USE_SAME_CANONICAL_GLASS")
require(glass.count("class AppGlassEdgeFade") == 1 and
        "IgnorePointer(" in glass and "BackdropFilter(" in glass,
        "FROSTED_EDGE_MUST_BE_SINGLE_NONINTERACTIVE_COMPONENT")
require("seamlessGlass ?" not in nav and "!seamlessGlass ?" not in nav,
        "TAB_SPECIFIC_NAV_VISUAL_VARIANTS_FORBIDDEN")
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
