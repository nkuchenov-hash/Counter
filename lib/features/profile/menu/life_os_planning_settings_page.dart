import 'dart:async';

import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/core/widgets/app_settings_breadcrumb_bar.dart';
import 'package:counter/core/widgets/app_menu_icons.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/time_view_fixed_time_policy.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/planning_quick_add_tags_controller.dart';
import 'package:counter/features/planning/settings/planning_no_tags_settings.dart';
import 'package:counter/features/planning/settings/plan_record_link_settings.dart';
import 'package:counter/features/planning/settings/default_plan_times_settings_block.dart';
import 'package:counter/features/planning/time_view/time_view_fixed_time_settings.dart';
import 'package:counter/features/planning/time_view/time_view_settings_sheet.dart';
import 'package:counter/features/profile/tag_settings_hub.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The same persisted Planning settings as the Time View context sheet.
/// The app-level entry has no independent copies of preference state.
class LifeOsPlanningSettingsPage extends StatefulWidget {
  const LifeOsPlanningSettingsPage({
    super.key,
    required this.onOpenDefaultPlanTimes,
    this.backLabel,
  });

  final VoidCallback onOpenDefaultPlanTimes;
  /// Label of the actual route opened before this page (e.g. Plans).
  final String? backLabel;

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
  int _openingLead = PlanningSheetTimelinePrefs.openingLeadMinutes;
  bool _savingPlacement = false;
  bool _openDefaultTimes = false;
  bool _noTagsVisible = true;
  String _noTagsColor = PlanningQuickAddTagsController.defaultNoTagsColorHex;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final noTagsVisible = prefs.getBool(
            PlanningQuickAddTagsController.prefsKeyNoTagsVisible,
          ) ??
          true;
      final noTagsColor = prefs.getString(
            PlanningQuickAddTagsController.prefsKeyNoTagsColor,
          ) ??
          PlanningQuickAddTagsController.defaultNoTagsColorHex;
      final range = await PlanningSheetTimelinePrefs.loadVisibleDayRange();
      final openingLead = await PlanningSheetTimelinePrefs.loadOpeningLeadMinutes();
      final fixed = await TimeViewFixedTagPrefs.load();
      await DatabaseService.instance.loadPlanAutoPlacementMode();
      final afterLast = DatabaseService.instance.planAutoPlacementMode ==
          PlanAutoPlacementMode.afterLastPlan;
      if (mounted) {
        setState(() {
          _bounds = range;
          _noTagsVisible = noTagsVisible;
          _noTagsColor = noTagsColor;
          _openingLead = openingLead;
          _fixedTagIds = fixed;
          _afterLast = afterLast;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _saveVisibleDayBounds(int start, int end) async {
    final normalized = PlanningSheetTimelinePrefs.normalizeExtendedRange(
      start,
      end,
    );
    if (_bounds == normalized) return;
    final previous = _bounds;
    setState(() => _bounds = normalized);
    try {
      await PlanningSheetTimelinePrefs.saveVisibleDayRange(
        normalized.start,
        normalized.end,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _bounds = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentLocale.value.startsWith('ru')
                ? 'Не удалось сохранить границы дня'
                : 'Could not save visible day bounds',
          ),
        ),
      );
    }
  }

  Widget _dayHourSelect({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final ru = currentLocale.value.toLowerCase().startsWith('ru');
    return Expanded(
      child: DropdownButtonFormField<int>(
        key: ValueKey('planning-day-$label-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (var hour = PlanningSheetTimelinePrefs.extendedMin;
              hour <= PlanningSheetTimelinePrefs.extendedMax;
              hour++)
            DropdownMenuItem<int>(
              value: hour,
              child: Text(
                '${PlanningSheetTimelinePrefs.formatExtendedHourClock(hour)}'
                '${hour < 0 ? (ru ? ' · вчера' : ' · previous day') : ''}'
                '${hour >= 24 ? (ru ? ' · завтра' : ' · next day') : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (hour) {
          if (hour != null) onChanged(hour);
        },
      ),
    );
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

  Future<void> _saveNoTagsChip(bool visible, String colorHex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      PlanningQuickAddTagsController.prefsKeyNoTagsVisible,
      visible,
    );
    await prefs.setString(
      PlanningQuickAddTagsController.prefsKeyNoTagsColor,
      colorHex,
    );
    if (mounted) {
      setState(() {
        _noTagsVisible = visible;
        _noTagsColor = colorHex;
      });
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
        appBar: AppSettingsBreadcrumbBar(
          alignWithSettingsBody: true,
          parentLabel: _openDefaultTimes
              ? (ru ? 'Планирование и время' : 'Planning & time')
              : (widget.backLabel ??
                  (ru ? 'Настройки' : 'Settings')),
          title: _openDefaultTimes
              ? t(loc, 'plan_default_times_title')
              : (ru ? 'Планирование и время' : 'Planning & time'),
          onBack: _openDefaultTimes
              ? () => setState(() => _openDefaultTimes = false)
              : () => Navigator.of(context).maybePop(),
        ),
        body: _openDefaultTimes
            ? const AppSettingsPageBody(children: [DefaultPlanTimesSettingsBlock()])
            : (range == null || ids == null)
            ? Center(
                child: _loadFailed
                    ? TextButton(
                        onPressed: () => unawaited(_load()),
                        child: Text(t(loc, 'try_again')),
                      )
                    : const CircularProgressIndicator(),
              )
            : AppSettingsPageBody(children: [
                    _heading(context, ru ? 'РАСПИСАНИЕ' : 'SCHEDULE'),
                    AppSettingsNavigationGroup(
                      header: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            ru ? 'Границы видимого дня' : 'Visible day hours',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ru
                                ? 'Начало и конец временной шкалы планов'
                                : 'Start and end of the planning timeline',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _dayHourSelect(
                                label: ru ? 'Начало' : 'Start',
                                value: range.start,
                                onChanged: (value) => unawaited(
                                  _saveVisibleDayBounds(value, range.end),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _dayHourSelect(
                                label: ru ? 'Конец' : 'End',
                                value: range.end,
                                onChanged: (value) => unawaited(
                                  _saveVisibleDayBounds(range.start, value),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: [
                      _menuRow(
                        t(loc, 'plan_default_times_title'),
                        AppMenuIconRole.defaultTime,
                        () => setState(() => _openDefaultTimes = true),
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
                        ru ? 'Открывать таймлайн' : 'Timeline opening position',
                        AppMenuIconRole.clock,
                        () => _openEditor(PlanningTimelineOpeningSettingsBlock(
                          onChanged: (minutes) {
                            if (mounted) setState(() => _openingLead = minutes);
                          },
                        )),
                        subtitle: ru
                          ? 'Текущий момент или за выбранное время до него'
                          : 'Today or a selected time before now',
                        value: _openingLead < 0
                          ? (ru ? 'Начало дня' : 'Day start')
                          : _openingLead == 0
                            ? (ru ? 'Сейчас' : 'Now')
                            : '${_openingLead} min',
                      ),
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
                        t(loc, 'plan_filter_no_tags'),
                        AppMenuIconRole.tags,
                        () => _openEditor(PlanningNoTagsSettingsBlock(
                          initialVisible: _noTagsVisible,
                          initialColorHex: _noTagsColor,
                          onApply: _saveNoTagsChip,
                        )),
                        subtitle: ru
                            ? 'Видимость и цвет чипа без тегов'
                            : 'Visibility and color of the untagged chip',
                      ),
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
      )),
    );
  }
}
