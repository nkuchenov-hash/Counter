import 'package:counter/data/models.dart';
import 'package:counter/features/notes/widgets/notes_canonical_components.dart';
import 'package:flutter/material.dart';

class NotesEditorToolbarHost extends StatelessWidget {
  const NotesEditorToolbarHost({
    super.key,
    required this.activeBlock,
    required this.onHeading,
    required this.onBody,
    required this.onQuote,
    required this.onList,
    required this.onChecklist,
    required this.onTable,
  });

  final NoteBlock? activeBlock;
  final VoidCallback onHeading;
  final VoidCallback onBody;
  final VoidCallback onQuote;
  final VoidCallback onList;
  final VoidCallback onChecklist;
  final VoidCallback onTable;

  @override
  Widget build(BuildContext context) {
    final type = activeBlock?.type;
    final convertible = type != null && _isConvertibleText(type);
    return NotesEditorToolbar(
      actions: [
        NotesToolbarAction(
          tool: NotesToolbarTool.heading,
          icon: Icons.title_rounded,
          tooltip: 'Heading styles',
          selected: type == NoteBlockType.heading,
          enabled: convertible,
          onPressed: onHeading,
        ),
        NotesToolbarAction(
          tool: NotesToolbarTool.text,
          icon: Icons.text_fields_rounded,
          tooltip: 'Body text',
          selected: type == NoteBlockType.paragraph,
          enabled: convertible,
          onPressed: onBody,
        ),
        NotesToolbarAction(
          tool: NotesToolbarTool.quote,
          icon: Icons.format_quote_rounded,
          tooltip: 'Quote',
          selected: type == NoteBlockType.quote,
          enabled: convertible,
          onPressed: onQuote,
        ),
        NotesToolbarAction(
          tool: NotesToolbarTool.list,
          icon: type == NoteBlockType.numberedList
              ? Icons.format_list_numbered_rounded
              : Icons.format_list_bulleted_rounded,
          tooltip: type == NoteBlockType.bulletedList
              ? 'Numbered list'
              : 'Bulleted list',
          selected: type == NoteBlockType.bulletedList ||
              type == NoteBlockType.numberedList,
          enabled: convertible,
          onPressed: onList,
        ),
        NotesToolbarAction(
          tool: NotesToolbarTool.checklist,
          icon: Icons.checklist_rounded,
          tooltip: 'Checklist',
          selected: type == NoteBlockType.checklist,
          enabled: convertible,
          onPressed: onChecklist,
        ),
        NotesToolbarAction(
          tool: NotesToolbarTool.table,
          icon: Icons.table_chart_rounded,
          tooltip: 'Insert table',
          selected: type == NoteBlockType.table,
          onPressed: onTable,
        ),
        NotesToolbarAction(
          tool: NotesToolbarTool.drawing,
          icon: Icons.draw_rounded,
          tooltip: 'Drawing — next phase',
          enabled: false,
          onPressed: _noop,
        ),
        NotesToolbarAction(
          tool: NotesToolbarTool.image,
          icon: Icons.image_rounded,
          tooltip: 'Image — next phase',
          enabled: false,
          onPressed: _noop,
        ),
        NotesToolbarAction(
          tool: NotesToolbarTool.audio,
          icon: Icons.mic_rounded,
          tooltip: 'Audio — next phase',
          enabled: false,
          onPressed: _noop,
        ),
      ],
    );
  }
}

Future<void> showNotesHeadingStylesMenu({
  required BuildContext context,
  required NotesTextBlockStyle? selected,
  required ValueChanged<NotesTextBlockStyle> onSelected,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) => Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: NotesHeadingStylesMenu(
          selected: selected,
          onSelected: (style) {
            Navigator.of(dialogContext).pop();
            onSelected(style);
          },
        ),
      ),
    ),
  );
}

Future<void> showNotesTablePicker({
  required BuildContext context,
  required ValueChanged<NoteTableData> onSelected,
}) {
  final wide = MediaQuery.sizeOf(context).width >= 768;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) => Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: NotesTableSizePicker(
          maxRows: wide ? 8 : 5,
          maxColumns: wide ? 6 : 5,
          onSelected: (table) {
            Navigator.of(dialogContext).pop();
            onSelected(table);
          },
        ),
      ),
    ),
  );
}

Future<void> showNotesInsertMenu({
  required BuildContext context,
  required VoidCallback onHeading,
  required VoidCallback onText,
  required VoidCallback onQuote,
  required VoidCallback onBulletedList,
  required VoidCallback onNumberedList,
  required VoidCallback onChecklist,
  required VoidCallback onTable,
  required VoidCallback onDivider,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) => Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: NotesInsertMenu(
          actions: [
            _menuAction(dialogContext, Icons.title_rounded, 'Heading', onHeading),
            _menuAction(
              dialogContext,
              Icons.text_fields_rounded,
              'Text',
              onText,
            ),
            _menuAction(
              dialogContext,
              Icons.format_quote_rounded,
              'Quote',
              onQuote,
            ),
            _menuAction(
              dialogContext,
              Icons.format_list_bulleted_rounded,
              'Bulleted list',
              onBulletedList,
            ),
            _menuAction(
              dialogContext,
              Icons.format_list_numbered_rounded,
              'Numbered list',
              onNumberedList,
            ),
            _menuAction(
              dialogContext,
              Icons.checklist_rounded,
              'Checklist',
              onChecklist,
            ),
            _menuAction(
              dialogContext,
              Icons.table_chart_rounded,
              'Table',
              onTable,
            ),
            _menuAction(
              dialogContext,
              Icons.horizontal_rule_rounded,
              'Divider',
              onDivider,
            ),
          ],
        ),
      ),
    ),
  );
}

NotesInsertMenuAction _menuAction(
  BuildContext dialogContext,
  IconData icon,
  String label,
  VoidCallback action,
) {
  return NotesInsertMenuAction(
    icon: icon,
    label: label,
    onPressed: () {
      Navigator.of(dialogContext).pop();
      action();
    },
  );
}

bool _isConvertibleText(NoteBlockType type) {
  return type == NoteBlockType.paragraph ||
      type == NoteBlockType.heading ||
      type == NoteBlockType.bulletedList ||
      type == NoteBlockType.numberedList ||
      type == NoteBlockType.checklist ||
      type == NoteBlockType.quote;
}

void _noop() {}
