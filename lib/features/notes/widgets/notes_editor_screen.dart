import 'package:counter/features/notes/notes_figma_tokens.dart';
import 'package:flutter/material.dart';

class NotesEditorMetadataTag {
  const NotesEditorMetadataTag({required this.label, this.color});

  final String label;
  final Color? color;
}

/// Marks a Notes editor as part of the desktop master-detail workspace.
///
/// In this mode the editor must not create another application-like canvas,
/// card, safe area, or mobile navigation label. The surrounding Lists page
/// already owns the workspace and supplies the close action.
class NotesEmbeddedEditorScope extends InheritedWidget {
  const NotesEmbeddedEditorScope({
    super.key,
    required this.onClose,
    required super.child,
  });

  final VoidCallback onClose;

  static NotesEmbeddedEditorScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NotesEmbeddedEditorScope>();
  }

  @override
  bool updateShouldNotify(NotesEmbeddedEditorScope oldWidget) {
    return oldWidget.onClose != onClose;
  }
}

/// Shared production shell for the Figma Notes editor.
///
/// Mobile uses the dedicated full-screen surface. Wide web and desktop can use
/// the same editor inside [NotesEmbeddedEditorScope], where it becomes a plain
/// workspace column with an 880 px content rail and no nested modal chrome.
class NotesEditorScreen extends StatelessWidget {
  const NotesEditorScreen({
    super.key,
    required this.titleController,
    required this.onTitleChanged,
    required this.onDone,
    required this.pinned,
    required this.onTogglePinned,
    required this.onDelete,
    required this.content,
    required this.toolbar,
    this.categoryLabel,
    this.categoryColor,
    this.tags = const <NotesEditorMetadataTag>[],
    this.titleHint,
  });

  final TextEditingController titleController;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onDone;
  final bool pinned;
  final VoidCallback onTogglePinned;
  final VoidCallback onDelete;
  final Widget content;
  final Widget toolbar;
  final String? categoryLabel;
  final Color? categoryColor;
  final List<NotesEditorMetadataTag> tags;
  final String? titleHint;

  @override
  Widget build(BuildContext context) {
    final embeddedScope = NotesEmbeddedEditorScope.maybeOf(context);
    final embedded = embeddedScope != null;
    final editor = LayoutBuilder(
      builder: (context, constraints) {
        final desktop = embedded || constraints.maxWidth >= 768;
        final frameWidth = embedded
            ? constraints.maxWidth
            : (constraints.maxWidth -
                      (desktop
                          ? NotesFigmaTokens.editorDesktopOuterInset * 2
                          : 0))
                  .clamp(0.0, NotesFigmaTokens.editorSurfaceMaxWidth)
                  .toDouble();
        final frameHeight = embedded
            ? constraints.maxHeight
            : (constraints.maxHeight -
                      (desktop
                          ? NotesFigmaTokens.editorDesktopOuterInset * 2
                          : 0))
                  .clamp(0.0, 920.0)
                  .toDouble();

        final frame = SizedBox(
          width: frameWidth,
          height: frameHeight,
          child: _NotesEditorSurface(
            desktop: desktop,
            embedded: embedded,
            child: _NotesEditorRail(
              embedded: embedded,
              onDone: embeddedScope?.onClose ?? onDone,
              pinned: pinned,
              onTogglePinned: onTogglePinned,
              onDelete: onDelete,
              titleController: titleController,
              onTitleChanged: onTitleChanged,
              categoryLabel: categoryLabel,
              categoryColor: categoryColor,
              tags: tags,
              titleHint: titleHint,
              content: content,
              toolbar: toolbar,
            ),
          ),
        );

        if (embedded) return frame;
        return ColoredBox(
          color: NotesFigmaTokens.canvas(context),
          child: Center(child: frame),
        );
      },
    );

    if (embedded) {
      return Material(
        color: NotesFigmaTokens.surfaceCard(context),
        child: editor,
      );
    }
    return Scaffold(
      backgroundColor: NotesFigmaTokens.canvas(context),
      resizeToAvoidBottomInset: true,
      body: editor,
    );
  }
}

class _NotesEditorRail extends StatelessWidget {
  const _NotesEditorRail({
    required this.embedded,
    required this.onDone,
    required this.pinned,
    required this.onTogglePinned,
    required this.onDelete,
    required this.titleController,
    required this.onTitleChanged,
    required this.categoryLabel,
    required this.categoryColor,
    required this.tags,
    required this.titleHint,
    required this.content,
    required this.toolbar,
  });

  final bool embedded;
  final VoidCallback onDone;
  final bool pinned;
  final VoidCallback onTogglePinned;
  final VoidCallback? onDelete;
  final TextEditingController titleController;
  final ValueChanged<String> onTitleChanged;
  final String? categoryLabel;
  final Color? categoryColor;
  final List<NotesEditorMetadataTag> tags;
  final String? titleHint;
  final Widget content;
  final Widget toolbar;

  @override
  Widget build(BuildContext context) {
    Widget rail = LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = embedded
            ? (constraints.maxWidth >= NotesFigmaTokens.editorSurfaceMaxWidth
                  ? 40.0
                  : 24.0)
            : 0.0;
        final contentWidth = (constraints.maxWidth - horizontalPadding * 2)
            .clamp(0.0, NotesFigmaTokens.editorContentMaxWidth)
            .toDouble();
        final collapseTitleForKeyboard =
            !embedded &&
            constraints.maxWidth < 768 &&
            constraints.maxHeight < 600 &&
            FocusManager.instance.primaryFocus != null;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            key: const ValueKey('notes-editor-content-rail'),
            width: contentWidth,
            height: constraints.maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NotesNavigationHeader(
                  embedded: embedded,
                  onDone: onDone,
                  pinned: pinned,
                  onTogglePinned: onTogglePinned,
                  onDelete: onDelete,
                ),
                _NotesTitleBlock(
                  controller: titleController,
                  onChanged: onTitleChanged,
                  categoryLabel: categoryLabel,
                  categoryColor: categoryColor,
                  tags: tags,
                  hintText: titleHint,
                  collapseForKeyboard: collapseTitleForKeyboard,
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            bottom: NotesFigmaTokens.toolbarHeight + 28,
                          ),
                          child: content,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: embedded ? 14 : 8,
                        child: RepaintBoundary(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: toolbar,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!embedded) rail = SafeArea(child: rail);
    return rail;
  }
}

class _NotesEditorSurface extends StatelessWidget {
  const _NotesEditorSurface({
    required this.desktop,
    required this.embedded,
    required this.child,
  });

  final bool desktop;
  final bool embedded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (embedded || !desktop) {
      return ColoredBox(
        color: NotesFigmaTokens.surfaceCard(context),
        child: child,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: NotesFigmaTokens.surfaceCard(context),
        borderRadius: BorderRadius.circular(
          NotesFigmaTokens.editorSurfaceRadius,
        ),
        border: Border.all(color: NotesFigmaTokens.glassStroke(context)),
        boxShadow: [NotesFigmaTokens.editorShadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          NotesFigmaTokens.editorSurfaceRadius,
        ),
        child: ColoredBox(
          color: NotesFigmaTokens.surfaceCard(context),
          child: child,
        ),
      ),
    );
  }
}

class _NotesNavigationHeader extends StatelessWidget {
  const _NotesNavigationHeader({
    required this.embedded,
    required this.onDone,
    required this.pinned,
    required this.onTogglePinned,
    required this.onDelete,
  });

  final bool embedded;
  final VoidCallback onDone;
  final bool pinned;
  final VoidCallback onTogglePinned;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
_NotesHeaderAction(
  icon: Icons.arrow_back_rounded,
  tooltip: 'Back',
  onPressed: onDone,
),
const Spacer(),
_NotesHeaderMoreMenu(
  pinned: pinned,
  onTogglePinned: onTogglePinned,
  onDelete: onDelete,
),
        ],
      ),
    );
  }
}

enum _NotesHeaderMenuAction { pin, delete }

class _NotesHeaderMoreMenu extends StatelessWidget {
  const _NotesHeaderMoreMenu({
    required this.pinned,
    required this.onTogglePinned,
    required this.onDelete,
  });

  final bool pinned;
  final VoidCallback onTogglePinned;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_NotesHeaderMenuAction>(
      tooltip: 'More',
      position: PopupMenuPosition.under,
      onSelected: (action) {
        switch (action) {
case _NotesHeaderMenuAction.pin:
  onTogglePinned();
case _NotesHeaderMenuAction.delete:
  onDelete?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_NotesHeaderMenuAction>(
value: _NotesHeaderMenuAction.pin,
child: Row(
  children: [
    Icon(pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded),
    const SizedBox(width: 10),
    Text(pinned ? 'Unpin' : 'Pin'),
  ],
),
        ),
        if (onDelete != null)
PopupMenuItem<_NotesHeaderMenuAction>(
  value: _NotesHeaderMenuAction.delete,
  child: Row(
    children: [
      Icon(
        Icons.delete_outline_rounded,
        color: Theme.of(context).colorScheme.error,
      ),
      const SizedBox(width: 10),
      Text(
        'Delete',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ],
  ),
),
      ],
      child: Material(
        color: NotesFigmaTokens.glassFill(context),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        child: SizedBox.square(
dimension: 40,
child: Icon(
  Icons.more_horiz_rounded,
  size: 19,
  color: NotesFigmaTokens.iconSecondary(context),
),
        ),
      ),
    );
  }
}

class _NotesBackAction extends StatelessWidget {
  const _NotesBackAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: NotesFigmaTokens.iconSecondary(context),
              ),
              const SizedBox(width: 6),
              Text(
                'Done',
                style: TextStyle(
                  fontSize: 16,
                  color: NotesFigmaTokens.iconSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesHeaderAction extends StatelessWidget {
  const _NotesHeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.subtle = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? NotesFigmaTokens.textPrimary(context)
        : NotesFigmaTokens.iconSecondary(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: subtle
            ? Colors.transparent
            : NotesFigmaTokens.glassFill(context),
        elevation: subtle ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 40,
            child: Icon(icon, size: 17, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _NotesTitleBlock extends StatefulWidget {
  const _NotesTitleBlock({
    required this.controller,
    required this.onChanged,
    required this.categoryLabel,
    required this.categoryColor,
    required this.tags,
    required this.collapseForKeyboard,
    this.hintText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? categoryLabel;
  final Color? categoryColor;
  final List<NotesEditorMetadataTag> tags;
  final bool collapseForKeyboard;
  final String? hintText;

  @override
  State<_NotesTitleBlock> createState() => _NotesTitleBlockState();
}

class _NotesTitleBlockState extends State<_NotesTitleBlock> {
  final FocusNode _titleFocusNode = FocusNode(debugLabel: 'notes-title');

  @override
  void initState() {
    super.initState();
    _titleFocusNode.addListener(_onTitleFocusChanged);
  }

  @override
  void dispose() {
    _titleFocusNode
      ..removeListener(_onTitleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onTitleFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.collapseForKeyboard && !_titleFocusNode.hasFocus) {
      return const SizedBox(
        key: ValueKey('notes-editor-title-collapsed-for-keyboard'),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('notes-editor-title'),
            controller: widget.controller,
            focusNode: _titleFocusNode,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            minLines: 1,
            maxLines: null,
            scrollPadding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              NotesFigmaTokens.toolbarHeight + 48,
            ),
            onChanged: widget.onChanged,
            style: TextStyle(
              fontSize: NotesFigmaTokens.titleSize,
              height:
                  NotesFigmaTokens.titleLineHeight / NotesFigmaTokens.titleSize,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: NotesFigmaTokens.textPrimary(context),
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                fontSize: NotesFigmaTokens.titleSize,
                height:
                    NotesFigmaTokens.titleLineHeight /
                    NotesFigmaTokens.titleSize,
                fontWeight: FontWeight.w700,
                color: NotesFigmaTokens.textSecondary(
                  context,
                ).withValues(alpha: 0.55),
              ),
              filled: false,
              fillColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          _NotesMetadataRow(
            categoryLabel: widget.categoryLabel,
            categoryColor: widget.categoryColor,
            tags: widget.tags,
          ),
        ],
      ),
    );
  }
}

class _NotesMetadataRow extends StatelessWidget {
  const _NotesMetadataRow({
    required this.categoryLabel,
    required this.categoryColor,
    required this.tags,
  });

  final String? categoryLabel;
  final Color? categoryColor;
  final List<NotesEditorMetadataTag> tags;

  @override
  Widget build(BuildContext context) {
    final label = categoryLabel?.trim() ?? '';
    return SizedBox(
      height: 21,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: (label.isNotEmpty ? 1 : 0) + tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (label.isNotEmpty && index == 0) {
            return _NotesMetadataBadge(
              label: label,
              color: categoryColor ?? Theme.of(context).colorScheme.primary,
            );
          }
          final tagIndex = label.isNotEmpty ? index - 1 : index;
          final tag = tags[tagIndex];
          return _NotesMetadataBadge(
            label: tag.label,
            color: tag.color ?? Theme.of(context).colorScheme.primary,
          );
        },
      ),
    );
  }
}

class _NotesMetadataBadge extends StatelessWidget {
  const _NotesMetadataBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: NotesFigmaTokens.badgeSize,
            height:
                NotesFigmaTokens.badgeLineHeight / NotesFigmaTokens.badgeSize,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
