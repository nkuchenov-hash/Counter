import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/core/widgets/app_menu_icons.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/time_view_fixed_time_policy.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/settings/default_plan_times_settings_block.dart';
import 'package:counter/features/planning/settings/planning_no_tags_settings.dart';
import 'package:counter/features/planning/settings/planning_timeline_bounds_sheet.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:counter/features/planning/time_view/time_view_fixed_time_settings.dart';
import 'package:counter/features/profile/menu/life_os_planning_settings_page.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:counter/features/planning/time_view/time_view_search_delegate.dart';

extension PlanningTimeViewTimeViewSettingsSheet on PlanningTimeViewCoordinator {
  Future<void> loadTimeViewFixedTagIds() async {
    final ids = await TimeViewFixedTagPrefs.load();
    if (host.mounted) {
      host.notifySetState(() => timeViewFixedTagIds = ids);
    }
  }

  Future<void> loadPlanningTimelineBounds() async {
    final range = await PlanningSheetTimelinePrefs.loadVisibleDayRange();
    await DatabaseService.instance.loadPlanAutoPlacementMode();
    if (host.mounted) {
      host.notifySetState(() {
        timelineHourStart = range.start;
        timelineHourEnd = range.end;
      });
    }
  }

  void onPlanningTimelineBoundsChanged(int start, int end) {
    final range = PlanningSheetTimelinePrefs.normalizeExtendedRange(start, end);
    host.notifySetState(() {
      timelineHourStart = range.start;
      timelineHourEnd = range.end;
    });
    unawaited(
      PlanningSheetTimelinePrefs.saveVisibleDayRange(range.start, range.end),
    );
  }

  String formatDayLengthValueSummary(int start, int end) {
    final loc = currentLocale.value;
    final hours = PlanningSheetTimelinePrefs.visibleDurationHours(start, end);
    final startClock = PlanningSheetTimelinePrefs.formatExtendedHourClock(
      start,
    );
    final endClock = PlanningSheetTimelinePrefs.formatExtendedHourClock(end);
    final startSuffix = start < 0 ? ' ${t(loc, 'day_length_prev_day')}' : '';
    final endSuffix = end > 24 ? ' ${t(loc, 'day_length_next_day')}' : '';
    if (loc == 'ru') {
      return '$startClock$startSuffix — $endClock$endSuffix · $hours ч';
    }
    return '$startClock$startSuffix — $endClock$endSuffix · ${hours}h';
  }

  void showDefaultPlanTimesSheet() {
    // The Time View shortcut now reuses the canonical Settings editor.
    // Settings-tab entries render this block inline instead of opening a sheet.
    showModalBottomSheet<void>(
      context: host.context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(host.context).height * 0.86,
      ),
      backgroundColor: Theme.of(host.context).colorScheme.surfaceContainerLowest,
      builder: (sheetCtx) => Theme(
        data: settingsNeutralTheme(sheetCtx),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: const DefaultPlanTimesSettingsBlock(),
          ),
        ),
      ),
    );
  }

  void showPlanningSettingsSheet() {
    final loc = currentLocale.value;
    showModalBottomSheet<void>(
      context: host.context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(host.context).height * 0.84,
      ),
      backgroundColor: Theme.of(host.context).colorScheme.surfaceContainerLowest,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: PlanningTimelineBoundsSheet(
              initialStart: timelineHourStart,
              initialEnd: timelineHourEnd,
              onBoundsChanged: onPlanningTimelineBoundsChanged,
              title: t(loc, 'day_length_title'),
              helper: t(loc, 'day_length_helper'),
              valueSummaryBuilder: formatDayLengthValueSummary,
              prevDayMarker: t(loc, 'day_length_prev_day'),
              nextDayMarker: t(loc, 'day_length_next_day'),
              header: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PlanningNoTagsSettingsBlock(
                    initialVisible: host.noTagsChipVisible,
                    initialColorHex: host.noTagsColorHex,
                    onApply: (visible, colorHex) async {
                      final p = await SharedPreferences.getInstance();
                      await p.setBool(host.prefsKeyNoTagsVisible, visible);
                      await p.setString(host.prefsKeyNoTagsColor, colorHex);
                      if (!host.mounted) return;
                      host.applyNoTagsChipSettings(visible, colorHex);
                      await host.reloadQuickAddTags();
                    },
                  ),
                  const Divider(height: 24),
                  PlanAutoPlacementSettingsBlock(
                    initialMode: DatabaseService.instance.planAutoPlacementMode,
                    onChanged: DatabaseService.instance.setPlanAutoPlacementMode,
                  ),
                  const Divider(height: 24),
                  AppSettingsNavigationGroup(
                    children: [
                      AppSettingsNavigationRow(
                        title: t(loc, 'plan_default_times_title'),
                        subtitle: t(loc, 'plan_default_times_subtitle'),
                        leading: AppSettingsMenuIcon(
                          icon: AppMenuIcons.icon(AppMenuIconRole.defaultTime),
                        ),
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          showDefaultPlanTimesSheet();
                        },
                      ),
                      AppSettingsNavigationRow(
                        title: loc.startsWith('ru')
                            ? 'Все настройки планирования'
                            : 'All Planning settings',
                        leading: AppSettingsMenuIcon(
                          icon: AppMenuIcons.icon(AppMenuIconRole.filter),
                        ),
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          Navigator.of(host.context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (settingsContext) =>
                                  LifeOsPlanningSettingsPage(
                                onOpenDefaultPlanTimes: () {
                                  Navigator.of(settingsContext).pop();
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (host.mounted) {
                                      showDefaultPlanTimesSheet();
                                    }
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class PlanAutoPlacementSettingsBlock extends StatefulWidget {
  const PlanAutoPlacementSettingsBlock({
    super.key,
    required this.initialMode,
    required this.onChanged,
  });

  final PlanAutoPlacementMode initialMode;
  final Future<void> Function(PlanAutoPlacementMode mode) onChanged;

  @override
  State<PlanAutoPlacementSettingsBlock> createState() =>
      _PlanAutoPlacementSettingsBlockState();
}

class _PlanAutoPlacementSettingsBlockState
    extends State<PlanAutoPlacementSettingsBlock> {
  late PlanAutoPlacementMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  Future<void> _select(PlanAutoPlacementMode mode) async {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    await widget.onChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final helperKey = _mode == PlanAutoPlacementMode.nearestFreeSlot
        ? 'plan_auto_placement_nearest_helper'
        : 'plan_auto_placement_after_last_helper';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t(loc, 'plan_auto_placement_title'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          t(loc, 'plan_auto_placement_subtitle'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(t(loc, 'plan_auto_placement_nearest')),
              selected: _mode == PlanAutoPlacementMode.nearestFreeSlot,
              onSelected: (_) =>
                  unawaited(_select(PlanAutoPlacementMode.nearestFreeSlot)),
            ),
            ChoiceChip(
              label: Text(t(loc, 'plan_auto_placement_after_last')),
              selected: _mode == PlanAutoPlacementMode.afterLastPlan,
              onSelected: (_) =>
                  unawaited(_select(PlanAutoPlacementMode.afterLastPlan)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          t(loc, helperKey),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
