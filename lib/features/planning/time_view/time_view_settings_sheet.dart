import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/time_view_fixed_time_policy.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/settings/default_plan_times_settings_block.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:counter/features/planning/time_view/time_view_fixed_time_settings.dart';
import 'package:counter/features/profile/menu/life_os_planning_settings_page.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

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
    await PlanningSheetTimelinePrefs.loadOpeningLeadMinutes();
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

  /// Planning toolbar routes to the same canonical Settings page used by
  /// the main menu. Do not assemble a second full-screen sheet here.
  Future<void> showPlanningSettingsSheet() async {
    await Navigator.of(host.context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LifeOsPlanningSettingsPage(
          onOpenDefaultPlanTimes: showDefaultPlanTimesSheet,
        ),
      ),
    );
    if (!host.mounted) return;
    await loadPlanningTimelineBounds();
    await loadTimeViewFixedTagIds();
    await host.reloadQuickAddTags();
    timeModeDidAutoScrollToNow = false;
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

/// Shared Time View opening-position preference; used from both settings UIs.
class PlanningTimelineOpeningSettingsBlock extends StatefulWidget {
  const PlanningTimelineOpeningSettingsBlock({super.key, this.onChanged});

  final ValueChanged<int>? onChanged;

  @override
  State<PlanningTimelineOpeningSettingsBlock> createState() =>
      _PlanningTimelineOpeningSettingsBlockState();
}

class _PlanningTimelineOpeningSettingsBlockState
    extends State<PlanningTimelineOpeningSettingsBlock> {
  late int _leadMinutes;

  @override
  void initState() {
    super.initState();
    _leadMinutes = PlanningSheetTimelinePrefs.openingLeadMinutes;
  }

  String _label(int minutes, bool ru) {
    if (minutes < 0) return ru ? 'С начала дня' : 'Day start';
    if (minutes == 0) return ru ? 'Сейчас' : 'Now';
    if (minutes == 30) return ru ? 'За 30 мин' : '30 min before';
    if (minutes == 60) return ru ? 'За 1 час' : '1 hour before';
    return ru ? 'За 2 часа' : '2 hours before';
  }

  void _select(int minutes) {
    if (_leadMinutes == minutes) return;
    setState(() => _leadMinutes = minutes);
    unawaited(PlanningSheetTimelinePrefs.saveOpeningLeadMinutes(minutes));
    widget.onChanged?.call(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final ru = currentLocale.value.toLowerCase().startsWith('ru');
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ru ? 'Открывать таймлайн' : 'Open timeline at',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          ru
              ? 'Для сегодняшнего дня показывать время от выбранной точки. '
                'Другие даты открываются с начала дня.'
              : 'For today, scroll to the selected time. '
                'Other dates open at the beginning of the day.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in PlanningSheetTimelinePrefs.openingLeadOptions)
              ChoiceChip(
                label: Text(_label(option, ru)),
                selected: _leadMinutes == option,
                onSelected: (_) => _select(option),
              ),
          ],
        ),
      ],
    );
  }
}
