// Canonical notes editor toolbar.
//
// Wraps the existing `flutter_quill` simple toolbar and layers Apple-Notes-style
// affordances the Quill simple toolbar does not expose by default:
//   - inline link insertion
//   - horizontal divider insertion
//   - copy-as-markdown / paste-from-markdown hooks (callback-only)
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
    this.onInsertLink,
    this.onInsertDivider,
    this.onCopyAsMarkdown,
    this.onPasteFromMarkdown,
    this.tooltips = const AppNotesToolbarTooltips(),
  });

  /// Insert an inline link into the editor's current selection.
  final VoidCallback? onInsertLink;

  /// Insert a horizontal-rule divider at the current selection.
  final VoidCallback? onInsertDivider;

  /// Copy the editor contents as Markdown.
  final VoidCallback? onCopyAsMarkdown;

  /// Convert clipboard Markdown into the editor's rich content.
  final VoidCallback? onPasteFromMarkdown;

  /// Locale-aware tooltips surfaced on the trailing action buttons.
  final AppNotesToolbarTooltips tooltips;
}

/// Locale-aware tooltip strings for the trailing Notes toolbar buttons.
class AppNotesToolbarTooltips {
  const AppNotesToolbarTooltips({
    this.insertLink = 'Insert link',
    this.insertDivider = 'Divider',
    this.copyAsMarkdown = 'Copy as Markdown',
    this.pasteFromMarkdown = 'Paste from Markdown',
  });

  final String insertLink;
  final String insertDivider;
  final String copyAsMarkdown;
  final String pasteFromMarkdown;
}

/// Compact single-row formatting toolbar for the Notes editor.
///
/// Wraps [quill.QuillSimpleToolbar] to keep formatting consistent with the
/// existing edit sheets, then appends app-owned actions (link, divider,
/// markdown) when provided by the composing surface.
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
  /// sensible default matching the existing planning edit sheet is used.
  final quill.QuillSimpleToolbarConfig? Function(BuildContext)? configBuilder;

  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trailing = <Widget>[];

    if (actions.onInsertLink != null) {
      trailing.add(
        _NotesToolbarIconButton(
          icon: Icons.link_rounded,
          tooltip: actions.tooltips.insertLink,
          onTap: actions.onInsertLink!,
        ),
      );
    }
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

    final config = configBuilder?.call(context) ?? _defaultConfig(scheme);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: quill.QuillSimpleToolbar(
              controller: controller,
              config: config,
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
                padding: const EdgeInsets.symmetric(horizontal: 4),
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
          iconSize: 17,
          iconButtonFactor: 1.42,
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
      showLink: false,
      showUndo: false,
      showRedo: false,
      showSearchButton: false,
      showSubscript: false,
      showSuperscript: false,
      showSmallButton: false,
      showLineHeightButton: false,
      showDirection: false,
      color: scheme.surfaceContainerHighest,
    );
  }
}

class _NotesToolbarIconButton extends StatelessWidget {
  const _NotesToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        color: scheme.onSurfaceVariant,
        splashRadius: 18,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
