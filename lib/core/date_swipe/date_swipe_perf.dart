import 'package:counter/core/app_diag.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Debug-gated frame diagnostics for horizontal **date** paging (Timeline/Planning).
class DateSwipePerfMonitor {
  DateSwipePerfMonitor._();
  static final DateSwipePerfMonitor instance = DateSwipePerfMonitor._();

  String? _section;
  String? _fromDateKey;
  DateTime? _startedAt;
  int _timingCallbacks = 0;
  double _maxBuildMs = 0;
  double _maxRasterMs = 0;

  static const double _warnMs = 16;
  static const double _strongWarnMs = 32;
  static const double _criticalMs = 50;

  bool get isSwipeActive => _startedAt != null;

  void onSwipeStart({required String section, required String dateKey}) {
    if (!kDebugMode) return;
    _section = section;
    _fromDateKey = dateKey;
    _startedAt = DateTime.now();
    _maxBuildMs = 0;
    _maxRasterMs = 0;
    if (_timingCallbacks == 0) {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _timingCallbacks = 1;
    }
    appDebugDiag('DATE_SWIPE_START section=$section date=$dateKey');
  }

  void onSwipeEnd({required String toDateKey}) {
    if (!kDebugMode) return;
    final section = _section ?? '-';
    final from = _fromDateKey ?? '-';
    final started = _startedAt;
    _startedAt = null;
    _section = null;
    _fromDateKey = null;
    if (_timingCallbacks > 0) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _timingCallbacks = 0;
    }
    final durationMs = started == null
        ? 0
        : DateTime.now().difference(started).inMilliseconds;
    appDebugDiag(
      'DATE_SWIPE_END section=$section fromDate=$from toDate=$toDateKey durationMs=$durationMs',
    );
    final totalMs = _maxBuildMs + _maxRasterMs;
    if (totalMs >= _warnMs) {
      final level = totalMs >= _criticalMs
          ? 'critical'
          : totalMs >= _strongWarnMs
          ? 'strong'
          : 'warn';
      appDebugDiag(
        'DATE_SWIPE_JANK section=$section level=$level buildMs=${_maxBuildMs.toStringAsFixed(1)} '
        'rasterMs=${_maxRasterMs.toStringAsFixed(1)} totalMs=${totalMs.toStringAsFixed(1)}',
      );
    }
    _maxBuildMs = 0;
    _maxRasterMs = 0;
  }

  void logGestureOwner(String owner) {
    appDebugDiag('DATE_SWIPE_GESTURE_OWNER owner=$owner');
  }

  void logFetchBlocked(String reason) {
    appDebugDiag('DATE_SWIPE_FETCH_BLOCKED section=${_section ?? '-'} reason=$reason');
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_startedAt == null) return;
    for (final t in timings) {
      final buildMs = t.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = t.rasterDuration.inMicroseconds / 1000.0;
      if (buildMs > _maxBuildMs) _maxBuildMs = buildMs;
      if (rasterMs > _maxRasterMs) _maxRasterMs = rasterMs;
    }
  }
}
