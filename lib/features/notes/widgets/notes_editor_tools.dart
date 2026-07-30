import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/widgets/notes_canonical_components.dart';
import 'package:flutter/material.dart';

enum NotesTableEditCommand {
  addRowAbove,
  addRowBelow,
  addColumnLeft,
  addColumnRight,
  deleteRow,
  deleteColumn,
}

class NotesLinkDialogResult {
  const NotesLinkDialogResult(this.url);

  /// Null means remove the current link. A null dialog result means cancel.
  final String? url;
}

class NotesEditorToolbarHost extends StatelessWidget {
  const NotesEditorToolbarHost({
    super.key,
    required this.activeBlock,
    required this.selectionFormats,
    required this.onHeading,
    required this.onFormatting,
    required this.onQuote,
    required this.onList,
    required this.onChecklist,
    required this.onTable,
    required this.onMore,
  });

  final NoteBlock? activeBlock;
  final Set<NotesInlineFormat> selectionFormats;
  final VoidCallback onHeading;
  final VoidCallback onFormatting;
  final VoidCallback onQuote;
  final VoidCallback onList;
  final VoidCallback onChecklist;
  final VoidCallback onTable;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final type = activeBlock?.type;
    final convertible = type != null && _isConvertibleText(type);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: NotesEditorToolbar(
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
                icon: Icons.format_bold_rounded,
                tooltip: 'Text formatting',
                selected: selectionFormats.isNotEmpty,
                enabled: convertible,
                onPressed: onFormatting,
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
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(0, 8, 8, 8),
            child: AppIconButton(
              icon: Icons.more_horiz_rounded,
              tooltip: 'Block options',
              size: AppIconButtonSize.m,
              variant: AppIconButtonVariant.subtle,
              onPressed: activeBlock == null ? null : onMore,
            ),
          ),
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

Future<void> showNotesTextFormattingMenu({
  required BuildContext context,
  required Set<NotesInlineFormat> selected,
  required ValueChanged<NotesInlineFormat> onSelected,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) => Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: NotesTextFormattingMenu(
          selected: selected,
          onSelected: (format) {
            Navigator.of(dialogContext).pop();
            onSelected(format);
          },
        ),
      ),
    ),
  );
}

Future<NotesLinkDialogResult?> showNotesLinkDialog({
  required BuildContext context,
  String? currentUrl,
}) {
  final controller = TextEditingController(text: currentUrl ?? '');
  return showDialog<NotesLinkDialogResult>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Link'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'https://example.com'),
        onSubmitted: (value) {
          final clean = value.trim();
          if (clean.isEmpty) return;
          Navigator.of(dialogContext).pop(NotesLinkDialogResult(clean));
        },
      ),
      actions: [
        AppButton.ghost(
          label: 'Cancel',
          size: AppButtonSize.s,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        if ((currentUrl ?? '').isNotEmpty)
          AppButton.destructive(
            label: 'Remove',
            size: AppButtonSize.s,
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(const NotesLinkDialogResult(null)),
          ),
        AppButton.primary(
          label: 'Apply',
          size: AppButtonSize.s,
          onPressed: () {
            final clean = controller.text.trim();
            if (clean.isEmpty) return;
            Navigator.of(dialogContext).pop(NotesLinkDialogResult(clean));
          },
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
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

Future<void> showNotesBlockOptionsMenu({
  required BuildContext context,
  required NoteBlock block,
  required VoidCallback onDeleteBlock,
  ValueChanged<NotesTableEditCommand>? onTableCommand,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (block.type == NoteBlockType.table && onTableCommand != null) ...[
            _sheetAction(
              sheetContext,
              Icons.vertical_align_top_rounded,
              'Add row above',
              () => onTableCommand(NotesTableEditCommand.addRowAbove),
            ),
            _sheetAction(
              sheetContext,
              Icons.vertical_align_bottom_rounded,
              'Add row below',
              () => onTableCommand(NotesTableEditCommand.addRowBelow),
            ),
            _sheetAction(
              sheetContext,
              Icons.align_horizontal_left_rounded,
              'Add column left',
              () => onTableCommand(NotesTableEditCommand.addColumnLeft),
            ),
            _sheetAction(
              sheetContext,
              Icons.align_horizontal_right_rounded,
              'Add column right',
              () => onTableCommand(NotesTableEditCommand.addColumnRight),
            ),
            _sheetAction(
              sheetContext,
              Icons.remove_rounded,
              'Delete row',
              () => onTableCommand(NotesTableEditCommand.deleteRow),
            ),
            _sheetAction(
              sheetContext,
              Icons.view_column_outlined,
              'Delete column',
              () => onTableCommand(NotesTableEditCommand.deleteColumn),
            ),
            const Divider(height: 1),
          ],
          ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(sheetContext).colorScheme.error,
            ),
            title: Text(
              block.type == NoteBlockType.table ? 'Delete table' : 'Delete block',
              style: TextStyle(
                color: Theme.of(sheetContext).colorScheme.error,
              ),
            ),
            onTap: () {
              Navigator.of(sheetContext).pop();
              onDeleteBlock();
            },
          ),
        ],
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

Widget _sheetAction(
  BuildContext sheetContext,
  IconData icon,
  String label,
  VoidCallback action,
) {
  return ListTile(
    leading: Icon(icon),
    title: Text(label),
    onTap: () {
      Navigator.of(sheetContext).pop();
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
