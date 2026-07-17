import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/time_view_fixed_time_policy.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/settings/default_plan_category_search.dart';
import 'package:counter/features/planning/settings/plan_record_link_settings.dart';
import 'package:counter/features/planning/settings/planning_no_tags_settings.dart';
import 'package:counter/features/planning/settings/planning_timeline_bounds_sheet.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:counter/features/planning/time_view/time_view_fixed_time_settings.dart';
import 'package:counter/features/profile/tag_settings_hub.dart';
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
    unawaited(PlanningSheetTimelinePrefs.saveVisibleDayRange(range.start, range.end));
  }

  String formatDayLengthValueSummary(int start, int end) {
    final loc = currentLocale.value;
    final hours = PlanningSheetTimelinePrefs.visibleDurationHours(start, end);
    final startClock = PlanningSheetTimelinePrefs.formatExtendedHourClock(start);
    final endClock = PlanningSheetTimelinePrefs.formatExtendedHourClock(end);
    final startSuffix =
        start < 0 ? ' ${t(loc, 'day_length_prev_day')}' : '';
    final endSuffix = end > 24 ? ' ${t(loc, 'day_length_next_day')}' : '';
    if (loc == 'ru') {
      return '$startClock$startSuffix — $endClock$endSuffix · $hours ч';
    }
    return '$startClock$startSuffix — $endClock$endSuffix · ${hours}h';
  }

  void showDefaultPlanTimesSheet() {
    int? selectedCategoryId;
    showModalBottomSheet<void>(
      context: host.context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final loc = currentLocale.value;
            final db = DatabaseService.instance;
            final pairs = db.allCategoryIdPathPairs
                .where((p) => p.id != CategoryRule.uncategorizedSyntheticId)
                .toList();
            final configuredPairs = pairs.where((p) {
              final rule = db.getCategoryRuleById(p.id);
              return db.sanitizeDefaultPlanTime(rule?.defaultPlanTime) != null;
            }).toList();
            ({int id, String path})? selectedPair;
            for (final p in pairs) {
              if (p.id == selectedCategoryId) {
                selectedPair = p;
                break;
              }
            }
            final selectedRule = selectedCategoryId == null
                ? null
                : db.getCategoryRuleById(selectedCategoryId!);
            final selectedOwn = db.sanitizeDefaultPlanTime(
              selectedRule?.defaultPlanTime,
            );
            final selectedEffective = selectedCategoryId == null
                ? null
                : db.effectiveDefaultPlanScheduleForCategory(
                    selectedCategoryId!,
                  );
            String statusText({
              required String? own,
              required String? ownTz,
              required ({String? hhmm, String? timezoneIana, int? sourceCategoryId})?
                  effective,
            }) {
              if (own != null) {
                return t(loc, 'plan_default_time_own').replaceFirst(
                  '%s',
                  db.formatDefaultPlanTimeWithTimezoneLabel(own, ownTz),
                );
              }
              if (effective?.hhmm != null) {
                return t(loc, 'plan_default_time_inherited').replaceFirst(
                  '%s',
                  db.formatDefaultPlanTimeWithTimezoneLabel(
                    effective!.hhmm!,
                    effective.timezoneIana,
                  ),
                );
              }
              return t(loc, 'plan_default_time_none');
            }

            Future<void> pickCategory() async {
              final picked = await showSearch<DefaultPlanCategoryOption?>(
                context: host.context,
                delegate: DefaultPlanCategorySearchDelegate(
                  loc: loc,
                  options: [
                    for (final p in pairs)
                      DefaultPlanCategoryOption(id: p.id, path: p.path),
                  ],
                ),
              );
              if (picked == null || !context.mounted) return;
              setModalState(() => selectedCategoryId = picked.id);
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t(loc, 'plan_default_times_title'),
                      style: Theme.of(host.context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t(loc, 'plan_default_times_subtitle'),
                      style: Theme.of(host.context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(host.context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t(loc, 'plan_default_times_profile_tz_notice').replaceFirst(
                        '%s',
                        db.profileTimezoneShortLabel(),
                      ),
                      style: Theme.of(host.context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(host.context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: pairs.isEmpty
                          ? null
                          : () => unawaited(pickCategory()),
                      icon: const Icon(Icons.search_rounded),
                      label: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          selectedPair?.path ??
                              t(loc, 'plan_default_time_select_category'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selectedPair != null)
                      Builder(
                        builder: (context) {
                          final pair = selectedPair!;
                          return Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    pair.path,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    statusText(
                                      own: selectedOwn,
                                      ownTz: selectedRule?.defaultPlanTimezone,
                                      effective: selectedEffective,
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      AppButton.secondary(
                                        label: t(loc, 'plan_default_time_set'),
                                        onPressed: () => unawaited(
                                          setCategoryDefaultPlanTime(
                                            pair.id,
                                            setModalState,
                                          ),
                                        ),
                                      ),
                                      AppButton.ghost(
                                        label: t(
                                          loc,
                                          'plan_default_time_clear',
                                        ),
                                        onPressed: selectedOwn == null
                                            ? null
                                            : () => unawaited(
                                                clearCategoryDefaultPlanTime(
                                                  pair.id,
                                                  setModalState,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    Text(
                      t(loc, 'plan_default_time_configured_categories'),
                      style: Theme.of(host.context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(host.context).height * 0.45,
                      ),
                      child: configuredPairs.isEmpty
                          ? Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(t(loc, 'plan_default_time_none')),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: configuredPairs.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final pair = configuredPairs[i];
                                final rule = db.getCategoryRuleById(pair.id);
                                final own = db.sanitizeDefaultPlanTime(
                                  rule?.defaultPlanTime,
                                );
                                final subtitle = own != null
                                    ? db.formatDefaultPlanTimeWithTimezoneLabel(
                                        own,
                                        rule?.defaultPlanTimezone,
                                      )
                                    : '';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    pair.path,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(subtitle),
                                  trailing: Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton(
                                        tooltip: t(
                                          loc,
                                          'plan_default_time_set',
                                        ),
                                        icon: const Icon(Icons.edit_rounded),
                                        onPressed: () {
                                          setModalState(
                                            () => selectedCategoryId = pair.id,
                                          );
                                          unawaited(
                                            setCategoryDefaultPlanTime(
                                              pair.id,
                                              setModalState,
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        tooltip: t(
                                          loc,
                                          'plan_default_time_clear',
                                        ),
                                        icon: const Icon(Icons.clear_rounded),
                                        onPressed: () => unawaited(
                                          clearCategoryDefaultPlanTime(
                                            pair.id,
                                            setModalState,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () => setModalState(
                                    () => selectedCategoryId = pair.id,
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    // TODO(F2C): remove sanity marker after web + APK verification.
                    Text(
                      'F2C selector UI',
                      style: Theme.of(host.context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(host.context).colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void showPlanningSettingsSheet() {
    final loc = currentLocale.value;
    showModalBottomSheet<void>(
      context: host.context,
      showDragHandle: true,
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
                  const Divider(height: 1),
                  const PlanRecordLinkSuggestionSettingsBlock(),
                  const Divider(height: 24),
                  TimeViewFixedTagsSettingsBlock(
                    initialSelectedIds: timeViewFixedTagIds,
                    onSave: (ids) async {
                      await TimeViewFixedTagPrefs.save(ids);
                      if (host.mounted) {
                        host.notifySetState(() => timeViewFixedTagIds = ids);
                      }
                    },
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(t(loc, 'plan_default_times_title')),
                    subtitle: Text(
                      t(loc, 'plan_default_times_subtitle'),
                      style: Theme.of(host.context).textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      showDefaultPlanTimesSheet();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(t(loc, 'tag_default_durations_title')),
                    subtitle: Text(
                      t(loc, 'tag_default_durations_sheet_subtitle'),
                      style: Theme.of(host.context).textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      Navigator.of(host.context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const TagSettingsHub(
                            initialTabIndex: 2,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.label_outline_rounded),
                    title: Text(t(loc, 'tag_settings_hub_title')),
                    subtitle: Text(
                      t(loc, 'tag_settings_sheet_subtitle'),
                      style: Theme.of(host.context).textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      Navigator.of(host.context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const TagSettingsHub(),
                        ),
                      );
                    },
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
