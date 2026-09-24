// Notes surfaces — shared visual layer for the Notes library and editor.
// Presentation only. No Brain / PocketBase imports.

import 'package:flutter/material.dart';

/// Editor column (`max-w-3xl`).
const double kGlmEditorMaxWidth = 768;

const double kGlmEditorPadH = 20;
const double kGlmEditorPadV = 16;
const double kGlmTopBarHeight = 56;
const double kGlmToolbarHeight = 56;

const double kGlmTitleSizeDesktop = 30;
const double kGlmTitleSizeMobile = 28;
const double kGlmBodySize = 16;
const double kGlmMetaSize = 12;
const double kGlmPillHeight = 32;
const double kNotesLibraryControlHeight = 42;

// v32-gapfix5 reference palette.
const Color kNotesInk = Color(0xFF111827);
const Color kNotesMuted = Color(0xFF6B7280);
const Color kNotesAccent = Color(0xFF2563EB);
const Color kNotesRule = Color(0xFFDFE3E8);
const Color kNotesPaper = Color(0xFFF7F8FA);
const Color kNotesCard = Color(0xFFFCFDFE);
const Color kNotesCardBorder = Color(0xFFEEF1F5);
const Color kNotesFolderPane = Color(0xFFE3ECF8);

/// Kept for existing editor widgets that use the old public token names.
const Color kGlmMetaColor = Color(0xFF6B7280);
const Color kGlmPillTextColor = Color(0xFF475569);
const Color kGlmActiveBlockWash = Color(0x0A2563EB);

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

/// Full-page Notes background from the supplied v32-gapfix5 mockup.
class NotesGlmBackground extends StatelessWidget {
  const NotesGlmBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return ColoredBox(color: theme.colorScheme.surface, child: child);
    }
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF7F8FA),
              Color(0xFFEDF4FA),
              Color(0xFFF7F8FA),
            ],
            stops: [0.0, 0.46, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.12, -0.9),
                  radius: 0.72,
                  colors: [Color(0xD9D9E5F2), Color(0x00D9E5F2)],
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

/// Notes uses the full content area supplied by the LIFE OS shell. The HTML's
/// geometry defines the internal layout, not a fixed desktop canvas width.
class NotesGlmLibraryFrame extends StatelessWidget {
  const NotesGlmLibraryFrame({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotesGlmBackground(
      child: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final EdgeInsets pagePadding;
            if (width <= 520) {
              pagePadding = const EdgeInsets.fromLTRB(12, 10, 12, 20);
            } else if (width <= 1023) {
              pagePadding = const EdgeInsets.symmetric(horizontal: 18);
            } else {
              pagePadding = const EdgeInsets.fromLTRB(28, 12, 28, 28);
            }
            return SizedBox(
              width: double.infinity,
              child: Padding(
                padding: pagePadding,
                child: child,
              ),
            );
          },
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
                              color: scheme.outlineVariant.withValues(alpha: 0.45),
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

BoxDecoration notesGlmGlassPillDecoration({BuildContext? context}) {
  final dark = context != null && Theme.of(context).brightness == Brightness.dark;
  final scheme = context != null ? Theme.of(context).colorScheme : null;
  return BoxDecoration(
    color: dark
        ? scheme!.surfaceContainerHigh.withValues(alpha: 0.88)
        : const Color(0xFFF7F8FA).withValues(alpha: 0.80),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: dark
          ? scheme!.outlineVariant.withValues(alpha: 0.78)
          : const Color(0xFFDFE3E8).withValues(alpha: 0.82),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.16 : 0.035),
        blurRadius: dark ? 8 : 12,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

InputDecoration notesGlmSearchDecoration({
  required String hintText,
  Widget? suffixIcon,
  BuildContext? context,
  bool showSearchIcon = true,
}) {
  final dark = context != null && Theme.of(context).brightness == Brightness.dark;
  final scheme = context != null ? Theme.of(context).colorScheme : null;
  final meta = context != null ? notesGlmMetaColor(context) : kGlmMetaColor;
  final fill = dark
      ? scheme!.surfaceContainerHigh.withValues(alpha: 0.82)
      : const Color(0xFFF7F8FA).withValues(alpha: 0.78);
  final borderColor = dark
      ? scheme!.outlineVariant.withValues(alpha: 0.78)
      : const Color(0xFFDFE3E8).withValues(alpha: 0.76);
  return InputDecoration(
    constraints: const BoxConstraints.tightFor(height: 42),
    hintText: hintText,
    hintStyle: TextStyle(fontSize: 13.5, color: meta),
    prefixIcon: showSearchIcon
        ? Icon(Icons.search_rounded, size: 18, color: meta)
        : null,
    prefixIconConstraints: showSearchIcon
        ? const BoxConstraints(minWidth: 40, minHeight: 42)
        : null,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: fill,
    isDense: true,
    contentPadding: EdgeInsets.fromLTRB(showSearchIcon ? 0 : 13, 11, 13, 11),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: (scheme?.primary ?? kNotesAccent).withValues(
          alpha: dark ? 0.82 : 0.42,
        ),
      ),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: borderColor),
    ),
  );
}

/// Notes library input that follows the HTML's exact 42px search geometry.
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
  Widget build(BuildContext context) => TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(
          fontSize: 13.5,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: notesGlmSearchDecoration(
          hintText: hintText,
          suffixIcon: suffixIcon,
          context: context,
          showSearchIcon: showSearchIcon,
        ),
      );
}

/// Card surface from the supplied Notes mockup: quiet paper, 14px corners,
/// no decorative hover elevation. Selection is the only emphasized state.
BoxDecoration notesGlmGlassCardDecoration({
  double radius = 14,
  BuildContext? context,
  bool selected = false,
}) {
  final dark = context != null && Theme.of(context).brightness == Brightness.dark;
  final scheme = context != null ? Theme.of(context).colorScheme : null;
  if (dark) {
    final darkScheme = scheme!;
    return BoxDecoration(
      color: selected
          ? Color.alphaBlend(
              darkScheme.primary.withValues(alpha: 0.13),
              darkScheme.surfaceContainerHigh,
            )
          : darkScheme.surfaceContainerHigh.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: selected
            ? darkScheme.primary.withValues(alpha: 0.55)
            : darkScheme.outlineVariant.withValues(alpha: 0.62),
        width: selected ? 1.2 : 1,
      ),
    );
  }
  return BoxDecoration(
    color: selected
        ? const Color(0xFFF4F7FB)
        : kNotesCard.withValues(alpha: 0.94),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: selected
          ? kNotesAccent.withValues(alpha: 0.32)
          : kNotesCardBorder,
      width: selected ? 1.2 : 1,
    ),
  );
}
