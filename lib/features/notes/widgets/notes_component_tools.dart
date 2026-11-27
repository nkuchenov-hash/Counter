part of 'notes_canonical_components.dart';

class NotesToolbarMenuItem {
  const NotesToolbarMenuItem({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;
}

class NotesToolbarAction {
  const NotesToolbarAction({
    required this.tool,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.enabled = true,
    this.menuItems = const <NotesToolbarMenuItem>[],
  });

  final NotesToolbarTool tool;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;
  final bool enabled;
  final List<NotesToolbarMenuItem> menuItems;
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
    final native = NotesFigmaTokens.nativeNotesLayout(context);
    final buttonSize = native
        ? NotesFigmaTokens.nativeToolbarButtonSize
        : NotesFigmaTokens.toolbarButtonSize;
    final foreground = selected
        ? NotesFigmaTokens.selectedIcon(context)
        : enabled
        ? NotesFigmaTokens.iconSecondary(context)
        : NotesFigmaTokens.iconSecondary(context).withValues(alpha: 0.35);
    final background = selected
        ? NotesFigmaTokens.selectedSurface(context)
        : Colors.transparent;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        label: tooltip,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(
            NotesFigmaTokens.toolbarButtonRadius,
          ),
          child: InkWell(
            key: ValueKey('notes-toolbar-${tool.name}'),
            onTap: enabled ? onPressed : null,
            hoverColor: NotesFigmaTokens.textPrimary(context).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(
              NotesFigmaTokens.toolbarButtonRadius,
            ),
            child: SizedBox.square(
              dimension: buttonSize,
              child: Icon(
                icon,
                size: native
                    ? NotesFigmaTokens.nativeToolbarIconSize
                    : NotesFigmaTokens.toolbarIconSize,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesToolbarMenuButton extends StatefulWidget {
  const _NotesToolbarMenuButton({required this.action});

  final NotesToolbarAction action;

  @override
  State<_NotesToolbarMenuButton> createState() =>
      _NotesToolbarMenuButtonState();
}

class _NotesToolbarMenuButtonState extends State<_NotesToolbarMenuButton> {
  static const _hoverCloseDelay = Duration(milliseconds: 140);
  static const _menuGap = 4.0;

  final GlobalKey _buttonKey = GlobalKey();
  final Object _tapRegionGroup = Object();
  OverlayEntry? _overlayEntry;
  bool _pointerOverTrigger = false;
  bool _pointerOverMenu = false;
  int _closeTicket = 0;

  void _showMenu() {
    if (!widget.action.enabled || _overlayEntry != null) return;

    final buttonRenderObject =
        _buttonKey.currentContext?.findRenderObject();
    final overlay = Overlay.of(context);
    final overlayRenderObject = overlay.context.findRenderObject();
    if (buttonRenderObject is! RenderBox ||
        overlayRenderObject is! RenderBox) {
      return;
    }

    final buttonTopLeft = overlayRenderObject.globalToLocal(
      buttonRenderObject.localToGlobal(Offset.zero),
    );
    final menuButtonSize = NotesFigmaTokens.nativeNotesLayout(context)
        ? NotesFigmaTokens.nativeToolbarButtonSize
        : kNotesToolbarButtonSize;
    final menuHeight = widget.action.menuItems.length * menuButtonSize;
    final maxLeft = math.max(
      0.0,
      overlayRenderObject.size.width - menuButtonSize,
    );
    final left = buttonTopLeft.dx.clamp(0.0, maxLeft).toDouble();
    final top = math.max(
      MediaQuery.paddingOf(context).top + _menuGap,
      buttonTopLeft.dy - _menuGap - menuHeight,
    );

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: top,
        width: menuButtonSize,
        height: menuHeight,
        child: TapRegion(
          groupId: _tapRegionGroup,
          child: MouseRegion(
            onEnter: (_) {
              _pointerOverMenu = true;
              _cancelScheduledClose();
            },
            onExit: (_) {
              _pointerOverMenu = false;
              _scheduleClose();
            },
            child: _NotesCompactToolbarMenu(
              items: widget.action.menuItems,
              onSelected: _selectItem,
            ),
          ),
        ),
      ),
    );
    _overlayEntry = entry;
    overlay.insert(entry);
  }

  void _toggleMenu() {
    if (_overlayEntry == null) {
      _showMenu();
    } else {
      _hideMenu();
    }
  }

  void _selectItem(NotesToolbarMenuItem item) {
    _hideMenu();
    item.onPressed();
  }

  void _hideMenu() {
    _cancelScheduledClose();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _pointerOverMenu = false;
  }

  void _cancelScheduledClose() {
    _closeTicket++;
  }

  void _scheduleClose() {
    final ticket = ++_closeTicket;
    Future<void>.delayed(_hoverCloseDelay, () {
      if (!mounted ||
          ticket != _closeTicket ||
          _pointerOverTrigger ||
          _pointerOverMenu) {
        return;
      }
      _hideMenu();
    });
  }

  @override
  void didUpdateWidget(covariant _NotesToolbarMenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.action.enabled && _overlayEntry != null) _hideMenu();
  }

  @override
  void dispose() {
    _closeTicket++;
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _tapRegionGroup,
      onTapOutside: (_) => _hideMenu(),
      child: MouseRegion(
        onEnter: (_) {
          _pointerOverTrigger = true;
          _cancelScheduledClose();
          _showMenu();
        },
        onExit: (_) {
          _pointerOverTrigger = false;
          _scheduleClose();
        },
        child: NotesToolbarButton(
          key: _buttonKey,
          tool: widget.action.tool,
          icon: widget.action.icon,
          tooltip: widget.action.tooltip,
          onPressed: _toggleMenu,
          selected: widget.action.selected,
          enabled: widget.action.enabled,
        ),
      ),
    );
  }
}

class _NotesCompactToolbarMenu extends StatelessWidget {
  const _NotesCompactToolbarMenu({
    required this.items,
    required this.onSelected,
  });

  final List<NotesToolbarMenuItem> items;
  final ValueChanged<NotesToolbarMenuItem> onSelected;

  @override
  Widget build(BuildContext context) {
    final menuButtonSize = NotesFigmaTokens.nativeNotesLayout(context)
        ? NotesFigmaTokens.nativeToolbarButtonSize
        : kNotesToolbarButtonSize;
    return SizedBox(
      width: menuButtonSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            NotesFigmaTokens.toolbarButtonRadius,
          ),
          boxShadow: [NotesFigmaTokens.floatingMenuShadow],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            NotesFigmaTokens.toolbarButtonRadius,
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: NotesFigmaTokens.floatingMenuBlur,
              sigmaY: NotesFigmaTokens.floatingMenuBlur,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: NotesFigmaTokens.glassFill(context),
                border: Border.all(
                  color: NotesFigmaTokens.glassStroke(context),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in items)
                    Tooltip(
                      message: item.tooltip,
                      child: Semantics(
                        button: true,
                        selected: item.selected,
                        label: item.tooltip,
                        child: Material(
                          color: item.selected
                              ? NotesFigmaTokens.selectedSurface(context)
                              : Colors.transparent,
                          child: InkWell(
                            key: ValueKey(
                              'notes-list-menu-${item.tooltip}',
                            ),
                            onTap: () => onSelected(item),
                            child: SizedBox.square(
                              dimension: menuButtonSize,
                              child: Icon(
                                item.icon,
                                size: NotesFigmaTokens.toolbarIconSize,
                                color: item.selected
                                    ? NotesFigmaTokens.selectedIcon(context)
                                    : NotesFigmaTokens.iconSecondary(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact floating Notes formatting pill (Figma 604:8938).
///
/// The bottom-edge blur belongs to NotesBottomGlassFade, not this component.
/// This capsule alone supplies the translucent contrast needed to keep icons
/// legible when document text scrolls underneath.
class NotesEditorToolbar extends StatelessWidget {
  const NotesEditorToolbar({super.key, required this.actions});

  final List<NotesToolbarAction> actions;

  @override
  Widget build(BuildContext context) {
    // The Android IME animates height; toolbar geometry only needs width.
    final viewportWidth = MediaQuery.widthOf(context);
    final width = math.min(
      NotesFigmaTokens.toolbarWidth,
      math.max(0.0, viewportWidth - 40),
    );
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final native = NotesFigmaTokens.nativeNotesLayout(context);
    final radius = BorderRadius.circular(
      native
          ? NotesFigmaTokens.nativeToolbarRadius
          : NotesFigmaTokens.toolbarRadius,
    );

    return SizedBox(
      key: const ValueKey('notes-floating-glass-toolbar'),
      width: width,
      height: native
          ? NotesFigmaTokens.nativeToolbarHeight
          : NotesFigmaTokens.toolbarHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.22 : 0.11),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            // A stationary, opaque Android dock avoids expensive background
            // sampling whenever the IME paints or the document scrolls.
            enabled: !native,
            filter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
            child: DecoratedBox(
              key: const ValueKey('notes-floating-glass-pill'),
              decoration: BoxDecoration(
                // True glass: the document is visible through a lightly
                // tinted material, not hidden under two near-opaque whites.
                // The footer fade has a pill-sized aperture behind this glass
                // so the local BackdropFilter samples real scrolling content.
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: native
                      ? [
                          scheme.surfaceContainerHigh.withValues(alpha: 0.96),
                          scheme.surfaceContainerHigh.withValues(alpha: 0.94),
                        ]
                      : dark
                          ? [
                              AppColors.editorGlassDarkTop.withValues(alpha: 0.65),
                              AppColors.editorGlassDarkBottom.withValues(alpha: 0.53),
                            ]
                          : [
                              AppNeutralTones.white.withValues(alpha: 0.70),
                              AppNeutralTones.white.withValues(alpha: 0.56),
                            ],
                ),
                borderRadius: radius,
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.24)
                      : scheme.outlineVariant.withValues(alpha: 0.23),
                  width: 0.8,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = native || constraints.maxWidth < actions.length * NotesFigmaTokens.toolbarButtonSize + 2 * NotesFigmaTokens.toolbarHorizontalPadding;
                  final row = Row(
                    mainAxisSize: compact
                        ? MainAxisSize.min
                        : MainAxisSize.max,
                    mainAxisAlignment: compact
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.spaceBetween,
                    children: [
                      for (final action in actions)
                        if (action.menuItems.isEmpty)
                          NotesToolbarButton(
                            tool: action.tool,
                            icon: action.icon,
                            tooltip: action.tooltip,
                            onPressed: action.onPressed,
                            selected: action.selected,
                            enabled: action.enabled,
                          )
                        else
                          _NotesToolbarMenuButton(action: action),
                    ],
                  );
                  final padded = Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: native
                          ? 10
                          : NotesFigmaTokens.toolbarHorizontalPadding,
                      vertical: native
                          ? 5
                          : NotesFigmaTokens.toolbarVerticalPadding,
                    ),
                    child: row,
                  );
                  return compact
                      ? SingleChildScrollView(
                          key: const ValueKey('notes-native-toolbar-scroll'),
                          scrollDirection: Axis.horizontal,
                          physics: native ? const BouncingScrollPhysics() : null,
                          child: padded,
                        )
                      : padded;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma `Menus/Floating Options Sheet` glass surface.
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
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kNotesMenuRadius),
          boxShadow: [NotesFigmaTokens.floatingMenuShadow],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kNotesMenuRadius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: NotesFigmaTokens.floatingMenuBlur,
              sigmaY: NotesFigmaTokens.floatingMenuBlur,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: NotesFigmaTokens.glassFill(context),
                borderRadius: BorderRadius.circular(kNotesMenuRadius),
                border: Border.all(
                  color: NotesFigmaTokens.glassStroke(context),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ),
        ),
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
                    : NotesFigmaTokens.textPrimary(context),
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
              leading: Icon(
                action.icon,
                size: 20,
                color: NotesFigmaTokens.iconSecondary(context),
              ),
              title: Text(
                action.label,
                style: TextStyle(
                  color: NotesFigmaTokens.textPrimary(context),
                ),
              ),
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
    final selectedColor = NotesFigmaTokens.selectedSurface(context);
    return Material(
      color: selected ? selectedColor.withValues(alpha: 0.08) : Colors.transparent,
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
                Icon(Icons.check_rounded, size: 18, color: selectedColor),
            ],
          ),
        ),
      ),
    );
  }
}