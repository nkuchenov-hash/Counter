from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")


def replace_one(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"patch target not found: {label}")
    if text.count(old) != 1:
        raise SystemExit(f"patch target not unique: {label} count={text.count(old)}")
    return text.replace(old, new, 1)


# 1) Trailing Play + Menu must both remain outside the Time View body-drag overlay.
p = "lib/core/widgets/plan_time_task_card/plan_card_density.dart"
s = read(p)
pattern = re.compile(
    r"/// Right inset for timeline drag/tap body zone[^\n]*\n"
    r"double planCardBodyGestureRightInsetPx\(\{bool hasMenu = true\}\) =>\n"
    r"    hasMenu \? PlanCardGeom\.menuSize \+ PlanCardGeom\.padRight : 0;"
)
replacement = """/// Right inset for timeline drag/tap body zone.
///
/// Time View renders Play + Menu as trailing controls. The direct-manipulation
/// overlay must stop before both controls, otherwise it steals hover/tap events.
double planCardBodyGestureRightInsetPx({
  bool hasPlay = false,
  bool hasMenu = true,
}) {
  final count = (hasPlay ? 1 : 0) + (hasMenu ? 1 : 0);
  if (count == 0) return 0;
  return PlanCardGeom.padRight +
      count * PlanCardGeom.controlSize +
      (count - 1) * 8.0;
}"""
s2, n = pattern.subn(replacement, s, count=1)
if n != 1:
    raise SystemExit(f"right inset patch count={n}")
write(p, s2)

p = "lib/features/planning/time_view/time_view_card_layer.dart"
s = read(p)
old = """    final blockDensity = layout.density;
    final resizeHeightPx = math.max(heightPx, kPlanTimeCardMinHeightPx);"""
new = """    final blockDensity = layout.density;
    final displayDone =
        host.planDoneOverride[planKey] ?? layout.task.isDone;
    final hasTrailingPlay = !host.planSelectMode && !displayDone;
    final resizeHeightPx = math.max(heightPx, kPlanTimeCardMinHeightPx);"""
s = replace_one(s, old, new, "time view displayDone/trailing play")
s = replace_one(
    s,
    "controlsRightInset: planCardBodyGestureRightInsetPx(),",
    """controlsRightInset: planCardBodyGestureRightInsetPx(
                    hasPlay: hasTrailingPlay,
                  ),""",
    "time view right interaction inset",
)
old = """                        displayDone:
                            host.planDoneOverride[planKey] ??
                            layout.task.isDone,"""
s = replace_one(s, old, "                        displayDone: displayDone,", "time view displayDone reuse")
write(p, s)

# 2) Actual-time label gets a real line box instead of the clipped 8px slot.
p = "lib/core/widgets/plan_time_task_card/plan_card_geometry.dart"
s = read(p)
s = replace_one(
    s,
    "  static const double actualTimeSlotHeight = 8;",
    "  static const double actualTimeSlotHeight = 12;",
    "actual time slot height",
)
write(p, s)

# 3) Keep actual time alive locally while the linked plan is running. This rebuilds only
#    the tiny progress slot, not the whole Planning page.
p = "lib/core/widgets/plan_time_task_card/plan_card_progress.dart"
s = read(p)
if not s.startswith("import 'package:"):
    raise SystemExit("unexpected progress imports")
s = "import 'dart:async';\n\n" + s
start = s.index("class PlanCardProgressSlot extends StatelessWidget {")
end = s.index("\nclass PlanCardInvariantBody extends StatelessWidget {")
live_class = r'''class PlanCardProgressSlot extends StatefulWidget {
  const PlanCardProgressSlot({
    required this.planTrackedSeconds,
    required this.categoryColor,
    this.planEstimatedSeconds,
    this.isRunning = false,
    this.spacing = PlanCardVerticalSpacing.shared,
  });

  final int planTrackedSeconds;
  final int? planEstimatedSeconds;
  final Color categoryColor;
  final bool isRunning;
  final PlanCardVerticalSpacing spacing;

  @override
  State<PlanCardProgressSlot> createState() => _PlanCardProgressSlotState();
}

class _PlanCardProgressSlotState extends State<PlanCardProgressSlot> {
  Timer? _ticker;
  late int _displayTrackedSeconds;

  @override
  void initState() {
    super.initState();
    _displayTrackedSeconds = widget.planTrackedSeconds;
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant PlanCardProgressSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isRunning || !oldWidget.isRunning) {
      _displayTrackedSeconds = widget.planTrackedSeconds;
    } else if (widget.planTrackedSeconds > _displayTrackedSeconds) {
      // Parent aggregates include the open record through planetary-now. Never
      // jump a live label backwards between those authoritative refreshes.
      _displayTrackedSeconds = widget.planTrackedSeconds;
    }
    if (widget.isRunning != oldWidget.isRunning) {
      _syncTicker();
    }
  }

  void _syncTicker() {
    _ticker?.cancel();
    _ticker = null;
    if (!widget.isRunning) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _displayTrackedSeconds++);
    });
  }

  String _liveLabel(int seconds) {
    final s = seconds.clamp(0, 8640000);
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = sec.toString().padLeft(2, '0');
    if (h > 0) return '${h.toString().padLeft(2, '0')}:$mm:$ss';
    return '$mm:$ss';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estimated = widget.planEstimatedSeconds ?? 0;
    final tracked = _displayTrackedSeconds;
    final hasActual = tracked > 0;
    final slotHeight = widget.spacing.progressSlotHeight(
      hasTrackedProgress: hasActual,
    );
    return SizedBox(
      height: slotHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.spacing.actualTimeSlotHeight,
            child: hasActual
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      widget.isRunning
                          ? _liveLabel(tracked)
                          : PlanCardProgressRow.formatCompact(tracked),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: PlanCardTokens.timeColor,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(height: widget.spacing.progressAfterActualGap),
          PlanCardProgressRow(
            trackedSeconds: tracked,
            estimatedSeconds: estimated,
            categoryColor: widget.categoryColor,
            compact: true,
            alwaysShowTrack: true,
            trackHeight: widget.spacing.progressBarHeight,
          ),
        ],
      ),
    );
  }
}
'''
s = s[:start] + live_class + s[end:]
write(p, s)

p = "lib/core/widgets/plan_time_task_card/plan_time_task_card.dart"
s = read(p)
old = """            planEstimatedSeconds: widget.planEstimatedSeconds,
            categoryColor: categoryTone,"""
new = """            planEstimatedSeconds: widget.planEstimatedSeconds,
            categoryColor: categoryTone,
            isRunning: widget.highlightAsRunning,"""
s = replace_one(s, old, new, "pass running state to progress slot")
write(p, s)

# 4) Exact wall-time position is sacred. Stretch the shared wall-time scale to create
#    the 4px clearance; never pack/shift a card top away from its timeline coordinate.
p = "lib/features/planning/plan_time_view_layout.dart"
s = read(p)
s, removed = re.subn(
    r"\n  static bool _wallAdjacent\(double prevEndMin, double nextStartMin\) =>\n"
    r"      \(nextStartMin - prevEndMin\)\.abs\(\) < 0\.01;\n",
    "\n",
    s,
    count=1,
)
if removed != 1:
    raise SystemExit(f"wallAdjacent removal count={removed}")
old = """      final hasAdjacentNext =
          i + 1 < slots.length &&
          _wallAdjacent(slot.endMin, slots[i + 1].startMin);
      final requiredSpanPx =
          _cardHeightPx(slot.durationMin) +
          (hasAdjacentNext ? kPlanTimeCardGapPx : 0.0);
      final wallSpanMinutes = math.max(1.0, slot.endMin - slot.startMin);
      final requiredHourHeight = (requiredSpanPx / wallSpanMinutes * 60.0)
          .clamp(baseHourHeightPx, kPlanTimeMaxHourHeightPx)
          .toDouble();

      final firstHour = (visibleStart / 60.0).floor().clamp(0, hourCount - 1);
      final lastMinute = math.max(visibleStart, visibleEnd - 0.001);
      final lastHour = (lastMinute / 60.0).floor().clamp(0, hourCount - 1);"""
new = """      final next = i + 1 < slots.length ? slots[i + 1] : null;
      final nextIsNonOverlapping =
          next != null && next.startMin >= slot.endMin - 0.01;
      final clearanceEnd = nextIsNonOverlapping ? next.startMin : slot.endMin;
      final requiredSpanPx =
          _cardHeightPx(slot.durationMin) +
          (nextIsNonOverlapping ? kPlanTimeCardGapPx : 0.0);
      final wallSpanMinutes = math.max(1.0, clearanceEnd - slot.startMin);
      final requiredHourHeight = (requiredSpanPx / wallSpanMinutes * 60.0)
          .clamp(baseHourHeightPx, kPlanTimeMaxHourHeightPx)
          .toDouble();

      // Clearance is created by stretching the same wall-time scale used by
      // the hour grid. Card top stays exactly yForMinute(startMin).
      final visibleClearanceEnd = clearanceEnd
          .clamp(0.0, totalMinutes)
          .toDouble();
      final firstHour = (visibleStart / 60.0).floor().clamp(0, hourCount - 1);
      final lastMinute = math.max(visibleStart, visibleClearanceEnd - 0.001);
      final lastHour = (lastMinute / 60.0).floor().clamp(0, hourCount - 1);"""
s = replace_one(s, old, new, "4px shared-scale clearance")
write(p, s)

# 5) Behavioral contract: 5-minute precision, exact grid/card projection, independent controls.
p = "docs/UX_CONTRACT.md"
s = read(p)
old = "- **Snap / duration:** Time mode supports **10-minute** minimum duration and **10-minute** snap for move and top/bottom resize (`timelineSnapMinutes`, `kPlanScheduleSnapMinutes`, `kPlanTimeMinDurationMinutes`)."
new = "- **Snap / duration:** Time mode supports **10-minute** minimum duration and **5-minute** snap for move and top/bottom resize (`timelineSnapMinutes`, `kPlanScheduleSnapMinutes`, `kPlanTimeMinDurationMinutes`). Card top positions remain exact wall-time projections on the same Y scale as the timeline grid; no post-layout packing may shift them."
s = replace_one(s, old, new, "UX snap contract")
old = "- **Interactions:** Checkbox, play, menu, body tap, drag, and resize keep independent hit zones; optimistic schedule updates follow the Iron Laws."
new = "- **Interactions:** Checkbox, play, menu, body tap, drag, and resize keep independent hit zones; body drag/tap overlays must not cover trailing controls; optimistic schedule updates follow the Iron Laws."
s = replace_one(s, old, new, "UX independent control hit zones")
write(p, s)

# 6) Focused regressions in existing test files only.
p = "test/plan_time_view_wall_alignment_regression_test.dart"
s = read(p)
marker = "  test('only hours that need room stretch', () {"
tests = r'''  test('every 5-minute start uses the exact shared timeline Y coordinate', () {
    for (var minute = 0; minute < 60; minute += 5) {
      final result = _layout([
        _projection(
          hour: 14,
          minute: minute,
          durationMinutes: 10,
          id: 'five-$minute',
        ),
      ]);
      expect(
        result.layouts.single.topPx,
        closeTo(result.grid.yForMinute(minute.toDouble()), 0.001),
      );
    }

    final hourBoundary = _layout([
      _projection(hour: 15, minute: 0, durationMinutes: 10, id: 'hour'),
    ]);
    expect(
      hourBoundary.layouts.single.topPx,
      closeTo(hourBoundary.grid.hourLineY(1), 0.001),
    );
  });

  test('non-overlapping neighbors keep at least the canonical 4px gap', () {
    final result = _layout([
      _projection(hour: 15, minute: 0, durationMinutes: 10, id: 'gap-a'),
      _projection(hour: 15, minute: 15, durationMinutes: 10, id: 'gap-b'),
    ]);

    final a = result.layouts[0];
    final b = result.layouts[1];
    expect(a.topPx, closeTo(result.grid.yForMinute(60), 0.001));
    expect(b.topPx, closeTo(result.grid.yForMinute(75), 0.001));
    expect(
      b.topPx - (a.topPx + a.heightPx),
      greaterThanOrEqualTo(kPlanTimeCardGapPx - 0.01),
    );
  });

'''
s = replace_one(s, marker, tests + marker, "wall/grid and gap tests")
idx = s.rfind("\n}\n")
if idx < 0:
    raise SystemExit("test file closing marker not found")
live_test = r'''
  testWidgets('running progress time is fully visible and advances every second', (
    tester,
  ) async {
    final projection = _projection(
      hour: 15,
      minute: 0,
      durationMinutes: 60,
      id: 'live-progress',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 140,
            child: PlanTimeTaskCard(
              task: projection.projectedTask,
              density: PlanTimeTaskCardDensity.medium,
              surface: PlanCardSurface.timeline,
              timelineVisualDensity: PlanTimeCardVisualDensity.medium,
              timelineBlockHeightPx: 140,
              timelineFillHeight: true,
              showProgressBar: true,
              timeLabel: '15:00 – 16:00',
              planTrackedSeconds: 10,
              planEstimatedSeconds: 3600,
              highlightAsRunning: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final initial = find.text('00:10');
    expect(initial, findsOneWidget);
    expect(tester.getSize(initial).height, lessThanOrEqualTo(12.01));
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
'''
s = s[:idx] + live_test + s[idx:]
write(p, s)

p = "test/time_view_interaction_block_test.dart"
s = read(p)
s = replace_one(
    s,
    "import 'package:counter/features/planning/time_view/time_view_drag_state.dart';",
    """import 'package:counter/core/widgets/plan_time_task_card/plan_card_controls.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_density.dart';
import 'package:counter/features/planning/time_view/time_view_drag_state.dart';""",
    "interaction test imports",
)
s = replace_one(
    s,
    "import 'package:flutter/material.dart';",
    "import 'package:flutter/gestures.dart';\nimport 'package:flutter/material.dart';",
    "mouse test import",
)
marker = """  testWidgets(
    'phone swipe scrolls without starting move or resize',"""
play_test = r'''  testWidgets(
    'trailing play keeps hover and tap outside the desktop move zone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var playCount = 0;
      var bodyTapCount = 0;
      var moveStartCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 80,
                child: TimelinePlanInteractionBlock(
                  canMove: true,
                  canResize: true,
                  bulkSelectMode: false,
                  resizeHandlePx: 16,
                  blockHeightPx: 80,
                  isInteracting: false,
                  controlsLeftInset: 56,
                  controlsRightInset: planCardBodyGestureRightInsetPx(
                    hasPlay: true,
                    hasMenu: true,
                  ),
                  onBodyTap: () => bodyTapCount++,
                  onVerticalDragStart: (_) => moveStartCount++,
                  onVerticalDragUpdate: (_, __) {},
                  onVerticalDragEnd: () {},
                  onVerticalDragCancel: () {},
                  onResizeStart: (_) {},
                  onResizeUpdate: (_, __) {},
                  onResizeEnd: () {},
                  onResizeCancel: () {},
                  child: Stack(
                    children: [
                      Positioned(
                        top: 24,
                        right: 52,
                        child: PlanCardPlayButton(
                          onPlay: () => playCount++,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final play = find.byType(PlanCardPlayButton);
      expect(play, findsOneWidget);
      final decorated = find.descendant(
        of: play,
        matching: find.byType(DecoratedBox),
      );
      final before = (tester.widget<DecoratedBox>(decorated.first).decoration
              as BoxDecoration)
          .color;

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(play));
      await tester.pump();

      final after = (tester.widget<DecoratedBox>(decorated.first).decoration
              as BoxDecoration)
          .color;
      expect(after, isNot(equals(before)));

      await tester.tap(play);
      await tester.pump();
      expect(playCount, 1);
      expect(bodyTapCount, 0);
      expect(moveStartCount, 0);
      await mouse.removePointer();
    },
  );

'''
s = replace_one(s, marker, play_test + marker, "play hover/tap regression")
write(p, s)

# 7) Release note, limited to this requested repair.
p = "CHANGELOG.md"
s = read(p)
entry = """## 2026-09-10 — Planning Time precision and controls [product]

- Restored exact shared grid/card Y mapping at 5-minute move/resize precision; a plan starting on an hour line now starts exactly on that line.
- Restored a minimum 4px visual gap for non-overlapping neighboring Time View cards by stretching the shared hour scale instead of moving card tops.
- Restored clickable/hoverable trailing Play controls and an unclipped, second-by-second live actual-time label above the progress bar without full-page timer invalidation.

"""
write(p, entry + s)
