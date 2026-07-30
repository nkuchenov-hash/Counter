part of 'notes_canonical_components.dart';

class NotesQuoteBlock extends StatelessWidget {
  const NotesQuoteBlock({
    super.key,
    required this.textController,
    this.attributionController,
    this.state = NotesBlockState.defaultState,
    this.onTextChanged,
    this.onAttributionChanged,
    this.textHint,
    this.attributionHint,
  });

  final TextEditingController textController;
  final TextEditingController? attributionController;
  final NotesBlockState state;
  final ValueChanged<String>? onTextChanged;
  final ValueChanged<String>? onAttributionChanged;
  final String? textHint;
  final String? attributionHint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = state == NotesBlockState.active;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kNotesContentInset,
        vertical: kNotesBlockVerticalPadding,
      ),
      child: DecoratedBox(
        key: const ValueKey('notes-quote-surface'),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? scheme.outline : scheme.outlineVariant,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: textController,
                minLines: 1,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                onChanged: onTextChanged,
                style: _notesTextStyle(context, NotesTextBlockStyle.body)
                    .copyWith(fontStyle: FontStyle.italic),
                decoration: InputDecoration(
                  hintText: textHint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (attributionController != null) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: attributionController,
                  minLines: 1,
                  maxLines: 2,
                  onChanged: onAttributionChanged,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  decoration: InputDecoration(
                    hintText: attributionHint,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class NotesDividerBlock extends StatelessWidget {
  const NotesDividerBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: kNotesContentInset,
        vertical: kNotesBlockVerticalPadding,
      ),
      child: Divider(height: 1),
    );
  }
}

class NotesTableBlock extends StatefulWidget {
  const NotesTableBlock({
    super.key,
    required this.data,
    required this.onChanged,
    this.state = NotesBlockState.defaultState,
    this.onOptionsRequested,
  });

  final NoteTableData data;
  final ValueChanged<NoteTableData> onChanged;
  final NotesBlockState state;
  final VoidCallback? onOptionsRequested;

  @override
  State<NotesTableBlock> createState() => _NotesTableBlockState();
}

class _NotesTableBlockState extends State<NotesTableBlock> {
  late List<List<TextEditingController>> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = _buildControllers(_normalizedCells(widget.data));
  }

  @override
  void didUpdateWidget(covariant NotesTableBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _normalizedCells(widget.data);
    final shapeChanged = _controllers.length != next.length ||
        _controllers.first.length != next.first.length;
    if (shapeChanged) {
      _disposeControllers();
      _controllers = _buildControllers(next);
      return;
    }
    for (var row = 0; row < next.length; row++) {
      for (var column = 0; column < next[row].length; column++) {
        final controller = _controllers[row][column];
        final nextText = next[row][column];
        if (controller.text == nextText) continue;
        controller.value = TextEditingValue(
          text: nextText,
          selection: TextSelection.collapsed(
            offset: controller.selection.extentOffset
                .clamp(0, nextText.length)
                .toInt(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  List<List<TextEditingController>> _buildControllers(
    List<List<String>> cells,
  ) => [
    for (final row in cells)
      [for (final cell in row) TextEditingController(text: cell)],
  ];

  void _disposeControllers() {
    for (final row in _controllers) {
      for (final controller in row) {
        controller.dispose();
      }
    }
  }

  void _updateCell(int row, int column, String text) {
    final cells = [
      for (final sourceRow in _normalizedCells(widget.data))
        List<String>.from(sourceRow),
    ];
    cells[row][column] = text;
    widget.onChanged(widget.data.copyWith(cells: cells));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.state == NotesBlockState.active;
    final cells = _normalizedCells(widget.data);
    final columnCount = cells.first.length;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kNotesContentInset,
        vertical: kNotesBlockVerticalPadding,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = math.max(96.0, constraints.maxWidth / columnCount);
          return DecoratedBox(
            key: const ValueKey('notes-table-surface'),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? scheme.outline : scheme.outlineVariant,
                width: active ? 1.5 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: GestureDetector(
                onLongPress: widget.onOptionsRequested,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var row = 0; row < cells.length; row++)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var column = 0;
                                column < columnCount;
                                column++)
                              SizedBox(
                                width: cellWidth,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: widget.data.hasHeader && row == 0
                                        ? scheme.surfaceContainerHighest
                                        : scheme.surface,
                                    border: Border(
                                      right: column == columnCount - 1
                                          ? BorderSide.none
                                          : BorderSide(
                                              color: scheme.outlineVariant,
                                            ),
                                      bottom: row == cells.length - 1
                                          ? BorderSide.none
                                          : BorderSide(
                                              color: scheme.outlineVariant,
                                            ),
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _controllers[row][column],
                                    minLines: 1,
                                    maxLines: null,
                                    onChanged: (value) =>
                                        _updateCell(row, column, value),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontSize: 16, height: 1.35),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.all(10),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
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

/// One shared size picker. Compact mobile defaults to 5 x 5; desktop may pass
/// a larger range without introducing a desktop-only component.
class NotesTableSizePicker extends StatefulWidget {
  const NotesTableSizePicker({
    super.key,
    required this.onSelected,
    this.maxRows = 5,
    this.maxColumns = 5,
    this.cellSize = 28,
  });

  final ValueChanged<NoteTableData> onSelected;
  final int maxRows;
  final int maxColumns;
  final double cellSize;

  @override
  State<NotesTableSizePicker> createState() => _NotesTableSizePickerState();
}

class _NotesTableSizePickerState extends State<NotesTableSizePicker> {
  int _rows = 1;
  int _columns = 1;

  void _select(int row, int column) {
    final nextRows = row + 1;
    final nextColumns = column + 1;
    if (_rows == nextRows && _columns == nextColumns) return;
    setState(() {
      _rows = nextRows;
      _columns = nextColumns;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = widget.maxRows.clamp(1, 20).toInt();
    final columns = widget.maxColumns.clamp(1, 12).toInt();
    final gridWidth = columns * widget.cellSize;
    final gridHeight = rows * widget.cellSize;
    final grid = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < rows; row++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var column = 0; column < columns; column++)
                MouseRegion(
                  onEnter: (_) => _select(row, column),
                  child: GestureDetector(
                    key: ValueKey('notes-table-size-${row + 1}-${column + 1}'),
                    onTap: () => widget.onSelected(
                      NoteTableData.empty(rows: row + 1, columns: column + 1),
                    ),
                    child: SizedBox.square(
                      dimension: widget.cellSize,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: row < _rows && column < _columns
                                ? scheme.primaryContainer
                                : scheme.surface,
                            border: Border.all(color: scheme.outlineVariant),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
    return NotesFloatingMenuSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_rows × $_columns',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: math.min(gridWidth, 280.0),
            height: math.min(gridHeight, 280.0),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: grid,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<List<String>> _normalizedCells(NoteTableData data) {
  if (data.cells.isEmpty || data.columnCount == 0) {
    return NoteTableData.empty().cells;
  }
  final columns = data.columnCount;
  return [
    for (final row in data.cells)
      [
        ...row.take(columns),
        if (row.length < columns)
          ...List<String>.filled(columns - row.length, ''),
      ],
  ];
}
