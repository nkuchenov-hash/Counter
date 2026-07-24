import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Non-text block renderer used by the production Notes editor.
class NotesSpecialBlockView extends StatelessWidget {
  const NotesSpecialBlockView({
    super.key,
    required this.block,
    required this.isActive,
    required this.loc,
    required this.onActivate,
    required this.onDelete,
    required this.onTableChanged,
  });

  final NoteBlock block;
  final bool isActive;
  final String loc;
  final VoidCallback onActivate;
  final VoidCallback onDelete;
  final ValueChanged<NoteTableData> onTableChanged;

  @override
  Widget build(BuildContext context) {
    return switch (block.type) {
      NoteBlockType.divider => _DividerBlock(
          isActive: isActive,
          onActivate: onActivate,
          onDelete: onDelete,
        ),
      NoteBlockType.table => _TableBlock(
          data: block.table ?? NoteTableData.empty(),
          isActive: isActive,
          loc: loc,
          onActivate: onActivate,
          onDelete: onDelete,
          onChanged: onTableChanged,
        ),
      NoteBlockType.linkCard => _LinkCardBlock(
          data: block.linkData ?? const NoteLinkData(url: ''),
          isActive: isActive,
          onActivate: onActivate,
          onDelete: onDelete,
        ),
      NoteBlockType.planReference ||
      NoteBlockType.recordReference ||
      NoteBlockType.noteReference ||
      NoteBlockType.categoryReference => _ReferenceBlock(
          type: block.type,
          data: block.reference ?? const NoteReferenceData(targetId: ''),
          isActive: isActive,
          onActivate: onActivate,
          onDelete: onDelete,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _DividerBlock extends StatelessWidget {
  const _DividerBlock({
    required this.isActive,
    required this.onActivate,
    required this.onDelete,
  });

  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onActivate,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Divider(
                height: 1,
                color: isActive ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              _OverlayAction(
                icon: Icons.delete_outline_rounded,
                onTap: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TableBlock extends StatelessWidget {
  const _TableBlock({
    required this.data,
    required this.isActive,
    required this.loc,
    required this.onActivate,
    required this.onDelete,
    required this.onChanged,
  });

  final NoteTableData data;
  final bool isActive;
  final String loc;
  final VoidCallback onActivate;
  final VoidCallback onDelete;
  final ValueChanged<NoteTableData> onChanged;

  void _changeCell(int row, int column, String value) {
    final cells = data.cells.map((item) => List<String>.from(item)).toList();
    if (row >= cells.length || column >= cells[row].length) return;
    cells[row][column] = value;
    onChanged(data.copyWith(cells: cells));
  }

  void _addRow() {
    final columns = data.columnCount.clamp(1, 6);
    if (data.rowCount >= 20) return;
    onChanged(
      data.copyWith(
        cells: [
          ...data.cells.map((row) => List<String>.from(row)),
          List<String>.filled(columns, ''),
        ],
      ),
    );
  }

  void _addColumn() {
    if (data.columnCount >= 6) return;
    final source = data.cells.isEmpty ? NoteTableData.empty().cells : data.cells;
    onChanged(
      data.copyWith(
        cells: source
            .map((row) => <String>[...row, ''])
            .toList(growable: false),
      ),
    );
  }

  void _removeRow() {
    if (data.rowCount <= 1) return;
    onChanged(
      data.copyWith(
        cells: data.cells
            .take(data.rowCount - 1)
            .map((row) => List<String>.from(row))
            .toList(),
      ),
    );
  }

  void _removeColumn() {
    if (data.columnCount <= 1) return;
    onChanged(
      data.copyWith(
        cells: data.cells
            .map((row) => row.take(row.length - 1).toList())
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cells = data.cells.isEmpty ? NoteTableData.empty().cells : data.cells;
    return GestureDetector(
      onTap: onActivate,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? scheme.primary : scheme.outlineVariant,
            width: isActive ? 1.5 : 1,
          ),
          color: scheme.surface.withValues(alpha: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(142),
                border: TableBorder(
                  horizontalInside: BorderSide(color: scheme.outlineVariant),
                  verticalInside: BorderSide(color: scheme.outlineVariant),
                ),
                children: [
                  for (var row = 0; row < cells.length; row++)
                    TableRow(
                      decoration: data.hasHeader && row == 0
                          ? BoxDecoration(
                              color: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.72),
                            )
                          : null,
                      children: [
                        for (var column = 0;
                            column < cells[row].length;
                            column++)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: TextFormField(
                              key: ValueKey(
                                'table-${row}_$column-${cells[row][column]}',
                              ),
                              initialValue: cells[row][column],
                              maxLines: null,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: data.hasHeader && row == 0
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 7),
                              ),
                              onTap: onActivate,
                              onChanged: (value) =>
                                  _changeCell(row, column, value),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.fromLTRB(8, 5, 8, 7),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _TableAction(
                      icon: Icons.add_rounded,
                      label: t(loc, 'notes_tools_add_row'),
                      onTap: _addRow,
                    ),
                    _TableAction(
                      icon: Icons.view_column_outlined,
                      label: t(loc, 'notes_tools_add_column'),
                      onTap: _addColumn,
                    ),
                    _TableAction(
                      icon: data.hasHeader
                          ? Icons.table_rows_rounded
                          : Icons.table_rows_outlined,
                      label: t(loc, 'notes_tools_header_row'),
                      onTap: () =>
                          onChanged(data.copyWith(hasHeader: !data.hasHeader)),
                    ),
                    _TableAction(
                      icon: Icons.remove_rounded,
                      label: t(loc, 'notes_tools_remove_row'),
                      onTap: data.rowCount > 1 ? _removeRow : null,
                    ),
                    _TableAction(
                      icon: Icons.view_column_rounded,
                      label: t(loc, 'notes_tools_remove_column'),
                      onTap: data.columnCount > 1 ? _removeColumn : null,
                    ),
                    _TableAction(
                      icon: Icons.delete_outline_rounded,
                      label: t(loc, 'notes_v3_editor_delete_block'),
                      danger: true,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LinkCardBlock extends StatelessWidget {
  const _LinkCardBlock({
    required this.data,
    required this.isActive,
    required this.onActivate,
    required this.onDelete,
  });

  final NoteLinkData data;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onActivate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          border: Border.all(
            color: isActive ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.link_rounded, color: scheme.primary),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title?.trim().isNotEmpty == true
                        ? data.title!
                        : data.url,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (data.title?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      data.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isActive)
              _OverlayAction(
                icon: Icons.delete_outline_rounded,
                onTap: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceBlock extends StatelessWidget {
  const _ReferenceBlock({
    required this.type,
    required this.data,
    required this.isActive,
    required this.onActivate,
    required this.onDelete,
  });

  final NoteBlockType type;
  final NoteReferenceData data;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  IconData get _icon => switch (type) {
        NoteBlockType.planReference => Icons.event_note_outlined,
        NoteBlockType.recordReference => Icons.timer_outlined,
        NoteBlockType.noteReference => Icons.sticky_note_2_outlined,
        NoteBlockType.categoryReference => Icons.folder_outlined,
        _ => Icons.link_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onActivate,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: scheme.primaryContainer.withValues(alpha: 0.34),
          border: Border.all(
            color: isActive ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(_icon, size: 18, color: scheme.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label ?? data.targetId,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (data.subtitle != null)
                    Text(
                      data.subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (isActive)
              _OverlayAction(
                icon: Icons.delete_outline_rounded,
                onTap: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class _TableAction extends StatelessWidget {
  const _TableAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.48),
          ),
          child: Icon(
            icon,
            size: 16,
            color: onTap == null
                ? scheme.onSurfaceVariant.withValues(alpha: 0.3)
                : danger
                    ? scheme.error
                    : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _OverlayAction extends StatelessWidget {
  const _OverlayAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: t(currentLocale.value, 'notes_v3_editor_delete_block'),
        onPressed: onTap,
        icon: Icon(icon, size: 17),
      );
}
