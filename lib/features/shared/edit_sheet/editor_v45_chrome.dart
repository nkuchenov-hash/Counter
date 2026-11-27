import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/categories/picker/category_tree_picker.dart';

/// Shared native editor chrome derived from the approved B1 prototype.
/// Domain mutations and persistence remain in the host edit sheets.
class EditorV45Title extends StatefulWidget {
  const EditorV45Title({super.key, required this.controller, required this.onChanged,
    required this.onClose, required this.creating, required this.writing,
    this.contextLabel, this.contextTime});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final bool creating, writing;
  final String? contextLabel, contextTime;
  @override
  State<EditorV45Title> createState() => _EditorV45TitleState();
}
class _EditorV45TitleState extends State<EditorV45Title> {
  final FocusNode _focus = FocusNode();
  bool _editing = false;
  @override
  void dispose() { _focus.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editing = widget.creating || _editing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: TextField(
            controller: widget.controller, focusNode: _focus,
            readOnly: !editing || widget.writing,
            minLines: 1, maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(fontSize: widget.writing ? 22 : 28, height: 1.22,
              fontWeight: FontWeight.w700, letterSpacing: -.65, color: scheme.onSurface),
            decoration: InputDecoration(hintText: t(currentLocale.value, 'title_label'),
              filled: false, isDense: true, constraints: const BoxConstraints(),
              contentPadding: EdgeInsets.zero, border: InputBorder.none,
              enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
            onChanged: widget.onChanged,
            onTap: () { if (!widget.creating && !widget.writing && !_editing) {
              setState(() => _editing = true); _focus.requestFocus();
            }},
          )),
          if (!widget.creating && !widget.writing)
            IconButton(tooltip: _editing ? t(currentLocale.value, 'save') : t(currentLocale.value, 'title_label'),
              onPressed: () { setState(() => _editing = !_editing);
                if (_editing) { _focus.requestFocus(); } else { _focus.unfocus(); }
              }, icon: Icon(_editing ? Icons.check_rounded : Icons.edit_outlined, size: 20)),
          if (widget.writing)
            TextButton(onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: Text(currentLocale.value == 'ru' ? 'Готово' : 'Done'))
          else IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close_rounded)),
        ]),
        if (widget.writing) Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 4),
          child: Row(children: [
            Expanded(child: Text(widget.contextLabel ?? '', style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant))),
            Text(widget.contextTime ?? '', style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

String editorV45Time(DateTime? date) => date == null ? '—:—' :
  '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String editorV45Range(DateTime? start, DateTime? end) =>
  start == null ? '' : end == null ? editorV45Time(start) : '${editorV45Time(start)} — ${editorV45Time(end)}';

class EditorV45TimeCard extends StatelessWidget {
  const EditorV45TimeCard({super.key, this.start, this.end, this.fallbackDate,
    required this.onStart, this.onEnd, this.running = false});
  final DateTime? start, end, fallbackDate;
  final VoidCallback onStart;
  final VoidCallback? onEnd;
  final bool running;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final ru = currentLocale.value == 'ru';
    final duration = start != null && end != null && !running ? end!.difference(start!) : null;
    final mins = duration?.inMinutes ?? -1;
    final label = mins < 0 ? '' : [
      if (mins >= 1440) '${mins ~/ 1440} ${ru ? 'д' : 'd'}',
      if (mins ~/ 60 % 24 > 0) '${mins ~/ 60 % 24} ${ru ? 'ч' : 'h'}',
      if (mins % 60 > 0 || mins == 0) '${mins % 60} ${ru ? 'мин' : 'min'}',
    ].join(' ');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(color: s.surfaceContainerHighest, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: s.outlineVariant)),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _EditorTimePoint(label: ru ? 'Начало' : 'Start', value: start,
            fallbackDate: fallbackDate, onTap: onStart)),
          const SizedBox(width: 14),
          Expanded(child: _EditorTimePoint(label: ru ? 'Окончание' : 'End', value: end,
            fallbackDate: fallbackDate, onTap: onEnd, end: true, running: running)),
        ]),
        if (label.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12),
          child: Row(children: [
            const _DurationLine(), Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(label, style: TextStyle(fontSize: 14, color: s.onSurfaceVariant))),
            const _DurationLine(reverse: true),
          ])),
      ]),
    );
  }
}
class _DurationLine extends StatelessWidget {
  const _DurationLine({this.reverse = false});
  final bool reverse;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    final dot = Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
    final line = Expanded(child: Container(height: 1, color: color));
    return Expanded(child: Row(children: reverse ? [line, dot] : [dot, line]));
  }
}
class _EditorTimePoint extends StatelessWidget {
  const _EditorTimePoint({required this.label, this.value, this.fallbackDate, this.onTap, this.end = false, this.running = false});
  final String label;
  final DateTime? value, fallbackDate;
  final VoidCallback? onTap;
  final bool end, running;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final date = value ?? fallbackDate;
    final time = Text(running ? t(currentLocale.value, 'running_label') : editorV45Time(value),
      maxLines: 1, style: TextStyle(fontSize: running ? 16 : 30, fontWeight: FontWeight.w700, color: s.onSurface));
    final chevron = Icon(Icons.expand_more_rounded, size: 17, color: s.onSurfaceVariant);
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8),
      child: Column(crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 14, color: s.onSurfaceVariant)),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: end ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (end && onTap != null) chevron, time, if (!end && onTap != null) chevron,
          ])),
        const SizedBox(height: 4),
        Text(date == null ? '—' : DateFormat('d MMM, E', currentLocale.value).format(date),
          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: s.onSurfaceVariant)),
      ]),
    );
  }
}

class EditorV45MetadataRow extends StatelessWidget {
  const EditorV45MetadataRow({super.key, required this.icon, required this.label, required this.value, this.onTap});
  final IconData icon;
  final String label, value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48),
        child: Row(children: [
          Icon(icon, size: 20, color: s.onSurfaceVariant), const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 16, color: s.onSurfaceVariant)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: s.onSurface))),
          const SizedBox(width: 4), Icon(Icons.expand_more_rounded, size: 16, color: s.onSurfaceVariant),
        ])),
    );
  }
}

class EditorV45CategoryRow extends StatelessWidget {
  const EditorV45CategoryRow({super.key, required this.value, required this.display, required this.onChanged});
  final int? value;
  final String display;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => EditorV45MetadataRow(icon: Icons.folder_outlined,
    label: t(currentLocale.value, 'category_label'), value: display,
    onTap: () async { final id = await showCategoryTreePicker(context, initialCategoryId: value);
      if (id != null && context.mounted) onChanged(id); });
}

class EditorV45Actions extends StatelessWidget {
  const EditorV45Actions({super.key, required this.primaryLabel, required this.onPrimary, this.onCancel, this.onDelete, this.onStop});
  final String primaryLabel;
  final VoidCallback? onPrimary, onCancel, onDelete, onStop;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    return SafeArea(top: false, minimum: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: DecoratedBox(decoration: BoxDecoration(
        color: s.surfaceContainerHighest.withValues(alpha: .75),
        borderRadius: BorderRadius.circular(29), border: Border.all(color: s.outlineVariant),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0, 3))]),
        child: Padding(padding: const EdgeInsets.all(5), child: Row(children: [
          if (onStop != null) IconButton(onPressed: onStop, tooltip: t(loc, 'stop'), icon: const Icon(Icons.stop_rounded)),
          if (onDelete != null) Expanded(child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: s.error, minimumSize: const Size(0, 44)),
            onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 18), label: Text(t(loc, 'delete'))))
          else if (onCancel != null) Expanded(child: TextButton(onPressed: onCancel, child: Text(t(loc, 'cancel')))),
          Expanded(flex: 2, child: FilledButton(onPressed: onPrimary,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44), shape: const StadiumBorder()),
            child: Text(primaryLabel, textAlign: TextAlign.center))),
        ]))),
    );
  }
}
