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
require("AppGlassEdgeFade(" in shell and
        "AppGlassEdge.bottom" in shell and
        "extendBody: !desktopShell" in shell,
        "BOTTOM_FADE_MUST_BE_SHELL_OWNED_AND_NONINTERACTIVE")
require("AppFrostedNavigationPanel(" in nav and
        "Positioned(" not in nav and "top: -46" not in nav,
        "NAV_BACKDROP_MUST_BE_CLIPPED_TO_FLOATING_CAPSULE")
require("AppGlassEdgeFade(" in settings and
        "AppGlassEdge.top" in settings,
        "TOP_HEADER_MUST_USE_CANONICAL_EDGE_FADE")
require(glass.count("class AppGlassEdgeFade") == 1 and
        glass.count("class AppFrostedNavigationPanel") == 1 and
        "ClipRRect(" in glass and "BackdropFilter(" in glass,
        "GLASS_COMPONENTS_MUST_BE_CENTRALIZED_AND_CLIPPED")
require("surfaceContainerLowest" not in nav and
        "AppGlassEdgeFade(" not in nav and
        "seamlessGlass ?" not in nav and "!seamlessGlass ?" not in nav,
        "TAB_SPECIFIC_NAV_VISUAL_VARIANTS_FORBIDDEN")
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
