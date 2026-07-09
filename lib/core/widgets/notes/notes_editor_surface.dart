// Canonical notes editor surface.
//
// Apple-Notes-style layout:
//   - large, borderless title (strong typography, no boxed input look)
//   - compact context row (category chip / tags; save status optional)
//   - thin hairline divider (only visual separator)
//   - large body editor with a SAFE overlay placeholder ("Start writing…")
//     that is always visible when the document is empty — even on web where
//     Quill's built-in placeholder is unreliable. Tapping the body requests
//     focus so the cursor appears immediately.
//   - persistent single-row formatting toolbar pinned above the keyboard
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
///
/// This widget is a [StatefulWidget] only so it can listen to Quill document
/// changes and focus changes to drive the safe overlay placeholder. No business
/// state is held here.
class AppNotesEditorSurface extends StatefulWidget {
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
    this.showStatusInContextRow = false,
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

  /// When false (default), the save status is NOT rendered inside the context
  /// row — the composing sheet is expected to surface it once (e.g. in the top
  /// bar) to avoid duplicate "All changes saved" chips.
  final bool showStatusInContextRow;

  @override
  State<AppNotesEditorSurface> createState() => _AppNotesEditorSurfaceState();
}

class _AppNotesEditorSurfaceState extends State<AppNotesEditorSurface> {
  bool _bodyEmpty = true;

  @override
  void initState() {
    super.initState();
    _bodyEmpty = _isBodyPlainEmpty();
    widget.quillController.document.changes.listen(_onDocChange);
    widget.quillFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.quillFocusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  bool _isBodyPlainEmpty() {
    final plain = widget.quillController.document
        .toPlainText()
        .replaceAll('\u200b', '')
        .trim();
    return plain.isEmpty;
  }

  void _onDocChange(_) {
    if (!mounted) return;
    final next = _isBodyPlainEmpty();
    if (next != _bodyEmpty) {
      setState(() => _bodyEmpty = next);
    }
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _requestBodyFocus() {
    FocusScope.of(context).requestFocus(widget.quillFocusNode);
  }

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
              controller: widget.titleController,
              focusNode: widget.titleFocusNode,
              autofocus: widget.autofocusTitle,
              style: titleStyle,
              minLines: 1,
              maxLines: keyboardOpen
                  ? widget.titleMaxLinesWhenKeyboardOpen
                  : widget.titleMaxLinesWhenKeyboardClosed,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: widget.titleHint,
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
              onChanged: widget.onTitleChanged,
            ),
          ),
          // Compact context row directly under title. Status is rendered here
          // only when the host opts in; otherwise the host surfaces it once
          // (e.g. in the top bar) to avoid duplicate chips.
          AppNotesContextRow(
            data: widget.contextRowData,
            onTap: widget.onContextRowTap,
            fallbackCategoryLabel: '',
            showStatus: widget.showStatusInContextRow,
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
          // A safe overlay placeholder is shown whenever the document is empty,
          // so the user always sees "Start writing…" even on web where Quill's
          // built-in placeholder is unreliable. Tapping anywhere in the body
          // area requests focus so the cursor appears immediately.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _requestBodyFocus,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: quill.QuillEditor.basic(
                      controller: widget.quillController,
                      focusNode: widget.quillFocusNode,
                      scrollController: widget.quillScrollController,
                      config: quill.QuillEditorConfig(
                        expands: true,
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                        // Keep Quill's placeholder too (harmless redundancy).
                        placeholder: widget.placeholder(context),
                        keyboardAppearance:
                            theme.brightness == Brightness.dark
                                ? Brightness.dark
                                : Brightness.light,
                      ),
                    ),
                  ),
                  // Safe overlay placeholder: visible when empty AND not focused.
                  if (_bodyEmpty && !widget.quillFocusNode.hasFocus)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                          child: Text(
                            widget.placeholder(context),
                            style: (tt.bodyLarge ?? tt.bodyMedium)?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.38),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Persistent formatting toolbar pinned above the keyboard.
          // Distinct background so it never blends invisibly into the surface.
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: AppNotesToolbar(
              controller: widget.quillController,
              actions: widget.toolbarActions,
              configBuilder: widget.configBuilder,
            ),
          ),
          // Keyboard-safe bottom inset so the IME never overlaps the toolbar.
          SizedBox(height: keyboardOpen ? kbBottom : 0),
        ],
      ),
    );
  }
}
