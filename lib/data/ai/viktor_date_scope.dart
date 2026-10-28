import 'package:timezone/timezone.dart' as tz;

import 'viktor_action_contract.dart';

/// Dates used by Viktor tools are explicit user-intent dates, not the
/// calendar tab currently visible in Flutter. All day keys are profile-wall
/// dates; provider-specific clock conversion belongs to the Brain executor.
class ViktorDateScope {
  const ViktorDateScope._();

  static String key(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static DateTime parseDay(String value) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (m == null) throw const FormatException('Invalid wall day');
    final y = int.parse(m[1]!);
    final month = int.parse(m[2]!);
    final d = int.parse(m[3]!);
    final date = DateTime(y, month, d);
    if (date.year != y || date.month != month || date.day != d) {
      throw const FormatException('Invalid wall day');
    }
    return date;
  }


  /// Reproject a persisted UTC instant into the requested conversation
  /// clock without editing the underlying PocketBase record.
  static DateTime projectUtcInstant(DateTime instant, String ianaZone) =>
      tz.TZDateTime.from(instant.toUtc(), tz.getLocation(ianaZone));


  /// Relative dates use the profile's current date, never the opened tab.
  static DateTime? relativeDay(String input, DateTime profileToday) {
    final m = RegExp(
      r'через\s+(?:(\d{1,2}|один|одну|два|две|три|четыре|пять)\s+)?'
      r'(неделю|недели|недель|день|дня|дней)(?=\s|$|[.,!?])',
      caseSensitive: false,
    ).firstMatch(input);
    if (m == null) return null;
    const names = <String, int>{
      'один': 1, 'одну': 1, 'два': 2, 'две': 2,
      'три': 3, 'четыре': 4, 'пять': 5,
    };
    final word = m.group(1)?.toLowerCase();
    final count = word == null ? 1 : int.tryParse(word) ?? names[word];
    if (count == null || count < 1 || count > 12) return null;
    final days = m.group(2)!.startsWith('недел') ? count * 7 : count;
    return DateTime(profileToday.year, profileToday.month,
        profileToday.day + days);
  }

  /// An independent, single date-only plan must not inherit old itineraries.
  static ({DateTime day, String title})? explicitDateOnlyPlan(
      String input, DateTime today) {
    final normalized = input.trim();
    if (RegExp(r'\b\d{1,2}:\d{2}\b').hasMatch(normalized)) return null;
    final prefix = RegExp(
      r'^(?:([a-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?|'
      r'(\d{1,2})\s+([а-яё]+))'
      r'(?:,?\s+(20\d{2}))?\s*[-–—:]\s*'
      r'(?:(?:new|новый)\s+)?(?:plan|task|план|задача)\s+(.+)$',
      caseSensitive: false, dotAll: true,
    ).firstMatch(normalized);
    final command = prefix == null ? RegExp(
      r'^(?:add|create|schedule|добавь|создай|запиши|запланируй)\s+'
      r'(?:(?:a|мне|new|новый|отдельный)\s+)*'
      r'(?:plan|task|план|задачу)\s+(?:for|on|на)\s+'
      r'(?:([a-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?|'
      r'(\d{1,2})\s+([а-яё]+))'
      r'(?:,?\s+(20\d{2}))?\s*[:\-–—]\s*(.+)$',
      caseSensitive: false, dotAll: true,
    ).firstMatch(normalized) : null;
    final m = prefix ?? command;
    if (m == null) return null;
    const months = <String, int>{
      'january': 1, 'jan': 1, 'february': 2, 'feb': 2,
      'march': 3, 'mar': 3, 'april': 4, 'apr': 4,
      'may': 5, 'june': 6, 'jun': 6, 'july': 7, 'jul': 7,
      'august': 8, 'aug': 8, 'september': 9, 'sep': 9,
      'october': 10, 'oct': 10, 'november': 11, 'nov': 11,
      'december': 12, 'dec': 12,
      'января': 1, 'февраля': 2, 'марта': 3, 'апреля': 4,
      'мая': 5, 'июня': 6, 'июля': 7, 'августа': 8,
      'сентября': 9, 'октября': 10, 'ноября': 11, 'декабря': 12,
    };
    final month = months[(m.group(1) ?? m.group(4))?.toLowerCase()];
    final dayNum = int.tryParse(m.group(2) ?? m.group(3) ?? '');
    final title = (m.group(6) ?? '').trim();
    if (month == null || dayNum == null || dayNum < 1 ||
        dayNum > 31 || title.length < 3 || title.length > 160) return null;
    if (RegExp(
      r'\band\s+(?:also\s+)?(?:add|create|schedule)\s+'
      r'(?:a\s+)?(?:new\s+)?(?:plan|task)\b|'
      r'\bи\s+(?:ещ[её]\s+)?(?:добавь|создай)\s+(?:план|задачу)\b',
      caseSensitive: false,
    ).hasMatch(title)) return null;
    bool valid(int year) {
      final date = DateTime(year, month, dayNum);
      return date.year == year && date.month == month && date.day == dayNum;
    }
    final rawYear = m.group(5);
    int? year = rawYear == null ? null : int.tryParse(rawYear);
    if (year != null && !valid(year)) return null;
    if (year == null) {
      final todayDay = DateTime(today.year, today.month, today.day);
      for (var y = today.year; y <= today.year + 5; y++) {
        if (valid(y) && !DateTime(y, month, dayNum).isBefore(todayDay)) {
          year = y;
          break;
        }
      }
    }
    if (year == null) return null;
    return (day: DateTime(year, month, dayNum), title: title);
  }

  /// A simple standalone untimed plan bypasses model round trips but still
  /// goes through Viktor's typed Brain-backed executor.
  static ({DateTime day, String title})? independentDateOnlyPlan(
      String input, DateTime profileToday) {
    final normalized = input.trim();
    if (RegExp(r'\b\d{1,2}:\d{2}\b').hasMatch(normalized)) return null;
    final dated = explicitDateOnlyPlan(normalized, profileToday);
    if (dated != null) return dated;
    final m = RegExp(
      r'^(?:добавь|создай|запиши|запланируй)\s+'
      r'(?:мне\s+)?(?:(?:новый|отдельный)\s+)?'
      r'(?:план|задачу)\s+'
      r'(через\s+(?:(?:\d{1,2}|один|одну|два|две|три|четыре|пять)\s+)?'
      r'(?:неделю|недели|недель|день|дня|дней))'
      r'(?:\s+от\s+(?:сегодняшнего\s+дня|сегодня))?'
      r'\s+(.+)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(normalized);
    if (m == null || m.end != normalized.length) return null;
    final day = relativeDay(m.group(1)!, profileToday);
    final title = m.group(2)!.trim();
    if (day == null || title.length < 3 || title.length > 160 ||
        RegExp(r'\b(?:и\s+ещ[её]\s+добавь|а\s+также\s+создай)\b',
          caseSensitive: false).hasMatch(title)) return null;
    return (day: day, title: title[0].toUpperCase() + title.substring(1));
  }

  /// Only explicit relative-day words may override a visible calendar day.
  /// "через N дней" is resolved separately by relativeDay().
  static DateTime? _namedRelativeDay(String text, DateTime origin) {
    final offsets = <int>{};
    final lower = text.toLowerCase();
    bool containsWord(String word) => RegExp(
      '(^|[^а-яёa-z])' + word + r'(?=$|[^а-яёa-z])',
      caseSensitive: false,
    ).hasMatch(lower);
    if (containsWord('позавчера')) offsets.add(-2);
    if (containsWord('вчера(?:шн[а-яё]*)?')) offsets.add(-1);
    if (containsWord('сегодня(?:шн[а-яё]*)?')) offsets.add(0);
    if (containsWord('завтра(?:шн[а-яё]*)?')) offsets.add(1);
    if (containsWord('послезавтра')) offsets.add(2);
    if (offsets.length != 1) return null; // Conflicting dates need reasoning.
    return DateTime(origin.year, origin.month, origin.day + offsets.single);
  }

  static DateTime itineraryDay(String input, DateTime displayed,
      List<Map<String, String>> history,
      {bool revision = false, DateTime? profileToday}) {
    DateTime? findDate(String text) {
      final iso = RegExp(r'20[0-9]{2}-[0-9]{2}-[0-9]{2}').firstMatch(text);
      if (iso != null) {
        try { return parseDay(iso.group(0)!); } catch (_) { return null; }
      }
      const months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
          'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
      final ru = RegExp(r'([0-9]{1,2})\s+(' + months.join('|') +
          r')\s+(20[0-9]{2})', caseSensitive: false).firstMatch(text);
      if (ru == null) return null;
      final date = DateTime(int.parse(ru.group(3)!),
          months.indexOf(ru.group(2)!.toLowerCase()) + 1,
          int.parse(ru.group(1)!));
      if (date.year != int.parse(ru.group(3)!) ||
          date.day != int.parse(ru.group(1)!)) return null;
      return date;
    }
    final explicit = findDate(input);
    if (explicit != null) return explicit;
    final relative = profileToday == null ? null
        : relativeDay(input, profileToday);
    if (relative != null) return relative;
    final named = profileToday == null ? null
        : _namedRelativeDay(input, profileToday);
    if (named != null) return named;

    // "Добавь эти записи тоже" refers to a previous request, not to the
    // currently open calendar tab or the day on which the follow-up is sent.
    // Only an explicit temporal statement in a prior USER turn can supply
    // that day. Do not invent dates for legacy turns missing message_day.
    final referringBack = RegExp(
      r'^(?:добавь|запиши|сохрани|внеси|переделай|исправь|'
      r'перенеси|измени|создай)\s+(?:мне\s+)?'
      r'(?:эти|те|их|это|ту|тот|этот|его|её|ее)(?=\s|$)',
      caseSensitive: false,
    ).hasMatch(input.trim());
    if (referringBack) {
      for (final turn in history.reversed) {
        if (turn['role'] != 'user') continue;
        final source = turn['content'] ?? '';
        final dated = findDate(source);
        if (dated != null) return dated;
        final sourceDay = DateTime.tryParse(turn['message_day'] ?? '');
        if (sourceDay == null) continue;
        final sourceRelative = relativeDay(source, sourceDay) ??
            _namedRelativeDay(source, sourceDay);
        if (sourceRelative != null) return sourceRelative;
      }
    }
    if (!revision) return displayed;
    for (final turn in history) {
      if (turn['role'] != 'user') continue;
      final content = turn['content'] ?? '';
      if (!RegExp('расплан|расписани|маршрут|суббот|itinerary|schedule',
          caseSensitive: false).hasMatch(content)) continue;
      final date = findDate(content);
      if (date != null) return date;
    }
    return displayed;
  }

  static DateTime scheduleDay(
      ViktorActionBatch batch, DateTime displayedDay) {
    final dates = <String>{
      for (final action in batch.actions)
        if (const {'move_plan_after', 'swap_plan_positions',
                    'update_plan_duration'}.contains(action.name) &&
            action.arguments.containsKey('wall_day'))
          action.arguments['wall_day'] as String,
    };
    if (dates.length > 1) {
      throw StateError('Составные изменения расписания относятся к '
          'разным дням. Выполните их отдельно.');
    }
    return dates.isEmpty ? displayedDay : parseDay(dates.single);
  }

  static ViktorBulkDateScope bulkDays(ViktorAction action) {
    if (action.name != 'bulk_replan') {
      throw ArgumentError('Expected bulk_replan');
    }
    final ops = action.arguments['operations'] as List;
    final sources = <String>{};
    final targets = <String>{};
    for (final item in ops) {
      final op = Map<String, Object?>.from(item as Map);
      sources.add(op['source_day'] as String);
      if (op['kind'] == 'move') {
        targets.add(op['target_day'] as String);
      }
    }
    if (sources.length != 1 || targets.length > 1) {
      throw StateError('Пакет переноса охватывает несколько независимых '
          'исходных или целевых дней. Разделите его на операции.');
    }
    final source = sources.single;
    parseDay(source);
    final target = targets.isEmpty ? null : targets.single;
    if (target != null) parseDay(target);
    return ViktorBulkDateScope(source, target);
  }
}

class ViktorBulkDateScope {
  const ViktorBulkDateScope(this.sourceDay, this.targetDay);
  final String sourceDay;
  final String? targetDay;
}
