#!/usr/bin/env python3
"""Pass 3 — split timeline_view.dart into day page + record card modules."""
from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
TV = ROOT / "lib" / "features" / "timeline" / "timeline_view.dart"

DAY_HEADER = """import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/features/timeline/timeline_record_card.dart';
import 'package:counter/features/timeline/timeline_widgets.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

"""

RECORD_HEADER = """import 'package:counter/data/models.dart';
import 'package:counter/features/timeline/timeline_widgets.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

"""

RENAMES = {
    "_TimelineDayCardList": "TimelineDayCardList",
    "_TimelineDayCardListState": "TimelineDayCardListState",
    "_TimelineLazyRecordList": "TimelineLazyRecordList",
    "_TimelineLazyRecordListState": "TimelineLazyRecordListState",
    "_TimelineRecordCard": "TimelineRecordCard",
    "_TimelineRecordCardState": "TimelineRecordCardState",
}


def apply_renames(text: str) -> str:
    for old, new in RENAMES.items():
        text = text.replace(old, new)
    return text


def main() -> None:
    lines = TV.read_text(encoding="utf-8").splitlines(keepends=True)
    day_start = next(
        i for i, l in enumerate(lines) if l.startswith("class _TimelineDayCardList")
    )
    record_start = next(
        i for i, l in enumerate(lines) if l.startswith("class _TimelineRecordCard")
    )

    day_chunk = apply_renames("".join(lines[day_start:record_start]))
    record_chunk = apply_renames("".join(lines[record_start:]))

    (ROOT / "lib/features/timeline/timeline_day_page.dart").write_text(
        DAY_HEADER + day_chunk,
        encoding="utf-8",
    )
    (ROOT / "lib/features/timeline/timeline_record_card.dart").write_text(
        RECORD_HEADER + record_chunk,
        encoding="utf-8",
    )

    kept = lines[:day_start]
    import_line = "import 'package:counter/features/timeline/timeline_day_page.dart';\n"
    if import_line not in "".join(kept):
        insert_at = next(
            (i for i, l in enumerate(kept) if l.startswith("import ")),
            0,
        )
        # after last import
        for i, l in enumerate(kept):
            if l.startswith("import "):
                insert_at = i
        kept.insert(insert_at + 1, import_line)

    kept_text = apply_renames("".join(kept))
    # fix internal reference to record card class in TimelinePage
    kept_text = kept_text.replace(
        "_TimelineDayCardList(",
        "TimelineDayCardList(",
    )
    TV.write_text(kept_text, encoding="utf-8")
    print(
        "timeline_view:",
        len(kept_text.splitlines()),
        "timeline_day_page:",
        len((DAY_HEADER + day_chunk).splitlines()),
        "timeline_record_card:",
        len((RECORD_HEADER + record_chunk).splitlines()),
    )


if __name__ == "__main__":
    main()
