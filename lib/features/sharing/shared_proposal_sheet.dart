import 'package:counter/data/database_service.dart';
import 'package:counter/data/sharing/share_service.dart';
import 'package:counter/shared/time/wall_clock.dart' as wall_clock;
import 'package:flutter/material.dart';

/// Safe proposal only: returns a draft to send, never patches personal plans.
class SharedProposalDraft {
  const SharedProposalDraft({
    this.title,
    this.startUtc,
    this.endUtc,
    this.comment = '',
  });
  final String? title;
  final String? startUtc;
  final String? endUtc;
  final String comment;
}

/// Uses the profile's selected timezone (not the device timezone).
Future<SharedProposalDraft?> showSharedProposalSheet(
  BuildContext context, {
  required SharedPlanItem item,
  required String wallDay,
  required bool ru,
}) async {
  final titleController = TextEditingController(text: item.title);
  final commentController = TextEditingController();
  final settings = DatabaseService.instance.settings;
  final oldUtc = DateTime.tryParse(item.startTime)?.toUtc();
  final endUtc = DateTime.tryParse(item.endTime)?.toUtc();
  final oldWall = oldUtc == null
      ? null
      : wall_clock.toWallClockForLabel(
          oldUtc, settings.timezoneOffsetHours, settings.preferredTimeZone);
  TimeOfDay? proposedClock;
  final result = await showDialog<SharedProposalDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (ctx, update) {
        String clockText(TimeOfDay clock) =>
            '${clock.hour.toString().padLeft(2, '0')}:'
            '${clock.minute.toString().padLeft(2, '0')}';
        return AlertDialog(
          title: Text(ru ? 'Предложить изменение' : 'Suggest a change'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: titleController,
                  maxLength: 160,
                  decoration: InputDecoration(labelText: ru
                      ? 'Название задачи' : 'Task title'),
                ),
                if (oldWall != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(ru
                        ? 'Время: ${clockText(proposedClock ??
                            TimeOfDay.fromDateTime(oldWall))}'
                        : 'Time: ${clockText(proposedClock ??
                            TimeOfDay.fromDateTime(oldWall))}'),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: proposedClock ??
                            TimeOfDay.fromDateTime(oldWall),
                      );
                      if (picked != null) update(() => proposedClock = picked);
                    },
                  ),
                TextField(
                  controller: commentController,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(labelText:
                      ru ? 'Комментарий (необязательно)'
                         : 'Comment (optional)'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(ru ? 'Отмена' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty || title.length > 160) return;
                String? changedStart;
                String? changedEnd;
                if (proposedClock != null && oldWall != null) {
                  final chosen = proposedClock!;
                  // Anchor to the recipient's profile-local calendar date,
                  // which may differ from the owner's selected wall day.
                  final day = oldWall;
                  final wall = DateTime(day.year, day.month, day.day,
                      chosen.hour, chosen.minute);
                  final proposedUtc = wall_clock.wallClockToUtcForLabel(
                    wall, settings.timezoneOffsetHours,
                    settings.preferredTimeZone,
                  );
                  // DST transitions may adjust the instant; enforce a valid
                  // strictly positive duration before suggesting an end.
                  if (proposedUtc != oldUtc) {
                    changedStart = proposedUtc.toIso8601String();
                    if (endUtc != null && oldUtc != null &&
                        endUtc.isAfter(oldUtc)) {
                      changedEnd = proposedUtc.add(
                        endUtc.difference(oldUtc)).toIso8601String();
                    }
                  }
                }
                final changedTitle = title != item.title ? title : null;
                if (changedTitle == null && changedStart == null) return;
                Navigator.pop(dialogContext, SharedProposalDraft(
                  title: changedTitle,
                  startUtc: changedStart,
                  endUtc: changedEnd,
                  comment: commentController.text.trim(),
                ));
              },
              child: Text(ru ? 'Предложить' : 'Suggest'),
            ),
          ],
        );
      },
    ),
  );
  titleController.dispose();
  commentController.dispose();
  return result;
}
