import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/settings/default_plan_category_search.dart';
import 'package:counter/features/planning/settings/default_plan_timezone_search.dart';
import 'package:counter/features/settings/timezone_settings.dart' as timezone_settings;
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Category defaults editor embedded in the canonical Planning Settings page.
/// Do not navigate back to Planning or use the legacy Time View bottom sheet.
class DefaultPlanTimesSettingsBlock extends StatefulWidget {
  const DefaultPlanTimesSettingsBlock({super.key});

  @override
  State<DefaultPlanTimesSettingsBlock> createState() =>
      _DefaultPlanTimesSettingsBlockState();
}

class _DefaultPlanTimesSettingsBlockState
    extends State<DefaultPlanTimesSettingsBlock> {
  int? _selectedCategoryId;
  TimeOfDay _draftTime = const TimeOfDay(hour: 9, minute: 0);
  bool _useProfileTimezone = true;
  String _fixedTimezone = timezone_settings.kCategoryDefaultTimezoneOptions.first.ianaId;
  bool _saving = false;

  DatabaseService get _db => DatabaseService.instance;
  String get _loc => currentLocale.value;
  bool get _ru => _loc.toLowerCase().startsWith('ru');

  String _hhmm(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  void _selectCategory(int id) {
    final rule = _db.getCategoryRuleById(id);
    final current = _db.sanitizeDefaultPlanTime(rule?.defaultPlanTime) ??
        _db.effectiveDefaultPlanTimeForCategory(id) ??
        '09:00';
    final ownTimezone = _db.sanitizeDefaultPlanTimezone(rule?.defaultPlanTimezone);
    setState(() {
      _selectedCategoryId = id;
      _draftTime = TimeOfDay(
        hour: int.parse(current.substring(0, 2)),
        minute: int.parse(current.substring(3, 5)),
      );
      _useProfileTimezone = ownTimezone == null;
      _fixedTimezone = ownTimezone ??
          timezone_settings.kCategoryDefaultTimezoneOptions.first.ianaId;
    });
  }

  Future<void> _chooseCategory() async {
    final options = [
      for (final pair in _db.allCategoryIdPathPairs)
        if (pair.id != CategoryRule.uncategorizedSyntheticId)
          DefaultPlanCategoryOption(id: pair.id, path: pair.path),
    ];
    final chosen = await showSearch<DefaultPlanCategoryOption?>(
      context: context,
      delegate: DefaultPlanCategorySearchDelegate(loc: _loc, options: options),
    );
    if (chosen != null && mounted) _selectCategory(chosen.id);
  }

  Future<void> _chooseTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _draftTime,
    );
    if (picked != null && mounted) setState(() => _draftTime = picked);
  }

  Future<void> _chooseTimezone() async {
    final picked = await showSearch<String?>(
      context: context,
      delegate: DefaultPlanTimezoneSearchDelegate(
        loc: _loc,
        options: timezone_settings.kCategoryDefaultTimezoneOptions,
      ),
    );
    if (picked != null && mounted) setState(() => _fixedTimezone = picked);
  }

  void _error(bool timezoneMissing) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(timezoneMissing
          ? t(_loc, 'plan_default_timezone_field_missing')
          : t(_loc, 'toast_error')),
    ));
  }

  Future<void> _save() async {
    final id = _selectedCategoryId;
    if (id == null || _saving) return;
    setState(() => _saving = true);
    try {
      final result = await _db.updateCategoryDefaultPlanSchedule(
        id, _hhmm(_draftTime), _useProfileTimezone ? null : _fixedTimezone,
      );
      if (!mounted) return;
      if (!result.ok) _error(result.timezoneFieldMissing);
    } catch (_) {
      if (mounted) _error(false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    final id = _selectedCategoryId;
    if (id == null || _saving) return;
    setState(() => _saving = true);
    try {
      final result = await _db.updateCategoryDefaultPlanSchedule(id, null, null);
      if (!mounted) return;
      if (!result.ok) {
        _error(result.timezoneFieldMissing);
      } else {
        setState(() => _selectedCategoryId = null);
      }
    } catch (_) {
      if (mounted) _error(false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairs = _db.allCategoryIdPathPairs
        .where((p) => p.id != CategoryRule.uncategorizedSyntheticId)
        .toList();
    final configured = pairs.where((p) =>
        _db.sanitizeDefaultPlanTime(
          _db.getCategoryRuleById(p.id)?.defaultPlanTime,
        ) != null).toList();
    final selected = pairs.where((p) => p.id == _selectedCategoryId);
    final selectedPath = selected.isEmpty ? null : selected.first.path;
    final selectedRule = _selectedCategoryId == null
        ? null : _db.getCategoryRuleById(_selectedCategoryId!);
    final selectedOwn = _db.sanitizeDefaultPlanTime(selectedRule?.defaultPlanTime);
    final inherited = _selectedCategoryId == null
        ? null : _db.effectiveDefaultPlanScheduleForCategory(_selectedCategoryId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t(_loc, 'plan_default_times_title'),
          style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          _ru
              ? 'Начальное время для новых планов выбранной категории. Если оно занято, план размещается в следующем свободном промежутке.'
              : 'Earliest start for new plans in this category. If occupied, the next available slot is used.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Text(t(_loc, 'plan_default_times_profile_tz_notice')
            .replaceFirst('%s', _db.profileTimezoneShortLabel()),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        AppSettingsNavigationGroup(children: [
          AppSettingsNavigationRow(
            title: t(_loc, 'plan_default_time_select_category'),
            subtitle: selectedPath,
            onTap: pairs.isEmpty || _saving ? null : () => unawaited(_chooseCategory()),
            leading: const Icon(Icons.search_rounded),
          ),
        ]),
        if (_selectedCategoryId != null && selectedPath != null) ...[
          const SizedBox(height: 18),
          AppSettingsSectionCard(
            title: selectedPath,
            subtitle: selectedOwn == null && inherited?.hhmm != null
                ? t(_loc, 'plan_default_time_inherited').replaceFirst(
                    '%s',
                    _db.formatDefaultPlanTimeWithTimezoneLabel(
                      inherited!.hhmm!, inherited.timezoneIana))
                : selectedOwn == null
                    ? t(_loc, 'plan_default_time_none')
                    : t(_loc, 'plan_default_time_own').replaceFirst(
                        '%s',
                        _db.formatDefaultPlanTimeWithTimezoneLabel(
                          selectedOwn, selectedRule?.defaultPlanTimezone)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSettingsNavigationGroup(children: [
                  AppSettingsNavigationRow(
                    title: t(_loc, 'plan_default_time_field_time'),
                    value: _hhmm(_draftTime),
                    onTap: _saving ? null : () => unawaited(_chooseTime()),
                    leading: const Icon(Icons.access_time_rounded),
                  ),
                ]),
                const SizedBox(height: 15),
                Text(t(_loc, 'plan_default_time_field_timezone'),
                  style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(
                    label: Text(t(_loc, 'plan_default_time_tz_profile')
                        .replaceFirst('%s', _db.profileTimezoneShortLabel())),
                    selected: _useProfileTimezone,
                    onSelected: _saving ? null :
                        (_) => setState(() => _useProfileTimezone = true),
                  ),
                  ChoiceChip(
                    label: Text(t(_loc, 'plan_default_time_tz_fixed')),
                    selected: !_useProfileTimezone,
                    onSelected: _saving ? null :
                        (_) => setState(() => _useProfileTimezone = false),
                  ),
                ]),
                if (!_useProfileTimezone) ...[
                  const SizedBox(height: 12),
                  AppSettingsNavigationGroup(children: [
                    AppSettingsNavigationRow(
                      title: timezone_settings
                          .shortLabelForCategoryDefaultTimezoneIana(_fixedTimezone),
                      subtitle: _fixedTimezone.replaceAll('_', ' '),
                      onTap: _saving ? null : () => unawaited(_chooseTimezone()),
                      leading: const Icon(Icons.public_rounded),
                    ),
                  ]),
                ],
                const SizedBox(height: 18),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  AppButton.primary(
                    label: t(_loc, 'save'),
                    onPressed: _saving ? null : () => unawaited(_save()),
                  ),
                  AppButton.secondary(
                    label: t(_loc, 'plan_default_time_clear'),
                    onPressed: _saving || selectedOwn == null
                        ? null : () => unawaited(_clear()),
                  ),
                ]),
              ],
            ),
          ),
        ],
        const SizedBox(height: 15),
        Text(t(_loc, 'plan_default_time_configured_categories'),
          style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 9),
        if (configured.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(t(_loc, 'plan_default_time_none')),
          )
        else
          AppSettingsNavigationGroup(children: [
            for (final pair in configured)
              AppSettingsNavigationRow(
                title: pair.path,
                value: _db.formatDefaultPlanTimeWithTimezoneLabel(
                  _db.sanitizeDefaultPlanTime(
                    _db.getCategoryRuleById(pair.id)?.defaultPlanTime)!,
                  _db.getCategoryRuleById(pair.id)?.defaultPlanTimezone,
                ),
                onTap: _saving ? null : () => _selectCategory(pair.id),
                leading: const Icon(Icons.schedule_rounded),
              ),
          ]),
      ],
    );
  }
}
