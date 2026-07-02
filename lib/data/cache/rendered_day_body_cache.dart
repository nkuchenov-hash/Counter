import 'package:counter/data/models.dart';

/// P0R: rendered day body cache constants.
abstract final class RenderedDayBodyConstants {
  static const int criticalRadius = 1;
  static const int radius = 10;
  static const int extendThreshold = 3;
  static const int extendBy = 10;
  static const int maxBodies = 41;
}

/// Prebuilt timeline day body data (not widgets).
class TimelineDayBodyEntry {
  const TimelineDayBodyEntry({
    required this.dateKey,
    required this.records,
    required this.knownEmpty,
    required this.bodyReady,
    required this.source,
  });

  final String dateKey;
  final List<Map<String, dynamic>> records;
  final bool knownEmpty;
  final bool bodyReady;
  final String source;
}

/// Prebuilt plans day body data (not widgets).
class PlansDayBodyEntry {
  const PlansDayBodyEntry({
    required this.dateKey,
    required this.tasks,
    required this.knownEmpty,
    required this.bodyReady,
    required this.source,
  });

  final String dateKey;
  final List<PlanningTask> tasks;
  final bool knownEmpty;
  final bool bodyReady;
  final String source;
}

/// In-memory rendered body cache for one screen.
final class DayBodyCache<TEntry> {
  DayBodyCache({required this.screen});

  final String screen;
  final Map<String, TEntry> _entries = {};
  String? _centerKey;
  int _windowPrebuildGeneration = 0;
  final bool _windowPrebuildInFlight = false;

  int get bodyCount => _entries.length;

  TEntry? peek(String dateKey) => _entries[dateKey];

  bool isBodyReady(String dateKey) {
    final e = _entries[dateKey];
    if (e == null) return false;
    if (e is TimelineDayBodyEntry) return e.bodyReady;
    if (e is PlansDayBodyEntry) return e.bodyReady;
    return false;
  }

  bool isDataReady(String dateKey) => _entries.containsKey(dateKey);

  void put(String dateKey, TEntry entry) {
    _entries[dateKey] = entry;
    _evictIfNeeded();
  }

  void setCenter(String centerKey) => _centerKey = centerKey;

  Iterable<String> get dateKeys => _entries.keys;

  void invalidateAll() {
    _entries.clear();
    _centerKey = null;
    _windowPrebuildGeneration++;
  }

  bool isInsideWarmRange(String dateKey) {
    if (_centerKey == null) return false;
    final center = _parseKey(_centerKey!);
    final day = _parseKey(dateKey);
    final dist = day.difference(center).inDays.abs();
    return dist <= RenderedDayBodyConstants.radius;
  }

  bool isInsideCriticalRange(String dateKey) {
    if (_centerKey == null) return false;
    final center = _parseKey(_centerKey!);
    final day = _parseKey(dateKey);
    final dist = day.difference(center).inDays.abs();
    return dist <= RenderedDayBodyConstants.criticalRadius;
  }

  int countReadyInRange(int radius) {
    if (_centerKey == null) return 0;
    final center = _parseKey(_centerKey!);
    var n = 0;
    for (final key in _entries.keys) {
      final dist = _parseKey(key).difference(center).inDays.abs();
      if (dist <= radius && isBodyReady(key)) n++;
    }
    return n;
  }

  /// Offsets prioritized: 0, -1, +1, -2, +2, ... up to [radius].
  static List<int> prioritizedOffsets(int radius) {
    final out = <int>[0];
    for (var i = 1; i <= radius; i++) {
      out.add(-i);
      out.add(i);
    }
    return out;
  }

  void _evictIfNeeded() {
    if (_entries.length <= RenderedDayBodyConstants.maxBodies) return;
    if (_centerKey == null) return;
    final center = _parseKey(_centerKey!);
    final keys = _entries.keys.toList()
      ..sort((a, b) {
        final distA = _parseKey(a).difference(center).inDays.abs();
        final distB = _parseKey(b).difference(center).inDays.abs();
        return distB.compareTo(distA);
      });
    while (_entries.length > RenderedDayBodyConstants.maxBodies) {
      _entries.remove(keys.removeAt(0));
    }
  }

  static String dateKeyFrom(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _parseKey(String key) {
    final p = key.split('-');
    if (p.length != 3) return DateTime.now();
    return DateTime(
      int.tryParse(p[0]) ?? 2000,
      int.tryParse(p[1]) ?? 1,
      int.tryParse(p[2]) ?? 1,
    );
  }

  void logMemory({required int snapshotCount, required int itemCount}) {
  }
}
