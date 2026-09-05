// GLM Notes v3 page surfaces — literal background + centered column shells.
// Presentation only. No Brain / PocketBase imports.

import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:flutter/material.dart';

/// Editor column (`max-w-3xl`).
const double kGlmEditorMaxWidth = 768;

/// Library content (`max-w-5xl`).
const double kGlmLibraryMaxWidth = 1440;

const double kGlmEditorPadH = 20;
const double kGlmEditorPadV = 16;
const double kGlmTopBarHeight = 56;
const double kGlmToolbarHeight = 56;

const double kGlmTitleSizeDesktop = 30;
const double kGlmTitleSizeMobile = 28;
const double kGlmBodySize = 16;
const double kGlmMetaSize = 12;
const double kGlmPillHeight = 32;
const double kNotesLibraryControlHeight = kAppQuickEntryControlHeight;

/// Muted blue-grey metadata (`text-muted` in GLM light theme).
const Color kGlmMetaColor = Color(0xFF94A3B8);

/// Secondary pill label on light glass.
const Color kGlmPillTextColor = Color(0xFF475569);

/// Barely-visible active block wash.
const Color kGlmActiveBlockWash = Color(0x0A6366F1);

Color notesGlmMetaColor(BuildContext context) {
  final theme = Theme.of(context);
  if (theme.brightness == Brightness.dark) {
    return theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.92);
  }
  return kGlmMetaColor;
}

Color notesGlmPillTextColor(BuildContext context) {
  final theme = Theme.of(context);
  if (theme.brightness == Brightness.dark) {
    return theme.colorScheme.onSurfaceVariant;
  }
  return kGlmPillTextColor;
}

/// Soft full-page gradient matching the supplied GLM screenshot.
class NotesGlmBackground extends StatelessWidget {
  const NotesGlmBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: child,
      );
    }
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8F9FD), Color(0xFFF5F6FC)],
            stops: [0.0, 0.55],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.85, 0.95),
                  radius: 1.1,
                  colors: [Color(0x38EEF0FF), Color(0x00EEF0FF)],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.9, 0.92),
                  radius: 1.0,
                  colors: [Color(0x30FFF1F5), Color(0x00FFF1F5)],
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Centers Notes library content at GLM `max-w-5xl` on a full-bleed gradient.
class NotesGlmLibraryFrame extends StatelessWidget {
  const NotesGlmLibraryFrame({
    super.key,
    required this.child,
    this.maxWidth = kGlmLibraryMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final desktop = shellUsesSideNavigation(width);
    return NotesGlmBackground(
      child: SafeArea(
        top: false,
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: desktop ? double.infinity : maxWidth,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                desktop
                    ? kShellDesktopContentHorizontalPadding
                    : wide
                    ? 24
                    : 20,
                desktop ? kShellDesktopContentTopPadding : 16,
                desktop
                    ? kShellDesktopContentHorizontalPadding
                    : wide
                    ? 24
                    : 20,
                16,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-height centered editor column: top bar + scroll body + bottom toolbar.
class NotesGlmEditorFrame extends StatelessWidget {
  const NotesGlmEditorFrame({
    super.key,
    required this.topBar,
    required this.body,
    required this.toolbar,
    this.keyboardInset = 0,
  });

  final Widget topBar;
  final Widget body;
  final Widget toolbar;
  final double keyboardInset;

  @override
  Widget build(BuildContext context) {
    return NotesGlmBackground(
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columnWidth = constraints.maxWidth < kGlmEditorMaxWidth
                ? constraints.maxWidth
                : kGlmEditorMaxWidth;
            final scheme = Theme.of(context).colorScheme;
            final hasOuterCanvas = constraints.maxWidth > kGlmEditorMaxWidth;
            return Center(
              child: SizedBox(
                width: columnWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: hasOuterCanvas
                        ? Border.symmetric(
                            vertical: BorderSide(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          )
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      topBar,
                      Expanded(child: body),
                      if (keyboardInset > 0) SizedBox(height: keyboardInset),
                      toolbar,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// GLM glass pill for add-block actions.
BoxDecoration notesGlmGlassPillDecoration({BuildContext? context}) {
  final dark =
      context != null && Theme.of(context).brightness == Brightness.dark;
  final scheme = context != null ? Theme.of(context).colorScheme : null;
  return BoxDecoration(
    color: dark
        ? scheme!.surfaceContainerHigh.withValues(alpha: 0.88)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.82),
    borderRadius: BorderRadius.circular(999),
    border: Border.all(
      color: dark
          ? scheme!.outlineVariant.withValues(alpha: 0.78)
          : const Color(0xFFE2E8F0),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.18 : 0.04),
        blurRadius: dark ? 8 : 3,
        offset: const Offset(0, 1),
      ),
    ],
  );
}

/// GLM library search field surface.
InputDecoration notesGlmSearchDecoration({
  required String hintText,
  Widget? suffixIcon,
  BuildContext? context,
}) {
  final dark =
      context != null && Theme.of(context).brightness == Brightness.dark;
  final scheme = context != null ? Theme.of(context).colorScheme : null;
  final meta = context != null ? notesGlmMetaColor(context) : kGlmMetaColor;
  final fill = dark
      ? scheme!.surfaceContainerHigh.withValues(alpha: 0.82)
      : const Color(0xFFFFFFFF).withValues(alpha: 0.75);
  final borderColor = dark
      ? scheme!.outlineVariant.withValues(alpha: 0.78)
      : const Color(0xFFE2E8F0).withValues(alpha: 0.95);
  return InputDecoration(
    constraints: const BoxConstraints.tightFor(
      height: kNotesLibraryControlHeight,
    ),
    hintText: hintText,
    hintStyle: TextStyle(fontSize: 14, color: meta),
    prefixIcon: Icon(Icons.search_rounded, size: 18, color: meta),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: fill,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: (scheme?.primary ?? const Color(0xFF6366F1)).withValues(
          alpha: dark ? 0.82 : 0.55,
        ),
        width: dark ? 1.2 : 1,
      ),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: borderColor),
    ),
  );
}

/// Notes compatibility wrapper over the canonical core library input.
/// Search, Notes quick-add, Planning and Timeline now render the same field.
class NotesGlmLibraryInput extends StatelessWidget {
  const NotesGlmLibraryInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.suffixIcon,
    this.showSearchIcon = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;
  final bool showSearchIcon;

  @override
  Widget build(BuildContext context) => AppLibraryInput(
    controller: controller,
    focusNode: focusNode,
    hintText: hintText,
    textInputAction: textInputAction,
    textCapitalization: textCapitalization,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    suffixIcon: suffixIcon,
    showSearchIcon: showSearchIcon,
  );
}

/// GLM glass card surface for library note cards.
BoxDecoration notesGlmGlassCardDecoration({
  double radius = 16,
  BuildContext? context,
  bool selected = false,
}) {
  final dark =
      context != null && Theme.of(context).brightness == Brightness.dark;
  final scheme = context != null ? Theme.of(context).colorScheme : null;
  final Color fill;
  final Color borderColor;
  final List<BoxShadow> shadows;

  if (dark) {
    final base = scheme!.surfaceContainerHigh;
    fill = selected
        ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.14), base)
        : base.withValues(alpha: 0.82);
    borderColor = selected
        ? scheme.primary.withValues(alpha: 0.62)
        : scheme.outlineVariant.withValues(alpha: 0.62);
    shadows = [
      BoxShadow(
        color: selected
            ? scheme.primary.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.18),
        blurRadius: selected ? 14 : 10,
        offset: const Offset(0, 3),
      ),
    ];
  } else {
    fill = selected
        ? const Color(0xFFF1F3FF).withValues(alpha: 0.94)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.72);
    borderColor = selected
        ? const Color(0xFF6366F1).withValues(alpha: 0.45)
        : const Color(0xFFE8ECF4);
    shadows = [
      BoxShadow(
        color: selected
            ? const Color(0xFF6366F1).withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.03),
        blurRadius: selected ? 12 : 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  return BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor, width: selected ? 1.2 : 1),
    boxShadow: shadows,
  );
}
