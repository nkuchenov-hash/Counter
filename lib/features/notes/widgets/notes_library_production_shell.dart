// Production Lists-tab Notes library shell.
// Visual composition only: all data/actions remain owned by ListsPage.

import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Full-bleed Notes library workspace. The category strip acts as the index
/// tabs of a physical folder; the content below is the folder body.
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
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 600;
    final paneFill = dark
        ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.88)
        : kNotesFolderPane;
    final paneBorder = dark
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.70)
        : const Color(0xFFD5DFEA);

    return NotesGlmLibraryFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topBar != null) topBar!,
          header,
          if (!categoryBarInHeader) ...[
            const SizedBox(height: 11),
            SizedBox(
              height: 45,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: categoryBar,
              ),
            ),
          ],
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: paneFill,
                border: Border.all(color: paneBorder),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: dark
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFF3F536C).withValues(alpha: 0.045),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              padding: EdgeInsets.fromLTRB(
                mobile ? 12 : 28,
                mobile ? 14 : 22,
                mobile ? 12 : 28,
                mobile ? 10 : 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (categoryBarInHeader) categoryBar,
                  if (tagBar != null) ...[
                    if (categoryBarInHeader) const SizedBox(height: 6),
                    tagBar!,
                  ],
                  if (inlineAdd != null) ...[
                    SizedBox(height: tagBar != null ? 8 : 2),
                    inlineAdd!,
                    const SizedBox(height: 10),
                  ] else
                    const SizedBox(height: 2),
                  Expanded(child: content),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick-add keeps the existing submit contract, but visually lives inside the
/// folder body instead of looking like a separate legacy form.
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: NotesGlmLibraryInput(
            controller: controller,
            focusNode: focusNode,
            hintText: t(locale, 'input_placeholder_list'),
            textInputAction: TextInputAction.done,
            showSearchIcon: false,
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: kNotesLibraryControlHeight,
          child: Material(
            color: kNotesInk,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onSubmit,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      t(locale, 'add'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
