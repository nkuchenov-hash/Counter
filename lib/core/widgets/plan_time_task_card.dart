// ---------------------------------------------------------------------------
// PlanTimeTaskCard — CardPlan_Small / CardPlan_Medium / CardPlan_Large
// Geometry source: Figma MCP metadata (328px ref). Visual tokens: design/*.svg
// ---------------------------------------------------------------------------

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/profile/tag_manager_page.dart';
import 'package:counter/features/shared/chip_component.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

enum PlanTimeTaskCardDensity { micro, compact, medium, large }

/// Where the card is rendered — drives height/interaction assumptions.
enum PlanCardSurface { list, timeline, calendar }

/// CardPlan-style unified plan task card (list, timeline, calendar).
class PlanTimeTaskCard extends StatefulWidget {
  const PlanTimeTaskCard({
    super.key,
    required this.task,
    required this.density,
    required this.timeLabel,
    this.surface = PlanCardSurface.timeline,
    this.heightPx,
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
  final String timeLabel;
  final double? heightPx;
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
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext menuContext)? onOpenMenu;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<PlanTimeTaskCard> createState() => _PlanTimeTaskCardState();
}

class _PlanTimeTaskCardState extends State<PlanTimeTaskCard> {
  bool _hovered = false;

  bool get _hasRepeat =>
      (widget.task.rrule?.trim().isNotEmpty ?? false) ||
      (widget.task.recurrenceInstanceDateKey?.trim().isNotEmpty ?? false);

  bool get _showPlay =>
      !widget.selectMode && !widget.displayIsDone && widget.onPlay != null;

  List<Tag> get _visibleTags =>
      widget.task.tags.where((t) => t.rendersAsChip).toList(growable: false);

  bool get _isListLike =>
      widget.surface == PlanCardSurface.list ||
      widget.surface == PlanCardSurface.calendar;

  bool get _showMetrics =>
      widget.planTrackedSeconds > 0 || (widget.planEstimatedSeconds ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final categoryTone =
        DatabaseService.instance.getCategoryColor(widget.task.categoryId);
    final categoryTrailRaw = widget.showFooterBreadcrumb
        ? localizeCategoryBreadcrumbPath(
            DatabaseService.instance
                .getCategoryPath(widget.task.categoryId)
                .trim(),
            loc,
          ).trim()
        : '';
    final categoryTrail = categoryTrailRaw.isNotEmpty
        ? categoryTrailRaw
        : (widget.showFooterBreadcrumb ? t(loc, 'uncategorized') : '');
    final categoryIcon = DatabaseService.instance
        .getCategoryRuleById(widget.task.categoryId)
        ?.iconOrDefault;
    final effectiveTimeLabel = widget.timeLabel.trim().isNotEmpty
        ? widget.timeLabel.trim()
        : _planCardWallTimeLabel(widget.task);

    final hovered = _hovered && !widget.interacting;
    final borderColor = widget.highlightAsRunning
        ? scheme.primary
        : widget.interacting
            ? scheme.primary.withValues(alpha: 0.45)
            : hovered
                ? scheme.outlineVariant.withValues(alpha: 0.62)
                : scheme.outlineVariant.withValues(alpha: 0.38);
    final borderWidth = widget.highlightAsRunning
        ? 2.0
        : widget.interacting
            ? 1.5
            : hovered
                ? 1.25
                : 1.0;

    var surface = widget.selectMode && widget.isSelected
        ? Color.alphaBlend(
            scheme.primaryContainer.withValues(alpha: 0.35),
            _PlanCardTokens.surface,
          )
        : _PlanCardTokens.surface;
    if (hovered) {
      surface = Color.alphaBlend(
        scheme.surfaceContainerHighest.withValues(alpha: 0.28),
        surface,
      );
    }

    final pinFooter = widget.heightPx != null;
    final isTimeline = widget.surface == PlanCardSurface.timeline;
    final showProgressTrack = switch (widget.density) {
      PlanTimeTaskCardDensity.micro => false,
      PlanTimeTaskCardDensity.compact when isTimeline => false,
      _ => true,
    };
    final footerSeparator = !showProgressTrack
        ? null
        : (widget.density == PlanTimeTaskCardDensity.compact &&
                _isListLike &&
                !_showMetrics)
            ? null
            : _PlanCardFooterSeparator(
                planTrackedSeconds: widget.planTrackedSeconds,
                planEstimatedSeconds: widget.planEstimatedSeconds,
                categoryColor: categoryTone,
                alwaysShowTrack: isTimeline || !_isListLike || _showMetrics,
              );

    Widget body;
    switch (widget.density) {
      case PlanTimeTaskCardDensity.micro:
        body = _TimelinePlanCardMicro(
          task: widget.task,
          timeLabel: effectiveTimeLabel,
          displayIsDone: widget.displayIsDone,
          selectMode: widget.selectMode,
          isSelected: widget.isSelected,
          hasRepeat: _hasRepeat,
          showPlay: _showPlay,
          toggleDoneEnabled: widget.toggleDoneEnabled,
          metaIcons: widget.metaIcons,
          categoryColor: categoryTone,
          onToggleDone: widget.onToggleDone,
          onSelectToggle: widget.onSelectToggle,
          onPlay: widget.onPlay,
          onOpenMenu: widget.onOpenMenu,
          onBodyTap: widget.onTap,
          onBodyLongPress: widget.onLongPress,
        );
      case PlanTimeTaskCardDensity.compact:
        body = isTimeline
            ? _TimelinePlanCardCompactTimeline(
                task: widget.task,
                timeLabel: effectiveTimeLabel,
                displayIsDone: widget.displayIsDone,
                selectMode: widget.selectMode,
                isSelected: widget.isSelected,
                hasRepeat: _hasRepeat,
                showPlay: _showPlay,
                toggleDoneEnabled: widget.toggleDoneEnabled,
                metaIcons: widget.metaIcons,
                categoryColor: categoryTone,
                onToggleDone: widget.onToggleDone,
                onSelectToggle: widget.onSelectToggle,
                onPlay: widget.onPlay,
                onOpenMenu: widget.onOpenMenu,
                onBodyTap: widget.onTap,
                onBodyLongPress: widget.onLongPress,
              )
            : _TimelinePlanCardSmall(
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
          metricsBlock: footerSeparator,
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
          metricsBlock: footerSeparator,
          pinFooter: pinFooter,
          onToggleDone: widget.onToggleDone,
          onSelectToggle: widget.onSelectToggle,
          onPlay: widget.onPlay,
          onOpenMenu: widget.onOpenMenu,
          onBodyTap: widget.onTap,
          onBodyLongPress: widget.onLongPress,
          titleMaxLines: 1,
          heightPx: widget.heightPx,
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
          metricsBlock: footerSeparator,
          pinFooter: pinFooter,
          onToggleDone: widget.onToggleDone,
          onSelectToggle: widget.onSelectToggle,
          onPlay: widget.onPlay,
          onOpenMenu: widget.onOpenMenu,
          onBodyTap: widget.onTap,
          onBodyLongPress: widget.onLongPress,
          heightPx: widget.heightPx,
        );
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
        borderRadius: BorderRadius.circular(_PlanCardGeom.radius),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = widget.heightPx ?? constraints.maxHeight;
            return Stack(
              fit: widget.heightPx != null
                  ? StackFit.expand
                  : StackFit.passthrough,
              children: [
                if (widget.density != PlanTimeTaskCardDensity.micro &&
                    !(isTimeline &&
                        widget.density == PlanTimeTaskCardDensity.compact))
                  _PlanCardWatermark(
                  icon: categoryIcon,
                  color: categoryTone,
                  density: widget.density,
                  cardWidth: w.isFinite ? w : _PlanCardGeom.refWidth,
                  cardHeight:
                      h.isFinite ? h : _PlanCardGeom.refHeight(widget.density),
                ),
                if (widget.heightPx != null)
                  SizedBox(
                    height: widget.heightPx,
                    width: double.infinity,
                    child: body,
                  )
                else
                  body,
              ],
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

    return card;
  }
}

// --- Figma geometry (328px reference) ----------------------------------------

abstract final class _PlanCardGeom {
  static const double refWidth = 328;
  static const double padLeft = 12;
  static const double padRight = 12;
  static const double padTopSmall = 10;
  static const double padTopMediumLarge = 12;
  static const double controlSize = 32;
  static const double playInlineX = 48;
  static const double contentXSmall = 84;
  static const double contentXMediumLarge = 56;
  static const double railWidth = 32;
  static const double railToContentGap = 12;
  static const double checkboxPlayGap = 8;
  static const double playAfterCheckboxGap = 4;
  static const double menuSize = 33;
  static const double contentSpanMediumLarge = 260;
  static const double radius = 12;
  static const double refHeightMicro = 48;
  static const double refHeightSmall = 54;
  static const double refHeightMedium = 95;
  static const double refHeightLarge = 147;
  static const double titleToTagsGap = 12;
  static const double footerBlockGap = 8;
  static const double footerBlockGapPinned = 4;
  static const double dividerHeight = 1;
  static const double footerTextHeight = 14;
  static const double footerBottomPadPinned = 6;
  static const double padTopPinned = 8;
  static const double tagRowHeight = 16;
  static const double tagGap = 5;

  static double refHeight(PlanTimeTaskCardDensity d) => switch (d) {
        PlanTimeTaskCardDensity.micro => refHeightMicro,
        PlanTimeTaskCardDensity.compact => refHeightSmall,
        PlanTimeTaskCardDensity.medium => refHeightMedium,
        PlanTimeTaskCardDensity.large => refHeightLarge,
      };

  static double contentSpanWidth(double cardWidth) =>
      cardWidth - contentXMediumLarge - padRight;
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

class _PlanCardFooterSeparator extends StatelessWidget {
  const _PlanCardFooterSeparator({
    required this.planTrackedSeconds,
    required this.categoryColor,
    this.planEstimatedSeconds,
    this.alwaysShowTrack = false,
  });

  final int planTrackedSeconds;
  final int? planEstimatedSeconds;
  final Color categoryColor;
  final bool alwaysShowTrack;

  @override
  Widget build(BuildContext context) {
    final estimated = planEstimatedSeconds ?? 0;
    if (!alwaysShowTrack && planTrackedSeconds <= 0 && estimated <= 0) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (planTrackedSeconds > 0)
          Align(
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
          ),
        Padding(
          padding: EdgeInsets.only(top: planTrackedSeconds > 0 ? 4 : 0),
          child: _PlanCardProgressRow(
            trackedSeconds: planTrackedSeconds,
            estimatedSeconds: estimated,
            categoryColor: categoryColor,
            compact: true,
            alwaysShowTrack: alwaysShowTrack || estimated > 0,
          ),
        ),
      ],
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
  });

  final int trackedSeconds;
  final int estimatedSeconds;
  final Color categoryColor;
  final bool compact;
  final bool alwaysShowTrack;

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
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              minHeight: 3,
              value: showFill
                  ? (trackedSeconds <= estimatedSeconds
                      ? trackedSeconds / estimatedSeconds
                      : 1.0)
                  : (alwaysShowTrack ? 0.0 : null),
              backgroundColor: const Color(0x61D9D9D9),
              color: over
                  ? Theme.of(context).colorScheme.error
                  : accent,
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

// --- CardPlan_Micro (timeline short blocks) -----------------------------------

class _TimelinePlanCardMicro extends StatelessWidget {
  const _TimelinePlanCardMicro({
    required this.task,
    required this.timeLabel,
    required this.displayIsDone,
    required this.selectMode,
    required this.isSelected,
    required this.hasRepeat,
    required this.showPlay,
    required this.toggleDoneEnabled,
    this.metaIcons = const [],
    this.categoryColor = _PlanCardTokens.breadcrumbFallbackColor,
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
  final bool toggleDoneEnabled;
  final List<Widget> metaIcons;
  final Color categoryColor;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  static Widget _scaledControl(Widget child) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Center(child: Transform.scale(scale: 0.82, child: child)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final durationLabel = _planCardShortDurationLabel(task, timeLabel);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          top: 5,
          bottom: 5,
          child: Container(
            width: 3,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.88),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(2),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(7, 3, 4, 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _scaledControl(
                _PlanCardCheckbox(
                  selectMode: selectMode,
                  isSelected: isSelected,
                  displayIsDone: displayIsDone,
                  toggleDoneEnabled: toggleDoneEnabled,
                  onToggleDone: onToggleDone,
                  onSelectToggle: onSelectToggle,
                ),
              ),
              if (showPlay) ...[
                const SizedBox(width: 2),
                _scaledControl(_PlanCardPlayButton(onPlay: onPlay)),
              ],
              const SizedBox(width: 6),
              Expanded(
                child: _PlanCardBodyTapShell(
                  onTap: onBodyTap,
                  onLongPress: onBodyLongPress,
                  child: _PlanCardTitleRow(
                    title: task.title,
                    displayIsDone: displayIsDone,
                    hasRepeat: hasRepeat,
                    maxLines: 1,
                    metaIcons: metaIcons,
                  ),
                ),
              ),
              if (durationLabel.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  durationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: _PlanCardTokens.timeColor,
                  ),
                ),
              ],
              if (onOpenMenu != null)
                _scaledControl(
                  _PlanCardMenuButton(onOpenMenu: onOpenMenu!),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- CardPlan_Compact (timeline 20–30 min blocks) -----------------------------

class _TimelinePlanCardCompactTimeline extends StatelessWidget {
  const _TimelinePlanCardCompactTimeline({
    required this.task,
    required this.timeLabel,
    required this.displayIsDone,
    required this.selectMode,
    required this.isSelected,
    required this.hasRepeat,
    required this.showPlay,
    required this.toggleDoneEnabled,
    this.metaIcons = const [],
    this.categoryColor = _PlanCardTokens.breadcrumbFallbackColor,
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
  final bool toggleDoneEnabled;
  final List<Widget> metaIcons;
  final Color categoryColor;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          top: 6,
          bottom: 6,
          child: Container(
            width: 3,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.75),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(2),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 6, 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                const SizedBox(width: 8),
              Expanded(
                child: _PlanCardBodyTapShell(
                  onTap: onBodyTap,
                  onLongPress: onBodyLongPress,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PlanCardTitleRow(
                        title: task.title,
                        displayIsDone: displayIsDone,
                        hasRepeat: hasRepeat,
                        maxLines: 1,
                        metaIcons: metaIcons,
                      ),
                      if (timeLabel.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            timeLabel.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              height: 1.15,
                              fontWeight: FontWeight.w500,
                              color: _PlanCardTokens.timeColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (onOpenMenu != null)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: _PlanCardMenuButton(onOpenMenu: onOpenMenu!),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- CardPlan_Small -----------------------------------------------------------

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
  final _PlanCardFooterSeparator? metricsBlock;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    final showTagRow = visibleTags.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _PlanCardGeom.padLeft,
        _PlanCardGeom.padTopSmall,
        _PlanCardGeom.padRight,
        _PlanCardGeom.padTopSmall,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              child: Column(
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

// --- CardPlan_Medium ----------------------------------------------------------

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
    this.pinFooter = false,
    this.heightPx,
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
  final _PlanCardFooterSeparator? metricsBlock;
  final Color categoryColor;
  final bool pinFooter;
  final double? heightPx;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _PlanCardGeom.padLeft,
        pinFooter ? _PlanCardGeom.padTopPinned : _PlanCardGeom.padTopMediumLarge,
        _PlanCardGeom.padRight,
        pinFooter
            ? _PlanCardGeom.footerBottomPadPinned
            : _PlanCardGeom.padTopMediumLarge,
      ),
      child: SizedBox(
        height: pinFooter
            ? null
            : _PlanCardGeom.refHeightMedium -
                _PlanCardGeom.padTopMediumLarge * 2,
        child: Row(
          crossAxisAlignment:
              pinFooter ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
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
            Expanded(
              child: _PlanCardBodyTapShell(
                onTap: onBodyTap,
                onLongPress: onBodyLongPress,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: _PlanCardTitleRow(
                                  title: task.title,
                                  displayIsDone: displayIsDone,
                                  hasRepeat: hasRepeat,
                                  maxLines: titleMaxLines,
                                  metaIcons: metaIcons,
                                ),
                              ),
                            if (visibleTags.isNotEmpty &&
                                !(pinFooter &&
                                    heightPx != null &&
                                    heightPx! < 104))
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: _PlanCardGeom.titleToTagsGap,
                                ),
                                child: _PlanCardTagsRow(tags: visibleTags),
                              ),
                          ],
                        ),
                      ),
                      if (onOpenMenu != null)
                        _PlanCardMenuButton(onOpenMenu: onOpenMenu!),
                    ],
                  ),
                  if (pinFooter) const Spacer() else const SizedBox(height: 8),
                  if (metricsBlock != null) metricsBlock!,
                  SizedBox(
                    height: pinFooter
                        ? _PlanCardGeom.footerBlockGapPinned
                        : _PlanCardGeom.footerBlockGap,
                  ),
                  _PlanCardFooterRow(
                    categoryTrail: categoryTrail,
                    timeLabel: timeLabel,
                    scheduleConflict: scheduleConflict,
                    categoryColor: categoryColor,
                  ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CardPlan_Large -----------------------------------------------------------

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
    this.pinFooter = false,
    this.heightPx,
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
  final _PlanCardFooterSeparator? metricsBlock;
  final Color categoryColor;
  final bool pinFooter;
  final double? heightPx;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _PlanCardGeom.padLeft,
        pinFooter ? _PlanCardGeom.padTopPinned : _PlanCardGeom.padTopMediumLarge,
        _PlanCardGeom.padRight,
        pinFooter
            ? _PlanCardGeom.footerBottomPadPinned
            : _PlanCardGeom.padTopMediumLarge,
      ),
      child: SizedBox(
        height: pinFooter
            ? null
            : _PlanCardGeom.refHeightLarge -
                _PlanCardGeom.padTopMediumLarge * 2,
        child: Row(
          crossAxisAlignment:
              pinFooter ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
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
              expandSpacer: true,
            ),
            const SizedBox(width: _PlanCardGeom.railToContentGap),
            Expanded(
              child: _PlanCardBodyTapShell(
                onTap: onBodyTap,
                onLongPress: onBodyLongPress,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: _PlanCardTitleRow(
                                  title: task.title,
                                  displayIsDone: displayIsDone,
                                  hasRepeat: hasRepeat,
                                  maxLines: 3,
                                  metaIcons: metaIcons,
                                ),
                              ),
                            if (visibleTags.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: _PlanCardGeom.titleToTagsGap,
                                ),
                                child: _PlanCardTagsRow(tags: visibleTags),
                              ),
                          ],
                        ),
                      ),
                      if (onOpenMenu != null)
                        _PlanCardMenuButton(onOpenMenu: onOpenMenu!),
                    ],
                  ),
                  if (pinFooter) const Spacer(),
                  if (metricsBlock != null) metricsBlock!,
                  SizedBox(
                    height: pinFooter
                        ? _PlanCardGeom.footerBlockGapPinned
                        : _PlanCardGeom.footerBlockGap,
                  ),
                  _PlanCardFooterRow(
                    categoryTrail: categoryTrail,
                    timeLabel: timeLabel,
                    scheduleConflict: scheduleConflict,
                    categoryColor: categoryColor,
                  ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _PlanCardGeom.railWidth,
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
          ),
          if (showPlay) ...[
            const SizedBox(height: _PlanCardGeom.checkboxPlayGap),
            _PlanCardPlayButton(onPlay: onPlay),
          ],
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
  });

  final bool selectMode;
  final bool isSelected;
  final bool displayIsDone;
  final bool toggleDoneEnabled;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;

  @override
  State<_PlanCardCheckbox> createState() => _PlanCardCheckboxState();
}

class _PlanCardCheckboxState extends State<_PlanCardCheckbox> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final checked = widget.selectMode ? widget.isSelected : widget.displayIsDone;
    final enabled = widget.selectMode
        ? widget.onSelectToggle != null
        : widget.toggleDoneEnabled && widget.onToggleDone != null;
    final borderColor = _hovered && enabled
        ? _PlanCardTokens.playFill.withValues(alpha: 0.55)
        : _PlanCardTokens.checkboxStroke;
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
            width: _PlanCardGeom.controlSize,
            height: _PlanCardGeom.controlSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
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
                  ? const Center(
                      child: Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: _PlanCardTokens.playFill,
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
  const _PlanCardPlayButton({this.onPlay});

  final VoidCallback? onPlay;

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
            width: _PlanCardGeom.controlSize,
            height: _PlanCardGeom.controlSize,
            child: Center(
              child: CustomPaint(
                size: const Size(16, 18),
                painter: _PlanCardPlayIconPainter(
                  fill: _hovered
                      ? const Color(0xFF4A4A4A)
                      : _PlanCardTokens.playFill,
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
  const _PlanCardPlayIconPainter({this.fill = _PlanCardTokens.playFill});

  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.08, h * 0.05)
      ..quadraticBezierTo(w * 0.92, h * 0.48, w * 0.92, h * 0.52)
      ..quadraticBezierTo(w * 0.92, h * 0.56, w * 0.08, h * 0.95)
      ..quadraticBezierTo(w * 0.02, h * 0.5, w * 0.08, h * 0.05)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlanCardMenuButton extends StatefulWidget {
  const _PlanCardMenuButton({required this.onOpenMenu});

  final void Function(BuildContext) onOpenMenu;

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
              width: _PlanCardGeom.menuSize,
              height: _PlanCardGeom.menuSize,
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
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              height: 1.1,
              fontWeight: FontWeight.w400,
              decoration:
                  displayIsDone ? TextDecoration.lineThrough : null,
              color: displayIsDone
                  ? _PlanCardTokens.titleColor.withValues(alpha: 0.55)
                  : _PlanCardTokens.titleColor,
            ),
          ),
        ),
        if (hasRepeat)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              Icons.repeat_rounded,
              size: 15,
              color: _PlanCardTokens.breadcrumbFallbackColor.withValues(
                alpha: 0.85,
              ),
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
      overflow: TextOverflow.ellipsis,
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
          if (timeLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
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

/// Height-based density tiers for proportional timeline blocks.
const double _kPlanTimeCardMicroMaxPx = 56;
const double _kPlanTimeCardCompactMaxPx = 90;
const double _kPlanTimeCardMediumMaxPx = 130;

PlanTimeTaskCardDensity planTimeCardDensityForBlock(
  double heightPx,
  int durationMin,
) {
  if (heightPx < _kPlanTimeCardMicroMaxPx) {
    return PlanTimeTaskCardDensity.micro;
  }
  if (heightPx < _kPlanTimeCardCompactMaxPx) {
    return PlanTimeTaskCardDensity.compact;
  }
  if (heightPx < _kPlanTimeCardMediumMaxPx) {
    return PlanTimeTaskCardDensity.medium;
  }
  return PlanTimeTaskCardDensity.large;
}

String _planCardShortDurationLabel(PlanningTask task, String timeLabel) {
  final start = task.startTime;
  final end = task.endDateTime;
  if (start != null && end != null) {
    final min = end.difference(start).inMinutes;
    if (min > 0) return '${min}m';
  }
  final trimmed = timeLabel.trim();
  if (trimmed.contains('–')) {
    return trimmed.split('–').last.trim();
  }
  return trimmed;
}

String _planCardWallTimeLabel(PlanningTask task) {
  final start = task.startTime;
  if (start == null) return '';
  final startLabel =
      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  final end = task.endDateTime;
  if (end != null) {
    return '$startLabel – ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  }
  return startLabel;
}

/// List/calendar row density — compact when minimal, medium when tags/progress/schedule.
PlanTimeTaskCardDensity planTimeCardDensityForList({
  required PlanningTask task,
  int? planEstimatedSeconds,
  int planTrackedSeconds = 0,
}) {
  final hasTags = task.tags.any((t) => t.rendersAsChip);
  final hasProgress =
      (planEstimatedSeconds ?? 0) > 0 || planTrackedSeconds > 0;
  if (!hasTags && !hasProgress && task.startTime == null) {
    return PlanTimeTaskCardDensity.compact;
  }
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

/// Left inset for timeline drag/tap body zone — excludes checkbox + play rail.
double planCardBodyGestureLeftInsetPx(
  PlanTimeTaskCardDensity density, {
  bool timeline = false,
}) =>
    switch (density) {
      PlanTimeTaskCardDensity.micro => 68,
      PlanTimeTaskCardDensity.compact =>
        timeline ? 72 : _PlanCardGeom.contentXSmall,
      PlanTimeTaskCardDensity.medium ||
      PlanTimeTaskCardDensity.large =>
        _PlanCardGeom.padLeft +
            _PlanCardGeom.railWidth +
            _PlanCardGeom.railToContentGap,
    };

/// Right inset for timeline drag/tap body zone — excludes menu button column.
double planCardBodyGestureRightInsetPx({bool hasMenu = true}) =>
    hasMenu ? _PlanCardGeom.menuSize + _PlanCardGeom.padRight : 0;
