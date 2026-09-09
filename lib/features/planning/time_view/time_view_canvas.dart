import 'dart:async';

import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/shared/diagnostics/performance/shell_flags.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

import 'package:counter/features/planning/time_view/planning_time_view.dart';
import 'package:counter/features/planning/time_view/time_view_card_layer.dart';
import 'package:counter/features/planning/time_view/time_view_hour_grid.dart';

const double kPlanningTimeViewMaxContentWidth = 1240;

extension PlanningTimeViewTimeViewCanvas on PlanningTimeViewCoordinator {
  Widget buildProportionalDayTimelineCanvas({
    required ColorScheme scheme,
    required String loc,
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
    required List<int> visibleHours,
    required List<PlanningTask> scheduledInRange,
    required List<TimeModeProjectedPlan> projections,
    required String selectedDayKey,
    required Map<String, int> planActualByPbId,
  }) {
    final durationResult = computeTimelineDurationLayout(
      projections,
      planWallDay,
      rangeStart,
      rangeEnd,
      selectedDayKey,
    );
    activeTimelineDurationGrid = durationResult.grid;
    final grid = durationResult.grid;
    final layouts = durationResult.layouts;
    final canvasHeight = timelineCanvasHeightPx(grid);
    final gridColor = scheme.outlineVariant.withValues(alpha: 0.18);
    final railColor = scheme.brightness == Brightness.light
        ? const Color(0xFFB6C0CC)
        : const Color(0xFF667483);
    final nowTop = timelineNowLineTopPx(planWallDay, rangeStart, rangeEnd, grid);
    final wallNow = profileWallNow();
    final nowLabel = nowTop != null
        ? '${wallNow.hour.toString().padLeft(2, '0')}:${wallNow.minute.toString().padLeft(2, '0')}'
        : null;
    if (nowTop != null) {
      maybeAutoScrollTimelineToNow(nowTop, canvasHeight);
    }

    final compact = timelineCompactLayout(host.context);
    final railWidth = timelineRailWidthPx(host.context);
    final desktop = shellUsesSideNavigation(MediaQuery.sizeOf(host.context).width);
    final contentHorizontalInset = desktop
        ? kShellDesktopContentHorizontalPadding
        : 8.0;
    final axisX = railWidth - 10.0;
    final prevMarker = t(loc, 'day_length_prev_day');
    final nextMarker = t(loc, 'day_length_next_day');
    String hourLabel(int extHour) {
      final clock = PlanningSheetTimelinePrefs.formatExtendedHourClock(extHour);
      final mod = PlanningSheetTimelinePrefs.displayHourMod24(extHour);
      if (extHour < 0) {
        return compact ? '$mod$prevMarker' : '$clock $prevMarker';
      }
      if (extHour >= 24) {
        return compact ? '$mod$nextMarker' : '$clock $nextMarker';
      }
      return compact ? '$mod' : clock;
    }

    final canvas = SizedBox(
      height: canvasHeight + 8,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: kPlanningTimeViewMaxContentWidth,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: contentHorizontalInset),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: railWidth,
                    height: canvasHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: axisX,
                          child: IgnorePointer(
                            child: Container(width: 1, color: railColor),
                          ),
                        ),
                        for (var i = 0; i < visibleHours.length; i++) ...[
                          Positioned(
                            top: grid.hourLineY(i) - 6,
                            left: 0,
                            right: 14,
                            child: Text(
                              hourLabel(visibleHours[i]),
                              style: Theme.of(host.context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurface.withValues(
                                      alpha: 0.64,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                            ),
                          ),
                          Positioned(
                            top: grid.hourLineY(i) - 3,
                            left: axisX - 3,
                            child: IgnorePointer(
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: railColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (nowTop != null && nowLabel != null)
                          Positioned(
                            top: nowTop.clamp(0, canvasHeight - 1) - 10,
                            left: 0,
                            right: 14,
                            child: IgnorePointer(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(alpha: 0.94),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    nowLabel,
                                    style: Theme.of(host.context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: scheme.onPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: canvasHeight,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              for (var i = 0; i < visibleHours.length; i++)
                                Positioned(
                                  top: grid.hourLineY(i),
                                  left: 0,
                                  right: 0,
                                  height: grid.hourBandHeightPx,
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        child: Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: gridColor,
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 4,
                                        child: IconButton(
                                          tooltip: t(loc, 'plan_quick_add_hour'),
                                          padding: EdgeInsets.zero,
                                          constraints:
                                              const BoxConstraints.tightFor(
                                                width: 28,
                                                height: 28,
                                              ),
                                          visualDensity: VisualDensity.compact,
                                          style: IconButton.styleFrom(
                                            foregroundColor: scheme
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.38),
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          iconSize: 18,
                                          icon: const Icon(Icons.add_rounded),
                                          onPressed: () => host
                                              .openQuickAddForHour(
                                                visibleHours[i],
                                              ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: DragTarget<PlanningTask>(
                                          hitTestBehavior:
                                              HitTestBehavior.translucent,
                                          onWillAcceptWithDetails: (_) =>
                                              !host.planSelectMode &&
                                              timelineVerticalDragPlanKey ==
                                                  null &&
                                              timelineResizePlanKey == null,
                                          onAcceptWithDetails: (details) {
                                            unawaited(
                                              onPlanningTaskDroppedOnHour(
                                                details.data,
                                                visibleHours[i],
                                              ),
                                            );
                                          },
                                          builder:
                                              (context, candidate, rejected) {
                                                final hover =
                                                    candidate.isNotEmpty;
                                                return GestureDetector(
                                                  behavior: HitTestBehavior
                                                      .translucent,
                                                  onTap: () => host
                                                      .openQuickAddForHour(
                                                        visibleHours[i],
                                                      ),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 120,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: hover
                                                          ? scheme
                                                                .primaryContainer
                                                                .withValues(
                                                                  alpha: 0.28,
                                                                )
                                                          : null,
                                                    ),
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (timelineDragInsertMarkerTopPx != null &&
                                  timelineVerticalDragPlanKey != null)
                                Positioned(
                                  top: timelineDragInsertMarkerTopPx!.clamp(
                                    0,
                                    canvasHeight - 4,
                                  ),
                                  left: 6,
                                  right: 6,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: scheme.primary.withValues(
                                        alpha: 0.62,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: scheme.primary.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ...[
                                ...layouts
                                    .where(
                                      (l) =>
                                          host.planKey(l.task) !=
                                          timelineElevatedPlanKey(),
                                    )
                                    .map(
                                      (layout) => buildTimelinePlanStackLayer(
                                        layout: layout,
                                        canvasHeight: canvasHeight,
                                        scheme: scheme,
                                        planWallDay: planWallDay,
                                        rangeStart: rangeStart,
                                        rangeEnd: rangeEnd,
                                        selectedDayKey: selectedDayKey,
                                        planActualByPbId: planActualByPbId,
                                        scheduledInRange: scheduledInRange,
                                      ),
                                    ),
                                ...layouts
                                    .where(
                                      (l) =>
                                          host.planKey(l.task) ==
                                          timelineElevatedPlanKey(),
                                    )
                                    .map(
                                      (layout) => buildTimelinePlanStackLayer(
                                        layout: layout,
                                        canvasHeight: canvasHeight,
                                        scheme: scheme,
                                        planWallDay: planWallDay,
                                        rangeStart: rangeStart,
                                        rangeEnd: rangeEnd,
                                        selectedDayKey: selectedDayKey,
                                        planActualByPbId: planActualByPbId,
                                        scheduledInRange: scheduledInRange,
                                      ),
                                    ),
                              ],
                              if (nowTop != null)
                                Positioned(
                                  top: nowTop.clamp(0, canvasHeight - 1),
                                  left: 0,
                                  right: 0,
                                  child: IgnorePointer(
                                    child: Container(
                                      height: 2,
                                      decoration: BoxDecoration(
                                        color: scheme.primary.withValues(
                                          alpha: 0.78,
                                        ),
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (ShellFlags.enableTimelineRepaintBoundary) {
      return RepaintBoundary(child: canvas);
    }
    return canvas;
  }
}
