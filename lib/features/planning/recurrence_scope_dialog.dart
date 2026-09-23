import 'package:counter/data/models.dart';
import 'package:counter/data/recurrence_edit_scope.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Keeps one explicit recurrence-scope decision per edit session and coalesces
/// concurrent autosave/Save requests onto the same dialog.
class RecurrenceEditScopeGate {
  RecurrenceEditScope? selected;
  Future<RecurrenceEditScope?>? _pending;

  bool requiresChoice(bool isRecurring) => isRecurring && selected == null;

  Future<RecurrenceEditScope?> resolve(
    BuildContext context, {
    required PlanningTask task,
    required bool isRecurring,
  }) async {
    if (!isRecurring) return RecurrenceEditScope.singleOccurrence;
    if (selected != null) return selected;
    if (_pending != null) return _pending!;
    final pending = showRecurrenceScopeDialog(
      context,
      task: task,
      isDelete: false,
    );
    _pending = pending;
    final scope = await pending;
    if (identical(_pending, pending)) _pending = null;
    if (scope != null) selected = scope;
    return scope;
  }
}

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
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        title: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(t(locale, titleKey)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t(locale, thisKey)),
                onTap: () =>
                    Navigator.of(ctx).pop(RecurrenceEditScope.singleOccurrence),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
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
                contentPadding: EdgeInsets.zero,
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
