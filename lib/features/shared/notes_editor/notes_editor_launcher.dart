// Launcher for the Notes editor as a FULL-SCREEN ROUTE (not a modal sheet).
//
// Product decision: the Notes editor is the primary editing experience for
// Lists/Notes. It must feel like a real notes-app workspace, not a dimmed
// popup. We push a [MaterialPageRoute] with no scrim/backdrop:
//   - mobile/narrow: full-screen editor;
//   - desktop/tablet/wide: editor centered in a max-width column over a clean
//     neutral background (no dimmed app behind it).
//
// The editor widget itself ([NotesEditorSheet]) is unchanged — only the
// hosting route changes from `showModalBottomSheet` to `Navigator.push`.

import 'package:counter/data/models.dart';
import 'package:counter/features/shared/notes_editor/notes_editor_sheet.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Opens the Notes editor as a full-screen route above the current navigator.
///
/// Returns the latest draft via [onSaved] after explicit Save OR after the
/// autosave flush that runs on dispose.
///
/// [onEditDetails] opens the legacy PlanningTaskEditSheet when the user picks
/// "Edit details" from the editor's More menu. The Notes editor closes itself
/// before invoking this so only one modal/route is open at a time.
Future<void> showNotesEditorSheet({
  required BuildContext context,
  required PlanningTask task,
  ScrollController? scrollController,
  void Function(PlanningTask updated)? onSaved,
  void Function(PlanningTask task)? onDeleted,
  Future<void> Function(PlanningTask task)? onEditDetails,
}) {
  return Navigator.of(context).push<void>(
    _NotesEditorRoute(
      task: task,
      onSaved: onSaved,
      onDeleted: onDeleted,
      onEditDetails: onEditDetails,
    ),
  );
}

class _NotesEditorRoute extends PageRoute<void> {
  _NotesEditorRoute({
    required this.task,
    this.onSaved,
    this.onDeleted,
    this.onEditDetails,
  }) : super(barrierDismissible: false);

  final PlanningTask task;
  final void Function(PlanningTask updated)? onSaved;
  final void Function(PlanningTask task)? onDeleted;
  final Future<void> Function(PlanningTask task)? onEditDetails;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null; // No dimmed backdrop.

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final loc = currentLocale.value;
    // Fade + subtle rise, like opening a note in Apple Notes.
    final fade = CurveTween(curve: Curves.easeOut).animate(animation);
    final rise = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurveTween(curve: Curves.easeOut).animate(animation));

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: rise,
        child: _NotesEditorRouteHost(
          task: task,
          onSaved: onSaved,
          onDeleted: onDeleted,
          onEditDetails: onEditDetails,
          backTooltip: t(loc, 'notes_route_close_tooltip'),
        ),
      ),
    );
  }

  // No transitions on the modal-ish secondary animations.
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Hosts the editor in a route-friendly frame: full-screen on narrow widths,
/// centered max-width panel on wide screens. Owns the [ScrollController] that
/// the modal used to pass in.
class _NotesEditorRouteHost extends StatefulWidget {
  const _NotesEditorRouteHost({
    required this.task,
    required this.onSaved,
    required this.onDeleted,
    required this.onEditDetails,
    required this.backTooltip,
  });

  final PlanningTask task;
  final void Function(PlanningTask updated)? onSaved;
  final void Function(PlanningTask task)? onDeleted;
  final Future<void> Function(PlanningTask task)? onEditDetails;
  final String backTooltip;

  @override
  State<_NotesEditorRouteHost> createState() => _NotesEditorRouteHostState();
}

class _NotesEditorRouteHostState extends State<_NotesEditorRouteHost> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final isWide = width >= 720;
    final editor = NotesEditorSheet(
      task: widget.task,
      scrollController: _scrollController,
      onSaved: widget.onSaved,
      onDeleted: widget.onDeleted,
      onEditDetails: widget.onEditDetails,
    );

    if (!isWide) {
      // Mobile/narrow: full-screen editor, no chrome added. The route host
      // supplies the full screen height; the sheet fills it top-to-bottom.
      return Material(color: scheme.surface, child: editor);
    }

    // Desktop/tablet/wide web: a centered editor column with a deterministic
    // bounded height (full viewport minus safe areas). The sheet itself must
    // NOT re-center — centering is owned here, exactly once, to avoid nested
    // Center/ConstrainedBox chains that on web collapsed the toolbar below the
    // visible area. We do NOT use clipBehavior on an unbounded container.
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 880,
              // Bounded height = available area. This guarantees the inner
              // Column's Expanded (body) + fixed toolbar both paint inside the
              // viewport. Without a bounded height, Expanded can collapse.
              maxHeight: mq.size.height -
                  mq.padding.top -
                  mq.padding.bottom,
            ),
            child: editor,
          ),
        ),
      ),
    );
  }
}
