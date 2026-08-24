import 'dart:async';

import 'package:counter/core/picker_entry_modes.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/features/planning/settings/default_plan_timezone_search.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:counter/features/settings/timezone_settings.dart' as tz_settings;
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

extension PlanningTimeViewTimeViewSearchDelegate on PlanningTimeViewCoordinator {
  String hhmmFromTimeOfDay(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay timeOfDayFromHhmm(String? raw) {
    final sanitized = DatabaseService.instance.sanitizeDefaultPlanTime(raw);
    if (sanitized == null) return const TimeOfDay(hour: 9, minute: 0);
    return TimeOfDay(
      hour: int.parse(sanitized.substring(0, 2)),
      minute: int.parse(sanitized.substring(3, 5)),
    );
  }

  Future<void> editCategoryDefaultPlanSchedule(
    int categoryId,
    void Function(void Function())? modalSetState,
  ) async {
    final loc = currentLocale.value;
    final db = DatabaseService.instance;
    final rule = db.getCategoryRuleById(categoryId);
    final currentTime = db.sanitizeDefaultPlanTime(rule?.defaultPlanTime) ??
        db.effectiveDefaultPlanTimeForCategory(categoryId);
    var pickedTime = timeOfDayFromHhmm(currentTime);
    var useProfileTz = db.usesProfileDefaultPlanTimezone(rule?.defaultPlanTimezone);
    var fixedIana = db.sanitizeDefaultPlanTimezone(rule?.defaultPlanTimezone) ??
        tz_settings.kCategoryDefaultTimezoneOptions.first.ianaId;
    var saveInFlight = false;
    String? saveError;

    await showModalBottomSheet<void>(
      context: host.context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final profileTzLabel = db.profileTimezoneShortLabel();
            final timeLabel = hhmmFromTimeOfDay(pickedTime);
            final fixedShort = tz_settings.shortLabelForCategoryDefaultTimezoneIana(
              fixedIana,
            );
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  16 + MediaQuery.paddingOf(host.context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t(loc, 'plan_default_time_set'),
                      style: Theme.of(host.context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t(loc, 'plan_default_time_field_time')),
                      subtitle: Text(timeLabel),
                      trailing: const Icon(Icons.schedule_rounded),
                      onTap: saveInFlight
                          ? null
                          : () async {
                              final picked = await showTimePicker(
                                context: host.context,
                                initialTime: pickedTime,
                                initialEntryMode:
                                    appTimePickerEntryModeFromContext(host.context),
                              );
                              if (picked == null || !context.mounted) return;
                              setSheetState(() => pickedTime = picked);
                            },
                    ),
                    Text(
                      t(loc, 'plan_default_time_field_timezone'),
                      style: Theme.of(host.context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text(
                            t(loc, 'plan_default_time_tz_profile')
                                .replaceFirst('%s', profileTzLabel),
                          ),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text(t(loc, 'plan_default_time_tz_fixed')),
                        ),
                      ],
                      selected: {useProfileTz},
                      onSelectionChanged: saveInFlight
                          ? null
                          : (s) {
                              setSheetState(() => useProfileTz = s.first);
                            },
                    ),
                    if (!useProfileTz) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: saveInFlight
                            ? null
                            : () async {
                                final picked = await showSearch<String?>(
                                  context: host.context,
                                  delegate: DefaultPlanTimezoneSearchDelegate(
                                    loc: loc,
                                    options:
                                        tz_settings.kCategoryDefaultTimezoneOptions,
                                  ),
                                );
                                if (picked == null || !context.mounted) return;
                                setSheetState(() => fixedIana = picked);
                              },
                        icon: const Icon(Icons.public_rounded),
                        label: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            '$fixedShort (${fixedIana.replaceAll('_', ' ')})',
                          ),
                        ),
                      ),
                    ],
                    if (saveError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        saveError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppButton.primary(
                      label: t(loc, 'save'),
                      onPressed: saveInFlight
                          ? null
                          : () {
                              unawaited(() async {
                                setSheetState(() {
                                  saveInFlight = true;
                                  saveError = null;
                                });
                                final result =
                                    await db.updateCategoryDefaultPlanSchedule(
                                  categoryId,
                                  hhmmFromTimeOfDay(pickedTime),
                                  useProfileTz ? null : fixedIana,
                                );
                                if (!context.mounted) return;
                                if (!result.ok) {
                                  final message = result.timezoneFieldMissing
                                      ? t(loc, 'plan_default_timezone_field_missing')
                                      : t(loc, 'toast_error');
                                  setSheetState(() {
                                    saveInFlight = false;
                                    saveError = message;
                                  });
                                  return;
                                }
                                if (host.mounted) {
                                  host.notifySetState(() {});
                                  modalSetState?.call(() {});
                                }
                                Navigator.of(context).pop();
                              }());
                            },
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

  Future<void> setCategoryDefaultPlanTime(
    int categoryId,
    void Function(void Function())? modalSetState,
  ) async {
    await editCategoryDefaultPlanSchedule(categoryId, modalSetState);
  }

  Future<void> clearCategoryDefaultPlanTime(
    int categoryId,
    void Function(void Function())? modalSetState,
  ) async {
    final result = await DatabaseService.instance.updateCategoryDefaultPlanSchedule(
      categoryId,
      null,
      null,
    );
    if (!host.mounted) return;
    if (!result.ok) {
      final loc = currentLocale.value;
      final message = result.timezoneFieldMissing
          ? t(loc, 'plan_default_timezone_field_missing')
          : t(loc, 'toast_error');
      await showDialog<void>(
        context: host.context,
        useRootNavigator: true,
        builder: (dialogContext) => AlertDialog(
          title: Text(t(loc, 'toast_error')),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
            ),
          ],
        ),
      );
      return;
    }
    host.notifySetState(() {});
    modalSetState?.call(() {});
  }
}
