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

class _TableBlock extends StatefulWidget {
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

  @override
  State<_TableBlock> createState() => _TableBlockState();
}

class _TableBlockState extends State<_TableBlock> {
  late NoteTableData _data;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
  }

  @override
  void didUpdateWidget(covariant _TableBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) _data = widget.data;
  }

  void _emit(NoteTableData next, {bool rebuild = true}) {
    if (rebuild) {
      setState(() => _data = next);
    } else {
      _data = next;
    }
    widget.onChanged(next);
  }

  void _changeCell(int row, int column, String value) {
    final cells = _data.cells.map((item) => List<String>.from(item)).toList();
    if (row >= cells.length || column >= cells[row].length) return;
    cells[row][column] = value;
    _emit(_data.copyWith(cells: cells), rebuild: false);
  }

  void _addRow() {
    final columns = _data.columnCount.clamp(1, 6).toInt();
    if (_data.rowCount >= 20) return;
    _emit(
      _data.copyWith(
        cells: [
          ..._data.cells.map((row) => List<String>.from(row)),
          List<String>.filled(columns, ''),
        ],
      ),
    );
  }

  void _addColumn() {
    if (_data.columnCount >= 6) return;
    final source = _data.cells.isEmpty
        ? NoteTableData.empty().cells
        : _data.cells;
    _emit(
      _data.copyWith(
        cells: source
            .map((row) => <String>[...row, ''])
            .toList(growable: false),
      ),
    );
  }

  void _removeRow() {
    if (_data.rowCount <= 1) return;
    _emit(
      _data.copyWith(
        cells: _data.cells
            .take(_data.rowCount - 1)
            .map((row) => List<String>.from(row))
            .toList(),
      ),
    );
  }

  void _removeColumn() {
    if (_data.columnCount <= 1) return;
    _emit(
      _data.copyWith(
        cells: _data.cells
            .map((row) => row.take(row.length - 1).toList())
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cells = _data.cells.isEmpty
        ? NoteTableData.empty().cells
        : _data.cells;
    return GestureDetector(
      onTap: widget.onActivate,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(142),
                border: TableBorder.all(
                  color: widget.isActive
                      ? scheme.primary.withValues(alpha: 0.65)
                      : scheme.outlineVariant,
                  width: widget.isActive ? 1.1 : 0.8,
                ),
                children: [
                  for (var row = 0; row < cells.length; row++)
                    TableRow(
                      children: [
                        for (
                          var column = 0;
                          column < cells[row].length;
                          column++
                        )
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: TextFormField(
                              key: ValueKey('table-${row}_$column'),
                              initialValue: cells[row][column],
                              maxLines: null,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _data.hasHeader && row == 0
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 7,
                                ),
                              ),
                              onTap: widget.onActivate,
                              onChanged: (value) =>
                                  _changeCell(row, column, value),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (widget.isActive)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _TableAction(
                      icon: Icons.add_rounded,
                      label: t(widget.loc, 'notes_tools_add_row'),
                      onTap: _addRow,
                    ),
                    _TableAction(
                      icon: Icons.view_column_outlined,
                      label: t(widget.loc, 'notes_tools_add_column'),
                      onTap: _addColumn,
                    ),
                    _TableAction(
                      icon: _data.hasHeader
                          ? Icons.table_rows_rounded
                          : Icons.table_rows_outlined,
                      label: t(widget.loc, 'notes_tools_header_row'),
                      onTap: () =>
                          _emit(_data.copyWith(hasHeader: !_data.hasHeader)),
                    ),
                    _TableAction(
                      icon: Icons.remove_rounded,
                      label: t(widget.loc, 'notes_tools_remove_row'),
                      onTap: _data.rowCount > 1 ? _removeRow : null,
                    ),
                    _TableAction(
                      icon: Icons.view_column_rounded,
                      label: t(widget.loc, 'notes_tools_remove_column'),
                      onTap: _data.columnCount > 1 ? _removeColumn : null,
                    ),
                    _TableAction(
                      icon: Icons.delete_outline_rounded,
                      label: t(widget.loc, 'notes_v3_editor_delete_block'),
                      danger: true,
                      onTap: widget.onDelete,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.link_rounded, size: 20, color: scheme.primary),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
