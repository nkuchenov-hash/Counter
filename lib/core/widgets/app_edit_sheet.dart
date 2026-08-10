import 'package:flutter/material.dart';

/// Canonical host for the primary record/plan/list edit sheet.
///
/// Domain content stays in feature/shared editors; modal behavior, draggable
/// sizing, keyboard insets, transparency, and sheet geometry live here so one
/// design-system change affects every primary edit flow.
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

/// Canonical surface for primary edit-sheet chrome.
///
/// New shared edit-sheet content should use this rather than creating a local
/// Material/radius/surface copy. Existing domain editors can migrate without
/// changing their save/autosave logic.
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
