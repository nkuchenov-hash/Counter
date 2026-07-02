#!/usr/bin/env python3
from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
CARD = ROOT / "lib" / "core" / "widgets" / "plan_time_task_card.dart"
METRICS = ROOT / "lib" / "core" / "widgets" / "plan_card" / "plan_card_metrics.dart"
DENSITY = ROOT / "lib" / "core" / "widgets" / "plan_card" / "plan_time_card_density.dart"

METRICS_HEADER = """import 'dart:math' as math;

"""

DENSITY_HEADER = """import 'package:counter/core/widgets/plan_card/plan_card_metrics.dart';

"""


def main() -> None:
    lines = CARD.read_text(encoding="utf-8").splitlines(keepends=True)
    metrics_body = "".join(lines[16:59])  # enum + constants through base hour max
    density_body = "".join(lines[61:114])  # visual density helpers
    surface_body = "".join(lines[116:118])  # PlanCardSurface enum

    METRICS.parent.mkdir(parents=True, exist_ok=True)
    METRICS.write_text(METRICS_HEADER + metrics_body + surface_body, encoding="utf-8")
    DENSITY_HEADER_FIXED = """import 'package:counter/core/widgets/plan_card/plan_card_metrics.dart';

"""
    DENSITY.write_text(DENSITY_HEADER_FIXED + density_body, encoding="utf-8")

    kept = lines[:16] + [
        "import 'package:counter/core/widgets/plan_card/plan_card_metrics.dart';\n",
        "import 'package:counter/core/widgets/plan_card/plan_time_card_density.dart';\n",
        "\n",
    ] + lines[118:]
    CARD.write_text("".join(kept), encoding="utf-8")
    print(f"plan_card_metrics: {len(METRICS.read_text().splitlines())} lines")
    print(f"plan_time_card_density: {len(DENSITY.read_text().splitlines())} lines")
    print(f"plan_time_task_card: {len(''.join(kept).splitlines())} lines")


if __name__ == "__main__":
    main()
