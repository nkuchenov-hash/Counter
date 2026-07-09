// Canonical notes editor surface.
//
// Apple-Notes-style layout:
//   - large, borderless title (strong typography, no boxed input look)
//   - compact context row (category chip / tags / save status / checklist)
//   - thin hairline divider (only visual separator)
//   - single-row formatting toolbar
//   - large body editor that fills remaining space with a clear placeholder
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
    this.titleMaxLinesWhenKeyboardClosed = 3,
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

  /// Optional override of the Quill toolbar config.
  final quill.QuillSimpleToolbarConfig? Function(BuildContext)? configBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kbBottom = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = kbBottom > 0;
    final tt = theme.textTheme;

    // Apple-Notes-style title: large, plain, strong weight, no input border.
    final titleStyle = (tt.headlineSmall ?? tt.titleLarge ?? tt.titleMedium)
        ?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          height: 1.2,
          color: scheme.onSurface,
        );

    return Material(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title — borderless, large, comfortable.
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              keyboardOpen ? 8 : 14,
              20,
              4,
            ),
            child: TextField(
              controller: titleController,
              focusNode: titleFocusNode,
              autofocus: autofocusTitle,
              style: titleStyle,
              minLines: 1,
              maxLines: keyboardOpen
                  ? titleMaxLinesWhenKeyboardOpen
                  : titleMaxLinesWhenKeyboardClosed,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: titleHint,
                hintStyle: titleStyle?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.32),
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
              onChanged: onTitleChanged,
            ),
          ),
          // Compact context row directly under title.
          AppNotesContextRow(
            data: contextRowData,
            onTap: onContextRowTap,
            fallbackCategoryLabel: '',
          ),
          // Single thin hairline divider — the only structural separator.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          // Body editor — fills remaining space, no boxed border.
          Expanded(
            child: quill.QuillEditor.basic(
              controller: quillController,
              focusNode: quillFocusNode,
              scrollController: quillScrollController,
              config: quill.QuillEditorConfig(
                expands: true,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                placeholder: placeholder(context),
                keyboardAppearance: theme.brightness == Brightness.dark
                    ? Brightness.dark
                    : Brightness.light,
              ),
            ),
          ),
          // Persistent formatting toolbar pinned above the keyboard.
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: AppNotesToolbar(
              controller: quillController,
              actions: toolbarActions,
              configBuilder: configBuilder,
            ),
          ),
          // Keyboard-safe bottom inset so the IME never overlaps the toolbar.
          SizedBox(height: keyboardOpen ? kbBottom : 0),
        ],
      ),
    );
  }
}
