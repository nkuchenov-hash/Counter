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


# 1. Keep the Time View direct-manipulation overlay away from BOTH trailing controls.
p = "lib/core/widgets/plan_time_task_card/plan_card_density.dart"
s = read(p)
old = """/// Right inset for timeline drag/tap body zone ? excludes menu button column.
double planCardBodyGestureRightInsetPx({bool hasMenu = true}) =>
    hasMenu ? PlanCardGeom.menuSize + PlanCardGeom.padRight : 0;"""
if old not in s:
    # The source can contain the normal unicode dash instead of the historical replacement glyph.
    pattern = re.compile(
        r"/// Right inset for timeline drag/tap body zone[^\n]*\n"
        r"double planCardBodyGestureRightInsetPx\(\{bool hasMenu = true\}\) =>\n"
        r"    hasMenu \? PlanCardGeom\.menuSize \+ PlanCardGeom\.padRight : 0;"
    )
    replacement = """/// Right inset for timeline drag/tap body zone.
///
/// Time View renders Play + Menu as trailing controls. The body drag/tap
/// overlay must stop before both controls so pointer hover/tap reaches them.
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
    s, n = pattern.subn(replacement, s, count=1)
    if n != 1:
        raise SystemExit(f"right inset patch count={n}")
else:
    s = replace_one(
        s,
        old,
        """/// Right inset for timeline drag/tap body zone.
///
/// Time View renders Play + Menu as trailing controls. The body drag/tap
/// overlay must stop before both controls so pointer hover/tap reaches them.
double planCardBodyGestureRightInsetPx({
  bool hasPlay = false,
  bool hasMenu = true,
}) {
  final count = (hasPlay ? 1 : 0) + (hasMenu ? 1 : 0);
  if (count == 0) return 0;
  return PlanCardGeom.padRight +
      count * PlanCardGeom.controlSize +
      (count - 1) * 8.0;
}""",
        "right interaction inset",
    )
write(p, s)

p = "lib/features/planning/time_view/time_view_card_layer.dart"
s = read(p)
s = replace_one(
    s,
    """    final blockDensity = layout.density;
    final resizeHeightPx = math.max(heightPx, kPlanTimeCardMinHeightPx);""",
    """    final blockDensity = layout.density;
    final displayDone = host.planDoneOverride[planKey] ?? layout.task.isDone;
    final hasTrailingPlay = !host.planSelectMode && !displayDone;
    final resizeHeightPx = math.max(heightPx, kPlanTimeCardMinHeightPx);""",
    "derive trailing play state",
)
s = replace_one(
    s,
    "controlsRightInset: planCardBodyGestureRightInsetPx(),",
    """controlsRightInset: planCardBodyGestureRightInsetPx(
                    hasPlay: hasTrailingPlay,
                  ),""",
    "exclude play from body overlay",
)
s = replace_one(
    s,
    """                        displayDone:
                            host.planDoneOverride[planKey] ??
                            layout.task.isDone,""",
    "                        displayDone: displayDone,",
    "reuse display done",
)
write(p, s)

# 2. Give the actual-time label its real 12px line box; the previous 8px slot clipped 10px/1.2 text.
p = "lib/core/widgets/plan_time_task_card/plan_card_geometry.dart"
s = read(p)
s = replace_one(
    s,
    "  static const double actualTimeSlotHeight = 8;",
    "  static const double actualTimeSlotHeight = 12;",
    "actual time slot height",
)
write(p, s)

# 3. Make actual time live only inside the small progress slot while a linked plan is running.
p = "lib/core/widgets/plan_time_task_card/plan_card_progress.dart"
s = read(p)
if "import 'dart:async';" not in s:
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
      // Parent aggregates include the open record through planetary-now.
      // Accept a newer authoritative value, but never jump a live counter back.
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
    final value = seconds.clamp(0, 8640000);
    final hours = value ~/ 3600;
    final minutes = (value % 3600) ~/ 60;
    final secs = value % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');
    if (hours > 0) return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
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
    final hasActual = tracked > 0 || widget.isRunning;
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
s = replace_one(
    s,
    """            planEstimatedSeconds: widget.planEstimatedSeconds,
            categoryColor: categoryTone,
            spacing: cardSpacing,""",
    """            planEstimatedSeconds: widget.planEstimatedSeconds,
            categoryColor: categoryTone,
            isRunning: widget.highlightAsRunning,
            spacing: cardSpacing,""",
    "pass running state to progress slot",
)
write(p, s)

# 4. Lock the requested Time View behavior into the UX contract. Runtime snap is already 5 minutes.
p = "docs/UX_CONTRACT.md"
s = read(p)
s = replace_one(
    s,
    "- **Snap / duration:** Time mode supports **10-minute** minimum duration and **10-minute** snap for move and top/bottom resize (`timelineSnapMinutes`, `kPlanScheduleSnapMinutes`, `kPlanTimeMinDurationMinutes`).",
    "- **Snap / duration:** Time mode supports **10-minute** minimum duration and **5-minute** snap for move and top/bottom resize (`timelineSnapMinutes`, `kPlanScheduleSnapMinutes`, `kPlanTimeMinDurationMinutes`). Card top positions are exact wall-time projections on the same Y scale as the timeline grid: an hour-boundary start aligns exactly with that hour line, and no post-layout packing may shift the card top.",
    "5-minute exact-position UX contract",
)
s = replace_one(
    s,
    "- **Interactions:** Checkbox, play, menu, body tap, drag, and resize keep independent hit zones; optimistic schedule updates follow the Iron Laws.",
    "- **Interactions:** Checkbox, play, menu, body tap, drag, and resize keep independent hit zones; Time View body drag/tap overlays must not cover trailing Play/Menu controls; optimistic schedule updates follow the Iron Laws.",
    "independent control hit zones UX contract",
)
write(p, s)

# 5. Changelog: exactly this repair, no unrelated redesign claim.
p = "CHANGELOG.md"
s = read(p)
entry = """## 2026-09-10 — Planning Time precision and controls [fix]\n\n- Kept Time View card starts on the same wall-time Y scale as hour grid lines with 5-minute interaction precision and the existing 4px minimum card gap.\n- Restored pointer access to the trailing Play control without changing its existing hover design or card drag/resize behavior.\n- Made running actual time above the progress bar fully visible and locally live to the second.\n\n"""
if entry not in s:
    first_heading = s.find("## ")
    if first_heading < 0:
        s = entry + s
    else:
        s = s[:first_heading] + entry + s[first_heading:]
write(p, s)

# 6. Focused regression coverage for the requested geometry, 4px gap, Play pointer routing, and live time.
p = "test/plan_time_view_wall_alignment_regression_test.dart"
s = read(p)
marker = "  test('only hours that need room stretch', () {"
geometry_tests = r'''  test('every 5-minute start uses the exact shared timeline Y coordinate', () {
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

  test('touching scheduled cards keep the canonical 4px minimum visual gap', () {
    final result = _layout([
      _projection(hour: 15, minute: 0, durationMinutes: 10, id: 'gap-a'),
      _projection(hour: 15, minute: 10, durationMinutes: 10, id: 'gap-b'),
    ]);

    final a = result.layouts[0];
    final b = result.layouts[1];
    expect(a.topPx, closeTo(result.grid.yForMinute(60), 0.001));
    expect(b.topPx, closeTo(result.grid.yForMinute(70), 0.001));
    expect(
      b.topPx - (a.topPx + a.heightPx),
      greaterThanOrEqualTo(kPlanTimeCardGapPx - 0.01),
    );
  });

'''
s = replace_one(s, marker, geometry_tests + marker, "geometry regression tests")
closing = s.rfind("\n}\n")
if closing < 0:
    raise SystemExit("wall alignment test closing marker not found")
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

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:11'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
'''
s = s[:closing] + live_test + s[closing:]
write(p, s)

p = "test/time_view_interaction_block_test.dart"
s = read(p)
if "plan_card_controls.dart" not in s:
    s = s.replace(
        "import 'package:counter/features/planning/time_view/time_view_drag_state.dart';",
        "import 'package:counter/core/widgets/plan_time_task_card/plan_card_controls.dart';\nimport 'package:counter/features/planning/time_view/time_view_drag_state.dart';",
        1,
    )
marker = "  testWidgets(\n    'phone swipe scrolls without starting move or resize',"
play_test = r'''  testWidgets(
    'trailing Play keeps hover and tap outside the desktop move zone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var playCount = 0;
      var moveStarts = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 80,
                child: TimelinePlanInteractionBlock(
                  canMove: true,
                  canResize: false,
                  bulkSelectMode: false,
                  resizeHandlePx: 16,
                  blockHeightPx: 80,
                  isInteracting: false,
                  controlsRightInset: 84,
                  onVerticalDragStart: (_) => moveStarts++,
                  child: Stack(
                    children: [
                      const Positioned.fill(child: SizedBox.expand()),
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
      final decorationFinder = find.descendant(
        of: play,
        matching: find.byType(DecoratedBox),
      ).first;
      final before = tester.widget<DecoratedBox>(decorationFinder).decoration
          as BoxDecoration;

      await tester.moveMouseTo(tester.getCenter(play));
      await tester.pump();
      final after = tester.widget<DecoratedBox>(decorationFinder).decoration
          as BoxDecoration;
      expect(after.color, isNot(equals(before.color)));

      await tester.tap(play);
      await tester.pump();
      expect(playCount, 1);
      expect(moveStarts, 0);
    },
  );

'''
s = replace_one(s, marker, play_test + marker, "play interaction regression test")
write(p, s)
