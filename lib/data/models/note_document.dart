// Part of lib/data/models.dart — Life OS Notes block document model (v2).
//
// Serialized into the existing `plans.notes_delta` JSON field. V2 separates
// block structure from inline text marks while preserving the v1 public API so
// the current production editor and legacy notes continue to work during the
// staged editor-tools rollout.
//
// Pure data/serialization code. No Flutter widgets, PocketBase, or UI imports.

part of '../models.dart';

const String kLifeOsNotesBlocksV1Format = 'lifeos_notes_blocks_v1';
const String kLifeOsNotesBlocksFormat = 'lifeos_notes_blocks_v2';
const int kLifeOsNotesBlocksVersion = 2;

/// Guards against runaway base64 image/drawing payloads.
const int kLifeOsNotesMaxPayloadBytes = 4 * 1024 * 1024;
const int kLifeOsNotesMaxAssetBytes = 2 * 1024 * 1024;

/// Every document block has a stable id and a single structural type.
enum NoteBlockType {
  paragraph,
  checklist,
  heading,
  bulletedList,
  numberedList,
  quote,
  callout,
  divider,
  table,
  image,
  drawing,
  linkCard,
  codeBlock,
  collapsible,
  planReference,
  recordReference,
  noteReference,
  categoryReference;

  static NoteBlockType fromString(String? raw) {
    switch (raw) {
      case 'paragraph':
        return NoteBlockType.paragraph;
      case 'checklist':
        return NoteBlockType.checklist;
      case 'heading':
        return NoteBlockType.heading;
      case 'bulletedList':
      case 'bulleted_list':
      case 'bullet':
        return NoteBlockType.bulletedList;
      case 'numberedList':
      case 'numbered_list':
      case 'ordered':
        return NoteBlockType.numberedList;
      case 'quote':
        return NoteBlockType.quote;
      case 'callout':
        return NoteBlockType.callout;
      case 'divider':
        return NoteBlockType.divider;
      case 'table':
        return NoteBlockType.table;
      case 'image':
        return NoteBlockType.image;
      case 'drawing':
        return NoteBlockType.drawing;
      case 'linkCard':
      case 'link_card':
      case 'link':
        return NoteBlockType.linkCard;
      case 'codeBlock':
      case 'code_block':
      case 'code':
        return NoteBlockType.codeBlock;
      case 'collapsible':
      case 'toggle':
        return NoteBlockType.collapsible;
      case 'planReference':
      case 'plan_reference':
        return NoteBlockType.planReference;
      case 'recordReference':
      case 'record_reference':
        return NoteBlockType.recordReference;
      case 'noteReference':
      case 'note_reference':
        return NoteBlockType.noteReference;
      case 'categoryReference':
      case 'category_reference':
        return NoteBlockType.categoryReference;
      default:
        return NoteBlockType.paragraph;
    }
  }

  String get wire => name;

  bool get isTextual {
    switch (this) {
      case NoteBlockType.paragraph:
      case NoteBlockType.checklist:
      case NoteBlockType.heading:
      case NoteBlockType.bulletedList:
      case NoteBlockType.numberedList:
      case NoteBlockType.quote:
      case NoteBlockType.callout:
      case NoteBlockType.codeBlock:
      case NoteBlockType.collapsible:
        return true;
      case NoteBlockType.divider:
      case NoteBlockType.table:
      case NoteBlockType.image:
      case NoteBlockType.drawing:
      case NoteBlockType.linkCard:
      case NoteBlockType.planReference:
      case NoteBlockType.recordReference:
      case NoteBlockType.noteReference:
      case NoteBlockType.categoryReference:
        return false;
    }
  }
}

/// A single block. Legacy whole-block formatting remains readable/writable
/// during the transition; v2 editors should use [runs] for inline marks.
@immutable
class NoteBlock {
  const NoteBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.runs = const <NoteTextRun>[],
    this.checked = false,
    this.level = 2,
    this.indent = 0,
    this.alignment,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.color,
    this.imageData,
    this.drawingData,
    this.caption,
    this.mediaAlignment,
    this.callout,
    this.table,
    this.linkData,
    this.reference,
    this.codeLanguage,
    this.collapsed = false,
  });

  final String id;
  final NoteBlockType type;
  final String text;
  final List<NoteTextRun> runs;
  final bool checked;
  final int level;
  final int indent;
  final String? alignment;

  /// V1 compatibility fields. New inline formatting belongs in [runs].
  final bool bold;
  final bool italic;
  final bool underline;
  final String? color;

  final String? imageData;
  final String? drawingData;
  final String? caption;
  final String? mediaAlignment;
  final NoteCalloutData? callout;
  final NoteTableData? table;
  final NoteLinkData? linkData;
  final NoteReferenceData? reference;
  final String? codeLanguage;
  final bool collapsed;

  bool get hasText => type.isTextual;
  String get effectiveText =>
      runs.isEmpty ? text : runs.map((run) => run.text).join();

  List<NoteTextRun> get effectiveRuns {
    if (runs.isNotEmpty) return runs;
    if (text.isEmpty) return const <NoteTextRun>[];
    final marks = NoteInlineMarks(
      bold: bold,
      italic: italic,
      underline: underline,
      textColor: color,
    );
    return <NoteTextRun>[NoteTextRun(text: text, marks: marks)];
  }

  NoteBlock copyWith({
    NoteBlockType? type,
    String? text,
    List<NoteTextRun>? runs,
    bool? checked,
    int? level,
    int? indent,
    Object? alignment = _sentinel,
    bool? bold,
    bool? italic,
    bool? underline,
    Object? color = _sentinel,
    Object? imageData = _sentinel,
    Object? drawingData = _sentinel,
    Object? caption = _sentinel,
    Object? mediaAlignment = _sentinel,
    Object? callout = _sentinel,
    Object? table = _sentinel,
    Object? linkData = _sentinel,
    Object? reference = _sentinel,
    Object? codeLanguage = _sentinel,
    bool? collapsed,
  }) {
    final nextRuns = runs ?? (text != null ? const <NoteTextRun>[] : this.runs);
    return NoteBlock(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      runs: nextRuns,
      checked: checked ?? this.checked,
      level: level ?? this.level,
      indent: indent ?? this.indent,
      alignment: identical(alignment, _sentinel)
          ? this.alignment
          : alignment as String?,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      color: identical(color, _sentinel) ? this.color : color as String?,
      imageData: identical(imageData, _sentinel)
          ? this.imageData
          : imageData as String?,
      drawingData: identical(drawingData, _sentinel)
          ? this.drawingData
          : drawingData as String?,
      caption:
          identical(caption, _sentinel) ? this.caption : caption as String?,
      mediaAlignment: identical(mediaAlignment, _sentinel)
          ? this.mediaAlignment
          : mediaAlignment as String?,
      callout: identical(callout, _sentinel)
          ? this.callout
          : callout as NoteCalloutData?,
      table: identical(table, _sentinel)
          ? this.table
          : table as NoteTableData?,
      linkData: identical(linkData, _sentinel)
          ? this.linkData
          : linkData as NoteLinkData?,
      reference: identical(reference, _sentinel)
          ? this.reference
          : reference as NoteReferenceData?,
      codeLanguage: identical(codeLanguage, _sentinel)
          ? this.codeLanguage
          : codeLanguage as String?,
      collapsed: collapsed ?? this.collapsed,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'id': id, 'type': type.wire};
    if (hasText) {
      final encodedRuns = effectiveRuns;
      if (encodedRuns.isNotEmpty) {
        json['runs'] = encodedRuns.map((run) => run.toJson()).toList();
        json['text'] = effectiveText;
      } else {
        json['text'] = text;
      }
      if (type == NoteBlockType.checklist) json['checked'] = checked;
      if (type == NoteBlockType.heading) json['level'] = level.clamp(1, 3);
      if (indent > 0) json['indent'] = indent;
      if (alignment != null) json['alignment'] = alignment;
      if (type == NoteBlockType.callout && callout != null) {
        json['callout'] = callout!.toJson();
      }
      if (type == NoteBlockType.codeBlock && codeLanguage != null) {
        json['codeLanguage'] = codeLanguage;
      }
      if (type == NoteBlockType.collapsible) json['collapsed'] = collapsed;
    }
    if (type == NoteBlockType.image && imageData != null) {
      json['imageData'] = imageData;
    }
    if (type == NoteBlockType.drawing && drawingData != null) {
      json['drawingData'] = drawingData;
    }
    if ((type == NoteBlockType.image || type == NoteBlockType.drawing) &&
        caption != null) {
      json['caption'] = caption;
    }
    if ((type == NoteBlockType.image || type == NoteBlockType.drawing) &&
        mediaAlignment != null) {
      json['mediaAlignment'] = mediaAlignment;
    }
    if (type == NoteBlockType.table && table != null) {
      json['table'] = table!.toJson();
    }
    if (type == NoteBlockType.linkCard && linkData != null) {
      json['link'] = linkData!.toJson();
    }
    if (_isReferenceType(type) && reference != null) {
      json['reference'] = reference!.toJson();
    }
    return json;
  }

  factory NoteBlock.fromJson(Map<String, dynamic> json) {
    final type = NoteBlockType.fromString(json['type']?.toString());
    final runs = <NoteTextRun>[];
    final rawRuns = json['runs'];
    if (rawRuns is List) {
      for (final rawRun in rawRuns) {
        if (rawRun is Map<String, dynamic>) {
          runs.add(NoteTextRun.fromJson(rawRun));
        }
      }
    }
    final legacyText = json['text']?.toString() ?? '';
    final text = runs.isEmpty
        ? legacyText
        : runs.map((run) => run.text).join();
    final calloutRaw = json['callout'];
    final tableRaw = json['table'];
    final linkRaw = json['link'];
    final referenceRaw = json['reference'];
    return NoteBlock(
      id: (json['id']?.toString().trim().isNotEmpty ?? false)
          ? json['id'].toString()
          : generateNoteBlockId(),
      type: type,
      text: text,
      runs: runs,
      checked: _jsonBool(json['checked'], false),
      level: _jsonInt(json['level'], 2).clamp(1, 3),
      indent: _jsonInt(json['indent'], 0).clamp(0, 8),
      alignment: _cleanJsonString(json['alignment']),
      bold: _jsonBool(json['bold'], false),
      italic: _jsonBool(json['italic'], false),
      underline: _jsonBool(json['underline'], false),
      color: _cleanJsonString(json['color']),
      imageData: _cleanJsonString(json['imageData']),
      drawingData: _cleanJsonString(json['drawingData']),
      caption: _cleanJsonString(json['caption']),
      mediaAlignment: _cleanJsonString(json['mediaAlignment']),
      callout: calloutRaw is Map<String, dynamic>
          ? NoteCalloutData.fromJson(calloutRaw)
          : null,
      table: tableRaw is Map<String, dynamic>
          ? NoteTableData.fromJson(tableRaw)
          : null,
      linkData: linkRaw is Map<String, dynamic>
          ? NoteLinkData.fromJson(linkRaw)
          : null,
      reference: referenceRaw is Map<String, dynamic>
          ? NoteReferenceData.fromJson(referenceRaw)
          : null,
      codeLanguage: _cleanJsonString(json['codeLanguage']),
      collapsed: _jsonBool(json['collapsed'], false),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is NoteBlock && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

const Object _sentinel = Object();

@immutable
class NoteDocumentMeta {
  const NoteDocumentMeta({this.pinned = false});

  final bool pinned;

  NoteDocumentMeta copyWith({bool? pinned}) =>
      NoteDocumentMeta(pinned: pinned ?? this.pinned);

  Map<String, dynamic> toJson() => {'pinned': pinned};

  factory NoteDocumentMeta.fromJson(Map<String, dynamic> json) =>
      NoteDocumentMeta(pinned: _jsonBool(json['pinned'], false));
}

@immutable
class NoteDocument {
  const NoteDocument({
    this.format = kLifeOsNotesBlocksFormat,
    this.version = kLifeOsNotesBlocksVersion,
    this.meta = const NoteDocumentMeta(),
    this.blocks = const <NoteBlock>[],
  });

  final String format;
  final int version;
  final NoteDocumentMeta meta;
  final List<NoteBlock> blocks;

  bool get isEmpty => blocks.isEmpty || blocks.every(_isBlank);

  static bool _isBlank(NoteBlock block) {
    if (block.hasText) return block.effectiveText.trim().isEmpty;
    switch (block.type) {
      case NoteBlockType.divider:
        return false;
      case NoteBlockType.table:
        return block.table == null || block.table!.cells.isEmpty;
      case NoteBlockType.image:
        return (block.imageData ?? '').isEmpty;
      case NoteBlockType.drawing:
        return (block.drawingData ?? '').isEmpty;
      case NoteBlockType.linkCard:
        return (block.linkData?.url ?? '').isEmpty;
      case NoteBlockType.planReference:
      case NoteBlockType.recordReference:
      case NoteBlockType.noteReference:
      case NoteBlockType.categoryReference:
        return (block.reference?.targetId ?? '').isEmpty;
      case NoteBlockType.paragraph:
      case NoteBlockType.checklist:
      case NoteBlockType.heading:
      case NoteBlockType.bulletedList:
      case NoteBlockType.numberedList:
      case NoteBlockType.quote:
      case NoteBlockType.callout:
      case NoteBlockType.codeBlock:
      case NoteBlockType.collapsible:
        return block.effectiveText.trim().isEmpty;
    }
  }

  NoteDocument copyWith({
    List<NoteBlock>? blocks,
    NoteDocumentMeta? meta,
    String? format,
    int? version,
  }) =>
      NoteDocument(
        format: format ?? this.format,
        version: version ?? this.version,
        meta: meta ?? this.meta,
        blocks: blocks ?? this.blocks,
      );

  Map<String, dynamic> toJson() => {
        'format': kLifeOsNotesBlocksFormat,
        'version': kLifeOsNotesBlocksVersion,
        'meta': meta.toJson(),
        'blocks': blocks.map((block) => block.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());

  factory NoteDocument.tryParse({
    String? notesDeltaJson,
    String? notesPlain,
    List<Map<String, dynamic>>? checklist,
  }) {
    final raw = notesDeltaJson?.trim() ?? '';
    if (raw.isEmpty) {
      return _fromLegacyPlainAndChecklist(notesPlain, checklist);
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return _fromLegacyPlainAndChecklist(notesPlain, checklist);
    }

    if (decoded is Map<String, dynamic> &&
        (decoded['format'] == kLifeOsNotesBlocksFormat ||
            decoded['format'] == kLifeOsNotesBlocksV1Format)) {
      final blocks = <NoteBlock>[];
      final rawBlocks = decoded['blocks'];
      if (rawBlocks is List) {
        for (final rawBlock in rawBlocks) {
          if (rawBlock is Map<String, dynamic>) {
            blocks.add(NoteBlock.fromJson(rawBlock));
          }
        }
      }
      final rawMeta = decoded['meta'];
      return NoteDocument(
        format: kLifeOsNotesBlocksFormat,
        version: kLifeOsNotesBlocksVersion,
        meta: rawMeta is Map<String, dynamic>
            ? NoteDocumentMeta.fromJson(rawMeta)
            : const NoteDocumentMeta(),
        blocks: blocks,
      );
    }

    if (decoded is List || (decoded is Map && decoded['ops'] is List)) {
      final document = _fromLegacyQuillDelta(decoded);
      return document.blocks.isEmpty
          ? _fromLegacyPlainAndChecklist(notesPlain, checklist)
          : document;
    }

    return _fromLegacyPlainAndChecklist(notesPlain, checklist);
  }

  static NoteDocument _fromLegacyPlainAndChecklist(
    String? notesPlain,
    List<Map<String, dynamic>>? checklist,
  ) {
    final blocks = <NoteBlock>[];
    if (checklist != null) {
      for (final item in checklist) {
        final text = item['text']?.toString().trim() ?? '';
        final checked = _jsonBool(item['done'], false);
        if (text.isEmpty && !checked) continue;
        blocks.add(NoteBlock(
          id: generateNoteBlockId(),
          type: NoteBlockType.checklist,
          text: text,
          checked: checked,
        ));
      }
    }

    var body = notesPlain?.trim() ?? '';
    const linkPrefix = 'LIFEOS_LINK::';
    if (body.startsWith(linkPrefix)) {
      body = body.substring(linkPrefix.length).trim();
      final newline = body.indexOf('\n');
      if (newline >= 0) {
        final firstLine = body.substring(0, newline).trim();
        if (firstLine.startsWith('http://') ||
            firstLine.startsWith('https://')) {
          body = body.substring(newline + 1).trim();
        }
      }
    }
    for (final line in body.split('\n')) {
      final text = line.trim();
      if (text.isEmpty) continue;
      blocks.add(NoteBlock(
        id: generateNoteBlockId(),
        type: NoteBlockType.paragraph,
        text: text,
      ));
    }
    return NoteDocument(blocks: blocks);
  }

  static NoteDocument _fromLegacyQuillDelta(dynamic decoded) {
    final List ops;
    if (decoded is List) {
      ops = decoded;
    } else if (decoded is Map && decoded['ops'] is List) {
      ops = decoded['ops'] as List;
    } else {
      return const NoteDocument();
    }

    final blocks = <NoteBlock>[];
    final buffer = StringBuffer();
    final runs = <NoteTextRun>[];
    String? lineBlockType;
    int headingLevel = 2;

    void appendRun(String text, Map? attributes) {
      if (text.isEmpty) return;
      final marks = NoteInlineMarks(
        bold: attributes?['bold'] == true,
        italic: attributes?['italic'] == true,
        underline: attributes?['underline'] == true,
        strike: attributes?['strike'] == true,
        textColor: _cleanJsonString(attributes?['color']),
        highlightColor: _cleanJsonString(attributes?['background']),
        link: _cleanJsonString(attributes?['link']),
        inlineCode: attributes?['code'] == true,
      );
      buffer.write(text);
      runs.add(NoteTextRun(text: text, marks: marks));
    }

    void flush() {
      final text = buffer.toString();
      if (text.isEmpty && lineBlockType == null) {
        runs.clear();
        return;
      }
      var type = NoteBlockType.paragraph;
      if (lineBlockType == 'checklist') type = NoteBlockType.checklist;
      if (lineBlockType == 'bulleted') type = NoteBlockType.bulletedList;
      if (lineBlockType == 'numbered') type = NoteBlockType.numberedList;
      if (lineBlockType == 'heading') type = NoteBlockType.heading;
      if (lineBlockType == 'quote') type = NoteBlockType.quote;
      if (lineBlockType == 'code') type = NoteBlockType.codeBlock;
      if (text.isNotEmpty || type != NoteBlockType.paragraph) {
        blocks.add(NoteBlock(
          id: generateNoteBlockId(),
          type: type,
          text: text,
          runs: List<NoteTextRun>.unmodifiable(runs),
          level: headingLevel,
        ));
      }
      buffer.clear();
      runs.clear();
      lineBlockType = null;
      headingLevel = 2;
    }

    for (final rawOp in ops) {
      if (rawOp is! Map) continue;
      final insert = rawOp['insert'];
      if (insert is! String) continue;
      final attributes = rawOp['attributes'] is Map
          ? rawOp['attributes'] as Map
          : null;
      final list = attributes?['list']?.toString();
      if (list == 'checked' || list == 'unchecked') {
        lineBlockType = 'checklist';
      } else if (list == 'bullet') {
        lineBlockType = 'bulleted';
      } else if (list == 'ordered') {
        lineBlockType = 'numbered';
      }
      final header = attributes?['header'];
      if (header is int && header >= 1 && header <= 3) {
        lineBlockType = 'heading';
        headingLevel = header;
      }
      if (attributes?['blockquote'] == true) lineBlockType = 'quote';
      if (attributes?['code-block'] == true) lineBlockType = 'code';

      final parts = insert.split('\n');
      for (var index = 0; index < parts.length; index++) {
        appendRun(parts[index], attributes);
        if (index < parts.length - 1) flush();
      }
    }
    flush();
    return NoteDocument(blocks: blocks);
  }

  String toPlainText({String? title}) {
    final buffer = StringBuffer();
    final cleanTitle = title?.trim() ?? '';
    if (cleanTitle.isNotEmpty) buffer.writeln(cleanTitle);
    for (final block in blocks) {
      String text = '';
      if (block.hasText) {
        text = block.effectiveText.trim();
      } else if (block.type == NoteBlockType.table && block.table != null) {
        text = block.table!.cells
            .map(
              (row) => row
                  .map((cell) => cell.trim())
                  .where((cell) => cell.isNotEmpty)
                  .join(' | '),
            )
            .where((row) => row.isNotEmpty)
            .join('\n');
      } else if (block.type == NoteBlockType.linkCard) {
        text = <String?>[block.linkData?.title, block.linkData?.url]
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .join(' — ');
      } else if (_isReferenceType(block.type)) {
        text = block.reference?.label ?? block.reference?.targetId ?? '';
      } else if (block.caption != null) {
        text = block.caption!.trim();
      }
      if (text.isEmpty) continue;
      if (buffer.isNotEmpty && !buffer.toString().endsWith('\n')) {
        buffer.writeln();
      }
      buffer.writeln(text);
    }
    return buffer.toString().trim();
  }

  List<Map<String, dynamic>> toChecklistProjection() => blocks
      .where((block) => block.type == NoteBlockType.checklist)
      .map((block) => <String, dynamic>{
            'text': block.effectiveText,
            'done': block.checked,
          })
      .toList();

  NoteDocumentStats computeStats() {
    var checklistTotal = 0;
    var checklistChecked = 0;
    var hasImage = false;
    var hasDrawing = false;
    for (final block in blocks) {
      if (block.type == NoteBlockType.checklist) {
        checklistTotal++;
        if (block.checked) checklistChecked++;
      } else if (block.type == NoteBlockType.image) {
        hasImage = true;
      } else if (block.type == NoteBlockType.drawing) {
        hasDrawing = true;
      }
    }
    return NoteDocumentStats(
      checklistTotal: checklistTotal,
      checklistChecked: checklistChecked,
      hasImage: hasImage,
      hasDrawing: hasDrawing,
      blockCount: blocks.length,
    );
  }
}

@immutable
class NoteDocumentStats {
  const NoteDocumentStats({
    required this.checklistTotal,
    required this.checklistChecked,
    required this.hasImage,
    required this.hasDrawing,
    required this.blockCount,
  });

  final int checklistTotal;
  final int checklistChecked;
  final bool hasImage;
  final bool hasDrawing;
  final int blockCount;

  bool get hasChecklist => checklistTotal > 0;
  bool get isEmpty => blockCount == 0;
}

bool _isReferenceType(NoteBlockType type) =>
    type == NoteBlockType.planReference ||
    type == NoteBlockType.recordReference ||
    type == NoteBlockType.noteReference ||
    type == NoteBlockType.categoryReference;

String? _cleanJsonString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String generateNoteBlockId() {
  final ms = DateTime.now().millisecondsSinceEpoch;
  final random = _blockIdCounter.nextInt(0x100000);
  return 'b-${ms.toRadixString(36)}-${random.toRadixString(36).padLeft(4, '0')}';
}

final math.Random _blockIdCounter = math.Random();
