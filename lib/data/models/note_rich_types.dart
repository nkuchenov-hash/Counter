// Part of lib/data/models.dart — typed value objects for Life OS Notes v2.
// Pure data/serialization code. No UI or PocketBase imports.

part of '../models.dart';

enum NoteCalloutType {
  note,
  info,
  idea,
  warning,
  success,
  question;

  static NoteCalloutType fromString(String? value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return NoteCalloutType.note;
  }
}

@immutable
class NoteInlineMarks {
  const NoteInlineMarks({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.textColor,
    this.highlightColor,
    this.link,
    this.inlineCode = false,
  });

  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final String? textColor;
  final String? highlightColor;
  final String? link;
  final bool inlineCode;

  bool get isEmpty =>
      !bold &&
      !italic &&
      !underline &&
      !strike &&
      textColor == null &&
      highlightColor == null &&
      link == null &&
      !inlineCode;

  NoteInlineMarks copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    Object? textColor = _noteRichUnset,
    Object? highlightColor = _noteRichUnset,
    Object? link = _noteRichUnset,
    bool? inlineCode,
  }) {
    return NoteInlineMarks(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strike: strike ?? this.strike,
      textColor: identical(textColor, _noteRichUnset)
          ? this.textColor
          : textColor as String?,
      highlightColor: identical(highlightColor, _noteRichUnset)
          ? this.highlightColor
          : highlightColor as String?,
      link: identical(link, _noteRichUnset) ? this.link : link as String?,
      inlineCode: inlineCode ?? this.inlineCode,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (bold) json['bold'] = true;
    if (italic) json['italic'] = true;
    if (underline) json['underline'] = true;
    if (strike) json['strike'] = true;
    if (textColor != null) json['textColor'] = textColor;
    if (highlightColor != null) json['highlightColor'] = highlightColor;
    if (link != null) json['link'] = link;
    if (inlineCode) json['inlineCode'] = true;
    return json;
  }

  factory NoteInlineMarks.fromJson(Map<String, dynamic> json) =>
      NoteInlineMarks(
        bold: _jsonBool(json['bold'], false),
        italic: _jsonBool(json['italic'], false),
        underline: _jsonBool(json['underline'], false),
        strike: _jsonBool(json['strike'], false),
        textColor: _cleanNoteRichString(json['textColor'] ?? json['color']),
        highlightColor: _cleanNoteRichString(
          json['highlightColor'] ?? json['highlight'],
        ),
        link: _cleanNoteRichString(json['link']),
        inlineCode: _jsonBool(json['inlineCode'], false),
      );
}

@immutable
class NoteTextRun {
  const NoteTextRun({required this.text, this.marks = const NoteInlineMarks()});

  final String text;
  final NoteInlineMarks marks;

  NoteTextRun copyWith({String? text, NoteInlineMarks? marks}) =>
      NoteTextRun(text: text ?? this.text, marks: marks ?? this.marks);

  Map<String, dynamic> toJson() => {
    'text': text,
    if (!marks.isEmpty) 'marks': marks.toJson(),
  };

  factory NoteTextRun.fromJson(Map<String, dynamic> json) {
    final marksRaw = json['marks'];
    return NoteTextRun(
      text: json['text']?.toString() ?? '',
      marks: marksRaw is Map<String, dynamic>
          ? NoteInlineMarks.fromJson(marksRaw)
          : const NoteInlineMarks(),
    );
  }
}

@immutable
class NoteCalloutData {
  const NoteCalloutData({
    this.type = NoteCalloutType.note,
    this.icon,
    this.color,
  });

  final NoteCalloutType type;
  final String? icon;
  final String? color;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    if (icon != null) 'icon': icon,
    if (color != null) 'color': color,
  };

  factory NoteCalloutData.fromJson(Map<String, dynamic> json) =>
      NoteCalloutData(
        type: NoteCalloutType.fromString(json['type']?.toString()),
        icon: _cleanNoteRichString(json['icon']),
        color: _cleanNoteRichString(json['color']),
      );
}

@immutable
class NoteTableData {
  const NoteTableData({
    this.cells = const <List<String>>[],
    this.hasHeader = false,
    this.columnAlignments = const <String>[],
  });

  final List<List<String>> cells;
  final bool hasHeader;
  final List<String> columnAlignments;

  int get rowCount => cells.length;
  int get columnCount => cells.isEmpty ? 0 : cells.first.length;

  NoteTableData copyWith({
    List<List<String>>? cells,
    bool? hasHeader,
    List<String>? columnAlignments,
  }) => NoteTableData(
    cells: cells ?? this.cells,
    hasHeader: hasHeader ?? this.hasHeader,
    columnAlignments: columnAlignments ?? this.columnAlignments,
  );

  Map<String, dynamic> toJson() => {
    'cells': cells,
    'hasHeader': hasHeader,
    if (columnAlignments.isNotEmpty) 'columnAlignments': columnAlignments,
  };

  factory NoteTableData.fromJson(Map<String, dynamic> json) {
    final rows = <List<String>>[];
    final rawCells = json['cells'];
    if (rawCells is List) {
      for (final rawRow in rawCells.take(20)) {
        if (rawRow is! List) continue;
        rows.add(
          rawRow.take(6).map((value) => value?.toString() ?? '').toList(),
        );
      }
    }
    final rawAlignments = json['columnAlignments'];
    final alignments = rawAlignments is List
        ? rawAlignments.take(6).map((value) => value.toString()).toList()
        : const <String>[];
    return NoteTableData(
      cells: rows,
      hasHeader: _jsonBool(json['hasHeader'], false),
      columnAlignments: alignments,
    );
  }

  factory NoteTableData.empty({int rows = 2, int columns = 2}) {
    final safeRows = rows.clamp(1, 20).toInt();
    final safeColumns = columns.clamp(1, 6).toInt();
    return NoteTableData(
      cells: List<List<String>>.generate(
        safeRows,
        (_) => List<String>.filled(safeColumns, ''),
      ),
    );
  }
}

@immutable
class NoteLinkData {
  const NoteLinkData({
    required this.url,
    this.title,
    this.description,
    this.previewImage,
  });

  final String url;
  final String? title;
  final String? description;
  final String? previewImage;

  Map<String, dynamic> toJson() => {
    'url': url,
    if (title != null) 'title': title,
    if (description != null) 'description': description,
    if (previewImage != null) 'previewImage': previewImage,
  };

  factory NoteLinkData.fromJson(Map<String, dynamic> json) => NoteLinkData(
    url: json['url']?.toString() ?? '',
    title: _cleanNoteRichString(json['title']),
    description: _cleanNoteRichString(json['description']),
    previewImage: _cleanNoteRichString(json['previewImage']),
  );
}

@immutable
class NoteReferenceData {
  const NoteReferenceData({required this.targetId, this.label, this.subtitle});

  final String targetId;
  final String? label;
  final String? subtitle;

  Map<String, dynamic> toJson() => {
    'targetId': targetId,
    if (label != null) 'label': label,
    if (subtitle != null) 'subtitle': subtitle,
  };

  factory NoteReferenceData.fromJson(Map<String, dynamic> json) =>
      NoteReferenceData(
        targetId: json['targetId']?.toString() ?? '',
        label: _cleanNoteRichString(json['label']),
        subtitle: _cleanNoteRichString(json['subtitle']),
      );
}

/// Applies a plain-text insertion/deletion/replacement while preserving
/// unaffected inline marks. Inserted text inherits the marks at the edit point.
List<NoteTextRun> applyNoteTextEditToRuns({
  required String oldText,
  required List<NoteTextRun> oldRuns,
  required String newText,
}) {
  if (oldText == newText) return List<NoteTextRun>.unmodifiable(oldRuns);
  if (newText.isEmpty) return const <NoteTextRun>[];

  final normalizedRuns =
      oldRuns.isNotEmpty && oldRuns.map((run) => run.text).join() == oldText
      ? oldRuns
      : oldText.isEmpty
      ? const <NoteTextRun>[]
      : <NoteTextRun>[NoteTextRun(text: oldText)];

  var prefix = 0;
  final sharedLength = math.min(oldText.length, newText.length);
  while (prefix < sharedLength && oldText[prefix] == newText[prefix]) {
    prefix++;
  }

  var suffix = 0;
  while (suffix < oldText.length - prefix &&
      suffix < newText.length - prefix &&
      oldText[oldText.length - 1 - suffix] ==
          newText[newText.length - 1 - suffix]) {
    suffix++;
  }

  final oldEditEnd = oldText.length - suffix;
  final newEditEnd = newText.length - suffix;
  final inserted = newText.substring(prefix, newEditEnd);
  final result = <NoteTextRun>[..._sliceNoteRuns(normalizedRuns, 0, prefix)];

  if (inserted.isNotEmpty) {
    final inheritedOffset = oldEditEnd > prefix
        ? prefix
        : prefix > 0
        ? prefix - 1
        : oldEditEnd < oldText.length
        ? oldEditEnd
        : -1;
    result.add(
      NoteTextRun(
        text: inserted,
        marks: _noteMarksAt(normalizedRuns, inheritedOffset),
      ),
    );
  }

  result.addAll(_sliceNoteRuns(normalizedRuns, oldEditEnd, oldText.length));
  return List<NoteTextRun>.unmodifiable(_mergeNoteRuns(result));
}

List<NoteTextRun> _sliceNoteRuns(List<NoteTextRun> runs, int start, int end) {
  if (start >= end) return const <NoteTextRun>[];
  final result = <NoteTextRun>[];
  var offset = 0;
  for (final run in runs) {
    final runStart = offset;
    final runEnd = offset + run.text.length;
    final sliceStart = start.clamp(runStart, runEnd).toInt();
    final sliceEnd = end.clamp(runStart, runEnd).toInt();
    if (sliceStart < sliceEnd) {
      result.add(
        NoteTextRun(
          text: run.text.substring(sliceStart - runStart, sliceEnd - runStart),
          marks: run.marks,
        ),
      );
    }
    offset = runEnd;
  }
  return result;
}

NoteInlineMarks _noteMarksAt(List<NoteTextRun> runs, int offset) {
  if (offset < 0) return const NoteInlineMarks();
  var cursor = 0;
  for (final run in runs) {
    final end = cursor + run.text.length;
    if (offset >= cursor && offset < end) return run.marks;
    cursor = end;
  }
  return runs.isEmpty ? const NoteInlineMarks() : runs.last.marks;
}

List<NoteTextRun> _mergeNoteRuns(List<NoteTextRun> runs) {
  final result = <NoteTextRun>[];
  for (final run in runs.where((item) => item.text.isNotEmpty)) {
    if (result.isNotEmpty &&
        result.last.marks.toJson().toString() ==
            run.marks.toJson().toString()) {
      final previous = result.removeLast();
      result.add(
        NoteTextRun(text: '${previous.text}${run.text}', marks: run.marks),
      );
    } else {
      result.add(run);
    }
  }
  return result;
}

const Object _noteRichUnset = Object();

String? _cleanNoteRichString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
