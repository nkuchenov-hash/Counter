// Pure helpers for converting between a Quill document and Markdown text.
//
// Scope: a small, dependency-free subset that covers the formatting already
// supported by the editor (B/I/U, strike, lists, checklist, link, divider).
// We deliberately avoid pulling a third-party markdown package because that
// would introduce a new dependency surface and migration risk; the helper is
// a best-effort MVP for copy/paste convenience, not a full markdown parser.

import 'dart:convert';

/// Converts a Quill Delta JSON string into Markdown text.
///
/// - bold → `**...**`
/// - italic → `*...*`
/// - underline → `<u>...</u>` (Markdown has no native underline) — escaped as
///   literal angle brackets in the output, kept as the conventional marker
/// - strike → `~~...~~`
/// - link → `[text](url)`
/// - bullet list → `- item`
/// - numbered list → `1. item`
/// - checklist (checked/unchecked) → `- [x] item` / `- [ ] item`
/// - divider (image with `divider` alt) → `---`
///
/// Returns an empty string on invalid input.
String quillDeltaJsonToMarkdown(String? deltaJson) {
  final raw = deltaJson?.trim() ?? '';
  if (raw.isEmpty) return '';
  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return '';
  }
  if (decoded is! List) return '';

  final sb = StringBuffer();
  int? lastListType; // 1=bullet, 2=numbered, 3=checklist
  int numberedCounter = 0;

  for (final op in decoded) {
    if (op is! Map) continue;
    final insert = op['insert'];
    if (insert == null) continue;
    final text = insert is String ? insert : insert.toString();
    final attrs = op['attributes'] is Map
        ? Map<String, dynamic>.from(op['attributes'] as Map)
        : <String, dynamic>{};

    if (text == '\n' || text == '\r\n') {
      // Block-level marker. Quill embeds block attributes on the trailing '\n'.
      final blockList = attrs['list'];
      if (blockList == null) {
        lastListType = null;
        numberedCounter = 0;
        continue;
      }
      continue;
    }

    final listAttr = attrs['list'];
    String? listMarker;
    int newLastListType = lastListType ?? 0;
    int newNumberedCounter = numberedCounter;
    if (listAttr == 'bullet') {
      listMarker = '- ';
      newLastListType = 1;
    } else if (listAttr == 'ordered') {
      newNumberedCounter += 1;
      listMarker = '$newNumberedCounter. ';
      newLastListType = 2;
    } else if (listAttr == 'checked' || listAttr == 'unchecked') {
      listMarker = listAttr == 'checked' ? '- [x] ' : '- [ ] ';
      newLastListType = 3;
    } else {
      newLastListType = 0;
      newNumberedCounter = 0;
    }

    // Image embed as divider.
    final image = attrs['image'];
    if (image is String && image.contains('lifeos-divider')) {
      if (sb.isNotEmpty && !sb.toString().endsWith('\n')) {
        sb.write('\n');
      }
      sb.writeln('---');
      lastListType = newLastListType;
      numberedCounter = newNumberedCounter;
      continue;
    }

    String piece = text;

    final link = attrs['link'];
    if (link is String && link.trim().isNotEmpty) {
      piece = '[$piece]($link)';
    } else {
      if (attrs['bold'] == true) piece = '**$piece**';
      if (attrs['italic'] == true) piece = '*$piece*';
      if (attrs['underline'] == true) piece = '<u>$piece</u>';
      if (attrs['strike'] == true) piece = '~~$piece~~';
    }

    if (listMarker != null) {
      if (sb.isNotEmpty && !sb.toString().endsWith('\n')) {
        sb.write('\n');
      }
      sb.write(listMarker);
    } else if (lastListType != null && lastListType != 0) {
      // We just exited a list block.
      if (sb.isNotEmpty && !sb.toString().endsWith('\n')) {
        sb.write('\n');
      }
    }

    sb.write(piece);
    lastListType = newLastListType;
    numberedCounter = newNumberedCounter;
  }

  return sb.toString().trim();
}

/// Converts a Markdown text into a Quill Delta JSON string.
///
/// Supports the same subset as [quillDeltaJsonToMarkdown]. Inline runs of
/// emphasis markers (`**`, `*`, `~~`, `<u>`) are applied to the same insertion
/// when adjacent. Lists are detected per-line.
String? markdownToQuillDeltaJson(String? markdown) {
  final src = markdown?.trim() ?? '';
  if (src.isEmpty) return null;

  final ops = <Map<String, dynamic>>[];
  final lines = src.split(RegExp(r'\r?\n'));

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    // Divider
    if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
      ops.add(<String, dynamic>{
        'insert': '\n',
        'attributes': <String, dynamic>{
          'image': 'lifeos-divider',
        },
      });
      continue;
    }

    String text = line;
    Map<String, dynamic>? blockAttrs;

    // Checklist
    final checkMatch = RegExp(r'^[-*]\s+\[(?<x>[ xX])\]\s+(?<body>.*)$')
        .firstMatch(text);
    final bulletMatch =
        RegExp(r'^[-*]\s+(?<body>.*)$').firstMatch(text);
    final orderedMatch =
        RegExp(r'^\d+\.\s+(?<body>.*)$').firstMatch(text);

    if (checkMatch != null) {
      final checked =
          (checkMatch.namedGroup('x') ?? ' ').toLowerCase() == 'x';
      blockAttrs = <String, dynamic>{
        'list': checked ? 'checked' : 'unchecked',
      };
      text = checkMatch.namedGroup('body') ?? '';
    } else if (orderedMatch != null) {
      blockAttrs = <String, dynamic>{'list': 'ordered'};
      text = orderedMatch.namedGroup('body') ?? '';
    } else if (bulletMatch != null) {
      blockAttrs = <String, dynamic>{'list': 'bullet'};
      text = bulletMatch.namedGroup('body') ?? '';
    }

    // Inline markdown parse within the line.
    final inlineOps = _parseInlineMarkdown(text);
    ops.addAll(inlineOps);

    ops.add(<String, dynamic>{
      'insert': '\n',
      if (blockAttrs != null) 'attributes': blockAttrs,
    });
  }

  if (ops.isEmpty) return null;
  return jsonEncode(ops);
}

/// Parse a single line of markdown into a list of Quill ops.
///
/// Supported patterns: `**bold**`, `*italic*`, `~~strike~~`, `<u>underline</u>`,
/// `[text](url)`. Underline wrapping spans the entire match because Markdown
/// has no native underline; this is a deliberate, documented compromise.
List<Map<String, dynamic>> _parseInlineMarkdown(String text) {
  final out = <Map<String, dynamic>>[];
  // Combined regex: link, bold, italic, strike, underline.
  final pattern = RegExp(
    r'\[(?<ltext>[^\]]+)\]\((?<lurl>[^)]+)\)'
    r'|\*\*(?<bold>[^*]+)\*\*'
    r'|\*(?<italic>[^*]+)\*'
    r'|~~(?<strike>[^~]+)~~'
    r'|<u>(?<underline>[^<]+)</u>',
  );

  var lastEnd = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > lastEnd) {
      out.add(<String, dynamic>{'insert': text.substring(lastEnd, m.start)});
    }
    final linkText = m.namedGroup('ltext');
    final linkUrl = m.namedGroup('lurl');
    if (linkText != null && linkUrl != null) {
      out.add(<String, dynamic>{
        'insert': linkText,
        'attributes': <String, dynamic>{'link': linkUrl},
      });
    } else if (m.namedGroup('bold') != null) {
      out.add(<String, dynamic>{
        'insert': m.namedGroup('bold'),
        'attributes': <String, dynamic>{'bold': true},
      });
    } else if (m.namedGroup('italic') != null) {
      out.add(<String, dynamic>{
        'insert': m.namedGroup('italic'),
        'attributes': <String, dynamic>{'italic': true},
      });
    } else if (m.namedGroup('strike') != null) {
      out.add(<String, dynamic>{
        'insert': m.namedGroup('strike'),
        'attributes': <String, dynamic>{'strike': true},
      });
    } else if (m.namedGroup('underline') != null) {
      out.add(<String, dynamic>{
        'insert': m.namedGroup('underline'),
        'attributes': <String, dynamic>{'underline': true},
      });
    }
    lastEnd = m.end;
  }
  if (lastEnd < text.length) {
    out.add(<String, dynamic>{'insert': text.substring(lastEnd)});
  }
  if (out.isEmpty) {
    out.add(<String, dynamic>{'insert': text});
  }
  return out;
}

/// Builds a delta op that inserts a horizontal-rule "divider" embed. The
/// canonical editor uses a Quill image embed with the magic alt text
/// `lifeos-divider`. The renderer treats it as a visual divider.
Map<String, dynamic> dividerDeltaOp() {
  return <String, dynamic>{
    'insert': '\n',
    'attributes': <String, dynamic>{'image': 'lifeos-divider'},
  };
}
