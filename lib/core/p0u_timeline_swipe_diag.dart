import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// P0U.4D — first Timeline swipe diagnostics only (summary-level, no spam).
abstract final class P0uTimelineSwipeDiag {
  static bool _firstSwipeConsumed = false;
  static bool _sessionActive = false;
  static String? _targetDateKey;
  static Stopwatch? _swipeSw;
  static TimingsCallback? _timingsCallback;

  static int _longestFrameMs = 0;
  static int _frameCount = 0;
  static int _over16ms = 0;
  static int _over32ms = 0;
  static int _frameLogCount = 0;
  static const int _maxFrameLogs = 12;

  static String _phase = 'drag';
  static final Set<String> _pagesBuilt = {};

  static bool get sessionActive => _sessionActive;
  static bool get isFirstSwipePending => !_firstSwipeConsumed;

  static bool isTargetDate(String dateKey) =>
      _sessionActive && _targetDateKey == dateKey;

  static bool wasPageBuilt(String dateKey) => _pagesBuilt.contains(dateKey);

  static void markPageBuilt(String dateKey) {
    _pagesBuilt.add(dateKey);
  }

  static void begin({
    required String fromDate,
    required String targetDate,
    required int page,
    required int targetPage,
  }) {
    if (_firstSwipeConsumed) return;
    if (_sessionActive && _targetDateKey == targetDate) return;
    _sessionActive = true;
    _targetDateKey = targetDate;
    _swipeSw ??= Stopwatch()..start();
    _phase = 'drag';
    _resetFrameStats();
    _attachTimings();
    debugPrint(
      '[P0U_TIMELINE_SWIPE_BEGIN] fromDate=$fromDate targetDate=$targetDate '
      'page=$page targetPage=$targetPage',
    );
  }

  static void commit({
    required String fromDate,
    required String targetDate,
    required String source,
  }) {
    if (!_sessionActive || _firstSwipeConsumed) return;
    _phase = 'settle';
    debugPrint(
      '[P0U_TIMELINE_SWIPE_COMMIT] fromDate=$fromDate targetDate=$targetDate '
      'source=$source',
    );
  }

  static void done({required String targetDate, required bool ok}) {
    if (_firstSwipeConsumed) return;
    if (!_sessionActive && _targetDateKey == null) return;
    final ms = _swipeSw?.elapsedMilliseconds ?? 0;
    _detachTimings();
    debugPrint(
      '[P0U_TIMELINE_SWIPE_DONE] targetDate=$targetDate ok=$ok totalMs=$ms',
    );
    _emitJankSummary(targetDate);
    _firstSwipeConsumed = true;
    _sessionActive = false;
    _targetDateKey = null;
    _swipeSw = null;
  }

  static void targetState({
    required String targetDate,
    required String dayIndex,
    required int records,
    required String rowVm,
    required int rows,
    required bool pageBuilt,
    required bool active,
  }) {
    if (!_sessionActive || _firstSwipeConsumed) return;
    debugPrint(
      '[P0U_TIMELINE_TARGET_STATE] targetDate=$targetDate '
      'dayIndex=$dayIndex records=$records rowVm=$rowVm rows=$rows '
      'pageBuilt=$pageBuilt active=$active',
    );
  }

  static void targetDataReady({
    required String targetDate,
    required String source,
    required int records,
    required int ms,
  }) {
    if (!_sessionActive || _firstSwipeConsumed) return;
    if (_targetDateKey != null && _targetDateKey != targetDate) return;
    debugPrint(
      '[P0U_TIMELINE_TARGET_DATA_READY] targetDate=$targetDate '
      'source=$source records=$records ms=$ms',
    );
  }

  static void targetVmReady({
    required String targetDate,
    required String source,
    required int rows,
    required int ms,
  }) {
    if (!_sessionActive || _firstSwipeConsumed) return;
    if (_targetDateKey != null && _targetDateKey != targetDate) return;
    debugPrint(
      '[P0U_TIMELINE_TARGET_VM_READY] targetDate=$targetDate '
      'source=$source rows=$rows ms=$ms',
    );
  }

  static void targetListBuild({
    required String targetDate,
    required int rows,
    required int ms,
  }) {
    if (!_sessionActive || _firstSwipeConsumed) return;
    if (_targetDateKey != targetDate) return;
    debugPrint(
      '[P0U_TIMELINE_TARGET_LIST_BUILD] targetDate=$targetDate '
      'rows=$rows ms=$ms',
    );
  }

  static void targetPageBuild({
    required String targetDate,
    required int ms,
  }) {
    if (!_sessionActive || _firstSwipeConsumed) return;
    if (_targetDateKey != targetDate) return;
    debugPrint(
      '[P0U_TIMELINE_TARGET_PAGE_BUILD] targetDate=$targetDate ms=$ms',
    );
  }

  static void _resetFrameStats() {
    _longestFrameMs = 0;
    _frameCount = 0;
    _over16ms = 0;
    _over32ms = 0;
    _frameLogCount = 0;
  }

  static void _attachTimings() {
    if (_timingsCallback != null) return;
    _timingsCallback = (List<FrameTiming> timings) {
      if (!_sessionActive || _firstSwipeConsumed) return;
      for (final t in timings) {
        final ms = t.totalSpan.inMilliseconds;
        _frameCount++;
        if (ms > _longestFrameMs) _longestFrameMs = ms;
        if (ms > 16) _over16ms++;
        if (ms > 32) _over32ms++;
        if (ms > 16 &&
            _frameLogCount < _maxFrameLogs &&
            _targetDateKey != null) {
          _frameLogCount++;
          debugPrint(
            '[P0U_TIMELINE_SWIPE_FRAME] targetDate=$_targetDateKey '
            'frameMs=$ms phase=$_phase',
          );
        }
      }
    };
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback!);
  }

  static void _detachTimings() {
    final cb = _timingsCallback;
    if (cb != null) {
      SchedulerBinding.instance.removeTimingsCallback(cb);
      _timingsCallback = null;
    }
  }

  static void _emitJankSummary(String targetDate) {
    debugPrint(
      '[P0U_TIMELINE_SWIPE_JANK_SUMMARY] targetDate=$targetDate '
      'longestFrameMs=$_longestFrameMs frameCount=$_frameCount '
      'over16ms=$_over16ms over32ms=$_over32ms',
    );
  }
}
