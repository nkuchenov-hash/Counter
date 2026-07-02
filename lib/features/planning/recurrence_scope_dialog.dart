import 'package:counter/data/models.dart';
import 'package:counter/data/recurrence_edit_scope.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Returns chosen scope, or null when dismissed.
Future<RecurrenceEditScope?> showRecurrenceScopeDialog(
  BuildContext context, {
  required PlanningTask task,
  required bool isDelete,
}) async {
  final locale = currentLocale.value;
  final titleKey = isDelete
      ? 'plan_recurrence_delete_scope_title'
      : 'plan_recurrence_edit_scope_title';
  final thisKey = isDelete
      ? 'plan_recurrence_delete_this'
      : 'plan_recurrence_edit_this';
  final futureKey = isDelete
      ? 'plan_recurrence_delete_future'
      : 'plan_recurrence_edit_future';
  final seriesKey = isDelete
      ? 'plan_recurrence_delete_series'
      : 'plan_recurrence_edit_series';
  const futureDisabledKey = 'plan_recurrence_future_disabled_hint';

  return showDialog<RecurrenceEditScope>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(t(locale, titleKey)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text(t(locale, thisKey)),
                onTap: () =>
                    Navigator.of(ctx).pop(RecurrenceEditScope.singleOccurrence),
              ),
              ListTile(
                enabled: recurrenceEditScopeIsSupported(
                  RecurrenceEditScope.thisAndFuture,
                ),
                title: Text(t(locale, futureKey)),
                subtitle: recurrenceEditScopeIsSupported(
                        RecurrenceEditScope.thisAndFuture)
                    ? null
                    : Text(t(locale, futureDisabledKey)),
                onTap: recurrenceEditScopeIsSupported(
                  RecurrenceEditScope.thisAndFuture,
                )
                    ? () => Navigator.of(
                        ctx,
                      ).pop(RecurrenceEditScope.thisAndFuture)
                    : null,
              ),
              ListTile(
                title: Text(t(locale, seriesKey)),
                onTap: () =>
                    Navigator.of(ctx).pop(RecurrenceEditScope.entireSeries),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t(locale, 'cancel')),
          ),
        ],
      );
    },
  );
}
