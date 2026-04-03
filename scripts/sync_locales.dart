// Locale sync: lib/l10n/langs/en.dart is SSOT. Missing keys in other lang files
// get appended before the map's closing `}` as '[TODO] <English value>'.
//
// Run from project root:
//   dart run scripts/sync_locales.dart

import 'dart:convert';
import 'dart:io';

const _todoPrefix = '[TODO] ';

void main(List<String> args) {
  final root = _projectRoot();
  final langsDir = Directory(_join(root, 'lib', 'l10n', 'langs'));
  final enPath = File(_join(langsDir.path, 'en.dart'));

  if (!enPath.existsSync()) {
    stderr.writeln('Missing ${enPath.path}');
    exitCode = 1;
    return;
  }

  final enContent = enPath.readAsStringSync(encoding: utf8);
  final enRegion = _findL10nMap(enContent);
  if (enRegion == null) {
    stderr.writeln('Could not find kEnL10n map in en.dart');
    exitCode = 1;
    return;
  }
  if (enRegion.name != 'kEnL10n') {
    stderr.writeln('Expected kEnL10n in en.dart, found ${enRegion.name}');
    exitCode = 1;
    return;
  }

  final inner = enContent.substring(enRegion.openBrace + 1, enRegion.closeBrace);
  List<(String, String)> enOrdered;
  try {
    enOrdered = _parseOrderedEntries(inner);
  } on FormatException catch (e) {
    stderr.writeln('Failed to parse en.dart map body: $e');
    exitCode = 1;
    return;
  }
  final enMap = <String, String>{for (final e in enOrdered) e.$1: e.$2};

  if (enOrdered.isEmpty) {
    stderr.writeln('No entries parsed from en.dart — aborting');
    exitCode = 1;
    return;
  }

  var changedFiles = 0;
  var injectedTotal = 0;

  for (final entity in langsDir.listSync(followLinks: false)) {
    if (entity is! File || !_endsWith(entity.path, '.dart')) continue;
    if (_basename(entity.path) == 'en.dart') continue;

    final path = entity.path;
    final text = File(path).readAsStringSync(encoding: utf8);
    final region = _findL10nMap(text);
    if (region == null) {
      stderr.writeln('Skip (no k*L10n map): $path');
      continue;
    }

    final tInner = text.substring(region.openBrace + 1, region.closeBrace);
    List<(String, String)> tParsed;
    try {
      tParsed = _parseOrderedEntries(tInner);
    } on FormatException catch (e) {
      stderr.writeln('Skip (parse error in ${_basename(path)}): $e');
      continue;
    }
    final existing = tParsed.map((e) => e.$1).toSet();

    final missing = <(String, String)>[];
    for (final e in enOrdered) {
      if (!existing.contains(e.$1)) {
        missing.add((e.$1, enMap[e.$1] ?? e.$2));
      }
    }

    if (missing.isEmpty) {
      stdout.writeln('OK ${_basename(path)}');
      continue;
    }

    final injection = missing
        .map(
          (e) =>
              "    '${_escapeDartSingleQuotedKey(e.$1)}': ${_dartStringLiteralForValue('$_todoPrefix${e.$2}')},",
        )
        .join('\n');

    final beforeClose = text.substring(0, region.closeBrace);
    final afterClose = text.substring(region.closeBrace);
    final needsNl = !beforeClose.endsWith('\n') && beforeClose.isNotEmpty;
    final updated =
        '$beforeClose${needsNl ? '\n' : ''}$injection\n$afterClose';

    File(path).writeAsStringSync(updated, encoding: utf8);
    changedFiles++;
    injectedTotal += missing.length;
    stdout.writeln(
      'Updated ${_basename(path)}: +${missing.length} key(s) — ${missing.map((e) => e.$1).join(', ')}',
    );
  }

  stdout.writeln(
    '\nDone. Files touched: $changedFiles, keys injected: $injectedTotal',
  );
}

String _projectRoot() {
  final script = Platform.script.toFilePath();
  final dir = File(script).parent.path;
  return Directory(_join(dir, '..')).absolute.resolveSymbolicLinksSync();
}

String _join(String a, [String? b, String? c, String? d]) {
  var p = a;
  if (b != null) p = '$p${Platform.pathSeparator}$b';
  if (c != null) p = '$p${Platform.pathSeparator}$c';
  if (d != null) p = '$p${Platform.pathSeparator}$d';
  return p;
}

String _basename(String path) {
  final i = path.lastIndexOf(Platform.pathSeparator);
  if (i < 0 || i >= path.length - 1) return path;
  return path.substring(i + 1);
}

bool _endsWith(String path, String suffix) {
  return path.length >= suffix.length &&
      path.substring(path.length - suffix.length) == suffix;
}

/// Map declaration: `const Map<String, String> kXxxL10n = {`
final _mapDecl = RegExp(
  r'const\s+Map<String,\s*String>\s+(k\w+L10n)\s*=\s*\{',
  multiLine: true,
);

class _MapRegion {
  _MapRegion({
    required this.name,
    required this.openBrace,
    required this.closeBrace,
  });
  final String name;
  final int openBrace;
  final int closeBrace;
}

_MapRegion? _findL10nMap(String content) {
  final m = _mapDecl.firstMatch(content);
  if (m == null) return null;
  final open = m.end - 1;
  if (open < 0 || open >= content.length || content[open] != '{') {
    return null;
  }
  final close = _indexOfMatchingBrace(content, open);
  if (close == null) return null;
  return _MapRegion(name: m.group(1)!, openBrace: open, closeBrace: close);
}

/// First `}` that balances [openBrace] (`{`), skipping `{`/`}` inside literals.
int? _indexOfMatchingBrace(String s, int openBrace) {
  var depth = 1;
  var i = openBrace + 1;
  var inSingle = false;
  var inDouble = false;
  final n = s.length;
  while (i < n && depth > 0) {
    final c = s.codeUnitAt(i);
    if (inSingle) {
      if (c == 0x5c /* \ */ && i + 1 < n) {
        i += 2;
        continue;
      }
      if (c == 0x27 /* ' */) inSingle = false;
      i++;
      continue;
    }
    if (inDouble) {
      if (c == 0x5c && i + 1 < n) {
        i += 2;
        continue;
      }
      if (c == 0x22 /* " */) inDouble = false;
      i++;
      continue;
    }
    if (c == 0x27) {
      inSingle = true;
      i++;
      continue;
    }
    if (c == 0x22) {
      inDouble = true;
      i++;
      continue;
    }
    if (c == 0x7b /* { */) {
      depth++;
      i++;
      continue;
    }
    if (c == 0x7d /* } */) {
      depth--;
      if (depth == 0) return i;
      i++;
      continue;
    }
    i++;
  }
  return null;
}

void _skipWhitespaceAndCommas(String s, List<int> posRef) {
  var i = posRef[0];
  final n = s.length;
  while (i < n) {
    final c = s.codeUnitAt(i);
    if (c == 0x20 ||
        c == 0x09 ||
        c == 0x0a ||
        c == 0x0d ||
        c == 0x2c /* , */) {
      i++;
      continue;
    }
    break;
  }
  posRef[0] = i;
}

(String, int) _readSingleQuoted(String s, int start) {
  final n = s.length;
  if (start >= n || s.codeUnitAt(start) != 0x27) {
    throw FormatException("Expected ' at $start");
  }
  var i = start + 1;
  final buf = StringBuffer();
  while (i < n) {
    final c = s.codeUnitAt(i);
    if (c == 0x5c) {
      if (i + 1 >= n) throw FormatException('Dangling escape');
      buf.writeCharCode(s.codeUnitAt(i + 1));
      i += 2;
      continue;
    }
    if (c == 0x27) {
      return (buf.toString(), i + 1);
    }
    buf.writeCharCode(c);
    i++;
  }
  throw FormatException('Unterminated single-quoted string');
}

(String, int) _readDoubleQuoted(String s, int start) {
  final n = s.length;
  if (start >= n || s.codeUnitAt(start) != 0x22) {
    throw FormatException('Expected " at $start');
  }
  var i = start + 1;
  final buf = StringBuffer();
  while (i < n) {
    final c = s.codeUnitAt(i);
    if (c == 0x5c) {
      if (i + 1 >= n) throw FormatException('Dangling escape');
      buf.writeCharCode(s.codeUnitAt(i + 1));
      i += 2;
      continue;
    }
    if (c == 0x22) {
      return (buf.toString(), i + 1);
    }
    buf.writeCharCode(c);
    i++;
  }
  throw FormatException('Unterminated double-quoted string');
}

(String, int) _readStringLiteral(String s, int start) {
  if (start >= s.length) throw FormatException('EOF at value');
  if (s.codeUnitAt(start) == 0x27) return _readSingleQuoted(s, start);
  if (s.codeUnitAt(start) == 0x22) return _readDoubleQuoted(s, start);
  throw FormatException('Value must start with \' or " at $start');
}

/// Ordered key/value pairs inside the map body (between `{` and balancing `}`).
List<(String, String)> _parseOrderedEntries(String inner) {
  final out = <(String, String)>[];
  final pos = <int>[0];
  final n = inner.length;
  while (true) {
    _skipWhitespaceAndCommas(inner, pos);
    if (pos[0] >= n) break;
    final keyPair = _readSingleQuoted(inner, pos[0]);
    final key = keyPair.$1;
    pos[0] = keyPair.$2;

    _skipWhitespaceAndCommas(inner, pos);
    if (pos[0] >= n || inner.codeUnitAt(pos[0]) != 0x3a /* : */) {
      throw FormatException('Expected : after key "$key"');
    }
    pos[0]++;

    _skipWhitespaceAndCommas(inner, pos);
    final valPair = _readStringLiteral(inner, pos[0]);
    out.add((key, valPair.$1));
    pos[0] = valPair.$2;
  }
  return out;
}

String _escapeDartSingleQuotedKey(String key) {
  return key.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}

String _escapeDartSingleQuotedContent(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}

/// Dart source literal for map value: prefers single quotes if unambiguous.
String _dartStringLiteralForValue(String value) {
  var hasSingle = false;
  var hasDollar = false;
  for (final r in value.runes) {
    if (r == 0x27) hasSingle = true;
    if (r == 0x24) hasDollar = true;
  }
  if (!hasSingle &&
      !hasDollar &&
      !value.contains('\n') &&
      !value.contains(r'\')) {
    return "'${_escapeDartSingleQuotedContent(value)}'";
  }
  final buf = StringBuffer('"');
  for (final cu in value.codeUnits) {
    switch (cu) {
      case 0x5c:
        buf.write(r'\\');
        break;
      case 0x22:
        buf.write(r'\"');
        break;
      case 0x24:
        buf.write(r'\$');
        break;
      case 0x0a:
        buf.write(r'\n');
        break;
      case 0x0d:
        buf.write(r'\r');
        break;
      case 0x09:
        buf.write(r'\t');
        break;
      default:
        buf.write(String.fromCharCode(cu));
    }
  }
  buf.write('"');
  return buf.toString();
}
