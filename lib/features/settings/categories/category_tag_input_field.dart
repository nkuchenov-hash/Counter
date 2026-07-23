import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Input field that commits a tag on Space, Comma, or Enter.
class TagInputField extends StatefulWidget {
  const TagInputField({
    super.key,
    required this.tags,
    required this.onChanged,
    this.decoration,
    this.chipBackgroundColor,
    this.chipLabelColor,
    this.onTagAdded,
  });

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final InputDecoration? decoration;
  final Color? chipBackgroundColor;
  final Color? chipLabelColor;
  final void Function(String tag)? onTagAdded;

  @override
  State<TagInputField> createState() => _TagInputFieldState();
}

class _TagInputFieldState extends State<TagInputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (text.isEmpty) return;
    final last = text.length - 1;
    if (last < 0) return;
    final ch = text[last];
    if (ch == ' ' || ch == ',') {
      final before = text.substring(0, last).trim().toLowerCase();
      _controller.removeListener(_onTextChanged);
      _controller.text = '';
      _controller.addListener(_onTextChanged);
      if (before.isNotEmpty) {
        final next = List<String>.from(widget.tags);
        if (!next.contains(before)) {
          next.add(before);
          widget.onChanged(next);
          widget.onTagAdded?.call(before);
        }
      }
    }
  }

  void _commitCurrent() {
    final trimmed = _controller.text.trim().toLowerCase();
    _controller.clear();
    if (trimmed.isEmpty) return;
    final next = List<String>.from(widget.tags);
    if (!next.contains(trimmed)) {
      next.add(trimmed);
      widget.onChanged(next);
      widget.onTagAdded?.call(trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg =
        widget.chipBackgroundColor ??
        Theme.of(context).chipTheme.backgroundColor ??
        Colors.grey.shade300;
    final fg =
        widget.chipLabelColor ??
        Theme.of(context).chipTheme.labelStyle?.color ??
        Colors.black87;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in widget.tags)
              InputChip(
                label: Text(tag, style: TextStyle(color: fg)),
                backgroundColor: bg,
                onDeleted: () {
                  final next = List<String>.from(widget.tags)..remove(tag);
                  widget.onChanged(next);
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          decoration:
              widget.decoration ??
              InputDecoration(
                labelText: t(currentLocale.value, 'add_keyword_hint'),
              ),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _commitCurrent(),
        ),
      ],
    );
  }
}
