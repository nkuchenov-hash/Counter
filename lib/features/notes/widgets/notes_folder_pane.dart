import 'package:counter/data/database_service.dart';
import 'package:flutter/material.dart';

/// A single folder-paper surface shared by the active tab and Notes contents.
/// The tab sits flush on top; the 18px inset belongs INSIDE the folder, so the
/// note cards are visually separated without breaking the tab-to-paper seam.
Color notesFolderPaper(BuildContext context, int? categoryId) {
  final scheme = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (categoryId == null) {
    return dark
        ? Color.alphaBlend(const Color(0xFF285B99).withValues(alpha: 0.25), scheme.surface)
        : const Color(0xFFE3ECF8);
  }
  final accent = DatabaseService.instance.getCategoryRuleById(categoryId)?.colorOrDefault;
  if (accent == null) return scheme.surface;
  // Real folder paper: the selected spine and the page use one saturated
  // category surface, not a nearly-white tint that hides the active color.
  return Color.alphaBlend(
    accent.withValues(alpha: dark ? 0.68 : 0.82),
    dark ? scheme.surface : Colors.white,
  );
}

class NotesFolderPane extends StatelessWidget {
  const NotesFolderPane({
    super.key,
    required this.categoryId,
    required this.child,
  });

  final int? categoryId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: const ValueKey('notes-folder-paper'),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: notesFolderPaper(context, categoryId),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(15),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: child,
    );
  }
}
