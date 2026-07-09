// Canonical notes editor toolbar.
//
// Wraps `flutter_quill` simple toolbar with the formatting that a Notes-class
// editor needs (B/I/U/strike/bullet/numbered/checklist/link/clear) and appends
// app-owned trailing actions:
//   - divider insertion
//   - copy-as-markdown / paste-from-markdown (callback-only)
//   - a More (...) menu entry point forwarded to the composing surface
//
// Pure UI — no Brain/PocketBase imports. The composition surface owns the
// `QuillController`, clipboard calls, and any autosave gate. This widget only
// forwards callbacks.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Optional Notes toolbar action descriptor. Each non-null callback renders an
/// icon-only button appended after the standard Quill simple toolbar buttons.
class AppNotesToolbarActions {
  const AppNotesToolbarActions({
    this.onInsertDivider,
    this.onCopyAsMarkdown,
    this.onPasteFromMarkdown,
    this.onOpenMore,
    this.tooltips = const AppNotesToolbarTooltips(),
  });

  /// Insert a horizontal-rule divider at the current selection.
  final VoidCallback? onInsertDivider;

  /// Copy the editor contents as Markdown.
  final VoidCallback? onCopyAsMarkdown;

  /// Convert clipboard Markdown into the editor's rich content.
  final VoidCallback? onPasteFromMarkdown;

  /// Open the editor's More (...) menu. The composing surface owns the menu
  /// contents (Edit details, Convert to Plan, AI, Share, Attach, Delete, etc.).
  final VoidCallback? onOpenMore;

  /// Locale-aware tooltips surfaced on the trailing action buttons.
  final AppNotesToolbarTooltips tooltips;
}

/// Locale-aware tooltip strings for the trailing Notes toolbar buttons.
class AppNotesToolbarTooltips {
  const AppNotesToolbarTooltips({
    this.insertDivider = 'Divider',
    this.copyAsMarkdown = 'Copy as Markdown',
    this.pasteFromMarkdown = 'Paste from Markdown',
    this.more = 'More',
  });

  final String insertDivider;
  final String copyAsMarkdown;
  final String pasteFromMarkdown;
  final String more;
}

/// Compact single-row formatting toolbar for the Notes editor.
///
/// Wraps [quill.QuillSimpleToolbar] (with native link support enabled) then
/// appends app-owned actions (divider, markdown, more) when provided by the
/// composing surface.
class AppNotesToolbar extends StatelessWidget {
  const AppNotesToolbar({
    super.key,
    required this.controller,
    this.actions = const AppNotesToolbarActions(),
    this.configBuilder,
    this.minHeight = 44,
  });

  final quill.QuillController controller;
  final AppNotesToolbarActions actions;

  /// Optional builder to override the Quill toolbar config. When null a
  /// sensible default matching the Notes product UX is used.
  final quill.QuillSimpleToolbarConfig? Function(BuildContext)? configBuilder;

  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trailing = <Widget>[];

    if (actions.onInsertDivider != null) {
      trailing.add(
        _NotesToolbarIconButton(
          icon: Icons.horizontal_rule_rounded,
          tooltip: actions.tooltips.insertDivider,
          onTap: actions.onInsertDivider!,
        ),
      );
    }
    if (actions.onCopyAsMarkdown != null) {
      trailing.add(
        _NotesToolbarIconButton(
          icon: Icons.content_copy_rounded,
          tooltip: actions.tooltips.copyAsMarkdown,
          onTap: actions.onCopyAsMarkdown!,
        ),
      );
    }
    if (actions.onPasteFromMarkdown != null) {
      trailing.add(
        _NotesToolbarIconButton(
          icon: Icons.content_paste_rounded,
          tooltip: actions.tooltips.pasteFromMarkdown,
          onTap: actions.onPasteFromMarkdown!,
        ),
      );
    }
    if (actions.onOpenMore != null) {
      trailing.add(
        _NotesToolbarIconButton(
          icon: Icons.more_horiz_rounded,
          tooltip: actions.tooltips.more,
          onTap: actions.onOpenMore!,
          emphasize: true,
        ),
      );
    }

    final config = configBuilder?.call(context) ?? _defaultConfig(scheme);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: quill.QuillSimpleToolbar(
                controller: controller,
                config: config,
              ),
            ),
          ),
          if (trailing.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(children: trailing),
              ),
            ),
        ],
      ),
    );
  }

  quill.QuillSimpleToolbarConfig _defaultConfig(ColorScheme scheme) {
    return quill.QuillSimpleToolbarConfig(
      multiRowsDisplay: false,
      showDividers: false,
      toolbarSize: 13,
      toolbarRunSpacing: 0,
      buttonOptions: const quill.QuillSimpleToolbarButtonOptions(
        base: quill.QuillToolbarBaseButtonOptions(
          iconSize: 19,
          iconButtonFactor: 1.35,
        ),
      ),
      showFontFamily: false,
      showFontSize: false,
      showBoldButton: true,
      showItalicButton: true,
      showUnderLineButton: true,
      showStrikeThrough: true,
      showInlineCode: false,
      showColorButton: false,
      showBackgroundColorButton: false,
      showClearFormat: true,
      showAlignmentButtons: false,
      showHeaderStyle: false,
      showListNumbers: true,
      showListBullets: true,
      showListCheck: true,
      showCodeBlock: false,
      showQuote: false,
      showIndent: false,
      // Native Quill link button — clean dialog, selection-aware.
      showLink: true,
      showUndo: false,
      showRedo: false,
      showSearchButton: false,
      showSubscript: false,
      showSuperscript: false,
      showSmallButton: false,
      showLineHeightButton: false,
      showDirection: false,
      color: scheme.surface,
    );
  }
}

class _NotesToolbarIconButton extends StatelessWidget {
  const _NotesToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.emphasize = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = emphasize ? scheme.primary : scheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        color: color,
        splashRadius: 18,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// Convenience: read the plain text of the clipboard safely. Returns '' on
/// failure so callers never throw inside a tap handler.
Future<String> readClipboardTextSafely() async {
  try {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return (data?.text ?? '').trim();
  } catch (_) {
    return '';
  }
}
