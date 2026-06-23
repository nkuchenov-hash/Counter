import 'package:counter/data/models.dart';

/// Rolling warm day window constants (P0O).
abstract final class WarmDayWindowConstants {
  static const int radius = 10;
  static const int extendThreshold = 3;
  static const int extendBy = 10;
  static const int maxCachedDays = 41;
}

/// Lightweight Timeline day snapshot — data only, no widgets/streams.
class TimelineDaySnapshot {
  const TimelineDaySnapshot({
    required this.dateKey,
    required this.knownEmpty,
    required this.records,
    required this.cacheSignature,
  });

  final String dateKey;
  final bool knownEmpty;
  final List<Map<String, dynamic>> records;
  final int cacheSignature;
}

/// Lightweight Plans day snapshot — data only, no widgets/streams.
class PlansDaySnapshot {
  const PlansDaySnapshot({
    required this.dateKey,
    required this.knownEmpty,
    required this.tasks,
    required this.cacheSignature,
  });

  final String dateKey;
  final bool knownEmpty;
  final List<PlanningTask> tasks;
  final int cacheSignature;
}

/// In-memory LRU rolling window for day snapshots (data only).
class WarmSnapshotWindow<T> {
  WarmSnapshotWindow({required this.dateKeyOf});

  final String Function(DateTime day) dateKeyOf;

  final Map<String, T> _snapshots = {};
  DateTime? windowFrom;
  DateTime? windowTo;
  DateTime? center;

  int get cachedDayCount => _snapshots.length;
  Iterable<String> get dateKeys => _snapshots.keys;
  Iterable<T> get snapshots => _snapshots.values;

  T? peek(String dateKey) => _snapshots[dateKey];

  void put(String dateKey, T snapshot) {
    _snapshots[dateKey] = snapshot;
  }

  void remove(String dateKey) => _snapshots.remove(dateKey);

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime parseDateKey(String key) {
    final p = key.split('-');
    if (p.length != 3) return DateTime.now();
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return DateTime.now();
    return DateTime(y, m, d);
  }

  void ensureInitialWindow(
    DateTime centerDay,
    T Function(DateTime day) buildSnapshot,
  ) {
    final c = dateOnly(centerDay);
    center = c;
    final from = c.subtract(const Duration(days: WarmDayWindowConstants.radius));
    final to = c.add(const Duration(days: WarmDayWindowConstants.radius));
    _warmRange(from, to, buildSnapshot);
    windowFrom = from;
    windowTo = to;
    _evictBeyondMax(c);
  }

  void _warmRange(
    DateTime from,
    DateTime to,
    T Function(DateTime day) buildSnapshot,
  ) {
    var d = dateOnly(from);
    final end = dateOnly(to);
    while (!d.isAfter(end)) {
      final key = dateKeyOf(d);
      _snapshots[key] = buildSnapshot(d);
      d = d.add(const Duration(days: 1));
    }
  }

  /// Returns `past`, `future`, or `initial` if window was extended/created.
  String? extendIfNeeded(
    DateTime centerDay,
    T Function(DateTime day) buildSnapshot,
  ) {
    if (windowFrom == null || windowTo == null) {
      ensureInitialWindow(centerDay, buildSnapshot);
      return 'initial';
    }
    final c = dateOnly(centerDay);
    center = c;
    final daysFromPastEdge = c.difference(windowFrom!).inDays;
    final daysToFutureEdge = windowTo!.difference(c).inDays;

    if (daysFromPastEdge <= WarmDayWindowConstants.extendThreshold) {
      final newFrom = windowFrom!.subtract(
        const Duration(days: WarmDayWindowConstants.extendBy),
      );
      _warmRange(
        newFrom,
        windowFrom!.subtract(const Duration(days: 1)),
        buildSnapshot,
      );
      windowFrom = newFrom;
      _evictBeyondMax(c);
      return 'past';
    }
    if (daysToFutureEdge <= WarmDayWindowConstants.extendThreshold) {
      final newTo = windowTo!.add(
        const Duration(days: WarmDayWindowConstants.extendBy),
      );
      _warmRange(
        windowTo!.add(const Duration(days: 1)),
        newTo,
        buildSnapshot,
      );
      windowTo = newTo;
      _evictBeyondMax(c);
      return 'future';
    }
    return null;
  }

  void _evictBeyondMax(DateTime centerDay) {
    if (_snapshots.length <= WarmDayWindowConstants.maxCachedDays) return;
    final c = dateOnly(centerDay);
    final keys = _snapshots.keys.toList()
      ..sort((a, b) {
        final da = parseDateKey(a);
        final db = parseDateKey(b);
        final distA = da.difference(c).inDays.abs();
        final distB = db.difference(c).inDays.abs();
        return distB.compareTo(distA);
      });
    while (_snapshots.length > WarmDayWindowConstants.maxCachedDays) {
      _snapshots.remove(keys.removeAt(0));
    }
  }

  void invalidateAll() {
    _snapshots.clear();
    windowFrom = null;
    windowTo = null;
    center = null;
  }
}
