#!/usr/bin/env python3
"""Audit LIFE OS Dart sources for unowned chromatic UI colors.

Only color-token owners may declare literal chromatic colors:
- lib/core/life_color_compat.dart: the eleven category/tag families
- lib/core/app_colors.dart: global interface states and theme chrome

Feature code must refer to those tokens, Theme.colorScheme, or colors supplied
by the user's data model. Neutral black/white/gray surfaces are intentionally
not classified as chromatic colors.

The --report mode lists existing violations without failing (migration aid).
The --strict mode makes all unowned chromatic literals a CI error.
"""

from __future__ import annotations

import argparse
import colorsys
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OWNERS = {
    "lib/core/life_color_compat.dart",
    "lib/core/app_colors.dart",
}
HEX_COLOR = re.compile(r"\bColor\s*\(\s*0x([0-9A-Fa-f]{8})\s*\)")
MATERIAL_COLOR = re.compile(
    r"\b(?:Colors|CupertinoColors)\."
    r"(red|redAccent|deepOrange|deepOrangeAccent|orange|orangeAccent|"
    r"amber|amberAccent|yellow|yellowAccent|lime|limeAccent|"
    r"lightGreen|lightGreenAccent|green|greenAccent|teal|tealAccent|"
    r"cyan|cyanAccent|lightBlue|lightBlueAccent|blue|blueAccent|"
    r"indigo|indigoAccent|deepPurple|deepPurpleAccent|purple|purpleAccent|"
    r"pink|pinkAccent|brown|blueGrey|activeBlue|activeGreen|systemRed|"
    r"systemOrange|systemYellow|systemGreen|systemBlue|systemPurple|"
    r"systemPink|systemTeal)"
    r"\b"
)
FROM_ARGB = re.compile(
    r"\bColor\.fromARGB\s*\(\s*\d+\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)"
)
FROM_RGBO = re.compile(
    r"\bColor\.fromRGBO\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,"
)
ALLOW = "semantic-color-audit: external"


def chromatic(r: int, g: int, b: int) -> bool:
    spread = max(r, g, b) - min(r, g, b)
    saturation = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)[1]
    # Cool gray/slate shadows count as neutral chrome, not semantic accents.
    return spread >= 35 and saturation >= 0.24


def findings(source: Path) -> list[tuple[int, str]]:
    text = source.read_text(encoding="utf-8")
    issues = []
    for number, line in enumerate(text.splitlines(), 1):
        stripped = line.lstrip()
        if stripped.startswith(("//", "///", "*")):
            continue
        if ALLOW in line:
            continue
        pieces = []
        for match in HEX_COLOR.finditer(line):
            raw = match.group(1)
            r, g, b = int(raw[2:4], 16), int(raw[4:6], 16), int(raw[6:8], 16)
            if chromatic(r, g, b):
                pieces.append(match.group(0))
        for match in MATERIAL_COLOR.finditer(line):
            pieces.append(match.group(0))
        for regex in (FROM_ARGB, FROM_RGBO):
            for match in regex.finditer(line):
                if chromatic(*(int(v) for v in match.groups())):
                    pieces.append(match.group(0))
        if pieces:
            issues.append((number, ", ".join(pieces)))
    return issues


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--report", action="store_true")
    args = parser.parse_args()
    failures = []
    examined = 0
    for path in sorted((ROOT / "lib").rglob("*.dart")):
        relative = path.relative_to(ROOT).as_posix()
        if relative in OWNERS:
            continue
        examined += 1
        for number, item in findings(path):
            failures.append((relative, number, item))
    tally = Counter(path.split("/")[1] for path, _, _ in failures)
    print(
        f"semantic_color_contract: checked {examined} Dart sources, "
        f"found {len(failures)} unowned chromatic color literal(s)"
    )
    for area, count in tally.most_common():
        print(f"  {area}: {count}")
    for path, number, item in failures[:250]:
        print(f"  {path}:{number}: {item}")
    if len(failures) > 250:
        print(f"  ... and {len(failures) - 250} more")
    if args.strict and failures:
        print("FAIL: use the canonical family tokens or the shared semantic roles")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
