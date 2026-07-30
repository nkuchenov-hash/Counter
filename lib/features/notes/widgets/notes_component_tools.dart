part of 'notes_canonical_components.dart';

class NotesToolbarAction {
  const NotesToolbarAction({
    required this.tool,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.enabled = true,
  });

  final NotesToolbarTool tool;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;
  final bool enabled;
}

class NotesToolbarButton extends StatelessWidget {
  const NotesToolbarButton({
    super.key,
    required this.tool,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.enabled = true,
  });

  final NotesToolbarTool tool;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? scheme.onInverseSurface
        : enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.35);
    final background = selected ? scheme.inverseSurface : Colors.transparent;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        label: tooltip,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: ValueKey('notes-toolbar-${tool.name}'),
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
              dimension: kNotesToolbarButtonSize,
              child: Icon(icon, size: 22, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

class NotesEditorToolbar extends StatelessWidget {
  const NotesEditorToolbar({super.key, required this.actions});

  final List<NotesToolbarAction> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.96),
      elevation: 6,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                if (index > 0) const SizedBox(width: 4),
                NotesToolbarButton(
                  tool: actions[index].tool,
                  icon: actions[index].icon,
                  tooltip: actions[index].tooltip,
                  onPressed: actions[index].onPressed,
                  selected: actions[index].selected,
                  enabled: actions[index].enabled,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class NotesFloatingMenuSurface extends StatelessWidget {
  const NotesFloatingMenuSurface({
    super.key,
    required this.child,
    this.maxWidth = 320,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: scheme.surface,
        elevation: 10,
        shadowColor: scheme.shadow.withValues(alpha: 0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kNotesMenuRadius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

class NotesHeadingStylesMenu extends StatelessWidget {
  const NotesHeadingStylesMenu({
    super.key,
    required this.onSelected,
    this.selected,
  });

  final ValueChanged<NotesTextBlockStyle> onSelected;
  final NotesTextBlockStyle? selected;

  @override
  Widget build(BuildContext context) {
    return NotesFloatingMenuSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final style in NotesTextBlockStyle.values)
            _NotesMenuRow(
              label: switch (style) {
                NotesTextBlockStyle.body => 'Body',
                NotesTextBlockStyle.h1 => 'Heading 1',
                NotesTextBlockStyle.h2 => 'Heading 2',
                NotesTextBlockStyle.h3 => 'Heading 3',
              },
              previewStyle: _notesTextStyle(context, style),
              selected: selected == style,
              onTap: () => onSelected(style),
            ),
        ],
      ),
    );
  }
}

class NotesTextFormattingMenu extends StatelessWidget {
  const NotesTextFormattingMenu({
    super.key,
    required this.onSelected,
    this.selected = const <NotesInlineFormat>{},
  });

  final ValueChanged<NotesInlineFormat> onSelected;
  final Set<NotesInlineFormat> selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NotesFloatingMenuSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final format in NotesInlineFormat.values)
            _NotesMenuRow(
              label: switch (format) {
                NotesInlineFormat.bold => 'Bold',
                NotesInlineFormat.italic => 'Italic',
                NotesInlineFormat.underline => 'Underline',
                NotesInlineFormat.strike => 'Strikethrough',
                NotesInlineFormat.highlight => 'Highlight',
                NotesInlineFormat.link => 'Link',
              },
              previewStyle: TextStyle(
                fontSize: 16,
                fontWeight: format == NotesInlineFormat.bold
                    ? FontWeight.w700
                    : FontWeight.w400,
                fontStyle: format == NotesInlineFormat.italic
                    ? FontStyle.italic
                    : FontStyle.normal,
                decoration: switch (format) {
                  NotesInlineFormat.underline => TextDecoration.underline,
                  NotesInlineFormat.strike => TextDecoration.lineThrough,
                  NotesInlineFormat.link => TextDecoration.underline,
                  _ => TextDecoration.none,
                },
                color: format == NotesInlineFormat.link
                    ? scheme.primary
                    : scheme.onSurface,
                backgroundColor: format == NotesInlineFormat.highlight
                    ? scheme.tertiaryContainer
                    : null,
              ),
              selected: selected.contains(format),
              onTap: () => onSelected(format),
            ),
        ],
      ),
    );
  }
}

class NotesInsertMenuAction {
  const NotesInsertMenuAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

class NotesInsertMenu extends StatelessWidget {
  const NotesInsertMenu({super.key, required this.actions});

  final List<NotesInsertMenuAction> actions;

  @override
  Widget build(BuildContext context) {
    return NotesFloatingMenuSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(action.icon, size: 20),
              title: Text(action.label),
              onTap: action.onPressed,
            ),
        ],
      ),
    );
  }
}

class _NotesMenuRow extends StatelessWidget {
  const _NotesMenuRow({
    required this.label,
    required this.previewStyle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final TextStyle previewStyle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Expanded(child: Text(label, style: previewStyle)),
              if (selected)
                Icon(Icons.check_rounded, size: 18, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
