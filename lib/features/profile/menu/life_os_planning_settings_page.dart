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
import 'package:counter/features/planning/settings/planning_timeline_bounds_sheet.dart';
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
    final scheme = Theme.of(context).colorScheme;
    if (MediaQuery.sizeOf(context).width >= 900) {
      // Desktop uses a compact, content-sized dialog, not an 82%-height
      // bottom drawer for a single toggle or a handful of tag chips.
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          scrollable: true,
          backgroundColor: scheme.surfaceContainerHigh,
          contentPadding: const EdgeInsets.all(24),
          content: SizedBox(
            width: 520,
            child: child,
          ),
        ),
      );
      return;
    }

    // Compact devices retain a touch-friendly sheet but size it to content.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerLowest,
      constraints: BoxConstraints(
        maxWidth: 620,
        maxHeight: MediaQuery.sizeOf(context).height * 0.76,
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: child,
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
                      header: PlanningTimelineBoundsSheet(
                        key: const ValueKey('planning-visible-day-range-slider'),
                        embedded: true,
                        initialStart: range.start,
                        initialEnd: range.end,
                        onBoundsChanged: (start, end) => unawaited(
                          _saveVisibleDayBounds(start, end),
                        ),
                        title: t(loc, 'day_length_title'),
                        helper: ru
                            ? 'Передвигайте два бегунка, чтобы задать начало и конец дня.'
                            : 'Drag the two handles to set the visible start and end.',
                        valueSummaryBuilder: (start, end) {
                          final startClock =
                              PlanningSheetTimelinePrefs.formatExtendedHourClock(start);
                          final endClock =
                              PlanningSheetTimelinePrefs.formatExtendedHourClock(end);
                          final hours = PlanningSheetTimelinePrefs.visibleDurationHours(
                            start, end,
                          );
                          final suffix = end > 24
                              ? (ru ? ' · следующий день' : ' · next day')
                              : '';
                          return '$startClock – $endClock$suffix · '
                              '${hours}${ru ? ' ч' : ' h'}';
                        },
                        prevDayMarker: ru ? 'вчера' : 'previous day',
                        nextDayMarker: ru ? 'завтра' : 'next day',
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
                            builder: (_) => TagSettingsHub(
                              initialTabIndex: 2,
                              backLabel: ru
                                  ? 'Планирование и время'
                                  : 'Planning & time',
                            ))),
                        subtitle: t(loc, 'tag_default_durations_sheet_subtitle'),
                      ),
                    ]),
                  ]),
      )),
    );
  }
}
