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
    this.tagBar,
    this.inlineAdd,
    required this.content,
    this.topBar,
  });

  final Widget? topBar;
  final Widget header;
  final Widget categoryBar;
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
          const SizedBox(height: 8),
          categoryBar,
          if (tagBar != null) ...[
            const SizedBox(height: 6),
            tagBar!,
          ],
          if (inlineAdd != null) ...[
            const SizedBox(height: 8),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF).withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
              decoration: InputDecoration(
                hintText: t(locale, 'input_placeholder_list'),
                hintStyle: const TextStyle(fontSize: 14, color: kGlmMetaColor),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onSubmit,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    t(locale, 'add'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
