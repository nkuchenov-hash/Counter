// GLM Notes v3 page surfaces — literal background + centered column shells.
// Presentation only. No Brain / PocketBase imports.

import 'package:flutter/material.dart';

/// Editor column (`max-w-3xl`).
const double kGlmEditorMaxWidth = 768;

/// Library content (`max-w-5xl`).
const double kGlmLibraryMaxWidth = 1024;

const double kGlmEditorPadH = 20;
const double kGlmEditorPadV = 20;
const double kGlmTopBarHeight = 56;
const double kGlmToolbarHeight = 56;

const double kGlmTitleSizeDesktop = 32;
const double kGlmTitleSizeMobile = 30;
const double kGlmBodySize = 17;
const double kGlmMetaSize = 12;
const double kGlmPillHeight = 32;

/// Muted blue-grey metadata (`text-muted` in GLM light theme).
const Color kGlmMetaColor = Color(0xFF94A3B8);

/// Secondary pill label on light glass.
const Color kGlmPillTextColor = Color(0xFF475569);

/// Barely-visible active block wash.
const Color kGlmActiveBlockWash = Color(0x0A6366F1);

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
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8F9FD),
            Color(0xFFF5F6FC),
          ],
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
                colors: [
                  Color(0x38EEF0FF),
                  Color(0x00EEF0FF),
                ],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.9, 0.92),
                radius: 1.0,
                colors: [
                  Color(0x30FFF1F5),
                  Color(0x00FFF1F5),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Centers Notes library content at GLM `max-w-5xl`.
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
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return NotesGlmBackground(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 32 : 20,
              vertical: 16,
            ),
            child: child,
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
            return Center(
              child: SizedBox(
                width: kGlmEditorMaxWidth,
                height: constraints.maxHeight,
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
            );
          },
        ),
      ),
    );
  }
}

/// GLM glass pill for add-block actions.
BoxDecoration notesGlmGlassPillDecoration() {
  return BoxDecoration(
    color: const Color(0xFFFFFFFF).withValues(alpha: 0.82),
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: const Color(0xFFE2E8F0)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ],
  );
}

/// GLM glass card surface for library note cards.
BoxDecoration notesGlmGlassCardDecoration({double radius = 16}) {
  return BoxDecoration(
    color: const Color(0xFFFFFFFF).withValues(alpha: 0.72),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFE8ECF4)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}
