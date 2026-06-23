// One-shot: extract EN/RU from dictionary.dart inline _l10nCore into langs/*.dart
import 'dart:io';

void main() {
  final dict = File('lib/l10n/dictionary.dart').readAsStringSync();
  for (final locale in ['en', 'ru']) {
    final varName = locale == 'en' ? 'kEnL10n' : 'kRuL10n';
    final startMarker = "'$locale': {";
    final start = dict.indexOf(startMarker);
    if (start < 0) {
      stderr.writeln('Missing $startMarker');
      exitCode = 1;
      return;
    }
    var i = start + startMarker.length;
    var depth = 1;
    while (i < dict.length && depth > 0) {
      final c = dict[i];
      if (c == '{') depth++;
      if (c == '}') depth--;
      i++;
    }
    final body = dict.substring(start + startMarker.length, i - 1);
    final out = StringBuffer()
      ..writeln('// App strings (${locale.toUpperCase()}).')
      ..writeln()
      ..writeln('const Map<String, String> $varName = {')
      ..write(body.trim())
      ..writeln()
      ..writeln('};');
    File('lib/l10n/langs/$locale.dart').writeAsStringSync(out.toString());
    stdout.writeln('$locale: ${body.split("': ").length} entries');
  }
}
