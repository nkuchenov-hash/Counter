/// Finite mounted day window: ±3 initial (P0T), extend by 10, max 41 bodies.
/// Data warm window stays ±10 via [WarmDayWindowConstants].
///
/// Kept for legacy [kUseP0tMountedStrip] path (kill switch false). Active Timeline/Plans
/// use [PageView.builder]; this window only applies when mounted strip is re-enabled.
final class MountedDayWindow {
  MountedDayWindow({required DateTime center})
    : _center = dateOnly(center) {
    _windowFrom = _center.subtract(const Duration(days: radius));
    _windowTo = _center.add(const Duration(days: radius));
  }

  /// P0T: fewer eagerly mounted bodies (7) — was ±10 (21) under P0S.
  static const int radius = 3;
  static const int extendThreshold = 3;
  static const int extendBy = 10;
  static const int maxBodies = 41;

  DateTime _center;
  late DateTime _windowFrom;
  late DateTime _windowTo;

  DateTime get center => _center;
  DateTime get windowFrom => _windowFrom;
  DateTime get windowTo => _windowTo;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<DateTime> get dates {
    final out = <DateTime>[];
    var d = _windowFrom;
    while (!d.isAfter(_windowTo)) {
      out.add(d);
      d = d.add(const Duration(days: 1));
    }
    return out;
  }

  Iterable<String> get dateKeys => dates.map(dateKey);

  int get length => dates.length;

  bool contains(DateTime date) {
    final d = dateOnly(date);
    return !d.isBefore(_windowFrom) && !d.isAfter(_windowTo);
  }

  int indexOf(DateTime date) => dateOnly(date).difference(_windowFrom).inDays;

  DateTime dateAt(int index) => _windowFrom.add(Duration(days: index));

  void recenter(DateTime date) {
    _center = dateOnly(date);
    _windowFrom = _center.subtract(const Duration(days: radius));
    _windowTo = _center.add(const Duration(days: radius));
  }

  /// Extends window when [selected] is within [extendThreshold] of an edge.
  /// Returns scroll-index delta when days were prepended at the past edge.
  int extendIfNeeded({
    required String screen,
    required DateTime selected,
    void Function(DateTime date)? onNewDate,
  }) {
    final sel = dateOnly(selected);
    var scrollShift = 0;
    final distFromStart = sel.difference(_windowFrom).inDays;
    final distToEnd = _windowTo.difference(sel).inDays;

    if (distFromStart <= extendThreshold) {
      final oldFrom = _windowFrom;
      _windowFrom = _windowFrom.subtract(const Duration(days: extendBy));
      scrollShift += extendBy;
      var d = _windowFrom;
      while (d.isBefore(oldFrom)) {
        onNewDate?.call(d);
        d = d.add(const Duration(days: 1));
      }
    }

    if (distToEnd <= extendThreshold) {
      final oldTo = _windowTo;
      _windowTo = _windowTo.add(const Duration(days: extendBy));
      var d = oldTo.add(const Duration(days: 1));
      while (!d.isAfter(_windowTo)) {
        onNewDate?.call(d);
        d = d.add(const Duration(days: 1));
      }
    }

    _evictFarthest(screen: screen, keepAround: sel);
    return scrollShift;
  }

  void _evictFarthest({required String screen, required DateTime keepAround}) {
    while (length > maxBodies) {
      final distFromStart = keepAround.difference(_windowFrom).inDays;
      final distToEnd = _windowTo.difference(keepAround).inDays;
      if (distFromStart >= distToEnd) {
        _windowTo = _windowTo.subtract(const Duration(days: 1));
      } else {
        _windowFrom = _windowFrom.add(const Duration(days: 1));
      }
    }
  }
}
