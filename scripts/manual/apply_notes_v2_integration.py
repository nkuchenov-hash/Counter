from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace(path: str, old: str, new: str) -> None:
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    if old not in text:
        raise RuntimeError(f"Expected snippet not found in {path}: {old[:120]!r}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


def append_map_entries(path: str, entries: str) -> None:
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    marker = "};"
    index = text.rfind(marker)
    if index < 0:
        raise RuntimeError(f"Map end not found in {path}")
    if "'notes_tools_format'" in text:
        return
    text = text[:index] + entries + "\n" + text[index:]
    file.write_text(text, encoding="utf-8")


# 1. Keep the v1 public fields round-tripping while the production editor is
# migrated incrementally to inline runs.
replace(
    "lib/data/models/note_document.dart",
    """      if (type == NoteBlockType.checklist) json['checked'] = checked;
      if (type == NoteBlockType.heading) json['level'] = level.clamp(1, 3);
      if (indent > 0) json['indent'] = indent;
""",
    """      if (type == NoteBlockType.checklist) json['checked'] = checked;
      if (type == NoteBlockType.heading) json['level'] = level.clamp(1, 3);
      // V1 compatibility while existing editor controls still expose
      // whole-block formatting. V2 readers also receive equivalent runs.
      if (bold) json['bold'] = true;
      if (italic) json['italic'] = true;
      if (underline) json['underline'] = true;
      if (color != null) json['color'] = color;
      if (indent > 0) json['indent'] = indent;
""",
)

# 2. Fix the new standalone tool/special widgets before wiring them.
replace(
    "lib/features/notes/widgets/notes_special_block_widgets.dart",
    "final columns = data.columnCount.clamp(1, 6);",
    "final columns = data.columnCount.clamp(1, 6).toInt();",
)
replace(
    "lib/features/notes/widgets/notes_special_block_widgets.dart",
    """                              key: ValueKey(
                                'table-${row}_$column-${cells[row][column]}',
                              ),
""",
    """                              key: ValueKey('table-${row}_$column'),
""",
)
replace(
    "lib/features/notes/widgets/notes_editor_tools.dart",
    """  @override
  Widget build(BuildContext context) => _PanelPill(
        label: String.fromCharCode(icon.codePoint),
        selected: selected,
        onTap: onTap,
      );
""",
    """  @override
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
""",
)

# 3. Production editor page: imports, typed insertion, conversion, toolbar.
replace(
    "lib/features/notes/note_editor_page.dart",
    "import 'package:counter/features/notes/widgets/note_editor_block_widgets.dart';\n",
    """import 'package:counter/features/notes/widgets/note_editor_block_widgets.dart';
import 'package:counter/features/notes/widgets/notes_editor_tools.dart';
""",
)
replace(
    "lib/features/notes/note_editor_page.dart",
    """  void _addBlock(NoteBlockType type, {String? afterId, String? imageData, String? drawingData, int? level}) {
    final base = NoteBlock(
      id: generateNoteBlockId(),
      type: type,
      text: '',
      checked: type == NoteBlockType.checklist ? false : false,
      level: level ?? (type == NoteBlockType.heading ? 2 : 2),
      imageData: imageData,
      drawingData: drawingData,
    );
    final blocks = List<NoteBlock>.from(_doc.blocks);
    int insertIdx = blocks.length;
    if (afterId != null) {
      final i = blocks.indexWhere((b) => b.id == afterId);
      if (i >= 0) insertIdx = i + 1;
    }
    blocks.insert(insertIdx, base);
    _mutate(_doc.copyWith(blocks: blocks));
    setState(() => _activeBlockId = base.id);
  }

""",
    """  void _addBlock(
    NoteBlockType type, {
    String? afterId,
    String? imageData,
    String? drawingData,
    int? level,
    NoteTableData? table,
    NoteCalloutData? callout,
    NoteLinkData? linkData,
    NoteReferenceData? reference,
    String? codeLanguage,
  }) {
    final base = NoteBlock(
      id: generateNoteBlockId(),
      type: type,
      text: '',
      checked: false,
      level: level ?? 2,
      imageData: imageData,
      drawingData: drawingData,
      table: table,
      callout: callout,
      linkData: linkData,
      reference: reference,
      codeLanguage: codeLanguage,
    );
    final blocks = List<NoteBlock>.from(_doc.blocks);
    var insertIndex = blocks.length;
    if (afterId != null) {
      final index = blocks.indexWhere((block) => block.id == afterId);
      if (index >= 0) insertIndex = index + 1;
    }
    blocks.insert(insertIndex, base);
    _mutate(_doc.copyWith(blocks: blocks));
    setState(() => _activeBlockId = base.id);
  }

  void _insertRequest(NotesInsertRequest request) {
    _addBlock(
      request.type,
      afterId: _activeBlockId,
      table: request.table,
      callout: request.callout,
      linkData: request.linkData,
      codeLanguage: request.codeLanguage,
    );
  }

  void _setBlockType(NoteBlockType type) {
    final block = _activeBlock;
    if (block == null || (!block.hasText && type.isTextual)) return;
    _updateBlock(
      block.id,
      (current) => current.copyWith(
        type: type,
        callout: type == NoteBlockType.callout
            ? current.callout ??
                const NoteCalloutData(type: NoteCalloutType.idea)
            : null,
        codeLanguage:
            type == NoteBlockType.codeBlock ? current.codeLanguage ?? 'plain' : null,
      ),
    );
  }

""",
)
replace(
    "lib/features/notes/note_editor_page.dart",
    """        case 'underline':
          return x.copyWith(underline: !x.underline);
        default:
          return x;
""",
    """        case 'underline':
          return x.copyWith(underline: !x.underline);
        case 'strike':
          final effective = x.effectiveRuns;
          final enabled = effective.any((run) => run.marks.strike);
          return x.copyWith(
            runs: effective
                .map(
                  (run) => run.copyWith(
                    marks: run.marks.copyWith(strike: !enabled),
                  ),
                )
                .toList(growable: false),
          );
        default:
          return x;
""",
)
replace(
    "lib/features/notes/note_editor_page.dart",
    """                if (b.type == NoteBlockType.checklist ||
                    b.type == NoteBlockType.paragraph) {
                  _addBlock(
                    b.type == NoteBlockType.checklist
                        ? NoteBlockType.checklist
                        : NoteBlockType.paragraph,
                    afterId: b.id,
                  );
                }
""",
    """                if (b.hasText) {
                  final nextType = switch (b.type) {
                    NoteBlockType.heading => NoteBlockType.paragraph,
                    NoteBlockType.quote => NoteBlockType.paragraph,
                    NoteBlockType.callout => NoteBlockType.paragraph,
                    NoteBlockType.codeBlock => NoteBlockType.codeBlock,
                    NoteBlockType.collapsible => NoteBlockType.paragraph,
                    _ => b.type,
                  };
                  _addBlock(nextType, afterId: b.id);
                }
""",
)
replace(
    "lib/features/notes/note_editor_page.dart",
    """        toolbar: _EditorToolbar(
          activeBlock: _activeBlock,
          showColorPicker: _showColorPicker,
          onToggleChecklist: _toggleChecklist,
          onHeading: _setHeading,
          onToggleFormat: _toggleFormat,
          onToggleColorPicker: () =>
              setState(() => _showColorPicker = !_showColorPicker),
          onSetColor: _setColor,
          onImage: _pickImage,
          onDraw: () => _openDrawing(),
          loc: loc,
        ),
""",
    """        toolbar: NotesEditorToolsDock(
          activeBlock: _activeBlock,
          loc: loc,
          onToggleChecklist: _toggleChecklist,
          onHeading: _setHeading,
          onSetBlockType: _setBlockType,
          onToggleFormat: _toggleFormat,
          onSetColor: _setColor,
          onInsert: _insertRequest,
          onImage: _pickImage,
          onDraw: () => _openDrawing(),
        ),
""",
)

# 4. Block renderer: use effective text/runs, route structural blocks, style
# quote/callout/code/list/collapsible blocks, and persist table edits through the
# same parent callback/autosave path.
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    "import 'package:counter/features/notes/notes_visual_tokens.dart';\n",
    """import 'package:counter/features/notes/notes_visual_tokens.dart';
import 'package:counter/features/notes/widgets/notes_special_block_widgets.dart';
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """    this.drawingData = _unset,
  });
""",
    """    this.drawingData = _unset,
    this.runs,
    this.callout = _unset,
    this.table = _unset,
    this.linkData = _unset,
    this.reference = _unset,
    this.codeLanguage = _unset,
    this.collapsed,
  });
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """  final Object? drawingData;

  NoteBlock applyTo(NoteBlock b) => b.copyWith(
""",
    """  final Object? drawingData;
  final List<NoteTextRun>? runs;
  final Object? callout;
  final Object? table;
  final Object? linkData;
  final Object? reference;
  final Object? codeLanguage;
  final bool? collapsed;

  NoteBlock applyTo(NoteBlock b) => b.copyWith(
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """        drawingData: identical(drawingData, _unset)
            ? b.drawingData
            : drawingData as String?,
      );
""",
    """        drawingData: identical(drawingData, _unset)
            ? b.drawingData
            : drawingData as String?,
        runs: runs ?? b.runs,
        callout: identical(callout, _unset)
            ? b.callout
            : callout as NoteCalloutData?,
        table: identical(table, _unset)
            ? b.table
            : table as NoteTableData?,
        linkData: identical(linkData, _unset)
            ? b.linkData
            : linkData as NoteLinkData?,
        reference: identical(reference, _unset)
            ? b.reference
            : reference as NoteReferenceData?,
        codeLanguage: identical(codeLanguage, _unset)
            ? b.codeLanguage
            : codeLanguage as String?,
        collapsed: collapsed ?? b.collapsed,
      );
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    "TextEditingController(text: widget.block.text)",
    "TextEditingController(text: widget.block.effectiveText)",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """    if (oldWidget.block.id != widget.block.id) {
      _textController.text = widget.block.text;
    } else if (widget.block.text != _textController.text &&
        widget.block.text != oldWidget.block.text) {
      _textController.text = widget.block.text;
    }
""",
    """    final nextText = widget.block.effectiveText;
    final oldText = oldWidget.block.effectiveText;
    if (oldWidget.block.id != widget.block.id) {
      _textController.text = nextText;
    } else if (nextText != _textController.text && nextText != oldText) {
      _textController.text = nextText;
    }
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """    if (block.type == NoteBlockType.drawing && block.drawingData != null) {
      return _NoteEditorDrawingBlock(
        block: block,
        isActive: widget.isActive,
        onActivate: widget.onActivate,
        onEditDrawing: widget.onEditDrawing,
        onDelete: widget.onDelete,
      );
    }

    final isChecklist = block.type == NoteBlockType.checklist;
""",
    """    if (block.type == NoteBlockType.drawing && block.drawingData != null) {
      return _NoteEditorDrawingBlock(
        block: block,
        isActive: widget.isActive,
        onActivate: widget.onActivate,
        onEditDrawing: widget.onEditDrawing,
        onDelete: widget.onDelete,
      );
    }
    if (!block.hasText) {
      return NotesSpecialBlockView(
        block: block,
        isActive: widget.isActive,
        loc: loc,
        onActivate: widget.onActivate,
        onDelete: widget.onDelete,
        onTableChanged: (table) =>
            widget.onUpdate(NoteEditorBlockPatch(table: table)),
      );
    }

    final isChecklist = block.type == NoteBlockType.checklist;
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """    final isHeading = block.type == NoteBlockType.heading;
    final headingSize = block.level == 1
""",
    """    final isHeading = block.type == NoteBlockType.heading;
    final isBullet = block.type == NoteBlockType.bulletedList;
    final isNumbered = block.type == NoteBlockType.numberedList;
    final isQuote = block.type == NoteBlockType.quote;
    final isCallout = block.type == NoteBlockType.callout;
    final isCode = block.type == NoteBlockType.codeBlock;
    final isCollapsible = block.type == NoteBlockType.collapsible;
    final hasStrike = block.effectiveRuns.any((run) => run.marks.strike);
    final headingSize = block.level == 1
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """      decoration: block.underline ? TextDecoration.underline : null,
""",
    """      decoration: hasStrike
          ? TextDecoration.lineThrough
          : block.underline
              ? TextDecoration.underline
              : null,
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """        decoration: widget.isActive
            ? BoxDecoration(
                color: notesBlockActiveFill(scheme),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
""",
    """        decoration: widget.isActive
            ? BoxDecoration(
                color: notesBlockActiveFill(scheme),
                borderRadius: BorderRadius.circular(8),
              )
            : isQuote
                ? BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.24),
                    border: Border(
                      left: BorderSide(color: scheme.primary, width: 3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  )
                : isCallout
                    ? BoxDecoration(
                        color: scheme.tertiaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : isCode
                        ? BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """            if (isChecklist) const SizedBox(width: 8),
            Expanded(
""",
    """            if (isChecklist) const SizedBox(width: 8),
            if (isBullet || isNumbered || isQuote || isCallout || isCollapsible)
              Padding(
                padding: const EdgeInsets.only(top: 5, right: 8),
                child: Icon(
                  isBullet
                      ? Icons.circle
                      : isNumbered
                          ? Icons.format_list_numbered_rounded
                          : isQuote
                              ? Icons.format_quote_rounded
                              : isCallout
                                  ? Icons.lightbulb_outline_rounded
                                  : block.collapsed
                                      ? Icons.chevron_right_rounded
                                      : Icons.expand_more_rounded,
                  size: isBullet ? 7 : 16,
                  color: isCallout ? scheme.tertiary : scheme.primary,
                ),
              ),
            Expanded(
""",
)

# 5. Localized labels for the new panel system.
en_entries = """
    // Notes v2 contextual editing tools
    'notes_tools_redo': 'Redo',
    'notes_tools_format': 'Text formatting',
    'notes_tools_lists': 'Lists and indentation',
    'notes_tools_insert': 'Insert block',
    'notes_tools_block_style': 'Block style',
    'notes_tools_body': 'Body',
    'notes_tools_quote': 'Quote',
    'notes_tools_callout': 'Callout',
    'notes_tools_code': 'Code',
    'notes_tools_text_format': 'Text formatting',
    'notes_tools_media': 'Media',
    'notes_tools_structure': 'Lists and structure',
    'notes_tools_bullets': 'Bulleted list',
    'notes_tools_numbers': 'Numbered list',
    'notes_tools_divider': 'Divider',
    'notes_tools_special_blocks': 'Special blocks',
    'notes_tools_code_block': 'Code block',
    'notes_tools_collapsible': 'Collapsible section',
    'notes_tools_data_links': 'Data and links',
    'notes_tools_table': 'Table',
    'notes_tools_link_card': 'Link card',
    'notes_tools_more_hint': 'Block actions and Life OS references will appear here contextually.',
    'notes_tools_table_size': 'Table size',
    'notes_tools_add_row': 'Add row',
    'notes_tools_add_column': 'Add column',
    'notes_tools_header_row': 'Header row',
    'notes_tools_remove_row': 'Remove row',
    'notes_tools_remove_column': 'Remove column',
"""
ru_entries = """
    // Notes v2 — контекстные инструменты редактора
    'notes_tools_redo': 'Повторить',
    'notes_tools_format': 'Форматирование текста',
    'notes_tools_lists': 'Списки и отступы',
    'notes_tools_insert': 'Вставить блок',
    'notes_tools_block_style': 'Стиль блока',
    'notes_tools_body': 'Обычный текст',
    'notes_tools_quote': 'Цитата',
    'notes_tools_callout': 'Спецзаметка',
    'notes_tools_code': 'Код',
    'notes_tools_text_format': 'Формат текста',
    'notes_tools_media': 'Медиа',
    'notes_tools_structure': 'Списки и структура',
    'notes_tools_bullets': 'Маркированный список',
    'notes_tools_numbers': 'Нумерованный список',
    'notes_tools_divider': 'Разделитель',
    'notes_tools_special_blocks': 'Специальные блоки',
    'notes_tools_code_block': 'Блок кода',
    'notes_tools_collapsible': 'Сворачиваемый раздел',
    'notes_tools_data_links': 'Данные и ссылки',
    'notes_tools_table': 'Таблица',
    'notes_tools_link_card': 'Карточка ссылки',
    'notes_tools_more_hint': 'Действия блока и ссылки Life OS появляются здесь контекстно.',
    'notes_tools_table_size': 'Размер таблицы',
    'notes_tools_add_row': 'Добавить строку',
    'notes_tools_add_column': 'Добавить столбец',
    'notes_tools_header_row': 'Строка заголовков',
    'notes_tools_remove_row': 'Удалить строку',
    'notes_tools_remove_column': 'Удалить столбец',
"""
append_map_entries("lib/l10n/langs/en.dart", en_entries)
append_map_entries("lib/l10n/langs/ru.dart", ru_entries)

# 6. Strict structure manifest. New persisted semantics are within notes_delta;
# PocketBase schema is unchanged.
replace(
    "docs/APP_STRUCTURE.md",
    """| `models/note_document.dart` | `NoteDocument` / `NoteBlock` — versioned `lifeos_notes_blocks_v1` envelope (pure data) *(part)* |
""",
    """| `models/note_rich_types.dart` | Notes v2 inline marks, text runs, table/callout/link/reference value objects (pure data) *(part)* |
| `models/note_document.dart` | `NoteDocument` / `NoteBlock` — backward-compatible `lifeos_notes_blocks_v2` envelope in existing `plans.notes_delta` *(part)* |
""",
)
replace(
    "docs/APP_STRUCTURE.md",
    """| `notes/widgets/note_editor_block_widgets.dart` | Editor block rows + add-block chrome (text/checklist/heading/image/drawing; callbacks only) |
| `notes/widgets/notes_library_body.dart` | Grid/list body of `NoteCard`s for Lists tab |
""",
    """| `notes/widgets/note_editor_block_widgets.dart` | Editor block rows + add-block chrome; callbacks only; no Brain ownership |
| `notes/widgets/notes_editor_tools.dart` | Contextual primary toolbar, Aa formatting panel, Insert panel, table/link dialogs |
| `notes/widgets/notes_special_block_widgets.dart` | Divider, table, link card, and Life OS reference block renderers |
| `notes/widgets/notes_library_body.dart` | Grid/list body of `NoteCard`s for Lists tab |
""",
)
replace(
    "docs/APP_STRUCTURE.md",
    """| `notes/` | `drawing_canvas_page.dart`, `notes_glm_surface.dart`, `notes_library_page.dart`, `notes_visual_tokens.dart`, `note_editor_page.dart`, **`widgets/`** (`notes_library_body.dart`, `notes_library_production_shell.dart`, `note_card.dart`, `note_editor_block_widgets.dart`) | Notes library/editor/drawing feature UI (GLM v3); exact roles in §3.4 Notes below |
""",
    """| `notes/` | `drawing_canvas_page.dart`, `notes_glm_surface.dart`, `notes_library_page.dart`, `notes_visual_tokens.dart`, `note_editor_page.dart`, **`widgets/`** (`notes_library_body.dart`, `notes_library_production_shell.dart`, `note_card.dart`, `note_editor_block_widgets.dart`, `notes_editor_tools.dart`, `notes_special_block_widgets.dart`) | Notes library/editor/drawing feature UI; exact roles in §3.4 Notes below |
""",
)

print("Notes v2 production integration patch applied")
