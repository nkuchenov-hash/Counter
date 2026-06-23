import 'package:counter/core/p0s_mount_diag.dart';

/// Finite mounted day window: ±10 initial, extend by 10, max 41 bodies (P0S).
final class MountedDayWindow {
  MountedDayWindow({required DateTime center})
    : _center = dateOnly(center) {
    _windowFrom = _center.subtract(const Duration(days: radius));
    _windowTo = _center.add(const Duration(days: radius));
  }

  static const int radius = 10;
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
      final sw = Stopwatch()..start();
      P0SMountDiag.mountExtendStart(
        screen: screen,
        direction: 'past',
        from: dateKey(oldFrom),
        to: dateKey(_windowFrom),
      );
      var d = _windowFrom;
      while (d.isBefore(oldFrom)) {
        onNewDate?.call(d);
        P0SMountDiag.mountExtendBody(
          screen: screen,
          date: dateKey(d),
          ms: 0,
        );
        d = d.add(const Duration(days: 1));
      }
      sw.stop();
      P0SMountDiag.mountExtendDone(
        screen: screen,
        mounted: length,
        ms: sw.elapsedMilliseconds,
      );
    }

    if (distToEnd <= extendThreshold) {
      final oldTo = _windowTo;
      _windowTo = _windowTo.add(const Duration(days: extendBy));
      final sw = Stopwatch()..start();
      P0SMountDiag.mountExtendStart(
        screen: screen,
        direction: 'future',
        from: dateKey(oldTo),
        to: dateKey(_windowTo),
      );
      var d = oldTo.add(const Duration(days: 1));
      while (!d.isAfter(_windowTo)) {
        onNewDate?.call(d);
        P0SMountDiag.mountExtendBody(
          screen: screen,
          date: dateKey(d),
          ms: 0,
        );
        d = d.add(const Duration(days: 1));
      }
      sw.stop();
      P0SMountDiag.mountExtendDone(
        screen: screen,
        mounted: length,
        ms: sw.elapsedMilliseconds,
      );
    }

    _evictFarthest(screen: screen, keepAround: sel);
    return scrollShift;
  }

  void _evictFarthest({required String screen, required DateTime keepAround}) {
    while (length > maxBodies) {
      final distFromStart = keepAround.difference(_windowFrom).inDays;
      final distToEnd = _windowTo.difference(keepAround).inDays;
      if (distFromStart >= distToEnd) {
        P0SMountDiag.mountEvict(
          screen: screen,
          date: dateKey(_windowTo),
          reason: 'maxBodies',
        );
        _windowTo = _windowTo.subtract(const Duration(days: 1));
      } else {
        P0SMountDiag.mountEvict(
          screen: screen,
          date: dateKey(_windowFrom),
          reason: 'maxBodies',
        );
        _windowFrom = _windowFrom.add(const Duration(days: 1));
      }
    }
  }
}
