from pathlib import Path


def replace_one(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, got {count}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


layout = 'lib/features/planning/plan_time_view_layout.dart'

target = """      final requiredSpanPx =
          _cardHeightPx(slot.durationMin) +
          (hasAdjacentNext ? kPlanTimeCardGapPx : 0.0);"""
replacement = """      // The hour only needs to stretch enough for the canonical minimum
      // rendered card height. Actual card height is derived from the shared
      // wall-time Y span below, so a wall-adjacent boundary can stay exactly
      // kPlanTimeCardGapPx instead of becoming an arbitrarily large empty gap.
      final requiredSpanPx =
          kPlanTimeCardMinHeightPx +
          (hasAdjacentNext ? kPlanTimeCardGapPx : 0.0);"""
replace_one(layout, target, replacement, 'hour stretch requirement')

target = """    for (final slot in slots) {
      final heightPx = _cardHeightPx(slot.durationMin);
      final topPx = yScale.yForMinute(slot.startMin);

      // TIME_VIEW_CARD_CONTENT_DENSITY_FROM_AVAILABLE_HEIGHT — inner layout only."""
replacement = """    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final topPx = yScale.yForMinute(slot.startMin);
      final endPx = yScale.yForMinute(slot.endMin);
      final hasAdjacentNext =
          i + 1 < slots.length &&
          _wallAdjacent(slot.endMin, slots[i + 1].startMin);
      final boundaryGapPx = hasAdjacentNext ? kPlanTimeCardGapPx : 0.0;
      final heightPx = math.max(
        kPlanTimeCardMinHeightPx,
        endPx - topPx - boundaryGapPx,
      ).toDouble();

      // TIME_VIEW_CARD_CONTENT_DENSITY_FROM_AVAILABLE_HEIGHT — inner layout only."""
replace_one(layout, target, replacement, 'card placement height')

target = """      final expectedHeight = _cardHeightPx(slot.durationMin);
      final expectedTop = yScale.yForMinute(slot.startMin);"""
replacement = """      final expectedTop = yScale.yForMinute(slot.startMin);
      final expectedEnd = yScale.yForMinute(slot.endMin);
      final hasAdjacentNext =
          i + 1 < slots.length &&
          _wallAdjacent(slot.endMin, slots[i + 1].startMin);
      final expectedHeight = math.max(
        kPlanTimeCardMinHeightPx,
        expectedEnd -
            expectedTop -
            (hasAdjacentNext ? kPlanTimeCardGapPx : 0.0),
      ).toDouble();"""
replace_one(layout, target, replacement, 'debug expected height')

target = """        final requiredGap = _wallAdjacent(slotA.endMin, slotB.startMin)
            ? kPlanTimeCardGapPx
            : 0.0;
        assert(
          b.topPx >= a.topPx + a.heightPx + requiredGap - 0.51,
          'TIME_VIEW_VISUAL_OVERLAP: ${a.task.title} -> ${b.task.title}',
        );"""
replacement = """        final wallAdjacent = _wallAdjacent(slotA.endMin, slotB.startMin);
        final actualGap = b.topPx - (a.topPx + a.heightPx);
        if (wallAdjacent) {
          assert(
            (actualGap - kPlanTimeCardGapPx).abs() < 0.51,
            'TIME_VIEW_ADJACENT_GAP_MISMATCH: '
            '${a.task.title} -> ${b.task.title}; gap=$actualGap',
          );
        } else {
          assert(
            actualGap >= -0.51,
            'TIME_VIEW_VISUAL_OVERLAP: ${a.task.title} -> ${b.task.title}',
          );
        }"""
replace_one(layout, target, replacement, 'debug exact adjacent gap')


test = 'test/plan_time_view_wall_alignment_regression_test.dart'
target = """    expect(b.topPx, greaterThanOrEqualTo(a.topPx + a.heightPx + 3.49));
    expect(c.topPx, greaterThanOrEqualTo(b.topPx + b.heightPx + 3.49));
    expect(d.topPx, greaterThanOrEqualTo(c.topPx + c.heightPx + 3.49));"""
replacement = """    expect(b.topPx - (a.topPx + a.heightPx), closeTo(4, 0.01));
    expect(c.topPx - (b.topPx + b.heightPx), closeTo(4, 0.01));
    expect(d.topPx - (c.topPx + c.heightPx), closeTo(4, 0.01));"""
replace_one(test, target, replacement, 'mixed-duration exact gaps')

target = """    'touching scheduled cards keep the canonical 4px minimum visual gap',"""
replacement = """    'touching scheduled cards keep exactly the canonical 4px visual gap',"""
replace_one(test, target, replacement, 'test name')

target = """      expect(
        b.topPx - (a.topPx + a.heightPx),
        greaterThanOrEqualTo(kPlanTimeCardGapPx - 0.01),
      );"""
replacement = """      expect(
        b.topPx - (a.topPx + a.heightPx),
        closeTo(kPlanTimeCardGapPx, 0.01),
      );"""
replace_one(test, target, replacement, 'exact short-card gap expectation')


changelog = 'CHANGELOG.md'
p = Path(changelog)
text = p.read_text(encoding='utf-8')
old = """## 2026-09-10 — Planning Time precision and controls [fix]\n\n- Kept Time View card starts on the same wall-time Y scale as hour grid lines with 5-minute interaction precision and the existing 4px minimum card gap.\n"""
new = """## 2026-09-10 — Planning Time exact adjacent spacing [fix]\n\n- Corrected the Time View elastic-hour geometry so cards whose wall times directly follow each other render with exactly 4px between their visible rectangles, including mixed-duration sequences; card starts and hour lines remain on the same wall-time Y scale.\n\n## 2026-09-10 — Planning Time precision and controls [fix]\n\n- Kept Time View card starts on the same wall-time Y scale as hour grid lines with 5-minute interaction precision and the existing 4px minimum card gap.\n"""
if old not in text:
    raise SystemExit('changelog insertion target not found')
p.write_text(text.replace(old, new, 1), encoding='utf-8')
