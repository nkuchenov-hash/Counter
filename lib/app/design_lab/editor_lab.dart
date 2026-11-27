import 'dart:math' as math;

import 'package:counter/core/theme.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_figma_tokens.dart';
import 'package:counter/features/notes/widgets/note_editor_block_widgets.dart';
import 'package:counter/features/notes/widgets/notes_canonical_components.dart';
import 'package:counter/features/notes/widgets/notes_editor_screen.dart';
import 'package:counter/features/notes/widgets/notes_editor_tools.dart';
import 'package:counter/features/shared/edit_sheet/editor_v45_chrome.dart';
import 'package:flutter/material.dart';

enum LabEditor { note, record, plan }
enum LabMode { existing, creating, writing }
enum LabDevice { phone, wide, desktop }

/// The laboratory is deliberately an in-memory surface. Its only editor
/// dependencies are the actual production UI components and document models.
class EditorDesignLab extends StatefulWidget {
  const EditorDesignLab({super.key});
  @override
  State<EditorDesignLab> createState() => _EditorDesignLabState();
}

class _EditorDesignLabState extends State<EditorDesignLab> {
  LabEditor _editor = LabEditor.record;
  LabMode _mode = LabMode.existing;
  LabDevice _device = LabDevice.phone;
  bool _dark = false;
  bool _android = false;
  int _revision = 0;

  String _name(LabEditor editor) => switch (editor) {
    LabEditor.note => 'Заметка', LabEditor.record => 'Запись', LabEditor.plan => 'План',
  };
  String _modeName(LabMode mode) => switch (mode) {
    LabMode.existing => 'Существующий', LabMode.creating => 'Создание', LabMode.writing => 'Письмо',
  };
  String _deviceName(LabDevice device) => switch (device) {
    LabDevice.phone => '390', LabDevice.wide => '760', LabDevice.desktop => '960',
  };

  Widget _choice(String text, bool selected, VoidCallback action, {Key? key}) =>
    AppButton(key: key, label: text, onPressed: action,
      size: AppButtonSize.s,
      variant: selected ? AppButtonVariant.primary : AppButtonVariant.ghost);

  @override
  Widget build(BuildContext context) {
    final theme = (_dark ? appDarkTheme : appLightTheme).copyWith(
      platform: _device == LabDevice.phone
        ? (_android ? TargetPlatform.android : TargetPlatform.iOS)
        : TargetPlatform.windows,
    );
    return Theme(data: theme, child: Builder(builder: (context) {
      final s = Theme.of(context).colorScheme;
      return Scaffold(
        backgroundColor: s.surfaceContainerLow,
        body: SafeArea(child: Column(children: [
          Container(
            width: double.infinity,
            color: s.surface,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('LIFE OS / Design Lab', style: Theme.of(context).textTheme.titleLarge),
                  Text('01 · Редакторы · Flutter · Только демоданные',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                ])),
                AppButton.ghost(key: const ValueKey('lab-reset'), label: 'Сбросить',
                  icon: Icons.refresh_rounded, onPressed: () => setState(() => _revision++)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final item in LabEditor.values)
                  _choice(_name(item), item == _editor, () => setState(() { _editor = item; _revision++; }),
                    key: ValueKey('lab-editor-${item.name}')),
                const SizedBox(width: 8),
                for (final item in LabMode.values)
                  _choice(_modeName(item), item == _mode, () => setState(() { _mode = item; _revision++; }),
                    key: ValueKey('lab-mode-${item.name}')),
              ]),
              Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final item in LabDevice.values)
                  _choice(_deviceName(item), item == _device, () => setState(() => _device = item),
                    key: ValueKey('lab-device-${item.name}')),
                const SizedBox(width: 8),
                _choice(_dark ? 'Тёмная' : 'Светлая', _dark, () => setState(() => _dark = !_dark),
                  key: const ValueKey('lab-theme')),
                _choice(_android ? 'Android' : 'iOS', _android, () => setState(() { _android = !_android; _device = LabDevice.phone; }),
                  key: const ValueKey('lab-platform')),
              ]),
            ]),
          ),
          Expanded(child: LayoutBuilder(builder: (context, constraints) {
            final width = switch (_device) { LabDevice.phone => 390.0, LabDevice.wide => 760.0, LabDevice.desktop => 960.0 };
            final height = _device == LabDevice.phone ? 844.0 : 850.0;
            final frameWidth = math.min(width, math.max(1.0, constraints.maxWidth - 24));
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
              child: Center(child: Column(children: [
                Text('${_name(_editor)} · ${frameWidth.toInt()} × ${height.toInt()}',
                  style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 10),
                SizedBox(width: frameWidth, height: height, child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: Size(frameWidth, height),
                      padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero,
                    ),
                    child: Material(
                      color: NotesFigmaTokens.surfaceCard(context),
                      child: _LabEditorSurface(
                        key: ValueKey('${_editor.name}-${_mode.name}-$_revision'),
                        editor: _editor, mode: _mode,
                      ),
                    ),
                  ),
                )),
              ])),
            );
          })),
        ])),
      );
    }));
  }
}

class _LabEditorSurface extends StatefulWidget {
  const _LabEditorSurface({super.key, required this.editor, required this.mode});
  final LabEditor editor;
  final LabMode mode;
  @override
  State<_LabEditorSurface> createState() => _LabEditorSurfaceState();
}

class _LabEditorSurfaceState extends State<_LabEditorSurface> {
  late final TextEditingController _title;
  late final List<NoteBlock> _blocks;
  final _controllers = <String, NotesTextEditingController>{};
  final _focus = <String, FocusNode>{};
  String? _active;
  String _category = 'Спорт / Тренировки';
  String _linked = 'Тренировка в зале';
  bool _pinned = false;
  bool _closed = false;
  int _tab = 0;
  int _sequence = 0;
  DateTime _start = DateTime(2026, 11, 27, 18, 30);
  DateTime _end = DateTime(2026, 11, 27, 19, 45);

  bool get _note => widget.editor == LabEditor.note;
  bool get _record => widget.editor == LabEditor.record;
  bool get _creating => widget.mode == LabMode.creating;
  bool get _writing => widget.mode == LabMode.writing;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: _creating ? '' : _note ? 'Поездка в Петербург' : 'Тренировка в зале');
    if (_note) _category = 'Личное / Поездки';
    if (_record) {
      _start = DateTime(2026, 11, 27, 18, 34);
      _end = DateTime(2026, 11, 27, 19, 42);
    }
    _blocks = _creating ? [const NoteBlock(id: 'empty', type: NoteBlockType.paragraph)] : _fixture(_note, _record);
    for (final block in _blocks) _prepare(block);
    if (_writing) {
      _active = _blocks.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus[_active]?.requestFocus();
      });
    }
  }

  void _prepare(NoteBlock block) {
    _controllers[block.id] = NotesTextEditingController(text: block.effectiveText, runs: block.effectiveRuns);
    _focus[block.id] = FocusNode();
  }
  @override
  void dispose() {
    _title.dispose();
    for (final controller in _controllers.values) { controller.dispose(); }
    for (final focus in _focus.values) { focus.dispose(); }
    super.dispose();
  }

  void _update(int i, NoteBlock block) => setState(() => _blocks[i] = block);
  void _convert(NoteBlockType type, {int level = 2}) {
    final index = _blocks.indexWhere((b) => b.id == _active);
    if (index < 0) return;
    _update(index, _blocks[index].copyWith(type: type, level: level));
  }

  void _insertTable() {
    final index = _blocks.indexWhere((b) => b.id == _active);
    final block = NoteBlock(id: 'table-${_sequence++}', type: NoteBlockType.table,
      table: const NoteTableData(cells: [['Упражнение', 'Подходы'], ['', '']], hasHeader: true));
    _prepare(block);
    setState(() { _blocks.insert(index < 0 ? _blocks.length : index + 1, block); });
  }

  void _toggleBold() {
    final index = _blocks.indexWhere((b) => b.id == _active);
    if (index < 0) return;
    final old = _blocks[index];
    final runs = old.effectiveRuns;
    final enabled = !runs.every((r) => r.marks.bold);
    final next = runs.map((r) => NoteTextRun(text: r.text, marks: r.marks.copyWith(bold: enabled))).toList();
    _controllers[old.id]?.setRuns(next);
    _update(index, old.copyWith(runs: next));
  }

  Widget _toolbar() => NotesEditorToolbarHost(
    activeBlock: _blocks.where((b) => b.id == _active).firstOrNull,
    onHeading: () => _convert(NoteBlockType.heading, level: 2),
    onBody: () => _convert(NoteBlockType.paragraph),
    onFormatting: _toggleBold,
    onQuote: () => _convert(NoteBlockType.quote),
    onList: () => _convert(NoteBlockType.bulletedList),
    onBulletedList: () => _convert(NoteBlockType.bulletedList),
    onNumberedList: () => _convert(NoteBlockType.numberedList),
    onChecklist: () => _convert(NoteBlockType.checklist),
    onTable: _insertTable,
  );

  Widget _document() => ReorderableListView.builder(
    buildDefaultDragHandles: false,
    onReorder: (oldIndex, newIndex) => setState(() {
      if (newIndex > oldIndex) newIndex--;
      _blocks.insert(newIndex, _blocks.removeAt(oldIndex));
    }),
    padding: const EdgeInsets.only(top: 18, bottom: 112),
    itemCount: _blocks.length,
    itemBuilder: (context, i) {
      final b = _blocks[i];
      var ordinal = 1;
      for (var j = i - 1; j >= 0 && _blocks[j].type == NoteBlockType.numberedList; j--) { ordinal++; }
      return NotesEditorBlockItem(
        key: ValueKey(b.id), block: b, index: i, numberedOrdinal: ordinal,
        previousBlockType: i == 0 ? null : _blocks[i - 1].type,
        active: _active == b.id, editing: _active == b.id, directEditOnTap: true,
        textController: _controllers[b.id], focusNode: _focus[b.id],
        onTap: () => setState(() => _active = b.id),
        onKeyEvent: (_) => KeyEventResult.ignored,
        onTextChanged: (value) => _update(i, b.copyWith(text: value)),
        onCheckedChanged: (value) => _update(i, b.copyWith(checked: value)),
        onTableChanged: (value) => _update(i, b.copyWith(table: value)),
      );
    },
  );

  Future<void> _time(bool start) async {
    final old = start ? _start : _end;
    final next = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(old));
    if (next == null || !mounted) return;
    final value = DateTime(old.year, old.month, old.day, next.hour, next.minute);
    setState(() {
      if (start) { _start = value; if (_end.isBefore(value)) _end = value.add(const Duration(hours: 1)); }
      else { _end = value.isBefore(_start) ? value.add(const Duration(days: 1)) : value; }
    });
  }

  Future<void> _pick(String title, List<String> options, ValueChanged<String> onPick) async {
    final value = await showDialog<String>(context: context, builder: (context) => SimpleDialog(
      title: Text(title),
      children: [for (final option in options) SimpleDialogOption(
        onPressed: () => Navigator.pop(context, option), child: Text(option),
      )],
    ));
    if (mounted && value != null) setState(() => onPick(value));
  }

  void _close() => setState(() => _closed = true);

  @override
  Widget build(BuildContext context) {
    if (_closed) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle_outline_rounded, size: 36),
      const SizedBox(height: 12),
      const Text('Демонстрационный редактор закрыт'),
      const SizedBox(height: 12),
      AppButton.primary(label: 'Открыть снова', onPressed: () => setState(() => _closed = false)),
    ]));
    if (_note) return NotesEditorScreen(
      titleController: _title, onTitleChanged: (_) {},
      onDone: _close, pinned: _pinned, onTogglePinned: () => setState(() => _pinned = !_pinned),
      onDelete: _close, categoryLabel: _category,
      tags: _creating ? [] : const [NotesEditorMetadataTag(label: '#поездка'), NotesEditorMetadataTag(label: '#выходные')],
      titleHint: 'Название заметки', timestampLabel: _creating ? null : '27 ноября, 10:24',
      content: _document(), toolbar: _toolbar(),
    );
    final tabs = ['Заметки', if (_record) 'Параллельные записи' else ...['Повтор', 'Параллельные планы']];
    final paper = NotesFigmaTokens.surfaceCard(context);
    return Material(color: paper, child: Column(children: [
      EditorV45Title(controller: _title, onChanged: (_) {}, onClose: _close,
        creating: _creating, writing: _writing,
        contextLabel: _category, contextTime: editorV45Range(_start, _end)),
      if (!_writing) ...[
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: EditorV45TimeCard(
          start: _start, end: _end, onStart: (_) => _time(true), onEnd: (_) => _time(false),
        )),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: EditorV45MetadataRow(
          icon: Icons.folder_outlined, label: 'Категория', value: _category,
          onTap: () => _pick('Категория', ['Спорт / Тренировки', 'Работа', 'Личное / Поездки'], (v) => _category = v),
        )),
        if (_record) Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: EditorV45MetadataRow(
          icon: Icons.link_rounded, label: 'Связь с планом', value: _linked,
          onTap: () => _pick('Связь с планом', ['Тренировка в зале', 'Без связи'], (v) => _linked = v),
        )),
        if (!_record) const Padding(padding: EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: Align(alignment: Alignment.centerLeft, child: Text('#спорт    #вечер'))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Row(children: [
          for (var i = 0; i < tabs.length; i++) Flexible(child: InkWell(
            onTap: () => setState(() => _tab = i),
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(
                width: 2, color: _tab == i ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
              ))),
              child: AppCompactTextTab(text: tabs[i], fontSize: 15),
            ),
          )),
        ])),
      ],
      Expanded(child: _tab != 0 && !_writing
        ? const Center(child: Text('Демонстрационный сценарий — только оформление вкладки'))
        : _writing ? NotesEditorBody(content: _document(), toolbar: _toolbar(), embedded: true)
        : EditorV45ActionOverlay(content: _document(), visible: true, actions: EditorV45Actions(
          primaryLabel: _creating ? (_record ? 'Создать запись' : 'Создать план') : 'Закрыть',
          onPrimary: _close, onCancel: _creating ? _close : null, onDelete: _creating ? null : _close,
        ))),
    ]));
  }
}

List<NoteBlock> _fixture(bool note, bool record) => [
  NoteBlock(id: 'h1', type: NoteBlockType.heading, level: 1,
    text: note ? 'Подготовка' : record ? 'Итоги тренировки' : 'Программа тренировки'),
  NoteBlock(id: 'p1', type: NoteBlockType.paragraph, runs: [
    NoteTextRun(text: note ? 'В первую очередь нужно ' : 'Силовая тренировка на верх тела. '),
    NoteTextRun(text: note ? 'купить билеты и забронировать жильё.' : 'Не работать до отказа.',
      marks: const NoteInlineMarks(bold: true)),
    NoteTextRun(text: note ? ' Это будет наша первая поездка в этом году.' : ' Нагрузка умеренная.'),
  ]),
  NoteBlock(id: 'h2', type: NoteBlockType.heading, level: 2, text: note ? 'Что взять с собой' : 'Разминка'),
  NoteBlock(id: 'l1', type: NoteBlockType.bulletedList, text: note ? 'Удобную обувь для прогулок' : 'Дорожка — 7 минут'),
  NoteBlock(id: 'l2', type: NoteBlockType.bulletedList, text: note ? 'Тёплую одежду и зонт' : 'Разминка плеч и локтей'),
  NoteBlock(id: 'l3', type: NoteBlockType.bulletedList, text: note ? 'Зарядку и пауэрбанк' : 'Два лёгких подхода жима'),
  NoteBlock(id: 'h3', type: NoteBlockType.heading, level: 2, text: note ? 'Документы' : 'Основная часть'),
  if (note) ...[
    const NoteBlock(id: 'n1', type: NoteBlockType.numberedList, text: 'Паспорт'),
    const NoteBlock(id: 'n2', type: NoteBlockType.numberedList, text: 'Билеты туда и обратно'),
    const NoteBlock(id: 'c1', type: NoteBlockType.checklist, text: 'Забронировать жильё', checked: true),
  ] else
    const NoteBlock(id: 't1', type: NoteBlockType.table, table: NoteTableData(hasHeader: true, cells: [
      ['Упражнение', 'Подходы', 'Вес'], ['Жим лёжа', '3 × 10', '50 кг'],
      ['Тяга блока', '3 × 12', '45 кг'], ['Жим гантелей', '3 × 10', '12 кг'], ['Планка', '3 × 45 с', '—'],
    ])),
];
