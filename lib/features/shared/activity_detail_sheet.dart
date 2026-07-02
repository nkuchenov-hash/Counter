import 'package:counter/data/models.dart';
import 'package:counter/features/shared/planning_task_edit_sheet.dart';
import 'package:counter/features/shared/timeline_record_edit_sheet.dart';
import 'package:flutter/material.dart';

enum ActivityDetailKind { timelineRecord, planningTask }
class ActivityDetailSheet extends StatelessWidget {
  const ActivityDetailSheet({
    super.key,
    required this.kind,
    this.timelineRecord,
    this.planningTask,
    required this.scrollController,
    required this.onSaved,
    this.onDelete,
    this.onStop,
  });

  final ActivityDetailKind kind;
  final TimelineRecord? timelineRecord;
  final PlanningTask? planningTask;
  final ScrollController scrollController;
  final void Function(dynamic updated) onSaved;
  final VoidCallback? onDelete;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    if (kind == ActivityDetailKind.planningTask && planningTask != null) {
      return PlanningTaskEditSheet(
        task: planningTask!,
        dateKey: planningTask!.dateKey,
        scrollController: scrollController,
        onDelete: onDelete != null ? (_) => onDelete!() : null,
        onSaved: onSaved,
      );
    }
    if (kind == ActivityDetailKind.timelineRecord && timelineRecord != null) {
      return TimelineRecordSheetContent(
        record: timelineRecord!,
        scrollController: scrollController,
        onSaved: onSaved,
        onDelete: onDelete ?? () {},
        onStop: onStop ?? () {},
      );
    }
    return const SizedBox.shrink();
  }
}
