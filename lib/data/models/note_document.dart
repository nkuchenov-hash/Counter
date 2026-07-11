// Part of lib/data/models.dart — Note block document model (Life OS Notes v1).
//
// A versioned block-document envelope serialized into the existing
// `plans.notes_delta` JSON field. Every note is an ordered list of typed
// blocks (paragraph / checklist / heading / image / drawing). Legacy Quill
// Delta notes are converted on read; the new format is written back on the
// first successful user edit.
//
// Pure data/serialization code. No Flutter, no PocketBase, no UI imports.

part of '../models.dart';

/// Versioned block-document envelope format identifier.
const String kLifeOsNotesBlocksFormat = 'lifeos_notes_blocks_v1';

/// Current document version. Bump when the block schema changes in a way the
/// parser cannot safely ignore.
const int kLifeOsNotesBlocksVersion = 1;

/// Maximum total payload size (encoded JSON string) we allow for a single
/// note's notes_delta. Guards against runaway base64 image/drawing blobs
/// bricking PocketBase rows or the local cache.
const int kLifeOsNotesMaxPayloadBytes = 4 * 1024 * 1024; // 4 MiB

/// Soft per-asset (image or drawing) size cap on the raw base64 data URL.
/// Assets larger than this are rejected before insertion.
const int kLifeOsNotesMaxAssetBytes = 2 * 1024 * 1024; // 2 MiB

String _generateBlockId() {
  final ms = DateTime.now().microsecondsSinceEpoch;
  final r = math.Random().nextInt(0xFFFFFF);
  return 'blk_${ms.toRadixString(16)}_${r.toRadixString(16)}';
}

/// Block kind. Each block carries only the fields relevant to its type.
enum NoteBlockType {
  paragraph,
  checklist,
  heading,
  image,
  drawing;

  static NoteBlockType fromString(String? raw) {
    switch (raw) {
      case 'paragraph':
        return NoteBlockType.paragraph;
      case 'checklist':
        return NoteBlockType.checklist;
      case 'heading':
        return NoteBlockType.heading;
      case 'image':
        return NoteBlockType.image;
      case 'drawing':
        return NoteBlockType.drawing;
      default:
        return NoteBlockType.paragraph;
    }
  }

  String get wire => name;
}

/// A single block inside a note document.
///
/// Ids are stable across edits/reorders so the editor can track focus and
/// animate block moves without relying on list indices.
@immutable
class NoteBlock {
  const NoteBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.checked = false,
    this.level = 2,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.color,
    this.imageData,
    this.drawingData,
  });

  final String id;
  final NoteBlockType type;

  /// Paragraph / checklist / heading text.
  final String text;

  /// Checklist only.
  final bool checked;

  /// Heading only (1/2/3).
  final int level;

  /// Whole-block formatting (v1 — matches GLM source model).
  final bool bold;
  final bool italic;
  final bool underline;

  /// Whole-block text color. `null` = auto/default theme color.
  final String? color;

  /// Image only — base64 data URL (e.g. `data:image/jpeg;base64,...`).
  final String? imageData;

  /// Drawing only — base64 PNG data URL.
  final String? drawingData;

  /// Whether this block carries any user-visible text content.
  bool get hasText =>
      type == NoteBlockType.paragraph ||
      type == NoteBlockType.checklist ||
      type == NoteBlockType.heading;

  NoteBlock copyWith({
    NoteBlockType? type,
    String? text,
    bool? checked,
    int? level,
    bool? bold,
    bool? italic,
    bool? underline,
    Object? color = _sentinel,
    Object? imageData = _sentinel,
    Object? drawingData = _sentinel,
  }) {
    return NoteBlock(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      checked: checked ?? this.checked,
      level: level ?? this.level,
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
    );
  }

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'id': id,
      'type': type.wire,
    };
    switch (type) {
      case NoteBlockType.paragraph:
      case NoteBlockType.checklist:
      case NoteBlockType.heading:
        m['text'] = text;
        if (type == NoteBlockType.checklist) m['checked'] = checked;
        if (type == NoteBlockType.heading) m['level'] = level.clamp(1, 3);
        if (bold) m['bold'] = true;
        if (italic) m['italic'] = true;
        if (underline) m['underline'] = true;
        if (color != null) m['color'] = color;
        break;
      case NoteBlockType.image:
        if (imageData != null) m['imageData'] = imageData;
        break;
      case NoteBlockType.drawing:
        if (drawingData != null) m['drawingData'] = drawingData;
        break;
    }
    return m;
  }

  factory NoteBlock.fromJson(Map<String, dynamic> json) {
    final type = NoteBlockType.fromString(json['type']?.toString());
    return NoteBlock(
      id: (json['id']?.toString().trim().isNotEmpty ?? false)
          ? json['id'].toString()
          : generateNoteBlockId(),
      type: type,
      text: (json['text']?.toString() ?? ''),
      checked: _jsonBool(json['checked'], false),
      level: (_jsonInt(json['level'], 2)).clamp(1, 3),
      bold: _jsonBool(json['bold'], false),
      italic: _jsonBool(json['italic'], false),
      underline: _jsonBool(json['underline'], false),
      color: json['color']?.toString().trim().isEmpty == true
          ? null
          : json['color']?.toString(),
      imageData: json['imageData']?.toString(),
      drawingData: json['drawingData']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is NoteBlock && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

const Object _sentinel = Object();

/// Per-note metadata stored in the document envelope.
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

/// Versioned block-document envelope.
///
/// Serialized into `plans.notes_delta`. The Brain owns the lifecycle; the
/// editor/library parse via [NoteDocument.tryParse] once and then operate on
/// the typed model.
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

  bool get isEmpty => blocks.isEmpty || blocks.every((b) => _isBlank(b));

  static bool _isBlank(NoteBlock b) {
    switch (b.type) {
      case NoteBlockType.paragraph:
      case NoteBlockType.checklist:
      case NoteBlockType.heading:
        return b.text.trim().isEmpty;
      case NoteBlockType.image:
        return (b.imageData ?? '').isEmpty;
      case NoteBlockType.drawing:
        return (b.drawingData ?? '').isEmpty;
    }
  }

  NoteDocument copyWith({
    List<NoteBlock>? blocks,
    NoteDocumentMeta? meta,
  }) {
    return NoteDocument(
      format: format,
      version: version,
      meta: meta ?? this.meta,
      blocks: blocks ?? this.blocks,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': format,
        'version': version,
        'meta': meta.toJson(),
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  /// Encodes the document to a JSON string suitable for `plans.notes_delta`.
  String encode() => jsonEncode(toJson());

  /// Attempts to parse a `notes_delta` payload into a NoteDocument.
  ///
  /// Accepts:
  ///  - the new `lifeos_notes_blocks_v1` envelope;
  ///  - a legacy Quill Delta (ops list) — converted into paragraph/checklist/
  ///    heading blocks;
  ///  - `null` / empty / malformed — returns an empty document.
  ///
  /// Also accepts the legacy `notes_plain` string and a legacy `checklist` so
  /// the caller can fold them in when the delta alone is empty.
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

    // New envelope?
    if (decoded is Map<String, dynamic> &&
        decoded['format'] == kLifeOsNotesBlocksFormat) {
      final blocksRaw = decoded['blocks'];
      final blocks = <NoteBlock>[];
      if (blocksRaw is List) {
        for (final b in blocksRaw) {
          if (b is Map<String, dynamic>) {
            blocks.add(NoteBlock.fromJson(b));
          }
        }
      }
      final metaRaw = decoded['meta'];
      final meta = metaRaw is Map<String, dynamic>
          ? NoteDocumentMeta.fromJson(metaRaw)
          : const NoteDocumentMeta();
      return NoteDocument(
        format: kLifeOsNotesBlocksFormat,
        version: _jsonInt(decoded['version'], kLifeOsNotesBlocksVersion),
        meta: meta,
        blocks: blocks,
      );
    }

    // Legacy Quill Delta: a list (or {"ops": [...]}) of ops.
    if (decoded is List || (decoded is Map && decoded['ops'] is List)) {
      final doc = _fromLegacyQuillDelta(decoded);
      // Fold in checklist/plain if the delta produced nothing useful.
      if (doc.blocks.isEmpty) {
        return _fromLegacyPlainAndChecklist(notesPlain, checklist);
      }
      return doc;
    }

    return _fromLegacyPlainAndChecklist(notesPlain, checklist);
  }

  static NoteDocument _fromLegacyPlainAndChecklist(
    String? notesPlain,
    List<Map<String, dynamic>>? checklist,
  ) {
    final blocks = <NoteBlock>[];
    if (checklist != null && checklist.isNotEmpty) {
      for (final item in checklist) {
        final text = (item['text']?.toString() ?? '').trim();
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
    final plain = (notesPlain ?? '').trim();
    if (plain.isNotEmpty) {
      // Strip the backlog-idea link prefix and split into paragraph blocks
      // by line so multi-line notes round-trip cleanly.
      var body = plain;
      const prefix = 'LIFEOS_LINK::';
      if (body.startsWith(prefix)) {
        body = body.substring(prefix.length).trim();
        final nl = body.indexOf('\n');
        if (nl >= 0) {
          final firstLine = body.substring(0, nl).trim();
          if (firstLine.startsWith('http://') ||
              firstLine.startsWith('https://')) {
            body = body.substring(nl + 1).trim();
          }
        }
      }
      for (final line in body.split('\n')) {
        final t = line.trim();
        if (t.isEmpty) continue;
        blocks.add(NoteBlock(
          id: generateNoteBlockId(),
          type: NoteBlockType.paragraph,
          text: t,
        ));
      }
    }
    return NoteDocument(blocks: blocks);
  }

  /// Best-effort conversion of a legacy Quill Delta into NoteBlocks.
  static NoteDocument _fromLegacyQuillDelta(dynamic decoded) {
    List ops;
    if (decoded is List) {
      ops = decoded;
    } else if (decoded is Map && decoded['ops'] is List) {
      ops = decoded['ops'] as List;
    } else {
      return const NoteDocument();
    }

    final blocks = <NoteBlock>[];
    final buffer = StringBuffer();
    bool bold = false;
    bool italic = false;
    bool underline = false;
    String? color;
    String? blockType; // 'list' bullet/ordered, 'header' level

    void flush() {
      final text = buffer.toString();
      if (text.isEmpty && blockType == null) {
        buffer.clear();
        return;
      }
      if (blockType == 'list') {
        blocks.add(NoteBlock(
          id: generateNoteBlockId(),
          type: NoteBlockType.checklist,
          text: text,
          checked: false,
          bold: bold,
          italic: italic,
          underline: underline,
          color: color,
        ));
      } else if (blockType == 'header') {
        blocks.add(NoteBlock(
          id: generateNoteBlockId(),
          type: NoteBlockType.heading,
          text: text,
          level: 2,
          bold: bold,
          italic: italic,
          underline: underline,
          color: color,
        ));
      } else {
        if (text.isNotEmpty) {
          blocks.add(NoteBlock(
            id: generateNoteBlockId(),
            type: NoteBlockType.paragraph,
            text: text,
            bold: bold,
            italic: italic,
            underline: underline,
            color: color,
          ));
        }
      }
      buffer.clear();
      bold = false;
      italic = false;
      underline = false;
      color = null;
      blockType = null;
    }

    for (final rawOp in ops) {
      if (rawOp is! Map) continue;
      final insert = rawOp['insert'];
      if (insert == null) {
        // Pure format op (rare). Apply attributes to the buffer state.
        final attrs = rawOp['attributes'];
        if (attrs is Map) {
          if (attrs['bold'] == true) bold = true;
          if (attrs['italic'] == true) italic = true;
          if (attrs['underline'] == true) underline = true;
          if (attrs['color'] is String) color = attrs['color'].toString();
        }
        continue;
      }
      final s = insert.toString();
      final attrs = rawOp['attributes'];
      bool lineBold = bold;
      bool lineItalic = italic;
      bool lineUnderline = underline;
      String? lineColor = color;
      String? lineBlockType = blockType;
      if (attrs is Map) {
        if (attrs['bold'] == true) lineBold = true;
        if (attrs['italic'] == true) lineItalic = true;
        if (attrs['underline'] == true) lineUnderline = true;
        if (attrs['color'] is String) lineColor = attrs['color'].toString();
        final listAttr = attrs['list'];
        if (listAttr is String && listAttr.isNotEmpty) {
          lineBlockType = 'list';
        }
        final headerAttr = attrs['header'];
        if (headerAttr is int && headerAttr > 0) {
          lineBlockType = 'header';
        }
      }

      if (s.contains('\n')) {
        // Split on newlines: each segment before a \n is a block.
        final parts = s.split('\n');
        for (var i = 0; i < parts.length - 1; i++) {
          buffer.write(parts[i]);
          bold = lineBold;
          italic = lineItalic;
          underline = lineUnderline;
          color = lineColor;
          blockType = lineBlockType;
          flush();
        }
        final last = parts.last;
        if (last.isNotEmpty) {
          buffer.write(last);
        }
      } else {
        buffer.write(s);
      }
    }
    flush();
    return NoteDocument(blocks: blocks);
  }

  // ---- Projections (deterministic mirrors) -------------------------------

  /// Plain-text projection of title + text blocks, used to keep
  /// `plans.notes_plain` synchronized for search and legacy display.
  /// [title] is optional and prepended on its own line when non-empty.
  String toPlainText({String? title}) {
    final buf = StringBuffer();
    final t = (title ?? '').trim();
    if (t.isNotEmpty) {
      buf.write(t);
      buf.write('\n');
    }
    for (final b in blocks) {
      if (!b.hasText) continue;
      final txt = b.text.trim();
      if (txt.isEmpty) continue;
      if (buf.isNotEmpty) buf.write('\n');
      buf.write(txt);
    }
    return buf.toString().trim();
  }

  /// Compatibility projection of checklist blocks into the legacy
  /// `plans.checklist` JSON array shape (`[{text, done}]`).
  List<Map<String, dynamic>> toChecklistProjection() {
    final out = <Map<String, dynamic>>[];
    for (final b in blocks) {
      if (b.type != NoteBlockType.checklist) continue;
      out.add({'text': b.text, 'done': b.checked});
    }
    return out;
  }

  /// Quick stats for library card previews. Computed once per card build,
  /// never inside scroll hot paths.
  NoteDocumentStats computeStats() {
    int checklistTotal = 0;
    int checklistChecked = 0;
    bool hasImage = false;
    bool hasDrawing = false;
    for (final b in blocks) {
      if (b.type == NoteBlockType.checklist) {
        checklistTotal++;
        if (b.checked) checklistChecked++;
      } else if (b.type == NoteBlockType.image) {
        hasImage = true;
      } else if (b.type == NoteBlockType.drawing) {
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

/// Generates a short, stable, unique-enough block id for local use.
/// Format: `b-<base36 millis>-<base36 random>`. Stable across the note's
/// lifetime; only regenerated when a brand-new block is created.
String generateNoteBlockId() {
  final ms = DateTime.now().millisecondsSinceEpoch;
  final r = _blockIdCounter.nextInt(0x100000);
  return 'b-${ms.toRadixString(36)}-${r.toRadixString(36).padLeft(4, '0')}';
}

final math.Random _blockIdCounter = math.Random();
