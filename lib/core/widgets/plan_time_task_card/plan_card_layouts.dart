import 'package:counter/core/plan_category_lookup.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_controls.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_geometry.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_metrics.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_progress.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_density.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_sections.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

// --- Time View explicit CardPlan density layouts --------------------------------

/// Routes Time View blocks to explicit CardPlan layouts (tags always visible).
class TimeViewDensityBody extends StatelessWidget {
  const TimeViewDensityBody({
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
  final PlanCardProgressSlot? metricsBlock;
  final PlanCardVerticalSpacing spacing;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    final common = TimeViewCardCommon(
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
      PlanTimeCardVisualDensity.verySmall => TimeViewVerySmallLayout(
        common: common,
        heightPx: heightPx,
      ),
      PlanTimeCardVisualDensity.small => TimeViewSmallLayout(
        common: common,
        heightPx: heightPx,
      ),
      PlanTimeCardVisualDensity.moreCompact => TimeViewMoreCompactLayout(
        common: common,
        heightPx: heightPx,
      ),
      PlanTimeCardVisualDensity.compact => TimeViewCompactLayout(
        common: common,
        heightPx: heightPx,
      ),
      PlanTimeCardVisualDensity.medium => TimeViewMediumLayout(
        common: common,
        heightPx: heightPx,
      ),
    };
  }
}

class TimeViewCardCommon {
  const TimeViewCardCommon({
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
  final PlanCardProgressSlot? metricsBlock;
  final PlanCardVerticalSpacing spacing;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;
}

class TimeViewLeftControls extends StatelessWidget {
  const TimeViewLeftControls({required this.common, this.inlinePlay = true});

  final TimeViewCardCommon common;
  final bool inlinePlay;

  @override
  Widget build(BuildContext context) {
    if (inlinePlay) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlanCardCheckbox(
            selectMode: common.selectMode,
            isSelected: common.isSelected,
            displayIsDone: common.displayIsDone,
            toggleDoneEnabled: common.toggleDoneEnabled,
            onToggleDone: common.onToggleDone,
            onSelectToggle: common.onSelectToggle,
          ),
          if (common.showPlay) ...[
            const SizedBox(width: PlanCardGeom.playAfterCheckboxGap),
            PlanCardPlayButton(onPlay: common.onPlay),
          ],
        ],
      );
    }
    return PlanCardControlRail(
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
class TimeViewResponsiveShell extends StatelessWidget {
  const TimeViewResponsiveShell({
    required this.heightPx,
    required this.leftControls,
    required this.center,
    this.menu,
    this.padVertical = 0,
    this.horizontalPadLeft = PlanCardGeom.padLeft,
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
            const SizedBox(width: PlanCardGeom.timeViewRailToContentGap),
            Expanded(child: center),
            ?menu,
          ],
        ),
      ),
    );
  }
}

/// Vertical-rail CardPlan shell for Compact / Medium densities.
class TimeViewVerticalShell extends StatelessWidget {
  const TimeViewVerticalShell({
    required this.heightPx,
    required this.common,
    required this.body,
    this.padTop = 6,
    this.padBottom = 4,
  });

  final double heightPx;
  final TimeViewCardCommon common;
  final Widget body;
  final double padTop;
  final double padBottom;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: heightPx,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          PlanCardGeom.padLeft,
          padTop,
          8,
          padBottom,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TimeViewLeftControls(common: common, inlinePlay: false),
            const SizedBox(width: PlanCardGeom.timeViewRailToContentGap),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Time View tag row ? every tag visible (horizontal scroll, never +N).
class TimeViewTagsRow extends StatelessWidget {
  const TimeViewTagsRow({required this.tags, this.trailing});

  final List<Tag> tags;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty && trailing == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: PlanCardGeom.tagRowHeight,
      child: Row(
        children: [
          if (tags.isNotEmpty)
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: tags.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: PlanCardGeom.tagGap),
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
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
  }
}

/// VerySmall tag column ? compact CardPlan pills stacked vertically (ref).
class TimeViewTagStack extends StatelessWidget {
  const TimeViewTagStack({required this.tags});

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
              TimeViewCompactTagPill(tag: tags[i], scheme: scheme),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact CardPlan tag pill for minimum-density Time View (16px, readable).
class TimeViewCompactTagPill extends StatelessWidget {
  const TimeViewCompactTagPill({required this.tag, required this.scheme});

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
      height: PlanCardGeom.tagRowHeight,
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
class TimeViewVerySmallLayout extends StatelessWidget {
  const TimeViewVerySmallLayout({
    required this.common,
    required this.heightPx,
  });

  final TimeViewCardCommon common;
  final double heightPx;

  @override
  Widget build(BuildContext context) {
    return TimeViewResponsiveShell(
      heightPx: heightPx,
      padVertical: 0,
      horizontalPadRight: 8,
      leftControls: TimeViewLeftControls(common: common),
      menu: common.onOpenMenu != null
          ? PlanCardMenuButton(onOpenMenu: common.onOpenMenu!)
          : null,
      center: PlanCardBodyTapShell(
        onTap: common.onBodyTap,
        onLongPress: common.onBodyLongPress,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: PlanCardTitleRow(
                title: common.task.title,
                displayIsDone: common.displayIsDone,
                hasRepeat: common.hasRepeat,
                maxLines: 1,
                metaIcons: common.metaIcons,
              ),
            ),
            if (common.visibleTags.isNotEmpty) ...[
              const SizedBox(width: 4),
              TimeViewTagStack(tags: common.visibleTags),
            ],
            if (common.timeLabel.isNotEmpty) ...[
              const SizedBox(width: 6),
              PlanCardTimeText(label: common.timeLabel),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small 39?54px ? title row + tags/time metadata row (CardPlan ref).
class TimeViewSmallLayout extends StatelessWidget {
  const TimeViewSmallLayout({required this.common, required this.heightPx});

  final TimeViewCardCommon common;
  final double heightPx;

  @override
  Widget build(BuildContext context) {
    return TimeViewTwoRowCenterLayout(
      common: common,
      heightPx: heightPx,
      padVertical: 6,
    );
  }
}

/// MoreCompact 55?77px ? same rhythm as Small with slightly more breathing room.
class TimeViewMoreCompactLayout extends StatelessWidget {
  const TimeViewMoreCompactLayout({
    required this.common,
    required this.heightPx,
  });

  final TimeViewCardCommon common;
  final double heightPx;

  @override
  Widget build(BuildContext context) {
    return TimeViewTwoRowCenterLayout(
      common: common,
      heightPx: heightPx,
      padVertical: 7,
    );
  }
}

class TimeViewTwoRowCenterLayout extends StatelessWidget {
  const TimeViewTwoRowCenterLayout({
    required this.common,
    required this.heightPx,
    required this.padVertical,
  });

  final TimeViewCardCommon common;
  final double heightPx;
  final double padVertical;

  @override
  Widget build(BuildContext context) {
    return TimeViewResponsiveShell(
      heightPx: heightPx,
      padVertical: padVertical,
      leftControls: TimeViewLeftControls(common: common),
      menu: common.onOpenMenu != null
          ? PlanCardMenuButton(onOpenMenu: common.onOpenMenu!)
          : null,
      center: PlanCardBodyTapShell(
        onTap: common.onBodyTap,
        onLongPress: common.onBodyLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            PlanCardTitleRow(
              title: common.task.title,
              displayIsDone: common.displayIsDone,
              hasRepeat: common.hasRepeat,
              maxLines: 1,
              metaIcons: common.metaIcons,
            ),
            const SizedBox(height: 2),
            TimeViewTagsRow(
              tags: common.visibleTags,
              trailing: common.timeLabel.isNotEmpty
                  ? PlanCardTimeText(label: common.timeLabel)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact 78?94px ? vertical rail, title/tags, optional footer (CardPlan ref).
class TimeViewCompactLayout extends StatelessWidget {
  const TimeViewCompactLayout({required this.common, required this.heightPx});

  final TimeViewCardCommon common;
  final double heightPx;

  @override
  Widget build(BuildContext context) {
    final showProgress = common.showProgressBar && common.metricsBlock != null;
    final showBreadcrumb = common.categoryTrail.trim().isNotEmpty;
    return TimeViewVerticalShell(
      heightPx: heightPx,
      common: common,
      body: PlanCardBodyTapShell(
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
                    child: PlanCardTitleRow(
                      title: common.task.title,
                      displayIsDone: common.displayIsDone,
                      hasRepeat: common.hasRepeat,
                      maxLines: 1,
                      metaIcons: common.metaIcons,
                    ),
                  ),
                  if (common.onOpenMenu != null)
                    PlanCardMenuButton(onOpenMenu: common.onOpenMenu!),
                ],
              ),
            ),
            if (common.visibleTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: TimeViewTagsRow(tags: common.visibleTags),
              ),
            if (showProgress) ...[
              const SizedBox(height: 4),
              common.metricsBlock!,
            ],
            const Expanded(child: SizedBox.shrink()),
            if (showBreadcrumb || common.timeLabel.isNotEmpty)
              PlanCardFooterRow(
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
class TimeViewMediumLayout extends StatelessWidget {
  const TimeViewMediumLayout({required this.common, required this.heightPx});

  final TimeViewCardCommon common;
  final double heightPx;

  @override
  Widget build(BuildContext context) {
    final progressSlot =
        common.metricsBlock ??
        PlanCardProgressSlot(
          planTrackedSeconds: 0,
          categoryColor: common.categoryColor,
          spacing: common.spacing,
        );
    final showBreadcrumb = common.categoryTrail.trim().isNotEmpty;
    return TimeViewVerticalShell(
      heightPx: heightPx,
      common: common,
      padTop: 8,
      body: PlanCardBodyTapShell(
        onTap: common.onBodyTap,
        onLongPress: common.onBodyLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: PlanCardGeom.titleRowHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: PlanCardTitleRow(
                      title: common.task.title,
                      displayIsDone: common.displayIsDone,
                      hasRepeat: common.hasRepeat,
                      maxLines: 1,
                      metaIcons: common.metaIcons,
                    ),
                  ),
                  if (common.onOpenMenu != null)
                    PlanCardMenuButton(onOpenMenu: common.onOpenMenu!),
                ],
              ),
            ),
            if (common.visibleTags.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: common.spacing.titleToTagsGap),
                child: TimeViewTagsRow(tags: common.visibleTags),
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
                  color: PlanCardTokens.dividerColor,
                ),
              ),
            PlanCardFooterRow(
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

class TimelinePlanCardSmall extends StatelessWidget {
  const TimelinePlanCardSmall({
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
    this.categoryColor = PlanCardTokens.breadcrumbFallbackColor,
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
  final PlanCardProgressSlot? metricsBlock;
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
        PlanCardGeom.padLeft,
        timelineFillHeight
            ? PlanCardGeom.padTopSmall
            : PlanCardGeom.padTopSmall,
        PlanCardGeom.padRight,
        timelineFillHeight
            ? PlanCardGeom.footerBottomPad
            : PlanCardGeom.padTopSmall,
      ),
      child: Row(
        crossAxisAlignment: timelineFillHeight
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.start,
        children: [
          PlanCardCheckbox(
            selectMode: selectMode,
            isSelected: isSelected,
            displayIsDone: displayIsDone,
            toggleDoneEnabled: toggleDoneEnabled,
            onToggleDone: onToggleDone,
            onSelectToggle: onSelectToggle,
          ),
          if (showPlay) ...[
            const SizedBox(width: PlanCardGeom.playAfterCheckboxGap),
            PlanCardPlayButton(onPlay: onPlay),
            const SizedBox(width: PlanCardGeom.playAfterCheckboxGap),
          ] else
            SizedBox(
              width:
                  PlanCardGeom.contentXSmall -
                  PlanCardGeom.padLeft -
                  PlanCardGeom.controlSize,
            ),
          Expanded(
            child: PlanCardBodyTapShell(
              onTap: onBodyTap,
              onLongPress: onBodyLongPress,
              child: timelineFillHeight
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PlanCardTitleRow(
                          title: task.title,
                          displayIsDone: displayIsDone,
                          hasRepeat: hasRepeat,
                          maxLines: 1,
                          metaIcons: metaIcons,
                        ),
                        const Spacer(),
                        PlanCardFooterRow(
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
                        PlanCardTitleRow(
                          title: task.title,
                          displayIsDone: displayIsDone,
                          hasRepeat: hasRepeat,
                          maxLines: 1,
                          metaIcons: metaIcons,
                        ),
                        if (showTagRow)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: PlanCardTagsRow(tags: visibleTags),
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
              child: PlanCardMenuButton(onOpenMenu: onOpenMenu!),
            ),
        ],
      ),
    );
  }
}

// --- CardPlan_Medium / CardPlan_Large (invariant skeleton) --------------------

class TimelinePlanCardMedium extends StatelessWidget {
  const TimelinePlanCardMedium({
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
    this.categoryColor = PlanCardTokens.breadcrumbFallbackColor,
    this.spacing = PlanCardVerticalSpacing.shared,
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
  final PlanCardProgressSlot? metricsBlock;
  final Color categoryColor;
  final PlanCardVerticalSpacing spacing;
  final bool timelineFillHeight;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    final progressSlot =
        metricsBlock ??
        PlanCardProgressSlot(
          planTrackedSeconds: 0,
          categoryColor: categoryColor,
          spacing: spacing,
        );
    return PlanCardRailShell(
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
      body: PlanCardInvariantBody(
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

class TimelinePlanCardLarge extends StatelessWidget {
  const TimelinePlanCardLarge({
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
    this.categoryColor = PlanCardTokens.breadcrumbFallbackColor,
    this.spacing = PlanCardVerticalSpacing.shared,
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
  final PlanCardProgressSlot? metricsBlock;
  final Color categoryColor;
  final PlanCardVerticalSpacing spacing;
  final bool timelineFillHeight;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    final progressSlot =
        metricsBlock ??
        PlanCardProgressSlot(
          planTrackedSeconds: 0,
          categoryColor: categoryColor,
          spacing: spacing,
        );
    return PlanCardRailShell(
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
      body: PlanCardInvariantBody(
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

