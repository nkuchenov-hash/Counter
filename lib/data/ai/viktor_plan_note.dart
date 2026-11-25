import 'package:counter/data/models.dart';

/// Convert Viktor's plan note into the same persisted blocks used by the
/// existing embedded Notes editor. No parallel checklist model or UI.
NoteDocument viktorPlanNoteDocument(String source) {
  final blocks = <NoteBlock>[];
  void add(NoteBlockType type, [String text = '', int level = 2]) {
    blocks.add(NoteBlock(
      id: generateNoteBlockId(), type: type, text: text, level: level,
    ));
  }

  final note = source.trim();
  // A forwarded appointment's "с собой" is a checklist, not a duration
  // or a plain-text bullet list. Restrict inference to clear list tails;
  // arbitrary prose after the marker remains intact as ordinary text.
  final carry = RegExp(
    r'(?:^|[\s,;:])с\s+собой(?:\s+(?:взять|иметь))?\s*[:\-—]?\s+(.+)$',
    caseSensitive: false, dotAll: true,
  ).firstMatch(note);
  if (carry != null) {
    final tail = carry[1]!.trim();
    final items = tail
        .split(RegExp(r'\s*[,;\n]\s*|\s+и\s+', caseSensitive: false))
        .map((item) => item.trim().replaceFirst(RegExp(r'[.!]+$'), ''))
        .where((item) => item.isNotEmpty)
        .toList();
    final isList = items.length >= 2 && items.length <= 20 &&
        items.every((item) => item.length <= 100 &&
            !RegExp(r'[:?]|\d{1,2}:\d{2}|https?://', caseSensitive: false)
                .hasMatch(item));
    if (isList) {
      final before = note.substring(0, carry.start).trimRight()
          .replaceFirst(RegExp(r'[,;:]$'), '').trimRight();
      final arrival = RegExp(r'(?:^|\s)(подойти|прибыть|прийти)\s+',
          caseSensitive: false).firstMatch(before);
      final details = arrival == null ? before :
          before.substring(0, arrival.start).trim();
      if (details.isNotEmpty) {
        add(NoteBlockType.heading, 'Информация');
        add(NoteBlockType.paragraph, details);
      }
      if (arrival != null) {
        if (blocks.isNotEmpty) add(NoteBlockType.divider);
        add(NoteBlockType.heading, 'Перед посещением');
        add(NoteBlockType.paragraph, before.substring(arrival.start).trim());
      }
      if (blocks.isNotEmpty) add(NoteBlockType.divider);
      add(NoteBlockType.heading, 'С собой');
      for (final item in items) {
        add(NoteBlockType.checklist, item);
      }
      return NoteDocument(blocks: blocks);
    }
  }

  // Provider notes may use a small explicit formatting vocabulary. All
  // unrecognized text remains literal; no arbitrary JSON/media/link import.
  for (final rawLine in note.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final heading = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
    final checkbox = RegExp(r'^[-*]\s+\[ \]\s+(.+)$').firstMatch(line);
    if (heading != null) {
      add(NoteBlockType.heading, heading[2]!, heading[1]!.length);
    } else if (checkbox != null) {
      add(NoteBlockType.checklist, checkbox[1]!);
    } else if (line == '---') {
      add(NoteBlockType.divider);
    } else {
      add(NoteBlockType.paragraph, line);
    }
  }
  return NoteDocument(blocks: blocks);
}
