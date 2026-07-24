import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/features/notes/notes_visual_tokens.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Structured request emitted by the Insert panel. The editor page remains the
/// single owner of NoteDocument state and autosave.
class NotesInsertRequest {
  const NotesInsertRequest({
    required this.type,
    this.table,
    this.callout,
    this.linkData,
    this.codeLanguage,
  });

  final NoteBlockType type;
  final NoteTableData? table;
  final NoteCalloutData? callout;
  final NoteLinkData? linkData;
  final String? codeLanguage;
}

enum NotesToolsPanel { none, format, insert, more }

/// The primary editor toolbar plus its contextual Aa / Insert panels.
///
/// This intentionally keeps Link out of the first level. Inline links live in
/// Aa; link cards live in Insert.
class NotesEditorToolsDock extends StatefulWidget {
  const NotesEditorToolsDock({
    super.key,
    required this.activeBlock,
    required this.loc,
    required this.onToggleChecklist,
    required this.onHeading,
    required this.onSetBlockType,
    required this.onToggleFormat,
    required this.onSetColor,
    required this.onInsert,
    required this.onImage,
    required this.onDraw,
    this.onUndo,
    this.onRedo,
  });

  final NoteBlock? activeBlock;
  final String loc;
  final VoidCallback onToggleChecklist;
  final ValueChanged<int> onHeading;
  final ValueChanged<NoteBlockType> onSetBlockType;
  final ValueChanged<String> onToggleFormat;
  final ValueChanged<String?> onSetColor;
  final ValueChanged<NotesInsertRequest> onInsert;
  final VoidCallback onImage;
  final VoidCallback onDraw;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;

  @override
  State<NotesEditorToolsDock> createState() => _NotesEditorToolsDockState();
}

class _NotesEditorToolsDockState extends State<NotesEditorToolsDock> {
  NotesToolsPanel _panel = NotesToolsPanel.none;

  void _toggle(NotesToolsPanel panel) {
    setState(() => _panel = _panel == panel ? NotesToolsPanel.none : panel);
  }

  void _closePanel() {
    if (_panel != NotesToolsPanel.none) {
      setState(() => _panel = NotesToolsPanel.none);
    }
  }

  Future<void> _insertTable() async {
    final table = await showDialog<NoteTableData>(
      context: context,
      builder: (context) => const _NotesTableSizeDialog(),
    );
    if (table == null) return;
    widget.onInsert(
      NotesInsertRequest(type: NoteBlockType.table, table: table),
    );
    _closePanel();
  }

  Future<void> _insertLinkCard() async {
    final link = await showDialog<NoteLinkData>(
      context: context,
      builder: (context) => _NotesLinkDialog(loc: widget.loc),
    );
    if (link == null) return;
    widget.onInsert(
      NotesInsertRequest(type: NoteBlockType.linkCard, linkData: link),
    );
    _closePanel();
  }

  void _insert(NoteBlockType type) {
    widget.onInsert(NotesInsertRequest(type: type));
    _closePanel();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: switch (_panel) {
              NotesToolsPanel.format => _NotesFormatPanel(
                key: const ValueKey('format'),
                activeBlock: widget.activeBlock,
                loc: widget.loc,
                onHeading: widget.onHeading,
                onSetBlockType: widget.onSetBlockType,
                onToggleFormat: widget.onToggleFormat,
                onSetColor: widget.onSetColor,
              ),
              NotesToolsPanel.insert => _NotesInsertPanel(
                key: const ValueKey('insert'),
                loc: widget.loc,
                onText: () => _insert(NoteBlockType.paragraph),
                onChecklist: () => _insert(NoteBlockType.checklist),
                onBullets: () => _insert(NoteBlockType.bulletedList),
                onNumbers: () => _insert(NoteBlockType.numberedList),
                onQuote: () => _insert(NoteBlockType.quote),
                onCallout: () {
                  widget.onInsert(
                    const NotesInsertRequest(
                      type: NoteBlockType.callout,
                      callout: NoteCalloutData(type: NoteCalloutType.idea),
                    ),
                  );
                  _closePanel();
                },
                onDivider: () => _insert(NoteBlockType.divider),
                onCode: () {
                  widget.onInsert(
                    const NotesInsertRequest(
                      type: NoteBlockType.codeBlock,
                      codeLanguage: 'plain',
                    ),
                  );
                  _closePanel();
                },
                onCollapsible: () => _insert(NoteBlockType.collapsible),
                onTable: _insertTable,
                onImage: () {
                  widget.onImage();
                  _closePanel();
                },
                onDraw: () {
                  widget.onDraw();
                  _closePanel();
                },
                onLink: _insertLinkCard,
              ),
              NotesToolsPanel.more => _NotesMorePanel(
                key: const ValueKey('more'),
                loc: widget.loc,
                onClose: _closePanel,
              ),
              NotesToolsPanel.none => const SizedBox.shrink(
                key: ValueKey('none'),
              ),
            },
          ),
          Container(
            height: kGlmToolbarHeight,
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.94),
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.72),
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _PrimaryToolButton(
                    icon: Icons.undo_rounded,
                    tooltip: t(widget.loc, 'undo'),
                    onTap: widget.onUndo,
                  ),
                  _PrimaryToolButton(
                    icon: Icons.redo_rounded,
                    tooltip: t(widget.loc, 'notes_tools_redo'),
                    onTap: widget.onRedo,
                  ),
                  const _ToolsDivider(),
                  _PrimaryToolButton(
                    text: 'Aa',
                    tooltip: t(widget.loc, 'notes_tools_format'),
                    selected: _panel == NotesToolsPanel.format,
                    onTap: () => _toggle(NotesToolsPanel.format),
                  ),
                  _PrimaryToolButton(
                    icon: Icons.checklist_rounded,
                    tooltip: t(widget.loc, 'notes_v3_editor_checklist_toggle'),
                    selected:
                        widget.activeBlock?.type == NoteBlockType.checklist,
                    onTap: widget.onToggleChecklist,
                  ),
                  _PrimaryToolButton(
                    icon: Icons.format_list_bulleted_rounded,
                    tooltip: t(widget.loc, 'notes_tools_lists'),
                    selected:
                        widget.activeBlock?.type ==
                            NoteBlockType.bulletedList ||
                        widget.activeBlock?.type == NoteBlockType.numberedList,
                    onTap: () => _toggle(NotesToolsPanel.format),
                  ),
                  const _ToolsDivider(),
                  _PrimaryToolButton(
                    icon: Icons.add_rounded,
                    tooltip: t(widget.loc, 'notes_tools_insert'),
                    selected: _panel == NotesToolsPanel.insert,
                    onTap: () => _toggle(NotesToolsPanel.insert),
                  ),
                  _PrimaryToolButton(
                    icon: Icons.more_horiz_rounded,
                    tooltip: t(widget.loc, 'notes_editor_more_tooltip'),
                    selected: _panel == NotesToolsPanel.more,
                    onTap: () => _toggle(NotesToolsPanel.more),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesFormatPanel extends StatelessWidget {
  const _NotesFormatPanel({
    super.key,
    required this.activeBlock,
    required this.loc,
    required this.onHeading,
    required this.onSetBlockType,
    required this.onToggleFormat,
    required this.onSetColor,
  });

  final NoteBlock? activeBlock;
  final String loc;
  final ValueChanged<int> onHeading;
  final ValueChanged<NoteBlockType> onSetBlockType;
  final ValueChanged<String> onToggleFormat;
  final ValueChanged<String?> onSetColor;

  @override
  Widget build(BuildContext context) {
    return _ToolsPanelSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelLabel(t(loc, 'notes_tools_block_style')),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PanelPill(
                label: t(loc, 'notes_tools_body'),
                selected: activeBlock?.type == NoteBlockType.paragraph,
                onTap: () => onSetBlockType(NoteBlockType.paragraph),
              ),
              _PanelPill(
                label: 'H1',
                selected:
                    activeBlock?.type == NoteBlockType.heading &&
                    activeBlock?.level == 1,
                onTap: () => onHeading(1),
              ),
              _PanelPill(
                label: 'H2',
                selected:
                    activeBlock?.type == NoteBlockType.heading &&
                    activeBlock?.level == 2,
                onTap: () => onHeading(2),
              ),
              _PanelPill(
                label: 'H3',
                selected:
                    activeBlock?.type == NoteBlockType.heading &&
                    activeBlock?.level == 3,
                onTap: () => onHeading(3),
              ),
              _PanelPill(
                label: t(loc, 'notes_tools_quote'),
                selected: activeBlock?.type == NoteBlockType.quote,
                onTap: () => onSetBlockType(NoteBlockType.quote),
              ),
              _PanelPill(
                label: t(loc, 'notes_tools_callout'),
                selected: activeBlock?.type == NoteBlockType.callout,
                onTap: () => onSetBlockType(NoteBlockType.callout),
              ),
              _PanelPill(
                label: t(loc, 'notes_tools_code'),
                selected: activeBlock?.type == NoteBlockType.codeBlock,
                onTap: () => onSetBlockType(NoteBlockType.codeBlock),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PanelLabel(t(loc, 'notes_tools_text_format')),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PanelIconButton(
                icon: Icons.format_bold_rounded,
                selected: activeBlock?.bold == true,
                onTap: () => onToggleFormat('bold'),
              ),
              _PanelIconButton(
                icon: Icons.format_italic_rounded,
                selected: activeBlock?.italic == true,
                onTap: () => onToggleFormat('italic'),
              ),
              _PanelIconButton(
                icon: Icons.format_underlined_rounded,
                selected: activeBlock?.underline == true,
                onTap: () => onToggleFormat('underline'),
              ),
              _PanelIconButton(
                icon: Icons.format_strikethrough_rounded,
                selected:
                    activeBlock?.effectiveRuns.any((run) => run.marks.strike) ==
                    true,
                onTap: () => onToggleFormat('strike'),
              ),
              _PanelIconButton(
                icon: Icons.format_list_bulleted_rounded,
                selected: activeBlock?.type == NoteBlockType.bulletedList,
                onTap: () => onSetBlockType(NoteBlockType.bulletedList),
              ),
              _PanelIconButton(
                icon: Icons.format_list_numbered_rounded,
                selected: activeBlock?.type == NoteBlockType.numberedList,
                onTap: () => onSetBlockType(NoteBlockType.numberedList),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PanelLabel(t(loc, 'notes_v3_editor_color')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in _notesTextColors)
                _ColorDot(
                  color: color,
                  selected: activeBlock?.color == color,
                  onTap: () => onSetColor(color),
                ),
              _PanelPill(
                label: t(loc, 'notes_v3_editor_color_auto'),
                selected: activeBlock?.color == null,
                onTap: () => onSetColor(null),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotesInsertPanel extends StatelessWidget {
  const _NotesInsertPanel({
    super.key,
    required this.loc,
    required this.onText,
    required this.onChecklist,
    required this.onBullets,
    required this.onNumbers,
    required this.onQuote,
    required this.onCallout,
    required this.onDivider,
    required this.onCode,
    required this.onCollapsible,
    required this.onTable,
    required this.onImage,
    required this.onDraw,
    required this.onLink,
  });

  final String loc;
  final VoidCallback onText;
  final VoidCallback onChecklist;
  final VoidCallback onBullets;
  final VoidCallback onNumbers;
  final VoidCallback onQuote;
  final VoidCallback onCallout;
  final VoidCallback onDivider;
  final VoidCallback onCode;
  final VoidCallback onCollapsible;
  final VoidCallback onTable;
  final VoidCallback onImage;
  final VoidCallback onDraw;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return _ToolsPanelSurface(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InsertSection(
                title: t(loc, 'notes_tools_media'),
                items: [
                  _InsertItemData(
                    Icons.image_outlined,
                    t(loc, 'notes_v3_editor_add_image'),
                    onImage,
                  ),
                  _InsertItemData(
                    Icons.draw_outlined,
                    t(loc, 'notes_v3_editor_add_draw'),
                    onDraw,
                  ),
                ],
              ),
              _InsertSection(
                title: t(loc, 'notes_tools_structure'),
                items: [
                  _InsertItemData(
                    Icons.text_fields_rounded,
                    t(loc, 'notes_v3_editor_add_text'),
                    onText,
                  ),
                  _InsertItemData(
                    Icons.checklist_rounded,
                    t(loc, 'notes_v3_editor_add_checklist'),
                    onChecklist,
                  ),
                  _InsertItemData(
                    Icons.format_list_bulleted_rounded,
                    t(loc, 'notes_tools_bullets'),
                    onBullets,
                  ),
                  _InsertItemData(
                    Icons.format_list_numbered_rounded,
                    t(loc, 'notes_tools_numbers'),
                    onNumbers,
                  ),
                  _InsertItemData(
                    Icons.horizontal_rule_rounded,
                    t(loc, 'notes_tools_divider'),
                    onDivider,
                  ),
                ],
              ),
              _InsertSection(
                title: t(loc, 'notes_tools_special_blocks'),
                items: [
                  _InsertItemData(
                    Icons.format_quote_rounded,
                    t(loc, 'notes_tools_quote'),
                    onQuote,
                  ),
                  _InsertItemData(
                    Icons.lightbulb_outline_rounded,
                    t(loc, 'notes_tools_callout'),
                    onCallout,
                  ),
                  _InsertItemData(
                    Icons.code_rounded,
                    t(loc, 'notes_tools_code_block'),
                    onCode,
                  ),
                  _InsertItemData(
                    Icons.expand_more_rounded,
                    t(loc, 'notes_tools_collapsible'),
                    onCollapsible,
                  ),
                ],
              ),
              _InsertSection(
                title: t(loc, 'notes_tools_data_links'),
                items: [
                  _InsertItemData(
                    Icons.table_chart_outlined,
                    t(loc, 'notes_tools_table'),
                    onTable,
                  ),
                  _InsertItemData(
                    Icons.link_rounded,
                    t(loc, 'notes_tools_link_card'),
                    onLink,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesMorePanel extends StatelessWidget {
  const _NotesMorePanel({super.key, required this.loc, required this.onClose});

  final String loc;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return _ToolsPanelSurface(
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t(loc, 'notes_tools_more_hint'),
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
          IconButton(
            tooltip: t(loc, 'close'),
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ToolsPanelSurface extends StatelessWidget {
  const _ToolsPanelSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 768),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
      ),
      child: child,
    );
  }
}

class _PrimaryToolButton extends StatelessWidget {
  const _PrimaryToolButton({
    this.icon,
    this.text,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
  });

  final IconData? icon;
  final String? text;
  final String tooltip;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: text != null
                ? Text(
                    text!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? scheme.onPrimary
                          : onTap == null
                          ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                          : scheme.onSurfaceVariant,
                    ),
                  )
                : Icon(
                    icon,
                    size: 18,
                    color: selected
                        ? scheme.onPrimary
                        : onTap == null
                        ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                        : scheme.onSurfaceVariant,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ToolsDivider extends StatelessWidget {
  const _ToolsDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.72),
  );
}

class _PanelLabel extends StatelessWidget {
  const _PanelLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _PanelPill extends StatelessWidget {
  const _PanelPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary
              : scheme.surfaceContainerHighest.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _PanelIconButton extends StatelessWidget {
  const _PanelIconButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parsed = _parseColor(color);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: parsed,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

class _InsertItemData {
  const _InsertItemData(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _InsertSection extends StatelessWidget {
  const _InsertSection({required this.title, required this.items});
  final String title;
  final List<_InsertItemData> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelLabel(title),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 96,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: notesGlmGlassPillDecoration(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, size: 20),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotesTableSizeDialog extends StatefulWidget {
  const _NotesTableSizeDialog();

  @override
  State<_NotesTableSizeDialog> createState() => _NotesTableSizeDialogState();
}

class _NotesTableSizeDialogState extends State<_NotesTableSizeDialog> {
  int _rows = 3;
  int _columns = 3;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    return AlertDialog(
      title: Text(t(loc, 'notes_tools_table_size')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 1; row <= 5; row++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var column = 1; column <= 6; column++)
                  InkWell(
                    onTap: () => setState(() {
                      _rows = row;
                      _columns = column;
                    }),
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: row <= _rows && column <= _columns
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: row <= _rows && column <= _columns
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Text('$_rows × $_columns'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t(loc, 'cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(NoteTableData.empty(rows: _rows, columns: _columns)),
          child: Text(t(loc, 'add')),
        ),
      ],
    );
  }
}

class _NotesLinkDialog extends StatefulWidget {
  const _NotesLinkDialog({required this.loc});
  final String loc;

  @override
  State<_NotesLinkDialog> createState() => _NotesLinkDialogState();
}

class _NotesLinkDialogState extends State<_NotesLinkDialog> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t(widget.loc, 'notes_tools_link_card')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: t(widget.loc, 'title_label'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'URL'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t(widget.loc, 'cancel')),
        ),
        FilledButton(
          onPressed: () {
            final url = _urlController.text.trim();
            if (url.isEmpty) return;
            Navigator.of(context).pop(
              NoteLinkData(
                url: url,
                title: _titleController.text.trim().isEmpty
                    ? null
                    : _titleController.text.trim(),
              ),
            );
          },
          child: Text(t(widget.loc, 'add')),
        ),
      ],
    );
  }
}

const List<String> _notesTextColors = [
  '#0F172A',
  '#EF4444',
  '#F59E0B',
  '#10B981',
  '#06B6D4',
  '#6366F1',
  '#EC4899',
  '#94A3B8',
];

Color _parseColor(String value) {
  var raw = value.replaceFirst('#', '');
  if (raw.length == 6) raw = 'FF$raw';
  return Color(int.parse(raw, radix: 16));
}
