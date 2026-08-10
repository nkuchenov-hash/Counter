import 'package:counter/data/database_service.dart';

/// Presentation policy shared by Timeline and Stats.
///
/// Sleep remains an ordinary Timeline record and a health signal, but it is not
/// part of the waking-day Stats activity surface.
abstract final class SleepRecordPolicy {
  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime? startWall(Map<String, dynamic> record) {
    final utc = CategoryServiceExtension.startTimeFromRecord(record);
    return utc == null ? null : DatabaseService.instance.applyUserOffset(utc);
  }

  static DateTime? endWall(Map<String, dynamic> record) {
    final db = DatabaseService.instance;
    final utc = CategoryServiceExtension.endTimeFromRecord(record);
    if (utc != null) return db.applyUserOffset(utc);
    final status = (record['status'] ?? '').toString().trim().toLowerCase();
    if (status != 'running') return null;
    return db.applyUserOffset(DatabaseService.getPlanetaryNow());
  }

  static bool isSleepCategoryId(int? categoryId) {
    if (categoryId == null) return false;
    final db = DatabaseService.instance;
    final path = db.getCategoryPath(categoryId).trim().toLowerCase();
    if (path.isEmpty) return false;
    final root = path.split(' > ').first.trim();
    return root == 'sleep' || root == 'сон';
  }

  static bool isSleepRecord(Map<String, dynamic> record) {
    final externalKind =
        (record['external_kind'] ?? record['externalKind'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    if (externalKind == 'sleep') return true;

    final sleepSource = (record['sleep_source'] ?? record['sleepSource'] ?? '')
        .toString()
        .trim();
    if (sleepSource.isNotEmpty) return true;

    final title = (record['title'] ?? '').toString().trim().toLowerCase();
    if (title == 'sleep' || title == 'сон') return true;

    final db = DatabaseService.instance;
    final resolvedId = db.resolvedCategoryIdForRecord(record);
    if (isSleepCategoryId(resolvedId)) return true;

    final path = db.resolvedCategoryPathForRecord(record).trim().toLowerCase();
    if (path.isNotEmpty) {
      final root = path.split(' > ').first.trim();
      if (root == 'sleep' || root == 'сон') return true;
    }
    return false;
  }

  static List<Map<String, dynamic>> adjacentRecordsForDay(
    DateTime selectedDay,
    List<Map<String, dynamic>> currentRecords,
  ) {
    final db = DatabaseService.instance;
    final day = _day(selectedDay);
    final candidates = <Map<String, dynamic>>[
      ...db.peekTimelineRecordsForDate(day.subtract(const Duration(days: 1))),
      ...currentRecords,
      ...db.peekTimelineRecordsForDate(day.add(const Duration(days: 1))),
    ];

    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final record in candidates) {
      final start = CategoryServiceExtension.startTimeFromRecord(record);
      final key = [
        (record['record_id'] ?? record['id'] ?? '').toString().trim(),
        start?.toIso8601String() ?? '',
        (record['title'] ?? '').toString(),
      ].join('|');
      if (!seen.add(key)) continue;
      out.add(record);
    }
    return out;
  }

  /// Main overnight sleep ending on [selectedDay]. Naps are intentionally
  /// ignored by requiring a substantial duration and a morning-ish end time.
  static Map<String, dynamic>? mainSleepEndingOnDay(
    DateTime selectedDay,
    Iterable<Map<String, dynamic>> records,
  ) {
    Map<String, dynamic>? best;
    var bestSeconds = -1;
    for (final record in records) {
      if (!isSleepRecord(record)) continue;
      final start = startWall(record);
      final end = endWall(record);
      if (start == null || end == null || !end.isAfter(start)) continue;
      if (!_sameDay(end, selectedDay)) continue;
      final seconds = end.difference(start).inSeconds;
      if (seconds < const Duration(hours: 2).inSeconds) continue;
      // An overnight/main sleep normally ends before mid-afternoon. This keeps
      // a long daytime nap from redefining the start of the day.
      if (end.hour >= 15) continue;
      if (seconds > bestSeconds) {
        best = record;
        bestSeconds = seconds;
      }
    }
    return best;
  }

  static Map<String, dynamic>? nextMainSleepAfter(
    DateTime wakeWall,
    Iterable<Map<String, dynamic>> records,
  ) {
    Map<String, dynamic>? best;
    DateTime? bestStart;
    for (final record in records) {
      if (!isSleepRecord(record)) continue;
      final start = startWall(record);
      final end = endWall(record);
      if (start == null || end == null || !end.isAfter(start)) continue;
      if (!start.isAfter(wakeWall.add(const Duration(hours: 4)))) continue;
      if (end.difference(start) < const Duration(hours: 2)) continue;
      if (bestStart == null || start.isBefore(bestStart)) {
        best = record;
        bestStart = start;
      }
    }
    return best;
  }

  static WakingDayWindow wakingDayWindow({
    required DateTime selectedDay,
    required List<Map<String, dynamic>> currentRecords,
  }) {
    final db = DatabaseService.instance;
    final day = _day(selectedDay);
    final candidates = adjacentRecordsForDay(day, currentRecords);
    final nonSleep = candidates.where((r) => !isSleepRecord(r)).toList();

    final previousSleep = mainSleepEndingOnDay(day, candidates);
    DateTime? wake = previousSleep == null ? null : endWall(previousSleep);

    final nonSleepOnDay =
        nonSleep.where((record) {
          final start = startWall(record);
          return start != null && _sameDay(start, day);
        }).toList()..sort((a, b) {
          final as = startWall(a)!;
          final bs = startWall(b)!;
          return as.compareTo(bs);
        });

    // If sleep data has not arrived yet, the first waking activity is the most
    // truthful observable start boundary. Only then fall back to 06:00.
    wake ??= nonSleepOnDay.isNotEmpty
        ? startWall(nonSleepOnDay.first)
        : day.add(const Duration(hours: 6));

    final nextSleep = nextMainSleepAfter(wake, candidates);
    DateTime? bed = nextSleep == null ? null : startWall(nextSleep);

    final today = _day(db.getTimelineDeviceLocalToday());
    if (bed == null) {
      if (_sameDay(day, today)) {
        final nowWall = db.applyUserOffset(DatabaseService.getPlanetaryNow());
        bed = nowWall.isAfter(wake)
            ? nowWall
            : wake.add(const Duration(minutes: 1));
      } else {
        // When the next sleep is unavailable, keep the historical fallback at
        // the calendar boundary rather than inventing a bedtime.
        bed = day.add(const Duration(days: 1));
        if (!bed.isAfter(wake)) bed = wake.add(const Duration(hours: 16));
      }
    }

    final wakingRecords = <Map<String, dynamic>>[];
    for (final record in nonSleep) {
      final start = startWall(record);
      final end = endWall(record) ?? start;
      if (start == null || end == null) continue;
      if (!end.isAfter(wake) || !start.isBefore(bed)) continue;
      wakingRecords.add(record);
    }
    wakingRecords.sort((a, b) {
      final as = startWall(a);
      final bs = startWall(b);
      if (as == null && bs == null) return 0;
      if (as == null) return 1;
      if (bs == null) return -1;
      return as.compareTo(bs);
    });

    return WakingDayWindow(
      selectedDay: day,
      wakeWall: wake,
      bedWall: bed,
      previousSleep: previousSleep,
      nextSleep: nextSleep,
      records: wakingRecords,
    );
  }
}

class WakingDayWindow {
  const WakingDayWindow({
    required this.selectedDay,
    required this.wakeWall,
    required this.bedWall,
    required this.records,
    this.previousSleep,
    this.nextSleep,
  });

  final DateTime selectedDay;
  final DateTime wakeWall;
  final DateTime bedWall;
  final List<Map<String, dynamic>> records;
  final Map<String, dynamic>? previousSleep;
  final Map<String, dynamic>? nextSleep;
}
