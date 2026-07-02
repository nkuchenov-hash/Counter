#!/usr/bin/env python3
from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
SHELL = ROOT / "lib" / "app_shell.dart"
OUT = ROOT / "lib" / "core" / "widgets" / "offline_sync_status_bar.dart"

HEADER = """import 'dart:async';

import 'package:counter/core/performance/rebuild_metrics.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

"""

RENAMES = {
    "_OfflineSyncStatusBar": "OfflineSyncStatusBar",
    "_OfflineSyncStatusBarState": "OfflineSyncStatusBarState",
}


def main() -> None:
    lines = SHELL.read_text(encoding="utf-8").splitlines(keepends=True)
    chunk = "".join(lines[149:275])  # comment block + class
    for old, new in RENAMES.items():
        chunk = chunk.replace(old, new)
    OUT.write_text(HEADER + chunk, encoding="utf-8")

    kept = lines[:149] + [
        "import 'package:counter/core/widgets/offline_sync_status_bar.dart';\n",
        "\n",
    ] + lines[275:]
    text = "".join(kept)
    for old, new in RENAMES.items():
        text = text.replace(old, new)
    SHELL.write_text(text, encoding="utf-8")
    print(f"Wrote offline_sync_status_bar.dart")
    print(f"app_shell trimmed to {len(text.splitlines())} lines")


if __name__ == "__main__":
    main()
