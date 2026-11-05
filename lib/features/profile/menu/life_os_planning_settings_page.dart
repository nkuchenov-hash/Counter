import 'dart:async';

import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/core/widgets/app_menu_icons.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/time_view_fixed_time_policy.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/settings/plan_record_link_settings.dart';
import 'package:counter/features/planning/settings/planning_timeline_bounds_sheet.dart';
import 'package:counter/features/planning/time_view/time_view_fixed_time_settings.dart';
import 'package:counter/features/planning/time_view/time_view_settings_sheet.dart';
import 'package:counter/features/profile/tag_settings_hub.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// The same persisted Planning settings as the Time View context sheet.
/// The app-level entry has no independent copies of preference state.
class LifeOsPlanningSettingsPage extends StatefulWidget {
  const LifeOsPlanningSettingsPage({
    super.key,
    required this.onOpenPlanning,
  });

  final VoidCallback onOpenPlanning;

  @override
  State<LifeOsPlanningSettingsPage> createState() =>
      _LifeOsPlanningSettingsPageState();
}

class _LifeOsPlanningSettingsPageState
    extends State<LifeOsPlanningSettingsPage> {
  ({int start, int end})? _bounds;
  Set<String>? _fixedTagIds;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final range = await PlanningSheetTimelinePrefs.loadVisibleDayRange();
      final fixed = await TimeViewFixedTagPrefs.load();
      await DatabaseService.instance.loadPlanAutoPlacementMode();
      if (mounted) {
        setState(() {
          _bounds = range;
          _fixedTagIds = fixed;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final ru = loc.toLowerCase().startsWith('ru');
    final range = _bounds;
    final ids = _fixedTagIds;
    return Theme(
      data: settingsNeutralTheme(context),
      child: Builder(builder: (context) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          title: Text(ru ? 'Планирование и время' : 'Planning & time'),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
        ),
        body: (range == null || ids == null)
            ? Center(
                child: _loadFailed
                    ? TextButton(
                        onPressed: () => unawaited(_load()),
                        child: Text(t(loc, 'try_again')),
                      )
                    : const CircularProgressIndicator(),
              )
            : AppSettingsPageBody(
                children: [
                  AppSettingsSectionCard(
                    title: t(loc, 'day_length_title'),
                    child: PlanningTimelineBoundsSheet(
                      initialStart: range.start,
                      initialEnd: range.end,
                      onBoundsChanged: (start, end) {
                        setState(() => _bounds = (start: start, end: end));
                        unawaited(PlanningSheetTimelinePrefs.saveVisibleDayRange(start, end));
                      },
                      title: t(loc, 'day_length_title'),
                      helper: t(loc, 'day_length_helper'),
                      valueSummaryBuilder: (start, end) =>
                          PlanningSheetTimelinePrefs.formatExtendedHourClock(start) +
                          ' — ' +
                          PlanningSheetTimelinePrefs.formatExtendedHourClock(end),
                      prevDayMarker: t(loc, 'day_length_prev_day'),
                      nextDayMarker: t(loc, 'day_length_next_day'),
                    ),
                  ),
                  AppSettingsSectionCard(
                    title: t(loc, 'plan_auto_placement_title'),
                    child: PlanAutoPlacementSettingsBlock(
                      initialMode: DatabaseService.instance.planAutoPlacementMode,
                      onChanged: DatabaseService.instance.setPlanAutoPlacementMode,
                    ),
                  ),
                  AppSettingsSectionCard(
                    title: ru ? 'Планы и записи' : 'Plans and records',
                    child: const PlanRecordLinkSuggestionSettingsBlock(),
                  ),
                  AppSettingsSectionCard(
                    title: ru ? 'Фиксированное время' : 'Fixed-time tags',
                    child: TimeViewFixedTagsSettingsBlock(
                      initialSelectedIds: ids,
                      onSave: (next) async {
                        await TimeViewFixedTagPrefs.save(next);
                        if (mounted) setState(() => _fixedTagIds = next);
                      },
                    ),
                  ),
                  AppSettingsNavigationGroup(
                    children: [
                      AppSettingsNavigationRow(
                        title: t(loc, 'tag_default_durations_title'),
                        subtitle: t(loc, 'tag_default_durations_sheet_subtitle'),
                        leading: AppSettingsMenuIcon(
                          icon: AppMenuIcons.icon(AppMenuIconRole.defaultTime)),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const TagSettingsHub(initialTabIndex: 2))),
                      ),
                      AppSettingsNavigationRow(
                        title: ru ? 'Другие параметры Time View' : 'More Time View options',
                        subtitle: ru
                            ? 'Время по категориям и настройки отображения'
                            : 'Category default times and display options',
                        leading: AppSettingsMenuIcon(
                          icon: AppMenuIcons.icon(AppMenuIconRole.schedule)),
                        onTap: widget.onOpenPlanning,
                      ),
                    ],
                  ),
                ],
              ),
      )),
    );
  }
}
