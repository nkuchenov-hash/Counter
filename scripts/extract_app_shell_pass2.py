#!/usr/bin/env python3
"""Structure refactor pass 2 — app_shell.dart safe UI extractions."""
from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
SHELL = ROOT / "lib" / "app_shell.dart"

PROFILE_BAR_HEADER = """import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

"""

SETTINGS_HEADER = """import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/app_locales.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

"""

NAV_HEADER = """import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

"""

RENAMES = {
    "_ProfileHydrationStatusBar": "ProfileHydrationStatusBar",
    "_SettingsPageState": "SettingsPageState",
    "_ShellSideNavigation": "ShellSideNavigation",
    "_ShellSideNavItem": "ShellSideNavItem",
}


def apply_renames(text: str) -> str:
    for old, new in RENAMES.items():
        text = text.replace(old, new)
    return text


def main() -> None:
    lines = SHELL.read_text(encoding="utf-8").splitlines(keepends=True)

    profile = apply_renames("".join(lines[93:148]))
    (ROOT / "lib/features/shared/profile_hydration_status_bar.dart").write_text(
        PROFILE_BAR_HEADER + profile,
        encoding="utf-8",
    )

    settings = apply_renames("".join(lines[153:274]))
    (ROOT / "lib/features/profile/settings/settings_page.dart").write_text(
        SETTINGS_HEADER + settings,
        encoding="utf-8",
    )

    nav = apply_renames("".join(lines[2632:2782]))
    (ROOT / "lib/core/navigation/shell_side_navigation.dart").write_text(
        NAV_HEADER + nav,
        encoding="utf-8",
    )

    kept = lines[:93] + [
        "import 'package:counter/core/navigation/shell_side_navigation.dart';\n",
        "import 'package:counter/features/profile/settings/settings_page.dart';\n",
        "import 'package:counter/features/shared/profile_hydration_status_bar.dart';\n",
        "\n",
    ] + lines[274:2632] + lines[2782:]

    text = apply_renames("".join(kept))
    SHELL.write_text(text, encoding="utf-8")
    print(f"app_shell.dart -> {len(text.splitlines())} lines")


if __name__ == "__main__":
    main()
