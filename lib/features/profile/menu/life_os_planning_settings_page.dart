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
    required this.onOpenDefaultPlanTimes,
  });

  final VoidCallback onOpenDefaultPlanTimes;

  @override
  State<LifeOsPlanningSettingsPage> createState() =>
      _LifeOsPlanningSettingsPageState();
}

class _LifeOsPlanningSettingsPageState
    extends State<LifeOsPlanningSettingsPage> {
  ({int start, int end})? _bounds;
  Set<String>? _fixedTagIds;
  bool _loadFailed = false;
  bool _afterLast = false;
  bool _savingPlacement = false;

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
      final afterLast = DatabaseService.instance.planAutoPlacementMode ==
          PlanAutoPlacementMode.afterLastPlan;
      if (mounted) {
        setState(() {
          _bounds = range;
          _fixedTagIds = fixed;
          _afterLast = afterLast;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _changePlacement(bool afterLast) async {
    if (_savingPlacement) return;
    final previous = _afterLast;
    setState(() {
      _afterLast = afterLast;
      _savingPlacement = true;
    });
    try {
      await DatabaseService.instance.setPlanAutoPlacementMode(
        afterLast
            ? PlanAutoPlacementMode.afterLastPlan
            : PlanAutoPlacementMode.nearestFreeSlot,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _afterLast = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(currentLocale.value.startsWith('ru')
            ? 'Не удалось сохранить размещение планов'
            : 'Could not save plan placement')),
      );
    } finally {
      if (mounted) setState(() => _savingPlacement = false);
    }
  }

  void _openEditor(Widget child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 20, 0, 10),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.55,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _menuRow(
    String title,
    AppMenuIconRole icon,
    VoidCallback onTap, {
    String? subtitle,
    String? value,
  }) => AppSettingsNavigationRow(
    title: title,
    subtitle: subtitle,
    value: value,
    leading: AppSettingsMenuIcon(icon: AppMenuIcons.icon(icon)),
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final ru = loc.toLowerCase().startsWith('ru');
    final range = _bounds;
    final ids = _fixedTagIds;

    void editBounds() {
      if (range == null) return;
      _openEditor(PlanningTimelineBoundsSheet(
        initialStart: range.start,
        initialEnd: range.end,
        onBoundsChanged: (start, end) {
          if (mounted) setState(() => _bounds = (start: start, end: end));
          unawaited(PlanningSheetTimelinePrefs.saveVisibleDayRange(start, end));
        },
        title: t(loc, 'day_length_title'),
        helper: t(loc, 'day_length_helper'),
        valueSummaryBuilder: (start, end) =>
            '${PlanningSheetTimelinePrefs.formatExtendedHourClock(start)} — '
            '${PlanningSheetTimelinePrefs.formatExtendedHourClock(end)}',
        prevDayMarker: t(loc, 'day_length_prev_day'),
        nextDayMarker: t(loc, 'day_length_next_day'),
      ));
    }

    void editFixedTags() {
      if (ids == null) return;
      _openEditor(TimeViewFixedTagsSettingsBlock(
        initialSelectedIds: ids,
        onSave: (next) async {
          await TimeViewFixedTagPrefs.save(next);
          if (mounted) setState(() => _fixedTagIds = next);
        },
      ));
    }

    return Theme(
      data: settingsNeutralTheme(context),
      child: Builder(builder: (context) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          title: Text(ru ? 'Настройки' : 'Settings'),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
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
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: AppSettingsPageBody(children: [
                    Text(ru ? 'Планирование и время' : 'Planning & time',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 31,
                        fontWeight: FontWeight.w800,
                      )),
                    const SizedBox(height: 7),
                    Text(
                      ru
                          ? 'Расписание, логика размещения задач и отображение временной шкалы.'
                          : 'Schedule, plan placement rules and timeline display.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    _heading(context, ru ? 'РАСПИСАНИЕ' : 'SCHEDULE'),
                    AppSettingsNavigationGroup(children: [
                      _menuRow(
                        t(loc, 'day_length_title'),
                        AppMenuIconRole.clock,
                        editBounds,
                        subtitle: ru ? 'Начало и конец видимого дня' : 'Visible day start and end',
                        value: '${PlanningSheetTimelinePrefs.formatExtendedHourClock(range.start)}–'
                               '${PlanningSheetTimelinePrefs.formatExtendedHourClock(range.end)}',
                      ),
                      _menuRow(
                        t(loc, 'plan_default_times_title'),
                        AppMenuIconRole.defaultTime,
                        widget.onOpenDefaultPlanTimes,
                        subtitle: t(loc, 'plan_default_times_subtitle'),
                      ),
                      AppSettingsControlRow(
                        title: ru ? 'Планы друг за другом' : 'Sequential plans',
                        subtitle: ru
                          ? 'Новые планы размещаются после последнего'
                          : 'New plans follow the last scheduled plan',
                        leading: AppSettingsMenuIcon(
                          icon: AppMenuIcons.icon(AppMenuIconRole.schedule)),
                        value: _afterLast,
                        onChanged: _savingPlacement ? null : (v) => unawaited(_changePlacement(v)),
                      ),
                    ]),
                    _heading(context, ru ? 'ВРЕМЕННАЯ ШКАЛА' : 'TIME VIEW'),
                    AppSettingsNavigationGroup(children: [
                      _menuRow(
                        ru ? 'Фиксированное время для тегов' : 'Fixed-time tags',
                        AppMenuIconRole.shield,
                        editFixedTags,
                        subtitle: ru
                          ? 'Планы с этими тегами нельзя сдвигать'
                          : 'Plans with these tags are not shifted',
                        value: ids.isEmpty ? null : '${ids.length}',
                      ),
                      _menuRow(
                        ru ? 'Связь планов и записей' : 'Plans and records',
                        AppMenuIconRole.link,
                        () => _openEditor(
                          const PlanRecordLinkSuggestionSettingsBlock()),
                        subtitle: ru ? 'Предложения и автоматическая связь' : 'Suggestions and automatic linking',
                      ),
                    ]),
                    _heading(context, ru ? 'ДОПОЛНИТЕЛЬНО' : 'ADDITIONAL'),
                    AppSettingsNavigationGroup(children: [
                      _menuRow(
                        t(loc, 'tag_default_durations_title'),
                        AppMenuIconRole.defaultTime,
                        () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const TagSettingsHub(initialTabIndex: 2))),
                        subtitle: t(loc, 'tag_default_durations_sheet_subtitle'),
                      ),
                    ]),
                  ]),
                ),
              ),
      )),
    );
  }
}
