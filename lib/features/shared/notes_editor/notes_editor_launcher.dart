// Launcher for the Notes editor sheet. Mirrors the existing pattern used by
// `showModalBottomSheet` callers (e.g. ActivityDetailSheet) so the editor is
// reachable from Lists as the PRIMARY editing experience.
//
// Always full-height on mobile and centered on wide screens.

import 'package:counter/data/models.dart';
import 'package:counter/features/shared/notes_editor/notes_editor_sheet.dart';
import 'package:flutter/material.dart';

/// Opens the Notes editor as a modal bottom sheet.
///
/// Returns the latest draft via [onSaved] after explicit Save OR after the
/// autosave flush that runs on dispose. The caller may use this to refresh
/// Lists UI without waiting for the Brain refresh broadcast.
///
/// [onEditDetails] opens the legacy PlanningTaskEditSheet when the user picks
/// "Edit details" from the editor's More menu. The Notes editor closes itself
/// before invoking this so only one modal is open at a time.
Future<void> showNotesEditorSheet({
  required BuildContext context,
  required PlanningTask task,
  ScrollController? scrollController,
  void Function(PlanningTask updated)? onSaved,
  void Function(PlanningTask task)? onDeleted,
  Future<void> Function(PlanningTask task)? onEditDetails,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 1.0,
          minChildSize: 0.6,
          maxChildSize: 1.0,
          expand: false,
          builder: (_, scrollController) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: NotesEditorSheet(
                task: task,
                scrollController: scrollController,
                onSaved: onSaved,
                onDeleted: onDeleted,
                onEditDetails: onEditDetails,
              ),
            );
          },
        ),
      );
    },
  );
}
