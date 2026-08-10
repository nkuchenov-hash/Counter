import 'package:counter/data/models.dart';
import 'package:counter/features/shared/planning_task_edit_sheet.dart';
import 'package:counter/features/shared/timeline_record_edit_sheet.dart';
import 'package:flutter/material.dart';

enum ActivityDetailKind { timelineRecord, planningTask }

/// Canonical host tokens for the primary record/plan/list edit sheet.
///
/// Domain content stays in the record/plan editors below; modal behavior,
/// draggable sizing, keyboard insets, transparency, and geometry stay here so
/// one shared change applies to every platform and every primary edit flow.
abstract final class AppEditSheetTokens {
  static const double initialChildSize = 0.88;
  static const double minChildSize = 0.42;
  static const double maxChildSize = 0.95;
  static const double surfaceRadius = 24;
}

typedef AppEditSheetBuilder = Widget Function(
  BuildContext context,
  ScrollController scrollController,
  BuildContext sheetContext,
);

Future<T?> showAppEditSheet<T>({
  required BuildContext context,
  required AppEditSheetBuilder builder,
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    clipBehavior: Clip.none,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: AppEditSheetTokens.initialChildSize,
          minChildSize: AppEditSheetTokens.minChildSize,
          maxChildSize: AppEditSheetTokens.maxChildSize,
          builder: (context, scrollController) =>
              builder(context, scrollController, sheetContext),
        ),
      );
    },
  );
}

/// Canonical primary edit-sheet surface.
class AppEditSheetSurface extends StatelessWidget {
  const AppEditSheetSurface({
    super.key,
    required this.child,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppEditSheetTokens.surfaceRadius),
      ),
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// Single domain router for the canonical primary edit sheet.
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
