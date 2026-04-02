// ---------------------------------------------------------------------------
// SMART INPUT — Parse natural time hints from a planning task title (Phase 1).
// Uses profile-agnostic wall hour/minute; caller binds to [baseDate] for the day.
// ---------------------------------------------------------------------------

/// Result of parsing a draft title for an embedded clock time.
class SmartTimeParseResult {
  const SmartTimeParseResult({
    required this.cleanedTitle,
    required this.hour,
    required this.minute,
  });

  /// Title text after removing the matched time phrase (trimmed).
  final String cleanedTitle;

  /// Wall-clock hour 0–23 on [baseDate] (caller builds [wallDateTime]).
  final int hour;

  /// Wall-clock minute 0–59.
  final int minute;

  /// Naive wall [DateTime] on the given calendar day (isUtc: false).
  DateTime wallDateTimeOn(DateTime baseDate) => DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        hour,
        minute,
      );
}

/// Parses times from free text without treating unrelated numbers as times.
///
/// **Regex strategy (strict):**
/// 1. `\b([01]?\d|2[0-3]):([0-5]\d)\b` — explicit clock `19:30` / `09:05`.
/// 2. Trailing `HH:mm` after whitespace (EOL).
/// 3. Trailing **four digits** `HHmm` (e.g. `1230` → 12:30).
/// 4. Trailing hour only: `[\s]+(2[0-3]|1[0-9]|[0-9])\s*$` (e.g. `Ужин 12`).
/// 5. `at` / `@` / **preposition в** only after start or whitespace.
///
/// First matching rule wins.
abstract final class SmartInputParser {
  static final RegExp _colonTime = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)\b');

  /// Trailing ` … HH:mm` at end of string (space before hours).
  static final RegExp _trailingColonTime = RegExp(
    r'[\s\u00A0]+([01]?\d|2[0-3]):([0-5]\d)\s*$',
  );

  /// Trailing ` … HHmm` four digits at end (12:30 from `1230`).
  static final RegExp _trailingHhmmCompact = RegExp(r'[\s\u00A0]+(\d{4})\s*$');

  /// Requires space/start before `at|@|в` so Cyrillic words are never split on `в`.
  static final RegExp _atWordTime = RegExp(
    r'(?:^|[\s\u00A0])(?:at|@|в)\s*([01]?\d|2[0-3])(?::([0-5]\d))?(?=\s|$)',
    caseSensitive: false,
  );

  /// Lenient trailing hour: whitespace run + hour 0–23 at end.
  static final RegExp _trailingHourAfterSpace = RegExp(
    r'[\s\u00A0]+(2[0-3]|1[0-9]|[0-9])\s*$',
  );

  /// Returns null if no time token matched (caller should not mutate the field).
  static SmartTimeParseResult? parseTitleForScheduledTime(String raw) {
    final input = raw.replaceAll('\u00A0', ' ');
    if (input.trim().isEmpty) return null;

    Match? m = _colonTime.firstMatch(input);
    if (m != null) {
      final h = int.parse(m.group(1)!);
      final min = int.parse(m.group(2)!);
      final cleaned =
          _collapseSpace(input.replaceRange(m.start, m.end, '')).trim();
      return SmartTimeParseResult(cleanedTitle: cleaned, hour: h, minute: min);
    }

    final trimmedRight = input.trimRight();

    m = _trailingColonTime.firstMatch(trimmedRight);
    if (m != null) {
      final skip = m.start > 0 &&
          RegExp(r'[\d:]').hasMatch(trimmedRight[m.start - 1]);
      if (!skip) {
        final h = int.parse(m.group(1)!);
        final min = int.parse(m.group(2)!);
        final cleaned = _collapseSpace(
          trimmedRight.replaceRange(m.start, m.end, ''),
        ).trim();
        return SmartTimeParseResult(
            cleanedTitle: cleaned, hour: h, minute: min);
      }
    }

    m = _trailingHhmmCompact.firstMatch(trimmedRight);
    if (m != null) {
      final skip = m.start > 0 &&
          RegExp(r'[\d:]').hasMatch(trimmedRight[m.start - 1]);
      if (!skip) {
        final digits = m.group(1)!;
        final h = int.parse(digits.substring(0, 2));
        final min = int.parse(digits.substring(2, 4));
        if (h >= 0 && h <= 23 && min >= 0 && min <= 59) {
          final cleaned = _collapseSpace(
            trimmedRight.replaceRange(m.start, m.end, ''),
          ).trim();
          return SmartTimeParseResult(
              cleanedTitle: cleaned, hour: h, minute: min);
        }
      }
    }

    m = _trailingHourAfterSpace.firstMatch(trimmedRight);
    if (m != null) {
      if (m.start > 0) {
        final beforeWhitespaceRun = trimmedRight[m.start - 1];
        if (RegExp(r'[\d:]').hasMatch(beforeWhitespaceRun)) {
          return null;
        }
      }
      final h = int.parse(m.group(1)!);
      final cleaned =
          _collapseSpace(trimmedRight.replaceRange(m.start, m.end, '')).trim();
      return SmartTimeParseResult(cleanedTitle: cleaned, hour: h, minute: 0);
    }

    m = _atWordTime.firstMatch(input);
    if (m != null) {
      final h = int.parse(m.group(1)!);
      final min =
          m.group(2) != null ? int.parse(m.group(2)!) : 0;
      final cleaned =
          _collapseSpace(input.replaceRange(m.start, m.end, '')).trim();
      return SmartTimeParseResult(
        cleanedTitle: cleaned,
        hour: h,
        minute: min,
      );
    }

    return null;
  }

  static String _collapseSpace(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
