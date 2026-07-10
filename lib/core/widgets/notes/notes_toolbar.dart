// Canonical notes editor toolbar — DETERMINISTIC CUSTOM implementation.
//
// Why not QuillSimpleToolbar: in flutter_quill 11.x on Flutter Web,
// `QuillSimpleToolbar` (a `Wrap`/`Flow`-based widget) renders with effectively
// zero height when placed inside a horizontally scrollable container with a
// `minHeight` constraint. The result was an "invisible toolbar" on live web —
// the most reported Notes failure. It also depended on the package's internal
// theming, which made it blend into the editor surface.
//
// This file now ships a fixed-height (48px) toolbar of plain Material
// `IconButton`s wired DIRECTLY to `QuillController.formatSelection(...)`.
// No Quill toolbar widget is used. The toolbar is:
//   - always visible (deterministic height);
//   - visually distinct (caller paints a hairline top border + background);
//   - horizontally scrollable on narrow widths;
//   - reactive to the controller so active styles (bold ON) are highlighted.
//
// Pure UI — no Brain/PocketBase imports. The composing surface owns the
// `QuillController`, clipboard calls, and any autosave gate.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Optional Notes toolbar action descriptor. Each non-null callback renders an
/// icon-only button appended after the standard formatting buttons.
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

  /// Open the editor's More (...) menu.
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

/// Fixed-height (48px) formatting toolbar for the Notes editor.
///
/// Renders deterministic icon buttons bound directly to
/// [quill.QuillController.formatSelection]. The toolbar is ALWAYS visible:
/// its height is fixed (never `minHeight`-only), it is horizontally
/// scrollable on narrow widths, and active inline styles are highlighted by
/// listening to the controller.
class AppNotesToolbar extends StatefulWidget {
  const AppNotesToolbar({
    super.key,
    required this.controller,
    this.actions = const AppNotesToolbarActions(),
    this.configBuilder,
    this.height = 48,
  });

  final quill.QuillController controller;
  final AppNotesToolbarActions actions;

  /// Kept for API compatibility with the previous signature. Ignored — the
  /// custom toolbar does not use Quill's toolbar config.
  final quill.QuillSimpleToolbarConfig? Function(BuildContext)? configBuilder;

  /// Fixed toolbar height. The toolbar is given a deterministic [SizedBox]
  /// height so it can never collapse to zero.
  final double height;

  @override
  State<AppNotesToolbar> createState() => _AppNotesToolbarState();
}

class _AppNotesToolbarState extends State<AppNotesToolbar> {
  // Currently-active inline/block attributes at the caret or selection.
  // Refreshed from the controller's notifyListeners.
  Set<String> _activeKeys = const <String>{};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _onControllerChanged();
  }

  @override
  void didUpdateWidget(covariant AppNotesToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _onControllerChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    try {
      final sel = widget.controller.selection;
      if (!sel.isValid) {
        if (_activeKeys.isNotEmpty) {
          setState(() => _activeKeys = const <String>{});
        }
        return;
      }
      // getAllSelectionStyles() returns the union of inline + block styles
      // across the current selection (and at the caret when collapsed). We
      // collect any attribute key that has a non-null value.
      final styles = widget.controller.getAllSelectionStyles();
      final next = <String>{};
      for (final s in styles) {
        for (final key in s.attributes.keys) {
          if (s.attributes[key]?.value != null) next.add(key);
        }
      }
      if (next.length != _activeKeys.length ||
          !next.containsAll(_activeKeys)) {
        setState(() => _activeKeys = next);
      }
    } catch (_) {
      // Defensive: never break the toolbar over a stale selection read.
    }
  }

  void _toggle(quill.Attribute<dynamic> attr) {
    final c = widget.controller;
    // Ensure there is a valid selection to format; if not, place the caret at
    // the end so toggling works on an empty/new note too.
    if (!c.selection.isValid) {
      c.moveCursorToEnd();
    }
    c.formatSelection(attr);
    // Do NOT request focus here: the icon buttons below are marked
    // `canRequestFocus: false` so tapping them never steals focus from the
    // Quill editor — the caret stays visible and typing continues inline.
  }

  bool _isActive(String key) => _activeKeys.contains(key);

  Future<void> _insertLink() async {
    final url = await _showLinkDialog(context);
    if (url == null || url.trim().isEmpty) return;
    final c = widget.controller;
    if (!c.selection.isValid || c.selection.isCollapsed) {
      AppSnackLinkScope.warn(context, 'Select text first to add a link');
      return;
    }
    c.formatSelection(quill.LinkAttribute(url.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final buttons = <Widget>[
      _TogglableFormatButton(
        icon: Icons.format_bold_rounded,
        tooltip: 'Bold',
        active: _isActive(quill.Attribute.bold.key),
        activeColor: scheme.primary,
        onTap: () => _toggle(quill.Attribute.bold),
      ),
      _TogglableFormatButton(
        icon: Icons.format_italic_rounded,
        tooltip: 'Italic',
        active: _isActive(quill.Attribute.italic.key),
        activeColor: scheme.primary,
        onTap: () => _toggle(quill.Attribute.italic),
      ),
      _TogglableFormatButton(
        icon: Icons.format_underlined_rounded,
        tooltip: 'Underline',
        active: _isActive(quill.Attribute.underline.key),
        activeColor: scheme.primary,
        onTap: () => _toggle(quill.Attribute.underline),
      ),
      _TogglableFormatButton(
        icon: Icons.format_strikethrough_rounded,
        tooltip: 'Strikethrough',
        active: _isActive(quill.Attribute.strikeThrough.key),
        activeColor: scheme.primary,
        onTap: () => _toggle(quill.Attribute.strikeThrough),
      ),
      _vd(scheme),
      _TogglableFormatButton(
        icon: Icons.format_list_bulleted_rounded,
        tooltip: 'Bullet list',
        active: _isActive(quill.Attribute.list.key),
        activeColor: scheme.primary,
        onTap: () => _toggle(quill.Attribute.ul),
      ),
      _TogglableFormatButton(
        icon: Icons.format_list_numbered_rounded,
        tooltip: 'Numbered list',
        active: _isActive(quill.Attribute.list.key),
        activeColor: scheme.primary,
        onTap: () => _toggle(quill.Attribute.ol),
      ),
      _TogglableFormatButton(
        icon: Icons.checklist_rounded,
        tooltip: 'Checklist',
        active: _isActive(quill.Attribute.list.key),
        activeColor: scheme.primary,
        onTap: () => _toggle(quill.Attribute.unchecked),
      ),
      _vd(scheme),
      _TogglableFormatButton(
        icon: Icons.link_rounded,
        tooltip: 'Insert link',
        active: _isActive(quill.Attribute.link.key),
        activeColor: scheme.primary,
        onTap: _insertLink,
      ),
    ];

    // Trailing app-owned actions.
    final trailing = <Widget>[];
    if (widget.actions.onInsertDivider != null) {
      trailing.add(_vd(scheme));
      trailing.add(_PlainFormatButton(
        icon: Icons.horizontal_rule_rounded,
        tooltip: widget.actions.tooltips.insertDivider,
        onTap: widget.actions.onInsertDivider!,
      ));
    }
    if (widget.actions.onCopyAsMarkdown != null) {
      trailing.add(_PlainFormatButton(
        icon: Icons.content_copy_rounded,
        tooltip: widget.actions.tooltips.copyAsMarkdown,
        onTap: widget.actions.onCopyAsMarkdown!,
      ));
    }
    if (widget.actions.onPasteFromMarkdown != null) {
      trailing.add(_PlainFormatButton(
        icon: Icons.content_paste_rounded,
        tooltip: widget.actions.tooltips.pasteFromMarkdown,
        onTap: widget.actions.onPasteFromMarkdown!,
      ));
    }
    if (widget.actions.onOpenMore != null) {
      trailing.add(_vd(scheme));
      trailing.add(_PlainFormatButton(
        icon: Icons.more_horiz_rounded,
        tooltip: widget.actions.tooltips.more,
        emphasize: true,
        onTap: widget.actions.onOpenMore!,
      ));
    }

    // FIXED height SizedBox guarantees the toolbar is always painted with a
    // concrete vertical extent. Combined with the horizontal scroll, the
    // toolbar never collapses and never overflows the row.
    return SizedBox(
      height: widget.height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            ...buttons,
            ...trailing,
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _vd(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.6),
      ),
    );
  }

  Future<String?> _showLinkDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insert link'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://example.com',
            labelText: 'URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _TogglableFormatButton extends StatelessWidget {
  const _TogglableFormatButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
    required this.activeColor,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      // Prevent the button from stealing keyboard focus from the Quill editor
      // when tapped — the caret stays in the body and typing continues.
      child: FocusScope(
        canRequestFocus: false,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
          decoration: BoxDecoration(
            color: active ? activeColor.withValues(alpha: 0.16) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            onPressed: onTap,
            icon: Icon(icon, size: 20),
            color: active ? activeColor : scheme.onSurfaceVariant,
            splashRadius: 18,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

class _PlainFormatButton extends StatelessWidget {
  const _PlainFormatButton({
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
      child: FocusScope(
        canRequestFocus: false,
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          color: color,
          splashRadius: 18,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          padding: EdgeInsets.zero,
        ),
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

/// Tiny indirection so the toolbar file has no dependency on app-wide snack
/// plumbing. Hosts can wire a real warning; default is a no-op.
class AppSnackLinkScope {
  static void warn(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
