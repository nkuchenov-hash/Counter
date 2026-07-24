from __future__ import annotations

from pathlib import Path

CASCADE = Path("lib/data/plan_time_sequential_cascade.dart")
TEST = Path("test/time_view_bulk_resize_rules_test.dart")


def replace_once(source: str, old: str, new: str, name: str) -> str:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{name}: expected one match, found {count}")
    return source.replace(old, new, 1)


cascade = CASCADE.read_text(encoding="utf-8")
old_chain = """    final hadExplicitEnd = task.endDateTime != null;
    final shiftedStart = originalStart.isBefore(cursorEnd)
        ? cursorEnd
        : originalStart;
    final effectiveEnd = shiftedStart.add(Duration(minutes: duration));

    if (shiftedStart != originalStart) {
      changedById[task.planRowIdForBackend] = task.copyWith(
        startTime: shiftedStart,
        endDateTime: hadExplicitEnd ? effectiveEnd : null,
        clearEnd: !hadExplicitEnd,
      );
    }
    cursorEnd = effectiveEnd;
"""
new_chain = """    if (!originalStart.isBefore(cursorEnd)) break;
    final hadExplicitEnd = task.endDateTime != null;
    final shiftedStart = cursorEnd;
    final effectiveEnd = shiftedStart.add(Duration(minutes: duration));
    changedById[task.planRowIdForBackend] = task.copyWith(
      startTime: shiftedStart,
      endDateTime: hadExplicitEnd ? effectiveEnd : null,
      clearEnd: !hadExplicitEnd,
    );
    cursorEnd = effectiveEnd;
"""
if new_chain not in cascade:
    cascade = replace_once(
        cascade,
        old_chain,
        new_chain,
        "manual resize connected-chain rule",
    )

required_markers = (
    "Map<String, int>? _resolveOriginalBulkRelativeOffsets",
    "blockedReason: 'bulkScheduleMissing'",
    "blockedReason: 'bulkRelativeOffsetsChanged'",
    "final offset = resolvedBulkOffsets[id]!;",
)
for marker in required_markers:
    if marker not in cascade:
        raise RuntimeError(f"required bulk-time guard missing: {marker}")

CASCADE.write_text(cascade, encoding="utf-8", newline="\n")

test = TEST.read_text(encoding="utf-8")
if "pocketRecordId: id," not in test:
    test = replace_once(
        test,
        "    planRowId: id,\n",
        "    planRowId: id,\n    pocketRecordId: id,\n",
        "stable test backend id",
    )

if "_task('e', 13, 15, 13, 45, order: 4)," not in test:
    test = replace_once(
        test,
        "      _task('d', 13, 0, 13, 30, order: 3),\n",
        "      _task('d', 13, 0, 13, 30, order: 3),\n"
        "      _task('e', 13, 15, 13, 45, order: 4),\n",
        "resize first-gap fixture",
    )

if "expect(_byId(result, 'e').startTime" not in test:
    test = replace_once(
        test,
        "    expect(_byId(result, 'd').startTime, DateTime(2026, 7, 24, 13));\n",
        "    expect(_byId(result, 'd').startTime, DateTime(2026, 7, 24, 13));\n"
        "    expect(_byId(result, 'e').startTime, DateTime(2026, 7, 24, 13, 15));\n",
        "resize first-gap assertion",
    )

TEST.write_text(test, encoding="utf-8", newline="\n")
print("refined Time View resize chain; bulk-time guards intact")
