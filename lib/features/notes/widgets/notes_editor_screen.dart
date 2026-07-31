import 'package:counter/features/notes/notes_figma_tokens.dart';
import 'package:flutter/material.dart';

class NotesEditorMetadataTag {
  const NotesEditorMetadataTag({required this.label, this.color});

  final String label;
  final Color? color;
}

/// Shared production shell for the Figma Notes editor.
///
/// The always-visible editor chrome intentionally avoids BackdropFilter. Large
/// blur surfaces made scrolling and typing expensive on web and lower-end
/// Android devices. Layering is expressed through opaque semantic surfaces,
/// token borders, shadows, and repaint boundaries instead.
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
    return Scaffold(
      backgroundColor: NotesFigmaTokens.canvas(context),
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 768;
          final horizontalRoom =
              constraints.maxWidth -
              (desktop ? NotesFigmaTokens.editorDesktopOuterInset * 2 : 0);
          final verticalRoom =
              constraints.maxHeight -
              (desktop ? NotesFigmaTokens.editorDesktopOuterInset * 2 : 0);
          final frameWidth = desktop
              ? horizontalRoom
                    .clamp(0.0, NotesFigmaTokens.editorSurfaceMaxWidth)
                    .toDouble()
              : constraints.maxWidth;
          final frameHeight = desktop
              ? verticalRoom.clamp(0.0, 920.0).toDouble()
              : constraints.maxHeight;

          return ColoredBox(
            color: NotesFigmaTokens.canvas(context),
            child: Center(
              child: SizedBox(
                width: frameWidth,
                height: frameHeight,
                child: _NotesEditorSurface(
                  desktop: desktop,
                  child: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, editorConstraints) {
                        final contentWidth = editorConstraints.maxWidth
                            .clamp(0.0, NotesFigmaTokens.editorContentMaxWidth)
                            .toDouble();
                        return Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: contentWidth,
                            height: editorConstraints.maxHeight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _NotesNavigationHeader(
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
                                ),
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Positioned.fill(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            bottom:
                                                NotesFigmaTokens.toolbarHeight +
                                                24,
                                          ),
                                          child: content,
                                        ),
                                      ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 8,
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
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotesEditorSurface extends StatelessWidget {
  const _NotesEditorSurface({required this.desktop, required this.child});

  final bool desktop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!desktop) {
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
    required this.onDone,
    required this.pinned,
    required this.onTogglePinned,
    required this.onDelete,
  });

  final VoidCallback onDone;
  final bool pinned;
  final VoidCallback onTogglePinned;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _NotesBackAction(onPressed: onDone),
          const Spacer(),
          _NotesHeaderAction(
            icon: pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            tooltip: pinned ? 'Unpin note' : 'Pin note',
            selected: pinned,
            onPressed: onTogglePinned,
          ),
          const SizedBox(width: 8),
          _NotesHeaderAction(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete note',
            onPressed: onDelete,
          ),
        ],
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
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? NotesFigmaTokens.textPrimary(context)
        : NotesFigmaTokens.iconSecondary(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: NotesFigmaTokens.glassFill(context),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 40,
            child: Icon(icon, size: 16, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _NotesTitleBlock extends StatelessWidget {
  const _NotesTitleBlock({
    required this.controller,
    required this.onChanged,
    required this.categoryLabel,
    required this.categoryColor,
    required this.tags,
    this.hintText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? categoryLabel;
  final Color? categoryColor;
  final List<NotesEditorMetadataTag> tags;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('notes-editor-title'),
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            minLines: 1,
            maxLines: null,
            onChanged: onChanged,
            style: TextStyle(
              fontSize: NotesFigmaTokens.titleSize,
              height:
                  NotesFigmaTokens.titleLineHeight / NotesFigmaTokens.titleSize,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: NotesFigmaTokens.textPrimary(context),
            ),
            decoration: InputDecoration(
              hintText: hintText,
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
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          _NotesMetadataRow(
            categoryLabel: categoryLabel,
            categoryColor: categoryColor,
            tags: tags,
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
