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

  static DateTime itineraryDay(String input, DateTime displayed,
      List<Map<String, String>> history, {bool revision = false}) {
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
