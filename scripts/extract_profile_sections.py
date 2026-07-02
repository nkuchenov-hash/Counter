#!/usr/bin/env python3
from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
PV = ROOT / "lib" / "features" / "profile" / "profile_view.dart"

SECTIONS = [
    (
        31,
        127,
        "lib/features/profile/settings/notification_settings_section.dart",
        [
            "import 'dart:async';",
            "",
            "import 'package:counter/core/widgets/app_button.dart';",
            "import 'package:counter/l10n/dictionary.dart';",
            "import 'package:counter/services/notification_service.dart';",
            "import 'package:flutter/foundation.dart' show kIsWeb;",
            "import 'package:flutter/material.dart';",
            "import 'package:flutter_local_notifications/flutter_local_notifications.dart';",
            "",
        ],
        {"_ProfileNotificationsSection": "ProfileNotificationsSection",
         "_ProfileNotificationsSectionState": "ProfileNotificationsSectionState"},
    ),
    (
        129,
        262,
        "lib/features/profile/settings/security_settings_section.dart",
        [
            "import 'dart:async';",
            "",
            "import 'package:counter/core/app_snackbar.dart';",
            "import 'package:counter/core/widgets/app_button.dart';",
            "import 'package:counter/data/auth_bridge.dart';",
            "import 'package:counter/data/database_service.dart';",
            "import 'package:counter/l10n/dictionary.dart';",
            "import 'package:flutter/foundation.dart' show kIsWeb;",
            "import 'package:flutter/material.dart';",
            "",
        ],
        {"_SecuritySection": "SecuritySection",
         "_SecuritySectionState": "SecuritySectionState"},
    ),
    (
        264,
        356,
        "lib/features/profile/settings/account_settings_section.dart",
        [
            "import 'dart:async';",
            "",
            "import 'package:counter/features/auth/oauth_session.dart';",
            "import 'package:counter/data/auth_bridge.dart';",
            "import 'package:counter/data/database_service.dart';",
            "import 'package:counter/data/models.dart';",
            "import 'package:counter/l10n/dictionary.dart';",
            "import 'package:flutter/material.dart';",
            "",
        ],
        {"_AccountSecuritySection": "AccountSecuritySection"},
    ),
]

IMPORTS = [
    "import 'package:counter/features/profile/settings/account_settings_section.dart';",
    "import 'package:counter/features/profile/settings/notification_settings_section.dart';",
    "import 'package:counter/features/profile/settings/security_settings_section.dart';",
]

RENAMES = {
    "_ProfileNotificationsSection": "ProfileNotificationsSection",
    "_SecuritySection": "SecuritySection",
    "_AccountSecuritySection": "AccountSecuritySection",
}


def apply_renames(text: str, renames: dict[str, str]) -> str:
    for old, new in renames.items():
        text = text.replace(old, new)
    return text


def main() -> None:
    lines = PV.read_text(encoding="utf-8").splitlines(keepends=True)
    for start, end, rel, header, renames in SECTIONS:
        chunk = apply_renames("".join(lines[start - 1 : end]), renames)
        out = ROOT / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text("".join(header) + chunk, encoding="utf-8")
        print(f"Wrote {rel}")

    kept = lines[:30] + lines[356:]
    text = "".join(kept)
    marker = "import 'package:counter/core/widgets/app_loading.dart';"
    text = text.replace(marker, marker + "\n" + "\n".join(IMPORTS) + "\n", 1)
    text = apply_renames(text, RENAMES)
    PV.write_text(text, encoding="utf-8")
    print(f"Trimmed profile_view to {len(text.splitlines())} lines")


if __name__ == "__main__":
    main()
