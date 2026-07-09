// Canonical notes editor surface.
//
// A reusable container that gives the editor:
//   - large comfortable title field
//   - compact context row (category chip / tags / save status)
//   - single-row formatting toolbar
//   - large body editor that fills remaining space
//   - keyboard-safe padding (no clipping when the IME opens)
//
// Pure UI. The composing feature surface supplies the `QuillController`,
// title controller, and the [AppNotesContextRowData]. No Brain/PocketBase
// imports, no autosave logic — the surface only emits action callbacks.

import 'package:counter/core/widgets/notes/notes_context_row.dart';
import 'package:counter/core/widgets/notes/notes_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Optional hint text shown by the editor body when empty.
typedef NotesEditorPlaceholderBuilder = String Function(BuildContext);

/// A self-contained Apple-Notes-style editor surface.
///
/// The caller owns all state; this widget is presentational. Layout is
/// keyboard-safe via [MediaQuery.viewInsetsOf] so the body never gets clipped
/// when the IME opens on mobile web / mobile native.
class AppNotesEditorSurface extends StatelessWidget {
  const AppNotesEditorSurface({
    super.key,
    required this.titleController,
    required this.titleFocusNode,
    required this.quillController,
    required this.quillFocusNode,
    required this.quillScrollController,
    required this.contextRowData,
    required this.placeholder,
    required this.toolbarActions,
    this.onTitleChanged,
    this.onContextRowTap,
    this.titleHint,
    this.autofocusTitle = false,
    this.titleMaxLinesWhenKeyboardOpen = 2,
    this.titleMaxLinesWhenKeyboardClosed = 4,
    this.bodyMinHeight = 220,
    this.fallbackCategoryLabel = 'Uncategorized',
    this.configBuilder,
  });

  final TextEditingController titleController;
  final FocusNode titleFocusNode;
  final quill.QuillController quillController;
  final FocusNode quillFocusNode;
  final ScrollController quillScrollController;
  final AppNotesContextRowData contextRowData;
  final NotesEditorPlaceholderBuilder placeholder;

  /// Optional toolbar actions surfaced in the trailing toolbar group.
  final AppNotesToolbarActions toolbarActions;

  final ValueChanged<String>? onTitleChanged;

  /// Tap target for the compact context row (e.g. open category picker).
  final VoidCallback? onContextRowTap;

  final String? titleHint;
  final bool autofocusTitle;
  final int titleMaxLinesWhenKeyboardOpen;
  final int titleMaxLinesWhenKeyboardClosed;
  final double bodyMinHeight;

  /// Localized "Uncategorized" label surfaced when the context row has no
  /// category. Provided by the composing surface so the canonical widget
  /// never hardcodes user-facing strings.
  final String fallbackCategoryLabel;

  /// Optional override of the Quill toolbar config (used by the Component Lab
  /// mock to show disabled states).
  final quill.QuillSimpleToolbarConfig? Function(BuildContext)? configBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kbBottom = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = kbBottom > 0;

    return Material(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              keyboardOpen ? 6 : 12,
              8,
              keyboardOpen ? 4 : 8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: titleController,
                    focusNode: titleFocusNode,
                    autofocus: autofocusTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    minLines: 1,
                    maxLines: keyboardOpen
                        ? titleMaxLinesWhenKeyboardOpen
                        : titleMaxLinesWhenKeyboardClosed,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: titleHint ?? 'Title',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: onTitleChanged,
                  ),
                ),
              ],
            ),
          ),
          AppNotesContextRow(
            data: contextRowData,
            onTap: onContextRowTap,
            fallbackCategoryLabel: fallbackCategoryLabel,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: AppNotesToolbar(
              controller: quillController,
              actions: toolbarActions,
              configBuilder: configBuilder,
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              constraints: BoxConstraints(minHeight: bodyMinHeight),
              child: quill.QuillEditor.basic(
                controller: quillController,
                focusNode: quillFocusNode,
                scrollController: quillScrollController,
                config: quill.QuillEditorConfig(
                  expands: true,
                  padding: const EdgeInsets.all(12),
                  placeholder: placeholder(context),
                  keyboardAppearance: theme.brightness == Brightness.dark
                      ? Brightness.dark
                      : Brightness.light,
                ),
              ),
            ),
          ),
          // Keyboard-safe bottom inset so the IME never overlaps the editor.
          SizedBox(height: keyboardOpen ? kbBottom : 0),
        ],
      ),
    );
  }
}
