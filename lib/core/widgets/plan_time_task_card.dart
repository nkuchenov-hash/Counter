// ---------------------------------------------------------------------------
// PlanTimeTaskCard ? CardPlan_Small / CardPlan_Medium / CardPlan_Large
// Geometry source: Figma MCP metadata (328px ref). Visual tokens: design/*.svg
// ---------------------------------------------------------------------------

import 'dart:math' as math;

import 'package:counter/core/performance/rebuild_metrics.dart';
import 'package:counter/core/plan_category_lookup.dart';
import 'package:counter/data/models.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

enum PlanTimeTaskCardDensity { micro, compact, medium, large }

/// Minimum rendered CardPlan height in Time View (VerySmall).
const double kPlanTimeCardMinHeightPx = 38.0;

/// Minimum vertical gap between adjacent Time View cards.
const double kPlanTimeCardGapPx = 2.0;

/// Padding below the last card when computing stretched hour height.
const double kPlanTimeHourVerticalPaddingPx = 4.0;

/// Hard cap for a single hour band (prevents infinite day growth).
const double kPlanTimeMaxReasonableHourHeightPx = 480.0;

/// Stable px-per-minute for **card** height only ? never stretched-hour ppm.
/// 10-minute tasks map to 38px (VerySmall); hour stretch does not inflate cards.
const double kPlanTimeStableBaseCardPxPerMinute = 3.8;

/// Card rendered height from scheduled duration (independent of hour stretch).
double planTimeCardRenderedHeightPxForDuration(int durationMinutes) {
  final dur = math.max(5, durationMinutes);
  return math.max(
    dur * kPlanTimeStableBaseCardPxPerMinute,
    kPlanTimeCardMinHeightPx,
  );
}

/// Default hour band height before stretch.
const double kPlanTimeViewBaseHourHeightMinPx = 120.0;
const double kPlanTimeViewBaseHourHeightMaxPx = 160.0;

/// Visual density bands from CardPlan reference screenshots (Time View).
enum PlanTimeCardVisualDensity {
  verySmall,
  small,
  moreCompact,
  compact,
  medium,
}

/// Maps final rendered block height to CardPlan visual density.
PlanTimeCardVisualDensity planTimeCardVisualDensityForRenderedHeight(
  double renderedHeightPx,
) {
  final h = math.max(renderedHeightPx, kPlanTimeCardMinHeightPx);
  if (h <= 38) return PlanTimeCardVisualDensity.verySmall;
  if (h <= 54) return PlanTimeCardVisualDensity.small;
  if (h <= 77) return PlanTimeCardVisualDensity.moreCompact;
  if (h <= 94) return PlanTimeCardVisualDensity.compact;
  return PlanTimeCardVisualDensity.medium;
}

PlanTimeTaskCardDensity planTimeCardTaskDensityForVisual(
  PlanTimeCardVisualDensity visual,
) {
  switch (visual) {
    case PlanTimeCardVisualDensity.verySmall:
      return PlanTimeTaskCardDensity.compact;
    case PlanTimeCardVisualDensity.small:
      return PlanTimeTaskCardDensity.micro;
    case PlanTimeCardVisualDensity.moreCompact:
    case PlanTimeCardVisualDensity.compact:
      return PlanTimeTaskCardDensity.compact;
    case PlanTimeCardVisualDensity.medium:
      return PlanTimeTaskCardDensity.medium;
  }
}

bool planTimeCardShowProgressForVisual(PlanTimeCardVisualDensity density) {
  return density == PlanTimeCardVisualDensity.compact ||
      density == PlanTimeCardVisualDensity.medium;
}

bool planTimeCardShowFooterBreadcrumbForVisual(
  PlanTimeCardVisualDensity density,
) {
  return density == PlanTimeCardVisualDensity.compact ||
      density == PlanTimeCardVisualDensity.medium;
}

bool planTimeCardUseTimelineFillHeightForVisual(
  PlanTimeCardVisualDensity density,
) {
  return density != PlanTimeCardVisualDensity.small;
}

/// Where the card is rendered ? drives height/interaction assumptions.
enum PlanCardSurface { list, timeline, calendar }

/// CardPlan-style unified plan task card (list, timeline, calendar).
class PlanTimeTaskCard extends StatefulWidget {
  const PlanTimeTaskCard({
    super.key,
    required this.task,
    required this.density,
    required this.timeLabel,
    this.surface = PlanCardSurface.timeline,
    this.timelineVisualDensity,
    this.timelineBlockHeightPx,
    this.displayIsDone = false,
    this.selectMode = false,
    this.isSelected = false,
    this.highlightAsRunning = false,
    this.interacting = false,
    this.toggleDoneEnabled = true,
    this.planTrackedSeconds = 0,
    this.planEstimatedSeconds,
    this.scheduleConflict = false,
    this.metaIcons = const [],
    this.showFooterBreadcrumb = true,
    this.showProgressBar = true,
    this.timelineFillHeight = false,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.onOpenMenu,
    this.onTap,
    this.onLongPress,
  });

  final PlanningTask task;
  final PlanTimeTaskCardDensity density;
  final PlanCardSurface surface;
  /// Time View CardPlan band from rendered block height (explicit layout path).
  final PlanTimeCardVisualDensity? timelineVisualDensity;
  final double? timelineBlockHeightPx;
  final String timeLabel;
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final bool highlightAsRunning;
  final bool interacting;
  final bool toggleDoneEnabled;
  final int planTrackedSeconds;
  final int? planEstimatedSeconds;
  final bool scheduleConflict;
  final List<Widget> metaIcons;
  final bool showFooterBreadcrumb;
  final bool showProgressBar;
  /// When true (Time mode duration blocks), card fills parent height and pins
  /// progress + footer to the bottom edge.
  final bool timelineFillHeight;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext menuContext)? onOpenMenu;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<PlanTimeTaskCard> createState() => _PlanTimeTaskCardState();
}

class _PlanTimeTaskCardState extends State<PlanTimeTaskCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _completionCtrl;

  @override
  void initState() {
    super.initState();
    _completionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    if (widget.displayIsDone) {
      _completionCtrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant PlanTimeTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.displayIsDone && widget.displayIsDone) {
      _completionCtrl.forward(from: 0);
    } else if (oldWidget.displayIsDone && !widget.displayIsDone) {
      _completionCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _completionCtrl.dispose();
    super.dispose();
  }

  bool get _hasRepeat =>
      (widget.task.rrule?.trim().isNotEmpty ?? false) ||
      (widget.task.recurrenceInstanceDateKey?.trim().isNotEmpty ?? false);

  bool get _showPlay =>
      !widget.selectMode && !widget.displayIsDone && widget.onPlay != null;

  List<Tag> get _visibleTags =>
      widget.task.tags.where((t) => t.rendersAsChip).toList(growable: false);

  bool get _isListLike =>
      widget.surface == PlanCardSurface.list ||
      widget.surface == PlanCardSurface.calendar ||
      (widget.surface == PlanCardSurface.timeline &&
          widget.timelineVisualDensity == null &&
          !widget.timelineFillHeight);

  @override
  Widget build(BuildContext context) {
    rebuildMetricsTick('PlanTimeTaskCard');
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final lookup = PlanCategoryLookup.resolve;
    final categoryPresentation = lookup?.call(widget.task.categoryId);
    final categoryTone = categoryPresentation?.color ??
        Theme.of(context).colorScheme.primary;
    final categoryTrailRaw = widget.showFooterBreadcrumb
        ? localizeCategoryBreadcrumbPath(
            (categoryPresentation?.breadcrumbPath ?? '').trim(),
            loc,
          ).trim()
        : '';
    final categoryTrail = categoryTrailRaw;
    final categoryIcon = categoryPresentation?.icon;
    final effectiveTimeLabel = widget.timeLabel.trim().isNotEmpty
        ? widget.timeLabel.trim()
        : _planCardWallTimeLabel(widget.task);

    final hovered = _hovered && !widget.interacting;
    final selected = widget.selectMode && widget.isSelected;
    final borderColor = selected
        ? scheme.primary.withValues(alpha: 0.52)
        : widget.highlightAsRunning
            ? scheme.primary
            : widget.interacting
                ? scheme.primary.withValues(alpha: 0.45)
                : hovered
                    ? scheme.outlineVariant.withValues(alpha: 0.62)
                    : scheme.outlineVariant.withValues(alpha: 0.38);
    final borderWidth = selected
        ? 1.25
        : widget.highlightAsRunning
            ? 1.75
            : widget.interacting
                ? 1.5
                : hovered
                    ? 1.25
                    : 1.0;

    var surface = selected
        ? Color.alphaBlend(
            scheme.primaryContainer.withValues(alpha: 0.16),
            _PlanCardTokens.surface,
          )
        : _PlanCardTokens.surface;
    if (hovered) {
      surface = Color.alphaBlend(
        scheme.surfaceContainerHighest.withValues(alpha: 0.28),
        surface,
      );
    }

    final effectiveDensity = widget.density;
    final useInvariantSlots =
        (effectiveDensity == PlanTimeTaskCardDensity.medium ||
            effectiveDensity == PlanTimeTaskCardDensity.large) &&
        widget.showProgressBar;
    const cardSpacing = _PlanCardVerticalSpacing.shared;
    final progressSlot = useInvariantSlots
        ? _PlanCardProgressSlot(
            planTrackedSeconds: widget.planTrackedSeconds,
            planEstimatedSeconds: widget.planEstimatedSeconds,
            categoryColor: categoryTone,
            spacing: cardSpacing,
          )
        : null;

    Widget body;
    if (widget.surface == PlanCardSurface.timeline &&
        widget.timelineVisualDensity != null) {
      body = _TimeViewDensityBody(
        visual: widget.timelineVisualDensity!,
        heightPx: widget.timelineBlockHeightPx ?? kPlanTimeCardMinHeightPx,
        task: widget.task,
        timeLabel: effectiveTimeLabel,
        categoryTrail: widget.showFooterBreadcrumb ? categoryTrail : '',
        categoryColor: categoryTone,
        displayIsDone: widget.displayIsDone,
        selectMode: widget.selectMode,
        isSelected: widget.isSelected,
        hasRepeat: _hasRepeat,
        showPlay: _showPlay,
        visibleTags: _visibleTags,
        scheduleConflict: widget.scheduleConflict,
        toggleDoneEnabled: widget.toggleDoneEnabled,
        metaIcons: widget.metaIcons,
        showProgressBar: widget.showProgressBar,
        metricsBlock: progressSlot,
        spacing: cardSpacing,
        onToggleDone: widget.onToggleDone,
        onSelectToggle: widget.onSelectToggle,
        onPlay: widget.onPlay,
        onOpenMenu: widget.onOpenMenu,
        onBodyTap: widget.onTap,
        onBodyLongPress: widget.onLongPress,
      );
    } else {
    switch (effectiveDensity) {
      case PlanTimeTaskCardDensity.micro:
        body = _TimelinePlanCardSmall(
          task: widget.task,
          timeLabel: widget.timeLabel,
          displayIsDone: widget.displayIsDone,
          selectMode: widget.selectMode,
          isSelected: widget.isSelected,
          hasRepeat: _hasRepeat,
          showPlay: _showPlay,
          visibleTags: _visibleTags,
          toggleDoneEnabled: widget.toggleDoneEnabled,
          metaIcons: widget.metaIcons,
          metricsBlock: progressSlot,
          onToggleDone: widget.onToggleDone,
          onSelectToggle: widget.onSelectToggle,
          onPlay: widget.onPlay,
          onOpenMenu: widget.onOpenMenu,
          onBodyTap: widget.onTap,
          onBodyLongPress: widget.onLongPress,
        );
      case PlanTimeTaskCardDensity.compact:
        body = _TimelinePlanCardSmall(
          task: widget.task,
          timeLabel: effectiveTimeLabel,
          displayIsDone: widget.displayIsDone,
          selectMode: widget.selectMode,
          isSelected: widget.isSelected,
          hasRepeat: _hasRepeat,
          showPlay: _showPlay,
          visibleTags: _visibleTags,
          toggleDoneEnabled: widget.toggleDoneEnabled,
          metaIcons: widget.metaIcons,
          metricsBlock: progressSlot,
          timelineFillHeight: widget.timelineFillHeight,
          categoryTrail: widget.showFooterBreadcrumb ? categoryTrail : '',
          categoryColor: categoryTone,
          scheduleConflict: widget.scheduleConflict,
          onToggleDone: widget.onToggleDone,
          onSelectToggle: widget.onSelectToggle,
          onPlay: widget.onPlay,
          onOpenMenu: widget.onOpenMenu,
          onBodyTap: widget.onTap,
          onBodyLongPress: widget.onLongPress,
        );
      case PlanTimeTaskCardDensity.medium:
        body = _TimelinePlanCardMedium(
          task: widget.task,
          timeLabel: effectiveTimeLabel,
          categoryTrail:
              widget.showFooterBreadcrumb ? categoryTrail : '',
          categoryColor: categoryTone,
          displayIsDone: widget.displayIsDone,
          selectMode: widget.selectMode,
          isSelected: widget.isSelected,
          hasRepeat: _hasRepeat,
          showPlay: _showPlay,
          visibleTags: _visibleTags,
          scheduleConflict: widget.scheduleConflict,
          toggleDoneEnabled: widget.toggleDoneEnabled,
          metaIcons: widget.metaIcons,
          metricsBlock: progressSlot,
          spacing: cardSpacing,
          timelineFillHeight: widget.timelineFillHeight,
          onToggleDone: widget.onToggleDone,
          onSelectToggle: widget.onSelectToggle,
          onPlay: widget.onPlay,
          onOpenMenu: widget.onOpenMenu,
          onBodyTap: widget.onTap,
          onBodyLongPress: widget.onLongPress,
          titleMaxLines: 1,
        );
      case PlanTimeTaskCardDensity.large:
        body = _TimelinePlanCardLarge(
          task: widget.task,
          timeLabel: effectiveTimeLabel,
          categoryTrail:
              widget.showFooterBreadcrumb ? categoryTrail : '',
          categoryColor: categoryTone,
          displayIsDone: widget.displayIsDone,
          selectMode: widget.selectMode,
          isSelected: widget.isSelected,
          hasRepeat: _hasRepeat,
          showPlay: _showPlay,
          visibleTags: _visibleTags,
          scheduleConflict: widget.scheduleConflict,
          toggleDoneEnabled: widget.toggleDoneEnabled,
          metaIcons: widget.metaIcons,
          metricsBlock: progressSlot,
          spacing: cardSpacing,
          timelineFillHeight: widget.timelineFillHeight,
          onToggleDone: widget.onToggleDone,
          onSelectToggle: widget.onSelectToggle,
          onPlay: widget.onPlay,
          onOpenMenu: widget.onOpenMenu,
          onBodyTap: widget.onTap,
          onBodyLongPress: widget.onLongPress,
        );
    }
    }

    final minH = _isListLike
        ? planTimeCardListMinHeight(widget.density)
        : null;

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_PlanCardGeom.radius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: _PlanCardTokens.cardShadow(
          widget.interacting,
          hovered: hovered,
        ),
      ),
      child: ClipRRect(
        clipBehavior: Clip.none,
        borderRadius: BorderRadius.circular(_PlanCardGeom.radius),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final timelineBlockH = widget.timelineBlockHeightPx;
            final measuredH = widget.surface == PlanCardSurface.timeline &&
                    widget.timelineVisualDensity != null &&
                    timelineBlockH != null
                ? timelineBlockH
                : planTimeCardMeasureHeight(
                    hasTags: _visibleTags.isNotEmpty,
                    hasTrackedProgress: widget.planTrackedSeconds > 0,
                    density: effectiveDensity,
                  );
            final h = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : measuredH;
            final showWatermark = widget.surface != PlanCardSurface.timeline &&
                !widget.timelineFillHeight &&
                effectiveDensity != PlanTimeTaskCardDensity.micro &&
                h >= _PlanCardGeom.watermarkMinCardHeight;
            return SizedBox(
              height: h.isFinite ? h : measuredH,
              width: w.isFinite ? w : null,
              child: Stack(
              fit: StackFit.passthrough,
              children: [
                if (showWatermark)
                  _PlanCardWatermark(
                    icon: categoryIcon,
                    color: categoryTone,
                    density: effectiveDensity,
                    cardWidth: w.isFinite ? w : _PlanCardGeom.refWidth,
                    cardHeight: h.isFinite ? h : measuredH,
                  ),
                body,
              ],
            ),
            );
          },
        ),
      ),
    );

    if (minH != null) {
      card = ConstrainedBox(
        constraints: BoxConstraints(minHeight: minH),
        child: card,
      );
    }

    card = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: card,
    );

    if (_completionCtrl.isAnimating) {
      card = AnimatedBuilder(
        animation: _completionCtrl,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_completionCtrl.value);
          return Opacity(
            opacity: (1.0 - 0.12 * t).clamp(0.88, 1.0),
            child: child,
          );
        },
        child: card,
      );
    } else if (widget.displayIsDone) {
      card = Opacity(opacity: 0.88, child: card);
    }

    return card;
  }
}

// --- Figma geometry (328px reference) ----------------------------------------

abstract final class _PlanCardGeom {
  static const double refWidth = 328;
  static const double padLeft = 12;
  static const double padRight = 12;
  static const double padTopMediumLarge = 10;
  static const double padTopSmall = 10;
  static const double controlSize = 32;
  static const double playInlineX = 48;
  static const double contentXSmall = 84;
  static const double contentXMediumLarge = 56;
  static const double railWidth = 32;
  static const double railToContentGap = 12;
  static const double checkboxPlayGap = 8;
  static const double playIconWidth = 22;
  static const double playIconHeight = 24;
  static const double playIconCornerRadius = 4.0;
  static const double recurringIconSize = 15;
  static const double titleToRecurringGap = 5;
  static const double playAfterCheckboxGap = 4;
  static const double menuSize = 33;
  static const double timeViewRailToContentGap = 6;
  static const double contentSpanMediumLarge = 260;
  static const double radius = 12;
  static const double refHeightMicro = 38;
  static const double refHeightSmall = 54;
  static const double refHeightMedium = 106;
  static const double refHeightLarge = 147;
  static const double tagRowHeight = 16;
  static const double tagGap = 5;
  static const double titleToTagsGap = 2;
  static const double emptyTagsSlotHeight = 18;
  static const double tagsToProgressGap = 3;
  static const double actualTimeSlotHeight = 8;
  static const double progressAfterActualGap = 3;
  static const double progressBarHeight = 3;
  static const double footerBlockGap = 6;
  static const double footerTimeGap = 6;
  static const double footerTimeRightSafePad = 6;
  static const double footerTextHeight = 14;
  static const double footerBottomPad = 8;
  static const double titleTopInset = 0;
  static const double titleLineHeight = 16;
  static const double titleRowHeight = 33;
  static const double timelineBlockAllowancePx = 2;
  static const double watermarkMinCardHeight = 90;

  static double refHeight(PlanTimeTaskCardDensity d) => switch (d) {
        PlanTimeTaskCardDensity.micro => refHeightMicro,
        PlanTimeTaskCardDensity.compact => refHeightSmall,
        PlanTimeTaskCardDensity.medium => refHeightMedium,
        PlanTimeTaskCardDensity.large => refHeightLarge,
      };

  static double contentSpanWidth(double cardWidth) =>
      cardWidth - contentXMediumLarge - padRight;
}

/// Single shared vertical rhythm for list, calendar, and Time mode.
final class _PlanCardVerticalSpacing {
  const _PlanCardVerticalSpacing._({
    required this.padTop,
    required this.padBottom,
    required this.titleTopInset,
    required this.titleToTagsGap,
    required this.emptyTagsSlotHeight,
    required this.actualTimeSlotHeight,
    required this.progressAfterActualGap,
    required this.progressBarHeight,
    required this.footerBlockGap,
  });

  static const shared = _PlanCardVerticalSpacing._(
    padTop: _PlanCardGeom.padTopMediumLarge,
    padBottom: _PlanCardGeom.footerBottomPad,
    titleTopInset: _PlanCardGeom.titleTopInset,
    titleToTagsGap: _PlanCardGeom.titleToTagsGap,
    emptyTagsSlotHeight: _PlanCardGeom.emptyTagsSlotHeight,
    actualTimeSlotHeight: _PlanCardGeom.actualTimeSlotHeight,
    progressAfterActualGap: _PlanCardGeom.progressAfterActualGap,
    progressBarHeight: _PlanCardGeom.progressBarHeight,
    footerBlockGap: _PlanCardGeom.footerBlockGap,
  );

  final double padTop;
  final double padBottom;
  final double titleTopInset;
  final double titleToTagsGap;
  final double emptyTagsSlotHeight;
  final double actualTimeSlotHeight;
  final double progressAfterActualGap;
  final double progressBarHeight;
  final double footerBlockGap;

  double progressSlotHeight({required bool hasTrackedProgress}) =>
      actualTimeSlotHeight + progressAfterActualGap + progressBarHeight;

  double tagsSlotHeight({required bool hasTags}) =>
      emptyTagsSlotHeight;
}

// --- Visual tokens (design/CardPlan *.svg fallback) ---------------------------

abstract final class _PlanCardTokens {
  static const Color surface = Color(0xFFF8F8F8);
  static const Color titleColor = Color(0xFF353535);
  static const Color checkboxStroke = Color(0xFFCCCCCC);
  static const Color playFill = Color(0xFF696969);
  static const Color menuBg = Color(0xFFEBEBEB);
  static const Color menuStroke = Color(0xFF8E8E8E);
  static const Color dividerColor = Color(0x61D9D9D9);
  static const Color breadcrumbColor = Color(0xFF609CE1);
  static const Color breadcrumbFallbackColor = Color(0xFF878787);
  static const Color timeColor = Color(0xB8878787);
  static const Color tagPinkBg = Color(0xFFFFE8E8);
  static const Color tagPinkText = Color(0xFFF55D88);
  static const Color tagPurpleBg = Color(0xFFEEE5F8);
  static const Color tagPurpleText = Color(0xFF7118E5);

  static List<BoxShadow> cardShadow(bool interacting, {bool hovered = false}) => [
        BoxShadow(
          color: Color(hovered ? 0x14000000 : 0x0A000000),
          blurRadius: interacting ? 6 : (hovered ? 8 : 4),
          offset: const Offset(0, 4),
        ),
      ];
}

class _PlanCardProgressSlot extends StatelessWidget {
  const _PlanCardProgressSlot({
    required this.planTrackedSeconds,
    required this.categoryColor,
    this.planEstimatedSeconds,
    this.spacing = _PlanCardVerticalSpacing.shared,
  });

  final int planTrackedSeconds;
  final int? planEstimatedSeconds;
  final Color categoryColor;
  final _PlanCardVerticalSpacing spacing;

  @override
  Widget build(BuildContext context) {
    final estimated = planEstimatedSeconds ?? 0;
    final hasActual = planTrackedSeconds > 0;
    final slotHeight =
        spacing.progressSlotHeight(hasTrackedProgress: hasActual);
    return SizedBox(
      height: slotHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: spacing.actualTimeSlotHeight,
            child: hasActual
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _PlanCardProgressRow.formatCompact(planTrackedSeconds),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: _PlanCardTokens.timeColor,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(height: spacing.progressAfterActualGap),
          _PlanCardProgressRow(
            trackedSeconds: planTrackedSeconds,
            estimatedSeconds: estimated,
            categoryColor: categoryColor,
            compact: true,
            alwaysShowTrack: true,
            trackHeight: spacing.progressBarHeight,
          ),
        ],
      ),
    );
  }
}

class _PlanCardInvariantBody extends StatelessWidget {
  const _PlanCardInvariantBody({
    required this.task,
    required this.titleMaxLines,
    required this.visibleTags,
    required this.displayIsDone,
    required this.hasRepeat,
    required this.metaIcons,
    required this.progressSlot,
    required this.categoryTrail,
    required this.timeLabel,
    required this.scheduleConflict,
    required this.categoryColor,
    required this.spacing,
    this.anchorFooterBottom = false,
    this.onOpenMenu,
    this.onBodyTap,
    this.onBodyLongPress,
  });

  final PlanningTask task;
  final int titleMaxLines;
  final List<Tag> visibleTags;
  final bool displayIsDone;
  final bool hasRepeat;
  final List<Widget> metaIcons;
  final _PlanCardProgressSlot progressSlot;
  final String categoryTrail;
  final String timeLabel;
  final bool scheduleConflict;
  final Color categoryColor;
  final _PlanCardVerticalSpacing spacing;
  final bool anchorFooterBottom;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    if (anchorFooterBottom) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final compact = h.isFinite && h < 88;
          final showTags = !compact && visibleTags.isNotEmpty;
          final showProgress = !compact;
          return _PlanCardBodyTapShell(
            onTap: onBodyTap,
            onLongPress: onBodyLongPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _PlanCardGeom.titleRowHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _PlanCardTitleRow(
                          title: task.title,
                          displayIsDone: displayIsDone,
                          hasRepeat: hasRepeat,
                          maxLines: titleMaxLines,
                          metaIcons: metaIcons,
                        ),
                      ),
                      if (onOpenMenu != null)
                        _PlanCardMenuButton(onOpenMenu: onOpenMenu!),
                    ],
                  ),
                ),
                if (showTags)
                  SizedBox(
                    height: spacing.tagsSlotHeight(hasTags: true),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(top: spacing.titleToTagsGap),
                        child: _PlanCardTagsRow(tags: visibleTags),
                      ),
                    ),
                  ),
                const Spacer(),
                if (showProgress) ...[
                  progressSlot,
                  SizedBox(height: spacing.footerBlockGap),
                ],
                _PlanCardFooterRow(
                  categoryTrail: compact ? '' : categoryTrail,
                  timeLabel: timeLabel,
                  scheduleConflict: scheduleConflict,
                  categoryColor: categoryColor,
                ),
              ],
            ),
          );
        },
      );
    }
    return _PlanCardBodyTapShell(
      onTap: onBodyTap,
      onLongPress: onBodyLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _PlanCardGeom.titleRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PlanCardTitleRow(
                    title: task.title,
                    displayIsDone: displayIsDone,
                    hasRepeat: hasRepeat,
                    maxLines: titleMaxLines,
                    metaIcons: metaIcons,
                  ),
                ),
                if (onOpenMenu != null)
                  _PlanCardMenuButton(onOpenMenu: onOpenMenu!),
              ],
            ),
          ),
          SizedBox(
            height: spacing.tagsSlotHeight(hasTags: visibleTags.isNotEmpty),
            child: Align(
              alignment: Alignment.centerLeft,
              child: visibleTags.isNotEmpty
                  ? Padding(
                      padding: EdgeInsets.only(top: spacing.titleToTagsGap),
                      child: _PlanCardTagsRow(tags: visibleTags),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          SizedBox(height: _PlanCardGeom.tagsToProgressGap),
          progressSlot,
          SizedBox(height: spacing.footerBlockGap),
          _PlanCardFooterRow(
            categoryTrail: categoryTrail,
            timeLabel: timeLabel,
            scheduleConflict: scheduleConflict,
            categoryColor: categoryColor,
          ),
        ],
      ),
    );
  }
}

class _PlanCardRailShell extends StatelessWidget {
  const _PlanCardRailShell({
    required this.showPlay,
    required this.selectMode,
    required this.isSelected,
    required this.displayIsDone,
    required this.toggleDoneEnabled,
    required this.spacing,
    required this.body,
    this.fillHeight = false,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
  });

  final bool showPlay;
  final bool selectMode;
  final bool isSelected;
  final bool displayIsDone;
  final bool toggleDoneEnabled;
  final _PlanCardVerticalSpacing spacing;
  final Widget body;
  final bool fillHeight;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _PlanCardGeom.padLeft,
        spacing.padTop,
        _PlanCardGeom.padRight,
        spacing.padBottom,
      ),
      child: Row(
        crossAxisAlignment:
            fillHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
        children: [
          _PlanCardControlRail(
            showPlay: showPlay,
            selectMode: selectMode,
            isSelected: isSelected,
            displayIsDone: displayIsDone,
            toggleDoneEnabled: toggleDoneEnabled,
            onToggleDone: onToggleDone,
            onSelectToggle: onSelectToggle,
            onPlay: onPlay,
          ),
          const SizedBox(width: _PlanCardGeom.railToContentGap),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _PlanCardProgressRow extends StatelessWidget {
  const _PlanCardProgressRow({
    required this.trackedSeconds,
    required this.estimatedSeconds,
    required this.categoryColor,
    this.compact = false,
    this.alwaysShowTrack = false,
    this.trackHeight = 2,
  });

  final int trackedSeconds;
  final int estimatedSeconds;
  final Color categoryColor;
  final bool compact;
  final bool alwaysShowTrack;
  final double trackHeight;

  static String formatTracked(int sec) {
    final s = sec.clamp(0, 8640000);
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static String formatCompact(int sec) {
    final s = sec.clamp(0, 8640000);
    if (s < 60) return '${s}s';
    if (s < 3600) return '${(s / 60).round()}m';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final pct = estimatedSeconds > 0
        ? ((trackedSeconds * 100) / estimatedSeconds).round()
        : 0;
    final over = estimatedSeconds > 0 && trackedSeconds > estimatedSeconds;
    final accent = categoryColor.a > 0
        ? categoryColor
        : _PlanCardTokens.breadcrumbFallbackColor;
    final showFill = estimatedSeconds > 0;
    final fraction = showFill
        ? (trackedSeconds <= estimatedSeconds
            ? trackedSeconds / estimatedSeconds
            : 1.0)
        : 0.0;
    final trackRadius = BorderRadius.circular(trackHeight / 2);
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: trackHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x61D9D9D9),
                    borderRadius: trackRadius,
                  ),
                ),
                if (showFill || alwaysShowTrack)
                  FractionallySizedBox(
                    widthFactor: showFill ? fraction.clamp(0.0, 1.0) : 0.0,
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: over
                            ? Theme.of(context).colorScheme.error
                            : accent,
                        borderRadius: trackRadius,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 8),
          Text(
            '${formatCompact(trackedSeconds)} / ${formatCompact(estimatedSeconds)} ($pct%)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              height: 1.1,
              color: over
                  ? Theme.of(context).colorScheme.error
                  : _PlanCardTokens.timeColor,
            ),
          ),
        ],
      ],
    );
  }
}

// --- Time View explicit CardPlan density layouts --------------------------------

/// Routes Time View blocks to explicit CardPlan layouts (tags always visible).
class _TimeViewDensityBody extends StatelessWidget {
  const _TimeViewDensityBody({
    required this.visual,
    required this.heightPx,
    required this.task,
    required this.timeLabel,
    required this.categoryTrail,
    required this.categoryColor,
    required this.displayIsDone,
    required this.selectMode,
    required this.isSelected,
    required this.hasRepeat,
    required this.showPlay,
    required this.visibleTags,
    required this.scheduleConflict,
    required this.toggleDoneEnabled,
    required this.metaIcons,
    required this.showProgressBar,
    required this.metricsBlock,
    required this.spacing,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.onOpenMenu,
    this.onBodyTap,
    this.onBodyLongPress,
  });

  final PlanTimeCardVisualDensity visual;
  final double heightPx;
  final PlanningTask task;
  final String timeLabel;
  final String categoryTrail;
  final Color categoryColor;
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final bool hasRepeat;
  final bool showPlay;
  final List<Tag> visibleTags;
  final bool scheduleConflict;
  final bool toggleDoneEnabled;
  final List<Widget> metaIcons;
  final bool showProgressBar;
  final _PlanCardProgressSlot? metricsBlock;
  final _PlanCardVerticalSpacing spacing;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    final common = _TimeViewCardCommon(
      task: task,
      timeLabel: timeLabel,
      categoryTrail: categoryTrail,
      categoryColor: categoryColor,
      displayIsDone: displayIsDone,
      selectMode: selectMode,
      isSelected: isSelected,
      hasRepeat: hasRepeat,
      showPlay: showPlay,
      visibleTags: visibleTags,
      scheduleConflict: scheduleConflict,
      toggleDoneEnabled: toggleDoneEnabled,
      metaIcons: metaIcons,
      showProgressBar: showProgressBar,
      metricsBlock: metricsBlock,
      spacing: spacing,
      onToggleDone: onToggleDone,
      onSelectToggle: onSelectToggle,
      onPlay: onPlay,
      onOpenMenu: onOpenMenu,
      onBodyTap: onBodyTap,
      onBodyLongPress: onBodyLongPress,
    );
    return switch (visual) {
      PlanTimeCardVisualDensity.verySmall =>
        _TimeViewVerySmallLayout(common: common, heightPx: heightPx),
      PlanTimeCardVisualDensity.small =>
        _TimeViewSmallLayout(common: common, heightPx: heightPx),
      PlanTimeCardVisualDensity.moreCompact =>
        _TimeViewMoreCompactLayout(common: common, heightPx: heightPx),
      PlanTimeCardVisualDensity.compact =>
        _TimeViewCompactLayout(common: common, heightPx: heightPx),
      PlanTimeCardVisualDensity.medium =>
        _TimeViewMediumLayout(common: common, heightPx: heightPx),
    };
  }
}

class _TimeViewCardCommon {
  const _TimeViewCardCommon({
    required this.task,
    required this.timeLabel,
    required this.categoryTrail,
    required this.categoryColor,
    required this.displayIsDone,
    required this.selectMode,
    required this.isSelected,
    required this.hasRepeat,
    required this.showPlay,
    required this.visibleTags,
    required this.scheduleConflict,
    required this.toggleDoneEnabled,
    required this.metaIcons,
    required this.showProgressBar,
    required this.metricsBlock,
    required this.spacing,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.onOpenMenu,
    this.onBodyTap,
    this.onBodyLongPress,
  });

  final PlanningTask task;
  final String timeLabel;
  final String categoryTrail;
  final Color categoryColor;
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final bool hasRepeat;
  final bool showPlay;
  final List<Tag> visibleTags;
  final bool scheduleConflict;
  final bool toggleDoneEnabled;
  final List<Widget> metaIcons;
  final bool showProgressBar;
  final _PlanCardProgressSlot? metricsBlock;
  final _PlanCardVerticalSpacing spacing;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;
}

class _TimeViewLeftControls extends StatelessWidget {
  const _TimeViewLeftControls({
    required this.common,
    this.inlinePlay = true,
  });

  final _TimeViewCardCommon common;
  final bool inlinePlay;

  @override
  Widget build(BuildContext context) {
    if (inlinePlay) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlanCardCheckbox(
            selectMode: common.selectMode,
            isSelected: common.isSelected,
            displayIsDone: common.displayIsDone,
            toggleDoneEnabled: common.toggleDoneEnabled,
            onToggleDone: common.onToggleDone,
            onSelectToggle: common.onSelectToggle,
          ),
          if (common.showPlay) ...[
            const SizedBox(width: _PlanCardGeom.playAfterCheckboxGap),
            _PlanCardPlayButton(onPlay: common.onPlay),
          ],
        ],
      );
    }
    return _PlanCardControlRail(
      showPlay: common.showPlay,
      selectMode: common.selectMode,
      isSelected: common.isSelected,
      displayIsDone: common.displayIsDone,
      toggleDoneEnabled: common.toggleDoneEnabled,
      onToggleDone: common.onToggleDone,
      onSelectToggle: common.onSelectToggle,
      onPlay: common.onPlay,
    );
  }
}

/// Responsive CardPlan shell: fixed left rail, expanding center, fixed right menu.
class _TimeViewResponsiveShell extends StatelessWidget {
  const _TimeViewResponsiveShell({
    required this.heightPx,
    required this.leftControls,
    required this.center,
    this.menu,
    this.padVertical = 0,
    this.horizontalPadLeft = _PlanCardGeom.padLeft,
    this.horizontalPadRight = 6,
  });

  final double heightPx;
  final Widget leftControls;
  final Widget center;
  final Widget? menu;
  final double padVertical;
  final double horizontalPadLeft;
  final double horizontalPadRight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: heightPx,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadLeft,
          padVertical,
          horizontalPadRight,
          padVertical,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leftControls,
            const SizedBox(width: _PlanCardGeom.timeViewRailToContentGap),
            Expanded(child: center),
            if (menu != null) menu!,
          ],
        ),
      ),
    );
  }
}

/// Vertical-rail CardPlan shell for Compact / Medium densities.
class _TimeViewVerticalShell extends StatelessWidget {
  const _TimeViewVerticalShell({
    required this.heightPx,
    required this.common,
    required this.body,
    this.padTop = 6,
    this.padBottom = 4,
  });

  final double heightPx;
  final _TimeViewCardCommon common;
  final Widget body;
  final double padTop;
  final double padBottom;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: heightPx,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _PlanCardGeom.padLeft,
          padTop,
          8,
          padBottom,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TimeViewLeftControls(common: common, inlinePlay: false),
            const SizedBox(width: _PlanCardGeom.timeViewRailToContentGap),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Time View tag row ? every tag visible (horizontal scroll, never +N).
class _TimeViewTagsRow extends StatelessWidget {
  const _TimeViewTagsRow({
    required this.tags,
    this.trailing,
  });

  final List<Tag> tags;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty && trailing == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _PlanCardGeom.tagRowHeight,
      child: Row(
        children: [
          if (tags.isNotEmpty)
            Expanded(
              child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: tags.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: _PlanCardGeom.tagGap),
              itemBuilder: (context, index) {
                final tag = tags[index];
                return CategoryChip(
                  mode: CategoryDisplayMode.letterChip,
                  label: tag.name.trim().isNotEmpty
                      ? tag.name.trim()
                      : '#${tag.tagId != 0 ? tag.tagId : tag.wrapperRowId}',
                  color: parseTagHexColor(tag.color) ?? scheme.primary,
                  icon: iconForTagKey(tag.icon),
                  compactGlyphLayout: true,
                  syntheticNoTagsMonochrome: tag.tagId == -1,
                );
              },
            ),
          )
          else
            const Spacer(),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// VerySmall tag column ? compact CardPlan pills stacked vertically (ref).
class _TimeViewTagStack extends StatelessWidget {
  const _TimeViewTagStack({required this.tags});

  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 80),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < tags.length; i++) ...[
              if (i > 0) const SizedBox(height: 1),
              _TimeViewCompactTagPill(tag: tags[i], scheme: scheme),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact CardPlan tag pill for minimum-density Time View (16px, readable).
class _TimeViewCompactTagPill extends StatelessWidget {
  const _TimeViewCompactTagPill({
    required this.tag,
    required this.scheme,
  });

  final Tag tag;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final color = parseTagHexColor(tag.color) ?? scheme.primary;
    final plate = tagLetterChipPlate(color, scheme.surface);
    final fg = tagVibrantForeground(color);
    final label = tag.name.trim().isNotEmpty
        ? tag.name.trim()
        : '#${tag.tagId != 0 ? tag.tagId : tag.wrapperRowId}';
    return Container(
      height: _PlanCardGeom.tagRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: plate,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: tagLetterChipBorder(color, scheme.surface)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          height: 1.0,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// VerySmall 38px ? single row, reference-sized controls (CardPlan ref).
class _TimeViewVerySmallLayout extends StatelessWidget {
  const _TimeViewVerySmallLayout({
    required this.common,
    required this.heightPx,
  });

  final _TimeViewCardCommon common;
  final double heightPx;

  @override
  Widget build(BuildContext context) {
    return _TimeViewResponsiveShell(
      heightPx: heightPx,
      padVertical: 0,
      horizontalPadRight: 8,
      leftControls: _TimeViewLeftControls(common: common),
      menu: common.onOpenMenu != null
          ? _PlanCardMenuButton(onOpenMenu: common.onOpenMenu!)
          : null,
      center: _PlanCardBodyTapShell(
        onTap: common.onBodyTap,
        onLongPress: common.onBodyLongPress,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _PlanCardTitleRow(
                title: common.task.title,
                displayIsDone: common.displayIsDone,
                hasRepeat: common.hasRepeat,
                maxLines: 1,
                metaIcons: common.metaIcons,
              ),
            ),
            if (common.visibleTags.isNotEmpty) ...[
              const SizedBox(width: 4),
              _TimeViewTagStack(tags: common.visibleTags),
            ],
            if (common.timeLabel.isNotEmpty) ...[
              const SizedBox(width: 6),
              _PlanCardTimeText(label: common.timeLabel),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small 39?54px ? title row + tags/time metadata row (CardPlan ref).
class _TimeViewSmallLayout extends StatelessWidget {
  const _TimeViewSmallLayout({
    required this.common,
    required this.heightPx,
  });

  final _TimeViewCardCommon common;
  final double heightPx;

  @override
  Widget build(BuildContext context) {
    return _TimeViewTwoRowCenterLayout(
      common: common,
      heightPx: heightPx,
      padVertical: 6,
    );
  }
}

/// MoreCompact 55?77px ? same rhythm as Small with slightly more breathing room.
class _TimeViewMoreCompactLayout extends StatelessWidget {
  const _TimeViewMoreCompactLayout({
    required this.common,
    required this.heightPx,
  });

  final _TimeViewCardCommon common;
  final double heightPx;

  @override
  Widget build(BuildContext context) {
    return _TimeViewTwoRowCenterLayout(
      common: common,
      heightPx: heightPx,
      padVertical: 7,
    );
  }
}

class _TimeViewTwoRowCenterLayout extends StatelessWidget {
  const _TimeViewTwoRowCenterLayout({
    required this.common,
    required this.heightPx,
    required this.padVertical,
  });

  final _TimeViewCardCommon common;
  final double heightPx;
  final double padVertical;

  @override
  Widget build(BuildContext context) {
    return _TimeViewResponsiveShell(
      heightPx: heightPx,
      padVertical: padVertical,
      leftControls: _TimeViewLeftControls(common: common),
      menu: common.onOpenMenu != null
          ? _PlanCardMenuButton(onOpenMenu: common.onOpenMenu!)
          : null,
      center: _PlanCardBodyTapShell(
        onTap: common.onBodyTap,
        onLongPress: common.onBodyLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _PlanCardTitleRow(
              title: common.task.title,
              displayIsDone: common.displayIsDone,
              hasRepeat: common.hasRepeat,
              maxLines: 1,
              metaIcons: common.metaIcons,
            ),
            const SizedBox(height: 2),
            _TimeViewTagsRow(
              tags: common.visibleTags,
              trailing: common.timeLabel.isNotEmpty
                  ? _PlanCardTimeText(label: common.timeLabel)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact 78?94px ? vertical rail, title/tags, optional footer (CardPlan ref).
class _TimeViewCompactLayout extends StatelessWidget {
  const _TimeViewCompactLayout({
    required this.common,
    required this.heightPx,
  });

  final _TimeViewCardCommon common;
  final double heightPx;

  @override
  Widget build(BuildContext context) {
    final showProgress =
        common.showProgressBar && common.metricsBlock != null;
    final showBreadcrumb = common.categoryTrail.trim().isNotEmpty;
    return _TimeViewVerticalShell(
      heightPx: heightPx,
      common: common,
      body: _PlanCardBodyTapShell(
        onTap: common.onBodyTap,
        onLongPress: common.onBodyLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PlanCardTitleRow(
                      title: common.task.title,
                      displayIsDone: common.displayIsDone,
                      hasRepeat: common.hasRepeat,
                      maxLines: 1,
                      metaIcons: common.metaIcons,
                    ),
                  ),
                  if (common.onOpenMenu != null)
                    _PlanCardMenuButton(onOpenMenu: common.onOpenMenu!),
                ],
              ),
            ),
            if (common.visibleTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _TimeViewTagsRow(tags: common.visibleTags),
              ),
            if (showProgress) ...[
              const SizedBox(height: 4),
              common.metricsBlock!,
            ],
            const Expanded(child: SizedBox.shrink()),
            if (showBreadcrumb || common.timeLabel.isNotEmpty)
              _PlanCardFooterRow(
                categoryTrail: showBreadcrumb ? common.categoryTrail : '',
                timeLabel: common.timeLabel,
                scheduleConflict: common.scheduleConflict,
                categoryColor: common.categoryColor,
              ),
          ],
        ),
      ),
    );
  }
}

/// Medium 95px+ ? full CardPlan hierarchy (CardPlan ref).
class _TimeViewMediumLayout extends StatelessWidget {
  const _TimeViewMediumLayout({
    required this.common,
    required this.heightPx,
  });

  final _TimeViewCardCommon common;
  final double heightPx;

  @override
  Widget build(BuildContext context) {
    final progressSlot = common.metricsBlock ??
        _PlanCardProgressSlot(
          planTrackedSeconds: 0,
          categoryColor: common.categoryColor,
          spacing: common.spacing,
        );
    final showBreadcrumb = common.categoryTrail.trim().isNotEmpty;
    return _TimeViewVerticalShell(
      heightPx: heightPx,
      common: common,
      padTop: 8,
      body: _PlanCardBodyTapShell(
        onTap: common.onBodyTap,
        onLongPress: common.onBodyLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _PlanCardGeom.titleRowHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PlanCardTitleRow(
                      title: common.task.title,
                      displayIsDone: common.displayIsDone,
                      hasRepeat: common.hasRepeat,
                      maxLines: 1,
                      metaIcons: common.metaIcons,
                    ),
                  ),
                  if (common.onOpenMenu != null)
                    _PlanCardMenuButton(onOpenMenu: common.onOpenMenu!),
                ],
              ),
            ),
            if (common.visibleTags.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: common.spacing.titleToTagsGap),
                child: _TimeViewTagsRow(tags: common.visibleTags),
              ),
            const Expanded(child: SizedBox.shrink()),
            if (common.showProgressBar) ...[
              progressSlot,
              SizedBox(height: common.spacing.footerBlockGap),
            ] else if (showBreadcrumb || common.timeLabel.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: _PlanCardTokens.dividerColor,
                ),
              ),
            _PlanCardFooterRow(
              categoryTrail: showBreadcrumb ? common.categoryTrail : '',
              timeLabel: common.timeLabel,
              scheduleConflict: common.scheduleConflict,
              categoryColor: common.categoryColor,
            ),
          ],
        ),
      ),
    );
  }
}

// --- CardPlan_Small (legacy list path) ----------------------------------------

class _TimelinePlanCardSmall extends StatelessWidget {
  const _TimelinePlanCardSmall({
    required this.task,
    required this.timeLabel,
    required this.displayIsDone,
    required this.selectMode,
    required this.isSelected,
    required this.hasRepeat,
    required this.showPlay,
    required this.visibleTags,
    required this.toggleDoneEnabled,
    this.metaIcons = const [],
    this.metricsBlock,
    this.timelineFillHeight = false,
    this.categoryTrail = '',
    this.categoryColor = _PlanCardTokens.breadcrumbFallbackColor,
    this.scheduleConflict = false,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.onOpenMenu,
    this.onBodyTap,
    this.onBodyLongPress,
  });

  final PlanningTask task;
  final String timeLabel;
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final bool hasRepeat;
  final bool showPlay;
  final List<Tag> visibleTags;
  final bool toggleDoneEnabled;
  final List<Widget> metaIcons;
  final _PlanCardProgressSlot? metricsBlock;
  final bool timelineFillHeight;
  final String categoryTrail;
  final Color categoryColor;
  final bool scheduleConflict;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    final showTagRow = !timelineFillHeight && visibleTags.isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _PlanCardGeom.padLeft,
        timelineFillHeight ? _PlanCardGeom.padTopSmall : _PlanCardGeom.padTopSmall,
        _PlanCardGeom.padRight,
        timelineFillHeight ? _PlanCardGeom.footerBottomPad : _PlanCardGeom.padTopSmall,
      ),
      child: Row(
        crossAxisAlignment:
            timelineFillHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
        children: [
          _PlanCardCheckbox(
            selectMode: selectMode,
            isSelected: isSelected,
            displayIsDone: displayIsDone,
            toggleDoneEnabled: toggleDoneEnabled,
            onToggleDone: onToggleDone,
            onSelectToggle: onSelectToggle,
          ),
          if (showPlay) ...[
            const SizedBox(width: _PlanCardGeom.playAfterCheckboxGap),
            _PlanCardPlayButton(onPlay: onPlay),
            const SizedBox(width: _PlanCardGeom.playAfterCheckboxGap),
          ] else
            SizedBox(
              width: _PlanCardGeom.contentXSmall -
                  _PlanCardGeom.padLeft -
                  _PlanCardGeom.controlSize,
            ),
          Expanded(
            child: _PlanCardBodyTapShell(
              onTap: onBodyTap,
              onLongPress: onBodyLongPress,
              child: timelineFillHeight
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PlanCardTitleRow(
                          title: task.title,
                          displayIsDone: displayIsDone,
                          hasRepeat: hasRepeat,
                          maxLines: 1,
                          metaIcons: metaIcons,
                        ),
                        const Spacer(),
                        _PlanCardFooterRow(
                          categoryTrail: '',
                          timeLabel: timeLabel,
                          scheduleConflict: scheduleConflict,
                          categoryColor: categoryColor,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PlanCardTitleRow(
                          title: task.title,
                          displayIsDone: displayIsDone,
                          hasRepeat: hasRepeat,
                          maxLines: 1,
                          metaIcons: metaIcons,
                        ),
                        if (showTagRow)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _PlanCardTagsRow(tags: visibleTags),
                          ),
                        if (metricsBlock != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: metricsBlock!,
                          ),
                      ],
                    ),
            ),
          ),
          if (onOpenMenu != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _PlanCardMenuButton(onOpenMenu: onOpenMenu!),
            ),
        ],
      ),
    );
  }
}

// --- CardPlan_Medium / CardPlan_Large (invariant skeleton) --------------------

class _TimelinePlanCardMedium extends StatelessWidget {
  const _TimelinePlanCardMedium({
    required this.task,
    required this.timeLabel,
    required this.categoryTrail,
    required this.displayIsDone,
    required this.selectMode,
    required this.isSelected,
    required this.hasRepeat,
    required this.showPlay,
    required this.visibleTags,
    required this.scheduleConflict,
    required this.toggleDoneEnabled,
    required this.titleMaxLines,
    this.metaIcons = const [],
    this.metricsBlock,
    this.categoryColor = _PlanCardTokens.breadcrumbFallbackColor,
    this.spacing = _PlanCardVerticalSpacing.shared,
    this.timelineFillHeight = false,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.onOpenMenu,
    this.onBodyTap,
    this.onBodyLongPress,
  });

  final PlanningTask task;
  final String timeLabel;
  final String categoryTrail;
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final bool hasRepeat;
  final bool showPlay;
  final List<Tag> visibleTags;
  final bool scheduleConflict;
  final bool toggleDoneEnabled;
  final int titleMaxLines;
  final List<Widget> metaIcons;
  final _PlanCardProgressSlot? metricsBlock;
  final Color categoryColor;
  final _PlanCardVerticalSpacing spacing;
  final bool timelineFillHeight;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    final progressSlot = metricsBlock ??
        _PlanCardProgressSlot(
          planTrackedSeconds: 0,
          categoryColor: categoryColor,
          spacing: spacing,
        );
    return _PlanCardRailShell(
      showPlay: showPlay,
      selectMode: selectMode,
      isSelected: isSelected,
      displayIsDone: displayIsDone,
      toggleDoneEnabled: toggleDoneEnabled,
      spacing: spacing,
      fillHeight: timelineFillHeight,
      onToggleDone: onToggleDone,
      onSelectToggle: onSelectToggle,
      onPlay: onPlay,
      body: _PlanCardInvariantBody(
        task: task,
        titleMaxLines: titleMaxLines,
        visibleTags: visibleTags,
        displayIsDone: displayIsDone,
        hasRepeat: hasRepeat,
        metaIcons: metaIcons,
        progressSlot: progressSlot,
        categoryTrail: categoryTrail,
        timeLabel: timeLabel,
        scheduleConflict: scheduleConflict,
        categoryColor: categoryColor,
        spacing: spacing,
        anchorFooterBottom: timelineFillHeight,
        onOpenMenu: onOpenMenu,
        onBodyTap: onBodyTap,
        onBodyLongPress: onBodyLongPress,
      ),
    );
  }
}

class _TimelinePlanCardLarge extends StatelessWidget {
  const _TimelinePlanCardLarge({
    required this.task,
    required this.timeLabel,
    required this.categoryTrail,
    required this.displayIsDone,
    required this.selectMode,
    required this.isSelected,
    required this.hasRepeat,
    required this.showPlay,
    required this.visibleTags,
    required this.scheduleConflict,
    required this.toggleDoneEnabled,
    this.metaIcons = const [],
    this.metricsBlock,
    this.categoryColor = _PlanCardTokens.breadcrumbFallbackColor,
    this.spacing = _PlanCardVerticalSpacing.shared,
    this.timelineFillHeight = false,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.onOpenMenu,
    this.onBodyTap,
    this.onBodyLongPress,
  });

  final PlanningTask task;
  final String timeLabel;
  final String categoryTrail;
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final bool hasRepeat;
  final bool showPlay;
  final List<Tag> visibleTags;
  final bool scheduleConflict;
  final bool toggleDoneEnabled;
  final List<Widget> metaIcons;
  final _PlanCardProgressSlot? metricsBlock;
  final Color categoryColor;
  final _PlanCardVerticalSpacing spacing;
  final bool timelineFillHeight;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    final progressSlot = metricsBlock ??
        _PlanCardProgressSlot(
          planTrackedSeconds: 0,
          categoryColor: categoryColor,
          spacing: spacing,
        );
    return _PlanCardRailShell(
      showPlay: showPlay,
      selectMode: selectMode,
      isSelected: isSelected,
      displayIsDone: displayIsDone,
      toggleDoneEnabled: toggleDoneEnabled,
      spacing: spacing,
      fillHeight: timelineFillHeight,
      onToggleDone: onToggleDone,
      onSelectToggle: onSelectToggle,
      onPlay: onPlay,
      body: _PlanCardInvariantBody(
        task: task,
        titleMaxLines: 3,
        visibleTags: visibleTags,
        displayIsDone: displayIsDone,
        hasRepeat: hasRepeat,
        metaIcons: metaIcons,
        progressSlot: progressSlot,
        categoryTrail: categoryTrail,
        timeLabel: timeLabel,
        scheduleConflict: scheduleConflict,
        categoryColor: categoryColor,
        spacing: spacing,
        anchorFooterBottom: timelineFillHeight,
        onOpenMenu: onOpenMenu,
        onBodyTap: onBodyTap,
        onBodyLongPress: onBodyLongPress,
      ),
    );
  }
}

// --- Shared parts -------------------------------------------------------------

class _PlanCardBodyTapShell extends StatelessWidget {
  const _PlanCardBodyTapShell({
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (onTap == null && onLongPress == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: child,
      ),
    );
  }
}

class _PlanCardControlRail extends StatelessWidget {
  const _PlanCardControlRail({
    required this.showPlay,
    required this.selectMode,
    required this.isSelected,
    required this.displayIsDone,
    required this.toggleDoneEnabled,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.expandSpacer = false,
    this.controlSize = _PlanCardGeom.controlSize,
  });

  final bool showPlay;
  final bool selectMode;
  final bool isSelected;
  final bool displayIsDone;
  final bool toggleDoneEnabled;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final bool expandSpacer;
  final double controlSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: controlSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PlanCardCheckbox(
            selectMode: selectMode,
            isSelected: isSelected,
            displayIsDone: displayIsDone,
            toggleDoneEnabled: toggleDoneEnabled,
            onToggleDone: onToggleDone,
            onSelectToggle: onSelectToggle,
            size: controlSize,
          ),
          const SizedBox(height: _PlanCardGeom.checkboxPlayGap),
          if (showPlay)
            _PlanCardPlayButton(onPlay: onPlay, size: controlSize)
          else
            SizedBox(width: controlSize, height: controlSize),
          if (expandSpacer) const Spacer(),
        ],
      ),
    );
  }
}

class _PlanCardCheckbox extends StatefulWidget {
  const _PlanCardCheckbox({
    required this.selectMode,
    required this.isSelected,
    required this.displayIsDone,
    required this.toggleDoneEnabled,
    this.onToggleDone,
    this.onSelectToggle,
    this.size = _PlanCardGeom.controlSize,
  });

  final bool selectMode;
  final bool isSelected;
  final bool displayIsDone;
  final bool toggleDoneEnabled;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final double size;

  @override
  State<_PlanCardCheckbox> createState() => _PlanCardCheckboxState();
}

class _PlanCardCheckboxState extends State<_PlanCardCheckbox>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _checkPulseCtrl;

  @override
  void initState() {
    super.initState();
    _checkPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    if (!widget.selectMode && widget.displayIsDone) {
      _checkPulseCtrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _PlanCardCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.selectMode &&
        !oldWidget.displayIsDone &&
        widget.displayIsDone) {
      _checkPulseCtrl.forward(from: 0);
    } else if (widget.selectMode || !widget.displayIsDone) {
      _checkPulseCtrl.value = widget.displayIsDone ? 1.0 : 0.0;
    }
  }

  @override
  void dispose() {
    _checkPulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checked = widget.selectMode ? widget.isSelected : widget.displayIsDone;
    final enabled = widget.selectMode
        ? widget.onSelectToggle != null
        : widget.toggleDoneEnabled && widget.onToggleDone != null;
    final scheme = Theme.of(context).colorScheme;
    final pulse = Curves.easeOut.transform(_checkPulseCtrl.value);
    final borderColor = Color.lerp(
      _hovered && enabled
          ? _PlanCardTokens.playFill.withValues(alpha: 0.55)
          : _PlanCardTokens.checkboxStroke,
      scheme.primary,
      checked && !widget.selectMode ? 0.35 * pulse : 0.0,
    )!;
    return Semantics(
      checked: checked,
      button: true,
      enabled: enabled,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled
              ? (widget.selectMode
                  ? widget.onSelectToggle
                  : widget.onToggleDone)
              : null,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(widget.size * 0.28),
                border: Border.all(color: borderColor),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x38000000),
                    blurRadius: 4,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: checked
                  ? Center(
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.72, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _checkPulseCtrl,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: widget.size * 0.56,
                          color: _PlanCardTokens.playFill,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCardPlayButton extends StatefulWidget {
  const _PlanCardPlayButton({
    this.onPlay,
    this.size = _PlanCardGeom.controlSize,
  });

  final VoidCallback? onPlay;
  final double size;

  @override
  State<_PlanCardPlayButton> createState() => _PlanCardPlayButtonState();
}

class _PlanCardPlayButtonState extends State<_PlanCardPlayButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: t(currentLocale.value, 'start'),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onPlay,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: CustomPaint(
                size: const Size(
                  _PlanCardGeom.playIconWidth,
                  _PlanCardGeom.playIconHeight,
                ),
                painter: _PlanCardPlayIconPainter(
                  fill: _hovered
                      ? const Color(0xFF4A4A4A)
                      : _PlanCardTokens.playFill,
                  cornerRadius: _PlanCardGeom.playIconCornerRadius,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCardPlayIconPainter extends CustomPainter {
  const _PlanCardPlayIconPainter({
    this.fill = _PlanCardTokens.playFill,
    this.cornerRadius = _PlanCardGeom.playIconCornerRadius,
  });

  final Color fill;
  final double cornerRadius;

  static Path _roundedPlayTrianglePath(
    Size size, {
    required double cornerRadius,
  }) {
    final w = size.width;
    final h = size.height;
    final vertices = <Offset>[
      Offset(w * 0.08, h * 0.06),
      Offset(w * 0.08, h * 0.94),
      Offset(w * 0.96, h * 0.50),
    ];
    return _roundedPolygonPath(vertices, cornerRadius);
  }

  static Path _roundedPolygonPath(List<Offset> vertices, double radius) {
    final path = Path();
    final n = vertices.length;
    for (var i = 0; i < n; i++) {
      final prev = vertices[(i - 1 + n) % n];
      final curr = vertices[i];
      final next = vertices[(i + 1) % n];
      final v1 = curr - prev;
      final v2 = next - curr;
      final len1 = v1.distance;
      final len2 = v2.distance;
      if (len1 < 0.001 || len2 < 0.001) continue;
      final r = math.min(radius, math.min(len1, len2) * 0.45);
      final d1 = Offset(v1.dx / len1 * r, v1.dy / len1 * r);
      final d2 = Offset(v2.dx / len2 * r, v2.dy / len2 * r);
      final before = curr - d1;
      final after = curr + d2;
      if (i == 0) {
        path.moveTo(before.dx, before.dy);
      } else {
        path.lineTo(before.dx, before.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, after.dx, after.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _roundedPlayTrianglePath(size, cornerRadius: cornerRadius);
    canvas.drawPath(
      path,
      Paint()
        ..color = fill
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _PlanCardPlayIconPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.cornerRadius != cornerRadius;
}

/// Inline recurring marker ? circular autorenew arrows after title.
class _PlanCardRecurringGlyph extends StatelessWidget {
  const _PlanCardRecurringGlyph({this.displayIsDone = false});

  final bool displayIsDone;

  @override
  Widget build(BuildContext context) {
    final color = displayIsDone
        ? _PlanCardTokens.breadcrumbFallbackColor.withValues(alpha: 0.45)
        : _PlanCardTokens.breadcrumbFallbackColor.withValues(alpha: 0.88);
    return Icon(
      Icons.autorenew_rounded,
      size: _PlanCardGeom.recurringIconSize,
      color: color,
    );
  }
}

class _PlanCardMenuButton extends StatefulWidget {
  const _PlanCardMenuButton({
    required this.onOpenMenu,
    this.size = _PlanCardGeom.menuSize,
  });

  final void Function(BuildContext) onOpenMenu;
  final double size;

  @override
  State<_PlanCardMenuButton> createState() => _PlanCardMenuButtonState();
}

class _PlanCardMenuButtonState extends State<_PlanCardMenuButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (menuCtx) => Semantics(
        button: true,
        label: t(currentLocale.value, 'plan_radial_menu_tip'),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => widget.onOpenMenu(menuCtx),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _hovered
                      ? const Color(0xFFDEDEDE)
                      : _PlanCardTokens.menuBg,
                  shape: BoxShape.circle,
                ),
                child: const CustomPaint(
                  painter: _PlanCardMenuIconPainter(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCardMenuIconPainter extends CustomPainter {
  const _PlanCardMenuIconPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _PlanCardTokens.menuStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const pad = 11.0;
    final w = size.width;
    final midY1 = size.height * 0.36;
    final midY2 = size.height * 0.52;
    final midY3 = size.height * 0.68;
    canvas.drawLine(Offset(pad, midY1), Offset(w - pad - 6, midY1), paint);
    canvas.drawLine(Offset(pad, midY2), Offset(w - pad - 10, midY2), paint);
    canvas.drawLine(Offset(pad, midY3), Offset(w - pad - 6, midY3), paint);
    final bracket = Path()
      ..moveTo(w - pad - 2, midY2 + 6)
      ..lineTo(w - pad - 6, midY2)
      ..lineTo(w - pad - 2, midY2 - 6);
    canvas.drawPath(bracket, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlanCardTitleRow extends StatelessWidget {
  const _PlanCardTitleRow({
    required this.title,
    required this.displayIsDone,
    required this.hasRepeat,
    required this.maxLines,
    this.metaIcons = const [],
  });

  final String title;
  final bool displayIsDone;
  final bool hasRepeat;
  final int maxLines;
  final List<Widget> metaIcons;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontSize: 16,
      height: 1.0,
      fontWeight: FontWeight.w400,
      leadingDistribution: TextLeadingDistribution.even,
      decoration:
          displayIsDone ? TextDecoration.lineThrough : TextDecoration.none,
      color: displayIsDone
          ? _PlanCardTokens.titleColor.withValues(alpha: 0.55)
          : _PlanCardTokens.titleColor,
    );
    return Row(
      children: [
        Flexible(
          child: Row(
            children: [
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: titleStyle,
                  child: Text(
                    title,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                  ),
                ),
              ),
              if (hasRepeat) ...[
                const SizedBox(width: _PlanCardGeom.titleToRecurringGap),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: _PlanCardRecurringGlyph(displayIsDone: displayIsDone),
                ),
              ],
            ],
          ),
        ),
        if (metaIcons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: metaIcons),
          ),
      ],
    );
  }
}

class _PlanCardTagsRow extends StatelessWidget {
  const _PlanCardTagsRow({
    required this.tags,
    this.trailing,
  });

  final List<Tag> tags;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _PlanCardGeom.tagRowHeight,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: tags.length.clamp(0, 4),
              separatorBuilder: (_, _) =>
                  const SizedBox(width: _PlanCardGeom.tagGap),
              itemBuilder: (context, index) {
                final tag = tags[index];
                return CategoryChip(
                  mode: CategoryDisplayMode.letterChip,
                  label: tag.name.trim().isNotEmpty
                      ? tag.name.trim()
                      : '#${tag.tagId != 0 ? tag.tagId : tag.wrapperRowId}',
                  color: parseTagHexColor(tag.color) ?? scheme.primary,
                  icon: iconForTagKey(tag.icon),
                  compactGlyphLayout: true,
                  syntheticNoTagsMonochrome: tag.tagId == -1,
                );
              },
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _PlanCardTimeText extends StatelessWidget {
  const _PlanCardTimeText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      style: const TextStyle(
        fontSize: 11,
        height: 1.0,
        fontWeight: FontWeight.w400,
        color: _PlanCardTokens.timeColor,
      ),
    );
  }
}

class _PlanCardFooterRow extends StatelessWidget {
  const _PlanCardFooterRow({
    required this.categoryTrail,
    required this.timeLabel,
    required this.scheduleConflict,
    required this.categoryColor,
  });

  final String categoryTrail;
  final String timeLabel;
  final bool scheduleConflict;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trailColor = categoryColor.a > 0
        ? categoryColor
        : _PlanCardTokens.breadcrumbFallbackColor;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: _PlanCardGeom.footerTextHeight,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              categoryTrail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w400,
                color: trailColor,
              ),
            ),
          ),
          if (timeLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: _PlanCardGeom.footerTimeGap,
                right: _PlanCardGeom.footerTimeRightSafePad,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PlanCardTimeText(label: timeLabel),
                  if (scheduleConflict)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 12,
                        color: scheme.error.withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanCardWatermark extends StatelessWidget {
  const _PlanCardWatermark({
    required this.icon,
    required this.color,
    required this.density,
    required this.cardWidth,
    required this.cardHeight,
  });

  final IconData? icon;
  final Color color;
  final PlanTimeTaskCardDensity density;
  final double cardWidth;
  final double cardHeight;

  static const double _opacity = 0.04;

  @override
  Widget build(BuildContext context) {
    if (icon == null) return const SizedBox.shrink();

    final ref = switch (density) {
      PlanTimeTaskCardDensity.micro ||
      PlanTimeTaskCardDensity.compact =>
        (left: 213.0, top: 18.86, size: 102.68),
      PlanTimeTaskCardDensity.medium => (left: 183.0, top: 33.40, size: 149.80),
      PlanTimeTaskCardDensity.large => (left: 128.93, top: 60.01, size: 230.48),
    };

    final widthScale = cardWidth / _PlanCardGeom.refWidth;
    final wideBoost = widthScale > 1
        ? 1.0 + (widthScale - 1).clamp(0.0, 0.6) * 0.45
        : 1.0;
    final size = ref.size * wideBoost;
    final left = ref.left * widthScale;
    final top = ref.top * (cardHeight / _PlanCardGeom.refHeight(density));

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: -0.457,
          child: Icon(
            icon,
            size: size,
            color: color.withValues(alpha: _opacity),
          ),
        ),
      ),
    );
  }
}

/// Time mode block density from rendered height (CardPlan reference bands).
PlanTimeTaskCardDensity planTimeCardDensityForBlock(
  double heightPx,
  int durationMin,
) {
  return planTimeCardTaskDensityForVisual(
    planTimeCardVisualDensityForRenderedHeight(heightPx),
  );
}

String _planCardWallTimeLabel(PlanningTask task) {
  final start = task.startTime;
  if (start == null) return '';
  final startLabel =
      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  final end = task.endDateTime;
  if (end != null) {
    return '$startLabel ? ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  }
  return startLabel;
}

/// List/calendar rows always use medium so footer (breadcrumb + planned time) is consistent.
PlanTimeTaskCardDensity planTimeCardDensityForList({
  required PlanningTask task,
  int? planEstimatedSeconds,
  int planTrackedSeconds = 0,
}) {
  return PlanTimeTaskCardDensity.medium;
}

/// Minimum visible height for list/calendar surfaces (never collapse to 0).
double planTimeCardListMinHeight(PlanTimeTaskCardDensity density) =>
    switch (density) {
      PlanTimeTaskCardDensity.micro => _PlanCardGeom.refHeightMicro,
      PlanTimeTaskCardDensity.compact => _PlanCardGeom.refHeightSmall,
      PlanTimeTaskCardDensity.medium => _PlanCardGeom.refHeightMedium,
      PlanTimeTaskCardDensity.large => _PlanCardGeom.refHeightLarge,
    };

/// Intrinsic CardPlan height ? single source for list minHeight and Time mode blocks.
double planTimeCardMeasureHeight({
  required bool hasTags,
  required bool hasTrackedProgress,
  PlanTimeTaskCardDensity density = PlanTimeTaskCardDensity.medium,
  int titleLines = 1,
}) {
  if (density == PlanTimeTaskCardDensity.micro ||
      density == PlanTimeTaskCardDensity.compact) {
    return planTimeCardListMinHeight(density);
  }
  const spacing = _PlanCardVerticalSpacing.shared;
  final titleBlock = spacing.titleTopInset +
      _PlanCardGeom.titleRowHeight * (titleLines > 1 ? titleLines / 1.0 : 1.0);
  final tagsBlock = spacing.tagsSlotHeight(hasTags: hasTags);
  final progressBlock =
      spacing.progressSlotHeight(hasTrackedProgress: hasTrackedProgress);
  final footerBlock =
      spacing.footerBlockGap + _PlanCardGeom.footerTextHeight;
  final contentColumn = titleBlock +
      tagsBlock +
      _PlanCardGeom.tagsToProgressGap +
      progressBlock +
      footerBlock;
  final contentWithPad = spacing.padTop + contentColumn + spacing.padBottom;
  const railInner = _PlanCardGeom.controlSize +
      _PlanCardGeom.checkboxPlayGap +
      _PlanCardGeom.controlSize;
  final railWithPad = spacing.padTop + railInner + spacing.padBottom;
  return math.max(contentWithPad, railWithPad);
}

/// Time mode [Positioned] height: preferred visual height + border allowance.
double planTimeCardTimelineAllocatedHeight({
  required bool hasTags,
  required bool hasTrackedProgress,
}) {
  return planTimeCardMeasureHeight(
        hasTags: hasTags,
        hasTrackedProgress: hasTrackedProgress,
      ) +
      _PlanCardGeom.timelineBlockAllowancePx;
}

/// Left inset for timeline drag/tap body zone ? excludes checkbox + play rail.
double planCardBodyGestureLeftInsetPx(
  PlanTimeTaskCardDensity density, {
  bool timeline = false,
}) =>
    switch (density) {
      PlanTimeTaskCardDensity.micro => _PlanCardGeom.contentXSmall,
      PlanTimeTaskCardDensity.compact =>
        timeline ? _PlanCardGeom.contentXSmall : _PlanCardGeom.contentXSmall,
      PlanTimeTaskCardDensity.medium ||
      PlanTimeTaskCardDensity.large =>
        _PlanCardGeom.padLeft +
            _PlanCardGeom.railWidth +
            _PlanCardGeom.railToContentGap,
    };

/// Right inset for timeline drag/tap body zone ? excludes menu button column.
double planCardBodyGestureRightInsetPx({bool hasMenu = true}) =>
    hasMenu ? _PlanCardGeom.menuSize + _PlanCardGeom.padRight : 0;
