#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(rel, old, new):
    path = ROOT / rel
    text = path.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{rel}: expected exactly one match, found {count}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


# Keep default-plan timezone save inside the owning modal until PB confirms.
replace_once(
    'lib/features/planning/time_view/time_view_search_delegate.dart',
    """    var fixedIana = db.sanitizeDefaultPlanTimezone(rule?.defaultPlanTimezone) ??
        tz_settings.kCategoryDefaultTimezoneOptions.first.ianaId;

    final saved = await showModalBottomSheet<bool>(
""",
    """    var fixedIana = db.sanitizeDefaultPlanTimezone(rule?.defaultPlanTimezone) ??
        tz_settings.kCategoryDefaultTimezoneOptions.first.ianaId;
    var saveInFlight = false;
    String? saveError;

    final saved = await showModalBottomSheet<bool>(
""",
)

replace_once(
    'lib/features/planning/time_view/time_view_search_delegate.dart',
    """                    const SizedBox(height: 16),
                    AppButton.primary(
                      label: t(loc, 'save'),
                      onPressed: () => Navigator.pop(context, true),
                    ),
""",
    """                    if (saveError != null) ...[
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
                                Navigator.of(context).pop(true);
                              }());
                            },
                    ),
""",
)

replace_once(
    'lib/features/planning/time_view/time_view_search_delegate.dart',
    """    if (saved != true || !host.mounted) return;

    final result = await db.updateCategoryDefaultPlanSchedule(
      categoryId,
      hhmmFromTimeOfDay(pickedTime),
      useProfileTz ? null : fixedIana,
    );
    if (!host.mounted) return;
    if (!result.ok) {
      if (result.timezoneFieldMissing) {
        ScaffoldMessenger.of(host.context).showSnackBar(
          SnackBar(
            content: Text(t(loc, 'plan_default_timezone_field_missing')),
          ),
        );
      } else {
        AppSnack.failed();
      }
      return;
    }
    host.notifySetState(() {});
    modalSetState?.call(() {});
""",
    """    if (saved != true || !host.mounted) return;
""",
)

replace_once(
    'lib/features/planning/time_view/time_view_search_delegate.dart',
    """    if (!result.ok) {
      if (result.timezoneFieldMissing) {
        ScaffoldMessenger.of(host.context).showSnackBar(
          SnackBar(
            content: Text(t(currentLocale.value, 'plan_default_timezone_field_missing')),
          ),
        );
      } else {
        AppSnack.failed();
      }
      return;
    }
""",
    """    if (!result.ok) {
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
""",
)

# Deduplicate expensive full-plan timezone reprojection in Brain.
replace_once(
    'lib/data/plans/plan_projection_types.dart',
    """int _profileTimezoneProjectionRevision = 0;

String? _lastPlanTimeTzLogKey;
""",
    """int _profileTimezoneProjectionRevision = 0;
String? _lastAppliedProfileTimezoneProjectionSignature;

String? _lastPlanTimeTzLogKey;
""",
)
replace_once(
    'lib/data/plans/plan_projection_types.dart',
    """  void reprojectAllPlansForProfileTimezone() {
    _allPlansUserCache = [
""",
    """  void reprojectAllPlansForProfileTimezone() {
    final signature =
        '${_settings.timezoneOffsetHours}|${_settings.preferredTimeZone.trim()}';
    if (_lastAppliedProfileTimezoneProjectionSignature == signature) return;
    _lastAppliedProfileTimezoneProjectionSignature = signature;

    _allPlansUserCache = [
""",
)

# Brain reprojection already invalidates caches and planning stream hubs.
replace_once(
    'lib/features/planning/planning_page.dart',
    """        DatabaseService.instance.reprojectAllPlansForProfileTimezone();
        _refreshPlanningTasksAfterTimezoneChange();
        DatabaseService.instance.notifyPlanningRefresh(
          scheduleNetworkRefresh: false,
        );
        setState(() {});
""",
    """        DatabaseService.instance.reprojectAllPlansForProfileTimezone();
        _refreshPlanningTasksAfterTimezoneChange();
        setState(() {});
""",
)

# Existing bulk drag must not silently collapse to a single recurring mutation.
replace_once(
    'lib/features/planning/time_view/time_view_card_layer.dart',
    "import 'package:counter/core/widgets/plan_time_task_card.dart';\n",
    "import 'package:counter/core/app_snackbar.dart';\nimport 'package:counter/core/widgets/plan_time_task_card.dart';\n",
)
replace_once(
    'lib/features/planning/time_view/time_view_card_layer.dart',
    "import 'package:counter/features/planning/recurrence_scope_dialog.dart';\n",
    "import 'package:counter/features/planning/recurrence_scope_dialog.dart';\nimport 'package:counter/l10n/dictionary.dart';\n",
)
replace_once(
    'lib/features/planning/time_view/time_view_card_layer.dart',
    """  void commitTimelineVerticalDragWithOptionalRecurrenceScope({
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
    required List<PlanningTask> scheduledInRange,
  }) {
    final task = timelineVerticalDragTask;
    if (task == null || !timeViewTaskIsRecurring(task)) {
      commitTimelineVerticalDrag(
        planWallDay: planWallDay,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        scheduledInRange: scheduledInRange,
      );
      return;
    }
    unawaited(
      _commitRecurringTimelineVerticalDrag(
        task: task,
        planWallDay: planWallDay,
        rangeStart: rangeStart,
      ),
    );
  }
""",
    """  void commitTimelineVerticalDragWithOptionalRecurrenceScope({
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
    required List<PlanningTask> scheduledInRange,
  }) {
    final task = timelineVerticalDragTask;
    final bulkIds = Set<String>.from(timelineBulkDragPlanIds);
    if (bulkIds.length > 1) {
      final selected = scheduledInRange
          .where((candidate) => bulkIds.contains(candidate.planRowIdForBackend))
          .toList(growable: false);
      if (selected.any(timeViewTaskIsRecurring)) {
        stopHourGridEdgeScroll();
        host.notifySetState(clearTimelineInteractionState);
        AppSnack.warning(
          t(currentLocale.value, 'plan_bulk_drag_recurring_blocked'),
        );
        return;
      }
      commitTimelineVerticalDrag(
        planWallDay: planWallDay,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        scheduledInRange: scheduledInRange,
      );
      return;
    }
    if (task == null || !timeViewTaskIsRecurring(task)) {
      commitTimelineVerticalDrag(
        planWallDay: planWallDay,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        scheduledInRange: scheduledInRange,
      );
      return;
    }
    unawaited(
      _commitRecurringTimelineVerticalDrag(
        task: task,
        planWallDay: planWallDay,
        rangeStart: rangeStart,
      ),
    );
  }
""",
)

replace_once(
    'lib/l10n/langs/en.dart',
    "  'cancel': 'Cancel',\n",
    "  'cancel': 'Cancel',\n  'plan_bulk_drag_recurring_blocked':\n      'Move recurring plans separately before moving a selected group.',\n",
)
replace_once(
    'lib/l10n/langs/ru.dart',
    "  'cancel': 'Отмена',\n",
    "  'cancel': 'Отмена',\n  'plan_bulk_drag_recurring_blocked':\n      'Повторяющиеся планы нужно перемещать отдельно от выбранной группы.',\n",
)

migration = ROOT / 'pb_migrations/1787580300_add_category_default_plan_timezone.js'
if not migration.exists():
    migration.write_text("""/// <reference path=\"../pb_data/types.d.ts\" />

migrate(function(app) {
    var categories = app.findCollectionByNameOrId(\"categories\");
    if (!categories.fields.getByName(\"default_plan_timezone\")) {
        categories.fields.add(new TextField({
            name: \"default_plan_timezone\",
            max: 255
        }));
        app.save(categories);
    }
}, function(app) {
    try {
        var categories = app.findCollectionByNameOrId(\"categories\");
        var field = categories.fields.getByName(\"default_plan_timezone\");
        if (field) {
            categories.fields.removeById(field.id);
            app.save(categories);
        }
    } catch (_) {}
});
""", encoding='utf-8')

changelog = ROOT / 'CHANGELOG.md'
text = changelog.read_text(encoding='utf-8')
marker = '## 2026-08-24 — Plans Time View timezone/bulk P0 repair'
if marker not in text:
    changelog.write_text("""## 2026-08-24 — Plans Time View timezone/bulk P0 repair [engineering]

- Default category plan timezone saves now stay inside the owning editor until PocketBase confirms success; save errors remain visible above the modal instead of rendering behind Settings.
- Added the missing `categories.default_plan_timezone` PocketBase migration required by the existing DATA_MAP/POCKETBASE_MANIFEST contract.
- Profile-timezone full-plan reprojection is now idempotent per timezone signature and Planning day pages no longer rebroadcast the same global refresh.
- Existing Time View multi-card dragging is preserved; a recurring plan can no longer silently divert a multi-selection into a single-card recurrence mutation.

""" + text, encoding='utf-8')

print('Applied Plans Time View P0 repair.')
