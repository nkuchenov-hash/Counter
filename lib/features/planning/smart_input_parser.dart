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
/// 1. Word-bounded `HH:mm` / `HH.mm` (and comma or fullwidth dot normalized to `.` first).
/// 2. Trailing ` … HH[:.]mm` at EOL (after one or more spaces), not glued to another number/date chunk.
/// 3. Trailing **four digits** `HHmm` (e.g. `1230` → 12:30).
/// 4. Trailing hour only: `[\s]+(2[0-3]|1[0-9]|[0-9])\s*$` (e.g. `Ужин 12`).
/// 5. `at` / `@` / **в** / **на** after start or whitespace, optional `:` or `.` before minutes.
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

  /// Word-bounded HH:mm or HH.mm (same semantics; `.` is not a decimal separator here).
  /// Minutes may be one digit (`13.4` → 13:04) or two; separator is `:` or `.` only (comma normalized earlier).
  static final RegExp _clockTime = RegExp(
    r'\b([01]?\d|2[0-3])(?::|\.)([0-5]?\d)\b',
  );

  /// Trailing ` … HH:mm` / ` … HH.mm` at end (space before clock).
  static final RegExp _trailingClockTime = RegExp(
    r'[\s\u00A0]+([01]?\d|2[0-3])(?::|\.)([0-5]?\d)\s*$',
  );

  /// Trailing ` … HHmm` four digits at end (12:30 from `1230`).
  static final RegExp _trailingHhmmCompact = RegExp(r'[\s\u00A0]+(\d{4})\s*$');

  /// `at` / `@` / **в** / **на** only after start or whitespace (no splitting Cyrillic words on `в` mid-token).
  static final RegExp _atWordTime = RegExp(
    r'(?:^|[\s\u00A0])(?:at|@|в|на)\s*([01]?\d|2[0-3])(?:(?::|\.)([0-5]?\d))?(?=\s|$)',
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
    final input = normalizeClockSeparators(raw.replaceAll('\u00A0', ' '));
    if (input.trim().isEmpty) return null;

    Match? m = _clockTime.firstMatch(input);
    if (m != null) {
      final h = int.parse(m.group(1)!);
      final min = _minuteGroupToInt(m.group(2));
      final cleaned =
          _collapseSpace(input.replaceRange(m.start, m.end, '')).trim();
      return SmartTimeParseResult(cleanedTitle: cleaned, hour: h, minute: min);
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

    m = _atWordTime.firstMatch(input);
    if (m != null) {
      final h = int.parse(m.group(1)!);
      final min = _minuteGroupToInt(m.group(2));
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
      final input = normalizeClockSeparators(raw.replaceAll('\u00A0', ' '));
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
