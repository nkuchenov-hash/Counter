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

/// Embedded **start → end** wall-clock range; caller binds to [baseDate] for the day.
class SmartTimeRangeParseResult {
  const SmartTimeRangeParseResult({
    required this.cleanedTitle,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  final String cleanedTitle;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  DateTime startWallOn(DateTime baseDate) => DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        startHour,
        startMinute,
      );

  DateTime endWallOn(DateTime baseDate) => DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        endHour,
        endMinute,
      );
}

/// Parses times from free text without treating unrelated numbers as times.
///
/// **Regex strategy (strict):**
/// 0. [sanitizeSttTimeArtifacts] + RU spoken phrases + spaced `H mm` (STT often gives `9 0-0`, `9 00`).
/// 1. Word-bounded `HH:mm` / `HH.mm` (and comma or fullwidth dot normalized to `.` first).
/// 2. **Spaced** `H mm` / `H m` (e.g. STT `9 00` without colon).
/// 3. Trailing ` … HH[:.]mm` at EOL (after one or more spaces), not glued to another number/date chunk.
/// 4. Trailing **four digits** `HHmm` (e.g. `1230` → 12:30).
/// 5. Trailing hour only: `[\s]+(2[0-3]|1[0-9]|[0-9])\s*$` (e.g. `Ужин 12`).
/// 6. `at` / `@` / **в** / **на** after start or whitespace, optional `:` or `.` before minutes.
///
/// Dot form is always **clock time** (minute 00–59), not `dd.mm` calendar shorthand.
/// First matching rule wins.
abstract final class SmartInputParser {
  static int _minuteGroupToInt(String? raw) {
    final s = raw?.trim() ?? '';
    if (s.isEmpty) return 0;
    if (s.length == 1) {
      final d = int.tryParse(s);
      if (d == null) return 0;
      return d.clamp(0, 9);
    }
    final v = int.tryParse(s);
    if (v == null) return 0;
    if (v < 0) return 0;
    if (v > 59) return 59;
    return v;
  }

  /// Normalizes fullwidth / middle dots and **comma** between hour and minute (`13,40` → `13.40`).
  static String normalizeClockSeparators(String raw) {
    var t = raw.replaceAll('\u00A0', ' ');
    t = t
        .replaceAll('\uFF0E', '.')
        .replaceAll('\u2024', '.')
        .replaceAll('\u2219', '.')
        .replaceAll('\u00B7', '.');
    t = t.replaceAllMapped(
      RegExp(r'(?<![\d,])([01]?\d|2[0-3]),([0-5]?\d)(?![\d,])'),
      (m) => '${m[1]}.${m[2]}',
    );
    return t;
  }

  /// STT often outputs minute `00` as `0-0`. Collapse that **before** clock regexes.
  ///
  /// Also fixes `9-00` → `9:00` when minutes are `00` only (avoids clobbering range `10-12`).
  static String sanitizeSttTimeArtifacts(String raw) {
    var t = raw;
    t = t.replaceAllMapped(
      RegExp(r'\b([01]?\d|2[0-3])\s+0\s*[-–—]\s*0\b'),
      (m) => '${m[1]} 00',
    );
    t = t.replaceAllMapped(
      RegExp(r'\b0\s*[-–—]\s*0\b'),
      (_) => '00',
    );
    t = t.replaceAllMapped(
      RegExp(r'\b([01]?\d|2[0-3])[-–—]00\b'),
      (m) => '${m[1]}:00',
    );
    return t;
  }

  /// RU wall-clock phrases → numeric fragment (longest keys first so `двадцать один` wins over `двадцать`).
  static const Map<String, int> _ruHourWords = {
    'двадцать три': 23,
    'двадцать два': 22,
    'двадцать один': 21,
    'девятнадцать': 19,
    'восемнадцать': 18,
    'семнадцать': 17,
    'шестнадцать': 16,
    'пятнадцать': 15,
    'четырнадцать': 14,
    'тринадцать': 13,
    'двенадцать': 12,
    'одиннадцать': 11,
    'десять': 10,
    'девять': 9,
    'восемь': 8,
    'семь': 7,
    'шесть': 6,
    'пять': 5,
    'четыре': 4,
    'три': 3,
    'два': 2,
    'один': 1,
    'двадцать': 20,
    'ноль': 0,
  };

  static final List<(RegExp, String)> _ruSpokenClockReplacements =
      _buildRuSpokenClockReplacements();

  static List<(RegExp, String)> _buildRuSpokenClockReplacements() {
    final keys = _ruHourWords.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final out = <(RegExp, String)>[];
    for (final k in keys) {
      if (k == 'ноль') continue;
      final h = _ruHourWords[k]!;
      final esc = k.split(RegExp(r'\s+')).map(RegExp.escape).join(r'\s+');
      out.add((
        RegExp('\\bв\\s+$esc\\s+ноль\\s+ноль\\b', caseSensitive: false),
        ' $h:00 ',
      ),);
      out.add((
        RegExp('\\b$esc\\s+ноль\\s+ноль\\b', caseSensitive: false),
        ' $h:00 ',
      ),);
      out.add((
        RegExp('\\bв\\s+$esc\\s+нуль\\s+нуль\\b', caseSensitive: false),
        ' $h:00 ',
      ),);
      out.add((
        RegExp('\\bв\\s+$esc\\s+час(?:а|ов)?\\b', caseSensitive: false),
        ' $h:00 ',
      ),);
    }
    return out;
  }

  /// Expands common Russian spoken times; then [sanitizeSttTimeArtifacts]; then [normalizeClockSeparators].
  static String normalizeForTimeParsing(String raw) {
    var s = raw.replaceAll('\u00A0', ' ');
    for (final pair in _ruSpokenClockReplacements) {
      s = s.replaceAll(pair.$1, pair.$2);
    }
    s = s.replaceAllMapped(
      RegExp(
        r'(?:^|[\s\u00A0])в\s+([01]?\d|2[0-3])(?:\s+(?:часов|часа|час|минут|мин))?(?=\s|$|[,.;:!?)])',
        caseSensitive: false,
      ),
      (m) => ' ${m[1]}:00 ',
    );
    s = s.replaceAllMapped(
      RegExp(
        r'(?:^|[\s\u00A0])at\s+([01]?\d|2[0-3])(?:\s+(?:hours?|mins?|[hm]))?(?=\s|$|[,.;:!?)])',
        caseSensitive: false,
      ),
      (m) => ' ${m[1]}:00 ',
    );
    s = sanitizeSttTimeArtifacts(s);
    s = normalizeClockSeparators(s);
    return s;
  }

  /// Word-bounded HH:mm or HH.mm (same semantics; `.` is not a decimal separator here).
  /// Minutes may be one digit (`13.4` → 13:04) or two; separator is `:` or `.` only (comma normalized earlier).
  static final RegExp _clockTime = RegExp(
    r'\b([01]?\d|2[0-3])(?::|\.)([0-5]?\d)\b',
  );

  /// STT / casual: `9 00`, `9 0` as minutes (wall clock), not only `9:00`.
  static final RegExp _spacedHourMinute = RegExp(
    r'\b([01]?\d|2[0-3])\s+([0-5]\d)\b',
  );

  /// Single-digit minute after space (`9 0` → 9:00).
  static final RegExp _spacedHourMinuteSingleDigit = RegExp(
    r'\b([01]?\d|2[0-3])\s+(\d)(?=\s|$|[,.;:!?)])',
  );

  /// Trailing ` … HH:mm` / ` … HH.mm` at end (space before clock).
  static final RegExp _trailingClockTime = RegExp(
    r'[\s\u00A0]+([01]?\d|2[0-3])(?::|\.)([0-5]?\d)\s*$',
  );

  /// Trailing ` … HHmm` four digits at end (12:30 from `1230`).
  static final RegExp _trailingHhmmCompact = RegExp(r'[\s\u00A0]+(\d{4})\s*$');

  /// `at` / `@` / **в** / **на** only after start or whitespace (no splitting Cyrillic words on `в` mid-token).
  /// Allows **space** before minutes for STT (`в 9 00`); group 2 = `:`/`.` minutes, group 3 = spaced minutes.
  /// Optional trailing time units only immediately after the `at`/`в`/… hour (or hour+minute) token.
  static final RegExp _atWordTime = RegExp(
    r'(?:^|[\s\u00A0])(?:at|@|в|на)\s*([01]?\d|2[0-3])'
    r'(?:(?::|\.)([0-5]?\d)|\s+([0-5]?\d))?'
    r'(?:\s+(?:часов|часа|час|минут|мин|hours?|mins?|[hm]))?'
    r'(?=\s|$|[,.;:!?)])',
    caseSensitive: false,
  );

  /// Lenient trailing hour: whitespace run + hour 0–23 at end.
  static final RegExp _trailingHourAfterSpace = RegExp(
    r'[\s\u00A0]+(2[0-3]|1[0-9]|[0-9])\s*$',
  );

  static bool _charSuggestsGluedClockPrefix(String s, int indexBeforeSpace) {
    if (indexBeforeSpace < 0 || indexBeforeSpace >= s.length) return false;
    return RegExp(r'[\d:.]').hasMatch(s[indexBeforeSpace]);
  }

  /// Returns null if no time token matched (caller should not mutate the field).
  static SmartTimeParseResult? parseTitleForScheduledTime(String raw) {
    final input = normalizeForTimeParsing(raw);
    if (input.trim().isEmpty) return null;

    Match? m = _clockTime.firstMatch(input);
    if (m != null) {
      final h = int.parse(m.group(1)!);
      final min = _minuteGroupToInt(m.group(2));
      final cleaned =
          _collapseSpace(input.replaceRange(m.start, m.end, '')).trim();
      return SmartTimeParseResult(cleanedTitle: cleaned, hour: h, minute: min);
    }

    m = _atWordTime.firstMatch(input);
    if (m != null) {
      final h = int.parse(m.group(1)!);
      final min = _minuteGroupToInt(m.group(2) ?? m.group(3));
      final cleaned =
          _collapseSpace(input.replaceRange(m.start, m.end, '')).trim();
      return SmartTimeParseResult(
        cleanedTitle: cleaned,
        hour: h,
        minute: min,
      );
    }

    m = _spacedHourMinute.firstMatch(input);
    if (m != null) {
      final h = int.parse(m.group(1)!);
      final min = int.parse(m.group(2)!);
      if (h >= 0 && h <= 23 && min >= 0 && min <= 59) {
        final cleaned =
            _collapseSpace(input.replaceRange(m.start, m.end, '')).trim();
        return SmartTimeParseResult(
          cleanedTitle: cleaned,
          hour: h,
          minute: min,
        );
      }
    }

    m = _spacedHourMinuteSingleDigit.firstMatch(input);
    if (m != null) {
      final h = int.parse(m.group(1)!);
      final min = _minuteGroupToInt(m.group(2));
      if (h >= 0 && h <= 23) {
        final cleaned =
            _collapseSpace(input.replaceRange(m.start, m.end, '')).trim();
        return SmartTimeParseResult(
          cleanedTitle: cleaned,
          hour: h,
          minute: min,
        );
      }
    }

    final trimmedRight = input.trimRight();

    m = _trailingClockTime.firstMatch(trimmedRight);
    if (m != null) {
      final skip = m.start > 0 &&
          _charSuggestsGluedClockPrefix(trimmedRight, m.start - 1);
      if (!skip) {
        final h = int.parse(m.group(1)!);
        final min = _minuteGroupToInt(m.group(2));
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
          _charSuggestsGluedClockPrefix(trimmedRight, m.start - 1);
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
        if (RegExp(r'[\d:.]').hasMatch(beforeWhitespaceRun)) {
          return null;
        }
      }
      final h = int.parse(m.group(1)!);
      final cleaned =
          _collapseSpace(trimmedRight.replaceRange(m.start, m.end, '')).trim();
      return SmartTimeParseResult(cleanedTitle: cleaned, hour: h, minute: 0);
    }

    return null;
  }

  // --- Time **ranges** (plan title NLP): try range first, then [parseTitleForScheduledTime]. ---

  /// EN: spaces optional so `from9to5`, `from 9 to 12` both match. Leading word
  /// must start after start-of-string or whitespace (avoid glued Latin words).
  static final RegExp _rangeFromToEn = RegExp(
    r'(?:^|[\s\u00A0,.;:!?\-–—])from\s*([01]?\d|2[0-3])(?:(?::|\.)(\d{1,2}))?\s*to\s*([01]?\d|2[0-3])(?:(?::|\.)(\d{1,2}))?',
    caseSensitive: false,
  );

  /// RU: `с 10 до 2`, `с11до12`, etc.
  static final RegExp _rangeRuDo = RegExp(
    r'(?:^|[\s\u00A0,.;:!?\-–—])с\s*([01]?\d|2[0-3])(?:(?::|\.)(\d{1,2}))?\s*до\s*([01]?\d|2[0-3])(?:(?::|\.)(\d{1,2}))?',
    caseSensitive: false,
  );

  static final RegExp _rangeSpacedTo = RegExp(
    r'\b([01]?\d|2[0-3])(?:(?::|\.)(\d{2}))?\s*to\s*([01]?\d|2[0-3])(?:(?::|\.)(\d{2}))?\b',
    caseSensitive: false,
  );

  static final RegExp _rangeDash = RegExp(
    r'\b([01]?\d|2[0-3])(?:(?::|\.)(\d{2}))?\s*-\s*([01]?\d|2[0-3])(?:(?::|\.)(\d{2}))?\b',
  );

  static final RegExp _rangeGluedTo = RegExp(
    r'\b([01]?\d|2[0-3])to([01]?\d|2[0-3])\b',
    caseSensitive: false,
  );

  /// Parses a start–end time range from the title. Returns null if nothing matched.
  ///
  /// Applies **+12h on the end** when end is strictly before start the same day
  /// (e.g. `from 10 to 2` → 14:00).
  static SmartTimeRangeParseResult? parseTitleForTimeRange(String raw) {
    try {
      final input = normalizeForTimeParsing(raw);
      if (input.trim().isEmpty) return null;

      SmartTimeRangeParseResult? try4(
        Match m, {
        required int shI,
        required int smI,
        required int ehI,
        required int emI,
      }) {
        final sh = int.tryParse(m.group(shI) ?? '');
        final eh = int.tryParse(m.group(ehI) ?? '');
        if (sh == null || eh == null || sh < 0 || sh > 23 || eh < 0 || eh > 23) {
          return null;
        }
        final sm = smI < 0 ? 0 : _minuteGroupToInt(m.group(smI));
        final em = emI < 0 ? 0 : _minuteGroupToInt(m.group(emI));
        if (sm < 0 || sm > 59 || em < 0 || em > 59) return null;
        final adjusted = _afternoonAdjustEnd(sh, sm, eh, em);
        final eh2 = adjusted.$1;
        final em2 = adjusted.$2;
        final cleaned = _collapseSpace(input.replaceRange(m.start, m.end, '')).trim();
        return SmartTimeRangeParseResult(
          cleanedTitle: cleaned,
          startHour: sh,
          startMinute: sm,
          endHour: eh2,
          endMinute: em2,
        );
      }

      SmartTimeRangeParseResult? tryGlued(Match m) {
        final sh = int.tryParse(m.group(1) ?? '');
        final eh = int.tryParse(m.group(2) ?? '');
        if (sh == null || eh == null || sh < 0 || sh > 23 || eh < 0 || eh > 23) {
          return null;
        }
        final adjusted = _afternoonAdjustEnd(sh, 0, eh, 0);
        final cleaned = _collapseSpace(input.replaceRange(m.start, m.end, '')).trim();
        return SmartTimeRangeParseResult(
          cleanedTitle: cleaned,
          startHour: sh,
          startMinute: 0,
          endHour: adjusted.$1,
          endMinute: adjusted.$2,
        );
      }

      Match? m = _rangeFromToEn.firstMatch(input);
      if (m != null) {
        final r = try4(m, shI: 1, smI: 2, ehI: 3, emI: 4);
        if (r != null) return r;
      }
      m = _rangeRuDo.firstMatch(input);
      if (m != null) {
        final r = try4(m, shI: 1, smI: 2, ehI: 3, emI: 4);
        if (r != null) return r;
      }
      m = _rangeSpacedTo.firstMatch(input);
      if (m != null) {
        final r = try4(m, shI: 1, smI: 2, ehI: 3, emI: 4);
        if (r != null) return r;
      }
      m = _rangeDash.firstMatch(input);
      if (m != null) {
        final r = try4(m, shI: 1, smI: 2, ehI: 3, emI: 4);
        if (r != null) return r;
      }
      m = _rangeGluedTo.firstMatch(input);
      if (m != null) {
        final r = tryGlued(m);
        if (r != null) return r;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// When [end] is earlier on the clock than [start], shift end by +12 hours (same calendar day bucket).
  static (int, int) _afternoonAdjustEnd(int sh, int sm, int eh, int em) {
    var startT = sh * 60 + sm;
    var endT = eh * 60 + em;
    if (endT < startT) {
      endT += 12 * 60;
    }
    while (endT >= 24 * 60) {
      endT -= 24 * 60;
    }
    while (endT < 0) {
      endT += 24 * 60;
    }
    return (endT ~/ 60, endT % 60);
  }

  static String _collapseSpace(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
