#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / "lib/features/paths/paths_page.dart"
text = path.read_text(encoding="utf-8-sig")
start = text.find("\n  Widget _warningCard(String text) {")
if start >= 0:
    end = text.find("\n  }", start)
    if end < 0:
        raise SystemExit("_warningCard closing brace missing")
    end += len("\n  }")
    text = text[:start] + text[end:]
path.write_text(text.rstrip() + "\n", encoding="utf-8", newline="\n")
print("durable_paths_lint_cleanup: applied")
