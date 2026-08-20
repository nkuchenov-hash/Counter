// Production Lists-tab Notes library shell — GLM NotesScreen composition.
// Presentation only: wraps existing filter/add/content widgets from [ListsPage].

import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Full-bleed GLM library workspace used by the live Lists tab.
class NotesLibraryProductionShell extends StatelessWidget {
  const NotesLibraryProductionShell({
    super.key,
    required this.header,
    required this.categoryBar,
    this.categoryBarInHeader = false,
    this.tagBar,
    this.inlineAdd,
    required this.content,
    this.topBar,
  });

  final Widget? topBar;
  final Widget header;
  final Widget categoryBar;
  final bool categoryBarInHeader;
  final Widget? tagBar;
  final Widget? inlineAdd;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return NotesGlmLibraryFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topBar != null) topBar!,
          header,
          if (!categoryBarInHeader) ...[
            const SizedBox(height: 8),
            categoryBar,
          ],
          if (tagBar != null) ...[
            const SizedBox(height: 6),
            tagBar!,
          ],
          if (inlineAdd != null) ...[
            SizedBox(height: categoryBarInHeader ? 8 : 14),
            inlineAdd!,
          ],
          const SizedBox(height: 8),
          Expanded(child: content),
        ],
      ),
    );
  }
}

/// GLM-styled quick-add row (same submit contract as [ListsInlineAddRow]).
class NotesGlmInlineAddRow extends StatelessWidget {
  const NotesGlmInlineAddRow({
    super.key,
    required this.locale,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final String locale;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final fill = dark
        ? scheme.surfaceContainerHigh.withValues(alpha: 0.82)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.75);
    final borderColor = dark
        ? scheme.outlineVariant.withValues(alpha: 0.78)
        : const Color(0xFFE2E8F0).withValues(alpha: 0.95);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SizedBox(
            height: kNotesLibraryControlHeight,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.done,
              style: TextStyle(fontSize: 15, color: scheme.onSurface),
              decoration: InputDecoration(
                hintText: t(locale, 'input_placeholder_list'),
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: notesGlmMetaColor(context),
                ),
                filled: true,
                fillColor: fill,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: scheme.primary.withValues(alpha: dark ? 0.82 : 0.55),
                    width: dark ? 1.2 : 1,
                  ),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox.square(
dimension: kNotesLibraryControlHeight,
child: Tooltip(
  message: t(locale, 'add'),
  child: Material(
    color: scheme.primary,
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onSubmit,
      customBorder: const CircleBorder(),
      child: Center(
        child: Icon(
          Icons.add_rounded,
          size: 24,
          color: scheme.onPrimary,
        ),
      ),
    ),
  ),
),
        ),
      ],
    );
  }
}
